# S10-06 — Skill Engine + `story-writer` Run Summary

**Sprint:** Sprint 10 — "The Brain"
**Story:** S10-06 `story-writer` skill with age profiles (13 pts)
**Landed:** April 18, 2026
**Status:** ✅ Shipped. All code, tests, and Dev Console surfaces merged. Awaiting bang's Mac-side runtime walkthrough.

This document is the **delivery run summary and Mac-side runbook** for S10-06. It assumes the spike (`docs/design-spikes/S10-06-07-skill-loader.md`) and S10-11 Kickoff block in the tracker have been read. The tracker entry (`docs/SPRINT-10-tracker.md` → "S10-06 Delivery Notes") is the authoritative per-file changelog; this doc is the **validation matrix + operator recipe** bang walks through in the Dev Console to confirm the skill engine behaves as specified across the age × progression × difficulty cube.

---

## What shipped

Seven-file bundle in three directories plus the Dev Console surface:

- `src/services/skills/{types,loader,progression,registry}.ts` — engine core.
- `src/services/skills/defs/story-writer/{manifest.json, prompt.md, styles.md, topics.md, age-profiles/{4,6,8}.md}` — the first real skill.
- `src/services/skills/defs/_shared/progressionModifier.hbs` — the sliding-scale nudge partial, shared across every future skill.
- `src/routes/devSkills.ts` — four dev endpoints (`GET /dev/skills`, `GET /dev/skills/:name`, `POST /dev/skills/:name/render`, `POST /dev/skills/:name/reload`).
- `src/server.ts` — boot-time eager load (`await getSkillRegistry().load()`).
- `public/dev-pipeline.html` — **Skills** tab with picker, manifest readout, inputs JSON editor, age / progression Δ / difficulty / interest / parent-avoid controls, 8-cell meta grid, system/user prompt panes, progression-breakdown readout, hot-reload button.
- `tests/skillEngine.test.ts` (21 cases) + `tests/devSkills.test.ts` (20 cases).

Zero schema changes. Zero new migrations. Zero new env vars. The `handlebars@4.7.9` dep was added to `package.json`; `npm install` picks it up.

---

## Quick-start runbook (bang's Mac)

```bash
cd ~/Projects/Novai/src/Backend

# 1. Install Handlebars (new dep, lockfile already bumped)
npm install

# 2. Regenerate Prisma client. No schema changes for S10-06, but S10-04/05 may
#    still need generate on a fresh clone.
npx prisma generate

# 3. Run the two new test suites (should complete in <1s total)
npx vitest run tests/skillEngine.test.ts tests/devSkills.test.ts
# expect: 21 + 20 = 41 passing, 0 failing

# 4. Boot the server. A broken manifest / template will fail HERE, not at
#    first LLM call — this is the whole point of decision #4.
npm run dev
# expect: "Server is running at http://0.0.0.0:3000" and no "SkillRegistry load failed" errors.

# 5. Open the Dev Console Skills tab
#    → http://localhost:3000/dev/dev-pipeline.html#skills
```

If `npm run dev` logs a SkillRegistry error, the boot order is:

1. Prisma → `initializeFlags()` → **`getSkillRegistry().load()`** → `fastify.listen`.

A registry error stops the process before `listen`, so the port stays free and there's no half-up server. The error message will name the offending file (`defs/<skill>/<file>.md` or `manifest.json`) and the Zod / Handlebars failure path.

---

## Validation matrix

The matrix below is what to click through in the Dev Console Skills tab to prove the sliding-scale age resolution and the difficulty curve both work end-to-end. Every cell is also covered by at least one unit test or HTTP integration test — the matrix is for operator smoke, not regression coverage.

**Controls:** `mode = synthetic`, `skill = story-writer`, `inputs = { "topic": "how seeds grow" }`, `interestTopics = "plants, science"`, `parentAvoid = ""`. Only the three bolded knobs vary.

| # | `ageYears` | `progressionDelta` | `difficultyOffset` | Expected `meta.ageProfileUsed` | Expected `context.effectiveAgeYears` | Expected difficulty curve | Notes |
|---|-----------:|-------------------:|-------------------:|-------------------------------:|-------------------------------------:|:--------------------------|:------|
| 1 | 4 | 0.0 | 0 | **4** | 4.0 | medium | Baseline — youngest anchor. Story paragraphs ≤80 words, no metaphor, concrete nouns only. |
| 2 | 4 | +1.0 | 0 | **4** (rounds down at tie) | 5.0 | medium | Still on age-4 profile but `progressionModifier` renders the "above" nudge → allow one stretch term. |
| 3 | 4 | +1.5 | +2 | **6** | 5.5 | hard | Crosses the 4↔6 midpoint (5.0). Difficulty +2 → more structured reflection questions. |
| 4 | 6 | 0.0 | 0 | **6** | 6.0 | medium | Middle anchor. 10-word sentences, simple simile, 120-word paragraphs. |
| 5 | 6 | -1.5 | -2 | **4** (ties-round-down hits 4.5 → 4) | 4.5 | easy | Struggling child on a hard day — scaffolded prompt, soften vocabulary. |
| 6 | 6 | +1.2 | +1 | **8** (crosses 7.0 midpoint) | 7.2 | hard | Advanced child. `progressionModifier` "above" branch fires. |
| 7 | 7 | +1.2 | 0 | **8** | 8.2 | medium | **Primary test-locked cell.** `devSkills.test.ts` explicitly verifies `ageProfileUsed === 8` AND `effectiveAgeYears > 8`. |
| 8 | 8 | 0.0 | -1 | **8** | 8.0 | easy | Oldest anchor, baseline progression, easier difficulty. Compound sentences OK, slower cause-effect chains. |
| 9 | 8 | +1.5 | +2 | **8** (clamps at effectiveAge ≤ 18, no anchor beyond 8) | 9.5 | hard | Stretch case — effective age extends past the oldest anchor. Profile 8 holds; `progressionModifier` "above" adds one advanced vocab term and one longer sentence. Matches spike intent: the LLM interpolates past the anchor without a new MD file. |

**Edge behavior to spot-check:**

- **Cell 2** proves the sliding-scale's _ties-round-down_ rule: an effective age of 5.0 is equidistant from anchors 4 and 6; we land on 4 to avoid over-stretching a 4-year-old.
- **Cell 5** confirms _negative_ progressionDelta can cross a profile boundary in the other direction.
- **Cell 7** is the locked contract — the integration test in `tests/devSkills.test.ts` asserts it and will fail CI if the resolver drifts.
- **Cell 9** proves the "above" path doesn't require an age-10 profile to exist. If we ever add one, it fires at effectiveAge ≥ 9.0.

After clicking through all nine, open one render response's **Progression Breakdown** panel and confirm the per-signal rows (`mastery`, `quizWinRate`, `flow`, `frustration`, `parentOffset`) sum to the `progressionDelta` total within 0.001. The breakdown is what the Strategy tab will show once S10-12 wires the skill engine into the pipeline.

---

## curl cheat sheet

Grab your auth token from the Dev Console's **Session** tab (or any prior request's `Authorization` header) and export:

```bash
TOKEN="<paste Bearer token>"
BASE="http://localhost:3000/api/v1"
```

### List skills

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills" | jq '.data'
# expect: array with one entry, name: "story-writer", ageProfiles: [4,6,8],
#         difficulties: ["easy","medium","hard"], handlesConceptTypes length 6
```

### Fetch a single manifest

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills/story-writer" | jq '.data'
# expect: full manifest + computed inputs schema

curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills/nope-not-a-real-skill" -w '\n%{http_code}\n'
# expect: 404
```

### Dry-run render (synthetic — no DB lookup)

```bash
# Cell 7 — age 7 + progressionDelta +1.2 → profile 8, effectiveAge > 8
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/story-writer/render" \
  -d '{
    "inputs": { "topic": "how seeds grow" },
    "ctxOverrides": {
      "ageYears": 7,
      "progressionDelta": 1.2,
      "difficultyOffset": 0,
      "interestTopics": ["plants", "science"]
    },
    "includeProgressionBreakdown": true
  }' | jq '{ageProfileUsed: .data.meta.ageProfileUsed, effectiveAge: .data.context.effectiveAgeYears, delta: .data.progressionBreakdown.totalDelta, systemHead: (.data.system | .[0:200])}'
# expect: ageProfileUsed: 8, effectiveAge: 8.2, delta ≈ 1.2, systemHead contains "age-8 profile" cues
```

### Dry-run with parent avoidance

```bash
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/story-writer/render" \
  -d '{
    "inputs": { "topic": "what happens in a storm" },
    "ctxOverrides": {
      "ageYears": 6,
      "progressionDelta": 0,
      "difficultyOffset": 0,
      "parentGuidance": { "topicAvoid": ["monsters", "thunderstorms"] }
    }
  }' | jq '.data.system' | grep -iE 'monsters|thunderstorms'
# expect: both terms echoed in the system prompt's "Topics to avoid" line
```

### Strict-schema rejection

```bash
# Unknown key → 400
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/story-writer/render" \
  -d '{ "inputs": {"topic":"x"}, "ctxOverrides": {}, "extraHackField": true }' -w '\n%{http_code}\n'
# expect: 400

# Out-of-range progressionDelta → 400
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/story-writer/render" \
  -d '{ "inputs": {"topic":"x"}, "ctxOverrides": { "progressionDelta": 5 } }' -w '\n%{http_code}\n'
# expect: 400

# Missing required input → 400 with "topic" in the message
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/story-writer/render" \
  -d '{ "inputs": {}, "ctxOverrides": {} }'
# expect: 400, message matches /topic|required/i
```

### Hot reload (dev-only)

```bash
# In development:
curl -s -XPOST -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills/story-writer/reload" | jq '.data'
# expect: { reloaded: "story-writer", at: "<iso timestamp>" }

# Simulate production lockdown (from a separate shell, before starting the server):
# NODE_ENV=production npm start
# curl -s -XPOST ... /reload -w '\n%{http_code}\n' → 403
```

### Real-child render

Pick a childId from the Dev Console's child picker or `GET /api/v1/children`, then:

```bash
CHILD="<child-uuid>"

curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/story-writer/render" \
  -d "{
    \"inputs\": { \"topic\": \"how bees make honey\" },
    \"childId\": \"$CHILD\",
    \"ctxOverrides\": { \"difficultyOffset\": 0 },
    \"includeProgressionBreakdown\": true
  }" | jq '{
    ageProfileUsed: .data.meta.ageProfileUsed,
    effectiveAge: .data.context.effectiveAgeYears,
    interestTopics: .data.context.interestTopics,
    modality: .data.context.teachingStrategy.modality,
    progression: .data.progressionBreakdown
  }'
# expect: ageProfileUsed drawn from child's real birthDate + computed progressionDelta,
#         interestTopics pulled from ParentGuidance.extractedTopics (or [] pre-S10-07),
#         modality inferred from engagement profile's top card type.
```

---

## Dev Console Skills tab — operator walkthrough

Open `http://localhost:3000/dev/dev-pipeline.html#skills`. The tab should load immediately (the URL hash triggers `switchTab('skills')` → `NovaDevConsole.loadSkills()`).

**Panels:**

1. **Skill picker** (top left) — dropdown listing every manifest the registry loaded. Default: first skill alphabetically (`story-writer`).
2. **Manifest readout** — shows `name`, `version`, `modelHint`, `temperatureHint`, `ageProfiles`, `difficulties`, `handlesConceptTypes`, and the computed inputs schema.
3. **Mode selector** — `synthetic` (construct a baseline `ChildContext` from the sliders) or `realChild` (use `STATE.childId` from the top-of-page child picker).
4. **Inputs JSON** (textarea) — pre-seeded with `{ "topic": "how seeds grow" }` when `story-writer` is selected. Invalid JSON displays an inline error and disables the Render button.
5. **Context override sliders:**
   - `ageYears` (number, 2..18)
   - `progressionDelta` (range, -1.5..+1.5, step 0.1)
   - `difficultyOffset` (range, -2..+2, step 1)
   - `interestTopics` (CSV textarea)
   - `parentAvoid` (CSV textarea)
6. **Render dry-run** button → POST to `/dev/skills/story-writer/render`.
7. **Meta grid** (8 cells) — `ageProfileUsed`, `effectiveAgeYears`, `progressionDelta`, `difficultyOffset`, `modelHint`, `temperatureHint`, `version`, `childId` (or "(synthetic)").
8. **System prompt pane** + **User prompt pane** — `<pre>` blocks, max-height 420px, scrollable.
9. **Progression Breakdown panel** — five rows (`mastery`, `quizWinRate`, `flow`, `frustration`, `parentOffset`) with per-signal `value` / `contribution` columns, plus a totals row that must equal `progressionDelta` within 0.001.
10. **Raw JSON pane** — the full render response for debugging.
11. **Hot reload** button → POST to `/dev/skills/story-writer/reload`. On success, refetches `GET /dev/skills` and re-renders the picker, preserving selection.

**Walkthrough bang should run on the Mac once the server is up:**

1. Select `story-writer`. Confirm manifest readout shows `ageProfiles: [4,6,8]` and `modelHint: flash`.
2. Leave mode on `synthetic`. Leave inputs default. Click **Render dry-run**.
3. Verify the meta grid: `ageProfileUsed = 6`, `effectiveAgeYears = 6.0`, `difficultyOffset = 0`, `modelHint = flash`.
4. Scroll the system pane — confirm it references "age-6 profile" cues (simple simile, 10-word sentences, 120-word paragraphs).
5. Drag `progressionDelta` slider to `+1.2`, change `ageYears` to `7`, click **Render**. Meta grid now shows `ageProfileUsed = 8`, `effectiveAgeYears = 8.2`. System pane now references "age-8 profile".
6. Add `monsters, thunderstorms` to `parentAvoid`. Click **Render**. Scroll system pane — the "Topics to avoid" line should list both.
7. Flip mode to `realChild`. If no child is picked, hit the top-of-page child picker and choose one. Click **Render**. The meta grid's `childId` should populate and the `effectiveAgeYears` / `interestTopics` / modality should reflect real child data.
8. Click **Hot reload**. The meta timestamp refreshes; no page reload occurs.

All eight steps complete without an error toast → S10-06 is green on the Mac.

---

## Known follow-ups (out of scope for this run)

1. **Option A for `interestTopics` extraction.** Land the `ParentGuidance.extractedTopics` column + `PUT /children/:id/guidance` post-commit hook. Scheduled with the first downstream skill that actually _needs_ extracted topics (S10-07 quiz-maker or S10-09 curriculum-architect, whichever lands first).
2. **Story-writer output validation.** Per spike decision #3 ("per-skill Zod co-located with each skill's definition"), the story-writer skill will grow a `validators.ts` that Zod-checks the LLM response (`{ title, paragraphs[3], reflectionQuestions[2] }`). Not needed for S10-06's DoD (the skill engine's acceptance is "render a valid prompt"); needed for S10-12 when the pipeline consumes the skill's output.
3. **Pipeline integration (S10-12).** `buildChildContext(childId, conceptType, difficultyOffset)` + ranked-card-type loop + per-card-type skill invocation. The skill engine is ready; S10-12 is the caller.
4. **Quality gate coupling.** `runQualityGate` will get a skill-aware mode that knows to check against the skill's declared `handlesConceptTypes` and `ageProfiles`. Same sprint (S10-12).

---

## Sources

- Sprint 10 tracker: [docs/SPRINT-10-tracker.md](../SPRINT-10-tracker.md)
- Spike: [docs/design-spikes/S10-06-07-skill-loader.md](../design-spikes/S10-06-07-skill-loader.md)
- Kickoff run summary: [docs/sprint-runs/S10-skill-engine-kickoff.md](./S10-skill-engine-kickoff.md)
- Engine source: `src/Backend/src/services/skills/{types,loader,progression,registry}.ts`
- Story-writer definition: `src/Backend/src/services/skills/defs/story-writer/*`
- Dev endpoints: `src/Backend/src/routes/devSkills.ts`
- Dev Console: `src/Backend/public/dev-pipeline.html` → "Skills" tab
- Tests: `src/Backend/tests/skillEngine.test.ts`, `src/Backend/tests/devSkills.test.ts`
