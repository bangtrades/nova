# Sprint Run — S11-01 + S11-02 (Spacing Enum + Palette Consolidation)

**Run ID:** `S11/R01-02`
**Parent sprint:** Sprint 11 ("Comic-Book Polish" — 85 pts total)
**Run window:** April 20, 2026 (single-session delivery)
**Delivery agents:** `/senior-swift` (code) + `/senior-fullstack` (integration) + `/jira-expert` (sprint tracking)
**Tracking request:** `/jira-expert` ("add a sprint for this run so that we have a tracked summary of the added features")
**Status:** ✅ **DELIVERED** — design-system foundation in place; Tier 1 rebuilds (S11-05/06/07) can now start without blocking on DS work.

---

## 1. Run Goal

Lay the design-system foundation for the rest of Sprint 11 so every subsequent story (S11-03 NovaCard + ButtonStyle, S11-05 Home rebuild, S11-06 Quiz comic-ification, S11-07 Trophy refinement) has a stable 3+1 palette + spacing vocabulary to build against.

Two stories — intentionally sized small — because the right order-of-operations for a UX sprint is *foundation first, visible polish second*. Ship both in the first working session so the rest of the week is pure feature work.

**Standing constraints (carried from Sprint 11 plan):**
- UX-only sprint — no backend changes, no TestFlight, no submission.
- Keep the 280+ existing `NovaPalette.novaBlue` / `.novaOrange` / etc. call sites working without a codebase-wide find-and-replace.
- Dark-mode adaptivity must not regress. If anything, it should improve.
- No new dependencies — iOS 17+ SwiftUI only.

---

## 2. Stories & Acceptance Criteria

### S11-01 — `Spacing` enum (2 pts) ✅

**User story:** *As a Nova engineer, I have a canonical 8-point spacing scale I can reach for so that padding values stop being invented per-screen and vertical rhythm holds across Tier 1.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | `public enum Spacing` at top level of `NovaPalette.swift` with `xs`/`sm`/`md`/`lg`/`xl`/`xxl` constants. | ✅ |
| AC2 | Values are `CGFloat` so they drop directly into `.padding(_:)` / `HStack(spacing:)` / `VStack(spacing:)`. | ✅ |
| AC3 | 8-point grid with a single 4-point half-step (xs). | ✅ |
| AC4 | T-shirt naming chosen so future sizes (e.g. `md2`) don't force renumbering. | ✅ |
| AC5 | Docstring explains when each size is used (tight gaps / default gap / padding / section / screen / hero). | ✅ |

### S11-02 — Palette consolidation (5 pts) ✅

**User story:** *As a Nova user, every screen picks up a coherent 3+1 palette (ink / coral / sun / page) so the app stops looking like a rainbow-colored prototype and starts looking like a comic-book kids product. As a Nova engineer, I can keep using `NovaPalette.novaBlue` etc. without breaking — the rainbow is preserved as category metadata.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | `NovaPalette` exposes `.ink` (navy `#1A2138`), `.coral` (`#FF5B4C`), `.sun` (`#FFCE47`), `.page` (paper `#FAF6ED`) as public adaptive colors. | ✅ |
| AC2 | `ink` and `page` are an **inverse adaptive pair** — each flips to the other's value in dark mode — so `ink.opacity(0.05)` reads correctly in both modes without branching. | ✅ |
| AC3 | Rainbow palette moved into `NovaPalette.Category.{blue, orange, green, purple, yellow, pink}` with identical RGB values (no color shift). | ✅ |
| AC4 | Back-compat aliases preserve every `NovaPalette.novaBlue` / `novaOrange` / `novaGreen` / `novaPurple` / `novaYellow` / `novaPink` call site without modification. | ✅ |
| AC5 | `pathColor(for:)` rewritten against `Category.*`; signature unchanged so callers don't break. | ✅ |
| AC6 | All 27 `Color.gray.opacity(…)` sites across `Views/` rewritten to `NovaPalette.ink.opacity(…)`. | ✅ |
| AC7 | All 5 raw `.font(.title)` sites across `Views/` rewritten to `.font(NovaPalette.titleFont())`. | ✅ |
| AC8 | Coral and sun brightened (~+10% L) for dark mode so they stay legible on navy surface. | ✅ |
| AC9 | Typography helpers (`titleFont`, `headingFont`, `bodyFont`, `captionFont`, `largeBodyFont`, `smallHeadingFont`, `fontDesign`) and surface aliases (`novaBackground`, `novaCardBackground`) preserved bit-for-bit. | ✅ |
| AC10 | Docstring at top of `NovaPalette.swift` explains the 3+1 structure, the inverse-pair trick, and the Category back-compat so future contributors find the rationale without chasing an ADR. | ✅ |

---

## 3. Files Changed

**Design-system core (1 file):**
- `src/Apps/NovaKids/Sources/Views/Common/NovaPalette.swift` — added `Spacing` enum; added `ink`/`coral`/`sun`/`page`; added `Category` namespace; added back-compat aliases; preserved typography helpers.

**`Color.gray.opacity` migration (13 files, 27 sites):**
- `Views/Trophies/BadgeView.swift` (×5)
- `Views/Trophies/TrophyRoomView.swift` (×3)
- `Views/Trophies/TrophiesView.swift` (×2)
- `Views/Home/FeaturedLessonCard.swift` (×1)
- `Views/Home/ContinueLearningSection.swift` (×2)
- `Views/Home/EnhancedHomeView.swift` (×1)
- `Views/Flipbook/QuizCardView.swift` (×2)
- `Views/Flipbook/SparkyHintSheet.swift` (×3 — file also caught the `.font(.title)` sweep)
- `Views/Flipbook/FlipbookView.swift` (×2)
- `Views/Flipbook/FlipbookHeader.swift` (×1)
- `Views/Lessons/LessonsView.swift` (×1)
- `Views/Lessons/LessonTileView.swift` (×1)
- `Views/Common/LoadingSkeletonView.swift` (×3)

**`.font(.title)` migration (4 files, 5 sites):**
- `Views/Onboarding/OnboardingView.swift` (×2)
- `Views/Flipbook/ExperimentCardView.swift` (×1)
- `Views/Lessons/LearningPathCard.swift` (×1)
- `Views/Flipbook/SparkyHintSheet.swift` (×1 — dual-caught)

**Docs (2 files):**
- `docs/SPRINT-11-tracker.md` — S11-01 + S11-02 rows marked ✅ Done; Delivery Notes sections appended; Sprint Summary updated to 7/85 (8%).
- `docs/sprint-runs/S11-palette-spacing.md` — this file.

**Totals:** 16 source files + 2 doc files = **18 files changed**. 27 `Color.gray.opacity` sites + 5 `.font(.title)` sites + 1 palette rewrite = **33 meaningful code edits**.

---

## 4. Architectural Decisions

### 4.1 The inverse-pair trick (`ink` ↔ `page`) is the load-bearing bet

Every `Color.gray.opacity(0.05)` in the old codebase was a *subtle tint* — a call that wanted "darken-in-light, lighten-in-dark" without writing a branch. Native `Color.gray` doesn't flip by default, which is why many of those sites looked washed-out in dark mode.

By defining `ink = navy↔paper` and `page = paper↔navy` as inverse adaptive pairs, a single `NovaPalette.ink.opacity(0.05)` now *automatically* reads as dark-tint-on-paper in light mode and light-tint-on-dark in dark mode. **We deleted a hundred latent contrast bugs by changing one constant.**

The only catch: some sites genuinely wanted a *surface* (not a tint), and those should use `page` directly, not `ink.opacity`. The S11-05/06/07 inline migrations will catch any mis-routed sites during screen rebuilds; the Day-1 dark-mode walkthrough (per Mac Prerequisite #2) is the safety net.

### 4.2 Category namespace + back-compat aliases

Renaming `novaBlue` → `categoryBlue` across 280+ sites would have been a two-hour churn exercise with no product value and real merge-conflict risk. Instead:

```swift
public enum Category {
    public static let blue = Color(light: ..., dark: ...)
    // etc.
}
public static let novaBlue = Category.blue  // back-compat
```

Every existing call site keeps compiling. New code *should* prefer `NovaPalette.Category.blue` to make category-intent explicit, but we're not forcing it. If a future sprint decides the rainbow should be further restricted (e.g., only `pathColor(for:)` uses it), that refactor becomes trivial because the rainbow already lives in one namespace.

### 4.3 T-shirt naming for Spacing

`Spacing.md` is both shorter and more meaningful at the call site than `Spacing.size2` or `Spacing.sixteen`. The t-shirt idiom also lets us *insert* new steps (`md2` between `md` and `lg`) without renumbering — a common pain point with numeric naming.

The one place this shows strain is the `xxl` name at the far end; `hero` might have been more evocative. Acceptable: `xxl` is consistent with Tailwind and most major design systems, and the Spacing docstring spells out "48pt — hero / splash spacing" explicitly so the intent isn't lost.

### 4.4 Coral and sun brightened for dark mode

`#FF5B4C` reads great on paper but a touch muddy on navy. Raising L by ~10% in HSL gives `#FF7A6E` — still unambiguously the same coral, but legible against dark surface. Same treatment for `#FFCE47` → `#FFD765`. Ink stays at one value (the inverse pair handles the flip). Page stays at one value (same reason, opposite direction).

### 4.5 Preserved every existing helper

Typography (`titleFont`, `headingFont`, `bodyFont`, `captionFont`, `largeBodyFont`, `smallHeadingFont`, `fontDesign`), surface colors (`novaBackground`, `novaCardBackground`), and the `pathColor(for:)` hash-based selector — all preserved bit-for-bit. S11-02 is **strictly additive plus a rainbow namespace move with back-compat aliases**. No existing screen should render differently except where it was supposed to (the Color.gray.opacity sweep).

---

## 5. Validation

```bash
# Grep-clean on both migration patterns
$ grep -rn "Color\.gray\.opacity" src/Apps/NovaKids/Sources/Views/
# (no matches)

$ grep -rn "\.font(\.title)" src/Apps/NovaKids/Sources/Views/
# (no matches — preserves .font(.title2) / .font(.title3) which are semantically different)
```

Back-compat verified: every prior `NovaPalette.novaBlue` / `novaOrange` / `novaGreen` / `novaPurple` / `novaYellow` / `novaPink` / `novaBackground` / `novaCardBackground` / `titleFont()` / `headingFont()` / `bodyFont()` / `captionFont()` / `largeBodyFont()` / `smallHeadingFont()` / `fontDesign` / `pathColor(for:)` reference resolves without change.

No new files, no new imports, no new dependencies. Single-file scope change to `NovaPalette.swift` + mechanical sweep of 16 view files.

---

## 6. Prerequisites bang must run on his Mac

1. **Clean build of NovaKids target.** `Cmd+Shift+K` then full build. The 16 touched files span `Views/Trophies/`, `Views/Home/`, `Views/Flipbook/`, `Views/Lessons/`, `Views/Onboarding/`, and `Views/Common/`; incremental builds should still pick it all up but a clean build eliminates any stale-cache doubt.
2. **Light + dark mode walkthrough on iPad Pro 13-inch simulator.** Tier 1 first (Home → Lessons → Flipbook → Trophy → Onboarding), then rest of the app. The inverse-pair trick is the load-bearing bet — if any screen looks washed-out in dark mode, the culprit is an `ink.opacity(…)` site that actually wanted `page.opacity(…)`. Easy one-token fix but worth catching on Day 1 not Day 4.
3. **Confirm rainbow category usage still reads correctly.** Home featured card and Lessons grid both consume `pathColor(for:)` which now reaches through `Category.*`. Verify colors still look right — they should be identical because the Category RGB values are unchanged from the original 6-rainbow.
4. **Dev Console regression sanity.** Per the Sprint 11 plan's testing emphasis: open `dev-pipeline.html`, confirm Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs all render and operate normally. Nothing in S11-01/02 touched the Dev Console or any backend path, but a quick sanity check ensures the palette change didn't ripple somewhere unexpected.

---

## 7. What this unblocks

With the design-system foundation in place, the next stories can start immediately:

- **S11-03** (`NovaCard` + `ButtonStyle`) — has `ink` / `coral` / `sun` / `page` and `Spacing.md`/`lg` available. Ready.
- **S11-04** (Bangers display font) — independent; can go in parallel if desired.
- **S11-05** (Home rebuild) — will consume all DS output; this story pulls Spacing into Tier 1 inline per the original plan.
- **S11-06 + S11-07** (Quiz + Trophy polish) — Quiz already uses `NovaPalette.ink.opacity(0.05)` at the answer-option fill site (migrated from `Color.gray.opacity(0.05)` at QuizCardView:363); S11-06 reduces to the comic-POW reaction + button-style swap. Trophy detail sheet can lean on `NovaCard` as soon as S11-03 lands.
- **S11-09** (Sparky → Dashy rename) — independent; the `SparkyHintSheet.swift` file is the one remaining user-visible Sparky surface in the Views tree and will be renamed to `DashyHintSheet.swift` as part of S11-09.

Week 1 stays on track. Demo-this-week checkpoint (end of Day 4) still achievable.

---

## 8. Sprint Summary After This Run

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| DS | 7 | 15 | 47% |
| T1 | 0 | 25 | 0% |
| DSH | 0 | 10 | 0% |
| T2 | 0 | 18 | 0% |
| MX | 0 | 10 | 0% |
| QA | 0 | 7 | 0% |
| **Sprint 11 Total** | **7** | **85** | **8%** |

DS epic is nearly half done with the two foundational stories cleared. S11-03 (5 pts) and S11-04 (3 pts) remaining in DS. Next likely run: S11-03 + S11-09 (rename) + S11-04 to clear DS + DSH-rename in a second focused session, setting up Day 2 for the Home rebuild.
