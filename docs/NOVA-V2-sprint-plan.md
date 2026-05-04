# Nova v2 Classroom Sprint Plan

**Status:** Draft implementation plan
**Created:** April 29, 2026
**Scope:** NovaKids iPad app first; Companion and backend changes only when required
**Plan shape:** 4 sprints, 2 weeks each, classroom v2 surface architecture

---

## Summary

Nova v2 turns the Kids app from a card dashboard into an AI classroom. The four-sprint plan keeps the current learning pipeline intact while replacing the primary child-facing surfaces with classroom scenes, object navigation, chalkboard learning cards, Dashy guide presence, and image-model-driven art direction.

The plan assumes SwiftUI 2D illustrated scenes. It does not require a backend migration for the first release. Backend fields for classroom placement and generated object art are optional follow-ups after the iPad experience proves the metaphor.

Primary success metric:

> A 4-8 year old can open Nova, understand where to tap, start a parent-created lesson, finish the first card, and identify the reward without adult reading support.

---

## Sprint 1 - Classroom Foundation

**Goal:** Establish v2 classroom tokens, scene architecture, and a working classroom shell behind a feature flag.
**Target:** 40 points

| ID | Story | Points | Acceptance criteria |
|---|---|---:|---|
| V2-S1-01 | Classroom design tokens | 5 | Add classroom semantic colors, material names, spacing guidance, and SwiftUI token accessors without breaking existing `NovaPalette` callers. Contrast checks documented for text-bearing colors. |
| V2-S1-02 | Classroom scene model | 5 | Add `ClassroomSceneModel`, `ClassroomObject`, object roles, destination enum, and normalized frame strategy. Unit tests cover generated object derivation. |
| V2-S1-03 | Classroom background shell | 8 | Build `ClassroomSceneView` and `ClassroomBackgroundView` with placeholder vector/shape art and stable object hit zones for iPad landscape and portrait. |
| V2-S1-04 | Object button primitive | 5 | Build `ClassroomObjectButton` with 88x88pt preferred hit zones, bounce/haptic hook, VoiceOver labels, and reduced-motion behavior. |
| V2-S1-05 | Dashy guide layer v1 | 5 | Add `ClassroomDashyGuideLayer` using existing Dashy character and speech bubble. Tapping Dashy repeats the current classroom narration. |
| V2-S1-06 | Feature flag and route integration | 5 | Add a local debug flag or app-state switch so Home can load the classroom shell without deleting current Home. NavigationStack routes work for placeholder destinations. |
| V2-S1-07 | Image prompt validation pass | 3 | Generate or review prompt-pack outputs outside the app, select one classroom art direction, and document chosen prompt revisions. |
| V2-S1-08 | Sprint QA and kid-readability check | 4 | Simulator and iPad build pass. Adult can point to each object and state its purpose. No text-only primary target in the shell. |

### Sprint 1 Definition Of Done

- `NovaKids` builds.
- Existing Home can still be reached if the v2 flag is off.
- Classroom shell shows chalkboard, bookshelf, project table, Dashy desk, trophy shelf, and backpack/cubby.
- Every primary object is tappable, accessible, and can speak or repeat a narration line.

### Sprint 1 Cut Lines

- If time slips, cut image generation and use placeholder art.
- Do not cut scene model, object button, or feature flag.
- Do not refactor backend or Companion in Sprint 1.

---

## Sprint 2 - Home And Lesson Object Navigation

**Goal:** Replace the child-facing Home/Lessons entry flow with classroom object navigation backed by real lesson data.
**Target:** 42 points

| ID | Story | Points | Acceptance criteria |
|---|---|---:|---|
| V2-S2-01 | Home data adapter | 5 | Map `HomeViewModel` and `LessonsViewModel` data into `ClassroomSceneModel`. Continue lesson, paths, new lessons, and completed lessons all produce deterministic objects. |
| V2-S2-02 | Generated lesson object derivation | 5 | Lesson title, path, first card type, and completion state derive a classroom object kind. No backend field required. Tests cover story, concept, quiz, experiment, voice, and video cards. |
| V2-S2-03 | Classroom Home v1 | 8 | Feature-flagged Home renders the classroom with real user data. Chalkboard opens current lesson, bookshelf opens lesson library, Dashy's desk opens Dashy, trophy shelf opens trophies. |
| V2-S2-04 | Bookshelf lesson library | 8 | Replace flat lesson grid with bookshelf/path sections in the v2 route. Books and objects use path color, first card image when available, completion stickers, and accessible labels. |
| V2-S2-05 | Bulletin board new lesson state | 5 | Newly published or unstarted lessons appear as glowing bulletin board or table objects. Dashy narration points the child to the newest item. |
| V2-S2-06 | Classroom empty/error states | 4 | Empty state shows Dashy near an empty board and asks a grown-up to add a lesson. Error state stays in-world and keeps cached objects visible where possible. |
| V2-S2-07 | Narration scripts | 3 | Add short scripts for classroom home, bookshelf, new lesson, trophy shelf, and empty states. Scripts avoid reading long titles unless necessary. |
| V2-S2-08 | Sprint QA and kid test 1 | 4 | Test with an adult proxy or child: "Where would you tap to start?" and "What changed?" Capture findings in a sprint-run note. |

### Sprint 2 Definition Of Done

- A child can start the current lesson from the chalkboard.
- A child can find a new lesson from a visible object without reading a list.
- Lessons still use real backend data and existing navigation routes.
- Old LessonsView remains available outside the feature flag until v2 is stable.

### Sprint 2 Cut Lines

- If time slips, keep bookshelf visual simple but preserve object navigation.
- Cut advanced completion sticker placement before cutting new lesson visibility.
- Do not add backend schema unless object derivation blocks a required UI state.

---

## Sprint 3 - Chalkboard Flipbook And Classroom Cards

**Goal:** Convert the learning flow from generic cards to classroom learning materials.
**Target:** 44 points

| ID | Story | Points | Acceptance criteria |
|---|---|---:|---|
| V2-S3-01 | Chalkboard card container | 8 | Build `ChalkboardCardSurface` with wood frame, chalk interior, progress as chalk stars or sticker dots, and existing Flipbook navigation controls. |
| V2-S3-02 | Story card redesign | 5 | Story cards render as pinned pages or storybook sheets on the board/rug. TTS still starts from existing `FlipbookViewModel` behavior. |
| V2-S3-03 | Concept card redesign | 5 | Concept cards render as chalk diagrams with title, image, and body layout optimized for iPad. Long copy wraps cleanly and keeps Dynamic Type support. |
| V2-S3-04 | Magnetic quiz card | 8 | Quiz options render as magnetic tiles or sticky notes. Correct/wrong feedback uses classroom materials, Dashy hint, haptic, and reduced-motion fallback. |
| V2-S3-05 | Project table experiment card | 8 | Experiment cards render as table trays/manipulatives while preserving current drag/drop mechanics and success/failure states. |
| V2-S3-06 | Voice prompt card | 4 | Voice cards render as Dashy prompt plus microphone badge. Listening state is obvious visually and via accessibility. |
| V2-S3-07 | Completion transition | 3 | Lesson completion places a sticker/badge onto the classroom trophy shelf or board. Existing completion store remains the source of truth. |
| V2-S3-08 | Sprint QA and regression | 3 | Build pass, VoiceOver smoke test, reduced-motion pass, and card type walkthrough with at least one sample of each card type. |

### Sprint 3 Definition Of Done

- Flipbook still supports all current card types.
- The learning flow feels like using classroom materials.
- Text does not overflow on iPad portrait or landscape.
- Existing lesson completion behavior remains intact.

### Sprint 3 Cut Lines

- If time slips, ship chalkboard container plus story/concept/quiz first.
- Keep experiment cards on old UI behind a classroom wrapper if drag/drop polish overruns.
- Do not break TTS or card progression for visual polish.

---

## Sprint 4 - Rewards, Art Assets, Polish, And Kid Testing

**Goal:** Make the classroom feel complete enough for TestFlight-quality kid and parent feedback.
**Target:** 42 points

| ID | Story | Points | Acceptance criteria |
|---|---|---:|---|
| V2-S4-01 | Trophy shelf redesign | 6 | Trophies render as shelf stickers, badges, and collected classroom objects. Existing trophy data maps to visible rewards. |
| V2-S4-02 | Classroom art asset integration | 8 | Replace placeholder art with selected image-model assets or hand-edited composites. Assets contain no baked text, logos, unsafe content, or copyrighted characters. |
| V2-S4-03 | Age profile visual variants | 6 | Add age-band hooks for 4-5 classroom, 6-7 maker lab, and 8+ AI studio. If full art is not ready, token/object density changes still demonstrate progression. |
| V2-S4-04 | Parent-safe controls | 4 | Voice picker, mute, and settings remain discoverable without becoming primary child objects. Parent-only actions stay gated or visually adult-coded. |
| V2-S4-05 | Classroom sound and reaction pass | 5 | Primary object taps use consistent bounce, haptic, and small particle burst. Reduced motion removes ambient and particle effects. |
| V2-S4-06 | Performance pass | 4 | Classroom home scrolls/interacts smoothly on target iPad. Large background images are compressed and do not cause memory warnings. |
| V2-S4-07 | Kid test 2 | 4 | Run 30-minute kid test. Measure time to first tap, first lesson start, first card completion, help requests, and spontaneous "again" signal. |
| V2-S4-08 | Release decision and cleanup | 5 | Decide whether v2 replaces current Home by default. Document known issues, screenshots, and remaining polish for TestFlight. |

### Sprint 4 Definition Of Done

- Classroom v2 can be enabled as the default Kids app experience for internal testing.
- Kid test shows the child can navigate Home to lesson without adult reading support.
- Assets are safe, performant, and aligned with the prompt pack.
- The old UI can still be restored quickly if testing exposes a blocker.

### Sprint 4 Cut Lines

- If time slips, cut 8+ AI Studio art before cutting 4-5 classroom polish.
- Cut decorative ambient animations before cutting tap feedback and narration.
- Cut advanced trophy shelf animation before cutting visible earned rewards.

---

## Cross-Sprint Test Plan

### Build And Regression

- Run `xcodebuild -workspace src/Nova.xcworkspace -scheme NovaKids -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` at the end of each sprint.
- Smoke test Home, Lessons/bookshelf, Flipbook, Dashy, Trophies, Voice Picker, and offline/error state.
- Confirm current non-v2 UI still works while the feature flag exists.

### Accessibility

- VoiceOver rotor finds meaningful object labels.
- Primary targets are at least 44x44pt, with main classroom objects 88x88pt or larger.
- Reduce Motion disables parallax, idle loops, and particle bursts.
- Text scales without clipping in iPad portrait and landscape.
- No required instruction is text-only for the 4-5 experience.

### Kid Testing

Run two structured sessions:

- End of Sprint 2: object navigation comprehension.
- End of Sprint 4: full classroom learning loop.

Capture:

- Time to first intentional tap.
- Whether the child finds the new lesson object.
- Whether the child starts a lesson without adult reading.
- Whether the child completes the first card.
- Number of adult prompts.
- Which objects the child names or remembers after the session.
- Whether the child asks to continue.

### Parent Review

Ask parent reviewers:

- Does this feel trustworthy?
- Does the classroom feel educational without feeling like schoolwork?
- Is the AI-generated lesson object understandable?
- Is Dashy helpful or distracting?
- Is the reward loop motivating without feeling manipulative?

---

## Implementation Defaults

- Use existing backend models first. Add optional classroom metadata only after the UI proves the need.
- Use SwiftUI 2D illustrated scenes. Do not introduce SceneKit, SpriteKit, or 3D in this v2.
- Keep current Dashy implementation and evolve presentation before redesigning the character.
- Keep current `NavigationNarrator` and `VoiceManager`.
- Add a reversible feature flag until Sprint 4 release decision.
- Prefer deterministic object mapping over hand-authored per-lesson placement for v2.

---

## Risks And Mitigations

| Risk | Mitigation |
|---|---|
| Classroom becomes visually noisy | Limit first release to 5 primary objects, with secondary objects decorative or disabled. |
| Generated image assets look inconsistent | Use prompt pack, select one direction, and apply app-rendered overlays for consistency. |
| Kids tap decorative objects and get frustrated | Decorative objects should either be inert with no affordance or produce a tiny non-blocking reaction. Primary objects get glow, narration, and hit zones. |
| Backend metadata scope expands | Ship deterministic mapping first. Treat schema fields as optional v2.1 enhancements. |
| Reading still blocks navigation | Voice-first scripts and Dashy repeat-on-tap are required acceptance criteria. |
| Rewards overpower learning | Rewards are stickers/collections attached to concepts, not currency or shopping. |
| Performance suffers from large art | Use compressed assets, one background per age profile, and app-rendered interactive overlays. |

---

## Release Gate

Nova v2 Classroom can become the default Kids app experience when:

- A real iPad build passes.
- Classroom Home to first Flipbook card works with live or seeded lessons.
- The child can start a lesson without adult reading support in kid test 2.
- No critical VoiceOver, reduced-motion, or text clipping issues remain.
- Parent reviewer understands that new classroom objects came from parent-approved content.
- Reverting to the current UI is still possible through the feature flag.

