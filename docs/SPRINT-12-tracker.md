# Sprint 12 — "Touch Test" — Progress Tracker

**Sprint dates:** May 4 – May 17, 2026
**Goal:** Put the iPad app in bang's kid's hands. By end of Week 1, the content-authoring loop works end-to-end: bang opens the Dev Console on his Mac, drafts a lesson, the skill-engine generates the cards, the iPad (on LAN) picks up the new content and renders it comic-book-style. By end of Week 2, three real lessons exist, a kid-safe session has been run, and the defects that actually broke during touch-test are fixed. This sprint is the pivot from "the app looks finished" (S11) to "the app is usable" (S12) — every story either unblocks the touch-test loop or retires debt that's in the way of it.
**Velocity target:** 60 pts (UX + backend mixed sprint — back to S10-style cadence after S11's UX-only sprint).
**Carry-in from S11:** 8 pts QA defects (S11-18 audit inventory — three follow-up stories S12-01/02/03). 5 pts rename debt (Sparky filepath + wire-literal carve-outs from S11-19 MVP epic).
**Carry-in from S10:** 18 pts content-engine expansion (`experiment-designer`, `curriculum-architect`, `voice-persona` skills — deferred from S10 to keep S11 as a UX-pure sprint).
**Demo path:** Same as S11 — Xcode-built Debug iPad on same wifi as Mac backend. No TestFlight, no submission, no tunnels. The *entire point* of this sprint is to stress-test that loop with real content and a real kid.

---

## Why this sprint exists (the framing)

S11 shipped the aesthetic wrapper and S11-19 punctured the "iOS-only" fence to wire every Tier 1 surface to the real `APIRouter`. That means as of Sprint 12 Day 1, the iPad is *capable* of rendering live data — but there's no content in the pipeline, the Sparky→Dashy rename is only half-done (wire literals + filepaths still say Sparky), and S11-18's code-review audit surfaced 12 iPad defects that will bite the first time bang's kid tilts the iPad to landscape or cranks the text size. This sprint closes all three gaps in one pass so the next time bang hands the iPad to a kid, nothing is apologetic.

**Three questions this sprint answers:**

1. **"Can I create a lesson?"** — content authoring Dev Console + the three carry-from-S10 skill defs (`experiment-designer`, `curriculum-architect`, `voice-persona`) land the full 5-modality skill-engine that's been waiting since S10-12. Without the carry-from-S10 skills, the skill-engine only generates story + quiz atoms; the experiment + voice card types still fall back to legacy generation, which is what landed in S10-12 as the carry path.
2. **"Can my kid touch it?"** — iPad QA debt from S11-18 (layout adaptivity, Dynamic Type, dark-mode contrast) retired. Kid-safe session boundaries (parental gate + session time) validated end-to-end.
3. **"Is the identity coherent?"** — Sparky→Dashy filepath + wire-literal rename closes the `/sparky/chat` + `role == "sparky"` asymmetric-rename debt that S11-09 documented as an S12 coordinated-migration carve-out. After this sprint, Sparky is a dead word anywhere in the codebase.

---

## Epic breakdown

### CAR Epic — Carry-in iPad QA (8 pts)

Retires the S11-18 audit's 12-finding defect inventory. Sequenced **first in Week 1** because every story below lands on iPad surfaces — fixing layout adaptivity + Dynamic Type now means the rest of the sprint doesn't re-rediscover the same defects five times over. S11-18 audit findings map 1:1 into three stories so each fix is scoped.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S12-01 | iPad layout adaptivity pass | 5 | ⏳ Planned | Plumb `horizontalSizeClass` through `EnhancedHomeView`, `LearningPathCard`, `MasonryGrid`, `TrophyRoomView`. Replace hardcoded `.frame(width: 140/160/180)` on lesson tiles + path cards with adaptive widths (compact: current values; regular: 1.4× or `GeometryReader`-driven). `MasonryGrid` columns 2 → 3 on regular. `TrophyRoomView.columns` 3 → 5 on regular. `OnboardingView` + `KidsLoginView` + `FlipbookView` nav HStack + `DashyHintSheet` get `.frame(maxWidth: 600).frame(maxWidth: .infinity)` double-frame pattern so content centers on iPad without cutting the ink-outline edge on compact. **Bonus bug fix:** `LearningPathCard.swift:69` progress bar math — replace hardcoded `CGFloat(progress) * 160` with `GeometryReader`-driven inner-width calc. S11-18 audit found this overflows the card interior by 12pt at `progress=1.0`. |
| S12-02 | Dynamic Type pass | 2 | ⏳ Planned | One-line fix in `NovaPalette.displayFont(size:)` — add `relativeTo: Font.TextStyle = .title` parameter and pass through to `.custom(_:size:relativeTo:)`. This single change unblocks **every** Bangers-font title across the entire app picking up user-level Dynamic Type scaling. Then sweep 5 `.lineLimit(1)`-without-`.minimumScaleFactor()` sites (FlipbookHeader:64 + 4 others identified in audit) — add `.minimumScaleFactor(0.7)` so titles shrink-to-fit at `.accessibility5` instead of truncating. Walk-through validation at `.xSmall` and `.accessibility5` on iPad Pro. |
| S12-03 | Dark-mode contrast pass | 1 | ⏳ Planned | `.white` foreground on `pathColor` (LearningPathCard lines 39/57/68/74) and on `Category.blue` / `Category.purple` gradients (EnhancedHomeView lines 144/150/154/161) — verify WCAG AA (4.5:1) in dark mode. If fails, swap to `NovaPalette.ink` or a semantically-adaptive `Color(light: .white, dark: .ink)` per site. **Guard rail:** `NovaPalette` adaptive implementation was verified in S11-18 (`Color(light:dark:)` uses `UIColor(dynamicProvider:)`) so the fix is *additive* — no systemic palette changes needed. |

### CE Epic — Content Engine Expansion (18 pts)

Carried from S10. S10-12 closed with the skill-engine generating `story` + `quiz` atoms through the decomposition-aware path; `experiment`, `voice`, and `curriculum` still run on the legacy generator. This epic completes the 5-modality matrix so **every card type on the flipbook** comes through the skill-engine and the atomic `ok/retry-ok/retry-failed/skipped` Pipeline-tab telemetry. Shape mirrors S10-R4 (story-writer) and S10-07 (quiz-maker) exactly — lifted patterns, not new architecture.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S12-04 | `experiment-designer` skill — def bundle + engine wiring | 6 | ⏳ Planned | Mirror S10-R4's story-writer + S10-07's quiz-maker shape: `manifest.yaml` + `prompt.md` + `age-profiles/` + `topics/` + per-skill Zod validator. Wires into `skillRouter` for `card.type === 'experiment'` atoms. **Key design question to lock in the spike:** does `experiment-designer` need its own age-gated materials list (scissors OK at 8+ / not at 5) or can `age-profiles/` carry that? Spike day 1. |
| S12-05 | `curriculum-architect` skill — def bundle + engine wiring | 6 | ⏳ Planned | Same shape as S12-04. Runs at **Stage 3** (decomposition) rather than Stage 4 (atom generation) — it's the skill that answers "what *ought* to be in this lesson" before the per-card skills run. Feeds the card-type sequence that `cardGenerator` then routes through `storyWriter` / `quizMaker` / `experimentDesigner`. **Validation:** regression-test S10-12's Pipeline tab — `skillEngineUsed: true` + per-atom pills still render, just with one more stage preceding. |
| S12-06 | `voice-persona` skill — def bundle + engine wiring | 6 | ⏳ Planned | Same shape. Covers `card.type === 'voice'` atoms (the Dashy voice-mode cards where the kid reads aloud). **Carve-out:** this skill's prompt is where the Dashy voice character lives — first-person mascot voice, kid-calibrated reading-level gate, gentle correction patterns (matches the Dashy chat voice from S11-13). Cross-reference: any time the Dashy voice character drifts in S13+, this prompt is the single-sourced-truth. |

### RN Epic — Sparky → Dashy Coordinated Rename (5 pts)

Closes the asymmetric-rename carve-out S11-09 + S11-19 both documented. S11-09 renamed user-visible strings (iOS). S11-19 preserved `role == "sparky"` wire literal + `/sparky/chat` endpoint path because changing those is a **coordinated migration** (backend file rename + wire-protocol change + iOS VM update + DB column rename all in one commit range, not three independent passes). This is that pass.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S12-07 | Filepath rename — `services/sparky/` → `services/dashy/` with import sweep | 3 | ⏳ Planned | `git mv src/Backend/src/services/sparky/ src/Backend/src/services/dashy/` then sweep every `from './sparky/...'` / `from '../sparky/...'` import across the backend. TypeScript compile-check catches misses. Route handler path `/sparky/chat` → `/dashy/chat` coordinated with S12-08 below. No wire-compat shim — bang owns both client and server, and the only live client is his own iPad, so a coordinated deploy is cheaper than maintaining a dual-path shim we'd delete in S13 anyway. |
| S12-08 | Wire-literal rename — `role: "sparky"` → `role: "dashy"` + iOS VM update | 2 | ⏳ Planned | Rename the `role` discriminant in `ChatMessage` types across Backend (Zod schema + TypeScript types) + iOS VM (Swift struct) + DB migration (if any message rows persist the role — likely not, DM flow is ephemeral). Coordinate with S12-07's endpoint rename so both flip in the same commit range. **Regression test:** S11-13's DashyView chat flow — send a message, confirm the paper-and-ink Dashy bubble still renders (was keying on `role == "sparky"` for the bubble-type discriminant). |

### MVP Epic — Touch Test Loop (14 pts)

The actual point of the sprint. These stories land the content-authoring workflow bang needs to create real lessons on his Mac and see them appear on the iPad. Sequenced **after CE epic** because the skill-engine needs to be complete before content authoring is worth stress-testing — you can't author an experiment card if `experiment-designer` doesn't exist yet.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S12-09 | Dev Console — content authoring surface | 5 | ⏳ Planned | New Dev Console tab: `Author Lesson`. Form inputs: title / description / topic / age-profile / difficulty / card-type sequence (hint: leave empty to let `curriculum-architect` decide). Submit button calls `POST /lessons/author` (new route) which kicks off the full skill-engine pipeline and streams progress per-atom via server-sent events so the tab shows the same `ok/retry-ok/…` pills as the existing Pipeline tab. On success, the created lesson + cards persist to the dev DB and the iPad's `GET /lessons` (wired S11-19) picks them up on pull-to-refresh. **Why a Dev Console tab and not a standalone admin UI:** bang is the sole author, the Dev Console is already the gravity well for every operational surface we've built, adding a 7th tab is zero UX debt. |
| S12-10 | Seed — 3 real lessons through the full pipeline | 3 | ⏳ Planned | Using S12-09, author three lessons end-to-end: one story-heavy (e.g. "Why the sky is blue"), one experiment-heavy (e.g. "Make a rainbow with a prism"), one quiz-heavy (e.g. "Name the planets"). One per modality mix so we stress-test the full 5-card-type matrix in the wild. Captured artifacts: lesson JSON + Pipeline-tab screenshots committed into `docs/sprint-runs/S12-10-seed-lessons/`. Success criteria: each lesson generates zero `retry-failed` or `skipped` atoms on first pass. If any do, that's a skill-def bug we fix in-line before calling this story done. |
| S12-11 | Touch test — bang's kid runs the demo loop | 2 | ⏳ Planned | **Live testing story**, not a code story. Bang sits next to his kid, opens the app, kid picks an avatar + path, runs one of the three seeded lessons, unlocks a trophy. Bang takes notes. Every defect captured goes into `docs/sprint-runs/S12-11-touch-test.md` as a numbered issue with severity (High: blocks completion; Medium: degrades joy; Low: cosmetic). High-severity defects resolve inline; Medium/Low either resolve in S12-12 below or carry to S13. **No silent pass** — this story is only ✅ Done when the write-up exists and has at least one qualitative "what the kid said / did" observation per card type that ran. |
| S12-12 | Touch-test defect recovery + empty-state sweep | 4 | ⏳ Planned | Budget for fixing whatever S12-11 uncovers. If the touch test is clean (optimistic scenario), this story absorbs into an empty-state sweep: the iPad currently assumes every path has lessons + every lesson has cards + every child has avatars. Every surface that could hit an empty list needs a tested empty state — `NovaCard`-styled page with page-fill + ink-stroke + a helpful "What's this?" copy line + a `.novaSecondary()` "Create one" CTA that opens the Dev Console authoring link for bang specifically (hidden behind the parental gate for kids). Matches the S11-19 error-banner language. |

### POL Epic — Pre-demo Polish (8 pts)

Only the polish that materially affects the touch-test loop. Everything else (app icon, splash, TestFlight, submission) stays deferred to S13 per the S11 tracker's forward plan.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S12-13 | Parental gate on first launch + settings surface | 4 | ⏳ Planned | First-launch flow needs a parental gate (S11's onboarding doesn't have one — `KidsLoginView` is kid-accessible directly). Shape: on fresh-install or "switch user", present a quick math gate ("what's 7 × 8?") before the Parent tab / settings are accessible. Settings tab exposes: child profile edit, session time limit (default 20 min, override per-kid), favorite-palette toggle (light / dark / system default — currently system-only). Reuses the existing `ParentalGateView` from pre-S11. Wire into `NovaKidsApp` startup sequence and the settings-icon tap in Home. |
| S12-14 | Avatar picker + child profile polish | 2 | ⏳ Planned | Avatar picker (S11-17 preserved the per-avatar Category colors as semantic identity) gets a quick polish pass: larger avatars on iPad regular size class, better selected-state (currently just a ring — add a coral fill transition on tap matching `.novaPrimary()` press behavior). Child profile display-name editable inline in settings (S12-13). Small thing — but the kid picks an avatar once and sees it on every Home visit, so it's worth one afternoon. |
| S12-15 | Sprint close — tracker finalize + demo recording | 2 | ⏳ Planned | End-of-sprint: flip every story to final status, sum Sprint Summary, record a 60-second screen capture of the touch-test loop (iPad mirrored to Mac, Mac QuickTime screen recording). Archive into `docs/sprint-runs/S12-15-close/`. Used as the "does this actually work?" artifact bang shows anyone who asks without having to do a live demo. Also: write the S13 tracker stub so TestFlight prep has a home. |

### QA Epic — Sprint close + cross-cutting testing (7 pts)

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S12-16 | Pipeline tab regression sweep after CE epic lands | 3 | ⏳ Planned | S10-12-R7 landed the Pipeline tab. S12-04/05/06 add three new skills to it. Verify `skillEngineUsed: true` still fires + the new per-skill pills (experiment / curriculum / voice) render correctly + no atom silently falls back to legacy generation when it shouldn't. One-hour regression pass on three test lessons covering all five card types — run, screenshot, commit into `docs/sprint-runs/S12-16-pipeline-regression/`. |
| S12-17 | Dashy voice consistency audit — cross-skill | 2 | ⏳ Planned | After S12-06 lands, Dashy's first-person voice prompt lives in `voice-persona/prompt.md`. But Dashy's *character* also shows up in `DashyView` chat (S11-13), onboarding (`meetDashyPage`, S11-17), and the hint bubble (`DashyHintSheet`). Audit whether these four voice surfaces agree on tone + lexicon + correction patterns. If not, either hoist the character definition into a shared reference or explicitly document divergence per surface. **Not a rewrite**, just an audit + one-page write-up. |
| S12-18 | iPad QA re-walk (light + dark + Dynamic Type extremes) | 2 | ⏳ Planned | S11-18 was a code-review audit because sandbox can't boot an iPad simulator. S12-18 is the **sim walkthrough** bang runs on his Mac: `xcodebuild -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch)'` — both orientations, light + dark mode, Dynamic Type `.xSmall` and `.accessibility5`. Screenshots into `docs/sprint-runs/S12-18-qa-screenshots/`. **Goal:** confirm S12-01/02/03 fixed what the S11-18 audit found — no new defects, or if new defects surface, file them into S13's tracker directly (not the same rediscovery-loop trap S11 dodged). |

---

## Definition of Done

- [ ] **Touch test completed:** bang has run the end-to-end demo loop with his kid. Three lessons seeded, at least one fully completed with trophy unlock, one qualitative observation per card type captured in the S12-11 write-up.
- [ ] **Content authoring works from the Dev Console:** bang can author a new lesson in the Dev Console, see per-atom pipeline pills, confirm the iPad picks up the new content on pull-to-refresh. Zero `retry-failed` / `skipped` atoms on the three seed lessons.
- [ ] **Skill-engine 5-modality complete:** `story-writer` + `quiz-maker` (from S10) + `experiment-designer` + `curriculum-architect` + `voice-persona` (this sprint). Every card type routes through the skill-engine; legacy fallback is dead code.
- [ ] **Sparky is a dead word:** `grep -ri "sparky" --include="*.{swift,ts,js,md}"` returns zero hits outside of `docs/sprint-runs/` (where historical tracker notes stay intact).
- [ ] **iPad layout adaptive:** every Tier 1 surface walks cleanly in iPad Pro 12.9-inch simulator, both orientations. No fixed-width overflow, no gutter bleed, no truncated titles at `.accessibility5`.
- [ ] **Parental gate enforced on first launch.** Settings accessible only past the gate.
- [ ] **Dev Console regression clean:** Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs all still functional after the skill-engine expansion.

---

## Sprint Summary

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| CAR | 0 | 8 | 0% |
| CE  | 0 | 18 | 0% |
| RN  | 0 | 5 | 0% |
| MVP | 0 | 14 | 0% |
| POL | 0 | 8 | 0% |
| QA  | 0 | 7 | 0% |
| **Sprint 12 Total** | **0** | **60** | **0%** |

---

## Execution Plan (solo, 6 focused hrs/day)

**Week 1 — Loop closure (Day 1–4, ~32 hrs, 38 pts):**
- Day 1: S12-01 (iPad layout, 5) + S12-02 (Dynamic Type, 2) + S12-03 (dark-mode, 1) — S11-18 carry-in retired, foundation for everything else. 8 pts.
- Day 2: S12-04 (experiment-designer, 6) + kick off S12-05 spike. 6–9 pts depending on spike close.
- Day 3: S12-05 (curriculum-architect, 6) + S12-06 (voice-persona, 6). CE epic closes. 12 pts.
- Day 4: S12-07 (filepath rename, 3) + S12-08 (wire-literal rename, 2) + S12-09 (Dev Console authoring, 5 — start). 5–10 pts. RN epic closes Day 4.

**Week 1 checkpoint — end of Day 4:** CE epic 100% + RN epic 100% + Dev Console authoring tab prototyped. If CE isn't clean here, **Week 2 absorbs slip** and touch-test pushes to Day 9.

**Week 2 — Touch test + polish (Day 5–10, ~22 pts):**
- Day 5: S12-09 (Dev Console authoring, finish) + S12-10 (seed 3 lessons, 3). 5–8 pts.
- Day 6: S12-11 (touch test with kid, 2) + S12-12 (defect recovery / empty states, 4 — start). 2–6 pts.
- Day 7: S12-12 (finish) + S12-13 (parental gate + settings, 4). 4–8 pts.
- Day 8: S12-14 (avatar polish, 2) + S12-16 (Pipeline regression, 3). 5 pts.
- Day 9: S12-17 (Dashy voice audit, 2) + S12-18 (iPad sim walkthrough, 2). 4 pts.
- Day 10: S12-15 (sprint close + demo recording, 2) + buffer. 2+ pts.

**Contingency:** Week 2 is the slip absorber. If CE overruns in Week 1 (most likely risk — three new skills in 2 days is tight), MVP epic slides into Day 6–7 and POL compresses. Under no circumstance does S12-11 (touch test) get cut — if something must give, POL + QA carry to S13.

---

## Dev Console — what to test during the sprint

Per the running pattern: the Dev Console is the instrumentation that lets bang debug what shipped without flipping into Xcode.

- **Pipeline tab** — regression-critical. Must show `skillEngineUsed: true` + per-atom pills for all five card types after S12-04/05/06 land. S12-16 is the explicit regression sweep.
- **Skills tab** — must dry-run-render all five skill defs (two existing + three new) with `age-profiles` + `topics` resolving correctly.
- **Strategy tab** (S10-11) + **Parent Guidance tab** (S10-04) + **Session Context tab** (S10-05) — unchanged; sanity-check during S12-18.
- **NEW — Author Lesson tab** (S12-09) — primary new surface this sprint. SSE stream + pipeline pills + created-lesson preview + jump-to-iPad affordance ("refresh iPad now").

---

## Out of Scope (explicit — prevents scope creep)

- **TestFlight / submission / App Store artifacts** → **Sprint 13** (explicitly this sprint's successor, not a hypothetical).
- **App icon + splash screen + Info.plist marketing strings** → **Sprint 13**.
- **Custom Dashy illustration asset pack** (S11-10 shipped the comic silhouette; new artwork is S13–S15 if needed).
- **Parent dashboard surface** (progress tracking, time-on-device, content filters) → **Sprint 15+**.
- **Paid infra — Railway / Supabase / R2 / any cloud migration** → **Sprint 13–14**.
- **Content at scale** (more than 3 seed lessons) → **Sprint 13+** once the authoring loop is proven.
- **Lesson editing / versioning** (S12-09 is create-only; edit is S13+).
- **Multi-kid support UX** (profiles exist, but the UX for a household of two siblings is S14+).

---

## Risks & Mitigations

- **Risk:** CE epic (18 pts in 3 days) overruns. Three new skill defs in a week is cadence-aggressive even with S10-R4 + S10-07 as templates. **Mitigation:** Week 2 is the slip absorber; POL epic is compressible; the only non-negotiable is S12-11 touch test. If CE looks rocky by Day 2 noon, cut S12-06 (`voice-persona`) to S13 and let the existing VoiceCard legacy path ride one more sprint.
- **Risk:** Touch test exposes a demo-breaking bug that's expensive to fix (e.g., a race condition in the skill-engine streaming path only visible under live load). **Mitigation:** S12-12's 4-pt budget is intentionally generous. If blown, it's fine to close S12-12 with carry-to-S13 documented in the run summary — the learning is the artifact, not the patch.
- **Risk:** Kid bounces off the app within 30 seconds. **Mitigation:** this is a *product* risk, not a sprint risk. Document what happened. A kid bouncing in 30 seconds on a three-card lesson is *information*, not failure. The sprint closes clean either way.
- **Risk:** Rename (RN epic) breaks a surface we didn't account for (e.g., a log parser that keys on `role: "sparky"` in analytics). **Mitigation:** grep before merging; rely on TypeScript compile-check to catch import-level misses; run a local dev-DB restore after the rename commit to confirm persistence layer is intact.
- **Risk:** iPad layout fixes regress compact (iPhone) layouts. **Mitigation:** S12-01's double-frame pattern (`.frame(maxWidth: 600).frame(maxWidth: .infinity)`) is explicitly no-op on compact. `horizontalSizeClass` branches default to current values on compact. S12-18 walks both form factors.

---

## Sprint 13+ preview (what this sprint is NOT doing, for context)

- **S13 — "Submit":** TestFlight + app icon + splash + Info.plist marketing. Railway or equivalent paid infra. Supabase Auth + Postgres migration. R2 or equivalent for asset storage. App Store submission artifacts (privacy policy, screenshots, keywords). Preflight with App Review guidelines.
- **S14 — "Scale":** Content-authoring UX polish beyond the Dev Console. Multi-kid households. Parent dashboard spike. Lesson versioning.
- **S15+ — "Discover":** Pinterest-style discovery layer matures (library, search, curated collections). Content-engine outputs evolve toward comic-native. Parent-facing analytics.

---

*Tracker scaffolded April 22, 2026. Carry-ins: S11-18 audit (QA epic) + S11-09/S11-19 rename debt (RN epic) + S10-08/09/10 content-engine expansion (CE epic). Stories fill in Delivery Notes sections below as they complete, following the SPRINT-10/11 idiom: Files changed / Architectural decisions / Validation / Prerequisites bang must run on his Mac.*

---

## Delivery Notes

*(Empty at sprint start — populated as each story ships.)*
