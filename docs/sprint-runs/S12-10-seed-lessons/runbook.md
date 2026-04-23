# S12-10 Mac-Side Runbook

Step-by-step for the live seeding session. Estimated wall-clock: 45 min if everything lands on first attempt; up to 2 hrs if skill-def fixes are needed.

## 0. Pre-flight (5 min)

```bash
cd ~/Code/Novai
git pull   # should be at dbac350 or d5af1e0 HEAD (S12-09 author tab) + any S12-10 in-sandbox edits
```

**Confirm the S12-10 in-sandbox fixes are present:**

```bash
grep -n "celebration: String?" src/Packages/NovaCore/Sources/NovaCore/Models/Card.swift
# expect: one hit — the new optional field

grep -n "matches(transcript:" src/Apps/NovaKids/Sources/Views/Flipbook/VoiceCardView.swift
# expect: one hit — the fuzzy bidirectional match helper

git status
# expect: working tree at the latest committed S12-10 state (if committed); else shows the 2 modified files
```

**Build NovaKids:**

```bash
cd src/Apps/NovaKids
xcodebuild \
  -scheme NovaKids \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch)' \
  -quiet \
  build 2>&1 | tail -20
# expect: "** BUILD SUCCEEDED **"
# If you get a "'celebration' is not a member of Card.CardContent" error,
# confirm Card.swift has the new fields AND NovaCore has been rebuilt.
# Clean build if needed:  xcodebuild clean && rebuild above
```

**Boot backend:**

```bash
cd ~/Code/Novai/src/Backend
npm run dev
# expect: "Server listening on port 3000" + no Prisma schema warnings
```

Keep that terminal open; server logs are useful during seeding.

## 1. Open Dev Console (1 min)

```bash
open http://localhost:3000/dev/dev-pipeline.html#author
```

Author Lesson tab should be active (the `#author` hash forces it). You should see:

- Child dropdown populated from your dev DB
- Path dropdown populated (probably empty if no paths exist yet)
- "+ New Path" button next to path dropdown
- URL input + override inputs
- "Pipeline stream" empty-state panel at the bottom

Also open **browser DevTools → Console tab**. The SSE event-by-event raw frames will print if you add a `console.log(event)` inside `handleAuthorEvent` (already present in the file) or watch the stream panel render.

## 2. Create the path (2 min)

Click **"+ New Path"** — inline form expands.

- Title: `Science Stage 1`
- Icon emoji: `🔬`
- Color: `#5AC8FA`
- Description: `Sky, rainbows, and planets — the first seeded curriculum.`

Click **Create path**. Status should show "✓ Created". Path dropdown refreshes and auto-selects the new path.

## 3. Lesson 1 — Sky (15 min including iPad regression)

Fill the form:
- Child: your test child
- Path: Science Stage 1
- URL: `https://simple.wikipedia.org/wiki/Sky`
- Title/description overrides: leave blank
- Skip quality gate: unchecked

Click **Author lesson**.

**As SSE events arrive**, paste each into `lesson-1-sky-blue.md` → SSE event log table. The stream panel shows each one as a row; click into the row to expand the full event JSON, or copy from DevTools Network tab → `/author-lesson` request → Response tab.

**Expected elapsed:** 20-40 seconds end-to-end. If it takes >2 min without terminal events, check server logs for LLM timeout/retry.

When you see **`complete:done`**:

1. Click **"Jump to Pipeline tab →"** button in the success card.
2. The Pipeline tab skill-trace panel opens against the new lesson's `lessonId`.
3. Screenshot the Pipeline tab (full panel — Stage-3 decompose row + 4 Stage-4 atom rows). Save as `screenshots/lesson-1-pipeline.png`.
4. Copy each atom's row data into `lesson-1-sky-blue.md` → Per-atom trace table.

**iPad regression:**

1. Pull to refresh on iPad Home.
2. Confirm "Science Stage 1" path appears with 🔬 icon.
3. Tap the path → Sky lesson appears.
4. Tap the lesson → first card opens.
5. Confirm story renders with Bangers title + body text.
6. Tap "Read aloud" (or equivalent) — TTS narration plays.
7. Screenshot first card → `screenshots/lesson-1-ipad-card-1.png`.
8. Flip through remaining cards using Next → arrows.

**Fill in the Verdict section of `lesson-1-sky-blue.md`.**

## 4. Lesson 2 — Rainbow (20 min — experiment atom is the risk)

Same flow. The experiment atom is where first-attempt Zod retries are most likely. **Do NOT panic on a `retry-ok` event** — that means the validator caught a referential-integrity violation and the retry prompt fixed it. That's exactly what the retry layer is for.

**If experiment atom `retry-failed`:** STOP. In the Pipeline tab, expand the failed atom's row to see both attempt traces + both Zod error arrays. Then:

1. Identify the invariant that fired (orphan check? difficulty matrix? kebab-case?).
2. Come back in-sandbox to update `src/Backend/src/services/skills/defs/experiment-designer/prompt.md` or the relevant partial to give the LLM a more concrete example + stronger negative constraint.
3. Re-deploy backend (`npm run dev` reloads on save for most dev configs).
4. Re-author the Rainbow URL → expect new lesson row, old one can be left as reference.
5. Update `lesson-2-rainbow.md` Verdict + add an entry to `outcomes.md` Fix section.

**iPad regression for experiment:**

- Drag items appear with labels (e.g. "sun", "rain drops", "angle")
- Drop into correct bin → coral snap + haptic success + label shows in bin
- Drag into wrong bin → shake animation + haptic wrong + item bounces back to source
- Complete the sort → star completion reaction

Screenshots for `lesson-2-ipad-experiment.png` (pre-drag) + `lesson-2-ipad-experiment-complete.png` (post-completion).

## 5. Lesson 3 — Planet (20 min — voice atom is THE high risk)

Same flow. The voice atom has 6 Dashy-voice gates; expect the LLM's first attempt to fail at least one of them (probably "you got it!" in celebration or "you will know" in promptText).

**`retry-ok` is normal and acceptable on voice atoms.** This story's DoD is zero `retry-failed`, not zero retries.

**iPad regression for voice (IMPORTANT — first time the S12-10 rewrite runs against real content):**

Per-step checklist from `lesson-3-planets.md` → iPad render notes. Pay attention to:

- Dashy's prompt plays via TTS on card appear. If silent: check VoiceManager injection at app startup, check speech permissions, check Settings → Sounds.
- Mic button animation under listening state — TimelineView pulse, coral fill.
- Speak an answer from `expectedResponses` → match → **celebration plays**.
- Speak nonsense → miss → **retryHint plays** → card returns to idle.
- "Skip for now" button appears after a miss (escape hatch).

**Two screenshots:** `lesson-3-ipad-quiz.png` + `lesson-3-ipad-voice.png` (idle state with mic visible).

## 6. Fill in `outcomes.md` (5 min)

Aggregate cross-lesson totals. Write DoD verdict. Snapshot screenshots dir contents. If any fixes were applied, capture diff summary.

## 7. Commit artifacts (2 min)

```bash
cd ~/Code/Novai
git status docs/sprint-runs/S12-10-seed-lessons/
# expect: new screenshots + filled-in per-lesson files

git add docs/sprint-runs/S12-10-seed-lessons/
git commit -m "docs(s12-10): seed 3 lessons — Sky + Rainbow + Planet through full pipeline · 3 pts"
git push origin main
```

Then update `docs/SPRINT-12-tracker.md` S12-10 row from 🟡 → ✅ + bump Sprint Summary (+3 pts).

## Troubleshooting

### "Failed to load" on child dropdown

- Server not running on 3000, or wrong port configured. Check terminal.
- JWT expired. Refresh the Dev Console page.

### SSE stream never starts

- Check DevTools Network tab → `/author-lesson` request. Is it 403? 400? Response body has the error.
- 400 means Zod rejected body — confirm URL is valid `https://` URL + childId/pathId are UUIDs.

### Backend returns 500 on `/author-lesson`

- Check backend terminal logs. Common: LLM API key missing (`ANTHROPIC_API_KEY` or `OPENAI_API_KEY` in `.env`), Prisma client not generated, child doesn't exist in dev DB.

### Pipeline hangs at scrape stage

- Simple Wikipedia occasionally rate-limits. Wait 30 seconds and retry the same URL.
- If the URL consistently times out, try a different stable one (Simple Wikipedia's "Science" category has lots of alternates).

### `retry-failed` keeps firing on the same atom

- The skill-def prompt needs actual tuning. Come back in-sandbox. Look at what the LLM output on both attempts; identify whether the Zod error message is clear enough for a retry to succeed.
- Often the fix is: add a concrete positive example in the prompt, then add a concrete negative example ("NOT: ..." with a common anti-pattern the LLM is producing).

### VoiceCardView renders but TTS doesn't play

- Simulator may have muted audio. Check Simulator → I/O → Audio menu.
- On physical iPad: check mute switch + Settings → Accessibility → Spoken Content → Speaking Rate not 0.
- Worst case: VoiceManager not injected via `@EnvironmentObject`. Check `FlipbookView.swift` is passing `voiceManager` into `VoiceCardView`.

### Speech recognition never starts

- iOS 18+ requires explicit speech + microphone authorization. First use of any voice card should prompt — if denied, must enable in Settings → Privacy → Microphone + Speech Recognition → NovaKids.
- Simulator speech recognition is unreliable; test on physical iPad if possible.

## Quick-reference curl for inspecting lessons

```bash
TOKEN="<paste from Session tab>"

# List all lessons for your user
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/lessons | jq '.data[] | {id, title, pathId, status, cardCount: (.cards | length)}'

# Full card dump for a specific lesson
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/lessons/<LESSON_UUID> | jq '.'

# aiAnalysis blob with full skill-engine envelope
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/lessons/<LESSON_UUID> | jq '.aiAnalysis | fromjson'
```
