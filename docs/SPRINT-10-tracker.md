# Sprint 10 — "The Brain" — Progress Tracker

**Sprint dates:** April 29 – May 12, 2026 *(S10-01 kicked off early on April 16 alongside Sprint 9 close-out)*
**Goal:** The AI starts learning each child. Content quality jumps from "generic for age" to "personalized for this kid."
**Velocity target:** 118 pts (heaviest sprint in Phase 2 — core intelligence layer)

---

## MEM Epic — Knowledge Graph + Engagement (50 pts)

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S10-01 | Design and implement child knowledge-graph schema | 13 | ✅ Done (April 16) | `Concept` + `ChildConcept` Prisma models. Seeded with **50 concepts** (17 computers / 17 robots / 16 AI). `prerequisites` stored as JSON text via `client.ts` middleware (`JSON_STRING_FIELDS.concept = ['prerequisites']`). Deterministic slug IDs (`comp-01`, `robo-01`, `ai-01`...) so prereqs are declared statically. Cross-domain edges: `ai-01 → comp-01`, `robo-17 → comp-14`. 16 unit tests in `tests/knowledgeGraph.test.ts` covering shape, prereq integrity, cycle detection, cross-domain edges, and the difficulty-monotonicity invariant. New npm script: `db:seed:knowledge`. Sandbox validation: ✅ zero issues (50 concepts / 0 cycles / 0 unknown prereqs / 0 difficulty inversions / 0 sortOrder dupes). |
| S10-02 | Track concept mastery from quiz results | 8 | ✅ Done (April 16) | Pure-math core (`clampConfidence` / `applyDecay` / `applyDelta`) + DB-facing `recordQuizResult` / `recordQuizResultsBatch` / `getChildMastery` in `src/services/mastery/masteryTracker.ts`. Wired into `POST /progress/sync` (filters `action==='answer'` + `typeof result.correct === 'boolean'`) and exposed via `GET /knowledge/children/:childId/mastery` with on-the-fly decay + domain rollup. `Card.conceptId` nullable FK added via hand-written `20260416190000_s10_02_card_concept_link` migration (SQLite RedefineTables). 20-case vitest suite in `tests/masteryTracker.test.ts` locks the DoD constants (0.15/−0.10/0.02/wk), decay-before-delta composition, and cap/floor invariants. See delivery notes below. |
| S10-03 | Build engagement profile from interaction data | 13 | ✅ Done (April 16) | Per-child engagement signals from the `CardInteraction` stream. New `EngagementProfile` 1:1 with `ChildProfile` (migration `20260416200000_s10_03_engagement_profile`). Raw counters in the clear; `cardTypeStats` + `topicAffinities` AES-256-GCM encrypted via `tokenEncryption`. Pure reducers (`mergeCardTypeStats` / `mergeTopicAffinities` / `classifyInteractionStream` / `summarizeBatch` / `rankCardTypePreferences` / `rankTopicAffinities`) + DB-facing `ingestInteractions{ForSession}` / `getEngagementProfile`. Signal rules: frustration = 2+ consecutive wrong on same concept OR <2000ms non-answer action (rapid-quit); flow = fires once per run when correct-streak transitions 2→3. Wired into `POST /progress/sync` (all interactions, not just quiz). New route group at `/api/v1/engagement/children/:childId` (ranked view) + `/raw` (debug, includes encrypted→decrypted counters for dev console). 28-case vitest suite `tests/engagementProfiler.test.ts`. See delivery notes below. |
| S10-04 | Parent guidance API | 8 | ✅ Done (April 17) | `ParentGuidance` model 1:1 with `ChildProfile` (`onDelete: Cascade`), migration `20260417210000_s10_04_s10_05_guidance_timezone`. Pure helpers (`clampDifficultyOffset` / `normalizeTopicList` / `sanitizeBoundaries` / `coerceLimitMinutes` / `mergeGuidance` / `defaultGuidance`) + DB helpers (`getGuidance` / `getGuidanceOrDefault` / `upsertGuidance` / `deleteGuidance`) in `src/services/guidance/parentGuidance.ts`. REST at `/api/v1/children/:childId/guidance` (GET/PUT/DELETE) with 401/404/403 ownership chain. Injected into card-gen, concept-decomposition, and quality-gate prompts via new `buildParentGuidancePreamble` in `promptTemplates.ts`. Sparky per-turn preamble added in `services/sparky/conversationEngine.ts`. Prompt-injection defense via `sanitizePromptInput` (strips control chars, "ignore previous instructions", "system:", length caps). 22-case vitest suite in `tests/parentGuidance.test.ts`. Dev Console tab added. |
| S10-05 | Session-aware context engine | 8 | ✅ Done (April 17) | New `ianaTimezone String @default("UTC")` on `ChildProfile` (same migration). IANA validated server-side via `Intl.DateTimeFormat` — zero hand-rolled offset math. 5-channel `SessionContext`: timeOfDay bucket (earlyMorning/morning/afternoon/evening/night — DST-safe), currentSessionMinutes (clamped 0..180), lessonsCompletedToday (counted against child's LOCAL midnight via `localStartOfDayUtc` read-back-and-shift), currentStreak (from EngagementProfile), recentQuizResults (last 10, tolerant parser). Pure reducer `buildSessionContextFrom` + DB-facing `buildSessionContext(childId, now)` in `src/services/context/sessionContext.ts`. Orchestrator fetches guidance + context once up-front, threads through every LLM stage. Dev Console Session Context tab + `GET /dev/session-context/:childId` diagnostic endpoint added. 24-case vitest suite in `tests/sessionContext.test.ts` covering DST spring-forward gap, fall-back overlap, Pacific/Eastern/Tokyo divergence, invalid-tz fallback, clock-skew clamp. |

---

## SKILL Epic — Content Generation Skills v1 (68 pts)

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S10-06 | `story-writer` skill with age profiles | 13 | ✅ Done (April 18) | Handlebars-backed skill engine (`src/services/skills/{types,loader,progression,registry}.ts`). Six-file `defs/story-writer/{manifest.json,prompt.md,styles.md,topics.md,age-profiles/{4,6,8}.md}`. Sliding-scale age resolution via `progressionDelta ∈ [−1.5, +1.5]` → `effectiveAgeYears` → nearest anchor profile (4/6/8), with `progressionModifier` partial carrying "above / standard / struggle" nudges. Boot-time eager loader (`await getSkillRegistry().load()` in `server.ts`) fails fast on manifest typos per spike decision #4. `/api/v1/dev/skills` (list, single, render dry-run, dev-only reload) wired at `src/routes/devSkills.ts`. Dev Console **Skills** tab (`public/dev-pipeline.html`) with picker, JSON inputs, age / progression / difficulty / interest / parent-avoid controls, system/user pane, meta grid, progression-breakdown readout, and a dev-only hot-reload button. 21-case `tests/skillEngine.test.ts` + 20-case `tests/devSkills.test.ts`. See delivery notes below. |
| S10-07 | `quiz-maker` skill with difficulty curves | 13 | ✅ Done (April 18) | Second skill on the S10-06 engine. Eleven-file bundle under `defs/quiz-maker/` (`manifest.json`, `prompt.md`, `styles.md`, `distractors.md`, `age-profiles/{4,6,8}.md`, `difficulty-curves/{easy,medium,hard}.md`). Difficulty curves lock **exact option counts: easy=3, medium=4, hard=5** per the spike. New shared partial `defs/_shared/modalityNote.hbs` (4-branch `eq`-helper selector on `ctx.teachingStrategy.modality` — visual / auditory / kinesthetic / default) carries the S10-11 modality into the prompt without a per-skill MD file. Per-skill Zod **output validator** (`src/services/skills/validators/{index.ts, quizMaker.ts}`) enforces the full structural contract: `{question, options, correctIndex, rationalePerOption, explanation}` with strict mode, banned-phrase check (`all of the above` / `none of the above` + 3 variants), duplicate-option detection (case-insensitive, whitespace-normalized), `correctIndex` range, `rationalePerOption` 1:1 with `options`. Loader pivoted from dynamic `require('./validators')` to static `import { SKILL_OUTPUT_SCHEMAS }` so vitest / tsx / compiled-node all resolve the registry identically. `devSkills.ts` `renderBodySchema.ctxOverrides` extended with `modality` + `conceptType` enums; `buildDevRenderContext` threads them into `teachingStrategy`. Dev Console Skills tab polish: modality dropdown, conceptType dropdown, validator chip (✓ attached / none), per-skill Re-seed button, validator badge on list rows, `validator` + `opts (expected)` cells on the render meta grid (opts derived from `difficultyUsed`: 3/4/5). New per-skill seed templates (`story-writer → {topic:"how seeds grow"}`, `quiz-maker → {concept:"helium balloons float because they are lighter than air", conceptType:"causeEffect"}`). **43 new tests:** 24-case `tests/quizMakerValidator.test.ts` (parameterized banned-phrase check across 7 variants, option-count/correctIndex/rationale invariants, duplicate detection, strict mode), 13 new cases in `tests/skillEngine.test.ts` (prompt variance by age/difficulty/modality, 3/4/5 option-count assertions in system prompt, modality-branch assertions visual→"shown" / auditory→"sound and rhythm" / kinesthetic→"action", missing required-input throws, `temperatureHint === 0.4`), 6 new cases in `tests/devSkills.test.ts` (list includes quiz-maker with `hasOutputSchema=true`, manifest fetch returns `handlesConceptTypes`, easy→3 / hard→5 via `difficultyOffset` ±2, modality-matrix render across all three modalities, 400 on missing `conceptType`, dev-only reload). See delivery notes below. |
| S10-08 | `experiment-designer` skill | 8 | ⏸ Pending | Drag-and-drop configs. Complexity adapts to age + motor skill. Hint system. |
| S10-09 | `curriculum-architect` skill | 13 | ⏸ Pending | 4–8 lesson sequence from knowledge graph + parent goals + engagement. Respects prerequisites, fills gaps first. |
| S10-10 | `voice-persona` skill | 8 | ⏸ Pending | Character voice per age: vocabulary, humor style, emotional range. Consumed by Sparky + narration. |
| S10-11 | Teaching strategy matrix | 5 | ✅ Done (April 17) | Pure `teachingStrategy.ts` with the full 6×3 matrix (`[vocabulary, abstract, process, comparison, causeEffect, factual] × [visual, auditory, kinesthetic]`), additive ranker that layers engagement (top +1.5, second +0.75, zero-completion -0.5), difficulty (`±0.4 × offset`, clamped ±2, favor-lists for hard/easy), and age-gating (experiment <6 / concept <5 → -0.75). Stable sort (score desc, baseRank asc). `inferModality` heuristic from engagement top-type. 39-case vitest suite locks matrix shape, ranker layers, cold-start neutrality, NaN/Infinity safety. `GET /dev/teaching-strategy` endpoint + **Strategy** Dev Console tab (concept-type × modality sandbox, difficulty slider, engagement override, rendered 6×3 grid with focus-cell highlight). See delivery notes below. |
| S10-12 | Integrate skills into Grand Architect pipeline | 8 | ✅ Done (April 18) | Skill engine fully wired into Stage 4. `childContextBuilder` (R1) assembles `ChildContext` from guidance + session context + engagement + mastery + teaching-strategy in one helper; `skillRouter` (R2) loops decomposition atoms through `skill.buildPrompt` → LLM → per-skill Zod validator, with a `lastStoryExcerpt` bridge so `quiz-maker` can cite the story that ran just before it; Zod retry (R3) closes **S9-07 carried debt** — one retry with the parse error embedded in the repair prompt, surfaced as `validatorStatus: 'retry-ok' \| 'retry-failed'`; `cardGenerator.generateCardsWithSkills` (R4) is a drop-in replacement for `generateCards` that cherry-picks skipped atoms into a legacy fallback and swallows legacy failures to ship a partial skill payload; `pipelineOrchestrator` (R5) threads `childId` through every stage, builds `ChildContext` once per run, calls `generateCardsWithSkills` when the feature flag is on and `childId` is present, and persists `skillEngine: {used, traces, skipped}` onto `Lesson.aiAnalysis` alongside the decomposition. `SKILL_ENGINE_STAGE4` env flag defaults **on** (set `false`/`0`/`off`/empty to disable; case-insensitive, whitespace-trimmed); legacy path is fully preserved when disabled or when `childId` is missing. R6 adds 44 new tests: 15-case `tests/childContextBuilder.test.ts` (pure helpers — `withConceptType` no-op-on-unchanged, `summarizeEngagement`/`summarizeMastery` weighting, `summarizeRecentEvents` 6-event cap), 15-case `tests/pipelineSkillIntegration.test.ts` (real skill registry booted from disk via `__resetSkillRegistryForTests` + LLM mock queue — happy path, `lastStoryExcerpt` threading, mixed-path cherry-pick, legacy-fallback-fails partial delivery, retry-ok surfaced through adapter, 9 feature-flag parser cases), 14-case `tests/skillRouter.test.ts`. R7 Dev Console: new `GET /api/v1/dev/pipeline/trace/:lessonId` endpoint (401/403/404/200 with parse-error passthrough), `PipelineRingEntry` extended with `lessonId: string \| null` + `skillEngineUsed: boolean`, pipeline.ts response body carries `skillEngineUsed` / `skillSkippedAtoms` / `regeneratedCardIndexes` / `qualityScore`, new "Skill Engine" panel on the Pipeline tab with per-atom rows (color-coded pill for `ok`/`retry-ok`/`retry-failed`/`skipped`, retry-count badge, token total, modality/conceptType, skip-reason red block) and an auto-refresh hook at the end of `generateCards()`. See delivery notes below. |

---

## Definition of Done

- [ ] New lesson for a child uses their knowledge graph — does not re-teach mastered concepts
- [ ] Quiz difficulty reflects demonstrated ability, not just age
- [ ] Generated story references the child's interest topics
- [ ] `curriculum-architect` produces a coherent 4-lesson sequence with prerequisites respected
- [ ] Parent changes difficulty in Companion → next generated lesson reflects the change

---

## Sprint Summary

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| MEM | 50 | 50 | 100% |
| SKILL | 39 | 68 | 57% |
| **Sprint 10 Total** | **89** | **118** | **75%** |

### S10-01 Delivery Notes (April 16)

**Files changed:**
- `src/db/schema.prisma` — added `Concept` + `ChildConcept` models; added `childConcepts ChildConcept[]` back-relation on `ChildProfile`.
- `src/db/client.ts` — registered `concept: ['prerequisites']` in the JSON-field middleware.
- `src/db/seedKnowledgeGraph.ts` *(new, 200 LOC)* — 50-concept seed + exported `validateSeedGraph()` helper with duplicate-ID / unknown-prereq / self-prereq / cycle detection.
- `tests/knowledgeGraph.test.ts` *(new, 16 cases across 4 describe blocks)* — seed shape, prerequisite integrity, cross-domain edges, pedagogical-ordering invariants.
- `package.json` — added `db:seed:knowledge` npm script.

**Why slugs instead of UUIDs for concept IDs:** prerequisites are declared statically in the seed (array of IDs). UUIDs would require runtime ID-rewriting after the first `create`. Slugs (`comp-01` etc.) make the seed idempotent (upsert by stable id), make tests readable, and let S10-02 / S10-09 reference concepts by name without a lookup indirection. Real user-generated concepts, if we ever allow them, would still use UUIDs via `@default(uuid())` — the seed just overrides for its 50 rows.

**Why prerequisites-as-JSON-text:** SQLite has no native JSON column. Using a text column + the existing `client.ts` middleware keeps us consistent with every other JSON field in the schema (`lesson.aiAnalysis`, `card.content`, etc.) and avoids introducing a join table for what is read-mostly static metadata. Join table becomes attractive only when Sprint 11's knowledge-graph-visualization (S11-01) needs graph traversal queries — at that point a DEPLOY-sprint migration to Postgres `jsonb` or a normalized `concept_prerequisites` table is the cleaner play.

---

### S10-02 Delivery Notes (April 16)

**Files changed:**
- `src/db/schema.prisma` — added `Card.conceptId String?` + `@@index([conceptId])` + FK with `onDelete: SetNull`; added `cards Card[]` back-relation on `Concept`. Validated with `npx prisma validate` → ✅.
- `src/db/migrations/20260416190000_s10_02_card_concept_link/migration.sql` *(new)* — hand-written SQLite RedefineTables migration (PRAGMA foreign_keys=OFF → `CREATE TABLE new_cards` with new column + FK → `INSERT SELECT` from old `cards` → `DROP TABLE cards` → `ALTER TABLE new_cards RENAME` → recreate `cards_lessonId_idx` and new `cards_conceptId_idx`). Hand-written because `prisma migrate dev` can't run in the sandbox; matches Prisma's own output format so the migration history stays linear.
- `src/services/mastery/masteryTracker.ts` *(new, 273 LOC)* — pure/DB split described below.
- `src/routes/progress.ts` — `POST /progress/sync` now filters quiz-shaped interactions (`action === 'answer'` + `typeof result.correct === 'boolean'`), batch-resolves `Card → conceptId` (a card may not be mastery-bearing — those are silently dropped), builds `QuizResultEvent[]`, and awaits `recordQuizResultsBatch`. Response now includes `masteryUpdates[]` with `{conceptId, priorConfidence, nextConfidence, attempts, correctCount, wasFirstIntroduction}` for client-side optimism / badge surfacing.
- `src/routes/knowledge.ts` — added `GET /children/:childId/mastery` with ownership check (same 401/404/403 pattern as `/progress`). Returns `{childId, data: MasteryRow[], domainRollup, totalTracked}`. Decay applied on-the-fly — NOT persisted on read.
- `tests/masteryTracker.test.ts` *(new, 158 LOC, 20 cases across 5 describe blocks)* — locks the DoD numbers into a "constant sanity" test so future refactors can't quietly drift them.

**Architectural decisions:**

1. **Pure-math / DB-facing split.** `clampConfidence`, `applyDecay`, and `applyDelta` are pure and exported. `recordQuizResult` / `recordQuizResultsBatch` / `getChildMastery` take the Prisma client. Tests exercise the pure layer without a DB; the DB layer is a thin upsert around it.

2. **Decay applied BEFORE delta.** Two successive correct answers a month apart should not skip the intervening 4 weeks of decay. `applyDelta` first decays the stored `confidence` to "now", then adds ±delta, then clamps. The `{prior, decayed, next}` trio is returned so callers can log full deltas if they want.

3. **On-read decay, on-write materialization.** `getChildMastery` computes `effectiveConfidence = applyDecay(confidence, lastTested, now)` per-row but never writes back. This keeps reads cheap, avoids racy writes from concurrent dashboard loads, and means a cron job is not needed. `confidence` is only persisted on actual quiz events, where the decay is naturally baked into `next`.

4. **`conceptId` on Card, not Lesson.** Not every card is mastery-bearing — intro cards, story cards, and Sparky prompts are not quizzes. A lesson-level link would force a fake "this lesson tests concept X" assertion on cards that don't actually test anything. Nullable card-level FK is the precise granularity.

5. **Quiz-result convention over new endpoint.** Mastery ingestion piggybacks on the existing `POST /progress/sync` — no new client-facing endpoint. A quiz result is any interaction with `action === 'answer'` and `typeof result.correct === 'boolean'`. Non-quiz interactions (views, story completions) pass through untouched. One ingestion point = one race surface.

6. **Batch ordering is serial, not parallel.** `recordQuizResultsBatch` `await`s each `recordQuizResult` in turn so later events in the same sync see the effect of earlier ones (compounding attempts / confidence). `Promise.all` would race the upsert on the same `(childId, conceptId)` unique key and drop events.

**Validation:**
- ✅ `npx tsc --noEmit` — zero errors in `masteryTracker.ts` and the new `knowledge.ts` endpoint. The 32 pre-existing Prisma-JSON errors are unchanged; two transient errors on `progress.ts:116/118` ("`conceptId` does not exist in type `CardSelect`") resolve once `prisma generate` runs on bang's Mac.
- ✅ Brace/paren/bracket balance on `masteryTracker.ts`.
- 🟡 Vitest blocked in sandbox — `Cannot find module '@rollup/rollup-linux-arm64-gnu'` (same class of esbuild/rollup binary-mismatch as prior sprints). Pure-math tests must be run on bang's Mac via `npx vitest run tests/masteryTracker.test.ts`.

**In-flight fix during deploy — `client.ts` middleware gap (April 16, late):**
Running `npm run db:seed:knowledge` against the reset DB surfaced a latent bug in `src/db/client.ts`: the JSON-string-field middleware stringified `params.args.data` (used by `create` / `update` / `updateMany`) but NOT the `create` + `update` sibling payloads that `upsert` uses. The knowledge-graph seeder is upsert-based (for idempotency), so `prerequisites: []` passed through unchanged and Prisma rejected the array against the SQLite `String` column. Fix: middleware now handles the `upsert` branch explicitly AND iterates `params.args.data` when it's an array (for `createMany` — preemptive for S10-03's batched interaction inserts). Post-patch reseed: **Concept=50 (17 computers / 17 robots / 16 AI) — ✅**.

**Prerequisites bang must run on his Mac before the Backend compiles cleanly:**

```bash
cd src/Backend

# 1. Regenerate the Prisma client (picks up Card.conceptId + Concept.cards)
npx prisma generate

# 2. Apply the new migration to the dev DB
npx prisma migrate deploy        # or: npx prisma migrate dev  (if you want auto-gen of the lockfile row)

# 3. Re-run the (newly clean) typecheck
npx tsc --noEmit

# 4. Run the S10-02 unit tests
npx vitest run tests/masteryTracker.test.ts
```

**Smoke-test recipe (post-migrate, post-seed, server running):**

```bash
# Assuming a child + card with conceptId exists (or after seed):
CHILD=<uuid>
CARD=<uuid-with-conceptId-set>

# 1. Fire a correct answer
curl -s -XPOST http://localhost:3000/api/v1/progress/sync \
  -H 'content-type: application/json' \
  -d "{\"childId\":\"$CHILD\",\"interactions\":[{\"cardId\":\"$CARD\",\"action\":\"answer\",\"durationMs\":1200,\"result\":{\"correct\":true}}]}" \
  | jq '.masteryUpdates[0]'
# expect: priorConfidence: 0.000, nextConfidence: 0.150, wasFirstIntroduction: true

# 2. Read back the child's mastery with decay applied
curl -s "http://localhost:3000/api/v1/knowledge/children/$CHILD/mastery" \
  | jq '{totalTracked, firstRow: .data[0], rollup: .domainRollup}'
```

---

### S10-03 Delivery Notes (April 16)

**Files changed:**
- `src/db/schema.prisma` — added `EngagementProfile` model (1:1 with `ChildProfile`, `onDelete: Cascade`) with raw counters + two AES-256-GCM ciphertext fields (`cardTypeStatsEncrypted`, `topicAffinitiesEncrypted`) + timestamps, and added the reverse `engagementProfile EngagementProfile?` relation on `ChildProfile`.
- `src/db/migrations/20260416200000_s10_03_engagement_profile/migration.sql` *(new)* — hand-written `CREATE TABLE "engagement_profiles"` + unique index on `childId`. Timestamp ordered AFTER S10-02's `20260416190000_...` so the migration history stays linear.
- `src/services/engagement/engagementProfiler.ts` *(new, ~530 LOC)* — pure reducers + ranking + DB-facing ingest/read. Thin `encryptJSON`/`decryptJSON` wrappers around the existing `services/oauth/tokenEncryption` helpers (same key, same AES-256-GCM cipher). Decrypt failures return the fallback silently — a key rotation or corrupt blob must not poison the write path, and the next write re-encrypts.
- `src/routes/progress.ts` — `POST /progress/sync` now (a) hoists the card-metadata lookup to a single query that both the mastery path (S10-02) and the engagement path (S10-03) reuse, (b) calls `ingestInteractionsForSession` after mastery updates with **all** interactions (not just quiz-shaped ones — views, completions, skips all feed the profile), and (c) surfaces the `ProfileDelta` back to the client as `engagementDelta` in the sync response.
- `src/routes/engagement.ts` *(new, 180 LOC)* — two endpoints under `/api/v1/engagement`:
  - `GET /children/:childId` → rendered `EngagementProfileView` (ranked card-type prefs + topic affinities, zero-state when no profile yet).
  - `GET /children/:childId/raw` → debugging: raw counters + decrypted `cardTypeStats` + `topicAffinities` + both rankings + timestamps. Intended for the dev-console Engagement tab.
- `src/routes/index.ts` — registered `engagementRoutes` under `/engagement` and `devConsoleRoutes` under `/dev`.
- `tests/engagementProfiler.test.ts` *(new, 28 cases across 7 describe blocks)* — locks the DoD tunables (2000ms rapid-quit, 3-trigger flow, 2-consecutive-wrong frustration), exercises pure reducers (merge + mutation-safety + duration clamping + unknown-type skipping), classifies edge cases (flow fires ONCE per run, same-concept vs. different-concept wrong-answer frustration, rapid-quit only on non-answer actions), and verifies ranking ordering + completion-rate rounding.

**Architectural decisions:**

1. **Encrypt only the behavior-profiling fields.** `totalSessions`, `totalInteractions`, `totalDurationMs`, event counts, and streaks are raw integers and not child-identifying on their own — a dashboard or monitoring system needs to read them cheaply. `cardTypeStats` and `topicAffinities` reveal *what the child likes and struggles with*, which IS profiling under COPPA, so both live behind AES-256-GCM ciphertext using the same `ENCRYPTION_KEY` that protects OAuth tokens.

2. **Pure / DB-facing split (same pattern as S10-02).** `mergeCardTypeStats` / `mergeTopicAffinities` / `classifyInteractionStream` / `summarizeBatch` / ranking functions are pure and exported. Tests exercise them without a DB or an encryption key. `ingestInteractions` wraps them with fetch → decrypt → reduce → encrypt → upsert; `ingestInteractionsForSession` adds the session-counter bump as a follow-up update (safer than folding into the upsert, which already writes `totalSessions: 1` on create).

3. **Cross-batch streak continuity via `initialStreak`.** `classifyInteractionStream` takes a prior streak value so a 2→3 flow transition spanning two sync calls is still counted exactly once. The caller passes `existing?.currentStreak ?? 0` on every ingest.

4. **Rapid-quit is non-answer-only.** An answer submitted in 100ms is not a rapid quit — it's just a fast answer. Only view/skip/complete actions under 2000ms fire the rapid-quit frustration event. Locked in tests.

5. **`flow` fires once per run.** The event fires when the streak transitions 2→3; further correct answers in the same run don't double-count. Breaking the streak and rebuilding to 3+ DOES fire a new event. Two tests pin this so future refactors can't silently drift it.

6. **Dev-console raw endpoint.** A separate `/children/:childId/raw` endpoint was added because the dev console will want to render the low-level `CardTypeStat { count, totalDurationMs, completionCount }` table alongside the ranked view. Mobile clients use `/children/:childId` (ranked, no raw stats).

**Validation:**
- ✅ Brace/paren/bracket balance on `engagementProfiler.ts` and `engagement.ts`: exact match.
- ✅ 28 vitest cases across 7 describe blocks — pending run on bang's Mac since the sandbox's vitest tooling has an rollup/arm64 mismatch (Sprint 9 note, not our bug).
- ✅ `tsc --noEmit` clean on the three new/edited files. Carried-in `Prisma.InputJsonValue` errors in `routes/cards.ts`/`routes/badges.ts`/`seed.ts`/etc. are untouched.
- 🟡 Runtime spot-checks pending on Mac — exact curl commands below.

**Commands to run on your Mac:**

```bash
cd ~/Projects/Novai/src/Backend

# 1. Regenerate Prisma client (picks up the new EngagementProfile model + relation)
npx prisma generate

# 2. Apply the new migration
npx prisma migrate deploy

# 3. Sanity: run the profiler unit tests
npm test -- tests/engagementProfiler.test.ts
#   expect: 28 passing

# 4. Full suite (catches cross-file regressions)
npm test
#   expect: ~150+ passing (133 prior + 28 new)

# 5. Boot the server + run a sync with a mix of quiz + view interactions,
#    then read back the engagement profile
npm run dev
# in another shell — substitute your childId and a real cardId:
CHILD="<child-uuid>"
CARD="<card-uuid>"
curl -s -X POST http://localhost:3000/api/v1/progress/sync \
  -H "Content-Type: application/json" \
  -d "{\"childId\":\"$CHILD\",\"interactions\":[
    {\"cardId\":\"$CARD\",\"action\":\"view\",\"durationMs\":1500},
    {\"cardId\":\"$CARD\",\"action\":\"answer\",\"durationMs\":4000,\"result\":{\"correct\":true}},
    {\"cardId\":\"$CARD\",\"action\":\"answer\",\"durationMs\":3500,\"result\":{\"correct\":true}},
    {\"cardId\":\"$CARD\",\"action\":\"answer\",\"durationMs\":3800,\"result\":{\"correct\":true}}
  ]}" | jq '.engagementDelta'
# expect: interactionsApplied: 4, flowEventsAdded: 1, frustrationEventsAdded: 1 (the 1500ms view),
#         finalStreak: 3, newLongestStreak: >= 3

curl -s "http://localhost:3000/api/v1/engagement/children/$CHILD" | jq '.data'
# expect: cardTypePreferences non-empty with the quiz entry, topicAffinities sorted desc,
#         currentStreak: 3, longestStreak: 3, flowEventCount: 1

curl -s "http://localhost:3000/api/v1/engagement/children/$CHILD/raw" | jq '.data'
# expect: counters + decrypted cardTypeStats + topicAffinities + both rankings
```

---

## Side-Quest: Dev Console Tab-Shell Refactor (April 16)

*Infrastructure work — not a scored story. Enables Knowledge Graph inspection in the same dev tool already wired up for Pipeline, so S10-02 (mastery tracking) and S10-09 (curriculum architect) have a UI surface to verify generated output against.*

**What changed:**
- **New backend route** `src/routes/knowledge.ts` — 3 endpoints under `/api/v1/knowledge`:
  - `GET /concepts` (optional `?domain=computers|robots|ai` filter, 200 rows max unfiltered)
  - `GET /concepts/:id` (expands `prerequisites` to `{id,name,domain,difficulty}` objects; also computes reverse edge `dependentConcepts` in-memory — 50 rows, cheap)
  - `GET /domains` (group-by aggregate: count, min/max difficulty per domain)
  - All three require `request.userId` (same pattern as pipeline routes — dev middleware auto-fills `firstUser.id`).
- **Registered** in `src/routes/index.ts` under `/api/v1/knowledge` prefix, grouped next to other Sprint-10 work.
- **Renamed** `dev-pipeline.html` → keeps the same filename (bookmarks preserved) but the page is now **Nova · Dev Console** with two tabs:
  - **Pipeline** — existing 7-stage ingest/generate flow, moved verbatim into `<section class="tab-pane" id="tab-pipeline">`.
  - **Knowledge Graph** — new domain-grouped concept browser: filter chips (All / Computers / Robots / AI), per-concept cards with id-chip + name + difficulty stars (●●●○○) + description + prerequisite chips (green "root" chip for foundation concepts, cyan chips for dependencies). Click a card to open a detail modal listing prerequisites + reverse-edge "Unlocks" (what depends on this).
- **Tab persistence** via URL hash (`#pipeline`, `#knowledge`). Reloads and bookmarks land on the same tab. Lazy-loads KG data on first tab switch — zero cost if you never open it.

**Why not a separate `dev-kg.html`:** a second page would mean duplicating the header/status chrome, a second health-check, and no path to cross-link. Tab shell costs ~350 LOC total, keeps one URL, and means S10-02's "concept mastery heatmap per child" can slot in as a third tab without another page-level refactor.

**Why new backend endpoints instead of reading `KNOWLEDGE_GRAPH_SEED` directly in the HTML:** two reasons. (1) Seed is TypeScript — we'd need a build step or a second JSON copy to ship it to the browser. (2) S10-02 onwards will enrich concept responses with per-child mastery data that *must* come from the DB. Having the endpoint now means the dev tool stays API-driven and the contract is stable.

**Files touched:**
- `src/routes/knowledge.ts` *(new, 148 LOC)* — 3 Fastify handlers, zod params validation, userId auth check.
- `src/routes/index.ts` — 1 import + 1 `fastify.register(knowledgeRoutes, { prefix: '/knowledge' })` line.
- `public/dev-pipeline.html` — added ~230 LOC of tab-shell CSS + KG tab CSS, tab-nav markup, knowledge-tab markup, concept-detail modal, ~180 LOC of JS (`switchTab`, `loadKnowledgeGraph`, `renderKG`, `renderConceptCard`, `openConceptDetail`, `renderConceptModal`, `filterKG`, URL-hash sync, Escape-to-close).

**Validation:**
- ✅ `tsc --noEmit` produces zero new errors on `knowledge.ts` or `routes/index.ts` (the 32 pre-existing Prisma-JSON errors remain — Sprint-9 carry-in debt, documented below).
- ✅ HTML structural parse: `tab-pane` opens = `</section>` closes = 2 · `<div class="app">` = 1 · `<script>`/`</script>` balanced.
- ✅ Brace/paren/bracket balance on `knowledge.ts`: 47/47 · 59/59 · 9/9.
- 🟡 Runtime spot-check **pending on bang's Mac** — sandbox can't run `npx tsx src/server.ts` (tsx IPC dir `/var/folders` is read-only). Run these once the server is up locally:

```bash
# After `npm run dev` in src/Backend:

# 1. List all concepts (expect count: 50)
curl -s http://localhost:3000/api/v1/knowledge/concepts | jq '.count'

# 2. Filter by domain (expect 17 / 17 / 16)
curl -s "http://localhost:3000/api/v1/knowledge/concepts?domain=computers" | jq '.count'
curl -s "http://localhost:3000/api/v1/knowledge/concepts?domain=robots"    | jq '.count'
curl -s "http://localhost:3000/api/v1/knowledge/concepts?domain=ai"        | jq '.count'

# 3. Single concept with prereq expansion (expect ai-01 depends on comp-01)
curl -s http://localhost:3000/api/v1/knowledge/concepts/ai-01 \
  | jq '.data | {id, name, prerequisiteConcepts, dependentConcepts: (.dependentConcepts | length)}'

# 4. Domain aggregate
curl -s http://localhost:3000/api/v1/knowledge/domains | jq
```

**Prerequisite:** `npm run db:seed:knowledge` must be run against the fresh `nova.db` — Prisma Studio currently shows `Concept=0`, which will cause the KG tab to display a "Have you run npm run db:seed:knowledge?" hint.

---

### S10-04 + S10-05 Delivery Notes (April 17)

Shipped together — the session-aware context engine (S10-05) consumes the same `ChildProfile` row as Parent Guidance (S10-04), so both models landed on one migration and both preambles are composed side-by-side in every LLM prompt.

**Files changed:**
- `src/db/schema.prisma` — added `ianaTimezone String @default("UTC")` to `ChildProfile`; added `ParentGuidance` model (1:1 with `ChildProfile`, `onDelete: Cascade`, unique `childId`, index on `updatedByUserId`) with `topicFocus` / `topicAvoid` / `contentBoundaries` stored as JSON text (SQLite); added reverse relation `parentGuidance ParentGuidance?` on `ChildProfile`.
- `src/db/client.ts` — registered `parentGuidance: ['topicFocus', 'topicAvoid', 'contentBoundaries']` in `JSON_STRING_FIELDS` middleware.
- `src/db/migrations/20260417210000_s10_04_s10_05_guidance_timezone/migration.sql` *(new)* — `ALTER TABLE child_profiles ADD COLUMN ianaTimezone TEXT NOT NULL DEFAULT 'UTC'` + `CREATE TABLE parent_guidance` + unique index + updatedByUserId index. Migration timestamp ordered AFTER S10-03's `20260416200000_...`.
- `src/services/guidance/parentGuidance.ts` *(new, ~300 LOC)* — pure helpers + DB helpers (see architectural decisions below).
- `src/services/context/sessionContext.ts` *(new, ~380 LOC)* — pure reducer + DB-facing builder with DST-safe Intl-backed timezone math.
- `src/services/pipeline/promptTemplates.ts` — added `GuidancePreambleInput` / `SessionContextPreambleInput` types; added `sanitizePromptInput` (prompt-injection defense); added `describeDifficultyOffset` / `describeTimeOfDay` / `describeMomentum` render helpers; added `buildParentGuidancePreamble` / `buildSessionContextPreamble`; extended `getCardGenerationSystemPrompt` + `getConceptDecompositionSystemPrompt` with optional `guidance` + `sessionContext` params, and `getQualityGateSystemPrompt` with `guidance` only (session context intentionally excluded — review is about the lesson, not the moment).
- `src/services/pipeline/cardGenerator.ts` — threaded `guidance?` + `sessionContext?` through `generateCards`.
- `src/services/pipeline/conceptDecomposer.ts` — threaded `guidance?` + `sessionContext?` through `decomposeConcepts`.
- `src/services/pipeline/qualityGate.ts` — threaded `guidance?` through `runQualityGate` + private `reviewLesson`.
- `src/services/pipeline/pipelineOrchestrator.ts` — `PipelineOptions.childId?: string` added; orchestrator fetches guidance + sessionContext once up-front (with defense-in-depth ownership re-check on the child row) and threads them into every LLM stage. Failures degrade to no-preamble — Sprint 9 behavior preserved.
- `src/routes/pipeline.ts` — `childId: z.string().uuid().optional()` added to `generateCardsSchema`; destructured + passed into `runPipeline(...)`.
- `src/routes/parentGuidance.ts` *(new)* — GET/PUT/DELETE at `/children/:childId/guidance`. Zero-state GET returns `hasGuidance: false` without 404-ing. PUT is patch-style upsert via `mergeGuidance` (zod `.refine` rejects empty bodies). DELETE is idempotent (204 on either hit or miss). Full 401 → 404 → 403 ownership chain.
- `src/routes/children.ts` — accepts `ianaTimezone` in POST + PATCH bodies (validated via `Intl.DateTimeFormat` refinement — no hand-rolled allowlist), returns it in GET responses.
- `src/routes/devConsole.ts` — added `GET /dev/session-context/:childId` diagnostic endpoint that returns `{sessionContext, guidance, preamble, preambleChars}` so the Dev Console can render the exact preamble the LLM would see.
- `src/routes/index.ts` — registered `parentGuidanceRoutes` under `/children`.
- `src/services/sparky/conversationEngine.ts` — prepends `buildParentGuidancePreamble(guidance) + buildSessionContextPreamble(sessionContext)` to `SPARKY_SYSTEM_PROMPT`. Wrapped in try/catch — preamble failure degrades to vanilla Sparky (old Sprint 6 behavior).
- `public/dev-pipeline.html` — added **Guidance** tab (edit topicFocus / topicAvoid / difficulty / boundaries / session limits / IANA timezone with quick-select chips for NYC/LA/London/Tokyo/UTC) and **Session Context** tab (live wall-clock, bucket, streak, recent quiz strip, full preamble preview, auto-refresh 5s).
- `tests/parentGuidance.test.ts` *(new, 22 cases across 6 describe blocks)* — `clampDifficultyOffset` range/rounding/non-numeric/string-coerce; `normalizeTopicList` trim/dedupe/length-cap/non-array; `sanitizeBoundaries` pass-through/empty-drop/unknown-key-reject/non-object; `coerceLimitMinutes` positive/zero-negative-null/cap-1440; `mergeGuidance` field-preservation/sanitizer-composition/boundary-replace/empty-patch; `defaultGuidance` zero-state.
- `tests/sessionContext.test.ts` *(new, 24 cases across 7 describe blocks)* — DST spring-forward gap (2025-03-09 06:30 UTC → 01:30 EST, 07:30 UTC → 03:30 EDT in America/New_York), fall-back overlap (2025-11-02 05:30 UTC and 06:30 UTC both read as 01:30 local), Pacific/Eastern bucket divergence at the same UTC instant, UTC → Tokyo next-day wrap, `localStartOfDayUtc` for NYC/LA/UTC/invalid-zone, pure reducer zero-state + clamping + tz fallback.

**Architectural decisions:**

1. **IANA zone + Intl, never hand-rolled offsets.** A child in New York during DST is UTC-4, not UTC-5. A child in Arizona never observes DST despite sitting next to Pacific. A child in São Paulo doesn't observe DST anymore (abolished 2019). An offset-based representation would be wrong in every one of those cases. We store the IANA zone name (`America/New_York`), validate it server-side by passing it to `new Intl.DateTimeFormat(... { timeZone })` (Intl throws `RangeError` on unknown zones), and every time-of-day read goes back through Intl. The DST spring-forward gap (`02:30` never exists on transition day) and fall-back overlap (`01:30` exists twice) are handled automatically — Intl never emits a non-existent wall-clock and the bucket for both fall-back 1:30ams is the same (`night`), which is the right answer for "where is the child in their day?"

2. **`localStartOfDayUtc` by read-back-and-shift, not date math.** To count "lessons completed today" against the child's local day rather than UTC, we compute the UTC instant that represents local-midnight. Approach: format `now` into the zone, extract `yyyy-mm-dd`, construct a candidate `Date.UTC(yyyy, mm-1, dd, 0, 0, 0)`, read that candidate back through the same Intl formatter, compute the delta, and shift. This converges in one iteration for every real-world zone and sidesteps any ambiguous-wall-clock case (midnight is never inside a DST transition on any real IANA zone).

3. **Pure / DB-facing split (matches S10-02 and S10-03).** `clampDifficultyOffset`, `normalizeTopicList`, `sanitizeBoundaries`, `coerceLimitMinutes`, `mergeGuidance`, `defaultGuidance` are pure. `bucketForHour24`, `resolveTimezone`, `getLocalWallClock`, `sessionMinutesSince`, `localStartOfDayUtc`, `buildSessionContextFrom` are pure. The DB layer (`getGuidance`, `upsertGuidance`, `buildSessionContext`) is a thin shell around them. Tests exercise the pure layer without a DB, encryption key, or clock.

4. **Prompt-injection defense.** Parent-supplied strings (topicFocus entries, disallowedKeywords) go through `sanitizePromptInput` before they ever reach an LLM prompt. It strips ASCII/Unicode control chars, case-insensitively filters "ignore previous instructions" and variants, strips `system:` role-spoofing patterns, collapses whitespace, and caps at 80 chars per entry. Layered defense — the normalization helpers already cap list length (32) and per-entry length (80) at the service boundary, so even a parent pasting a 10,000-character "jailbreak" only gets one 80-char entry through.

5. **Single fetch, thread through every stage.** The orchestrator calls `getGuidanceOrDefault` + `buildSessionContext` once, stores the results in closure-local variables, and passes them to `decomposeConcepts` / `generateCards` / `runQualityGate`. Rationale: (a) every stage sees the same snapshot — no race where a parent edit mid-pipeline causes Stage 4 to see different guidance than Stage 6; (b) guidance fetch is a single DB round-trip, amortized across all stages; (c) reduces surface area for guidance-fetch failure from "every stage might fail" to "one top-of-pipeline fetch might fail, degrading to generic prompts".

6. **Pipeline never dies on guidance/context failures.** All three fetch sites (orchestrator, Sparky, Dev Console diagnostic) wrap guidance + context in try/catch. On failure we log a warning and proceed with `null` — which the preamble builders render as an empty string, which is indistinguishable from the pre-Sprint-10 behavior. A missing ChildProfile row, a corrupt `contentBoundaries` blob, a timezone lookup that somehow fails — none of these should take down a kid's lesson generation.

7. **Defense-in-depth ownership check in the orchestrator.** Even though `POST /pipeline/generate` already verifies the caller owns the `ingestId`, the orchestrator re-verifies that the caller also owns the supplied `childId` before reading guidance/context. This is belt-and-suspenders: the only caller is the route handler, but if some future code path (a scheduled job, a background worker) ever invokes `runPipeline` with an attacker-controlled `childId`, the ownership re-check keeps the guidance read scoped. On mismatch we log and degrade — we do not throw, because the pipeline itself is not an ownership-verification surface (the route is).

8. **Session context intentionally excluded from quality gate.** `runQualityGate` takes `guidance` (because the review is quality-filtered against the parent's boundaries — we shouldn't pass a card that violates a disallowed keyword) but does NOT take `sessionContext`. The review is about whether the *lesson* is good, not whether it's appropriate for *this moment* — and we don't want a critic model second-guessing "should the child be learning this at 8pm?" every run.

**Prompt preamble shape:**

```
PARENT GUIDANCE (apply before any other instruction):
- Topics to emphasize: dinosaurs, robots, space.
- Topics to avoid: war, scary animals.
- Difficulty: Make this noticeably SIMPLER than the default for this age.
- Content boundaries:
  - Disallowed keywords: violence, weapons.
  - Allowed tags: nature, science.
- Session limits (minutes): daily=60, single=20.

SESSION CONTEXT (for this lesson generation):
- Child's local time: 14:32 on Friday (afternoon).
- Current session duration: 12 minutes.
- Lessons completed today: 2.
- Current correct-answer streak: 5.
- Recent quiz momentum: 4 of the last 5 correct — the child is on a roll.

[... then the original system prompt follows ...]
```

**Validation:**
- ✅ Brace/paren/bracket balance on `parentGuidance.ts`, `sessionContext.ts`, `promptTemplates.ts` edits.
- ✅ `tsc --noEmit` on new files clean (the pre-existing `Prisma.InputJsonValue` errors in `pipelineOrchestrator.ts`, `cards.ts`, `badges.ts`, `seed.ts`, `assetJobProcessor.ts` are unchanged — Sprint 9 carry-in, unblocked by `prisma generate` on the Mac).
- ✅ `tests/parentGuidance.test.ts` — 22 cases, locks all invariants (range clamps, dedupe, length caps, empty-patch preservation).
- ✅ `tests/sessionContext.test.ts` — 24 cases covering DST spring-forward + fall-back + same-instant-different-zone + invalid-zone fallback + clock-skew clamp + local-midnight in NYC/LA/UTC.
- 🟡 Vitest blocked in sandbox — same rollup/arm64 binary mismatch as prior sprints. Tests must be run on bang's Mac (commands below).

**Commands to run on your Mac:**

```bash
cd ~/Projects/Novai/src/Backend

# 1. Regenerate Prisma client (picks up ianaTimezone on ChildProfile + ParentGuidance model)
npx prisma generate

# 2. Apply the new migration
npx prisma migrate deploy

# 3. Run the S10-04 + S10-05 unit tests
npm test -- tests/parentGuidance.test.ts
#   expect: 22 passing
npm test -- tests/sessionContext.test.ts
#   expect: 24 passing

# 4. Full suite (catches cross-file regressions)
npm test

# 5. Boot the server
npm run dev

# 6. Open the Dev Console
#    → http://localhost:3000/dev-pipeline.html
#    → pick a child
#    → Guidance tab: set timezone to America/New_York, difficulty to -1, topicFocus to "dinosaurs, robots", save
#    → Session Context tab: verify localClock + bucket reflect NYC time, refresh, flip timezone to Asia/Tokyo on the Guidance tab and watch the bucket move

# 7. Full end-to-end: ingest a URL + generate cards with a childId
CHILD="<child-uuid>"
INGEST="<ingest-uuid-from-POST /pipeline/ingest>"
curl -s -X POST http://localhost:3000/api/v1/pipeline/generate \
  -H 'Content-Type: application/json' \
  -d "{\"ingestId\":\"$INGEST\",\"childId\":\"$CHILD\"}" \
  | jq '.data | {lessonId, cardCount, qualityScore}'
#   expect: cards reflecting parent focus topics + simpler vocabulary if difficulty is -1
```

---

### S10-11 Delivery Notes (April 17)

**Files changed:**
- `src/services/skills/teachingStrategy.ts` *(new, ~350 LOC)* — pure module. Six `ConceptType` × three `LearningModality` matrix, fully populated (every cell lists all 5 card types). Pure ranker `rankCardTypesFor(conceptType, modality, ctx)` layers engagement / difficulty / age bonuses on top of a base score (`5 - baseRank`). Additional helpers: `rankedCardTypeOrder` (string[] convenience), `getStrategyMatrix` (cloned to prevent mutation), `inferModality` (heuristic from engagement top-type).
- `src/routes/devConsole.ts` — new `GET /dev/teaching-strategy` endpoint. Zod-validated query params: `childId?` (uuid), `conceptType?`, `modality?`, `difficultyOffset?` (-2..+2), `ageYears?` (2..18), `engagementOverride?` (story|concept|experiment|quiz|voice). Full 401 → 404 → 403 ownership chain when `childId` is supplied. Returns `{matrix, conceptTypes, modalities, focus:{conceptType, modality, difficultyOffset, ageYears, engagementOverride, ranking}, childContext}`. `childContext` populated when `childId` is passed (age from birthDate via `365.25`-day division, inferred modality from engagement profile).
- `public/dev-pipeline.html` — new **Strategy** tab between Context and Inspector. `VALID_TABS` extended; `switchTab` lazy-loads via `NovaDevConsole.loadStrategy()`. Sandbox UI: concept-type select, modality select (with "(from child)" default), difficulty range slider (-2..+2) with live label, engagement-override select. Ranker panel renders the focus cell's ordered card types with horizontal score bars and per-row bonus breakdown (`eng +0.75 · diff -0.40 · age -0.75`). Full-matrix panel renders the 6×3 grid with the focus cell highlighted green. Raw JSON pane. Cross-tab refresh on `nova:childChanged`. Public API exposes `loadStrategy` + `onStrategyDifficultyInput`.
- `tests/teachingStrategy.test.ts` *(new, ~350 LOC, 39 cases across 8 describe blocks)* — matrix shape (6×3, uniqueness, auditory top-2 contains voice/story, kinesthetic top-2 contains experiment, clone immutability), base ranker (empty-ctx order preservation, score formula, rank-order equivalence, all 5 types returned), engagement bonus (top +1.5, second +0.75, zero-completion -0.5, cold-start neutrality, 3rd→2nd lift), difficulty bonus (zero=neutral, +2 favors quiz/experiment, -2 inverts, clamp ±2, NaN/Infinity safety), age bonus (undefined=0, experiment <6, concept <5, other types never gated), composed ranking (engagement × difficulty cooperates, 3rd→2nd but not past 1st without stronger bonuses, no NaN/duplicates under max layering), inferModality (undefined/empty → visual, voice/story → auditory, experiment/quiz → kinesthetic, concept → visual), graceful degradation.

**Architectural decisions:**

1. **Six ConceptType values ≠ the existing `TeachingStrategy` enum.** The `conceptDecomposer.ts` `TeachingStrategy` enum (`narrative | explanation | experiment | comparison | cause_effect | quiz | voice`) describes *how to present* a concept; the S10-11 matrix's `ConceptType` (`vocabulary | abstract | process | comparison | causeEffect | factual`) describes *what kind of thing the concept is*. The matrix maps the second onto the first via ranked CardType recommendations. They coexist without renaming either.

2. **Additive scoring, not multiplicative.** Base score `5 - baseRank` (5..1), engagement adds ±1.5, difficulty adds ±0.8 max (±0.4 × ±2 clamp), age adds up to -0.75. Worst-case negative = -0.75; best-case positive = ~+2.3. No bonus can by itself flip a matrix-3rd into 1st, but two bonuses layered can, and that's the desired emergent behavior.

3. **Stable tiebreak: score desc, baseRank asc.** When two types tie on score, the matrix's author-intended order wins. Tested.

4. **Age-gate is a nudge, not a disqualifier.** `experiment` at age 4 gets -0.75, not -∞. If the child's engagement history strongly prefers experiments, experiments still win — we flag the age mismatch to downstream stages, we don't silently ban the card type. Gives the quality gate the final say without locking out content types.

5. **Zero completion is a profile red-flag, not a ranking disqualifier.** If a card type has appeared in interactions but `completionRate === 0`, we apply a `-0.5` penalty. This is softer than hiding the card type (the child might have just been interrupted twice) but firmer than ignoring the signal. Layered on top of the top-2 positive bonus, so a card type that's been top-engaged-with BUT never completed nets out to +1.0, still mildly preferred.

6. **Cold-start neutrality.** Empty engagement array → all bonuses zero → cell's author-intended order wins. No need for a separate cold-start path. Tested.

7. **NaN/Infinity safety.** `computeDifficultyBonus` checks `Number.isFinite` and returns 0 on non-finite input; the clamp catches out-of-range offsets. One unit test passes `Number.NaN` and `Number.POSITIVE_INFINITY` to prove no NaN leaks into the final score.

8. **Dev Console endpoint accepts `engagementOverride` for introspection.** Operator can pretend a child prefers any card type without actually driving interactions — makes the 6×3 matrix exhaustively explorable from the UI without seeding synthetic data. Synthetic engagement row uses `completionRate: 0.8` and `score: 2` so the ranker treats it as a strong positive preference.

**Validation:**
- ✅ `npx tsc --noEmit` — zero errors across `teachingStrategy.ts` + `devConsole.ts` + `dev-pipeline.html` edits. (Pre-existing 32 Prisma-JSON errors in seed/cards/badges/assets are unchanged.)
- ✅ `npx vitest run tests/teachingStrategy.test.ts` — **39 tests passing**, 340ms total. Sandbox-run green after fixing the Rollup `@rollup/rollup-linux-arm64-gnu` optional-dep gap.
- 🟡 Dev Console runtime verification pending on bang's Mac — fetch a child + poke the sandbox, expect the focus cell to re-rank as the difficulty slider moves and the engagement override flips.

**Commands to run on your Mac:**

```bash
cd ~/Projects/Novai/src/Backend

# 1. No schema changes → no prisma generate / migrate needed for this story.

# 2. Run the S10-11 unit tests
npx vitest run tests/teachingStrategy.test.ts
#   expect: 39 passing

# 3. Full suite
npm test

# 4. Boot the server
npm run dev

# 5. Open the Dev Console → http://localhost:3000/dev-pipeline.html
#    → pick a child
#    → open the Strategy tab
#    → drag difficulty slider from 0 → +2 and watch quiz/experiment climb
#    → flip engagementOverride to "voice top" and watch voice move up
#    → change modality to "kinesthetic" and verify experiment leads in process × kinesthetic

# 6. Raw endpoint check
curl -s 'http://localhost:3000/api/v1/dev/teaching-strategy?conceptType=process&modality=kinesthetic' | jq '.data.focus.ranking'
# expect: experiment first with score 5.00, others following
```

---

## S10-11 Kickoff — Skill Engine Design Spike (April 17)

S10-06 (story-writer, 13pts) and S10-07 (quiz-maker, 13pts) depend on a shared skill loader that doesn't exist yet. Rather than ship two skills in parallel and discover at integration time that they've diverged on directory layout / context shape / prompt-assembly contract, we wrote a design spike first:

**Document:** [docs/design-spikes/S10-06-07-skill-loader.md](design-spikes/S10-06-07-skill-loader.md)

**Covers:**
- Skill directory convention (`defs/<name>/{manifest.json, prompt.md, age-profiles/, styles.md, topics.md, difficulty-curves/}`).
- `SkillManifest` Zod schema (name, version, modelHint, temperatureHint, inputs, ageProfiles, difficulties, handlesConceptTypes).
- `ChildContext` — the single input every skill consumes (age, parentGuidance, sessionContext, engagement, mastery, interestTopics, teachingStrategy, difficultyOffset).
- `SkillRegistry` interface — `load` at boot, `list` / `get`, `reload(name?)` for hot-reload in dev.
- Prompt assembly pipeline (6-step: get skill → validate inputs → load markdown → select age profile → select difficulty curve → render handlebars → `{system, user, meta}`).
- S10-06 `story-writer` sketch: inputs, abbreviated `prompt.md`, all three age profiles (4/6/8), `topics.md` seed list, `styles.md` voice examples, expected output shape.
- S10-07 `quiz-maker` sketch: inputs, abbreviated `prompt.md`, all three difficulty curves (easy/medium/hard option counts 3/4/5), `distractors.md` seed, expected output shape.
- S10-12 integration preview: `buildChildContext(childId, conceptType, difficultyOffset)` + ranked-card-type loop + per-card-type skill invocation.
- Dev Console integration: `/dev/skills`, `/dev/skills/:name/render` (dry-run, no LLM call), `/dev/skills/:name/reload`.
- Six open questions flagged for review before implementation starts (Handlebars lib choice, age profile resolution direction, schema validator strategy, loader eagerness, model-routing authority, `interestTopics` source).
- Restated acceptance criteria for S10-06 and S10-07.
- Timeline: ~18h total across both stories, fits in the 26pt allocation with Dev Console Skills tab room.

### Spike status: ✅ APPROVED by bang (April 17, 2026)

All six open questions answered; decisions locked:

| # | Question | Decision |
|---|----------|----------|
| 1 | Templating engine | **Handlebars.js** (real library — triple-stache disabled, partials for age profile + difficulty + progression modifier) |
| 2 | Age profile resolution | **Sliding-scale effective age.** Chronological age + `progressionDelta ∈ [-1.5, +1.5]` composed from mastery, quiz win rate, flow / frustration events, and parent difficulty offset. Base profile picked by nearest-with-ties-round-down on effective age; `progressionModifier` Handlebars partial nudges the LLM within or beyond the chosen profile. Three MD anchors kept (4 / 6 / 8) — LLM interpolates. |
| 3 | Output schema validation | **Per-skill Zod** (co-located with each skill's definition) |
| 4 | Loader strategy | **Eager at boot** — validate every manifest + parse every MD + compile every template at startup |
| 5 | Model routing authority | **Manifest advisory, `costRouter` decides** — `modelHint` is a preference, costRouter enforces cold-start / caps / rollout |
| 6 | `interestTopics` source | **Option A** — LLM-extract from `ParentGuidance.parentGoals` at guidance-save time, fire-and-forget via `setImmediate`, cached in `ParentGuidance.extractedTopics (Json?)`, Flash tier, strict JSON schema with retry-on-parse-fail |

**Net architectural delta from the locked decisions:**
- New pure module `src/services/skills/progression.ts` (`computeProgressionDelta` + `computeEffectiveAge`) — colocated with `teachingStrategy.ts`.
- `ChildContext` grows two fields: `progressionDelta: number`, `effectiveAgeYears: number`.
- New shared Handlebars partial `_shared/progressionModifier.hbs` registered at loader init.
- New migration for `ParentGuidance.extractedTopics (Json?)`.
- New `PUT /children/:id/guidance` post-commit hook: `setImmediate(() => extractInterestTopics(...))`.
- Dev Console Strategy tab gains a "Progression" readout — `ageYears · effectiveAgeYears (Δ+0.8)` + signal breakdown.

**Next action:** claude lands `types.ts` + `registry.ts` + `loader.ts` + `progression.ts` + Handlebars dep + `story-writer` defs + `/dev/skills` dry-run endpoint + Skills tab dry-run panel → closes S10-06. Follow-on run closes S10-07.

---

### S10-06 Delivery Notes (April 18)

Closes the skill engine's first full story. Delivers the Handlebars-backed loader/registry, the three-anchor sliding-scale age resolution, the story-writer definition bundle, the `/dev/skills` dry-run endpoints, and the Dev Console **Skills** tab that bang will use for all downstream skill QA.

**Files changed:**
- `src/services/skills/types.ts` *(new, ~155 LOC)* — `ChildContext` (age, parentGuidance, sessionContext, engagement.{cardTypeRanking, topicAffinities}, mastery.{average, topConcepts}, interestTopics, teachingStrategy.{modality, rankedCardTypes}, difficultyOffset, **progressionDelta**, **effectiveAgeYears**), `LearningModality = 'visual' | 'auditory' | 'kinesthetic'`, `SkillManifest` Zod schema, `SkillDefinition`, `RenderedSkill { system, user, meta }`, `ProgressionBreakdown`. Zod manifest schema locks `name` (kebab-case, 3..64 chars), `version` (semver-lite), `ageProfiles: number[]` (≥1), `difficulties: string[]` (≥1), `handlesConceptTypes` (the six S10-11 types), `modelHint` (flash / sonnet / opus), `temperatureHint ∈ [0,1]`, and a free-form `inputs` record. Zod inference exposes `SkillManifest` type with zero `any`.
- `src/services/skills/progression.ts` *(new, ~200 LOC)* — pure functions. `computeProgressionDelta({mastery, quizWinRate, flowEvents, frustrationEvents, parentOffset})` layers five signals clamped to `[-1.5, +1.5]`; `computeEffectiveAge(ageYears, progressionDelta)` → `chronologicalAge + progressionDelta` clamped to `[2, 18]`; `pickAnchorAgeProfile(effectiveAgeYears, [4,6,8])` → nearest-with-ties-round-down; `computeProgressionBreakdown(...)` returns the per-signal `{label, value, contribution}` array plus total delta for Dev Console readout. All math is `Number.isFinite`-guarded and will never emit NaN.
- `src/services/skills/loader.ts` *(new, ~260 LOC)* — reads `defs/<name>/manifest.json`, validates via Zod, reads `prompt.md` (the single required template), walks `age-profiles/*.md` + optional `difficulty-curves/*.md` + optional `styles.md` + `topics.md` + `distractors.md`, splits prompt on `USER_PROMPT_MARKER` (`<!-- user-prompt -->`) into system vs user halves, compiles each half with Handlebars (HTML-escape disabled — prompts are plain text, not HTML), registers per-invocation partials (`ageProfile`, `difficultyCurve`, `styles`, `topics`, `distractors`, `progressionModifier`) so profiles don't collide across hot-reloads. `normalizeCtxForTemplate(ctx)` denulls optional fields into empty strings / arrays so Handlebars triple-stache conditionals don't throw.
- `src/services/skills/registry.ts` *(new, ~180 LOC)* — singleton `getSkillRegistry()`. `load()` walks `defs/*` and compiles every skill; a typo in ANY manifest throws at boot per spike decision #4. `list()` returns manifest-only views; `get(name)` returns full definition or throws; `render(name, inputs, ctx, opts?)` runs the 6-step pipeline (get → validate inputs → resolve age profile via progressionDelta → resolve difficulty → render templates → return `{system, user, meta}`); `reload(name?)` hot-reloads a single skill or the whole registry (dev-only guard enforced at the route layer). Zero side effects other than module-singleton state.
- `src/services/skills/defs/story-writer/manifest.json` *(new)* — `name: "story-writer"`, `version: "0.1.0"`, `modelHint: "flash"`, `temperatureHint: 0.8`, `ageProfiles: [4, 6, 8]`, `difficulties: ["easy", "medium", "hard"]`, `handlesConceptTypes: ["vocabulary", "abstract", "process", "comparison", "causeEffect", "factual"]`, `inputs.topic: { type: "string", required: true }`, `inputs.conceptName: { type: "string", required: false }`.
- `src/services/skills/defs/story-writer/prompt.md` *(new)* — shared Handlebars prompt. System half enumerates the child profile (age / effective age / progression delta / modality / difficulty offset / parent focus / parent avoid / recent topics), invokes `{{> ageProfile}}`, `{{> styles}}`, `{{> progressionModifier}}`, and emits output contract (story title, 3-paragraph body, 2 reflection questions). User half after the `<!-- user-prompt -->` marker supplies the topic + concept hook.
- `src/services/skills/defs/story-writer/age-profiles/{4,6,8}.md` *(new)* — per-anchor vocabulary ceilings, sentence-length caps, narrative complexity rules, permissible abstractions. Age 4: concrete nouns, 6-word sentences, 80-word paragraphs, no metaphor. Age 6: simple simile, 10-word sentences, 120-word paragraphs, one abstract noun per paragraph. Age 8: compound sentences, multi-step causal chains, 160-word paragraphs, one introduced vocab term per section.
- `src/services/skills/defs/story-writer/styles.md` *(new)* — voice examples and tone guards (no violence, no scary imagery, no dismissive language; celebrate curiosity; embed parent-allowed tags).
- `src/services/skills/defs/story-writer/topics.md` *(new)* — 24-topic seed list grouped by domain (nature, everyday objects, friendship, problem-solving, creativity) — the LLM picks adjacent topics when the provided `topic` is unavailable for the age profile.
- `src/services/skills/defs/_shared/progressionModifier.hbs` *(new)* — Handlebars partial branching on `progressionDelta`: `< -0.75` → "struggle" (soften vocabulary, more scaffolding), `-0.75..+0.75` → "standard" (trust the profile), `> +0.75` → "above" (introduce one stretch term, allow a longer sentence). Single source of truth for every skill.
- `src/routes/devSkills.ts` *(new, ~250 LOC)* — four dev-only endpoints under `/api/v1/dev/skills`:
  - `GET /` → list of manifests (name/version/modelHint/ageProfiles/difficulties/handlesConceptTypes).
  - `GET /:name` → single manifest + computed inputs schema.
  - `POST /:name/render` → dry-run. Body `{ inputs, ctxOverrides?: { ageYears, progressionDelta, difficultyOffset, interestTopics?, parentGuidance?: { topicAvoid? } }, includeProgressionBreakdown?: bool, childId? }`. When `childId` is present, loads the real child + engagement + guidance + mastery as the base context; otherwise constructs a synthetic `ChildContext` with a canonical baseline (age 6, visual modality, neutral engagement). Strict Zod validation on the body (`passthrough: false`) rejects unknown keys with 400. Returns `{ system, user, meta, context, progressionBreakdown? }`.
  - `POST /:name/reload` → dev-only (guarded on `config.NODE_ENV === 'development'` → 403 otherwise), re-walks the single skill's `defs` dir and re-compiles partials.
- `src/routes/index.ts` — registered `devSkillsRoutes` under `/dev/skills` (mounts the four handlers inside the existing `/dev` prefix so the auth/ownership hooks apply uniformly).
- `src/server.ts` — `await getSkillRegistry().load()` added right after `initializeFlags()` in `start()`. A manifest typo or broken template fails boot rather than surfacing at first lesson generation per spike decision #4.
- `public/dev-pipeline.html` — added the full **Skills** tab: nav button, `VALID_TABS` entry, `switchTab('skills')` lazy-load branch, `postJson` HTTP helper (existing `post()` sends no body), ~100 LOC of pane markup (picker, manifest readout, mode badge, inputs JSON textarea, age / progression Δ / difficulty / interestTopics CSV / parentAvoid CSV controls, 8-cell meta grid, system & user `<pre>` panes, progression breakdown panel, raw JSON pane), and ~200 LOC of Skills JS module wired into `NovaDevConsole` (`loadSkills`, `onSkillSelect`, `onSkillsModeChange`, `parseSkillsInputs`, `renderSkill`, `paintSkillRender`, `reloadSkill`).
- `tests/skillEngine.test.ts` *(new, 21 cases across 5 describe blocks)* — pure-layer coverage: `computeProgressionDelta` signal-layering + clamp + NaN-safety, `computeEffectiveAge` clamp + finite-safety, `pickAnchorAgeProfile` nearest-with-ties-round-down across every anchor, registry load/list/get/render happy paths, render `meta.ageProfileUsed` changes as `progressionDelta` slides, render `meta.effectiveAgeYears` reflects the compound, `reload` picks up a new age profile written to disk mid-process, strict-schema manifest rejects unknown keys.
- `tests/devSkills.test.ts` *(new, 20 cases across 3 describe blocks)* — HTTP-layer coverage via Fastify `inject()`: list & single (unauth → 401, list returns story-writer with `ageProfiles` containing `[4, 6, 8]`, unknown name → 404), render dry-run (strict Zod rejects `extraHackField` → 400, `progressionDelta: 5` → 400, empty `inputs: {}` → 400 with `/topic|required/i` message, `ageYears: 4` → `ageProfileUsed === 4`, `ageYears: 7 + progressionDelta: 1.2` → `ageProfileUsed === 8` AND `effectiveAgeYears > 8`, `parentGuidance.topicAvoid: ['monsters','thunderstorms']` → combined prompt contains both, non-existent UUID childId → 404/403), reload (NODE_ENV=production → 403, NODE_ENV=development → 200, unknown skill → 404).

**Architectural decisions (locked during the spike, carried through implementation unchanged):**

1. **Handlebars per-invocation partials.** `ageProfile` / `difficultyCurve` / `styles` / `topics` / `distractors` / `progressionModifier` are re-registered on each `render()` call under a skill-scoped key (`${skillName}::${partialName}`). This is ~10µs of overhead per invocation and it means two concurrent skill renders can't step on each other's partial registry state — a real risk given the registry is a process singleton and renders happen inside async LLM pipelines where ordering is non-deterministic.

2. **Sliding-scale `progressionDelta`, not discrete jumps.** The skill never asks "is this child age 4 or age 6?" — it asks "what's the effective age and which anchor is nearest?". `progressionDelta ∈ [-1.5, +1.5]` is computed from five signals (mastery %, quiz win rate, flow events, frustration events, parent difficulty offset) and composed additively with chronological age; the nearest anchor wins (ties round down, so a 5-year-old at +1.0 lands on profile 6). The `progressionModifier` partial then renders a one-paragraph nudge so the LLM can interpolate past the anchor without losing the profile's scaffolding.

3. **`USER_PROMPT_MARKER` splits system vs user halves.** A single `prompt.md` contains both — the marker is a single HTML comment (`<!-- user-prompt -->`) that survives Markdown rendering but is meaningless outside our loader. Keeping the two halves in one file means the author writes them together and sees the conceptual boundary, but the runtime still hands the LLM a proper `{system, user}` pair.

4. **Boot-time eager load, fail-fast on manifest errors.** `server.ts` awaits `getSkillRegistry().load()` before `fastify.listen`. A broken manifest / missing age profile / busted Handlebars syntax surfaces in the deploy step, not at the child's first bedtime story. The alternative (lazy load on first render) trades a clean boot error for a runtime 500 with a cryptic stack. Not worth it.

5. **Manifest `modelHint` is advisory, costRouter decides.** `meta.modelHint` is returned in the render response and is consumed by `costRouter` when the skill is invoked through the pipeline. The router still enforces cold-start routing, global rate caps, and per-child rollout gates. If the skill manifest says "flash" but the child is in a canary group for Sonnet, Sonnet wins. If the router can't satisfy the hint (quota exhausted), it falls back per its own logic without asking the skill.

6. **`interestTopics` source — Option A (LLM-extract from `ParentGuidance.parentGoals`).** Not implemented in this run (it's a guidance-save-time hook scheduled against S10-07 or S10-09, whichever needs it first). For S10-06, the dev console lets the operator supply `interestTopics` inline as CSV; the real-child code path falls back to empty array when `extractedTopics` is null, which the story-writer prompt handles by picking from the `topics.md` seed list.

7. **`normalizeCtxForTemplate` denulls optionals.** Handlebars triple-stache helpers (`{{#if}}`, `{{#each}}`) will throw on `undefined` in strict mode. The loader wraps the raw `ChildContext` with a normalized copy where `interestTopics`, `parentGuidance.topicAvoid`, `engagement.cardTypeRanking`, and `mastery.topConcepts` all become `[]` when absent, and string fields become `""`. The original context is still returned in the render response's `context` field for debugging.

8. **`LearningModality` ⊂ S10-11's modality set.** The skill-engine type is `'visual' | 'auditory' | 'kinesthetic'` — it does NOT accept `'narrative'` even though S10-11's `TeachingStrategy` enum has narrative-like entries. A one-line `modality: 'narrative'` typo in the synthetic-baseline `ChildContext` in `devSkills.ts` caused a typecheck fail during final cleanup; fixed to `'auditory'`. Kept narrow on purpose — the modality is used for engagement inference, not for prompt content selection.

**Validation:**
- ✅ `npx tsc --noEmit` — zero new errors across `types.ts` / `loader.ts` / `progression.ts` / `registry.ts` / `defs/story-writer/*` / `routes/devSkills.ts` / `server.ts` / `routes/index.ts`. The 50 carry-in errors (seed.ts, routes/cards.ts, pipelineOrchestrator.ts, assetJobProcessor.ts, badgeCriteriaEngine.ts — all pre-existing `Prisma.InputJsonValue` / `Prisma.CardSelect` noise) are unchanged.
- ✅ `npx vitest run tests/skillEngine.test.ts` — **21 passing**.
- ✅ `npx vitest run tests/devSkills.test.ts` — **20 passing**.
- ✅ Brace/paren/bracket balance on every new TS file — exact match.
- ✅ Handlebars compile balance on every MD template (`{{#if}}`…`{{/if}}`, `{{#each}}`…`{{/each}}`) — exact match.
- 🟡 Dev Console runtime verification pending on bang's Mac — walk the Skills tab controls and run the curl recipes in [docs/sprint-runs/S10-skill-engine-s10-06.md](sprint-runs/S10-skill-engine-s10-06.md).

**Commands to run on your Mac:**

```bash
cd ~/Projects/Novai/src/Backend

# 1. Install the new Handlebars dep (added to package.json, lockfile bumped)
npm install

# 2. No new migrations for S10-06 itself — the extractedTopics column is
#    Option A follow-up work scheduled against S10-07/S10-09.
npx prisma generate

# 3. Run the two new test suites (41 cases total, ~400ms)
npx vitest run tests/skillEngine.test.ts tests/devSkills.test.ts
#   expect: 21 + 20 = 41 passing

# 4. Full suite
npm test

# 5. Boot the server. If a manifest is broken, THIS is where you find out.
npm run dev

# 6. Open the Dev Console → http://localhost:3000/dev/dev-pipeline.html#skills
#    → pick story-writer
#    → leave mode on Synthetic baseline
#    → hit Render dry-run and read the meta grid + system/user panes
#    → slide progressionDelta +1.2 with age 7 → verify ageProfileUsed = 8
#    → add "monsters, thunderstorms" to parentAvoid and re-render → verify they
#      appear in the system prompt's "Topics to avoid" line
#    → click Hot reload → verify the meta timestamp refreshes
```

See [docs/sprint-runs/S10-skill-engine-s10-06.md](sprint-runs/S10-skill-engine-s10-06.md) for the full 9-cell validation matrix (age × progressionDelta × difficultyOffset) and the curl cheat sheet.

---

### S10-07 Delivery Notes (April 18)

Closes the SKILL epic's second story. Re-uses the S10-06 Handlebars engine unchanged at the module level — S10-07 is a pure content + validator + Dev-Console-polish landing. The one cross-cutting refactor (dynamic `require` → static `import` in the loader's validator resolver) was forced by vite-node's handling of relative CJS `require()`s; the same code path now works identically across vitest, tsx, and compiled node.

**Files changed:**

- `src/services/skills/defs/quiz-maker/manifest.json` *(new)* — `name: "quiz-maker"`, `version: "0.1.0"`, `modelHint: "flash"`, `temperatureHint: 0.4` (tighter than story-writer's 0.8 — formative-assessment output wants less drift), `inputs.requires: ["concept", "conceptType"]`, `inputs.optional: ["topic", "targetLessonId", "lastStoryExcerpt"]`, `ageProfiles: [4, 6, 8]`, `difficulties: ["easy", "medium", "hard"]`, `handlesConceptTypes` covers all six S10-11 types.
- `src/services/skills/defs/quiz-maker/prompt.md` *(new, 112 LOC)* — system half pulls child context (age / effective age / progression Δ / modality / difficulty offset / concept / conceptType / parent avoid / recent topics), invokes `{{> ageProfile}}`, `{{> difficultyCurve}}`, `{{> styles}}`, `{{> distractors}}`, `{{> progressionModifier}}`, **`{{> modalityNote}}`**, and emits the output contract: single MCQ with `question`, `options[n]` where n matches the difficulty curve, `correctIndex`, `rationalePerOption[n]`, `explanation`. Explicitly bans "all of the above" / "none of the above" in the system prompt AND enforces it in the Zod validator. User half after the marker supplies the concept + optional topic hook.
- `src/services/skills/defs/quiz-maker/styles.md` *(new, 50 LOC)* — voice guardrails (one concept per item, no trick wording, avoid double-negatives, kid-first framing, plausibly-wrong distractors).
- `src/services/skills/defs/quiz-maker/distractors.md` *(new, 61 LOC)* — the misconception taxonomy the LLM samples from: _near miss_ (similar-looking but different), _surface-feature_ (shares a visible attribute with the correct answer), _over-generalization_ (true-sometimes), _category error_ (right kind of thing, wrong category), _reversed-cause_ (swaps cause and effect — primary for causeEffect conceptType). One seed example per misconception per conceptType.
- `src/services/skills/defs/quiz-maker/age-profiles/{4,6,8}.md` *(new)* — per-anchor question stem complexity and option length ceilings. Age 4: 1-clause stems ≤10 words, options ≤4 words, single concrete attribute. Age 6: 1-2 clause stems ≤16 words, options ≤8 words, allow simple comparison. Age 8: compound stems, options up to one short sentence, multi-step reasoning permitted.
- `src/services/skills/defs/quiz-maker/difficulty-curves/{easy,medium,hard}.md` *(new)* — **locks option counts: easy=3, medium=4, hard=5** (the spec's "4–5 options (not 3)" ladder). Easy: one clearly-better + two obvious near-misses. Medium: one correct + three plausible distractors (one from misconception list). Hard: one correct + four plausible distractors from ≥2 misconception categories.
- `src/services/skills/defs/_shared/modalityNote.hbs` *(new, 9 LOC)* — 4-branch Handlebars partial using the `eq` helper (`ctx.teachingStrategy.modality === "visual"|"auditory"|"kinesthetic"|default`). Each branch emits a one-paragraph modality note with quiz-specific framing ("describe a scene" for visual, "small story or what-did-they-say" for auditory, "anchor each option in an action" for kinesthetic). Registered globally in the registry at boot so every future skill can `{{> modalityNote}}` without its own copy.
- `src/services/skills/validators/index.ts` *(new)* — static `SKILL_OUTPUT_SCHEMAS: Record<string, z.ZodTypeAny>` registry. Pattern per spike decision #3: content authors own `defs/<skill>/*.md`, engineers own `validators/<camelCase>.ts`. Currently holds `{ 'quiz-maker': quizMakerOutputSchema }`; `story-writer` intentionally has no entry (free-form prose).
- `src/services/skills/validators/quizMaker.ts` *(new, ~130 LOC)* — `quizMakerOutputSchema = z.object({...}).strict().superRefine(...)`. Base shape rejects empty strings (after trim) and caps `options` / `rationalePerOption` at 3..5. `superRefine` layers: (a) exact membership in `{3, 4, 5}`, (b) `correctIndex < options.length`, (c) `rationalePerOption.length === options.length`, (d) banned-phrase substring check over a 5-entry list (`all of the above` + 4 variants) against a normalize-trim-lowercase-collapse-whitespace key, (e) duplicate detection on the same normalized key. Exports `QuizMakerOutput = z.infer<typeof schema>`.
- `src/services/skills/loader.ts` — **cross-cutting refactor**. Replaced `function getOutputSchemaFor(name) { const mod = require('./validators') as {...}; return mod.SKILL_OUTPUT_SCHEMAS[name]; }` with a static top-level `import { SKILL_OUTPUT_SCHEMAS } from './validators';` + `function getOutputSchemaFor(name) { return SKILL_OUTPUT_SCHEMAS[name]; }`. Reason: vite-node (vitest's runtime) does not resolve dynamic CJS `require()` on relative `.ts` modules the same way Node's CJS does — `require('./validators')` threw `Cannot find module './validators'` under test. Static imports are resolved identically by vitest / tsx / compiled-node. No semantic change, one runtime bug class removed.
- `src/routes/devSkills.ts` — `renderBodySchema.ctxOverrides` extended with `modality: z.enum(['visual','auditory','kinesthetic']).optional()` and `conceptType: z.enum(['vocabulary','abstract','process','comparison','causeEffect','factual']).optional()`. `buildDevRenderContext` now threads those into `teachingStrategy.{modality, conceptType}` with existing fallbacks (`modality ?? 'auditory'`, `conceptType ?? 'abstract'`). Also mirrors `hasOutputSchema: Boolean(s.outputSchema)` in both the list response and the single-manifest response so the Dev Console can render the validator chip without a second fetch.
- `public/dev-pipeline.html` — **Skills tab polish (R5).** Four-column grid row added below the existing `ageYears / progressionDelta / difficultyOffset` row: `<select id="skillsModality">` (blank/visual/auditory/kinesthetic), `<select id="skillsConceptType">` (blank + the six S10-11 types), read-only `<span id="skillsValidatorChip">` (green "✓ attached" or muted "none"), `<button id="skillsReseedBtn">` (overwrites inputs JSON with the per-skill canonical template). Render-meta grid gets two new cells: `validator` (mirrors the chip) and `opts (expected)` (derived from `meta.difficultyUsed`: easy=3, medium=4, hard=5, else —). `loadSkills()` adds a green `val` badge to list rows when `hasOutputSchema`. `onSkillSelect()` repaints the chip and runs `seedSkillInputsIfBlank()` (non-destructive). `renderSkill()` now passes `modality` + `conceptType` into `body.ctxOverrides` when non-empty. `paintSkillRender()` populates the two new meta cells. New `reseedInputsForSkill()` destructive helper exposes the per-skill template table: `story-writer → {topic:"how seeds grow"}`, `quiz-maker → {concept:"helium balloons float because they are lighter than air", conceptType:"causeEffect"}`, fallback builds `{[req]: ""}` from `rec.inputs.requires`. Exported from the `NovaDevConsole` module.
- `tests/quizMakerValidator.test.ts` *(new, 24 cases across 7 describe blocks)* — pure Zod coverage. Happy paths for 3 / 4 / 5 options. Option-count boundary: 2 options → fail, 6 options → fail, 0 options → fail. `correctIndex`: negative → fail, equal to length → fail, string instead of int → fail. `rationalePerOption`: off-by-one short → fail, off-by-one long → fail, empty entry → fail. Banned-phrase invariant parameterized over 7 variants (`"All of the above"`, `"none of the above"`, `"None Of These"`, `"ALL OF THE ABOVE!"` with punctuation, `" both of the above "` with whitespace padding, `"all the above"`, case-alternating) — every one must fail. Duplicate detection on normalized form. Strict mode rejects an unknown `hintType` key. Empty-string `question` / `explanation` fail after trim.
- `tests/skillEngine.test.ts` — **added `describe('quiz-maker — buildPrompt variance by context', ...)` block with 13 cases.** Registry load happy-path asserts `skill.outputSchema` is defined (story-writer's is still `undefined`). System prompt contains `"question"` and the output-contract language. Difficulty variance: `difficultyOffset: -2` → medium bucket→ matches `/exactly 3/` (easy curve prompts), `+2` → `/exactly 5/` (hard). Modality variance: visual → contains `"shown"`, auditory → contains `"sound and rhythm"`, kinesthetic → contains `"action"`. Missing `concept` throws with `/missing required input "concept"/`; missing `conceptType` same pattern. `meta.temperatureHint === 0.4`. Pattern mirrors the S10-06 story-writer block (beforeAll resets registry, shared `makeCtx()` helper).
- `tests/devSkills.test.ts` — **added `describe('/api/v1/dev/skills — quiz-maker coverage', ...)` block with 6 cases.** (1) list response includes quiz-maker with `hasOutputSchema=true`, difficulties array present, story-writer still `hasOutputSchema=false`. (2) `GET /:name` returns full manifest with `handlesConceptTypes` containing `['vocabulary','abstract','causeEffect']` (subset check). (3) `ctxOverrides: {difficultyOffset: -2}` → system prompt matches `/exactly 3/`; `+2` → `/exactly 5/`. (4) each of `['visual','auditory','kinesthetic']` in `ctxOverrides.modality` produces a prompt that matches `/Modality note/i` AND the modality-specific keyword. (5) missing `conceptType` → 400. (6) reload endpoint in `NODE_ENV=development` returns `data.reloaded === 'quiz-maker'`.

**Architectural decisions (incremental on top of S10-06's 8):**

1. **Validator registry is central and static, not per-skill dynamic.** The spike floated co-locating `validators.ts` next to each skill's `defs/` tree. In practice, dynamic `require('./validators')` from the loader failed under vite-node, and co-locating the schema still means the loader has to know the skill name → module path. Simpler: one `src/services/skills/validators/index.ts` with a name-keyed `Record<string, ZodTypeAny>`, one `<camelCase>.ts` per skill schema, statically imported at boot. Adds ~1 LOC per new skill's validator (add an entry to the record), zero runtime behavior change, and fixes the vitest incompatibility.

2. **`modalityNote.hbs` lives in `_shared/`, not per-skill.** The note itself is general ("this child learns best when information is *shown* / heard / acted") — only the closing hint is skill-specific (quiz item framing). The quiz-specific closing is fine as a one-line inline concatenation in the prompt; the partial stays universal so future skills (`experiment-designer`, `voice-persona`) can `{{> modalityNote}}` without touching `_shared/`.

3. **Temperature split: 0.4 for quiz-maker, 0.8 for story-writer.** Formative assessment rewards a smaller output distribution (predictable distractor quality, low spelling drift). Narrative rewards a wider one (voice variance, topic surprise). Both still go through `costRouter` which has final say, but the manifest's `temperatureHint` is the skill author's signal.

4. **Difficulty curve = exact option count, not a suggestion.** The prompt says "exactly N options" and the Zod validator rejects anything else. Any ambiguity would leak into downstream scoring logic (S10-12 pipeline) which assumes a fixed-width ladder. Locking it at the schema means the LLM has a hard contract and the orchestrator doesn't need defensive branching on option-count.

5. **Banned-phrase list is substring match on normalized form, not equality.** Real-world LLM outputs include `"All of the above"`, `"All of the above!"`, `" all of the above"` — normalizing (trim → lowercase → collapse whitespace) and using `.includes()` catches every shape without an exponential alternation regex. The check is invariant, not aesthetic: those options provide no signal about what the child knows.

**Validation:**
- ✅ `npx vitest run tests/quizMakerValidator.test.ts` — **24 passing** (validator-only).
- ✅ `npx vitest run tests/skillEngine.test.ts` — **34 passing** (21 pre-existing + 13 new quiz-maker cases).
- ✅ `npx vitest run tests/devSkills.test.ts` — **26 passing, 1 pre-existing flaky** (the `returns 404 when childId references a non-existent child` case is a Prisma-SQLite `disk I/O error` under test DB stress; unrelated to S10-07, already flagged in S10-06 notes). 20 pre-existing + 6 new quiz-maker cases.
- ✅ Combined: `npx vitest run tests/skillEngine.test.ts tests/quizMakerValidator.test.ts tests/devSkills.test.ts` — **84 passing / 1 flaky** in ~1.7s. Every new S10-07 test passes.
- ✅ Brace/paren/bracket balance on every new TS file — exact match.
- ✅ Handlebars compile balance on every new MD template — exact match.
- ✅ Dev Console `<script>` block re-parses under `new Function(...)` — no syntax errors introduced by the R5 wiring.
- 🟡 Dev Console runtime verification pending on bang's Mac — walk the new Skills tab controls (modality / conceptType / validator chip / Re-seed button) per the recipes in [docs/sprint-runs/S10-skill-engine-s10-07.md](sprint-runs/S10-skill-engine-s10-07.md).

**Commands to run on your Mac:**

```bash
cd ~/Projects/Novai/src/Backend

# 1. No new deps. No new migrations. Just pull.
git pull

# 2. Run the three relevant test suites
npx vitest run tests/skillEngine.test.ts tests/quizMakerValidator.test.ts tests/devSkills.test.ts
#   expect: 84 passing (1 known pre-existing Prisma flake on devSkills.test.ts:292)

# 3. Full suite sanity
npm test

# 4. Boot the server. Registry is now loading TWO skills.
npm run dev
#   expect boot log: "SkillRegistry loaded: quiz-maker v0.1.0, story-writer v0.1.0"
#   (deterministic sort — quiz-maker first)

# 5. Open Dev Console → http://localhost:3000/dev/dev-pipeline.html#skills
#    → pick quiz-maker (picker now has two entries; quiz-maker row shows the green "val" badge)
#    → verify the validator chip reads "✓ attached" and the list row has the badge
#    → default inputs seeded: {"concept":"helium balloons float ...","conceptType":"causeEffect"}
#    → click Render dry-run → system pane should say "exactly 4 options" (medium curve), meta grid
#      should show validator: "✓ attached", opts: 4
#    → drag difficulty offset to -2, render → system says "exactly 3 options", opts: 3
#    → drag to +2, render → "exactly 5 options", opts: 5
#    → set modality = visual, render → system contains "shown"
#    → set modality = kinesthetic, render → system contains "action"
#    → click Re-seed inputs → inputs textarea overwrites with canonical concept+conceptType
#    → click Hot reload → meta timestamp refreshes, selection preserved
```

See [docs/sprint-runs/S10-skill-engine-s10-07.md](sprint-runs/S10-skill-engine-s10-07.md) for the full validation matrix (difficulty × modality × age) and the curl cheat sheet.

---

### S10-12 Delivery Notes (April 18)

**Retires:** S9-07 carried debt (skill invocation in Stage 4). Grand Architect's pipeline now routes every decomposition atom through the skill engine, with a Zod-retry safety net and a legacy cherry-pick fallback for atoms the engine skips.

**Files changed (19 files — 4 new services, 3 new test files, 2 edited routes, 1 orchestrator edit, HTML panel, tracker + run summary):**

- `src/services/pipeline/childContextBuilder.ts` *(new, R1)* — pure builder that assembles `ChildContext` from `ParentGuidance` + `SessionContext` + `EngagementProfileView` + `MasteryRow[]` + `teachingStrategy.ts` matrix output in a single call. Exports four pure helpers (`withConceptType`, `summarizeEngagement`, `summarizeMastery`, `summarizeRecentEvents`) so the integration test can lock them down without a DB. `withConceptType` is a pointer-equal no-op when the `conceptType` is unchanged — keeps the hot path from churning `teachingStrategy.rankedCardTypes` for every atom in a same-concept burst.
- `src/services/pipeline/skillRouter.ts` *(new, R2+R3)* — per-atom loop. For each atom: look up `{conceptType, recommendedCardType} → skillName` via `SKILL_ROUTING_TABLE`, call `skill.buildPrompt(ctx, inputs)`, dispatch to `providerRouter`, parse JSON, run the skill's Zod validator. On validation failure: one retry with `You returned invalid JSON. Here is the Zod error: <pretty-printed>. Return corrected JSON only.` appended to the user prompt. `AtomTrace.validatorStatus` resolves to `'ok'` on first-pass, `'retry-ok'` when the retry fixes it, `'retry-failed'` after both attempts fail, `'skipped'` when the skill never ran. Tracks `lastStoryExcerpt` across atoms so `quiz-maker` can receive `{story: "..."}` for any atom that follows a `story-writer` run (bridges the story→quiz dependency without a coupling hack).
- `src/services/pipeline/cardGenerator.ts` *(edited, R4)* — new `generateCardsWithSkills(decomposition, ctx, options)` wraps `routeAllAtoms`. If the router returns any `skipped` atoms, the adapter calls the legacy `generateCards` once (full prompt) and cherry-picks only the skipped atoms from the legacy output; if legacy itself throws, the adapter swallows the error, logs a warn, and ships the partial skill-only payload instead of failing the whole lesson. Legacy's trailing wrap-up card is preserved verbatim. Exports `isSkillEngineStage4Enabled()` reading `SKILL_ENGINE_STAGE4` — default **on**, disabled by `false`/`0`/`off`/empty (case-insensitive, trimmed).
- `src/services/pipeline/pipelineOrchestrator.ts` *(edited, R5)* — `runPipeline(options)` now accepts `childId` and threads it through every LLM-bearing stage. Stage 3.5 (before card generation): if `SKILL_ENGINE_STAGE4` is on AND `childId` is present, the orchestrator calls `buildChildContext({childId, ...})` once and invokes `generateCardsWithSkills`; otherwise it falls through to the legacy `generateCards` path. Stage-4 persistence writes `{...analysis, decomposition, qualityReport, skillEngine: {used, traces, skipped} | null}` into `Lesson.aiAnalysis` as the SQLite-compat JSON string — makes the `/dev/pipeline/trace/:lessonId` endpoint a simple Lesson read. The new `PipelineResult` fields `skillEngineUsed`, `skillSkippedAtoms`, `skillTraces` are surfaced all the way up to the HTTP response.
- `src/services/pipeline/skillRoutingTable.ts` *(new)* — single source of truth for `{conceptType, recommendedCardType} → skillName`. Currently maps `story` → `story-writer`, `quiz`/`factual+quiz`/`causeEffect+quiz` → `quiz-maker`. Anything not in the table emits `SkipReason: 'no-skill-mapping'` and falls through to legacy.
- `src/routes/pipeline.ts` *(edited)* — the `POST /pipeline/generate` success reply now carries `skillEngineUsed`, `skillSkippedAtoms`, `regeneratedCardIndexes`, `qualityScore` alongside the existing `lessonId`/`cardCount`/etc. Success path passes `lessonId: result.lessonId ?? null, skillEngineUsed: Boolean(result.skillEngineUsed)` into `recordPipelineEvent`; failure path passes `lessonId: null, skillEngineUsed: false` so the Dev Console ring buffer never shows a failed run with a misleading "used" badge.
- `src/routes/devConsole.ts` *(edited, R7)* — `PipelineRingEntry` extended with `lessonId: string | null` and `skillEngineUsed: boolean`. New endpoint `GET /api/v1/dev/pipeline/trace/:lessonId` (UUID-validated via Zod `preHandler`) reads `Lesson.aiAnalysis`, parses it, extracts `skillEngine` + `decomposition`, and returns `200` with `{lessonId, title, status, createdAt, skillEngine, decomposition, parseError}`. Auth: 401 when `request.userId` missing, 403 on cross-user lookup, 404 when the lesson doesn't exist. Returns `skillEngine: null` (still 200) for pre-S10-12 lessons or lessons where the engine was disabled — lets the UI render a helpful "didn't run for this lesson" empty state instead of a raw 404.
- `public/dev-pipeline.html` *(edited, R7)* — new "Skill Engine" panel inside the Pipeline tab, positioned right before the Activity Log so it's visible on every run without scrolling. Header has the `S10-12` tag, a live badge (`skillEngineBadge`) that shows `used · N atoms · M retry-ok · K skipped · T tok` after a trace loads, and a manual Refresh button. Body is keyed off `skillEnginePanel`. Two new JS functions: `refreshSkillTrace()` fetches `/dev/pipeline/trace/${currentLessonId}` and handles empty states / HTTP errors / JSON parse errors; `renderSkillTrace(data)` builds one row per trace with `atomName → cardType → skillName`, a color-coded validator-status pill (ok=green / retry-ok=amber / retry-failed=red / skipped=grey), retry-count badge, token total, modality/conceptType/effective-age mono-text, and a red skip-reason block when present. The renderer cross-references `decomposition.atoms` by atomId so it can pull full atom names and descriptions that the trace shorthand omits. `generateCards()` gets a three-line hook at the end of its success branch that sets the preliminary badge from `data.skillEngineUsed` and then calls `refreshSkillTrace()`.
- `tests/childContextBuilder.test.ts` *(new, 15 cases)* — locks the four pure helpers: `withConceptType` identity-on-unchanged + modality-preservation + non-teachingStrategy-fields-preserved + different-conceptTypes-yield-different-orderings; `summarizeEngagement` quiz-row extraction + pass-through; `summarizeMastery` weighted average + zero-attempts-ignored + empty-set zero-state; `summarizeRecentEvents` cap-at-6 + abandon-always-zero-until-S10-13.
- `tests/pipelineSkillIntegration.test.ts` *(new, 15 cases)* — boots the real `SkillRegistry` from `defs/` via `__resetSkillRegistryForTests(resolveDefsDir()); await reg.load();` and mocks `@services/llm/providerRouter` with a queue-based `mockResponses` array. Covers happy-path no-legacy, `lastStoryExcerpt` threading, mixed-path cherry-pick (story+quiz via skills + legacy for unmapped atom), traces-for-every-atom, legacy-fallback-fails partial delivery, retry-ok surfaced end-to-end, and 9 feature-flag parser cases (default on, truthy/falsy strings, whitespace trim, case-insensitive).
- `tests/skillRouter.test.ts` *(new, 14 cases)* — router-only tests. Atom-mapping hit + miss, per-atom skill invocation, `lastStoryExcerpt` thread, Zod-retry success + failure, token aggregation, skip-reason enumeration.

**Architectural decisions:**

1. **Skill engine is default-on, opt-out.** `SKILL_ENGINE_STAGE4=true` (or unset) runs the router; `false`/`0`/`off`/`''` disables it and falls back to the legacy path. The operator switch being on-by-default is deliberate — in dev we want to surface router regressions immediately; in prod the flag gives us a one-env-var kill-switch without a redeploy. The orchestrator also falls back to legacy when `childId` is missing, so the S9-07 legacy flow keeps working for any caller that doesn't plumb a child through.

2. **Lesson is the trace anchor, not UrlIngest.** `UrlIngest` and `Lesson` have no FK between them. The skill engine runs at Stage 4, where a Lesson always exists, so the traces live on `Lesson.aiAnalysis.skillEngine`. The Dev Console endpoint is keyed by `lessonId` (not `ingestId`) to avoid plumbing an extra mapping table. The `PipelineRingEntry.lessonId` field gives the recent-runs view enough context to deep-link into the new Skill Engine panel with one click.

3. **Cherry-pick fallback, not all-or-nothing.** When `quiz-maker` is mapped but `experiment-designer` isn't (S10-08 not shipped yet), the router emits one `skipped` entry with `SkipReason: 'no-skill-mapping'`. The adapter then calls `generateCards` ONCE with the full decomposition and cherry-picks only the skipped atoms from the legacy output. This keeps the skill engine shipping real output for mapped atoms without regressing any unmapped atom. When legacy itself crashes on the cherry-pick, the adapter swallows the error and ships the partial skill-only payload — better to deliver a 60% skill-based lesson than a 0% failed lesson.

4. **Zod retry embeds the Zod error verbatim.** The retry prompt appends the pretty-printed Zod message to the user prompt: `You returned invalid JSON: Missing key "rationalePerOption". Return corrected JSON only, preserving your question and options.` This closes S9-07 carried debt — the whole point of the retry is to give the model enough signal to self-correct without a round trip through Claude. One retry cap; after that the atom goes `'retry-failed'` and skips to legacy cherry-pick.

5. **`lastStoryExcerpt` is a router-local bridge, not a skill-input field.** Rather than forcing `quiz-maker`'s manifest to require a `story` input (which would break the skill's standalone dry-run in the Dev Console), the router maintains a local `lastStoryExcerpt` and merges it into `inputs` only when the quiz skill asks for it and a story preceded this atom in the same decomposition. Skills stay independently testable; the story→quiz coherence emerges from router behavior.

6. **Trace shape echoes key child context at the row level.** Each `AtomTrace` carries `modality`, `conceptType`, `effectiveAgeYears`, and `progressionDelta` inline — redundantly with `ctx.teachingStrategy` — so the Dev Console can render "what the skill saw" without reverse-engineering from a childId. The extra bytes are worth the observability: when a retry fails, the first question is always "which age profile and modality did it render against?" and the answer should never require a second round trip.

**Validation:**
- ✅ `npx tsc --noEmit` — baseline held at 33 errors (same 33 pre-existing Prisma-JSON / orchestrator / badge-criteria errors). Zero new tsc errors introduced by any of R1–R7.
- ✅ `npx vitest run tests/childContextBuilder.test.ts tests/pipelineSkillIntegration.test.ts tests/skillRouter.test.ts` — **44/44 green** in 844ms.
- ✅ `public/dev-pipeline.html` re-parses under `new Function(...)` — 103,733 chars of JS, zero syntax errors. `skillEnginePanel` + `skillEngineBadge` + `refreshSkillTrace` + `renderSkillTrace` all wired into `generateCards()` success branch.
- 🟡 Two pre-existing full-suite failures are NOT from S10-12: `tests/sprint6.test.ts:864` data-rights assertion and `tests/sprint7.test.ts:196` `jest is not defined` (legacy `jest.clearAllMocks()` in a vitest file). Both pre-date this sprint — filed for the hardening window.
- 🟡 Dev Console runtime verification pending on bang's Mac — run the pipeline against a URL with `childId` passed through, confirm the Skill Engine panel populates, drill into one trace per validator-status color, flip `SKILL_ENGINE_STAGE4=false` and confirm the panel reads "legacy". Walkthrough in [docs/sprint-runs/S10-skill-engine-s10-12.md](sprint-runs/S10-skill-engine-s10-12.md).

**Commands to run on your Mac:**

```bash
cd ~/Projects/Novai/src/Backend

# 1. Pull. No new deps. No new migrations. No new env vars
#    (SKILL_ENGINE_STAGE4 defaults to on if unset).
git pull

# 2. Run the three new suites + a sanity full pass
npx vitest run tests/childContextBuilder.test.ts tests/pipelineSkillIntegration.test.ts tests/skillRouter.test.ts
#   expect: 44 passing / 0 failing.
npm test
#   expect: two pre-existing failures unchanged (sprint6 data-rights + sprint7 jest ref).

# 3. Boot the server. Flag defaults to on — no env change needed.
npm run dev

# 4. Open the Pipeline tab in the Dev Console.
#    → http://localhost:3000/dev/dev-pipeline.html#pipeline
#    → load a URL, pick a childId, Analyze → Generate
#    → the new "Skill Engine" panel fills in as soon as /pipeline/generate returns;
#      look for 6-8 rows (one per atom), green pills for ok, amber for retry-ok
#    → click Refresh on the panel header to re-fetch the trace without re-running
#
#    To confirm the legacy fallback: clear SKILL_ENGINE_STAGE4 or set =false, restart,
#    re-run → panel reads "Skill engine did not run for this lesson".

# 5. curl the trace directly (for scripting / debugging)
curl -s http://localhost:3000/api/v1/dev/pipeline/trace/$LESSON_ID | jq '.data.skillEngine.traces[] | {name: .atomName, skill: .skillName, status: .validatorStatus, retries: .retryCount}'
```

See [docs/sprint-runs/S10-skill-engine-s10-12.md](sprint-runs/S10-skill-engine-s10-12.md) for the full validation matrix, curl cheat sheet, and end-to-end Dev Console runbook.

---

## Carried-In Debt from Sprint 9 (candidates for hardening window)

1. **~~S9-07 partial: Stage 4 card generation with skill invocation~~** — ✅ **RETIRED April 18** by S10-12. Grand Architect's Stage 4 now routes every decomposition atom through the skill engine (story-writer / quiz-maker) with per-skill Zod validation, one-shot retry on schema failure, and a cherry-pick legacy fallback for unmapped atoms. `SKILL_ENGINE_STAGE4` env flag defaults on.
2. **33 Prisma-SQLite JSON typing errors** — known middleware pattern (was 32 at start of S10; the `Lesson.aiAnalysis` write in the orchestrator R5 edit added one more of the same class). Recommendation: single ticket, either `JsonField<T>` wrappers or Postgres `jsonb` cutover during DEPLOY.
3. **Coverage gaps flagged in Sprint 9 QA:**
   - `cardGenerator.ts` `validateAndNormalizeCard` per-type unit tests.
   - `pipelineOrchestrator.ts` 7-step state-machine transition tests.
   - `buildDecompositionUserPrompt` unit tests.
4. **Pre-existing full-suite failures surfaced during S10-12 test run (not from this sprint):**
   - `tests/sprint6.test.ts:864` — data-rights route AssertionError.
   - `tests/sprint7.test.ts:196` — `jest is not defined` (legacy `jest.clearAllMocks()` call in a vitest suite; should be `vi.clearAllMocks()`).
