# Design Spike — S10-06 / S10-07: Skill Loader + First Two Skills

**Spike owner:** claude (orchestrator) · **Date:** 2026-04-17 · **Status:** ✅ APPROVED by bang (2026-04-17)

## Decisions locked

1. **Templating engine:** Handlebars.js.
2. **Age profile resolution:** sliding-scale progression detection — see the *Sliding-scale effective age* section below. Child's chronological age picks a base profile; a computed `progressionDelta ∈ [-1.5, +1.5]` derived from mastery / quiz win rate / engagement signals / parent difficulty offset slides the effective age up or down; the delta is rendered into the prompt as a natural-language modifier so the LLM adapts at generation time.
3. **Output schema validation:** per-skill Zod.
4. **Loader:** eager at boot (validate every manifest + load every MD file up-front).
5. **Model routing:** manifest `modelHint` is advisory, `costRouter` has final authority (cold-start overrides, cost caps, etc.).
6. **`interestTopics` source:** extract from `ParentGuidance.parentGoals` free-text via a tiny LLM step at guidance-save time, cache in a new `extractedTopics` field, never re-run on read.

---

## Goal

Settle the shape of the *Skill Engine* before we start coding S10-06 (`story-writer`) and S10-07 (`quiz-maker`), so that both skills drop into the same loader and share one prompt-assembly contract. S10-08..S10-10 will reuse whatever we pick here; S10-12 is the integration point into the Grand Architect pipeline.

Out of scope for this spike: persisting skill output to DB (happens in S10-12), versioning / evaluation tooling (S11 material).

## Why a spike instead of jumping in

The Sprint 10 brief for each skill calls out age profiles, difficulty curves, and engagement-driven adaptation. If S10-06 and S10-07 are built independently they will diverge on:

1. Directory layout — where does `prompt.md` live relative to `age-profiles/`?
2. Context contract — what exactly does a skill consume, and who assembles it?
3. Prompt-assembly pipeline — does the registry produce a system prompt, a pair `(system, user)`, or a `ChatMessage[]`?
4. Extensibility surface — how do S10-08 (experiment designer), S10-09 (curriculum architect), S10-10 (voice persona) slot in without reopening the loader?

Decide once, ship five times.

---

## Directory convention

```
src/Backend/src/services/skills/
├── teachingStrategy.ts           // pure — already landed (S10-11)
├── index.ts                      // SkillRegistry barrel
├── registry.ts                   // loader + invoke
├── types.ts                      // shared ChildContext, SkillInvocation, etc.
├── loader.ts                     // fs-based MD loader (+ in-memory cache)
└── defs/
    ├── story-writer/
    │   ├── manifest.json          // name, version, inputs, modelHint, tempHint
    │   ├── prompt.md              // BASE system prompt (handlebars-lite)
    │   ├── topics.md              // canonical interest-topic vocabulary bank
    │   ├── styles.md              // narrative-voice examples (3 tones)
    │   └── age-profiles/
    │       ├── 4.md               // vocab + sentence-length + cognition for age 4
    │       ├── 6.md
    │       └── 8.md
    ├── quiz-maker/
    │   ├── manifest.json
    │   ├── prompt.md
    │   ├── distractors.md         // common-misconception pools by concept domain
    │   ├── styles.md              // option-writing style (no "all of the above" etc.)
    │   └── difficulty-curves/
    │       ├── easy.md            // 2–3 options, obvious distractors
    │       ├── medium.md          // 4 options, one "trap" distractor
    │       └── hard.md            // 5 options, layered distractors
    ├── experiment-designer/        // S10-08 follow-on
    ├── curriculum-architect/       // S10-09
    └── voice-persona/              // S10-10
```

### Why Markdown (not pure TypeScript templates)

- Prompt tweaks become *content edits*, not code changes — CMS-y.
- Easy diff/review for non-engineers (bang can tune voice without pulling a branch).
- Still typed at the boundary via the `manifest.json` inputs schema.

### Why `manifest.json` instead of front-matter

Keeps machine metadata strictly separated from LLM-facing content. Loader validates the manifest against a Zod schema at boot. Front-matter would create ambiguity over whether keys leak into the prompt.

### Manifest shape (Zod)

```ts
export const SkillManifest = z.object({
  name: z.string(),                      // 'story-writer'
  version: z.string(),                   // '0.1.0'
  description: z.string(),
  modelHint: z.enum(['flash', 'pro']),   // used by costRouter — flash for story, pro for quiz
  temperatureHint: z.number().min(0).max(1),
  inputs: z.object({
    requires: z.array(z.string()),       // ['topic', 'ageYears']
    optional: z.array(z.string()).default([]),
  }),
  ageProfiles: z.array(z.number().int()).optional(), // [4,6,8]
  difficulties: z.array(z.enum(['easy','medium','hard'])).optional(),
  // Which ConceptType values this skill claims to handle. Used by S10-12
  // router so we don't invoke story-writer on a factual lookup.
  handlesConceptTypes: z.array(z.enum([
    'vocabulary','abstract','process','comparison','causeEffect','factual'
  ])).default([]),
});
```

---

## `ChildContext` — the single input parameter

Every skill gets the same context object. Fields new skills don't need they simply ignore.

```ts
export interface ChildContext {
  childId: string;
  ageYears: number;                     // chronological age — computed upstream from birthDate
  effectiveAgeYears: number;            // ageYears + progressionDelta, used for profile selection
  progressionDelta: number;             // -1.5..+1.5, signed slide from chronological age (see Sliding-scale section)
  parentGuidance: ParentGuidanceView;   // S10-04 output
  sessionContext: SessionContext;       // S10-05 output
  engagement?: RankedCardType[];        // S10-03 — optional for cold-start
  mastery?: MasteryEffective;           // S10-02 — optional
  interestTopics?: string[];            // extracted from ParentGuidance.parentGoals via LLM (see decision #6)
  teachingStrategy: {
    conceptType: ConceptType;           // upstream classifier provides this
    modality: LearningModality;         // inferModality(engagement) unless overridden
    rankedCardTypes: RankedCardTypeRec[]; // from rankCardTypesFor(...)
  };
  difficultyOffset?: number;            // -2..+2, parent-driven
}
```

### Building `ChildContext`

S10-12 (the pipeline integrator) will own a `buildChildContext(childId, conceptType, difficultyOffset)` helper that assembles all of the above in **one DB read pass** — just like `getSessionContext` does today. Skills NEVER touch Prisma directly. This keeps the skills pure and testable.

---

## `SkillRegistry` — the loader

```ts
// src/services/skills/registry.ts
export interface Skill {
  manifest: SkillManifest;
  // Pure: takes ChildContext + skill-specific inputs → returns a ready
  // system prompt + user prompt. Does NOT call the LLM.
  buildPrompt(input: {
    ctx: ChildContext;
    inputs: Record<string, unknown>;  // validated upstream against manifest.inputs
  }): { system: string; user: string; meta: SkillPromptMeta };
}

export interface SkillPromptMeta {
  skillName: string;
  version: string;
  ageProfileUsed?: number;          // which age-profiles/*.md snippet was merged in
  difficultyUsed?: 'easy'|'medium'|'hard';
  modelHint: 'flash'|'pro';
  temperatureHint: number;
}

export interface SkillRegistry {
  load(): Promise<void>;            // loads + validates every defs/*/manifest.json at boot
  list(): Skill[];
  get(name: string): Skill;         // throws if missing — no fallbacks
  reload(name?: string): Promise<void>; // dev-console hot-reload hook
}
```

### Prompt assembly pipeline (per invocation)

1. `registry.get('story-writer')` → `Skill`
2. Validate `inputs` against `manifest.inputs`
3. Load `prompt.md` (already cached)
4. Select nearest `age-profiles/<n>.md` **by `ctx.effectiveAgeYears`** (nearest-≤), not by raw chronological age — see *Sliding-scale effective age* below
5. Select `difficulty-curves/<level>.md` by `ctx.difficultyOffset`
6. Render the `{{> progressionModifier}}` partial from `ctx.progressionDelta` — inserts a short natural-language nudge so the LLM adapts *within* the chosen profile (see *Sliding-scale effective age*)
7. Render Handlebars with the full `ctx` → yield `{system, user, meta}`

Handlebars.js (real library) is used, not a home-grown interpolator. Triple-stache (`{{{...}}}`) is disabled at registry init so raw HTML can never leak into a prompt.

---

## `prompt.md` template shape

Every skill's `prompt.md` starts with a standard preamble block so the Grand Architect pipeline reads identically from call site to call site:

```md
<!-- system-role -->
You are Nova — the AI teaching assistant for a child aged {{ctx.ageYears}}.

<!-- parent-guidance -->
{{preamble.parentGuidance}}

<!-- session-context -->
{{preamble.sessionContext}}

<!-- age-profile (base, selected by ctx.effectiveAgeYears) -->
{{> ageProfile}}

<!-- progression modifier — slides the LLM within or beyond the base profile -->
{{> progressionModifier}}

<!-- skill-specific instructions below -->
```

The `{{> ageProfile}}` partial resolves to the matching `age-profiles/<n>.md` using `ctx.effectiveAgeYears`. The `{{> progressionModifier}}` partial renders a short natural-language nudge derived from `ctx.progressionDelta` (see *Sliding-scale effective age*). The `difficulty-curves` partial works the same way. The `preamble.parentGuidance` and `preamble.sessionContext` fields come pre-rendered from `promptTemplates.ts` (S10-04 / S10-05), so we don't re-walk that logic.

---

## S10-06 — `story-writer` sketch

### Inputs

```ts
{
  topic: string;              // 'gravity', 'photosynthesis', 'the moon'
  targetLessonId?: string;    // optional — tie the story to a lesson
}
```

### `prompt.md` (abbreviated)

```md
<!-- system-role -->
You are Nova — writing a short, memorable story for a child aged {{ctx.ageYears}}.

<!-- parent-guidance -->
{{preamble.parentGuidance}}

<!-- session-context -->
{{preamble.sessionContext}}

<!-- age-profile -->
{{> ageProfile}}

<!-- style -->
{{> styleExamples}}

<!-- topics bank -->
Child's known interests: {{#each ctx.interestTopics}}{{.}}{{#unless @last}}, {{/unless}}{{/each}}
Weave ONE interest into the story if it fits the science; do not force it.

<!-- task -->
Write a 4–6 paragraph story that teaches "{{inputs.topic}}" through a concrete narrative.

Constraints:
- Sentence length: {{ageProfile.maxSentenceWords}} words max
- Vocabulary ceiling: {{ageProfile.vocabCeiling}}
- One new word introduced per paragraph, defined inline.
- End with a single-sentence "wonder question" — no answer, just provoke curiosity.
- Output MUST be JSON: {"title": string, "paragraphs": string[], "wonderQuestion": string, "newWords": Array<{word:string, definition:string}>}
```

### `age-profiles/4.md`

```md
<!-- age 4 profile -->
- ageProfile.maxSentenceWords: 8
- ageProfile.vocabCeiling: CEFR A1 / Dolch Pre-K sight words
- Tone: playful, warm, repetitive. Name at most 2 characters.
- Avoid: subordinate clauses, metaphors that aren't immediately concrete.
- Prefer: direct sensory verbs (jumps, shines, tastes), simple present tense.
```

### `age-profiles/6.md`

```md
<!-- age 6 profile -->
- ageProfile.maxSentenceWords: 14
- ageProfile.vocabCeiling: CEFR A1+ / first-grade reading level
- Tone: curious. Use one mild metaphor per paragraph.
- May introduce past tense and simple compound sentences.
- Dialogue is fine (2–3 exchanges max).
```

### `age-profiles/8.md`

```md
<!-- age 8 profile -->
- ageProfile.maxSentenceWords: 20
- ageProfile.vocabCeiling: CEFR A2 / third-grade reading level
- Tone: adventurous. Metaphors allowed freely, but each must unpack itself.
- Introduce mild cause-and-effect chains ("because … so …").
- May use one domain-specific technical word per paragraph if defined.
```

### `topics.md`

```md
<!-- topics bank (canonical) -->
A curated list of child-safe topic anchors by domain. Used when the child
has no interestTopics set (cold-start). Ordered by universality.

- animals: cats, dogs, dinosaurs, dolphins, bees
- space: moon, sun, stars, rockets
- everyday: kitchen, bathtub, playground, garden, snow
- machines: cars, trains, robots, computers
- people: family, doctors, artists, inventors
```

### `styles.md` — three voice examples

```md
### Warm (default for age 4)
> "Little Mo the moth loved the porch light. Every night she danced
> around it, dizzy and happy…"

### Curious (default for age 6)
> "Why does ice melt when you hold it? Mae wondered this every summer.
> Her hand was warm. The ice was cold. Something had to give…"

### Adventurous (default for age 8)
> "The rocket wasn't moving yet, but deep inside the fuel tanks the
> liquid was already quietly fighting with the engines…"
```

### Expected output shape (validated downstream)

```ts
interface StoryWriterOutput {
  title: string;
  paragraphs: string[];                  // 4–6 entries
  wonderQuestion: string;
  newWords: Array<{ word: string; definition: string }>;
}
```

---

## S10-07 — `quiz-maker` sketch

### Inputs

```ts
{
  concept: string;              // 'the moon orbits the earth'
  conceptType: ConceptType;     // from classifier; drives distractor strategy
}
```

### `prompt.md` (abbreviated)

```md
<!-- system-role -->
You are Nova — writing a check-for-understanding quiz for a child aged {{ctx.ageYears}}.

<!-- parent-guidance -->
{{preamble.parentGuidance}}

<!-- age-profile -->
{{> ageProfile}}

<!-- difficulty -->
{{> difficultyCurve}}

<!-- style -->
{{> styleExamples}}

<!-- distractors -->
{{> distractors}}
Use the distractor bank above to select plausible wrong answers.
NEVER write "all of the above", "none of the above", or joke answers.

<!-- task -->
Write a single multiple-choice question about: "{{inputs.concept}}".

Produce exactly {{difficultyCurve.optionCount}} options.
ONE is correct. The rest are plausible misconceptions a child aged
{{ctx.ageYears}} might genuinely hold.

Output JSON: {"question": string, "options": string[], "correctIndex": number, "explanation": string, "rationalePerOption": string[]}
```

### `difficulty-curves/easy.md`

```md
- difficultyCurve.optionCount: 3
- difficultyCurve.distractorStyle: obvious — one clearly wrong, one thematic
- Explanation should be ≤ 15 words
```

### `difficulty-curves/medium.md`

```md
- difficultyCurve.optionCount: 4
- difficultyCurve.distractorStyle: one "trap" misconception + two thematic
- Explanation should be ≤ 25 words and name WHY the trap fails
```

### `difficulty-curves/hard.md`

```md
- difficultyCurve.optionCount: 5
- difficultyCurve.distractorStyle: layered — two traps, two thematic
- Explanation should be ≤ 40 words and discriminate between EVERY option
```

### `distractors.md` — common-misconception seeds

```md
- gravity: "heavier things fall faster", "gravity only exists on earth"
- moon phases: "the earth's shadow causes phases", "the moon disappears on new moon"
- addition: off-by-one, confusion with subtraction, reversed operands
- computers: "the internet is in the box", "bigger computer = smarter"
(expand as we add topics)
```

### Expected output shape

```ts
interface QuizMakerOutput {
  question: string;
  options: string[];                    // length 3 / 4 / 5 by difficulty
  correctIndex: number;
  explanation: string;
  rationalePerOption: string[];         // same length as options, used for adaptive feedback
}
```

---

## Integration with Grand Architect pipeline (S10-12 preview)

The current pipeline (`pipelineOrchestrator.ts`) calls hardcoded prompts from `promptTemplates.ts`. S10-12 will replace that with:

```ts
const ctx = await buildChildContext(childId, conceptType, difficultyOffset);
const ranked = rankCardTypesFor(conceptType, ctx.teachingStrategy.modality, {
  engagement: ctx.engagement,
  difficultyOffset,
  ageYears: ctx.ageYears,
});

for (const { cardType } of ranked) {
  const skillName = CARD_TYPE_TO_SKILL[cardType]; // story→story-writer, quiz→quiz-maker, etc.
  const skill = registry.get(skillName);
  const { system, user, meta } = skill.buildPrompt({ ctx, inputs });
  const result = await llm.call({ system, user, ...meta });
  // validate, persist, break-on-success-per-concept
}
```

Key property: the ranked list means if `story-writer` fails quality gate, the orchestrator tries the next card type (e.g. `concept`) without human intervention. Matches the "pipeline never dies on failure" discipline from S9.

---

## Dev Console integration

### `/dev/skills` (new, not in this spike but sketched)

- `GET /dev/skills` → list manifests (so the UI can show version, model, temp)
- `GET /dev/skills/:name/render?childId&inputs=…` → returns `{system, user, meta}` *without* calling the LLM. This is the dry-run endpoint — lets bang inspect what the model will actually see.
- `POST /dev/skills/:name/reload` → hot-reload a skill's markdown (dev only).

The dry-run endpoint is deliberately cheap to add and pays for itself every time a prompt goes sideways. File under "worth the 2 hours" during S10-12.

---

## Decisions & rationale

1. **Handlebars.js.** Battle-tested, small (~35KB gzipped), removes the prompt-injection risk inherent in a DIY parser, supports partials out of the box — we need partials for age-profile / difficulty-curve / style injection. Triple-stache (`{{{...}}}`) disabled at registry level so raw HTML can never leak into a prompt.

2. **Sliding-scale effective age.** See dedicated section below. Motivation: a chronological-5 child who is demonstrably outperforming the age-5 profile should not keep getting age-5 vocabulary; conversely, a chronological-7 child who is struggling should slide back toward age-6. Static `nearest-≤` mapping can't express this.

3. **Per-skill Zod output validator.** Each skill's output is structurally different (`StoryWriterOutput` vs `QuizMakerOutput` vs future `ExperimentConfig`). A shared validator would either (a) collapse to `z.unknown()` and lose the guarantee, or (b) grow a union that invalidates each time a skill changes shape. Per-skill keeps the validator next to the skill that defines the shape, and the registry stays generic.

4. **Boot-time loader.** Corpus is ~20 files across 5 skills. Cost of eager load is ~50ms on boot. Benefit: manifest typos, missing MD partials, malformed Handlebars — all surface at startup, not the first time a child opens a lesson. Lazy load would also complicate hot-reload, which we want in dev.

5. **Manifest hint advisory, costRouter decides.** `manifest.modelHint = 'pro'` tells costRouter "this skill is latency- or quality-sensitive, prefer Pro if the budget allows." But: (a) cold-start users get Flash regardless — no value in burning Pro tokens on a child who hasn't been profiled yet; (b) daily / monthly cost caps override; (c) planned future cost-routing signals (A/B tests, model rollout, fallback on upstream 5xx) all live in costRouter, not in a static manifest. Manifest stays the declaration of *intent*; costRouter enforces *reality*.

6. **LLM-extracted `interestTopics` at guidance-save time.** Parents write `parentGoals` as free-text ("I want her to learn more about how computers work and keep doing dinosaurs, but she's scared of spiders so maybe stay away from bugs"). Option A extracts `{focus: ['computers', 'dinosaurs'], avoid: ['spiders', 'bugs']}` from that single field via a tiny Flash call, caches the result as `ParentGuidance.extractedTopics (Json?)`, and never re-runs on read. Benefits: (a) parents don't have to learn a tagging taxonomy, (b) we get structured topics without a second input field, (c) same extraction pipeline can later pull goals + boundaries + difficulty hints if we want. Implementation notes: fire-and-forget from `PUT /children/:id/guidance` (200 returns immediately; extraction happens in a `setImmediate` callback and writes back when done), rate-limited to once per guidance-save per child, cost gated by costRouter at Flash tier, extraction prompt locked to a strict JSON schema with retry-on-parse-fail.

---

## Sliding-scale effective age

### Motivation

A chronological-5 child who is demonstrably outperforming the age-5 profile should not keep getting age-5 vocabulary. Conversely, a chronological-7 who is struggling should slide back toward age-6. Static `nearest-≤` mapping can't express this. But building per-year profiles (5, 6, 7, 8, 9, 10) doubles the content surface and forces us to invent age-7 content that sits awkwardly between 6 and 8. The answer: **keep three anchor profiles (4 / 6 / 8) as landmarks, and slide the LLM between them at generation time** using a computed `progressionDelta`.

### The `progressionDelta` signal

`progressionDelta ∈ [-1.5, +1.5]` — a signed scalar that shifts the child's *effective age* relative to their chronological age. Composed additively from four sources, then clamped:

| Signal | Source | Condition | Delta contribution |
|--------|--------|-----------|-------------------:|
| Mastery pace | `MasteryEffective` (S10-02) | `masteryAvg > 0.7 && attempts >= 10` over last 30d | **+0.5** |
| Quiz win rate | `EngagementSummary` (S10-03) | `recentQuizWinRate > 0.8` over last 14d | **+0.3** |
| Flow events | session events last 7d | count of `flow` events | **+0.3** (capped) |
| Frustration events | session events last 7d | count of `frustration` / `abandon` events ≥ 2 | **-0.5** |
| Low mastery pace | `MasteryEffective` | `masteryAvg < 0.4 && attempts >= 10` | **-0.3** |
| Parent difficulty offset | `ParentGuidance.difficultyOffset` | any non-zero | **`offset × 0.4`** (so `±2` offset = `±0.8`) |

Final value is clamped to `[-1.5, +1.5]`. Ordering is cosmetic — the sum is commutative.

The **chronological age** is still used for legal/ethical guards (age gates in content filters, parent-mode switches). The **effective age** is used only for pedagogical profile selection.

```ts
export function computeProgressionDelta(ctx: {
  mastery?: MasteryEffective;
  engagement?: EngagementSummary;
  recentSessionEvents?: SessionEventCounts;
  parentDifficultyOffset?: number;
}): number {
  let delta = 0;

  if (ctx.mastery) {
    if (ctx.mastery.averageScore > 0.7 && ctx.mastery.totalAttempts >= 10) delta += 0.5;
    else if (ctx.mastery.averageScore < 0.4 && ctx.mastery.totalAttempts >= 10) delta -= 0.3;
  }

  if (ctx.engagement && ctx.engagement.recentQuizWinRate > 0.8) delta += 0.3;

  if (ctx.recentSessionEvents) {
    const flow = Math.min(ctx.recentSessionEvents.flow ?? 0, 3);   // cap contribution
    if (flow > 0) delta += 0.1 * flow;                             // up to +0.3
    if ((ctx.recentSessionEvents.frustration ?? 0) >= 2) delta -= 0.5;
  }

  if (typeof ctx.parentDifficultyOffset === 'number') {
    delta += ctx.parentDifficultyOffset * 0.4;
  }

  return Math.max(-1.5, Math.min(1.5, delta));
}

export function computeEffectiveAge(ageYears: number, delta: number): number {
  // Keep effective age physically plausible — never below 3, never above 14 (our supported range).
  return Math.max(3, Math.min(14, ageYears + delta));
}
```

This is pure, trivially unit-testable, and lives next to `teachingStrategy.ts` as `src/services/skills/progression.ts`. No DB access — it consumes the same already-assembled memory views that S10-12's `buildChildContext` passes around.

### Why three profiles, not six

Keeping three anchors (4 / 6 / 8) is deliberate:

1. **Content cost.** Every profile is a hand-tuned MD file. Six profiles ⇒ six tuning targets. Three ⇒ landmarks.
2. **LLM interpolation is free.** GPT-4-class models interpolate naturally between "age-6 vocab ceiling A1+" and "age-8 vocab ceiling A2" given both in context. We don't need to hand-author age-7.
3. **`progressionDelta` carries the signed nuance.** A child at chronological 7 with delta `+0.3` gets: base profile = 8 (`nearest-≤` of effective 7.3 is 6, but we round-to-nearest, so 7.3 picks 8 — see resolution rule below) with "standard" modifier. A child at chronological 5 with delta `+0.8` gets: base profile 6 (effective 5.8) with "above-profile mastery" modifier. The LLM does the rest.

### Profile selection rule

Given anchors `[4, 6, 8]` and `effectiveAge`:

```ts
function selectAgeProfile(anchors: number[], effectiveAge: number): number {
  // Clamp to anchor range first.
  const clamped = Math.max(anchors[0], Math.min(anchors[anchors.length - 1], effectiveAge));
  // Nearest anchor (ties round down — err toward simpler).
  let best = anchors[0];
  let bestDist = Infinity;
  for (const a of anchors) {
    const d = Math.abs(a - clamped);
    if (d < bestDist || (d === bestDist && a < best)) { best = a; bestDist = d; }
  }
  return best;
}
```

This is intentionally different from the `nearest-≤` that was originally floated — nearest-≤ on effective age 5.9 picks age 4 (too simple). Nearest-with-ties-round-down on the same picks age 6, then the modifier partial softens it. The modifier partial is the thing that says "this child is 5.9 not 6, still scaffold vocabulary carefully."

### The `progressionModifier` partial

Rendered at prompt-build time into a 1–2 sentence nudge. The partial lives at `src/services/skills/defs/_shared/progressionModifier.hbs` and is registered globally on the Handlebars instance so every skill inherits it:

```hbs
{{#if (gt ctx.progressionDelta 0.5)}}
**Progression note:** this child is demonstrating above-profile mastery
(chronological age {{ctx.ageYears}}, effective age {{ctx.effectiveAgeYears}}).
Freely use vocabulary from one profile tier up; introduce slightly longer
sentences; allow one domain-technical term if you define it inline.
{{else if (lt ctx.progressionDelta -0.5)}}
**Progression note:** this child is showing signs of struggle recently
(chronological age {{ctx.ageYears}}, effective age {{ctx.effectiveAgeYears}}).
Err toward the previous profile's simplicity — shorter sentences, more
concrete verbs, repeat key terms, avoid metaphors.
{{else}}
**Progression note:** standard pace — follow the age profile as written.
{{/if}}
```

The `gt` / `lt` helpers are registered in `registry.ts` at Handlebars init. Strings are tuned so the LLM has enough to adapt but not so verbose that they dominate the prompt. Worst-case overhead: ~60 tokens; typical: ~40.

### Where it plugs in

- `types.ts` — `ChildContext` gains `progressionDelta: number` and `effectiveAgeYears: number`.
- `progression.ts` (new) — pure `computeProgressionDelta` + `computeEffectiveAge`, colocated with `teachingStrategy.ts`.
- `buildChildContext` (lives in S10-12) — calls `computeProgressionDelta(ctx)` during assembly, stamps both fields on the returned object.
- `loader.ts` — uses `effectiveAgeYears` for `selectAgeProfile`, injects `progressionModifier` partial globally.
- Dev Console Strategy tab — add a read-only "Progression" row showing `ageYears · effectiveAgeYears (Δ+0.8)` and the signals that drove the delta, so bang can see *why* a child is being sloted above or below their chronological age.
- Dev Console Skills tab (S10-06/07 follow-on) — the dry-run endpoint `/dev/skills/:name/render` echoes `meta.progressionDelta` and `meta.ageProfileUsed` so prompt diffs are inspectable.

### Unit test plan

- `computeProgressionDelta` — each signal in isolation (mastery high / low, quiz win rate high, flow events 0..3, frustration ≥2, parent offset -2..+2), then all-signals-max clamps to +1.5, all-signals-min clamps to -1.5, no-signals returns 0.
- `computeEffectiveAge` — clamps to [3, 14], preserves non-integer deltas, handles negative results.
- `selectAgeProfile` — nearest-with-ties-round-down across anchors [4,6,8], clamps out-of-range.
- End-to-end: `buildPrompt` for a chronological-5 / delta+0.8 child yields the "above-profile" modifier text; chronological-7 / delta-0.6 yields "err toward simplicity"; standard child yields "standard pace".

### Ops knob

Every signal weight is a module constant (`MASTERY_HIGH_BONUS = 0.5`, etc.). If the formula over- or under-shoots in practice, bang tunes constants in one file — no migration needed. When we move to S11 evaluation tooling we can A/B two weight tables against engagement outcomes.

---

## Acceptance criteria for S10-06 and S10-07 (restated)

### S10-06 — story-writer

- [ ] Skill manifest validates via Zod at boot
- [ ] `prompt.md` + 3 age profiles + styles.md + topics.md present
- [ ] `buildPrompt` produces a valid `{system, user, meta}` without touching the DB
- [ ] Ages 4/6/8 produce visibly-different vocabulary ceilings in the rendered prompt (test case)
- [ ] `interestTopics` absence ⇒ prompt mentions "cold start: pick a universal anchor"
- [ ] Output JSON schema validated post-LLM
- [ ] Unit tests: prompt differs per age, per parent content-level, per session time-of-day

### S10-07 — quiz-maker

- [ ] Skill manifest validates via Zod at boot
- [ ] `prompt.md` + 3 difficulty curves + distractors.md + styles.md present
- [ ] Difficulty offset `-2..+2` maps deterministically to easy / medium / hard
- [ ] Option counts match spec: 3 / 4 / 5
- [ ] `distractors.md` consulted when conceptType matches a bank key
- [ ] No "all of the above" / "none of the above" (tested against a property-based generator)
- [ ] Unit tests: rendered prompt varies with difficultyOffset, ageYears, conceptType

---

## Timeline estimate

| Chunk | LOC est. | Effort |
|-------|----------|--------|
| types.ts + manifest Zod | 80 | 1h |
| registry.ts + loader.ts + Handlebars wiring | 250 | 3h |
| story-writer defs (prompt.md, 3 age profiles, styles, topics) | ~200 MD | 2h |
| quiz-maker defs (prompt.md, 3 difficulty curves, distractors, styles) | ~200 MD | 2h |
| /dev/skills endpoints | 120 | 2h |
| Dev Console "Skills" tab (dry-run preview) | 300 | 3h |
| Tests | 400 | 4h |
| Wiring ParentGuidance.topics field (migration) | 60 + SQL | 1h |
| **Total** | | **~18h** (~2.5 days) |

This fits inside the S10-06 (13pts) + S10-07 (13pts) = 26pt allocation with room for the Dev Console Skills tab.

---

## Next actions if bang approves this spike

1. Add `ParentGuidance.topics: string[]` migration (Prisma + SQL).
2. Land `types.ts`, `registry.ts`, `loader.ts` + Handlebars dep.
3. Ship `story-writer` defs + unit tests (close S10-06).
4. Ship `quiz-maker` defs + unit tests (close S10-07).
5. Expose `/dev/skills` endpoints + Dev Console "Skills" tab.
6. S10-08..S10-10 become pure content work — same loader, no new infra.

---

*End of spike.*
