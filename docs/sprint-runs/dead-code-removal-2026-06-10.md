# Dead-code removal — classroomCardStage + EnhancedHomeView

> Slice run summary, 2026-06-10. Single slice from the V2 tracker's
> carry-debt table / program Definition of Done, executed directly by
> the session lead on the Mac.

---

## Meta

- **Slice:** carry-debt rows "`classroomCardStage` dead code" (V2-S3 rework) + "`EnhancedHomeView` orphaned" (V2-S2).
- **Agent:** session lead (Fable 5), direct execution.
- **Run window:** 2026-06-10.
- **Status:** ✅ delivered, build-verified, committed.

---

## 1. Goal restated

Two acknowledged-dead surfaces left by the V2 reworks: the
`classroomCardStage` card container in `FlipbookView` (superseded by
`LessonBookReaderShell` in the S3 mid-sprint rework, never called
since) and `EnhancedHomeView` (orphaned when the live Home moved to
`ClassroomSceneView`; referenced only by its own `#Preview`, carrying a
dead `.narrate("home")` call site).

## 2. Files changed

| File | What |
|---|---|
| `Views/Flipbook/FlipbookView.swift` | `classroomCardStage` (−78 LOC) deleted. Verified zero call sites before removal. |
| `Views/Home/EnhancedHomeView.swift` | Deleted (git rm). Zero non-comment references outside its own `#Preview`. |
| `Nova.xcodeproj/project.pbxproj` | The 4 `EnhancedHomeView` entries removed by script (build file, file reference, group child, sources-phase entry). Within the project's pbxproj rule — "trivial file-removal of non-`+` names" is the allowed hand-edit case. |
| `ViewModels/HomeViewModel.swift`, `DesignSystem/NovaNavigationStyle.swift` | Three stale doc-comment references to the deleted view rewritten so the docs don't point at a ghost. |

## 3. Acceptance criteria

| Criterion (program DoD) | Met |
|---|---|
| "`classroomCardStage` dead code removed" | ✅ |
| `EnhancedHomeView` orphan removed | ✅ (bonus on the same theme — it was the adjacent carry-debt row) |
| Build green after removal | ✅ `xcodebuild` BUILD SUCCEEDED |

## 4. In-plan vs drift

In-plan. The pbxproj was hand-edited (scripted line filter, asserted
exactly 4 lines) rather than via Xcode UI — this is the explicitly
permitted case in the project rule (trivial removal, no `+` in name),
and the build verifies the project file still loads.

## 5. Validation

- `xcodebuild … build` → **BUILD SUCCEEDED**.
- `grep -rn "classroomCardStage\|EnhancedHomeView" src/Apps --include="*.swift"` → zero hits post-change.

## 6. Reviewer / next-agent notes

- The dead `.narrate("home")` call site went down with
  `EnhancedHomeView`; the live classroom Home narrates via
  `ClassroomDashyGuideLayer` (`classroomHome` script), unchanged.
- `WorkbookNavDirection` and the other `FlipbookView` helpers adjacent
  to the deleted function are live — only the stage container was dead.
