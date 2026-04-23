/**
 * Card Generator Service
 *
 * Uses the LLM to generate structured lesson cards from analyzed content.
 * Cards are validated and returned ready for database insertion.
 */

import { routeRequest } from '../llm/providerRouter';
import type { LLMMessage } from '../llm/types';
import {
  getCardGenerationSystemPrompt,
  type GuidancePreambleInput,
  type SessionContextPreambleInput,
} from './promptTemplates';
import type { ContentAnalysis } from './contentAnalyzer';
import type { ConceptDecomposition } from './conceptDecomposer';
import type { ScrapedContent } from './scraper';
import type { ChildContext } from '@services/skills/types';
import { routeAllAtoms, type AtomTrace, type SkipReason } from './skillRouter';

export type CardType = 'story' | 'concept' | 'experiment' | 'quiz' | 'voice';

/**
 * Drag-item chip emitted by `experiment-designer` (S12-04).
 *
 * Backend uses camelCase; the iOS transformer re-keys to `image_url`
 * etc. at the app boundary, same as quiz's `correct_option_index`.
 */
export interface DragItem {
  id: string;
  label: string;
  /** Optional illustration — not populated by the LLM today. */
  imageURL?: string;
}

/**
 * Drop-target bin emitted by `experiment-designer` (S12-04).
 * `acceptsItemIds` is the set of `DragItem.id`s that belong here.
 */
export interface DropTarget {
  id: string;
  label: string;
  acceptsItemIds: string[];
}

export interface CardContent {
  text?: string;
  title?: string;
  imagePrompt?: string;
  options?: string[];
  correctIndex?: number;
  materials?: string[];
  /** Experiment: 1–2 sentence drag-and-drop instruction. S12-04. */
  instructions?: string;
  /** Experiment: 3/4/5 drag chips (easy/medium/hard). S12-04. */
  dragItems?: DragItem[];
  /** Experiment: 2/2/3 drop bins (easy/medium/hard). S12-04. */
  dropTargets?: DropTarget[];
  /**
   * Voice: Dashy's first-person spoken prompt the kid answers aloud.
   * Matches iOS `card.content.promptText`. S12-06.
   */
  promptText?: string;
  /**
   * Voice: 1–5 accepted spoken responses the matcher whitelists.
   * Case-insensitively unique after whitespace-normalization. Matches
   * iOS `card.content.expectedResponses`. S12-06.
   */
  expectedResponses?: string[];
  /**
   * Voice: Dashy's shared-win line on match (6–80 chars, first-person).
   * Persisted so the iPad can surface the celebration post-match. S12-06.
   */
  celebration?: string;
  /**
   * Voice: Dashy's soft-reset line on miss (6–80 chars, first-person).
   * Never a hard correction. S12-06.
   */
  retryHint?: string;
  /**
   * Voice: optional kebab-syllable pronunciation hint for TTS, e.g.
   * "pho-to-syn-the-sis". S12-06.
   */
  phonetics?: string;
}

export interface GeneratedCard {
  type: CardType;
  content: CardContent;
  voiceScript: string;
  sortOrder: number;
}

/**
 * Generate lesson cards from analyzed content.
 *
 * If a {@link ConceptDecomposition} is provided (Pipeline Stage 3 output),
 * the generator uses it to target ONE card per atom in strategy-matched form,
 * plus a wrap-up quiz/voice card. Without a decomposition, it falls back to
 * the generic prompt-based generation from Sprint 8.
 */
export async function generateCards(
  userId: string,
  analysis: ContentAnalysis,
  scraped: ScrapedContent,
  decomposition?: ConceptDecomposition,
  guidance?: GuidancePreambleInput | null,
  sessionContext?: SessionContextPreambleInput | null
): Promise<GeneratedCard[]> {
  // Prepare content text
  const contentText = `Title: ${scraped.title}\n\nContent:\n${scraped.content.substring(0, 3000)}`;

  const systemPrompt = getCardGenerationSystemPrompt(
    analysis.topic,
    analysis.summary,
    analysis.keyConcepts,
    guidance,
    sessionContext
  );

  const userPrompt = decomposition
    ? buildDecompositionUserPrompt(analysis, contentText, decomposition)
    : `Create ${analysis.suggestedCardCount} lesson cards for stage ${analysis.suggestedStage} children:\n\n${contentText}`;

  const messages: LLMMessage[] = [
    {
      role: 'system',
      content: systemPrompt,
    },
    {
      role: 'user',
      content: userPrompt,
    },
  ];

  let response;
  try {
    response = await routeRequest(userId, {
      model: 'claude-sonnet',
      messages,
      temperature: 0.7,
      maxTokens: 2000,
    }, 'card_generation');
  } catch (error) {
    throw new Error(`Card generation failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }

  // Parse and validate the JSON response
  let cards: GeneratedCard[];
  try {
    const jsonMatch = response.content.match(/\[[\s\S]*\]/);
    if (!jsonMatch) {
      throw new Error('No JSON array found in response');
    }

    const parsed = JSON.parse(jsonMatch[0]);
    if (!Array.isArray(parsed)) {
      throw new Error('Response is not an array');
    }

    cards = parsed
      .map((card: unknown, index: number) => validateAndNormalizeCard(card as Record<string, unknown>, index))
      .filter((card): card is GeneratedCard => card !== null);

    if (cards.length === 0) {
      throw new Error('No valid cards generated');
    }

    // Ensure sortOrder is sequential
    cards.forEach((card, index) => {
      card.sortOrder = index;
    });

    return cards;
  } catch (error) {
    throw new Error(
      `Failed to parse card response: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
}

/**
 * Build the user-turn prompt when a concept decomposition is available.
 * Each atom becomes one targeted card with a matched card type.
 */
function buildDecompositionUserPrompt(
  analysis: ContentAnalysis,
  contentText: string,
  decomposition: ConceptDecomposition
): string {
  const atomLines = decomposition.atoms
    .map((atom, index) => {
      const prereqs = atom.prerequisites.length
        ? ` (builds on: ${atom.prerequisites.join(', ')})`
        : '';
      return `  Card ${index + 1}: ${atom.name} — type "${atom.recommendedCardType}" via ${atom.teachingStrategy} strategy${prereqs}
    What to teach: ${atom.description}`;
    })
    .join('\n');

  const wrapupIndex = decomposition.atoms.length + 1;
  const totalCards = Math.max(analysis.suggestedCardCount, decomposition.atoms.length + 1);
  const extraCards = totalCards - decomposition.atoms.length - 1;
  const extraBlock =
    extraCards > 0
      ? `\n  Cards ${wrapupIndex}..${totalCards}: ${extraCards === 1 ? 'a wrap-up quiz or voice card' : 'wrap-up quiz and voice cards'} reinforcing the atoms above.`
      : '';

  return `Create a lesson of exactly ${totalCards} cards for stage ${analysis.suggestedStage} children.

Use this concept decomposition — one card per atom, in this order, with the recommended type:

${atomLines}${extraBlock}

Rationale from the decomposer: ${decomposition.rationale}

Source excerpt (for facts — rewrite for kids, do NOT copy):
${contentText}

Return the JSON array per the card schema in your system prompt. sortOrder must be 0..${totalCards - 1}.`;
}

// ---------------------------------------------------------------------------
// S10-12 · R4 — Skill-engine-aware card generation
// ---------------------------------------------------------------------------

/**
 * Result of the skill-engine path. Returned from
 * {@link generateCardsWithSkills}. The orchestrator surfaces `traces` to
 * Dev Console (R7) and records `skippedAtomIds` + `usedLegacyFallback`
 * in the ingest audit trail.
 */
export interface SkillCardGenerationResult {
  cards: GeneratedCard[];
  traces: AtomTrace[];
  skipped: Array<{ atomId: string; reason: SkipReason }>;
  /** True when the legacy generator ran to fill in skipped atoms. */
  usedLegacyFallback: boolean;
}

/**
 * Route every atom in the decomposition through the skill engine
 * (story-writer / quiz-maker today; more coming in S10-08+). For atoms
 * that don't have a mapped skill (e.g. `concept`, `experiment`, `voice`
 * today), or for skill failures that the Zod-retry couldn't recover
 * from, run the legacy generator once and cherry-pick the cards at the
 * matching atom indices to preserve lesson completeness.
 *
 * Callers:
 *   - pipelineOrchestrator Stage 4 (when childId is present + flag on)
 *   - Dev Console /dev/pipeline/run endpoint (for observability)
 */
export async function generateCardsWithSkills(
  userId: string,
  analysis: ContentAnalysis,
  scraped: ScrapedContent,
  decomposition: ConceptDecomposition,
  childContext: ChildContext,
  guidance?: GuidancePreambleInput | null,
  sessionContext?: SessionContextPreambleInput | null
): Promise<SkillCardGenerationResult> {
  const route = await routeAllAtoms(decomposition.atoms, {
    userId,
    baseContext: childContext,
    analysis,
  });

  // Map atomId → card for the successful atoms.
  const skilledByAtomId = new Map<string, GeneratedCard>();
  for (const r of route.results) {
    if (r.kind === 'ok') skilledByAtomId.set(r.atomId, r.card);
  }

  const allSucceeded = route.skipped.length === 0;
  let legacyCards: GeneratedCard[] | null = null;

  // Only invoke the legacy generator if at least one atom skipped.
  // Saves a full LLM round-trip in the happy path.
  if (!allSucceeded) {
    try {
      legacyCards = await generateCards(
        userId,
        analysis,
        scraped,
        decomposition,
        guidance,
        sessionContext
      );
    } catch (err) {
      // Legacy fallback itself failed — log and proceed with whatever
      // the skill engine produced. A partial lesson beats no lesson.
      console.warn(
        `[cardGenerator] legacy fallback failed, shipping partial skill output: ${
          err instanceof Error ? err.message : String(err)
        }`
      );
      legacyCards = null;
    }
  }

  // Assemble final cards in atom order. Skill-produced cards take
  // priority; legacy at matching index fills the gaps.
  const finalCards: GeneratedCard[] = [];
  for (let i = 0; i < decomposition.atoms.length; i++) {
    const atom = decomposition.atoms[i];
    const skilled = skilledByAtomId.get(atom.id);
    if (skilled) {
      skilled.sortOrder = i;
      finalCards.push(skilled);
      continue;
    }
    const legacy = legacyCards?.[i];
    if (legacy) {
      legacy.sortOrder = i;
      finalCards.push(legacy);
    }
  }

  // Preserve the legacy generator's trailing wrap-up card (if any) so
  // lessons retain their "ending quiz" beat. Only when we actually
  // invoked the legacy path.
  if (legacyCards && legacyCards.length > decomposition.atoms.length) {
    const tail = legacyCards[legacyCards.length - 1];
    tail.sortOrder = finalCards.length;
    finalCards.push(tail);
  }

  return {
    cards: finalCards,
    traces: route.traces,
    skipped: route.skipped,
    usedLegacyFallback: legacyCards !== null,
  };
}

/**
 * Feature flag reader for `SKILL_ENGINE_STAGE4`. Defaults to ON.
 * Any of "false" / "0" / "off" (case-insensitive) disables the skill
 * engine and forces the pipeline back onto the legacy path.
 */
export function isSkillEngineStage4Enabled(): boolean {
  const raw = (process.env.SKILL_ENGINE_STAGE4 ?? 'true').trim().toLowerCase();
  return raw !== 'false' && raw !== '0' && raw !== 'off' && raw !== '';
}

/**
 * Validate and normalize a single card
 */
function validateAndNormalizeCard(card: Record<string, unknown>, fallbackIndex: number): GeneratedCard | null {
  const type = card.type as string;

  // Validate card type
  const validTypes: CardType[] = ['story', 'concept', 'experiment', 'quiz', 'voice'];
  if (!validTypes.includes(type as CardType)) {
    console.warn(`Invalid card type: ${type}, skipping`);
    return null;
  }

  const voiceScript = String(card.voiceScript || '').trim();
  if (!voiceScript) {
    console.warn('Card missing voiceScript, skipping');
    return null;
  }

  // Validate content
  const content = card.content as Record<string, unknown>;
  if (!content || typeof content !== 'object') {
    console.warn('Card missing content object, skipping');
    return null;
  }

  // Normalize content by type
  let normalizedContent: CardContent = {};

  if (type === 'story') {
    normalizedContent = {
      text: String(content.text || '').trim(),
      title: content.title ? String(content.title).trim() : undefined,
      imagePrompt: content.imagePrompt ? String(content.imagePrompt).trim() : undefined,
    };
  } else if (type === 'concept') {
    normalizedContent = {
      title: String(content.title || '').trim(),
      text: String(content.text || '').trim(),
      imagePrompt: content.imagePrompt ? String(content.imagePrompt).trim() : undefined,
    };
  } else if (type === 'experiment') {
    // S12-04: experiment cards prefer the skill-engine drag-and-drop
    // shape (instructions + dragItems + dropTargets). Legacy cards that
    // still ship with `materials` + `text` keep working — the iOS view
    // falls back to the instructional layout when dragItems is absent.
    const dragItemsRaw = Array.isArray(content.dragItems) ? content.dragItems : [];
    const dropTargetsRaw = Array.isArray(content.dropTargets) ? content.dropTargets : [];

    const dragItems: DragItem[] = dragItemsRaw
      .map((raw) => {
        const item = raw as Record<string, unknown>;
        const id = typeof item.id === 'string' ? item.id.trim() : '';
        const label = typeof item.label === 'string' ? item.label.trim() : '';
        if (!id || !label) return null;
        const imageURL = typeof item.imageURL === 'string' ? item.imageURL.trim() : undefined;
        return { id, label, ...(imageURL ? { imageURL } : {}) } as DragItem;
      })
      .filter((v): v is DragItem => v !== null);

    const dropTargets: DropTarget[] = dropTargetsRaw
      .map((raw) => {
        const t = raw as Record<string, unknown>;
        const id = typeof t.id === 'string' ? t.id.trim() : '';
        const label = typeof t.label === 'string' ? t.label.trim() : '';
        const accepts = Array.isArray(t.acceptsItemIds)
          ? t.acceptsItemIds.map(String).map((s) => s.trim()).filter(Boolean)
          : [];
        if (!id || !label) return null;
        return { id, label, acceptsItemIds: accepts } as DropTarget;
      })
      .filter((v): v is DropTarget => v !== null);

    const hasDragDropShape = dragItems.length > 0 && dropTargets.length > 0;

    normalizedContent = {
      title: content.title ? String(content.title).trim() : undefined,
      instructions: content.instructions ? String(content.instructions).trim() : undefined,
      text: String(content.text || '').trim(),
      // Preserve the legacy materials list when the card came from the
      // old path; drop it silently when the drag/drop shape is present.
      materials: hasDragDropShape
        ? undefined
        : Array.isArray(content.materials)
        ? content.materials.map(String)
        : [],
      dragItems: hasDragDropShape ? dragItems : undefined,
      dropTargets: hasDragDropShape ? dropTargets : undefined,
      imagePrompt: content.imagePrompt ? String(content.imagePrompt).trim() : undefined,
    };
  } else if (type === 'quiz') {
    const options = Array.isArray(content.options)
      ? content.options.map(String).filter(Boolean)
      : [];

    if (options.length < 2) {
      console.warn('Quiz card missing valid options, skipping');
      return null;
    }

    const correctIndex = Number(content.correctIndex) || 0;
    if (correctIndex < 0 || correctIndex >= options.length) {
      console.warn('Quiz card has invalid correctIndex, skipping');
      return null;
    }

    normalizedContent = {
      text: String(content.text || '').trim(),
      options,
      correctIndex,
      imagePrompt: content.imagePrompt ? String(content.imagePrompt).trim() : undefined,
    };
  } else if (type === 'voice') {
    normalizedContent = {
      text: String(content.text || '').trim(),
      title: content.title ? String(content.title).trim() : undefined,
      imagePrompt: content.imagePrompt ? String(content.imagePrompt).trim() : undefined,
    };
  }

  return {
    type: type as CardType,
    content: normalizedContent,
    voiceScript,
    sortOrder: fallbackIndex,
  };
}
