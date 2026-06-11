# Nova V2 "Classroom" — Program Tracker

**Program:** Surface re-architecture of the NovaKids iPad app from a Pinterest card-grid into an immersive 2.5D classroom. Backend, pipeline, skill-engine, and intelligence layers are kept as-is.
**Plan of record:** [`NOVA-V2-sprint-plan.md`](./NOVA-V2-sprint-plan.md) — 4 sub-sprints, ~168 pts.
**Status:** 🟢 Active — V2-S1/S2/S3 substantially landed; **V2-S4 in progress, gated on art-asset generation.**
**Tracker created:** May 22, 2026 (retroactively, to close the audit gap — see [Why this tracker exists late](#why-this-tracker-exists-late)).
**Supersedes:** SPRINT-14 "Playable" (cancelled — see `SPRINT-14-tracker.md`).
**Demo path:** Xcode-built Debug iPad on same wifi as Mac backend. Same LAN `NOVA_BACKEND_HOST` setup as S13/S14.

---

## Why this tracker exists (late)

The V2 classroom redesign was implemented across 12 `feat(kids):` commits (`2f58ba9` → `5f4f5f5`, May 4–11) and 69 agent-work-slice logs in the Cortana vault (`projects/novai/slices/`, Apr 29 – May 11), but **no execution tracker was ever produced** — the disciplined `SPRINT-N-tracker.md` cadence that covered S9–S14 stopped exactly when the pivot started. The May 22 development health audit (`cortana-vault/projects/novai/novai--dev-health-audit-2026-05-22.md`) flagged this as the highest-leverage navigability fix. This tracker closes that gap: it takes the 4-sprint plan in `NOVA-V2-sprint-plan.md` and reconciles each story against what actually shipped (git history + the 69 slices), so V2 progress is measurable again.

**Status legend:** ✅ done · 🟡 partial / shipped-with-debt · ⬜ not started · ❌ planned-not-done (gating).

---

## Program Summary

| Sub-sprint | Theme | Planned | Landed | Status |
|---|---|---:|---:|:---:|
| V2-S1 | Classroom Foundation | 40 | ~37 | ✅ closed (1 debt item) |
| V2-S2 | Home & Lesson Object Navigation | 42 | ~38 | ✅ closed (kid-test 1 skipped) |
| V2-S3 | Chalkboard Flipbook & Classroom Cards | 44 | ~41 | ✅ closed (QA code-level only) |
| V2-S4 | Rewards, Art, Polish, Kid Testing | 42 | ~14 | 🟢 **active — art-gated** |
| **Program total** | | **168** | **~130** | **~77%** |

The headline: **the classroom code shell is ~done; the classroom *experience* is not** — because V2-S4-02 (art-asset integration) has not happened. Every art slot currently renders a SwiftUI shape-fallback. bang is generating the ~110 specced assets now (see [`novai--v2-beta-art-asset-list.md`](../../Cortana/cortana-vault/projects/novai/novai--v2-beta-art-asset-list.md) in the vault).

---

## V2-S1 — Classroom Foundation ✅

Landed Apr 29 – May 4 (vault slices `2026-04-29--*`, `2026-05-04--*`; commits `5e8b778`–`496dd00`).

| ID | Story | Pts | Status | Notes |
|---|---|---:|:---:|---|
| V2-S1-01 | Classroom design tokens | 5 | ✅ | `NovaPalette.classroom*` semantic colors + accessors. Slices `classroom-token-layer` / `-adoption`. |
| V2-S1-02 | Classroom scene model | 5 | ✅ | `ClassroomSceneModel` shipped + **35 unit tests**. May 22: model extracted into the `NovaClassroom` SPM package, tests run as `NovaClassroomTests` on the build graph (symlink package retired). Pending one Xcode wiring step on bang's Mac. |
| V2-S1-03 | Classroom background shell | 8 | ✅ | `ClassroomSceneView` + `ClassroomBackgroundView`, placeholder shape-art, stable hit zones portrait + landscape. |
| V2-S1-04 | Object button primitive | 5 | ✅ | `ClassroomObjectButton` — 88×88pt hit zones, bounce/haptic, VoiceOver labels, reduce-motion. |
| V2-S1-05 | Dashy guide layer v1 | 5 | ✅ | `ClassroomDashyGuideLayer` — reuses existing Dashy + speech bubble; tap-to-repeat narration. |
| V2-S1-06 | Feature flag + route integration | 5 | 🟡 | Flag exists but is a hard-coded `classroomV2Enabled = true` literal in `HomeView.swift:4`. **No runtime fallback path to the legacy grid Home is wired** — see [Risk register](#risk-register). |
| V2-S1-07 | Image prompt validation pass | 3 | 🟡 | First `Assets.xcassets` created with solid-cream placeholder imagesets marked "do not ship." Art direction not finalized in-app. |
| V2-S1-08 | Sprint QA + kid-readability check | 4 | 🟡 | `xcodebuild … BUILD SUCCEEDED` only. No simulator screenshot / VoiceOver hardware pass recorded. |

---

## V2-S2 — Home & Lesson Object Navigation ✅

Landed May 4 – May 7 (vault slices `bookshelf-*`, `mission-board-*`, `home-data-adapter`, `classroom-home-shell`).

| ID | Story | Pts | Status | Notes |
|---|---|---:|:---:|---|
| V2-S2-01 | Home data adapter | 5 | ✅ | `HomeViewModel` / `LessonsViewModel` data mapped into `ClassroomSceneModel`. |
| V2-S2-02 | Generated lesson object derivation | 5 | ✅ | Object-kind derivation shipped + tested (35 tests, shared with V2-S1-02, now in the `NovaClassroom` package). |
| V2-S2-03 | Classroom Home v1 | 8 | ✅ | Flag-on Home renders the classroom with real user data. `HomeView` → `ClassroomSceneView` is the live route. |
| V2-S2-04 | Bookshelf lesson library | 8 | ✅ | `ClassroomLessonLibraryView` — path sections, completion/new badges, accessible labels, empty state. |
| V2-S2-05 | Bulletin board new-lesson state | 5 | ✅ | `mission-board-visual` — glowing new-lesson objects, Dashy points to newest. |
| V2-S2-06 | Classroom empty / error states | 4 | ✅ | In-world empty + error states; cached objects stay visible on error. |
| V2-S2-07 | Narration scripts | 3 | ✅ | `classroomHome` / `classroomBookshelf` scripts via `NavigationNarrator` (S14-VF service, kept per V2 plan). |
| V2-S2-08 | Sprint QA + **kid test 1** | 4 | ❌ | **The end-of-S2 object-navigation kid test was not run.** No sprint-run note exists. This is a real gap — the plan made it an explicit gate. |

---

## V2-S3 — Chalkboard Flipbook & Classroom Cards ✅

Landed May 4 – May 9 (vault slices `*-chalkboard-surface`, `flipbook-*`, `*-workbook-page-materials`).

| ID | Story | Pts | Status | Notes |
|---|---|---:|:---:|---|
| V2-S3-01 | Chalkboard card container | 8 | ✅ | `ChalkboardLessonCardSurface` primitive. |
| V2-S3-02 | Story card redesign | 5 | ✅ | **Reworked mid-sprint:** initial chalkboard surface removed in favour of `LessonBookPageSurface` ("a card on a chalkboard on a book" = double chrome). Approach reversal, documented in slice `story-concept-workbook-page-materials`. |
| V2-S3-03 | Concept card redesign | 5 | ✅ | Same `LessonBookPageSurface` rework. |
| V2-S3-04 | Magnetic quiz card | 8 | ✅ | Magnetic-tile quiz options + Dashy hint + haptic + reduce-motion fallback. |
| V2-S3-05 | Project table experiment card | 8 | ✅ | Experiment cards as table trays; existing drag/drop preserved. |
| V2-S3-06 | Voice prompt card | 4 | ✅ | Dashy prompt + mic badge; listening state visually + accessibly clear. |
| V2-S3-07 | Completion transition | 3 | ✅ | Completion writes to trophy shelf; `LessonCompletionStore` remains source of truth. |
| V2-S3-08 | Sprint QA + regression | 3 | 🟡 | Build pass only. No VoiceOver / reduce-motion / per-card device walkthrough recorded. |

**Dead-code left by the S3 rework:** `classroomCardStage` is acknowledged-dead pending cleanup (superseded by `LessonBookReaderShell`). See [Carry-debt](#carry-debt).

---

## V2-S4 — Rewards, Art, Polish & Kid Testing 🟢 ACTIVE

The current sprint. Started ~May 11. **Art-asset generation (V2-S4-02) is the gate** — bang is producing the ~110-asset catalog now.

| ID | Story | Pts | Status | Notes |
|---|---|---:|:---:|---|
| V2-S4-01 | Trophy shelf redesign | 6 | ✅ | Trophy room reskinned; existing trophy data maps to shelf rewards. Art-slot contracts (`ClassroomRewardArtSlot`, 16/16 slots) wired. |
| V2-S4-02 | **Classroom art asset integration** | 8 | ❌ | **THE GATE.** Art-slot contract system is built (`LessonArtSlot`, `ClassroomLibraryArtSlot`, `ClassroomRewardArtSlot` + resolution caching) but **zero painted PNGs ship** — every slot renders a SwiftUI fallback. bang generating assets per the v2-beta-art-asset-list. |
| V2-S4-03 | Age profile visual variants | 6 | ✅ | Age-band routing live — `.classroom45` / `.makerLab67` / `.aiStudio8Plus`. 8+ falls back to maker-lab profile until 8+ art ships. |
| V2-S4-04 | Parent-safe controls | 4 | 🟡 | Voice picker / mute / settings present; "visually adult-coded, not a primary child object" treatment not fully verified. |
| V2-S4-05 | Classroom sound + reaction pass | 5 | 🟡 | Bounce + haptic on object taps exist (`ClassroomObjectButton`). Consistent particle-burst pass + reduce-motion strip not confirmed across all surfaces. |
| V2-S4-06 | Performance pass | 4 | 🟡 | May 11 perf-audit slice ran (`v2-classroom-swiftui-performance-code-audit` — "no P0 blocker"). Recommended caching + downsampling **not yet applied.** |
| V2-S4-07 | Kid test 2 | 4 | ⬜ | Blocked on art — a kid test against shape-placeholders tests plumbing, not the experience. Run after art integration. |
| V2-S4-08 | Release decision + cleanup | 5 | ⬜ | Decide whether classroom replaces Home by default (currently hard-`true`). Document known issues + screenshots for TestFlight. |

### V2-S4 fix-pack (from the May 11 audit slices)

The two May 11 audit slices (`v2-beta-kid-flow-and-art-import-risk-audit`, `v2-classroom-swiftui-performance-code-audit`) rated the build "medium risk / not beta-ready" and recommended four fix-slices before broad art import. **All four are pure code — art-independent — and are the [parallel dev lane](#parallel-dev-lane) while art is generated.**

| ID | Story | Pts | Status | Notes |
|---|---|---:|:---:|---|
| V2-S4-F1 | Kid-flow hit-target audit | 3 | ✅ | Audit-only slice (May 22 batch) — every primary classroom-home object already met the 88×88pt floor, reduce-motion gated. Zero code change. Run summary: `sprint-runs/V2-S4-fixpack-2026-05-22.md`. |
| V2-S4-F2 | Kid-safe fallback / error copy | 2 | 🟡 | Bookshelf empty state done (May 22 batch) — kid-safe copy + voiced `classroomBookshelfEmpty` line. **Gap:** error states + `homeEmpty`/`lessonsEmpty`/`trophyRoomEmpty` registry cases not yet reviewed → follow-up slice. Uncommitted. |
| V2-S4-F3 | Experiment-card affordance clarity | 3 | ✅ | Done (May 22 batch) — finger-tap badge, lift shadow, breathing pulse on draggables; underglow + thicker stroke + bobbing filled-arrow on drop targets; every motion cue has a static reduce-motion fallback. +113 LOC. Uncommitted, pending Mac build verify. |
| V2-S4-F4 | Post-art iPad verification pass | 2 | ⬜ | After art lands: full device walkthrough, both orientations, reduce-motion, VoiceOver. Gated on V2-S4-02. Fold in an F1 hit-target spot-check. |

---

## Definition of Done (program)

- [ ] Classroom v2 is the default Kids experience, with a **tested** path back to legacy Home if a blocker surfaces.
- [ ] Every art slot renders a real painted asset (or a deliberately-accepted stylized fallback — see [decision needed](#decision-needed-art-pipeline)). No solid-cream placeholders.
- [ ] Kid test 1 (object-nav comprehension) **and** kid test 2 (full classroom loop) both run and written up as sprint-run notes.
- [ ] The 4 fix-pack slices land.
- [ ] Scene-model + object-derivation unit tests exist (closes V2-S1-02 / V2-S2-02 debt).
- [ ] `classroomCardStage` dead code removed.
- [ ] Performance pass recommendations (caching, downsampling) applied; no memory warnings on target iPad.
- [ ] Release decision documented; TestFlight screenshots captured.

---

## Decision needed — art pipeline

The single highest-leverage open decision. Pick one:

1. **Generate the full ~110-asset catalog** (bang's current path). Highest-quality result; longest path. Every additional `feat(kids):` shell commit until then widens the gap between "code complete" and "shippable."
2. **Accept stylized SwiftUI shape-art as the v1 visual.** Rewrite the art contract to make the shape-fallbacks the intended look, ship sooner, treat painted art as v2.1. Lower ceiling, immediate unblock.

Until this is decided, V2-S4-02 stays ❌ and the program cannot close. bang is pursuing (1).

---

## Parallel dev lane

Work that is **art-independent** and can proceed in full while the art catalog is generated:

- **V2-S4 fix-pack F1/F2/F3** — hit targets, kid-safe copy, experiment affordances. Pure code.
- **Scene-model + object-derivation unit tests** (V2-S1-02 / V2-S2-02 debt). The plan asked for them; they were skipped.
- **`classroomCardStage` dead-code removal.**
- **iOS↔backend contract test** (audit rec #4) — one test file decoding recorded real backend responses into iOS models. Would have caught 5 of the last ~15 production-reaching bugs.
- **Backend `tsc` baseline burndown** — 33 errors (down from 51); finish it to zero.
- **Backend deployment prep** (audit rec #8) — S8 "Infrastructure" never ran; TestFlight is structurally impossible without a deployed backend. This is the true critical-path blocker and needs no art.

V2-S4-F4 (post-art verification) and V2-S4-07 (kid test 2) are the only V2-S4 items genuinely blocked on art.

---

## Carry-debt

| Item | Origin | Notes |
|---|---|---|
| ~~Scene-model test packaging decision~~ → **resolved May 22** | V2-S1-02 / V2-S2-02 | Decision taken: extract. `ClassroomSceneModel` moved into a new `NovaClassroom` SPM package (`src/Packages/NovaClassroom/`); the symlink package deleted; the 35 tests now run as `NovaClassroomTests` on the build graph. Remaining: one Xcode step on bang's Mac to wire NovaClassroom as a NovaKids target dependency (see Delivery Notes). |
| F2 error states + remaining `*Empty` registry cases | V2-S4-F2 (May 22 batch) | F2 covered the bookshelf empty state only. Error states + `homeEmpty`/`lessonsEmpty`/`trophyRoomEmpty` unreviewed → follow-up slice. |
| `classroomCardStage` dead code | V2-S3 rework | Superseded by `LessonBookReaderShell`; not removed. |
| `EnhancedHomeView` orphaned | V2-S2 (live Home moved to `ClassroomSceneView`) | Referenced only in a `#Preview`. The S14-VF `.narrate("home")` call site sits on it, dead. |
| `classroomV2Enabled` hard-coded `true` | V2-S1-06 | No tested rollback to legacy Home. |
| Performance recommendations unapplied | V2-S4-06 | Caching + downsampling from the May 11 perf audit. |
| `architecture.mermaid` was stale | pre-existing | Fixed May 22 alongside this tracker. |

---

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Art generation overruns; program stalls art-gated | Medium | High | Parallel dev lane keeps non-art work moving; decision §"art pipeline" offers a shape-art fallback. |
| `classroomV2Enabled` hard-`true` with no rollback | Medium | Medium | Wire a real runtime flag + keep legacy Home reachable until V2-S4-08 release decision. |
| Kid test 1 was skipped — object-nav comprehension unvalidated | High (already happened) | Medium | Fold a comprehension check into kid test 2, or run a quick standalone session now. |
| No tests on the new classroom surface | High | Medium | Scene-model + contract tests in the parallel lane. |
| Backend still not deployed | High | High | S8 Infrastructure — true TestFlight blocker, art-independent, should start now. |

---

## Delivery Notes

*V2-S1, V2-S2, V2-S3 landed before this tracker existed — their delivery record is the 69 vault slices in `cortana-vault/projects/novai/slices/` (Apr 29 – May 11) and commits `2f58ba9`→`5f4f5f5`. V2-S4 delivery notes are filled in here as stories close, following the SPRINT-10/11/12/13 idiom.*

### V2-S4 fix-pack + scene-model tests — 4-agent parallel batch (May 22)

Four file-disjoint agent slices ran in parallel while the art catalog was generated. Full reconciliation: [`sprint-runs/V2-S4-fixpack-2026-05-22.md`](./sprint-runs/V2-S4-fixpack-2026-05-22.md).

- **V2-S4-F1** ✅ — hit-target audit, zero-change (surface already passed).
- **V2-S4-F2** 🟡 — bookshelf empty-state kid-safe copy + voiced line. In-scope; error states deferred to a follow-up slice.
- **V2-S4-F3** ✅ — experiment-card drag/drop affordances (badge / shadow / pulse / underglow), all motion cues reduce-motion-gated. +113 LOC. Cleanest slice of the batch.
- **V2-S1-02 / V2-S2-02** 🟡 — 35 `ClassroomSceneModel` unit tests delivered, but via a symlinked SPM package off the app build graph — **drift; needs a packaging decision** (recommend extracting `ClassroomSceneModel` into a real SPM package).

**Status:** all four delivered to the working tree, **uncommitted** — review checkpoint. Agent `BUILD SUCCEEDED` / 35-tests-pass claims are **unverified** (no Xcode in the sandbox); Mac-side build + `swift test` is the gate before commit. **Process change:** future agent slice briefs must include the slice-report instruction (see the run summary's "Slice-report protocol" section) so slices self-document instead of evaporating into chat recaps.

### ClassroomSceneModel extracted into the NovaClassroom package (May 22)

Resolving the Slice-4 drift. `ClassroomSceneModel.swift` (505 LOC, pure model logic, imports only CoreGraphics/Foundation/NovaCore) was misfiled under `Apps/NovaKids/Sources/Views/Classroom/` and only testable via Agent 4's symlink workaround. Done in the sandbox:

- New SPM package `src/Packages/NovaClassroom/` — `Package.swift` (depends on NovaCore), `Sources/NovaClassroom/ClassroomSceneModel.swift` (`git mv`'d, history preserved), `Tests/NovaClassroomTests/ClassroomSceneModelTests.swift` (the 35 tests, de-symlinked — import flipped `ClassroomSceneSubject` → `NovaClassroom`).
- Symlink package `NovaKidsClassroomTests/` deleted.
- `import NovaClassroom` added to the 6 app files that reference the model (HomeView + 5 Classroom views).
- `NovaClassroom` registered in `Nova.xcworkspace`.
- The model is already heavily `public` (Agent 4's standalone package proved it compiles against NovaCore alone) — no access-modifier sweep needed.

**Mac step required — one Xcode operation, can't be done safely from the sandbox.** After pulling: (1) the NovaKids project navigator shows `ClassroomSceneModel.swift` as a red/missing reference (moved on disk) — remove that dangling reference (right-click → Delete → Remove Reference). (2) NovaKids target → General → "Frameworks, Libraries, and Embedded Content" → `+` → add the `NovaClassroom` library product. (3) Build. Xcode writes the correct `XCSwiftPackageProductDependency` entries — far safer than hand-editing pbxproj. Then `swift test --package-path src/Packages/NovaClassroom` confirms the 35 tests.

---

*Tracker created May 22, 2026, retroactively, to close the audit-flagged navigability gap. Reconciles `NOVA-V2-sprint-plan.md` against git history + the Cortana vault slice record. Companion to the [development health audit](../../Cortana/cortana-vault/projects/novai/novai--dev-health-audit-2026-05-22.md).*
