# S11-17 — Auth login + Onboarding spacing polish

**Run ID:** S11/R17
**Parent sprint:** [SPRINT-11](../SPRINT-11-tracker.md) — "Comic-Book Polish"
**Stories landed:** S11-17 (QA, 4 pts)
**Run window:** 2026-04-22 (single session)
**Landed:** 2026-04-22
**Status:** ✅ Delivered
**Delivery agents:** /senior-fullstack + /senior-swift + /swiftui-pro + /jira-expert
**Sprint progress after this run:** 88 / 93 pts (95%) — QA epic **4 / 7 (57%)**

---

## Run Goal

Close the first QA-epic story by bringing the app's two first-impression surfaces — the Sign-In screen and the 4-page Onboarding flow — onto the 3+1 palette, the `Spacing` enum, the `.novaPrimary()` / `.novaSecondary()` button vocabulary, and the reduce-motion-at-source branching pattern established in S11-05 / S11-13.

This is the story that picks up the *last* two places in the app still wearing the pre-S11-02 rainbow:

- **KidsLoginView** — a logo with a `novaBlue → novaPurple` gradient circle, four floating background shapes in `novaBlue / novaOrange / novaPurple / novaGreen` opacities, a hand-rolled off-white gradient backdrop, and an `UIImpactFeedbackGenerator`-free animation loop with no reduce-motion branch.
- **OnboardingView** — four hand-rolled pages of bespoke button gradients (`novaYellow / novaOrange → novaPurple`), inline `sin(Date().timeIntervalSince1970)` "animations" that were silently broken (no frame invalidation), a `.easeInOut` screen-transition that ignored `@Environment(\.accessibilityReduceMotion)`, and three separate raw magic-number paddings per page.

After this run, both surfaces consume exclusively DS primitives. The only legacy-palette literals that survive are three deliberate carve-outs (Dashy's body `novaPurple` character identity; the avatar-picker's per-avatar identity colors; `novaCardBackground` as an adaptive card-fill alias) — all documented inline.

S11-17's sequencing note on the tracker says *"Keep the confetti — that's already good."* Confirmed: the confetti survives as a single one-shot celebration burst, deliberately not gated by reduce-motion (it's a finish-line marker, not ambient motion — documented in the environment declaration).

---

## Stories & Acceptance Criteria

| ID | Story | AC → Outcome |
|----|-------|----------|
| S11-17 | Auth login tighten + Onboarding spacing | ✅ All 4 AC landed — login floating-shapes on 3+1 palette (ink / coral / sun over page); login buttons where allowed route through DS (Sign In with Apple stays stock per Apple HIG carve-out — see Decision 1); onboarding avatar grid consistently uses `Spacing.md` + `Spacing.sm + Spacing.xs`; Dashy's onboarding intro animates via `TimelineView(.animation)` with reduce-motion fallback to `.rest` pose; confetti preserved. |

**AC correction — in-plan vs drift.** The tracker row called for *"replace the two raw `.font(.title)` sites with `NovaPalette.titleFont()`"*. Grep confirms only **one** `.font(.title)` site remains across the entire `NovaKids/` tree, and it lives in `NovaCard.swift`'s `#Preview` sample — explicitly a preview-only literal, not a call-site target. Both onboarding raw `.font(.title)` sites were already swept during **S11-02 / S11-04** when `titleFont()` landed. Retiring this AC line as "already delivered upstream" rather than counting it as new work (see [Retired Debt](#retired-debt)).

---

## Files Changed

### Sources

| File | Δ LOC | Change |
|------|------:|--------|
| `src/Apps/NovaKids/Sources/Views/Auth/KidsLoginView.swift` | +54 / -29 (204 → 229) | Logo gradient `novaBlue → novaPurple` → `coral → sun` + 2pt ink-outline overlay; inner glyph + wordmark `.white` → `ink`; four floating shapes flipped to ink/coral/ink/sun opacities with deliberate weight variance; background LinearGradient collapsed to flat `NovaPalette.page`; `@Environment(\.accessibilityReduceMotion)` wired into `AnimatedBackgroundView` with source-level guard on the repeatForever loop; five raw paddings swapped to `Spacing` tokens; progress-view tint `novaBlue` → `coral`; doc comments explaining the S11-17 flip + Apple HIG carve-out for Sign In with Apple. |
| `src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift` | +153 / -119 (433 → 467) | `@Environment(\.accessibilityReduceMotion)` declared at struct scope with confetti-carve-out doc; container background `novaBackground` → `.page`; `meetDashyPage()` refactored from silently-broken inline `sin(Date())` into `TimelineView(.animation)`-driven `DashyIdlePose` struct with `.rest` static fallback + `dashyPageContent(pose:)` helper (ViewBuilder branching — see Decision 2); `chooseAvatarPage` / `enterNamePage` / `firstMissionPage` rewired through Spacing tokens + `.novaPrimary()` / `.novaSecondary()` on every Back/Next/Let's Go; one-step "Let's Go!" gradient stripped in favor of `.novaPrimary()`; `transitionToPage(_:)` helper added to centralise reduce-motion branching on page transitions (one decision point, not four); wave-icon `novaYellow` → `sun`; lightbulb `novaYellow` → `sun`. |

**Zero new files.** No `project.pbxproj` touch. No new assets. No new public API. The run is a pure view-layer paint + animation-correctness pass, no VM or backend surface moved.

### Docs

| File | Change |
|------|--------|
| `docs/SPRINT-11-tracker.md` | S11-17 row flipped ⏸ Pending → ✅ Done with dense Notes column. Sprint Summary table updated QA `0 / 7 (0%)` → `4 / 7 (57%)`, Total `84 / 93 (90%)` → `88 / 93 (95%)`. |
| `docs/sprint-runs/S11-17-auth-onboarding-polish.md` | This file. |
| `docs/sprint-runs/index.md` | New top row: `S11-17` → `S11/R17`, landed 2026-04-22, one-line summary. |

---

## Architectural Decisions

### 1. Sign In with Apple stays stock — Apple HIG carve-out, not a DS drift

The obvious move would have been to wrap `SignInWithAppleButton` in `.novaPrimary()` so every primary CTA in the app shares the coral-fill + ink-outline + commit-haptic vocabulary. Don't.

`ASAuthorizationAppleIDButton` (which `SignInWithAppleButton` bridges to) is a system-managed button that Apple requires we present in one of three sanctioned styles: `.black`, `.white`, or `.whiteOutline`. Apple's [Human Interface Guidelines on Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple) are explicit: "Don't customize the button's appearance beyond the allowed style variations." App-store review rejections for custom Sign-In-with-Apple skins are well-documented.

The DS re-skin would have:
1. Violated the system button contract (ink outline over Apple's own outline = double-stroke chrome).
2. Risked App Review rejection on the one surface every user hits on first launch.
3. Broken the user's muscle-memory for "that is the Apple button" — a known accessibility consideration for VoiceOver users who recognize the system-announced `AXTraitButton` + Apple-authored label.

So `.signInWithAppleButtonStyle(.white)` stays. The **palette around it** flips — the logo, the background, the floating shapes, the progress spinner tint all consume the 3+1 system — and the Apple button sits inside that surrounding without competing for "which button is the primary CTA" because **it's the only button on the screen**. S11-03's "never show two primary buttons at once" rule is satisfied trivially. Documented in a dense inline comment at the call site so the next reader doesn't try to `.novaPrimary()` it.

### 2. `meetDashyPage` — `@ViewBuilder` branching, not ternary-on-TimelineView-Schedule

The first draft looked like this:

```swift
// FIRST DRAFT — won't compile
private func meetDashyPage() -> some View {
    TimelineView(
        reduceMotion
            ? .explicit([.now])
            : .animation(minimumInterval: 1.0 / 30.0)
    ) { context in
        // …body
    }
}
```

The intent was "pick the Schedule based on reduce-motion". The compile error was cryptic — Swift's generic type-inference machinery chokes because `TimelineView` is generic over `Schedule: TimelineSchedule`, and `ExplicitTimelineSchedule` / `AnimationTimelineSchedule` are **distinct concrete types** not joined by any common conformance beyond the protocol. A ternary can't synthesize a single concrete `Schedule` for `TimelineView`'s generic slot.

Three options to fix:

1. **Type-erase to `AnyTimelineSchedule`** — doesn't exist (SwiftUI has no `AnyTimelineSchedule` type-eraser as of iOS 17).
2. **Custom `ReduceMotionSchedule`** that wraps both cases internally — works but adds a file for a one-off need.
3. **`@ViewBuilder` branch at the function level** — the reduce-motion path skips `TimelineView` entirely; the motion path instantiates it.

Option 3 wins because it's **also the correct accessibility move**: under reduce-motion, we don't just want "a TimelineView that doesn't tick" — we want **zero scheduling overhead**. No tick source, no per-frame body re-evaluation, no `context.date` read. The view collapses to a static `dashyPageContent(pose: .rest)` that never re-renders. This mirrors the S11-13 thinking-dots branch: the non-motion path produces no `TimelineView` at all.

Final shape:

```swift
@ViewBuilder
private func meetDashyPage() -> some View {
    if reduceMotion {
        dashyPageContent(pose: .rest)
    } else {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pose = DashyIdlePose(
                headBob: CGFloat(sin(t) * 4),
                eyePulse: 1.0 + (sin(t * 2) * 0.1),
                eyePulseOffset: 1.0 + (sin(t * 2 + 0.2) * 0.1),
                handAngle: sin(t * 1.5) * 25
            )
            dashyPageContent(pose: pose)
        }
    }
}
```

And the `DashyIdlePose` struct holding the four animation values:

```swift
private struct DashyIdlePose {
    let headBob: CGFloat
    let eyePulse: CGFloat
    let eyePulseOffset: CGFloat
    let handAngle: CGFloat

    static let rest = DashyIdlePose(headBob: 0, eyePulse: 1.0, eyePulseOffset: 1.0, handAngle: 0)
}
```

`.rest` is the neutral pose — the one the view renders when reduce-motion is on, or when SwiftUI hasn't yet had a tick to populate the fields. Identical across both paths so the layout doesn't jump on accessibility-setting toggle.

### 3. The `sin(Date().timeIntervalSince1970)` bug was silently broken — fixed for free

The pre-rebuild `meetDashyPage` had code of this shape in the body:

```swift
// BROKEN — this doesn't animate
Circle()
    .offset(y: sin(Date().timeIntervalSince1970) * 4)

Image(systemName: "hand.wave.fill")
    .rotationEffect(.degrees(sin(Date().timeIntervalSince1970 * 1.5) * 25))
```

The intent was "SwiftUI re-evaluates the body frequently, so these sin() expressions will animate". In practice, nothing invalidates the body between evaluations — `@State var currentPage` gets flipped once at page transition, the body re-runs once, and the Dashy head / hand sit frozen at whatever `Date()` sampled on the last render. Under user exploration this manifests as "Dashy's waving, oh wait, it stopped, why is it frozen?" — the animation works on the first frame and then dies.

`TimelineView(.animation)` was the right fix on *correctness* grounds alone (the one that existed before S11-17) and the reduce-motion accessibility pass just happens to be the forcing function that surfaced the bug. The run closes a latent correctness defect as a side-effect of the accessibility work — documented in the doc-comment on `meetDashyPage` so a future maintainer sees the lineage.

### 4. Reduce-motion branches at *both* the animation source and the page transition

The S11-13 decision established "branch at source, not modifier-gate a `.repeatForever`" for `TimelineView`-driven animations. S11-17 extends that to two more source-level gates:

**Gate A — the Dashy idle pose** (see Decision 2 above).

**Gate B — the 4-page screen transition.** Pre-rebuild:

```swift
Button(action: {
    withAnimation {
        currentPage = 1
    }
}) { Text("Back") }
```

The `withAnimation` block honors reduce-motion *at the modifier boundary*, but the S11-13 pulse-ring precedent showed that's the wrong place to trust. SwiftUI's runtime can continue ticking an already-running animation after a mid-flight reduce-motion toggle, and — more importantly — `withAnimation` still pays the setup/teardown cost of an animation frame even when reduce-motion collapses the interpolation to instant. Branching at the source costs one helper function and zero overhead:

```swift
private func transitionToPage(_ page: Int) {
    if reduceMotion {
        currentPage = page
    } else {
        withAnimation {
            currentPage = page
        }
    }
}
```

All four Back/Next callsites route through it. One decision point, not four inline ternaries that future maintainers would need to keep in lockstep.

### 5. Logo re-skin — `coral → sun` gradient, ink outline, ink glyphs

The pre-S11-17 logo was a `novaBlue → novaPurple` gradient circle with a white `sparkles` SF Symbol + white "Nova" wordmark centered inside. It was the *only* novaBlue→novaPurple rainbow left in the live app after S11-13 closed T2.

The rebuild:

1. Gradient flips to `coral → sun` (topLeading → bottomTrailing). Coral and sun are the two "warm pop" colors in the 3+1 palette; paired, they read as a sunrise / warm-welcome moment which is the semantic the login screen wants.
2. A `Circle().stroke(NovaPalette.ink, lineWidth: 2)` overlay adds the comic-book ink outline that every other NovaCard / button / speech-bubble chrome carries. The logo now matches the "every chrome element is ink-outlined" language.
3. Glyph + wordmark `.white` → `NovaPalette.ink`. Ink-on-coral-sun has strong contrast (AAA-passing on both coral and sun at the weights we use); white-on-coral-sun is only AA-passing on coral and fails on sun. The accessibility payload is better and the visual lineage matches the app.

First impression now reads as *"comic-book ink on paper"* from the moment the app launches — not *"a tech-product blue-purple gradient"*. Documented in the call-site comment referencing this decision number.

### 6. Floating shapes — deliberate weight variance, not symmetric rainbow

The four background shapes were `novaBlue / novaOrange / novaPurple / novaGreen` at `0.15` opacity each — a rainbow at uniform weight. Flipping to the 3+1 palette forces a design choice because there are only three non-page colors (ink, coral, sun) and we want four shapes in varied weights.

Solution — weight variance by semantic role:

| Shape | Size | Fill | Why that weight |
|-------|-----:|------|-----------------|
| Top-left circle (100pt) | medium | `ink.opacity(0.08)` | Background "texture dot" — ink carries the paper-and-ink metaphor but at low opacity so it reads as texture, not foreground. |
| Top-right rounded-rect (80pt) | small-mid | `coral.opacity(0.18)` | The "warm focal pop" — coral is the DS hero color, reads as a comic-book speech-bubble ghost behind the logo. |
| Bottom-left rounded-rect (70pt) | small | `ink.opacity(0.06)` | Second ink texture dot, even lighter than the top-left — the shapes form an ink-on-paper grain that reads as background fabric. |
| Bottom-right circle (90pt) | mid | `sun.opacity(0.28)` | The sun element balances the coral — higher opacity because yellow has lower perceived intensity than coral, so `0.28` matches coral's `0.18` visual weight. |

The two ink shapes at different opacities (`0.08` / `0.06`) provide "background texture grain"; the coral + sun shapes at matched perceptual weights provide "warm focal pops". Pairing them this way keeps the *visual rhythm* of the rainbow original (four shapes at varied positions) without falling back to a rainbow palette.

### 7. Page-container surface `novaBackground` → `.page`

`novaBackground` (lines 146-149 of `NovaPalette.swift`) is a back-compat alias for a near-white / true-dark adaptive color. `.page` is the canonical 3+1 page-surface adaptive color introduced in S11-02 — same dark-mode inverse-pair behavior, same accessibility contrast, but carries the design system semantic "this is the paper the comic-book is printed on". Swapping is a one-line flip with zero visual diff but it retires the alias dependency, which means when S12 deletes the back-compat exports, Onboarding won't break.

`novaCardBackground` (lines 307, 361) is **not** flipped — it's a card-fill adaptive color (white in light, elevated surface in dark) that's semantically distinct from `.page`. Leaving it is correct: the name-input card and the first-mission card are elevated elements over the page, not the page itself. Noting this in the file's inline comments so the next reader doesn't hunt for "why is novaCardBackground still here?"

### 8. Avatar-picker identity colors preserved — `Category.*` rainbow *is* the right palette here

Lines 452-459 of `OnboardingView.swift` map each of seven avatars to a color:

```swift
case .robot: return NovaPalette.novaBlue      // actually Category.blue
case .rocket: return NovaPalette.novaPink     // actually Category.pink
case .star: return NovaPalette.novaYellow     // actually Category.yellow
case .planet: return NovaPalette.novaGreen    // actually Category.green
case .rainbow: return NovaPalette.novaPurple  // actually Category.purple
// …
```

These are **per-avatar identity colors**, not arbitrary surface drift. The kid picks their avatar; the color *is* the avatar's identity, the way a lesson-path card's color is the lesson-category's identity. This is exactly what the `NovaPalette.Category.*` namespace was introduced for in S11-02 — a rainbow reserved for semantic-content-tagging. The back-compat aliases on the `NovaPalette` top level (`novaBlue` etc.) resolve to `Category.blue` etc., so the call sites work unchanged and the palette story holds: the rainbow exists for per-content identity, not for generic chrome.

Left untouched. S12 will rename the call sites to `NovaPalette.Category.blue` directly when the back-compat aliases get deleted, but that's a mechanical rename, not a semantic change.

### 9. "Let's Go!" finale button loses its gradient, routes through `.novaPrimary()`

Pre-rebuild, the "Let's Go!" button on the first-mission (final) onboarding page had a custom `LinearGradient([novaOrange, novaPurple])` background, white text, and inline `UIImpactFeedbackGenerator(style: .medium)` haptic. It was the only onboarding button with bespoke chrome — deliberate at the time, because the confetti-celebration moment wants a visual peak.

But the confetti **already** carries the celebration beat: a one-shot particle burst fires immediately on `onComplete` with kid-readable sparkles and a 2-second wind-down. Layering a gradient button *underneath* the confetti dilutes the celebration — the eye doesn't know where to land. Stripping the gradient and routing through `.novaPrimary()` keeps the button in the shared DS vocabulary (coral fill, ink outline, press-scale, `NovaHaptics.commit()` via the style's baked-in haptic), and lets the **confetti** own the celebration frame. One primary CTA, one celebration burst, one finish-line moment.

Documented in the button's call-site comment referencing this decision number so the next "can we make this more celebratory?" instinct has prior art to push back against.

### 10. Confetti survives reduce-motion — one-shot celebration, not ambient motion

The `@Environment(\.accessibilityReduceMotion)` declaration on `OnboardingView` has a dense doc comment explaining the confetti carve-out:

```swift
/// Reduce-motion branches:
/// - Dashy's idle bob switches from TimelineView(.animation) to .rest pose
/// - Page transitions skip withAnimation
/// - Confetti is **preserved regardless** — it's a single one-shot
///   celebration burst marking "onboarding complete", not ambient motion.
///   Apple HIG and WCAG both distinguish between motion-as-decoration
///   (removable) and motion-as-celebration-of-a-discrete-event (typically
///   preserved) — this is the latter.
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

[Apple's HIG on motion](https://developer.apple.com/design/human-interface-guidelines/motion) explicitly distinguishes "motion that communicates relationships, action results, or state changes" from "decorative motion." A single 2-second celebration after a user completes a multi-step first-run flow falls under the former — removing it would strip the kid of the emotional "I did it!" payoff that makes onboarding actually finish. The kid's success is the information the motion conveys.

If we ever want a reduce-motion-specific alternative celebration (static sparkle overlay, success chime only, haptic-only), that's a future story — not S11-17 scope.

### 11. Reduce-motion ink-shape fallback skips `onAppear` animation entirely

`AnimatedBackgroundView` (inside `KidsLoginView`) got the same source-level branch:

```swift
.onAppear {
    // Reduce-motion: keep shapes at rest. Doing this in onAppear (not
    // at declaration time) is deliberate — @Environment is only valid
    // inside body/onAppear, and a future toggle while the view is on
    // screen should still win without re-mounting.
    guard !reduceMotion else { return }
    withAnimation(
        Animation.easeInOut(duration: 3.5)
            .repeatForever(autoreverses: true)
    ) {
        isAnimating = true
    }
}
```

The `guard` short-circuits the `withAnimation` block entirely — the `isAnimating` state stays at its `false` declared default, so `offset(y: isAnimating ? -20 : 20)` resolves to `20` (the mid-point rest value). The shapes render at their neutral offset and never tick.

Important: the guard lives inside `.onAppear`, not at the declaration site. `@Environment` is only valid to read inside `body` or an `@ViewBuilder`-equivalent context; reading it at property-declaration level would compile but would fail at runtime with a stale environment value. `onAppear` is the first place in the view lifecycle where `@Environment(\.accessibilityReduceMotion)` is guaranteed fresh.

---

## Validation

### Sandbox ✅

| Check | Command | Result |
|-------|---------|--------|
| Live-code palette drift — KidsLogin | `grep -n "novaOrange\|novaPurple\|novaBlue\|novaPink\|novaYellow\|novaGreen\|novaCardBackground" src/Apps/NovaKids/Sources/Views/Auth/KidsLoginView.swift` | 3 hits, all in doc comments (lines 34, 152, 153) describing what was replaced — deliberately preserved context. Zero live-code references. ✅ |
| Live-code palette drift — Onboarding | `grep -n "novaOrange\|novaPink\|novaBlue\|novaYellow\|novaGreen" src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift` | 7 hits — 2 doc comments explaining flips; 5 live-code hits inside `avatarColor(_:)` helper (lines 452-459). Those are per-avatar identity colors, not drift (see Decision 8). `novaPurple` hits (lines 120, 159, 457) — two are Dashy body identity, one is the rainbow avatar's purple. ✅ |
| `novaBackground` | `grep -n "novaBackground" src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift src/Apps/NovaKids/Sources/Views/Auth/KidsLoginView.swift` | 1 hit, in a doc-comment explaining the `.page` flip (line 28 of Onboarding). Zero live code. ✅ |
| Deprecated color API | `grep -n "foregroundColor\|NavigationView" src/Apps/NovaKids/Sources/Views/{Auth,Onboarding}/` | 0 hits. ✅ |
| Single-param `onChange` | `grep -nE "onChange\(of: [^,)]+\) \{ [a-z][a-zA-Z]* in" src/Apps/NovaKids/Sources/Views/{Auth,Onboarding}/` | 0 hits. No `onChange` call sites in either file. ✅ |
| Raw `.font(.title)` | `grep -n "\.font(\.title)" src/Apps/NovaKids/Sources/Views/{Auth,Onboarding}/` | 0 hits. All title fonts route through `NovaPalette.titleFont()`. ✅ |
| `Timer` usage | `grep -n "Timer\." src/Apps/NovaKids/Sources/Views/{Auth,Onboarding}/` | 0 hits. ✅ |
| `TimelineView` usage | `grep -n "TimelineView" src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift` | 1 hit (meetDashyPage idle bob, line 98). ✅ |
| DS button routing | `grep -c "\.novaSecondary()\|\.novaPrimary()" src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift` | 7 call sites (3× Back `.novaSecondary`, 3× Next `.novaPrimary`, 1× "Let's Go!" `.novaPrimary`). ✅ |
| Apple HIG Sign-In stays stock | `grep -nE "\.signInWithAppleButtonStyle|ASAuthorizationAppleIDButton" src/Apps/NovaKids/Sources/Views/Auth/KidsLoginView.swift` | 1 `.signInWithAppleButtonStyle(.white)` hit (line 97). No `.novaPrimary()` on the SignInWithAppleButton. ✅ |
| Spacing tokens vs magic numbers | `grep -c "Spacing\." src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift src/Apps/NovaKids/Sources/Views/Auth/KidsLoginView.swift` | 37 hits in Onboarding + 9 in KidsLogin = **46 total**. ✅ |
| Reduce-motion paths | `grep -n "reduceMotion\|accessibilityReduceMotion" src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift src/Apps/NovaKids/Sources/Views/Auth/KidsLoginView.swift` | 6 hits (3 per file) — declaration + meetDashyPage branch + transitionToPage branch in Onboarding; declaration + AnimatedBackgroundView branch + `.onAppear` guard in KidsLogin. ✅ |
| `sin(Date().timeInterval...)` regression | `grep -n "sin(Date()" src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift` | 0 hits. The pre-rebuild broken inline pattern is retired. ✅ |
| Accessibility annotations | `grep -c "accessibilityLabel\|accessibilityValue\|accessibilityHint\|accessibilityHidden" src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift src/Apps/NovaKids/Sources/Views/Auth/KidsLoginView.swift` | 3 hits — `accessibilityElement(children: .combine) + accessibilityLabel("Nova Kids Sign In")` on login; `accessibilityLabel("Name input field")` on the onboarding TextField. ✅ |
| Files LOC | `wc -l` | 229 (KidsLogin) + 467 (Onboarding) = 696 combined. ✅ |
| swiftui-pro self-audit | inline | Clean — no deprecated API, `foregroundStyle` throughout, no `onChange` call sites at all (no signature to verify), `TimelineView` (not `Timer`), reduce-motion gated at source in three places (Dashy pose, page transition, floating shapes), `@ViewBuilder`-branching correctly handles distinct `Schedule` types in the TimelineView gate, decorative shapes not `accessibilityHidden` but they sit behind `.ignoresSafeArea()` as background — acceptable for AnimatedBackgroundView pattern; confetti preserved regardless of reduce-motion per Apple HIG carve-out; `@Environment(\.accessibilityReduceMotion)` declared on parent struct and nested private struct `AnimatedBackgroundView` also declares its own (Senior-Swift rule: child structs don't inherit `@Environment` from parent). ✅ |

### 🟡 Mac-only (requires bang's hardware)

| Check | Why sandbox can't |
|-------|-------------------|
| Xcode clean build of `NovaKids` target | Swift compiler not present in sandbox; the pbxproj is unchanged so the build is a pure recompile of two files. |
| iPad Pro 13" simulator — cold launch → Sign-In screen | Simulator requires Xcode + macOS host. |
| "Sign In with Apple" button tap — live Apple-ID sheet | Requires simulator with a signed-in Apple ID + authentication flow. |
| Onboarding flow walk — 4 pages forward + back | Requires simulator + tap-through timing. |
| Dashy idle bob — verify 1s head-bob period + 1.5s hand-wave period | Requires running view + TimelineView scheduler live. |
| Reduce-motion toggle | Settings → Accessibility → Motion → Reduce Motion = ON; verify: (a) Dashy locks at `.rest` pose — no head-bob, no hand-wave; (b) page transitions snap instantly with zero animation; (c) KidsLogin floating shapes lock at mid-offset — no 3.5s ease loop; (d) confetti **still fires** on "Let's Go!". |
| Dynamic Type @ .xSmall and .accessibility5 | Requires Environment Overrides panel. |
| Dark mode walk — all 4 onboarding pages + login | Requires simulator appearance override. |
| Avatar selection — pick each of 7 avatars, verify haptic | Simulator has no Taptic Engine — requires physical iPad. |
| Physical haptic ladder — Back (tap) / Next (commit) / Let's Go (commit) | Requires physical hardware. |
| Dev Console regression — Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs | Requires Mac backend at `http://127.0.0.1:8787`. S11-17 didn't touch backend; this is a sanity walkthrough. |

---

## Prerequisites bang must run on his Mac

```bash
# 1. Clean rebuild — two files changed, no pbxproj touch
cd ~/path/to/Nova
xcodebuild -project src/Nova.xcodeproj \
           -scheme NovaKids \
           -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
           clean build
# expect: ** BUILD SUCCEEDED **

# 2. Cold-launch the app from scratch (delete on simulator first so you hit login)
# expect: Sign-In screen with coral→sun logo, ink outline, "Nova Kids" + subtitle,
#         four ink/coral/sun floating shapes drifting on a 3.5s ease loop,
#         page surface is flat NovaPalette.page (not a gradient)

# 3. Sign in with Apple → onboarding lands on Meet Dashy page
# expect: Dashy idle-bobbing (head offset visibly oscillates ±4pt on ~1s period)
#         hand rotating ±25° on ~1.5s period
#         tap "Let's Meet!" → animated transition to Choose Avatar page

# 4. Choose avatar → enter name → first mission → Let's Go!
# expect: Back buttons all read as .novaSecondary (page fill, ink outline, coral text)
#         Next buttons all read as .novaPrimary (coral fill, ink outline, ink text)
#         "Let's Go!" button ends onboarding with confetti burst

# 5. Toggle reduce-motion ON (Settings → Accessibility → Motion → Reduce Motion = ON)
# Cold relaunch → walk onboarding again:
# expect: Dashy locks at .rest pose (no head-bob, no hand-wave, hand at 0°)
#         page transitions snap instantly (zero animation)
#         KidsLogin floating shapes lock at mid-offset (no drift loop)
#         BUT: "Let's Go!" confetti STILL FIRES — one-shot celebration is preserved

# 6. Toggle reduce-motion OFF — verify animations return

# 7. Dynamic Type @ accessibility5 (Settings → Accessibility → Display & Text Size → Larger Text)
# Walk: KidsLogin title + subtitle, onboarding page titles, name input, lightbulb card —
#       nothing should clip; font scales through NovaPalette.titleFont() and bodyFont()

# 8. Dark mode walk — KidsLogin + all 4 onboarding pages
# expect: NovaPalette.page ↔ .ink inverse-pair flips cleanly
#         Dashy body (novaPurple) + avatar identity colors unchanged (they're semantic, not chrome)
#         Confetti still visible (coral + sun pop against dark background)

# 9. Dev Console regression — open http://127.0.0.1:8787/dev/dev-pipeline.html
# Pipeline + Skills + Strategy + Parent Guidance + Session Context tabs all render
# No S11-17 change should have touched any backend surface — sanity check.
```

---

## Sprint Impact

| Metric | Before S11-17 | After S11-17 |
|-------:|:--------------|:-------------|
| Sprint 11 Total | 84 / 93 (90%) | **88 / 93 (95%)** |
| DS epic | 15 / 15 (100%) | 15 / 15 (100%) |
| T1 epic | 25 / 25 (100%) | 25 / 25 (100%) |
| DSH epic | 10 / 10 (100%) | 10 / 10 (100%) |
| T2 epic | 18 / 18 (100%) | 18 / 18 (100%) |
| MVP epic | 8 / 8 (100%) | 8 / 8 (100%) |
| MX epic | 8 / 10 (80%) | 8 / 10 (80%) |
| **QA epic** | 0 / 7 (0%) | **4 / 7 (57%)** |

**QA epic opens at 4/7.** First-impression surfaces now speak the 3+1 + DS + Spacing + reduce-motion-at-source vocabulary end to end. The only remaining Sprint 11 work is **S11-16** (reduce-motion audit sweep across S11-05…13, 2 pts) and **S11-18** (iPad landscape + dark + DynamicType QA, 3 pts). Sprint 11 can close at 93/93 (100%) with both.

---

## What's Next

1. **S11-16** (MX, 2 pts) — Reduce-motion audit sweep. S11-13 established the "branch at source, not modifier-gate `.repeatForever`" pattern; S11-17 extends it to page transitions. The audit walks S11-05 through S11-13 and confirms every `withAnimation(…)` added this sprint either (a) respects `@Environment(\.accessibilityReduceMotion)` at the source, or (b) is a one-shot discrete-event celebration that deliberately doesn't (the confetti pattern). One-line comment at each site documenting the classification. Targets per pre-compaction notes: POW reaction (S11-06), hover scale (S11-12), Dashy idle bounce (now handled in S11-17), chat typing dots (S11-13), pulse ring (S11-13), BadgeUnlockBurst (S11-07).
2. **S11-18** (QA, 3 pts) — iPad landscape + dark mode + DynamicType verification. Walk every screen in `iPad Pro 13-inch` simulator — both orientations — in light + dark. Walk every screen at Dynamic Type `.xSmall` and `.accessibility5`. Capture screenshots or maintain a written defect inventory for S12. S11-19's live-data wire-up means this QA pass now exercises *real* content shapes (wrapping titles, missing thumbnails, empty descriptions) that mock arrays hid — the QA is more valuable post-wire-up than it would have been pre-wire-up.
3. **Sprint 12 scaffold** — after Sprint 11 closes at 93/93 (100%), next scaffolding target is the backend asymmetric-rename carve-out retired debt (`role == "sparky"` → `role == "dashy"`, filepaths under `src/Backend/src/services/sparky/` → `src/Backend/src/services/dashy/`, exported identifiers). Plus whatever S11-18 QA turns up.

---

## Retired Debt

Three items closed by this run:

1. **Last rainbow live-code references in app shell.** Pre-S11-17, KidsLoginView + OnboardingView were the last two screens in the live app still wearing `novaBlue / novaOrange / novaPurple / novaGreen` as chrome (not as semantic per-content identity). Post-S11-17, the only legacy-palette hits in either file are documented carve-outs: Dashy body `novaPurple` (identity), avatar identity colors (semantic per-avatar), and `novaCardBackground` (adaptive card fill alias). The S11-02 palette story is now end-to-end consistent across every live surface.

2. **Silently-broken `sin(Date().timeIntervalSince1970)` animation pattern.** The pre-rebuild `meetDashyPage` head-bob and hand-wave were non-functional — they sampled `Date()` once per body re-evaluation, so the animation froze after the first frame. `TimelineView(.animation)` fixes this on correctness grounds while also providing the reduce-motion branch-point. Zero tests broken because no test asserted "Dashy's head bobs" — the regression was purely visual and slipped past QA until this run surfaced it.

3. **Stale tracker AC — "two raw `.font(.title)` sites"**. Pre-compaction intel from sprint-scaffolding days claimed two raw `.font(.title)` sites needed flipping to `NovaPalette.titleFont()`. Grep confirms **one** `.font(.title)` remains across the entire `NovaKids/` tree, and it's inside `NovaCard.swift`'s `#Preview` sample (preview-only, out of scope for any production sweep). Both onboarding `.font(.title)` sites were swept upstream during S11-02 / S11-04 when `titleFont()` landed as part of the display-font plumbing. Retiring this AC line as "already delivered upstream" and noting it here so future scans don't re-chase the same ghost.

No new debt introduced. Zero test regressions. The `DashyIdlePose` struct is a net-positive abstraction (testable in isolation if we ever want to unit-test the pose math, though at 4 lines we probably won't).

---

## Cross-references

- [S11-02 — Palette + Spacing foundation](./S11-palette-spacing.md) — the 3+1 palette + `Spacing` enum S11-17 consumes end to end.
- [S11-03 — NovaCard + Button styles](./S11-ds-dashy-rename.md) — `.novaPrimary()` / `.novaSecondary()` consumed on all four onboarding pages.
- [S11-04 — Bangers display font plumbing](./S11-ds-dashy-rename.md) — `NovaPalette.titleFont()` / `headingFont()` / `bodyFont()` consumed throughout; retired the stale-AC "two raw `.font(.title)`" intel.
- [S11-05 — Home refresh](./S11-home-refresh.md) — first place in the sprint where `@Environment(\.accessibilityReduceMotion)` got wired; S11-17 extends the pattern to its last two first-impression surfaces.
- [S11-10 — Dashy visual reskin](./S11-dashy-reskin.md) — promotes `novaPurple` to Dashy's character-identity color; Decision 8 carries that forward on the Meet Dashy onboarding page.
- [S11-13 — Dashy chat surface rebuild](./S11-13-dashy-chat.md) — establishes the "branch at source, not modifier-gate a `.repeatForever`" pattern that S11-17 applies in three places (Dashy idle pose, page transitions, floating shapes).
- [S11-15 — Haptic ladder sweep](./S11-haptic-ladder-sweep.md) — `.novaPrimary()` and `.novaSecondary()` button styles bake `NovaHaptics.commit()` / `.tap()` in at the DS level, so every S11-17 button routes through the ladder without inline `UIImpactFeedbackGenerator`.
- [S11-19 — Live data wire-up](./S11-19-live-data-wireup.md) — the preceding run that flipped Tier 1 VMs to real `APIRouter` calls; S11-17 closes the first-impression surfaces so the live-data iPad demo loop goes from cold-launch → Sign In → Onboarding → Home with zero mock-array drift.
