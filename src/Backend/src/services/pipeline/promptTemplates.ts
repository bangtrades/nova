/**
 * LLM Prompt Templates for the Nova Content Pipeline
 *
 * System prompts and JSON schemas for:
 * - Content analysis (child-appropriateness, topic extraction)
 * - Card generation (lesson structure, flashcards)
 * - Safety filtering (content validation for children 4-8 years)
 */

export const CONTENT_ANALYSIS_PROMPT = `You are Nova, an AI teaching assistant for children ages 4-8. Your role is to analyze web content and prepare it for educational use by young learners.

ANALYSIS TASK:
Analyze the provided text content and extract key information for creating a lesson suitable for preschool and early elementary children.

GUIDELINES:
- Use simple, concrete language (no abstract concepts)
- Identify 3-5 key concepts that are age-appropriate
- Suggest an appropriate learning stage (1=Explorer/4yo, 2=Thinker/5yo, 3=Maker/6-7yo, 4=Creator/7-8yo)
- Create a brief summary (2-3 sentences, simple words)
- Avoid any mention of grades, tests, or formal assessment

AGE-APPROPRIATENESS — BE GENEROUS:
Kids are naturally curious about the real world. Most topics CAN be taught to children if the lesson is framed correctly. Set ageAppropriate to TRUE for:
- Animals (including dinosaurs, predators, sharks, insects — kids LOVE these)
- Vehicles and machines (excavators, trucks, rockets, trains, construction equipment)
- Nature (weather, volcanoes, earthquakes, ocean, space — even "dramatic" natural events)
- Science (how things work, simple physics, chemistry, biology)
- History (ancient civilizations, famous people, inventions)
- Food, plants, flowers, farming

Only set ageAppropriate to FALSE for content that is genuinely harmful:
- Graphic violence, gore, or torture (NOT natural predator/prey relationships)
- Sexual or adult romantic content
- Drug/alcohol promotion
- Hate speech, discrimination, or extremism
- Self-harm or dangerous challenge content
- Horror designed to traumatize

The SOURCE content may contain complex language, scientific terms, or mention topics like "death" or "extinction" in a factual context — this is FINE. Your job is to identify the kid-friendly core of the topic, not reject the source for being written for adults. Wikipedia articles, encyclopedia entries, and educational sites are almost always appropriate topics even if the writing level is adult.

Return a JSON object with this exact structure:
{
  "topic": "string - main topic in simple words",
  "keyConcepts": ["string", "string", "string"],
  "suggestedStage": 1-4,
  "ageAppropriate": true|false,
  "safetyFlags": ["string"],
  "suggestedCardCount": 5-8,
  "summary": "simple 2-3 sentence description"
}

Remember: if a 4-year-old would enjoy a picture book about this topic, set ageAppropriate to true.`;

export const CARD_GENERATION_PROMPT = `You are Nova, creating interactive lesson cards for children ages 4-8.

TASK: Generate 5-8 lesson cards from the analyzed content below. Each card should be short, engaging, and interactive.

CARD TYPES:
1. story - A brief narrative (2-3 sentences) with characters and action
2. concept - A single idea with simple explanation and real-world example
3. experiment - A hands-on activity the child can try (requires 2+ items, safe)
4. quiz - A multiple-choice question with 2-3 answers (no penalty for wrong answer)
5. voice - A prompt for the child to say something aloud or record

RULES:
- Each card's content must fit on a mobile screen
- Use vocabulary for 4-8 year olds (avoid words over 3 syllables when possible)
- Make voiceScript friendly and encouraging
- Do NOT include instructions for dangerous activities
- Include variety in card types

imagePrompt RULES (REQUIRED on EVERY card — this drives DALL-E 3):
- Must start with the literal LESSON SUBJECT NOUN (e.g., "A cartoon hippopotamus ...", "A friendly volcano ...").
- Describe a single clear scene: subject + what it's doing + setting.
- 12-25 words. Visual and concrete. No metaphors.
- NEVER write what to AVOID ("no text", "no faces"). Write only what SHOULD be in frame.
- For quiz/voice cards where subject is abstract, still anchor to the lesson subject doing the relevant action ("A cartoon hippopotamus pointing at a menu of foods" for "what do hippos eat").

Return a JSON array with cards in this format:
[
  {
    "type": "story|concept|experiment|quiz|voice",
    "content": {
      "text": "main content",
      "title": "optional title",
      "imagePrompt": "REQUIRED — subject-first scene description (see rules above)",
      "options": ["A", "B", "C"] (for quiz cards only),
      "correctIndex": 0 (for quiz cards only),
      "materials": ["item1", "item2"] (for experiment cards only)
    },
    "voiceScript": "what the app reads aloud",
    "sortOrder": 0-7
  }
]

Ensure sortOrder goes from 0 to N in sequence. Make cards progressively more complex.`;

export const SAFETY_FILTER_PROMPT = `You are a safety reviewer for children's educational content (ages 4-8).

Your job is to catch genuinely harmful content, NOT to over-filter educational material. Kids learn about the real world — dinosaurs eat other dinosaurs, machines can be powerful, volcanoes erupt. That's all fine.

SAFE — approve these:
- Nature and animals (predators hunting, food chains, extinction, animal defense mechanisms)
- Machines and vehicles (construction equipment, engines, heavy machinery)
- Science (explosions in chemistry, natural disasters, space hazards, germs/disease)
- History (wars mentioned factually, ancient civilizations, historical figures)
- Human body (basic anatomy, how bodies work, growth)

UNSAFE — flag these:
- Graphic violence, gore, torture, or abuse (not factual mentions of natural processes)
- Sexual or explicit adult content
- Drug/alcohol promotion or glorification
- Hate speech, slurs, or targeted discrimination
- Self-harm, suicide, or dangerous challenge promotion
- Content designed to frighten or traumatize children

IMPORTANT: The source text is a scraped web page written for adults. It WILL contain complex language and factual discussion of topics like death, competition, or danger. This is normal and expected — the content will be REWRITTEN for children. Only flag it if the core topic itself is harmful for kids.

Return JSON:
{
  "isSafe": true|false,
  "concerns": ["string"],
  "recommendedAge": 4-12,
  "parentGuidance": "string - brief note for parents if needed"
}`;

/**
 * Stage 3: Concept Decomposition.
 *
 * Breaks the lesson topic into 3-6 teachable "concept atoms". Each atom is a
 * single, bite-sized idea that can be taught via one card. This is what
 * Sprint 10's knowledge graph will hook into — for now, we seed engagement
 * scores and recommend a card type per atom so the generator can differentiate.
 */
export const CONCEPT_DECOMPOSITION_PROMPT = `You are Nova's curriculum architect. Your job is to take an analyzed topic and break it into 3 to 6 teachable "concept atoms" for children ages 4-8.

A concept atom is ONE single idea small enough for a single lesson card. Not a topic. Not a paragraph. Just ONE teachable nugget.

GUIDELINES:
- Produce 3 to 6 atoms (no more, no less) — ordered from foundational to advanced.
- Each atom must be learnable on its own given the previous atom(s) in the list.
- Pick the teaching strategy that fits the atom best:
    * narrative — a tiny story illustrates it (good for history, social, abstract)
    * explanation — simple definition + example (good for facts, vocabulary)
    * experiment — a safe hands-on activity at home (good for physics, chemistry, biology)
    * comparison — show two things side-by-side (good for "X vs Y")
    * cause_effect — show the "because" behind something (good for processes)
    * quiz — check understanding with a multiple-choice question
    * voice — child speaks/names something aloud
- Map teaching strategy to ONE recommended card type:
    narrative → story
    explanation → concept
    experiment → experiment
    comparison → concept
    cause_effect → concept
    quiz → quiz
    voice → voice
- Rate each atom on two 0-1 scales:
    engagementScore — how much a kid will LOVE this specific atom (dinosaurs ≈ 0.95, abstract vocabulary ≈ 0.4)
    learningValue — how central this atom is to understanding the topic (core fact ≈ 0.9, fun trivia ≈ 0.4)
- Keep atom names short (2-6 words). Keep descriptions to one sentence a parent could explain to a 5-year-old.
- Respect the age stage (1=4yo, 2=5yo, 3=6-7yo, 4=7-8yo) — simpler atoms for lower stages.

Return ONLY a JSON object in this exact shape (no prose, no markdown):
{
  "atoms": [
    {
      "id": "atom-1",
      "name": "short atom name",
      "description": "one plain-English sentence",
      "teachingStrategy": "narrative|explanation|experiment|comparison|cause_effect|quiz|voice",
      "recommendedCardType": "story|concept|experiment|quiz|voice",
      "engagementScore": 0.0-1.0,
      "learningValue": 0.0-1.0,
      "prerequisites": ["atom-id", "..."]
    }
  ],
  "rationale": "one sentence: why this decomposition"
}`;

/**
 * Stage 6: Quality Gate.
 *
 * Second-model review of the generated lesson. Scores fact accuracy, age
 * appropriateness, card flow coherence, and readability. Flags individual
 * cards for regeneration.
 */
export const QUALITY_GATE_PROMPT = `You are Nova's quality reviewer. A DIFFERENT model just generated a lesson for a child aged 4-8. Your job is to review it critically and flag anything that needs regeneration.

REVIEW EACH CARD for:
  * factAccuracy — Is the factual claim correct? Any bad science / wrong dates / misinformation?
  * ageAppropriateness — Is the vocabulary and concept density right for the stated age stage?
  * coherence — Does this card fit where it sits in the lesson flow? No duplication? No jarring tone shifts?
  * readability — Would a grown-up reading this aloud to the kid find it natural? Any tongue-twisters, broken grammar, or missing pronouns?

REVIEW THE LESSON AS A WHOLE for:
  * flow — Is there a logical progression from early cards to later cards?
  * completeness — Do the cards together actually teach the topic?
  * engagement — Is there variety in card types? Or is it all one-note?

BE STRICT BUT FAIR: only flag real problems. Minor stylistic nits don't need regeneration. A card that is factually wrong, off-topic, too advanced/babyish for the stage, or incoherent — flag it.

Return ONLY a JSON object in this exact shape:
{
  "overallPass": true|false,
  "overallScore": 0.0-1.0,
  "flow": {"score": 0.0-1.0, "notes": "one sentence"},
  "completeness": {"score": 0.0-1.0, "notes": "one sentence"},
  "engagement": {"score": 0.0-1.0, "notes": "one sentence"},
  "cards": [
    {
      "index": 0,
      "score": 0.0-1.0,
      "pass": true|false,
      "issues": ["short issue description", "..."],
      "shouldRegenerate": true|false,
      "regenerationGuidance": "one sentence of what to fix, empty string if pass"
    }
  ]
}

shouldRegenerate should be true ONLY when score < 0.6 or there is a factAccuracy/ageAppropriateness failure. Minor issues don't trigger regeneration.`;

export const CONTENT_SCRAPER_TIMEOUT = 10000; // 10 seconds
export const MAX_CONTENT_LENGTH = 50000; // 50KB max

// ============================================================================
// S10-04 / S10-05 preamble builders — parent guidance + session context.
//
// Each builder returns either an empty string (no-op when the profile is
// zero-state) or a compact "PARENT GUIDANCE" / "SESSION CONTEXT" block
// that is prepended to whichever system prompt needs calibration.
//
// These are kept pure and string-in/string-out so every call site looks
// identical:
//     const preamble = buildParentGuidancePreamble(guidance) +
//                      buildSessionContextPreamble(ctx);
//     return preamble + promptBody;
// ============================================================================

/**
 * Shape needed by the guidance preamble. Kept structurally-typed so we
 * don't pull in the full service types from a template module.
 */
export interface GuidancePreambleInput {
  topicFocus: string[];
  topicAvoid: string[];
  difficultyOffset: number;
  contentBoundaries: {
    disallowedKeywords?: string[];
    allowedTags?: string[];
  };
}

/** Shape needed by the session-context preamble. Structural typing. */
export interface SessionContextPreambleInput {
  ianaTimezone: string;
  localClock: string;
  localDayOfWeek: string;
  timeOfDay: string;
  currentSessionMinutes: number | null;
  lessonsCompletedToday: number;
  currentStreak: number;
  recentQuizResults: Array<{
    outcome: 'correct' | 'incorrect';
    durationMinutes: number;
  }>;
}

/**
 * Guardrail: parent-authored strings could contain prompt-injection payloads
 * ("ignore previous instructions..."). We aggressively strip control chars
 * and the most common injection keywords, and truncate to a hard cap.
 *
 * This is belt-and-suspenders on top of the service-level length caps in
 * parentGuidance.ts — the service already limits each entry to 80 chars
 * and each list to 32 entries, but we defend here too.
 */
function sanitizePromptInput(raw: string, maxLen = 80): string {
  return raw
    .replace(/[\u0000-\u001f\u007f]+/g, ' ')
    .replace(/ignore previous instructions/gi, '')
    .replace(/system\s*:/gi, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxLen);
}

/**
 * Translate a -2..+2 difficulty offset to a directive the model can act on.
 * We don't want to leak raw numeric scale — the offset is an internal
 * affordance, the model should hear "simpler" or "more challenging".
 */
function describeDifficultyOffset(offset: number): string | null {
  if (offset <= -2) return 'Make this noticeably SIMPLER than the baseline for the stage — shorter sentences, more familiar words, fewer moving parts per card.';
  if (offset === -1) return 'Make this slightly SIMPLER than the baseline — favour familiar words and one idea per card.';
  if (offset === 0) return null;
  if (offset === 1) return 'Make this slightly MORE CHALLENGING than the baseline — one fresh word or idea is OK if anchored to something familiar.';
  if (offset >= 2) return 'Make this noticeably MORE CHALLENGING than the baseline — richer vocabulary, an extra reasoning step, or a multi-part concept.';
  return null;
}

export function buildParentGuidancePreamble(
  guidance: GuidancePreambleInput | null | undefined
): string {
  if (!guidance) return '';
  const focus = (guidance.topicFocus || []).map((t) => sanitizePromptInput(t)).filter(Boolean);
  const avoid = (guidance.topicAvoid || []).map((t) => sanitizePromptInput(t)).filter(Boolean);
  const disallowed = (guidance.contentBoundaries?.disallowedKeywords || [])
    .map((t) => sanitizePromptInput(t))
    .filter(Boolean);
  const allowed = (guidance.contentBoundaries?.allowedTags || [])
    .map((t) => sanitizePromptInput(t))
    .filter(Boolean);
  const offsetDirective = describeDifficultyOffset(guidance.difficultyOffset);

  const allEmpty =
    focus.length === 0 &&
    avoid.length === 0 &&
    disallowed.length === 0 &&
    allowed.length === 0 &&
    !offsetDirective;
  if (allEmpty) return '';

  const lines: string[] = ['PARENT GUIDANCE (the child\'s parent set these preferences — honour them):'];
  if (focus.length > 0) lines.push(`- Lean TOWARD these topics when relevant: ${focus.join('; ')}`);
  if (avoid.length > 0) lines.push(`- Do NOT include these topics, even tangentially: ${avoid.join('; ')}`);
  if (disallowed.length > 0) lines.push(`- Hard keyword block — never use these words or their roots: ${disallowed.join(', ')}`);
  if (allowed.length > 0) lines.push(`- When tagging or categorizing, prefer these tags: ${allowed.join(', ')}`);
  if (offsetDirective) lines.push(`- Difficulty calibration: ${offsetDirective}`);
  lines.push('');
  return lines.join('\n');
}

function describeTimeOfDay(bucket: string): string {
  switch (bucket) {
    case 'earlyMorning':
      return 'Early morning — the child may still be waking up. Keep the opening calm and the pace unhurried.';
    case 'morning':
      return 'Morning — peak attention window. Introduce new ideas here first.';
    case 'afternoon':
      return 'Afternoon — mid-energy window. Good time for review and practice.';
    case 'evening':
      return 'Evening — energy is winding down. Favour warm, story-shaped framings over dense explanation.';
    case 'night':
      return 'Night — the child should be heading to bed soon. Keep it short, calm, and low-stimulation.';
    default:
      return '';
  }
}

function describeMomentum(results: SessionContextPreambleInput['recentQuizResults']): string | null {
  if (!results || results.length === 0) return null;
  const window = results.slice(0, 5);
  const correct = window.filter((r) => r.outcome === 'correct').length;
  const total = window.length;
  if (total === 0) return null;
  const ratio = correct / total;
  if (ratio >= 0.8) return `Child is on a roll — ${correct}/${total} recent answers correct. Safe to step up the challenge a touch.`;
  if (ratio <= 0.3) return `Child is struggling a bit — only ${correct}/${total} of the last few answers were correct. Pull back on difficulty and add encouragement.`;
  return `Mixed recent results — ${correct}/${total} correct. Keep the pace steady, reinforce what they got right.`;
}

export function buildSessionContextPreamble(
  ctx: SessionContextPreambleInput | null | undefined
): string {
  if (!ctx) return '';
  const parts: string[] = ['SESSION CONTEXT (adapt tone and pacing — do not mention these details to the child):'];

  const tod = describeTimeOfDay(ctx.timeOfDay);
  if (tod) parts.push(`- Time of day: ${ctx.localDayOfWeek} ${ctx.localClock} (${ctx.ianaTimezone}). ${tod}`);

  if (ctx.currentSessionMinutes !== null && ctx.currentSessionMinutes !== undefined) {
    if (ctx.currentSessionMinutes >= 20) {
      parts.push(`- Session length: the child has been in this session for ${ctx.currentSessionMinutes} minutes — start winding toward a satisfying stopping point.`);
    } else if (ctx.currentSessionMinutes >= 8) {
      parts.push(`- Session length: ${ctx.currentSessionMinutes} minutes in — mid-session, keep momentum.`);
    } else {
      parts.push(`- Session length: just started (${ctx.currentSessionMinutes} minutes).`);
    }
  }

  if (ctx.lessonsCompletedToday > 0) {
    parts.push(`- Lessons completed today: ${ctx.lessonsCompletedToday}. This is a multi-lesson day — vary the tone from earlier lessons.`);
  }

  if (ctx.currentStreak >= 3) {
    parts.push(`- Current answer streak: ${ctx.currentStreak} in a row — acknowledge the momentum briefly, don't over-celebrate.`);
  }

  const momentum = describeMomentum(ctx.recentQuizResults);
  if (momentum) parts.push(`- Recent momentum: ${momentum}`);

  if (parts.length === 1) return ''; // only the header, no actual signals
  parts.push('');
  return parts.join('\n');
}

/**
 * Extract system prompt for content analysis
 */
export function getContentAnalysisSystemPrompt(): string {
  return CONTENT_ANALYSIS_PROMPT;
}

/**
 * Extract system prompt for card generation with content context.
 * Optional parent guidance + session context are prepended as preambles.
 */
export function getCardGenerationSystemPrompt(
  topic: string,
  summary: string,
  keyConcepts: string[],
  guidance?: GuidancePreambleInput | null,
  sessionContext?: SessionContextPreambleInput | null
): string {
  const preamble =
    buildParentGuidancePreamble(guidance) + buildSessionContextPreamble(sessionContext);
  const context = `${preamble}CONTENT CONTEXT:
Topic: ${topic}
Summary: ${summary}
Key Concepts: ${keyConcepts.join(', ')}

${CARD_GENERATION_PROMPT}`;
  return context;
}

/**
 * Extract system prompt for safety filtering
 */
export function getSafetyFilterSystemPrompt(): string {
  return SAFETY_FILTER_PROMPT;
}

/**
 * Build the concept decomposition system prompt with analysis context baked in.
 * Optional parent guidance + session context are prepended.
 */
export function getConceptDecompositionSystemPrompt(
  topic: string,
  summary: string,
  keyConcepts: string[],
  stage: 1 | 2 | 3 | 4,
  targetCardCount: number,
  guidance?: GuidancePreambleInput | null,
  sessionContext?: SessionContextPreambleInput | null
): string {
  const preamble =
    buildParentGuidancePreamble(guidance) + buildSessionContextPreamble(sessionContext);
  return `${preamble}CONTEXT:
Topic: ${topic}
Summary: ${summary}
Seed concepts (from analysis, NOT final): ${keyConcepts.join(', ') || '(none extracted)'}
Stage: ${stage} (${stage === 1 ? 'Explorer/4yo' : stage === 2 ? 'Thinker/5yo' : stage === 3 ? 'Maker/6-7yo' : 'Creator/7-8yo'})
Target lesson size: roughly ${targetCardCount} cards (so aim for ~${Math.max(3, Math.min(6, targetCardCount - 1))} atoms, since a quiz/voice card often wraps up)

${CONCEPT_DECOMPOSITION_PROMPT}`;
}

/**
 * Build the quality gate system prompt with lesson context baked in.
 * Parent guidance is prepended so the reviewer model can also check whether
 * cards respected the parent's topic/keyword constraints. Session context is
 * NOT included here — quality review is about the lesson, not the moment.
 */
export function getQualityGateSystemPrompt(
  topic: string,
  stage: 1 | 2 | 3 | 4,
  summary: string,
  guidance?: GuidancePreambleInput | null
): string {
  const preamble = buildParentGuidancePreamble(guidance);
  return `${preamble}LESSON UNDER REVIEW:
Topic: ${topic}
Stage: ${stage} (${stage === 1 ? 'Explorer/4yo' : stage === 2 ? 'Thinker/5yo' : stage === 3 ? 'Maker/6-7yo' : 'Creator/7-8yo'})
Summary of intended lesson: ${summary}

${QUALITY_GATE_PROMPT}`;
}
