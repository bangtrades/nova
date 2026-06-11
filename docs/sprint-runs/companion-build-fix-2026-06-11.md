# NovaCompanion build fix — scheme builds for the first time

> Slice run summary, 2026-06-11. Single slice from carry-debt
> (discovered during the VOX-02 triage), executed directly by the
> session lead.

---

## Meta

- **Slice:** carry-debt row "NovaCompanion scheme does not build".
- **Agent:** session lead (Fable 5), direct execution.
- **Run window:** 2026-06-11.
- **Status:** ✅ delivered — `xcodebuild -scheme NovaCompanion` → **BUILD SUCCEEDED**. Evidence says this is the first time the scheme has ever compiled (the first defect dates to the initial commit).

---

## 1. What was found (7 defects, peeled in build-error layers)

| # | File | Defect |
|---|---|---|
| 1 | `Views/Common/CompanionPalette.swift` | Brand colors aliased into `NovaPalette` — a type compiled only into the NovaKids target. **Broken since the initial commit.** Fixed by inlining the six color values verbatim (with a local light/dark dynamic-color helper preserving dark-mode behavior); re-alias if the palette ever moves to a shared package. |
| 2 | `Views/Pipeline/URLIntakeView.swift` | `#Preview` closure contained a local type declaration + trailing expression — not a single View-building expression, so the macro had "no exact matches". Mock hoisted to file scope. |
| 3 | `Views/Editor/CardPreviewView.swift`, `LessonPreviewView.swift` | Direct `NovaPalette.*` references (fonts + brand colors + background). Remapped to `CompanionPalette` (new `smallHeadingFont()` added; `novaBackground` → `companionBackground`). |
| 4 | `Views/Editor/CardListSidebar.swift` | `.onMove` mutated the immutable `if let` shadow of a `@Binding` — rebuilt via a local copy written back through the binding. |
| 5 | `Views/Settings/OAuthFlowView.swift` | Retry button assigned `nil` to the `if let` shadow of `errorMessage` — now writes `self.errorMessage`. Same shadowing class as #4. |
| 6 | `ViewModels/LessonManagerViewModel.swift` | Six mock `Lesson(...)` inits with `userId:`/`pathId:` in the wrong order (scripted swap). |
| 7 | `Views/Auth/LoginView.swift` | Called `authManager.handleAppleSignIn(credential:)` — a method that **never existed** on AuthManager. Rewired to the real (post-contract-fix) `signInWithApple(appleId:identityToken:displayName:email:)` with proper credential extraction, mirroring the kid app's login. |
| +1 | `Views/Lessons/LessonManagerView.swift` | `.sheet(isPresented:item:)` — not a SwiftUI API → item-driven `.sheet(item:)`. |
| +1 | `Views/Settings/ChildProfileView.swift` | `Section("…", footer:)` — not a SwiftUI initializer; the bad expression type-collapsed the whole `Form` into the misleading "FormStyleConfiguration" diagnostic → `Section(header:footer:)`. |

The mix (phantom APIs, never-compiled aliases, invalid initializers)
indicates the Companion surface was authored without ever running its
build — consistent with the audit's finding that nobody builds this
scheme.

## 2. Validation

- `xcodebuild -workspace Nova.xcworkspace -scheme NovaCompanion … build` → **BUILD SUCCEEDED** (was failing on the first file it compiled).
- NovaKids unaffected — zero shared-code changes in this slice (all edits under `Apps/NovaCompanion/`).
- No Companion test target exists (pre-existing gap, now *possible* to add since the target compiles).

## 3. In-plan vs drift

In-plan ("make the scheme build"), with the smallest-correct fix at
each layer — no redesigns. The shared-design-tokens package idea was
deliberately NOT pursued (it needs an Xcode-side product-linking step,
i.e. bang-gated); the inline palette keeps this slice self-contained
and the comment marks the re-alias point.

## 4. Reviewer / next-agent notes

- The Companion app now *compiles*; it has never been *run*. Treat it
  as untested UI — a Companion smoke pass (launch, tab through, author
  a lesson against the local backend) is the natural follow-up when
  the parent surface becomes a priority.
- CompanionPalette's inlined colors will drift from NovaPalette if the
  brand palette changes — the file header says where they came from.
