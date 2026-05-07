# Nova v2 — Classroom Home 2.5D Art Contract

**Status:** Live contract. 4–5 placeholder PNGs are shipping in the
asset catalog so the build is green and `UIImage(named:)` lookup is
exercisable; final illustrated art is still upstream. Placeholders are
intentionally too small to activate the illustrated production scene.
**Owner:** Classroom Home (`HomeView` → `ClassroomSceneView`).
**Consumers:** Designer / image-model operator (generates the artwork);
SwiftUI engineer (lays `ClassroomObject` hotspots over the artwork).

> **Why this doc exists.** Nova's differentiator is an AI classroom that
> changes as parents add content and as the child grows. The classroom is
> the brand surface. For that to work, generated artwork and the SwiftUI
> hotspot layer have to line up the *first* time, and they have to keep
> lining up across age bands (4–5, 6–7, 8+) without rewriting either side.
> This doc is the shared contract.

---

## 1. Scene philosophy

- **Perspective.** A 2.5D illustrated classroom at a 4-year-old's eye level,
  standing just inside the doorway. Front wall straight ahead, side walls
  receding into the scene, foreground floor sweeping toward the viewer.
  Mild perspective, not full 3D — the silhouettes have to stay flat enough
  to read at iPad-thumbnail scales.
- **Mood.** Warm, friendly, confident. A classroom a kid wants to *enter*,
  not a sterile UI grid.
- **Style.** Hand-drawn / cut-paper feel, soft chalk + paper textures,
  saturated but not neon. Ink outlines on each major object so they read
  even on the busiest day.
- **Palette.** Pull only from `NovaPalette.classroom*` tokens
  (`classroomChalkboard`, `classroomChalkDust`, `classroomWood`,
  `classroomSky`, `classroomSchoolRed`, `classroomSun`, `classroomPaper`,
  `classroomInk`, `classroomLeaf`, `classroomPurple`). No comic-book primary
  rainbow; no neon gradients; no third-party brand colors.
- **Subject focus.** Six furniture objects at well-defined screen zones (see
  §3). Everything else is decoration that must stay *out* of the hotspot
  rectangles.
- **No baked-in text rule.** **The artwork must contain zero rendered text,
  zero numerals, zero fake-typography signs, and zero readable book spines.**
  All copy ("Chalkboard", "Bookshelf", trophy counts, mission counts, the
  Dashy speech bubble, etc.) is composed by SwiftUI on top of the image at
  runtime. Generated text drifts across age bands and breaks localization;
  SwiftUI labels don't. Decorative shapes (squiggles, abstract chalk marks,
  generic book-spine *colors* without letters) are fine.
- **No brand / IP references.** No real school logos, no licensed cartoon
  characters, no recognizable real toys, no celebrity faces, no AI-tool
  watermarks, no Apple/Disney/Pixar/etc. silhouettes. The room is a
  *generic* warm classroom inhabited by Nova's own characters (Dashy is
  composed at runtime by SwiftUI; do not draw Dashy into the background).

---

## 2. Asset names

All assets ship into the `NovaKids` asset catalog under a single
`Classroom/Home/` group. The **imageset name** must match the runtime
resolver exactly; Xcode owns the internal @2x / @3x filenames.

| Runtime imageset name             | Resolution targets inside imageset | Aspect     | Purpose                                              |
|------------------------------------|------------------------------------|------------|------------------------------------------------------|
| `classroom_home_45_landscape`      | @2x: 2732 × 2048, @3x: 4098 × 3072 | 4 : 3 land | Ages 4-5 iPad landscape master.                      |
| `classroom_home_45_portrait`       | @2x: 2048 × 2732, @3x: 3072 × 4098 | 3 : 4 port | Ages 4-5 iPad portrait master.                       |
| `classroom_home_67_landscape`      | @2x: 2732 × 2048, @3x: 4098 × 3072 | 4 : 3 land | Ages 6-7 maker-lab landscape variant.                |
| `classroom_home_67_portrait`       | @2x: 2048 × 2732, @3x: 3072 × 4098 | 3 : 4 port | Ages 6-7 maker-lab portrait variant.                 |
| `classroom_home_8plus_landscape`   | @2x: 2732 × 2048, @3x: 4098 × 3072 | 4 : 3 land | Ages 8+ AI-studio landscape variant.                 |
| `classroom_home_8plus_portrait`    | @2x: 2048 × 2732, @3x: 3072 × 4098 | 3 : 4 port | Ages 8+ AI-studio portrait variant.                  |
| `classroom_home_45_landscape_hotspot.svg` | matches landscape          | 4 : 3 land | Reference overlay (designer/QA only — never shipped).|
| `classroom_home_45_portrait_hotspot.svg`  | matches portrait           | 3 : 4 port | Reference overlay (designer/QA only — never shipped).|

Runtime lookup in `ClassroomSceneAssetResolver` is deterministic:

```swift
classroom_home_<ageBand>_<orientation>
```

where `ageBand` is `45`, `67`, or `8plus`, and `orientation` is
`landscape` or `portrait`.

The 4–5 file is the canonical reference; older variants must keep the same
hotspot layout so `ClassroomSceneModel` does not need a per-age-band
dispatch in MVP.

### 2.1 Current shipping state — placeholders, not final art

The Xcode asset catalog at
`src/Apps/NovaKids/Resources/Assets.xcassets/` currently ships **two
placeholder imagesets** for the 4–5 age band:

- `classroom_home_45_landscape.imageset/` →
  `classroom_home_45_landscape_placeholder.png` (256 × 192,
  classroom-cream solid color, no text).
- `classroom_home_45_portrait.imageset/` →
  `classroom_home_45_portrait_placeholder.png` (192 × 256,
  classroom-cream solid color, no text).

Each imageset's `Contents.json` carries a `properties.comment` field
that explicitly marks the file as `"PLACEHOLDER — solid classroom-cream
stand-in for the 4-5 classroom <orientation> art. Replace with final
illustrated PNG drop. Do not ship as final."` so the placeholder status
is visible inside the asset metadata; **no text is baked into the PNG
itself**, per §1's no-baked-text rule.

The `AppIcon.appiconset` and `AccentColor.colorset` siblings in the same
catalog are likewise placeholders and exist only to satisfy actool
during the transitional period; they are not the final app icon or
brand accent.

The 6–7 and 8+ age-band imagesets have **not** shipped yet — when those
land, they should also use the deterministic naming
(`classroom_home_67_landscape`, `classroom_home_8plus_portrait`, …)
defined in this doc and consumed by `ClassroomSceneAssetResolver`.

Runtime routing uses `ClassroomSceneAssetResolver.hasProductionAsset(...)`,
which requires the resolved image's short side to be at least 700 points.
The 256 × 192 and 192 × 256 placeholders resolve via `UIImage(named:)` but
stay below that threshold, so NovaKids continues to show the richer SwiftUI
fallback classroom until final high-resolution art lands. Final @2x/@3x iPad
art from the table above clears the threshold and activates the illustrated
2.5D scene automatically.

### 2.2 Final-art import procedure

When the final illustrated PNGs arrive:

1. Drop the @1x / @2x / @3x PNGs into the matching imageset folder
   (e.g. `classroom_home_45_landscape.imageset/`).
2. Update that imageset's `Contents.json` to point each scale slot at
   its new filename and remove the `properties.comment` placeholder
   marker (or replace it with a "final" note).
3. Delete the `*_placeholder.png` file once a final asset is bound at
   the `1x` slot.
4. Rebuild — the runtime resolver picks up the new art automatically;
   no Swift changes are required because the imageset *name* stays
   identical.
5. Confirm the asset's short side clears the
   `hasProductionAsset(...)` 700pt threshold.
6. Run the hotspot debug overlay
   (`NOVA_CLASSROOM_HOTSPOTS_DEBUG=1` env var) to confirm the
   normalized §3 rectangles still align with the new artwork.

---

## 3. Normalized hotspot map

Coordinates are normalized in [0, 1] with `(0, 0)` at top-left, scaled by
`ClassroomSceneView` for both orientations. **The artwork must place each
furniture object so its visual center lands inside its hotspot rectangle,
and so the silhouette extends beyond the rect by no more than ~10% on any
side.** Hotspot rectangles intentionally leak past the visible furniture
edges because a 4-year-old aims with a finger, not a pixel.

| Object         | role             | x    | y    | w    | h    | Notes                                                      |
|----------------|------------------|------|------|------|------|------------------------------------------------------------|
| Chalkboard     | `.chalkboard`    | 0.24 | 0.07 | 0.50 | 0.36 | Front wall, dead-center upper. Primary CTA. Wooden frame.  |
| Bookshelf      | `.bookshelf`     | 0.03 | 0.22 | 0.21 | 0.32 | Left wall, top half. Tappable shelf zone (NOT the window). |
| Trophy Shelf   | `.trophyShelf`   | 0.76 | 0.04 | 0.20 | 0.17 | Right wall, upper. Wooden display shelf with trophies.     |
| Mission Board  | `.bulletinBoard` | 0.74 | 0.23 | 0.22 | 0.22 | Right wall, mid. Cork board with pinned blank notes.       |
| Project Table  | `.projectTable`  | 0.28 | 0.80 | 0.42 | 0.18 | Foreground center-bottom desk surface. Disabled today.     |
| Dashy's Desk   | `.dashyDesk`     | 0.71 | 0.46 | 0.27 | 0.28 | Right foreground floor. Desk + lamp silhouette.            |
| Backpack/Cubby | `.backpack`      | 0.03 | 0.56 | 0.21 | 0.20 | Below the bookshelf. Cubby crates / backpack zone.         |

### 3.1 Age-band hotspot profiles

`ClassroomSceneModel` keeps one **`HotspotProfile`** per age band so each
painted variant gets its own tuned rectangles. Adding a future age band
is a one-call-site change: drop a new profile constant and add a
`case` in `HotspotProfile.profile(for:)`.

The 4-5 frames are the canonical reference (table above). The 6-7
maker-lab profile shifts a few rectangles by 1-6% to match its painted
art (`classroom_home_67_landscape` / `classroom_home_67_portrait`):

| Object         | role             | x    | y    | w    | h    | vs. 4-5                                      |
|----------------|------------------|------|------|------|------|----------------------------------------------|
| Chalkboard     | `.chalkboard`    | 0.25 | 0.08 | 0.50 | 0.34 | nudged right + down by 1%, slightly thinner  |
| Bookshelf      | `.bookshelf`     | 0.03 | 0.18 | 0.21 | 0.30 | sits 4% higher; height shrinks by 2%         |
| Trophy Shelf   | `.trophyShelf`   | 0.76 | 0.04 | 0.20 | 0.18 | 1% taller — painted shelf is a hair larger   |
| Mission Board  | `.bulletinBoard` | 0.74 | 0.24 | 0.22 | 0.22 | 1% lower start to clear the taller trophy    |
| Project Table  | `.projectTable`  | 0.28 | 0.80 | 0.42 | 0.18 | unchanged — foreground desk lands the same   |
| Dashy's Desk   | `.dashyDesk`     | 0.71 | 0.48 | 0.27 | 0.28 | sits 2% lower — heavier desk + lamp silhouette |
| Backpack/Cubby | `.backpack`      | 0.03 | 0.50 | 0.21 | 0.22 | rises 6% with the bookshelf above; +2% taller |

The 8+ AI-studio band reuses the 6-7 profile until its dedicated art
ships in `Assets.xcassets`. When the 8+ painting lands, add an
`aiStudio8Plus` `HotspotProfile` constant and switch the
`.aiStudio8Plus` case in `HotspotProfile.profile(for:)` from the
maker-lab fallback to the new constant.

> **Reserved zone — Dashy speech bubble.** The center column from roughly
> `x: 0.30…0.66, y: 0.40…0.65` floats Dashy's speech bubble at runtime.
> Do not place visually busy detail there in the artwork (avoid posters,
> high-saturation patterns, complex chalk diagrams). A soft uncluttered
> wall area is what we need.
>
> The **classroom hotspot debug overlay**
> (`ClassroomHotspotDebugOverlay`, gated by
> `NOVA_CLASSROOM_HOTSPOTS_DEBUG=1`) renders this reserved zone as a
> dashed orange rectangle on top of the live scene so QA can confirm at
> a glance that the artwork stays calm under the bubble. The overlay
> also draws dashed green markers for each entry in the "Required clear
> visual object zones" list below — not just the hotspot tap rectangles
> — so a single QA pass validates both the tap layer **and** the
> art-safe zones in one look.

### Required clear visual object zones

For each hotspot, the generated artwork must keep the listed slot
**uncluttered**, so SwiftUI overlays land cleanly:

- **Chalkboard surface:** flat slate area at least 0.40 × 0.22 inside the
  hotspot, free of pre-drawn text/numbers.
- **Trophy Shelf interior:** at least 0.18 × 0.16 of empty shelf surface
  inside the hotspot for runtime trophy stickers + the count badge in the
  upper-right corner.
- **Mission Board face:** at least 0.20 × 0.18 of empty cork inside the
  hotspot for runtime mission cards.
- **Bookshelf shelves:** at least three visible shelf rows; book *colors*
  may be drawn but no book *titles*.
- **Project Table top:** at least 0.22 × 0.10 of clear table surface with
  no pre-drawn experiment.
- **Dashy's Desk top:** clear surface (~0.20 × 0.08); Dashy is composed at
  runtime — do **not** draw Dashy into the background.
- **Cubby/Backpack:** clear cubby opening big enough to read at iPad
  thumbnail scale; one neutral-color backpack OK as decoration.

---

## 4. iPad **landscape** prompt (4–5 base)

```
A warm, friendly children's classroom for a four-to-five-year-old, drawn
in a soft 2.5D illustration style with hand-drawn / cut-paper textures,
gentle ink outlines, and a slightly washy chalk-and-paper feel. Wide
landscape composition, 4:3 aspect ratio, designed at child eye-level —
viewer is standing just inside the doorway looking into the room.

Scene layout, left to right and front to back:
 - Far wall straight ahead, mid-tone classroom-paper cream with subtle
   warm shading.
 - On the far wall, dead-center upper, a large green chalkboard in a thick
   wooden frame; the slate is clean (NO TEXT, NO NUMBERS, NO LETTERS, NO
   PRE-DRAWN PICTURES); a small wooden chalk tray underneath.
 - Left wall recedes into the scene; against it stands a tall four-shelf
   wooden bookshelf with rows of brightly colored book spines (NO TITLES,
   NO LETTERS).
 - Right wall recedes into the scene; on the upper portion a
   glass-fronted wooden trophy display case, EMPTY interior shelves.
 - Below the trophy case, on the same right wall, a cork-textured
   mission/bulletin board with a few small empty colored sticky-note
   shapes pinned with thumbtacks (NO WORDS on the notes).
 - Foreground center floor: a warm wooden child-sized desk with a small
   wooden chair, surface clean and empty (no character drawn — Dashy is
   added in software).
 - Foreground right floor: a low rectangular wooden craft / project
   table, surface empty.
 - Bottom-left near the skirting: a small built-in cubby with one soft
   fabric backpack hung on a hook.

Color palette only:
 - Chalkboard green (deep, slightly muted).
 - Warm wooden brown for frames, shelves, desk, table.
 - Cream / soft-white wall and paper.
 - Red, yellow, blue, teal, purple, leaf-green book spines and small
   cork-board notes — saturated but not neon.
 - Soft cool sky-blue accents (window light if any).
 - Dark indigo ink outlines on every major object.

Lighting: soft daylight from upper-left window glow, gentle long shadows
falling toward bottom-right. No harsh contrast.

Required clear / uncluttered zones:
 - The chalkboard slate.
 - The interior of the trophy case.
 - The face of the mission board.
 - The top of the desk.
 - The top of the project table.
 - A wide vertical strip in the center of the scene, from mid-height
   down to just above the desk, where a soft speech bubble will be
   composed at runtime — keep this strip simple and free of busy
   detail.

Hard rules:
 - NO TEXT of any kind anywhere — no titles, no numbers, no letters, no
   signage, no readable book spines.
 - NO real-world brand logos, no cartoon characters, no licensed
   properties, no celebrity faces, no AI watermarks.
 - NO people, NO Dashy, NO mascot — characters are added in software.
 - NO baked-in trophy icons or mission cards — those are added in
   software.

Style references (descriptive, not for IP): cut-paper picture-book
illustration, soft chalk + watercolor textures, calm warm classroom
poster, slightly storybook.

Output: a single high-resolution illustration filling the full 4:3 frame
with no borders, no UI chrome, no captions.
```

## 5. iPad **portrait** prompt (4–5 base)

```
The same warm friendly preschool classroom, child eye-level, but
recomposed for a 3:4 portrait iPad frame.

Scene layout, top to bottom:
 - Upper third: front wall with the centered chalkboard in a wooden
   frame (clean slate, NO TEXT). To the upper-right against the right
   wall, the glass-fronted wooden trophy display case (EMPTY shelves).
 - Middle third: left wall holds the tall multi-shelf bookshelf
   (colored book spines, NO TITLES). Right wall, mid-height, the
   cork-textured mission board with empty pinned sticky-note shapes.
 - Lower third / foreground: a warm wooden child-sized desk and chair
   centered (surface clean, no character drawn), a small wooden craft
   project table to the right, and a built-in cubby with a single soft
   backpack hanging in the bottom-left.

Same palette, same hand-drawn 2.5D style, soft daylight from upper-left,
ink outlines, no neon.

Required clear / uncluttered zones:
 - Chalkboard slate.
 - Trophy case interior.
 - Mission board face.
 - Desk top.
 - Project table top.
 - A vertical strip down the center, from mid-image to just above the
   desk, kept simple for the runtime speech bubble.

Hard rules:
 - NO TEXT of any kind.
 - NO real brands, logos, cartoon characters, celebrities, AI
   watermarks.
 - NO people, NO Dashy, NO mascot.
 - NO baked-in trophy icons or mission cards.

Output: a single high-resolution illustration filling the full 3:4
frame, no borders, no UI chrome.
```

---

## 6. Age variants

The hotspot map (§3) is **identical** across all age bands so
`ClassroomSceneModel` does not need to branch per age in MVP. Only the
artwork shifts.

### 6.1 Ages 4–5 (base — `classroom_home_45_*`)

Use the prompts in §4 / §5 verbatim. Soft cut-paper, friendly, calm.
Furniture is generic preschool: chalkboard, bookshelf, trophy display
case, cork mission board, desk + chair, project table, cubby + backpack.

### 6.2 Ages 6–7 (maker lab — `classroom_home_67_*`)

Same hotspot map, same camera angle, same palette. Variations:

- **Chalkboard** becomes a **whiteboard** in a wooden frame (still slate-
  shaped, still empty, no text).
- **Project Table** becomes a **maker workbench** with a clean tool pegboard
  *behind* it on the right wall (pegboard slots may be drawn — do not draw
  recognizable real-brand tools or branded electronics; abstract shapes only).
- **Bookshelf** keeps multi-color spines but adds a few rolled paper
  scrolls and abstract project boxes among the books.
- **Trophy case** unchanged (empty shelves).
- Style stays cut-paper but slightly more confident line weight and a
  hint of grid texture on the table top.

### 6.3 Ages 8+ (AI studio — `classroom_home_8plus_*`)

Same hotspot map, same camera angle, same palette. Variations:

- **Chalkboard** becomes a **flat dark display panel** in a thin wooden
  frame (still empty — no rendered UI, no text).
- **Project Table** becomes a **studio desk** with an abstract keyboard-
  shaped block and an abstract tablet-shaped block (no real device
  outlines, no logos).
- **Mission Board** becomes a **pin-up wall of empty index-card shapes**
  (still no text).
- **Trophy case** unchanged (empty shelves).
- Style stays cut-paper but with calmer, more grown-up ink weights and a
  slightly cooler accent (more `classroomSky` / `classroomPurple` in the
  decoration, less yellow saturation).

In all three variants, **Dashy is never drawn into the background** — the
character is composed at runtime so the same room can host different
mascots in future skinning.

---

## 7. Acceptance criteria for generated artwork

A generated background is acceptable for ship if **all** of the following
are true.

### 7.1 Layout

1. Furniture silhouettes line up with the §3 hotspot map within ±5% on
   each axis.
2. The center column from `x: 0.30…0.66, y: 0.40…0.65` is visually calm
   (no busy patterns, no posters, no high-contrast detail) so the runtime
   speech bubble reads cleanly on top.
3. No two furniture silhouettes overlap each other's hotspot
   rectangle.

### 7.2 Content

4. **Zero** rendered text, numerals, letters, signage, fake typography,
   or readable book spines anywhere in the image.
5. **Zero** real-world brands, real toys, real electronics, real
   characters, real celebrities, AI-tool watermarks.
6. **No people, no Dashy, no mascot.** The room is empty of characters.
7. No baked-in trophy icons, mission cards, lesson previews, or progress
   indicators.

### 7.3 Style

8. Palette stays inside the listed `NovaPalette.classroom*` tokens —
   spot-check against `NovaPalette.swift`. Saturated, not neon.
9. Hand-drawn / cut-paper / soft-chalk feel. Visible but soft ink
   outlines on every major object so the silhouettes read at
   thumbnail scales.
10. Soft daylight, gentle warm shadows, no harsh contrast.

### 7.4 Required clear zones

11. Chalkboard slate is empty and roughly 0.40 × 0.22 of clear surface
    inside the hotspot.
12. Trophy case interior shelves are empty (~0.18 × 0.16 clear).
13. Mission board cork face has at least 0.20 × 0.18 of empty surface.
14. Desk top is clean (~0.20 × 0.08 clear).
15. Project table top is clean (~0.22 × 0.10 clear).
16. Cubby opening is visible at iPad thumbnail scale.

### 7.5 Resolution & format

17. Landscape master delivered at 2732 × 2048 PNG (4 : 3) with @3x
    counterpart at 4098 × 3072.
18. Portrait master delivered at 2048 × 2732 PNG (3 : 4) with @3x
    counterpart at 3072 × 4098.
19. No transparent margins (the image fills the frame); no embedded
    color profile that fights iOS sRGB.

### 7.6 Cross-age consistency

20. Age variants (6–7, 8+) keep the §3 hotspot rectangles unchanged so a
    single `ClassroomSceneModel.home(...)` call site works for all
    variants.

If any item in §7 fails, regenerate before shipping.

---

## 8. Engineering hand-off

- The single source of truth for hotspot rectangles is
  `ClassroomSceneModel.baseHomeObjects(currentLessonId:trophyCount:)`.
  Any change here must round-trip to §3 of this doc; any change to §3
  must round-trip to that function.
- `ClassroomSceneView` performs the orientation-aware scaling. It does
  not read this contract directly; it just consumes
  `ClassroomObject.frame`. Engineers should not normalize hotspots in
  the view layer.
- The runtime overlays — Dashy speech bubble, trophy count sticker,
  highlighted "Tap" badge, disabled "Soon" badge — are all composed by
  SwiftUI in `ClassroomObjectButton.swift`. Designers must keep the
  artwork's zones (§3 "required clear visual object zones") clean enough
  for those overlays to read on top.
- This contract intentionally leaves `voicePicker` and any future
  classroom objects out of the MVP map. New roles should land in
  `ClassroomObjectRole`, get a hotspot rectangle here in §3 first, and
  then ship in the artwork variant in the same slice.
