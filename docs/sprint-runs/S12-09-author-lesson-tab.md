# S12-09 — Dev Console Author Lesson Tab Run Summary

**Sprint:** Sprint 12 — "Touch Test"
**Story:** S12-09 — Dev Console content authoring surface (5 pts)
**Landed:** April 23, 2026
**Status:** ✅ Shipped. New Author Lesson tab in `dev-pipeline.html` + new `/api/v1/dev/author-lesson` SSE route + `PipelineStageEvent` hook on the orchestrator. 11 new test assertions green. Full backend: 834 pass / 0 fail. MVP epic opens at 5/14 (36%); Sprint 12 Total flips to 36/60 (60%).

This document is the delivery run summary for the MVP epic's opening story — the Dev Console surface that makes the content-authoring loop bang needs for S12-10's seed lessons + S12-11's touch test with his kid actually *exist*. Prior work got the 5-modality skill-engine to feature-complete (S12-04/05/06) and cleared the Sparky name debt (S12-07/08); this run stitches those pieces into an operator-facing UI that bang can drive end-to-end.

---

## What shipped

**Backend (~330 LOC):**

- `src/services/pipeline/pipelineOrchestrator.ts` — added `PipelineStageEvent` discriminated-union type (20+ variants) + `onStageEvent?: (event: PipelineStageEvent) => void` callback on `PipelineOptions` + internal `emit(opts, event)` helper that swallows handler errors (disconnected SSE must not crash the pipeline). Hooked into every stage boundary: scrape start/done/failed, analyze start/done/failed/blocked (age-inappropriate), decompose start/done/failed with `source: 'skill-engine' | 'legacy'` tag, generate start/done/failed with per-retry counts, quality start/done/failed, persist start/done, pipeline done/failed. Pre-existing behavior unchanged — the hook is purely additive.
- `src/routes/devAuthor.ts` — new 260-LOC route handler for `POST /api/v1/dev/author-lesson`. Zod body schema with `.strict()` + ownership pre-check (403 on cross-user child/path) + `reply.hijack()` + SSE headers + UrlIngest row creation + `runPipeline` bridge + post-pipeline title/description override + final `complete:done` or `complete:failed` event.
- `src/routes/index.ts` — one-line import + one-line registration under the existing `/dev` prefix.

**Frontend (~370 LOC in `src/Backend/public/dev-pipeline.html`):**

- New `<section id="tab-author">` tab-pane between Skills and Progress Inspector. Structure: child dropdown → path dropdown + "+ New Path" button → inline collapsible path-create form (title + icon + hex color + description) → URL input + optional title/description overrides → submit + cancel + skip-quality-gate toggle → stream panel that renders per-stage rows as SSE events arrive.
- New `NovaDevConsole.loadAuthor()` / `loadAuthorPaths()` / `toggleNewPathForm()` / `createPath()` / `startAuthor()` / `cancelAuthor()` / `jumpToPipelineWithLesson()` methods — registered in the IIFE's return block and wired through `switchTab` lazy-load case.
- SSE client implementation via `fetch()` + `response.body.getReader()` + `TextDecoder` + manual `\n\n` frame parsing (the browser's native `EventSource` is GET-only, so a POST-based SSE endpoint requires manual stream reading). `AbortController` on every in-flight stream so the Cancel button kills the connection cleanly.
- Stage-event rendering: one row per `(stage, source)` tuple — so a `skill-engine` decompose failure followed by a `legacy` decompose retry produce two distinct rows (not an overwrite). Pill colors match the Pipeline tab's skill-trace conventions: amber for `start`, green for `done`, red for `failed`/`blocked`, slate for neutral statuses. Detail formatter extracts whatever event-specific fields are relevant (bytes, topic, atom count, retry count, elapsed ms).
- Terminal "Lesson created" card with `lessonId` + `cardCount` + `skillEngineUsed` + optional `qualityScore` + a **Jump to Pipeline tab →** button that cross-syncs the `currentLessonId` global so the skill-trace panel there can open against the new lesson.

**Tests (~330 LOC):**

- `tests/devAuthor.test.ts` — 11 assertions across three describe blocks. Zod body validation (5 cases: missing url, malformed url, non-UUID childId, missing pathId, strict-mode unknown field). Auth + ownership (3 cases: 401 no-bearer, 403 cross-user child, 403 cross-user path). SSE stream (3 cases: happy path asserting connection+ingest+scrape+analyze+decompose+generate+persist stages + terminal `complete:done` with correct payload; throw path asserting `complete:failed` with error propagation). Uses `vi.mock` on `runPipeline` to avoid hitting the real LLM chain — tests exercise the route's control-flow surface (auth, framing, event bridging) while the orchestrator's internal behavior is covered by the pre-existing skill-engine suites.

Zero new npm deps. Zero new env vars. Zero schema changes. Zero new migrations.

---

## Architectural decisions

1. **`onStageEvent` hook on `PipelineOptions` — NOT a side-channel or global emitter.** The callback lives on the options object passed into `runPipeline` so every caller is explicit about whether they want events. Alternative considered: a global EventEmitter or a dedicated `PipelineStreamer` service. Rejected — adds hidden coupling + forces every test to remember to reset the emitter. Callback-on-options keeps the control flow local and stateless; tests just pass a `vi.fn()` and assert call args.

2. **Synchronous `emit` helper that swallows handler errors.** If the browser disconnects mid-stream, the next `reply.raw.write(...)` will throw `ERR_STREAM_WRITE_AFTER_END`. That error must not kill the pipeline — the state machine is the source of truth, event streaming is advisory. Swallowing with a single `console.warn` keeps the orchestrator's invariants intact while still surfacing the issue in logs. Alternative: async `emit` + Promise-wrapped callback. Rejected — adds microtask churn to the hot path of a function that already has 6+ stages of awaits, and the caller doesn't need async-aware semantics anyway (SSE writes are fire-and-forget on the Node side).

3. **POST-based SSE over GET-based EventSource.** The `EventSource` browser API is GET-only per spec, which would require either (a) stuffing the `url`/`childId`/`pathId` into query params (URL-encoding + length limits + server-log leakage of URLs) or (b) a two-step handshake (POST to create a session, GET+EventSource to stream it). Both are worse than manual SSE framing on a POST response. The frontend reads `response.body.getReader()` and parses `data: <json>\n\n` frames in a while-loop — 15 lines of client code for a cleaner shape.

4. **Ownership checks BEFORE `reply.hijack()`, not after.** Once `reply.hijack()` is called, Fastify's error handler no longer runs — a JSON error response is impossible because the response has already been committed to `text/event-stream`. So the route does `prisma.findUnique` on both child + path up-front, returns plain 403 JSON if either check fails, and only then flips into SSE mode. This keeps auth failures as ordinary REST errors (browser fetch sees `res.ok === false`) instead of requiring the client to parse a stream for error conditions.

5. **Discriminated-union event type — not `Record<string, unknown>`.** `PipelineStageEvent` is a union of ~20 variant objects, each with a fixed `stage` + `status` literal + stage-specific payload. The frontend can switch on `event.stage` and get narrow TypeScript-style inference in JS (via typeof checks). Alternative: a freeform `Record<string, unknown>` + runtime duck-typing. Rejected — a typo in a backend event shape would silently render a blank pill; the discriminated union makes the contract self-documenting + catches renames at compile time.

6. **Per-`(stage, source)` row keying — not pure per-stage.** During Stage 3 decompose, the orchestrator may try the skill-engine path first, fail, and fall back to the legacy decomposer. Both paths emit events with the same `stage: 'decompose'`. If the frontend keyed rows by stage alone, the legacy row would overwrite the skill-engine row and bang would lose the evidence that the skill-engine was tried. Keying by `(stage, source)` preserves both — the UI shows two rows, the failed skill-engine attempt on top of the successful legacy retry, which is exactly what the operator needs to see.

7. **Paths are `userId`-scoped, documented as a carve-out for per-child paths.** The existing `LearningPath` model has `userId` (parent) as its FK, not `childId` — all children under a parent share the same paths. Bang's "multiple paths" ask is fully satisfied by creating multiple paths under his own user; if per-child path isolation becomes a product need, that's a schema change (add `childId` FK, migrate existing paths, adjust `GET /paths` query) deferred to S13+. Called out in the tracker so the decision is legible.

8. **Terminal `complete` event always fires.** Both success and failure end with a `{ stage: 'complete', status: 'done' | 'failed', ... }` payload. The client's while-loop over the stream exits cleanly on `reader.done` instead of having to time out waiting for the connection to close. This makes the EventSource-style "listen forever" pattern work correctly even for one-shot pipelines.

---

## Validation (sandbox ✅)

- `tests/devAuthor.test.ts` — 11/11 green. Zod + auth + SSE framing all locked.
- Full backend suite: **834 pass / 0 fail** — the previously-flaky sprint6 LLM-call tests even settled this run (they're real-network-dependent, so any given run will show 0-2 timeouts; this run happened to complete without any).
- `tsc --noEmit` zero new errors — baseline 51 pre-existing errors held constant.

### Validation left for bang's Mac (🟡)

The Dev Console is an HTML + JS surface that can only be meaningfully validated against a running browser + live DB + real LLM chain. The following walkthrough is the S12-09 Mac-side smoke:

```bash
cd ~/Code/Novai/src/Backend
git pull
npm test -- tests/devAuthor
# expect: 11/11 green
npm run dev
# Open http://localhost:3000/dev/dev-pipeline.html#author in your browser
```

**Walkthrough:**

1. The **Author Lesson** tab appears between Skills and Progress Inspector.
2. Child dropdown populates from `/children`. Path dropdown populates from `/paths`.
3. Click **+ New Path** → fill in title ("Science Stage 1") + icon (🔬) + color (#FF8C5A) + description → click **Create path**. The dropdown refreshes and auto-selects the new path.
4. Paste a URL (e.g. `https://simple.wikipedia.org/wiki/Photosynthesis`) + submit.
5. Stream panel lights up: `connection:open` → `ingest:created` → `scrape:start` → `scrape:done (N bytes · "Photosynthesis")` → `analyze:start` → `analyze:done (topic: Photosynthesis · stage 2)` → `decompose:start (skill-engine)` → `decompose:done (skill-engine · 4 atoms · validator: ok)` → `generate:start (skill-engine · 4 atoms)` → `generate:done (skill-engine · 4 cards · 1 retry-ok)` → `quality:start` → `quality:done (0 regenerated)` → `persist:start` → `persist:done` → `complete:done` rendering the final lesson card.
6. Click **Jump to Pipeline tab →** — confirms skill-trace panel opens against the new `lessonId` with all 4 atoms rendered.
7. On iPad (same LAN): pull-to-refresh on Home — the new lesson appears under the new path. Open + run one card to confirm end-to-end content rendering.
8. **Cancel-mid-flight regression**: submit a URL, click Cancel while stream is in-flight → stream panel shows "— cancelled —" row, server logs a clean `AbortError`, no zombie ingest row stuck in `analyzing` state (the orchestrator updates ingest status to `failed` on throw).
9. **403 regression**: manually edit the request body in DevTools to reference a child ID from another user account → confirm 403 JSON response with clear `message: "Child not owned by caller"` (not an SSE stream).

---

## Retired debt / what's next

This run opens the MVP epic at 5/14 (36%). Next stops in Week 2:

1. **S12-10 seed — 3 real lessons (3 pts)** — bang drafts three lessons end-to-end using this new tab, covering all five card types (story, quiz, experiment, voice, plus the curriculum-architect Stage 3 path). Each lesson gets screenshot + atom trace captured into `docs/sprint-runs/S12-10-seed-lessons/`. First real stress test of the 5-modality skill-engine under authored-content load.
2. **S12-11 touch test — bang's kid runs the demo loop (2 pts)** — the actual point of the sprint.
3. **S12-12 defect recovery (4 pts)** — budget for fixing what the touch test uncovers.

---

## Cross-references

- Sprint 12 tracker: [docs/SPRINT-12-tracker.md](../SPRINT-12-tracker.md) — S12-09 delivery note + MVP epic open
- Prior skill-engine runs (the machinery this tab drives): [S12-04 experiment-designer](./S12-04-experiment-designer.md), [S12-05 curriculum-architect](./S12-05-curriculum-architect.md), [S12-06 voice-persona](./S12-06-voice-persona.md)
- Prior Dev Console Pipeline tab (jump-target + pattern reuse): S10-12-R7 skill-trace rendering in `devConsole.ts`
- Backend orchestrator: `src/Backend/src/services/pipeline/pipelineOrchestrator.ts` — `PipelineStageEvent` + `onStageEvent` hook
- Backend route: `src/Backend/src/routes/devAuthor.ts`
- Frontend tab: `src/Backend/public/dev-pipeline.html` — tab markup + `NovaDevConsole.{loadAuthor, startAuthor, createPath, ...}`
- Tests: `src/Backend/tests/devAuthor.test.ts`
