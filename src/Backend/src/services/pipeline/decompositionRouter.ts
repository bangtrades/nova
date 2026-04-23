/**
 * DecompositionRouter — Sprint 12 · S12-05 · R4
 *
 * Stage-3 (concept decomposition) analog of `skillRouter.routeAtom`.
 * Where the skillRouter fans out N per-atom skill calls in Stage 4, this
 * module issues a single `curriculum-architect` call in Stage 3 to
 * produce the `ConceptDecomposition` *itself* — the atom list that
 * Stage 4 then consumes.
 *
 * Why a separate router:
 *
 *   - Stage 3 is a 1:1 LLM call — per-atom retry loops, legacy fallback
 *     cherry-picking, last-story-excerpt threading (all skillRouter
 *     concerns) don't apply. The code here is intentionally narrow.
 *   - The output contract is a `ConceptDecomposition` (legacy shape), not
 *     a `GeneratedCard`. Keeping that mapping out of skillRouter avoids
 *     bloat and keeps the two routers testable in isolation.
 *   - Trace emission is different shape — one `DecompositionTrace`
 *     object, not a per-atom array — so the orchestrator can render a
 *     new Pipeline-tab section preceding the atom traces.
 *
 * Design tenets (same as skillRouter's):
 *
 *   - **Transient errors bubble.** `runStage` outside is allowed to retry
 *     on timeout / 5xx / rate-limit. Everything else is captured in the
 *     trace and surfaces as `{ kind: 'failed' }` so the orchestrator can
 *     fall back to the legacy heuristic `decomposeConcepts()`.
 *   - **Retry-once on Zod.** S10-12-R3's pattern. The model gets the
 *     pretty-printed validation error appended to its own user turn and
 *     a single retry at slightly reduced temperature.
 *   - **No side effects.** The router does not persist, does not update
 *     ingest status — it returns the decomposition (or a failure) + the
 *     trace. The orchestrator owns stateful moves.
 */
import { ZodError } from 'zod';

import { routeRequest } from '@services/llm/providerRouter';
import type { LLMMessage, LLMResponse } from '@services/llm/types';
import { getSkillRegistry } from '@services/skills/registry';
import type {
  ChildContext,
  Skill,
  SkillPromptMeta,
} from '@services/skills/types';

import type { ContentAnalysis } from './contentAnalyzer';
import type { ScrapedContent } from './scraper';
import type { ConceptDecomposition } from './conceptDecomposer';
import { normalizeDecomposition } from './conceptDecomposer';
import { errMsg, isTransient } from './pipelineUtils';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/**
 * The skill invoked at Stage 3. Exported so tests + the Dev Console can
 * assert against the same string the orchestrator uses.
 */
export const DECOMPOSITION_SKILL = 'curriculum-architect';

/** Output-token cap for the curriculum-architect call. */
const DECOMPOSITION_MAX_TOKENS = 1400;

/**
 * Model routing for Stage 3. curriculum-architect is the single skill
 * here today; kept as a map so future Stage-3 experiments (e.g.
 * "curriculum-critic" variants) slot in without touching routing.
 */
const DECOMPOSITION_SKILL_TO_MODEL: Record<string, string> = {
  'curriculum-architect': 'claude-sonnet',
};

const DEFAULT_MODEL = 'claude-sonnet';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export type DecompositionFailureReason =
  | 'skill-not-loaded'
  | 'skill-runtime-error'
  | 'llm-error'
  | 'json-parse-error'
  | 'validation-failed'
  | 'missing-required-input'
  | 'empty-response';

/**
 * Per-run trace for the decomposition stage. Mirrors `AtomTrace`'s
 * shape where it makes sense so the Dev Console "Pipeline" tab can
 * render a uniform row preceding the atom rows.
 */
export interface DecompositionTrace {
  skillName: string;
  /** null when the skill never ran (not loaded / missing input). */
  promptMeta: SkillPromptMeta | null;
  /**
   * 'ok'           — validator passed on first try
   * 'retry-ok'     — second attempt passed
   * 'retry-failed' — both attempts failed validation
   * 'skipped'      — skill never ran (mapping / missing / runtime)
   */
  validatorStatus: 'ok' | 'retry-ok' | 'retry-failed' | 'skipped';
  retryCount: number;
  tokens?: {
    prompt: number;
    completion: number;
    total: number;
  };
  error?: string;
  failureReason?: DecompositionFailureReason;
  /** Number of atoms produced (0 on failure). Handy Dev Console glance. */
  atomCount: number;
  /** Echoed context so UI doesn't re-derive. */
  modality: ChildContext['teachingStrategy']['modality'];
  effectiveAgeYears: number;
  progressionDelta: number;
  ageProfileUsed: string;
  difficultyUsed: string;
}

export type DecompositionRouteResult =
  | {
      kind: 'ok';
      decomposition: ConceptDecomposition;
      trace: DecompositionTrace;
    }
  | {
      kind: 'failed';
      reason: DecompositionFailureReason;
      trace: DecompositionTrace;
    };

export interface RouteDecompositionInputs {
  userId: string;
  /** Base child context — decomposition spans all concept types, so
   * `conceptType` is left at the context default. */
  baseContext: ChildContext;
  analysis: ContentAnalysis;
  scraped: ScrapedContent;
  /**
   * Registry override — tests pin a fresh instance via
   * `__resetSkillRegistryForTests`. Default = singleton.
   */
  registry?: {
    has(name: string): boolean;
    get(name: string): Skill;
  };
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Run the curriculum-architect skill to produce a full
 * `ConceptDecomposition`. Returns `{ kind: 'ok', decomposition, trace }`
 * on success; `{ kind: 'failed', reason, trace }` on any non-transient
 * failure (Zod exhausted, skill missing, parse error, …). The
 * orchestrator treats `failed` as a signal to fall back to the legacy
 * `decomposeConcepts()` heuristic path.
 *
 * Transient LLM errors (timeout / 5xx / rate-limit) re-throw so the
 * outer `runStage` can retry as usual.
 */
export async function routeDecomposition(
  inputs: RouteDecompositionInputs
): Promise<DecompositionRouteResult> {
  const { userId, baseContext, analysis, scraped } = inputs;
  const registry = inputs.registry ?? getSkillRegistry();
  const skillName = DECOMPOSITION_SKILL;

  // ---- 1. Resolve the skill --------------------------------------------

  if (!registry.has(skillName)) {
    return buildFailedResult(
      baseContext,
      'skill-not-loaded',
      skillName,
      `skill "${skillName}" is not loaded in the registry`
    );
  }

  let skill: Skill;
  try {
    skill = registry.get(skillName);
  } catch (err) {
    return buildFailedResult(
      baseContext,
      'skill-not-loaded',
      skillName,
      errMsg(err)
    );
  }

  // ---- 2. Per-skill inputs ---------------------------------------------
  //
  // curriculum-architect's manifest requires topic + summary +
  // suggestedStage; optional keyConcepts, suggestedCardCount,
  // sourceExcerpt. We forward whatever the analyzer produced.

  if (!analysis.topic || !analysis.summary) {
    return buildFailedResult(
      baseContext,
      'missing-required-input',
      skillName,
      'analysis missing topic or summary — curriculum-architect needs both'
    );
  }

  const skillInputs: Record<string, unknown> = {
    topic: analysis.topic,
    summary: analysis.summary,
    suggestedStage: analysis.suggestedStage,
  };
  if (Array.isArray(analysis.keyConcepts) && analysis.keyConcepts.length > 0) {
    skillInputs.keyConcepts = analysis.keyConcepts;
  }
  if (typeof analysis.suggestedCardCount === 'number') {
    skillInputs.suggestedCardCount = analysis.suggestedCardCount;
  }
  // Source excerpt lets the architect pull evocative language from the
  // original article if it wants — truncated so the prompt doesn't
  // explode. Title is prepended so the model has the frame.
  if (scraped?.content) {
    const excerpt = `Title: ${scraped.title ?? ''}\n\n${scraped.content}`;
    skillInputs.sourceExcerpt =
      excerpt.length > 2500 ? excerpt.slice(0, 2500) + '…' : excerpt;
  }

  // ---- 3. Build the prompt ----------------------------------------------

  let system: string;
  let user: string;
  let promptMeta: SkillPromptMeta;
  try {
    const built = skill.buildPrompt({ ctx: baseContext, inputs: skillInputs });
    system = built.system;
    user = built.user;
    promptMeta = built.meta;
  } catch (err) {
    const msg = errMsg(err);
    const reason: DecompositionFailureReason = msg.includes('missing required input')
      ? 'missing-required-input'
      : 'skill-runtime-error';
    return buildFailedResult(baseContext, reason, skillName, msg, /* promptMeta */ null);
  }

  // ---- 4. First attempt -------------------------------------------------

  let response: LLMResponse;
  try {
    response = await callLLM({
      userId,
      model: pickModel(skillName),
      system,
      user,
      temperature: promptMeta.temperatureHint,
      maxTokens: DECOMPOSITION_MAX_TOKENS,
    });
  } catch (err) {
    if (isTransient(err)) throw err;
    return buildFailedResult(
      baseContext,
      'llm-error',
      skillName,
      errMsg(err),
      promptMeta
    );
  }

  if (!response.content || !response.content.trim()) {
    return buildFailedResult(
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
    const decomposition = normalizeDecomposition(firstAttempt.value, analysis);
    return buildOkResult(
      baseContext,
      skillName,
      promptMeta,
      'ok',
      /* retryCount */ 0,
      tokensOf(response),
      decomposition
    );
  }

  // ---- 5. Retry once with validation feedback ---------------------------

  const retryableReasons: DecompositionFailureReason[] = [
    'validation-failed',
    'json-parse-error',
  ];
  if (!retryableReasons.includes(firstAttempt.reason)) {
    return buildFailedResult(
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
      maxTokens: DECOMPOSITION_MAX_TOKENS,
    });
  } catch (err) {
    if (isTransient(err)) throw err;
    return buildFailedResult(
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
    return buildFailedResult(
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
    const decomposition = normalizeDecomposition(secondAttempt.value, analysis);
    return buildOkResult(
      baseContext,
      skillName,
      promptMeta,
      'retry-ok',
      /* retryCount */ 1,
      addTokens(tokensOf(response), tokensOf(retryResponse)),
      decomposition
    );
  }

  return buildFailedResult(
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
 * Feature flag reader for `SKILL_ENGINE_STAGE3`. Defaults to ON.
 * Any of "false" / "0" / "off" (case-insensitive) disables the Stage-3
 * skill path and forces the legacy `decomposeConcepts()` heuristic.
 *
 * Mirrors `isSkillEngineStage4Enabled()` so operators can toggle
 * stages independently during rollout.
 */
export function isSkillEngineStage3Enabled(): boolean {
  const raw = (process.env.SKILL_ENGINE_STAGE3 ?? 'true').trim().toLowerCase();
  return raw !== 'false' && raw !== '0' && raw !== 'off' && raw !== '';
}

// ---------------------------------------------------------------------------
// Internals — parse + validate
// ---------------------------------------------------------------------------

type ValidationOutcome =
  | { ok: true; value: unknown }
  | { ok: false; reason: DecompositionFailureReason; error: string };

function tryParseAndValidate(raw: string, skill: Skill): ValidationOutcome {
  const schema = skill.outputSchema;

  // curriculum-architect always ships a schema. Kept defensive for
  // future Stage-3 variants that might not.
  if (!schema) {
    return { ok: true, value: raw };
  }

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

function prettyZodError(err: ZodError): string {
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
    'concept_decomposition'
  );
}

function pickModel(skillName: string): string {
  return DECOMPOSITION_SKILL_TO_MODEL[skillName] ?? DEFAULT_MODEL;
}

function tokensOf(response: LLMResponse): DecompositionTrace['tokens'] {
  const u = response.usage;
  if (!u) return undefined;
  return {
    prompt: u.promptTokens ?? 0,
    completion: u.completionTokens ?? 0,
    total: u.totalTokens ?? 0,
  };
}

function addTokens(
  a: DecompositionTrace['tokens'],
  b: DecompositionTrace['tokens']
): DecompositionTrace['tokens'] {
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
// Internals — result builders
// ---------------------------------------------------------------------------

function buildOkResult(
  baseContext: ChildContext,
  skillName: string,
  promptMeta: SkillPromptMeta,
  validatorStatus: 'ok' | 'retry-ok',
  retryCount: number,
  tokens: DecompositionTrace['tokens'],
  decomposition: ConceptDecomposition
): DecompositionRouteResult {
  return {
    kind: 'ok',
    decomposition,
    trace: {
      skillName,
      promptMeta,
      validatorStatus,
      retryCount,
      tokens,
      atomCount: decomposition.atoms.length,
      modality: baseContext.teachingStrategy.modality,
      effectiveAgeYears: baseContext.effectiveAgeYears,
      progressionDelta: baseContext.progressionDelta,
      ageProfileUsed:
        promptMeta.ageProfileUsed != null
          ? String(promptMeta.ageProfileUsed)
          : 'unknown',
      difficultyUsed: promptMeta.difficultyUsed ?? 'unknown',
    },
  };
}

function buildFailedResult(
  baseContext: ChildContext,
  reason: DecompositionFailureReason,
  skillName: string,
  error?: string,
  promptMeta: SkillPromptMeta | null = null,
  tokens?: DecompositionTrace['tokens'],
  retryCount = 0,
  validatorStatus: DecompositionTrace['validatorStatus'] = 'skipped'
): DecompositionRouteResult {
  return {
    kind: 'failed',
    reason,
    trace: {
      skillName,
      promptMeta,
      validatorStatus,
      retryCount,
      tokens,
      error,
      failureReason: reason,
      atomCount: 0,
      modality: baseContext.teachingStrategy.modality,
      effectiveAgeYears: baseContext.effectiveAgeYears,
      progressionDelta: baseContext.progressionDelta,
      ageProfileUsed:
        promptMeta?.ageProfileUsed != null
          ? String(promptMeta.ageProfileUsed)
          : 'unknown',
      difficultyUsed: promptMeta?.difficultyUsed ?? 'unknown',
    },
  };
}
