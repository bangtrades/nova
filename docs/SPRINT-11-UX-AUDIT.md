# Sprint 11 — UX Audit (NovaKids iPad)

**Date:** 2026-04-19
**Scope:** Pre-sprint audit of the NovaKids iPad app to scope a 2-week UX-polish sprint.
**Context:** Demo to stakeholders this week in-person (path (a) — bang holding the iPad, Mac on same wifi, Xcode-built). No TestFlight, no submission work, no infra. Sprint 11 is UX polish only.

## TL;DR

The app is further along visually than the prior reassessment suggested. A real design system exists (`NovaPalette.swift`), rich animation vocabulary is already in place (44 `withAnimation` calls), and several screens — Quiz cards, Trophy room, Flipbook transitions — are genuinely polished. What's missing is *consistency*. The same codebase has a solid palette sitting next to 27 places where `Color.gray.opacity(…)` sneaks in, and a rounded typography helper sitting next to 5 raw `.font(.title)` calls. Sprint 11 is a unification sweep plus targeted uplift on the 5-6 screens that carry the demo.

Realistic solo-dev work: **~60 hours over 2 weeks**. Demo-this-week subset (Tier 1 only): **~20 hours over 3-4 focused days**.

## What exists

**38 SwiftUI view files** across 8 functional areas:

| Area | Files | Polish level |
|---|---|---|
| Auth | 1 (`KidsLoginView`) | Polished — animated gradient bg, branded logo, proper states |
| Onboarding | 2 (`OnboardingView`, `AgeGateView`) | Polished — 4-page flow, avatar picker, confetti, haptics |
| Home | 4 | **Partial** — header + stats styled, featured card basic, continue-learning minimal |
| Lessons grid | 4 | **Partial** — masonry works, tiles styled, filter pills need work |
| Flipbook cards | 9 (Story / Concept / Experiment / Quiz / Voice + chrome) | Polished — asymmetric transitions, progress dots, per-type layouts |
| Sparky chat | 2 | **Partial** — character skeleton, chat bubbles unstyled, progress bar basic |
| Trophy room | 3 | Polished — stat cards, 3-col badge grid, detail sheet w/ progress |
| Common utilities | 9 | Mature — empty/error/loading/offline/accessibility views all exist |

## Design system state — present, mature foundation

**`NovaPalette.swift`** is the single source of truth:
- 6 brand colors (blue, orange, green, purple, yellow, pink) with light/dark adaptation
- Background and card surfaces with dark-mode handling
- 5 typography helpers (`titleFont`, `headingFont`, `bodyFont`, `largeBodyFont`, `smallHeadingFont`) using Dynamic Type + `.fontDesign(.rounded)`
- Path-to-color mapping for learning path theming

**What's missing from the design system:**
- No `Spacing` enum / no 8-point grid — padding numbers are ad-hoc (8, 10, 12, 14, 16, 20, 24, 32, 40, 48 scattered across 63+ sites)
- No shared `Card` container — each view rolls its own
- No unified `ButtonStyle` — buttons are built inline
- No `Assets.xcassets` content — Resources folder is empty, everything relies on SF Symbols (fine for now)
- No custom fonts — SF Rounded only (which is actually great for a kids app — defer indefinitely)

## Top 5 prototype tells

1. **Default `Color.gray` leaking through the palette** — 27 sites. Biggest offender: `QuizCardView` line 363 uses `Color.gray.opacity(0.05)` for unselected button background. Should be a nova brand tint. Files: `QuizCardView`, `LessonsView`, `FlipbookView` button rows.

2. **Ad-hoc spacing everywhere** — 63+ inline padding values with no shared scale. Same vertical rhythm looks different on every screen.

3. **Raw `.font(.title)` bypassing NovaPalette** — 5 sites. Onboarding has two, plus `ExperimentCardView`, `LearningPathCard`, `SparkyView` header. These break the rounded-font consistency.

4. **Loading states exist but aren't wired.** `HomeViewModel.isLoading` is `@Published` but never actually toggled during fetch (mock data only). `LessonsView` has no skeleton applied even though `LoadingSkeletonView` is in the codebase. Real data fetch → pops in with no loader.

5. **Navigation bar inconsistency.** Some screens `.navigationTitle(…, displayMode: .inline)`, others use default. No custom toolbar styling. On iPad landscape this shows as inconsistent title sizes and chrome.

## Priority screens for the demo

### Tier 1 — stakeholder-facing, cut here first (~15 hrs)
1. **Home screen** (6-8 hrs) — WelcomeHeader with avatar+name, featured lesson card with thumbnail gradient, Continue-Learning with real progress bar
2. **Quiz card** (2-3 hrs) — already near-polished; swap gray fallbacks for nova tints, apply spacing scale
3. **Trophy/badge detail sheet** (3-4 hrs) — refine spacing, typography, iconography consistency

### Tier 2 — noticeable uplift (~12 hrs)
4. **Flipbook navigation chrome** (2-3 hrs) — previous/next buttons, progress dots, header
5. **Lessons grid + filter pills** (3-4 hrs) — tile depth (shadows, hover on iPad), filter pill consistency
6. **Sparky chat** (4-5 hrs) — chat bubbles, suggestion pills, progress bar styling

### Tier 3 — supporting (~5 hrs if time)
7. **Auth login** (1-2 hrs) — tighten floating shapes animation, button styling
8. **Onboarding flow** (2-3 hrs) — avatar grid spacing, Sparky animation smoothness

## The unification sweep (~12 hrs, pervasive)

This is the single biggest lever. Rather than doing it as a separate pass, **do it ON the Tier 1 screens as you go** — the pattern emerges by example, then apply to Tier 2-3 in Week 2.

Three changes:

```swift
// 1. Introduce Spacing scale in NovaPalette
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// 2. Replace Color.gray.opacity(…) with NovaPalette tint + opacity
// 3. Replace .font(.title) / .font(.body) with NovaPalette.titleFont() / bodyFont()
```

## Effort summary — solo dev

Assumption: bang solo, 6 focused hrs/day.

- Tier 1 (Home + Quiz + Trophy detail): **15 hrs → 3 days**
- Tier 2 (Flipbook + Lessons + Sparky): **12 hrs → 2 days**
- Tier 3 (Auth + Onboarding): **5 hrs → 1 day**
- Unification sweep (pervasive, rolled in as you go): **12 hrs** — not a separate bucket
- Loading states wired: **3 hrs**
- iPad testing (landscape, dark mode, accessibility): **4 hrs**
- Navigation bar consistency: **4 hrs**
- Contingency: **6 hrs**

**Total: ~60 hrs over 10 working days = 2 weeks at 6 hrs/day.**

Demo-this-week = Tier 1 only + rolled-in unification on those 3 screens = **~20 hrs over 3-4 focused days.** Doable if you start tomorrow and the design direction is decided.

## What's already working — don't touch

- `NovaPalette` structure is good, just extend it
- Flipbook card transitions (asymmetric insertion/removal) are the best motion work in the app
- Quiz card attempt counter + hint system + haptic feedback pattern — the whole UX is right, just needs color cleanup
- Trophy detail sheet with progress bars — ship as-is after minor refinement
- Onboarding confetti + avatar animation — polished, leave alone
- Accessibility basics (labels, hints, reduce-motion support) already in place

## Gating question

Design direction — I can't scope the specific screens until I know the answer:

1. **Keep the rainbow palette** (blue / orange / green / purple / yellow / pink) or **consolidate** to 2-3 primary brand colors with accents? The rainbow is kid-appropriate and already built; consolidation reads more premium.
2. **Reference apps** — anything you're pulling visual inspiration from? Khan Academy Kids, Duolingo ABC, Lingokids, Homer, Ello? Or pure original direction?
3. **Sparky's visual identity** — is there a settled character design, or still exploratory?

Once these are answered, I scaffold `docs/SPRINT-11-tracker.md` via the sprint-runner skill and we're off.
