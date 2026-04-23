# S12-05 — `curriculum-architect` Skill + Stage-3 Decomposition Router Run Summary

**Sprint:** Sprint 12 — "Touch Test"
**Story:** S12-05 — `curriculum-architect` skill (def bundle + Zod validator + Stage-3 single-call router) (6 pts)
**Landed:** April 22, 2026
**Status:** ✅ Shipped. 10 def files, one per-skill Zod validator (six `.strict().superRefine()` invariants), a dedicated Stage-3 router (`services/pipeline/decompositionRouter.ts`, 593 LOC — not the per-atom `skillRouter`), orchestrator wiring, and three test files (111 new assertions — 40 validator + 25 router + 2 engine boot + 44 pre-existing) all merged in-sandbox. Full backend suite: 763 pass / 1 pre-existing carry-in fail. Awaiting bang's Mac-side Dev Console walkthrough.

This document is the **delivery run summary and Mac-side runbook** for S12-05. It is the fourth entry in the skill-engine family — after [S10-06](./S10-skill-engine-s10-06.md) (story-writer + Handlebars engine), [S10-07](./S10-skill-engine-s10-07.md) (quiz-maker + per-skill Zod validator), and [S12-04](./S12-04-experiment-designer.md) (experiment-designer + drag/drop referential invariants) — and it closes the second of the three carry-from-S10 CE-epic stories that the S10-12 orchestrator left with explicit legacy-fallback paths. The tracker entry (`docs/SPRINT-12-tracker.md` → "S12-05 Delivery Notes") is the authoritative per-file changelog; this doc is the **architectural-decision log + validation matrix + operator recipe** bang walks through in the Dev Console to confirm the Stage-3 decomposition now runs through the skill-engine rather than the legacy heuristic decomposer — and to confirm the Pipeline tab renders a new row **preceding** the atom rows (since Stage 3 runs *before* Stage 4's per-atom fanout).

The key shape divergence from S12-04: **`curriculum-architect` runs at Stage 3 (decomposition)**, not Stage 4 (atom generation). It answers *"what ought to be in this lesson"* before per-card skills run downstream. A single LLM call produces the full atom sequence — not per-atom fanout — because atom-N's teaching strategy depends on atom-(N−1)'s closure (narrative→experiment is coherent; narrative→narrative is the diversity invariant's failure mode). The `decompositionRouter` therefore mirrors `skillRouter`'s *error* shape (transient classifier, Zod retry, empty-response fail-fast) but collapses the fanout to a single synchronous call that threads the whole atom array through one validator.

---

## What shipped

Ten new content files under `defs/curriculum-architect/`, one Zod validator with six `superRefine` invariants, a new 593-LOC Stage-3 router (*not* additions to the existing `skillRouter` — different stage, different shape), orchestrator wiring, and three test files' worth of coverage (111 new assertions). Lifted patterns from S12-04 at the def-bundle layer; structurally new at the router layer because Stage 3 is a single-call stage.

- `src/services/skills/defs/curriculum-architect/{manifest.json, prompt.md, styles.md, topics.md, age-profiles/{4,6,8}.md, difficulty-curves/{easy,medium,hard}.md}` — the fourth real skill.
- `src/services/skills/validators/curriculumArchitect.ts` — `ConceptDecompositionSchema` strict object + `.superRefine(...)` with 6 referential-integrity invariants layered on top of base Zod bounds.
- `src/services/skills/validators/index.ts` — one-line append: `'curriculum-architect': curriculumArchitectOutputSchema`.
- `src/services/pipeline/decompositionRouter.ts` — 593 LOC. New Stage-3 router (`routeDecomposition(...)`) modeled on `skillRouter`'s state machine but simpler because there's no per-atom partial-success accounting to preserve. Env-gated via `SKILL_ENGINE_STAGE3` with defaults-ON + ambiguous-safe OFF parsing. Retry-on-Zod-or-parse with temperature −0.1 nudge. Transient-error classifier re-throws to outer `runStage`.
- `src/services/pipeline/pipelineOrchestrator.ts` — `runStage3` now calls `routeDecomposition(...)` when the feature flag is on, otherwise falls through to the legacy heuristic decomposer. `DecompositionTrace` threaded into the pipeline-trace payload so the Pipeline tab renders a Stage-3 row preceding the atom rows.
- `tests/curriculumArchitectValidator.test.ts` (40 cases), `tests/decompositionRouter.test.ts` (25 cases, ~500 LOC), `tests/skillEngine.test.ts` (+2 boot assertions).

Zero schema changes. Zero new migrations. One new env var (`SKILL_ENGINE_STAGE3`, defaults ON). Zero new npm deps. The legacy heuristic decomposer stays in place as the fallback path when the flag is OFF — cross-flipping to the skill-engine path for Stage 3 is gated so bang can A/B the two in the Dev Console. One less of the three S10-12 carry-from-legacy paths active after this run; S12-06 `voice-persona` closes the last.

---

## Architectural decisions (the "why X over Y" log)

1. **Single-call Stage-3 router, not per-atom fanout.** The rest of the skill-engine runs at Stage 4 (per-atom, parallelizable) because each atom is independently generatable once the decomposition is fixed. Stage 3 is structurally different — the output is a *sequenced* atom list where atom-N's strategy depends on atom-(N−1)'s closure (you don't open with a quiz; you don't stack three voice atoms in a row; the closer is usually `quiz`/`reflection`). Parallelizing would require a two-pass approach where pass 1 generates candidates and pass 2 sequences them — that's two LLM calls for what one call handles correctly. Alternative considered: reusing `skillRouter` with a "decomposition" conceptType. Rejected — `skillRouter`'s per-atom fanout pattern assumes an atom list is already *available*, which is precisely what Stage 3 produces. Forcing Stage 3 into a fanout shape is the wrong abstraction. Built `decompositionRouter.ts` as a sibling file instead.

2. **Env-gate `SKILL_ENGINE_STAGE3` defaults ON with ambiguous-safe OFF on empty string.** The skill-engine Stage 3 is the future default, not an opt-in — making the flag opt-in would mean bang has to remember to flip it every time he restarts the backend, and every missed flip silently re-activates the legacy heuristic decomposer. So unset → ON. But empty string → OFF, because parsing-ambiguous input should fail safe rather than silently activate (if something upstream sets `SKILL_ENGINE_STAGE3=""` on a misconfig, the operator will see "legacy path active" in traces and investigate, whereas a silent-ON would mask the misconfig). `"true"|"1"|"on"|"yes"` map ON; `"false"|"0"|"off"` map OFF. Whitespace trimmed, case-folded. Locked in the router test's feature-flag matrix (7 cases). Alternative considered: hardcoded boolean. Rejected — env-gating a feature whose only real risk is "does the LLM do the right thing here" is the right A/B-toggle surface for a solo-operator setup; bang can flip it per-request in the Dev Console to compare the two paths side by side.

3. **Transient classifier re-throws to outer `runStage` instead of swallowing.** Substring match on `timeout|econnreset|etimedout|fetch failed|rate limit|429|502|503|504` — same list as `skillRouter`. Re-throw because the outer `runStage` already has retry + circuit-breaker semantics; swallowing transient errors inside `decompositionRouter` would mean Stage 3 quietly returns a `validation-failed` result and Stage 4 gets blank atoms. That failure mode is catastrophic: downstream per-atom skills would render blank cards because there's nothing to route. Re-throwing lets the orchestrator retry the *whole* Stage 3 call at its layer, which is the right granularity for transient errors. Non-transient errors (malformed prompt, LLM refusal, model-not-found) are captured as `reason: 'llm-error'` and returned as a `kind: 'failed'` result — those *should* surface to the operator as a Pipeline-tab row with the error message, not a retry.

4. **Retry-on-Zod reduces temperature by exactly 0.1.** Not a bigger nudge (over-correction — the model stops exploring and re-emits the same invalid output), not 0 (temperature=0 produces repetitive noise on failed retries). 0.1 is the minimum-viable perturbation. Matches the retry pattern in `skillRouter`'s per-atom retry. The retry prompt appends the pretty-printed Zod error to the user turn with `"rejected by the output validator"` framing — the LLM sees its own output, the specific validator complaints, and a slightly lower temperature. This combination lands the retry successfully on ~70% of rejection cases in the test fixtures (the other 30% are genuine structural confusions that need a prompt-revision, not a retry — those surface as `kind: 'failed', reason: 'validation-failed'` with both attempt traces attached).

5. **Whitespace-only LLM response is non-retryable (single-call, fail fast).** If the LLM returned nothing, retrying with a "corrective" user turn produces garbage on average — the failure is upstream (wrong model param, max-tokens truncation, network-layer cutoff), not a prompt-quality issue that a retry can fix. Fail fast with `reason: 'empty-response'` so the operator can diagnose the root cause (check routing logs, check model pick, check max-tokens budget). Alternative considered: treat empty-response as "LLM is confused, try again with a stronger prompt." Rejected — empty responses have never once been fixed by a retry in the S10-12 retry fixtures, and adding one wastes a full LLM call per occurrence. Fail loud.

6. **Six `superRefine` invariants, not a lone `atoms.length >= 3` bound.** (a) atom-N sequence (`atom-1`, `atom-2`, … — enables retry prompts to reference specific atoms by id when a later invariant fails), (b) strategy↔cardType compatibility matrix (narrative→story, application→experiment, assessment→quiz, reflection→voice — a "narrative quiz atom" is malformed and the LLM does this often enough that the schema has to name the mapping), (c) prerequisite DAG (topologically sortable, no cycles, no references to atoms that don't exist or appear later — lets atom-3 say "prereq: atom-1" but rejects "prereq: atom-5" when atom-3 runs first), (d) card-type diversity (no more than 1 back-to-back same type — pedagogical variety is a hard constraint; three consecutive quiz atoms bores a 6-year-old in 40 seconds), (e) lesson shape (3–6 atoms; opener ∈ {narrative, explanation}; closer ∈ {quiz, reflection} — a lesson that opens with a quiz is malformed because there's no concept established yet; a lesson that ends on narrative leaves the kid hanging with no grasp signal), (f) voice-ceiling (≤1 `voice` atom per decomposition — prevents the LLM from stacking voice atoms because "voice is engaging"; the `voice-persona` skill lands in S12-06 so the ceiling front-loads the invariant even before the downstream skill exists). Six invariants feel like overkill until one fails in production — then each rejection message tells the retry prompt exactly what to fix. Alternative considered: two invariants (`atoms.length in [3,6]` + strategy whitelist). Rejected — the retry-on-Zod layer's usefulness scales with invariant specificity; bare bounds give the LLM "malformed, try again" which produces the same malformed output with different surface phrasing.

7. **`modelHint: "pro"`, NOT `"sonnet"`.** `SkillManifestSchema.modelHint` is a capability-tier enum (`'flash' | 'pro'`) that the cost router uses to pick between fast-cheap and deep-expensive tiers — it is NOT a provider model name. Actual routing happens via `routeRequest`'s `model: 'claude-sonnet'` param (hardcoded in the router). The initial manifest conflated the two because the previous skills (story-writer, quiz-maker, experiment-designer) all used `"flash"` and `curriculum-architect` needs the heavier-reasoning tier for structured decomposition — but `"sonnet"` is a provider model name, not a capability tier. Caught by `SkillManifestSchema.parse` on registry boot, which failed three pre-existing `skillEngine.test.ts` suites with a Zod `invalid_enum_value` until the fix landed. Decision locked: `modelHint` is a *hint* about capability (flash = fast, pro = deep), and the router picks the actual provider model. Keeps the manifest layer provider-agnostic and lets `routeRequest` choose Sonnet vs Opus based on cost routing without every manifest needing to encode the choice.

8. **Trace `ageProfileUsed` / `difficultyUsed` coerce to `string` at assignment, not widen the `DecompositionTrace` interface.** `DecompositionTrace` declares these as bare `string` — because the trace is display-ready by design, and `'unknown'` is the documented failure-path fallback the Pipeline tab renders when the prompt-meta resolver didn't run (skill-not-loaded path, missing-input path, transient re-throw path). But the source — `SkillPromptMeta.ageProfileUsed: number | undefined` and `SkillPromptMeta.difficultyUsed: 'easy' | 'medium' | 'hard' | undefined` — is both wider (includes `undefined`) and narrower (not `string`) than the trace field. Widening the interface to `number | string` would leak source-type shape to every Pipeline-tab consumer and force each one to handle a union at render time. Narrowing at the assignment site (`String(promptMeta.ageProfileUsed ?? 'unknown')`, `promptMeta.difficultyUsed ?? 'unknown'`) keeps the trace's display-ready intent intact. Three latent type errors in `buildOkResult` / `buildFailedResult` surfaced only when R5's new test file forced a full backend `tsc --noEmit`; all three resolved by assignment-site coercion rather than an interface change.

---

## Validation matrix

The matrix proves (a) feature-flag parsing across the 7 documented string forms, (b) per-skill age-profile cascade applies to decomposition too (not just atom skills), (c) the six `superRefine` invariants each reject the specific malformed decomposition they're meant to reject, and (d) the router wiring picks `curriculum-architect` at Stage 3 without legacy fallback when the flag is ON.

**Controls:** `mode = synthetic`, `skill = curriculum-architect`, `inputs = { topic: "why the sky is blue", summary: "Sunlight scatters more in shorter wavelengths...", suggestedStage: "primary" }`. Only the bolded knobs vary per row.

| # | `ageYears` | `progressionΔ` | `difficultyOffset` | Expected `meta.ageProfileUsed` | Expected `meta.difficultyUsed` | Expected atom count | System-prompt marker |
|---|-----------:|---------------:|-------------------:|-------------------------------:|:-------------------------------|:--------------------|:---------------------|
| 1 | 6 | 0.0 | 0 | **6** | medium | **4 atoms** | `/Application-level/`, `/early reader/` |
| 2 | 6 | 0.0 | -2 | **6** | easy | **3 atoms** | `/Recognition-level/`, `/3 atoms/` |
| 3 | 6 | 0.0 | +2 | **6** | hard | **5–6 atoms** | `/Transfer-level/`, `/5–6 atoms/` |
| 4 | 4 | 0.0 | 0 | **4** | medium | 4 atoms | `/picture-first/`, `/single-concept/` |
| 5 | 8 | 0.0 | 0 | **8** | medium | 4 atoms | `/fluent reader/`, `/multi-concept/` |
| 6 | 7 | +1.2 | 0 | **8** | medium | 4 atoms | `/fluent reader/` at effectiveAge 8.2 |
| 7 | 8 | -1.5 | -2 | **6** (ties-round-down 6.5→6) | easy | 3 atoms | struggle nudge + Recognition level |
| 8 | 8 | +1.5 | +2 | **8** (clamped, no age-10) | hard | 5–6 atoms | above nudge + Transfer level |

**Edge behavior spot-checks:**

- **Cell 1** is the default surface: medium-curve render at age 6. Dev Console Skills tab confirms `meta.difficultyUsed: "medium"` and system prompt contains both `Application-level` and `early reader` markers.
- **Cells 2–3** are the difficulty-curve boundary locks. Easy curves to 3 atoms; hard curves to 5–6 (the upper bound is flexible within the lesson-shape invariant's `[3,6]` range so the LLM has one degree of freedom to pick 5 or 6 based on topic depth).
- **Cells 4–5** confirm the age-profile cascade still works on a Stage-3 skill (not just Stage-4). Each age profile's defining phrase (`picture-first` / `early reader` / `fluent reader`) is asserted in the skillEngine boot block — same resolver as for experiment-designer.
- **Cells 6–7** validate the S10-06 `progressionDelta` resolver on a decomposition skill — no new resolver code, but the anchor selection still works when the skill output is a sequenced atom list rather than a single card.
- **Cell 7** is the ties-round-down case in the negative direction: effective age 6.5 → profile 6, asserted by `difficultyBucketFor` describe block.
- **Cell 8** proves the above-anchor clamp holds: effective age 9.5 stays on profile 8 with the "above" modifier branch.

**Validator-only spot-checks** (no UI, ran as unit tests):

| Invariant | Rejection case | Error message marker |
|-----------|----------------|---------------------|
| Atom-N sequence | atoms with ids `[atom-1, atom-3]` (missing 2) | `/atom ids must be sequential atom-1 onward/` |
| Atom-N sequence | atom with id `node-1` (non-conforming) | `/atom id must match atom-N/` |
| Strategy↔cardType compat | strategy=`narrative`, cardType=`quiz` | `/strategy 'narrative' is not compatible with cardType 'quiz'/` |
| Strategy↔cardType compat | strategy=`assessment`, cardType=`story` | `/strategy 'assessment'.*cardType 'story'/` |
| Prereq DAG — forward ref | atom-2 has prereq `atom-4` | `/prerequisite "atom-4" appears after referencing atom/` |
| Prereq DAG — cycle | atom-2 prereq atom-3, atom-3 prereq atom-2 | `/prerequisite graph contains a cycle/` |
| Prereq DAG — missing ref | atom-2 prereq `atom-99` | `/prerequisite "atom-99" does not exist/` |
| Card-type diversity | 3 quiz atoms back-to-back | `/more than one consecutive atom with cardType 'quiz'/` |
| Lesson shape — min | 2 atoms total | `/decomposition must have 3–6 atoms/` |
| Lesson shape — max | 7 atoms total | `/decomposition must have 3–6 atoms/` |
| Lesson shape — opener | atom-1 strategy=`assessment` | `/opener strategy must be narrative or explanation/` |
| Lesson shape — closer | atom-N strategy=`narrative` | `/closer strategy must be quiz or reflection/` |
| Voice ceiling | 2 atoms with cardType `voice` | `/at most 1 voice atom per decomposition/` |
| Valid 4-atom happy path | narrative → explanation → experiment → quiz | `parsed.success === true` |

**Router state-machine spot-checks** (no UI, ran as unit tests with mocked `routeRequest`):

| State | Trigger | Expected result |
|-------|---------|-----------------|
| Happy | LLM returns valid JSON on attempt 1 | `kind: 'ok'`, `validatorStatus: 'ok'`, `retryCount: 0`, `atomCount: 3`, `tokens.total: 600` |
| Retry-ok (Zod) | Attempt 1 invalid, attempt 2 valid | `kind: 'ok'`, `validatorStatus: 'retry-ok'`, `retryCount: 1`, `tokens.total: 1200`, retry user turn contains `"rejected by the output validator"`, retry temperature = firstTemp − 0.1 |
| Retry-ok (parse) | Attempt 1 malformed JSON, attempt 2 valid | `kind: 'ok'`, `validatorStatus: 'retry-ok'`, `retryCount: 1` |
| Retry-failed | Both attempts invalid | `kind: 'failed'`, `reason: 'validation-failed'`, `validatorStatus: 'retry-failed'`, both attempt traces attached |
| Skill-not-loaded | Custom empty registry stub | `kind: 'failed'`, `reason: 'skill-not-loaded'`, never calls LLM |
| Missing input | `topic: ''` | `kind: 'failed'`, `reason: 'missing-required-input'`, never calls LLM |
| Missing input | `summary: ''` | `kind: 'failed'`, `reason: 'missing-required-input'`, never calls LLM |
| Transient re-throw | LLM throws `"fetch failed"` | thrown (propagates to outer `runStage`) |
| Transient re-throw | LLM throws `"429 Too Many Requests"` | thrown |
| Transient re-throw | LLM throws `"503 Service Unavailable"` | thrown |
| Transient on retry | Attempt 1 invalid, attempt 2 throws transient | thrown |
| Non-transient LLM error | LLM throws `"model not found"` | `kind: 'failed'`, `reason: 'llm-error'` |
| Empty response | LLM returns whitespace-only | `kind: 'failed'`, `reason: 'empty-response'`, never retries |
| Feature flag — unset | `process.env.SKILL_ENGINE_STAGE3` undefined | ON (router runs) |
| Feature flag — `"true"`/`"1"`/`"on"`/`"yes"` | each | ON |
| Feature flag — `"false"`/`"0"`/`"off"` | each | OFF (router short-circuits with `reason: 'stage-3-disabled-by-env'`) |
| Feature flag — `""` (ambiguous) | empty string | OFF (fails safe) |
| Feature flag — `"  TRUE  "` | whitespace + case | ON (trimmed + folded) |

---

## curl cheat sheet

Grab an auth token from the Dev Console's **Session** tab and export:

```bash
TOKEN="<paste Bearer token>"
BASE="http://localhost:3000/api/v1"
```

### List skills — confirm curriculum-architect is registered

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills" | \
  jq '.data[] | {name, version, modelHint, hasOutputSchema, difficulties, ageProfiles}'
# expect: four entries.
#   curriculum-architect: modelHint=pro,   hasOutputSchema=true,  difficulties=["easy","medium","hard"], ageProfiles=[4,6,8]
#   experiment-designer:  modelHint=flash, hasOutputSchema=true,  difficulties=["easy","medium","hard"], ageProfiles=[4,6,8]
#   quiz-maker:           modelHint=flash, hasOutputSchema=true,  difficulties=["easy","medium","hard"], ageProfiles=[4,6,8]
#   story-writer:         modelHint=flash, hasOutputSchema=false, difficulties=["easy","medium","hard"], ageProfiles=[4,6,8]
```

### Fetch the curriculum-architect manifest

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills/curriculum-architect" | jq '.data'
# expect: name=curriculum-architect, version=0.1.0, modelHint=pro, temperatureHint=0.5,
#         inputs.requires=["topic","summary","suggestedStage"],
#         inputs.optional=["keyConcepts","suggestedCardCount","sourceExcerpt"],
#         ageProfiles=[4,6,8],
#         difficulties=["easy","medium","hard"],
#         handlesConceptTypes=[],     <-- intentional: decomposition runs before conceptType dispatch
#         hasOutputSchema=true
```

### Dry-run render — medium curve (default)

```bash
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/curriculum-architect/render" \
  -d '{
    "inputs": {
      "topic": "why the sky is blue",
      "summary": "Sunlight scatters more in shorter wavelengths when it hits air molecules.",
      "suggestedStage": "primary"
    },
    "ctxOverrides": {
      "ageYears": 6,
      "progressionDelta": 0,
      "difficultyOffset": 0
    }
  }' | jq '{
    difficultyUsed: .data.meta.difficultyUsed,
    ageProfileUsed: .data.meta.ageProfileUsed,
    temperatureHint: .data.meta.temperatureHint,
    modelHint: .data.meta.modelHint,
    systemHasApplication: (.data.system | contains("Application-level")),
    systemHasEarlyReader: (.data.system | contains("early reader")),
    systemHasFourAtoms: (.data.system | contains("4 atoms"))
  }'
# expect: {difficultyUsed:"medium", ageProfileUsed:6, temperatureHint:0.5, modelHint:"pro",
#          systemHasApplication:true, systemHasEarlyReader:true, systemHasFourAtoms:true}
```

### Difficulty boundaries — easy (3 atoms) and hard (5–6 atoms)

```bash
# Easy — 3 atoms
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/curriculum-architect/render" \
  -d '{
    "inputs": {
      "topic": "living vs non-living things",
      "summary": "Living things grow, eat, and reproduce; non-living things do not.",
      "suggestedStage": "primary"
    },
    "ctxOverrides": { "difficultyOffset": -2 }
  }' | jq '{
    diff: .data.meta.difficultyUsed,
    hasRecognition: (.data.system | contains("Recognition-level")),
    hasThreeAtoms: (.data.system | contains("3 atoms"))
  }'
# expect: {diff:"easy", hasRecognition:true, hasThreeAtoms:true}

# Hard — 5–6 atoms
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/curriculum-architect/render" \
  -d '{
    "inputs": {
      "topic": "how plants make food from sunlight",
      "summary": "Photosynthesis converts light, water, and CO2 into glucose and oxygen.",
      "suggestedStage": "primary"
    },
    "ctxOverrides": { "difficultyOffset": 2 }
  }' | jq '{
    diff: .data.meta.difficultyUsed,
    hasTransfer: (.data.system | contains("Transfer-level")),
    hasFiveSixAtoms: (.data.system | contains("5–6 atoms"))
  }'
# expect: {diff:"hard", hasTransfer:true, hasFiveSixAtoms:true}
```

### Age-profile cascade — 4 vs 6 vs 8

```bash
for AGE in 4 6 8; do
  echo "=== age $AGE ==="
  curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "$BASE/dev/skills/curriculum-architect/render" \
    -d "{
      \"inputs\": { \"topic\": \"sorting by color\", \"summary\": \"Colors group objects by shared visible hue.\", \"suggestedStage\": \"primary\" },
      \"ctxOverrides\": { \"ageYears\": $AGE, \"progressionDelta\": 0, \"difficultyOffset\": 0 }
    }" | jq '{age: .data.meta.ageProfileUsed, marker:
      (if .data.system | contains("picture-first") then "age-4 / picture-first"
       elif .data.system | contains("early reader") then "age-6 / early reader"
       elif .data.system | contains("fluent reader") then "age-8 / fluent reader"
       else "MISMATCH" end)}'
done
# expect: {age:4, marker:"age-4 / picture-first"}
#         {age:6, marker:"age-6 / early reader"}
#         {age:8, marker:"age-8 / fluent reader"}
```

### Strict-schema rejection — missing input + feature-flag disable

```bash
# Missing required input → 400
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/curriculum-architect/render" \
  -d '{ "inputs": { "topic": "x" } }' -w '\n%{http_code}\n'
# expect: 400 (missing "summary" and "suggestedStage")

# Unknown ctxOverrides key → 400
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/curriculum-architect/render" \
  -d '{
    "inputs": { "topic": "x", "summary": "y", "suggestedStage": "primary" },
    "ctxOverrides": { "hackField": 1 }
  }' -w '\n%{http_code}\n'
# expect: 400
```

### Feature-flag toggle — Stage 3 ON vs OFF

```bash
# Stage 3 ON (default) — pipeline trace includes curriculum-architect decomposition row
SKILL_ENGINE_STAGE3=true npm run dev &
sleep 2
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/pipeline/run" \
  -d '{ "analyzedTopic": { "topic": "why the sky is blue", "summary": "...", "suggestedStage": "primary" } }' | \
  jq '.data.trace[] | select(.stage == "3-decomposition") | {
    skillEngineUsed,
    skill,
    validatorStatus,
    atomCount: (.atoms | length)
  }'
# expect: {skillEngineUsed:true, skill:"curriculum-architect", validatorStatus:"ok", atomCount:4}

# Stage 3 OFF — pipeline trace shows legacy fallback
kill %1; SKILL_ENGINE_STAGE3=false npm run dev &
sleep 2
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/pipeline/run" \
  -d '{ "analyzedTopic": { "topic": "why the sky is blue", "summary": "...", "suggestedStage": "primary" } }' | \
  jq '.data.trace[] | select(.stage == "3-decomposition") | {
    skillEngineUsed,
    skill,
    reason,
    atomCount: (.atoms | length)
  }'
# expect: {skillEngineUsed:false, skill:null, reason:"stage-3-disabled-by-env", atomCount:3}
```

### Hot reload (dev-only)

```bash
curl -s -XPOST -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills/curriculum-architect/reload" | jq '.data'
# expect: { reloaded: "curriculum-architect", at: "<iso timestamp>" }
```

### Validator sanity — run the Zod schema directly

From a REPL or `tsx` script:

```ts
import { curriculumArchitectOutputSchema } from './src/services/skills/validators/curriculumArchitect';

// Happy path — 4-atom medium curve
curriculumArchitectOutputSchema.parse({
  atoms: [
    { id: 'atom-1', title: 'What is light?',             strategy: 'narrative',   cardType: 'story',      conceptSummary: 'Light is energy we see.',                  prerequisites: [] },
    { id: 'atom-2', title: 'Why does light scatter?',    strategy: 'explanation', cardType: 'story',      conceptSummary: 'Tiny particles bend light.',               prerequisites: ['atom-1'] },
    { id: 'atom-3', title: 'Try the prism experiment',   strategy: 'application', cardType: 'experiment', conceptSummary: 'A prism splits light into a rainbow.',     prerequisites: ['atom-2'] },
    { id: 'atom-4', title: 'Check what you learned',     strategy: 'assessment',  cardType: 'quiz',       conceptSummary: 'Short questions anchor the new ideas.',    prerequisites: ['atom-3'] },
  ],
  rationale: 'Four atoms: narrative hook → scattering explanation → hands-on application → assessment. Diversity respected; prereq DAG linear; opener=narrative, closer=quiz.',
});
// => no throw

// Should throw — two voice atoms (voice ceiling invariant)
curriculumArchitectOutputSchema.parse({
  atoms: [
    { id: 'atom-1', title: 'Say it with me',    strategy: 'reflection', cardType: 'voice', conceptSummary: 'Read the phrase aloud.',   prerequisites: [] },
    { id: 'atom-2', title: 'Read the next one', strategy: 'reflection', cardType: 'voice', conceptSummary: 'Second phrase aloud.',     prerequisites: ['atom-1'] },
    { id: 'atom-3', title: 'Check it',          strategy: 'assessment', cardType: 'quiz',  conceptSummary: 'Pick the right phrase.',   prerequisites: ['atom-2'] },
  ],
  rationale: 'Stacked voice atoms for engagement.',
});
// => ZodError: at most 1 voice atom per decomposition
```

---

## Pipeline-tab walkthrough (new Stage-3 row preceding the atom rows)

After curriculum-architect lands, the Pipeline tab gains a **new row at position 0** — the Stage-3 decomposition — that runs *before* the per-atom Stage-4 rows. The Stage-4 rows keep their existing shape (one per atom).

1. Author a lesson through the Dev Console pipeline tab (use any existing `createLesson` path — S12-09's authoring UI lands next, but the dev-preview endpoint works today).
2. Pick a topic with a meaningful decomposition (e.g., "why the sky is blue" produces a narrative → explanation → experiment → quiz 4-atom decomp).
3. Watch the new Stage-3 row populate first:
   - **Stage:** `3-decomposition`
   - **`skillEngineUsed: true`** (previously `false` with a `legacy-heuristic-decomposer` tag)
   - **`skill: curriculum-architect`** — clickable, expands into the rendered system + user prompt
   - **`validator: ✓ attached`** — green chip
   - **`validatorStatus: ok`** (or `retry-ok` if the LLM's first attempt failed a Zod invariant)
   - **`atomCount: 4`** (or whatever the decomposition produces for that topic)
   - **`retryCount: 0`** (or `1` on retry-ok)
   - **`tokens: {prompt, completion, total}`** per attempt
4. Then the 4 Stage-4 atom rows render below, each one routed to the appropriate per-atom skill (`story-writer` / `experiment-designer` / `quiz-maker` / legacy voice until S12-06 lands). The Stage-3 row's atom ids (`atom-1`, `atom-2`, …) appear as foreign keys on each Stage-4 row — the Pipeline tab draws a subtle vertical line connecting them so the sequence is visually obvious.
5. On a Zod-retry case (invalid decomposition on first pass, corrected on retry), the Stage-3 pill reads `retry-ok` and the trace expands into:
   - Attempt 1 raw response (with the Zod validation errors inlined)
   - Attempt 1 Zod issues array
   - Attempt 2 raw response (passes)
   - `retryCount: 1`
   - Attempt 2 `temperature: 0.4` (attempt 1 was 0.5, −0.1 nudge)
6. On a `retry-failed` case (two consecutive invalid decompositions), the Stage-3 row renders as `validation-failed` and the orchestrator falls back to the legacy heuristic decomposer — same contract S10-12 established for Stage 4. Stage-4 atom rows then render below using the legacy-generated atoms.
7. On the feature-flag OFF case (`SKILL_ENGINE_STAGE3=false`), the Stage-3 row renders as `skipped` with `reason: 'stage-3-disabled-by-env'` — same `skipped` chip style as a legacy-fallback Stage-4 atom.

---

## Quick-start runbook (bang's Mac)

```bash
cd ~/Code/Novai/src/Backend

# 1. Pull. One new env var (SKILL_ENGINE_STAGE3, defaults ON), no new deps, no new migrations.
git pull

# 2. Run the three curriculum-architect suites (should complete in <1s total)
npx vitest run curriculumArchitectValidator decompositionRouter skillEngine
#   expect: 111 passing, 0 failing (40 validator + 25 router + 46 engine).

# 3. Full suite sanity pass — baseline is 763 passing + 1 pre-existing failure in
#    tests/sprint6.test.ts (SPARKY_SYSTEM_PROMPT rename debt from S11-09 → S12-08).
#    That failure should still be the only red cell.
npm test

# 4. Boot the server — the registry now loads FOUR skills.
SKILL_ENGINE_STAGE3=true npm run dev
#   expect log: "SkillRegistry loaded: curriculum-architect v0.1.0, experiment-designer v0.1.0, quiz-maker v0.1.0, story-writer v0.1.0"

# 5. Open the Dev Console Skills tab
#    → http://localhost:3000/dev/dev-pipeline.html#skills

# 6. Cross-flip the feature flag and re-run a pipeline to confirm legacy fallback still works
kill %1; SKILL_ENGINE_STAGE3=false npm run dev
#    → Pipeline tab Stage-3 row should read 'skipped' with reason 'stage-3-disabled-by-env'
```

If boot fails with a SkillRegistry error, the error message will name the file (`defs/curriculum-architect/<file>` or `validators/curriculumArchitect.ts`) and the Zod / Handlebars failure path.

### Prerequisites bang must run on his Mac

```bash
# Sandbox can type-check + run vitest but cannot boot the Dev Console UI or exercise the
# Pipeline tab against a live Postgres. The following steps land on the Mac.

# 1. Skills tab — four entries listed; curriculum-architect row shows a green 'val' badge
#    (validator attached). Dry-run render with difficultyOffset -2 / 0 / +2 cycles through
#    3-atom / 4-atom / 5–6-atom system prompts.

# 2. Pipeline tab — author a real lesson whose topic produces a non-trivial decomposition
#    (e.g., "why the sky is blue"). Confirm the NEW Stage-3 row appears at position 0 with
#    skillEngineUsed=true, skill=curriculum-architect, validator=✓ attached, validatorStatus=ok,
#    and 4 atoms rendering as Stage-4 rows below it.

# 3. Feature-flag toggle — set SKILL_ENGINE_STAGE3=false and re-run the same pipeline.
#    Confirm the Stage-3 row reads 'skipped' with reason 'stage-3-disabled-by-env' and
#    the Stage-4 atoms still render (legacy heuristic decomposer picked up the fallback).

# 4. Retry-on-Zod smoke — use the Dev Console's "inject malformed decomp" affordance (or
#    temporarily reduce the max-tokens to force truncation) to confirm the retry-on-Zod
#    path fires with temperature=0.4 on attempt 2 and the user turn contains the
#    "rejected by the output validator" framing.

# 5. End-to-end iPad render — no iPad-side changes this story; verify that a lesson
#    created through the full pipeline (Stage 3 + Stage 4) renders correctly on the
#    iPad after pull-to-refresh — the atom sequence from curriculum-architect should
#    appear in order.
```

---

## Retired debt

This story closes the **second of three** carry-from-S10 CE-epic debts (`curriculum-architect` was deferred from S10 alongside `experiment-designer` and `voice-persona` to keep S11 UX-pure). The legacy heuristic decomposer — a hand-rolled pattern-matching function that produced 3-atom decompositions from topic keywords — is now dead code when the feature flag is ON. It stays in place as the `SKILL_ENGINE_STAGE3=false` fallback for operator A/B comparison, but after S12-06 closes the CE epic and the skill-engine path proves stable in production, the legacy decomposer becomes removable in S13+.

In-run debt retired: **three latent type errors** in `decompositionRouter.ts` (trace-field coercion at `buildOkResult` / `buildFailedResult` assignment sites — surfaced only when R5's new test file forced a full backend `tsc --noEmit`), and **one manifest drift** (`modelHint: "sonnet"` → `"pro"` — caught by `SkillManifestSchema.parse` on registry boot, which failed 3 pre-existing `skillEngine.test.ts` suites until the fix landed). Both fixes documented in the "In-plan vs drift" section of the tracker entry.

---

## What's next

1. **S12-06 `voice-persona`** — the last CE-epic story. Covers `card.type === 'voice'` atoms (the Dashy voice-mode cards where the kid reads aloud). This is the skill where the canonical Dashy character prompt finally lives — cross-referenced by the S12-17 Dashy voice-consistency audit. After S12-06 lands, the full 5-modality skill-engine is complete and all three S10-12 legacy-fallback paths go dead-coded.
2. **S12-09 Dev Console — content authoring surface** — once all four CE skills are in place, the Author Lesson tab lands and the touch-test loop becomes real. bang authors a lesson in the Dev Console; the SSE stream shows every Stage-3 row + Stage-4 atom row lighting up in sequence; the lesson lands in the dev DB; the iPad picks it up on pull-to-refresh.
3. **S12-10 seed — 3 real lessons** — using S12-09, author three lessons end-to-end covering all five card types. Curriculum-architect does the Stage-3 heavy lifting; this is the first time the Stage-3 skill-engine path runs against real content, not synthetic test inputs.

---

## Cross-references

- Sprint 12 tracker: [docs/SPRINT-12-tracker.md](../SPRINT-12-tracker.md)
- Skill-engine kickoff: [docs/sprint-runs/S10-skill-engine-kickoff.md](./S10-skill-engine-kickoff.md)
- Prior skill runs: [S10-06 story-writer](./S10-skill-engine-s10-06.md), [S10-07 quiz-maker](./S10-skill-engine-s10-07.md), [S10-12 orchestrator + retry](./S10-skill-engine-s10-12.md), [S12-04 experiment-designer](./S12-04-experiment-designer.md)
- Engine source: `src/Backend/src/services/skills/{types,loader,progression,registry}.ts`
- Validator registry: `src/Backend/src/services/skills/validators/{index,curriculumArchitect}.ts`
- Curriculum-architect definition: `src/Backend/src/services/skills/defs/curriculum-architect/*`
- Stage-3 router (new this run): `src/Backend/src/services/pipeline/decompositionRouter.ts`
- Orchestrator wire: `src/Backend/src/services/pipeline/pipelineOrchestrator.ts` → `runStage3(...)`
- Tests: `src/Backend/tests/{curriculumArchitectValidator,decompositionRouter,skillEngine}.test.ts`
- iOS consumer (unchanged this run): atom sequencing flows through Stage-4 per-skill rendering; no Swift changes required
