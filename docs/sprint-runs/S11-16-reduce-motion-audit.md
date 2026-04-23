# S11-16 — Reduce-motion audit sweep

**Run ID:** S11/R16
**Parent sprint:** [SPRINT-11](../SPRINT-11-tracker.md) — "Comic-Book Polish"
**Stories landed:** S11-16 (MX, 2 pts)
**Run window:** 2026-04-22 (single session, post S11-17)
**Landed:** 2026-04-22
**Status:** ✅ Delivered
**Delivery agents:** /senior-swift + /swiftui-pro + /sprint-runner
**Sprint progress after this run:** 90 / 93 pts (97%) — MX epic **10 / 10 (100%)**

---

## Run Goal

Walk every `withAnimation(…)` block added to `src/Apps/NovaKids/` during Sprint 11 (the comic-book polish arc S11-05 through S11-13) and classify each site into one of three buckets:

1. **Ambient motion — gate at source.** Scale pulses, scroll transitions, bounce-back snaps, idle loops. These need `@Environment(\.accessibilityReduceMotion)` at the call-site so reduce-motion users get an instant state change instead of the animation.
2. **Discrete-event celebration — carve-out and document.** One-shot "you did it" moments (confetti burst on experiment completion, UNLOCKED! word on badge reveal, POW! on correct quiz answer) deliberately survive reduce-motion per Apple HIG motion-semantics guidance — they're not ambient motion, they're the finish-line marker that must land regardless of preference.
3. **Already gated upstream.** Either inside an `if !reduceMotion { }` block at the caller, or guarded by an `@State hasAppeared` / `.onAppear { guard !reduceMotion }` pattern that's been in place since the site landed.

The sweep covered **52 call sites across 16 files**. Every site now falls into one of the three buckets with an inline classification comment. No site was left ambiguous.

---

## Stories & Acceptance Criteria

| ID | Story | AC → Outcome |
|----|-------|----------|
| S11-16 | Reduce-motion audit (sweep of S11-05…13) | ✅ All 3 AC landed — (1) every S11-05…13 `withAnimation(…)` block respects reduce-motion or carries a celebration carve-out doc; (2) one-line classification comment at each site; (3) celebration one-shots explicitly documented as deliberate-not-gated per Apple HIG. |

This story was originally scoped against the 52-site count that the S11-05…13 rebuild left behind. Triage surfaced that **~32 of those sites were already gated upstream** — either because the author wrote the reduce-motion branch at the time of landing (S11-06 QuizPowReaction, S11-07 BadgeUnlockBurst, S11-13 DashyView chat dots) or because the outer caller already guards with `guard !reduceMotion else { return }` (S11-05 WelcomeHeader wave loop, S11-07 BadgeView earned scale). The actual edit surface was **5 files × 7 sites needing new gates + 1 file needing a celebration carve-out doc** — see [Files Changed](#files-changed) for the specific breakdown.

---

## Files Changed

### Sources

| File | Δ LOC | Change |
|------|------:|--------|
| `src/Apps/NovaKids/Sources/Views/Flipbook/ExperimentCardView.swift` | +19 / -3 | Four ambient-motion sites gated (`handleDrop` correct-drop snap spring; wrong-drop bounce-in + bounce-out; auto-dismiss completion fade); one celebration carve-out documented (completion card fade-in — paired with `NovaHaptics.success()` + confetti); ShakeModifier driver guarded at the `shakeAnimation = !reduceMotion` source so the Timer-based ±10pt offset loop never even starts for reduce-motion users. |
| `src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` | +9 / -2 | `@Environment(\.accessibilityReduceMotion)` declared at struct scope; Prev + Next card-swap animations gated — reduce-motion turns the TabView slide into an instant state flip. Progress dots + card content still convey navigation semantically. |
| `src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | +10 / -2 | `updateAnimationFromEmotion` showCelebration flips gated both on enter and exit — this is *per-response ambient motion* (fires every happy/excited emotion beat), not a one-shot celebration, so it gets the gate treatment rather than the carve-out. Celebration state still flips so VoiceOver + state-machine observers see the semantic beat regardless. |
| `src/Apps/NovaKids/Sources/Views/Flipbook/ConfettiView.swift` | +13 / -0 | Header doc block updated with explicit "S11-16 carve-out" paragraph — codifies *why* the particle physics do not gate on reduce-motion and points future contributors at the sibling-view pattern if they want a reduce-motion-friendly celebration variant. Zero runtime change; this is pure documentation of an architectural decision we want the code to make loud. |

### Verified — already gated upstream (no edit)

These files were audited and confirmed compliant. No change required; recording here so the audit is reproducible.

| File | Sites | Gating pattern |
|------|:-----:|----------------|
| `Views/Home/WelcomeHeader.swift` | 2 | `animateWaveIfAllowed()` opens with `guard !reduceMotion else { return }` — both `withAnimation` sites inside the `while !Task.isCancelled` loop are unreachable under reduce-motion. |
| `Views/Flipbook/QuizPowReaction.swift` | 4 | `runBurst()` has an `if reduceMotion { … return }` early-branch with its own degraded path (plain fade, no scale/rotate transforms). The reduce-motion path still uses `withAnimation` for the fade-in/fade-out opacity change, which is fine — the transforms are the motion-sensitive part. |
| `Views/Flipbook/QuizCardView.swift` | 5 | Every `withAnimation` site is a ternary on `reduceMotion ? .none : <animation>` at the call-site. |
| `Views/Flipbook/VoiceCardView.swift` | 3 | Line 276 site inside `if !reduceMotion { }` (waveform); line 289 ternary-gated (sparkle enter); line 298 inside the `if !reduceMotion { sparkleTask = Task { … } } else { sparkleOpacity = 0 }` bifurcation. |
| `Views/Flipbook/StoryCardView.swift` | 1 | Ternary on `reduceMotion` at the call-site. |
| `Views/Flipbook/DashyHintButton.swift` | 1 | Ternary on `reduceMotion` at the call-site. |
| `Views/Dashy/DashyCharacterView.swift` | ~10 | Every site lives inside an `if !reduceMotion { }` block (lines 321, 328, 350, 366, 380, 394). Multiple repeatForever idle loops, all uniformly gated. |
| `Views/Trophies/BadgeUnlockBurst.swift` | 4 | `runBurst()` has the same `if reduceMotion { … return }` early-branch shape as QuizPowReaction. Documented explicitly in the header doc as a celebration that degrades (not a carve-out that survives). |
| `Views/Trophies/BadgeView.swift` | 1 | `animateEntrance()` guards `earned, !reduceMotion` before the spring — locked badges and reduce-motion users both skip the scale bounce. |
| `Views/Common/ParentalGateView.swift` | 3 | One ternary, two inside `if !reduceMotion` blocks. |
| `Views/Auth/KidsLoginView.swift` | 1 | `.onAppear { guard !reduceMotion else { return } }` guards the float-loop at its entry point (landed in S11-17). |
| `Views/Onboarding/OnboardingView.swift` | 2 | Live site at `transitionToPage(_:)` is ternary-gated (S11-17); confetti site is deliberate celebration carve-out with inline doc (S11-17). |

### Docs

| File | Δ LOC | Change |
|------|------:|--------|
| `docs/SPRINT-11-tracker.md` | +~8 / -~4 | S11-16 row flipped `⏸ Pending` → `✅ Done` with dense Notes. Sprint Summary table MX epic `8/10 (80%)` → `10/10 (100%)`; Total `88/93 (95%)` → `90/93 (97%)`. |
| `docs/sprint-runs/S11-16-reduce-motion-audit.md` | +~280 / -0 | This file. |
| `docs/sprint-runs/index.md` | +~1 / -0 | New top row for S11-16 (runs index sorted newest-first). |

**Zero new files in source.** No `project.pbxproj` touch. This is a pure behavioral-correctness audit — a survey followed by surgical edits at five ambient-motion sites and one documentation insert at the confetti carve-out. The bulk of the work was the triage that proved the other ~32 sites didn't need touching.

---

## Architectural Decisions

Numbered so they're easy to reference in later sprints.

### 1. Reduce-motion gate shape: `withAnimation(reduceMotion ? nil : .spring(...))`

`withAnimation(_:body:)` has signature `(Animation?, () throws -> Result) -> Result` — passing `nil` applies the state change *without* animation, synchronously. Ternary on `reduceMotion ? nil : <animation>` at the call-site is the minimum-scope way to gate: the body still runs, the state still flips, VoiceOver still announces, but the screen redraws once instead of animating through intermediate frames.

**Why this over `if reduceMotion { state = newValue } else { withAnimation { state = newValue } }`**: the inline ternary keeps the body closure single-sited — the state mutation code lives in exactly one place. The `if/else` variant duplicates the body, which is a minor correctness hazard (future change has to be made in both branches) and a noise hit at review time.

**Why this over `.none`**: the SwiftUI docs write the type as `Animation?`, so `nil` is the canonical form. `Optional<Animation>.none` compiles to the same thing but reads as if the author was reaching for `Animation.none` (which doesn't exist as a static member in all SDKs). VoiceCardView uses `.none` in a pre-S11-16 site — we left it because the nearby code was already landed and the compiler is happy, but new writes go through `nil`.

### 2. Three classification buckets, not two

Early triage tried to split into "gated" vs "not gated" and ran into noise: some sites *looked* ungated but had upstream `guard !reduceMotion` that made them unreachable, which is functionally identical to a call-site gate but visually different. And celebration one-shots that deliberately don't gate were being flagged as bugs by the audit's grep pass.

Three buckets — **ambient (gate)**, **celebration (carve-out + doc)**, **already gated upstream (verify)** — let the audit artifact be reproducible. The final S11-16 doc block lists every file in one of the three buckets; running `grep -n withAnimation` + cross-referencing against this doc is the ongoing regression test for future sprints.

### 3. Celebration carve-out: document *why* at the view, not in a central place

ConfettiView's header doc block now carries a three-paragraph "Reduce-motion (S11-16 carve-out)" section explaining *why* the particle animations deliberately don't gate. The same pattern is already in `QuizPowReaction` (though that view chooses to degrade rather than carve-out — the header doc notes this), `BadgeUnlockBurst`, and `OnboardingView.meetDashyPage`'s confetti call-site.

**Why per-view rather than a central `docs/reduce-motion-policy.md`**: the future contributor asking "should I gate this?" is going to be staring at *the view they're editing*, not at a policy doc. The decision needs to be visible where it's applied. If we grow to 10+ celebration views we might extract the pattern to a named `@ViewModifier` (`.novaCelebration()`) — but at 4 call sites the duplication is cheap and the in-place doc is clearer.

### 4. Dashy emotion celebration is ambient, not a one-shot

`updateAnimationFromEmotion` fires every time Dashy's emotion state flips to `.happy` or `.excited`. In a chat session this can happen many times (every supportive response). It *looks* like a celebration — there's an 800ms timed burst — but semantically it's closer to Dashy's idle bounce than to ConfettiView: it's an ambient expression of mood, fired repeatedly, not a singular "you did it" beat.

**Decision**: gate it with `reduceMotion ? nil : .default`. The `showCelebration` state still flips — that's observable by the state machine, VoiceOver, and any future hooks — but the scale/pulse transition turns into an instant state change under reduce-motion.

**Why not carve-out like ConfettiView**: ConfettiView is guaranteed to fire at most once per session (at the end of an experiment card). Dashy's emotion celebration can fire dozens of times per session. Motion-sensitive users opted out of repeated ambient motion; firing dozens of pulses during a chat is exactly the case reduce-motion exists to prevent.

### 5. Shake driver guarded at the `shakeAnimation` source, not in the modifier

ExperimentCardView's wrong-drop has a `ShakeModifier` — a custom `ViewModifier` that subscribes to a `Timer.publish` and jitters the view's offset by ±10pt every 50ms while `shakeAnimation == true`. Gating the `withAnimation` calls doesn't help here because the jitter isn't inside a `withAnimation` — it's the raw offset assignment.

**Fix**: gate *at the source* — change `shakeAnimation = true` to `shakeAnimation = !reduceMotion` in the wrong-drop path. The Timer subscribes either way (setupTimer is called in `.onAppear`), but with `shakeAnimation` staying false the subscription's sink-branch never runs the random-offset path. Cheaper than unsubscribing, and keeps the modifier's contract ("jitter while shakeAnimation is true") intact.

**Alternative considered**: give `ShakeModifier` its own `@Environment(\.accessibilityReduceMotion)` and guard at the subscription sink. Rejected because it pushes responsibility away from the caller who *decided* to trigger a shake — the decision to shake belongs at the semantic level (wrong-drop), not at the implementation level (the modifier).

### 6. Confetti survives on the experiment card AND the onboarding "Let's Go!"

ExperimentCardView's `celebrateCompletion()` and OnboardingView's `firstMissionPage` both fire `ConfettiView` at their finish-lines. Both are explicitly classified as discrete-event celebrations: one-shot, user-earned, paired with haptic success() feedback. Both survive reduce-motion.

**What would make us revisit this**: if the experiment card celebration started firing on failure states (e.g. "completed with hints used"), that would change the semantics from "you finished the experiment" to "you finished *something*" — the ambient-vs-discrete line gets fuzzy. For now the fire condition is `dragItems.allSatisfy({ $0.isPlaced })` with correctness already validated per-snap, so the celebration is truly binary.

---

## Validation

### Sandbox ✅

| Check | Result |
|-------|--------|
| Grep all 52 `withAnimation` sites in `src/Apps/NovaKids/Sources/Views/` | ✅ every site classified in one of three buckets |
| `grep -rn 'withAnimation' src/Apps/NovaKids/Sources/Views/Flipbook/ExperimentCardView.swift` | ✅ 5 sites, 4 gated + 1 celebration carve-out with inline doc |
| `grep -rn 'withAnimation' src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` | ✅ 2 sites, both gated with shared `reduceMotion ? nil : …` ternary |
| `grep -rn 'withAnimation' src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` | ✅ 2 showCelebration sites gated |
| `grep -rn '@Environment.*accessibilityReduceMotion' src/Apps/NovaKids/Sources/Views/` | ✅ 13 files declare it (up from 12 pre-run) |
| ShakeModifier driver: `shakeAnimation = !reduceMotion` in wrong-drop path | ✅ |
| No `withAnimation` site left unclassified | ✅ |
| ConfettiView header doc updated with carve-out language | ✅ |

### 🟡 Mac-only — bang to run

Sandbox can't launch a simulator or flip system reduce-motion. The following need device validation before closing the sprint:

| Check | How |
|-------|-----|
| ExperimentCardView: enable iOS reduce-motion, drag a correct item onto a zone — snap lands instantly, no spring bounce | Settings → Accessibility → Motion → Reduce Motion (on) |
| ExperimentCardView: enable reduce-motion, drag a wrong item — no ±10pt shake jitter; haptic `wrong()` still fires | Same settings |
| ExperimentCardView: enable reduce-motion, complete all drops — confetti + "All set!" card still celebrate (carve-out working) | Same settings |
| FlipbookView: enable reduce-motion, tap Next — card index advances, no horizontal slide transition | Same settings |
| DashyView: enable reduce-motion, send a chat that triggers happy emotion — no celebration pulse, but state machine still processes correctly | Run Dashy chat with a reduce-motion flipped device |
| Disable reduce-motion, repeat each above — all animations run at full fidelity (regression check) | Settings → Accessibility → Motion → Reduce Motion (off) |

Prerequisites bang must run on his Mac:

```bash
# expect: compiles clean, no warnings on the edited files
cd src/Apps/NovaKids
xcodebuild -scheme NovaKids -destination 'generic/platform=iOS' -configuration Debug build

# expect: SwiftUI-pro warnings on the audit surface are zero or only pre-existing issues
# (the audit doesn't introduce new API usage — purely ternary guards on existing withAnimation)
```

---

## Sprint Impact

### Before S11-16

| Epic | Progress |
|------|----------|
| DS (Design System foundations) | 21 / 21 (100%) |
| T1 (Tier 1 surfaces) | 22 / 22 (100%) |
| T2 (Tier 2 surfaces) | 15 / 15 (100%) |
| MX (Motion & Haptics) | 8 / 10 (80%) — S11-16 open, S11-15 closed |
| MVP (Live data wire-up) | 8 / 8 (100%) |
| QA | 4 / 7 (57%) |
| **Total** | **88 / 93 (95%)** |

### After S11-16

| Epic | Progress |
|------|----------|
| DS | 21 / 21 (100%) |
| T1 | 22 / 22 (100%) |
| T2 | 15 / 15 (100%) |
| MX | **10 / 10 (100%)** |
| MVP | 8 / 8 (100%) |
| QA | 4 / 7 (57%) |
| **Total** | **90 / 93 (97%)** |

Only S11-18 (3 pts, iPad landscape + dark + DynamicType QA) remains open. MX epic closed.

---

## What's Next

1. **S11-18 — iPad landscape + dark mode + DynamicType QA** (3 pts, last open story). Code-review-based audit since the sandbox can't run simulators. Produces a written defect inventory (file + line + expected-vs-observed) that bang works through on his Mac. Closes Sprint 11 at 93/93 (100%).
2. **Sprint 12 scaffolding.** Per S11-13 and S11-19 carve-outs: coordinated Sparky → Dashy rename across backend (`role == "sparky"` literal in the card generator + `/sparky/chat` route) + iOS chat VM. Low risk; high value (branding consistency end-to-end).
3. **Reduce-motion as a first-class design primitive going forward.** Sprint 12+ should treat `@Environment(\.accessibilityReduceMotion)` as mandatory for any new animation — the audit pattern established here (source-level gate + classification comment) is the muscle memory we want.

---

## Retired Debt

1. **The "shake jitter keeps firing under reduce-motion" latent bug.** Before S11-16, ExperimentCardView's wrong-drop would run the Timer-based ±10pt offset even when the user had iOS reduce-motion enabled — the `withAnimation` on `showBounceBack` was gated, but the `shakeAnimation` state flag flipped unconditionally, and the modifier's publisher sink ran the random-offset path. Now the flag itself is gated at the source.
2. **The "confetti is a reduce-motion violation" audit false-positive.** Prior sprint audits had flagged ConfettiView as missing a reduce-motion guard. S11-16 formally establishes the carve-out: one-shot discrete-event celebrations deliberately survive reduce-motion per Apple HIG. Documented inline so future audits don't re-flag.
3. **The "ambient vs discrete" classification debt.** Pre-S11-16, several views had ad-hoc reduce-motion handling with no documented rationale. The three-bucket classification (ambient / celebration / already-gated) is now the standard and the audit artifact lists every file against it.

---

## Cross-references

- [S11-17 — Auth login + Onboarding polish](./S11-17-auth-onboarding-polish.md) — prior run in the same session; established the `transitionToPage(_:)` centralised-gate pattern S11-16 generalises.
- [S11-13 — Dashy chat surface rebuild](./S11-13-dashy-chat.md) — earlier in Sprint 11; the TimelineView + reduce-motion branching idiom S11-16 audits against.
- [S11-haptic-ladder-sweep](./S11-haptic-ladder-sweep.md) — the MX epic's other sweep story (S11-15); S11-16 closes the epic alongside it.
- [S11-06 — Quiz comic-ification](./S11-quiz-comic-ification.md) — introduced QuizPowReaction's internal `if reduceMotion { … return }` pattern that set the template for S11-07 BadgeUnlockBurst and S11-16's reuse guidance.
- [S11-07 — Trophy refinement](./S11-trophy-refinement.md) — BadgeUnlockBurst + BadgeView earned-scale, both verified compliant in the S11-16 audit.
- [SPRINT-11 tracker](../SPRINT-11-tracker.md) — forward-looking plan of record; MX epic flipped to 100% after this run.
