# Nova v2 Classroom Architecture

**Status:** Draft for implementation planning
**Created:** April 29, 2026
**Primary app:** NovaKids iPad app
**Design thesis:** Nova is not a dashboard. Nova is a classroom that rearranges itself around the child.

---

## 1. Product Thesis

Nova v2 should feel like a place, not a set of screens. The child should open the iPad and feel that they have entered a warm classroom where every object can be touched, Dashy is present as a guide, and parent-created lessons physically appear in the room.

The current Nova Kids app has strong foundations: parent-curated generated lessons, Dashy, voice-first narration, card-based learning, and a kid-tested need for less reading-dependent navigation. The v2 shift is a surface architecture change: keep the intelligence layer, but replace the visible UX contract from "cards in a grid" to "objects in a classroom."

The core promise:

> A grown-up can add a NASA page, a robot video, or a science article, and the child sees a new mission object appear in their classroom. Dashy notices it, explains it aloud, and guides the child through chalkboard lessons, tabletop experiments, and sticker rewards.

This is not "ABCmouse with AI." ABCmouse builds a static world of activities. Nova should build a classroom that changes because the family and the child changed.

---

## 2. Competitive Lessons

Research baseline checked April 29, 2026:

- [Appfigures top U.S. Google Play family education apps](https://appfigures.com/top-apps/google-play/united-states/family/education?profile=product.319709974340.details): PBS KIDS Games, PBS KIDS Video, ABCmouse, Lingokids, Epic, Starfall, Prodigy, and similar apps remain highly visible in the category.
- [ABCmouse personalization support](https://support.abcmouse.com/hc/en-us/articles/34386069711767-How-ABCmouse-Personalizes-Learning): learning paths, daily quests, avatar, and immersive feature zones such as My World.
- [ABCmouse tickets article](https://www.abcmouse.com/learn/abcmouse/earn-play-learn-the-magic-of-abcmouse-tickets/7827): rewards are earned through learning and spent on avatar, room, and pet personalization.
- [Khan Academy Kids App Store](https://apps.apple.com/us/app/khan-academy-kids/id1378467217): 4.8 rating, 124K ratings, over 5,000 activities, character-guided subject areas, free with no ads or subscriptions.
- [PBS KIDS Games](https://pbskids.org/apps/play-pbs-kids-games.html) and [TVTechnology PBS KIDS gameplay article](https://www.tvtechnology.com/news/pbs-kids-embraces-gameplay-content): familiar characters, hundreds of curriculum-based games, and very high monthly game-play volume across web and app.
- [Prodigy Math overview](https://www.prodigygame.com/main-en/blog/what-is-prodigy-math-game): quests, pets, battles, rewards, and adaptive questions.
- [Duolingo ABC App Store](https://apps.apple.com/us/app/learn-to-read-duolingo-abc/id1440502568): game-like reading lessons, mini games, rewards, offline use, and expert-designed literacy sequences.
- [Lingokids Playlearning](https://lingokids.com/playlearning): large activity library, age and skill-level adaptation, and a play-first learning frame.

What successful products have in common:

- **They are places.** ABCmouse has worlds and zones. Prodigy has a fantasy world. PBS KIDS has character worlds. Kids do not experience them as menus.
- **They use known guides.** Kodi, Duo, PBS characters, Prodigy avatars, pets, and ABCmouse avatars reduce uncertainty.
- **They make the next action obvious.** The child usually sees one large thing to tap, one quest to continue, or one character cue.
- **They reward effort with visible ownership.** Tickets, pets, stickers, trophies, rooms, avatars, shelves, and collections make progress concrete.
- **They repeat short loops.** Tap, hear, react, answer, celebrate, collect, continue.
- **They are safe by default.** Parents trust ad-free modes, known characters, curriculum framing, teacher tools, and offline support.

Common complaints and risks to avoid:

- Paywall pressure and subscription friction can make parents distrust the experience.
- Reward loops can become the product if learning feels secondary.
- Static school-like UI feels boring even when the content is educational.
- Pre-readers get stuck when navigation depends on labels.
- Overly busy worlds can create cognitive noise and hide the primary action.

Nova's opportunity:

Nova should combine the trust of Khan Academy Kids, the place-based navigation of ABCmouse, the recognizable guide pattern of PBS KIDS, and the progression energy of Prodigy, but make the differentiator unmistakable: the room changes from parent-curated AI lessons and the child's learning history.

---

## 3. North-Star Experience

### First Launch After Parent Adds A Lesson

1. Parent adds a NASA article in Companion and publishes it.
2. The lesson syncs to NovaKids.
3. The classroom home opens with a new rocket model on the project table and a subtle glow around it.
4. Dashy says: "A new space mission is ready. Tap the rocket."
5. Child taps the rocket.
6. The chalkboard flips down with a rocket sketch, progress dots as chalk stars, and the first card starts with audio.
7. The child completes the lesson.
8. A rocket sticker lands on the trophy shelf, and the rocket model remains in the room as a learned object.

### UX Rule

Every primary action must pass this test:

- Can a 4-year-old guess what to tap without reading?
- Does Dashy say what the object does?
- Does the object react when touched?
- Does the result feel like moving deeper into the classroom rather than opening a generic screen?

---

## 4. Classroom Information Architecture

The v2 home is a full-screen classroom scene. Tabs can remain for platform familiarity and adult navigation, but the child-facing first screen should be object navigation.

| Classroom object | Product function | Current equivalent | Child mental model |
|---|---|---|---|
| Chalkboard | Continue lesson and active card flow | Featured lesson / Flipbook | "This is what Dashy is teaching me now" |
| Bookshelf | Lesson library and learning paths | Lessons tab | "Pick a book or mission" |
| Project table | Experiments and hands-on cards | Experiment cards | "Build or try something" |
| Reading rug | Stories and read-aloud content | Story cards | "Sit for a story" |
| Dashy's desk | Ask Dashy / voice chat | Dashy tab | "Ask my teacher buddy" |
| Trophy shelf | Badges, stickers, collections | Trophies tab | "See what I earned" |
| Backpack / cubby | Voice, profile, settings | Voice picker / settings | "My stuff" |
| Bulletin board | New parent-approved lessons | Newly published lessons | "New things showed up" |

Primary navigation should start with five tappable objects: chalkboard, bookshelf, project table, Dashy's desk, and trophy shelf. Secondary objects can be present visually but should not compete for the first v2 release.

---

## 5. Age Progression

Nova should not use one classroom forever. The same architecture should support age-based scene variants.

| Age band | Scene | Dashy role | Visual language | Interaction style |
|---|---|---|---|---|
| 4-5 | AI Classroom | Teacher and helper | Big chalkboard, rug, blocks, cubbies, stickers, chunky object shapes | Voice-first, few labels, large tap zones, one next action |
| 6-7 | Maker Lab | Coach and lab partner | Project table, shelves, robot parts, puzzles, science posters, experiment bins | More choice, visible collections, light reading support |
| 8+ | AI Studio | Collaborator | Smart board, concept map wall, build station, prompt console, project archive | More autonomy, richer text, creation tools, project workflows |

The implementation should not fork the app. It should use the same scene model, object registry, and component primitives with different tokens and art assets by age profile.

---

## 6. Design System Direction

### Palette

The existing `NovaPalette` 3+1 comic palette is a useful base, but v2 needs a classroom token layer. Keep current colors available for compatibility, then add classroom semantic tokens.

| Token | Hex | Use |
|---|---:|---|
| `classroomChalkboard` | `#235C49` | Chalkboard surfaces, lesson board frame interior |
| `classroomChalkDust` | `#F4F0DF` | Chalk strokes, chalk text, diagrams |
| `classroomWood` | `#B87333` | Shelves, table edges, frames |
| `classroomSky` | `#4EA7E8` | Windows, atmosphere, non-card background accents |
| `classroomSchoolRed` | `#E84D3D` | New lesson glow, urgent CTA accents, magnets |
| `classroomSun` | `#FFD24A` | Rewards, highlights, Dashy warmth |
| `classroomPaper` | `#FFF7E3` | Worksheets, pinned notes, cards inside board |
| `classroomInk` | `#17213A` | Strokes, readable text, outlines |
| `classroomLeaf` | `#64B96A` | Success, correct answers, growth |
| `classroomPurple` | `#7B5BE8` | Dashy AI accent, magical/generated content |

Rules:

- Green is the chalkboard anchor, not the whole app.
- Wood and paper are supporting materials, not the dominant palette.
- Red, yellow, blue, purple, and leaf green keep the room saturated and kid-readable.
- All text-bearing surfaces must pass WCAG AA for normal text and 3:1 for large display text.
- Use dark navy outlines instead of black for warmth.

### Typography

Keep Dynamic Type and rounded system fonts for body text. Keep the current display font only for short, celebratory labels. Do not put long instructions in a display face.

| Text role | Font direction | Notes |
|---|---|---|
| Object labels | Rounded heavy, 18-24pt | Optional for ages 4-5; voice must carry the meaning |
| Chalkboard title | Display, 28-40pt | Short phrases only |
| Card body | Rounded semibold/body, 20-28pt | Must be readable from iPad distance |
| Parent-only controls | Standard rounded body | Keep restrained and adult-clear |

### Shape And Materials

- Chalkboards: 12-16pt radius, thick wood frame, chalk dust texture, subtle eraser smudges.
- Object tap targets: stable hit zones at least 88x88pt, visual object can be larger.
- Cards: no generic floating white cards for kid-facing learning surfaces.
- Stickers: die-cut shapes, 2pt ink outline, small drop shadow, placed on shelf or poster.
- Magnets: saturated shape tiles with 2pt ink outline and tactile pressed states.
- Speech bubbles: current Dashy bubble language can continue, but should sit in the classroom layer.

### Motion

- Idle motion: 1-3 slow loops on the scene at a time.
- Tap motion: bounce, haptic, small particle burst.
- Lesson reveal: chalkboard slide or flip.
- Reduced motion: disable parallax and idle loops; keep opacity changes, haptics, and static state changes.

---

## 7. SwiftUI Architecture

The first implementation target is 2D SwiftUI with illustrated image layers, not 3D.

### New Modules / Component Families

Suggested file grouping:

```text
src/Apps/NovaKids/Sources/Views/Classroom/
  ClassroomSceneView.swift
  ClassroomSceneModel.swift
  ClassroomObjectButton.swift
  ClassroomObjectRegistry.swift
  ClassroomBackgroundView.swift
  ClassroomDashyGuideLayer.swift
  ClassroomPromptBubble.swift
  ClassroomTokens.swift

src/Apps/NovaKids/Sources/Views/Classroom/Cards/
  ChalkboardCardSurface.swift
  ChalkboardStoryCardView.swift
  ChalkboardConceptCardView.swift
  MagneticQuizCardView.swift
  ProjectTableExperimentCardView.swift
  VoicePromptCardView.swift
```

### Scene Model

The scene should be data-driven so lessons can materialize as objects.

```swift
struct ClassroomSceneModel: Identifiable, Equatable {
    let id: String
    let ageBand: ClassroomAgeBand
    let backgroundAssetName: String
    let objects: [ClassroomObject]
    let activePrompt: ClassroomPrompt?
}

struct ClassroomObject: Identifiable, Equatable {
    let id: String
    let role: ClassroomObjectRole
    let title: String
    let accessibilityLabel: String
    let narrationKey: String
    let visual: ClassroomObjectVisual
    let destination: ClassroomDestination
    let state: ClassroomObjectState
    let frame: CGRect
}
```

The `frame` is normalized in scene coordinates, not fixed pixels. This lets iPad landscape, iPad portrait, and future compact layouts reuse the same object map.

### Object Roles

```swift
enum ClassroomObjectRole {
    case chalkboard
    case bookshelf
    case projectTable
    case readingRug
    case dashyDesk
    case trophyShelf
    case backpack
    case bulletinBoard
    case generatedLesson
}
```

### Destinations

```swift
enum ClassroomDestination {
    case continueLesson(UUID)
    case lessonLibrary(pathId: UUID?)
    case lesson(UUID)
    case dashyChat
    case trophies
    case voicePicker
    case settings
}
```

Navigation should be implemented with `NavigationStack` and a classroom-specific route enum. Avoid mixing hidden `NavigationLink` objects into every scene object; the object button should emit a route.

### Reuse Existing Systems

Keep and extend:

- `NavigationNarrator` for object narration and screen narration.
- `VoiceManager` for TTS.
- `DashyCharacterView` and `DashySpeechBubble` as the guide foundation.
- `LessonCompletionStore` for completion state.
- `HomeViewModel`, `LessonsViewModel`, `FlipbookViewModel`, and `TrophyRoomViewModel` as data sources initially.
- Existing `Lesson`, `LearningPath`, `Card`, and `CardContent` models.

Do not require backend schema changes for v2 visual shell. If image/object metadata is absent, derive a deterministic object from `Lesson.cardType`, path, title, and completion state.

---

## 8. Backend And Content Mapping

The v2 app can ship with derived classroom placement first, then add backend fields later if needed.

### Derived Mapping For V2

| Backend data | Classroom expression |
|---|---|
| Newly published lesson | Glowing object on bulletin board or project table |
| `LearningPath` | Bookshelf section, shelf color, subject icon |
| `Lesson.status == published` | Available classroom object |
| First card image URL | Object poster, book cover, or table prop thumbnail |
| Card type `story` | Reading rug / pinned page / storybook |
| Card type `concept` | Chalkboard diagram |
| Card type `experiment` | Project table tray |
| Card type `quiz` | Magnet quiz on chalkboard |
| Card type `voice` | Dashy desk prompt / microphone token |
| Completed lesson | Sticker on shelf or board |

### Optional Future Backend Fields

These are not required for v2 sprint 1-4 unless generated art needs stronger authoring control.

```ts
LearningPath {
  classroomTheme?: "classroom" | "maker_lab" | "ai_studio"
  classroomShelfIcon?: string
  classroomColor?: string
}

Lesson {
  classroomObjectKind?: "book" | "rocket" | "robot_part" | "poster" | "experiment_tray" | "mystery_box"
  classroomPlacement?: "bulletin_board" | "bookshelf" | "project_table" | "chalkboard"
  classroomImagePrompt?: string
  classroomImageUrl?: string
}
```

Default policy: do not block the iPad v2 UI on these fields. The app should render useful classroom objects from current data.

---

## 9. Card Surface Redesign

Flipbook remains the learning engine, but the surfaces should look like classroom activities.

| Card type | V2 surface | Interaction |
|---|---|---|
| Story | Pinned illustrated page on chalkboard or reading rug easel | Dashy reads, child taps next page |
| Concept | Chalkboard diagram with animated chalk marks | Tap highlighted drawing parts for spoken labels |
| Quiz | Magnetic answer tiles or sticky notes | Drag or tap answer tile onto answer zone |
| Experiment | Project table tray with manipulatives | Drag pieces, sort objects, complete build |
| Voice | Dashy prompt bubble with microphone badge | Speak answer, Dashy reacts |
| Video | Classroom TV / projector | Video frame in wood cart with strict safety chrome |

The top-level card chrome should avoid generic progress bars. Use chalk stars, sticker dots, or board eraser marks for progress.

---

## 10. Dashy Guide Layer

Dashy should be visible in the classroom home and present in learning surfaces as a guide layer.

Behavior:

- Idle: small breathing/blink loop, respects reduced motion.
- Narrating: speech bubble appears near Dashy, matching the current narration line.
- New lesson: Dashy points or looks toward the new object.
- Wrong answer: Dashy softens, gives a hint, never scolds.
- Completion: Dashy celebrates briefly and places the sticker reward.
- Help: tapping Dashy repeats the last instruction.

Implementation:

- `ClassroomDashyGuideLayer` observes `NavigationNarrator` state.
- It receives `ClassroomPrompt` values from the scene model.
- It should not own learning logic; it translates app state into presence, pose, and speech.

---

## 11. Accessibility And Safety

Nova v2 must be playable by a pre-reader.

Requirements:

- Every scene object has an accessibility label, hint, role, and spoken narration line.
- The initial classroom view auto-narrates within 1 second unless the parent disabled narration.
- Touch targets are at least 44x44pt, with primary object targets preferably 88x88pt or larger.
- Text never carries the only instruction for ages 4-5.
- Reduced motion removes parallax, idle loops, and particle bursts.
- Parent-only controls stay behind an adult-readable or parental-gated affordance.
- Generated images must not contain text, brand characters, unsafe objects, or photorealistic children.
- Offline or failed sync states should be represented in-world: Dashy near an empty bulletin board, not a generic error page.

---

## 12. Image Prompt Pack

These prompts are source-of-truth starting points for image-model exploration. Generate as mood frames first, then select 1-2 directions before committing assets to the app.

Global negative prompt for all images:

```text
No readable text, no letters, no numbers, no logos, no copyrighted characters, no brand references, no photorealistic children, no scary faces, no cluttered tiny UI, no dark moody lighting, no phone frame, no tablet frame, no adult teacher, no chalk writing.
```

### Classroom Home, Age 4-5

```text
Bright warm illustrated classroom for a children's educational iPad app, landscape 4:3 composition, ages 4 to 5, saturated but controlled colors, large green chalkboard centered left, cozy reading rug, low bookshelf, project table with simple science toys, cubbies, sunny window, trophy sticker shelf, clear empty tappable zones for UI objects, friendly AI guide space near bottom right, clean focal hierarchy, soft rounded shapes, hand-painted digital illustration, warm paper texture, kid-safe, playful, no text.
```

### Maker Lab, Age 6-7

```text
Playful maker lab classroom for a children's AI learning app, landscape iPad composition, ages 6 to 7, green smart chalkboard, project table with robot parts and science materials, organized shelves, puzzle wall, bright safety colors, schoolhouse red accents, sunny yellow reward area, sky blue window light, clear tappable object zones, inviting and not cluttered, polished 2D digital illustration with tactile classroom materials, no text.
```

### AI Studio, Age 8+

```text
Creative AI studio classroom for older elementary kids, landscape iPad composition, ages 8 to 10, smart board, concept map wall, build station, bookshelf archive, glowing but warm AI accents, deep navy outlines, saturated classroom colors, organized maker-space layout, sophisticated but still kid-friendly, clear tappable zones for lessons and projects, 2D animated-app background style, no text.
```

### Chalkboard Lesson Surface

```text
Large classroom chalkboard lesson surface for a children's learning app, landscape iPad composition, rich green chalkboard with warm wood frame, chalk dust texture, pinned paper area, space for diagram overlays, small magnets and eraser, bright classroom accents, clean central teaching area, no readable chalk writing, no text, no logos, friendly and tactile.
```

### Bookshelf Lesson Library

```text
Low colorful classroom bookshelf for a children's educational app, landscape iPad scene component, chunky books and lesson objects arranged by subject, some glowing new objects, stickers and small trophies, warm wood, saturated school colors, clear large tap targets, uncluttered shelves, kid-safe 2D illustration, no text on book spines.
```

### Trophy And Sticker Shelf

```text
Classroom trophy and sticker shelf for a children's learning app, warm wood shelf, colorful sticker board, earned badges, star stickers, small science and reading trophies, sunny celebratory lighting, deep navy outlines, tactile paper and enamel materials, clear open spaces for app-rendered badges, landscape iPad composition, no text.
```

### Dashy Classroom Pose Reference

```text
Friendly small AI classroom guide character pose sheet, bright yellow and purple accents, rounded simple silhouette, expressive eyes, teacher-helper energy, pointing pose, listening pose, celebrating pose, thinking pose, kid-safe and warm, 2D digital illustration, transparent or simple light background, no text, no logos.
```

### Generated Lesson Object: Space Mission

```text
Small classroom project-table object representing a space lesson, toy rocket model, planet stickers, simple star chart shapes without text, warm wood table, saturated classroom colors, designed as a tappable object in a children's iPad app, friendly and not realistic, no text, no logos.
```

### Generated Lesson Object: Robot Mission

```text
Small classroom maker-table object representing a robot lesson, friendly robot parts, gears, battery shape, circuit-like toy board without symbols or text, warm illustrated style, saturated school colors, designed as a tappable object for a children's educational iPad app, no text, no logos.
```

---

## 13. Acceptance Criteria

The architecture is implementation-ready when:

- A SwiftUI engineer can implement v2 without choosing the product metaphor, palette, component categories, or navigation model.
- The classroom home can be built on top of existing view models and API models.
- Generated lessons have a deterministic classroom representation even without backend schema changes.
- The prompt pack can be copied into an image model without extra art-direction decisions.
- The design direction preserves Nova's existing strengths: Dashy, voice-first navigation, generated lessons, parent-curated content, and learning progression.
- The plan avoids copying ABCmouse by making classroom objects dynamic outputs of family-curated AI lessons.

