# Sprint 10 Run — Skill-Engine Kickoff (S10-11 + S10-06/07 Spike)

**Run ID:** S10-R3 · **Window:** April 17, 2026 *(same day, parallel with bang's Mac-side QA of S10-04 / S10-05)*
**Delivery agent:** claude (orchestrator) · **Tracking:** /jira-expert

---

## Goal

Deliver the Teaching Strategy Matrix (S10-11, 5pts) — the last non-skill dependency for the Content Generation Skills epic — and publish the design spike that settles the shape of S10-06 (story-writer) + S10-07 (quiz-maker) so they can be implemented without re-opening foundational questions.

## Strategic context

- S10-01/02/03/04/05 (50pts of MEM epic) already landed. The child's profile, mastery, engagement, parent guidance, and session context are all available to any downstream skill.
- S10-11 is a *prerequisite* for S10-12 (skill → pipeline integration) and de-facto a prerequisite for S10-06/07 (since every skill will consume `rankedCardTypes` as input).
- While bang does Mac-side QA on S10-04/S10-05 (new migrations, Prisma generate, Dev Console tabs), claude ships S10-11 in parallel and drafts the spike so the next run has a clear path.

## Stories delivered

### S10-11 — Teaching Strategy Matrix (5pts) — ✅ Done

**Service layer** (`src/services/skills/teachingStrategy.ts`, pure, ~350 LOC):
- Six `ConceptType` values × three `LearningModality` values fully populated; every cell contains all 5 card types.
- `rankCardTypesFor(conceptType, modality, ctx)` additive ranker:
  - base score `5 - baseRank` (5..1)
  - engagement: top type +1.5, second +0.75, zero-completion -0.5
  - difficulty: `±0.4 × offset`, clamped ±2, favor-list for quiz/experiment (hard) / story/voice (easy)
  - age: experiment <6 → -0.75, concept <5 → -0.75, other types never gated
  - stable sort: score desc, baseRank asc
  - NaN/Infinity-safe; empty engagement degrades to matrix order
- `inferModality(engagement)` heuristic: voice/story → auditory, experiment/quiz → kinesthetic, concept/empty → visual.
- `getStrategyMatrix()` returns a clone so callers can't mutate module state.

**Tests** (`tests/teachingStrategy.test.ts`, 39 cases, all green at 340ms):
- Matrix shape (6×3, uniqueness, auditory top-2 contains voice/story, kinesthetic top-2 contains experiment, clone immutability)
- Base ranker (empty-ctx preservation, score formula, equivalence of ranker/order, all 5 types returned per combo)
- Engagement bonus (top +1.5, second +0.75, zero-completion -0.5, cold-start neutrality, 3rd→2nd lift)
- Difficulty bonus (zero-neutral, +2 favors quiz/experiment, -2 inverts, clamp ±2, NaN/Infinity → 0)
- Age bonus (undefined → 0, experiment <6, concept <5, other types ungated)
- Composed ranking (layering is cooperative, no NaN/duplicates under max layering)
- `inferModality` (all branches)
- Graceful degradation

**Dev Console surface** (`src/routes/devConsole.ts`, `public/dev-pipeline.html`):
- `GET /dev/teaching-strategy` endpoint — Zod-validated query params, 401/404/403 ownership chain when `childId` supplied. Returns `{matrix, conceptTypes, modalities, focus:{...}, childContext}`. `engagementOverride` query param lets the operator fabricate a synthetic engagement preference without driving real interactions.
- **Strategy** tab in Dev Console — concept-type select, modality select (with "(from child)" default), difficulty slider (-2..+2) with live label, engagement-override select. Ranker panel shows the focus cell's ordered card types with horizontal score bars and per-row bonus breakdown. Full-matrix panel renders the 6×3 grid with the focus cell highlighted green. Raw JSON pane. Cross-tab refresh on `nova:childChanged`.

### S10-06 / S10-07 — Skill Engine Design Spike — ✅ Draft published

**Document:** `docs/design-spikes/S10-06-07-skill-loader.md`

**Scope:** defines the skill directory convention, `SkillManifest` Zod schema, `ChildContext` input shape, `SkillRegistry` interface, prompt-assembly pipeline, and abbreviated prompt templates for both S10-06 (story-writer with age 4/6/8 profiles) and S10-07 (quiz-maker with easy/medium/hard difficulty curves).

**Opens six decisions for bang:**

1. Handlebars.js vs home-grown interpolator (lean: Handlebars.js).
2. Age profile resolution — nearest-below vs nearest-above (lean: nearest-below).
3. One shared output schema validator vs per-skill Zod (lean: per-skill).
4. Loader eager vs lazy (lean: eager boot-time).
5. Model routing authority — manifest hint vs costRouter (lean: manifest advisory, costRouter decides).
6. Source of `interestTopics` — extract from parentGoals vs add structured field (lean: add field now, one migration).

**Effort estimate:** ~18h total for both S10-06 and S10-07 including Dev Console Skills tab — fits inside the 26pt allocation.

---

## Files changed this run

**New:**
- `src/Backend/src/services/skills/teachingStrategy.ts` — pure matrix + ranker
- `src/Backend/tests/teachingStrategy.test.ts` — 39 vitest cases
- `docs/design-spikes/S10-06-07-skill-loader.md` — skill-engine spike
- `docs/sprint-runs/S10-skill-engine-kickoff.md` — this document

**Modified:**
- `src/Backend/src/routes/devConsole.ts` — new `GET /dev/teaching-strategy` endpoint + imports
- `src/Backend/public/dev-pipeline.html` — new Strategy tab (HTML + CSS) + JS (`STATE.strategy`, `loadStrategy`, `renderStrategy`, `onStrategyDifficultyInput`), `VALID_TABS` + `switchTab` + public API + cross-tab sync updates
- `docs/SPRINT-10-tracker.md` — S10-11 flipped to Done, SKILL epic 0 → 5 pts, delivery notes appended, spike kickoff section added

## Validation matrix

| Check | Result |
|-------|--------|
| `tsc --noEmit` on `teachingStrategy.ts` | ✅ 0 errors |
| `tsc --noEmit` on `devConsole.ts` | ✅ 0 errors |
| Vitest on `teachingStrategy.test.ts` | ✅ 39/39 passing (340ms) |
| Brace/paren/bracket balance on new files | ✅ |
| Dev Console HTML structural parse | ✅ |
| Runtime verification of `/dev/teaching-strategy` | 🟡 pending on Mac |
| Runtime verification of Strategy tab UI | 🟡 pending on Mac |

Pre-existing 32 Prisma-SQLite JSON typing errors remain untouched (Sprint 9 carry-in debt — separate ticket).

## Mac-side runbook (what bang should verify)

```bash
cd ~/Projects/Novai/src/Backend

# 1. No schema changes → no prisma generate / migrate needed.

# 2. Unit tests
npx vitest run tests/teachingStrategy.test.ts          # expect 39 passing
npm test                                                # full suite

# 3. Boot server
npm run dev

# 4. Open Dev Console → http://localhost:3000/dev-pipeline.html
#    → pick a child
#    → open the Strategy tab
#    → drag difficulty slider 0 → +2 : quiz / experiment should climb
#    → drag 0 → -2 : story / voice should climb
#    → flip engagementOverride to "voice top" : voice moves up
#    → change modality to "kinesthetic" and conceptType to "process" : experiment leads (score 5.00)
#    → focus cell in the 6×3 grid is highlighted green
#    → raw JSON at the bottom mirrors the live ranking

# 5. Raw endpoint sanity
curl -s 'http://localhost:3000/api/v1/dev/teaching-strategy?conceptType=process&modality=kinesthetic' \
  | jq '.data.focus.ranking[0]'
# expect: { cardType: "experiment", score: 5, baseRank: 0, ... }

# 6. Ownership chain spot-check (use someone else's childId)
curl -s -o /dev/null -w '%{http_code}\n' \
  'http://localhost:3000/api/v1/dev/teaching-strategy?childId=<foreign-uuid>'
# expect: 403
```

## Architectural decisions log (this run)

1. **Additive layering over multiplicative.** Additive bonuses are predictable and debuggable — every bonus row in the Dev Console ranker panel shows its exact contribution.
2. **Matrix cells hold all 5 card types, not a top-1.** Graceful degradation: if the preferred type fails quality gate, the orchestrator has 4 fallbacks already ranked.
3. **Age gate is a nudge, not a veto.** Lets engagement override when the child genuinely prefers the card type.
4. **ConceptType separate from the existing `TeachingStrategy` enum in `conceptDecomposer.ts`.** Different semantic layer — "what kind of concept" vs "how to present it."
5. **Dev Console `engagementOverride` query param.** Lets the 6×3 matrix be fully introspected without driving real child interactions.
6. **Spike before skills.** S10-06 and S10-07 both cost 13pts — cheaper to pay 2h up-front on shared shape than discover divergence at S10-12 integration.

## What's next in Sprint 10

- **bang's Mac-side QA** on S10-04 + S10-05 (ongoing, parallel).
- **bang to review** `docs/design-spikes/S10-06-07-skill-loader.md` and resolve the six open questions.
- **Next claude run** (S10-R4): ship `types.ts` + `registry.ts` + `loader.ts` + Handlebars + `story-writer` defs + `/dev/skills` endpoints — closes S10-06.
- **Run after that** (S10-R5): ship `quiz-maker` defs + Dev Console Skills tab — closes S10-07.
- **Then**: S10-08 (experiment-designer) + S10-09 (curriculum-architect) + S10-10 (voice-persona) — pure content work on the same loader.
- **Final**: S10-12 integrates skill engine into the Grand Architect pipeline — closes S10-12 and by extension the last S9 carry-in (S9-07).

## Handoff checklist

- [x] S10-11 implementation complete, tests green in sandbox
- [x] Dev Console Strategy tab wired end-to-end
- [x] SPRINT-10 tracker updated (S10-11 Done, summary 55/118)
- [x] S10-11 delivery notes appended to tracker
- [x] S10-06/07 design spike published
- [x] Run summary document created (this file)
- [ ] bang to run Mac-side verification (unit tests + Dev Console smoke)
- [ ] bang to review spike and answer six open questions
