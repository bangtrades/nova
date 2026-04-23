### Style voices — pick the frame that matches the concept

Three voices. Pick the one the concept invites naturally, don't force.

---

#### Voice 1 — **Sort by property** (the classic)

The child is asked to group items by a single shared attribute. Bins
are the attribute values.

**When to use**
- Any concept built around a visible or learned property:
  alive/nonliving, floats/sinks, hot/cold, solid/liquid/gas, opaque/
  transparent, magnetic/not, herbivore/carnivore/omnivore.

**Voice cues**
- Title names the property: *"Sort by Floating"*, *"Which Ones
  Float?"*, *"States of Matter"*.
- Instructions invite the child to *drag each one to where it
  belongs*. Calm, observational tone.
- Bin labels are the property values themselves.
- `conceptSummary` reinforces the defining test: *"Things float when
  they're less dense than water."*

---

#### Voice 2 — **Sequence** (order the steps)

The child is asked to group items by their position in a process or
timeline. Bins are ordered stages.

**When to use**
- Concepts with a natural before/during/after shape: water cycle,
  plant growth (seed → sprout → flower → fruit), life cycle of a
  butterfly, the day/week/year, how bread is made, frog life cycle.
- Best for `conceptType === 'process'` and some `factual` concepts
  with temporal structure.

**Voice cues**
- Title names the progression: *"Order the Seasons"*, *"From Seed to
  Flower"*, *"Life of a Frog"*.
- Instructions are gentle and narrative: *"These all happen to a
  butterfly as it grows. Put each picture into the right stage."*
- Bin labels are stage names: *"Egg"*, *"Caterpillar"*, *"Chrysalis"*,
  *"Butterfly"*. At easy/medium keep to 2 stages; hard can use 3.
- `conceptSummary` tells the story: *"A butterfly starts as an egg,
  becomes a caterpillar, then a chrysalis, then finally a butterfly."*

**Guard-rail:** Sequence sorts still obey the exactly-one-bin rule.
A caterpillar goes in *"Caterpillar"*, not *"Egg"* or *"Butterfly"*.
Don't introduce items that span stages.

---

#### Voice 3 — **Cause → effect** (why did this happen?)

The child is asked to match outcomes to their causes, or actions to
their consequences. Bins are causes; items are effects (or vice versa,
whichever makes the child's mental move feel natural).

**When to use**
- Concepts with strong causal structure: why things sink, what
  weather each cloud brings, what happens when you mix colors, which
  action wastes energy vs. saves it, which food groups give which
  benefits.
- Best for `conceptType === 'causeEffect'`.

**Voice cues**
- Title names the causal frame: *"What Causes What?"*, *"Which Clouds
  Bring Rain?"*, *"Save or Waste?"*.
- Instructions are curious: *"Each of these things happens for a
  reason. Drag each one to the reason that best explains it."*
- Bin labels are short cause statements: *"Saves energy"*, *"Wastes
  energy"*. *"Brings rain"*, *"Means sunny"*.
- `conceptSummary` names the rule: *"When we turn off lights we're
  not using, we save the energy that would have been needed to keep
  them on."*

---

### A voice note that applies to all three

The sort card never tells the child which bin is *right* before
they drop — the drag-and-drop action IS the answer. So the
instructions set up the task but never leak the classification.
*"Some of these float and some sink"* is fine. *"The apple floats"* is
not — that's the answer.
