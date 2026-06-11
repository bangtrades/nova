# Novai — Session Handoff (2026-06-10)

> Paste-able first message for a fresh Claude (target: next model — Opus 4.8 / Fable — confirm at session start) continuing the Novai project.
> Session ran on: `claude-opus-4-7[1m]` · Generated: 2026-06-10.
> A longer "deep context" handoff written earlier this same session window (under a skewed session clock that stamped it May 22) lives at `/Users/nolan/Projects/Novai/docs/HANDOFF-2026-05-22.md` — same project, mostly-still-current substance; **this doc is the delta + current frontier and is the canonical first-message**.

---

You are continuing work on **Novai** (product name "Sparky", codebase prefix "Nova") — a dual-app iOS platform for kids 4–8 and their parents. NovaKids (iPad) is the kid app: AI-generated lesson flipbook cards narrated by **Dashy**, an AI mascot, via OpenAI TTS through a backend proxy. NovaCompanion (iPhone + iPad) is the parent app for URL→lesson authoring through a 6-stage backend pipeline ("Grand Architect"). Backend is Node/Fastify + Prisma + Postgres (local-only, **never deployed** — that's S8 "Infrastructure" debt). Repo: `/Users/nolan/Projects/Novai`. The dominant workstream is the **V2 Classroom** 2.5D Home redesign that overtook S14.

The operator is **bang** (Nolan). Style: maximum reasoning depth, decisive recommendations not menus, comfortable with pbxproj surgery and SPM graphs, **wants risk flagged honestly**. Environment: you have file access to the repo + the Cortana vault, a Linux shell sandbox, and computer-use tied to the Mac. You **cannot compile iOS in the sandbox** — Mac-side build is the gate for everything iOS. You can run `npx tsc --noEmit` on the backend and `swift test --package-path` on platform-independent SPM packages. You cannot push to GitHub from the sandbox (no creds — bang pushes from his Mac).

## What this project is                                                        [core]

A kids' iPad learning app whose pipeline turns any web URL into an illustrated, voice-narrated, age-appropriate "flipbook" lesson. Five card types: story, concept, experiment, quiz, voice. Dashy is the mascot + narration persona. The V2 redesign reskins the kid Home from a Pinterest grid into a **2.5D illustrated classroom** the kid taps objects in (chalkboard → continue lesson; bookshelf → lesson library; Dashy's desk → chat; trophy shelf → rewards). Backend + skill engine + knowledge graph + mastery tracker are unchanged through V2; only iOS surfaces.

Key vocabulary you'll encounter:
- **Oracle** — internal Dev Console web UI at `src/Backend/public/dev-pipeline.html` (was renamed from "Dev Console" in S13).
- **Slice** — bang's idiom for a discrete agent work unit. Vault has 69 of them under `cortana-vault/projects/novai/slices/` covering V2-S1/S2/S3.
- **Skill engine** — backend's pluggable LLM router (`story-writer`, `quiz-maker`, `experiment-designer`, `curriculum-architect`, `voice-persona`).
- **Fix-pack** — the 4 May-11-audit-recommended pre-art-import tasks (V2-S4-F1/F2/F3/F4).

## Read these first (in order)                                                 [core]

1. `/Users/nolan/Projects/Novai/docs/HANDOFF-2026-05-22.md` — **the deep-context briefing** from earlier this same session window. Same project, same operator. Read this first; everything below is a delta on top of it.
2. `/Users/nolan/Cortana/cortana-vault/projects/novai/novai--dev-health-audit-2026-05-22.md` — the full development health audit. The audit's 9 recommendations frame every open work item.
3. `/Users/nolan/Projects/Novai/docs/SPRINT-V2-classroom-tracker.md` — current execution tracker. The V2-S4 fix-pack rows + Carry-debt + Delivery Notes are where progress lives.
4. `/Users/nolan/Projects/Novai/docs/sprint-runs/V2-S4-fixpack-2026-05-22.md` — most recent slice run summary. Includes the **Slice-report protocol** every future agent slice brief must end with.
5. `/Users/nolan/Cortana/cortana-vault/projects/novai/novai.md` — project page. Vision, monetization, package layout, "Pivot — May 2026" callout.
6. `/Users/nolan/Projects/Novai/docs/NOVA-V2-sprint-plan.md` — V2 4-sprint plan of record (~168 pts). Authoritative for what V2 IS.

## What the LAST session did                                                   [core]

Long session window. Major arc: shipped S13 voice upgrade end-to-end → S14 "Playable" was scaffolded then immediately superseded by the V2 classroom pivot discovered on `main` → wrote the full health audit → restored map (SPRINT-V2 tracker, cancelled S14, fixed `architecture.mermaid`, updated `novai.md`) → built the iOS↔backend contract test → dispatched a 4-agent parallel slice batch → reconciled their work → extracted `ClassroomSceneModel` into a `NovaClassroom` SPM package to resolve symlink drift → wrote two handoff docs (the prior one and this).

Between session messages bang **organized the loose art PNGs into proper `Assets.xcassets` imagesets** (~28 new imagesets under `Apps/NovaKids/Resources/Assets.xcassets/lesson_*_45.imageset/`) and **completed the Xcode wiring step** for NovaClassroom (`grep -c NovaClassroom src/Nova.xcodeproj/project.pbxproj` returns **5**). Both are uncommitted but in place.

**Delivered (all on disk):**

- **Contract test** → `src/Packages/NovaCore/Tests/NovaCoreTests/ContractTests.swift` (committed `3cc3392`). 6 tests + `APIClient.makeJSONDecoder()` factory; locks the wire-shape drift class.
- **SPRINT-V2 program tracker** → `docs/SPRINT-V2-classroom-tracker.md` (committed `3974792`). Reconciles the V2 plan against 12 commits + 69 vault slices.
- **S14 cancellation banner** → `docs/SPRINT-14-tracker.md` (committed `3974792`).
- **`architecture.mermaid` fixed** → `docs/architecture.mermaid` (committed `3974792`). Was showing `Spark*` names and Pinterest grid.
- **Vault: dev health audit** → `cortana-vault/projects/novai/novai--dev-health-audit-2026-05-22.md` (in place, vault is NOT git-tracked).
- **Vault: `novai.md` updated** → `cortana-vault/projects/novai/novai.md`.
- **V2-S4 fix-pack slice batch (4 agents, uncommitted)** → modifies `NavigationNarrator.swift`, `ClassroomLessonLibraryView.swift`, `ExperimentCardView.swift`. F1 zero-change, F2 partial (bookshelf only), F3 clean (+113 LOC), F4 deferred.
- **NovaClassroom package extraction (uncommitted)** → `src/Packages/NovaClassroom/{Package.swift, Sources/NovaClassroom/ClassroomSceneModel.swift, Tests/NovaClassroomTests/ClassroomSceneModelTests.swift}`. `ClassroomSceneModel` `git mv`'d (history preserved), 35 tests de-symlinked, `import NovaClassroom` added to 6 app files, registered in `Nova.xcworkspace`. **Bang completed the Xcode wiring** (pbxproj has 5 NovaClassroom refs).
- **Run summary for the 4-agent batch** → `docs/sprint-runs/V2-S4-fixpack-2026-05-22.md` (untracked).
- **Deep-context handoff (prior)** → `docs/HANDOFF-2026-05-22.md` (untracked).
- **This handoff** → `docs/session-handoff-2026-06-10.md`.

**Gotchas to know:**

- **The session clock skewed**. Files written this session are stamped 2026-05-22 / 2026-05-29 by the sandbox `Date()`. Wall-clock today is 2026-06-10. Don't be confused by stale-looking dates in committed messages and file frontmatter — they describe this same session window.
- **The Cortana vault is NOT git-tracked.** Edits to `cortana-vault/projects/novai/novai.md` and the audit are saved on write — never `git add` the vault. Bang said this explicitly.
- **Don't `git add -A`** even now that art is organized: `HANDOFF-2026-05-22.md` and a few in-flight files would get swept; stage explicitly.
- **Hand-edited pbxproj broke Xcode twice** this session — specifically with `+` in a filename (`URL+RewriteLocalhost.swift`). Both times reverted; the rule is now: new files via Xcode `File → Add Files`; SPM package dependencies via Xcode's `General → Frameworks/Libraries → +`; raw pbxproj edits only for renames or trivial file-removal of non-`+` names.
- **The pre-existing `ModelTests` in NovaCoreTests is the kind of false-confidence test you don't trust.** It round-trips its own encoder with a strict `.iso8601` date strategy — never sees a real Prisma payload. The new `ContractTests` is what catches real wire drift.
- **`@testable import NovaClassroom`** works only if the package is built with testability on. SPM does this for test runs automatically. Don't try to manually `package(name: ..., swiftSettings: [.testable])`.
- **Backend dev-mode auth is permissive** — if no `Authorization: Bearer ...` header is present in `development`, the middleware resolves `request.userId` to the first user in the DB (see `src/Backend/src/middleware/auth.ts`). That's why local curl tests work without tokens.
- **Two recurring contract-drift patterns** that have shipped to real devices this year: (a) Prisma emits ISO 8601 with fractional seconds; Swift's `.iso8601` rejects them; (b) Backend dev-mode asset uploader hard-codes `http://localhost:3000/...` URLs into the DB which the iPad can't reach. Both fixed; both have tests guarding them. See the audit's "contract-drift bug class" section.

## Current state                                                               [core]

- **Frontier (iOS):** working tree has THREE uncommitted batches sitting on top of `3cc3392` (origin/main):
  1. **V2-S4 fix-pack** (3 files): `NavigationNarrator.swift` (+ `classroomBookshelfEmpty` script), `ClassroomLessonLibraryView.swift` (kid-safe bookshelf empty copy + `.narrate(...)`), `ExperimentCardView.swift` (+113 LOC affordance work — finger-tap badge, lift shadow, breathing pulse, underglow, thickened stroke, filled-bobbing arrow; every motion cue has a reduce-motion fallback).
  2. **NovaClassroom extraction**: the `git mv` of `ClassroomSceneModel.swift` from `Apps/NovaKids/Sources/Views/Classroom/` into `Packages/NovaClassroom/Sources/NovaClassroom/`, plus `Package.swift`, plus `Tests/NovaClassroomTests/ClassroomSceneModelTests.swift` (35 tests), plus 6 app-file `import NovaClassroom` additions (HomeView, ClassroomSceneView, ClassroomAssetDebugHUD, ClassroomObjectButton, ClassroomIllustratedSceneView, ClassroomHotspotDebugOverlay), plus `Nova.xcworkspace/contents.xcworkspacedata` adding the package FileRef, plus the pbxproj edits Xcode wrote when bang added the package product (5 NovaClassroom references in pbxproj — confirmed).
  3. **Art organization**: ~28 new imagesets under `Apps/NovaKids/Resources/Assets.xcassets/lesson_*_45.imageset/`. `lesson_workbook_45_landscape.imageset/` shows `M` (Contents.json + the PNG itself modified), the rest are `??` (new).
- **Frontier (docs)**: `docs/sprint-runs/V2-S4-fixpack-2026-05-22.md`, `docs/sprint-runs/index.md` update, `docs/HANDOFF-2026-05-22.md`, and `docs/SPRINT-V2-classroom-tracker.md` updates — all uncommitted.
- **`origin/main` HEAD:** `3cc3392 test(novacore): iOS↔backend contract test`. Ahead 0, behind 0.
- **Art generation:** bang has been doing rounds of asset generation. The 28-imageset batch landed; not clear if more rounds are planned.
- **Open question never answered:** the Slice-D candidate from the "next round" plan (VOX-FU backend trio: `PUBLIC_BASE_URL` env var, empty-body POST validation exemption, Oracle Content Browser publish/unpublish toggle) was offered as **dispatchable immediately** because it's backend-only and doesn't need the iOS Xcode gate. **Bang never said go.** First conversational move in the new session: ask if Slice D should dispatch now or stay queued.
- **Verifications you must do** before committing or dispatching new work — see "First moves" §1.

## Operator-gated items still outstanding                                      [if relevant]

```bash
# A. VERIFY the Mac Xcode wiring actually succeeded.
#    pbxproj has 5 NovaClassroom refs which strongly implies bang did
#    File→Add Package Dependencies → Add Local → NovaClassroom, then
#    linked the product to the NovaKids target. Confirm with a build.
cd ~/Projects/Novai/src
xcodebuild -workspace Nova.xcworkspace -scheme NovaKids \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
# expect: BUILD SUCCEEDED

# B. Run the package tests.
swift test --package-path src/Packages/NovaClassroom
# expect: 35 tests, all green

swift test --package-path src/Packages/NovaCore --filter ContractTests
# expect: 6 tests, all green

# C. If A+B green → commit the three uncommitted batches separately.
#    DO NOT `git add -A` — stage files explicitly.

# C.1 — the package extraction (touches the workspace + the package + import sites + the rename + pbxproj):
git add src/Packages/NovaClassroom/ \
        src/Nova.xcworkspace/contents.xcworkspacedata \
        src/Nova.xcodeproj/project.pbxproj \
        src/Apps/NovaKids/Sources/Views/Classroom/ClassroomSceneModel.swift \
        src/Packages/NovaClassroom/Sources/NovaClassroom/ClassroomSceneModel.swift \
        src/Apps/NovaKids/Sources/Views/Home/HomeView.swift \
        src/Apps/NovaKids/Sources/Views/Classroom/ClassroomSceneView.swift \
        src/Apps/NovaKids/Sources/Views/Classroom/ClassroomAssetDebugHUD.swift \
        src/Apps/NovaKids/Sources/Views/Classroom/ClassroomObjectButton.swift \
        src/Apps/NovaKids/Sources/Views/Classroom/ClassroomIllustratedSceneView.swift \
        src/Apps/NovaKids/Sources/Views/Classroom/ClassroomHotspotDebugOverlay.swift
git commit -m "refactor(kids): extract ClassroomSceneModel into NovaClassroom package"

# C.2 — the agent fix-pack:
git add src/Apps/NovaKids/Sources/Services/NavigationNarrator.swift \
        src/Apps/NovaKids/Sources/Views/Classroom/ClassroomLessonLibraryView.swift \
        src/Apps/NovaKids/Sources/Views/Flipbook/ExperimentCardView.swift
git commit -m "feat(kids): V2-S4 fix-pack — kid-safe bookshelf copy + experiment-card affordances"

# C.3 — art assets (review imageset Contents.json files first — anything iffy, fix before commit):
git add src/Apps/NovaKids/Resources/Assets.xcassets/
git commit -m "feat(kids): import V2 classroom art catalog (lesson_*_45 imagesets)"

# C.4 — the docs / planning artifacts:
git add docs/HANDOFF-2026-05-22.md \
        docs/session-handoff-2026-06-10.md \
        docs/sprint-runs/V2-S4-fixpack-2026-05-22.md \
        docs/sprint-runs/index.md \
        docs/SPRINT-V2-classroom-tracker.md
git commit -m "docs: session handoff + V2-S4 fix-pack run summary + tracker updates"

# D. Push.
git push
```

## Standing constraints — DO NOT VIOLATE (verbatim, operator-set)              [core]

- **"I don't want the vault committed to github repos"** — the Cortana vault (`~/Cortana/`) is NOT a git repo. Save edits in place; never propose committing it. Workflow split: project management → Novai repo (committed); reports + knowledge → vault (written direct, no commit).
- **"Project management should be from the project directory"** — sprint trackers, run summaries, planning docs live in `docs/` in the Novai repo. Reports live in the vault.
- **"Disable the agents from creating recap messages — slice reports go in the project docs and are compared to the sprint plan"** — every agent slice brief must end with a slice-report instruction (write a `docs/sprint-runs/<slice-id>.md` per the protocol in the V2-S4-fixpack run summary). The lead (you) then reconciles each slice report against `SPRINT-V2-classroom-tracker.md` and flips story statuses.
- **"Do not have each agent do a full vault review"** — for agent execution slices, the briefs are self-contained. A blanket vault review per agent is wasted context. The vault review's value is upstream (planning).
- **"Don't `git add -A`"** — stage files explicitly. The repo has historically had loose untracked files (art-in-progress, handoff drafts) you don't want to sweep in.
- **No `+` in iOS Swift filenames** added via pbxproj. Broke Xcode container loading once this session (`URL+RewriteLocalhost.swift`). Rule: new files via Xcode UI, or if hand-edited pbxproj, filename has no `+`.
- **Never embed `OPENAI_API_KEY` in iOS.** Already the architecture: iOS calls `POST /api/v1/voice/tts` on the backend; backend proxies to OpenAI. This is the S13 architectural decision; do not "simplify" it.
- **Voice is the primary UX channel for kids 4–10.** Don't propose silent UI; every Tier 1 screen narrates via `NavigationNarrator`, every kid-mode error/empty state must be voiced.

## Architecture / domain cheatsheet                                            [if relevant]

Full architecture is in `docs/architecture.mermaid` (fixed this session) and the audit. Quick reference:

- **Packages** (SPM): `NovaCore` (models, APIClient, sync), `NovaAuth` (Apple SSO, JWT, OAuth), `NovaVoice` (TTS + STT + remote TTS proxy client), `NovaStorage` (Core Data, AES-256-GCM), **`NovaClassroom` (V2 classroom scene model, new this session)**. All under `src/Packages/`. Workspace lists 5 packages; pbxproj's NovaKids target links 5 products.
- **Apps**: NovaKids (iPad app), NovaCompanion (iPhone + iPad parent app) — under `src/Apps/`.
- **Backend**: `src/Backend/` — Node 22, Fastify, Prisma, Postgres. Local-only `:3000`. **Never deployed.** Auth in dev mode: no token → first user in DB.
- **Decoder factory**: `APIClient.makeJSONDecoder()` is the ONE source of truth for backend response decoding. Custom date strategy: tries `.withFractionalSeconds` ISO 8601 first, falls back to plain ISO 8601, then throws.
- **Voice flow**: `VoiceManager.speak(text:voice:preferLocal:)` defaults to remote → backend `POST /api/v1/voice/tts` (SHA-256 LRU cache, 4 personas) → AVSpeech fallback on failure. The kid's chosen voice persona is the iOS L1 cache key.
- **V2 classroom flow**: `HomeView.swift:4` hard-codes `classroomV2Enabled = true` → `HomeView` renders `ClassroomSceneView` (the live Home) → `ClassroomSceneModel` derives objects from lesson data → `ClassroomObjectButton` provides the 88×88pt tap targets → `ClassroomDashyGuideLayer` overlays the mascot + narration. `EnhancedHomeView` is dead code (in a `#Preview` only).

## Critical IDs / values                                                       [if relevant]

- **Repo root**: `/Users/nolan/Projects/Novai`
- **Sandbox mount**: `/sessions/<session-id>/mnt/Novai`
- **Vault root**: `/Users/nolan/Cortana/cortana-vault`
- **Origin**: `https://github.com/bangtrades/nova.git` (main branch)
- **`origin/main` HEAD this session**: `3cc3392 test(novacore): iOS↔backend contract test`
- **Last classroom commit before this session**: `5f4f5f5 feat(kids): harden classroom beta UI` (2026-05-11)
- **Backend port**: 3000 (local)
- **Backend `tsc --noEmit` baseline**: 33 pre-existing errors (down from 51 cited in S12/S13 trackers — non-zero by design; burndown is a separate slice)
- **iOS test count**: 4 files / ~29 cases in NovaCoreTests + **6 cases in ContractTests** (new this session) + **35 cases in NovaClassroomTests** (new this session, pending Mac verify)
- **Backend test count**: 30 `*.test.ts` files / ~832 vitest cases
- **Art catalog target**: ~110 assets across 10 priority-tagged categories. Imagesets named `lesson_*_45.imageset` shipping now (~28 in the working tree).

## Useful skills / tools in this environment                                   [if relevant]

Skills loaded in the sandbox — use without hesitation:

- **senior-swift** — every Swift edit. Verify API signatures, write compile-clean code.
- **swiftui-pro** — reading/writing/reviewing SwiftUI views.
- **swift-concurrency** — async/await, actors, Sendable; relevant given V2 has scene-update perf considerations.
- **ios-accessibility** — Dynamic Type, VoiceOver, reduce-motion. Mandatory for a kids' app.
- **swiftui-performance-audit** — V2-S4-06 (image caching/downsampling) and any future perf work.
- **sprint-runner** — `docs/SPRINT-*-tracker.md` + `docs/sprint-runs/*.md` editing. Bang's idiom is encoded here.
- **orchestration** — when planning the next agent slice batch.
- **obsidian** — Cortana vault edits / structure / queries.

MCPs come and go in this sandbox. The Chrome MCP is available; the TradingView MCP is loaded (unrelated to Novai). The bio-research MCPs flicker on/off — not used here.

## First moves in the new session                                              [core]

1. **Verify state matches this handoff.** Run:
   ```bash
   cd ~/Projects/Novai && git log --oneline -3 && git status --short | head -8 && grep -c NovaClassroom src/Nova.xcodeproj/project.pbxproj
   ```
   Expect: HEAD `3cc3392`, working tree dirty with the three batches described in "Current state", pbxproj NovaClassroom count = 5. If any of these is different, **say so to bang before doing anything** — the world moved while this handoff was being written.
2. **Ask bang the standing open question, verbatim:** *"The 4 agent slice candidates were drafted but only Slice D (VOX-FU backend trio — `PUBLIC_BASE_URL`, empty-body POST exemption, Oracle publish toggle) was offered as dispatchable now because it's backend-only and doesn't need the iOS Xcode gate. Want me to write Slice D's full self-contained brief and you dispatch it, or hold for a different next move?"*
3. **If bang has not yet run "Operator-gated A" (the Mac `xcodebuild` verification)**, recommend doing it before any iOS work. The pbxproj NovaClassroom count of 5 is necessary but not sufficient — a clean build is the gate.
4. **If A+B green and bang wants to commit**, run the four commit blocks from "Operator-gated C" in order. Push.
5. **Standing next-up objective** once current work clears: write the 4 self-contained agent slice briefs (A: V2-S4-F2 completion, B: V2-S4-05 sound/reaction pass, C: V2-S4-06 performance pass, D: VOX-FU backend trio) following the prior-session format — file ownership table, do-not-touch boundaries, acceptance criteria, validation, AND the slice-report-protocol instruction baked in.

---

*Handoff written 2026-06-10 by the prior session's lead, `claude-opus-4-7[1m]`. Mtime of this file is authoritative even when content references the session-clock-stamped dates inside the docs.*
