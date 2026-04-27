# Sprint 14 — "Playable" — Progress Tracker

**Sprint dates:** Apr 26 – May 10, 2026
**Goal:** Kid-test review #1 surfaced two foundational gaps — (a) the navigation chrome doesn't speak (a 4.5-year-old can't read his way into a lesson), and (b) the visual surface reads "classroom" not "playground." S14 closes both: every Tier 1 screen narrates itself in the kid's chosen voice, Dashy is on screen everywhere as a persistent guide, every tap target reacts with the 3-stack (bounce + sound + haptic + particle), path/lesson tiles become full-bleed illustrated entries, and the flat backgrounds become parallax illustrated layers. Sprint close: bang's kid picks the iPad up, the app talks to him, and he can navigate end-to-end without an adult reading anything aloud. **S14 explicitly slips TestFlight to S15** — a beta of a clunky app produces no useful signal; the calendar moves but the launch quality goes up.
**Velocity target:** 55 pts (heavy iOS UX + modest backend; carry-in slips from S13 absorbed Week 1).
**Carry-in from S13:** VOX touch-test follow-ups (4 items, 8 pts) — backend `PUBLIC_BASE_URL`, `devBypassLogin()` real JWT, empty-body POST validation exemption, Oracle publish toggle.
**Carry-in from S12:** S12-10 Run 2/3 Rainbow + Planet re-seed (2 pts) — still pending bang's Mac. May naturally retire as S14 hero-tile work touches the same lesson rows.
**Demo path:** unchanged — Xcode-built Debug iPad on same wifi as Mac backend. Same LAN env-var setup S13 used. No TestFlight, no submission.

---

## Why this sprint exists (the framing)

User-test review #1 (Apr 25) — bang's kid, 4.5 years old, picked up the S13 build. Two qualitative observations dominate the run:

1. **The kid couldn't enter a lesson without adult guidance.** He saw the home screen with text labels ("Lessons," "Trophies," path titles), couldn't read them, and disengaged. Audio narration exists *inside* lessons (the S13 voice upgrade) but the navigation chrome is silent. Half the app speaks, half is silent. **For ages 4–10 audio is the primary UX channel** — the navigation has to talk first.

2. **The visual surface didn't capture sustained attention.** Reference is ABCMouse / Khan Academy Kids / Endless Reader / Duolingo ABC. Pattern across all four: every screen has a mascot doing something on it, every tappable element wiggles or pulses, every interaction has 3+ overlapping reactions (sound + animation + haptic + particle). Static card grids read as books to a kid; books are not toys. Novai currently feels like a small-Mac app, not a small playground. The cognitive contract is wrong.

S14 inverts both. **Voice-first navigation** addresses (1): every Tier 1 surface auto-narrates a kid-friendly script through the existing OpenAI TTS proxy in the kid's chosen voice persona, with cooldown / mute toggle / tap-to-skip. **Mascot presence + tap reaction stack + hero tiles + background layering** addresses (2): replaces utility-grid chrome with lived-in, animated, illustrated surfaces.

S14 explicitly does **not** rebuild Home/Lessons/Trophy as immersive 3D playscapes — that's a separate creative bet logged for S16+ if S14's increment doesn't move the engagement needle enough. The S14 hypothesis is: **voice-first + presence + tactility are sufficient to lift kid retention, separately from a deeper visual overhaul.** If true, art-redesign is a bonus optimization. If false, art-redesign becomes mandatory and S16+ commits.

TestFlight slip is intentional. A TestFlight beta of an app a kid disengages from in 30 seconds produces no useful signal. Ship Playable, then ship Submit.

---

## Epic breakdown

### VF — Voice-First Navigation (12 pts) ⭐ foundation

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S14-VF-01 | NavigationNarrator service | 4 | bang | 🚧 | @MainActor ObservableObject. Per-screen script registry. `.narrate(_:)` view modifier hooks into onAppear. Per-screen cooldown (60s default) so back-nav doesn't re-narrate. Tap-anywhere-to-skip. Routes through existing VoiceManager (S13 OpenAI TTS proxy). |
| S14-VF-02 | Wire .narrate(_:) on Tier 1 surfaces | 4 | bang | ⬜ | Home / Lessons (per path) / Lesson detail entry / Trophy room / Voice picker / parental gate. Dynamic scripts where needed (read path name; greet by kid's name when known). |
| S14-VF-03 | Parental mute toggle + Settings surface | 2 | bang | ⬜ | UserDefaults-backed. Adult-mediated gate (existing parental settings sheet — or first-launch Settings hook if not present). Default: narration on. |
| S14-VF-04 | Skip-narration gesture + visual cue | 2 | bang | ⬜ | Tap anywhere on screen during narration → stop playback gracefully. Subtle "tap to skip" pill bottom-right while audio is active. |

### MP — Mascot Presence (10 pts)

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S14-MP-01 | DashyMascotView block | 4 | bang | ⬜ | Reusable view. Reuses S11-10 Dashy comic silhouette. Idle breathing animation (scale 1.0↔1.04 / 2s) + occasional blink. Reduce-motion → static. Speech-bubble companion when narration is active. |
| S14-MP-02 | Plumb DashyMascotView into Home | 2 | bang | ⬜ | Top-of-Home block. Speaks the home-narration line. Tappable → re-narrates. |
| S14-MP-03 | Plumb into Lessons + Trophy | 2 | bang | ⬜ | Same pattern. Lessons screen Dashy says "Pick a lesson!"; Trophy screen Dashy says "Look at all your trophies!". |
| S14-MP-04 | DashyMascotView on empty states | 2 | bang | ⬜ | Replace text-only empty states ("No lessons yet") with mascot + speech-bubble + voiced line ("Looks like there's nothing here yet. Ask a grown-up to add a lesson!"). |

### TR — Tap Reaction Stack (8 pts)

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S14-TR-01 | KidTap ViewModifier | 3 | bang | ⬜ | `.kidTap { action }` — scale-bounce (0.92→1.06→1.0 / spring) + NovaHaptics `.tap` + subtle particle burst (3-5 small dots, fade out 0.4s, gentle). Reduce-motion path → instant + haptic only. |
| S14-TR-02 | Sweep all primary tap targets | 3 | bang | ⬜ | Home tiles, Lessons tiles, Trophy cards, Voice picker cards, Continue button, settings entries. Replace `.onTapGesture { ... }` with `.kidTap { ... }`. |
| S14-TR-03 | Particle effect implementation | 2 | bang | ⬜ | Lightweight SwiftUI Canvas overlay; one-shot animation per tap; 5–8 colored dots scatter outward. Falls back to simple opacity flash under reduce-motion. |

### HT — Hero Tile Upgrade (8 pts)

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S14-HT-01 | Generate per-path hero art | 3 | bang | ⬜ | Run DALL-E pipeline once per path via Oracle's Author tab (or new dedicated affordance) using path title as prompt. Save result on `LearningPath.imageUrl` (new column — backend migration needed). |
| S14-HT-02 | Path tile redesign | 3 | bang | ⬜ | Full-bleed `path.imageUrl` background + bigger tile size + visible pulsing glow ring as "tap me" cue. Title overlay at bottom with semi-opaque shadow. |
| S14-HT-03 | Lesson tile uses card[0].imageURL | 2 | bang | ⬜ | Lesson tiles render the first card's hero image as full-bleed background instead of flat color. Existing `localhost`-rewrite path on iOS makes this just work for assets already generated. |

### BL — Background Layering (5 pts)

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S14-BL-01 | LayeredBackground view | 2 | bang | ⬜ | Reusable. Sky gradient + cloud illustration (single asset) + paper texture overlay. Subtle vertical parallax on scroll (Cloud moves 0.3× scroll). Reduce-motion → fixed. |
| S14-BL-02 | Apply to Home / Lessons / Trophy | 1 | bang | ⬜ | Replace `NovaPalette.novaBackground` solid color. |
| S14-BL-03 | Asset generation (cloud / paper texture) | 2 | bang | ⬜ | Generate via DALL-E or hand-author 2 assets (cloud SVG + paper-texture PNG). Bundle in NovaKids resources. |

### VOX-FU — VOX touch-test follow-ups (carry-in from S13, 8 pts)

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S14-VOX-01 | Backend `PUBLIC_BASE_URL` env var | 2 | bang | ⬜ | `assetUploader.ts:98` reads `config.PUBLIC_BASE_URL` (default `http://localhost:${PORT}`). bang sets to `http://192.168.7.50:3000` for LAN demos. Eliminates the need for the iOS-side `localhost` rewrite — but the rewrite stays as defensive fallback. |
| S14-VOX-02 | `devBypassLogin()` mints a real JWT | 3 | bang | ⬜ | iOS `AuthManager.devBypassLogin()` actually hits `POST /api/v1/auth/dev-bypass`, gets a JWT, stores via `updateTokens(...)`. Eliminates the entire "stale keychain bites you" failure mode that cost 30 minutes of demo prep. |
| S14-VOX-03 | Empty-body POST validation exemption | 1 | bang | ⬜ | Add `{ Body: void }` typing or `validateBody(z.object({}).optional())` on `/lessons/:id/publish` and any similar no-body POST routes so `curl -d '{}'` workaround is no longer needed. |
| S14-VOX-04 | Oracle Content Browser publish toggle | 2 | bang | ⬜ | Each lesson row gets a publish/unpublish action. Bulk-publish-path action at the path level. Closes the gap between authoring lessons and them showing as "real content" on iOS. |

### POL — Polish + integration (4 pts)

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S14-POL-01 | Kid-retest #2 + write-up | 2 | bang | ⬜ | After VF + MP land. 30-min session. Capture qualitative observations under `docs/sprint-runs/S14-kid-retest-2.md`. Decision gate: continue with TR/HT/BL, or rescope. |
| S14-POL-02 | Sprint-close demo recording | 2 | bang | ⬜ | 90-second QuickTime walkthrough showing voice-first navigation + mascot presence + tap reactions + new tile + background. For TestFlight assets in S15. |

---

## Definition of Done

- [ ] **Voice-first navigation works end-to-end:** kid opens app, every Tier 1 screen narrates a kid-friendly line in his chosen voice within 1 second of appearance. No text-only chrome on the path from Home → Lesson → first card.
- [ ] **Mascot presence persistent across Tier 1 surfaces:** Dashy visible on Home, Lessons, Trophy, empty states. Idle animation respects reduce-motion. Speech bubble shows during narration.
- [ ] **Every primary tap target uses KidTap:** zero `.onTapGesture` left on tile-style or card-style tap targets in Tier 1 views. Sweep verified by `grep -r ".onTapGesture" Apps/NovaKids/Sources/Views/{Home,Lessons,Trophies}/` returning ≤ 3 hits (acceptable: utility taps inside detail screens that aren't primary entries).
- [ ] **Path tiles + lesson tiles full-bleed illustrated:** every path has `imageUrl` populated; every lesson tile renders the first card's hero image. No flat-colored tiles in the lesson grid.
- [ ] **Layered background visible on Home / Lessons / Trophy:** sky + clouds + paper texture replaces solid color. Parallax functions on scroll. Reduce-motion users see static.
- [ ] **VOX-FU debt retired:** all 4 carry-in items shipped + verified. Backend ships `PUBLIC_BASE_URL` env var; iOS dev-bypass actually mints a JWT; empty-body POST works without `-d '{}'` workaround; Oracle has working publish toggle.
- [ ] **Kid-retest #2 + #3 documented:** 30-min mid-sprint retest after VF+MP; 30-min sprint-close retest after full sprint. Each captures qualitative observations + a decision-gate note (proceed / rescope).
- [ ] **Oracle regression clean:** all S12/S13 tabs (Pipeline / Skills / Strategy / Parent Guidance / Session Context / Author / Content Browser / Voice) still functional after backend `PUBLIC_BASE_URL` + publish-toggle land.
- [ ] **Mute toggle works:** parental Settings has a "Voice prompts" toggle. Off → no auto-narration on screen entry. On → default behavior. Persists across launches.

---

## Sprint Summary

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| VF | 0 | 12 | 0% |
| MP | 0 | 10 | 0% |
| TR | 0 | 8 | 0% |
| HT | 0 | 8 | 0% |
| BL | 0 | 5 | 0% |
| VOX-FU | 0 | 8 | 0% |
| POL | 0 | 4 | 0% |
| **Sprint 14 Total** | **0** | **55** | **0%** |

---

## Execution Plan (solo, 6 focused hrs/day)

The sprint is **explicitly sequenced for kid-retest cadence** so the marginal value of each epic gets validated separately. We don't build everything then test; we build, retest, decide, build, retest, decide.

**Week 1 — Foundation + first retest (Day 1–4, ~22 pts):**
- Day 1: S14-VF-01 (NavigationNarrator service, 4) + S14-VF-04 (skip gesture, 2). Voice-first plumbing. 6 pts.
- Day 2: S14-VF-02 (wire 6 surfaces, 4) + S14-VF-03 (mute toggle, 2). VF epic closes. 6 pts.
- Day 3: S14-MP-01 (DashyMascotView, 4) + S14-MP-02 (Home plumbing, 2). 6 pts.
- Day 4: S14-MP-03 (Lessons + Trophy, 2) + S14-MP-04 (empty states, 2). MP epic closes. 4 pts.

**Week 1 checkpoint — end of Day 4: kid-retest #2 (S14-POL-01).** 30-min session. The hypothesis test is whether voice-first + mascot is enough to make the kid navigate without adult help. If yes, TR/HT/BL become "polish that makes it shine." If no, we know visual+tactile are doing more work than expected and Week 2 reprioritizes.

**Week 2 — Visual + tactile (Day 5–8, ~21 pts):**
- Day 5: S14-TR-01 (KidTap modifier, 3) + S14-TR-03 (particle, 2). 5 pts.
- Day 6: S14-TR-02 (sweep all targets, 3) + S14-VOX-01 (PUBLIC_BASE_URL, 2). 5 pts. TR epic closes. VOX-FU starts.
- Day 7: S14-HT-01 (per-path art, 3) + S14-HT-02 (path tile redesign, 3). 6 pts.
- Day 8: S14-HT-03 (lesson tiles, 2) + S14-BL-01/02 (LayeredBackground + apply, 3). 5 pts. HT + BL epic closes.

**Week 2 checkpoint — end of Day 8: kid-retest #3 (final).** Full sprint surface area. 30-min session. Captures sprint-close engagement signal vs. retest #2 baseline. If the marginal lift from retest #2 → #3 is small, Option B (deeper playscape redesign) becomes a stronger candidate for S16+ and we ship S15 (TestFlight) on schedule. If the lift is large, the engagement hypothesis is validated and S16+ scope can be more conservative.

**Day 9–10 — VOX-FU debt + close (~7 pts):**
- Day 9: S14-VOX-02 (devBypass JWT, 3) + S14-VOX-03 (empty-body, 1) + S14-VOX-04 (Oracle publish, 2). VOX-FU epic closes. 6 pts.
- Day 10: S14-BL-03 (asset gen, 2) + S14-POL-02 (demo recording, 2) + buffer. 4 pts.

**Contingency:** Week 2 absorbs Week 1 slip. Under no circumstance does VF cut — without it the rest of the sprint is performance art on top of a non-navigable app. If Week 1 slips, MP carries to Day 5, retest #2 slides to Day 5, and TR/HT/BL compress. The kid-retests are non-negotiable — they're the validating signal that says whether the next epic is even necessary.

---

## Dev Console / Oracle — what to test during the sprint

- **Voice tab** (S13-10) — primary regression target. Confirm OpenAI TTS still serves narration lines on every Tier 1 screen as expected. Use the Oracle Voice tab to A/B narration scripts before they ship.
- **Pipeline tab** — regression target after S14-HT-01 (per-path DALL-E art generation) and S14-VOX-01 (`PUBLIC_BASE_URL`).
- **Content Browser** — gets a publish/unpublish toggle (S14-VOX-04). Sanity-check existing 11 lessons toggle correctly between draft/published.
- **NEW — narration script preview** — optional Voice-tab affordance to dry-run a narration script before it lands on iOS. Lets bang iterate scripts on Mac without rebuilding the app.

---

## Out of Scope (explicit — prevents scope creep)

- **TestFlight submission** → **Sprint 15** ("Submit"). Sprint 14's hypothesis test must complete first.
- **Deeper visual playscape redesign** (3D shelves, illustrated portals, character-led navigation) → **Sprint 16+** if S14 retest signal warrants it.
- **Custom Dashy artwork** beyond the existing S11-10 silhouette → **Sprint 17+**. S14 reuses what's there.
- **Voice cloning / custom narration personas** → never. Stays on the OpenAI 4 voices from S13.
- **Multi-kid sibling UX** → S17+. Single kid demo path stays the focus.
- **Real-world ABCMouse-class playscape rebuild** → not a single sprint. Multi-sprint creative direction work that requires an art lead. Logged for a future "S20+ creative direction" workstream.
- **Cloud asset storage migration** → S15+ alongside TestFlight infra prep. Sandbox local-FS continues.

---

## Risks & Mitigations

- **Risk:** Voice-first narration becomes annoying. Cooldown is too short, kid hears "Pick a lesson" 5x in 30 seconds. **Mitigation:** 60s default cooldown, parental mute toggle, tap-to-skip. If kid-retest #2 shows annoyance, halve the script length (e.g., "Pick a lesson!" not "Pick a lesson to start learning today!") and bump cooldown to 120s.
- **Risk:** Mascot presence becomes noise. Dashy on every screen idle-breathing competes with content. **Mitigation:** keep block small (top of screen, ≤ 25% vertical real estate). Only animate idle when no narration is active. If retest shows distraction, demote to home + empty states only.
- **Risk:** Tap reaction stack becomes overwhelming. Particle on every tap = visual chaos. **Mitigation:** keep particles to 3-5 dots, fade in 0.4s, fade out 0.6s. Sound is existing NovaHaptics `.tap` (not new). Reduce-motion path strips particle entirely. If sprint review flags it as too much, reduce to bounce + haptic only.
- **Risk:** Per-path DALL-E art (S14-HT-01) drifts in tone — looks AI-generated rather than illustrated. **Mitigation:** prompt template tested against the 4 existing paths first; if tone is wrong, fall back to category-color full-bleed gradient + emoji icon (still better than current flat-color tile). Goal isn't perfect art, it's "less classroom."
- **Risk:** PUBLIC_BASE_URL backend fix introduces a regression in Oracle's asset URLs (Mac browser vs LAN iPad). **Mitigation:** Oracle is on the same Mac as the backend so localhost URLs would still work for it; the env var only changes where freshly-uploaded assets get their URL prefix. Existing rows stay localhost. Mac browser still resolves localhost. Worst case, both work via the iOS rewrite + new env var.
- **Risk:** Kid-retest #2 reveals retention is still low after VF + MP. **Mitigation:** that's information, not failure. The sprint reprioritizes — TR/HT/BL get heavier weight, or S16+ playscape redesign moves up. The retest IS the experiment; the data is the deliverable regardless of which way it points.
- **Risk:** Sprint slips past 2 weeks. **Mitigation:** S14-VOX-FU is the cuttable epic. The 4 follow-up items don't gate the kid demo; they gate clean engineering for S15+. If timing is tight, VOX-FU carries to S15 alongside TestFlight prep.

---

## Sprint 15+ preview

- **S15 — "Submit":** TestFlight submission. App icon + splash. Info.plist marketing strings. App Store screenshots. Privacy policy + EULA. Cloud asset storage (R2 / S3). Supabase Auth + Postgres migration off SQLite. Trophy backend sync.
- **S16 — "Discover" (or playscape redesign, if S14 signal demands):** Either Pinterest-style discovery layer maturation OR a deeper Home/Lessons/Trophy visual rebuild based on retest signal. Branch decision at S14 close.
- **S17+ — "Scale":** Localization. Multi-kid family UX. Parent dashboard. Cross-device sync of trophies + voice prefs.

---

*Tracker scaffolded April 26, 2026 immediately following User Review #01 (kid-test on the S13 build). Carry-ins: VOX touch-test follow-ups from S13 (4 items) + S12-10 Rainbow + Planet re-seed (2 pts pending Mac). Sprint goal is binary: bang's kid picks the iPad up, the app talks to him, he can navigate without adult help. Stories fill in Delivery Notes sections below as they complete, following the SPRINT-10/11/12/13 idiom: Files changed / Architectural decisions / Validation / Prerequisites bang must run on his Mac.*

---

## Delivery Notes

*(Populate as stories close. First entry will land after S14-VF epic closes — voice-first navigation across all Tier 1 surfaces.)*
