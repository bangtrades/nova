### Difficulty: easy — 3 atoms, linear chain

The minimum viable lesson. Three atoms in a strict linear sequence:
hook → teach → check. Every atom depends on the previous one; there
are no parallel strands, no synthesis. This is the difficulty to
reach for when the child is meeting the topic for the first time,
or when recent engagement data suggests the child is tired / frayed
/ struggling. A well-designed easy lesson still teaches *one thing
the child didn't know before* — it just teaches exactly one thing.

**Counts**

- `atoms.length` = **3** (exactly).
- Sequence: `atom-1` → `atom-2` → `atom-3`, strict chain.

**Strategy distribution**

- `atom-1`: **narrative** (or `explanation` if the topic has no
  story).
- `atom-2`: **explanation** (the core teach).
- `atom-3`: **quiz** (recognition-level, 3 options).

**Card-type diversity at easy**

- At least **2** distinct card types. A 3-atom lesson with strategies
  narrative → explanation → quiz produces card types
  story → concept → quiz — that's 3 card types, which exceeds the
  minimum.
- If the opener is an `explanation` (no story), the card types
  collapse to concept → concept → quiz — that's only 2, which is
  still valid, but rework the opener into narrative if you can so
  the lesson doesn't feel monotone.

**Prerequisite graph at easy**

- `atom-1.prerequisites = []`
- `atom-2.prerequisites = ["atom-1"]`
- `atom-3.prerequisites = ["atom-1", "atom-2"]` (the quiz probes
  what both earlier atoms taught)

**What easy is for**

- A child meeting the topic for the first time.
- A child whose recent sessions have a lot of wrongs or aborts —
  the system drops difficulty to rebuild confidence.
- A parent-requested "short lesson" shortcut.

**What easy is NOT for**

- Review sessions on a topic the child has already seen — those
  should be medium or hard so the child stretches.
- Topics with genuinely complex causal structure (evolution, food
  webs, seasons) — at easy you are choosing a *narrower slice* of
  those topics, not squishing the whole thing into 3 atoms.

**Scoring at easy**

- Engagement scores cluster 0.7–0.9 (nothing flat — a 3-atom lesson
  can't afford a boring atom).
- Learning-value scores cluster 0.7–0.9 (every atom is carrying
  weight when there are only three of them).
