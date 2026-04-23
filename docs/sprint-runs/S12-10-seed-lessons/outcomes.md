# S12-10 Outcomes

Fill this in after all 3 lessons have been seeded (or as soon as any lesson forces a skill-def fix).

## Cross-lesson totals

| Metric | Lesson 1 (Sky) | Lesson 2 (Rainbow) | Lesson 3 (Planet) | Total |
|--------|----------------|--------------------|--------------------|-------|
| Atoms generated | | | | |
| `ok` atoms | | | | |
| `retry-ok` atoms | | | | |
| `retry-failed` atoms | | | | |
| `skipped` atoms | | | | |
| Cards persisted | | | | |
| Tokens consumed | | | | |
| Elapsed seconds | | | | |

## DoD verdict

- [ ] ✅ **Zero `retry-failed` + zero `skipped` across all 3 lessons.** Story closes as ✅ Done. Proceed to S12-11 touch test.
- [ ] 🔴 **`retry-failed` or `skipped` on one or more lessons.** Story stays 🟡 in progress until skill-def fix + re-seed of the affected lesson(s). Document the fix below.

## Skill-def fixes applied (if any)

For each `retry-failed` / `skipped` event, fill in:

### Fix 1

- **Lesson + atom:** _(e.g. Lesson 3, atom-4 voice)_
- **Skill:** _(e.g. voice-persona)_
- **What the LLM did wrong (both attempts):**
  _(paste snippet from the trace)_
- **Which Zod invariant fired:** _(e.g. celebration must not contain "you got")_
- **Prompt change applied:** _(file path + diff summary)_
- **Re-seed result:** ✅ / 🔴

## Per-lesson render notes summary

Lift the high-severity iPad render issues from each per-lesson file here so anyone scanning can see what fires across all three:

- Lesson 1 (Sky): _(any issues)_
- Lesson 2 (Rainbow): _(any issues)_
- Lesson 3 (Planet): _(any issues)_

## Performance observations

- **Fastest lesson:** ____ at ____ s
- **Slowest lesson:** ____ at ____ s
- **Skill-engine success rate:** ____ / total atoms
- **Dashy-voice gate fire rate on voice atom:** ____ out of 1 (expected ~0.7 if the retry-risk prediction was right)

## What's next

On ✅: S12-11 touch test scheduled for ____ with ____ (your kid's name). These 3 lessons are the seed content.

On 🔴: close out the skill-def fix + re-seed loop here. Typical turnaround on a skill-def prompt tuning: edit the relevant `.md` prompt partial in `defs/<skill>/`, no tests to re-run (prompts are content not code), re-submit the lesson URL via Author tab, confirm retry-ok or ok. Update the row in the outcomes table and the per-lesson file's Verdict section.

## Artifact inventory

- [ ] `lesson-1-sky-blue.md` — filled in
- [ ] `lesson-2-rainbow.md` — filled in
- [ ] `lesson-3-planets.md` — filled in
- [ ] `screenshots/lesson-1-pipeline.png`
- [ ] `screenshots/lesson-1-ipad-card-1.png`
- [ ] `screenshots/lesson-2-pipeline.png`
- [ ] `screenshots/lesson-2-ipad-experiment.png`
- [ ] `screenshots/lesson-2-ipad-experiment-complete.png`
- [ ] `screenshots/lesson-3-pipeline.png`
- [ ] `screenshots/lesson-3-ipad-quiz.png`
- [ ] `screenshots/lesson-3-ipad-voice.png`
