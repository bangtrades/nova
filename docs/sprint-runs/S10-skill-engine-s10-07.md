# S10-07 — `quiz-maker` Skill + Validator Run Summary

**Sprint:** Sprint 10 — "The Brain"
**Story:** S10-07 `quiz-maker` skill with difficulty curves (13 pts)
**Landed:** April 18, 2026
**Status:** ✅ Shipped. Engine content, Zod validator, Dev Console polish, and tests all merged. Awaiting bang's Mac-side runtime walkthrough.

This document is the **delivery run summary and Mac-side runbook** for S10-07. It is the follow-on to [S10-skill-engine-s10-06.md](./S10-skill-engine-s10-06.md) — that run landed the Handlebars engine and the `story-writer` skill; this run drops the second skill onto the same engine, adds per-skill Zod output validation, and upgrades the Dev Console Skills tab to drive both skills end-to-end. The tracker entry (`docs/SPRINT-10-tracker.md` → "S10-07 Delivery Notes") is the authoritative per-file changelog; this doc is the **validation matrix + operator recipe** bang walks through in the Dev Console to confirm the `quiz-maker` skill and the modality / concept-type / validator surface behave as specified.

---

## What shipped

Eleven new content files under `defs/quiz-maker/`, one new shared partial, a 2-file validator registry, the loader's static-import refactor, the Dev Console polish, and three test files' worth of coverage.

- `src/services/skills/defs/quiz-maker/{manifest.json, prompt.md, styles.md, distractors.md, age-profiles/{4,6,8}.md, difficulty-curves/{easy,medium,hard}.md}` — the second real skill.
- `src/services/skills/defs/_shared/modalityNote.hbs` — 4-branch modality partial shared across every future skill.
- `src/services/skills/validators/{index.ts, quizMaker.ts}` — static name-keyed registry + the quiz-maker output schema (strict `.object(...).strict().superRefine(...)`).
- `src/services/skills/loader.ts` — one-function refactor: dynamic `require('./validators')` → static top-level `import { SKILL_OUTPUT_SCHEMAS }`. Fixes vite-node incompatibility.
- `src/routes/devSkills.ts` — `ctxOverrides` gains `modality` + `conceptType` enums; response payloads expose `hasOutputSchema`.
- `public/dev-pipeline.html` — Skills tab gets a modality/concept-type dial row, validator chip, per-skill Re-seed button, validator row badge, and two new meta cells (validator / opts).
- `tests/quizMakerValidator.test.ts` (24 new cases), additions to `tests/skillEngine.test.ts` (+13 cases), additions to `tests/devSkills.test.ts` (+6 cases).

Zero schema changes. Zero new migrations. Zero new env vars. Zero new npm deps.

---

## Quick-start runbook (bang's Mac)

```bash
cd ~/Projects/Novai/src/Backend

# 1. Pull. No new deps, no new migrations.
git pull

# 2. Run the three relevant suites (should complete in ~2s total)
npx vitest run tests/skillEngine.test.ts tests/quizMakerValidator.test.ts tests/devSkills.test.ts
#   expect: 84 passing / 1 pre-existing flaky (Prisma SQLite "disk I/O error" on
#   tests/devSkills.test.ts:292 — unrelated to S10-07, carried from S10-06).

# 3. Full suite sanity pass
npm test

# 4. Boot the server — the registry is now loading TWO skills.
npm run dev
#   expect log: "SkillRegistry loaded: quiz-maker v0.1.0, story-writer v0.1.0"

# 5. Open the Dev Console Skills tab
#    → http://localhost:3000/dev/dev-pipeline.html#skills
```

If boot fails with a SkillRegistry error, the error message will name the file (`defs/quiz-maker/<file>` or `validators/quizMaker.ts`) and the Zod / Handlebars failure path.

---

## Validation matrix

The matrix below proves (a) the difficulty-curve option-count ladder (easy=3, medium=4, hard=5), (b) the modality partial's 3-way branching, (c) the age-profile cascade still works on a second skill, and (d) the output-validator chip reflects the registry. Every cell is either covered by an automated test OR sits on a sliding scale where the matrix itself is the smoke check.

**Controls:** `mode = synthetic`, `skill = quiz-maker`, `inputs = {"concept": "helium balloons float because they are lighter than air", "conceptType": "causeEffect"}`. Only the bolded knobs vary per row.

| # | `ageYears` | `progressionΔ` | `difficultyOffset` | `modality` | Expected `meta.ageProfileUsed` | Expected `meta.difficultyUsed` | Expected option count | System-prompt marker |
|---|-----------:|---------------:|-------------------:|:-----------|-------------------------------:|:-------------------------------|----------------------:|:---------------------|
| 1 | 6 | 0.0 | 0 | auditory | **6** | medium | **4** | `/exactly 4/`, `/sound and rhythm/` |
| 2 | 6 | 0.0 | -2 | auditory | **6** | easy | **3** | `/exactly 3/` |
| 3 | 6 | 0.0 | +2 | auditory | **6** | hard | **5** | `/exactly 5/` |
| 4 | 6 | 0.0 | 0 | visual | **6** | medium | **4** | `/shown/` |
| 5 | 6 | 0.0 | 0 | kinesthetic | **6** | medium | **4** | `/action/` |
| 6 | 4 | 0.0 | 0 | visual | **4** | medium | **4** | age-4 stem ceiling visible |
| 7 | 7 | +1.2 | 0 | auditory | **8** | medium | **4** | age-8 compound stem OK |
| 8 | 8 | -1.5 | -2 | kinesthetic | **6** (ties-round-down 6.5→6) | easy | **3** | struggle nudge + action framing |
| 9 | 8 | +1.5 | +2 | visual | **8** (clamped, no age-10) | hard | **5** | above nudge + visual scene |

**Edge behavior to spot-check:**

- **Cell 1** is the test-locked default: the engine test asserts `/exactly 4/` on a medium-curve render and the dev-route test asserts the same response structure.
- **Cells 2–3** are the difficulty-curve locks. Both asserted by automated tests. On the UI, the `opts (expected)` meta cell must read `3` / `5` respectively.
- **Cells 4–5** prove the shared `modalityNote.hbs` partial routes correctly. Each modality keyword (`shown` / `sound and rhythm` / `action`) is asserted by the engine tests.
- **Cell 6** proves the age-4 profile still applies when `conceptType` is `causeEffect` — age-gating is layered, not mutually exclusive.
- **Cell 7** matches the story-writer cell 7 test — `ageYears: 7 + progressionDelta: 1.2` → profile 8, `effectiveAge > 8`. The S10-06 resolver is unchanged; this cell confirms it still works on a different skill.
- **Cell 8** is the ties-round-down case in the negative direction: effective age 6.5 → profile 6.
- **Cell 9** proves the above-anchor clamp holds: effective age 9.5 stays on profile 8 with the "above" modifier branch.

After clicking through, open one response's **Raw JSON** pane and confirm:

1. `data.meta.temperatureHint === 0.4` (quiz-maker is tighter than story-writer's 0.8).
2. `data.meta.modelHint === 'flash'`.
3. `data.context.teachingStrategy.modality` reflects the select.
4. `data.context.teachingStrategy.conceptType` reflects the select (or falls back to `"abstract"`).
5. The system prompt's ending output-contract block mentions the `question`, `options`, `correctIndex`, `rationalePerOption`, and `explanation` fields and explicitly bans `"all of the above"` / `"none of the above"`.

---

## curl cheat sheet

Grab an auth token from the Dev Console's **Session** tab (or any prior request's `Authorization` header) and export:

```bash
TOKEN="<paste Bearer token>"
BASE="http://localhost:3000/api/v1"
```

### List skills — validator surface

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills" | jq '.data[] | {name, version, modelHint, hasOutputSchema, difficulties, ageProfiles}'
# expect: two entries.
#   quiz-maker:   hasOutputSchema=true,  difficulties=["easy","medium","hard"], ageProfiles=[4,6,8]
#   story-writer: hasOutputSchema=false, difficulties=["easy","medium","hard"], ageProfiles=[4,6,8]
```

### Fetch the quiz-maker manifest

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills/quiz-maker" | jq '.data'
# expect: name=quiz-maker, temperatureHint=0.4, handlesConceptTypes covers all 6 S10-11 types,
#         inputs.requires=["concept","conceptType"], hasOutputSchema=true
```

### Dry-run render — medium curve (default)

```bash
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/quiz-maker/render" \
  -d '{
    "inputs": {
      "concept": "helium balloons float because they are lighter than air",
      "conceptType": "causeEffect"
    },
    "ctxOverrides": {
      "ageYears": 6,
      "progressionDelta": 0,
      "difficultyOffset": 0,
      "modality": "auditory"
    }
  }' | jq '{
    difficultyUsed: .data.meta.difficultyUsed,
    ageProfileUsed: .data.meta.ageProfileUsed,
    temperatureHint: .data.meta.temperatureHint,
    modality: .data.context.teachingStrategy.modality,
    systemHasExactly4: (.data.system | contains("exactly 4")),
    systemHasRhythm: (.data.system | contains("sound and rhythm"))
  }'
# expect: {difficultyUsed:"medium", ageProfileUsed:6, temperatureHint:0.4, modality:"auditory",
#          systemHasExactly4:true, systemHasRhythm:true}
```

### Difficulty boundaries — easy (3 options) and hard (5 options)

```bash
# Easy — 3 options
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/quiz-maker/render" \
  -d '{
    "inputs": { "concept": "water boils when heated", "conceptType": "causeEffect" },
    "ctxOverrides": { "difficultyOffset": -2 }
  }' | jq '{diff: .data.meta.difficultyUsed, hasThree: (.data.system | contains("exactly 3"))}'
# expect: {diff:"easy", hasThree:true}

# Hard — 5 options
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/quiz-maker/render" \
  -d '{
    "inputs": { "concept": "water boils when heated", "conceptType": "causeEffect" },
    "ctxOverrides": { "difficultyOffset": 2 }
  }' | jq '{diff: .data.meta.difficultyUsed, hasFive: (.data.system | contains("exactly 5"))}'
# expect: {diff:"hard", hasFive:true}
```

### Modality matrix

```bash
for M in visual auditory kinesthetic; do
  echo "=== $M ==="
  curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "$BASE/dev/skills/quiz-maker/render" \
    -d "{
      \"inputs\": { \"concept\": \"gravity pulls things down\", \"conceptType\": \"causeEffect\" },
      \"ctxOverrides\": { \"modality\": \"$M\" }
    }" | jq '.data.system' | grep -iE 'shown|sound and rhythm|action' | head -3
done
# expect: visual prints a line containing "shown", auditory prints "sound and rhythm",
#         kinesthetic prints "action".
```

### Strict-schema rejection

```bash
# Missing required input → 400
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/quiz-maker/render" \
  -d '{ "inputs": { "concept": "x" } }' -w '\n%{http_code}\n'
# expect: 400 (missing "conceptType")

# Unknown enum value → 400
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/quiz-maker/render" \
  -d '{
    "inputs": { "concept": "x", "conceptType": "causeEffect" },
    "ctxOverrides": { "modality": "olfactory" }
  }' -w '\n%{http_code}\n'
# expect: 400 (modality enum mismatch)

# Unknown ctxOverrides key → 400
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/quiz-maker/render" \
  -d '{
    "inputs": { "concept": "x", "conceptType": "causeEffect" },
    "ctxOverrides": { "hackField": 1 }
  }' -w '\n%{http_code}\n'
# expect: 400
```

### Hot reload (dev-only)

```bash
curl -s -XPOST -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills/quiz-maker/reload" | jq '.data'
# expect: { reloaded: "quiz-maker", at: "<iso timestamp>" }
```

### Validator sanity — run the Zod schema directly

From a REPL or tsx script:

```ts
import { quizMakerOutputSchema } from './src/services/skills/validators/quizMaker';

// Happy path — medium curve
quizMakerOutputSchema.parse({
  question: 'Why does a helium balloon float up?',
  options: [
    'helium is lighter than the surrounding air',
    'helium is heavier than the air',
    'the balloon is full of water',
    'the string pulls it up',
  ],
  correctIndex: 0,
  rationalePerOption: [
    'correct — density difference pushes the balloon up',
    'backwards — if it were heavier, it would sink',
    'category error — water would make it sink',
    'reversed-cause — the string does not create lift',
  ],
  explanation: 'Helium is less dense than air, so the surrounding air pushes the balloon upward (buoyancy).',
});
// => no throw

// Should throw — "all of the above" banned
quizMakerOutputSchema.parse({
  question: 'Q',
  options: ['a', 'b', 'All of the above'],
  correctIndex: 2,
  rationalePerOption: ['r1', 'r2', 'r3'],
  explanation: 'e',
});
// => ZodError: options cannot contain "all of the above" ... (offending indices: 2)
```

---

## Dev Console Skills tab — new controls walkthrough

Open `http://localhost:3000/dev/dev-pipeline.html#skills`. The tab now lists **two** skills; quiz-maker's list row shows a green `val` badge (validator attached).

**New panels / controls added in this run:**

1. **Modality dropdown** (`#skillsModality`) — blank / visual / auditory / kinesthetic. Blank = let the route default to `auditory`. Threaded into `ctxOverrides.modality`.
2. **Concept type dropdown** (`#skillsConceptType`) — blank / vocabulary / abstract / process / comparison / causeEffect / factual. Blank = let the route default to `abstract`. Threaded into `ctxOverrides.conceptType`.
3. **Validator chip** (`#skillsValidatorChip`) — green `✓ attached` for `quiz-maker`, muted `none` for `story-writer`. Updated on every skill selection.
4. **Re-seed button** (`#skillsReseedBtn`) — overwrites the inputs JSON textarea with the canonical template for the selected skill. Per-skill templates:
   - `story-writer` → `{"topic": "how seeds grow"}`
   - `quiz-maker` → `{"concept": "helium balloons float because they are lighter than air", "conceptType": "causeEffect"}`
   - Fallback → `{[req]: ""}` for each `rec.inputs.requires`
5. **Render meta — `validator` cell** — mirrors the chip.
6. **Render meta — `opts (expected)` cell** — derived from `meta.difficultyUsed`: `easy=3 · medium=4 · hard=5 · else=—`. Only populated for `quiz-maker`.

**Walkthrough bang should run on the Mac once the server is up:**

1. Open `#skills`. Confirm the list shows **two** entries; `quiz-maker` row has the green `val` badge; `story-writer` does not.
2. Pick `quiz-maker`. Validator chip reads `✓ attached`. Inputs textarea auto-seeds with the concept + conceptType template.
3. Leave all knobs at defaults. Click **Render dry-run**. Meta grid shows: `ageProfileUsed=6, difficultyUsed=medium, validator=✓ attached, opts=4, temperatureHint=0.4`. System pane contains `"exactly 4 options"` and a modality note mentioning `"sound and rhythm"` (auditory default).
4. Drag `difficultyOffset` to `-2`. Render. Meta reads `difficultyUsed=easy, opts=3`. System pane contains `"exactly 3 options"`.
5. Drag `difficultyOffset` to `+2`. Render. Meta reads `difficultyUsed=hard, opts=5`. System pane contains `"exactly 5 options"`.
6. Reset offset to `0`. Set `modality = visual`. Render. System pane contains `"shown"`.
7. Set `modality = kinesthetic`. Render. System pane contains `"action"`.
8. Click **Re-seed inputs for selected skill**. Textarea overwrites with the quiz-maker template (destructive, by design).
9. Switch picker to `story-writer`. Validator chip flips to muted `none`. Inputs textarea seeds with `{"topic":"how seeds grow"}` if empty. Render. Meta's `validator` cell reads `none`, `opts` cell reads `—`.
10. Switch back to `quiz-maker`. Click **Hot reload**. Status flashes `✓ reloaded quiz-maker @ <timestamp>`. Selection preserved.

All ten steps complete without an error toast → S10-07 is green on the Mac.

---

## Known follow-ups (out of scope for this run)

1. **Pipeline integration (S10-12).** `buildChildContext(childId, conceptType, difficultyOffset)` + ranked-card-type loop invokes the quiz-maker skill for any concept whose rank list has `quiz` in the top slot. Schema-validation calls `quizMakerOutputSchema.safeParse(llmJson)` and re-prompts on failure, up to N retries. Not needed for S10-07's DoD (the skill renders + the validator exists); needed for S10-12 when the pipeline consumes the skill.
2. **Validator error re-prompt layer.** A thin helper that translates `ZodError.issues` into a short corrective message for the retry prompt (e.g. `"options must be exactly 4 entries — you returned 3"` → "Return a valid MCQ with EXACTLY 4 options…"). Scheduled with S10-12.
3. **`experiment-designer` and `voice-persona` Zod schemas** (S10-08 / S10-10). Both will add `.ts` files under `validators/` and one line to `SKILL_OUTPUT_SCHEMAS`.
4. **Interest-topic extraction (Option A).** Still deferred from S10-06. `ParentGuidance.extractedTopics` column + `PUT /children/:id/guidance` post-commit hook. S10-09 `curriculum-architect` will force the issue.
5. **`difficultyOffset` in `ctxOverrides` + `body.childId` path.** When the real-child render path is used, `childId → progressionDelta → effectiveAge` flows through. The `modality` / `conceptType` overrides still win against child-derived defaults. This should be documented in the S10-12 pipeline runbook.

---

## Sources

- Sprint 10 tracker: [docs/SPRINT-10-tracker.md](../SPRINT-10-tracker.md)
- Spike: [docs/design-spikes/S10-06-07-skill-loader.md](../design-spikes/S10-06-07-skill-loader.md)
- Prior run summary (engine + story-writer): [docs/sprint-runs/S10-skill-engine-s10-06.md](./S10-skill-engine-s10-06.md)
- Engine source: `src/Backend/src/services/skills/{types,loader,progression,registry}.ts`
- Validator registry: `src/Backend/src/services/skills/validators/{index,quizMaker}.ts`
- Quiz-maker definition: `src/Backend/src/services/skills/defs/quiz-maker/*`
- Shared modality partial: `src/Backend/src/services/skills/defs/_shared/modalityNote.hbs`
- Dev endpoints: `src/Backend/src/routes/devSkills.ts`
- Dev Console: `src/Backend/public/dev-pipeline.html` → "Skills" tab
- Tests: `src/Backend/tests/quizMakerValidator.test.ts`, `src/Backend/tests/skillEngine.test.ts`, `src/Backend/tests/devSkills.test.ts`
