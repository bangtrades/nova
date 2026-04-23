### Difficulty: hard — technical vocabulary or compound-phrase target, 4–5 accepted answers

A recall card that asks the child to *produce* a technical or
compound-phrase answer from contextual clues alone. The child has met
the concept in this lesson (or a prior one) but the prompt does not
contain the target word — only a scenario or definition that points
to it.

**Counts**
- `expectedResponses.length` = **4 or 5**.
- Each entry = **1 to 5 words**.
- `promptText` ≤ **180 chars** (up to 2 longer sentences).
- `celebration` ≤ **80 chars**.
- `retryHint` ≤ **80 chars**.

**Cognitive load**
- Transfer-level. The child has to apply their understanding to
  produce the correct term without being handed any phonetic hint
  in the prompt.
- Target words are typically 3–5 syllables and often include
  compound terms ("*warm-blooded*", "*photosynthesis*", "*carnivore*",
  "*evaporation*", "*gravitational*").
- Include the technical term + a more-casual phrasing + one close
  variant + one common mispronunciation in `expectedResponses` so
  the matcher is generous without being sloppy.

**Style — Wondering Aloud or Call-and-Response**
- **Wondering Aloud** is the default — Dashy describes the concept
  and asks for the word: *"I was thinking about how plants make
  their own food from sunlight. There's a big word for that — I
  can't remember it. Can you?"*
- **Call-and-Response** works when the concept is a pattern the
  child has memorized: *"One, two, three, five, seven, eleven —
  what are these numbers all called together?"* → "primes".

**Bin design for hard**
- `promptText` provides the *definition without the word*. Never
  hand the child the word in the prompt.
- `phonetics` is recommended for 4+ syllable target words so Dashy's
  TTS voice articulates them cleanly: *"pho-to-syn-the-sis"*,
  *"e-va-po-ra-tion"*.
- `retryHint` offers a narrower clue: first sound, domain, or one
  of the target's constituent morphemes (*"Close — it starts with
  'photo-', like 'photograph'…"*).

**Avoid at hard**
- Words the child has not met in this lesson or a prior one.
- Concepts without a clean single-term answer (open-ended explanations
  belong in story cards).
