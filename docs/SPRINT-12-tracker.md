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
| S12-01 | iPad layout adaptivity pass | 5 | ✅ Done | Plumbed `horizontalSizeClass` through `EnhancedHomeView`, `LearningPathCard`, `MasonryGrid` (via `LessonsView`), `TrophyRoomView`. Hardcoded tile widths now adapt (lesson 140→196, path card 180→252, trophy grid 3→5, masonry 2→3). Double-frame `(maxWidth: X).frame(maxWidth: .infinity)` pattern landed on `OnboardingView` (4 pages, via `@ViewBuilder` helper), `KidsLoginView` (480pt column cap), `FlipbookView` (CardProgressDots + Prev/Next pair at 600pt), `DashyHintSheet` (600pt content cap while background fills full sheet). Bonus bug fix retired: progress bar math now `GeometryReader`-driven (`CGFloat(progress) * geo.size.width`) instead of the hardcoded `* 160` that overflowed by 12pt at full progress. See `docs/sprint-runs/S12-01-03-ipad-qa.md`. |
| S12-02 | Dynamic Type pass | 2 | ✅ Done | One-line `NovaPalette.displayFont(size:relativeTo:)` signature change landed with `.title` default — 16 call sites untouched. Sweep added `.minimumScaleFactor(0.7)` before `.lineLimit(1)` on FlipbookHeader:64 (lesson title), BadgeView:152 (earned date), and three ExperimentCardView sites (drag label, placed item, target label). Bangers-font titles now scale cleanly from `.xSmall` to `.accessibility5` instead of truncating. See `docs/sprint-runs/S12-01-03-ipad-qa.md`. |
| S12-03 | Dark-mode contrast pass | 1 | ✅ Done | Added `NovaPalette.textOnPathColor(for:)` helper returning fixed dark navy (`0.102,0.129,0.220`) for 5 of 6 categories and white for purple — the only rainbow category where white clears WCAG AA (4.58:1). LearningPathCard now pairs `bg` ↔ `fg` through the helper so title, icon, lesson-count caption, progress track, and "% complete" all meet AA. Non-adaptive by design — rainbow category bgs stay bright in dark mode so an adaptive `fg` would flip to off-white-on-orange and reintroduce the exact contrast failure the audit flagged. See `docs/sprint-runs/S12-01-03-ipad-qa.md`. |

### CE Epic — Content Engine Expansion (18 pts)

Carried from S10. S10-12 closed with the skill-engine generating `story` + `quiz` atoms through the decomposition-aware path; `experiment`, `voice`, and `curriculum` still run on the legacy generator. This epic completes the 5-modality matrix so **every card type on the flipbook** comes through the skill-engine and the atomic `ok/retry-ok/retry-failed/skipped` Pipeline-tab telemetry. Shape mirrors S10-R4 (story-writer) and S10-07 (quiz-maker) exactly — lifted patterns, not new architecture.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S12-04 | `experiment-designer` skill — def bundle + engine wiring | 6 | ✅ Done | Mirrored S10-07's quiz-maker shape: `manifest.json` + `prompt.md` + `styles.md` + `topics.md` + `age-profiles/{4,6,8}.md` + `difficulty-curves/{easy,medium,hard}.md` (10 def files) + per-skill Zod validator (260 LOC, 8 referential-integrity superRefine invariants) + `skillRouter` touchpoints (token ceiling 900, `claude-sonnet` pick, `buildSkillInputs` + `buildCardFromSkillOutput` dispatch) + 3 test files (86 new assertions across validator / router / skillEngine suites). Design-question resolved without a separate age-gated materials list: difficulty matrix (3 items × 2 bins easy / 4×2 medium / 5×3 hard) + age-profile tone curve cover the cognitive-load calibration — materials stay age-safe via prompt constraints rather than a separate validator dimension. Retires one of the three S10-12 legacy-fallback paths (`generateExperimentCard` stays dead-coded until S12-05 + S12-06 close). See `docs/sprint-runs/S12-04-experiment-designer.md`. |
| S12-05 | `curriculum-architect` skill — def bundle + engine wiring | 6 | ✅ Done | Second CE-epic story landed. Mirrored S12-04 shape but re-targeted to **Stage 3** (decomposition) — single-call router (`services/pipeline/decompositionRouter.ts`, 593 LOC) answers "what *ought* to be in this lesson" before per-atom fanout. Skill defs: 10 files under `defs/curriculum-architect/` — `manifest.json` (`modelHint: pro`, `temperatureHint: 0.5`, `inputs.requires: ["topic","summary","suggestedStage"]`, `ageProfiles: [4,6,8]`, `difficulties: ["easy","medium","hard"]`, `handlesConceptTypes: []`), `prompt.md` (183 LOC with `<!-- user-prompt -->` system/user split), `styles.md` + `topics.md`, per-age + per-difficulty partials. Zod validator (`validators/curriculumArchitect.ts`) stacks **six `.strict().superRefine()` invariants** on a strict base: atom-N sequential-id sequence, strategy↔cardType compatibility matrix, prerequisite DAG (topological), card-type diversity (≤1 back-to-back same type), lesson shape (3–6 atoms, opener=narrative/explanation, closer=quiz/reflection), voice ceiling (≤1 `voice` atom per decomposition). **`routeDecomposition()` state machine:** env-gate via `SKILL_ENGINE_STAGE3` (defaults ON), short-circuit on registry miss / missing topic+summary → `skill-not-loaded` / `missing-required-input`; first LLM call (`claude-sonnet`, maxTokens 1400, `routingReason: 'concept_decomposition'`); validate → retry-on-Zod-or-parse with pretty-printed error appended to user turn + temperature reduced by 0.1; transient-error classifier (timeout/econnreset/fetch failed/rate limit/429/502/503/504) re-throws to outer `runStage` instead of swallowing; non-transient errors captured as `reason: 'llm-error'`; whitespace-only response → `reason: 'empty-response'` (single-call, not retryable). **Tests:** 111 assertions across three files green — `curriculumArchitectValidator.test.ts` (40 cases, every invariant with positive + negative fixtures per difficulty), `decompositionRouter.test.ts` (25 cases, full state machine incl. happy / retry-ok / retry-failed / JSON-parse retry / skill-not-loaded / missing-input / transient re-throw / non-transient llm-error / empty-response / feature-flag matrix), `skillEngine.test.ts` +2 boot assertions confirming curriculum-architect loads from real defs tree with correct manifest shape. **Retired debt:** fixed three latent type errors in `decompositionRouter.ts` (trace fields `ageProfileUsed` / `difficultyUsed` now coerce `SkillPromptMeta`'s optional `number` / literal-union into display-ready strings with `'unknown'` fallback); fixed manifest drift — `modelHint: "sonnet"` rejected by `SkillManifestSchema` (enum is capability tier `'flash' | 'pro'`, not provider model name — actual model routing happens via `routeRequest`'s `model: 'claude-sonnet'` param). Retires the second of three S10-12 legacy-fallback paths — legacy heuristic decomposer now dead-coded when Stage 3 is enabled. See `docs/sprint-runs/S12-05-curriculum-architect.md`. |
| S12-06 | `voice-persona` skill — def bundle + engine wiring | 6 | ✅ Done | Third and final CE-epic story landed — **CE epic 100%, full 5-modality skill-engine complete.** Mirrored S12-04 shape exactly at the def-bundle + validator + router layers: 10 def files under `defs/voice-persona/` (`manifest.json` — `modelHint: "flash"`, `temperatureHint: 0.6` for stylistic voice latitude, `inputs.requires: ["concept","conceptType"]`, `inputs.optional: ["topic","targetLessonId","lastStoryExcerpt"]`, `handlesConceptTypes: ["vocabulary","factual","abstract"]` — NOT process / comparison / causeEffect because those need diagram or narrative scaffolding voice can't provide), `prompt.md` (135 LOC, first-person Dashy voice gates + output contract declaring `promptText` / `expectedResponses` / `celebration` / `retryHint` / optional `phonetics` / `conceptSummary`), `styles.md` (3 voice shapes: Wondering-Aloud default + Echo-and-Read for phonics + Call-and-Response for patterns), `topics.md` (good-fit vs bad-fit taxonomy — single-word recall / short-fact / phonics / counting are good, multi-step reasoning / subjective / picture-dependent are bad), per-age + per-difficulty partials. **Zod validator (`validators/voicePersona.ts`)** stacks 10 `.strict().superRefine()` invariants — the Dashy voice contract lives in six of them: (1) `promptText` MUST contain first-person marker (I/me/my/we/us/our/let's/I'm/I'll/I've/mine), (2) `promptText` MUST NOT contain voice-of-god instructionals ("you will" / "you must" / "you should"), (3) `celebration` MUST have first-person marker, (4) `celebration` MUST NOT contain voice-of-god praise ("you got" / "good job") — Dashy shares the win not grants it from above, (5) `retryHint` MUST have first-person marker, (6) `retryHint` MUST NOT contain hard corrections ("wrong" / "incorrect" / "no,") — voice-mode misses get soft resets not reprimands; plus (7) `expectedResponses` case-insensitively unique after whitespace-normalization, (8) `phonetics` shape `/^[a-z]+(-[a-z]+)*( [a-z]+(-[a-z]+)*)*$/` for clean TTS articulation, (9)–(10) substantive-text gates on every field (`/[\p{L}\p{N}]/u`). **Router wiring via 5 touchpoints** — `SKILL_MAX_TOKENS['voice-persona'] = 700` (shorter than experiment's 900, longer than quiz's 600 — empirically 300–500 with ~50% headroom), `SKILL_TO_MODEL['voice-persona'] = 'claude-sonnet'`, `buildSkillInputs('voice-persona', ...)` emits concept + conceptType (STRATEGY_TO_CONCEPT_TYPE maps `voice` → `abstract` by default) + optional topic + optional lastStoryExcerpt, `buildCardFromSkillOutput('voice-persona', ...)` emits `type: 'voice'` with `content: { title, promptText, expectedResponses, celebration, retryHint, phonetics }` matching iOS `Card.CardContent.promptText` / `.expectedResponses` camelCase directly (no rename needed at the Swift decoder transformer — these are already camelCase-clean), `voiceScript = promptText + ' ' + celebration` (Dashy intro + shared-win line; `retryHint` deliberately NOT in default voiceScript because it only fires on a miss — iPad reads it on-demand from `content.retryHint`). Also: `CARD_TYPE_TO_SKILL.voice: 'voice-persona'` added in `skills/types.ts`; `CardContent` interface in `cardGenerator.ts` expanded with 5 voice-mode fields (`promptText` + `expectedResponses` + `celebration` + `retryHint` + `phonetics`). **Tests:** 60 new assertions across three files — `voicePersonaValidator.test.ts` (51 cases: happy paths per difficulty + 6 Dashy-voice gate rejections per line × positive fixture + phonetics shape + uniqueness + base bounds), `voicePersonaRouter.test.ts` (7 cases: router dispatch voice atom → voice-persona not legacy, GeneratedCard shape with camelCase content fields, voiceScript excludes retryHint, analysis.topic threading, lastStoryExcerpt threading for Dashy shared-context, `claude-sonnet` + `maxTokens=700`, retry-on-Zod success + retry-failed), `skillEngine.test.ts` +2 boot assertions. **Retired debt:** legacy inline voice branch at `cardGenerator.ts:432-438` now dead-coded for `card.type === 'voice'` atoms; **all three S10-12 legacy-fallback paths now retired** (`generateStoryCard` / `generateQuizCard` / `generateExperimentCard` went dead over S10-R4 / S10-07 / S12-04; the inline voice-branch + legacy heuristic decomposer close with this run). **Drift (caught + fixed in R5):** two content-layer issues surfaced only when tests ran against the real defs tree — (a) Handlebars partial `{{> styles}}` doesn't exist; the registry registers `styles.md` as `styleExamples` (name-drift inherited from S10-R4 registry.ts), fixed by renaming the template reference; (b) Handlebars helper `{{truncate inputs.lastStoryExcerpt 400}}` doesn't exist in the engine — experiment-designer uses raw `{{inputs.lastStoryExcerpt}}` without truncation because the excerpt is already truncated at the pipeline orchestrator layer before reaching the skill. Both fixes align voice-persona with the existing skills' Handlebars conventions. Backend suite: **823 pass / 1 carry-in debt fail** (pre-existing `sprint6.test.ts` SPARKY_SYSTEM_PROMPT — still the lone red cell, resolves when RN epic closes); +60 new assertions = 106 voice-persona specific green (51 + 7 + 48 total file counts). Zero new tsc errors (baseline 51 held constant). See `docs/sprint-runs/S12-06-voice-persona.md`. |

### RN Epic — Sparky → Dashy Coordinated Rename (5 pts)

Closes the asymmetric-rename carve-out S11-09 + S11-19 both documented. S11-09 renamed user-visible strings (iOS). S11-19 preserved `role == "sparky"` wire literal + `/sparky/chat` endpoint path because changing those is a **coordinated migration** (backend file rename + wire-protocol change + iOS VM update + DB column rename all in one commit range, not three independent passes). This is that pass.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S12-07 | Filepath rename — `services/sparky/` → `services/dashy/` with import sweep | 3 | ✅ Done | `git mv` on the directory + the route file + the 3 imports (`routes/index.ts`, `routes/sparky.ts` → `dashy.ts`, `tests/sprint6.test.ts`). Route path `/sparky/chat` → `/dashy/chat`. TS identifiers: `SPARKY_SYSTEM_PROMPT` → `DASHY_SYSTEM_PROMPT`, `SparkyResponse` → `DashyResponse`, `processSparkyMessage` → `processDashyMessage`. **Scope beyond the 3 documented carve-outs** — surfaced in R1 mapping: Prisma `SparkyConversation` model + `sparky_conversations` table rename (with a Prisma migration queued for bang's Mac `prisma migrate dev`), `sparkyRateLimiter` + `sparky_voice_chat` feature flag key + `sparky_chat` cost-tracker feature string + `prisma.sparkyConversation.findMany`/`.updateMany` call sites in `dataRights.ts` + `JSON_STRING_FIELDS.sparkyConversation` middleware registration in `db/client.ts`. All flipped. 8 Sparky strings in `db/seedCurriculum.ts` lesson content (user-facing body text shown to kids: "Talk to Sparky!" / "Sparky tries to answer!" etc.) also flipped — these are what a touch-test kid would read. See `docs/sprint-runs/S12-07-08-sparky-dashy-rename.md`. |
| S12-08 | Wire-literal rename — `role: "sparky"` → `role: "dashy"` + iOS VM update | 2 | ✅ Done | Wire-literal flipped in three iOS sites: `DashyViewModel.swift` line 263 (`role: "dashy"` assignment on server-authored message construction) + line 32 (`role` field comment), `DashyView.swift` line 222 (`if message.role == "dashy"` bubble-type discriminant). iOS `Endpoint.sparkyChat()` factory → `Endpoint.dashyChat()` + path `"/sparky/chat"` → `"/dashy/chat"` in `Packages/NovaCore/Sources/NovaCore/API/Endpoint.swift`. Additional iOS: `VoiceStyle.sparky` enum case → `.dashy` in `Packages/NovaVoice/Sources/NovaVoice/SpeechSynthesizer.swift` (voice tone/speed profile — not character-identity but grep-scope per DoD) + `DeepLinkDestination.sparky` → `.dashy` in `NovaCompanion/Sources/Services/DeepLinkHandler.swift` + `nova://sparky` → `nova://dashy` deep-link host. **The `SPARKY_SYSTEM_PROMPT` constant's text contained "You are Dashy" (flipped in S11-09)** — the failing `sprint6.test.ts` assertion on line 28 was `expect(SPARKY_SYSTEM_PROMPT).toContain('Sparky')` asserting the OLD word against the NEW prompt, which is what made it the lone red cell since S11-09. This story flipped the constant name AND the assertion target in lockstep; the test is now green. No DB migration data-loss risk — `dashy_conversations` is the new mapped table, Prisma will generate a rename migration on `prisma migrate dev`. **Regression (Mac-side):** S11-13 DashyView chat flow — send a message, confirm the paper-and-ink Dashy bubble still renders (the discriminant check at line 222 now matches "dashy" from the new wire literal). See `docs/sprint-runs/S12-07-08-sparky-dashy-rename.md`. |

### MVP Epic — Touch Test Loop (14 pts)

The actual point of the sprint. These stories land the content-authoring workflow bang needs to create real lessons on his Mac and see them appear on the iPad. Sequenced **after CE epic** because the skill-engine needs to be complete before content authoring is worth stress-testing — you can't author an experiment card if `experiment-designer` doesn't exist yet.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S12-09 | Dev Console — content authoring surface | 5 | ✅ Done | New **Author Lesson** tab in `dev-pipeline.html` between Skills and Progress Inspector. Form: child dropdown (populated from `GET /children`), path dropdown (`GET /paths`) with an inline **+ New Path** collapsible form (title + icon emoji + hex color + description → `POST /paths`), URL input, optional title/description overrides, skip-quality-gate toggle. Submit opens a **POST streaming fetch** to the new `/api/v1/dev/author-lesson` endpoint — the browser's native `EventSource` is GET-only so the frontend reads `reply.body` as a `ReadableStream` and parses `data: <json>\n\n` frames manually. Per-stage pills light up as SSE events arrive: `scrape → analyze → decompose (skill-engine or legacy) → generate (skill-engine or legacy) → quality → persist → complete`. On `complete:done` the tab renders a lesson card with `lessonId` + `cardCount` + `skillEngineUsed` + optional `qualityScore`, plus a **"Jump to Pipeline tab →"** button that pre-selects the new lesson's skill-trace panel. **Backend architecture:** added `onStageEvent?: (event: PipelineStageEvent) => void` hook to `PipelineOptions`; the orchestrator calls `emit(opts, { stage, status, ... })` at every stage boundary via a synchronous fire-and-forget helper that swallows handler errors (disconnected SSE must not kill the pipeline). New `PipelineStageEvent` discriminated union with 20+ variants gives the frontend one switch-based renderer and full per-stage detail (atom counts, retry counts, validator status, elapsed ms, etc). **New route** `routes/devAuthor.ts` (260 LOC): Zod body schema with `.strict()` (`url` + `childId` + `pathId` required, `title`/`description`/`skipQualityGate` optional), ownership pre-check (403 if child or path isn't owner's) BEFORE opening SSE so auth failures are clean JSON not mid-stream, `reply.hijack()` + raw Node response headers (`text/event-stream`, `no-cache`, `keep-alive`, `X-Accel-Buffering: no` to defeat nginx buffering), UrlIngest row creation + `ingest:created` SSE seed event, `runPipeline(userId, ingestId, pathId, { childId, skipQualityGate, onStageEvent })` bridges the orchestrator's events directly to `reply.raw.write('data: {json}\n\n')` with a `writable` check on each write. Optional title/description override applied via `prisma.lesson.update` after pipeline completes. Terminal `complete` event always fires (either `status: done` or `status: failed`) so the client sees a definitive end state and can close its fetch reader. **Paths are `userId`-scoped, NOT `childId`-scoped** per the Prisma `LearningPath` model — "multiple paths" in this sprint means parent creates multiple paths that all their children share; per-child paths is a schema change deferred to S13+. **Tests:** 11 assertions in `tests/devAuthor.test.ts` covering Zod body validation (missing/malformed URL, non-UUID childId, missing pathId, strict-mode unknown field), auth/ownership (401 no-bearer, 403 cross-user child, 403 cross-user path), and SSE flow (happy path asserting `connection:open` → `ingest:created` → scrape/analyze/decompose/generate/persist stages → `complete:done` with `lessonId` + `cardCount` + `skillEngineUsed`; error path asserting `complete:failed` with error propagation). Full backend: **834 pass / 0 fail** (previous flaky LLM-timeout even settled this run). Zero new tsc errors — baseline 51 held constant. See `docs/sprint-runs/S12-09-author-lesson-tab.md`. |
| S12-10 | Seed — 3 real lessons through the full pipeline | 3 | 🟡 1/3 green (Sky) · Content Browser + 3 unblocks shipped · Rainbow+Planet awaiting re-seed | **Run 2 update (Apr 23):** Sky lesson seeded green end-to-end (6 atoms, all `ok`, zero skipped, zero retry-failed). Rainbow + Planet await re-seed post-concept-routing-fix. **Scope-absorbed debt retired this run:** (1) iOS Xcode 26 / Swift 6.2 strict-concurrency build unblock — 3 fixes across `FlipbookHeader` (non-exhaustive switch on `Card.CardType.video`), `TrophyRoomViewModel` (`@MainActor` isolation leak on `childId` inside `async let` fan-out — captured to local before hop), `DashySpeechBubble` (`SpeechBubbleTailSide` enum missing `Sendable`). (2) Systemic concept-atom silent skip — `CARD_TYPE_TO_SKILL` was missing `concept: 'story-writer'` mapping, so every `curriculum-architect`-decomposed `concept` atom silently returned `skipped` with reason `no-skill-mapping` (9 ok / 7 skipped across 3 first-run lessons, 100% of skips were concept). Fix: one-line map entry + 5-line branching in `buildCardFromSkillOutput` (emit `type: 'concept'` with `content.explanation` when `atom.recommendedCardType === 'concept'`, else `type: 'story'` with `content.narrativeText`) + `CardContent` interface expanded with `narrativeText?`/`explanation?` + `normalizeCard` double-writes canonical field + legacy `content.text` back-fill (no DB migration needed) + 5 skill-router tests updated to use synthetic unmapped-cardType cast so defensive guard still exercised. (3) Pipeline stage-4 generate timeout bumped from 45s → 120s (and pipeline from 120s → 300s) — post-concept-fix all atoms route through real LLM calls, 6 atoms × ~5–10s serial = 30–60s baseline, blew past the 45s cap. Parallelization of per-atom loop logged for S13+ after rate-limit audit. (4) **Dev Console Content Browser built into the Pipeline tab's existing Skill Engine container** (319 LOC in `dev-pipeline.html` + 19 LOC in `routes/lessons.ts`) — path rail + lesson list + orphan bucket + auto-sync on external drivers (Author tab Jump-to-Pipeline, console trick, in-page URL Ingest+Generate) + `GET /lessons` select expanded with `pathId` + `_count.cards` unwrapped to flat `cardCount`. Reused same container per bang's "no new UI page" constraint. Limit-fix follow-up (`?limit=200` → `?limit=100` matches schema ceiling). **Sandbox work delivered (Run 1, commit `74932ba`):** (a) seed-plan picking 3 stable Simple Wikipedia URLs with target modality mixes — Sky (story-heavy, 4 atoms, LOW retry risk), Rainbow (experiment-heavy, MEDIUM — 8 referential-integrity invariants on the drag/drop atom), Planet (quiz-heavy + voice, **HIGH** retry risk on the voice atom per voice-persona's 6 Dashy-voice gates that commonly trip "you got it!"/"good job!"/"you will"-style phrasings); (b) **2 blockers fixed in-sandbox that would have broken S12-11 touch test** — `Card.CardContent` was missing `celebration` + `retryHint` + `phonetics` fields (S12-06 voice-persona emits them, iOS silently dropped them via Codable's default unknown-key behavior), added as optional Strings + CodingKeys + init params; `VoiceCardView` had a hardcoded `"That's a great answer! You said: ..."` canned response ignoring `expectedResponses` entirely — full rewrite (~300 LOC) with explicit Phase state machine (idle→listening→matching→celebrating|reprompting→idle|Next), fuzzy bidirectional transcript match (`normalize(lowercase + whitespace-collapse + strip .,!?)` both sides, contains check tolerates "a kitten" vs "kitten" fuzziness), TTS playback of celebration/retryHint via `voiceManager.speak(text:)`, S11-02 comic palette (ink/coral/sun/page/novaCardBackground) replacing pre-rebase novaPurple/novaBlue/novaOrange, S11-03 `.novaPrimary()`/`.novaSecondary()` button styles, S11-04 `displayFont(size:relativeTo:)` + `.minimumScaleFactor()` pairs for Dynamic Type scaling, S11-15 `NovaHaptics` ladder (tap on mic start, success on match, wrong on miss), `TimelineView(.animation)` source-level reduce-motion gate on listening pulse replacing the S11-13 Timer.scheduledTimer that mutated @State under strict-concurrency, `@MainActor Task` on the speech recognizer loop, accessibility labels + hints on the mic button ("Start/Stop listening" + "Double-tap to answer Dashy's question"), "Skip for now" escape hatch after a miss so kid isn't trapped in infinite loop; (c) preflight-swift-audit doc documenting 5 lower-severity carve-outs for S13+ (StoryCardView:80 + ExperimentCardView:82,148 scale-factor + palette nits, ShakeModifier Timer data race latent under Swift 6 strict, VoiceCardView DashyCharacterView migration deferred to S13 polish, phonetics field decoded but unused pending AVSpeechUtterance.pronunciations hook); (d) 7-file scaffolded artifact directory (`docs/sprint-runs/S12-10-seed-lessons/`) — README index + seed-plan with retry-risk matrix + 3 per-lesson templates (pre-submit checklist + SSE event log table + per-atom trace table + screenshot markers + iPad render notes + verdict section) + outcomes.md for cross-lesson totals + Mac-side runbook with troubleshooting + curl fallback for inspecting persisted lessons. **Next step:** bang runs `xcodebuild` on his Mac to confirm the VoiceCardView rewrite compiles clean, then walks the runbook to seed the 3 URLs. DoD is zero `retry-failed` + zero `skipped` atoms on first pass; `retry-ok` is acceptable (engine caught + retried successfully). Once seeded, flip this row to ✅ Done + bump Sprint Summary +3 pts. See `docs/sprint-runs/S12-10-seed-lessons/`. |
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
| S12-16 | Pipeline tab regression sweep after CE epic lands | 3 | ✅ Done | Closed via cross-skill cardType coverage suite in `tests/pipelineSkillIntegration.test.ts` + structural refactor exposing `CARD_TYPES` const-as-source-of-truth in `services/skills/types.ts`. **Three tests added (4 assertions across structural + integration layers):** (1) meta — every entry in `CARD_TYPES` has a non-empty `CARD_TYPE_TO_SKILL` mapping, catches the S12-10 concept-skip bug class at the structural level if anyone adds a new cardType to the schema without wiring its routing; (2) meta inverse — `CARD_TYPE_TO_SKILL` has zero orphan keys outside `CARD_TYPES`, catches stale-rename drift; (3) integration — full 5-atom decomposition (one of each cardType: story / concept / experiment / quiz / voice) runs through `generateCardsWithSkills` with mocked LLM, asserts zero skipped atoms, zero legacy fallback invocations, exactly 5 LLM calls, every trace `validatorStatus: 'ok'`, every emitted card carries its canonical iOS-facing field (narrativeText / explanation / dragItems / options / promptText) populated; (4) Pipeline-tab observability — every trace surfaces correct `skillName` per cardType so the Dev Console's per-atom row rendering can distinguish skill-ran-successfully from atom-fell-to-legacy. **Refactor:** moved `CardType` literal-union from inline declaration in `cardGenerator.ts` to a derived `typeof CARD_TYPES[number]` in `services/skills/types.ts`; `cardGenerator.ts` re-exports for back-compat with `skillRouter.ts` + `conceptDecomposer.ts` import sites. **Why this matters:** the S12-10 mid-sprint debug surfaced that no integration test ran a full mixed-cardType decomposition through per-atom dispatch — `concept` atoms were silently returning `skipped: no-skill-mapping` for an entire sprint of testing, hidden because each per-skill test happy-pathed against atoms of its own cardType only. Closing this gap means the next time a cardType is added to the schema, two layers (TypeScript exhaustiveness on `CardType` + the meta test on `CARD_TYPE_TO_SKILL`) catch the missing routing before any kid sees a blank card. tsc baseline 33 errors held constant; sandbox vitest blocked by rollup arm64 module gap (Mac-only run). QA epic flips to 3/7 (43%); Sprint 12 Total to 39/60 (65%). Mac-side validation: `npm test -- tests/pipelineSkillIntegration` should report all S12-16 cases green. |
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
| CAR | 8 | 8 | 100% |
| CE  | 18 | 18 | 100% |
| RN  | 5 | 5 | 100% |
| MVP | 5 | 14 | 36% |
| POL | 0 | 8 | 0% |
| QA  | 3 | 7 | 43% |
| **Sprint 12 Total** | **39** | **60** | **65%** |

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

### S12-01/02/03 — CAR epic closed (iPad QA carry-in retired)

Landed Apr 22 2026 as one coordinated three-story run — all three S11-18 audit findings (layout adaptivity, Dynamic Type, dark-mode contrast) ship together because they hit the same surfaces and splitting them across three days would have re-rediscovered the same layout edges three times. 8 pts → ✅. Full write-up: `docs/sprint-runs/S12-01-03-ipad-qa.md`.

**In plan:** every bullet in the CAR epic's original scope. Plumbed `horizontalSizeClass` through 4 views (EnhancedHomeView, LearningPathCard, LessonsView, TrophyRoomView); applied double-frame maxWidth pattern to 4 more (OnboardingView, KidsLoginView, FlipbookView, DashyHintSheet); one-line `displayFont(size:relativeTo:)` signature upgrade + 5-site `.minimumScaleFactor(0.7)` sweep; non-adaptive `textOnPathColor(for:)` helper for WCAG AA on the 6 path-card categories.

**Drift (positive):** the `GeometryReader`-driven progress-bar math also retired a latent bug — the old `CGFloat(progress) * 160` overflowed the card interior by ~12pt at `progress = 1.0` because the actual inner width is 148pt, not 160pt. Free fix, was going to be S13 debt.

**Validation left for bang's Mac:** iPad Pro 12.9" simulator walk-through (both orientations × light/dark × `.xSmall`/`.accessibility5`) — scheduled as S12-18 anyway, not re-run here because sandbox has no simulator. Sandbox-side type-check was done file-by-file during edits.

### S12-04 — `experiment-designer` shipped (CE epic kickoff)

Landed Apr 22 2026 as the first of the three carry-from-S10 content-engine expansion stories. 6 pts → ✅. Full write-up: `docs/sprint-runs/S12-04-experiment-designer.md`.

**Files changed (1,895 LOC total):**

- `src/Backend/src/services/skills/defs/experiment-designer/manifest.json` — new (33 LOC). Name + version + `modelHint: flash` + `temperatureHint: 0.5` + `inputs.requires: ["concept","conceptType"]` + `inputs.optional: ["topic","targetLessonId","lastStoryExcerpt"]` + `ageProfiles: [4,6,8]` + `difficulties: ["easy","medium","hard"]` + `handlesConceptTypes: ["process","comparison","causeEffect","vocabulary","factual"]`.
- `src/Backend/src/services/skills/defs/experiment-designer/prompt.md` — new (140 LOC). System block + `<!-- user-prompt -->` marker + user block. Enforces the JSON output contract: `{title, instructions, dragItems, dropTargets, conceptSummary, rationalePerTarget}` with kebab-case ids + referential-integrity prose.
- `src/Backend/src/services/skills/defs/experiment-designer/styles.md` — new (40 LOC). Voice + tone partial; mirrors quiz-maker's styles partial shape.
- `src/Backend/src/services/skills/defs/experiment-designer/topics.md` — new (60 LOC). Topic-drift guardrails for the LLM's bucket-naming.
- `src/Backend/src/services/skills/defs/experiment-designer/age-profiles/{4,6,8}.md` — new (3 files, 80 LOC each). Per-age cognitive load + reading level + allowed materials phrasing. 4 = picture-first / single-attribute; 6 = early reader / dual-attribute; 8 = fluent reader / multi-attribute.
- `src/Backend/src/services/skills/defs/experiment-designer/difficulty-curves/{easy,medium,hard}.md` — new (3 files, 40 LOC each). Locks the difficulty matrix: `(3 items × 2 bins) easy · (4×2) medium · (5×3) hard`. Validator enforces; prompt narrates.
- `src/Backend/src/services/skills/validators/experimentDesigner.ts` — new (260 LOC). Strict `.object(...).strict().superRefine(...)` with 8 layered invariants: difficulty matrix, rationalePerTarget parity, dragItem id uniqueness, dropTarget id uniqueness, referential integrity (orphan + dual-assignment + non-existent-ref), dragItem label uniqueness (case-insensitive + whitespace-normalized), dropTarget label uniqueness, substantive labels (`/[\p{L}\p{N}]/u` rejects emoji/punctuation-only).
- `src/Backend/src/services/skills/validators/index.ts` — +2 LOC. One-line registry append: `'experiment-designer': experimentDesignerOutputSchema` in `SKILL_OUTPUT_SCHEMAS`.
- `src/Backend/src/services/pipeline/skillRouter.ts` — +52 LOC. Four touchpoints: `SKILL_MAX_TOKENS['experiment-designer'] = 900`, model-pick `claude-sonnet` per manifest, `buildSkillInputs('experiment-designer', ...)` (concept + conceptType + optional topic + optional lastStoryExcerpt), `buildCardFromSkillOutput('experiment-designer', ...)` emits `type: 'experiment'` with `content: { title, instructions, dragItems, dropTargets }` + `voiceScript = instructions + conceptSummary`.
- `src/Backend/tests/experimentDesignerValidator.test.ts` — new (628 LOC, 35 cases). Covers every superRefine invariant with positive + negative fixtures, includes the fixed `"accepts label with a digit"` case that overrides both `dragItems` AND `dropTargets` together to preserve referential integrity while exercising only the substantive-label path.
- `src/Backend/tests/experimentDesignerRouter.test.ts` — new (379 LOC, 7 cases). Locks the router dispatch: `experiment` atom → `experiment-designer` skill (not legacy), payload shape, Sonnet model pick, 900-token ceiling, camelCase `dragItems`/`dropTargets` on the wire, voiceScript assembly.
- `src/Backend/tests/skillEngine.test.ts` — +44 LOC (9 new cases in experiment-designer describe block). Age-profile cascade, difficulty-curve locks, progressionDelta resolver, difficulty bucket ties-round-down.

**Architectural decisions (the "why X over Y" log, condensed — full version in run summary):**

1. **Per-item kebab-case `id` on the wire, not auto-assigned UUID.** The LLM *names* the mapping (`cork` ↔ `floats.acceptsItemIds[0]`) so Zod can cross-reference. Alternative (post-process label-to-id) rejected — backend would need the LLM to re-emit labels inside `acceptsItemIds` and referential integrity couldn't be enforced in-schema.
2. **Orphan + dual-assignment checks as a single `acceptedCount` map** (`=== 1` invariant). Every dragItem in exactly one dropTarget — never zero (kid can't place it), never two (ambiguous). Multi-select needs a separate card type, not a loosening of this one.
3. **Difficulty matrix as discrete `(3,2)/(4,2)/(5,3)` tuple.** Continuous-range heuristic rejected — fuzzy bounds let a 5/2 at easy "look OK" but break age-4 cognitive load. Discrete ladder is easier to test, retry, and debug.
4. **Substantive-label check uses `/[\p{L}\p{N}]/u`.** `\p{L}` + `\p{N}` + `/u` flag accepts "1st", "café", "rocks 🪨"; rejects "🍾", "...", whitespace-only. Future-proofs for international content.
5. **Label uniqueness case-insensitive + whitespace-normalized** via `s.trim().toLowerCase().replace(/\s+/g, ' ')`. LLM will emit `"Floats"` and `"floats"` thinking they're distinct; validator reports the *original* label in the error so retry-prompt can point at what was actually written.
6. **camelCase on wire, snake_case in Swift decoders** — same boundary as quiz's `correct_option_index`. iOS `Card.DragItem`/`Card.DropTarget` transformer handles the rename at decode. Locked as a code comment inside `buildCardFromSkillOutput`.
7. **`maxTokens: 900` specific to this skill.** Story 2400 (prose), quiz 600 (bounded options), experiment empirically lands at 400–600 with 50% headroom. Surfaces runaways as retries, not silent truncation.
8. **`rationalePerTarget` as a parallel length-N array, not nested under `dropTargets`.** Rationales emitted *after* the sort is finalized in the JSON order — matches how a human narrates ("here's the sort; here's why it works"). Nested form produces sloppy pairings because the LLM commits to rationale before finalizing `acceptsItemIds`.

**Validation (sandbox ✅):**

- `tests/experimentDesignerValidator.test.ts` — 35/35 green. All 8 superRefine invariants have rejection + acceptance fixtures; the "accepts label with a digit" regression case preserves referential integrity while exercising only the substantive-label path.
- `tests/experimentDesignerRouter.test.ts` — 7/7 green. Router dispatch, payload shape, Sonnet pick, token ceiling, camelCase wire, voiceScript assembly.
- `tests/skillEngine.test.ts` — 9 new assertions in experiment-designer describe block, 44 total in file — all green. Age-profile cascade phrases (`picture-first` / `early reader` / `fluent reader`) + difficulty markers (`Recognition-level` / `Application-level` / `Transfer-level`) + 3×2 / 4×2 / 5×3 shape locks + progressionDelta + ties-round-down all locked.
- Full backend suite: 696 pass / 1 carry-in debt fail (the pre-existing S11-09/S12-08 `SPARKY_SYSTEM_PROMPT` fixture in `sprint6.test.ts` — resolves when the RN epic closes this sprint). No S12-04 regression.
- `tsc --noEmit` regression check: filtered for `experimentDesigner|skillEngine` returned zero new errors — baseline 33 pre-existing errors held constant.

**Validation left for bang's Mac (🟡):**

- Dev Console **Skills** tab dry-run render of `experiment-designer` with controls for `ageYears` + `progressionDelta` + `difficultyOffset` — walk the 8-cell matrix documented in the run summary and confirm `meta.ageProfileUsed` / `meta.difficultyUsed` tags match expectations.
- Dev Console **Pipeline** tab regression — confirm `skillEngineUsed: true` + per-atom pills now fire for an `experiment` atom (previously fell through to `generateExperimentCard` legacy).
- End-to-end iPad render — draft a lesson with an experiment atom, confirm the iPad's `ExperimentCardView` renders the drag items + drop targets correctly after the JSON transformer renames `dragItems` → `drag_items`.

**Prerequisites bang must run on his Mac:**

```bash
cd ~/Code/Novai/src/Backend
npm run build                                    # confirm clean tsc
npm run test -- tests/experimentDesignerValidator tests/experimentDesignerRouter tests/skillEngine
# expect: 86 assertions green across the three suites
npm run dev                                      # boot backend on 3000
open http://localhost:3000/dev-console/skills    # walk the 8-cell age × difficulty matrix
open http://localhost:3000/dev-console/pipeline  # regression-check skillEngineUsed=true for experiment atoms
```

**In-plan vs drift:**

- In-plan: every bullet in S12-04's scope (manifest + prompt + age-profiles + topics + per-skill Zod + router wiring + tests). Shape mirrors S10-07's quiz-maker verbatim — same file layout, same loader path, same validator registry pattern.
- Drift (none): spike design-question — "does `experiment-designer` need a separate age-gated materials list?" — resolved in-prompt and in-age-profile without a separate validator dimension. Materials stay age-safe through the prompt constraints + per-age tone curve. One less schema axis to maintain, and materials phrasing stays a content concern (Markdown files) rather than a validator concern (TypeScript).

### S12-05 — `curriculum-architect` shipped (CE epic 67%)

Landed Apr 22 2026 as the second of the three carry-from-S10 CE stories. 6 pts → ✅. Full write-up: `docs/sprint-runs/S12-05-curriculum-architect.md`.

**Files changed (~2,100 LOC total across R2–R5; R1 was spike-only):**

- `src/Backend/src/services/skills/defs/curriculum-architect/manifest.json` — new (11 LOC). `modelHint: "pro"` (capability tier, not provider model name — `SkillManifestSchema` enum is `'flash' | 'pro'`), `temperatureHint: 0.5`, `inputs.requires: ["topic","summary","suggestedStage"]`, `inputs.optional: ["keyConcepts","suggestedCardCount","sourceExcerpt"]`, `ageProfiles: [4,6,8]`, `difficulties: ["easy","medium","hard"]`, `handlesConceptTypes: []` (decomposition runs *before* concept-type dispatch — consumes the raw analyzer topic instead of a conceptType-tagged atom).
- `src/Backend/src/services/skills/defs/curriculum-architect/prompt.md` — new (183 LOC). System block (stage role, Decomposition Contract with 6 invariants spelled out for the LLM, strategy→cardType compatibility matrix, topic-avoid list) + `<!-- user-prompt -->` marker + user block (topic / summary / keyConcepts / suggestedCardCount / sourceExcerpt truncated at 5000 chars).
- `src/Backend/src/services/skills/defs/curriculum-architect/{styles.md, topics.md, age-profiles/{4,6,8}.md, difficulty-curves/{easy,medium,hard}.md}` — new (8 files). Per-age cognitive-load + per-difficulty atom-count curves (easy 3 / medium 4 / hard 5–6) layered as Handlebars partials.
- `src/Backend/src/services/skills/validators/curriculumArchitect.ts` — new. `ConceptDecompositionSchema` as `z.object({atoms, rationale}).strict().superRefine(...)` with 6 invariants: (1) atom-N sequential ids (`atom-1`, `atom-2`, …), (2) strategy↔cardType compat matrix (narrative→story, application→experiment, assessment→quiz, reflection→voice), (3) prerequisite DAG (topologically sortable, no cycles, no references to atoms that don't exist or appear later), (4) card-type diversity (no more than 1 back-to-back same type), (5) lesson shape (3–6 atoms; opener ∈ {narrative, explanation}; closer ∈ {quiz, reflection}), (6) voice ceiling (≤1 `voice` atom per decomposition — `voice-persona` is S12-06 so this ceiling front-loads the invariant even before the downstream skill exists).
- `src/Backend/src/services/skills/validators/index.ts` — +2 LOC. One-line registry append: `'curriculum-architect': curriculumArchitectOutputSchema` in `SKILL_OUTPUT_SCHEMAS` + re-export.
- `src/Backend/src/services/pipeline/decompositionRouter.ts` — new (593 LOC). Single-call router (not per-atom fanout like `skillRouter`) — `routeDecomposition()` state machine. Env-gated via `SKILL_ENGINE_STAGE3` with trimmed + case-folded parsing (default ON; empty string → OFF as ambiguous-safe; `"true"/"1"/"on"/"yes"` ON; `"false"/"0"/"off"` OFF). Transient-error classifier (`isTransient`) re-throws `timeout|econnreset|etimedout|fetch failed|rate limit|429|502|503|504` to outer `runStage` instead of swallowing — same pattern as `skillRouter` but simpler because there's no per-atom partial-success accounting to preserve. Retry-on-Zod-or-parse: pretty-printed error appended to user turn with `"rejected by the output validator"` framing, temperature reduced by 0.1 on the retry attempt, second attempt validates or returns `reason: 'validation-failed'` with both traces. Whitespace-only LLM response treated as non-retryable (`reason: 'empty-response'`) — retrying doesn't fix an upstream that returned nothing. Fixed three latent type errors in `buildOkResult` / `buildFailedResult` where `DecompositionTrace.ageProfileUsed: string` / `difficultyUsed: string` received `SkillPromptMeta`'s `number | undefined` / literal-union — coerce at the assignment site with `String(...)` + `?? 'unknown'` fallback, because the trace is display-ready by design (`'unknown'` is already the documented failure-path fallback).
- `src/Backend/src/services/pipeline/pipelineOrchestrator.ts` — Stage 3 wiring (touched in R4). `runStage3` now calls `routeDecomposition(...)` when the feature flag is on, otherwise falls through to the legacy heuristic decomposer. `DecompositionTrace` threaded into the orchestrator's pipeline-trace payload so the Pipeline tab renders a row preceding the atom rows.
- `src/Backend/tests/curriculumArchitectValidator.test.ts` — new (40 cases). All 6 superRefine invariants with positive + negative fixtures per difficulty bucket (easy 3-atom, medium 4-atom, hard 5–6-atom) + boundary cases (atom-count lower and upper bounds, voice-atom ceiling, prerequisite cycle, cross-difficulty atom-count mismatch).
- `src/Backend/tests/decompositionRouter.test.ts` — new (25 cases, ~500 LOC). Mocked `routeRequest` via vi queue. Happy path (kind=ok, validatorStatus='ok', retryCount=0, atomCount=3, tokens.total=600); call-args verification (`model=claude-sonnet`, `maxTokens=1400`, `routingReason='concept_decomposition'`); prompt threading (topic/title/keyConcepts into user prompt, topicAvoid into system, source-excerpt truncation at 5000 chars); retry-on-Zod success (retry-ok, retryCount=1, tokens=1200, retry user turn contains `"rejected by the output validator"`, retry temperature = firstTemp - 0.1); retry-failed (both attempts invalid → kind=failed, reason='validation-failed', validatorStatus='retry-failed'); JSON-parse retry branch; skill-not-loaded (custom empty registry stub → never calls LLM); missing-required-input (empty topic, empty summary — used `''` instead of `undefined as unknown as string` casts because the router's `!analysis.topic` guard trips equally on empty strings and the cast would silence the type error making `@ts-expect-error` itself complain); transient-error re-throw (timeout, 429, 503 all propagate to outer `runStage`); non-transient captured as `reason: 'llm-error'`; transient-on-retry also re-throws; empty-response treated as single-call not retryable; full feature-flag matrix (unset/true/1/on/yes → ON; false/0/off → OFF; whitespace trimming applied).
- `src/Backend/tests/skillEngine.test.ts` — +2 cases. Boot assertions confirm `curriculum-architect` loads from the real `defs/` tree with `inputs.requires` containing `["topic","summary","suggestedStage"]`, `ageProfiles: [4,6,8]`, `difficulties: ["easy","medium","hard"]`, and `outputSchema` defined on the `Skill` interface.

**Architectural decisions (condensed — full "why X over Y" log in run summary):**

1. **Single-call router, not per-atom fanout.** Stage 3 produces a structured sequence (atoms + rationale) that the rest of the pipeline consumes — parallelizing it across atoms is incoherent because atom-N's strategy depends on atom-(N-1)'s closure. `routeDecomposition()` is synchronous top-to-bottom; `skillRouter`'s per-atom fanout pattern is wrong for this stage.
2. **Env-gate defaults ON with ambiguous-safe OFF.** `SKILL_ENGINE_STAGE3` unset → ON (the feature is the default path, not opt-in). Empty string → OFF (parsing-ambiguous input should fail safe, not silently activate). `"true"/"1"/"on"/"yes"` map ON; `"false"/"0"/"off"` map OFF. Whitespace trimmed + case-folded. Locked in the router test's feature-flag matrix.
3. **Transient classifier mirrors skillRouter's, re-throws instead of swallows.** `timeout|econnreset|etimedout|fetch failed|rate limit|429|502|503|504` — same substring list. Re-throw because the outer `runStage` already has retry + circuit-breaker semantics; swallowing here means Stage 3 failures become silent Stage 4 blanks.
4. **Retry-on-Zod reduces temperature by exactly 0.1.** Not a bigger nudge (over-correction) and not 0 (temperature=0 produces repetitive noise on failed retries). 0.1 is the minimum-viable perturbation. Matches the retry pattern in `skillRouter`'s per-atom retry.
5. **Whitespace-only response is non-retryable.** If the LLM returned nothing, retrying with a "corrective" user turn produces garbage on average — the failure is upstream (wrong model, wrong max-tokens, network truncation), not a prompt-quality issue. Fail fast with `reason: 'empty-response'` so the operator can diagnose the root cause.
6. **Six superRefine invariants, not a lone "atoms.length >= 3" check.** (a) sequence ids (`atom-1` onward — enables retry prompts to reference specific atoms by id), (b) strategy↔cardType compat (narrative→story, etc. — a "narrative quiz atom" is malformed), (c) prerequisite DAG (no cycles, no forward refs), (d) card-type diversity (no back-to-back same type — pedagogical variety is a hard constraint), (e) lesson shape (opener/closer semantics — a lesson that opens with a quiz is malformed), (f) voice ceiling (≤1 per decomposition — prevents the LLM from stacking 3 voice atoms because "voice is engaging"). Six invariants feel like overkill until one fails — then each one's rejection message tells the retry prompt exactly what to fix.
7. **`modelHint: "pro"`, NOT `"sonnet"`.** `SkillManifestSchema.modelHint` is a capability-tier enum (`'flash' | 'pro'`), not a provider model name. Actual model routing uses `routeRequest`'s `model: 'claude-sonnet'` param (hardcoded in the router). The initial manifest conflated the two; caught by `SkillManifestSchema.parse` on registry boot, failing 3 pre-existing `skillEngine.test.ts` suites until the fix landed.
8. **Trace `ageProfileUsed` / `difficultyUsed` coerce to string at assignment, not widen the interface.** `DecompositionTrace` declares these as bare `string` (with `'unknown'` documented-fallback on failure); `SkillPromptMeta` exposes them as `number | undefined` and literal-union. Coercion at the assignment site keeps the trace display-ready without leaking the source-type shape to every Pipeline-tab consumer.

**Validation (sandbox ✅):**

- `tests/curriculumArchitectValidator.test.ts` — 40/40 green. All 6 superRefine invariants with positive + negative fixtures per difficulty.
- `tests/decompositionRouter.test.ts` — 25/25 green. Full state machine including happy, retry-ok, retry-failed, JSON-parse retry, skill-not-loaded, missing-required-input, transient re-throw (3 cases), non-transient llm-error, empty-response, feature-flag matrix (7 cases).
- `tests/skillEngine.test.ts` — 46/46 green including the 2 new curriculum-architect boot assertions.
- Full backend suite: 763 pass / 1 carry-in debt fail (pre-existing `sprint6.test.ts` `SPARKY_SYSTEM_PROMPT` — same S11-09/S12-08 carry-in as S12-04; resolves when RN epic closes this sprint). Zero S12-05 regression.
- `tsc --noEmit` filtered for `decompositionRouter` returned zero new errors — the three latent type errors that surfaced on R5 are resolved.

**Validation left for bang's Mac (🟡):**

- Dev Console **Skills** tab dry-run render of `curriculum-architect` with `ageYears` × `difficultyOffset` controls — walk the 8-cell matrix and confirm `meta.ageProfileUsed` / `meta.difficultyUsed` tags match expectations.
- Dev Console **Pipeline** tab regression — confirm a Stage-3-decomposition row appears preceding the atom rows, with `skillEngineUsed: true` + `validator: ✓ attached` + `validatorStatus: ok` (or `retry-ok`).
- End-to-end authoring smoke — draft a lesson whose `curriculum-architect` output feeds `storyWriter` / `quizMaker` / `experimentDesigner` downstream. Confirm atom-N sequence survives through to final card rendering.
- Feature-flag toggle: set `SKILL_ENGINE_STAGE3=false` and confirm the legacy heuristic decomposer kicks in (skill-engine path bypassed, same trace fields filled with `skipped`).

**Prerequisites bang must run on his Mac:**

```bash
cd ~/Code/Novai/src/Backend
npm run build                                              # clean tsc
npm run test -- tests/curriculumArchitectValidator tests/decompositionRouter tests/skillEngine
# expect: 111 assertions green across the three suites (40 + 25 + 46)
SKILL_ENGINE_STAGE3=true npm run dev                       # boot backend on 3000 with Stage 3 ON
open http://localhost:3000/dev-console/skills              # walk the curriculum-architect matrix
open http://localhost:3000/dev-console/pipeline            # regression-check Stage-3 row + atom rows
# Toggle OFF to confirm legacy fallback still works:
SKILL_ENGINE_STAGE3=false npm run dev
# Pipeline tab row should read 'skipped' with reason 'stage-3-disabled-by-env'
```

**In-plan vs drift:**

- In-plan: R1 (map) / R2 (defs) / R3 (validator) / R4 (pipeline wire) / R5 (tests) / R6 (tracker + run summary + index). Shape mirrors S12-04 verbatim at the def-bundle layer; Stage 3 single-call router replaces S12-04's per-atom fanout at the router layer.
- Drift (caught + fixed in R5): three latent type errors in `decompositionRouter.ts` lines 555/556/586 — `DecompositionTrace`'s `ageProfileUsed` / `difficultyUsed` declared as bare `string` but `SkillPromptMeta` source fields are `number | undefined` / literal-union-or-undefined. `tsc --noEmit` surfaced them only when the new test file forced a full backend type-check; fixed via `String(...)` + `?? 'unknown'` coercion at the assignment sites, keeping the interface's display-ready intent intact.
- Drift (caught + fixed in R5): `modelHint: "sonnet"` in the curriculum-architect manifest rejected by `SkillManifestSchema` (enum is capability tier `'flash' | 'pro'`). Mistake was conflating the manifest hint with the `routeRequest` provider-model param. Fixed by flipping to `"pro"` — the correct capability tier for a reasoning-heavy structured-decomposition skill.

### S12-06 — `voice-persona` shipped (CE epic 100% — 5-modality skill-engine complete)

Landed Apr 23 2026 as the third and last carry-from-S10 CE-epic story. 6 pts → ✅. **CE epic closes at 18/18 (100%)**; Sprint 12 Total flips to 26/60 (43%). Full write-up: `docs/sprint-runs/S12-06-voice-persona.md`.

**Files changed (~1,900 LOC total):**

- `src/Backend/src/services/skills/defs/voice-persona/manifest.json` — new (15 LOC). `modelHint: "flash"`, `temperatureHint: 0.6` (slightly higher than experiment's 0.5 because voice needs stylistic latitude within the Dashy-voice gates), `inputs.requires: ["concept","conceptType"]`, `inputs.optional: ["topic","targetLessonId","lastStoryExcerpt"]`, `ageProfiles: [4,6,8]`, `difficulties: ["easy","medium","hard"]`, `handlesConceptTypes: ["vocabulary","factual","abstract"]` — narrower than experiment-designer (no process / comparison / causeEffect) because voice cards can't scaffold diagrams or multi-step reasoning.
- `src/Backend/src/services/skills/defs/voice-persona/prompt.md` — new (135 LOC). Dashy's "five non-negotiables" baked into the system prompt (first-person always / curiosity-framed / no "you will"/"you must"/"you should" / celebration is shared not granted / correction is always soft), output contract explicit about the three Dashy-voiced lines (`promptText` + `celebration` + `retryHint`) and the speech-recognition whitelist (`expectedResponses`).
- `src/Backend/src/services/skills/defs/voice-persona/styles.md` — new (70 LOC). Three voice shapes: **Wondering Aloud** (default — Dashy admits uncertainty and asks for help), **Echo and Read** (phonics drill — Dashy says a new word and asks the child to repeat), **Call and Response** (pattern recall — Dashy starts a sequence and the child completes).
- `src/Backend/src/services/skills/defs/voice-persona/topics.md` — new (60 LOC). Good-fit / bad-fit taxonomy + guidance on `expectedResponses` whitelist design (include the natural phrasings + one common mispronunciation; exclude obvious-wrong and filler-only).
- `src/Backend/src/services/skills/defs/voice-persona/age-profiles/{4,6,8}.md` — new (3 files). Per-age Dashy-voice calibration: age 4 = 1-word/short-phrase answers + short uncertainty prompts + re-state hint on retry; age 6 = mild vocabulary stretch + context clue + narrower clue on retry; age 8 = compound terms + 5-syllable science words + producing the term from a definition-only clue.
- `src/Backend/src/services/skills/defs/voice-persona/difficulty-curves/{easy,medium,hard}.md` — new (3 files). Easy = 2–3 whitelist entries + ≤80-char prompt + recognition-level (no phonetic challenge); medium = 3–4 entries + ≤110-char prompt + application-level + one mild phonetic stretch; hard = 4–5 entries + ≤180-char prompt + transfer-level + produce technical term from definition-only clue.
- `src/Backend/src/services/skills/validators/voicePersona.ts` — new. Strict `.object(...).strict().superRefine(...)` with 10 layered invariants encoding the Dashy-voice contract.
- `src/Backend/src/services/skills/validators/index.ts` — +2 LOC. One-line registry append.
- `src/Backend/src/services/pipeline/skillRouter.ts` — +32 LOC across 4 touchpoints. `SKILL_MAX_TOKENS['voice-persona'] = 700`, `SKILL_TO_MODEL['voice-persona'] = 'claude-sonnet'`, `buildSkillInputs('voice-persona', ...)`, `buildCardFromSkillOutput('voice-persona', ...)` emits `type: 'voice'` with camelCase content fields + `voiceScript = promptText + ' ' + celebration`.
- `src/Backend/src/services/skills/types.ts` — +1 LOC. `CARD_TYPE_TO_SKILL.voice: 'voice-persona'`.
- `src/Backend/src/services/pipeline/cardGenerator.ts` — +26 LOC. `CardContent` interface expanded with 5 voice-mode fields (`promptText?`, `expectedResponses?`, `celebration?`, `retryHint?`, `phonetics?`) matching iOS `Card.CardContent` shape.
- `src/Backend/tests/voicePersonaValidator.test.ts` — new (~580 LOC, 51 cases). Every `superRefine` invariant with positive + negative fixtures across all three difficulty tiers.
- `src/Backend/tests/voicePersonaRouter.test.ts` — new (~350 LOC, 7 cases). Router dispatch, voiceScript assembly, Sonnet pick, 700-token ceiling, analysis.topic + lastStoryExcerpt threading, retry-on-Zod happy + retry-failed paths.
- `src/Backend/tests/skillEngine.test.ts` — +45 LOC (2 new boot assertions).

**Architectural decisions (condensed — full "why X over Y" log in run summary):**

1. **Dashy-voice gates enforced in the validator, not just the prompt.** Prompts are advisory; validators are contracts. Six of the 10 superRefine invariants encode Dashy's character (first-person required × 3 lines; banned voice-of-god phrases × 3 lines). If these drift in S13+, the validator rejects the LLM output before it reaches the iPad — Dashy's voice is now a structurally-enforced contract, not a content guideline. This is the S12-17 voice-consistency audit's single line of defense encoded directly into the schema.
2. **`temperatureHint: 0.6` (not 0.5 like experiment-designer).** Voice is more stylistic — the same concept can fire Wondering-Aloud / Echo-and-Read / Call-and-Response shapes with equally-valid Dashy voice. 0.5 over-homogenizes; 0.6 preserves stylistic variety while staying coherent. Not 0.7 because Dashy's voice has hard non-negotiables (first-person only, no voice-of-god) that want lower sampling.
3. **`voiceScript = promptText + celebration`, NOT + retryHint.** The retryHint only fires on a miss — including it in the default TTS flow would have Dashy read the retry line every card even when the kid got it right on the first try. Retry is on-demand from `content.retryHint`; iPad reads it only on a speech-recognition miss. Same contract shape as experiment-designer's `voiceScript = instructions + conceptSummary` (always-read parts only).
4. **`expectedResponses` cardinality 1–5, not 3 fixed.** 1 acceptable for phonics echo (just the target word); 5 covers the complex hard-difficulty case with technical term + casual phrasing + plural + mispronunciation + short-form. Wider than a fixed 3 because over-restricting cardinality forces the LLM to pad whitelists with near-dupes (which then fail the case-insensitive uniqueness check — compounding error).
5. **`phonetics` optional + regex-shaped.** `/^[a-z]+(-[a-z]+)*( [a-z]+(-[a-z]+)*)*$/` accepts `pho-to-syn-the-sis` (single kebab-word) and `warm blood-ed` (space-separated multi-word). Optional because only 4+ syllable technical words need TTS guidance; short common words don't. The regex is strict enough to reject free-form phonetic spellings (which would confuse TTS) but permissive enough to cover the common cases.
6. **Banned-phrases list sourced from the "five non-negotiables," not from content sensibility.** "you will" / "you must" / "you should" were chosen because they're the exact phrasings that make Dashy sound like an adult watching the app (voice-of-god). "you got" / "good job" are the most-common AI-generated celebration phrases that fail the shared-not-granted rule. "wrong" / "incorrect" / "no," fail the soft-reset rule. Not exhaustive — S13+ may catch new drift patterns and add to the banlist. The current list is what S11-13's Dashy chat voice + S12-17's planned audit both flag.
7. **`handlesConceptTypes` narrower than experiment-designer.** Includes `vocabulary` + `factual` + `abstract`; excludes `process` + `comparison` + `causeEffect`. Voice-mode answers are single-point (one word / one short phrase) — multi-step processes and comparisons produce open-ended spoken responses the matcher can't whitelist. The narrower handlesConceptTypes tells the Stage-3 decomposer / orchestrator to route those concept types to experiment-designer or story-writer instead.
8. **CardContent interface expanded, not a separate VoiceContent shape.** Adding 5 optional fields to the shared `CardContent` keeps the iOS transformer boundary shape stable (one decoder handles all card types; the decoder picks fields by card type). Alternative considered: separate `CardContent.voice` union variant. Rejected — the rest of the backend treats `CardContent` as a flat optional-fields bag and refactoring to discriminated union would ripple through every card-type branch.

**Validation (sandbox ✅):**

- `tests/voicePersonaValidator.test.ts` — 51/51 green. All 10 superRefine invariants with positive + negative fixtures per difficulty + base bounds.
- `tests/voicePersonaRouter.test.ts` — 7/7 green. Router dispatch, GeneratedCard shape, voiceScript assembly, Sonnet model pick, 700-token ceiling, retry-on-Zod happy + retry-failed.
- `tests/skillEngine.test.ts` — 48/48 green including the 2 new voice-persona boot assertions.
- Full backend suite: **823 pass / 1 carry-in debt fail** (pre-existing `sprint6.test.ts` `SPARKY_SYSTEM_PROMPT` — same S11-09/S12-08 RN-epic carry-in; resolves when that epic closes this sprint). +60 new green assertions over the S12-05 baseline (763 pass).
- `tsc --noEmit` zero new errors — baseline 51 pre-existing errors held constant.

**Validation left for bang's Mac (🟡):**

- Dev Console **Skills** tab dry-run render of `voice-persona` with `ageYears` × `difficultyOffset` controls — walk the 8-cell matrix and confirm `meta.ageProfileUsed` / `meta.difficultyUsed` tags match expectations. Listen to the TTS of the `promptText` + `celebration` + `retryHint` lines in Dashy's voice to confirm the character reads coherently.
- Dev Console **Pipeline** tab regression — author a lesson whose decomposition includes a voice atom. Confirm the atom pill shows `skillEngineUsed: true`, `skill: voice-persona`, `validator: ✓ attached`, `validatorStatus: ok`. Previously fell through to the legacy inline voice branch.
- End-to-end iPad render — the voice card's `promptText` should speak via TTS when the card appears; the child's spoken response should match against `expectedResponses`; correct match plays `celebration` via TTS; miss plays `retryHint`. No iOS changes were required this run — the Swift `VoiceCardView` decoder already expected `card.content.promptText` + `card.content.expectedResponses` which is exactly what the new `buildCardFromSkillOutput` emits.
- S12-17 Dashy voice-consistency audit — the voice-persona prompt is now the single-sourced-truth for Dashy's character. S12-17 audits whether `DashyView` chat (S11-13), `meetDashyPage` onboarding (S11-17), and `DashyHintSheet` all match this prompt's tone + lexicon + correction patterns.

**Prerequisites bang must run on his Mac:**

```bash
cd ~/Code/Novai/src/Backend
npm run build                                                    # clean tsc (51 pre-existing; 0 new)
npm run test -- tests/voicePersonaValidator tests/voicePersonaRouter tests/skillEngine
# expect: 106 assertions green across the three suites (51 + 7 + 48)
npm run dev                                                      # boot backend — registry now loads FOUR skills
open http://localhost:3000/dev-console/skills                    # dry-run render voice-persona
open http://localhost:3000/dev-console/pipeline                  # regression-check voice-atom pill shows skillEngineUsed=true
```

**In-plan vs drift:**

- In-plan: every bullet in S12-06's scope (manifest + prompt + age-profiles + topics + per-skill Zod + router wiring + CardContent expansion + tests). Shape mirrors S12-04 experiment-designer verbatim at the def-bundle layer.
- Drift (caught + fixed in R5): Handlebars partial reference `{{> styles}}` in prompt.md failed because the registry registers `styles.md` as `styleExamples` — name-drift inherited from the S10-R4 registry.ts decision. Fixed by aligning to the existing convention (`{{> styleExamples}}` matches experiment-designer's prompt.md pattern).
- Drift (caught + fixed in R5): Handlebars helper `{{truncate inputs.lastStoryExcerpt 400}}` doesn't exist in the engine — experiment-designer's prompt.md uses the excerpt raw because the pipelineOrchestrator truncates upstream before reaching the skill. Fixed by removing the helper call. Both drifts are content-layer mistakes (template references to non-existent names) rather than architectural issues — they only surfaced when tests ran against the real defs tree, not when the prompt was being drafted in isolation.

---

### CE Epic closed — 5-modality skill-engine complete (18/18 · 100%)

Sprint 12 Day 3: the last carry-from-S10 content-engine story landed. The skill-engine now covers **all five card types** — `story-writer` (S10-R4) + `quiz-maker` (S10-07) handling the Stage-4 base cases; `experiment-designer` (S12-04) for drag-and-drop sorts; `curriculum-architect` (S12-05) running at Stage 3 for decomposition; `voice-persona` (S12-06) for Dashy-voiced spoken-answer cards. Every card rendered on the iPad flipbook, and every atom produced by the decomposer, now routes through the skill-engine and gets atomic `ok / retry-ok / retry-failed / skipped` Pipeline-tab telemetry.

**All three S10-12 legacy-fallback paths are now dead-coded:**

- `generateStoryCard` — retired when S10-R4 landed story-writer.
- `generateQuizCard` — retired when S10-07 landed quiz-maker.
- `generateExperimentCard` — retired when S12-04 landed experiment-designer.
- Legacy heuristic decomposer — retired when S12-05 landed curriculum-architect (env-gated; fallback remains for `SKILL_ENGINE_STAGE3=false` A/B).
- Inline voice branch at `cardGenerator.ts:432-438` — retired this run.

The legacy paths stay in the codebase as *dead code* for two sprints of safety margin (S13+ migration stability); they can be physically removed in S14 once the skill-engine path has proven stable under real touch-test load from S12-10's seed lessons + S12-11's kid demo.

**Cross-cutting benefits realized:**

- Every card type now supports per-skill Zod retry-on-validation (closes the S9-07 carried debt originally identified two sprints ago).
- The Dev Console Pipeline tab now shows full `skillEngineUsed: true` telemetry for every atom of every card type — complete observability over the content pipeline.
- Dashy's voice has a single-sourced-truth prompt (voice-persona/prompt.md) that S12-17 will audit against the Dashy chat + onboarding + hint surfaces.
- S12-09's Author Lesson tab can now pre-commit to the 5-modality matrix without reserving fallback paths for "coming soon" card types.

**Next stop (Week 2):** S12-07 + S12-08 close the RN epic (Sparky→Dashy coordinated rename), then S12-09 lands the Dev Console authoring surface, S12-10 seeds three real lessons, S12-11 is the touch test with bang's kid. The CE-epic close unblocks the MVP epic cleanly — every atom of every seed lesson will light up the Pipeline tab in skill-engine green.

### S12-07/08 — RN Epic closed · "Sparky is a dead word"

Landed Apr 23 2026 as a single coordinated commit range per the tracker's explicit plan (both stories flip together because the route path + Zod discriminant + iOS wire literal only work if they land atomically). 5 pts → ✅. **RN epic closes at 5/5 (100%)**; Sprint 12 Total flips to 31/60 (52%). Full write-up: `docs/sprint-runs/S12-07-08-sparky-dashy-rename.md`.

**Scope beyond the three documented carve-outs** — R1 mapping surfaced 5 additional Sparky footprint categories that the S11-09 carve-out documentation didn't anticipate. Every one flipped in this run:

- `services/sparky/` directory + `routes/sparky.ts` route file (git mv'd).
- 4 exported TS identifiers: `SPARKY_SYSTEM_PROMPT`, `SparkyResponse`, `processSparkyMessage`, + route handler `sparkyRoutes`.
- Route path `/sparky/chat` → `/dashy/chat` in Fastify registration + iOS `Endpoint.dashyChat()` factory.
- 3 iOS wire literals: `DashyViewModel.swift:263` (`role: "dashy"` assignment), `DashyView.swift:222` (`if message.role == "dashy"` discriminant), `DashyViewModel.swift:32` (field comment).
- Prisma `SparkyConversation` model → `DashyConversation`, `@@map("sparky_conversations")` → `@@map("dashy_conversations")`, child-profile relation field `sparkyConversations` → `dashyConversations`. Migration queued for `prisma migrate dev` on bang's Mac.
- `JSON_STRING_FIELDS.sparkyConversation` → `.dashyConversation` in `db/client.ts` middleware.
- `prisma.sparkyConversation.findMany` / `.updateMany` in `routes/dataRights.ts` (data-rights export + anonymization flows).
- `sparkyRateLimiter` → `dashyRateLimiter` export + the `/sparky/chat` comment hint in `middleware/rateLimiter.ts`.
- `sparky_voice_chat` feature flag key → `dashy_voice_chat` + metadata description in `services/featureFlags.ts`.
- `'sparky_chat'` cost-tracker feature-string literal → `'dashy_chat'` in `services/llm/costTracker.ts` + the `feature` comment in `schema.prisma`.
- 8 user-facing lesson strings in `db/seedCurriculum.ts` ("Talk to Sparky!" / "Sparky tries to answer!" / etc.) — these are what a touch-test kid would read in the seeded curriculum. All 8 flipped via `sed -i 's/Sparky/Dashy/g'` in one pass.
- iOS orthogonals flipped per the DoD's zero-grep rule: `VoiceStyle.sparky` enum case → `.dashy` in `NovaVoice/SpeechSynthesizer.swift` (5 touchpoints across the enum + `getVoice`/`getSpeechRate`/`getPitchMultiplier` switches), `DeepLinkDestination.sparky` → `.dashy` in `NovaCompanion/DeepLinkHandler.swift` (1 enum case + 2 `return .sparky` sites + 2 `case "sparky":` / `path.contains("sparky")` routing sites), `NovaPalette.swift:108` doc comment `/// Dashy (née Sparky) purple` → `/// Dashy purple`.
- Backend tests: `tests/sprint6.test.ts` (import block + 3 describe/section headers + 11 `processSparkyMessage` calls + `/api/v1/sparky/chat` URL + `'Hello Sparky!'` transcript fixtures + the critical `SPARKY_SYSTEM_PROMPT.toContain('Sparky')` assertion → `DASHY_SYSTEM_PROMPT.toContain('Dashy')`). `tests/sprint7.test.ts` (`sparkyRateLimiter` import + `sparky_voice_chat` feature flag references × 6 sites).

**The failing test retired for real this time.** `sprint6.test.ts:28` has been red for **two sprints** — it asserted `SPARKY_SYSTEM_PROMPT.toContain('Sparky')` against a prompt whose content was already flipped to "You are Dashy" in S11-09, intentionally left red as a Definition-of-Done hook for S12's coordinated rename. With both the constant name and the assertion target flipped in lockstep, the test is now **consistently green**.

**Architectural decisions (the "why X over Y" log, condensed — full version in run summary):**

1. **One coordinated commit range for both stories — no wire-compat shim.** bang owns both client (iPad) and server; the only live client is his own iPad on his LAN; a dual-path shim that accepts both `"sparky"` and `"dashy"` roles would be code we'd delete in S13 anyway. Coordinated deploy is cheaper than shim maintenance. Both stories flip atomically — no in-flight skew possible.
2. **DoD-strict sweep scope: zero-grep rule.** Initial carve-out documentation (S11-09) listed 3 items: filepath, route, wire literal. R1 mapping found **8 additional categories** (Prisma model/table, middleware registration, rate limiter export, feature flag key, cost tracker feature, data rights call sites, seed curriculum strings, iOS voice-style enum). Scope chose to include all of them because the tracker's explicit DoD says `grep -ri "sparky" --include="*.{swift,ts,js,md}"` returns zero hits outside `docs/sprint-runs/`. Stopping at 3 would have left the DoD unsatisfied; going all-in cost ~20 extra minutes of mechanical renaming.
3. **Test assertion flipped alongside the constant rename — not one then the other.** The `SPARKY_SYSTEM_PROMPT.toContain('Sparky')` assertion and the `SPARKY_SYSTEM_PROMPT` identifier are renamed in the same `sed -i` pass. Flipping just the identifier would leave the assertion searching for the now-wrong word. Flipping just the assertion would leave the test importing a now-nonexistent identifier. Both-in-lockstep is the only state where the test passes.
4. **Seed curriculum content flipped — not just code identifiers.** 8 user-facing strings in `db/seedCurriculum.ts` mentioned "Sparky" in lesson body text. These are what a touch-test child would read aloud / hear via TTS in S12-11. Leaving them would re-introduce Sparky to the child at exactly the moment bang's DoD is trying to retire it. Cost: zero (one sed pass); benefit: touch-test consistency.
5. **`VoiceStyle.sparky` flipped to `.dashy` even though it's orthogonal to character identity.** The enum is a voice tone/speed profile (`0.45` rate + `1.2` pitch = kid-friendly energetic voice). Strictly the rename isn't required — this is a TTS implementation detail, not the character name. But per the DoD's zero-grep rule, orthogonal references still count. Flipped to `.dashy` to satisfy the sweep; semantic meaning preserved (Dashy's voice style rather than Sparky's voice style).
6. **Prisma migration queued, not run in-sandbox.** Sandbox can't safely mutate bang's Mac-side dev DB. The schema change is the source of truth; `prisma migrate dev` on bang's Mac generates the migration SQL renaming the table and regenerates the Prisma client. If any existing `sparky_conversations` rows exist in a dev database, the migration preserves them via a `RENAME TABLE` DDL — no data loss risk. Mac-runbook step explicitly calls out the migrate command.
7. **Historical-rename comments removed from active source per strict DoD reading.** Two references remained in active `.swift`/`.ts` files explaining "flipped from sparky in S12-07/08" — useful context but technically grep-matching. Removed to satisfy DoD literally; the rename history now lives in this tracker + `docs/sprint-runs/S12-07-08-sparky-dashy-rename.md`, which are the canonical history artifacts.

**Validation (sandbox ✅):**

- Full backend suite: **823 pass / 1 flaky fail** — net neutral vs. the S12-06 baseline but the red cell is now different in *kind*. The S11-09 `SPARKY_SYSTEM_PROMPT.toContain('Sparky')` carry-in is **retired permanently** — consistently green. The lone remaining red cell is one of sprint6.test.ts's LLM-calling tests which occasionally exceeds the 5s default vitest timeout under real OpenAI API latency (flaky, not rename-related — different specific test fails on each run; all pass on re-run). Pre-existing flakiness, not S12-07/08 regression.
- `grep -ri '[Ss]parky|SPARKY' --include='*.{ts,swift,prisma,js,tsx}'` **zero hits** across the active codebase. Historical references remain only in `docs/sprint-runs/*.md` (the historical tracker notes that the DoD explicitly exempts).
- `tsc --noEmit` zero new errors — baseline 51 pre-existing errors held constant; zero S12-07/08-introduced type issues.

**Validation left for bang's Mac (🟡):**

- `prisma migrate dev --name rename_sparky_to_dashy_conversations` — generates the SQL migration renaming the table. Verify the migration file looks like `ALTER TABLE sparky_conversations RENAME TO dashy_conversations;` before applying. If the dev DB has test rows, confirm they survive the rename.
- Boot the backend with the renamed route — `npm run dev` — then hit `POST /api/v1/dashy/chat` (was `/api/v1/sparky/chat`). Expect 200 + a DashyResponse JSON. Confirm `404` on the OLD path `/api/v1/sparky/chat` (no backward-compat shim by design).
- iPad regression — build NovaKids, open DashyView, send a chat message. Confirm the paper-and-ink Dashy bubble still renders (the discriminant at DashyView.swift:222 now matches the new `"dashy"` wire literal from the backend response).
- Dev Console **Feature Flags** tab — the `dashy_voice_chat` flag should appear in the list (was `sparky_voice_chat`); toggle it off + on to confirm the flag registry picks up the key rename.
- iPad speech synthesis — play any voice-narration card. Confirm the TTS voice tone/speed matches the old "Sparky" profile (the `.dashy` enum case has the same `0.45` rate + `1.2` pitch multiplier — pure rename, not a tuning change).

**Prerequisites bang must run on his Mac:**

```bash
cd ~/Code/Novai/src/Backend
npm run build                                                     # clean tsc
npx prisma migrate dev --name rename_sparky_to_dashy_conversations
# expect: ALTER TABLE sparky_conversations RENAME TO dashy_conversations;
npm run test -- tests/sprint6 tests/sprint7
# expect: sprint6.test.ts 69/69 green (SPARKY_SYSTEM_PROMPT carry-in retired);
#         sprint7.test.ts all green (dashy_voice_chat flag + dashyRateLimiter refs updated)
npm run dev                                                       # boot backend
curl -s -XPOST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     http://localhost:3000/api/v1/dashy/chat \
     -d '{"childId":"<uuid>","transcript":"Hi!"}' | jq '.response'
# expect: Dashy-voiced reply
# Then open Xcode, build NovaKids, connect iPad on LAN, open DashyView, chat.
```

**In-plan vs drift:**

- In-plan: the 3 documented carve-outs (filepath + route + wire literal) + the sprint6.test.ts assertion flip that was explicitly the DoD hook.
- Drift (in-scope per DoD): 8 additional categories surfaced by R1 mapping (Prisma model, db/client middleware, rate limiter, feature flag, cost tracker, data rights, seed curriculum, iOS voice enum + deep link). All flipped because the DoD's zero-grep rule is non-negotiable and ignoring them would have left the sprint open on the "Sparky is a dead word" milestone.
- Drift (content): 8 Sparky strings in seed curriculum lesson content. Not identifier-level but user-facing — a touch-test kid would have read "Talk to Sparky!" in body text if not flipped. Sed-replaced in one pass.

---

### S12-10 — Content Browser + touch-test unblocks (scope-absorbed Run 2)

Landed Apr 23 2026 as a 5-commit run (`d5d375b` → `2a9df8c`) between the S12-10 Run 1 sandbox-prep commit (`74932ba`) and the first live-seed attempt. Story stays 🟡 — **1/3 lessons green (Sky) with Rainbow + Planet awaiting re-seed post-concept-fix** — but all systemic blockers are cleared. Full write-up: `docs/sprint-runs/S12-10-content-browser-and-unblocks.md`.

**What bang actually asked for vs. what this run delivered:**

The original S12-10 scope was narrow: run 3 URLs through the Author tab, capture screenshots, confirm zero skipped / retry-failed atoms. What actually happened is a multi-layer unblock — because the first live-seed attempt surfaced three latent hazards that no sandbox test had exercised, plus bang asked mid-run for the ability to cycle through past lessons in the Pipeline tab. All four pieces landed here under the S12-10 story rather than being split into new stories because they're all debt retired to make S12-10's DoD achievable.

**Five commits, in order:**

1. `d5d375b` fix(ios): Xcode 26 / Swift 6.2 strict-concurrency build unblock — 3 files / ~12 LOC. FlipbookHeader `.video` case added to two switches (auto-synthesized exhaustiveness now hard-errors under 6.2); TrophyRoomViewModel `childId` captured to local before `async let` fan-out (MainActor isolation leak into off-actor closure); DashySpeechBubble `SpeechBubbleTailSide` enum got `: Sendable` conformance (zero-cost auto-synth). NovaKids now builds clean on `iPad Pro 13-inch (M5)` simulator destination.
2. `c17b6d4` fix(s12-10): concept atoms skip + story/concept iOS field-name drift — 8 files / ~280 LOC. `CARD_TYPE_TO_SKILL.concept: 'story-writer'` mapping added; `buildCardFromSkillOutput` branches on `atom.recommendedCardType` to emit `type: 'concept'` (content.explanation + text back-fill) or `type: 'story'` (content.narrativeText + text back-fill); `normalizeCard` double-writes canonical iOS field + legacy `content.text` back-fill so historical cards keep rendering; 5 tests updated (`tests/skillRouter.test.ts` + `tests/pipelineSkillIntegration.test.ts`) to exercise the defensive unmapped-cardType guard via synthetic `'unmapped-future-type' as unknown as 'story'` cast, preserving coverage against future unknown-cardType scenarios.
3. `606610c` fix(s12-10): pipeline stage timeout bump — 1 file / 17 LOC. `stageTimeoutMs: 45_000 → 120_000` and `pipelineTimeoutMs: 120_000 → 300_000` in `pipelineOrchestrator.ts`. Post-concept-fix, all atoms route through real LLM calls (previously ~3/6 per decomposition were skipped instantly). 6 serial × 5–10s = 30–60s baseline, needs headroom for retry-on-Zod. Parallelization (Promise.all over atom generation) logged as the structural fix for S13+ after rate-limit quota audit.
4. `7d01628` feat(s12-10): Content Browser — paths/lessons viewer in Pipeline tab — 2 files / 319 LOC. Three-level layout inside the existing Skill Engine container (path rail → lesson list → skill trace). External-driver auto-sync (Author tab Jump-to-Pipeline, console trick, in-page URL Ingest+Generate) via `syncBrowserToCurrentLesson()` hook called inside `refreshSkillTrace()` before trace re-renders. Orphan bucket with dashed-border styling for pathId-null lessons. `GET /lessons` select expanded with `pathId` + `_count: { cards }` aggregate, unwrapped to flat `cardCount` on the wire response.
5. `2a9df8c` fix(s12-10): Content Browser lesson fetch cap — 1 file / 1 char. `?limit=200 → ?limit=100` because `listLessonsQuerySchema` caps `limit.max(100)`. Browser was getting Zod 400 + never populating. Follow-up options (bump schema for dev-only paths, or paginate client-side) logged but deferred.

**Architectural decisions (condensed — full version in run summary):**

1. **Layer the unblocks before building the Content Browser — not parallel.** Each layer validated before the next starts. Clean bisect surface if a regression surfaces during Rainbow + Planet re-seeds.
2. **`concept → story-writer` via same skill + branching output, not a new `concept-writer` skill.** Prompts/age-profiles/styles/topics are identical between story and concept; the only difference is downstream card shape. 5-line branch in `buildCardFromSkillOutput` vs. 10 duplicated def files.
3. **Double-write canonical + back-fill fields, no migration.** New cards get both `narrativeText`/`explanation` (iOS canonical) and `text` (pre-S10 back-fill); historical cards with only `text` still render via back-fill. Zero schema churn, zero deprecation window.
4. **Timeout bump, defer parallelization.** 120s covers worst-case serial path with headroom. Parallel atom generation is the structural fix but needs rate-limit quota check first.
5. **Content Browser inside existing Pipeline-tab container — not a new tab.** Bang explicit: "I don't want another UI page." Honored — `.panel.full` container now carries 3-level layout.
6. **Sync-browser-on-external-driver, not just on click.** `refreshSkillTrace()` calls `syncBrowserToCurrentLesson()` before re-render so any surface that sets `currentLessonId` gets auto-highlight for free.
7. **Unwrap Prisma `_count.cards` → flat `cardCount` at wire.** Client stays clean; ORM-specific aggregate shape doesn't leak.
8. **Orphan `(unassigned)` bucket with dashed border.** Legacy/manual-insert no-pathId rows stay browsable; hiding data from dev console is wrong default.

**Validation (sandbox ✅):**

- Backend: 834/834 pass held across all 5 commits. Zero regressions introduced.
- `tsc --noEmit`: zero new errors — baseline 51 pre-existing held constant.
- Concept-routing + defensive-guard tests green (5 updated tests).

**Validation left for bang's Mac (🟡):**

```bash
cd ~/Projects/Novai/src/Backend && git pull && npm test -- tests/skillRouter tests/pipelineSkillIntegration
# expect: green (5 updated tests for concept routing)
npm run dev
cd ~/Projects/Novai/src
xcodebuild -workspace Nova.xcworkspace -scheme NovaKids \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
# expect: BUILD SUCCEEDED (3 Xcode 26 fixes hold)

# In browser: open http://localhost:3000/dev/dev-pipeline.html#pipeline
# expect: Content Browser populates with paths + lessons, click path chip to filter,
#         click lesson row to load skill trace below

# Re-seed Rainbow via Author tab:
#   URL: https://simple.wikipedia.org/wiki/Rainbow
#   Expected: 5-7 atoms, all ok, 0 skipped, ≤1 retry-ok on experiment atom
# Re-seed Planet via Author tab:
#   URL: https://simple.wikipedia.org/wiki/Planet
#   Expected: 5-7 atoms, all ok, 0 skipped, ≤2 retry-ok on voice-persona + any experiment
```

**On green Rainbow + Planet:** fill in `docs/sprint-runs/S12-10-seed-lessons/outcomes.md` cross-lesson totals + lesson-2-rainbow.md + lesson-3-planets.md templates; flip S12-10 tracker row to ✅; Sprint Summary MVP 5 → 8 pts (36% → 57%); Sprint 12 Total 36/60 → 39/60 (65%); proceed to S12-11 touch test.

**In-plan vs drift:**

- In-plan: zero — entire run is drift absorbed from S12-10.
- Drift (necessary): iOS Xcode 26 build unblock + concept-atom routing + stage timeout bump. All retired here because they were blocking S12-10's DoD.
- Drift (scope creep, absorbed): Content Browser — bang asked mid-run. Shipped in one commit because the single-lesson skill-trace window was friction for the upcoming testing/analysis phase.
- Drift NOT absorbed (deferred): per-atom parallel fan-out (S13+ after rate-limit audit); cross-skill decomposition integration test (S12-16 Pipeline regression); back-fill `content.text` dead-code removal (S14+ migration cleanup).

**Retired debt (three pieces that would have blocked or silently degraded touch test):**

1. iOS build under Xcode 26 / Swift 6.2 strict concurrency. NovaKids compiles clean on iPad Pro 13-inch (M5) simulator.
2. Concept-atom silent skip via unmapped `CARD_TYPE_TO_SKILL.concept`. Every cardType curriculum-architect emits now finds a skill.
3. iOS StoryCardView + ConceptCardView rendering empty content on fresh-pipeline cards. Double-write pattern means both iOS canonical fields and legacy back-fill work.

