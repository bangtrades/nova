# Lesson 3 — "Planet" (quiz-heavy + voice)

**URL:** `https://simple.wikipedia.org/wiki/Planet`
**Target modality mix:** 1× story + 2× quiz + 1× voice
**Path:** Science Stage 1 (same as Lessons 1 & 2)
**Author tab field values:**

- Child: `<same test child>`
- Path: Science Stage 1
- URL: `https://simple.wikipedia.org/wiki/Planet`
- Skip quality gate: ☐

## Pre-submit checklist

- [ ] Lessons 1 & 2 landed successfully
- [ ] iPad speech recognition + microphone permissions already granted (ideally from a prior session)
- [ ] Physical environment quiet enough to test voice card

## SSE event log

| # | Stage | Status | Source | Detail | t (s) |
|---|-------|--------|--------|--------|-------|
| 1 | connection | open | — | | |
| 2 | ingest | created | — | | |
| 3 | scrape | done | — | | |
| 4 | analyze | done | — | topic: ____ | |
| 5 | decompose | done | skill-engine | atomCount: __ | |
| 6 | generate | done | skill-engine | cardCount: __ , retryOk: __ , retryFailed: __ | |
| 7 | quality | done | — | | |
| 8 | persist | done | — | lessonId: `<paste>` | |
| 9 | complete | done | — | | |

## Per-atom trace

**⚠️ Watch the voice atom closely — this is HIGH retry risk per the seed plan.** The voice-persona skill has 6 Dashy-voice gates that commonly trip generic-LLM output:

- `promptText` needs first-person marker (I/me/my/we/us/our/let's) AND must NOT contain "you will"/"you must"/"you should"
- `celebration` needs first-person AND must NOT contain "you got"/"good job"
- `retryHint` needs first-person AND must NOT contain "wrong"/"incorrect"/"no,"

Most LLM responses default to "You got it!" or "Great job!" on celebration — expect retries.

| Atom | Name | Strategy → cardType | Skill | validatorStatus | retryCount | tokens | Zod error on attempt 1 (if any) |
|------|------|---------------------|-------|-----------------|------------|--------|---------------------------------|
| atom-1 | | | | | | | |
| atom-2 | | | quiz-maker | | | | |
| atom-3 | | | quiz-maker | | | | |
| atom-4 | | voice → voice-persona | | | | | |

**If voice atom retries:** note which Dashy-voice gate fired. Common patterns worth documenting — the LLM's first attempt likely used "you got it" in celebration, or "you will know this" in promptText.

## Screenshots

- [ ] `screenshots/lesson-3-pipeline.png` — Pipeline tab after completion
- [ ] `screenshots/lesson-3-ipad-quiz.png` — one quiz card on iPad
- [ ] `screenshots/lesson-3-ipad-voice.png` — voice card on iPad (idle state, mic button visible)

## iPad render notes — VoiceCardView (S12-10 rewritten)

**This is the first time the rewritten VoiceCardView runs against real skill-engine output.** Pay close attention to:

- [ ] Card appears with Dashy's prompt text visible
- [ ] **Dashy's prompt plays via TTS on appear** (using `voiceManager.speak`)
- [ ] Tap mic → button turns coral, `listeningPulse` ring animates (unless reduce-motion on)
- [ ] Status text reads "I'm listening…"
- [ ] Speak an acceptable answer from `expectedResponses`
- [ ] Tap mic again to stop
- [ ] Brief "Thinking…" state appears
- [ ] **Match detected: `NovaHaptics.success()` fires, sun-tinted bubble shows `celebration` line, TTS plays the celebration line**
- [ ] Next → button appears at bottom (uses `.novaPrimary()` style)
- [ ] Tap Next → card dismisses, flipbook advances

**Miss case** (intentionally say nonsense):

- [ ] Mic tap → listen → stop
- [ ] Match fails: `NovaHaptics.wrong()` fires, coral-tinted bubble shows `retryHint` line, TTS plays the retry line
- [ ] After retry line finishes, card returns to idle state — same prompt visible, mic button resets to ink color, "Skip for now" button appears (new escape hatch)

## Verdict

- [ ] ✅ All atoms `ok` or `retry-ok`
- [ ] 🟡 Voice atom `retry-ok` — note the gate that fired (most likely candelebration/retryHint voice-of-god):
  ___
- [ ] 🔴 Any atom `retry-failed` or `skipped` — STOP + fix skill prompt

## Expected vs actual

| Expected | Actual |
|----------|--------|
| 4 atoms, two of which are quiz, one voice | |
| Voice atom cardType.content has promptText + expectedResponses + celebration + retryHint | |
| expectedResponses has ≥ 2 entries | |
