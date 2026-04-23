# S12-10 — Seed 3 Real Lessons Through the Full Pipeline

**Sprint:** Sprint 12 — "Touch Test"
**Story:** S12-10 (MVP epic, 3 pts)
**Status:** 🟡 Sandbox prep complete; live seeding awaits bang's Mac session.

This directory holds everything needed to run S12-10 end-to-end: the seed plan, the pre-flight iOS audit + fixes, per-lesson run logs (bang fills in as he goes), the Mac-side runbook, and the post-run outcomes summary.

## Files

| File | Role |
|------|------|
| [`seed-plan.md`](./seed-plan.md) | The 3 curated URLs + expected modality mix per lesson + DoD assertions + retry-risk warnings (esp. voice-persona first-person gates). Read this BEFORE opening the Author tab. |
| [`preflight-swift-audit.md`](./preflight-swift-audit.md) | iOS audit of the card views that will render these lessons. Two touch-test blockers fixed in-sandbox; a handful of carve-outs documented for S13+. |
| [`runbook.md`](./runbook.md) | Step-by-step Mac runbook: boot backend, open Author tab, run each URL, capture artifacts, pull iPad, run first card of each lesson. |
| [`lesson-1-sky-blue.md`](./lesson-1-sky-blue.md) | Story-heavy lesson template. Bang fills in SSE event log + Pipeline screenshot + retry breakdown + iPad render notes. |
| [`lesson-2-rainbow.md`](./lesson-2-rainbow.md) | Experiment-heavy lesson template. |
| [`lesson-3-planets.md`](./lesson-3-planets.md) | Quiz-heavy lesson template. |
| [`outcomes.md`](./outcomes.md) | Post-run summary: cross-lesson totals, skill-def fixes applied (if any), final DoD verdict, screenshots dir. |
| `screenshots/` | Pipeline-tab + iPad render screenshots live here. Filename convention: `lesson-N-pipeline.png`, `lesson-N-ipad-card-M.png`. |

## DoD for this story

Every seeded lesson must produce **zero `retry-failed` or `skipped` atoms on first pass**. `retry-ok` is acceptable — it means the LLM violated a Zod invariant on attempt 1 and succeeded on attempt 2; the engine did its job. `retry-failed` means both attempts failed the validator, which means a skill-def prompt needs tuning. If any lesson hits `retry-failed` on any atom: capture the full trace, **fix the skill-def prompt in-sandbox**, then re-seed that lesson before calling the story done.

## Tracker row

[`docs/SPRINT-12-tracker.md`](../../SPRINT-12-tracker.md) S12-10 row — flipped to ✅ Done post-seeding once outcomes.md confirms the DoD.
