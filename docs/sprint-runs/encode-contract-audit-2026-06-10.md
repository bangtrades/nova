# Encode-side contract audit — every iOS request body vs its backend schema

> Slice run summary, 2026-06-10. Single slice (the debt discovered
> during the auth contract fix), executed directly by the session lead.

---

## Meta

- **Slice:** carry-debt row "Encode-side contract audit (`.convertToSnakeCase` vs camelCase zod)".
- **Agent:** session lead (Fable 5), direct execution.
- **Run window:** 2026-06-10.
- **Status:** ✅ delivered, gated, committed.

---

## 1. Audit method + headline

Every `Endpoint` with a request body was cross-referenced against its
backend route's zod schema, weighted by live call sites. Headline: the
**two live kid-path seams were both completely broken**, and one of
them was broken at the transport level too.

| Seam | Breaks found |
|---|---|
| **`/dashy/chat`** (live — Dashy desk) | ① The view model was constructed with a **placeholder APIRouter pointed at `https://api.nova.local` and never swapped** — every chat request went to a dead host. ② Request body `{message, history, childAge}` vs schema `{childId, transcript, conversationHistory, providerId?}` — zero overlapping keys. ③ History roles sent `"dashy"`; schema enum is `user\|assistant`. ④ Response decoded a nonexistent `message` key (backend sends `response`). |
| **`/progress/sync`** (wired, no app caller yet) | Required top-level `childId` missing entirely; nested `CardInteraction` keys snake-cased (`duration_ms` vs `durationMs`). Every future sync would have 400'd. |
| `/pipeline/generate/cards` (Companion) | `ingest_id` key never validates; `stage` isn't in the schema (it takes `pathId?`/`childId?`). |
| `/pipeline/assets/:id` (Companion/dead) | Redundant `lesson_id` body the backend never reads; `generateAssets` also pointed at a nonexistent `/pipeline/generate/assets` path. |
| Model-bodied endpoints (createLesson etc.) | Multi-word fields snake-cased vs camelCase schemas — fixed wholesale by the encoder change. |

## 2. The systemic fix

**`APIClient.encoder.keyEncodingStrategy` → `.useDefaultKeys`.** The
backend's zod schemas are uniformly camelCase; the snake converter was
the root cause of the whole class. Swift property/CodingKey names now
hit the wire verbatim. The auth routes keep their tolerant-reader
preprocess (accepting both spellings) as a belt-and-suspenders.

## 3. Files changed

| File | What |
|---|---|
| `NovaCore/API/APIClient.swift` | Encoder strategy + do-not-restore comment. |
| `NovaCore/API/Endpoint.swift` | `syncProgress(childId:deviceId:_:)`, `dashyChat(childId:transcript:conversationHistory:providerId:)`, `generateCardsFromIngest(ingestId:pathId:childId:)`, `generateAssets`/`generateLessonAssets` → path-only POSTs (empty bodies tolerated since VOX-03). |
| `NovaCore/API/APIRouter.swift`, `NovaCore/Sync/SyncManager.swift`, `NovaStorage/OfflineSyncQueue.swift` | `childId` threaded through the sync chain (compile-enforced; no app callers existed yet). |
| `NovaKids/ViewModels/DashyViewModel.swift` | New `attach(apiRouter:voiceManager:childId:)` late-binding (kills the dead-host placeholder), role mapping `dashy→assistant`, childId guard with kid-safe error, response decodes the real `response` key. |
| `NovaKids/Views/Dashy/DashyView.swift` | `onAppear` attaches the real environment router + voice manager + active child id. |
| `NovaCompanion/ViewModels/URLIntakeViewModel.swift` | Call site updated for the new `generateCardsFromIngest` signature (Companion target still pre-existing-broken; change is source-correct, not compile-verified). |
| `NovaCore/Tests/.../ModelTests.swift` | Stale `signIn(appleToken:)` test call updated; now also pins the `/auth/apple` path. |
| `Backend tests/encodeContract.test.ts` | 3 wire tests with real JWTs (the test env has no dev-auth fallback — unauthenticated injects 401 before validation, which would make the assertions vacuous): sync body clears validation; dashy body clears validation; the OLD dashy body still 400s (canary against schema-loosening). |

## 4. Validation

- Backend: `tsc --noEmit` **0**; **vitest 848/848**.
- iOS: NovaCore package **26 tests green**; NovaKids `xcodebuild` **BUILD SUCCEEDED**.
- Live-fire check of Dashy chat / progress sync against the running
  backend needs the app on a simulator/device with a child profile —
  folds into the V2-S4-F4 device pass.

## 5. Reviewer / next-agent notes

- **Do not reintroduce `.convertToSnakeCase`** on the encode side; the
  comment in APIClient says why.
- `syncProgress` now *requires* a childId — when the progress-sync
  feature gets its first real app caller, the compiler will demand the
  right data instead of letting a 400 ship.
- Dashy without a child profile shows a kid-safe "ask a grown-up"
  error instead of sending a doomed request.
