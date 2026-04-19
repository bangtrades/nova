/**
 * Concept Decomposer Service — Grand Architect Pipeline Stage 3 (S9-06)
 *
 * Breaks an analyzed topic into 3-6 "concept atoms". Each atom is a single,
 * teachable idea mapped to a recommended card type. The card generator
 * consumes this decomposition to generate one card per atom (plus a wrap-up
 * quiz/voice card) instead of relying on a generic "give me 6 cards" prompt.
 *
 * Sprint 10 will replace the engagement/learning-value heuristics here with
 * real knowledge-graph data keyed by child. For Sprint 9, the decomposer
 * produces a stable, typed contract the card generator can rely on.
 */
import { routeRequest } from '../llm/providerRouter';
import type { LLMMessage } from '../llm/types';
import {
  getConceptDecompositionSystemPrompt,
  type GuidancePreambleInput,
  type SessionContextPreambleInput,
} from './promptTemplates';
import type { ContentAnalysis } from './contentAnalyzer';
import type { ScrapedContent } from './scraper';
import type { CardType } from './cardGenerator';

export type TeachingStrategy =
  | 'narrative'
  | 'explanation'
  | 'experiment'
  | 'comparison'
  | 'cause_effect'
  | 'quiz'
  | 'voice';

export interface ConceptAtom {
  id: string;
  name: string;
  description: string;
  teachingStrategy: TeachingStrategy;
  recommendedCardType: CardType;
  engagementScore: number; // 0..1
  learningValue: number; // 0..1
  prerequisites: string[]; // atom ids this atom depends on
}

export interface ConceptDecomposition {
  atoms: ConceptAtom[];
  rationale: string;
}

const VALID_STRATEGIES: TeachingStrategy[] = [
  'narrative',
  'explanation',
  'experiment',
  'comparison',
  'cause_effect',
  'quiz',
  'voice',
];

const VALID_CARD_TYPES: CardType[] = ['story', 'concept', 'experiment', 'quiz', 'voice'];

// Default card-type when the model picks an invalid strategy
const STRATEGY_TO_CARD_TYPE: Record<TeachingStrategy, CardType> = {
  narrative: 'story',
  explanation: 'concept',
  experiment: 'experiment',
  comparison: 'concept',
  cause_effect: 'concept',
  quiz: 'quiz',
  voice: 'voice',
};

/**
 * Decompose analyzed content into teachable concept atoms.
 *
 * Throws when the LLM call fails or returns unusable output — the orchestrator
 * should catch and fall back to a heuristic decomposition so the pipeline
 * never dies on a bad model response.
 */
export async function decomposeConcepts(
  userId: string,
  analysis: ContentAnalysis,
  scraped: ScrapedContent,
  guidance?: GuidancePreambleInput | null,
  sessionContext?: SessionContextPreambleInput | null
): Promise<ConceptDecomposition> {
  if (!analysis.topic || !analysis.summary) {
    throw new Error('Concept decomposition requires a topic and summary');
  }

  const systemPrompt = getConceptDecompositionSystemPrompt(
    analysis.topic,
    analysis.summary,
    analysis.keyConcepts,
    analysis.suggestedStage,
    analysis.suggestedCardCount,
    guidance,
    sessionContext
  );

  const userPrompt = `Source excerpt (truncated):
Title: ${scraped.title}

${scraped.content.substring(0, 2500)}`;

  const messages: LLMMessage[] = [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: userPrompt },
  ];

  let response;
  try {
    response = await routeRequest(
      userId,
      {
        model: 'claude-sonnet',
        messages,
        temperature: 0.5,
        maxTokens: 900,
      },
      'concept_decomposition'
    );
  } catch (error) {
    throw new Error(
      `Concept decomposition LLM call failed: ${
        error instanceof Error ? error.message : 'Unknown error'
      }`
    );
  }

  const jsonMatch = response.content.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error('Concept decomposer returned no JSON object');
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(jsonMatch[0]);
  } catch (error) {
    throw new Error(
      `Concept decomposer returned invalid JSON: ${
        error instanceof Error ? error.message : 'Unknown'
      }`
    );
  }

  return normalizeDecomposition(parsed, analysis);
}

/**
 * Validate + normalize the LLM output. Coerces bad fields rather than
 * rejecting the whole response so a slightly-off model reply still yields a
 * usable decomposition. Returns a decomposition with 3-6 atoms.
 */
export function normalizeDecomposition(
  raw: unknown,
  analysis: ContentAnalysis
): ConceptDecomposition {
  const obj = (raw as Record<string, unknown>) ?? {};
  const rawAtoms = Array.isArray(obj.atoms) ? (obj.atoms as unknown[]) : [];

  const atoms: ConceptAtom[] = rawAtoms
    .map((item, index) => normalizeAtom(item as Record<string, unknown>, index))
    .filter((atom): atom is ConceptAtom => atom !== null);

  // Clamp to 3-6 atoms (drop from the tail if too many, synthesize if too few)
  if (atoms.length > 6) {
    atoms.length = 6;
  }

  if (atoms.length < 3) {
    // Fill from keyConcepts as a last-resort fallback
    const seedConcepts = analysis.keyConcepts.slice(0, 3 - atoms.length);
    for (let i = 0; i < seedConcepts.length; i++) {
      const fallbackIndex = atoms.length;
      atoms.push({
        id: `atom-${fallbackIndex + 1}`,
        name: seedConcepts[i],
        description: `Introduce the idea of ${seedConcepts[i]} in simple language.`,
        teachingStrategy: 'explanation',
        recommendedCardType: 'concept',
        engagementScore: 0.6,
        learningValue: 0.7,
        prerequisites: [],
      });
    }
  }

  if (atoms.length < 3) {
    // Still not enough — synthesize from the topic itself
    while (atoms.length < 3) {
      const idx = atoms.length + 1;
      atoms.push({
        id: `atom-${idx}`,
        name: `${analysis.topic} — part ${idx}`,
        description: analysis.summary,
        teachingStrategy: idx === 1 ? 'narrative' : idx === 2 ? 'explanation' : 'quiz',
        recommendedCardType: idx === 1 ? 'story' : idx === 2 ? 'concept' : 'quiz',
        engagementScore: 0.6,
        learningValue: 0.6,
        prerequisites: [],
      });
    }
  }

  // Re-key ids to atom-1..atom-N so the rest of the pipeline can trust them
  const idRemap: Record<string, string> = {};
  atoms.forEach((atom, index) => {
    const newId = `atom-${index + 1}`;
    idRemap[atom.id] = newId;
  });
  atoms.forEach((atom, index) => {
    atom.id = `atom-${index + 1}`;
    atom.prerequisites = atom.prerequisites
      .map((p) => idRemap[p] ?? p)
      .filter((p) => atoms.some((a) => a.id === p) && p !== atom.id);
  });

  const rationale =
    typeof obj.rationale === 'string' && obj.rationale.trim()
      ? obj.rationale.trim()
      : `Broken into ${atoms.length} teachable atoms covering ${analysis.topic}.`;

  return { atoms, rationale };
}

function normalizeAtom(raw: Record<string, unknown>, index: number): ConceptAtom | null {
  if (!raw || typeof raw !== 'object') return null;

  const name = typeof raw.name === 'string' ? raw.name.trim() : '';
  if (!name) return null;

  const description =
    typeof raw.description === 'string' && raw.description.trim()
      ? raw.description.trim()
      : name;

  // Strategy
  let strategy: TeachingStrategy = 'explanation';
  if (typeof raw.teachingStrategy === 'string') {
    const s = raw.teachingStrategy.trim().toLowerCase() as TeachingStrategy;
    if (VALID_STRATEGIES.includes(s)) strategy = s;
  }

  // Card type — prefer LLM choice if valid, otherwise derive from strategy
  let cardType: CardType = STRATEGY_TO_CARD_TYPE[strategy];
  if (typeof raw.recommendedCardType === 'string') {
    const c = raw.recommendedCardType.trim().toLowerCase() as CardType;
    if (VALID_CARD_TYPES.includes(c)) cardType = c;
  }

  const engagementScore = clamp01(Number(raw.engagementScore ?? 0.7));
  const learningValue = clamp01(Number(raw.learningValue ?? 0.7));

  const prerequisites = Array.isArray(raw.prerequisites)
    ? (raw.prerequisites as unknown[]).map((p) => String(p)).filter(Boolean)
    : [];

  const id = typeof raw.id === 'string' && raw.id.trim() ? raw.id.trim() : `atom-${index + 1}`;

  return {
    id,
    name,
    description,
    teachingStrategy: strategy,
    recommendedCardType: cardType,
    engagementScore,
    learningValue,
    prerequisites,
  };
}

function clamp01(n: number): number {
  if (!Number.isFinite(n)) return 0.5;
  if (n < 0) return 0;
  if (n > 1) return 1;
  return Math.round(n * 100) / 100;
}
