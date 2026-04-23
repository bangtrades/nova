# S12-04 — `experiment-designer` Skill + Validator + Router Wiring Run Summary

**Sprint:** Sprint 12 — "Touch Test"
**Story:** S12-04 — `experiment-designer` skill (def bundle + Zod validator + router dispatch) (6 pts)
**Landed:** April 22, 2026
**Status:** ✅ Shipped. 10 def files, one per-skill Zod validator, skillRouter + cardGenerator wiring, and three test files (86 new assertions) merged in-sandbox. Awaiting bang's Mac-side Dev Console walkthrough.

This document is the **delivery run summary and Mac-side runbook** for S12-04. It is the third entry in the skill-engine family — after [S10-06](./S10-skill-engine-s10-06.md) (story-writer + Handlebars engine) and [S10-07](./S10-skill-engine-s10-07.md) (quiz-maker + per-skill Zod validator) — and it closes the first of the three carry-from-S10 CE-epic stories that the S10-12 orchestrator left with an explicit legacy-fallback path for. The tracker entry (`docs/SPRINT-12-tracker.md` → "S12-04 Delivery Notes") is the authoritative per-file changelog; this doc is the **architectural-decision log + validation matrix + operator recipe** bang walks through in the Dev Console to confirm the drag-and-drop sort generator behaves as specified — and to confirm the Pipeline tab's `skillEngineUsed: true` + per-atom pills now fire for `experiment` atoms alongside `story` and `quiz`.

---

## What shipped

Ten new content files under `defs/experiment-designer/`, one Zod validator, three skillRouter touchpoints (token ceiling + model pick + input assembly + card assembly), and three test files' worth of coverage. Lifted patterns from S10-07's quiz-maker — not new architecture, deliberately.

- `src/services/skills/defs/experiment-designer/{manifest.json, prompt.md, styles.md, topics.md, age-profiles/{4,6,8}.md, difficulty-curves/{easy,medium,hard}.md}` — the third real skill.
- `src/services/skills/validators/experimentDesigner.ts` (260 lines) — strict `.object(...).strict().superRefine(...)` with 8 referential-integrity invariants layered on top of base Zod bounds.
- `src/services/skills/validators/index.ts` — one-line append: `'experiment-designer': experimentDesignerOutputSchema`.
- `src/services/skills/types.ts` — already had `CARD_TYPE_TO_SKILL.experiment → 'experiment-designer'` from S10-12's groundwork. Untouched this run.
- `src/services/pipeline/skillRouter.ts` — four touchpoints: token ceiling (900 tokens, bounded by the drag/drop list shape), model pick (`claude-sonnet` per manifest hint), input assembly (`buildSkillInputs('experiment-designer', ...)` — concept + conceptType + optional topic + optional lastStoryExcerpt), card assembly (`buildCardFromSkillOutput('experiment-designer', ...)` emits `type: 'experiment'` + `content: { title, instructions, dragItems, dropTargets }` + `voiceScript = instructions + conceptSummary`).
- `tests/experimentDesignerValidator.test.ts` (628 lines, 35 cases), `tests/experimentDesignerRouter.test.ts` (379 lines, 7 cases), additions to `tests/skillEngine.test.ts` (+44 cases total for the file; 9 new in the experiment-designer describe block).

Zero schema changes. Zero new migrations. Zero new env vars. Zero new npm deps. The legacy `generateExperimentCard(...)` fallback stays in place until all three CE-epic skills land (S12-05 `curriculum-architect` and S12-06 `voice-persona` still pending) — the S10-12 decomposition-aware path picks the skill when `CARD_TYPE_TO_SKILL[atom.recommendedCardType]` resolves; otherwise it falls through. One less fall-through as of this run.

---

## Architectural decisions (the "why X over Y" log)

1. **Per-item `id` as kebab-case string, not auto-assigned UUID.** The drag-and-drop contract needs the LLM to correlate `dragItems[i].id` with `dropTargets[j].acceptsItemIds[k]` — the LLM has to *name* the mapping, not just produce two arrays and hope a post-process can pair them. Requiring the model to emit kebab-case ids (`cork`, `rock`, `apple`) is the cheapest way to get referential integrity out of JSON without a nested schema. Alternative considered: letting the LLM emit `dragItems` as `[{label: "Cork"}, ...]` and having the backend generate ids. Rejected — the backend would then need the LLM to *re-emit* the labels inside `dropTargets.acceptsItemIds`, and Zod can't cross-reference arbitrary strings that weren't declared. Kebab-case ids + strict Zod regex is the minimum viable referential protocol.
2. **Orphan check + dual-assignment check written as a single `acceptedCount` map.** Every dragItem must appear in exactly one dropTarget's `acceptsItemIds` — never zero (orphan — the kid can't place it anywhere and the game never completes), never two (dual-assignment — ambiguous, breaks the "one right bin" mental model). `acceptedCount.get(id) === 1` is the invariant; `=== 0` and `>= 2` both get their own `ctx.addIssue(...)` with specific error messages so the retry-on-Zod layer can translate them into corrective prompts. Alternative considered: allowing dual-assignment for "shows up in multiple categories" cards (e.g., whales are mammals AND swim). Rejected for S12-04 — that's a separate card type ("multi-select") and shoehorning it into the sort primitive muddies the grasp signal. If multi-select becomes a real need, it lands as a fourth card type with its own skill, not by loosening this one.
3. **Difficulty matrix as a hard-coded `(dragItems.length, dropTargets.length)` tuple: (3,2) easy · (4,2) medium · (5,3) hard.** The curve file says "exactly 3 items into 2 bins" (or 4/2, 5/3); the validator enforces it so the retry layer can push back with a specific message when the LLM drifts. Alternative considered: a continuous "target = items + bins between 4 and 8" heuristic. Rejected — fuzzy bounds mean an LLM that emits 5/2 at easy-difficulty "looks OK" but breaks the cognitive-load calibration the age profiles are tuned for (age 4 handles 3 items/2 bins; 5 items would overwhelm). Discrete ladder is easier to test, easier to retry, and easier to debug in the Pipeline tab when a skill misfires.
4. **Substantive-label check uses Unicode property escapes `/[\p{L}\p{N}]/u`, not a lone `/\w/`.** Accepts "1st step", "rocks 🪨", "café"; rejects "🍾", "…", whitespace-only. `\w` in a default-Latin regex would reject "café" and accept every ASCII word character including underscore. `\p{L}` matches any Unicode letter (including accented + non-Latin scripts) and `\p{N}` matches any Unicode digit — the right primitive when labels may contain international content in the future. The `/u` flag is required to activate property escapes; without it the regex silently accepts every character. One-character decision; 20 minutes saved every time the LLM emits "1st" or "Bin #1" down the line.
5. **Label uniqueness case-insensitive AND whitespace-normalized.** The LLM can and will emit `"Floats"` and `"floats"` as two drop targets and think they're distinct categories — they're not. Same for `"Hard object"` and `"hard   object"`. Normalization is `s.trim().toLowerCase().replace(/\s+/g, ' ')` so both collapse to the same key. The validator reports the *original* label in the error message (`duplicate dragItem label "Rock" (matches index 0)`) so the retry prompt can point at what the LLM actually emitted, not a normalized form the LLM never wrote.
6. **camelCase on the wire (backend → iOS), snake_case in Swift decoders.** The skill emits `dragItems` / `dropTargets` / `acceptsItemIds`. The iOS `ExperimentCardView` already expects `drag_items` / `drop_targets` / `accepts_item_ids` per `Card.DragItem` / `Card.DropTarget` conventions. Same boundary as quiz's `correct_option_index` — backend emits camelCase, iOS transformer `map` step renames at the decoder. Not re-negotiating the boundary for this card type. Locked in a one-line code comment inside `buildCardFromSkillOutput` so the next person touching this doesn't try to "fix" the casing.
7. **Conservative maxTokens=900 for `experiment-designer`.** Story-writer runs at 2400 (prose), quiz-maker at 600 (bounded options). Experiment-designer is structurally in between — title (1 line) + instructions (2 lines) + 3-5 drag items × (id + label) + 2-3 drop targets × (id + label + acceptsItemIds) + conceptSummary (2 sentences) + rationalePerTarget (N short strings). Empirically lands at 400-600 tokens; 900 is +50% headroom. Alternative considered: shared `maxTokens = 1500` default. Rejected — per-skill tuning lets the cost router + Pipeline tab trace more meaningful token budgets, and the ceiling matters when the LLM repeats itself. 900 surfaces a runaway as a retry, not as a silent truncation.
8. **`rationalePerTarget` parallel array, not nested under `dropTargets`.** Easier for the LLM to emit + validate as a separate length-2 or length-3 string array than as a nested object. The Zod schema enforces `rationalePerTarget.length === dropTargets.length` in a single `superRefine` check. Alternative considered: moving `rationale` inside each `dropTarget`. Rejected — the nested form requires the LLM to emit a rationale *before* it has finalized the `acceptsItemIds` list, which empirically produces sloppy pairings. Emitting rationales at the end of the JSON (after the sort is finalized) lines up with how a human would narrate it: "here's the sort; and here's *why* it works." Prompt follows that order.

---

## Validation matrix

The matrix proves (a) difficulty-matrix enforcement, (b) per-skill age-profile cascade, (c) the per-invariant Zod rejections, and (d) the router wiring picks `experiment-designer` for `card.type === 'experiment'` atoms without legacy fallback. Every cell is either covered by an automated test OR sits on a sliding scale where the matrix itself is the smoke check.

**Controls:** `mode = synthetic`, `skill = experiment-designer`, `inputs = {"concept": "which objects float or sink", "conceptType": "process"}`. Only the bolded knobs vary per row.

| # | `ageYears` | `progressionΔ` | `difficultyOffset` | Expected `meta.ageProfileUsed` | Expected `meta.difficultyUsed` | Expected sort shape | System-prompt marker |
|---|-----------:|---------------:|-------------------:|-------------------------------:|:-------------------------------|:--------------------|:---------------------|
| 1 | 6 | 0.0 | 0 | **6** | medium | **4 items × 2 bins** | `/Application-level/`, `/early reader/` |
| 2 | 6 | 0.0 | -2 | **6** | easy | **3 items × 2 bins** | `/Recognition-level/`, `/3 items × 2 bins/` |
| 3 | 6 | 0.0 | +2 | **6** | hard | **5 items × 3 bins** | `/Transfer-level/`, `/5 items × 3 bins/` |
| 4 | 4 | 0.0 | 0 | **4** | medium | 4 items × 2 bins | `/picture-first/`, `/single-attribute/` |
| 5 | 8 | 0.0 | 0 | **8** | medium | 4 items × 2 bins | `/fluent reader/`, `/multi-attribute/` |
| 6 | 7 | +1.2 | 0 | **8** | medium | 4 items × 2 bins | `/fluent reader/` at effectiveAge 8.2 |
| 7 | 8 | -1.5 | -2 | **6** (ties-round-down 6.5→6) | easy | 3 items × 2 bins | struggle nudge + Recognition level |
| 8 | 8 | +1.5 | +2 | **8** (clamped, no age-10) | hard | 5 items × 3 bins | above nudge + Transfer level |

**Edge behavior spot-checks:**

- **Cell 1** is the test-locked default: `skillEngine.test.ts` asserts `/Application-level/` and `/early reader/` fire on a medium-curve render at age 6.
- **Cells 2–3** are the difficulty-curve locks. Both asserted by skillEngine + validator tests. On the UI, the expected-shape meta cell must read `3×2` / `5×3` respectively.
- **Cells 4–5** prove the age-profile cascade still works on the third skill. Each age profile's defining phrase (`picture-first` / `early reader` / `fluent reader`) is asserted in the skillEngine describe block.
- **Cells 6–7** validate the S10-06 progressionDelta resolver on experiment-designer — no new resolver code, but the anchor selection still works when the skill is different.
- **Cell 7** is the ties-round-down case in the negative direction: effective age 6.5 → profile 6, asserted by `difficultyBucketFor` describe.
- **Cell 8** proves the above-anchor clamp holds: effective age 9.5 stays on profile 8 with the "above" modifier branch.

**Validator-only spot-checks** (no UI, ran as unit tests):

| Invariant | Rejection case | Error message marker |
|-----------|----------------|---------------------|
| Difficulty matrix | 3 items × 3 bins | `/counts must be \(3,2\) easy.*got \(3,3\)/` |
| Difficulty matrix | 2 items × 2 bins | `/dragItems must have 3, 4, or 5 entries/` |
| Difficulty matrix | 6 items × 2 bins | `/dragItems must have 3, 4, or 5 entries/` |
| Rationale parity | `rationalePerTarget.length === 3`, `dropTargets.length === 2` | `/rationalePerTarget length \(3\) must match/` |
| Duplicate dragItem id | two items with id `cork` | `/duplicate dragItem id "cork"/` |
| Non-kebab id | `Cork` (uppercase) | `/id must be kebab-case/` |
| Orphaned item | dragItem `pear` not in any `acceptsItemIds` | `/dragItem "pear" is orphaned/` |
| Dual-assignment | dragItem `cork` accepted by both `floats` and `sinks` | `/accepted by 2 dropTargets — must be exactly one/` |
| Non-existent reference | `acceptsItemIds: ["ghost-item"]` | `/does not match any dragItem id/` |
| Duplicate label (case) | `"Floats"` and `"floats"` | `/duplicate dropTarget label "floats"/` |
| Emoji-only label | `{label: "🍾"}` | `/emoji\/punctuation-only/` |
| Punctuation-only label | `{label: "..."}` | `/emoji\/punctuation-only/` |
| Substantive with digit | `{label: "1st"}` | `parsed.success === true` |

---

## curl cheat sheet

Grab an auth token from the Dev Console's **Session** tab and export:

```bash
TOKEN="<paste Bearer token>"
BASE="http://localhost:3000/api/v1"
```

### List skills — validator surface

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills" | \
  jq '.data[] | {name, version, modelHint, hasOutputSchema, difficulties, ageProfiles}'
# expect: three entries.
#   experiment-designer: hasOutputSchema=true,  difficulties=["easy","medium","hard"], ageProfiles=[4,6,8]
#   quiz-maker:          hasOutputSchema=true,  difficulties=["easy","medium","hard"], ageProfiles=[4,6,8]
#   story-writer:        hasOutputSchema=false, difficulties=["easy","medium","hard"], ageProfiles=[4,6,8]
```

### Fetch the experiment-designer manifest

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills/experiment-designer" | jq '.data'
# expect: name=experiment-designer, version=0.1.0, modelHint=flash, temperatureHint=0.5,
#         inputs.requires=["concept","conceptType"],
#         inputs.optional=["topic","targetLessonId","lastStoryExcerpt"],
#         handlesConceptTypes=["process","comparison","causeEffect","vocabulary","factual"],
#         hasOutputSchema=true
```

### Dry-run render — medium curve (default)

```bash
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/experiment-designer/render" \
  -d '{
    "inputs": {
      "concept": "which objects float or sink",
      "conceptType": "process"
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
    systemHasFourByTwo: (.data.system | contains("4 items × 2 bins"))
  }'
# expect: {difficultyUsed:"medium", ageProfileUsed:6, temperatureHint:0.5, modelHint:"flash",
#          systemHasApplication:true, systemHasEarlyReader:true, systemHasFourByTwo:true}
```

### Difficulty boundaries — easy (3×2) and hard (5×3)

```bash
# Easy — 3 items × 2 bins
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/experiment-designer/render" \
  -d '{
    "inputs": { "concept": "living vs non-living things", "conceptType": "comparison" },
    "ctxOverrides": { "difficultyOffset": -2 }
  }' | jq '{
    diff: .data.meta.difficultyUsed,
    hasRecognition: (.data.system | contains("Recognition-level")),
    hasThreeByTwo: (.data.system | contains("3 items × 2 bins"))
  }'
# expect: {diff:"easy", hasRecognition:true, hasThreeByTwo:true}

# Hard — 5 items × 3 bins
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/experiment-designer/render" \
  -d '{
    "inputs": { "concept": "animal habitats", "conceptType": "factual" },
    "ctxOverrides": { "difficultyOffset": 2 }
  }' | jq '{
    diff: .data.meta.difficultyUsed,
    hasTransfer: (.data.system | contains("Transfer-level")),
    hasFiveByThree: (.data.system | contains("5 items × 3 bins"))
  }'
# expect: {diff:"hard", hasTransfer:true, hasFiveByThree:true}
```

### Age-profile cascade — 4 vs 6 vs 8

```bash
for AGE in 4 6 8; do
  echo "=== age $AGE ==="
  curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "$BASE/dev/skills/experiment-designer/render" \
    -d "{
      \"inputs\": { \"concept\": \"sorting by color\", \"conceptType\": \"vocabulary\" },
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

### Strict-schema rejection

```bash
# Missing required input → 400
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/experiment-designer/render" \
  -d '{ "inputs": { "concept": "x" } }' -w '\n%{http_code}\n'
# expect: 400 (missing "conceptType")

# Unknown ctxOverrides key → 400
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/experiment-designer/render" \
  -d '{
    "inputs": { "concept": "x", "conceptType": "process" },
    "ctxOverrides": { "hackField": 1 }
  }' -w '\n%{http_code}\n'
# expect: 400
```

### Hot reload (dev-only)

```bash
curl -s -XPOST -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills/experiment-designer/reload" | jq '.data'
# expect: { reloaded: "experiment-designer", at: "<iso timestamp>" }
```

### Validator sanity — run the Zod schema directly

From a REPL or `tsx` script:

```ts
import { experimentDesignerOutputSchema } from './src/services/skills/validators/experimentDesigner';

// Happy path — easy curve (3×2)
experimentDesignerOutputSchema.parse({
  title: 'Sort by Floating',
  instructions: 'Drag each object onto the bin that matches what it does in water.',
  dragItems: [
    { id: 'cork', label: 'Cork' },
    { id: 'rock', label: 'Rock' },
    { id: 'apple', label: 'Apple' },
  ],
  dropTargets: [
    { id: 'floats', label: 'Floats', acceptsItemIds: ['cork', 'apple'] },
    { id: 'sinks', label: 'Sinks', acceptsItemIds: ['rock'] },
  ],
  conceptSummary: 'Objects less dense than water float; denser objects sink.',
  rationalePerTarget: [
    'Cork and apples are lighter than the water they push out.',
    'A rock is denser than water, so it falls through to the bottom.',
  ],
});
// => no throw

// Should throw — orphaned item
experimentDesignerOutputSchema.parse({
  title: 'Sort by Floating',
  instructions: 'Sort the items.',
  dragItems: [
    { id: 'cork', label: 'Cork' },
    { id: 'rock', label: 'Rock' },
    { id: 'pear', label: 'Pear' },      // <-- orphaned
  ],
  dropTargets: [
    { id: 'floats', label: 'Floats', acceptsItemIds: ['cork'] },
    { id: 'sinks', label: 'Sinks', acceptsItemIds: ['rock'] },
  ],
  conceptSummary: 'Density decides sinking.',
  rationalePerTarget: ['lighter-than-water floats', 'denser-than-water sinks'],
});
// => ZodError: dragItem "pear" is orphaned — no dropTarget accepts it
```

---

## Pipeline-tab walkthrough (S10-12-R7 surface)

After the three new skills land, the Pipeline tab's atom pills should tell the same story for `experiment` atoms that they already tell for `story` and `quiz`:

1. Author a lesson through the Dev Console pipeline tab (use any existing `createLesson` path — S12-09's authoring UI lands next).
2. Pick a topic whose decomposition includes an experiment atom (e.g., "why things float"). The decomposition step emits `recommendedCardType: 'experiment'` for at least one atom.
3. Watch the atom pills populate:
   - **`skillEngineUsed: true`** on the experiment atom (previously `false` with a legacy-path tag).
   - **`skill: experiment-designer`** — clickable, expands into the rendered system + user prompt.
   - **`validator: ✓ attached`** — green chip.
   - **`validatorStatus: ok`** (or `retry-ok` if the LLM's first attempt failed a Zod invariant and the retry layer succeeded on attempt 2).
4. On a Zod-retry case (invalid JSON on first pass, corrected on retry), the pill reads `retry-ok` and the trace expands into:
   - Attempt 1 raw response (with the validation errors inlined).
   - Attempt 1 Zod issues array.
   - Attempt 2 raw response (passes).
   - `retryCount: 1`.
5. On a `retry-failed` case (two consecutive invalid outputs), the atom renders as `skipped` in the final lesson and the pill reads `validation-failed` with both attempts' traces. The card generator falls back to the legacy experiment path — same contract S10-12 established.

---

## Quick-start runbook (bang's Mac)

```bash
cd ~/Projects/Novai/src/Backend

# 1. Pull. No new deps, no new migrations.
git pull

# 2. Run the three experiment-designer suites (should complete in <1s total)
npx vitest run experimentDesignerValidator experimentDesignerRouter skillEngine
#   expect: 86 passing, 0 failing (35 validator + 7 router + 44 engine).

# 3. Full suite sanity pass — baseline is 696 passing + 1 pre-existing failure in
#    tests/sprint6.test.ts (SPARKY_SYSTEM_PROMPT rename debt from S11-09 → S12-08).
#    That failure should still be the only red cell.
npm test

# 4. Boot the server — the registry now loads THREE skills.
npm run dev
#   expect log: "SkillRegistry loaded: experiment-designer v0.1.0, quiz-maker v0.1.0, story-writer v0.1.0"

# 5. Open the Dev Console Skills tab
#    → http://localhost:3000/dev/dev-pipeline.html#skills
```

If boot fails with a SkillRegistry error, the error message will name the file (`defs/experiment-designer/<file>` or `validators/experimentDesigner.ts`) and the Zod / Handlebars failure path.

### Prerequisites bang must run on his Mac

```bash
# Sandbox can type-check but cannot boot the Dev Console UI or exercise the
# Pipeline tab against a live Postgres. The following steps land on the Mac.

# 1. Skills tab — three entries listed; experiment-designer row shows a green
#    'val' badge (validator attached). Dry-run render with difficultyOffset
#    -2 / 0 / +2 cycles through 3×2 / 4×2 / 5×3 system prompts.

# 2. Pipeline tab — author a real lesson whose decomposition includes an
#    experiment atom. Confirm the atom pill shows skillEngineUsed=true,
#    skill=experiment-designer, validator=✓ attached, validatorStatus=ok.

# 3. iPad regression — the contract to Card.DragItem / Card.DropTarget on the
#    Swift side is unchanged by this run; existing ExperimentCardView renders
#    the skill-engine output identically to the legacy path. Cross-check with
#    one seeded lesson before S12-10.
```

---

## Retired debt

None explicitly — this story closes the first of three carry-from-S10 debts (`experiment-designer` was deferred from S10 to keep S11 UX-pure). S12-05 `curriculum-architect` + S12-06 `voice-persona` close the remaining two. After all three land, the legacy `generateExperimentCard` / `generateVoiceCard` / `generateCurriculumStep` fallback paths become dead code and the CE epic is fully retired.

---

## What's next

1. **S12-05 `curriculum-architect`** — same shape as this run, but runs at **Stage 3** (decomposition) rather than Stage 4 (atom generation). Mirrors the spike's Stage-3 extension points. Same manifest + prompt + age-profiles + Zod validator pattern lifted wholesale.
2. **S12-06 `voice-persona`** — closes the CE epic. Covers `card.type === 'voice'` atoms (Dashy voice-mode cards where the kid reads aloud). This is the skill where the canonical Dashy character prompt finally lives — cross-referenced by the S12-17 Dashy voice-consistency audit.
3. **S12-09 Dev Console — content authoring surface** — once all three skills are in place, the Author Lesson tab lands and the touch-test loop becomes real.

---

## Cross-references

- Sprint 12 tracker: [docs/SPRINT-12-tracker.md](../SPRINT-12-tracker.md)
- Skill-engine kickoff: [docs/sprint-runs/S10-skill-engine-kickoff.md](./S10-skill-engine-kickoff.md)
- Prior skill runs: [S10-06 story-writer](./S10-skill-engine-s10-06.md), [S10-07 quiz-maker](./S10-skill-engine-s10-07.md), [S10-12 orchestrator + retry](./S10-skill-engine-s10-12.md)
- Engine source: `src/Backend/src/services/skills/{types,loader,progression,registry}.ts`
- Validator registry: `src/Backend/src/services/skills/validators/{index,experimentDesigner}.ts`
- Experiment-designer definition: `src/Backend/src/services/skills/defs/experiment-designer/*`
- Router wiring: `src/Backend/src/services/pipeline/skillRouter.ts` (input assembly lines 628–641, card assembly lines 706–734)
- Tests: `src/Backend/tests/{experimentDesignerValidator,experimentDesignerRouter,skillEngine}.test.ts`
- iOS consumer (unchanged): `src/Apps/NovaKids/Sources/Views/Cards/ExperimentCardView.swift`
