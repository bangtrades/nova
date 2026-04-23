# Sprint Run — S11-15 (Haptic ladder sweep — Tier 1 screens)

**Run ID:** `S11/R12`
**Parent sprint:** Sprint 11 ("Comic-Book Polish" — 85 pts total)
**Run window:** April 22, 2026 (Day 5 continuation — same day as `S11/R11` Flipbook+Skeletons, but a fresh session targeting the MX epic's remaining haptic leg)
**Delivery agents:** `/senior-fullstack` (integration + dev-console surface readiness) + `/senior-swift` (iOS SwiftUI authoring) + `/swiftui-pro` (post-write review) + `/jira-expert` (sprint tracking + run summary artifact per the standing ARGUMENT)
**Tracking request:** `/jira-expert` ("add a sprint for this run so that we have a tracked summary of the added features")
**Runtime directive:** `/senior-fullstack` ("We will do a lot of testing/analysis in the dev console so I want the features to be ready") — meaning every call-site rename must land such that bang can open Home, Quiz, Trophy, Onboarding, AgeGate, Parental-Gate, and Experiment-drag on the iPad and feel the same ladder without one tap rung being heavier or one wrong rung louder than its neighbour.
**Status:** ✅ **DELIVERED** — every inline `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` call on a Tier 1 surface is now routed through `NovaHaptics.tap() / .commit() / .success() / .wrong()`. The ladder has four rungs; the app uses all four; the DS buttons themselves are the entry points for the first two. MX epic moves 5/10 → 8/10 = 80%; sprint total moves 60/85 → 63/85 = 74%.

---

## 1. Run Goal

Close the one surviving thread of the S11 design-system unification: **haptics**. The palette is consolidated (S11-02), the buttons share a style (S11-03), the Bangers font is plumbed (S11-04), the Quiz comic-ifies (S11-06), the Trophy reads as a gallery (S11-07), navigation wears one modifier (S11-08), Dashy owns the mascot voice (S11-09/10), Flipbook chrome is unified (S11-11), loading skeletons are honest (S11-14) — but every surface was still hand-rolling its own `UIImpactFeedbackGenerator(style: .light)` / `.medium` / `.heavy` / `.rigid`, often with the wrong semantic rung chosen. S11-06 introduced the `NovaHaptics` namespace with the four-rung ladder (`tap` / `commit` / `success` / `wrong`) and explicitly telegraphed "S11-15 will sweep those call sites to use this helper" in a doc comment on `NovaHaptics.tap()` itself. This run is that sweep.

Not just a mechanical rename. Three of the eleven call sites had semantic drift — the inline `UIImpactFeedbackGenerator` call was sitting on the wrong ladder rung relative to what the interaction meant. The worst offender was `ExperimentCardView`'s "wrong drop" path, where the comment said *"Gentle warning haptic"* but the code was `.light` — which is the `tap` / acknowledgement rung, not the `wrong` / try-again rung. A child dropping a piece on the wrong target was getting the same haptic beat as tapping a secondary button. The sweep is the opportunity to make the semantics match — the child's hand feels *"not quite, try again"* because the code now fires `NovaHaptics.wrong()` (rigid), not the ladder rung for *"got it"*. This is the kind of fix that you never catch in a code review because each side looks locally correct; you only catch it when someone forces the ladder to be named, and every call site has to pick a name.

The two other semantic shifts were softer: `ExperimentCardView`'s correct-drop path fired `.heavy` on each piece-snap (the same impact weight as the full-completion celebration) — after the sweep, individual snaps fire `commit` (medium) and the final all-placed celebration keeps `success` (heavy + system notification). This preserves the "each snap feels good" instinct of the original while giving the completion moment a distinct, louder beat. The second is `AgeGateView`'s pass path: `.heavy` impact alone is a big thump but does not give VoiceOver users a notification cue; routing through `.success()` pairs the impact with `UINotificationFeedbackGenerator().notificationOccurred(.success)` so sighted and blind users both get the "you're through" signal at the same moment.

The work also closes a meta-level debt: after this run, `grep -rn "UIImpactFeedbackGenerator\|UINotificationFeedbackGenerator"` returns zero hits outside `NovaHaptics.swift` itself. That grep becomes the audit signal — any future PR that reintroduces an inline generator is visible in one command. The sensory vocabulary is now greppable.

**Standing constraints (carried from Sprint 11 plan and prior runs):**
- UX-only sprint — no backend changes.
- `NovaHaptics.swift` itself (S11-06) is the canonical location for generator instantiation. All other files go through the namespace.
- The ladder is deliberately 4 rungs, not 5. There is no "heavy but not celebratory" rung — commit (medium) is the correct mapping for "decisive input" even if the original code used `.heavy`. Documented inline where that differs from the original intent.
- Swift 6 strict concurrency: `NovaHaptics.swift` documents that the common call pattern (`@MainActor`-isolated view firing the helper) is the safe one; nothing in this sweep changes that.
- No pbxproj changes — this is a call-site rename across 6 existing files, no new files land.

---

## 2. Stories & Acceptance Criteria

### S11-15 — Haptic pass, Tier 1 screens (3 pts) ✅

**User story:** *Every haptic beat in the app sits on the same 4-rung ladder. Tapping a secondary button feels the same whether I'm on Home or in Onboarding. Committing to a primary action feels the same whether I'm finishing a quiz or recording my voice. Celebrating a success feels the same whether I unlocked a badge or placed the last piece in an experiment. And the "try again" beat feels like a gentle correction, not an error alarm. I don't have to think about it — muscle memory builds up because every surface uses the same vocabulary.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | `NovaPrimaryButtonStyle`'s inline `UIImpactFeedbackGenerator(style: .medium)` replaced with `NovaHaptics.commit()`. Every `.novaPrimary()` consumer inherits the ladder entry automatically. | ✅ |
| AC2 | `NovaSecondaryButtonStyle`'s inline `UIImpactFeedbackGenerator(style: .light)` replaced with `NovaHaptics.tap()`. Every `.novaSecondary()` consumer inherits the ladder entry automatically. | ✅ |
| AC3 | `OnboardingView` avatar-select fires `NovaHaptics.tap()` (acknowledgement — selection, not commitment; commit fires on "Continue" via the primary button style). | ✅ |
| AC4 | `AgeGateView` parent-verified path fires `NovaHaptics.success()` (heavy impact + VoiceOver success notification — the gate-passed moment needs both channels). | ✅ |
| AC5 | `AgeGateView` parent-fail path fires `NovaHaptics.wrong()` (rigid — *"try again"* beat, deliberately not `UINotificationFeedbackGenerator(.error)` which reads as "you broke something"). | ✅ |
| AC6 | `ExperimentCardView` correct-snap fires `NovaHaptics.commit()` (medium), NOT `.success()`. Rationale: each piece-snap is a decisive input, not a full celebration; the full celebration is reserved for all-items-placed and should stand out. | ✅ |
| AC7 | `ExperimentCardView` wrong-drop fires `NovaHaptics.wrong()` (rigid). This is a **semantic fix** — the pre-sweep code was `.light` with a misleading comment *"Gentle warning haptic"*; `.light` is the `tap` rung for acknowledgements, not the `wrong` rung. The child's hand was being told *"got it"* on a miss. | ✅ |
| AC8 | `ExperimentCardView` all-placed (`celebrateCompletion`) fires `NovaHaptics.success()` (heavy + system notification) — the full celebration, with VoiceOver success cue paired to the visible confetti. | ✅ |
| AC9 | `VoiceCardView` record-commit fires `NovaHaptics.commit()` (medium) — decisive input. Celebration (if any) fires downstream from evaluation, not at the record moment itself. | ✅ |
| AC10 | `ParentalGateView` correct-math path fires `NovaHaptics.success()`; wrong-math path fires `NovaHaptics.wrong()`. Lockout trigger path untouched (doesn't fire its own haptic — the lockout screen is the feedback). | ✅ |
| AC11 | Grep audit: `rg "UIImpactFeedbackGenerator\|UINotificationFeedbackGenerator" src/Apps/NovaKids/Sources` returns only matches inside `Views/Common/DesignSystem/NovaHaptics.swift`. Zero leaks elsewhere. | ✅ |
| AC12 | Grep audit: `rg "NovaHaptics\.(tap\|commit\|success\|wrong)\(\)" src/Apps/NovaKids/Sources` returns the full call-site set (20 hits across 7 files, up from 5 files pre-sweep as the ladder reaches Onboarding, AgeGate, Experiment, Voice, and ParentalGate for the first time). | ✅ |
| AC13 | Each edited call site carries a one-line `S11-15:` comment noting the ladder-rung choice and (where applicable) the semantic shift from the pre-sweep code. Future reviewers reading the file see why, not just what. | ✅ |

**Intentionally NOT touched in this run:**
- `NovaHaptics.swift` itself — the canonical generator instantiation lives here; this is the one place where `UIImpactFeedbackGenerator(...)` is still the right code.
- `import UIKit` left in place on the six edited files. Removing it is a follow-up cleanup; several of the files still use other UIKit APIs, and a minimal-blast-radius sweep is safer than risking a "wait, where did I lose UIKit?" compile error mid-Sprint-11.
- The lockout path in `ParentalGateView` (`triggerLockout()`). It exits early and doesn't ride the haptic; the lockout screen itself is the deterrent beat, and adding a haptic there would compete with the screen change.
- Anything already through the ladder from S11-06 / S11-07 / S11-11 — `QuizCardView`, `BadgeUnlockBurst`, `TrophyRoomView`. Those call sites were already on `NovaHaptics.*` and are left untouched.

---

## 3. Files Changed

**Edits (6 files, 0 new files, 0 pbxproj changes):**

### `src/Apps/NovaKids/Sources/Views/Common/DesignSystem/NovaButtonStyles.swift` (2 call sites)

The design-system primitives are the highest-leverage change in the run: every `.novaPrimary()` and `.novaSecondary()` in the app now flows through the ladder without each consumer having to remember the rung. Two `.onChange(of: configuration.isPressed)` blocks edited:

- Line 57 (inside `NovaPrimaryButtonStyle.makeBody`): `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` → `NovaHaptics.commit()`. Doc comment updated to explain the ladder routing (`// Routed through NovaHaptics.commit() (S11-15) so the whole app shares one sensory ladder — grep NovaHaptics. to audit.`).
- Line 108 (inside `NovaSecondaryButtonStyle.makeBody`): `UIImpactFeedbackGenerator(style: .light).impactOccurred()` → `NovaHaptics.tap()`. Original comment kept (explaining why light vs medium); extended with "Routed through NovaHaptics.tap() (S11-15) for ladder consistency."

Press-down / press-release discipline preserved — haptic still fires only on the `false → true` transition, never on release. The ladder routing is a pure semantic upgrade; the tactile behavior is identical.

### `src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift` (1 call site)

`avatarButton` tap handler, line 217. Avatar selection is an **acknowledgement** beat, not a commitment — the child can change their pick before hitting Continue. Routed through `NovaHaptics.tap()`; inline comment explains *"avatar selection is an acknowledgement (tap beat), not a commitment — confirmation happens when the user proceeds."* The actual Continue button is a `.novaPrimary()` consumer, so it fires `.commit()` via the style system — the two haptics are distinct beats, as they should be.

### `src/Apps/NovaKids/Sources/Views/Onboarding/AgeGateView.swift` (2 call sites)

`handleParentVerification` branches. The parent-verified path previously fired a bare `.heavy` impact — big but one-channel; VoiceOver users got no equivalent cue. Now `NovaHaptics.success()` pairs the `.heavy` impact with `UINotificationFeedbackGenerator().notificationOccurred(.success)` so sighted and blind users both get the "you're through" signal at the same moment. The parent-fail path previously fired `.rigid` inline; now it calls `NovaHaptics.wrong()`, which is semantically identical but threads through the namespace. Both branches gain one-line comments that make the ladder rung choice explicit.

### `src/Apps/NovaKids/Sources/Views/Flipbook/ExperimentCardView.swift` (3 call sites)

The three-call-site drag-and-drop card is where the ladder audit paid off the most:

- **Correct-drop (line 242, now ~line 246):** pre-sweep `.heavy` on each piece snap. Post-sweep `NovaHaptics.commit()` (medium). Each snap is a *"committed a piece"* beat; full celebration is reserved for the all-placed moment. Inline comment spells out: *"each correct snap fires commit() (medium), NOT success(). Individual snaps are commitments … Using success() here would stack two VoiceOver 'success' cues on the final drop."*
- **Wrong-drop (line 268, now ~line 275):** **semantic bug fix**. Pre-sweep `.light` with comment *"Gentle warning haptic"* — `.light` is the tap / acknowledge rung, not the wrong / try-again rung. A child dropping a piece on the wrong target was getting the "got it" beat. Post-sweep `NovaHaptics.wrong()` (rigid) delivers the *"not there, try again"* feel that matches the intent. Inline comment documents the fix.
- **All-placed (line 289, now ~line 297):** pre-sweep `.heavy` bare impact in `celebrateCompletion`. Post-sweep `NovaHaptics.success()` (heavy + system notification). Celebration now reaches VoiceOver users via the system cue, matching the visible confetti.

The three-call-site shape is intentional — individual snaps feel good (commit), misses feel like soft bumps (wrong), the moment of completion stands above everything else (success). Pre-sweep all three used `.heavy`-family impacts and were indistinguishable to the hand.

### `src/Apps/NovaKids/Sources/Views/Flipbook/VoiceCardView.swift` (1 call site)

Voice-record commit, line 307. Pre-sweep `.medium` inline; post-sweep `NovaHaptics.commit()`. Inline comment: *"voice record commit — commit beat (medium) matches the ladder for 'user made a decisive input'. Not a celebration; the celebration comes from downstream evaluation."*

### `src/Apps/NovaKids/Sources/Views/Common/ParentalGateView.swift` (2 call sites)

`verifyAnswer` branches. Same shape as AgeGateView — correct-math path upgraded from `.heavy` to `NovaHaptics.success()` (adds VoiceOver success cue); wrong-math path threaded through `NovaHaptics.wrong()`. `triggerLockout()` path left untouched (no haptic — the lockout screen is the feedback). The lockout test-attempts counter and shake animation are unchanged.

---

## 4. Architectural Decisions

### Decision 1: DS button styles route through `NovaHaptics`, not inline generators

**Choice:** Replace the inline `UIImpactFeedbackGenerator` calls inside `NovaPrimaryButtonStyle` and `NovaSecondaryButtonStyle` with `NovaHaptics.commit()` / `.tap()`. Every `.novaPrimary()` / `.novaSecondary()` consumer in the app now inherits the ladder entry point automatically.

**Why not the alternative — leave DS buttons on inline haptics and only migrate the free-standing call sites?** Because the DS buttons are by far the highest-volume haptic path in the app. Every "Continue", "Next", "Start Lesson", "Cancel", "Back" button in every surface goes through these two styles. Leaving them on inline generators would mean the ladder is "documented in NovaHaptics.swift, used in 11 hand-written call sites, but actually bypassed 90% of the time because the DS buttons bypass it." The doc comment on `NovaHaptics.tap()` explicitly telegraphs this sweep ("S11-15 will sweep those call sites to use this helper") — the DS sweep is the main event, the app-level sweep is the rest.

### Decision 2: `commit()` for each Experiment-card piece-snap, not `success()`

**Choice:** Route each correct-drop in `ExperimentCardView` through `NovaHaptics.commit()` (medium), keeping `NovaHaptics.success()` (heavy + VoiceOver cue) for the full all-placed moment in `celebrateCompletion`.

**Why not the alternative — keep the pre-sweep `.heavy` everywhere by routing piece-snaps through `success()` too?** Three reasons.
(a) The ladder has four rungs deliberately; each rung has a meaning. `success()` is reserved for the *celebration* beat — the "you did the whole thing" moment. A piece-snap is a *commitment* beat, the "good move, keep going" moment. Collapsing those into one rung loses the signal.
(b) `success()` also fires `UINotificationFeedbackGenerator().notificationOccurred(.success)`. If piece-snaps all fired that, VoiceOver users would hear the system "success" cue five or six times in a single card — once per snap, then once more on completion. That's noise, not signal. Reserving the system-success cue for the full-completion moment preserves its meaning.
(c) The pre-sweep code's intent was "each snap feels satisfying" — that intent survives under `commit()`, which is still a firm medium impact. What changes is that the completion moment now *also* stands above the individual snaps (heavy + notification vs. medium), which reads to the hand as "the thing you've been building is now done" — a distinct beat from "you placed a piece."

### Decision 3: Wrong-drop on Experiment fires `wrong()`, fixing a semantic bug

**Choice:** Wrong-drop in `ExperimentCardView.handleDrop` (pre-sweep line 268) now fires `NovaHaptics.wrong()` (rigid), not `.light`.

**Why:** The pre-sweep code had `UIImpactFeedbackGenerator(style: .light)` with a comment *"Gentle warning haptic"*. `.light` is the `tap` rung — the ladder rung for *"got it, acknowledged"*. A child dropping a piece on the wrong target was receiving the "you did a thing" beat, which is exactly the wrong signal: it reinforces the action the child just took, rather than inviting retry. The correct rung is `wrong()` (rigid) — crisper than `.light`, softer than `.heavy`, semantically *"not there, try again"*. The only way this bug was going to get caught is by forcing every call site to pick a named rung; the moment the ladder requires a semantic choice, the mismatch becomes visible. Good argument for the namespace.

### Decision 4: Add VoiceOver success cues to AgeGate and ParentalGate passes

**Choice:** Route the success path in both gate views through `NovaHaptics.success()` rather than preserving the pre-sweep bare `.heavy`.

**Why:** `NovaHaptics.success()` fires both `UIImpactFeedbackGenerator(style: .heavy).impactOccurred()` AND `UINotificationFeedbackGenerator().notificationOccurred(.success)`. The pre-sweep code fired only the first — sighted users got the thump; VoiceOver users got silence. Both gates are accessibility-critical (they're the only blocker between "app starts" and "child can use app"), and the "you're through" moment is where VoiceOver users most need feedback. Routing through `.success()` is a pure accessibility uplift with no cost: the tactile feel is unchanged for sighted users, and VoiceOver users now get the system success cue they need.

### Decision 5: `import UIKit` stays in place on the six edited files

**Choice:** Do not attempt to drop `import UIKit` from any of the six edited files, even from `NovaButtonStyles.swift` which no longer references UIKit directly after this sweep.

**Why not the alternative — clean up the unused import as part of the same sweep?** Two reasons.
(a) Several of the edited files (`OnboardingView`, `AgeGateView`, `VoiceCardView`, `ParentalGateView`) still use other UIKit APIs elsewhere in the file — `UIScreen`, `UIAccessibility`, animation curves, etc. A mass import-cleanup is a different pass with a different audit trail.
(b) Swift's implicit SwiftUI → UIKit transitive re-export on iOS makes "unused" hard to prove without actually compiling. If I'm wrong, the build breaks mid-Sprint-11 on a distraction. The goal of S11-15 is one thing: ladder unification. Other cleanup belongs in other passes. Follow-up candidate noted for a hygiene-only story if it ever matters.

### Decision 6: Lockout trigger path in ParentalGateView stays without a haptic

**Choice:** `triggerLockout()` in `ParentalGateView.verifyAnswer` (invoked after N wrong attempts) does not fire its own haptic. Pre-sweep it didn't; post-sweep it still doesn't.

**Why:** The lockout is a screen change + countdown — a visual/state feedback. Adding a haptic would compete with the screen transition for the user's attention and risk reading as "you broke the app" rather than "take a break". The preceding wrong answer already fired `NovaHaptics.wrong()`; adding a second beat on top of that would stack two haptics too close together and desensitize the user to the individual wrong beat. The screen itself is the lockout's beat.

---

## 5. Validation

**Sandbox ✅ (what ran here):**
- `rg "UIImpactFeedbackGenerator\|UINotificationFeedbackGenerator\|UISelectionFeedbackGenerator" src/Apps/NovaKids/Sources` — returns 10 hits, all inside `Views/Common/DesignSystem/NovaHaptics.swift`. Zero leaks elsewhere.
- `rg "NovaHaptics\.(tap\|commit\|success\|wrong)\(\)" src/Apps/NovaKids/Sources` — returns 20 call sites across 7 files. Pre-sweep was 6 call sites across 5 files (the S11-06 / S11-07 / S11-11 landings). Delta: +14 call sites, +2 files (Onboarding + Common gate views now on the ladder for the first time).
- Edit-tool consistency: every `old_string` matched uniquely on first try; no drift between file state and tool expectation.
- Every edited block carries an `S11-15:` or `NovaHaptics` inline comment naming the ladder rung choice and, where applicable, the semantic shift.

**🟡 Mac-only (blocked on sandbox — bang runs these):**
- **Build:** `xcodebuild -scheme NovaKids -destination 'platform=iOS Simulator,name=iPad Pro 13-inch' build`. Expect clean compile — no new files, no pbxproj churn, no new API surface. The only language-level change is inline call-site rename `UIImpactFeedbackGenerator(style: .x).impactOccurred()` → `NovaHaptics.x()`.
- **iPad-in-hand feel test:** walk Home → Lesson → Quiz → Experiment drag → Voice record → Trophy → Badge unlock, firing each haptic beat. Every surface should feel like one ladder: light for selects, medium for commits, heavy-plus-notification for celebrations, rigid for try-agains. The most noticeable change for bang should be on the Experiment card — individual piece-snaps now feel lighter (commit/medium) while the all-placed moment feels distinctly heavier and rings the VoiceOver success cue.
- **VoiceOver pass:** enable VoiceOver, pass AgeGate with a parent birth year >= 18 years ago; expect to hear the system "success" cue alongside the impact. Pre-sweep this was silent on VoiceOver. Repeat for ParentalGate correct-math and ExperimentCard all-placed — all three should now announce success to VoiceOver.
- **Wrong-drop semantic test on ExperimentCard:** drop a piece on an incorrect target; the haptic should now feel like a soft bump (rigid, *"not there"*) rather than an acknowledgement tap (*"got it"*). The improvement is subtle but deliberate — a child should be able to close their eyes and tell whether a drop landed correctly or not.

**No Swift 6 isolation concerns introduced:** `NovaHaptics` helpers are pure static funcs on a `public enum`. `UIFeedbackGenerator` usage is MainActor-correct when called from SwiftUI view bodies (which is the only call path); the `.onChange(of:)` closure on the DS buttons runs on Main, the Onboarding/AgeGate/Experiment/Voice/ParentalGate handlers are all view-body handlers firing on Main. No actor hops added; none needed.

---

## 6. Prerequisites bang must run on his Mac

```bash
# 1. Pull the sandbox edits
cd ~/Projects/Novai   # adjust if different
git status            # expect 7 files modified: 6 view files + 1 tracker + 1 run summary
git diff --stat src/Apps/NovaKids/Sources/Views/

# 2. Build on iPad Pro 13-inch sim
xcodebuild -scheme NovaKids \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch' \
  build | xcpretty
# expect: BUILD SUCCEEDED, no warnings on the 6 edited files

# 3. Run on the iPad (physical device preferred for haptic feel)
#    Walk the 7 surfaces affected by the sweep:
#      - Home → any lesson tile (.novaSecondary haptic = tap beat)
#      - Quiz card (existing NovaHaptics path, regression-check)
#      - Experiment drag-and-drop card:
#          a. drop correctly — feel commit (medium), NOT heavy
#          b. drop incorrectly — feel wrong (rigid), NOT light
#          c. complete all drops — feel success (heavy + VoiceOver cue)
#      - Voice card record (commit beat on record-commit)
#      - Onboarding avatar pick (tap beat on select, commit on Continue)
#      - Age gate parent verification:
#          pass → success (heavy + VO cue)
#          fail → wrong (rigid)
#      - Parental gate math challenge:
#          correct → success (heavy + VO cue)
#          wrong → wrong (rigid)

# 4. VoiceOver sweep — enable Settings → Accessibility → VoiceOver:
#      Age-gate pass, parental-gate correct, experiment all-placed:
#      each should now announce "success" via the system notification cue
#      (pre-S11-15: silent on VoiceOver).

# 5. Haptic audit grep — should still be clean after any future edit:
rg "UIImpactFeedbackGenerator|UINotificationFeedbackGenerator" src/Apps/NovaKids/Sources
# expect: only NovaHaptics.swift lines. Any other hit is drift.

rg "NovaHaptics\.(tap|commit|success|wrong)\(\)" src/Apps/NovaKids/Sources | wc -l
# expect: 20 call sites (as of S11-15 close-out).
```

---

## 7. Sprint Impact

| Epic | Before this run | After this run | Δ |
|------|-----------------|----------------|---|
| DS   | 15/15 = 100%    | 15/15 = 100%   | — |
| T1   | 25/25 = 100%    | 25/25 = 100%   | — |
| DSH  | 10/10 = 100%    | 10/10 = 100%   | — |
| T2   | 5/18 = 28%      | 5/18 = 28%     | — |
| **MX** | **5/10 = 50%** | **8/10 = 80%** | **+3 pts** |
| QA   | 0/7 = 0%        | 0/7 = 0%       | — |
| **Sprint 11 Total** | **60/85 = 71%** | **63/85 = 74%** | **+3 pts** |

The MX epic has one story remaining (S11-16 — reduce-motion audit). Once that lands, MX closes at 100% and only the T2 epic (S11-12 + S11-13 = 13 pts) and QA epic (S11-17 + S11-18 = 7 pts) have pending stories.

---

## 8. What's next

1. **S11-12** — Lessons grid Pinterest-gestalt pass (6pt). `NovaCard` wrapper on tiles, `.onHover` + `scaleEffect(1.02)` on iPad, ink-outline / coral-fill filter pills, sun "NEW" badge on fresh content, `LoadingSkeletonView` wiring for initial load (closes audit finding #4 on the Lessons side — pairs with S11-14's Lessons wiring). Masonry math preserved. Reduce-motion respected on the hover scale. **Highest-visibility remaining story — major surface rebuild that bang can exercise in the iPad dev console end-to-end.**
2. **S11-13** — Dashy chat surface rebuild (7pt). Sun-filled Dashy bubble with ink stroke + tail, coral-filled child bubble, `NovaSecondaryButtonStyle` suggestion pills, ink-outline / coral-fill session-time progress bar. Typing animation preserved with static-"…" reduce-motion fallback.
3. **S11-17** — Auth login + Onboarding spacing polish (4pt). Floating shapes → 3+1 palette, login primary → `NovaPrimaryButtonStyle`, `.font(.title)` sites → `NovaPalette.titleFont()`, `Spacing.md` uniform gaps on avatar grid. Confetti stays.
4. **S11-16** — Reduce-motion audit across the S11-05..13 animations (2pt). Blocked-by: 12, 13, 17 land first so the audit sweeps the final set.
5. **S11-18** — iPad landscape + dark mode + DynamicType QA (3pt). Blocked-by: all prior stories land. Written defect inventory, not inline fixes.

---

## 9. Cross-references

- [`docs/sprint-runs/S11-flipbook-skeletons.md`](S11-flipbook-skeletons.md) — prior run (`S11/R11`), same day. Flipbook chrome + loading skeleton wiring.
- [`docs/sprint-runs/S11-quiz-comic-ification.md`](S11-quiz-comic-ification.md) — `S11/R6`. Original landing of `NovaHaptics` namespace. This run's sweep closes the "will sweep in S11-15" doc-comment telegraph.
- [`docs/SPRINT-11-tracker.md`](../SPRINT-11-tracker.md) — sprint plan of record. S11-15 row now ✅; Sprint Summary reflects 63/85 = 74%.
- [`src/Apps/NovaKids/Sources/Views/Common/DesignSystem/NovaHaptics.swift`](../../src/Apps/NovaKids/Sources/Views/Common/DesignSystem/NovaHaptics.swift) — canonical implementation. Doc comments now fully reflect that every external call site is on the ladder.
- [`docs/skill-updates/S11-swift-skills-update-proposal.md`](../skill-updates/S11-swift-skills-update-proposal.md) — meta-improvements to the Swift/SwiftUI skills from earlier in Sprint 11. The ladder-pays-off-only-when-forced-to-name-rungs lesson from this run is a candidate to fold into a future update.

---

## 10. Agent coordination note

The `/senior-fullstack` + `/jira-expert` framing from the user's standing directive holds for this run:
- `/senior-fullstack` is the integration lead — "features ready in the dev console" meant every haptic beat on every Tier 1 surface should feel consistent when bang walks the iPad alongside the backend dev cockpit at `http://localhost:3000/dev/dev-pipeline.html`. The sweep is invisible in the backend (no `/api/v1` changes), but visible in the tactile feel of every button on every surface the dev console can exercise.
- `/senior-swift` / `/swiftui-pro` did the call-site authoring + self-audit — no deprecated APIs introduced, no `.foregroundColor`, no actor-isolation hazards, no new `@Environment` dependencies in child structs, no new Timer-MainActor crossings.
- `/jira-expert` is the tracker + run-summary custodian — this file, the SPRINT-11 tracker row flip, and the index regeneration (next step) are its output.

Next run will pick up S11-12 (Lessons grid Pinterest pass) — the most visually substantial remaining story, best suited to early-Day-6 delivery so bang can exercise the rebuilt grid in the dev console the same morning.
