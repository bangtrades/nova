### Difficulty: hard — 5–6 atoms, richer arc with synthesis

The lesson the child earns by mastering the same topic at medium.
Five or six atoms, at least one **synthesis** atom that combines two
earlier strands, and at least one **experiment** or **voice** card
to keep the session physical. This is where the decomposition
stretches beyond "teach a fact" into "teach a model the child can
use on a novel case."

**Counts**

- `atoms.length` = **5** (typical) or **6** (when the topic
  genuinely has that much to teach — don't pad).
- Sequence: linear in *card order*, but the prerequisite graph may
  have one fork-and-rejoin where `atom-4` synthesises `atom-2` and
  `atom-3`.

**Strategy distribution**

- `atom-1`: **narrative** or **comparison** (pick whichever fits
  the topic).
- `atom-2`: **explanation** (first strand).
- `atom-3`: **explanation**, **comparison**, or **cause_effect**
  (second strand — often parallel to atom-2, not sequential).
- `atom-4`: **explanation** (synthesis — combines strands), or
  **experiment** (transfer-level sort on the combined rule).
- `atom-5` (or `atom-6` if 6-atom): **experiment** or **voice**
  (the voice option is age-8 only, and never more than once per
  lesson).
- Last atom: **quiz** (transfer-level, 5 options, at least one
  distractor probes a real misconception).

**Card-type diversity at hard**

- At least **3** distinct card types across the 5–6 atoms. Typical
  mixes that work well:
  - story → concept → concept → experiment → quiz (4 types — ideal)
  - story → concept → concept → concept → experiment → quiz (4
    types, when the topic has 3 teachable strands)
  - story → concept → concept → concept → voice → quiz (4 types, age
    8 only, for spoken/linguistic topics)
- Monotone stacks (story → concept × 3 → quiz) are NOT valid at
  hard — rework until at least 3 card types are present.

**Prerequisite graph at hard (the fork-and-rejoin)**

- `atom-1.prerequisites = []`
- `atom-2.prerequisites = ["atom-1"]`
- `atom-3.prerequisites = ["atom-1"]` ← *parallel strand, not
  sequential*
- `atom-4.prerequisites = ["atom-2", "atom-3"]` ← *synthesis*
- `atom-5.prerequisites = ["atom-4"]` (or `["atom-2", "atom-3"]`
  if the experiment applies the strands before synthesis)
- `atom-N.prerequisites = ["atom-2", "atom-3", "atom-4", "atom-5"]`
  (the final quiz probes everything)

**What hard is for**

- The child is demonstrating above-profile mastery (engagement
  profiler's progressionDelta > 0.5).
- The topic has been touched before at easy or medium in prior
  sessions — this is the depth pass.
- Parent has flagged a topic as high-priority in focus topics.

**Scoring at hard**

- Engagement scores span 0.55–0.95 — a hard lesson can afford one
  less-engaging atom because the density carries.
- Learning-value scores: the synthesis atom (`atom-4` typically)
  should be the single highest learning-value atom in the lesson
  (0.9–0.95). The experiment and quiz reinforce (0.8–0.9). The
  opener can be lower (0.5–0.65) — it's pulling the child in, not
  cementing the claim.

**Guard-rails at hard**

- Do not skip the synthesis. A hard lesson without a synthesis is
  just a medium lesson padded to 5 atoms.
- Do not use `voice` as synthesis — synthesis is written/read, not
  spoken, at this stage of the product.
- Do not chain more than two `cause_effect` atoms — the child
  loses the thread.
