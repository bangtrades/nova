# S11-19 — Live data wire-up across Tier 1 + Dashy (MVP testing loop)

**Run ID:** S11/R19
**Parent sprint:** [SPRINT-11](../SPRINT-11-tracker.md) — "Comic-Book Polish"
**Stories landed:** S11-19 (MVP, 8 pts)
**Run window:** 2026-04-22 (single session)
**Landed:** 2026-04-22
**Status:** ✅ Delivered
**Delivery agents:** /senior-fullstack + /senior-swift + /swiftui-pro + /jira-expert
**Sprint progress after this run:** 84 / 93 pts (90%) — MVP epic **100%**

---

## Run Goal

Flip the five core ViewModels from hard-coded mock arrays to real `APIRouter` calls so an iPad on bang's LAN can consume dev-console-generated content end-to-end. This is the first backend-touching story of Sprint 11 — every prior story was UX polish painted on top of mocks. The fence broke when bang said: *"I want the ipad app wired up so that my kid can try it out. There is so much back end and planning going on — nobody has touched the app yet. We need the MVP usable. I want to create content, push to the ipad, and let a kid touch it."*

The MVP testing loop is:

1. bang opens `http://localhost:3000/dev/` on his Mac → generates a lesson via pipeline → lesson hits Postgres.
2. iPad on same Wi-Fi → `NovaKidsApp` launches with `NOVA_BACKEND_HOST=192.168.x.y:3000` in its scheme → `APIRouter` hits the Mac.
3. Kid taps a lesson tile → `FlipbookView.task` fetches the cards for that lesson → kid swipes through real cards.
4. Kid talks to Dashy → `DashyView` → `apiRouter.request(.sparkyChat(...))` → real LLM reply streams back.
5. Kid earns a badge → trophy tab shows earned-badge state from the real ledger.

Every node in that loop is wired in this run. No more mock arrays on the consumed surfaces; every VM has a real-data fast path with a preview/test fallback intact.

---

## Stories & Acceptance Criteria

| ID | Story | AC → Outcome |
|----|-------|----------|
| S11-19 | Live data wire-up across Tier 1 + Dashy | ✅ All 5 AC landed — (1) `HomeViewModel` + `LessonsViewModel` + `FlipbookViewModel` + `TrophyRoomViewModel` + `DashyViewModel` each call `APIRouter` on the real path with mock fallback; (2) every VM carries `@Published var loadError: APIError?` and every consumer View renders a `.novaSecondary()` "Try Again" banner above cached content; (3) `GET /lessons` querystring bug fixed (`request.params` → `request.query`); (4) `NovaKidsApp.init()` reads backend base URL from `NOVA_BACKEND_HOST` env var with localhost fallback; (5) wire-protocol literal `role == "sparky"` preserved as S11-09 asymmetric-rename carve-out. |

Deviation from plan: the original S11-19 scope named only Tier 1 (Home / Lessons / Trophy) + Dashy. Flipbook's card fetch got pulled in too because it's the surface the kid actually spends most time on — shipping live Lessons but mock Flipbook would mean the tile you tap still shows the same five pre-baked mock cards every time, which is a worse demo than a clearly-stubbed tile. Cost: +30 LOC of wire-up in `FlipbookViewModel` + `FlipbookView`, same design. Documented in Decision 5 below.

---

## Files Changed

### Sources

| File | Δ LOC | Change |
|------|------:|--------|
| `src/Apps/NovaKids/Sources/App/NovaKidsApp.swift` | +48 / -0 | `APIHost.baseURL()` helper introduced; replaces three hardcoded `http://localhost:3000/api/v1` URL literals with `let backendBaseURL = APIHost.baseURL()` resolved once at launch. Reads `ProcessInfo.processInfo.environment["NOVA_BACKEND_HOST"]` with localhost fallback. |
| `src/Apps/NovaKids/Sources/ViewModels/HomeViewModel.swift` | +54 / -42 | `attach(apiRouter:childId:)` post-init injection; `refresh()` swaps mock sleep for a 3-fan parallel fetch (`fetchPaths` + `fetchLessons` + optional `fetchProgress`); `cachedProgress` private state backs a de-duplicated `progressPercentage` computation; `loadError: APIError?` published. |
| `src/Apps/NovaKids/Sources/ViewModels/LessonsViewModel.swift` | +44 / -18 | `attach(apiRouter:)` idempotent; `refresh()` does `async let` pair-fetch of paths + lessons so filter row + grid appear together; `loadError` published. |
| `src/Apps/NovaKids/Sources/ViewModels/FlipbookViewModel.swift` | +46 / -32 | `attach(apiRouter:)` + `loadCardsIfNeeded()` + `retryLoad()`. Lazy fetch because the list endpoint returns summaries; cards are per-lesson. Preview-safe: nil router falls to `generateMockCards()`. |
| `src/Apps/NovaKids/Sources/ViewModels/TrophyRoomViewModel.swift` | +52 / -29 | `attach(apiRouter:childId:)` + `loadBadges()` real path: parallel fetch of catalog + earned records, O(N+M) zip via `Dictionary(uniqueKeysWithValues:)`; nil childId degrades to catalog-only; `loadError` published. |
| `src/Apps/NovaKids/Sources/ViewModels/DashyViewModel.swift` | +60 / -32 | `fetchDashyResponse()` swaps the simulated response for `apiRouter.request(.sparkyChat(message:history:))`; `DashyResponse` struct lifted to type scope to avoid async-generic binding drag; history payload shaped as `[[String: String]]` to stay `Encodable`; suggestions capped at `maxSuggestions` (4). |
| `src/Apps/NovaKids/Sources/Views/Home/HomeView.swift` | +28 / -2 | `@EnvironmentObject apiRouter + appState`; errorBanner branch above content; `.task` attaches router + `appState.currentChild?.id` and awaits `refresh()`. |
| `src/Apps/NovaKids/Sources/Views/Home/EnhancedHomeView.swift` | +26 / -2 | Parallel wire-up to `HomeView`; error banner placed between header and content so it doesn't yank the skeleton away. |
| `src/Apps/NovaKids/Sources/Views/Lessons/LessonsView.swift` | +24 / -2 | Attach via `.task`; errorBanner above masonry; `.refreshable` triggers `refresh()` on the real path. |
| `src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` | +41 / -2 | Attach via `.task`; skeleton + errorBanner gated on `cards.isEmpty` so a mid-session fetch failure doesn't yank the already-rendered deck. |
| `src/Apps/NovaKids/Sources/Views/Trophies/TrophyRoomView.swift` | +30 / -4 | Attach via `.task`; errorBanner above stat row + achievements grid. |

### Backend

| File | Δ LOC | Change |
|------|------:|--------|
| `src/Backend/src/routes/lessons.ts` | +6 / -2 | Line 62: `request.params as unknown as ListLessonsQuery` → `request.query as unknown as ListLessonsQuery`. GET /lessons was reading pagination + filter off `.params` (URL path segments), not `.query` (querystring). Fastify schema validation was silently undefining the values — every list call defaulted to page 1, no filter. Correct-in-principle even though the bug had not yet manifested because nothing was sending `?pathId=…` from the iOS app until now. |

### Docs

| File | Change |
|------|--------|
| `docs/SPRINT-11-tracker.md` | S11-19 row flipped 🚧 In Progress → ✅ Done with dense Notes column. Sprint Summary MVP row `0 / 8 (0%)` → `8 / 8 (100%)`, Total `76 / 93 (82%)` → `84 / 93 (90%)`. Delivery Notes section appended with 10 numbered architectural decisions + Validation matrix + Mac-side LAN runbook + curl cheat sheet. |
| `docs/sprint-runs/S11-19-live-data-wireup.md` | This file. |
| `docs/sprint-runs/index.md` | New top row: `S11-19` → `S11/R19`, landed 2026-04-22, one-line summary. |

**Zero new Swift files. Zero pbxproj changes.** Every new symbol lives inside an existing compilation unit.

---

## Architectural Decisions

### 1. `attach(apiRouter:)` over constructor injection — preserve zero-arg `init()` for previews

Every consumer View already constructs its VM as `@StateObject private var viewModel = LessonsViewModel()` (and `HomeViewModel()`, `FlipbookViewModel(lesson: lesson, voiceManager: …)`, etc). Changing any constructor to require an `APIRouter` would cascade through:

- Every `#Preview { … }` block — ~12 sites across the Views folder — each of which would need a mock router scaffolded.
- Every test that instantiates a VM directly.
- Every child view that passes a transiently-constructed VM down the tree (we have a few).
- The `StateObject(wrappedValue:)` idiom, which is the compiler's way of telling you it holds the object for the lifetime of the parent view — plumbing a runtime router through it is awkward because the router itself comes from `@EnvironmentObject` and you can't read environment values in `@StateObject`'s initialization expression.

The `attach(apiRouter:)` idiom sidesteps all of that. The VM constructor stays zero-arg (or keeps its preview-friendly arg list). The View grabs the router from `@EnvironmentObject` inside `.task`, calls `viewModel.attach(apiRouter: apiRouter)`, then awaits the first fetch. Because `.task` runs when the view first appears, the router is guaranteed to be attached before any refresh call fires. Because `attach` is idempotent (guard on `self.apiRouter == nil` — or for the `childId`-capable ones, always-re-point to allow child switches in S12), re-entry from a tab re-selection is a no-op.

This is the same pattern the iOS team at a certain Cupertino-adjacent company uses for `CKContainer` injection in SwiftUI-over-CloudKit apps: the object is constructed early, the dependency arrives later via a method call inside `.task`. Chose this over Dependency-Injection-container frameworks (Resolver, Factory, Needle) because Nova Kids has zero third-party DI dependencies and isn't adding one for a 5-VM wire-up. Chose it over `@Environment` injection of the router into the VM directly (`@Environment(\.apiRouter)` custom key) because `@Environment` is per-view, not per-object — a VM that needs the router from multiple views would need the key read at each call site, and the `attach` pattern keeps the router-reference discipline in one file per VM.

### 2. `@Published var loadError: APIError?` over `throws` — Views read one typed field

The alternative was a throwing refresh: `func refresh() async throws`, with each View wrapping the call in `do/catch` and stashing the error in `@State`. Rejected because:

- Every View then owns duplicated error-state plumbing (`@State private var loadError: APIError?`, a `catch` block, the banner rendering code) — five times, across three people's future maintenance instincts, which means five slightly-different shapes over time.
- The VM is the right place to hold the error state: it's the same object that holds the success state (`allLessons`, `badges`, etc), and clearing the error on a successful subsequent fetch is a VM-internal detail, not a View-internal one.
- `APIError` is `LocalizedError` + `Equatable`, so the View reads `error.errorDescription ?? "Something went wrong"` once, without casting or branching on error type. The semantic message comes from the domain ("Dashy is offline" vs "No network"), which is exactly what a kid-facing banner needs.

So each VM gains one field: `@Published var loadError: APIError?`. The View's rendering branch is identical across the five consumers: `if let error = viewModel.loadError { errorBanner(message: error.errorDescription ?? …) }`. The `retryLoad()` method on each VM is the corresponding "Try Again" handler — clears the error, re-invokes the fetch. One concept, five identical touchpoints.

### 3. Mock fallback when `apiRouter == nil` — keeps `#Preview` green

The obvious-but-wrong design says: "the VM is now a real-data VM, delete the mock path." That design breaks every `#Preview { FlipbookView(lesson: …) }` + every unit test that instantiates a VM directly, because they have no router to attach.

The right design keeps the mock path as the nil-router branch:

```swift
guard let apiRouter else {
    // Preview / unit-test path — the 400ms sleep is the skeleton's
    // visible-work beat when there's no network latency.
    try? await Task.sleep(nanoseconds: 400_000_000)
    loadMockData()
    return
}
// … real fetch path …
```

Zero friction for the preview case. The `loadMockData()` function stays in place (still called from the zero-arg init, still called from the nil-router branch of `refresh()`), and deleting it later is a mechanical S12+ chore rather than a sprint-blocker right now. The 400ms sleep is kept in the preview branch because without it the skeleton would pop in and out faster than the eye can parse, and the whole point of the skeleton is to tell the kid "something is coming back".

### 4. `APIHost.baseURL()` + `NOVA_BACKEND_HOST` env var over Info.plist or build settings

Three places in `NovaKidsApp.init()` had the literal `"http://localhost:3000/api/v1"` burned into the APIClient constructor. That's fine for simulator runs (where `localhost` on the simulator resolves to the Mac's loopback). It's fatal for the iPad build over LAN: `localhost` on the iPad resolves to **the iPad itself**, not bang's Mac.

Three options for parameterizing the host:

1. **`Info.plist` value** — bakes into the bundle at build time; changing requires a rebuild; values are per-target, so the release build needs the prod URL at build time anyway.
2. **Xcode build setting** — same as Info.plist for our purposes; flag gets propagated via `GCC_PREPROCESSOR_DEFINITIONS` and still requires a rebuild.
3. **Scheme environment variable** — read via `ProcessInfo.processInfo.environment["NOVA_BACKEND_HOST"]` at launch; changing the value in the scheme's "Arguments → Environment Variables" panel only requires a **relaunch**, not a rebuild.

For bang's demo loop — iPad on home Wi-Fi, then iPad on coffee-shop Wi-Fi, then iPad on phone hotspot, then iPad back home — option 3 is the only one that doesn't require tearing down the dev loop every time the Mac's IP changes. Set `NOVA_BACKEND_HOST=192.168.1.42:3000` in the demo-iPad scheme, relaunch, done.

Resolution order is two-deep: env var first, localhost fallback second. The helper prepends `http://` and appends `/api/v1` so the scheme value stays short + copy-pastable (bang types `192.168.1.42:3000`, not the full URL). Helper lives in `NovaKidsApp.swift` rather than a `Networking` module because it's the app's composition-root concern and exactly one file needs it.

### 5. `loadCardsIfNeeded()` lazy fetch on Flipbook — list endpoint only returns summaries

Tier 1 `LessonsViewModel.refresh()` calls `apiRouter.fetchLessons(pathId: nil)`, which hits `GET /lessons`. That endpoint returns **lesson summaries** (id, title, description, thumbnailUrl, difficulty, status, sortOrder, createdAt, publishedAt) — it does **not** embed the card array, because:

- A path with 50 lessons × 10 cards each × voice scripts + explanations per card = a ~200KB payload for a screen that's rendering thumbnails. The list is a grid. Nobody needs the card text to render a grid tile.
- The cards are per-lesson detail. Pulling them lazily when the kid actually taps a tile is the semantic-correct shape.

So `Lesson.cards` arrives `nil` or `[]` from the list endpoint, and the Flipbook has to fetch them itself via `GET /lessons/:id/cards` (`apiRouter.fetchCards(lessonId:)`).

The `loadCardsIfNeeded()` method on `FlipbookViewModel` handles that:

```swift
public func loadCardsIfNeeded() async {
    guard cards.isEmpty else { return }

    guard let apiRouter else {
        self.cards = generateMockCards()
        if autoNarrate { try? await speakCurrentCard() }
        return
    }

    isLoading = true
    defer { isLoading = false }

    do {
        let fetched = try await apiRouter.fetchCards(lessonId: lesson.id)
        self.cards = fetched.sorted { $0.sortOrder < $1.sortOrder }
        self.loadError = nil
        if autoNarrate && !cards.isEmpty { try? await speakCurrentCard() }
    } catch let error as APIError {
        self.loadError = error
    } catch {
        self.loadError = .custom(error.localizedDescription)
    }
}
```

The `cards.isEmpty` guard at the top means: if the caller already passed a fully-populated lesson (legacy paths, tests, a future "lesson with preview cards" endpoint), we don't re-fetch. The `nil` router branch means previews keep their mock 5-card deck without changes. Naming is `loadCardsIfNeeded()` rather than `loadCards()` because the "if-needed" is the load-bearing semantics — re-entering the Flipbook after a back-navigation should not re-hit the network.

`retryLoad()` is the "Try Again" handler: clear the error, re-invoke `loadCardsIfNeeded()`. It's the same idiom used for the other four VMs' retry surfaces.

### 6. Parallel fetches via `async let` — filter row + grid arrive together

In `LessonsViewModel.refresh()`:

```swift
async let pathsFetch = apiRouter.fetchPaths()
async let lessonsFetch = apiRouter.fetchLessons(pathId: nil)
let (paths, lessons) = try await (pathsFetch, lessonsFetch)
```

The two calls are independent GETs against the same backend host. Sequential `await` would serialize them (paths arrives → then lessons), which means:

- Filter row renders empty for ~200ms while lessons are in flight.
- Grid renders empty for ~200ms before that.
- Kid sees two staggered in-pops instead of one unified content reveal.

`async let` is the idiomatic Swift 6 way to launch both at once and `await` them together. Same pattern in `HomeViewModel.refresh()` (3-fan: paths + lessons + optional progress) and `TrophyRoomViewModel.loadBadges()` (catalog + earned records). Chose `async let` over `TaskGroup` because the number of concurrent fetches is known at compile time — TaskGroup's dynamic-add ergonomics are overkill here and its error-propagation is more awkward than `try await (a, b)` tuple destructuring.

The optional third fetch in Home (`fetchProgress(childId:)`) runs **after** the paths/lessons tuple returns, not inside the `async let` tuple, because the `if let childId` guard needs to be a statement not an expression. Cost: one extra round-trip serial-to-the-other-two. Benefit: clean guard + skip-silently semantic when childId is nil (auth hasn't selected a kid yet).

### 7. `errorBanner` surfaces fetch failure without hiding cached content

The banner renders **above** the main content, not instead of it:

```swift
if let error = viewModel.loadError {
    errorBanner(message: error.errorDescription ?? "Something went wrong")
        .padding(.horizontal, Spacing.lg)
}

if viewModel.isLoading && viewModel.cards.isEmpty {
    LoadingSkeletonView(itemCount: 3, isGrid: false)
}

// always-rendered content below
```

If the kid has successfully loaded Lessons once and a subsequent `.refreshable` pull fails, the grid is still there with the previous content. The banner appears above it. The kid can hit "Try Again" to retry the fetch, or just keep browsing the cached grid. Contrast with a "replace content with error state" design, which would make every fetch failure feel like a catastrophic disconnect even when the kid has perfectly usable cached data.

The `isLoading && cards.isEmpty` double-gate on the skeleton is the same principle applied to the loading state: render the skeleton only when there's nothing else to show. A mid-session refresh keeps the cached content visible while the fetch runs; a cold-start load shows the skeleton because there's no cache to fall back on.

Chrome matches the Home/Lessons/Trophy language across the app — `NovaPalette.page` fill + 14pt rounded rect + 2pt ink stroke + coral `exclamationmark.triangle.fill` glyph + `NovaPalette.captionFont()` body + `.novaSecondary()` "Try Again". One visual language for "the network just hiccuped" across the five surfaces.

### 8. Preserved `role == "sparky"` wire literal per S11-09 asymmetric-rename carve-out

The backend under `src/Backend/src/services/sparky/` still emits `role: "sparky"` on the wire and still exposes its endpoint at `/api/v1/sparky/chat`. The S11-09 rename flipped **user-visible strings** (the character is named Dashy everywhere a kid can see the name) but explicitly deferred **wire-protocol literals + filesystem paths + exported identifiers** to S12.

S11-19 is the first run that has to construct a request body against that wire protocol. The history payload for `sparkyChat(message:history:)` maps each `ChatMessage` to `["role": message.role, "content": message.content]`. The `message.role` value is still the string `"sparky"` for Dashy-authored messages because that's what the backend expects; swapping it to `"dashy"` unilaterally would cause the server-side prompt-assembly code to classify every Dashy message as user-authored, poisoning the conversation history.

So the literal stays. The doc comment on the `ChatMessage.role` field flags it explicitly:

```swift
/// > Wire-protocol note (S11-09): `role` carries the server-side literal
/// > — currently still `"sparky"` for Dashy-authored messages because
/// > the backend under `services/sparky/` hasn't been renamed yet.
/// > S12 will flip both ends simultaneously.
public let role: String  // "user" or "sparky" (wire protocol — S12 renames to "dashy")
```

S12 will do a coordinated flip: rename the filesystem path `services/sparky/` → `services/dashy/`, rename the identifiers (`SPARKY_SYSTEM_PROMPT` etc), flip the wire-protocol literal, migrate the iOS side in the same PR. Until then the carve-out is load-bearing — trying to preserve a single source of truth for "dashy" on the iOS side while the backend still says "sparky" would require a translation layer that the S12 coordinated flip makes unnecessary.

### 9. `GET /lessons` bugfix — `request.params` → `request.query`

Pre-S11-19 the list handler read pagination + filter off `request.params`:

```ts
const { pathId, status, page, limit } = request.params as unknown as ListLessonsQuery;
```

`request.params` in Fastify carries **URL path segments** — the `:id` in `/lessons/:id`. `request.query` carries the **querystring** — `?pathId=…&page=2`. The list endpoint has no path parameters (just `/lessons`), so `request.params` was always an empty object; the destructuring got four `undefined`s.

Zod-via-`validateQuery` had already validated the querystring into `request.query` with defaults applied (page=1, limit=20). The `undefined`s from `request.params` got swallowed silently: `where: { userId, ...(undefined && { pathId }), ...(undefined && { status }) }` reduces to `{ userId }`, and `skip: (undefined - 1) * undefined` is `NaN`, which Prisma coerces back to `skip: 0, take: undefined` — i.e. "no skip, no take limit".

So the bug was: every list call defaulted to **page 1, no filter, unbounded take**. For the mock-data MVP that was indistinguishable from correct behavior (only 6 lessons in seed, no pagination pressure). The moment the iOS app started sending `?pathId=<uuid>` from the filter pills it would have returned every lesson instead of the path's subset.

Fix is one word:

```ts
const { pathId, status, page, limit } = request.query as unknown as ListLessonsQuery;
```

Ship-critical because the MVP loop has bang's kid tapping filter pills. Caught during wire-up, not during the unit tests that preceded it — the unit test was round-tripping through the full Fastify request lifecycle including `validateQuery`, so the validated query was sitting on `request.query` where the tests *also* weren't reading it. A pure integration test never caught it because no integration test was sending `?pathId=` yet.

Moved the old `// Query params already validated` comment to a longer explanation of the same principle. Correct-in-principle and demonstrably correct-in-practice now.

### 10. `DashyResponse` lifted to type scope — async-generic binding drag

First draft of `fetchDashyResponse()` had the response struct nested inside the method:

```swift
private func fetchDashyResponse(userMessage: String) async {
    struct DashyResponse: Decodable {
        let message: String
        let emotion: String?
        let suggestions: [String]?
    }
    // …use DashyResponse here
}
```

Swift 6 strict concurrency treats every async function body as its own isolation context. Nested `Decodable` types inside an async function body drag a generic-binding context with them every time the decoder is invoked — it's technically legal but measurably slower than a type-scope struct, and the compiler error messages when it goes wrong are genuinely cryptic ("cannot convert value of type 'DashyResponse' to expected argument type 'DashyResponse'" — same name, different generic contexts).

Lifting the struct to type scope:

```swift
@MainActor
public class DashyViewModel: NSObject, ObservableObject {
    // …
    private struct DashyResponse: Decodable {
        let message: String
        let emotion: String?
        let suggestions: [String]?
    }
    // …
    private func fetchDashyResponse(userMessage: String) async {
        // …use DashyResponse here
    }
}
```

The struct is still `private` to the class so no public surface change. The decoder binds against the same type across every invocation. The Swift 6 type-checker doesn't have to re-derive the generic context per call.

---

## Validation

### Sandbox ✅

| Check | Command | Result |
|-------|---------|--------|
| S11-19 comment markers present | `grep -rn "S11-19" src/Apps/NovaKids/Sources/` | 18 hits across 11 files — every wire-up site carries the sprint-marker for future grepability. ✅ |
| `attach` method landed on all 5 VMs | `grep -n "public func attach" src/Apps/NovaKids/Sources/ViewModels/` | 5 hits (Home, Lessons, Flipbook, Trophy, Dashy already had one). ✅ |
| `loadError: APIError?` published on all fetch VMs | `grep -n "@Published var loadError" src/Apps/NovaKids/Sources/ViewModels/` | 4 hits (Home, Lessons, Flipbook, Trophy). Dashy uses `errorMessage: String?` with a state-machine case. ✅ |
| errorBanner helper wired in consumer Views | `grep -n "private func errorBanner" src/Apps/NovaKids/Sources/Views/` | 5 hits (HomeView, EnhancedHomeView, LessonsView, FlipbookView, TrophyRoomView). ✅ |
| Hardcoded backend URLs gone | `grep -n "http://localhost:3000/api/v1" src/Apps/NovaKids/Sources/` | 1 hit — only inside `APIHost.baseURL()` fallback. ✅ |
| `APIHost` helper present | `grep -n "enum APIHost" src/Apps/NovaKids/Sources/App/NovaKidsApp.swift` | 1 hit. ✅ |
| `NOVA_BACKEND_HOST` env var read | `grep -n "NOVA_BACKEND_HOST" src/Apps/NovaKids/Sources/App/NovaKidsApp.swift` | 1 hit. ✅ |
| Wire literal `"sparky"` preserved | `grep -rn "role == \"sparky\"" src/Apps/NovaKids/Sources/` | 1 hit in `DashyView.swift` (S11-13 carve-out). 2 hits in VMs (`role: "sparky"` in message construction). ✅ |
| Backend bugfix landed | `grep -n "request.query as unknown as ListLessonsQuery" src/Backend/src/routes/lessons.ts` | 1 hit. ✅ |
| Endpoint static factory present | `grep -n "static func sparkyChat" src/Packages/NovaCore/Sources/NovaCore/API/Endpoint.swift` | 1 hit. ✅ |
| `async let` parallel-fetch pattern | `grep -n "async let" src/Apps/NovaKids/Sources/ViewModels/` | 6 hits across Home (2), Lessons (2), Trophy (2). ✅ |
| Mock fallback branches intact | `grep -n "guard let apiRouter" src/Apps/NovaKids/Sources/ViewModels/` | 4 hits — every real-path VM still guards. ✅ |
| No `@MainActor` + `Task { @MainActor in }` hop inside the VMs | inline — all VMs are `@MainActor`-isolated classes so published writes are already on the main actor. No redundant hops. ✅ |
| swift-senior checklist pass (no force-unwraps, no `try?` inside `do/catch`, no `foregroundColor`, no single-param `onChange`) | inline | Clean. ✅ |
| swiftui-pro checklist pass (zero-arg `init` preserved, `attach` is idempotent, `.task` awaits fetch, `@EnvironmentObject` reads are at View level not VM level, no deprecated API) | inline | Clean. ✅ |

### 🟡 Mac-only (requires bang's hardware)

| Check | Why sandbox can't |
|-------|-------------------|
| Xcode clean build of `NovaKids` target | Swift compiler not present in sandbox; pbxproj untouched so it's a pure recompile. |
| Backend boot — `npm run dev` in `src/Backend` | Requires a running Postgres + Node environment the sandbox doesn't host. |
| `curl http://localhost:3000/api/v1/lessons` sanity check on the bugfix | Backend not running in sandbox. |
| iPad Pro 13" simulator walk — cold-start attach sequence | Simulator requires Xcode. |
| `NOVA_BACKEND_HOST=…` scheme env var test | Requires Xcode scheme editor. |
| LAN ping between iPad and Mac | Requires actual hardware on bang's Wi-Fi. |
| Dev Console content-push → iPad consume round-trip | Needs the full stack running locally on bang's Mac. |
| Dashy chat real-LLM round-trip | Requires Anthropic API key + running backend. |
| Error-banner retry behavior under real network flakiness | Requires intermittent network — hard to reproduce in a sandbox. |

---

## Prerequisites bang must run on his Mac

Three setups required: backend up, scheme env var set, iPad on LAN.

### 1. Backend up on Mac

```bash
cd ~/path/to/Nova/src/Backend
npm install   # first time only
npm run migrate   # first time only (applies latest Prisma migrations)
npm run dev   # starts Fastify on :3000 with watch-mode reload

# Verify:
curl -sS http://localhost:3000/api/v1/lessons | jq '.'
# expect: { "data": [...], "total": N, "page": 1, "limit": 20, "totalPages": ... }
# (or 401 Unauthorized — the list endpoint requires Authorization header; see curl cheat sheet below for auth'd variant.)
```

If the Postgres isn't already seeded with content, create a lesson via the dev console first (step 4 below).

### 2. Find the Mac's LAN IP

```bash
# On macOS:
ipconfig getifaddr en0   # Wi-Fi
# or
ipconfig getifaddr en1   # ethernet / second adapter

# expect: something like "192.168.1.42"
```

If the Mac is on a captive coffee-shop Wi-Fi, the LAN IP may not be reachable from the iPad. Fallback: hotspot the iPhone, join both Mac and iPad to the iPhone's hotspot, re-run `ipconfig getifaddr en0` for the new IP.

### 3. Set the iPad scheme env var

In Xcode:

- Open `src/Nova.xcodeproj`.
- Scheme → `NovaKids` → Edit Scheme… → Run → Arguments → Environment Variables.
- Add: **Name** = `NOVA_BACKEND_HOST`, **Value** = `192.168.1.42:3000` (substitute your Mac's LAN IP).
- Close the scheme editor.
- Destination: iPad Pro 13" (physical device, not simulator — simulator already reaches `localhost` fine and doesn't need the env var).
- Cmd-R to launch.

### 4. Dev Console content-push loop

```bash
# With the backend running locally, open:
open http://localhost:3000/dev/dev-pipeline.html

# Pipeline tab:
# - Select a path (or "Create new path")
# - Enter a topic, age, difficulty
# - Click "Generate lesson"
# - Verify the pipeline trace shows skillEngineUsed: true, Stage 4 atoms OK/retry-ok/retry-failed/skipped pills
# - Lesson is persisted to Postgres and appears in GET /lessons

# Then on the iPad (once NOVA_BACKEND_HOST is set + app launched):
# - Lessons tab → pull to refresh → new lesson appears in the grid
# - Tap the new lesson → Flipbook fetches cards → deck renders
# - Swipe through cards → story → concept → experiment → quiz
# - Dashy tab → tap "Talk to Dashy" → speak a question → verify real LLM reply streams back
# - Any failed fetch should surface the error banner with "Try Again"
```

### 5. Rollback path if something's wrong

```bash
# Back out the wire-up without losing the design-system work:
git diff --stat src/Apps/NovaKids/Sources/ViewModels/
# expect: 5 files modified (Home, Lessons, Flipbook, Trophy, Dashy VMs)

# If the attach() indirection is the culprit, revert the VM:
git checkout HEAD -- src/Apps/NovaKids/Sources/ViewModels/HomeViewModel.swift
# (repeat per VM as needed)

# The mock path is still in loadMockData() so reverting any single VM returns
# it to a pre-S11-19 state without affecting the other four.
```

---

## curl cheat sheet — end-to-end content-push loop

The lessons endpoints require authentication. The dev console path (`/dev/*`) does not (for local-only use). These are the curls that correspond to what the iPad is doing when it fetches.

```bash
# 1. Confirm dev console is reachable
curl -sS http://localhost:3000/dev/ping | jq '.'
# expect: {"ok": true, "message": "dev console alive"}

# 2. List lessons (unauthenticated; this is what the dev console hits)
curl -sS 'http://localhost:3000/dev/lessons?limit=5' | jq '.data | map({id, title, status})'
# expect: array of 5 lesson summaries

# 3. List lessons filtered by path (tests the bugfix from Decision 9)
PATH_ID="<paste a learningPath id here>"
curl -sS "http://localhost:3000/dev/lessons?pathId=${PATH_ID}&limit=20" | jq '.data | length'
# expect: N where N is the count of lessons in that path
# before the S11-19 bugfix this would have returned every lesson

# 4. Fetch a specific lesson's cards
LESSON_ID="<paste a lesson id here>"
curl -sS "http://localhost:3000/dev/lessons/${LESSON_ID}/cards" | jq '.data | map({id, type, sortOrder})'
# expect: array of cards sorted ascending by sortOrder

# 5. Send a chat message to Dashy (wire literal "sparky" on the path)
curl -sS -X POST 'http://localhost:3000/dev/sparky/chat' \
     -H 'Content-Type: application/json' \
     -d '{
       "message": "What is a robot?",
       "history": []
     }' | jq '{message, emotion, suggestions}'
# expect: { "message": "...", "emotion": "curious"|"happy"|..., "suggestions": [...] }

# 6. Authenticated variant — what the iPad hits once signed in
TOKEN="<paste a dev JWT here, or use devBypassLogin to grab one>"
curl -sS 'http://localhost:3000/api/v1/lessons?limit=5' \
     -H "Authorization: Bearer ${TOKEN}" | jq '.data | length'
# expect: N (same as step 2 but going through real auth)
```

---

## Sprint Impact

| Metric | Before S11-19 | After S11-19 |
|-------:|:--------------|:-------------|
| Sprint 11 Total | 76 / 93 (82%) | **84 / 93 (90%)** |
| DS epic | 15 / 15 (100%) | 15 / 15 (100%) |
| T1 epic | 25 / 25 (100%) | 25 / 25 (100%) |
| DSH epic | 10 / 10 (100%) | 10 / 10 (100%) |
| T2 epic | 18 / 18 (100%) | 18 / 18 (100%) |
| **MVP epic** | 0 / 8 (0%) | **8 / 8 (100%)** |
| MX epic | 8 / 10 (80%) | 8 / 10 (80%) |
| QA epic | 0 / 7 (0%) | 0 / 7 (0%) |

**MVP epic closes at 8/8.** The demo loop ("create content in dev console → push to iPad → let a kid touch it") is runnable end-to-end. Sprint 11's remaining work is the **MX + QA carry-out** — S11-16 reduce-motion audit (2 pts) + S11-17 auth/onboarding spacing (4 pts) + S11-18 iPad landscape/dark-mode/DynamicType QA (3 pts).

---

## What's Next

1. **S11-17** (QA, 4 pts) — Auth login tighten + Onboarding spacing. Now unblocked because the MVP loop is working; bang can rehearse the full first-run flow (age gate → onboarding → auth → Home → tap a real lesson) and file defects as they surface.
2. **S11-16** (MX, 2 pts) — Reduce-motion audit sweep of S11-05…13. Comment-pass audit; every `withAnimation(…)` site gets a one-line doc comment confirming its reduce-motion behavior.
3. **S11-18** (QA, 3 pts) — iPad landscape + dark mode + DynamicType QA. Now *more* valuable because real content can stress edge cases (long lesson titles wrapping, missing thumbnails, empty descriptions, kids with very long names) that mock data was hiding.

S12 carve-outs surfaced or re-confirmed in this run:
- `services/sparky/` → `services/dashy/` coordinated filesystem + wire-protocol rename.
- `currentStreak` + `totalLessonsCompleted` per-child aggregation endpoints (TrophyVM currently returns mock streak + `earned.count` for total).
- Per-criterion badge progress endpoints (right now unearned badges render 0% progress instead of the visual fill the mock gave).
- Progress-driven lesson recommendation (right now `featuredLesson = lessons.first`; S12 ships a real ranker).
- Child-switch support (the `attach(apiRouter:childId:)` signature is deliberately re-pointable so a child picker in S12 can flip the VM without reconstructing it).

---

## Retired Debt

- **`GET /lessons` silent querystring bug** (Decision 9) — `request.params` → `request.query`. Not yet observed in production (nothing was sending `?pathId=` before this run) but correct-in-principle and future-proofed for the moment filter pills actually fire the query.
- **Hardcoded `localhost:3000` URLs in `NovaKidsApp.init()`** (Decision 4) — three literal URL strings replaced with a single `APIHost.baseURL()` call. Was listed on the Sprint 11 tracker's Risks & Mitigations section ("Risk: Demo iPad LAN connection to Mac backend is flaky on demo day") with a mitigation of "fallback to a mock-data path toggle". That mitigation is now unnecessary — the LAN config is a scheme env var away.
- **Mock arrays burned into five VMs** — not fully retired (still present as the nil-router fallback for previews) but now isolated to the preview/test path, no longer on the consumed real path.
- **Simulated Dashy response** (`DashyViewModel`) — S10-era simulation code deleted; every Dashy reply now originates from the real `sparkyChat` endpoint + `voiceManager.speak(...)` pipeline.

---

## Cross-references

- [S11-13 — Dashy chat surface rebuild](./S11-13-dashy-chat.md) — the surface S11-19 wires up; the `role == "sparky"` carve-out call-out originates there.
- [S11-09 — Sparky → Dashy iOS rename](./S11-ds-dashy-rename.md) — establishes the asymmetric-rename carve-out preserved in Decision 8.
- [S11-11 + S11-14 — Flipbook chrome + loading skeletons](./S11-flipbook-skeletons.md) — establishes the `LoadingSkeletonView` + `.refreshable` pattern S11-19 consumes in the wire-up Views.
- [S11-07 — Trophy refinement](./S11-trophy-refinement.md) — establishes the `BadgeDisplayItem` shape that `TrophyRoomViewModel.loadBadges()` now zips from the live catalog + earned records.
- [S10-12 — Skill engine + pipeline + dev console pipeline trace](./S10-skill-engine-s10-12.md) — the content-generation side of the demo loop that S11-19 consumes. Dev-console-generated lessons are the payload crossing the wire.
- Sprint 11 tracker [MVP epic](../SPRINT-11-tracker.md#mvp-epic--live-data-wire-up-8-pts) — the scope add that introduced this story mid-sprint after the user-visible surfaces landed on top of mocks.
