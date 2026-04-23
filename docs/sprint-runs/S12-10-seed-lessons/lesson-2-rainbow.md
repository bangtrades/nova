# Lesson 2 — "Rainbow" (experiment-heavy)

**URL:** `https://simple.wikipedia.org/wiki/Rainbow`
**Target modality mix:** 1× story + 1× experiment (drag-drop sort) + 1× quiz
**Path:** Science Stage 1 (same as Lesson 1)
**Author tab field values:**

- Child: `<same test child>`
- Path: Science Stage 1
- URL: `https://simple.wikipedia.org/wiki/Rainbow`
- Skip quality gate: ☐

## Pre-submit checklist

- [ ] Lesson 1 landed successfully
- [ ] Path dropdown still shows Science Stage 1 (sticky after previous seed)
- [ ] Stream panel cleared from Lesson 1

## SSE event log

| # | Stage | Status | Source | Detail | t (s) |
|---|-------|--------|--------|--------|-------|
| 1 | connection | open | — | | |
| 2 | ingest | created | — | | |
| 3 | scrape | done | — | | |
| 4 | analyze | done | — | topic: ____ | |
| 5 | decompose | done | skill-engine | atomCount: __ , validatorStatus: __ | |
| 6 | generate | done | skill-engine | cardCount: __ , retryOk: __ , retryFailed: __ | |
| 7 | quality | done | — | | |
| 8 | persist | done | — | lessonId: `<paste>` | |
| 9 | complete | done | — | | |

## Per-atom trace

**⚠️ Watch the experiment atom closely — this is MEDIUM retry risk per the seed plan.** The 8 referential-integrity invariants (kebab-case ids, orphan check, dual-assignment check, rationalePerTarget parity, label uniqueness, substantive-label) are where LLM first-attempt errors concentrate.

| Atom | Name | Strategy → cardType | Skill | validatorStatus | retryCount | tokens | Zod error on attempt 1 (if any) |
|------|------|---------------------|-------|-----------------|------------|--------|---------------------------------|
| atom-1 | | | | | | | |
| atom-2 | | experiment → experiment-designer | | | | | |
| atom-3 | | | | | | | |

**If the experiment atom retries:** common first-attempt failures to look for — (a) orphan dragItem (LLM forgot to include it in any acceptsItemIds), (b) non-kebab id (LLM used Title Case "Cork" instead of "cork"), (c) wrong difficulty-matrix shape (5 items / 2 bins instead of 5/3 at hard curve), (d) duplicate label case-insensitively. All of these are VALID retry-ok cases per DoD.

## Screenshots

- [ ] `screenshots/lesson-2-pipeline.png` — Pipeline tab after completion
- [ ] `screenshots/lesson-2-ipad-experiment.png` — experiment card rendered on iPad BEFORE first drag
- [ ] `screenshots/lesson-2-ipad-experiment-complete.png` — experiment card AFTER all items correctly placed (star completion state)

## iPad render notes — ExperimentCardView

- [ ] Title + instructions render at top
- [ ] Drag items appear in horizontal scroll row (or vertical stack on compact layout)
- [ ] Drop targets appear below with visible labels + accept-count hints
- [ ] Drag-and-drop gesture works (item lifts off source, snaps into target on release)
- [ ] Correct drop plays `NovaHaptics.success()` (medium impact) + coral-fill snap animation
- [ ] Wrong drop plays `NovaHaptics.wrong()` + ShakeModifier shake + item bounces back
- [ ] All items placed correctly → star completion reaction + auto-dismiss to next card

## Verdict

- [ ] ✅ All atoms `ok` or `retry-ok`
- [ ] 🟡 Experiment atom `retry-ok` — note the Zod rejection type:
  ___
- [ ] 🔴 Any atom `retry-failed` or `skipped` — STOP + fix skill prompt

## Expected vs actual

| Expected | Actual |
|----------|--------|
| 3 atoms, one of which is experiment | |
| difficulty matrix: easy (3 items × 2 bins) OR medium (4 × 2) — age 6 default | |
| rainbow colors or sun+rain+angle drag items | |
