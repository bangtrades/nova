# classroomV2Enabled runtime flag — V2-S1-06 debt + risk-register rollback path

> Slice run summary, 2026-06-10. Single slice, executed directly by the
> session lead on the Mac.

---

## Meta

- **Slice:** V2-S1-06 debt ("flag exists but is a hard-coded `true` literal; no runtime fallback path to the legacy grid Home") — also the risk-register row "`classroomV2Enabled` hard-`true` with no rollback".
- **Agent:** session lead (Fable 5), direct execution.
- **Run window:** 2026-06-10.
- **Status:** ✅ delivered, tested, committed.

---

## 1. Goal restated

The classroom Home shipped behind `private let classroomV2Enabled =
true` in `HomeView.swift` — recompile-only rollback. The V2 program DoD
requires "a **tested** path back to legacy Home if a blocker surfaces."

## 2. Files changed

| File | What |
|---|---|
| `Packages/NovaClassroom/Sources/NovaClassroom/ClassroomFeatureFlags.swift` | New testable resolver. Precedence: launch env `NOVA_CLASSROOM_V2` (lenient bool parsing; typos fall through rather than guessing) → persisted `nova.classroomV2Enabled.v1` UserDefaults key → shipped default `true`. New file lives in the SPM package, so no pbxproj registration needed. |
| `Packages/NovaClassroom/Tests/NovaClassroomTests/ClassroomFeatureFlagsTests.swift` | 7 tests locking the precedence contract + parser spellings. |
| `Apps/NovaKids/Sources/Views/Home/HomeView.swift` | The literal now calls the resolver; behavior identical by default. `classicHome` (still in the file) is the flag-off route. |

## 3. Acceptance criteria

| Criterion | Met |
|---|---|
| Default unchanged — classroom is the Kids Home | ✅ — resolver returns `true` with no overrides (test-pinned). |
| Runtime rollback without recompile | ✅ — `NOVA_CLASSROOM_V2=0` launch env (dev) or `defaults write … nova.classroomV2Enabled.v1 -bool NO` (installed build). |
| Path back to legacy Home **tested** | ✅ resolver contract unit-tested (7 cases); `classicHome` route compiles in the same build. Full device walkthrough of legacy Home folds into V2-S4-F4 alongside the other device checks. |

## 4. In-plan vs drift

In-plan. Deliberately **no settings UI** — NovaKids has no parent
settings surface yet (only the voice picker), and inventing one is a
product decision tied to V2-S4-04/V2-S4-08. The defaults-key escape
hatch is the hook a future parent-settings toggle writes to.

## 5. Validation

- `swift test --package-path src/Packages/NovaClassroom` → **42/42** (35 existing + 7 new).
- `xcodebuild` NovaKids → **BUILD SUCCEEDED**.

## 6. Reviewer / next-agent notes

- Read once per launch (file-private `let`) — restart-level toggle by
  design; live-swapping the Home hierarchy mid-session isn't a kid-flow
  state we support.
- V2-S4-08 (release decision) should consciously decide whether the
  flag stays long-term or the legacy grid gets deleted; this slice
  makes either ending cheap.
