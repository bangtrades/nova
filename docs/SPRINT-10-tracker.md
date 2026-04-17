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
| S10-04 | Parent guidance API | 8 | ⏸ Pending | Topic focus, ±2 difficulty, content boundaries, session limits. Consumed by pipeline at generation time. |
| S10-05 | Session-aware context engine | 8 | ⏸ Pending | Time of day, session duration, recent quiz results, lessons completed, current streak. Injected into every LLM prompt. |

---

## SKILL Epic — Content Generation Skills v1 (68 pts)

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S10-06 | `story-writer` skill with age profiles | 13 | ⏸ Pending | Skill directory + age-profiles.md + topics.md + styles.md. Vocabulary adapts to age 4 / 6 / 8. Pulls from engagement profile (S10-03). |
| S10-07 | `quiz-maker` skill with difficulty curves | 13 | ⏸ Pending | 4–5 options (not 3). Plausible distractors from common misconceptions. Format adapts: visual / textual / audio. |
| S10-08 | `experiment-designer` skill | 8 | ⏸ Pending | Drag-and-drop configs. Complexity adapts to age + motor skill. Hint system. |
| S10-09 | `curriculum-architect` skill | 13 | ⏸ Pending | 4–8 lesson sequence from knowledge graph + parent goals + engagement. Respects prerequisites, fills gaps first. |
| S10-10 | `voice-persona` skill | 8 | ⏸ Pending | Character voice per age: vocabulary, humor style, emotional range. Consumed by Sparky + narration. |
| S10-11 | Teaching strategy matrix | 5 | ⏸ Pending | [vocabulary, abstract, process, comparison, cause-effect, factual] × [visual, auditory, kinesthetic]. Returns ranked card-type recommendations. |
| S10-12 | Integrate skills into Grand Architect pipeline | 8 | ⏸ Pending | Replaces generic prompts in Stage 4. **Closes S9-07.** Each concept routed by teaching strategy. Skills receive child context. |

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
| MEM | 34 | 50 | 68% |
| SKILL | 0 | 68 | 0% |
| **Sprint 10 Total** | **34** | **118** | **29%** |

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

## Carried-In Debt from Sprint 9 (candidates for hardening window)

1. **32 Prisma-SQLite JSON typing errors** — known middleware pattern. Recommendation: single ticket, either `JsonField<T>` wrappers or Postgres `jsonb` cutover during DEPLOY.
2. **Coverage gaps flagged in Sprint 9 QA:**
   - `cardGenerator.ts` `validateAndNormalizeCard` per-type unit tests.
   - `pipelineOrchestrator.ts` 7-step state-machine transition tests.
   - `buildDecompositionUserPrompt` unit tests.
