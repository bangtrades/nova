# S12-10 Seed Plan — 3 URLs, Known Modality Mix

## Picks

Three **Simple Wikipedia** URLs. Simple Wikipedia is the ideal source for S12-10 because: (a) kid-safe by editorial policy (primary audience is English learners + children), (b) prose is already stage-1/2 appropriate so the content analyzer won't reject as age-inappropriate, (c) stable URLs + predictable structure, (d) the skill-engine's topic decomposition has enough content to produce 3–6 atoms without padding.

| # | URL | Target modality mix | Why this URL |
|---|-----|---------------------|--------------|
| 1 | `https://simple.wikipedia.org/wiki/Sky` | **Story-heavy** (2 story + 1 quiz + 1 voice) | Narrative explanation of light scattering. Expected atoms: (1) what is the sky, (2) why it looks blue, (3) why it turns red at sunset, (4) a quiz to check. Natural narrative flow = curriculum-architect's Wondering-Aloud default fits. |
| 2 | `https://simple.wikipedia.org/wiki/Rainbow` | **Experiment-heavy** (1 story + 1 experiment + 1 quiz) | Concrete sort-and-classify payload: which conditions produce a rainbow (sun + rain + angle), which colors appear in order. Experiment-designer's drag/drop shape fits naturally. |
| 3 | `https://simple.wikipedia.org/wiki/Planet` | **Quiz-heavy** (1 story + 2 quiz + 1 voice) | Factual retrieval space: number of planets, rocky vs gas, inner vs outer. Quiz-maker territory. Voice atom for recalling a planet name from a clue. |

All three live under **one path**: create a new **"Science Stage 1"** path (icon: 🔬, color: `#5AC8FA`) in the inline + New Path form before the first seed. Subsequent lessons attach to the same path so all three appear under one tab on the iPad Home.

## Per-lesson expectations

### Lesson 1 — "Sky" (story-heavy)

- **Stage 3 (curriculum-architect):** expect 4 atoms. Opener = narrative ("what is the sky"), two explanation/story mid-atoms on scattering mechanics, closer = quiz ("pick the right reason the sky is blue").
- **Stage 4 (per-atom skills):** story-writer × 2 (narrative + scattering), story-writer × 1 (sunset explanation), quiz-maker × 1 (closer). No experiment, no voice — wrong modality for a sky story at stage 2. Curriculum-architect should route accordingly; if it picks an experiment here, that's a decomposition-routing mis-signal worth noting.
- **Zod retry risk:** LOW. story-writer has no output schema; quiz-maker's schema is well-tested. Expect all 4 atoms `ok` on first attempt.
- **Expected tokens:** ~3,500 total (600–900 per story atom + quiz overhead).

### Lesson 2 — "Rainbow" (experiment-heavy)

- **Stage 3:** expect 3–4 atoms. Opener = narrative ("what is a rainbow"), application = experiment ("sort which conditions make one"), optional explanation, closer = quiz.
- **Stage 4:** story-writer × 1, experiment-designer × 1, quiz-maker × 1. The experiment-designer atom is the interesting one — its drag/drop output must pass 8 referential-integrity invariants (kebab-case ids, orphan check, dual-assignment check, label uniqueness, etc.). **If anything retry-fails this sprint, it's most likely here.**
- **Zod retry risk:** MEDIUM. The LLM has to coordinate `dragItems[i].id` with `dropTargets[j].acceptsItemIds[k]`. Expect 0–1 `retry-ok` events (first attempt misses orphan check, retry cleans it up). Zero `retry-failed` required.
- **Expected tokens:** ~2,800 total.

### Lesson 3 — "Planet" (quiz-heavy)

- **Stage 3:** expect 4 atoms. Opener = narrative ("what is a planet"), quiz × 2 (8 planets retrieval + rocky-vs-gas classification), closer = voice ("name a planet Dashy gives a clue for").
- **Stage 4:** story-writer × 1, quiz-maker × 2, voice-persona × 1.
- **Zod retry risk:** **MEDIUM–HIGH on the voice atom.** voice-persona's validator has 6 Dashy-voice gates: first-person required on promptText/celebration/retryHint, banned voice-of-god phrases ("you will"/"you must"/"you should") in promptText, banned voice-of-god praise ("you got"/"good job") in celebration, banned hard-corrections ("wrong"/"incorrect"/"no,") in retryHint. These are EXACTLY the phrasings a generic-tuned LLM will default to. Expect `retry-ok` on the voice atom with 70%+ probability on first attempt. Zero `retry-failed` required.
- **Expected tokens:** ~3,000 total.

## Retry-risk summary

| Skill | Risk | Why |
|-------|------|-----|
| `story-writer` | LOW | Free-form prose; no output schema. |
| `quiz-maker` | LOW | Strict schema but LLM reliably produces 4-option MCQ with valid correctIndex. |
| `experiment-designer` | MEDIUM | 8 referential-integrity invariants; the acceptsItemIds cross-reference is where orphans/dual-assignments sneak in. |
| `curriculum-architect` | LOW-MEDIUM | 6 invariants including card-type diversity + voice-ceiling. The diversity rule rejects "3 quiz atoms in a row" which a default LLM might try for the Planet lesson. |
| `voice-persona` | **HIGH** | 6 Dashy-voice gates — the most common AI-generated phrases ("You got it!" / "Good job!" / "You will know this") all fail the validator. Expect retries. |

**Reminder:** `retry-ok` is a **pass** per DoD. The engine violated, re-prompted with the validator's specific rejection, and the second attempt succeeded. The DoD only blocks on `retry-failed` (both attempts failed — skill-def prompt needs tuning) or `skipped` (router couldn't even invoke the skill — usually missing input or feature flag off).

## Stretch ambition

If all 3 seeds land with zero `retry-failed` AND zero `retry-ok` (i.e. every atom passes first-attempt), that's a **signal of over-tuning** — the skill prompts might be too conservative to produce stylistically varied output across real content. In that case, flag for S13 to monitor whether seeded lessons feel samey. For now, 0 `retry-failed` is the only hard requirement.

## Stop criteria — when to pause and fix in-sandbox

If any seeded lesson produces:

- **`retry-failed` on ANY atom** → **stop**. Capture the full trace from the Pipeline tab, including both attempt bodies + both Zod error arrays. Come back in-sandbox to update the failing skill's prompt based on what the LLM got wrong. Re-seed that lesson only after the fix.
- **`skipped` on ANY atom** → **stop**. That means `CARD_TYPE_TO_SKILL[atom.recommendedCardType]` returned undefined, the registry doesn't have the skill loaded, or the required input is missing. All three are bugs. Capture the `skip-reason` and debug.
- **Age-inappropriate block** at the analyze stage → surprising for Simple Wikipedia content but possible; the safety filter has flagged something. Pick a different URL and move on; file a safety-filter tuning issue for S13 if multiple kid-safe sources get blocked.

## Post-seed verification on iPad

After all 3 lessons land in the dev DB, pull to refresh on the iPad. The "Science Stage 1" path should appear on Home. All 3 lessons should show under it. Open the first card of each lesson and confirm:

- **Lesson 1 story card:** prose renders in Bangers title + body text, TTS plays the narrative via "Read aloud" button.
- **Lesson 2 experiment card:** drag items appear with labels, drop targets have the right labels, dragging a correct item into its bin plays `NovaHaptics.success()` + coral-fill snap, wrong drop plays `NovaHaptics.wrong()` + shake animation.
- **Lesson 3 voice card:** Dashy's prompt plays via TTS on appear, tapping the mic records, speaking an acceptable answer plays the celebration line via TTS, speaking nonsense plays the retryHint line via TTS.
