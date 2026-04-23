# Swift / SwiftUI Skill Updates — Sprint 11 Lessons

**Author:** generated after S11-11 + S11-14 landed (Sprint 11 Day 5)
**Target skills:** `senior-swift`, `swiftui-pro`
**Source of truth on your Mac:** `~/.claude/skills/senior-swift/…` and `~/.claude/skills/swiftui-pro/…`

The skill directory is mounted read-only inside this sandbox, so the edits live here as copy-paste blocks + a matching unified-diff patch (`S11-swift-skills.patch`). Each change is scoped to a concrete pattern that either surfaced as a new tool or bit during Sprint 11 — no piling on generic advice.

---

## Why these five

| # | Skill | File | Change | Triggered by |
|---|-------|------|--------|--------------|
| 1 | senior-swift | `SKILL.md` | Add rule #20 — `let` / imperative statements inside `@ViewBuilder` | FlipbookHeader's chapter-color lookup, CardProgressDots' tri-state mapping |
| 2 | senior-swift | `SKILL.md` | Add "Dead-flag preservation" to Build Error Triage → Maintenance | FlipbookViewModel.isLoading stub w/ forward-reference doc comment |
| 3 | swiftui-pro | `references/design.md` | Add tap-target pattern `.contentShape` + `.frame(minWidth:44, minHeight:44)` | CardProgressDots (4×4 visual dots, 44×44 hit area) |
| 4 | swiftui-pro | `references/hygiene.md` | Add padding-collision rule for DS primitives | LoadingSkeletonView's internal 20pt padding colliding with consumer padding |
| 5 | swiftui-pro | `references/views.md` | Narrow carve-out for `@ViewBuilder private var` | LessonsView's `lessonContent` gate branch |

The five are chosen because each one either (a) was not obvious from existing rules, (b) only became clear after seeing it compile / break in a real codebase, or (c) directly contradicts an existing rule and needs reconciliation.

---

## 1. senior-swift — New Rule #20

**Insert** between current Rule #19 (Delegate Conformance on `@MainActor` Classes) and the `## SPM Package Architecture` heading.

````markdown
### 20. `let` and Other Imperative Statements Inside `@ViewBuilder` Closures

**Problem:** Assuming `@ViewBuilder` closures are expression-only and awkwardly hoisting computed values into separate properties or `.onAppear` just to avoid inline `let` bindings.

**Since Swift 5.9**, `@ViewBuilder` closures accept `let` declarations (and `if let` / `if case let` / `switch` with bindings). You can precompute values inline for the branch where they're needed, rather than computing them at a higher scope where they'd be recomputed even on branches that don't use them.

```swift
// WRONGISH — computing chapter color at the view level, even though only one
// card type needs the rainbow mapping
var body: some View {
    let chapterColor = NovaPalette.chapterColor(for: card.type) // recomputed every render
    HStack {
        if showChapterBar {
            Rectangle().fill(chapterColor)
        }
        Text(card.title)
    }
}

// CORRECT — let inside the @ViewBuilder branch that actually needs it
var body: some View {
    HStack {
        if showChapterBar {
            let chapterColor = NovaPalette.chapterColor(for: card.type)
            Rectangle().fill(chapterColor)
                .accessibilityLabel("Chapter \(card.type.displayName)")
        }
        Text(card.title)
    }
}
```

**Also valid inside `@ViewBuilder`:** `if let page = cards.current { PageView(page: page) }`, `switch state { case .loading: …; case .loaded(let items): … }`, and `if case let` unwrapping of enum associated values.

**Rule of thumb:** if a value is used in exactly one branch, declare it in that branch — don't hoist it. This keeps the body's outer scope clean, avoids recomputation on unrelated re-renders, and makes the dependency obvious when reading the branch in isolation.
````

---

## 2. senior-swift — Dead-Flag Preservation (new subsection)

**Append** a new section after `## Build Error Triage` (before `## Reference Files`). This captures a pattern we've been using but hadn't codified.

````markdown
## Preserving Forward-Referenced Flags

When a view model owns a flag that no current code path actually flips (a dead flag), the instinct is to delete it. Resist this when the flag is about to be wired up in an upcoming story — deleting it turns a one-line wiring change into a multi-file refactor.

Instead, keep the flag declared, default it to `false`, and document its forward reference in a doc comment. The comment should name the wiring point so the next person (or a future grep) can find it instantly.

```swift
// In FlipbookViewModel.swift — story S11-14 (Wire loading skeletons) landed this
// but FlipbookView doesn't yet fetch async; isLoading stays false until S12-XX
// swaps the mock-data `Card.samples` for a real LessonRepository.fetch() call.
@MainActor
public final class FlipbookViewModel: ObservableObject {
    /// Set `true` while an async card fetch is in flight. Currently always `false`
    /// because cards are seeded synchronously; will be flipped once the real
    /// `LessonRepository.fetch(for:)` replaces the in-memory `Card.samples`
    /// source (planned S12-XX).
    @Published public private(set) var isLoading = false
    …
}
```

The doc comment must answer two questions: **why it's currently dead** (what's stubbed) and **what will light it up** (story/PR that replaces the stub). Without that, a future reader correctly assumes it's unused and removes it.

This pattern is preferable to both (a) deleting and re-adding later — the re-add is now scattered across VM + view + tests — and (b) adding an inline `// TODO: wire this up` without context, which decays into noise.
````

---

## 3. swiftui-pro — Tap-Target Pattern in `references/design.md`

**Append** to the end of the "Requirements for flexible, accessible design" section (after the existing 44×44 bullet on line 12). Keeps the rule where it already lives; extends it with the actual mechanism.

````markdown
- When a visual target must stay small (e.g. a 4pt progress dot, a 16pt icon badge), don't scale up the visual — scale up the hit region. Use `.contentShape(…)` to declare the hit geometry and `.frame(minWidth: 44, minHeight: 44)` to guarantee the minimum tap area. The visual stays small; the touch region meets HIG.

  ```swift
  // Small visual dot, generous hit region
  Circle()
      .fill(isCurrent ? NovaPalette.coral : NovaPalette.ink)
      .frame(width: 4, height: 4)               // visual
      .frame(minWidth: 44, minHeight: 44)       // hit-region guarantee
      .contentShape(Circle())                   // hit-shape matches the visual
      .onTapGesture { onTap() }
  ```

  The outer frame provides the minimum size; `.contentShape` defines which pixels of that frame actually respond to taps (without it, SwiftUI treats only the filled circle pixels as tappable, not the transparent padding). This keeps VoiceOver, Switch Control, and fat-finger reliability intact without visual bloat.
````

---

## 4. swiftui-pro — Padding Collision Rule in `references/hygiene.md`

**Append** as a new bullet. This caught us twice during S11 — once when LoadingSkeletonView's internal 20pt padding was doubled by consumers adding their own, once the opposite when consumers relied on DS-internal padding that wasn't actually there.

````markdown
- Design-system primitives that declare their own internal padding (e.g. `LoadingSkeletonView` with a built-in 20pt edge padding, `NovaCard` with built-in 16pt) must document that padding in the type's doc comment, and consumers must not re-wrap them in outer padding. When integrating a DS primitive, check the type's doc comment or source for an `.padding(…)` inside its body — if present, the consumer supplies layout only (alignment, stack spacing), never padding. The DS primitive owns its internal whitespace. Doubling padding produces a subtle visual regression that reads as "the layout is off" without an obvious cause, and is easy to miss in review because both sides look individually correct.
````

---

## 5. swiftui-pro — `@ViewBuilder` Computed-Property Carve-Out in `references/views.md`

Currently the file says (twice, for emphasis):

> Strongly prefer to avoid breaking up view bodies using computed properties or methods that return `some View`, even if `@ViewBuilder` is used. Extract them into separate `View` structs instead, placing each into its own file.

That rule is right as a default. But there's a narrow case where extraction into a struct is strictly worse: a body-level `if isLoading { skeleton } else { content }` gate where the `else` branch reads 4+ properties from the enclosing view/VM. Extracting the `else` branch forces all 4+ properties through the child struct's `init`, re-exposing private state as the child's public surface.

**Replace** the repeated rule on line 15 (the one that ends "Yes, this is repeated, but it's so important it needs to be mentioned twice.") with a carve-out that keeps the rule's force but acknowledges the exception:

````markdown
- Strongly prefer to avoid breaking up view bodies using computed properties or methods that return `some View`, even if `@ViewBuilder` is used. Extract them into separate `View` structs instead, placing each into its own file. (Yes, this is repeated, but it's so important it needs to be mentioned twice.)

  **Narrow carve-out — loading gates:** if the only reason you'd extract is to wrap a branch in `if isLoading { LoadingSkeletonView(…) } else { <main content> }`, and the `<main content>` branch reads 4+ properties from the enclosing view or view model, a `@ViewBuilder private var mainContent: some View` is acceptable. Extracting to a child struct would require forwarding those 4+ properties through the child's `init`, which re-exposes private state as the child's public API surface. Keep the gate as a view-level branch; extract the leaf content (e.g. `LessonRow`) into its own file as normal. This carve-out does **not** apply to larger decompositions (headers, toolbars, sidebars) — those always extract.

  ```swift
  // ACCEPTABLE — loading gate stays as @ViewBuilder; reads 5 VM bindings
  struct LessonsView: View {
      @StateObject private var viewModel = LessonsVM()
      @State private var searchText = ""
      @State private var selectedFilter: Filter = .all
      @State private var showArchived = false

      var body: some View {
          NavigationStack {
              if viewModel.isLoading {
                  LoadingSkeletonView(itemCount: 6, isGrid: false)
              } else {
                  lessonContent
              }
          }
      }

      @ViewBuilder
      private var lessonContent: some View {
          // Reads: viewModel.filtered, searchText, selectedFilter, showArchived,
          // viewModel.refresh(). Extracting would require 5 init params.
          List(viewModel.filtered(searchText, selectedFilter, showArchived)) { lesson in
              LessonRow(lesson: lesson)        // ← LessonRow IS extracted
          }
          .searchable(text: $searchText)
          .refreshable { await viewModel.refresh() }
      }
  }
  ```
````

---

## Applying the patch

Two options:

**(a) Unified diff.** `S11-swift-skills.patch` in this folder contains the edits formatted as a standard diff. From the directory that contains the skill tree (on your Mac that's likely `~/.claude/skills/`), run:

```bash
cd ~/.claude/skills
patch -p1 < /path/to/Novai/docs/skill-updates/S11-swift-skills.patch
```

**(b) Copy-paste.** Open each of the four target files in your editor and paste the blocks from this proposal. Order doesn't matter; each edit is independent.

After applying, `grep "Rule 20\|Dead-Flag\|contentShape\|Padding Collision\|carve-out" ~/.claude/skills` should return five distinct hits, one per change.

---

## What I deliberately did not add

For the record, these were considered and cut to keep the updates tight:

- **"Paint only, not rigging" invariant** — this is a Sprint 11 process rule (scope-management), not a Swift rule. Belongs in the Sprint-runner skill or a project CLAUDE.md, not in senior-swift.
- **pbxproj 4-location surgery** — niche enough that the existing senior-swift intro ("grep the codebase") covers it; a dedicated rule would be brittle as Xcode evolves.
- **Mock-data 400ms `Task.sleep` for skeleton visibility** — already covered implicitly by the existing async/defer rule; adding a specific timing would ossify a knob that should stay tunable.
- **Optional typed-domain param vs synthetic `.unknown` enum case** — showed up once in Sprint 11; not yet a pattern, more an instance. Revisit if it happens again.
- **`isLoading = true / defer { isLoading = false }`** — already idiomatic Swift and covered by existing concurrency rules; codifying it risks reading as "thou shalt write this one way."

If any of these want a home later, they can be added individually; for now the update stays focused on the five that paid compounding interest across S11.
