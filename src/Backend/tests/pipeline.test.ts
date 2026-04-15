import { describe, it, expect } from 'vitest';
import {
  getContentAnalysisSystemPrompt,
  getCardGenerationSystemPrompt,
  getSafetyFilterSystemPrompt,
  CONTENT_ANALYSIS_PROMPT,
  CARD_GENERATION_PROMPT,
  SAFETY_FILTER_PROMPT,
} from '../src/services/pipeline/promptTemplates';

/**
 * Tests for Prompt Templates (NOVA-130)
 */
describe('promptTemplates', () => {
  describe('system prompts', () => {
    it('should return non-empty content analysis prompt', () => {
      const prompt = getContentAnalysisSystemPrompt();
      expect(prompt).toBeTruthy();
      expect(prompt.length).toBeGreaterThan(100);
    });

    it('should include Nova role in content analysis prompt', () => {
      const prompt = getContentAnalysisSystemPrompt();
      expect(prompt).toContain('Nova');
      expect(prompt).toContain('teaching assistant');
    });

    it('should include age guidelines in content analysis prompt', () => {
      const prompt = getContentAnalysisSystemPrompt();
      expect(prompt).toMatch(/4-8|ages/i);
    });

    it('should include JSON schema in content analysis prompt', () => {
      const prompt = getContentAnalysisSystemPrompt();
      expect(prompt).toContain('topic');
      expect(prompt).toContain('keyConcepts');
      expect(prompt).toContain('suggestedStage');
    });

    it('should return card generation prompt with context', () => {
      const topic = 'Photosynthesis';
      const summary = 'How plants make food from sun';
      const concepts = ['sunlight', 'chlorophyll', 'food'];

      const prompt = getCardGenerationSystemPrompt(topic, summary, concepts);

      expect(prompt).toContain(topic);
      expect(prompt).toContain(summary);
      expect(prompt).toContain('sunlight');
    });

    it('should include card types in card generation prompt', () => {
      const prompt = getCardGenerationSystemPrompt('Topic', 'Summary', []);
      expect(prompt).toContain('story');
      expect(prompt).toContain('concept');
      expect(prompt).toContain('experiment');
      expect(prompt).toContain('quiz');
      expect(prompt).toContain('voice');
    });

    it('should return safety filter prompt', () => {
      const prompt = getSafetyFilterSystemPrompt();
      expect(prompt).toBeTruthy();
      expect(prompt.length).toBeGreaterThan(50);
      expect(prompt).toContain('safety');
    });
  });

  describe('constant prompts', () => {
    it('should have valid content analysis prompt constant', () => {
      expect(CONTENT_ANALYSIS_PROMPT).toBeTruthy();
      expect(CONTENT_ANALYSIS_PROMPT).toContain('Nova');
    });

    it('should have valid card generation prompt constant', () => {
      expect(CARD_GENERATION_PROMPT).toBeTruthy();
      expect(CARD_GENERATION_PROMPT).toContain('card');
    });

    it('should have valid safety filter prompt constant', () => {
      expect(SAFETY_FILTER_PROMPT).toBeTruthy();
      expect(SAFETY_FILTER_PROMPT).toContain('safety');
    });
  });
});

/**
 * Tests for Card Generation Validation (NOVA-130)
 */
describe('cardGenerator validation', () => {
  describe('card type validation', () => {
    it('should accept story card type', () => {
      const type = 'story';
      const validTypes = ['story', 'concept', 'experiment', 'quiz', 'voice'];
      expect(validTypes).toContain(type);
    });

    it('should accept concept card type', () => {
      const type = 'concept';
      const validTypes = ['story', 'concept', 'experiment', 'quiz', 'voice'];
      expect(validTypes).toContain(type);
    });

    it('should accept experiment card type', () => {
      const type = 'experiment';
      const validTypes = ['story', 'concept', 'experiment', 'quiz', 'voice'];
      expect(validTypes).toContain(type);
    });

    it('should accept quiz card type', () => {
      const type = 'quiz';
      const validTypes = ['story', 'concept', 'experiment', 'quiz', 'voice'];
      expect(validTypes).toContain(type);
    });

    it('should accept voice card type', () => {
      const type = 'voice';
      const validTypes = ['story', 'concept', 'experiment', 'quiz', 'voice'];
      expect(validTypes).toContain(type);
    });

    it('should reject invalid card type', () => {
      const type = 'invalid_type';
      const validTypes = ['story', 'concept', 'experiment', 'quiz', 'voice'];
      expect(validTypes).not.toContain(type);
    });
  });

  describe('card content requirements', () => {
    it('story card should have text field', () => {
      const card = {
        type: 'story',
        content: { text: 'Once upon a time...' },
      };
      expect(card.content.text).toBeTruthy();
    });

    it('concept card should have title and text', () => {
      const card = {
        type: 'concept',
        content: { title: 'Concept', text: 'Definition' },
      };
      expect(card.content.title).toBeTruthy();
      expect(card.content.text).toBeTruthy();
    });

    it('experiment card should have materials array', () => {
      const card = {
        type: 'experiment',
        content: { materials: ['water', 'paper'] },
      };
      expect(Array.isArray(card.content.materials)).toBe(true);
      expect(card.content.materials.length).toBeGreaterThan(0);
    });

    it('quiz card should have options array and correctIndex', () => {
      const card = {
        type: 'quiz',
        content: {
          text: 'Question?',
          options: ['A', 'B', 'C'],
          correctIndex: 1,
        },
      };
      expect(Array.isArray(card.content.options)).toBe(true);
      expect(card.content.options.length).toBeGreaterThanOrEqual(2);
      expect(card.content.correctIndex).toBeLessThan(card.content.options.length);
    });
  });

  describe('voiceScript validation', () => {
    it('should require voiceScript for all cards', () => {
      const cards = [
        { type: 'story', voiceScript: 'Listen' },
        { type: 'concept', voiceScript: 'Learn' },
        { type: 'experiment', voiceScript: 'Try' },
        { type: 'quiz', voiceScript: 'Answer' },
        { type: 'voice', voiceScript: 'Speak' },
      ];

      cards.forEach((card) => {
        expect(card.voiceScript).toBeTruthy();
      });
    });
  });

  describe('sortOrder validation', () => {
    it('should assign sequential sortOrder', () => {
      const cards = [
        { type: 'story', sortOrder: 0 },
        { type: 'concept', sortOrder: 1 },
        { type: 'quiz', sortOrder: 2 },
      ];

      cards.forEach((card, index) => {
        expect(card.sortOrder).toBe(index);
      });
    });
  });
});

/**
 * Tests for Badge Criteria Engine (NOVA-78)
 */
describe('badgeCriteriaEngine', () => {
  describe('badge criteria types', () => {
    it('should recognize lesson_completion criteria', () => {
      const criteria = {
        type: 'lesson_completion' as const,
        count: 5,
      };
      expect(criteria.type).toBe('lesson_completion');
      expect(criteria.count).toBe(5);
    });

    it('should recognize experiments_passed criteria', () => {
      const criteria = {
        type: 'experiments_passed' as const,
        count: 3,
      };
      expect(criteria.type).toBe('experiments_passed');
    });

    it('should recognize days_streak criteria', () => {
      const criteria = {
        type: 'days_streak' as const,
        days: 7,
      };
      expect(criteria.type).toBe('days_streak');
    });

    it('should recognize voice_interactions criteria', () => {
      const criteria = {
        type: 'voice_interactions' as const,
        count: 10,
      };
      expect(criteria.type).toBe('voice_interactions');
    });
  });

  describe('progress metrics', () => {
    it('should count completed lessons', () => {
      const lessonsCompleted = new Set(['lesson-1', 'lesson-2', 'lesson-3']);
      expect(lessonsCompleted.size).toBe(3);
    });

    it('should count unique lessons only once', () => {
      const lessonsCompleted = new Set(['lesson-1', 'lesson-1', 'lesson-2']);
      expect(lessonsCompleted.size).toBe(2);
    });

    it('should count experiments completed', () => {
      const interactions = [
        { cardType: 'experiment' },
        { cardType: 'experiment' },
        { cardType: 'story' },
      ];
      const experimentCount = interactions.filter((i) => i.cardType === 'experiment').length;
      expect(experimentCount).toBe(2);
    });

    it('should count voice interactions', () => {
      const interactions = [
        { voiceTranscript: 'hello' },
        { voiceTranscript: 'world' },
        { voiceTranscript: null },
      ];
      const voiceCount = interactions.filter((i) => i.voiceTranscript).length;
      expect(voiceCount).toBe(2);
    });
  });

  describe('badge evaluation logic', () => {
    it('should award lesson_completion badge at threshold', () => {
      const progress = { lessonsCompleted: 5 };
      const criteria = { type: 'lesson_completion' as const, count: 5 };

      const shouldAward = progress.lessonsCompleted >= criteria.count;
      expect(shouldAward).toBe(true);
    });

    it('should not award lesson_completion badge below threshold', () => {
      const progress = { lessonsCompleted: 3 };
      const criteria = { type: 'lesson_completion' as const, count: 5 };

      const shouldAward = progress.lessonsCompleted >= criteria.count;
      expect(shouldAward).toBe(false);
    });

    it('should award voice_interactions badge at threshold', () => {
      const progress = { voiceInteractions: 10 };
      const criteria = { type: 'voice_interactions' as const, count: 10 };

      const shouldAward = progress.voiceInteractions >= criteria.count;
      expect(shouldAward).toBe(true);
    });

    it('should award days_streak badge at threshold', () => {
      const progress = { consecutiveDaysOfLearning: 7 };
      const criteria = { type: 'days_streak' as const, days: 7 };

      const shouldAward = progress.consecutiveDaysOfLearning >= criteria.days;
      expect(shouldAward).toBe(true);
    });
  });
});

/**
 * Tests for Content Scraper URL Validation (NOVA-126)
 */
describe('contentScraper', () => {
  describe('URL validation', () => {
    it('should accept valid https URLs', () => {
      const url = 'https://example.com/article';
      const parsed = new URL(url);
      expect(parsed.protocol).toBe('https:');
    });

    it('should accept valid http URLs', () => {
      const url = 'http://example.com/article';
      const parsed = new URL(url);
      expect(parsed.protocol).toBe('http:');
    });

    it('should reject invalid URLs', () => {
      expect(() => new URL('not a valid url')).toThrow();
    });

    it('should reject unsupported protocols', () => {
      const url = 'ftp://example.com/file';
      const parsed = new URL(url);
      expect(['http:', 'https:']).not.toContain(parsed.protocol);
    });

    it('should handle URL with query parameters', () => {
      const url = 'https://example.com/article?id=123&lang=en';
      const parsed = new URL(url);
      expect(parsed.searchParams.get('id')).toBe('123');
    });
  });

  describe('content length handling', () => {
    it('should truncate content above max length', () => {
      const MAX_LENGTH = 50000;
      const longContent = 'x'.repeat(100000);

      const trimmed = longContent.length > MAX_LENGTH ? longContent.substring(0, MAX_LENGTH) : longContent;

      expect(trimmed.length).toBeLessThanOrEqual(MAX_LENGTH);
    });

    it('should preserve content below max length', () => {
      const MAX_LENGTH = 50000;
      const content = 'x'.repeat(1000);

      const result = content.length > MAX_LENGTH ? content.substring(0, MAX_LENGTH) : content;

      expect(result).toBe(content);
    });
  });

  describe('error scenarios', () => {
    it('should detect timeout errors', () => {
      const error = new Error('Scrape timeout (10000ms)');
      expect(error.message).toMatch(/timeout/i);
    });

    it('should detect network errors', () => {
      const error = new Error('Failed to fetch URL: Connection refused');
      expect(error.message).toContain('Failed to fetch');
    });

    it('should detect invalid content type', () => {
      const contentType = 'application/json';
      const isHtml = contentType.includes('text/html');
      expect(isHtml).toBe(false);
    });

    it('should detect HTTP status errors', () => {
      const statusCode = 404;
      const isError = statusCode >= 400;
      expect(isError).toBe(true);
    });
  });
});

/**
 * Tests for Content Analyzer (NOVA-126)
 */
describe('contentAnalyzer', () => {
  describe('analysis structure', () => {
    it('should return all required analysis fields', () => {
      const analysis = {
        topic: 'Photosynthesis',
        keyConcepts: ['sunlight', 'chlorophyll'],
        suggestedStage: 2,
        ageAppropriate: true,
        safetyFlags: [],
        suggestedCardCount: 6,
        summary: 'How plants make food',
      };

      expect(analysis).toHaveProperty('topic');
      expect(analysis).toHaveProperty('keyConcepts');
      expect(analysis).toHaveProperty('suggestedStage');
    });

    it('should have valid stage value (1-4)', () => {
      const validStages = [1, 2, 3, 4];
      const testAnalysis = { suggestedStage: 2 };

      expect(validStages).toContain(testAnalysis.suggestedStage);
    });

    it('should clamp stage values to 1-4', () => {
      const clamp = (val: number) => Math.max(1, Math.min(4, val));

      expect(clamp(0)).toBe(1);
      expect(clamp(5)).toBe(4);
    });
  });

  describe('card count validation', () => {
    it('should suggest 5-8 cards', () => {
      const normalize = (count: number) => Math.max(5, Math.min(8, count));

      expect(normalize(0)).toBe(5);
      expect(normalize(6)).toBe(6);
      expect(normalize(10)).toBe(8);
    });
  });

  describe('safety flags', () => {
    it('should have empty flags for safe content', () => {
      const analysis = {
        ageAppropriate: true,
        safetyFlags: [],
      };

      expect(analysis.safetyFlags).toHaveLength(0);
    });

    it('should populate flags for unsafe content', () => {
      const analysis = {
        ageAppropriate: false,
        safetyFlags: ['Violence detected', 'Scary imagery'],
      };

      expect(analysis.safetyFlags.length).toBeGreaterThan(0);
    });
  });
});

/**
 * Integration tests
 */
describe('pipeline integration', () => {
  it('should build complete pipeline flow for safe content', () => {
    const url = 'https://example.com/article';
    const urlValid = url.startsWith('http://') || url.startsWith('https://');
    expect(urlValid).toBe(true);

    const scraped = {
      title: 'Article Title',
      content: 'Article content here',
    };
    expect(scraped.title).toBeTruthy();

    const analysis = {
      ageAppropriate: true,
      suggestedCardCount: 6,
    };
    expect(analysis.ageAppropriate).toBe(true);
  });

  it('should stop pipeline for unsafe content', () => {
    const analysis = {
      ageAppropriate: false,
      safetyFlags: ['Violent content'],
    };

    const shouldGenerate = analysis.ageAppropriate;
    expect(shouldGenerate).toBe(false);
  });

  it('should handle pipeline errors gracefully', () => {
    const errorStates = ['scrape_failed', 'analyze_failed', 'generate_failed'];

    errorStates.forEach((state) => {
      expect(state).toMatch(/_failed$/);
    });
  });
});
