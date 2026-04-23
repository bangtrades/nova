# S11-13 — Dashy chat surface rebuild

**Run ID:** S11/R13
**Parent sprint:** [SPRINT-11](../SPRINT-11-tracker.md) — "Comic-Book Polish"
**Stories landed:** S11-13 (T2, 7 pts)
**Run window:** 2026-04-22 (single session)
**Landed:** 2026-04-22
**Status:** ✅ Delivered
**Delivery agents:** /senior-fullstack + /senior-swift + /swiftui-pro + /jira-expert
**Sprint progress after this run:** 76 / 85 pts (89%) — T2 epic **100%**

---

## Run Goal

Close the last-but-one T2 story by rebuilding `DashyView` on the Sprint 11 design system — DS type scale in the header, session-time progress bar, coral-vs-paper-and-ink chat bubbles, `.novaSecondary()` on every pill, reduce-motion-gated thinking dots + talk-button pulse. Leave the VM contract untouched so the rebuild is a pure view-layer paint pass and no parent composition root needs to change.

This is the Dashy surface's *third* landing in Sprint 11. S11-09 renamed the iOS class set Sparky → Dashy (with an asymmetric rename carve-out for backend filepaths + wire-protocol labels deferred to S12). S11-10 reskinned the character + built `DashySpeechBubble` + wired it into the dialogue call sites. S11-13 is the chat-surface chrome pass — the one remaining place where the pre-3+1 palette (novaOrange accents, novaPurple gradient, novaBlue child bubbles) was still visible because it's the most opinionated Tier-2 surface. After this run, **every live-code path in `Views/Dashy/` consumes exclusively the 3+1 palette + category rainbow + DS primitives.**

---

## Stories & Acceptance Criteria

| ID | Story | AC → Outcome |
|----|-------|----------|
| S11-13 | Dashy chat surface | ✅ All 5 AC landed — chat bubbles with sun-on-ink Dashy / coral child; `.novaSecondary()` on suggestion + starter pills; session-time progress bar at top (ink-outlined page rail + coral fill); typing animation preserved and reduce-motion swap to static "…"; ink + coral + sun palette only. |

Deviation from spec: the spec called for a "sun-filled bubble with ink stroke + tail" for Dashy's side. We already landed that in S11-10 via `DashySpeechBubble` (page fill, ink stroke, leading tail — the paper-and-ink speech-bubble idiom). Swapping Dashy's side to sun fill would have been a regression against the S11-10 design pass; kept the S11-10 chrome and instead flipped the child side from `novaBlue` to coral to carry the "child's turn / child's pick" semantic from S11-06 + S11-12. Documented in Decision 3 below.

---

## Files Changed

### Sources

| File | Δ LOC | Change |
|------|------:|--------|
| `src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | +197 / -0 overwrite (397 → 594) | Full rebuild — header + session bar + chat bubbles + thinking dots + suggestions + starters + error card + input bar + talk button. VM contract preserved byte-for-byte. |

**Zero new files.** No `project.pbxproj` touch. No new assets. No new public API. `DashyViewModel.swift`, `DashyCharacterView.swift`, `DashySpeechBubble.swift`, `DashyHintSheet.swift`, `DashyHintButton.swift`, `DashyOfflineView.swift` — all untouched.

### Docs

| File | Change |
|------|--------|
| `docs/SPRINT-11-tracker.md` | S11-13 row flipped ⏸ Pending → ✅ Done with dense Notes column. Sprint Summary table updated T2 `11 / 18 (61%)` → `18 / 18 (100%)`, Total `69 / 85 (81%)` → `76 / 85 (89%)`. Delivery Notes section appended (10 numbered architectural decisions + Validation matrix + 10-step Mac runbook). |
| `docs/sprint-runs/S11-13-dashy-chat.md` | This file. |
| `docs/sprint-runs/index.md` | New top row: `S11-13` → `S11/R13`, landed 2026-04-22, one-line summary. |

---

## Architectural Decisions

### 1. `TimelineView(.periodic)` as the sole time source — `Timer` forbidden

Three independently-ticking visuals live on the rebuilt surface:

- **Session-time progress bar** — ticks every 1s (5s under reduce-motion) to refresh the coral fill width against a 20-minute window.
- **Thinking indicator** — ticks every 0.3s to rotate which of the three dots is at full opacity.
- **Listening pulse ring** — ticks every 1/30s (~30fps) to interpolate scale + opacity via a sin-phase function.

Every previous incarnation of these animations wrapped them in `Timer.scheduledTimer(...)` callbacks firing into `@State` mirror variables. Under Swift 6 strict concurrency, the Timer callback runs in a non-isolated context, so writing to `@State` (which is `@MainActor` via the view's actor inheritance) requires `Task { @MainActor in … }` hops inside the callback. That works, but it:

1. Stores ticking state that needs lifecycle management (`.onAppear` → start timer, `.onDisappear` → invalidate, weak-self dance).
2. Crosses the `@MainActor` boundary once per tick for every animation, compounding on a surface with three concurrent ticking visuals.
3. Serializes the animation cadence through `@State` change propagation, which is reactive but not guaranteed per-tick.

`TimelineView(.periodic(from:by:))` hoists the time source **out** of the view's `@State` entirely. The schedule generates dates on its own cadence; the view's closure re-renders with a fresh `context.date` each time; stateless helpers like `elapsedFraction(at:)` derive the current visual value from that date without touching `@State`. Zero actor crossings, zero Timer lifecycle, zero mirrored state. Chose this over `Timer.publish(every:on:in:).autoconnect() + .onReceive(...)` because Combine still requires a `@State` mirror to expose the tick into the view; `TimelineView` skips the mirror entirely.

### 2. Session-time bar is a visual nudge, not an enforced cap

The bar fills from 0% to 100% over 20 minutes hardcoded in `Self.sessionWindowSeconds = 20 * 60`. No VM change, no backend hookup to parent-guidance session-length limits (that would couple a UI-polish sprint to a backend config surface S12+ owns). The `elapsedFraction(at:)` helper clamps at 1.0 so the bar can't overshoot past the edge of its rail; nothing downstream of `fraction >= 1.0` fires. Chose 20 minutes as a commonly-cited "one focused chat session" ceiling for the target K-5 age band.

Start time is captured lazily in `.onAppear` guarded on `sessionStartedAt == nil`:

```swift
.onAppear {
    if sessionStartedAt == nil {
        sessionStartedAt = Date()
    }
}
```

This is idempotent across tab re-selections without unmount — the kid tapping Dashy → Home → Dashy sees the bar still reflect their total session time, not a reset. A full app relaunch clears the state and the bar starts fresh on next `.onAppear`. Chose this over a `.task` because `.task` would re-fire on identity change and muddy the idempotence intent; `.onAppear` + nil-check is the simplest possible expression.

### 3. Child bubble coral, not novaBlue — carrying the S11-06 / S11-12 semantic forward

The S11-10 reskin left the child side of the chat surface on `novaBlue`, which was the ambient "user's voice" color from the pre-3+1 era. But S11-06 (quiz answer chip: coral = "the one the child picked") and S11-12 (path filter pill: coral = "the active filter the child selected") both established **coral = the child's pick / the child's turn** as a consistent cross-surface semantic during T2.

Keeping novaBlue on the chat surface would have left it as the last place in the app where "I'm the child and I did a thing" reads as blue instead of coral. The fix is a 4-line paint change in `childBubble(_:)`:

```swift
Text(message.content)
    .font(NovaPalette.bodyFont())
    .foregroundStyle(NovaPalette.page)
    .padding(.horizontal, Spacing.md)
    .padding(.vertical, Spacing.sm + Spacing.xs)
    .background(NovaPalette.coral, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(NovaPalette.ink, lineWidth: 2))
```

Dashy's side stays on the S11-10 `DashySpeechBubble` — page fill, ink stroke, leading tail — because:

- The **speech-bubble-tail** idiom is a comic-world affordance reserved for the character's voice. A tail on the child's side would muddle whose speech is whose.
- Dashy is the **paper-and-ink persona** (it's the comic-book page's voice); the child is **the coral actor** (the kid driving the interaction). Two distinct chrome languages, one per role, consistent across the app.

### 4. `.novaSecondary()` on every suggestion + starter pill — zero bespoke chrome

Pre-rebuild, the suggestion pills had a `novaOrange` arrow accent and the starter-prompt list sat on a `novaOrange → novaPurple` LinearGradient. Historic rationale: "Dashy surface is its own visual dialect, signal it." But by S11-12 the Lessons filter pills were on DS secondary styling, and by S11-14 the Flipbook nav buttons were on DS secondary styling — the chat surface was the last holdout on a different pill shape + haptic + press animation.

Routing both lists through `.novaSecondary()` (from `NovaButtonStyles.swift`) gives every pill the same 16pt corner radius, 2pt ink stroke, 0.96 press scale, and `NovaHaptics.tap()` haptic. The child learns **one** affordance for "Dashy is offering me a tap target" — and it's the same one Lessons and Flipbook and Quiz all use.

The `arrow.right` trailing glyph is kept on `suggestionList` because that list populates the input field (semantically: "tap → fill in for me") — the arrow reinforces the direction-of-intent. The `starterPromptList` drops the arrow because those prompts *are* the send action (tap → send immediately), and a trailing arrow would suggest "and then you'll edit this" which is the wrong affordance.

Grep-verified: zero live-code references to `novaOrange` / `novaPurple` / `novaBlue` / `novaPink` / `novaYellow` / `novaCardBackground` in `DashyView.swift`. The two remaining mentions are both in the file's doc-comment header (lines 15, 22) describing what was replaced — deliberately kept so the "why does this file say novaBlue?" context survives for the next reader.

### 5. Reduce-motion branching at source, not at modifier

The pre-rebuild thinking indicator used `withAnimation(.linear(duration:).repeatForever(autoreverses:))` on a `TimerPublisher`-driven phase variable. `withAnimation` respects `@Environment(\.accessibilityReduceMotion)`, **but** `.repeatForever` animations that are already running don't kill themselves when the environment flips to reduce-motion — they keep ticking silently until the view unmounts. That's a subtle accessibility bug: the user turns on reduce-motion expecting motion to stop, and the thinking dots keep cycling.

The rebuild branches at the source — two completely different render paths:

```swift
if reduceMotion {
    HStack(spacing: Spacing.xs) {
        ForEach(0..<3, id: \.self) { _ in
            Circle().fill(NovaPalette.coral).frame(width: 8, height: 8)
        }
    }
} else {
    TimelineView(.periodic(from: .now, by: 0.3)) { context in
        let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.3) % 3
        // …opacity-dim non-phase dots
    }
}
```

The non-motion branch produces no `TimelineView` at all — zero scheduling overhead, zero view invalidation cost. Three static fully-opaque coral circles of identical visual weight. The "Dashy is thinking…" caption is unconditional under both paths so a VoiceOver user hears a consistent announcement regardless of motion setting.

### 6. Pulse ring must be inside its own `TimelineView` — bare computed properties don't animate

The first draft of the talk button computed `pulseScale` and `pulseOpacity` as view-local `let`s off `Date().timeIntervalSinceReferenceDate`:

```swift
// FIRST DRAFT — broken
private var pulseScale: CGFloat {
    let t = Date().timeIntervalSinceReferenceDate
    return 1.0 + (sin(t * 2 * .pi / 1.2) + 1) / 2 * 0.04
}
```

The intent was "SwiftUI will re-read these every body evaluation, so the pulse animates". In practice, nothing invalidated the view between evaluations — `@State var isListening` gets flipped once at the state transition, the body re-runs once, and the pulse sits frozen at whatever time it sampled on the last render.

The fix wraps the pulse ring in an inner `TimelineView(.periodic(from: .now, by: 1.0/30.0))` at 30fps:

```swift
TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
    let phase = (sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.2) + 1) / 2
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(NovaPalette.ink.opacity(0.4), lineWidth: 2)
        .scaleEffect(1.0 + CGFloat(phase) * 0.04)
        .opacity(0.3 + phase * 0.5)
}
```

The `TimelineView` closure is the thing SwiftUI re-renders per tick — the phase is freshly computed from `context.date` each time, and the scale/opacity are interpolated as expected. 30fps (33ms period) is the sweet spot: 60fps is needlessly expensive for a simple breathing effect; 15fps feels juddery. `pulseScale` and `pulseOpacity` helpers deleted — the computation lives in the closure where it belongs.

**Triple-gating is load-bearing:**
```swift
if viewModel.state == .listening && !reduceMotion {
    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { … }
}
```

The `TimelineView` is only *instantiated* when the pulse is actually visible. In ready / processing / responding / error states, zero scheduling cost. Under reduce-motion, zero scheduling cost. The button body itself lives outside the gate so the coral↔sun fill swap happens instantly on state transition without paying the pulse-ring ticking overhead to get there.

### 7. Talk-button fill is a one-step swap, not a gradient

Ready state = coral fill, ink outline, ink text + `mic` glyph. Listening state = sun fill, same ink outline, same ink text + `mic.fill` glyph. Two binary state changes:

1. **Fill color** — coral → sun (one-step swap via a ternary in `.background(_ :in:)`).
2. **Glyph fill** — `mic` → `mic.fill` (SF Symbol variant swap via a ternary in `Image(systemName:)`).

One-step means the state-change reads as "the state just changed" without asking the kid to parse a gradient transition or a color interpolation. The two changes are redundant — color + glyph fill — so if a child with reduced color perception misses the hue swap, the filled-vs-outlined glyph carries the same signal. Matches the S11-06 quiz-answer evaluate pattern (selected → coral fill + glyph swap; correct → green fill + checkmark; wrong → orange fill + x-mark).

### 8. Error-card chrome inlined, not wrapped in `NovaCard`

`NovaCard` has a mandatory 6pt leading accent stripe. On the error card, that would claim the stripe slot for "error semantics", but then the coral `exclamationmark.circle.fill` glyph *also* claims "error semantics", and the two compete for the visual "this is the error signal" role. Inlined chrome — page fill + 20pt rounded rect + 2pt ink stroke — keeps the card chrome minimal so the coral icon + body text + `.novaPrimary()` "Try Again" button each carry their own weight without fighting a stripe that's saying the same thing.

The "Try Again" is **primary**, not secondary, because on an error card it's the single meaningful action — S11-03's rule ("a screen should never show two primary buttons at once") is satisfied because there's only one button at all, and the primary CTA is correctly the strongest affordance on the card.

### 9. Asymmetric rename carve-out preserved — `role == "sparky"` stays

The `chatBubble(_:)` helper at line 220 still compares against the string literal `"sparky"`:

```swift
private func chatBubble(_ message: ChatMessage) -> some View {
    HStack(spacing: Spacing.sm) {
        // Wire-protocol literal "sparky" — S12 rename will flip this to "dashy"
        // once the backend catches up. See S11-09 delivery note.
        if message.role == "sparky" {
            dashyBubble(message: message)
        } else {
            childBubble(message: message)
        }
    }
    .padding(.horizontal, Spacing.lg)
}
```

Backend services under `src/Backend/src/services/sparky/` still emit `role: "sparky"` on the wire; the filepath + exported identifiers (`SPARKY_SYSTEM_PROMPT`, `SparkyResponse`, `processSparkyMessage`) flip in S12. The doc-comment header at the head of `DashyView` repeats the S11-09 carve-out note so any future contributor opening the file encounters the "why is this still saying sparky?" answer in the first 30 lines — not buried in a sprint tracker.

Grep-safe: the only live-code `sparky` reference in this file is the literal + its doc-comment callout.

### 10. VM contract preserved byte-for-byte — pure view-layer rebuild

Zero changes to `DashyViewModel.swift`. Every `@Published` property (`state`, `conversationHistory`, `currentEmotion`, `suggestions`, `errorMessage`, `processingProgress`) is consumed as before. Every method the rebuild touches (`viewModel.sendMessage(text:)`, `viewModel.startListening()`, `viewModel.stopListening()`, `viewModel.clearHistory()`) already existed pre-rebuild — zero new signatures, zero modified method bodies.

The private `EmptyTokenProvider` class + the placeholder `init()` for transient-init paths that bypass DI are preserved untouched — the `#Preview` + any harness that constructs a `DashyView()` without the full parent composition root still compiles.

This keeps the rebuild a pure view-layer change. The parent `NovaKidsApp` composition root doesn't need to change. The tab-container holding `DashyView` doesn't need to change. The run is a paint pass, nothing more.

---

## Validation

### Sandbox ✅

| Check | Command | Result |
|-------|---------|--------|
| Live-code palette drift | `grep -n "novaOrange\|novaPurple\|novaBlue\|novaPink\|novaYellow\|novaCardBackground" src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | 2 hits, both doc-comment (lines 15, 22). Zero live-code references. ✅ |
| Deprecated color API | `grep -n "foregroundColor\|NavigationView" src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | 0 hits. ✅ |
| Single-param `onChange` | `grep -n "onChange(of: [^,)]\+) { [a-z][a-zA-Z]* in" src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | 0 hits — both `.onChange` sites use the iOS 17+ two-param signature. ✅ |
| `Timer` usage | `grep -n "Timer\." src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | 0 hits. ✅ |
| `TimelineView` usage | `grep -n "TimelineView" src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | 3 hits (session bar 177, thinking indicator 307, pulse ring 493). ✅ |
| DS button routing | `grep -c "\.novaSecondary()\|\.novaPrimary()" src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | 3 call sites. ✅ |
| Spacing tokens vs magic numbers | `grep -c "Spacing\." src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | ~35 hits. ✅ |
| Reduce-motion paths | `grep -n "reduceMotion\|accessibilityReduceMotion" src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | 5 hits (declaration + 3 branches + one cadence ternary). ✅ |
| Accessibility annotations | `grep -c "accessibilityLabel\|accessibilityValue\|accessibilityHint\|accessibilityHidden" src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | 8 hits. ✅ |
| File LOC | `wc -l` | 594. ✅ |
| swiftui-pro self-audit | inline | Clean — no deprecated API, `foregroundStyle` throughout, two-param `onChange`, `NavigationStack`, `TimelineView` (not `Timer`), reduce-motion gated at source, decorative shapes `accessibilityHidden`, no force-unwrapping, no `@MainActor` boundary crossings, `@Environment(\.accessibilityReduceMotion)` on parent struct (child `private var` computed properties inherit — no extracted-struct violations), `.onDisappear { celebrationTask?.cancel() }` preserved. ✅ |

### 🟡 Mac-only (requires bang's hardware)

| Check | Why sandbox can't |
|-------|-------------------|
| Xcode clean build of `NovaKids` target | Swift compiler not present in sandbox; the pbxproj is unchanged so the build is a pure recompile of one file. |
| iPad Pro 13" simulator walk — light + dark | Simulator requires Xcode + macOS host. |
| Session-time bar 1-minute fill verification | Requires a running view and 60s of wall-clock time. |
| Pulse-ring 30fps breathing animation | Requires a running view + VoiceOver-off + reduce-motion-off state. |
| Reduce-motion toggle in Settings → Accessibility → Motion | Requires simulator or device. |
| Dynamic Type @ .xSmall and .accessibility5 | Requires Environment Overrides panel. |
| Dev Console regression check | Requires Mac backend running at `http://127.0.0.1:8787`. |
| Physical haptic feedback on `.novaSecondary()` pills | Requires physical hardware — simulator has no Taptic Engine. |

---

## Prerequisites bang must run on his Mac

```bash
# 1. Clean rebuild — one file changed, no pbxproj touch
cd ~/path/to/Nova
xcodebuild -project src/Apps/NovaKids/Nova.xcodeproj \
           -scheme NovaKids \
           -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
           clean build
# expect: ** BUILD SUCCEEDED **

# 2. Launch Dashy tab cold and leave open for 60s — watch the session bar fill
# Open app → Dashy tab → wait 60s → bar should be visibly >0%, <10% (60/1200 = 5%)

# 3. Send a starter prompt — verify coral child bubble vs paper-and-ink Dashy
# Tap "What is AI?" → child bubble renders trailing, coral fill, ink stroke, page text
# Dashy reply renders leading with sun-avatar + DashySpeechBubble (page fill, ink tail)

# 4. Toggle reduce-motion ON (Settings → Accessibility → Motion → Reduce Motion = ON)
# Reload Dashy → thinking dots render as three static coral circles, no cycle
# Reload Dashy → talk-button pulse ring is absent during listening state

# 5. Toggle reduce-motion OFF — pulse ring should visibly breathe at ~1.2s period
# Tap "Talk to Dashy" → ring scales 1.00 → 1.04 → 1.00, opacity 0.3 → 0.8 → 0.3

# 6. Dynamic Type @ accessibility5 (Settings → Accessibility → Display & Text Size → Larger Text)
# Walk: chat bubbles wrap vertically, talk-button text scales within 64pt frame,
# session bar stays at 4pt height (affordance, not text).

# 7. Dark mode walk — ink ↔ page inverse-pair flips bubbles + rail + input + error card
# Everything still reads; Dashy character unchanged (S11-10 was mode-stable)

# 8. Dev Console regression — open http://127.0.0.1:8787/dev/dev-pipeline.html
# Pipeline + Skills + Strategy + Parent Guidance + Session Context tabs all render
# No S11-13 change should have touched the backend surface; this is a sanity check
```

---

## Sprint Impact

| Metric | Before S11-13 | After S11-13 |
|-------:|:--------------|:-------------|
| Sprint 11 Total | 69 / 85 (81%) | **76 / 85 (89%)** |
| T1 epic | 25 / 25 (100%) | 25 / 25 (100%) |
| **T2 epic** | 11 / 18 (61%) | **18 / 18 (100%)** |
| DSH epic | 10 / 10 (100%) | 10 / 10 (100%) |
| DS epic | 15 / 15 (100%) | 15 / 15 (100%) |
| MX epic | 8 / 10 (80%) | 8 / 10 (80%) |
| QA epic | 0 / 7 (0%) | 0 / 7 (0%) |

**T2 epic closes at 18/18.** Every Tier-2 surface (Flipbook chrome, Lessons grid, Dashy chat) now speaks the 3+1 palette + DS primitives + `.novaSecondary()` / `.novaPrimary()` button language. The only remaining Sprint 11 work is the **QA epic (S11-17 + S11-16 + S11-18)** plus the S11-16 carry from MX — reduce-motion audit + auth/onboarding spacing + iPad landscape/dark-mode/DynamicType QA.

---

## What's Next

1. **S11-17** (QA, 4 pts) — Auth login tighten + Onboarding spacing. Login's floating-shapes animation needs to move to the 3+1 palette (ink shapes over page, not rainbow); button styling via `.novaPrimary()`; onboarding avatar grid uses `Spacing.md` consistently; the two raw `.font(.title)` sites already swept by S11-02 — verify; Dashy's onboarding intro animates with reduce-motion fallback.
2. **S11-16** (MX, 2 pts) — Reduce-motion audit across all new S11-05…13 animations. S11-13 establishes the "branch at source, not modifier-gate a `.repeatForever`" pattern — the audit will confirm every `withAnimation(…)` added during Sprint 11 respects `@Environment(\.accessibilityReduceMotion)` and adds a one-line comment at each site documenting the reduce-motion behavior.
3. **S11-18** (QA, 3 pts) — iPad landscape + dark mode + DynamicType verification. Capture screenshots of every screen in iPad Pro 13" both orientations, light + dark, `.xSmall` and `.accessibility5`. File defect inventory for S12 — goal is zero-surprises, not zero-defects.

---

## Retired Debt

None directly retired in this run — the S11-13 rebuild consumes primitives already landed (`DashySpeechBubble` S11-10, `.novaSecondary()` S11-03, `Spacing` S11-01, `NovaHaptics` S11-15 via the secondary button style, `TimelineView` idiom established in S11-05's `WelcomeHeader` fix). Zero new technical debt introduced. The pre-rebuild `novaOrange` arrow accent + `novaOrange → novaPurple` starter-prompt gradient that were called out as carry-through palette drift in the S11-10 run summary's "Starter-prompt gradient intentionally not reskinned — that's a CTA button surface, not character/dialogue" note — **now retired**.

---

## Cross-references

- [S11-09 — Sparky → Dashy iOS rename](./S11-ds-dashy-rename.md) — establishes the asymmetric-rename carve-out preserved in Decision 9.
- [S11-10 — Dashy visual reskin](./S11-dashy-reskin.md) — builds `DashySpeechBubble` and lands the character repaint consumed by Decision 3.
- [S11-12 — Lessons grid Pinterest-gestalt pass](./S11-12-lessons-pinterest.md) — establishes the "coral = child's pick" semantic extended to the chat child-bubble.
- [S11-03 — NovaCard + Button styles](../SPRINT-11-tracker.md#s11-03--novacard--button-styles-5-pts--done-april-20) (tracker section) — `.novaSecondary()` consumed by Decisions 4 + 8.
- [S11-11 + S11-14 — Flipbook chrome + loading skeletons](./S11-flipbook-skeletons.md) — prior T2 surface that established the "consume `.novaSecondary()` on nav chrome" pattern S11-13 extends to Dashy pills.
- [S11-05 — Home refresh](./S11-home-refresh.md) — neutralized a Swift 6 `Timer` + `@MainActor` hazard in `WelcomeHeader` using a structured `.task`-scoped `Task`; S11-13 extends the "no `Timer` on the Dashy surface either" principle by reaching for `TimelineView`.
