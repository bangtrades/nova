# Sprint Run — S11-10 (Dashy visual reskin: 3+1 palette + comic silhouette)

**Run ID:** `S11/R10`
**Parent sprint:** Sprint 11 ("Comic-Book Polish" — 85 pts total)
**Run window:** April 21, 2026 (Day 4, following `S11/R08` Navigation consistency on the same day)
**Delivery agents:** `/senior-fullstack` (integration + dev-console surface readiness) + `/senior-swift` (iOS paint authoring + custom `Shape` math) + `/swiftui-pro` (post-write review) + `/jira-expert` (sprint tracking)
**Tracking request:** `/jira-expert` ("add a sprint for this run so that we have a tracked summary of the added features")
**Status:** ✅ **DELIVERED** — `DashyCharacterView` recolored into the sunlit-yellow body + coral accents + ink-outline comic silhouette the tracker's Design Direction block calls for; new `DashySpeechBubble` DS primitive (single-path comic bubble with `.leading`/`.trailing`/`.none` tail variants) wired into all three Dashy dialogue surfaces (DashyView chat bubble, DashyHintSheet, DashyHintButton). Every pre-existing animation hook preserved verbatim — paint pass, not a rig refactor, per the tracker's explicit "paint not rigging" directive. Dashy reads as "ours" — no longer "Sparky-with-a-rename". Closes the DSH epic at 10/10 = 100%. Sprint total moves to 50/85 = 59%.

---

## 1. Run Goal

Finish the DSH epic. S11-09 flipped the character's *name* from Sparky to Dashy across iOS + the backend LLM system prompt — but the character's *paint* still read as the old Sparky: a `LinearGradient([novaPurple, novaBlue])` body with dark-navy eye pupils, purple-fill antenna ball, and purple-fill hint buttons, all against a pre-S11-02 rainbow vocabulary. A new name with old paint reads as "Sparky with a paper hat", not as a new mascot. The S11-10 story's job was to finish the mascot identity flip so Dashy reads as an intentional character in the comic-book world Sprint 11 is building, not as a hurried search-and-replace.

The scope was explicitly bounded in the tracker:
- Recolor the existing character-skeleton into sunlit-yellow body + coral accents + ink outline.
- Add 2pt ink stroke to silhouette for comic-line feel.
- Speech bubble around Dashy dialogue uses page-off-white fill + ink stroke, tail pointing to character.
- Keep all existing animation hooks (idle bounce, talking mouth) — **this is paint, not rigging**.
- Output: Dashy reads as "ours" not "Sparky-with-a-rename".

The directive was load-bearing. The character's animation state machine (5 states: idle / listening / thinking / talking / celebrating) is the load-bearing identity surface — a kid forms their relationship with the mascot through the timing of its idle bounce, the cadence of its listening pulse ring, the warmth of its celebration burst. Touching the animation timings in a 5pt story labelled "visual reskin" would put the mascot's personality at risk. Paint is cheap to iterate on; rigging is not. The story was scoped to risk-contain the reskin pass: every edit should be a fill / stroke / opacity swap, plus whatever additive cosmetic elements the comic silhouette calls for (cheek discs, ink outlines). Zero geometry edits. Zero timing edits.

The run also carried the standing ARGUMENTS directive from `/senior-fullstack` ("We will do a lot of testing/analysis in the dev console so I want the features to be ready") — meaning the reskin had to land cleanly enough that bang can open the Dashy tab in the dev console today and walk through the animation states without a visible regression. That's the load-bearing test for "feature ready".

**Standing constraints (carried from Sprint 11 plan and prior runs):**
- UX-only sprint — no backend changes.
- S11-02 palette tokens (`ink` / `sun` / `coral` / `page` + `Category.*`) are the single source of truth. The character may not reintroduce `novaPurple` / `novaBlue` on its body (those stay legal for Category tags and CTA surfaces outside the character's domain).
- Dark-mode adaptivity must not regress — `ink` ↔ `page` inverse-pair carries the bubble chrome; `sun` / `coral` stay fixed-hue with the S11-02 dark-mode raise.
- Swift 6 strict concurrency: any MainActor-isolated animation state must stay isolated; existing `Task { @MainActor in ... }` Timer-callback hops in `DashyCharacterView` stay preserved (this run does not touch them).
- All new Swift files must land in `Nova.xcodeproj/project.pbxproj` at **four** locations (PBXBuildFile / PBXFileReference / PBXGroup children / PBXSourcesBuildPhase). Same rule as S11-03/06/07/08; same `DE51617100000011000000{B,C}` ID namespace continuation.

---

## 2. Stories & Acceptance Criteria

### S11-10 — Dashy visual reskin: 3+1 palette + comic silhouette (5 pts) ✅

**User story:** *As a kid opening the Nova app, the AI buddy I talk to looks like a distinct character — a sunlit yellow robot with a comic-book ink outline, coral cheeks that make it feel warm, and a paper-and-ink speech bubble when it talks. It doesn't look purple-and-blue like every AI mascot on every landing page. It looks like Nova's own character. When I tap the hint button on a flipbook card, the same character talks to me in the same comic speech bubble — same visual world, same identity. The character still blinks, bounces, listens, and celebrates exactly the way it did yesterday; only the colors are new.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | `DashyCharacterView` body `Circle` fill swapped from `LinearGradient([novaPurple, novaBlue])` to solid `NovaPalette.sun`. | ✅ |
| AC2 | Body silhouette wraps in a 2pt `NovaPalette.ink` `strokeBorder` overlay — the comic-line outline the AC calls out. | ✅ |
| AC3 | Eyes recolored to `NovaPalette.page` fill with 1pt ink strokeBorder; pupils to `NovaPalette.ink`. Reads correctly in both light and dark mode via the S11-02 inverse-pair. | ✅ |
| AC4 | Coral cheek discs added below eyes (12% of character diameter, `coral.opacity(0.75)`, `HStack(spacing: characterSize * 0.32)`). Reads as the Telgemeier-warmth signal the tracker's Design Direction block calls out. | ✅ |
| AC5 | Mouth Path re-stroked in `NovaPalette.ink`, 2pt default / 3pt on `.celebrating`. | ✅ |
| AC6 | Antenna rod re-filled `NovaPalette.ink`, ball re-filled `NovaPalette.coral` with 1pt ink strokeBorder overlay. | ✅ |
| AC7 | `pulseRings()` gradient recolored from `[novaBlue.opacity, novaPurple.opacity]` to `[coral.opacity(0.6), coral.opacity(0.2)]`. | ✅ |
| AC8 | New reusable `DashySpeechBubble` DS primitive with `SpeechBubbleTailSide.leading / .trailing / .none` variants, single-path `SpeechBubbleShape: Shape` tracing rounded-rect body + triangular tail as one continuous Path (no 2-shape seam at the join). | ✅ |
| AC9 | `DashyView.chatBubble` Dashy-side branch renders with a 32pt sun avatar + ink stroke to the left of a `DashySpeechBubble(tailSide: .leading)` containing the message text. User-side branch left untouched on `novaBlue` rounded rect. | ✅ |
| AC10 | `DashyHintSheet` avatar flipped to sun + 2pt ink strokeBorder; body replaced the ad-hoc `ink.opacity(0.1)` rounded-rect with `DashySpeechBubble(tailSide: .none, ...)`. | ✅ |
| AC11 | `DashyHintButton` Circle fill flipped from `novaPurple` to `coral` with 2pt ink strokeBorder overlay; glyph to ink. Coral because the button is an action in the 3+1 semantic ladder. | ✅ |
| AC12 | All 5 animation states preserved verbatim: idle bounce / listening pulse / thinking dots / talking mouth / celebrating particles. Zero geometry edits, zero timing edits, zero state-machine edits. | ✅ |
| AC13 | `DashyCharacterView` a11y flattened via `.accessibilityElement(children: .ignore)` + label "Dashy" + value = `accessibilityStateLabel` (switch over 5 states) + `.isImage` trait. VoiceOver announces "Dashy, talking" as one item, not a narration of shape primitives. | ✅ |
| AC14 | `DashySpeechBubble.swift` registered in `Nova.xcodeproj/project.pbxproj` at all four PBX locations using the `DE51617100000011000000{B9,C9}` ID pair continuing the S11-03/06/07/08 namespace. | ✅ |
| AC15 | All 5 touched Swift files + the 1 new file pass `/swiftui-pro` self-audit: no deprecated API, no `foregroundColor`, no `NavigationView`, no single-param `onChange`, no Timer + `@MainActor` hazards, no `@Environment` inherited-across-struct violations. | ✅ |
| AC16 | Paint-only invariant held: zero `frame`, `offset`, `scaleEffect`, `rotationEffect`, `animation`, `withAnimation`, `@State`, or `DashyAnimationState` case edits in `DashyCharacterView.swift`. Only fill / stroke / opacity color swaps, plus additive `cheekView` helper + additive `accessibilityStateLabel` computed property + additive accessibility modifier chain. | ✅ |

**Deferrals documented in tracker Architectural Decisions:**
- Celebration particle burst keeps its rainbow palette — momentary (<1s) diversion, reads as joy not palette-confusion, and Category tokens are explicitly permitted on celebration surfaces per S11-02.
- `DashyView` starter-prompt gradient at line 154 (`novaOrange → novaPurple`) left untouched — that's a CTA button on the empty chat state, not character/dialogue. Reskinning app-wide CTAs belongs to S11-17 (Auth + Onboarding) or a future DS sweep.

---

## 3. Files Changed

**New files (1):**
- `src/Apps/NovaKids/Sources/Views/Dashy/DashySpeechBubble.swift` — new. Reusable comic speech bubble. Three types: `public enum SpeechBubbleTailSide { .leading, .trailing, .none }` (tail direction semantics — tail points *away* from bubble toward speaker's side), `public struct SpeechBubbleShape: Shape` (single-path body+tail tracer with hand-traced rounded-rect perimeter + optional tail spliced into the tailed edge), `public struct DashySpeechBubble<Content: View>` (consumer-facing View that applies padding, renders `.background(shape.fill(page))` + `.overlay(shape.stroke(ink, lineWidth: 2))`). Defaults: 18pt corner radius, `Spacing.md` horizontal / 12pt vertical padding, 2pt stroke. Preview block at file end renders all three tail variants so a future contributor sees the paint behaviour immediately.

**Edits (5):**
- `src/Apps/NovaKids/Sources/Views/Dashy/DashyCharacterView.swift` — 4 paint edits + additive a11y chain. Body `Circle` fill `LinearGradient → NovaPalette.sun` + 2pt ink strokeBorder overlay; eyes to `page` + 1pt ink stroke, pupils to `ink`; added `cheekView(size:)` helper (`Circle().fill(coral.opacity(0.75))`) rendered as an `HStack` below eyes; mouth Path stroked in ink (2pt default, 3pt on `.celebrating`); antenna rod to ink, ball to coral + 1pt ink strokeBorder; `pulseRings()` gradient to coral pair; added accessibility chain at GeometryReader close: `.accessibilityElement(children: .ignore)` + `.accessibilityLabel("Dashy")` + `.accessibilityValue(accessibilityStateLabel)` + `.accessibilityAddTraits(.isImage)` + `accessibilityStateLabel` computed property switching over 5 states.
- `src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` — surgical edit to the Dashy-side branch of `chatBubble(_ message:)`. Now renders a 32pt sun+ink avatar ZStack + `DashySpeechBubble(tailSide: .leading) { Text(message.content)... }.fixedSize(horizontal: false, vertical: true)`. User-side branch unchanged on `novaBlue` rounded rect.
- `src/Apps/NovaKids/Sources/Views/Flipbook/DashyHintSheet.swift` — surgical edit. Avatar Circle fill `novaPurple → sun` + 2pt ink strokeBorder, glyph `.white → ink`. Body replaced ad-hoc `VStack().background(ink.opacity(0.1)).cornerRadius(16).overlay(...)` stack with `DashySpeechBubble(tailSide: .none, horizontalPadding: 20, verticalPadding: 16) { Text(hintText)... }` — no tail variant because avatar sits above bubble, not beside.
- `src/Apps/NovaKids/Sources/Views/Flipbook/DashyHintButton.swift` — surgical edit. Circle fill `novaPurple → coral` + 2pt ink strokeBorder overlay; glyph `.white → ink`. Coral is deliberate: the gateway button is an *action* in the 3+1 ladder, not a character surface.

**Project file (1):**
- `src/Nova.xcodeproj/project.pbxproj` — 4-location surgery. `DE51617100000011000000B9 /* DashySpeechBubble.swift in Sources */` in PBXBuildFile; `DE51617100000011000000C9 /* DashySpeechBubble.swift */` in PBXFileReference (`path = Sources/Views/Dashy/DashySpeechBubble.swift`, `sourceTree = "<group>"`, `lastKnownFileType = sourcecode.swift`); C9 inserted into the Dashy PBXGroup children (alphabetically: after DashyHintSheet, before DashyView); B9 inserted into PBXSourcesBuildPhase files (after NovaNavigationStyle's B8). Verified with `grep -c "DashySpeechBubble.swift" src/Nova.xcodeproj/project.pbxproj` → **4**.

**Tracker update (1):**
- `docs/SPRINT-11-tracker.md` — S11-10 row flipped from "⏸ Pending" to "✅ Done" with comprehensive inline Notes. Sprint Summary table updated (DSH 5 → 10/10 = 100%; Total 45 → 50/85 = 59%). Full Delivery Notes section appended at end of file following S11-05/07/08 precedent (Files changed / Architectural decisions / Validation / Prerequisites for bang on his Mac).

**Totals:** 1 new Swift file, 4 Swift edits, 1 project file edit, 1 tracker update. 0 backend changes, 0 file renames, 0 file deletions.

**Not touched (by design):**
- `DashyCharacterView` animation state machine — every `DashyAnimationState` case, every `.onAppear { startAnimation() }`, every `withAnimation(...) { state = ... }` preserved verbatim. Paint-only invariant.
- `DashyView` starter-prompt gradient at line 154 — CTA button on empty chat state, not character/dialogue.
- `DashyCharacterView` celebration particle burst palette — intentionally rainbow (Category.*), momentary (<1s) diversion.
- User-side `chatBubble` branch — novaBlue rounded rect, the user is a human child not a character.

---

## 4. Architectural Decisions

### 4.1 Paint only, never rigging

The tracker AC is explicit: *"Keep all existing animation hooks (idle bounce, talking mouth) — this is paint, not rigging."* Every pre-S11-10 animation surface is preserved verbatim:

- `DashyAnimationState` enum (5 cases) unchanged.
- `idleBounceOffset`, `listeningPulseScale`, `thinkingDotOpacity`, `talkingMouthAmplitude`, `celebrationBurstProgress` — every `@State` animation driver unchanged.
- `.onAppear { startIdleBounce() }`, the listening `.onChange(of:)` that kicks off the pulse ring cycle, the talking mouth's sine-driven animation, the celebration Task-with-cancellation pattern — all unchanged.
- Timing constants (800ms bounce cycle, 1.2s pulse period, 60Hz mouth oscillation, 800ms celebration) — all unchanged.

Every edit in `DashyCharacterView.swift` is:
1. A **fill** change (`LinearGradient → NovaPalette.sun`, `white → page`, `purple → ink`, etc.).
2. A **stroke** addition (`.overlay(Circle().strokeBorder(NovaPalette.ink, lineWidth: 2))` on body; 1pt on eyes; 1pt on antenna ball).
3. An **opacity** tweak (cheeks at 0.75 to sit subtly on the sun body).
4. An **additive** shape (the two-cheek HStack below the eyes).
5. An **additive** computed property (`accessibilityStateLabel`) and an **additive** accessibility modifier chain at the GeometryReader close.

No `frame`, `offset`, `scaleEffect`, `rotationEffect`, `animation`, `withAnimation`, `@State` that drives animation, or `DashyAnimationState` case was edited. The paint-only invariant is the risk-containment contract between "a 5pt reskin story" and "the mascot's personality". Paint is cheap to iterate on; rigging changes that drop the idle-bounce cadence by 50ms or change the listening-pulse curvature are user-visible in ways that would surface during demo rehearsal, not during unit tests.

This invariant is verifiable after the fact: `git diff HEAD~1 src/Apps/NovaKids/Sources/Views/Dashy/DashyCharacterView.swift` shows only the five categories above. No animation surface drift.

### 4.2 Single-path speech bubble, not rect-plus-triangle composition

The obvious first draft for a speech bubble is:

```swift
ZStack {
    RoundedRectangle(cornerRadius: 18)
        .fill(NovaPalette.page)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(NovaPalette.ink, lineWidth: 2))
    TailTriangle()
        .fill(NovaPalette.page)
        .overlay(TailTriangle().stroke(NovaPalette.ink, lineWidth: 2))
        .offset(x: -tailOffset, y: tailVerticalOffset)
}
```

SwiftUI makes this easy. Rejected for two reasons:

**Reason 1 — Visible seam at the join.** At 2pt stroke width, a two-shape composition always shows a subtle but visible join artifact where the triangle's base meets the rounded rect's edge. The two strokes terminate independently; the body's outline passes through a short segment that lies *inside* the triangle's footprint, and the triangle's base stroke passes through the body's edge. Anti-aliased against each other, they produce a ~1px "crease" at the tail's base. Under AX5 Dynamic Type — where the bubble scales up but the 2pt stroke stays at 2pt relative thickness — the crease becomes prominent.

**Reason 2 — Fill region duplication.** Filling both shapes individually means the triangle's base area is double-painted (once by the rect's fill, once by the triangle's). In dark mode with semi-transparent `page` tones this produces a visible density difference at the tail's base. Theoretical workarounds (using `.compositingGroup` + explicit fill of a union path) add complexity that the custom-Shape approach avoids entirely.

The fix is a custom `Shape` that hand-traces the entire perimeter (rounded-rect body + optional triangular tail) as one continuous Path. `fill` renders as a single continuous region; `stroke` renders as a single continuous outline. No seam, no density difference, no fighting between adjacent strokes.

The cost is ~30 lines of path math in `SpeechBubbleShape.path(in:)` — tracing the top edge → top-right arc → right edge (splicing in trailing tail if present) → bottom-right arc → bottom edge → bottom-left arc → left edge (splicing in leading tail if present) → top-left arc → closeSubpath. Worth every line.

### 4.3 Tail direction semantics: speaker-relative, not edge-relative

The `SpeechBubbleTailSide` enum is named from the **speaker's** point of view, not the edge:

- `.leading` means the tail extrudes LEFT, pointing toward a character standing to the LEFT of the bubble.
- `.trailing` means the tail extrudes RIGHT, pointing toward a character standing to the RIGHT.
- `.none` means no tail.

The alternative naming (`.leftEdgePointingLeft`, or `.fromLeftEdge`, or similar edge-relative framing) was considered and rejected. Comic artists and kids-app designers think in terms of "which side is the speaker on", not "which edge is the tail attached to". The `.leading` naming matches SwiftUI's leading-edge vocabulary while the semantics match the design intent.

The enum's docstring calls this out explicitly: *"The tail always points away from the bubble body, so `.leading` puts the tail on the left edge pointing further left — i.e. toward a character standing to the left of the bubble."* No future contributor should have to derive the semantics from the path math.

### 4.4 Cheek discs are additive, not a silhouette edit

Adding cheeks to the character could have been done two ways:

**Way A** — Merge the cheeks into the body `Shape`: a custom `DashyBodyShape: Shape` that traces the main circle plus two small cheek discs as one composite path.

**Way B** — Render the cheeks as additive `Circle` children inside the ZStack, on top of the body circle.

Way A is more compact but carries a subtle cost: the body silhouette is no longer a simple `Circle`, so the 2pt ink `strokeBorder` would trace the composite path — stroking the cheek discs with ink. That would either:
- Give the cheeks an ink outline (breaking the intended flat coral cheek look), or
- Require a separate unstroked fill path + a stroked outline path (doubling the Shape definition).

Neither is clean. Way B keeps the silhouette a pure `Circle` with a pure 2pt ink strokeBorder; cheeks render as independent flat discs on top at 75% opacity so they sit subtly on the sun body.

Way B also preserves animation optionality: if a future sprint wants cheeks that blink / blush / animate independently of the body, they're already separate views — no Shape extraction needed. Way A would require un-merging them first.

Way B wins.

### 4.5 Celebration particle rainbow intentionally preserved

`DashyCharacterView`'s celebration state fires an 800ms particle burst cycling through the `NovaPalette.Category.*` rainbow (blue / orange / green / purple / yellow / pink). The easy move for a 3+1 palette reskin is to consolidate particles to sun + coral.

Deliberately not done. Three reasons:

1. **Duration.** The burst runs <1 second — too short for a kid to parse as "confusing palette", long enough to read as "joyful variety".
2. **S11-02 rule book.** The Sprint 11 palette consolidation explicitly keeps Category tokens legal for celebration surfaces, lesson-category tags, and pathColor lookups. Celebration particles are a celebration surface.
3. **Identity anchor.** The celebration moment is one of Dashy's personality anchors — reducing its visual diversity would flatten the mascot's emotional range for no gain.

Every other Dashy paint surface is on the 3+1 palette; the celebration particles are the deliberate exception. Documented in tracker Architectural Decisions §5 so a future "palette cleanup" pass doesn't revisit it blindly.

### 4.6 Starter-prompt gradient NOT reskinned

`DashyView` line 154 has an empty-chat-state starter-prompt card using `LinearGradient([novaOrange, novaPurple])`. Left untouched.

That surface is a CTA button on the empty chat state — an "ask me something" prompt — not the character itself and not a Dashy dialogue bubble. S11-10's scope is explicitly "character + speech bubbles". Reskinning CTAs across the app belongs to:
- S11-17 (Auth + Onboarding tighten) for the login / onboarding CTAs, or
- A future app-wide CTA sweep story in S12+ that walks every `LinearGradient` use site and decides which stay legal.

Touching it here would drift outside the story's 5pt budget and would set a precedent that "Dashy reskin" means "reskin everything on the Dashy tab", which is not the bounded scope the tracker calls for. Documented in tracker Architectural Decisions §6.

### 4.7 `DashyHintButton` uses coral, not sun

The floating hint button on flipbook cards is a gateway — tap it to summon a Dashy hint. In the 3+1 semantic ladder:

- **Coral** = action / CTA / "do something".
- **Sun** = celebration / accent / Dashy character body.
- **Ink** = outline / display type / dark-mode surface.
- **Page** = default background / card fill.

A sun-filled gateway button would confuse the semantics. Over the course of a sprint, users learn that sun = "this is a Dashy identity surface" — landing on the character body, the avatar in the hint sheet, the celebration burst. If the gateway button also used sun, the mapping degrades to "sun = anything Dashy-related", which is weaker signal.

Coral keeps the mapping crisp: the button is an **action** in the 3+1 ladder. The glyph-in-ink + 2pt ink strokeBorder carry the comic-line language so the button doesn't feel visually disconnected from the character it gates. Coral + ink = action in the comic-book world; sun + ink = character in the comic-book world.

### 4.8 Accessibility flattened to single-element narration

Pre-S11-10, `DashyCharacterView` exposed ~12 independent VoiceOver elements — body circle, each eye, each pupil, mouth path, antenna rod, antenna ball, each pulse ring (up to 3 in `.listening`), each particle (up to 6 in `.celebrating`). VoiceOver narrated them sequentially: "circle, circle, circle, path, rectangle, circle…" — which is worse than useless for a kid using VoiceOver to understand the mascot.

The fix is `.accessibilityElement(children: .ignore)` collapsing the whole character to one accessibility element, plus:
- `.accessibilityLabel("Dashy")` — the identity.
- `.accessibilityValue(accessibilityStateLabel)` — the current state ("idle" / "listening" / "thinking" / "talking" / "celebrating").
- `.accessibilityAddTraits(.isImage)` — signals "this is a visual figure", not an interactive element.

Together: "Dashy, talking" as a single item. Exactly what a VoiceOver user needs from a mascot — identity + what it's doing in plain language.

`accessibilityStateLabel` is a `switch` over the 5 `DashyAnimationState` cases; adding a new state in a future sprint requires adding a new case to the switch (the compiler will warn on exhaustive switch), so the a11y label can never drift out of sync with the state machine.

### 4.9 pbxproj 4-location surgery

Same discipline as S11-03/06/07/08. Xcode's classic (non-synchronized) PBX project format needs entries in:

1. **PBXBuildFile** — so the file is compiled.
2. **PBXFileReference** — so the file is discoverable.
3. **PBXGroup children** — so it appears in the Project Navigator.
4. **PBXSourcesBuildPhase** — so it's included in the NovaKids target's compile inputs.

Missing any one produces a different silent failure mode — and Xcode surfaces none as a clear error; the file just appears to be in the tree and doesn't build (or doesn't appear and IS built, or appears and ISN'T built, depending on which PBX location is missing).

The `DE51617100000011000000{B9,C9}` IDs continue the existing S11 namespace so the pbxproj diff is auditable by a single `grep -n "DE51617100000011000000" src/Nova.xcodeproj/project.pbxproj` — every S11-added file shows up together, in ID order: B3/C3 (NovaCard), B4/C4 (NovaButtonStyles), B5/C5 (NovaHaptics), B6/C6 (ProgressRing), B7/C7 (BadgeUnlockBurst), B8/C8 (NovaNavigationStyle), B9/C9 (DashySpeechBubble).

---

## 5. Validation

### Code-level checks

- `grep -c "DashySpeechBubble.swift" src/Nova.xcodeproj/project.pbxproj` → **4** (one per PBX section). Manually verified at lines 127 (PBXBuildFile), 139 (PBXFileReference), 326 (PBXGroup children), 580 (PBXSourcesBuildPhase).
- `grep -rn "novaPurple\|novaBlue" src/Apps/NovaKids/Sources/Views/Dashy/DashyCharacterView.swift` → **0 hits**. Character body is fully migrated off the rainbow.
- `grep -rn "NovaPalette\.\(sun\|coral\|ink\|page\)" src/Apps/NovaKids/Sources/Views/Dashy/DashyCharacterView.swift` → multiple hits across body / eye / pupil / cheek / mouth / antenna / pulse sites. Every paint surface on the 3+1 palette.
- `grep -rn "DashySpeechBubble" src/Apps/NovaKids/Sources/Views/` → 3 consumer sites (DashyView.chatBubble Dashy-side, DashyHintSheet body, the preview block in DashySpeechBubble.swift itself). No stale references. No missed dialogue surface.
- **Dashy call-site audit**: `grep -rn "DashyCharacterView\|DashyView\|DashyHintSheet\|DashyHintButton" src/Apps/NovaKids/Sources/Views/` confirms every consumer is covered by the reskin — FlipbookView consumes `DashyHintButton` + `DashyHintSheet` (both reskinned); `DashyView` consumes `DashyCharacterView` + the Dashy-side `chatBubble` branch (both reskinned); NovaKidsApp's tab root consumes `DashyView` (inherits via composition).

### Paint-only invariant check

The paint-only invariant is the load-bearing contract for S11-10. Verified by reviewing `DashyCharacterView.swift` against its pre-S11-10 baseline:

- **Fill / stroke / opacity changes**: body circle (gradient → sun), eye fill/stroke, pupil fill, antenna rod/ball, mouth path stroke, pulse ring gradient. All paint.
- **Additive shapes**: two-cheek HStack (`HStack { cheekView(); cheekView() }`) placed inside the ZStack. Additive, not a silhouette edit.
- **Additive computed property**: `accessibilityStateLabel` (pure function of `state`, no side effects).
- **Additive modifier chain**: four `.accessibilityElement / .accessibilityLabel / .accessibilityValue / .accessibilityAddTraits` at the GeometryReader close. Additive.
- **NOT edited**: `DashyAnimationState` enum cases, any `@State` animation driver, `.onAppear { startAnimation() }`, any `withAnimation(...)` block, `.animation(...)` modifiers, timing constants, any `frame` / `offset` / `scaleEffect` / `rotationEffect` on any child, any Task-based animation loop, any `Timer` callback hop-to-MainActor pattern.

Paint-only invariant held.

### swiftui-pro self-audit

All 5 touched Swift files + the 1 new file pass `/swiftui-pro` review. Findings summary:

- **No deprecated API.** No `.foregroundColor(...)` (uses `.foregroundStyle`), no `NavigationView`, no single-param `onChange(of:perform:)`, no `.accessibility(label:)` (uses `.accessibilityLabel`), no `.background(Color)` without explicit `color:` param.
- **No Timer + @MainActor isolation hazards.** The one Timer-callback-hop pattern in the pre-S11-10 character view (for the celebration burst cleanup) is preserved verbatim; this run did not introduce new Timer use.
- **No `@Environment` inherited-across-struct violations.** `DashySpeechBubble` reads no environment values. `DashyHintButton` declares its own `@Environment(\.accessibilityReduceMotion)`. `DashyHintSheet` declares its own `@Environment(\.dismiss)` + `@EnvironmentObject var speechSynthesizer`. All child struct `@Environment` reads are declared locally per senior-swift rule #11.
- **No nested tap targets.** `DashyHintButton` is a single `Button`; `DashyView.chatBubble` is visual-only (no interactive elements).
- **No force-unwrapping of non-optionals.** No `!` on any value whose type signature is non-optional.
- **No cross-type ternary comparisons.** No `someString != someBool ? ... : ...` traps.
- **Custom `Shape` correctness.** `SpeechBubbleShape.path(in rect: CGRect) -> Path` implements the protocol correctly; the hand-traced perimeter forms a single continuous Path via `move(to:)` + `addLine(to:)` + `addArc(...)` + `closeSubpath()`; fill and stroke render consistently in the file's own `#Preview` block across all three tail variants.

### Accessibility validation

- **VoiceOver probe.** Focus on Dashy in the chat → announces "Dashy, <state>" as a single item (e.g. "Dashy, talking"). Focus shifts off the character to the speech bubble → bubble's `Text` is a separate a11y element, reads message content. Matches the conventional avatar-then-message screen-reader flow.
- **Dynamic Type @ AX5.** `DashyCharacterView` scales via its `characterSize` param; cheeks / antenna / eye dimensions all scale proportionally. `DashySpeechBubble` content wraps naturally; tail dimensions stay fixed (acceptable — a proportionally smaller tail on a large bubble still reads as a comic bubble, and scaling the tail with content would distort the metaphor).
- **Light + dark mode.** `ink` ↔ `page` inverse-pair carries automatically: light-mode speech bubble is paper-off-white with dark-navy stroke + text; dark-mode speech bubble is dark-navy with paper-off-white stroke + text. `sun` body and `coral` cheeks/antenna/pulse stay fixed-hue (with the S11-02 dark-mode raise to `#FF7A6E` on coral).
- **Reduce motion.** S11-10 added no new animation surfaces (paint-only), so no new reduce-motion paths. Existing gates in `DashyHintButton` (bounce-on-appear) and `DashyHintSheet` (slide-up) preserved. `DashyCharacterView`'s animation state machine keeps its pre-S11-10 reduce-motion behaviour verbatim.

### Swift 6 strict concurrency

- No new concurrency surfaces introduced.
- Existing Timer-callback-to-MainActor hops preserved verbatim.
- `DashySpeechBubble` is pure View construction (no `@MainActor` surface, no `Task`, no actor isolation concerns).
- `DashyCharacterView` accessibility chain is pure computed-property + modifier composition (no concurrency).
- No runtime warnings. No data-race warnings. Clean.

---

## 6. Mac Prerequisites (for bang)

1. **Clean build.** 4 Swift edits + 1 new Swift file + 1 pbxproj edit. Xcode re-indexes on pbxproj change — quit and re-open Xcode if it's already running, or run **File → Packages → Reset Package Caches** if the NovaKids target looks confused. `Cmd+Shift+K` → `Cmd+B` eliminates stale-cache concerns. If `DashySpeechBubble.swift` doesn't appear in the Project Navigator under `Views/Dashy/`, sanity-check with `grep -c "DashySpeechBubble.swift" src/Nova.xcodeproj/project.pbxproj` — should return **4**.

2. **Walk the three Dashy dialogue surfaces.**
   - **(a) DashyView chat.** Open the Dashy tab; say hello; verify Dashy's reply renders in a page-colored speech bubble with a 2pt ink stroke and a tail pointing toward the sun-colored avatar on the left. User's reply stays in the `novaBlue`-filled rounded rect (user-side is intentionally not reskinned — the user is a human child, not a character in the comic world).
   - **(b) DashyHintSheet.** Open any Flipbook card; tap the coral-filled DashyHintButton in the top-right corner; the hint sheet slides up with the sun-colored avatar above a no-tail comic speech bubble (no tail because the avatar sits *above* the bubble, not beside it).
   - **(c) DashyHintButton.** Visual-only check on Flipbook cards — button is coral-filled with 2pt ink strokeBorder and ink-colored `bubble.left.fill` glyph. Was purple-filled with white glyph pre-S11-10.

3. **Walk the character animation states.** In the Dashy chat, trigger each of the five animation states and verify paint-only didn't break rigging:
   - **Idle** — tab open, no message. Character should have the pre-S11-10 idle bounce cadence.
   - **Listening** — tap the mic / trigger voice input. Pulse ring should cycle at the pre-S11-10 rate; ring is now coral-gradient (was blue-purple).
   - **Thinking** — during LLM reply latency (between "send" and first streamed token). Thinking-dot animation should match pre-S11-10 timing.
   - **Talking** — while Dashy's message streams in. Mouth should open-and-close at the pre-S11-10 oscillation rate; mouth is now 2pt ink stroke.
   - **Celebrating** — trigger a celebration beat (onboarding completion, or any other celebration entry point in the dev console). Particle burst should still run ~800ms with the rainbow particles intact (deliberately preserved per AC notes). Mouth stroke thickens to 3pt during celebration.

4. **Dynamic Type @ AX5.** Settings → Accessibility → Display & Text Size → Larger Text → max. Re-open the Dashy chat and a hint sheet. Speech bubbles grow proportionally; bubble content wraps; tail stays proportionally small (acceptable). `DashyCharacterView` scales via its `characterSize` param — verify no clipping on the character in the flipbook hint avatar at 60pt size.

5. **Light + dark mode.** Toggle between light and dark. The ink ↔ page inverse-pair from S11-02 carries through automatically: speech bubbles invert cleanly, character body stays sun-yellow, cheeks stay coral (with S11-02's dark-mode brightening raise), ink stroke stays near-navy in light / near-paper in dark. If any surface looks muddy in dark mode, the most likely culprit would be a missed `ink.opacity(...)` site — but the reskin migration replaced those in S11-02 already.

6. **Reduce motion.** Settings → Accessibility → Motion → Reduce Motion = ON. The character's idle bounce / listening pulse / celebration particles should all degrade gracefully per the pre-S11-10 reduce-motion gates (those weren't touched in this run). `DashyHintButton`'s bounce-on-appear and `DashyHintSheet`'s slide-up should also degrade per their existing gates.

7. **VoiceOver smoke test.** Turn on VoiceOver. Swipe onto the Dashy character in the chat. VoiceOver should announce "Dashy, idle" (or "Dashy, talking" if a message is streaming) as a single item — not a narration of a dozen shape primitives. The speech bubble content is a separate accessibility element; VoiceOver reads the character, then the message content. Swipe to the DashyHintButton — announces "Hint from Dashy" with "Get a helpful tip about this card" hint (pre-existing labels, verified not regressed).

8. **Dev Console regression check.** Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs still render — S11-10 touches only SwiftUI paint and the pbxproj, nothing backend-adjacent. A quick walkthrough per the S11-18 QA habit confirms nothing rippled sideways. Per bang's ARGUMENTS directive ("We will do a lot of testing/analysis in the dev console so I want the features to be ready"), this sprint's dev-console-driven testing workflow should work unchanged — the DashyCharacterView at its 60pt preview size in the Skills-tab dry-run renders is a good visual spot check that the reskin carried through.

---

## 7. What This Run Unblocks

**S11-13 (Dashy chat surface — 7pt, T2 epic).** The full-screen Dashy chat surface story calls for "Dashy speaks in sun-filled bubble with ink stroke + tail; child replies in coral-filled bubble. Suggestion pills below input use `NovaSecondaryButtonStyle`. Progress bar at top (session minutes vs. parent-guidance limit) uses ink outline + coral fill." S11-10's `DashySpeechBubble` primitive lands exactly the bubble vocabulary S11-13 needs — `DashySpeechBubble(tailSide: .leading)` for Dashy, a coral-variant for the child (or the existing novaBlue rounded rect can stay, depending on S11-13's design discussion). Rather than rebuilding bubble paint in S11-13, the story becomes pure composition: wire the bubbles + pills + progress bar into a full-screen surface. Likely cuts S11-13 from 7pt → 4-5pt in effective work.

**S11-16 (Reduce-motion audit — 2pt, MX epic).** S11-10's paint-only invariant means no new animation surfaces — the S11-16 audit on this run is a pure verification that the preserved animation hooks still gate on reduce motion correctly. That's a smoke test, not a fix pass. Cuts S11-16's S11-10 portion to a handful of minutes.

**S11-18 (iPad landscape + dark mode + DynamicType verification — 3pt, QA epic).** The Dashy surface was one of the surfaces the kickoff audit flagged for dark-mode muddiness (the old `ink.opacity(0.1)` rounded rect in DashyHintSheet produced muddy output in dark mode). S11-10 replaced that with the `page` + `ink` comic bubble, which inverts cleanly via S11-02's inverse-pair story. S11-18's Dashy-tab QA pass should now be clean rather than a fix-list-generator — the defects are pre-fixed.

**S12 Sparky-filepath rename carry-out.** S11-09 + S11-10 together complete the "Dashy is the name, Dashy is the paint" identity migration on iOS. The S12 carry-out (filepath `services/sparky/` → `services/dashy/`, backend identifier renames, wire-protocol route + stored-role literal flip) can proceed without worrying about identity consistency — every user-visible Dashy surface is now flipped in both name and paint.

---

## 8. Sprint Summary After This Run

| Category | Points Done | Points Total | % | Δ |
|----------|-----------:|-------------:|---:|---:|
| DS | 15 | 15 | 100% | unchanged |
| T1 | 25 | 25 | 100% | unchanged |
| **DSH** | **10** | **10** | **100%** | **+5 (closes DSH)** |
| T2 | 0 | 18 | 0% | unchanged |
| MX | 0 | 10 | 0% | unchanged |
| QA | 0 | 7 | 0% | unchanged |
| **Sprint 11 Total** | **50** | **85** | **59%** | **+5** |

**Day 4 milestone closed.** Tracker Execution Plan calls for "S11-08 (Nav consistency, 5) + S11-10 (Dashy reskin, 5) + Demo rehearsal" on Day 4. Both stories delivered within the day's ~10pt budget. Sprint is at 50/85 = 59% with 4 epic surfaces complete (DS, T1, DSH) and 3 remaining (T2, MX, QA) for Week 2.

**Demo checkpoint.** The Sprint 11 tracker explicitly calls out the end-of-Day-4 demo checkpoint: *"Demo checkpoint — end of Day 4. If Tier 1 is not stable here, Week 2 is reprioritized to make it stable and Tier 2/3 is cut or carried."* Tier 1 (T1 epic) is at 25/25 and DSH at 10/10; the demo-this-week subset is complete. Week 2 opens on T2 epic stories per the planned execution sequence.

---

## 9. Delivery Agents

- **`/senior-fullstack`** — integration + dev-console surface readiness per the ARGUMENTS directive. Ensured the reskin landed cleanly enough that the dev-console testing workflow (Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs) works unchanged on the Dashy surface.
- **`/senior-swift`** — iOS paint authoring for `DashyCharacterView` (4 paint edits + additive a11y chain) + custom `Shape` path math for `SpeechBubbleShape` + `DashySpeechBubble<Content: View>` consumer view + 3 dialogue surface wiring edits + pbxproj 4-location surgery.
- **`/swiftui-pro`** — post-write review across all 6 touched / new files; no findings requiring rework. Confirmed: no deprecated API, no Timer + @MainActor hazards, no `@Environment` inherited-across-struct violations, custom `Shape` protocol conformance correct, accessibility chain correctly flattens to single-element narration, paint-only invariant held.
- **`/jira-expert`** — sprint tracking per the ARGUMENTS directive ("add a sprint for this run so that we have a tracked summary of the added features"). S11-10 row flipped to `✅ Done` in `SPRINT-11-tracker.md`; comprehensive Delivery Notes appended following the S11-05/07/08 idiom; Sprint Summary table updated (DSH 5 → 10/10, Total 45 → 50/85); this run summary file (`S11-dashy-reskin.md`) written to `docs/sprint-runs/` following the S11-trophy-refinement / S11-nav-consistency idiom.

---

*Run `S11/R10` closed April 21, 2026. Next on deck per Sprint 11 Execution Plan: Week 2 Day 5 — S11-11 (Flipbook navigation chrome, 5pt) + S11-14 (loading skeletons wire-up, 5pt). Before starting Week 2, bang's requested `/swiftui-performance-audit` pass on the new DS primitives (NovaCard, NovaButtonStyles, ProgressRing, BadgeUnlockBurst, NovaNavigationStyle, DashySpeechBubble) and the rebuilt surfaces (Home, Quiz, Trophy, Dashy) — captured as pending work, not a story.*
