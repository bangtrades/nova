# Lesson 1 — "Sky" (story-heavy)

**URL:** `https://simple.wikipedia.org/wiki/Sky`
**Target modality mix:** 2× story + 1× explanation + 1× quiz (no experiment, no voice)
**Path:** Science Stage 1 (create via "+ New Path" before first seed)
**Author tab field values:**

- Child: `<select your test child>`
- Path: Science Stage 1
- URL: `https://simple.wikipedia.org/wiki/Sky`
- Title override: _(blank — use scraped title)_
- Description override: _(blank)_
- Skip quality gate: ☐ (unchecked — want full end-to-end signal)

## Pre-submit checklist

- [ ] Backend running (`npm run dev`)
- [ ] Dev Console open at `http://localhost:3000/dev/dev-pipeline.html#author`
- [ ] Browser DevTools console open (Network tab → Record events)
- [ ] "+ New Path" form closed (path already selected from dropdown)
- [ ] iPad on same LAN, logged in as test child, on Home tab ready to pull-to-refresh

## SSE event log

Fill in as events arrive. Paste the full event JSON from browser console or paraphrase in the Detail column.

| # | Stage | Status | Source | Detail (bytes, atomCount, validatorStatus, retryCount, etc.) | t (s) |
|---|-------|--------|--------|--------------------------------------------------------------|-------|
| 1 | connection | open | — | childId + pathId echo | 0.0 |
| 2 | ingest | created | — | ingestId: `<paste>` | |
| 3 | scrape | start | — | | |
| 4 | scrape | done | — | bytes: ____ , title: ____ | |
| 5 | analyze | start | — | | |
| 6 | analyze | done | — | topic: ____ , ageAppropriate: __ , suggestedStage: __ | |
| 7 | decompose | start | skill-engine | | |
| 8 | decompose | done | skill-engine | atomCount: ____ , validatorStatus: __ , retryCount: __ | |
| 9 | generate | start | skill-engine | atomCount: ____ | |
| 10 | generate | done | skill-engine | cardCount: ____ , retryOkCount: __ , retryFailedCount: __ , skippedCount: __ | |
| 11 | quality | start | — | | |
| 12 | quality | done | — | regeneratedCount: __ , overallScore: __ | |
| 13 | persist | start | — | | |
| 14 | persist | done | — | lessonId: `<paste>` , cardCount: __ | |
| 15 | complete | done | — | skillEngineUsed: __ , qualityScore: __ , elapsedMs: __ | |

## Per-atom trace (from Pipeline tab skill-trace panel)

After the lesson lands, click "Jump to Pipeline tab →" in the Author tab's success card. Paste the per-atom rows here:

| Atom | Name | Strategy → cardType | Skill | validatorStatus | retryCount | tokens | notes |
|------|------|---------------------|-------|-----------------|------------|--------|-------|
| atom-1 | | | | | | | |
| atom-2 | | | | | | | |
| atom-3 | | | | | | | |
| atom-4 | | | | | | | |

## Screenshots

- [ ] `screenshots/lesson-1-pipeline.png` — full Pipeline tab after completion showing Stage-3 row + 4 Stage-4 rows
- [ ] `screenshots/lesson-1-ipad-card-1.png` — first card rendered on iPad

## iPad render notes

Pull to refresh on iPad. Open Science Stage 1 path → Sky lesson → first card.

- [ ] Story card renders with Bangers title + body text
- [ ] "Read aloud" button plays TTS narration
- [ ] Next / Prev navigation chrome works
- [ ] No visual regressions (layout adapts to landscape + portrait)

## Verdict

- [ ] ✅ All 4 atoms reached `ok` or `retry-ok` (DoD met)
- [ ] 🟡 Any atom `retry-ok` — acceptable but note which one(s) + the specific Zod rejection from attempt 1:
  ___
- [ ] 🔴 Any atom `retry-failed` or `skipped` — **STOP**. Capture full trace, fix skill-def prompt, re-seed. Write up the fix here:
  ___

## Expected vs actual outcome

| Expected | Actual |
|----------|--------|
| 4 atoms (opener narrative, 2 explanation, closer quiz) | |
| 0 experiment atoms | |
| 0 voice atoms | |
| All `ok` on first attempt | |
