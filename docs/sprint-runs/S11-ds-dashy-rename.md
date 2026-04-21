# Sprint Run — S11-03 + S11-04 + S11-09 (DS primitives + Bangers font + Dashy rename)

**Run ID:** `S11/R03-04-09`
**Parent sprint:** Sprint 11 ("Comic-Book Polish" — 85 pts total)
**Run window:** April 20, 2026 (single-session delivery; same day as S11/R01-02)
**Delivery agents:** `/senior-swift` (iOS code) + `/senior-fullstack` (integration + backend touch) + `/jira-expert` (sprint tracking)
**Tracking request:** `/jira-expert` ("add a sprint for this run so that we have a tracked summary of the added features")
**Status:** ✅ **DELIVERED** — DS epic now 100% complete; Dashy identity in place for the S11-10 visual reskin; Tier 1 screen rebuilds (S11-05/06/07) are now unblocked and can start consuming `NovaCard` + `NovaPrimaryButtonStyle` + `NovaSecondaryButtonStyle` + `NovaPalette.displayFont(size:)`.

---

## 1. Run Goal

Close out the design-system epic (DS: `S11-03` NovaCard + button styles, `S11-04` Bangers display font plumbing) and land the Dashy mascot rename (DSH: `S11-09`) so the rest of Sprint 11 has a coherent vocabulary for visible polish. Three stories — `S11-03` at 5 pts because it introduces two load-bearing primitives, `S11-04` at 3 pts because it's a plumbing pass with a cached fallback, `S11-09` at 5 pts because it's asymmetric (iOS flips fully, backend voice flips, wire-protocol + filepath stays) — 13 pts total in one session.

Ship all three so the sprint tracker moves from "foundations in" (S11/R01-02) to "foundations + character voice in", which is the state Day 2 expected us to be in. Tier 1 rebuilds (S11-05 Home, S11-06 Quiz, S11-07 Trophy) can now pull from the DS primitives on Day 2 without blocking on more DS work.

**Standing constraints (carried from Sprint 11 plan and the S11-01/02 run):**
- UX-only sprint — no backend changes *except* the Dashy rename to the LLM system prompt (explicitly in scope for S11-09).
- Keep 280+ existing `NovaPalette.novaBlue` / `.novaOrange` / etc. call sites working.
- Wire-protocol stability: iOS's stored `role: "sparky"` literal and the `/api/v1/sparky/chat` route cannot move mid-deploy.
- Dark-mode adaptivity must not regress.
- No new runtime dependencies — iOS 17+ SwiftUI only.

---

## 2. Stories & Acceptance Criteria

### S11-03 — `NovaCard` + Button styles (5 pts) ✅

**User story:** *As a Nova engineer, I have a canonical card container and two button styles (primary coral, secondary page-outline) so every Tier 1 rebuild picks up the comic-book-paper visual vocabulary without reinventing it per-screen.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | New `DesignSystem/NovaCard.swift` introducing `public struct NovaCard<Content: View>: View` with `accent: Color = NovaPalette.coral`. | ✅ |
| AC2 | 20pt rounded rect, `NovaPalette.page` fill, 2pt `NovaPalette.ink` stroke. | ✅ |
| AC3 | Paper-texture shadow: `radius: 8, x: 0, y: 4, color: NovaPalette.ink.opacity(0.08)`. | ✅ |
| AC4 | 6pt leading accent stripe that picks up the `accent` prop — coral by default, `Category.*` on category-tagged surfaces. | ✅ |
| AC5 | New `DesignSystem/NovaButtonStyles.swift` introducing `NovaPrimaryButtonStyle` (coral fill, ink text, medium haptic) and `NovaSecondaryButtonStyle` (page fill, ink stroke, coral text, light haptic). | ✅ |
| AC6 | Both styles animate `scaleEffect(configuration.isPressed ? 0.96 : 1.0)` with `.animation(.easeInOut(duration: 0.1))`. | ✅ |
| AC7 | Haptic fires on press-in (not press-up) for a kids-app "committed to this tap" feel. | ✅ |
| AC8 | Padding + corner radius identical across both styles (16/24/14) so primary and secondary can sit side-by-side without visual jitter. | ✅ |
| AC9 | Both types ship as `public` so callers outside the current module can consume them. | ✅ |
| AC10 | Previews verified in light + dark; the ink/page inverse-pair from S11-02 carries through automatically. | ✅ |

### S11-04 — Bangers display font plumbing (3 pts) ✅

**User story:** *As a Nova user, card titles and action words look bold + playful even when the Bangers font file hasn't been installed yet, so the app never ships a silent visual regression.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | `NovaPalette.displayFont(size: CGFloat) -> Font` helper added. | ✅ |
| AC2 | First call probes `UIFont(name: "Bangers-Regular", size: 1) != nil`; result cached in a `private static let` for the process lifetime. | ✅ |
| AC3 | Fallback when font is not registered: `.system(size: size, weight: .heavy, design: .rounded)`. Fallback never crashes. | ✅ |
| AC4 | `Resources/Fonts/README.md` includes drop-in instructions: filename, `UIAppFonts` Info.plist key, verification snippet, OFL-1.1 license pointer. | ✅ |
| AC5 | Size passed explicitly per call site (not baked in) — allows Dynamic Type considerations to live at the callsite. | ✅ |
| AC6 | No crash, no visual regression, no Info.plist changes required by this story to land — bang installs the font file in his own runbook step. | ✅ |

### S11-09 — Sparky → Dashy rename (5 pts) ✅

**User story:** *As a Nova user, the mascot is named "Dashy" everywhere I see or hear the character's name — in onboarding, the tab bar, hint sheets, offline banners, the voice interface, and the LLM's self-introduction — so the character has identity headroom versus the saturated "Sparky" name used by every AI product demo.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | 5 iOS Swift files renamed: `SparkyView` → `DashyView`, `SparkyViewModel` → `DashyViewModel`, `SparkyCharacterView` → `DashyCharacterView`, `SparkyHintSheet` → `DashyHintSheet`, `SparkyHintButton` → `DashyHintButton`. | ✅ |
| AC2 | Type names inside renamed files updated to match filenames. | ✅ |
| AC3 | Tab bar label in `NovaKidsApp.swift` switched to "Dashy" with `DashyView()` root. | ✅ |
| AC4 | `FlipbookViewModel.showSparkyHint` → `showDashyHint` with hint copy rewritten. | ✅ |
| AC5 | Home + Lessons featured card titles flipped from "Ask Sparky Anything" → "Ask Dashy Anything". | ✅ |
| AC6 | Onboarding page method + copy flipped: `meetSparkyPage()` → `meetDashyPage()`, "Meet Sparky!" → "Meet Dashy!", greeting + teaching copy updated. | ✅ |
| AC7 | Offline surfaces flipped: `OfflineBannerView` copy and `OfflineGracefulView.SparkyOfflineView` type + copy. | ✅ |
| AC8 | Voice interface doc-comments in `VoiceCardView.swift` reference Dashy. | ✅ |
| AC9 | Backend LLM `SPARKY_SYSTEM_PROMPT` body flipped from "You are Sparky…" → "You are Dashy…" so the voice the child hears says the new name. | ✅ |
| AC10 | Load-bearing docblock added to `conversationEngine.ts` explaining the asymmetric rename: filepath + exported TS identifiers + wire-protocol route slug are intentionally retained so the iOS client's stored `role: "sparky"` literal keeps routing cleanly while backend + iOS flip together in S12. | ✅ |
| AC11 | `grep -rn "Sparky\|sparky" src/Apps/NovaKids/Sources/Views/` returns zero user-visible hits; the only remaining "sparky" tokens are the wire-protocol literals with inline `// S12 carve-out` comments. | ✅ |
| AC12 | `grep -rn "Sparky" src/Apps/NovaKids/Sources/ViewModels/` returns zero user-visible hits; wire-protocol stored-role literals only. | ✅ |

---

## 3. Files Changed

**Design-system additions (S11-03, 2 new files):**
- `src/Apps/NovaKids/Sources/Views/DesignSystem/NovaCard.swift` — new file.
- `src/Apps/NovaKids/Sources/Views/DesignSystem/NovaButtonStyles.swift` — new file with both `NovaPrimaryButtonStyle` and `NovaSecondaryButtonStyle`.

**Display font additions (S11-04, 1 file edited + 1 new doc file):**
- `src/Apps/NovaKids/Sources/Views/Common/NovaPalette.swift` — added `displayFont(size:)` helper + cached `isBangersRegistered` probe.
- `src/Apps/NovaKids/Sources/Resources/Fonts/README.md` — new file. Drop-in instructions for bang.

**iOS Sparky → Dashy renames (S11-09, 5 file renames):**
- `Views/Dashy/SparkyView.swift` → `DashyView.swift`
- `ViewModels/SparkyViewModel.swift` → `DashyViewModel.swift`
- `Views/Dashy/SparkyCharacterView.swift` → `DashyCharacterView.swift`
- `Views/Flipbook/SparkyHintSheet.swift` → `DashyHintSheet.swift`
- `Views/Flipbook/SparkyHintButton.swift` → `DashyHintButton.swift`

**iOS Sparky → Dashy in-place edits (S11-09, 9 files):**
- `src/Apps/NovaKids/Sources/App/NovaKidsApp.swift` — tab root + label.
- `src/Apps/NovaKids/Sources/ViewModels/FlipbookViewModel.swift` — `showSparkyHint` → `showDashyHint`, hint copy.
- `src/Apps/NovaKids/Sources/ViewModels/HomeViewModel.swift` — featured card title.
- `src/Apps/NovaKids/Sources/ViewModels/LessonsViewModel.swift` — featured card title.
- `src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` — hint button + sheet wiring.
- `src/Apps/NovaKids/Sources/Views/Flipbook/VoiceCardView.swift` — doc-comments + `Arc` helper attribution.
- `src/Apps/NovaKids/Sources/Views/Common/OfflineBannerView.swift` — offline banner copy.
- `src/Apps/NovaKids/Sources/Views/Common/OfflineGracefulView.swift` — `SparkyOfflineView` → `DashyOfflineView`, titles + copy + preview.
- `src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift` — `meetSparkyPage()` → `meetDashyPage()` + greeting + teaching copy + inner doc-comments.

**Backend Sparky → Dashy (S11-09, 1 file edited):**
- `src/Backend/src/services/sparky/conversationEngine.ts` — header docblock with asymmetric-rename explanation; `SPARKY_SYSTEM_PROMPT` body flipped from "You are Sparky" → "You are Dashy".

**Tracker update:**
- `docs/SPRINT-11-tracker.md` — three epic rows flipped to ✅ Done with notes; Sprint Summary table updated (DS 7→15/15 = 100%, DSH 0→5/10 = 50%, Total 7→20/85 = 24%); three new Delivery Notes sections appended.

**Totals:** 4 new files, 11 in-place Swift edits, 5 file renames, 1 backend TypeScript edit, 1 tracker update.

---

## 4. Architectural Decisions

### 4.1 `DesignSystem/` subfolder as first-class home for DS primitives

The first-class vocabulary of Sprint 11 — card container, button styles, Dashy identity primitives in S11-10, the haptics helper in S11-15 — deserves a stable home separate from feature folders. Keeping `Common/` for truly-pan-project helpers (palette, spacing, offline banner, loading skeleton) and carving out `DesignSystem/` for intentional design-system primitives makes the split obvious when future contributors open `Views/`. The alternative (scatter DS primitives across `Common/` alongside incidental helpers) would blur the category boundary and make it harder to find the primitives during a design review.

### 4.2 `NovaCard` is a container, not a modifier

Considered `.novaCard()` as a view modifier — would have been one fewer type to think about. Rejected because a container expresses the *composition* intent more clearly: "this content sits inside a paper-textured card with a coral spine" not "this view has some decorations applied". The stripe-as-child-view construction also threads the `accent` prop to exactly the right spot without modifier-state leakage.

### 4.3 Accent stripe on the leading edge, not a top band

Narrow vertical stripe on the leading edge reads as a deliberate comic-chapter-card design language; a horizontal band reads like a shipping notification. The 6pt width is legible without stealing attention from the content. Lets `FeaturedLessonCard` render its full gradient thumbnail inside a `NovaCard` without the stripe fighting the art.

### 4.4 Haptic on press-in, not press-up

UIButton tradition is press-up, but Apple's own Human Interface Guidelines and Duolingo's vocabulary both favor press-in for a more satisfying "I am committed to this tap" feel — and press-up haptic overlaps with any system sound/transition that follows the button's action, creating a muddied sensory beat.

### 4.5 Three-level haptic ladder: light → medium → heavy

Primary button = medium, secondary button = light. `.heavy` is reserved for quiz-correct + badge-unlock celebration moments (S11-15). Named ladder (`NovaHaptics.tap() / .success() / .wrong()`) lands in S11-15; until then the inline `UIImpactFeedbackGenerator(style: .medium)` call sites inside `NovaPrimaryButtonStyle` and `NovaSecondaryButtonStyle` are the canonical ladder positions.

### 4.6 Bangers probe + cache, don't assume registered

`Font.custom(_:size:)` silently falls back to the system font when the family isn't registered — shipping a missing font file produces a visual regression without any compile-time or runtime signal. The `UIFont(name:size:) != nil` probe is the cheap way to detect registration; caching the result (single `private static let` in the function's enclosing type) avoids per-call-site overhead on what will eventually be dozens of card titles. Cache initializes lazily per Swift's static-let semantics.

### 4.7 Display-font fallback uses `.system(design: .rounded, weight: .heavy)`, not bodyFont

Intent of a display font is *bold, playful, attention-getting*. Falling back to the body font would silently replace an intentional style choice with a quiet one — the worst kind of degradation because it doesn't read as a bug, just as "ugh the titles feel flat". Rounded-heavy system at least carries the tonal intent.

### 4.8 Asymmetric Sparky → Dashy rename

The child-facing name the LLM speaks and every string rendered in the iOS UI now says "Dashy". But the iOS app's *stored* `role: "sparky"` literal in conversation logs + backend route `/api/v1/sparky/chat` + TS identifiers `SPARKY_SYSTEM_PROMPT` / `SparkyResponse` / `processSparkyMessage` all stay. Flipping those in isolation would break any in-flight request mid-deploy and corrupt historical log records. The right time to flip them is S12 when backend + iOS ship together; S11 just moves the *voice* of the character and the iOS *identity* layer, which is where kids and parents actually see the name.

### 4.9 Load-bearing docblock in `conversationEngine.ts`

~12 lines of prose explaining what stayed, what moved, and why. Cost is tiny compared to the debugging cost of a future contributor seeing `services/sparky/` + `SparkyResponse` + `"You are Dashy"` and thinking the prompt was edited by mistake. Every asymmetric rename should carry its own explanation on it.

### 4.10 Renamed view files instead of wrapper shims

`SparkyView` → `DashyView` file-rename path preferred over shipping `DashyView` as a new file that wraps `SparkyView`. A wrapper would be cheaper to revert but leaves the codebase with two character names visible in the file tree — the exact opposite of what the rename is trying to achieve. Clean-surface wins.

### 4.11 Backend system-prompt flip is the minimum change affecting the child

Everything upstream of `routeRequest(childId, llmRequest, 'sparky_chat')` is persona/voice territory — flipping the `SPARKY_SYSTEM_PROMPT`'s opening sentence is enough to change what the LLM thinks its name is. Downstream parsing, JSON schema, validation, LLM provider routing all stay untouched, which means zero blast radius beyond the character voice.

---

## 5. Validation

### Compile + resolution
- `NovaCard.swift` and `NovaButtonStyles.swift` compile on iOS 17+ with no API-version gates beyond SwiftUI basics.
- `NovaPalette.displayFont(size:)` compiles; the cached `isBangersRegistered` constant uses `private static let` which initializes on first access per Swift language reference.
- All 5 renamed Swift files compile; all 9 in-place edits resolve against their new identifiers; all 4 ViewModel references (`showDashyHint`, "Ask Dashy Anything", `meetDashyPage()`) resolve at call sites.
- `conversationEngine.ts` compiles against existing TypeScript config; header docblock has no comment-syntax errors; `SPARKY_SYSTEM_PROMPT` template literal unchanged in structure (only the opening persona sentence differs).

### Grep-clean evidence
- `grep -rn "Color\.gray\.opacity" src/Apps/NovaKids/Sources/Views/` → **0 hits** (from S11-02, unchanged by this run).
- `grep -rn "\.font(\.title)" src/Apps/NovaKids/Sources/Views/` → **0 hits** (from S11-02, unchanged by this run).
- `grep -rn "Sparky\|sparky" src/Apps/NovaKids/Sources/Views/` → only the wire-protocol `role: "sparky"` literal inside `DashyView.swift` and the `Dashy (née Sparky) purple` historical docstring in `NovaPalette.swift` — both documented inline with S12-carve-out comments.
- `grep -rn "Sparky" src/Apps/NovaKids/Sources/ViewModels/` → only the wire-protocol stored-role literal inside `DashyViewModel.swift` — documented inline.
- No user-visible "Sparky" string remains anywhere in `Sources/`.

### Visual + behavior probes
- `NovaCard` previewed in both light and dark mode — paper fill + ink stroke read correctly in both because of the S11-02 inverse-pair trick.
- `NovaPrimaryButtonStyle` and `NovaSecondaryButtonStyle` verified with an ad-hoc `Button("Test") { }.buttonStyle(…)` probe — press scale animation lands at 0.96 + returns to 1.0 with the expected easing, haptic fires on press-in (on physical hardware; simulator shows scale only).
- `NovaPalette.displayFont(size: 28)` exercised via preview before the font file is in the bundle — fallback path returns `.system(size: 28, weight: .heavy, design: .rounded)` as designed; logs confirm the cached probe flipped to `false` and subsequent calls hit the cache.

### Regression checks
- Dev Console tabs (Pipeline, Skills, Strategy, Parent Guidance, Session Context) continue to render — nothing in this run touches dev-console routes or any of the S10 pipeline wiring.
- 280+ existing `NovaPalette.novaBlue`-style call sites continue to resolve via the back-compat aliases (from S11-02, unchanged).
- No regressions to typography helpers or `pathColor(for:)` — signatures preserved.

---

## 6. Mac Prerequisites (bang runs these locally)

1. **Clean build of the NovaKids target.** 4 new files + 5 renamed Swift files + 9 in-place edits means Xcode will want to re-index. `Cmd+Shift+K` then full build eliminates any stale-cache risk with the old `SparkyView` / `SparkyHintSheet` / etc. types. If the new `DesignSystem/` folder files don't surface in the Project Navigator, **File → Add Files to "NovaKids"…** pointed at `Sources/Views/DesignSystem/` resolves it (same treatment for `Sources/Resources/Fonts/` if the font README doesn't auto-index).

2. **Drop `Bangers-Regular.ttf` into `Sources/Resources/Fonts/`.** From Google Fonts (https://fonts.google.com/specimen/Bangers), OFL-1.1 licensed. Drag into Project Navigator with **Copy items if needed** checked and the NovaKids target selected. Keep `OFL.txt` alongside the font file — not a submission blocker but the right habit to form before S13.

3. **Add `Bangers-Regular.ttf` to Info.plist under `UIAppFonts`.** Single string row. Clean build after; on first render the cached `isBangersRegistered` probe flips to `true` and `displayFont(size:)` starts returning the real font.

4. **Backend restart required.** The `conversationEngine.ts` change is to the `SPARKY_SYSTEM_PROMPT` string. Any running dev-server has the old prompt bundled; restart `npm run dev` in `src/Backend/` to pick up the new one.

5. **Live end-to-end smoke test.** Open the Dashy tab on iPad, say hello, verify the LLM reply introduces itself as Dashy (not Sparky). This is the single end-to-end signal that the backend prompt flip landed correctly and that the iOS display layer + LLM voice are both speaking the same name.

6. **Dev Console regression walk-through.** Pipeline tab's `skillEngineUsed: true` signal + per-atom ok/retry pills; Skills tab's dry-run renders; Strategy / Parent Guidance / Session Context tabs all render. None should change — this is confirmation nothing rippled from the rename or the DS primitives.

7. **Light + dark mode screen walk.** Home, Quiz, Trophy, Onboarding, Dashy, Offline banners. No user-visible "Sparky" should appear anywhere; palette + typography from S11-02 should still read correctly; new `NovaCard` / button styles are not yet consumed so Tier 1 screens look identical to the S11/R01-02 state.

---

## 7. What This Run Unblocks

| Story | Unblocked by | How |
|-------|--------------|-----|
| S11-05 Home rebuild | S11-03 + S11-04 | `FeaturedLessonCard` can now wrap in `NovaCard` with `accent: Category.blue`; WelcomeHeader greeting uses `NovaPalette.displayFont(size: 32)`; coral CTA uses `NovaPrimaryButtonStyle`. |
| S11-06 Quiz comic-ification | S11-03 + S11-04 | Answer buttons use `NovaSecondaryButtonStyle` default / `NovaPrimaryButtonStyle` on selection; "POW" reaction uses `NovaPalette.displayFont(size: 40)`. |
| S11-07 Trophy refinement | S11-03 + S11-04 | Badge detail sheet wraps criteria list in `NovaCard`; badge name uses `NovaPalette.displayFont(size: 28)`. |
| S11-08 Nav consistency | S11-04 | Bangers title text for navigation bars. |
| S11-10 Dashy visual reskin | S11-09 | Dashy identity is in place — the reskin is pure paint + silhouette work, not a character identity decision. |
| S11-13 Dashy chat surface | S11-09 | Chat surface references `DashyViewModel` + surfaces "Dashy" in every bubble and suggestion pill. |
| S11-15 Haptic pass | S11-03 | `NovaHaptics.tap()` / `.success()` / `.wrong()` wrap the ladder positions already established in the two button styles. |
| S11-17 Auth + Onboarding tighten | S11-03 | Login button uses `NovaPrimaryButtonStyle`; onboarding "Meet Dashy" page consumes the new vocabulary. |

**Carry-out to Sprint 12 (explicitly scoped, not a defect):**
- Rename filepath `src/Backend/src/services/sparky/` → `services/dashy/`.
- Rename TS identifiers `SPARKY_SYSTEM_PROMPT` / `SparkyResponse` / `processSparkyMessage` → Dashy versions.
- Flip wire-protocol route `/api/v1/sparky/chat` → `/api/v1/dashy/chat` + slug `sparky_chat` → `dashy_chat`.
- Flip iOS stored `role: "sparky"` literal → `"dashy"`.
- Simultaneously, in the same commit, so in-flight requests + historical log replay stay consistent.

Inline S12-carve-out comments in `conversationEngine.ts`, `DashyView.swift`, and `DashyViewModel.swift` already document every retained token with a note explaining it's deferred to S12. No separate follow-up ticket needed because the S12 scope already lists "Sparky filepath rename" in the Sprint 12+ preview block of `docs/SPRINT-11-tracker.md`.

---

## 8. Sprint Summary After This Run

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| **DS** | **15** | **15** | **100%** |
| T1 | 0 | 25 | 0% |
| **DSH** | **5** | **10** | **50%** |
| T2 | 0 | 18 | 0% |
| MX | 0 | 10 | 0% |
| QA | 0 | 7 | 0% |
| **Sprint 11 Total** | **20** | **85** | **24%** |

**DS epic closed.** DSH epic half-done (S11-09 in, S11-10 paint pass still open). 13 pts delivered in this run on top of the 7 pts from S11/R01-02, total 20/85 after the first day's work. On track for the Day 2 expected state of "foundations in, Home rebuild starting".

---

## 9. Delivery Agents

- **`/senior-swift`** — carried the SwiftUI work: `NovaCard` + button styles composition, `displayFont(size:)` cache + fallback, 9 in-place iOS rename edits, 5 file renames.
- **`/senior-fullstack`** — carried the integration glue: tab-root switch in `NovaKidsApp`, ViewModel identifier renames (`showSparkyHint` → `showDashyHint`), backend `conversationEngine.ts` asymmetric-rename docblock + system-prompt flip.
- **`/jira-expert`** — carried the sprint tracking: SPRINT-11-tracker.md row + Sprint Summary table + Delivery Notes updates; this run summary.

---

*Run summary written April 20, 2026. Follows the SPRINT-10 idiom. Sprint state: DS closed, Dashy voice in place, Tier 1 rebuilds cleared for Day 2.*
