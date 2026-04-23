### Topic guidance — which concepts suit voice, which don't

Voice-mode cards are the right tool when **the concept's grasp
signal is the child speaking aloud**. They are the wrong tool when the
concept needs a diagram, a manipulation, or a multi-step reasoning
chain. Match the concept to the card type, not the other way around.

---

#### Good fits for voice

- **Single-word vocabulary recall** — the child has met a word
  (in a story, in onboarding, in a prior card) and voice-mode is how
  they prove they can produce it. *"What's the word for a baby cat?"*
- **Short-fact retrieval** — a fact that fits in 1–5 spoken words.
  *"How many legs does a spider have?"*
- **Name-it prompts** — given a described object/animal/concept, say
  the noun. *"I'm thinking of the orange thing rabbits love to eat
  — what's it called?"*
- **Phonics drill for newly-met words** — the child says the word
  aloud and the matcher confirms the pronunciation landed.
- **Counting / sequencing / pattern completion** — child fills in the
  next-in-sequence aloud. Works up to about 5–7 items before
  attention wavers.
- **Paired opposites + rhymes** — short, patterned, closed-answer.
- **Common sayings or short phrases the child has heard repeatedly**
  — *"The wheels on the bus go…?"*

---

#### Bad fits for voice

- **Concepts that need a picture to grasp** — shapes, colors, maps,
  diagrams, body parts in context. These are better as story or
  experiment cards. Don't ask a voice-mode card for *"what color is
  the ocean?"* when the child's answer depends on what picture Dashy
  is looking at that they can't see.
- **Multi-step reasoning** — "*why does ice float?*" is a story card
  or a short explanation, not a voice prompt. Voice-mode answers are
  short phrases; long explanations don't fit.
- **Comparative judgments with >2 options** — *"which is biggest,
  the Sun, the Earth, or the Moon?"* works, but *"rank these five
  planets by size"* does not. Voice is for single-point answers.
- **Subjective or open-ended prompts** — *"what's your favorite
  animal?"* has no `expectedResponses` you can whitelist, so the
  matcher has nothing to compare against. Skip.
- **Abstract causal concepts for ages 4–6** — *"why do leaves change
  color?"* is too open to match on a whitelist. An older child (8+)
  might give a crisp answer; a younger child will ramble in a way
  the matcher can't catch. Save abstract causes for story/quiz.

---

#### Choosing `expectedResponses`

Cover the most natural phrasings a child this age will actually say.
Three-to-five entries is the sweet spot.

**Include:**
- The single-word answer + the natural short phrase ("kitten", "a
  kitten", "a baby cat").
- Singular + plural if both are correct ("spider" + "spiders").
- One common mispronunciation that's close enough to still count
  (e.g. "fo-to-sin-thesis" for "photosynthesis" at age 6 —
  celebrating effort beats punishing phonetic near-misses).

**Exclude:**
- Obvious-wrong answers (never whitelist a wrong answer "to be nice").
- Answers that only sound-similar but mean something else.
- Filler-word-only responses ("um", "I don't know") — those are a
  legitimate retry trigger, not a match.
