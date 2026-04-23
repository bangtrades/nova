### Difficulty: medium — 1–2 word target, 3–4 accepted answers

A recall card with a mild phonetic or contextual stretch. The target
word is either newly-learned in this lesson OR requires the child to
pick it out from a short-list of similar concepts. Include phonetic
variants in `expectedResponses` so near-misses still count.

**Counts**
- `expectedResponses.length` = **3 or 4**.
- Each entry = **1 to 3 words**.
- `promptText` ≤ **110 chars** (up to 2 short sentences).
- `celebration` ≤ **60 chars**.
- `retryHint` ≤ **70 chars**.

**Cognitive load**
- Application-level. The child has to *produce* the word, not just
  recognize it. The word was introduced earlier in the session; now
  it's being recalled.
- One mildly phonetically-tricky word is allowed (2–3 syllables).
  Include `phonetics` to help the TTS voice pronounce it cleanly.
- One common mispronunciation belongs in `expectedResponses` — the
  matcher should accept "fo-to-sin-thesis" for "photosynthesis" at
  medium difficulty. Effort counts.

**Style — Wondering Aloud or Echo-and-Read**
- If the concept is a *newly-learned noun*, lean **Echo-and-Read**:
  Dashy names the word, the child repeats.
- If the concept is *recall from a minute ago*, lean **Wondering
  Aloud**: Dashy admits she's blanking and asks for help.

**Bin design for medium**
- The `promptText` can include a short definition or context clue:
  *"From the story — the word for an animal that only eats plants.
  What was it?"*
- `retryHint` should offer a narrower clue, not re-state the whole
  prompt.

**Avoid at medium**
- 4+ syllable words (that's hard).
- Multi-part answers ("*name two mammals*" — that's hard too).
