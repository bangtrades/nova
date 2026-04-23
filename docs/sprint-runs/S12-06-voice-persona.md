# S12-06 — `voice-persona` Skill + Router Wiring Run Summary — CE Epic Close

**Sprint:** Sprint 12 — "Touch Test"
**Story:** S12-06 — `voice-persona` skill (def bundle + Zod validator + router dispatch) (6 pts)
**Landed:** April 23, 2026
**Status:** ✅ Shipped. 10 def files, one per-skill Zod validator (10 `.strict().superRefine()` invariants — six of them are Dashy-voice contract gates), skillRouter + CardContent wiring, and three test files (60 new assertions) merged in-sandbox. Full backend suite: 823 pass / 1 carry-in debt fail. **CE epic closes 18/18 (100%) with this run** — the full 5-modality skill-engine is live.

This document is the **delivery run summary and Mac-side runbook** for S12-06. It is the fifth entry in the skill-engine family — after [S10-06](./S10-skill-engine-s10-06.md) (story-writer), [S10-07](./S10-skill-engine-s10-07.md) (quiz-maker), [S12-04](./S12-04-experiment-designer.md) (experiment-designer), [S12-05](./S12-05-curriculum-architect.md) (curriculum-architect) — and it closes the **third and last** of the carry-from-S10 CE-epic stories. With this run the legacy inline `voice` branch at `cardGenerator.ts:432-438` joins the other three S10-12 legacy-fallback paths in dead-code status. The skill-engine now handles every card type rendered on the iPad flipbook end-to-end with atomic `ok / retry-ok / retry-failed / skipped` Pipeline-tab telemetry.

What makes voice-persona structurally different from the other Stage-4 skills: **this is the skill where Dashy's character lives**. Six of the ten Zod `superRefine` invariants aren't about data shape — they're about Dashy's voice. First-person markers required on every spoken line. Voice-of-god phrases (`"you will"` / `"you must"` / `"you should"`) banned in the prompt. Voice-of-god praise (`"you got"` / `"good job"`) banned in the celebration. Hard corrections (`"wrong"` / `"incorrect"` / `"no,"`) banned in the retry hint. The audit that S12-17 plans to run against Dashy's chat + onboarding + hint surfaces has its contract encoded directly in this schema. Dashy's character drifts if and only if these rules drift — and Zod's retry-on-validation layer catches the drift before it reaches the iPad.

---

## What shipped

Ten new content files under `defs/voice-persona/`, one Zod validator with 10 `superRefine` invariants, skillRouter wiring at 4 touchpoints, `CARD_TYPE_TO_SKILL.voice` + `CardContent` interface expansion in the shared types, and three test files' worth of coverage. Lifted patterns from S12-04 exactly at the def-bundle + validator + router layers.

- `src/services/skills/defs/voice-persona/{manifest.json, prompt.md, styles.md, topics.md, age-profiles/{4,6,8}.md, difficulty-curves/{easy,medium,hard}.md}` — the fifth real skill.
- `src/services/skills/validators/voicePersona.ts` — strict `.object(...).strict().superRefine(...)` with 10 layered invariants.
- `src/services/skills/validators/index.ts` — one-line append: `'voice-persona': voicePersonaOutputSchema`.
- `src/services/pipeline/skillRouter.ts` — four touchpoints: `SKILL_MAX_TOKENS['voice-persona'] = 700`, `SKILL_TO_MODEL['voice-persona'] = 'claude-sonnet'`, `buildSkillInputs('voice-persona', ...)` (concept + conceptType + optional topic + optional lastStoryExcerpt), `buildCardFromSkillOutput('voice-persona', ...)` emits `type: 'voice'` with camelCase content fields matching iOS `Card.CardContent.promptText` / `.expectedResponses`, `voiceScript = promptText + ' ' + celebration`.
- `src/services/skills/types.ts` — one-line: `CARD_TYPE_TO_SKILL.voice: 'voice-persona'`.
- `src/services/pipeline/cardGenerator.ts` — `CardContent` interface expanded with 5 voice-mode optional fields: `promptText`, `expectedResponses`, `celebration`, `retryHint`, `phonetics`.
- `tests/voicePersonaValidator.test.ts` (51 cases), `tests/voicePersonaRouter.test.ts` (7 cases), `tests/skillEngine.test.ts` (+2 boot assertions).

Zero schema changes. Zero new migrations. Zero new env vars. Zero new npm deps. The legacy inline voice branch at `cardGenerator.ts:432-438` is now dead code for `card.type === 'voice'` atoms routed through the skill-engine path. Removing the branch physically is deferred to S14 for two sprints of migration stability.

---

## Architectural decisions (the "why X over Y" log)

1. **Dashy-voice gates enforced in the validator, not just the prompt.** Prompts are advisory; validators are contracts. Six of the 10 `superRefine` invariants encode Dashy's character — first-person required on `promptText` + `celebration` + `retryHint`, banned voice-of-god phrases on `promptText` + `celebration`, banned hard corrections on `retryHint`. If Dashy's voice drifts in S13+, the validator rejects the LLM output before it reaches the iPad; the retry-on-Zod layer then re-prompts with the specific rejection so the LLM sees what it violated. Alternative considered: leave the Dashy-voice rules in the prompt as narrative guidance. Rejected — prompts drift, validators don't. The S12-17 Dashy voice-consistency audit wants a structural enforcement point, not a guideline to cross-check against. Encoding the voice contract as Zod is that structural enforcement point.

2. **`temperatureHint: 0.6`, NOT 0.5 like experiment-designer.** Voice is stylistically variable within the Dashy-voice gates — the same concept can fire Wondering-Aloud / Echo-and-Read / Call-and-Response shapes, all equally valid Dashy. At 0.5 the sampler produces the same `promptText` skeleton over and over; at 0.7 it starts drifting outside the banned-phrase gates and triggering retries. 0.6 is the sweet spot: stylistic variety preserved, gates reliably respected on first pass. Alternative considered: a shared `temperatureHint: 0.5` across all Stage-4 skills. Rejected — per-skill tuning lets each skill's author (and the eventual cost router) optimize for the skill's actual variance budget.

3. **`voiceScript = promptText + ' ' + celebration` — retryHint deliberately NOT in default voiceScript.** The voiceScript is what the iPad TTS narrator reads when the card first appears. Dashy introduces her wondering (`promptText`) and on a correct match speaks the celebration (`celebration`). The `retryHint` fires only on a speech-recognition miss — including it in the default voiceScript would have Dashy read the retry line on every card even when the kid got it right on first try. Retry is on-demand from `content.retryHint`; iPad reads it only after a miss. Same always-read-parts-only contract shape as experiment-designer's `voiceScript = instructions + conceptSummary`.

4. **`expectedResponses` cardinality 1–5, not 3 fixed.** Easy difficulty might only need 2 entries (target word + natural article phrasing); hard difficulty might need 5 (technical term + casual phrasing + plural + mispronunciation + short-form). Over-restricting cardinality forces the LLM to pad whitelists with near-dupes which then fail the case-insensitive-uniqueness check — compounding error. 1–5 covers the full range without encouraging padding. Alternative considered: fixed 3 entries per card. Rejected — phonics cards often have a single-word target where 3 phonetic variants are awkward; hard-difficulty transfer-level prompts often need 5 to cover both technical and casual phrasings.

5. **`phonetics` optional + strict regex shape `/^[a-z]+(-[a-z]+)*( [a-z]+(-[a-z]+)*)*$/`.** Optional because only 4+ syllable technical words need TTS articulation guidance — simple common words pronounce fine without kebab-syllables. Strict regex rejects free-form phonetic spellings (which would confuse the iPad TTS voice) but accepts both single kebab-words (`"pho-to-syn-the-sis"`) and space-separated multi-word forms (`"warm blood-ed"`). The `/^[a-z]+/` start-anchor rejects uppercase and digits; the `(-[a-z]+)*` allows but doesn't require hyphenation; the space-separated repeat covers compound phrases.

6. **Banned-phrases list sourced from Dashy's "five non-negotiables," not from content sensibility.** Specifically: `"you will"` / `"you must"` / `"you should"` are the exact phrasings that make Dashy sound like an adult watching the app (voice-of-god). `"you got"` / `"good job"` are the two most-common AI-generated celebration phrases that fail the shared-not-granted rule. `"wrong"` / `"incorrect"` / `"no,"` are the three most-common hard-correction phrasings that fail the soft-reset rule. The list is not exhaustive — S13+ may catch new drift patterns in practice and add to the banlist. The current list is what the S11-13 Dashy chat voice established and what the S12-17 voice-consistency audit plans to enforce. Alternative considered: a single general "no voice-of-god" rule with LLM-side interpretation. Rejected — LLMs are notoriously inconsistent at self-policing abstract tone rules; concrete banned substrings give Zod a hard-rejection surface the retry layer can use.

7. **`handlesConceptTypes: ["vocabulary", "factual", "abstract"]` — narrower than experiment-designer's 5 types.** Voice-mode answers are single-point (one word / one short phrase). Multi-step processes, comparisons, and cause-effect concepts produce open-ended spoken responses that the speech-recognition matcher can't whitelist. Explicitly excluding `process` / `comparison` / `causeEffect` tells the Stage-3 decomposer / orchestrator that voice atoms for those concept types would be malformed — the decomposer routes them to experiment-designer or story-writer instead. Alternative considered: include all concept types and let the prompt sort out which shapes voice can handle. Rejected — the decomposer already has a concept-type dispatch layer; encoding the narrowing in `handlesConceptTypes` is the right layer to express it.

8. **`CardContent` interface expanded with 5 optional voice fields, NOT a separate `VoiceContent` discriminated union.** Adding `promptText?` + `expectedResponses?` + `celebration?` + `retryHint?` + `phonetics?` to the shared `CardContent` keeps the iOS transformer boundary stable — one decoder handles all card types; the decoder picks fields by `card.type`. Alternative considered: refactor `CardContent` into a discriminated union (`type CardContent = StoryContent | QuizContent | ExperimentContent | VoiceContent`). Rejected — the rest of the backend treats `CardContent` as a flat optional-fields bag (there are ~20 call sites that read `card.content.title` without caring about the card type). Refactoring to a discriminated union would ripple through every card-type branch and risk breaking the iOS decoder's field-by-field approach.

---

## Validation matrix

The matrix proves (a) per-skill age-profile cascade still works at the Dashy-voice layer, (b) the difficulty-curve shape (expectedResponses cardinality + prompt length) tracks the difficulty bucket, (c) each Dashy-voice Zod invariant rejects the specific line that violates it, and (d) the router wiring picks `voice-persona` for `card.type === 'voice'` atoms without legacy fallback.

**Controls:** `mode = synthetic`, `skill = voice-persona`, `inputs = {"concept": "the word for a baby cat", "conceptType": "vocabulary"}`. Only the bolded knobs vary per row.

| # | `ageYears` | `progressionΔ` | `difficultyOffset` | Expected `meta.ageProfileUsed` | Expected `meta.difficultyUsed` | Expected shape | System-prompt marker |
|---|-----------:|---------------:|-------------------:|-------------------------------:|:-------------------------------|:---------------|:---------------------|
| 1 | 6 | 0.0 | 0 | **6** | medium | prompt ≤ 110 chars / 3 entries | `/early reader/`, `/Wondering Aloud/` |
| 2 | 6 | 0.0 | -2 | **6** | easy | prompt ≤ 80 / 2 entries | `/Recognition-level/`, `/2 or 3/` |
| 3 | 6 | 0.0 | +2 | **6** | hard | prompt ≤ 180 / 4–5 entries | `/Transfer-level/`, `/4 or 5/` |
| 4 | 4 | 0.0 | 0 | **4** | medium | short uncertainty prompt | `/picture-first/`, `/one-word/` |
| 5 | 8 | 0.0 | 0 | **8** | medium | technical vocab OK | `/fluent reader/`, `/compound-phrase/` |
| 6 | 7 | +1.2 | 0 | **8** | medium | fluent-reader at effectiveAge 8.2 | `/fluent reader/` |
| 7 | 8 | -1.5 | -2 | **6** (ties-round-down 6.5→6) | easy | short uncertainty prompt | struggle nudge + Recognition level |
| 8 | 8 | +1.5 | +2 | **8** (clamped, no age-10) | hard | technical vocab + phonetics | above nudge + Transfer level |

**Validator-only spot-checks** (no UI, ran as unit tests):

| Invariant | Rejection case | Error message marker |
|-----------|----------------|---------------------|
| promptText first-person gate | `"What is a baby cat called?"` | `/first-person marker/` |
| promptText voice-of-god | `"You will know — what's a baby cat?"` | `/you will/` |
| promptText voice-of-god | `"You must know the word for a baby cat."` | `/you must/` |
| promptText voice-of-god | `"You should be able to tell me this."` | `/you should/` |
| celebration first-person | `"That is exactly right!"` | `/first-person marker/` |
| celebration voice-of-god praise | `"Yes! You got it!"` | `/you got/` |
| celebration voice-of-god praise | `"Good job! We got there."` | `/good job/` |
| retryHint first-person | `"Try thinking about a furry animal."` | `/first-person marker/` |
| retryHint hard-correction | `"Hmm, that's wrong — let's think again."` | `/wrong/` |
| retryHint hard-correction | `"Hmm, that's incorrect."` | `/incorrect/` |
| retryHint hard-correction | `"No, I was picturing a cat."` | `/no,/` |
| expectedResponses uniqueness | `["kitten", "Kitten"]` | `/duplicate expectedResponse/` |
| expectedResponses uniqueness | `["a kitten", "a  kitten"]` (whitespace-normalized) | `/duplicate expectedResponse/` |
| expectedResponses cardinality | 6 entries | `/at most 5 entries/` |
| expectedResponses cardinality | 0 entries | `/at least 1 entry/` |
| phonetics shape | `"Pho-to-syn-the-sis"` (uppercase) | `/kebab-syllable groups/` |
| phonetics shape | `"word1-word2"` (digits) | `/kebab-syllable groups/` |
| phonetics shape | `"pho-to-"` (trailing hyphen) | `/kebab-syllable groups/` |
| phonetics shape | `"pho_to_syn"` (underscores) | `/kebab-syllable groups/` |
| Substantive text | promptText `"🤔🤔🤔🤔🤔🤔🤔🤔🤔"` | `/emoji\/punctuation-only/` |
| Substantive text | expectedResponse `"🐱"` | `/emoji\/punctuation-only/` |
| Valid — first-person via `"let's"` | `"Let's try to remember — what's a baby cat?"` | `parsed.success === true` |
| Valid — first-person via `"we"` | `"What do we call a baby cat again?"` | `parsed.success === true` |
| Valid — first-person via `"I'm"` | `"I'm blanking — what's a baby cat?"` | `parsed.success === true` |
| Valid — benign `"you"` without god-phrase | `"I wonder — can you tell me?"` | `parsed.success === true` |

---

## curl cheat sheet

Grab an auth token from the Dev Console's **Session** tab and export:

```bash
TOKEN="<paste Bearer token>"
BASE="http://localhost:3000/api/v1"
```

### List skills — confirm voice-persona is registered

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills" | \
  jq '.data[] | {name, version, modelHint, hasOutputSchema, handlesConceptTypes}'
# expect: five entries — the full 5-modality skill-engine.
#   curriculum-architect: Stage 3, modelHint=pro,   handlesConceptTypes=[] (runs before conceptType dispatch)
#   experiment-designer:  Stage 4, modelHint=flash, handlesConceptTypes=["process","comparison","causeEffect","vocabulary","factual"]
#   quiz-maker:           Stage 4, modelHint=flash, handlesConceptTypes=[...]
#   story-writer:         Stage 4, modelHint=flash, handlesConceptTypes=[...]
#   voice-persona:        Stage 4, modelHint=flash, handlesConceptTypes=["vocabulary","factual","abstract"]
```

### Fetch the voice-persona manifest

```bash
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills/voice-persona" | jq '.data'
# expect: name=voice-persona, version=0.1.0, modelHint=flash, temperatureHint=0.6,
#         inputs.requires=["concept","conceptType"],
#         inputs.optional=["topic","targetLessonId","lastStoryExcerpt"],
#         handlesConceptTypes=["vocabulary","factual","abstract"],
#         hasOutputSchema=true
```

### Dry-run render — medium curve (default)

```bash
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/voice-persona/render" \
  -d '{
    "inputs": {
      "concept": "the word for a baby cat",
      "conceptType": "vocabulary"
    },
    "ctxOverrides": {
      "ageYears": 6,
      "progressionDelta": 0,
      "difficultyOffset": 0
    }
  }' | jq '{
    difficultyUsed: .data.meta.difficultyUsed,
    ageProfileUsed: .data.meta.ageProfileUsed,
    temperatureHint: .data.meta.temperatureHint,
    modelHint: .data.meta.modelHint,
    systemHasEarlyReader: (.data.system | contains("early reader")),
    systemHasWonderingAloud: (.data.system | contains("Wondering Aloud")),
    systemHasFirstPerson: (.data.system | contains("first-person"))
  }'
# expect: {difficultyUsed:"medium", ageProfileUsed:6, temperatureHint:0.6, modelHint:"flash",
#          systemHasEarlyReader:true, systemHasWonderingAloud:true, systemHasFirstPerson:true}
```

### Difficulty boundaries — easy (short) vs hard (technical + phonetics)

```bash
# Easy — 2–3 entries, ≤80 char prompt
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/voice-persona/render" \
  -d '{
    "inputs": { "concept": "the word for a baby cat", "conceptType": "vocabulary" },
    "ctxOverrides": { "difficultyOffset": -2 }
  }' | jq '{
    diff: .data.meta.difficultyUsed,
    hasRecognition: (.data.system | contains("Recognition-level")),
    hasTwoOrThree: (.data.system | contains("2 or 3"))
  }'
# expect: {diff:"easy", hasRecognition:true, hasTwoOrThree:true}

# Hard — 4–5 entries, technical + phonetics
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/voice-persona/render" \
  -d '{
    "inputs": { "concept": "the word for how plants make food", "conceptType": "factual" },
    "ctxOverrides": { "difficultyOffset": 2 }
  }' | jq '{
    diff: .data.meta.difficultyUsed,
    hasTransfer: (.data.system | contains("Transfer-level")),
    hasFourOrFive: (.data.system | contains("4 or 5"))
  }'
# expect: {diff:"hard", hasTransfer:true, hasFourOrFive:true}
```

### Age-profile cascade — 4 vs 6 vs 8 (Dashy-voice calibration)

```bash
for AGE in 4 6 8; do
  echo "=== age $AGE ==="
  curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "$BASE/dev/skills/voice-persona/render" \
    -d "{
      \"inputs\": { \"concept\": \"naming animals\", \"conceptType\": \"vocabulary\" },
      \"ctxOverrides\": { \"ageYears\": $AGE, \"progressionDelta\": 0, \"difficultyOffset\": 0 }
    }" | jq '{age: .data.meta.ageProfileUsed, marker:
      (if .data.system | contains("picture-first") then "age-4 / picture-first"
       elif .data.system | contains("early reader") then "age-6 / early reader"
       elif .data.system | contains("fluent reader") then "age-8 / fluent reader"
       else "MISMATCH" end)}'
done
# expect: {age:4, marker:"age-4 / picture-first"}
#         {age:6, marker:"age-6 / early reader"}
#         {age:8, marker:"age-8 / fluent reader"}
```

### Strict-schema rejection — missing input + unknown field

```bash
# Missing required input → 400
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/voice-persona/render" \
  -d '{ "inputs": { "concept": "x" } }' -w '\n%{http_code}\n'
# expect: 400 (missing "conceptType")

# Unknown ctxOverrides key → 400
curl -s -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$BASE/dev/skills/voice-persona/render" \
  -d '{
    "inputs": { "concept": "x", "conceptType": "vocabulary" },
    "ctxOverrides": { "hackField": 1 }
  }' -w '\n%{http_code}\n'
# expect: 400
```

### Hot reload (dev-only)

```bash
curl -s -XPOST -H "Authorization: Bearer $TOKEN" "$BASE/dev/skills/voice-persona/reload" | jq '.data'
# expect: { reloaded: "voice-persona", at: "<iso timestamp>" }
```

### Validator sanity — run the Zod schema directly

From a REPL or `tsx` script:

```ts
import { voicePersonaOutputSchema } from './src/services/skills/validators/voicePersona';

// Happy path — medium difficulty, 3 expectedResponses, no phonetics
voicePersonaOutputSchema.parse({
  title: 'Mammal word',
  promptText: "I learned a word today for an animal that gives milk to its babies — but I can't remember it. Do you?",
  expectedResponses: ['mammal', 'a mammal', 'mammals'],
  celebration: "Yes! I was hoping you'd remember it.",
  retryHint: "Hmm, that's not the one — I meant an animal that feeds milk to babies.",
  conceptSummary: 'A mammal is an animal that feeds milk to its babies — the child named the category aloud.',
});
// => no throw

// Should throw — voice-of-god praise in celebration
voicePersonaOutputSchema.parse({
  promptText: "I wonder what we call a baby cat — can you tell me?",
  expectedResponses: ['kitten', 'a kitten'],
  celebration: "Yes! You got it! Good job!",   // <-- banned
  retryHint: "Hmm, that's not the one — let me think again.",
  conceptSummary: 'The word for a baby cat is kitten.',
});
// => ZodError: celebration must not contain voice-of-god praise "you got"
//               celebration must not contain voice-of-god praise "good job"
```

---

## Pipeline-tab walkthrough (voice atoms now light up green)

Before this run, `card.type === 'voice'` atoms fell through to the legacy inline voice branch at `cardGenerator.ts:432-438` and the Pipeline tab showed them with `skillEngineUsed: false` + a `legacy-inline-voice` tag. After this run, voice atoms render the full atomic telemetry the other skills already had:

1. Author a lesson through the Dev Console pipeline tab (use any existing `createLesson` path — S12-09's authoring UI lands next, but the dev-preview endpoint works today).
2. Pick a topic with a vocabulary-recall concept (e.g., "classifying mammals" produces at least one `voice` atom via curriculum-architect's Stage-3 decomposition).
3. Watch the voice atom's pill populate:
   - **`skillEngineUsed: true`** (previously `false` with a `legacy-inline-voice` tag).
   - **`skill: voice-persona`** — clickable, expands into the rendered system + user prompt.
   - **`validator: ✓ attached`** — green chip.
   - **`validatorStatus: ok`** (or `retry-ok` if the LLM violated a Dashy-voice gate on first pass).
4. On a Zod-retry case (Dashy-voice violation on first pass — e.g., LLM emitted "Good job!" in celebration), the pill reads `retry-ok` and the trace expands into:
   - Attempt 1 raw response (with the Dashy-voice rejection message inlined).
   - Attempt 1 Zod issues array (e.g., `celebration must not contain voice-of-god praise "good job"`).
   - Attempt 2 raw response (passes).
   - `retryCount: 1`.
5. On a `retry-failed` case (two consecutive Dashy-voice violations), the pill reads `validation-failed` and the card generator falls back to the legacy voice path — same contract S10-12 established. Extremely rare in practice; if the LLM is mis-tuning the Dashy voice twice in a row, the prompt needs a revision.

---

## Quick-start runbook (bang's Mac)

```bash
cd ~/Code/Novai/src/Backend

# 1. Pull. No new deps, no new migrations, no new env vars.
git pull

# 2. Run the three voice-persona suites (should complete in <1s total)
npx vitest run voicePersonaValidator voicePersonaRouter skillEngine
#   expect: 106 passing, 0 failing (51 validator + 7 router + 48 engine).

# 3. Full suite sanity pass — baseline after S12-05 was 763 pass; S12-06 adds 60 more.
#    Single pre-existing failure remains: sprint6.test.ts SPARKY_SYSTEM_PROMPT (S11-09 → S12-08 carry-in).
npm test
#   expect: 823 pass / 1 fail

# 4. Boot the server — the registry now loads FOUR skills plus curriculum-architect (5 total).
npm run dev
#   expect log: "SkillRegistry loaded: curriculum-architect v0.1.0, experiment-designer v0.1.0, quiz-maker v0.1.0, story-writer v0.1.0, voice-persona v0.1.0"

# 5. Open the Dev Console Skills tab
#    → http://localhost:3000/dev/dev-pipeline.html#skills
```

If boot fails with a SkillRegistry error, the error message will name the file (`defs/voice-persona/<file>` or `validators/voicePersona.ts`) and the Zod / Handlebars failure path.

### Prerequisites bang must run on his Mac

```bash
# Sandbox can type-check + run vitest but cannot boot the Dev Console UI, run
# the iPad simulator, or listen to TTS output. The following steps land on
# the Mac.

# 1. Skills tab — five entries listed; voice-persona row shows a green 'val'
#    badge (validator attached). Dry-run render with difficultyOffset
#    -2 / 0 / +2 cycles through the easy/medium/hard shape markers in the
#    system prompt.

# 2. TTS audition — feed a few rendered voice-persona outputs into the
#    same TTS voice the iPad uses. Listen for Dashy's tone. Does it sound
#    like Dashy from S11-13's chat? If yes, the validator gates are doing
#    their job. If no, the prompt needs refinement (Dashy-voice rules are
#    enforced but voice *personality* beyond the rules is a content concern
#    that may still drift).

# 3. Pipeline tab — author a lesson whose curriculum-architect decomposition
#    includes a voice atom. Confirm the atom pill shows skillEngineUsed=true,
#    skill=voice-persona, validator=✓ attached, validatorStatus=ok.
#    Compare to a pre-S12-06 seed lesson — the voice pill was previously
#    gray with a 'legacy-inline-voice' tag.

# 4. End-to-end iPad render — no iOS changes this run. The existing
#    VoiceCardView decoder already expects card.content.promptText +
#    expectedResponses which is exactly what the new buildCardFromSkillOutput
#    emits. Verify: voice card appears → TTS speaks the promptText →
#    child responds aloud → speech recognition matches against
#    expectedResponses → correct match plays celebration via TTS.

# 5. S12-17 voice-consistency audit prep — voice-persona/prompt.md is now
#    the single-sourced-truth for Dashy's character voice. When S12-17 runs,
#    the audit compares this prompt against DashyView chat (S11-13),
#    meetDashyPage onboarding (S11-17), and DashyHintSheet. Divergences
#    get documented + either hoisted into a shared reference or explicitly
#    called out per surface.
```

---

## Retired debt

This story closes the **third and last** carry-from-S10 CE-epic debt (`voice-persona` was deferred from S10 alongside `experiment-designer` and `curriculum-architect` to keep S11 UX-pure). The legacy inline voice branch at `cardGenerator.ts:432-438` is now dead code for atoms routed through the skill-engine path.

**All five card types now skill-engine-native:**

- `story-writer` retired `generateStoryCard` at S10-R4.
- `quiz-maker` retired `generateQuizCard` at S10-07.
- `experiment-designer` retired `generateExperimentCard` at S12-04.
- `curriculum-architect` retired the legacy heuristic decomposer at S12-05 (env-gated; fallback remains for `SKILL_ENGINE_STAGE3=false` A/B).
- `voice-persona` retired the inline voice branch at S12-06 (this run).

The legacy paths remain physically in the codebase as dead code for two sprints of migration safety margin; removing them is S14+ work once the skill-engine path has proven stable under touch-test load.

**Cross-cutting benefits realized with CE close:**

- Every card type supports per-skill Zod retry-on-validation (closes the S9-07 carried debt).
- Dev Console Pipeline tab shows full `skillEngineUsed: true` telemetry for every atom of every card type.
- Dashy's voice is now encoded as a Zod contract, not a prose guideline — a structural enforcement point the S12-17 audit can compare surface-by-surface against.
- S12-09's Author Lesson tab can pre-commit to the 5-modality matrix without reserving fallback paths for "coming soon" card types.

**Drift caught + fixed in R5** (both content-layer, not architectural): (a) Handlebars partial `{{> styles}}` doesn't exist — the registry registers `styles.md` as `styleExamples` (name-drift inherited from S10-R4 registry.ts). Fixed by aligning to `{{> styleExamples}}`, which is what experiment-designer's prompt.md also uses. (b) Handlebars helper `{{truncate inputs.lastStoryExcerpt 400}}` doesn't exist — experiment-designer's prompt.md uses the raw `{{inputs.lastStoryExcerpt}}` because the pipelineOrchestrator truncates upstream before reaching the skill. Fixed by removing the helper call.

---

## What's next

The CE-epic close unblocks the MVP epic cleanly. Next stops:

1. **S12-07 `filepath rename` + S12-08 `wire-literal rename`** — RN epic closes. `services/sparky/` → `services/dashy/`, `/sparky/chat` → `/dashy/chat`, `role == "sparky"` → `role == "dashy"` in the ChatMessage discriminant. Single-coordinated-deploy because bang owns both client and server. After this, `grep -ri sparky` returns zero hits anywhere in the codebase (outside `docs/sprint-runs/` where historical notes stay intact).
2. **S12-09 Dev Console — content authoring surface** — the "Author Lesson" tab lands. Form inputs for title / description / topic / age-profile / difficulty / optional card-type sequence; submit kicks off the full skill-engine pipeline (Stage 3 curriculum-architect + Stage 4 per-atom skills); SSE stream lights up the Pipeline tab atom-by-atom; created lesson persists to dev DB; iPad picks it up on pull-to-refresh. This is the story that makes the touch-test loop real.
3. **S12-10 seed — 3 real lessons** — using S12-09, author three lessons end-to-end covering all five card types. First real test of the 5-modality skill-engine under authored-content load.
4. **S12-11 touch test — bang's kid runs the demo loop** — the actual point of the sprint. All CE-epic work has been in service of getting to this story.
5. **S12-17 Dashy voice-consistency audit** — this is the planned cross-surface audit of Dashy's character. The `voice-persona/prompt.md` + `voicePersona.ts` validator are now the single-sourced-truth; S12-17 compares against DashyView chat, meetDashyPage onboarding, DashyHintSheet, cross-references the Zod gates, and either hoists the character definition into a shared reference or documents per-surface divergence.

---

## Cross-references

- Sprint 12 tracker: [docs/SPRINT-12-tracker.md](../SPRINT-12-tracker.md) — CE Epic close-out note
- Skill-engine kickoff: [docs/sprint-runs/S10-skill-engine-kickoff.md](./S10-skill-engine-kickoff.md)
- Prior skill runs: [S10-06 story-writer](./S10-skill-engine-s10-06.md), [S10-07 quiz-maker](./S10-skill-engine-s10-07.md), [S10-12 orchestrator + retry](./S10-skill-engine-s10-12.md), [S12-04 experiment-designer](./S12-04-experiment-designer.md), [S12-05 curriculum-architect](./S12-05-curriculum-architect.md)
- Engine source: `src/Backend/src/services/skills/{types,loader,progression,registry}.ts`
- Validator registry: `src/Backend/src/services/skills/validators/{index,voicePersona}.ts`
- Voice-persona definition: `src/Backend/src/services/skills/defs/voice-persona/*`
- Router wiring: `src/Backend/src/services/pipeline/skillRouter.ts` (SKILL_MAX_TOKENS + SKILL_TO_MODEL tables, `buildSkillInputs` + `buildCardFromSkillOutput` branches)
- CardContent shape: `src/Backend/src/services/pipeline/cardGenerator.ts` (interface definition at lines 46–90)
- Tests: `src/Backend/tests/{voicePersonaValidator,voicePersonaRouter,skillEngine}.test.ts`
- iOS consumer (unchanged): `src/Apps/NovaKids/Sources/Views/Flipbook/VoiceCardView.swift` — already decodes `card.content.promptText` + `.expectedResponses` which is what the new `buildCardFromSkillOutput` emits
- Dashy cross-surfaces for S12-17: `DashyView.swift` (chat), `DashyViewModel.swift` (chat state), `DashyCharacterView.swift` (avatar), `DashySpeechBubble.swift` (bubble component), `DashyHintSheet.swift` + `DashyHintButton.swift` (hint surface), `OnboardingView.swift` line 94–126 (meetDashyPage)
