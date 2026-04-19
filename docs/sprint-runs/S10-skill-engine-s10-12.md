# S10-12 — Skill Engine ↔ Grand Architect Integration Run Summary

**Sprint:** Sprint 10 — "The Brain"
**Story:** S10-12 Integrate skills into Grand Architect pipeline (8 pts)
**Retires:** S9-07 (Stage 4 card generation with skill invocation) — carried-in debt
**Landed:** April 18, 2026
**Status:** ✅ Shipped. `childContextBuilder` + `skillRouter` + Zod-retry + `generateCardsWithSkills` + orchestrator wiring + Dev Console pipeline trace + 44 new tests. Awaiting bang's Mac-side runtime walkthrough.

This document is the **delivery run summary and Mac-side runbook** for S10-12. It follows [S10-skill-engine-s10-06.md](./S10-skill-engine-s10-06.md) (engine foundation + `story-writer`) and [S10-skill-engine-s10-07.md](./S10-skill-engine-s10-07.md) (`quiz-maker` + Zod validator). Those runs built the two real skills on an isolated dry-run surface; this run **connects the engine to the live pipeline**, so every lesson Grand Architect generates (when a `childId` is present) now routes its decomposition atoms through `skill.buildPrompt` → LLM → per-skill Zod validator → optional one-shot retry. The tracker entry (`docs/SPRINT-10-tracker.md` → "S10-12 Delivery Notes") is the authoritative per-file changelog; this doc is the **end-to-end operator recipe** — the curl-level and Dev-Console-level walkthroughs bang runs on his Mac to confirm the integration behaves as specified under the full validator-status matrix (`ok` / `retry-ok` / `retry-failed` / `skipped`).

---

## What shipped

Four new services (`childContextBuilder`, `skillRouter`, `skillRoutingTable`, plus the `generateCardsWithSkills` adapter on the existing `cardGenerator`), one orchestrator edit threading `childId` through every stage, two route edits (pipeline response + dev-console endpoint), one HTML panel in the Pipeline tab, and three new test files totaling 44 cases.

- `src/services/pipeline/childContextBuilder.ts` *(new, R1)* — pure `ChildContext` assembler + four testable helpers (`withConceptType`, `summarizeEngagement`, `summarizeMastery`, `summarizeRecentEvents`).
- `src/services/pipeline/skillRouter.ts` *(new, R2+R3)* — per-atom `{buildPrompt → LLM → validate → maybe retry}` loop with a `lastStoryExcerpt` bridge for the story→quiz handoff. Returns `AtomTrace[]` + `skipped[]` for the orchestrator to attach to the Lesson.
- `src/services/pipeline/skillRoutingTable.ts` *(new)* — single source of truth for `{conceptType, recommendedCardType} → skillName`. Maps story → `story-writer`, quiz → `quiz-maker`. Everything else emits `no-skill-mapping` and falls through.
- `src/services/pipeline/cardGenerator.ts` *(edited, R4)* — new `generateCardsWithSkills(decomposition, ctx, options)` wraps the router, cherry-picks skipped atoms into a legacy fallback, and swallows legacy crashes to ship a partial skill payload. Exports `isSkillEngineStage4Enabled()` (default on; disabled by `false`/`0`/`off`/empty, case-insensitive, whitespace-trimmed).
- `src/services/pipeline/pipelineOrchestrator.ts` *(edited, R5)* — accepts `childId` through every stage; builds `ChildContext` once per run; calls `generateCardsWithSkills` when the flag is on AND `childId` is present; persists `skillEngine: {used, traces, skipped}` into `Lesson.aiAnalysis` alongside the decomposition.
- `src/routes/pipeline.ts` *(edited)* — success reply now carries `skillEngineUsed`, `skillSkippedAtoms`, `regeneratedCardIndexes`, `qualityScore`. Ring-buffer recordings carry `lessonId` + `skillEngineUsed` on success; `null`/`false` on failure.
- `src/routes/devConsole.ts` *(edited, R7)* — new `GET /api/v1/dev/pipeline/trace/:lessonId` (UUID-validated, auth-scoped, cross-user-isolated) reads `Lesson.aiAnalysis.skillEngine` and returns the trace + decomposition. `PipelineRingEntry` extended with `lessonId: string | null` + `skillEngineUsed: boolean`.
- `public/dev-pipeline.html` *(edited, R7)* — new "Skill Engine" panel in the Pipeline tab: per-atom rows, color-coded validator-status pills (ok green / retry-ok amber / retry-failed red / skipped grey), retry-count badge, token total, modality/conceptType/effective-age, and a red skip-reason block. `refreshSkillTrace()` + `renderSkillTrace()` functions; auto-triggered from `generateCards()` on every successful run.
- `tests/childContextBuilder.test.ts` *(new, 15 cases)* — pure-helper tests.
- `tests/pipelineSkillIntegration.test.ts` *(new, 15 cases)* — real registry + mocked LLM; happy-path, story→quiz threading, mixed cherry-pick, legacy-fails partial delivery, retry-ok end-to-end, 9 flag-parser cases.
- `tests/skillRouter.test.ts` *(new, 14 cases)* — router-only unit tests.

Zero schema changes. Zero new migrations. No new npm deps. One new opt-out env var (`SKILL_ENGINE_STAGE4`) that defaults on.

---

## Quick-start runbook (bang's Mac)

```bash
cd ~/Projects/Novai/src/Backend

# 1. Pull. No new deps, no new migrations, no new env vars
#    (SKILL_ENGINE_STAGE4 defaults to on if unset).
git pull

# 2. Run the three new suites
npx vitest run tests/childContextBuilder.test.ts tests/pipelineSkillIntegration.test.ts tests/skillRouter.test.ts
#   expect: 44 passing / 0 failing in ~1s.

# 3. Full suite sanity pass
npm test
#   expect: two pre-existing failures unchanged (sprint6:864 data-rights,
#   sprint7:196 `jest is not defined`). These pre-date S10-12.

# 4. Boot the server.
npm run dev
#   expect boot log: "SkillRegistry loaded: quiz-maker v0.1.0, story-writer v0.1.0"

# 5. Open the Pipeline tab in the Dev Console:
#    → http://localhost:3000/dev/dev-pipeline.html#pipeline
```

If boot fails with a SkillRegistry error, the error message will name the offending file (e.g. `defs/quiz-maker/<file>`) — the pipeline orchestrator is deliberately dependent on `await reg.load()` at boot so misconfigured manifests fail fast instead of on the first request.

---

## End-to-end Dev Console walkthrough (Pipeline tab)

The Pipeline tab exercises the full 6-stage pipeline and now surfaces the skill engine in its own panel right above the Activity Log. This is the authoritative smoke test — all 6 stages, one real LLM round trip per atom, plus the trace panel rendering.

**Prerequisites**: a logged-in session (Session tab → auth tokens visible) and a `childId` selected in the Children tab. Without a childId the orchestrator falls through to the legacy path by design — the Skill Engine panel will read `legacy`.

### Step 1 — Kick off a pipeline run

1. Pipeline tab → paste a URL (e.g. `https://en.wikipedia.org/wiki/Helium`).
2. Confirm `childId` is set (badge at top of tab; if not, go pick one in the Children tab).
3. Click **Analyze** → wait for the stage dots to go green through the `scrape → analyze → decompose` stages.
4. Click **Generate** → watch the remaining stages. When it finishes, the Generated Cards panel fills in AND the Skill Engine panel pops from the empty state to a populated trace view.

### Step 2 — Read the Skill Engine panel

The panel header shows:

- **S10-12 tag** (purple badge) — cosmetic, identifies the feature.
- **Live badge** (monospace, right of the tag) — e.g. `used · 7 atoms · 1 retry-ok · 1 skipped · 2840 tok`. This is aggregated from the trace; it should match the stage-4 metrics.
- **Refresh button** — re-fetches `/dev/pipeline/trace/:lessonId` without re-running the pipeline. Useful if you reload the page and want to restore the panel from the last run.

The panel body shows one row per atom. Each row has:

- **Index + atom name + card-type pill** — e.g. `#3 why helium floats [concept]`.
- **Routed skill** — `→ quiz-maker` or `→ story-writer` or `—` (skipped).
- **Validator-status pill** — color-coded:
  - 🟢 `ok` — validator passed on first attempt (or the skill has no validator).
  - 🟡 `retry-ok` — first attempt failed validation, retry with the Zod error embedded in the repair prompt succeeded.
  - 🔴 `retry-failed` — both attempts failed; the atom falls through to legacy cherry-pick.
  - ⚪ `skipped` — router never invoked the skill (no mapping, skill not loaded, or missing required input).
- **Retry-count badge** — `retry×1` when present.
- **Metadata line** — modality / conceptType / effective-age (with progression-delta) / token total.
- **Skip-reason block** (red, when present) — the exact `SkipReason` string. Values: `no-skill-mapping` / `skill-not-loaded` / `skill-runtime-error` / `llm-error` / `json-parse-error` / `validation-failed` / `missing-required-input` / `empty-response`.
- **Error block** (red, when present) — first ~400 chars of the most recent error, verbatim. For `retry-failed`, this is the second (final) Zod error.

### Step 3 — Verify the validator-status matrix

Run the pipeline three or four times with different URLs. You should naturally accumulate trace rows in each of the four status bands. Specifically:

| Status | How to trigger naturally | What you should see |
|---|---|---|
| `ok` | Any normal run on a well-formed article, for decomposition atoms whose skill is mapped. | Vast majority of rows. Green pill. |
| `retry-ok` | Will show up sporadically — the LLM sometimes emits `"all of the above"` or drops `rationalePerOption`. First attempt fails the quiz-maker validator; retry corrects it. | Amber pill + `retry×1` badge. Token count roughly 1.8×–2.2× the `ok` rows (two full prompts). |
| `retry-failed` | Rare under normal operation. If you want to force it: temporarily edit `defs/quiz-maker/prompt.md` to instruct the model to "include `none of the above`" — the banned-phrase check will fail twice in a row. Revert the edit after the test. | Red pill + `retry×1` badge. Error block shows the final Zod path. |
| `skipped` | Pipe in a URL whose decomposition produces a non-quiz / non-story atom (anything `recommendedCardType` isn't in `skillRoutingTable.ts`). | Grey pill. Red skip-reason block shows `no-skill-mapping`. Legacy cherry-pick produces the actual card, which you see in the Generated Cards panel. |

### Step 4 — Verify cross-user isolation

In a second browser (or an incognito window), log in as a different user and hit:

```
GET /api/v1/dev/pipeline/trace/<lessonId-from-your-first-session>
```

Expect **403 Forbidden**. The endpoint enforces `lesson.userId === request.userId` — this is a hard guard so traces never leak across accounts.

### Step 5 — Verify the feature flag kill-switch

```bash
# Stop the dev server, then restart with the flag disabled.
SKILL_ENGINE_STAGE4=false npm run dev
```

Re-run the pipeline. The Skill Engine panel should read **"Skill engine did not run for this lesson (legacy path or flag off)"**. The lesson's cards should still generate via the legacy path — same schema, same quality-gate. This is the operator's one-env-var kill-switch.

Re-enable:

```bash
unset SKILL_ENGINE_STAGE4   # defaults to on
npm run dev
```

---

## Validation matrix

All cells are covered by automated tests. This matrix is the one-screen summary; the authoritative assertions live in `tests/pipelineSkillIntegration.test.ts`.

**Controls:** real `SkillRegistry` booted from `defs/` via `__resetSkillRegistryForTests(resolveDefsDir())`; `providerRouter` stubbed with a queued response array (`mockResponses.push(...)`); every atom carries a valid `ChildContext` assembled via `buildChildContext` against in-memory fixtures.

| # | Scenario | Decomposition | LLM mock queue | Expected `skillEngineUsed` | Expected traces | Expected skipped |
|---|---|---|---|---|---|---|
| 1 | Happy path (2 skills, no skip) | `[story, quiz]` | `[VALID_STORY_PROSE, VALID_QUIZ_JSON]` | `true` | 2 rows, both `ok` | `[]` |
| 2 | Story→Quiz `lastStoryExcerpt` threading | `[story, quiz]` | same as #1 | `true` | Quiz trace's `promptMeta.inputsUsed.story` contains the story's first 200 chars | `[]` |
| 3 | Mixed cherry-pick (unmapped atom) | `[story, quiz, concept]` (concept has no mapping) | `[VALID_STORY_PROSE, VALID_QUIZ_JSON, ...legacy3CardArray]` | `true` | 3 rows: `ok`, `ok`, `skipped:no-skill-mapping` | `[{atomId: concept.id, reason: 'no-skill-mapping'}]` |
| 4 | Every atom has a trace (sanity) | `[story, quiz, concept]` | same as #3 | `true` | `traces.length === atoms.length` | one entry |
| 5 | Legacy fallback fails — partial delivery | `[story, quiz, concept]` | `[VALID_STORY_PROSE, VALID_QUIZ_JSON, <throws>]` | `true` | 3 rows (skill + skill + skipped) | one entry; legacy failure swallowed with `console.warn`, skill-only payload shipped |
| 6 | Retry-ok surfaced end-to-end | `[quiz]` | `[{"question":"x","options":["a"]}, VALID_QUIZ_JSON]` (first is invalid per Zod) | `true` | 1 row, `validatorStatus: 'retry-ok'`, `retryCount: 1` | `[]` |
| 7 | Flag disabled (`SKILL_ENGINE_STAGE4=false`) | any | (not called) | `isSkillEngineStage4Enabled() === false`; orchestrator routes to legacy | adapter returns `null` for traces | — |
| 8 | `childId` missing | any | (not called) | legacy path regardless of flag | `null` | — |

The feature-flag parser cases (9 total) lock these inputs: unset → on, `'true'` → on, `'TRUE'` → on, `'1'` → on, `'false'` → off, `'False'` → off, `'0'` → off, `'off'` → off, `'  '` (whitespace) → off.

---

## curl cheat sheet

Grab an auth token from the Dev Console's **Session** tab (or any prior request's `Authorization` header) and export:

```bash
TOKEN="<paste Bearer token>"
BASE="http://localhost:3000/api/v1"
CHILD_ID="<pick from /children>"
```

### Kick off a pipeline run

```bash
# 1. Ingest a URL for the child.
INGEST=$(curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/pipeline/ingest" \
  -d "{\"url\":\"https://en.wikipedia.org/wiki/Helium\",\"childId\":\"$CHILD_ID\"}" | jq -r '.id')

# 2. Generate cards (this is where the skill engine fires).
RUN=$(curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/pipeline/generate" \
  -d "{\"ingestId\":\"$INGEST\",\"childId\":\"$CHILD_ID\"}")

LESSON_ID=$(echo "$RUN" | jq -r '.lessonId')

echo "$RUN" | jq '{
  lessonId,
  cardCount,
  skillEngineUsed,
  skillSkippedAtoms,
  regeneratedCardIndexes,
  qualityScore
}'
# expect: skillEngineUsed:true, skillSkippedAtoms:[<any unmapped atoms>],
#         qualityScore > 0.5, regeneratedCardIndexes:[] (or the indexes the gate regenerated).
```

### Fetch the per-atom trace

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE/dev/pipeline/trace/$LESSON_ID" | jq '.data.skillEngine.traces[] | {
    name: .atomName,
    skill: .skillName,
    card: .cardType,
    status: .validatorStatus,
    retries: .retryCount,
    tokens: .tokens.total,
    modality: .modality,
    concept: .conceptType
  }'
# expect: one row per decomposition atom; statuses in {ok, retry-ok, retry-failed, skipped}.
```

### Count validator-status bands across recent runs

```bash
# Snapshot the recent-runs buffer (ring buffer, last 50 runs).
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/recent-pipeline-runs?limit=50" \
  | jq '.data[] | select(.skillEngineUsed and .lessonId) | .lessonId' \
  | xargs -I{} curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/pipeline/trace/{}" \
  | jq -r '.data.skillEngine.traces[].validatorStatus' \
  | sort | uniq -c | sort -rn
# expect dominant: ok, then retry-ok, with occasional skipped and rare retry-failed.
```

### Cross-user isolation — 403

```bash
# Log in as a second user, grab that user's token, then:
curl -s -H "Authorization: Bearer $OTHER_USERS_TOKEN" \
  "$BASE/dev/pipeline/trace/$LESSON_ID" -w '\n%{http_code}\n'
# expect: 403 { "statusCode": 403, "error": "Forbidden", ... }
```

### Missing / malformed lessonId

```bash
# 401 when no auth header.
curl -s "$BASE/dev/pipeline/trace/$LESSON_ID" -w '\n%{http_code}\n'
# expect: 401

# 400 when lessonId isn't a UUID.
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/pipeline/trace/not-a-uuid" -w '\n%{http_code}\n'
# expect: 400 (Zod preHandler rejection)

# 404 when lessonId is a valid UUID but no row exists.
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE/dev/pipeline/trace/00000000-0000-4000-8000-000000000000" -w '\n%{http_code}\n'
# expect: 404
```

### Pre-S10-12 lesson (skillEngine: null, still 200)

Pick any Lesson row from before April 18 and hit the trace endpoint — the response is still 200 but `data.skillEngine` is `null` and the UI renders the "did not run for this lesson" empty state. This is deliberate: deleting pre-existing lessons just to clean up the trace view would be destructive, so the API is forward-compatible.

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/pipeline/trace/$OLD_LESSON_ID" \
  | jq '{status: .data.status, engine: .data.skillEngine, hasDecomp: (.data.decomposition != null)}'
# expect: status:"ready", engine:null, hasDecomp may be true or false depending on when the lesson was created.
```

---

## Feature-flag matrix

The `SKILL_ENGINE_STAGE4` env var is the operator's one-env-var kill-switch. Parsing is done in `isSkillEngineStage4Enabled()` in `cardGenerator.ts`:

| Env value | Parsed | Orchestrator path |
|---|---|---|
| _(unset)_ | `true` | skill engine |
| `"true"` / `"TRUE"` / `"True"` | `true` | skill engine |
| `"1"` | `true` | skill engine |
| `"on"` / `"ON"` | `true` | skill engine |
| `"false"` / `"False"` / `"FALSE"` | `false` | legacy |
| `"0"` | `false` | legacy |
| `"off"` / `"OFF"` | `false` | legacy |
| `""` (empty) | `false` | legacy |
| `"  "` (whitespace only) | `false` | legacy |
| Any other non-empty string | `true` | skill engine (default-on fallback) |

The 9 parser cases are locked in `tests/pipelineSkillIntegration.test.ts → isSkillEngineStage4Enabled — feature flag`. Each test saves/restores `process.env.SKILL_ENGINE_STAGE4` around the assertion so the flag state doesn't leak between cases.

---

## S9-07 debt retired

The Sprint-9 close-out left S9-07 ("Stage 4: Card generation with skill invocation") as a partial carry-in — the only one flagged as in-plan at Sprint 9 close. The note in `sprint-9-report.md:54` was:

> Partial. Cards generate end-to-end with atom-aware prompts. Full skill invocation waits on S10-06 → S10-12 — **this is the plan, not drift**.

S10-12 closes this. As of April 18, 2026:

- ✅ Every decomposition atom with a mapped skill (story, quiz) is generated via `skill.buildPrompt` + the skill's validator, not via a hardcoded prompt in `promptTemplates.ts`.
- ✅ Atoms without a mapping (anything in the not-yet-shipped `experiment-designer` / `curriculum-architect` / `voice-persona` territory) emit `SkipReason: 'no-skill-mapping'` and fall through to legacy cherry-pick, so the lesson still ships.
- ✅ Zod retry closes the validator loop: one repair attempt with the pretty-printed Zod error inlined, surfaced as `validatorStatus: 'retry-ok'` on success.
- ✅ The feature flag provides a clean operator kill-switch back to the legacy path if we need to disable skills mid-incident.
- ✅ Per-atom traces persist on `Lesson.aiAnalysis.skillEngine` so the Dev Console can render a trace table for any lesson on demand.

The "Carried-In Debt" section in the tracker has been updated to strike S9-07 and promote the 33 Prisma-JSON errors to the top slot.

---

## What's next

S10-12 was the last story on the critical path between the skill engine and the live pipeline. With it shipped, the remaining Sprint-10 scope is all additive content:

- **S10-08 `experiment-designer`** (8 pts) — drag-and-drop card configs. Complexity adapts to age + motor-skill profile. Will add a third row to the routing table and a third entry to `SKILL_OUTPUT_SCHEMAS`.
- **S10-09 `curriculum-architect`** (13 pts) — 4-to-8-lesson sequence from knowledge graph + parent goals + engagement. Respects prerequisites, fills gaps first. Will plug into a new pre-decomposition stage rather than the per-atom loop.
- **S10-10 `voice-persona`** (8 pts) — character voice per age: vocabulary, humor style, emotional range. Consumed by Sparky + narration. Lives on the same engine with a different inputs shape.

With S10-12 done the sprint sits at **89/118 pts (75%)** with the three remaining stories all on the same proven engine — no new infrastructure work required.

---

## Cross-references

- [docs/SPRINT-10-tracker.md](../SPRINT-10-tracker.md) — per-file changelog under "S10-12 Delivery Notes (April 18)".
- [docs/sprint-runs/S10-skill-engine-s10-06.md](./S10-skill-engine-s10-06.md) — engine foundation + `story-writer`.
- [docs/sprint-runs/S10-skill-engine-s10-07.md](./S10-skill-engine-s10-07.md) — `quiz-maker` + per-skill Zod validator.
- [docs/design-spikes/S10-06-07-skill-loader.md](../design-spikes/S10-06-07-skill-loader.md) — original design spike.
- [docs/sprint-9-report.md](../sprint-9-report.md) — S9-07 carry-in note (now retired).
