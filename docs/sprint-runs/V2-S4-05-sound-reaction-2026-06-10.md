# V2-S4-05 — classroom sound + reaction pass

> Slice run summary, 2026-06-10. Single slice, executed directly by the
> session lead on the Mac — build-verified locally. Reconciled against
> [`SPRINT-V2-classroom-tracker.md`](../SPRINT-V2-classroom-tracker.md).

---

## Meta

- **Slice:** V2-S4-05 (plan acceptance: "Primary object taps use consistent bounce, haptic, and small particle burst. Reduced motion removes ambient and particle effects.")
- **Agent:** session lead (Fable 5), direct execution.
- **Run window:** 2026-06-10.
- **Status:** ✅ delivered, build-verified on Mac, committed.

---

## 1. Goal restated

Tracker gap: "Bounce + haptic on object taps exist
(`ClassroomObjectButton`). Consistent particle-burst pass + reduce-motion
strip not confirmed across all surfaces." Two halves: (a) add the missing
third beat — a small particle burst on primary classroom object taps,
consistent across both render paths; (b) audit every ambient/looping
effect in the kid app for reduce-motion gating.

## 2. Files changed (153 insertions)

| File | Δ | What |
|---|---|---|
| `Views/Classroom/ClassroomObjectButton.swift` | +145 | New `ClassroomTapBurst` + private `BurstSpray` views (8 particles — 6 classroom-palette dots + 2 sparkle glyphs — radial spray, ~0.55s, deterministic layout, removed from hierarchy when idle). Wired into the shape-fallback button: tap → haptic + burst counter increment, burst overlay on the button. |
| `Views/Classroom/ClassroomIllustratedSceneView.swift` | +8 | Same burst wired into `ClassroomHotspotButton` (the illustrated render path) — identical trigger and overlay, so the reaction triple is consistent when final art lands. |

## 3. Acceptance criteria

| Criterion | Met |
|---|---|
| Primary object taps: consistent bounce | ✅ pre-existing — identical `scaleEffect(0.96)` spring in both paths. |
| Primary object taps: haptic | ✅ pre-existing — `NovaHaptics.tap()` in both paths. |
| Primary object taps: small particle burst | ✅ new — `ClassroomTapBurst`, identical in both render paths. |
| Reduce Motion removes particle effects | ✅ — the burst renders **nothing** under RM (early-return in the trigger handler). |
| Reduce Motion removes ambient effects | ✅ audited — every `repeatForever` in NovaKids checked (20 sites across 10 files): classroom halo, empty-state halo, Dashy idle bob, celebration ring, read-aloud pulse, voice-picker ring, login ambient, experiment-card affordances all RM-gated. `ClassroomSpinner` looked ungated at first read but its rotating arc only renders on the non-RM branch (static ring + tick under RM) — no change needed. |

## 4. In-plan vs drift

In-plan with two deliberate decisions:

1. **No audio SFX added.** The story title says "sound and reaction" but
   its acceptance criteria specify only bounce/haptic/burst/RM — and the
   repo has no sound-effect asset catalog (the only audio pipeline is
   TTS narration, which is the designated kid audio channel per the
   standing voice-first constraint). If bang wants tap *sounds*, that's
   a new asset-generation lane like the art catalog — flagged, not
   silently invented.
2. **`ClassroomTapBurst` lives inside `ClassroomObjectButton.swift`**
   rather than its own file: adding a new file to the NovaKids target
   requires Xcode-side pbxproj registration (project rule: new files
   via Xcode UI only; no `xcodeproj` gem on this Mac). Split it out on
   the next Xcode-open pass if preferred — it's a self-contained
   `// MARK: - Tap burst` section.

## 5. Validation

- `xcodebuild -workspace Nova.xcworkspace -scheme NovaKids … build` → **BUILD SUCCEEDED**.
- Burst is dormant-by-default (renders nothing until first tap, removes itself 650ms after) — no idle cost for V2-S4-06's perf pass to worry about.
- Device feel-check (does the spray *land* visually on hardware) folds into V2-S4-F4 per plan.

## 6. Reviewer / next-agent notes

- The burst trigger is a monotonic `Int`, not a `Bool` — rapid re-taps
  restart the spray rather than being swallowed.
- Particle layout is deterministic (fixed angle jitter table), so
  renders are stable across previews/tests; no per-tap randomness.
- The disabled-object guard runs before the burst increments — "Soon"
  objects give no reaction, matching their no-op behavior.
