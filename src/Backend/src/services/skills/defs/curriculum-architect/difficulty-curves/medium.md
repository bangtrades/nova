### Difficulty: medium — 4 atoms, hook + two-teach + check

The standard lesson shape. Four atoms: a hook, two teaching atoms
that carry the sub-concepts, and a check. The two teaching atoms
can be parallel (two facets of the same concept) or sequential
(one builds on the other) — pick based on the topic's natural
structure.

**Counts**

- `atoms.length` = **4** (preferred) or **5** (if the topic
  genuinely has four sub-concepts worth teaching — don't force a
  fifth atom just to hit 5).
- Sequence: `atom-1` → `atom-2` → `atom-3` → `atom-4` (+ `atom-5`
  only if warranted).

**Strategy distribution**

- `atom-1`: **narrative** (preferred) or **comparison** / **explanation**.
- `atom-2`: **explanation** (first core teach).
- `atom-3`: **explanation**, **comparison**, or **experiment** — pick
  the one that best carries the second strand of the concept.
- `atom-4`: **quiz** (application-level, 4 options) — or, if
  `atom-3` was already an experiment and the concept doesn't need
  a quiz, an additional **explanation** atom wrapping the lesson,
  but then you still need a quiz as `atom-5`.

**Card-type diversity at medium**

- At least **3** distinct card types across the 4 atoms. Typical
  mixes that work:
  - story → concept → concept → quiz (3 types — borderline; prefer
    swapping atom-3 to experiment)
  - story → concept → experiment → quiz (4 types — ideal)
  - concept → concept → experiment → quiz (3 types — OK if topic
    truly has no narrative hook)
- A 4-atom lesson that ends up as story → concept → concept →
  concept → quiz (when forced to 5) is flat — restructure.

**Prerequisite graph at medium**

- `atom-1.prerequisites = []`
- `atom-2.prerequisites = ["atom-1"]` (second atom needs the hook
  as framing)
- `atom-3.prerequisites = ["atom-2"]` (most of the time — OR
  `["atom-1"]` if `atom-3` is a parallel strand, not a sequential
  build)
- `atom-4.prerequisites = ["atom-2", "atom-3"]` (the quiz probes
  both teaching atoms)

**What medium is for**

- The default path. Most lessons should produce medium
  decompositions. The ranker will escalate to hard on topics the
  child has mastered easy on, and drop to easy on topics the child
  is meeting cold.

**Scoring at medium**

- Engagement scores span a broader range than at easy — the middle
  explanation atoms can score 0.6 without hurting the lesson,
  because the hook atom and the experiment/quiz atoms carry the
  energy.
- Learning-value scores: the two teaching atoms should be the
  highest in the lesson (0.85–0.95). The hook is lower (0.5–0.7),
  the quiz reinforces (0.8–0.9).
