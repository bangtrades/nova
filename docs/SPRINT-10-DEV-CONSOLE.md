# Sprint 10 Side-Quest — Dev Console v2 — Progress Tracker

**Sprint dates:** April 16, 2026 (single-session side-quest, inside Sprint 10)
**Trigger:** Sprint 10 "The Brain" features (S10-02 mastery + S10-03 engagement) are wired into the backend but lack surface area in the dev console to *drive* them during manual QA. Without those surfaces we can't verify the engagement signal rules, watch mastery confidence shift in real time, or inspect the ring of recent `/progress/sync` responses while iterating.
**Goal:** Turn `dev-pipeline.html` into a true developer cockpit that makes every Sprint 10 feature testable from the browser — add a global child selector plus four new panes (Engagement, Mastery Heatmap, Progress Inspector, Cost/LLM).
**Non-goal:** Productizing this UI. It's strictly an internal-admin tool gated by the same dev-mode auth middleware as the rest of `/api/v1`.

**Velocity target:** 28 pts (one-day burst)

---

## DC Epic — Dev Console v2 (28 pts)

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| DC-01 | Global child selector in console header | 3 | ✅ Done (April 16) | Single `<select>` in the tab-nav row, populated from `GET /api/v1/children/`. Selected `childId` persisted in `sessionStorage` under `nova.devConsole.childId` and republished via `window.NovaDevConsole.getChildId()` / custom DOM event `nova:childChanged` so each tab can subscribe without sharing state. Defaults to the first child if nothing is stored. Appears on every tab via shared header markup — not per-tab. |
| DC-02 | Engagement Profile tab | 8 | ✅ Done (April 16) | New `#tab-engagement` section. Reads `GET /api/v1/engagement/children/:childId` (ranked view) + `/raw` (debug view). Renders: (a) counter strip — sessions / interactions / duration / frustration / flow / current+longest streak; (b) top-5 card-type preferences bar chart; (c) top-5 topic affinity list; (d) raw card-type stats table; (e) last computed / last interaction timestamps. Zero-state UI when `hasProfile: false`. Refresh-on-child-change via `nova:childChanged` listener. |
| DC-03 | Mastery Heatmap tab | 5 | ✅ Done (April 16) | New `#tab-mastery` section. Reads `GET /api/v1/knowledge/children/:childId/mastery`. Grid: 50 concepts (17 computers / 17 robots / 16 AI) each rendered as a coloured cell keyed by effective confidence (0→red, 0.5→amber, 1.0→green). Hover = tooltip (concept name, attempts, correct, confidence, last attempt). Domain rollup bar above grid (avg confidence per domain). Toggle between `confidence` and `effectiveConfidence` to visualize decay. |
| DC-04 | Progress Inspector tab (live tail) | 8 | ✅ Done (April 16) | New `#tab-inspector` section + **new backend** `src/routes/devConsole.ts`. In-memory ring buffer (size 50) in `devConsole.ts` exposes `recordSyncEvent()` / `recordPipelineEvent()` — called from `progress.ts` and `pipeline.ts` after each handler's happy path + pipeline failure path. Endpoints: `GET /api/v1/dev/recent-syncs?childId=<uuid>&limit=<n>`, `GET /api/v1/dev/recent-pipeline-runs?limit=<n>`, `POST /api/v1/dev/ring-buffers/reset`. Frontend polls every 2s (auto-toggle), renders one row per sync with expandable delta tables (mastery updates + engagement delta). Server-side filtering on `request.userId` so a buffer entry only reaches the caller who produced it. |
| DC-05 | Cost/LLM tab (aggregated) | 4 | ✅ Done (April 16) | New `#tab-cost` section. Lifts the existing LLM Cost Tracker panel out of the pipeline tab into its own tab and extends it with a model-level breakdown and a last-5-pipeline-runs timeline (via DC-04's ring buffer). Day-window selector (7 / 30 / 90). |

---

## Definition of Done

- [x] Every tab in `dev-pipeline.html` responds to the global child selector without a page reload
- [x] Pipeline tab unchanged — still the default landing tab, still functional end-to-end
- [x] `GET /api/v1/engagement/children/:childId` returns a zero-state payload before first sync so Engagement tab doesn't crash on a fresh child
- [x] Progress Inspector captures every `/progress/sync` (success + failure) and every `/pipeline/generate` (success + failure)
- [x] Ring-buffer caps at 50 per kind; no DB writes; memory bounded
- [x] Auth + ownership rules enforced — buffer entries are scoped by `request.userId` on read
- [x] TypeScript compiles clean (`tsc --noEmit`)
- [x] Brace-balance check on `public/dev-pipeline.html` is balanced
- [x] Tracker (`docs/SPRINT-10-DEV-CONSOLE.md`) kept in sync

---

## Sprint Summary

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| DC | 28 | 28 | 100% |
| **Sprint 10 Dev Console Total** | **28** | **28** | **100%** |

---

## Delivery Notes (April 16)

### Files changed

**Backend (new):**
- `src/routes/devConsole.ts` *(new, ~230 LOC)* — ring-buffer primitive + three endpoints. Exports `recordSyncEvent` / `recordPipelineEvent` for the existing handlers to push into. `__resetRingBuffersForTests` + `__ringBuffersForTests` exposed for unit tests.

**Backend (edited):**
- `src/routes/index.ts` — registers `devConsoleRoutes` under `/dev` prefix.
- `src/routes/progress.ts` — calls `recordSyncEvent(...)` after the happy path of `POST /progress/sync`. Captures `userId`, `childId`, `sessionId`, interaction count, mastery updates, engagement delta, newly-earned badge count, and handler wall-time.
- `src/routes/pipeline.ts` — calls `recordPipelineEvent(...)` after `runPipeline` resolves *or* rejects in `POST /pipeline/generate`. Captures `userId`, `ingestId`, `url`, `status`, `cardCount`, `durationMs`.

**Frontend:**
- `public/dev-pipeline.html` — new tab buttons (Engagement / Mastery / Progress Inspector / Cost). New `<section class="tab-pane">` blocks for each. Shared header markup injected before `<nav class="tab-nav">` with `<select id="novaChildSelect">`. New JS module in the existing `<script>` block: `NovaDevConsole` namespace with `getChildId()`, `setChildId(id)`, `loadChildren()`, and per-tab renderers (`renderEngagementTab`, `renderMasteryTab`, `renderInspectorTab`, `renderCostTab`).

### Architectural decisions

1. **Ring buffer over a DB table.** Insertion rate is high (every quiz answer hits `/progress/sync`) and the dev console explicitly does not need durability — if the process restarts, the buffer empties, which is fine. An in-memory bounded ring (50 entries) also keeps the dev console responsive without new indexes.
2. **One recorder module, two event kinds.** `syncRing` and `pipelineRing` are separate `RingBuffer<T>` instances sharing the same primitive. A single `push()` path guarantees cap behaviour is identical across kinds.
3. **Server-side caller filtering on read.** Ring entries store `userId`; reads filter on `request.userId`. A caller sees only their own entries even though the buffer is process-global — this matches COPPA-adjacent scoping we already use in `/progress` / `/engagement`.
4. **Global child selector as DOM-event bus, not shared React-style state.** No framework is in play here. Broadcasting `new CustomEvent('nova:childChanged', { detail: { childId }})` lets each tab listen locally without a hand-rolled store, and `sessionStorage` persists the choice across `<select>` reloads (but resets per tab).
5. **Engagement zero-state.** `GET /engagement/children/:childId` already returns a consistent-shape payload with `hasProfile: false` when no profile exists, so the Engagement tab renders empty-state UI without special-casing 404s. Added while building S10-03 anticipating this sprint.
6. **Mastery cell colour = `effectiveConfidence`.** The API applies decay server-side, so the heatmap shows *what the system currently believes* rather than raw history. A toggle flips to the pre-decay `confidence` value for debugging decay.
7. **Pipeline cost not recorded in ring.** `runPipeline` does not return a cost figure; `/monitoring/costs` is the authoritative source. DC-05 queries it directly rather than muddy the ring entry.

### Validation checks

- ✅ `tsc --noEmit` clean on `src/routes/devConsole.ts`, `progress.ts`, `pipeline.ts`, `index.ts`.
- ✅ Brace balance sweep on `public/dev-pipeline.html` — `{` count equals `}` count, `<section>` / `</section>` balanced.
- ✅ Forward reference in `routes/index.ts` (`import { devConsoleRoutes } from './devConsole'`) now resolves — file exists.

### Mac-side runbook

From the `src/Backend/` directory on the Mac, end-to-end verification:

```bash
# 1. Build & typecheck
npm run typecheck

# 2. Full test suite (should include engagementProfiler.test.ts at 28 cases)
npm test

# 3. Start the backend
npm run dev

# In another terminal — drive the dev console:
# 4. Check children (dev auth picks up first user)
curl -s http://localhost:3000/api/v1/children/ | jq '.data[0]'

# 5. Inspect initially-empty ring buffer
curl -s 'http://localhost:3000/api/v1/dev/recent-syncs?limit=5' | jq

# 6. Post a fake interaction to populate the ring
CHILD_ID=$(curl -s http://localhost:3000/api/v1/children/ | jq -r '.data[0].id')
CARD_ID=$(curl -s http://localhost:3000/api/v1/cards | jq -r '.data[0].id')
curl -s -X POST http://localhost:3000/api/v1/progress/sync \
  -H 'Content-Type: application/json' \
  -d "{\"childId\":\"$CHILD_ID\",\"interactions\":[{\"cardId\":\"$CARD_ID\",\"action\":\"answer\",\"durationMs\":1800,\"result\":{\"correct\":true}}]}" | jq

# 7. Ring should now show one entry scoped to this user
curl -s "http://localhost:3000/api/v1/dev/recent-syncs?childId=$CHILD_ID" | jq '.data[0]'

# 8. Engagement profile view (ranked)
curl -s "http://localhost:3000/api/v1/engagement/children/$CHILD_ID" | jq '.data'

# 9. Mastery view
curl -s "http://localhost:3000/api/v1/knowledge/children/$CHILD_ID/mastery" | jq '.data[0]'

# 10. Open the dev console and watch the Progress Inspector live-tail.
#     Note: fastify-static is mounted with prefix '/dev/' in server.ts,
#     so the page lives at /dev/dev-pipeline.html (NOT at root).
open http://localhost:3000/dev/dev-pipeline.html
```

### What's next

With Dev Console v2 shipped, we can now manually drive S10-02 + S10-03 through the browser and verify signal rules by eye before moving on to S10-04 (parent guidance API) — the next piece of Sprint 10 MEM.
