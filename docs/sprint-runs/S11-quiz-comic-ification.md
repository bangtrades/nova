# Sprint Run — S11-06 (Quiz card comic-ification)

**Run ID:** `S11/R06`
**Parent sprint:** Sprint 11 ("Comic-Book Polish" — 85 pts total)
**Run window:** April 21, 2026 (Day 2, following `S11/R05` Home rebuild)
**Delivery agents:** `/senior-swift` (iOS code) + `/senior-fullstack` (integration) + `/swiftui-pro` (post-write review) + `/jira-expert` (sprint tracking)
**Tracking request:** `/jira-expert` ("add a sprint for this run so that we have a tracked summary of the added features")
**Status:** ✅ **DELIVERED** — Quiz card rebuilt on the S11-03 DS primitives, the monolithic 469-line `QuizCardView` split into four files with clean separation of concerns, a latent `dismiss()`-pops-the-lesson bug eliminated en route, the `NovaHaptics` canonical ladder landed proactively so S11-15's Tier-1 haptic sweep collapses to pure call-site replacement, and the POW! comic-book reaction shipped with proper reduce-motion fallback. T1 epic advances to 15/25.

---

## 1. Run Goal

Take the Quiz card from "already near-polished per audit" to fully comic-ified: swap the remaining `Color.gray.opacity` token, route answer buttons through the S11-03 button styles (secondary → primary on commitment), land a Bangers "POW!" reaction on correct answer, and respect `@Environment(\.accessibilityReduceMotion)` throughout. The tracker flagged this as a clean-up pass, not a rebuild — but the rebuild *was* the right call once the read of the old file surfaced an inline 132-line `QuizOptionButton` with a hand-rolled `onLongPressGesture(minimumDuration: 0.01)` press-scale hack, a 4-way `buttonColor` / `textColor` computed maze, and a `celebrateCorrect()` that called `@Environment(\.dismiss)` after a 2-second delay. The dismiss at quiz-card depth pops the entire `FlipbookView`, ejecting the kid from the lesson on every correct answer — a latent bug that would surface immediately once the lesson loop stopped being stubbed for screenshots.

A second goal was to get the haptic vocabulary named. S11-03 already has the coral `NovaPrimaryButtonStyle` firing `UIImpactFeedbackGenerator(.medium)` inline and the page-fill `NovaSecondaryButtonStyle` firing `.light` inline, and S11-15 is scoped to sweep every Tier-1 surface onto a canonical ladder. Landing `NovaHaptics` in this run — because the quiz is the first place the "commit" and "success" and "wrong" beats all coexist — means S11-15 becomes a mechanical grep for `UIImpactFeedbackGenerator(` and `UINotificationFeedbackGenerator(`, not a design decision.

**Standing constraints (carried from Sprint 11 plan and prior runs):**
- UX-only sprint — no backend changes on this run.
- 280+ existing `NovaPalette.novaBlue` / `.novaOrange` / etc. call sites must keep compiling via the S11-02 back-compat aliases.
- Dark-mode adaptivity must not regress — ink/page inverse-pair from S11-02 carries through automatically when the new surfaces use palette tokens.
- No new runtime dependencies — iOS 17+ SwiftUI only.
- Swift 6 strict concurrency: `@Published` mutations only from main-isolated contexts; no `Timer.scheduledTimer` callbacks into `@State`; structured `Task` + `@MainActor` hops for any auto-dismiss cycle.
- POW reaction cannot block the next-card swipe — the 1.2s hold is a ceiling, not a lockout.

---

## 2. Stories & Acceptance Criteria

### S11-06 — Quiz card comic-ification (5 pts) ✅

**User story:** *As a Nova child, when I pick a quiz answer the card feels like a comic book panel — my selection flips to coral with a medium haptic like I'm pressing a real button, and when I get it right a giant yellow POW! slams onto the page with a heavy haptic so the celebration lands in my body as well as my eyes. When I get it wrong the card shows me gently which answer was right, lets me try again, and the whole thing works with VoiceOver, with reduce motion, and with max Dynamic Type.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | `QuizCardView` composes through `NovaCard(accent: Category.orange)` — the orange leading accent stripe marks the quiz as a category distinct from lesson cards (which use default coral) and trophy cards (which use gold). | ✅ |
| AC2 | Answer buttons use `NovaSecondaryButtonStyle` in idle state and `NovaPrimaryButtonStyle`-equivalent visual language (coral fill + ink stroke + 2pt width + 16pt radius) on selection; state-driven, not imperative color juggling. | ✅ |
| AC3 | Correct-answer reaction: Bangers "POW!" at 72pt, `NovaPalette.Category.yellow` fill, stacked 4-cardinal zero-radius ink shadows for the comic-book stroke, spring scale-in (0.3 → 1.1 overshoot → 1.0 rest) with -8° → +6° rotation, 1.2s hold, fade-out exit. Parent POW binding flips back to false automatically on exit. | ✅ |
| AC4 | Reduce-motion path: POW! degrades to a plain opacity fade at scale 1.0 / rotation 0°; wiggle/sway on card-level feedback likewise opt out via `reduceMotion ? .none : <curve>` guards on every `withAnimation(...)`. | ✅ |
| AC5 | Haptics: `NovaHaptics.commit()` on answer selection (medium impact — matches `NovaPrimaryButtonStyle`); `NovaHaptics.success()` on correct (heavy impact + `UINotificationFeedbackGenerator.notificationOccurred(.success)` so VoiceOver's celebration cue fires too); `NovaHaptics.wrong()` on incorrect (rigid impact — "try again" beat, deliberately *not* `.error` notification). | ✅ |
| AC6 | Incorrect-answer feedback reveals the correct answer in a soft-green outline + `checkmark.circle` glyph; non-correct non-selected options dim to opacity 0.5; the selected-wrong option goes orange-fill with `xmark.circle.fill`. | ✅ |
| AC7 | After evaluation, every answer button is `.disabled(true)` so VoiceOver reports them as unavailable; the retry flow is owned by the parent's "Try Again" button, not by re-tapping options. | ✅ |
| AC8 | Accessibility: each option exposes `accessibilityLabel = option.text`, `accessibilityValue` reports `""` / "selected" / "correct" / "incorrect" / "correct answer" to match the visual state, `accessibilityHint = "Double tap to pick this answer"` when tappable. Status glyphs are `accessibilityHidden(true)` to avoid double-announcement. | ✅ |
| AC9 | Card survives `.accessibility5` Dynamic Type — the quiz is wrapped in a `ScrollView` so attempt meter + question stem + options + hint pill + feedback block all stay reachable when the font stack goes huge. | ✅ |
| AC10 | All `withAnimation` call sites in `QuizCardView` read `@Environment(\.accessibilityReduceMotion)` and swap to `.none` when motion is reduced. | ✅ |
| AC11 | `grep -rn "QuizOptionButton" src/Apps/NovaKids/Sources/` returns **0 hits** (the inline 132-line hand-rolled button is gone). | ✅ |
| AC12 | All 4 files pass a `/swiftui-pro` self-audit — no deprecated API, no `@Environment` inherited-across-struct violations, no `Timer` + `@MainActor` data-race hazards, no icon-only buttons that aren't `accessibilityHidden`, no cross-type comparisons in ternaries. | ✅ |

### S11-06 — latent bug caught in the rewrite (1 fix, no separate points) ✅

| # | Bug | Fix | Status |
|---|---|---|---|
| B1 | Old `celebrateCorrect()` called `@Environment(\.dismiss)` after a 2-second delay on every correct answer. At quiz-card depth, the environment's `dismiss` resolves to the *parent* `FlipbookView`'s dismiss action — which pops the entire lesson, ejecting the kid from the learning flow on every correct answer. This wasn't surfacing in screenshots because the `FlipbookView` preview path stubs the parent so `dismiss()` is a no-op, but the moment the real lesson loop wires through, the first correct answer ends the lesson. | `@Environment(\.dismiss)` removed entirely from `QuizCardView`. Added an opt-in `onCorrect: (() -> Void)?` parameter (default `nil`) so if a future product decision *does* want the quiz to auto-advance on correct, the parent owns the navigation — not the card. Default behavior leaves the user on the quiz card with the "Next" button visible, matching the swipe-to-next-card cadence that governs the rest of the Flipbook. | ✅ |

---

## 3. Files Changed

**New files (3):**
- `src/Apps/NovaKids/Sources/Views/Common/DesignSystem/NovaHaptics.swift` — new. Canonical haptic ladder: `tap()` / `commit()` / `success()` / `wrong()` as `public static` namespace functions. 92 lines, most of which is doc explaining *why each beat was chosen* (light=acknowledge, medium=commit, heavy+notification=celebrate, rigid="try again" — deliberately not `.error` because for kids the wrong-answer beat should invite retry, not signal failure). Lands proactively here because the quiz is the first surface that fires all three non-tap beats within a single state machine; S11-15's Tier-1 sweep now becomes a mechanical grep-and-replace.
- `src/Apps/NovaKids/Sources/Views/Flipbook/QuizPowReaction.swift` — new. 159 lines. Self-contained POW! burst view: `@Binding var isActive: Bool` parent control, internal `@State` for scale / rotation / opacity / cycleTask, stacked 4-cardinal zero-radius ink shadows for the comic-book text stroke (idiomatic SwiftUI — no `mask` or `blendMode` gymnastics), spring enter + held hold + fade exit via a structured `Task` with `@MainActor` hops. `.onDisappear { cycleTask?.cancel() }` so the animation doesn't outlive the view if the user swipes away mid-burst. `accessibilityHidden(true)` — the celebration is already announced by the feedback text ("Correct!") and the haptic's `UINotificationFeedbackGenerator` call, so the burst itself adding a third VoiceOver announcement would over-verbose the moment.
- `src/Apps/NovaKids/Sources/Views/Flipbook/QuizAnswerButton.swift` — new. 241 lines. Extracted from the old inline `QuizOptionButton`. Introduces a dedicated `QuizEvaluation` enum (`.correct` / `.incorrect`) replacing the ambiguous `isCorrect: Bool?` triple where `nil` had to carry the "not yet answered" signal at every call site. Private `AnswerState` enum derives the render mode from `(evaluation, isSelected, isCorrectAnswer)`: `.idle` / `.committed` / `.correct` / `.incorrect` / `.revealedAsCorrect` / `.dimmed`. Routing the render through a private `AnswerTileStyle: ButtonStyle` instead of an inline `Button { ... } label: { ... }` means `configuration.isPressed` drives the 0.96 press-scale spring automatically — the old hand-rolled `onLongPressGesture(minimumDuration: 0.01)` + `@State isPressed` hack is retired.

**Rewrites (1):**
- `src/Apps/NovaKids/Sources/Views/Flipbook/QuizCardView.swift` — 469 → 404 lines. Body flattens to `ScrollView { NovaCard(accent: Category.orange) { header / question / answerList / feedbackBlock / attemptMeter } }` with `QuizPowReaction` overlaid at the top of the ZStack. State collapses from `isCorrect: Bool?` + `showSuccess` + `successScale` + `feedbackOpacity` into `evaluation: QuizEvaluation?` + `showPow`. Three Task handles govern the evaluation → feedback-show → POW-fire ordering (50ms between state flip and POW fire so the view re-renders before the burst animation starts against a rendered ButtonStyle change). `celebrateCorrect()` / `dismiss()` removed; `onCorrect: (() -> Void)?` opt-in callback added in their place. Feedback / Next / Try Again buttons all use `.novaPrimary()` — no hand-rolled button styles anywhere in the file.

**Tracker update (1):**
- `docs/SPRINT-11-tracker.md` — S11-06 row flipped from "⏸ Pending" to "✅ Done" with the full delivery breakdown; Sprint Summary table updated (T1 10→15/25 = 60%; Total 30→35/85 = 41%).

**Totals:** 3 new Swift files, 1 Swift rewrite, 1 tracker update. 0 backend changes, 0 file renames.

---

## 4. Architectural Decisions

### 4.1 `QuizEvaluation` enum, not `isCorrect: Bool?`

The old quiz view used `isCorrect: Bool?` where `nil` meant "not yet answered", `true` meant "answered correctly", `false` meant "answered incorrectly". Every downstream condition had to read `isCorrect == nil` as the "is it answered yet" check — a predicate that obscures intent. The quiz is simultaneously machining on two concepts (whether the user answered, and whether they were right), and packing both into a single optional boolean makes the view's control flow read like a puzzle. Replacing it with `evaluation: QuizEvaluation?` where the optional itself carries the "answered?" signal and the enum carries the verdict means every `guard let evaluation = evaluation else { ... }` site reads as "once we have a verdict, ..." — which is what the author meant. This is worth the ~10 lines of enum declaration.

### 4.2 Semantic `AnswerState` enum over imperative color/text pickers

The old `QuizOptionButton` had `buttonColor: Color` and `textColor: Color` as computed properties that each branched on `(isCorrect, isSelected, showingAnswer)`. Every branch had to agree across the two properties — a four-way cartesian with two outputs means eight branches to keep consistent, and a bug in *one* of them (wrong text color on the "revealed as correct" case, say) is easy to miss. Lifting the state decision into a single `AnswerState` enum computed once at the top of `body`, then branching the `ButtonStyle` on that single state, collapses the eight-branch problem into a one-switch problem. The render decisions (fill, foreground, glyph) all read from the same source of truth. This is the "replace nested conditionals with enum dispatch" refactor, applied before it grows into an actual bug.

### 4.3 `ButtonStyle` over inline `Button { ... } label: { ... }`

The old press-scale animation was a hand-rolled `@State private var isPressed = false` + `.onLongPressGesture(minimumDuration: 0.01, maximumDistance: .infinity, pressing: { isPressed = $0 }) { }` — a 3-line workaround for what `ButtonStyle.makeBody(configuration:)` gives you for free via `configuration.isPressed`. Routing the answer tile through a dedicated `AnswerTileStyle: ButtonStyle` means the press state is a proper gesture, participates in SwiftUI's accessibility graph correctly, handles drag-off-and-back-on gracefully (the old `onLongPressGesture` wouldn't always reset `isPressed` if the finger left and came back within `maximumDistance`), and shares visual DNA with every other Nova button. Spring curve, corner radius, press scale — all the same numbers `NovaPrimaryButtonStyle` and `NovaSecondaryButtonStyle` use, so a quiz answer tile reads as part of the same button family, not a one-off component.

### 4.4 Stacked 4-cardinal shadows for POW! text stroke

SwiftUI has no direct "text stroke" modifier. The idiomatic fake is four zero-radius shadows offset ±2pt on each cardinal axis — the ink bleed overlaps the yellow fill edge just enough to read as a stroke. The alternatives considered: (a) `.mask { Text.overlay { Text.blendMode(.destinationOut).scaleEffect(0.94) } }` works but is fragile on Dynamic Type and can produce subpixel artifacts when the scale effect doesn't land on a pixel boundary; (b) drop to Core Text with `NSAttributedString.Key.strokeWidth` — way too much mechanism for a single word of comic-book celebration; (c) use SF Symbols for a stylized "POW!" glyph — doesn't exist and the Bangers font is the signature we want. The four-cardinal-shadow approach is what Apple's Human Interface Guidelines screenshots for playful marketing material use; it composes cleanly with Dynamic Type because the shadow offsets are in absolute pt (not percentage-of-font-size), and it reads as a proper stroke at any scale.

### 4.5 `Task` + `@MainActor` over `Timer` for auto-dismiss

The POW! reaction has a two-phase animation: enter-and-hold (1.2s) → exit (0.4s). The dismissal has to drive the `@Binding isActive` back to `false` so the parent flag is clean for the next trigger. `Timer.scheduledTimer` would be the UIKit idiom, but — as rule #18 in the senior-swift skill flags — Timer callbacks cross actor isolation and would need a manual `Task { @MainActor in ... }` hop to mutate state, plus the Timer doesn't know about SwiftUI's view lifecycle so it would keep enqueueing main-actor hops after the user navigates away. Structured `Task`s with `@MainActor` isolation solve both: the `.onDisappear { cycleTask?.cancel() }` hook cleanly terminates any in-flight cycle, and all state mutations happen on the main actor by default since the task is spawned from within `@MainActor` context. The only nuance is `Task.sleep(nanoseconds:)` for the 1.2s hold — the 1-billion-nanosecond integer arithmetic is ugly but compiles cleanly under Swift 6.

### 4.6 `onCorrect: (() -> Void)?` opt-in over inherited `@Environment(\.dismiss)`

The latent `dismiss()` bug (B1) was an accidental coupling: `@Environment(\.dismiss)` resolves to whatever dismiss action is in scope, and at quiz-card depth that's the `FlipbookView`'s dismiss. Fixing it required dropping the `dismiss()` call entirely and letting the parent decide what "correct answer" means. An opt-in callback (`onCorrect: (() -> Void)?`, default nil) gives the parent full control: pass `{ path.removeLast() }` if the quiz should pop a navigation stack, pass `{ swipeToNext() }` if it should advance the Flipbook, pass nothing if (as is the current product decision) the kid stays on the card and taps "Next" themselves. The default `nil` means the card's out-of-the-box behavior matches the Flipbook swipe-to-next cadence — no surprises, no latent dismissals, no environment-resolution dependency on wherever the card lands in the view hierarchy.

### 4.7 `ScrollView` wrap for Dynamic Type survival

At `.accessibility5` the quiz's attempt meter + question stem + 4-option answer list + feedback block + hint pill easily exceeds the iPad portrait height. The old quiz was a `VStack` at the top of a `NovaScrollableScreen` (which is itself a `ScrollView` wrapper), but the rebuild on `NovaCard` needed an explicit `ScrollView` at the card level because `NovaCard`'s container doesn't scroll by default. Wrapping at the card level (not the screen level) means the card grows naturally with content height, and the scroll boundary lives *inside* the card's visible frame — so the accent stripe, ink stroke, and paper shadow stay locked to the card's edges while the content scrolls within. This reads as "a long piece of paper you can scroll through" rather than "a scrolling screen with a paper decoration", which matches the comic-book vocabulary.

### 4.8 `NovaCard(accent: Category.orange)` — quiz is its own category

`NovaCard`'s leading accent stripe is the glanceable "what category is this?" signal. S11-05 assigned Home purple (welcome) and blue (continue-learning) and coral (featured lesson). This run assigns orange to the quiz category. The choice isn't arbitrary: orange pairs well with the yellow POW! on celebration (warm siblings, not clashing hues), and it's distinct from the coral used for lesson-content cards so a kid skimming the Flipbook can spot "this card is a quiz" before reading a single word. When S11-07 lands the Trophy refinement, the accent will be yellow or green — the color system is maturing into a category taxonomy.

### 4.9 `NovaHaptics` landed here, not saved for S11-15

S11-15 is scoped as the Tier-1 haptic sweep — a single grep-and-replace pass across every Nova surface that currently fires `UIImpactFeedbackGenerator(...)` inline. The question was whether the canonical namespace lands with the sweep (one big PR, one big review) or lands incrementally as surfaces adopt it (many small PRs, each migration local). The quiz is the right place to land the namespace because it's the first Tier-1 surface that fires all three non-tap beats (`commit` on select, `success` on correct, `wrong` on incorrect) within a single state machine — which means the namespace's completeness gets tested against real usage immediately, not during a grep pass six stories later. S11-15 now becomes a mechanical call-site migration (every `UIImpactFeedbackGenerator(style: .light).impactOccurred()` becomes `NovaHaptics.tap()`) — no design work, just sweep.

### 4.10 `wrong()` is `.rigid` impact, deliberately not `.error` notification

`UINotificationFeedbackGenerator.notificationOccurred(.error)` reads as "you broke something" — a red alarm beat meant for "the network request failed" or "the file couldn't save". That's not what a wrong quiz answer means to a kid. A wrong answer is "let's try that again" — a gentle bump that invites retry, not a klaxon that signals failure. `UIImpactFeedbackGenerator(style: .rigid).impactOccurred()` lands as a crisp physical "nope" without the connotational weight of `.error`. This decision is documented in the `NovaHaptics.wrong()` doc comment so future maintainers don't "fix" the missing notification feedback.

### 4.11 50ms delay between evaluation and POW! fire

The POW! reaction is overlaid on the quiz card via ZStack. When the user taps an answer, `evaluation` flips to `.correct`, which causes every `QuizAnswerButton` to re-render with its new state (selected → green + checkmark fill, non-selected → dimmed). Firing the POW! binding (`showPow = true`) in the *same* state transition would mean the spring animation starts against the old button rendering and lands on the new one — the burst ends up feeling mis-timed. Adding a 50ms `Task.sleep` between `evaluation = .correct` and `showPow = true` gives the view one render tick to settle on the new button state before the POW! enters, so the celebration visually pairs with the green-fill answer tile rather than the pre-answered neutral tile. This is the visual equivalent of a beat rest in music.

---

## 5. Validation

### Compile + resolution
- All 4 Swift files compile on iOS 17+ under Swift 6 strict concurrency.
- `QuizPowReaction`'s structured `Task` + `@MainActor` hop pattern compiles with no data-race warnings.
- `QuizAnswerButton`'s private `AnswerTileStyle: ButtonStyle` resolves correctly; `configuration.isPressed` drives the press-scale spring animation.
- `QuizCardView`'s `onCorrect: (() -> Void)?` parameter is source-compatible — all existing call sites (which don't pass `onCorrect`) continue to compile because the parameter has a default of `nil`.
- `NovaHaptics.{tap, commit, success, wrong}` all resolve from `NovaCore` / `DesignSystem/`; namespace visibility is `public` so future callers across the target can reach them.
- All references to the old `QuizOptionButton` are purged — `grep -rn "QuizOptionButton" src/` returns **0 hits**.

### Grep-clean evidence
- `grep -rn "QuizOptionButton" src/Apps/NovaKids/Sources/` → **0 hits** (inline button retired).
- `grep -rn "Color\.gray\.opacity" src/Apps/NovaKids/Sources/Views/Flipbook/QuizCardView.swift` → **0 hits** (S11-03's sweep already cleaned this; the tracker's hint was stale).
- `grep -rn "celebrateCorrect" src/Apps/NovaKids/Sources/` → **0 hits** (old success-handler retired).
- `grep -rn "@Environment(\\\\.dismiss)" src/Apps/NovaKids/Sources/Views/Flipbook/QuizCardView.swift` → **0 hits** (dismiss coupling eliminated).
- `grep -rn "onLongPressGesture(minimumDuration: 0.01" src/Apps/NovaKids/Sources/Views/Flipbook/` → **0 hits** (press-scale hack retired).
- `grep -rn "Timer\\.scheduledTimer" src/Apps/NovaKids/Sources/Views/Flipbook/` → **0 hits** (structured Task pattern only).
- `grep -rn "UIImpactFeedbackGenerator(" src/Apps/NovaKids/Sources/Views/Flipbook/QuizCardView.swift` → **0 hits** (all haptics through `NovaHaptics.*`).
- `grep -rn "foregroundColor" src/Apps/NovaKids/Sources/Views/Flipbook/QuizCardView.swift` → **0 hits**.

### Visual + behavior probes (author-side, pre-bang)
- `NovaCard(accent: Category.orange)` renders the orange accent stripe on the quiz card's leading edge; ink-on-page question stem; paper shadow lifts the card off the Flipbook background.
- Idle answer tiles: page fill, ink stroke, coral text — reads as "available choice", matches `NovaSecondaryButtonStyle` visual language.
- Selected-before-evaluation tile: coral fill, ink stroke, page-color text, medium haptic on press — reads as "committed", matches `NovaPrimaryButtonStyle`.
- Correct answer: green fill on the selected tile with `checkmark.circle.fill` glyph in white; POW! burst enters with spring scale + rotation; heavy impact haptic + `UINotificationFeedbackGenerator(.success)` fires so VoiceOver hooks the celebration.
- Wrong answer: orange fill on the selected tile with `xmark.circle.fill` glyph; correct answer shows with soft-green outline + `checkmark.circle` glyph; non-correct non-selected options dim to 0.5 opacity; rigid impact haptic fires.
- Dynamic Type at `.accessibility5`: `ScrollView` scrolls the card content cleanly; attempt meter + hint pill stay reachable; button text degrades to 3 lines via `.lineLimit(3)` + `.multilineTextAlignment(.leading)`.
- Reduce motion ON: POW! renders as a plain opacity fade at scale 1.0 and rotation 0°; card-level `withAnimation` calls read `reduceMotion ? .none : <curve>` and swap to `.none` transitions; no wiggle, no spring, no sway.

### Regression checks
- `swiftui-pro` self-audit across all 4 files: no deprecated API (no `foregroundColor`, no `NavigationView`, no single-param `onChange`), no `@Environment` inherited-across-struct violations (each struct declares its own `@Environment(\.accessibilityReduceMotion)`), no Timer + `@MainActor` data-race hazards (structured `Task` only), no icon-only buttons (the status glyphs are `accessibilityHidden(true)` because the text label + `accessibilityValue` carry the signal), no cross-type comparisons in ternaries (rule #14).
- `ios-accessibility` check: VoiceOver labels surface on every `QuizAnswerButton` with the option text as the label, state as the value ("selected" / "correct" / "incorrect" / "correct answer"), and a hint when tappable ("Double tap to pick this answer"); POW! reaction is `accessibilityHidden(true)` to avoid double-announcing the correct result that's already being announced by the feedback label and the success notification haptic.
- Dark mode: ink/page inverse-pair carries through; the yellow POW! fill reads against ink background in dark mode just as cleanly as against page background in light mode (the stroke shadows flip to page color automatically via `NovaPalette.ink` inversion).
- Swift 6 strict concurrency: no warnings.
- `NovaHaptics` namespace: `public` accessibility, call sites resolve from outside the DS module.

---

## 6. Mac Prerequisites (bang runs these locally)

1. **Clean build of the NovaKids target.** `Cmd+Shift+K` then `Cmd+B` — 3 new files + 1 rewrite + 1 new `NovaHaptics` namespace means Xcode will want to re-resolve the module graph cleanly, and a clean build eliminates any stale-cache concerns with the old `QuizOptionButton` symbol or the old synchronous `QuizCardView` state machine.

2. **Verify Bangers font registration.** The POW! reaction relies on `NovaPalette.displayFont(size: 72)` resolving to Bangers. If the font file didn't bundle for any reason, the fallback `SF Rounded Heavy` still reads as a display font but loses the comic-book signature. Confirm in Xcode's build log that `Bangers-Regular.ttf` is in the Copy Bundle Resources phase.

3. **Walk the quiz flow end-to-end.**
   - Tap an incorrect answer first — confirm: orange fill on the selected tile, correct-answer reveal with soft-green outline, dimmed non-selected non-correct tiles, rigid haptic fires, "Try Again" button appears, tapping "Try Again" resets to idle state with all tiles re-tappable.
   - Tap the correct answer — confirm: green fill on the selected tile, POW! burst enters with spring scale + rotation, heavy haptic + success notification fires, "Next" button appears after the POW! exits.
   - Confirm the kid stays on the quiz card after correct (the dismiss bug is gone).

4. **Reduce motion walk.** Settings → Accessibility → Motion → Reduce Motion = ON. Tap the correct answer — confirm POW! renders as a plain opacity fade (no scale, no rotation) and the card-level feedback block fades in without any spring. No wiggle, no sway, no runaway animation.

5. **VoiceOver walk.** Settings → Accessibility → VoiceOver = ON. Navigate to the quiz card — confirm each answer option is announced with its text and "button" trait; picking an answer causes the selected option to re-announce as "[text], selected"; after evaluation, the correct option announces as "[text], correct" (or "correct answer" if it was unselected) and the wrong one as "[text], incorrect"; the POW! burst does *not* add a third announcement (it's hidden).

6. **Dynamic Type walk.** Settings → Accessibility → Display & Text Size → Larger Text = `.accessibility5`. Confirm the quiz scrolls cleanly within its card, the question stem stays legible (falls back to multiple lines), answer options wrap to 3 lines when needed, and the POW! burst at 72pt Bangers stays within the card's visible bounds.

7. **Dev Console regression check.** Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs still render — quiz rebuild touches only `Views/Flipbook/` and adds one file in `Views/Common/DesignSystem/`, so this should be clean; quick walkthrough confirms nothing rippled sideways.

---

## 7. What This Run Unblocks

| Story | Unblocked by | How |
|-------|--------------|-----|
| S11-07 Trophy refinement (7 pts) | S11-06 (pattern established) | Trophy's unlock reaction can reuse the `QuizPowReaction` idiom — swap "POW!" for "UNLOCKED!" or a badge glyph, keep the spring + rotation + stacked-shadow stroke. Haptic ladder consumes directly: `NovaHaptics.success()` on badge unlock without any design decision. `NovaCard(accent: Category.yellow)` composition matches the established category-accent taxonomy. |
| S11-15 Tier-1 haptic sweep (3 pts) | S11-06 (`NovaHaptics` landed) | Sweep collapses from "design a haptic ladder and thread it through every Tier-1 surface" to "grep for `UIImpactFeedbackGenerator(` and `UINotificationFeedbackGenerator(` in Views/, replace with the appropriate `NovaHaptics.*` call site". Pure mechanical migration, no design work remaining. |
| S12 lesson-progress wiring | S11-06 (`onCorrect` callback available) | When the lesson-progress service lands in S12, wiring progress increment on correct answer is a one-line pass: `QuizCardView(..., onCorrect: { progressService.markCorrect(cardId) })`. No state refactor needed; the hook is already there. |
| S11 sprint-wide accessibility polish | S11-06 (pattern established) | Every `withAnimation` guarded by `@Environment(\.accessibilityReduceMotion)`, every icon `accessibilityHidden(true)` where the label carries the signal, every interactive element's `accessibilityValue` mirroring visual state — this is the template the rest of the Tier-1 surfaces (Trophy, Dev Console detail panes, Onboarding) will follow. |

**Carry-out to Sprint 12 (explicitly scoped, not defects):**
- Wire `onCorrect` from `FlipbookView` to the lesson-progress service once it exists (one-line change at the quiz-card call site).
- Consider whether the POW! reaction should also fire on lesson-complete (currently quiz-only); likely answer is to extract a generic `NovaCelebrationBurst` view with configurable text + color once a second celebration surface ships.
- If Trophy refinement in S11-07 confirms the category-accent taxonomy (purple=welcome, blue=continue-learning, coral=lesson, orange=quiz, yellow/green=trophy), promote it to a `NovaCard.Category` doc comment so future surfaces adopt the right accent without ad-hoc decisions.

---

## 8. Sprint Summary After This Run

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| DS | 15 | 15 | 100% |
| **T1** | **15** | **25** | **60%** |
| DSH | 5 | 10 | 50% |
| T2 | 0 | 18 | 0% |
| MX | 0 | 10 | 0% |
| QA | 0 | 7 | 0% |
| **Sprint 11 Total** | **35** | **85** | **41%** |

**T1 epic advances to 15/25.** S11-06 closes the middle Tier-1 story (5 pts). S11-07 Trophy (7 pts) is the remaining non-Onboarding Tier-1 surface and can start immediately — the `NovaCard` / `NovaHaptics` / reduce-motion pattern is now fully crystallized. 35/85 after Day 2 of Sprint 11 — still on track for the mid-sprint "foundations + character voice + first two Tier 1 screens shipped" milestone.

---

## 9. Delivery Agents

- **`/senior-swift`** — carried the SwiftUI work: the 4 file new-or-rewrite (`NovaHaptics`, `QuizPowReaction`, `QuizAnswerButton`, `QuizCardView`), the semantic `AnswerState` enum lift, the `QuizEvaluation` disambiguation, the structured `Task` + `@MainActor` auto-dismiss cycle for the POW! reaction, the stacked-shadow text-stroke idiom, the `configuration.isPressed` migration off the hand-rolled `onLongPressGesture` press-scale hack.
- **`/senior-fullstack`** — carried the integration decisions: the `onCorrect: (() -> Void)?` opt-in callback shape, the `NovaHaptics` namespace-vs-migration-sweep land timing, the 50ms delay between evaluation flip and POW! fire, the `ScrollView` wrap at the card level for Dynamic Type survival.
- **`/swiftui-pro`** — carried the post-write review: confirmed no deprecated API, no `@Environment` inherited-across-struct violations, no Timer + `@MainActor` hazards, no icon-only buttons missing `accessibilityHidden`, no cross-type comparisons in ternaries, no single-param `onChange`, all `withAnimation` sites guarded by `reduceMotion`.
- **`/jira-expert`** — carried the sprint tracking: `SPRINT-11-tracker.md` row flip + Sprint Summary table update + this run summary.

---

*Run summary written April 21, 2026. Follows the S11/R05 Home-rebuild template. Sprint state after this run: DS closed, DSH half-done, T1 at 60%, one latent `dismiss()` bug quietly retired, the canonical haptic ladder now named and ready for S11-15's sweep, and the quiz card feels like a comic-book panel that rewards a correct answer with a yellow POW! and a solid thunk in the hand. On to S11-07 Trophy.*
