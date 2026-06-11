# V2-S4-F2 completion — kid-safe error states + empty-state registry wiring

> Slice run summary, 2026-06-10. Single slice, executed directly by the
> session lead (no agent dispatch) on the Mac — build-verified locally.
> Reconciled against [`SPRINT-V2-classroom-tracker.md`](../SPRINT-V2-classroom-tracker.md).

---

## Meta

- **Slice:** V2-S4-F2 follow-up (the carry-debt row "F2 error states + remaining `*Empty` registry cases").
- **Agent:** session lead (Fable 5), direct execution.
- **Run window:** 2026-06-10.
- **Status:** ✅ delivered, build-verified on Mac, committed.
- **Plan of record:** `docs/SPRINT-V2-classroom-tracker.md` → V2-S4-F2 + Carry-debt.

---

## 1. Goal restated

Close the gap the May 22 batch left open: V2-S4-F2 ("kid-safe fallback /
error copy") covered only the bookshelf empty state. Error states across
all kid surfaces still showed raw `APIError.errorDescription` text —
technical, adult copy a pre-literate 4-year-old can't read — and were
never voiced. The `homeEmpty` / `lessonsEmpty` / `trophyRoomEmpty`
registry lines existed in `NavigationScript` but were wired to no view.

## 2. Files changed (80 insertions, 12 deletions)

| File | Δ | What |
|---|---|---|
| `Services/NavigationNarrator.swift` | +28 | 7 new registry cases (`homeError`, `lessonsError`, `trophiesError`, `cardsError`, `classroomError` generic fallback, `lessonNotFound`, `comingSoon`) + `NavigationScript.errorLine(forContext:)` resolver. |
| `Views/Common/ClassroomErrorBanner.swift` | +37/−7 | The shared banner now **displays** the kid-safe registry line (resolved from its existing `context` param) instead of the technical message, **narrates** it on appear via the standard `.narrate(_:)` pipeline (60s cooldown keyed `"\(context)Error"`, mute-respecting), and keeps the technical message in the VoiceOver announcement for grown-ups. Zero call-site signature changes — all 5 existing call sites (Home ×2, Lessons, Trophies, Flipbook) got kid-safe + voiced for free. Preview injects the narrator env object. |
| `Views/Home/HomeView.swift` | +6 | `.narrate("homeEmpty")` on the no-lesson-ready destination, `.narrate("lessonNotFound")` on the lesson-missing destination, `.narrate("comingSoon")` on the placeholder destination. |
| `Views/Lessons/LessonsView.swift` | +4 | `.narrate("lessonsEmpty")` on the empty masonry grid (distinct key from `"lessons"` so the kid hears the why-it's-empty line). |
| `Views/Trophies/TrophyRoomView.swift` | +17/−5 | Entry narration is now state-conditional: `trophyRoomEmpty` when the completion store has no trophies for the active child, `trophyRoom` otherwise. Keyed on the synchronous local store — no async badge fetch to race. |

## 3. Acceptance criteria (from tracker carry-debt row)

| Criterion | Met |
|---|---|
| Error states reviewed for kid-safe copy | ✅ — all 5 `ClassroomErrorBanner` call sites now display registry kid lines; raw `errorDescription` no longer reaches the kid surface (preserved for VoiceOver detail). |
| Error states voiced | ✅ — banner narrates on appear, per-context cooldown keys, mute/persona handling inherited from the standard pipeline. |
| `homeEmpty` registry case wired | ✅ — chalkboard-tap-with-no-lesson destination. |
| `lessonsEmpty` registry case wired | ✅ — empty lessons grid. |
| `trophyRoomEmpty` registry case wired | ✅ — trophy room with zero earned trophies. |

## 4. In-plan vs drift

In-plan, one design decision worth flagging: rather than editing 5 call
sites to pass kid-safe strings, the kid-safe resolution was centralized
**inside** `ClassroomErrorBanner` (display line = registry lookup on the
`context` param it already receives). This matches the banner's own
documented rationale ("a single change propagates everywhere") and means
future surfaces are kid-safe + voiced by default — a new context without
a bespoke line falls back to the generic `classroomError` line rather
than to silence. Two small additive registry cases (`lessonNotFound`,
`comingSoon`) went beyond the three named `*Empty` cases because those
two HomeView fallback surfaces were silent and the standing constraint
is "every kid-mode error/empty state must be voiced."

The dead `EnhancedHomeView` (carry-debt, preview-only) was deliberately
not touched — it inherits the banner fix for free anyway.

## 5. Validation

- `xcodebuild -workspace Nova.xcworkspace -scheme NovaKids -destination 'generic/platform=iOS Simulator' build` → **BUILD SUCCEEDED**, zero new warnings on touched files.
- No automated UI test exists for narration triggers (pre-existing gap — `NavigationNarrator` has no test target); validation is build + code-path review. A device pass folds into V2-S4-F4 (post-art verification) per plan.

## 6. Reviewer / next-agent notes

- The banner still **accepts** the technical `message:` param unchanged —
  callers don't need migration, and the string surfaces in the VoiceOver
  label as "Details: …". If a future slice adds parent-facing
  diagnostics, that param is the hook.
- Cooldown semantics: an error banner that stays on screen across a
  retry loop re-narrates at most once per 60s per surface; a *different*
  surface's error speaks immediately. This is the same global timeline
  every Tier 1 line shares.
- `trophiesError` (not `trophyRoomError`) is the registry key because
  the banner's existing context string is `"trophies"`.
