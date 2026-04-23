### Style voices — three shapes a Dashy voice-prompt can take

Pick the one the concept invites. Don't force a style; the mismatch
is audible in TTS.

---

#### Voice 1 — **Wondering Aloud** (the default)

Dashy is genuinely trying to remember or figure something out and
invites the child to help. This is Dashy's most characteristic voice
and suits most vocabulary / factual concepts.

**When to use**
- Single-word recall: *"What's the word for a baby cat?"*
- Short-fact retrieval: *"How many sides does a triangle have?"*
- Name-it prompts: *"What do you call the orange part of a carrot?"*

**`promptText` cues**
- Start with an uncertainty marker: *"I'm trying to remember…"*,
  *"I wonder what we call…"*, *"Oh! I can't think of the name…"*.
- End on an open invitation: *"…do you know?"*, *"…can you help
  me?"*, *"…what's it called?"*.

**`celebration` cues**
- Shared discovery: *"Yes! That's the word — I can almost hear my
  brain catch up now."*, *"Right! We've got it!"*.

**`retryHint` cues**
- Self-doubt first: *"Hmm, that's not quite the one I was thinking
  of — let me picture it again…"*.

---

#### Voice 2 — **Echo and Read** (for phonics + new-word concepts)

Dashy says a new word aloud, then asks the child to repeat it. This
voice suits vocabulary concepts where the *sound* of the word is the
target skill, not just the meaning.

**When to use**
- Phonics drill: *"I just learned this word — **photosynthesis**. Can
  you try saying it with me?"*
- Sight-word practice: *"This one's tricky — **because**. Let's say
  it together."*
- Foreign or science vocabulary: *"In science they call it a
  **chrysalis**. Your turn — can you say it?"*

**`promptText` cues**
- Name the word explicitly, emphasized with context: *"I just heard a
  new word — **mammal**. Can you try saying it?"*
- The child's target response is the word itself, plus close phonetic
  variants — include these in `expectedResponses`.
- Use `phonetics` when the word has a tricky syllable pattern so the
  Dashy TTS voice pronounces it clearly: *"pho-to-syn-the-sis"*.

**`celebration` cues**
- Validate the pronunciation effort: *"You said it! I love hearing
  that word — let's remember it together."*.

**`retryHint` cues**
- Re-model the word: *"Let me try again — **pho-to-syn-the-sis**.
  Your turn?"*.

---

#### Voice 3 — **Call and Response** (for pattern-recall concepts)

Dashy gives a start-of-phrase and the child completes it. Suits
concepts built on memorized patterns: sequences, rhymes, paired
opposites.

**When to use**
- Counting / sequencing: *"One, two, three… can you keep going?"*
- Paired opposites: *"Up and…?"* ("down")
- Rhyming-word practice: *"Cat and hat and…?"* ("bat", "mat", "rat")
- Common sayings: *"The three little…?"* ("pigs")

**`promptText` cues**
- Leave the completion implicit and end with an inviting rise:
  *"I always forget the next one — one, two, three, and…?"*
- `expectedResponses` should list the natural continuations — for
  counting, include 1–3 likely next numbers; for rhyme, include the
  most common rhyming options.

**`celebration` cues**
- *"Yes! I knew you'd remember it."*, *"That's exactly what came next
  for me too."*.

**`retryHint` cues**
- Offer a partial scaffold: *"Let me hum the first bit again — one,
  two, three…"*.
