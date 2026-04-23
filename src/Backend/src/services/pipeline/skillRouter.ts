/**
 * SkillRouter — Sprint 10 · S10-12 · R2
 *
 * Per-atom router that replaces Stage 4's monolithic "give me N cards"
 * prompt with the skill engine. For each atom produced by the concept
 * decomposer it:
 *
 *   1. Looks up the skill mapped to `atom.recommendedCardType`.
 *   2. Rebuilds the child's `teachingStrategy` for the atom's concept
 *      type via `withConceptType(base, conceptType)` — no DB re-fetch.
 *   3. Builds per-skill `inputs` (topic/concept/etc.) from the atom +
 *      analysis shell.
 *   4. Invokes `skill.buildPrompt(...)` to get system + user + meta.
 *   5. Routes the call through `routeRequest` at the skill's hinted
 *      temperature.
 *   6. Parses the response — free-form prose for story-writer, JSON for
 *      quiz-maker — and validates with the skill's Zod `outputSchema`
 *      when present.
 *   7. On Zod failure, re-prompts once with the error summary appended
 *      to the user turn (closes S9-07's carried retry debt). The second
 *      failure is recorded and the atom falls back to the legacy
 *      generator downstream.
 *
 * Design tenets:
 *
 *   - **Per-atom independence.** One bad atom never halts the run —
 *     each produces an `AtomRouteResult` with a card or a skip reason.
 *   - **Legacy fallback-friendly.** When an atom's card type isn't
 *     mapped yet (concept / experiment / voice in S10-12), the router
 *     returns a skip marker so `generateCards` can delegate that one
 *     atom to the legacy path.
 *   - **Trace emission.** Every atom (success or skip) produces a trace
 *     record shaped for R7's Dev Console. The router deliberately does
 *     not write anywhere — it returns the traces to the caller.
 *   - **No LLM-unaware failure.** Transient LLM errors surface as-is
 *     (so `runStage`'s outer retry can still bail); validation / JSON /
 *     logic errors are captured in the trace.
 */
import type { z } from 'zod';
import { ZodError } from 'zod';

import { routeRequest } from '@services/llm/providerRouter';
import type { LLMMessage, LLMResponse } from '@services/llm/types';
import { getSkillRegistry } from '@services/skills/registry';
import type {
  ChildContext,
  Skill,
  SkillPromptMeta,
} from '@services/skills/types';
import { CARD_TYPE_TO_SKILL } from '@services/skills/types';
import type { ConceptType } from '@services/skills/teachingStrategy';

import type { ContentAnalysis } from './contentAnalyzer';
import type { ConceptAtom, TeachingStrategy } from './conceptDecomposer';
import type { GeneratedCard, CardType } from './cardGenerator';
import { withConceptType } from './childContextBuilder';
import { errMsg, isTransient } from './pipelineUtils';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/**
 * Result of attempting to route one atom through the skill engine.
 *
 * The caller (cardGenerator in R4) treats `kind === 'skipped'` as a
 * signal to hand the atom to the legacy prompt path. `kind === 'ok'`
 * means the card is ready for persistence.
 */
export type AtomRouteResult =
  | {
      kind: 'ok';
      atomId: string;
      card: GeneratedCard;
      trace: AtomTrace;
    }
  | {
      kind: 'skipped';
      atomId: string;
      reason: SkipReason;
      trace: AtomTrace;
    };

export type SkipReason =
  | 'no-skill-mapping'
  | 'skill-not-loaded'
  | 'skill-runtime-error'
  | 'llm-error'
  | 'json-parse-error'
  | 'validation-failed'
  | 'missing-required-input'
  | 'empty-response';

/**
 * Trace record emitted for every atom. Keeps all the dimensions the Dev
 * Console's R7 "Pipeline" tab wants to show: which skill ran, against
 * which age-profile + difficulty, did the validator pass, how many
 * tokens, any error summary.
 */
export interface AtomTrace {
  atomId: string;
  atomName: string;
  cardType: CardType;
  /** null when the atom had no mapping. */
  skillName: string | null;
  /** null when the skill ran out of the gate (mapping/loaded). */
  promptMeta: SkillPromptMeta | null;
  /**
   * 'ok'         — validator passed on first try (or no validator)
   * 'retry-ok'   — validator failed once, second attempt passed
   * 'retry-failed' — validator failed twice
   * 'skipped'    — skill never ran (mapping / missing / runtime)
   */
  validatorStatus: 'ok' | 'retry-ok' | 'retry-failed' | 'skipped';
  retryCount: number;
  tokens?: {
    prompt: number;
    completion: number;
    total: number;
  };
  /** First error encountered (Zod pretty-printed for validation). */
  error?: string;
  skipReason?: SkipReason;
  /** Echoed modality + effective age so the UI doesn't have to re-derive. */
  modality: ChildContext['teachingStrategy']['modality'];
  conceptType: ConceptType;
  effectiveAgeYears: number;
  progressionDelta: number;
}

export interface RouteAtomInputs {
  /** User making the request — threaded for cost tracking + BYOK routing. */
  userId: string;
  /** Base child context — the router rebuilds per-atom teaching strategy. */
  baseContext: ChildContext;
  /** The atom being generated. */
  atom: ConceptAtom;
  /** Its zero-based position in the decomposition (for sortOrder). */
  atomIndex: number;
  /**
   * Analysis shell — provides `topic`, `summary`, etc. used to populate
   * per-skill inputs.
   */
  analysis: ContentAnalysis;
  /** Optional excerpt from the preceding story atom — helpful for quiz. */
  lastStoryExcerpt?: string;
  /**
   * Registry override — tests pin a fresh instance via
   * `__resetSkillRegistryForTests`. Default = singleton.
   */
  registry?: {
    has(name: string): boolean;
    get(name: string): Skill;
  };
}

export interface RouteResult {
  results: AtomRouteResult[];
  /** Atoms that skipped so the caller can batch a legacy fallback run. */
  skipped: Array<{ atomId: string; reason: SkipReason }>;
  /** Shallow trace list — Dev Console consumes this directly. */
  traces: AtomTrace[];
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/**
 * Adapter from the decomposer's `TeachingStrategy` (7 values) down to
 * the teaching-strategy matrix's `ConceptType` (6 values). The
 * decomposer was designed before S10-11; this mapping is how we bridge.
 *
 *   narrative    → abstract    (stories teach abstract ideas)
 *   explanation  → factual     (direct claims about how things are)
 *   experiment   → process     (step-by-step demonstration)
 *   comparison   → comparison  (direct match)
 *   cause_effect → causeEffect (direct match, rename casing)
 *   quiz         → factual     (probes a discrete fact)
 *   voice        → abstract    (voice cards default to reflection)
 */
const STRATEGY_TO_CONCEPT_TYPE: Record<TeachingStrategy, ConceptType> = {
  narrative: 'abstract',
  explanation: 'factual',
  experiment: 'process',
  comparison: 'comparison',
  cause_effect: 'causeEffect',
  quiz: 'factual',
  voice: 'abstract',
};

/**
 * Cap LLM output tokens per skill. Keeps cost predictable; the prompts
 * themselves tell the model how long to be, so this is a safety net.
 */
const SKILL_MAX_TOKENS: Record<string, number> = {
  'story-writer': 800,
  'quiz-maker': 600,
  // experiment-designer emits title + instructions + up to 5 dragItems +
  // up to 3 dropTargets with acceptsItemIds + conceptSummary +
  // rationalePerTarget. Larger envelope than quiz-maker because the
  // rationale section is long; still well under story-writer's.
  'experiment-designer': 900,
  // voice-persona emits title + promptText (≤180) + up to 5 short
  // expectedResponses + celebration (≤80) + retryHint (≤80) +
  // optional phonetics + conceptSummary (≤280). Empirically lands at
  // 300–500 tokens; 700 is ~50% headroom. Shorter than experiment
  // because there's no parallel rationale array; longer than quiz
  // because the three Dashy voice lines each have their own envelope.
  'voice-persona': 700,
};

/**
 * Model routing — the manifest's `modelHint` is advisory. Until the
 * costRouter lands a proper tier-selection layer, we pass Claude
 * sonnet for both. Can be swapped to `claude-haiku` for "flash" if we
 * wire a Haiku client later.
 */
const SKILL_TO_MODEL: Record<string, string> = {
  'story-writer': 'claude-sonnet',
  'quiz-maker': 'claude-sonnet',
  'experiment-designer': 'claude-sonnet',
  'voice-persona': 'claude-sonnet',
};

/** Default when a skill isn't in the table above. */
const DEFAULT_MODEL = 'claude-sonnet';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Route a single atom through the skill engine.
 *
 * Transient LLM errors (timeout / 5xx / rate limit) are re-thrown so
 * the outer `runStage` can retry. All other failures — missing
 * mapping, unloaded skill, JSON parse, validation — are captured in
 * the trace and surface as an 'skipped' result.
 */
export async function routeAtom(
  inputs: RouteAtomInputs
): Promise<AtomRouteResult> {
  const { atom, atomIndex, baseContext, userId, analysis } = inputs;
  const registry = inputs.registry ?? getSkillRegistry();

  // ---- 1. Resolve the skill --------------------------------------------

  const skillName = CARD_TYPE_TO_SKILL[atom.recommendedCardType];
  if (!skillName) {
    return buildSkipResult(atom, baseContext, 'no-skill-mapping');
  }

  if (!registry.has(skillName)) {
    return buildSkipResult(atom, baseContext, 'skill-not-loaded', skillName);
  }

  let skill: Skill;
  try {
    skill = registry.get(skillName);
  } catch (err) {
    return buildSkipResult(
      atom,
      baseContext,
      'skill-not-loaded',
      skillName,
      errMsg(err)
    );
  }

  // ---- 2. Per-atom teaching strategy ------------------------------------

  const conceptType = STRATEGY_TO_CONCEPT_TYPE[atom.teachingStrategy] ??
    baseContext.teachingStrategy.conceptType;
  const ctx = withConceptType(baseContext, conceptType);

  // ---- 3. Per-skill inputs ---------------------------------------------

  const skillInputs = buildSkillInputs(skillName, atom, analysis, inputs.lastStoryExcerpt);

  // ---- 4. Build the prompt ----------------------------------------------

  let system: string;
  let user: string;
  let promptMeta: SkillPromptMeta;
  try {
    const built = skill.buildPrompt({ ctx, inputs: skillInputs });
    system = built.system;
    user = built.user;
    promptMeta = built.meta;
  } catch (err) {
    const msg = errMsg(err);
    const reason: SkipReason = msg.includes('missing required input')
      ? 'missing-required-input'
      : 'skill-runtime-error';
    return buildSkipResult(
      atom,
      baseContext,
      reason,
      skillName,
      msg,
      /* promptMeta */ null
    );
  }

  // ---- 5. First attempt: LLM call + parse + validate --------------------

  let response: LLMResponse;
  try {
    response = await callLLM({
      userId,
      model: pickModel(skillName),
      system,
      user,
      temperature: promptMeta.temperatureHint,
      maxTokens: pickMaxTokens(skillName),
    });
  } catch (err) {
    // Let transient errors bubble up for runStage to retry; capture the
    // rest as a skipped result so the atom falls back.
    if (isTransient(err)) throw err;
    return buildSkipResult(
      atom,
      baseContext,
      'llm-error',
      skillName,
      errMsg(err),
      promptMeta
    );
  }

  if (!response.content || !response.content.trim()) {
    return buildSkipResult(
      atom,
      baseContext,
      'empty-response',
      skillName,
      'LLM returned an empty response',
      promptMeta,
      tokensOf(response)
    );
  }

  const firstAttempt = tryParseAndValidate(response.content, skill);

  if (firstAttempt.ok) {
    const card = buildCardFromSkillOutput(
      skillName,
      atom,
      atomIndex,
      firstAttempt.value,
      response.content
    );
    return {
      kind: 'ok',
      atomId: atom.id,
      card,
      trace: {
        atomId: atom.id,
        atomName: atom.name,
        cardType: atom.recommendedCardType,
        skillName,
        promptMeta,
        validatorStatus: 'ok',
        retryCount: 0,
        tokens: tokensOf(response),
        modality: ctx.teachingStrategy.modality,
        conceptType: ctx.teachingStrategy.conceptType,
        effectiveAgeYears: ctx.effectiveAgeYears,
        progressionDelta: ctx.progressionDelta,
      },
    };
  }

  // ---- 6. Retry once with feedback appended to the user turn ------------
  // R3 (closes S9-07): feed the pretty-printed error back to the model.
  // Only retry for validation / parse errors — those are the cases where
  // re-prompting actually stands to recover. Runtime/logic errors would
  // just burn tokens.

  const retryableReasons: SkipReason[] = ['validation-failed', 'json-parse-error'];
  if (!retryableReasons.includes(firstAttempt.reason)) {
    return buildSkipResult(
      atom,
      baseContext,
      firstAttempt.reason,
      skillName,
      firstAttempt.error,
      promptMeta,
      tokensOf(response)
    );
  }

  const retryUser = appendValidationFeedback(user, firstAttempt.error);

  let retryResponse: LLMResponse;
  try {
    retryResponse = await callLLM({
      userId,
      model: pickModel(skillName),
      system,
      user: retryUser,
      temperature: Math.max(0, promptMeta.temperatureHint - 0.1),
      maxTokens: pickMaxTokens(skillName),
    });
  } catch (err) {
    if (isTransient(err)) throw err;
    return buildSkipResult(
      atom,
      baseContext,
      'llm-error',
      skillName,
      errMsg(err),
      promptMeta,
      tokensOf(response),
      /* retryCount */ 1,
      'retry-failed'
    );
  }

  if (!retryResponse.content || !retryResponse.content.trim()) {
    return buildSkipResult(
      atom,
      baseContext,
      'empty-response',
      skillName,
      'LLM returned an empty response on retry',
      promptMeta,
      addTokens(tokensOf(response), tokensOf(retryResponse)),
      1,
      'retry-failed'
    );
  }

  const secondAttempt = tryParseAndValidate(retryResponse.content, skill);

  if (secondAttempt.ok) {
    const card = buildCardFromSkillOutput(
      skillName,
      atom,
      atomIndex,
      secondAttempt.value,
      retryResponse.content
    );
    return {
      kind: 'ok',
      atomId: atom.id,
      card,
      trace: {
        atomId: atom.id,
        atomName: atom.name,
        cardType: atom.recommendedCardType,
        skillName,
        promptMeta,
        validatorStatus: 'retry-ok',
        retryCount: 1,
        tokens: addTokens(tokensOf(response), tokensOf(retryResponse)),
        modality: ctx.teachingStrategy.modality,
        conceptType: ctx.teachingStrategy.conceptType,
        effectiveAgeYears: ctx.effectiveAgeYears,
        progressionDelta: ctx.progressionDelta,
      },
    };
  }

  return buildSkipResult(
    atom,
    baseContext,
    secondAttempt.reason,
    skillName,
    secondAttempt.error,
    promptMeta,
    addTokens(tokensOf(response), tokensOf(retryResponse)),
    1,
    'retry-failed'
  );
}

/**
 * Route every atom in a decomposition. Preserves atom order in the
 * output. Short-circuits on a transient LLM error (runStage will
 * retry); everything else is captured per-atom.
 */
export async function routeAllAtoms(
  atoms: ConceptAtom[],
  shared: Omit<RouteAtomInputs, 'atom' | 'atomIndex' | 'lastStoryExcerpt'>
): Promise<RouteResult> {
  const results: AtomRouteResult[] = [];
  const skipped: Array<{ atomId: string; reason: SkipReason }> = [];
  const traces: AtomTrace[] = [];

  // Track the most-recent story prose so quiz-maker can reference it.
  // We run sequentially (not Promise.all) to preserve this threading
  // AND to keep LLM concurrency bounded — cardGenerator has always
  // been serial, so we're not regressing there.
  let lastStoryExcerpt: string | undefined;

  for (let i = 0; i < atoms.length; i++) {
    const atom = atoms[i];
    const result = await routeAtom({
      ...shared,
      atom,
      atomIndex: i,
      lastStoryExcerpt,
    });
    results.push(result);
    traces.push(result.trace);

    if (result.kind === 'skipped') {
      skipped.push({ atomId: atom.id, reason: result.reason });
      continue;
    }

    // Only story cards contribute to lastStoryExcerpt. Trim to ~600
    // chars so the quiz prompt doesn't balloon.
    if (result.card.type === 'story') {
      const text = (result.card.content.text ?? '').trim();
      lastStoryExcerpt = text.length > 600 ? text.slice(0, 600) + '…' : text;
    }
  }

  return { results, skipped, traces };
}

// ---------------------------------------------------------------------------
// Internals — parse + validate
// ---------------------------------------------------------------------------

type ValidationOutcome =
  | { ok: true; value: unknown }
  | { ok: false; reason: SkipReason; error: string };

function tryParseAndValidate(
  raw: string,
  skill: Skill
): ValidationOutcome {
  const schema = skill.outputSchema;

  // Story-writer and any skill without a schema produce prose — the
  // caller wraps the raw text, no JSON parse needed.
  if (!schema) {
    return { ok: true, value: raw };
  }

  // With a schema, we expect JSON. Look for the first {...} block so a
  // stray prelude doesn't kill the parse; the schemas themselves are
  // strict enough to reject anything non-conforming.
  const match = raw.match(/\{[\s\S]*\}/);
  if (!match) {
    return {
      ok: false,
      reason: 'json-parse-error',
      error: 'no JSON object found in LLM response',
    };
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(match[0]);
  } catch (err) {
    return {
      ok: false,
      reason: 'json-parse-error',
      error: `invalid JSON: ${errMsg(err)}`,
    };
  }

  try {
    const value = schema.parse(parsed);
    return { ok: true, value };
  } catch (err) {
    if (err instanceof ZodError) {
      return {
        ok: false,
        reason: 'validation-failed',
        error: prettyZodError(err),
      };
    }
    return {
      ok: false,
      reason: 'validation-failed',
      error: errMsg(err),
    };
  }
}

function prettyZodError(err: z.ZodError): string {
  return err.issues
    .map((issue) => {
      const path = issue.path.length > 0 ? issue.path.join('.') : '(root)';
      return `- ${path}: ${issue.message}`;
    })
    .join('\n');
}

function appendValidationFeedback(userPrompt: string, errorSummary: string): string {
  return `${userPrompt}

---
Your previous attempt was rejected by the output validator. Specific problems:

${errorSummary}

Please return a corrected response that conforms to the required schema exactly. Do not apologize or explain — emit only the corrected output.`;
}

// ---------------------------------------------------------------------------
// Internals — per-skill input assembly
// ---------------------------------------------------------------------------

function buildSkillInputs(
  skillName: string,
  atom: ConceptAtom,
  analysis: ContentAnalysis,
  lastStoryExcerpt: string | undefined
): Record<string, unknown> {
  if (skillName === 'story-writer') {
    return {
      topic: atom.name,
      // Pass description as a setting hint so the story lands on the
      // atom's angle rather than a generic treatment. Optional field
      // in the manifest.
      settingHint: atom.description.length < 200 ? atom.description : undefined,
    };
  }
  if (skillName === 'quiz-maker') {
    const conceptType = STRATEGY_TO_CONCEPT_TYPE[atom.teachingStrategy] ?? 'factual';
    const inputs: Record<string, unknown> = {
      concept: atom.name,
      conceptType,
    };
    if (analysis.topic) inputs.topic = analysis.topic;
    if (lastStoryExcerpt) inputs.lastStoryExcerpt = lastStoryExcerpt;
    return inputs;
  }
  if (skillName === 'experiment-designer') {
    // The experiment-designer probes concept grasp via a drag-and-drop
    // sort. It needs the concept + its type, and optionally the broader
    // topic frame + the prior story excerpt so it can re-use character
    // or setting scaffolding the child just met.
    const conceptType = STRATEGY_TO_CONCEPT_TYPE[atom.teachingStrategy] ?? 'process';
    const inputs: Record<string, unknown> = {
      concept: atom.name,
      conceptType,
    };
    if (analysis.topic) inputs.topic = analysis.topic;
    if (lastStoryExcerpt) inputs.lastStoryExcerpt = lastStoryExcerpt;
    return inputs;
  }
  if (skillName === 'voice-persona') {
    // The voice-persona skill probes verbal recall. It needs the
    // concept + its type, and optionally the topic frame + the prior
    // story excerpt so Dashy can reference shared context in her
    // wondering-aloud prompt. STRATEGY_TO_CONCEPT_TYPE maps the
    // `voice` strategy to `abstract` by default; vocabulary / factual
    // strategies override that via their own mapping upstream.
    const conceptType = STRATEGY_TO_CONCEPT_TYPE[atom.teachingStrategy] ?? 'abstract';
    const inputs: Record<string, unknown> = {
      concept: atom.name,
      conceptType,
    };
    if (analysis.topic) inputs.topic = analysis.topic;
    if (lastStoryExcerpt) inputs.lastStoryExcerpt = lastStoryExcerpt;
    return inputs;
  }
  // Unknown skill — pass through the atom's name/description as a
  // best-effort hint. The skill's own required-input validation will
  // reject if that's insufficient.
  return {
    topic: atom.name,
    concept: atom.name,
    description: atom.description,
  };
}

// ---------------------------------------------------------------------------
// Internals — output → GeneratedCard
// ---------------------------------------------------------------------------

function buildCardFromSkillOutput(
  skillName: string,
  atom: ConceptAtom,
  atomIndex: number,
  value: unknown,
  rawResponse: string
): GeneratedCard {
  if (skillName === 'story-writer') {
    const text = typeof value === 'string'
      ? value.trim()
      : rawResponse.trim();
    return {
      type: 'story',
      content: {
        text,
        title: atom.name,
      },
      // The story IS the narration track — TTS synthesis consumes
      // voiceScript. Duplicating here keeps the persisted card shape
      // consistent with the legacy generator's contract.
      voiceScript: text,
      sortOrder: atomIndex,
    };
  }

  if (skillName === 'quiz-maker') {
    const v = value as {
      question: string;
      options: string[];
      correctIndex: number;
      explanation: string;
      rationalePerOption: string[];
    };
    // Build a lesson-quality voice script: read the question, then the
    // explanation. The rationalePerOption array is persisted via the
    // raw card content for the iPad client to surface post-answer.
    const voiceScript = `${v.question} ${v.explanation}`.trim();

    return {
      type: 'quiz',
      content: {
        text: v.question,
        options: v.options,
        correctIndex: v.correctIndex,
      },
      voiceScript,
      sortOrder: atomIndex,
    };
  }

  if (skillName === 'experiment-designer') {
    const v = value as {
      title: string;
      instructions: string;
      dragItems: Array<{ id: string; label: string }>;
      dropTargets: Array<{ id: string; label: string; acceptsItemIds: string[] }>;
      conceptSummary: string;
      rationalePerTarget: string[];
    };
    // Voice script: instructions (what to do) + conceptSummary (why the
    // sort works). Keeps the narration educational without leaking the
    // classification on the way in.
    const voiceScript = `${v.instructions} ${v.conceptSummary}`.trim();

    return {
      type: 'experiment',
      content: {
        title: v.title,
        instructions: v.instructions,
        // Note: backend uses camelCase. The iOS transformer maps this
        // to `drag_items` / `drop_targets` at the app boundary (same
        // pattern as quiz's `correct_option_index`).
        dragItems: v.dragItems,
        dropTargets: v.dropTargets,
      },
      voiceScript,
      sortOrder: atomIndex,
    };
  }

  if (skillName === 'voice-persona') {
    const v = value as {
      title?: string;
      promptText: string;
      expectedResponses: string[];
      celebration: string;
      retryHint: string;
      phonetics?: string;
      conceptSummary: string;
    };
    // Voice script = the full TTS flow the iPad will speak aloud:
    // Dashy introduces her wondering (promptText) and on a correct
    // match will say the celebration line. The retryHint only fires
    // on a miss, so it's NOT part of the default voiceScript — it
    // lives on `content.retryHint` and the iPad reads it on-demand.
    const voiceScript = `${v.promptText} ${v.celebration}`.trim();

    return {
      type: 'voice',
      content: {
        title: v.title,
        // iOS VoiceCardView decodes camelCase promptText /
        // expectedResponses directly — no rename at the transformer
        // because these are already camelCase-clean field names.
        promptText: v.promptText,
        expectedResponses: v.expectedResponses,
        celebration: v.celebration,
        retryHint: v.retryHint,
        phonetics: v.phonetics,
      },
      voiceScript,
      sortOrder: atomIndex,
    };
  }

  // Defensive fallback — shouldn't hit in practice because router only
  // routes mapped skills.
  return {
    type: atom.recommendedCardType,
    content: {
      text: typeof value === 'string' ? value.trim() : rawResponse.trim(),
      title: atom.name,
    },
    voiceScript: typeof value === 'string' ? value.trim() : rawResponse.trim(),
    sortOrder: atomIndex,
  };
}

// ---------------------------------------------------------------------------
// Internals — LLM + tokens
// ---------------------------------------------------------------------------

interface CallLLMInput {
  userId: string;
  model: string;
  system: string;
  user: string;
  temperature: number;
  maxTokens: number;
}

async function callLLM(i: CallLLMInput): Promise<LLMResponse> {
  const messages: LLMMessage[] = [
    { role: 'system', content: i.system },
    { role: 'user', content: i.user },
  ];
  return routeRequest(
    i.userId,
    {
      model: i.model,
      messages,
      temperature: i.temperature,
      maxTokens: i.maxTokens,
    },
    'card_generation'
  );
}

function pickModel(skillName: string): string {
  return SKILL_TO_MODEL[skillName] ?? DEFAULT_MODEL;
}

function pickMaxTokens(skillName: string): number {
  return SKILL_MAX_TOKENS[skillName] ?? 1000;
}

function tokensOf(response: LLMResponse): AtomTrace['tokens'] {
  const u = response.usage;
  if (!u) return undefined;
  return {
    prompt: u.promptTokens ?? 0,
    completion: u.completionTokens ?? 0,
    total: u.totalTokens ?? 0,
  };
}

function addTokens(
  a: AtomTrace['tokens'],
  b: AtomTrace['tokens']
): AtomTrace['tokens'] {
  if (!a && !b) return undefined;
  const left = a ?? { prompt: 0, completion: 0, total: 0 };
  const right = b ?? { prompt: 0, completion: 0, total: 0 };
  return {
    prompt: left.prompt + right.prompt,
    completion: left.completion + right.completion,
    total: left.total + right.total,
  };
}

// ---------------------------------------------------------------------------
// Internals — skip-result builder
// ---------------------------------------------------------------------------

function buildSkipResult(
  atom: ConceptAtom,
  baseContext: ChildContext,
  reason: SkipReason,
  skillName: string | null = null,
  error?: string,
  promptMeta: SkillPromptMeta | null = null,
  tokens?: AtomTrace['tokens'],
  retryCount = 0,
  validatorStatus: AtomTrace['validatorStatus'] = 'skipped'
): AtomRouteResult {
  const conceptType: ConceptType =
    STRATEGY_TO_CONCEPT_TYPE[atom.teachingStrategy] ??
    baseContext.teachingStrategy.conceptType;
  return {
    kind: 'skipped',
    atomId: atom.id,
    reason,
    trace: {
      atomId: atom.id,
      atomName: atom.name,
      cardType: atom.recommendedCardType,
      skillName,
      promptMeta,
      validatorStatus,
      retryCount,
      tokens,
      error,
      skipReason: reason,
      modality: baseContext.teachingStrategy.modality,
      conceptType,
      effectiveAgeYears: baseContext.effectiveAgeYears,
      progressionDelta: baseContext.progressionDelta,
    },
  };
}
