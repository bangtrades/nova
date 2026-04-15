# Nova: AI-Native Platform Vision

**Date:** April 14, 2026
**Author:** bang
**Status:** Strategic — informs all Phase 2+ architecture decisions

---

## The Core Insight

Every kids' education app today is a content library with an LLM bolted on. ABCmouse has 10,000 static activities. Homer uses AI for voice but serves the same curriculum to every child. Even if OpenAI shipped "ChatGPT Kids" tomorrow, it would be a generic chatbot with guardrails — it wouldn't *know* your kid.

Nova is different because **the AI is the product, not a feature of the product.**

Nova is an agentic platform where AI skills generate every piece of content, AI memory learns every child individually, and AI context adapts every interaction in real time. The longer a child uses Nova, the better it gets at teaching *them specifically* — and that's a moat no content library can replicate.

---

## Three Pillars: Skills, Memory, Context

### Pillar 1 — Skills (What the AI Can Do)

Skills are modular capabilities the Nova agent uses to generate content. They're analogous to Claude's skill system — specialized instruction sets that produce specific types of output with consistent quality.

**Content Generation Skills:**

| Skill | What It Produces | Adapts To |
|-------|-----------------|-----------|
| `story-writer` | Narrative cards that teach concepts through stories | Age (vocabulary, sentence length, complexity), interests (dinosaurs → space → code) |
| `quiz-maker` | Multiple-choice and open-ended questions | Difficulty level, demonstrated knowledge gaps, question style preferences |
| `experiment-designer` | Drag-and-drop interactive challenges | Motor skill level, conceptual understanding, attention span |
| `puzzle-crafter` | Logic puzzles, pattern matching, sequencing challenges | Cognitive level, favorite puzzle types, frustration tolerance |
| `game-builder` | Mini-games embedded in lessons (sorting, matching, building) | Speed preferences, competitive vs collaborative style |
| `image-stylist` | Illustrations, character designs, scene compositions | Age-appropriate style (more cartoonish for 4yo, more detailed for 8yo), child's avatar choices |
| `voice-persona` | Sparky's dialogue, tone, vocabulary, humor style | Child's language level, cultural context, conversation history |
| `curriculum-architect` | Learning path sequences, prerequisite mapping, pacing | Demonstrated mastery, parent goals, engagement patterns |

**How skills evolve:**

Phase 1 (launch): Skills are prompt templates with variable slots. The `story-writer` skill has a base prompt like "Write a story for a {age}-year-old about {concept}, using vocabulary appropriate for {reading_level}, incorporating their interest in {interests}."

Phase 2 (6 months): Skills become multi-step chains. The `curriculum-architect` skill analyzes the child's knowledge graph, identifies gaps, generates a lesson sequence, and then invokes `story-writer` + `quiz-maker` + `experiment-designer` to produce each lesson.

Phase 3 (12+ months, future models): Skills become truly agentic. The `curriculum-architect` observes the child's real-time engagement, detects confusion or boredom within a lesson, and dynamically adjusts — swapping a text-heavy card for an interactive one, simplifying language, or pivoting to a related topic the child finds more engaging. This is where models like Mythos change the game — they can maintain coherent multi-session educational arcs while adapting in real time.

**Skill architecture (backend):**

```
/skills/
  /story-writer/
    SKILL.md          ← Instructions, constraints, examples
    /references/
      age-profiles.md ← Vocabulary lists, sentence complexity by age
      topics.md       ← Concept explanations at different levels
      styles.md       ← Narrative styles (fairy tale, adventure, sci-fi, documentary)
  /quiz-maker/
    SKILL.md
    /references/
      question-types.md
      difficulty-curves.md
      misconceptions.md  ← Common wrong answers by age group
  /curriculum-architect/
    SKILL.md
    /references/
      learning-progressions.md  ← What concepts depend on what
      pacing-models.md          ← How fast kids learn at different ages
      engagement-patterns.md    ← Signs of boredom vs flow state
```

This mirrors the exact skill structure we use with Claude — proven, extensible, and each skill can be refined independently based on what works.

---

### Pillar 2 — Memory (What the AI Knows About This Child)

Memory is Nova's deepest moat. It's the difference between "a 6-year-old" and "Dash, who loves robots, struggles with abstract concepts but excels at pattern recognition, has been learning about how computers think for 3 weeks, and just mastered the concept of binary."

**Memory layers:**

```
CHILD MEMORY (persistent, encrypted, COPPA-compliant)
├── Identity
│   ├── Name, age, avatar, stage
│   ├── Language / locale
│   └── Learning style profile (visual / auditory / kinesthetic)
│
├── Knowledge Graph
│   ├── Concepts mastered (with confidence scores)
│   ├── Concepts in progress
│   ├── Concepts not yet introduced
│   ├── Prerequisite chains satisfied
│   └── Misconceptions detected (and corrected)
│
├── Engagement Profile
│   ├── Average session length
│   ├── Time-of-day patterns
│   ├── Card types that hold attention longest
│   ├── Frustration signals (rapid wrong answers, quitting mid-lesson)
│   ├── Flow state signals (fast correct answers, voluntary continuation)
│   └── Topic affinities (ranked by engagement time)
│
├── Interaction History
│   ├── Lessons completed (with scores)
│   ├── Quiz answer patterns (right/wrong by concept)
│   ├── Voice transcripts (what they said to Sparky)
│   ├── Experiment completion patterns
│   └── Badge/trophy achievements
│
└── Parent Guidance
    ├── Target topics ("focus on reading this week")
    ├── Boundaries ("no screen violence, even cartoonish")
    ├── Goals ("get ready for kindergarten math")
    ├── Age adjustment (parent can dial up/down difficulty)
    └── Content approval preferences
```

**How memory deepens over time:**

Week 1: Nova knows age, name, and chosen avatar. Content is generic for age group. Sparky uses default vocabulary.

Month 1: Nova knows the child prefers stories over quizzes, learns better in the morning, loves space topics, and struggles with sequencing tasks. Sparky adjusts: more stories, fewer quizzes, space-themed examples, extra scaffolding on sequencing.

Month 6: Nova has a rich knowledge graph. It knows the child mastered "what is an algorithm" but hasn't connected it to "algorithms in daily life." It generates a lesson that bridges the gap — using the child's love of space to explain how NASA uses algorithms. Quiz questions probe the specific misconception it detected last month.

Year 1+: Nova has a complete learning trajectory. When the child turns 5, it doesn't just bump a difficulty slider — it restructures the entire curriculum to match the new cognitive capabilities, building on everything the child has already learned.

**This is the moat.** If a family leaves Nova for a competitor, they leave behind the AI's understanding of their child. The new app starts from scratch. After 6 months of use, Nova's personalization advantage is so large that switching feels like going backwards.

**Memory architecture (backend):**

```json
// Stored encrypted per child, synced to backend
{
  "childId": "uuid",
  "knowledgeGraph": {
    "concepts": {
      "binary-numbers": { "confidence": 0.85, "lastTested": "2026-04-10", "attempts": 3 },
      "algorithms-intro": { "confidence": 0.92, "lastTested": "2026-04-12", "attempts": 2 },
      "neural-networks": { "confidence": 0.0, "introduced": false }
    },
    "edges": [
      { "from": "binary-numbers", "to": "how-computers-count", "type": "prerequisite" }
    ]
  },
  "engagementProfile": {
    "preferredCardTypes": ["story", "experiment", "quiz"],
    "averageSessionMinutes": 12,
    "topicAffinities": ["space", "robots", "animals"],
    "frustrationThreshold": 3  // wrong answers before disengagement
  },
  "parentGuidance": {
    "currentFocus": "prepare for kindergarten",
    "difficultyAdjustment": 0,  // -2 to +2 from age default
    "contentBoundaries": ["no violence", "emphasize creativity"]
  }
}
```

---

### Pillar 3 — Context (What the AI Knows Right Now)

Context is the real-time state that shapes every interaction. Memory is the child's history; context is this moment.

**Context signals:**

| Signal | Source | How It's Used |
|--------|--------|---------------|
| Time of day | Device clock | Evening → shorter lessons, calmer tone |
| Session duration so far | App timer | >15 min → suggest break, shift to lighter content |
| Last lesson completed | Sync state | Don't repeat; build on it |
| Current streak | Progress tracker | Acknowledge momentum ("3 days in a row!") |
| Recent wrong answers | Quiz history | Adjust next question difficulty down |
| Parent just changed age setting | Companion app event | Regenerate upcoming lessons for new level |
| New URL submitted by parent | Pipeline event | Generate new lesson, notify kid with excitement |
| Child's voice tone (future) | Audio analysis | Detect frustration/excitement, adjust pace |

**Context-driven generation example:**

```
Context: Tuesday evening, 7:15 PM. Dash (age 5) has been in-app for 8 minutes.
Completed 1 lesson today. Last quiz: 4/5 correct (missed "what's an input?").
Parent set focus: "prepare for kindergarten." Interest profile: robots, space.

Agent reasoning:
- Evening + 8 min session → 1 more short lesson, then gentle wrap-up
- Missed "inputs" → generate a concept card specifically about inputs,
  using robots as the example ("What does a robot need to hear from you?")
- Keep it light — story format, not quiz
- Sparky's tone: warm, slightly sleepy ("one more cool thing before bed!")
```

This isn't a static content library selecting from pre-made options. The AI is *composing* this lesson in real time, specifically for this child, at this moment, based on what it knows.

---

## The Grand Architect — Content Intelligence Pipeline

When a parent pastes a URL in the Companion app, they see "generating lesson..." and 60 seconds later their kid has a new lesson. What they don't see is the multi-stage agentic pipeline that made it. This is the heart of Nova's intelligence.

### Pipeline Stages

```
Parent pastes URL
       │
       ▼
┌──────────────────────────────────┐
│  STAGE 1: INTAKE & RESEARCH     │
│  ────────────────────────────    │
│  • Scrape URL content            │
│  • Identify source credibility   │
│  • Extract core topic & claims   │
│  • Research topic depth          │
│    (cross-reference 2-3 sources  │
│     to verify accuracy)          │
│  • Determine subject domain      │
│    (science, tech, math, social) │
└──────────┬───────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  STAGE 2: SAFETY & SUITABILITY  │
│  ────────────────────────────    │
│  • Content safety scan           │
│    - Violence / gore             │
│    - Sexual content              │
│    - Hate speech / discrimination│
│    - Self-harm / dangerous acts  │
│    - Substance abuse             │
│    - Political propaganda        │
│  • Age suitability assessment    │
│    - Conceptual complexity       │
│    - Emotional weight            │
│    - Prerequisite knowledge      │
│  • Parent boundary check         │
│    (does this match their        │
│     content preferences?)        │
│                                  │
│  REJECT → notify parent why      │
│  FLAG → generate but mark for    │
│          parent review            │
│  PASS → continue to Stage 3      │
└──────────┬───────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  STAGE 3: CONCEPT DECOMPOSITION │
│  ────────────────────────────    │
│  • Break topic into 3-6 core    │
│    concepts (teachable atoms)    │
│  • Map against child's knowledge │
│    graph: what do they already   │
│    know? What's new?             │
│  • Identify prerequisite gaps    │
│    (if any, generate a           │
│     bridging mini-lesson first)  │
│  • Rank concepts by:             │
│    - Engagement potential         │
│    - Learning value               │
│    - Connection to existing       │
│      knowledge                    │
│  • Select teaching strategies    │
│    per concept:                   │
│    - Analogy (relate to known)    │
│    - Story (narrative wrapper)    │
│    - Challenge (prove you know)   │
│    - Experiment (build/try)       │
│    - Game (play-based)            │
│    - Visual (show, don't tell)    │
└──────────┬───────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  STAGE 4: CARD GENERATION       │
│  ────────────────────────────    │
│  For each concept, invoke the    │
│  appropriate content skill:      │
│                                  │
│  Concept 1 → story-writer        │
│    "Explain binary through a     │
│     story about a robot          │
│     speaking in beeps"           │
│                                  │
│  Concept 2 → experiment-designer │
│    "Drag binary digits to make   │
│     the number 5"                │
│                                  │
│  Concept 3 → quiz-maker          │
│    "Which of these is binary?"   │
│    (difficulty: age 5, accounting │
│     for this child's quiz        │
│     history)                     │
│                                  │
│  Concept 4 → puzzle-crafter      │
│    "Put these steps in order     │
│     to count like a computer"    │
│                                  │
│  Wrap-up → voice-persona         │
│    Sparky celebration card        │
│    references what was learned    │
└──────────┬───────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  STAGE 5: ASSET GENERATION      │
│  ────────────────────────────    │
│  • Hero image (DALL-E 3)         │
│    style-matched to child's age  │
│  • Card illustrations            │
│  • Audio narration (TTS)         │
│  • Sound effects for interactions│
│  • Upload all to R2 CDN          │
└──────────┬───────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  STAGE 6: QUALITY GATE          │
│  ────────────────────────────    │
│  • Second-pass content review    │
│    (different model evaluates    │
│     output of first model)       │
│  • Fact-check key claims         │
│  • Age-appropriateness recheck   │
│  • Card flow coherence           │
│    (do they build on each other?)│
│  • Readability score vs target   │
│  • FAIL → regenerate flagged     │
│    cards with feedback            │
│  • PASS → publish to child's     │
│    lesson feed                    │
└──────────────────────────────────┘
```

### Teaching Strategy Selection

The Grand Architect doesn't just pick random card types. It has a strategy matrix based on concept type and child profile:

| Concept Type | Best For Visual Learners | Best For Auditory | Best For Kinesthetic | Fallback |
|-------------|------------------------|-------------------|---------------------|----------|
| New vocabulary | Image + definition card | Sparky pronounces + explains | Spelling drag-and-drop | Story with word in context |
| Abstract concept | Analogy illustration | Story narration | Interactive simulation | Step-by-step visual |
| Process/sequence | Flowchart card | Narrated walkthrough | Ordering experiment | Numbered steps with images |
| Comparison | Side-by-side visual | Debate with Sparky | Sorting game | Quiz with contrasting options |
| Cause/effect | Before/after animation | "What happens when..." story | Experiment with variables | Quiz probing prediction |
| Factual knowledge | Infographic card | Sparky trivia game | Matching puzzle | Standard quiz |

The Architect chooses from this matrix based on the child's learning style profile in memory, then the appropriate skill generates the actual content.

### Rejection & Flagging Logic

Not everything a parent submits is appropriate. The pipeline needs clear rules:

**Auto-reject (notify parent why):**
- Content about weapons, violence, substance abuse
- Sexually explicit source material
- Hate speech or discrimination in source
- Content from known misinformation sources
- Topics that require emotional maturity beyond the age group (grief, war, abuse)

**Flag for parent review (generate but hold):**
- Potentially scary content (thunderstorms, predators in nature docs)
- Religious or spiritual content (parents should opt-in)
- Content about death (natural and educational but sensitive)
- News events (factual but may need parent context)
- Content significantly above the child's current level

**Auto-pass:**
- Science, technology, engineering, math (STEM)
- Nature, animals, ecosystems
- Art, music, creativity
- Social skills, emotions, friendship
- History (age-appropriate framing)
- How things work (machines, systems, processes)

---

## Intellectual Property Protection — What's Visible vs Hidden

### The Strategic Principle

Nova's value to parents is the *experience* — their kid is learning, engaged, and growing. Parents don't need to see the machinery. Competitors copying our UI or marketing still can't replicate the intelligence layer.

### What Parents See (Transparent)

| Surface | What It Shows | Why |
|---------|--------------|-----|
| **Knowledge Graph** | Visual map of concepts their child has mastered | Builds trust, justifies subscription, creates "wow" moment |
| **Weekly Report** | Progress summary, strengths, growth areas, recommendations | Proves value, gives parents talking points with their kid |
| **Content Feed** | Lessons appearing in kid's app, matched to their interests | Parent sees their URL turned into a lesson — magical |
| **Difficulty Dial** | "Your child's content is set to Age 5 level" | Control and transparency |
| **Sparky's Personality** | "Sparky remembers your child's favorite topics" | Emotional hook — the AI is their kid's friend |

### What's Hidden (Our IP)

| Layer | What Competitors Don't See | Why It Matters |
|-------|---------------------------|----------------|
| **Skill definitions** | The actual prompt chains, reference files, and strategy matrices inside each skill | These are months of iteration. A competitor can guess we use "an LLM to generate content" but can't reverse-engineer the 50-page `curriculum-architect` skill that plans multi-week learning arcs with prerequisite mapping. |
| **Memory schema** | The knowledge graph structure, engagement profile dimensions, and how they interconnect | Knowing we "personalize" is obvious. Knowing that we track `frustrationThreshold` as a function of `wrongAnswersBeforeDisengagement × timeBetweenAttempts` — that's R&D. |
| **Grand Architect pipeline** | The 6-stage generation pipeline, safety filters, quality gate, teaching strategy matrix | A competitor sees "paste URL, get lesson." They don't see the concept decomposition, multi-model quality gate, or learning-style-aware strategy selection. |
| **Engagement scoring model** | How we measure and predict what content will hold a specific child's attention | We learn from every child what works. This aggregate intelligence is our flywheel — it improves the product for all users but isn't visible to any one user. |
| **Skill evolution data** | Which prompt versions produce better learning outcomes, measured by subsequent quiz performance | We're running continuous A/B tests on our skills. Version 47 of `story-writer` produces 23% better concept retention than version 1. That's our competitive intelligence. |

### Implementation: Opacity by Architecture

The skills live entirely server-side. The iOS app never sees them:

```
Nova Kids iPad                    Nova Backend
──────────────                    ────────────
"Show me a lesson"    ──────►    Grand Architect
                                 ├─ [hidden] Intake & Research
                                 ├─ [hidden] Safety Filter
                                 ├─ [hidden] Concept Decomposition
                                 ├─ [hidden] Skill Selection Matrix
                                 ├─ [hidden] Content Generation
                                 └─ [hidden] Quality Gate
                      ◄──────
"Here's 6 cards with              Only the OUTPUT reaches
 images and audio"                the device — never the
                                  reasoning, prompts, or
                                  decision logic.
```

The app receives finished cards — title, body text, image URLs, audio URLs, quiz options, experiment configs. It has zero knowledge of how they were made. Even if someone decompiled the app, they'd find a generic card renderer, not an AI pipeline.

Memory insights shared with parents are curated summaries — "your child excels at pattern recognition" — not raw data or the algorithms that produced that conclusion.

### When to Reveal (Post-Moat)

Once Nova has 12+ months of engagement data and refined skills, the moat is the data flywheel, not the architecture. At that point, publishing a high-level "how Nova's AI works" blog post or WWDC-style presentation becomes a *marketing advantage* — it positions Nova as the thought leader in AI education and makes competitors look like they're copying, even if they try to build something similar.

Timing: reveal after you have 10,000+ active children and 6+ months of engagement data. Before that, let the product speak for itself.

---

## Competitive Moat Analysis

### Why This Can't Be Copied Quickly

| Moat Layer | Why It's Defensible |
|------------|-------------------|
| **Skill library** | Prompt chains refined through thousands of real kid interactions. Not just "write a story" — it's "write a story that teaches concept X at level Y using interest Z with vocabulary appropriate for demonstrated reading level W." Each skill is months of iteration. |
| **Per-child memory** | Switching cost is enormous. 6 months of Nova means the AI knows your child better than any teacher who sees them 1 hour/week. A competitor starts from zero. |
| **Engagement data flywheel** | Every child interaction improves every skill. Nova learns what *types* of stories hold 5-year-olds' attention, what quiz formats reduce frustration, what pacing keeps kids in flow state. This is aggregate intelligence that improves the product for ALL children. |
| **Parent trust** | Parents see their child's knowledge graph grow. They see Sparky adapting. They see their guidance reflected in content. This builds trust that a generic chatbot can't match. |
| **Content quality over time** | A content library is static — it's done when it ships. Nova's content quality *improves* with every child who uses it, because the skills that generate content are continuously refined. |

### Competitor Comparison

| Feature | ABCmouse | Homer | Khan Kids | ChatGPT Kids (hypothetical) | **Nova** |
|---------|----------|-------|-----------|---------------------------|----------|
| Content | 10K static activities | Static curriculum | Static videos + exercises | Generic chat | **Generated per-child, per-session** |
| Personalization | Age bracket | Reading level | Grade level | Conversation context | **Full knowledge graph + engagement profile + parent guidance** |
| Adaptation speed | Never (content is fixed) | Quarterly updates | Annual | Per-conversation (no persistence) | **Real-time, within a lesson** |
| Parent control | Usage limits | Reading goals | None | None | **Topic focus, difficulty, boundaries, URL→lesson pipeline** |
| Memory | Badge collection | Reading level number | Grade progress | None between sessions | **Persistent knowledge graph, learning style, topic affinities** |
| AI role | None | Voice-only | None | Generic assistant | **Agentic tutor with personality, memory, and curriculum planning** |

---

## Product Evolution Timeline

### v1.0 — "Smart Content" (Launch)
- Skills generate lessons from parent URLs
- Basic age adaptation (vocabulary, complexity)
- Sparky has personality but limited memory
- Foundation: encrypted per-child storage, COPPA consent, knowledge tracking

### v1.5 — "Adaptive Learning" (3 months post-launch)
- Knowledge graph tracks concept mastery
- Quiz difficulty adapts based on demonstrated ability
- Sparky references past conversations ("Remember when we learned about binary?")
- Parent dashboard shows knowledge graph visualization
- Engagement profile influences content selection

### v2.0 — "Agentic Tutor" (6-9 months)
- Curriculum architect skill plans multi-week learning arcs
- Real-time difficulty adjustment within lessons
- Sparky detects frustration/boredom from interaction patterns
- Cross-topic connections ("Algorithms are like recipes — remember when we talked about cooking?")
- Parent sets weekly goals, AI plans the path

### v3.0 — "Learning Companion" (12-18 months, next-gen models)
- Multi-modal understanding (analyzes child's drawings, voice tone, response timing)
- Generative games and challenges (not just cards — actual interactive experiences)
- Study buddy mode for school homework support
- Social features (child-safe: share achievements, collaborative challenges)
- AI generates physical activity suggestions tied to concepts ("Go count 10 things in your house that use algorithms!")

### v4.0 — "Platform" (18-24 months)
- Open skill system — educators can create and share skills
- SDK for third-party educational content providers
- Enterprise tier for schools (teacher dashboard, classroom management)
- Multi-language with cultural adaptation (not just translation)
- Research partnerships with child development labs

---

## The Parent's Experience

This matters as much as the child's. The parent is the buyer.

**What the parent sees:**

1. **Dashboard:** "Dash completed 12 lessons this week. He mastered 'What is an Algorithm' and is progressing on 'How Computers Remember.' He struggled with sequencing tasks — we've adjusted his upcoming lessons to include more practice."

2. **Knowledge Graph:** Visual map of what their child knows. Nodes light up as concepts are mastered. Parents can tap a node to see which lessons covered it, how many attempts it took, and what's connected to it.

3. **Content Pipeline:** Parent pastes an article about Mars rovers. 60 seconds later, Nova has a 6-card lesson about "How Robots Explore Mars" — age-appropriate, connected to concepts Dash already knows, with a quiz that builds on his existing understanding.

4. **Guidance Controls:**
   - Age dial (adjust difficulty independent of actual age)
   - Topic focus ("more reading this week")
   - Content boundaries ("keep it science-focused")
   - Session limits ("max 20 minutes per day")

5. **Weekly Report:** "This week, Dash spent 45 minutes learning. His strongest area is pattern recognition. His biggest growth was in understanding sequences. Recommended next: introduce the concept of loops."

**The parent's realization:** "This AI knows my kid's learning style better than his preschool teacher does. And it's getting better every week."

---

## Technical Requirements for This Vision

### Backend Intelligence Layer

The backend needs a persistent agent per child — not just request/response LLM calls:

```
Per-Child Agent
├── Skill Registry (which skills to use for this child's level)
├── Memory Store (knowledge graph, engagement profile, parent guidance)
├── Context Engine (current session state, recent history)
├── Content Pipeline (generate → filter → quality check → deliver)
└── Analytics Engine (track what works, feed back into skills)
```

### Model Requirements

| Capability | Current (2026) | Future (Mythos+) |
|-----------|---------------|-------------------|
| Context window | 200K tokens | 1M+ tokens |
| Reasoning | Chain-of-thought | Extended thinking with curriculum planning |
| Multi-modal input | Text + images | Text + images + audio + video + interaction patterns |
| Multi-modal output | Text + image prompts | Direct image/audio/interactive generation |
| Personalization | Prompt-based (memory in context) | Fine-tuned per-child behavioral models |
| Real-time | ~2s latency | <500ms for in-lesson adaptation |

The architecture should be model-agnostic. When Mythos or the next breakthrough model arrives, we swap it in and every child's experience improves overnight — because the skills, memory, and context are ours, not the model's.

---

## One-Line Pitch

**Nova doesn't teach kids about AI. Nova IS the AI that teaches your kid — and it gets better at teaching *your* kid every single day.**
