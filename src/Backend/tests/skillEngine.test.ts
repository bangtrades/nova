/**
 * S10-06 / S10-07 — Skill Engine end-to-end tests.
 *
 * Scope:
 *   - Loader validates manifest shape and directory/name invariant.
 *   - Loader enforces age-profile and difficulty-curve file presence.
 *   - Registry boots cleanly over the real `defs/` tree.
 *   - Triple-stache is rejected at compile time.
 *   - USER_PROMPT_MARKER correctly splits system vs user halves.
 *   - story-writer renders produce different output per
 *     (age profile, progressionDelta, difficultyOffset, parent avoid list).
 *
 * These tests exercise the real filesystem under `defs/` — if the story-
 * writer manifest or prompt is broken, boot will fail loudly and the
 * tests will catch it before the Mac-side runbook ever launches the
 * server.
 */
import { describe, it, expect, beforeAll, afterEach } from 'vitest';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import {
  loadAllSkillsFromDisk,
  loadSkillFromDisk,
  resolveDefsDir,
} from '@services/skills/loader';
import {
  USER_PROMPT_MARKER,
  __resetSkillRegistryForTests,
  difficultyBucketFor,
  getSkillRegistry,
} from '@services/skills/registry';
import type { ChildContext } from '@services/skills/types';

// ---------------------------------------------------------------------------
// Real-defs tests — boot the registry over the checked-in skill tree.
// ---------------------------------------------------------------------------

describe('skill registry — real defs tree', () => {
  beforeAll(async () => {
    const reg = __resetSkillRegistryForTests(resolveDefsDir());
    await reg.load();
  });

  it('boots and lists at least the story-writer skill', () => {
    const reg = getSkillRegistry();
    expect(reg.isLoaded()).toBe(true);
    const names = reg.list().map((s) => s.manifest.name);
    expect(names).toContain('story-writer');
  });

  it('story-writer manifest passes Zod validation and has expected fields', () => {
    const skill = getSkillRegistry().get('story-writer');
    expect(skill.manifest.name).toBe('story-writer');
    expect(skill.manifest.version).toMatch(/^\d+\.\d+\.\d+$/);
    expect(skill.manifest.modelHint).toBe('flash');
    expect(skill.manifest.inputs.requires).toContain('topic');
    expect(skill.manifest.ageProfiles).toEqual([4, 6, 8]);
  });

  it('throws a helpful error when asked for an unknown skill', () => {
    expect(() => getSkillRegistry().get('no-such-skill')).toThrow(
      /no skill named "no-such-skill"/
    );
  });

  it('has(name) returns false for unknown skills, true for known', () => {
    const reg = getSkillRegistry();
    expect(reg.has('story-writer')).toBe(true);
    expect(reg.has('nope')).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// story-writer render behavior — the sliding-scale age invariant lives here.
// ---------------------------------------------------------------------------

function makeCtx(overrides: Partial<ChildContext> = {}): ChildContext {
  const base: ChildContext = {
    childId: 'child-xyz',
    ageYears: 6,
    effectiveAgeYears: 6,
    progressionDelta: 0,
    parentGuidance: {
      childId: 'child-xyz',
      topicFocus: [],
      topicAvoid: [],
      difficultyOffset: 0,
      contentBoundaries: {},
      dailySessionLimitMinutes: null,
      singleSessionLimitMinutes: null,
      updatedByUserId: 'user-abc',
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    sessionContext: {
      ianaTimezone: 'America/Los_Angeles',
      computedAt: new Date().toISOString(),
      localClock: '10:00',
      localDayOfWeek: 'Monday',
      timeOfDay: 'morning',
      currentSessionMinutes: null,
      lessonsCompletedToday: 0,
      currentStreak: 0,
      recentQuizResults: [],
    },
    interestTopics: [],
    teachingStrategy: {
      conceptType: 'abstract',
      modality: 'narrative',
      rankedCardTypes: [],
    },
    difficultyOffset: 0,
  };
  return { ...base, ...overrides };
}

describe('story-writer — buildPrompt variance by context', () => {
  beforeAll(async () => {
    const reg = __resetSkillRegistryForTests(resolveDefsDir());
    await reg.load();
  });

  it('splits system and user halves on USER_PROMPT_MARKER', () => {
    const skill = getSkillRegistry().get('story-writer');
    const { system, user } = skill.buildPrompt({
      ctx: makeCtx(),
      inputs: { topic: 'gravity pulls things toward the earth' },
    });
    // System half contains the age profile + voice references.
    expect(system).toMatch(/Novai's Story Writer/i);
    expect(system).toMatch(/age profile/i);
    // User half contains the concrete task and the topic.
    expect(user).toMatch(/Concept to teach/i);
    expect(user).toMatch(/gravity pulls things toward the earth/);
    // Marker itself must NOT appear in either half.
    expect(system.includes(USER_PROMPT_MARKER)).toBe(false);
    expect(user.includes(USER_PROMPT_MARKER)).toBe(false);
  });

  it('selects the age-4 profile for a 4-year-old', () => {
    const skill = getSkillRegistry().get('story-writer');
    const { system, meta } = skill.buildPrompt({
      ctx: makeCtx({ ageYears: 4, effectiveAgeYears: 4 }),
      inputs: { topic: 'sharing takes practice' },
    });
    expect(meta.ageProfileUsed).toBe(4);
    expect(system).toMatch(/preschool|pre-reader/i);
    expect(system).toMatch(/80.*140 words/);
  });

  it('selects the age-6 profile for a 6-year-old at standard pace', () => {
    const skill = getSkillRegistry().get('story-writer');
    const { system, meta } = skill.buildPrompt({
      ctx: makeCtx({ ageYears: 6, effectiveAgeYears: 6 }),
      inputs: { topic: 'friction slows things down' },
    });
    expect(meta.ageProfileUsed).toBe(6);
    expect(system).toMatch(/emergent reader/i);
  });

  it('selects the age-8 profile for an 8-year-old and for a progressing 7y/o', () => {
    const skill = getSkillRegistry().get('story-writer');
    const r8 = skill.buildPrompt({
      ctx: makeCtx({ ageYears: 8, effectiveAgeYears: 8 }),
      inputs: { topic: 'photosynthesis turns light into food' },
    });
    expect(r8.meta.ageProfileUsed).toBe(8);
    expect(r8.system).toMatch(/independent reader/i);

    // A 7-year-old with progressionDelta +1.2 ⇒ effective 8.2 ⇒ picks 8.
    const rBright = skill.buildPrompt({
      ctx: makeCtx({
        ageYears: 7,
        progressionDelta: 1.2,
        effectiveAgeYears: 8.2,
      }),
      inputs: { topic: 'photosynthesis turns light into food' },
    });
    expect(rBright.meta.ageProfileUsed).toBe(8);
  });

  it('embeds the progression nudge corresponding to the delta', () => {
    const skill = getSkillRegistry().get('story-writer');

    const ahead = skill.buildPrompt({
      ctx: makeCtx({
        ageYears: 6,
        effectiveAgeYears: 7.0,
        progressionDelta: 1.0,
      }),
      inputs: { topic: 'kindness spreads' },
    });
    expect(ahead.system).toMatch(/above-profile mastery/i);

    const standard = skill.buildPrompt({
      ctx: makeCtx({
        ageYears: 6,
        effectiveAgeYears: 6,
        progressionDelta: 0,
      }),
      inputs: { topic: 'kindness spreads' },
    });
    expect(standard.system).toMatch(/standard pace/i);

    const struggling = skill.buildPrompt({
      ctx: makeCtx({
        ageYears: 6,
        effectiveAgeYears: 5.0,
        progressionDelta: -1.0,
      }),
      inputs: { topic: 'kindness spreads' },
    });
    expect(struggling.system).toMatch(/signs of struggle/i);
  });

  it('renders parent avoid list when populated, omits when empty', () => {
    const skill = getSkillRegistry().get('story-writer');

    const noAvoid = skill.buildPrompt({
      ctx: makeCtx(),
      inputs: { topic: 'a very safe topic' },
    });
    expect(noAvoid.system).not.toMatch(/Do NOT use or reference/);

    const withAvoid = skill.buildPrompt({
      ctx: makeCtx({
        parentGuidance: {
          ...makeCtx().parentGuidance,
          topicAvoid: ['spiders', 'thunderstorms'],
        },
      }),
      inputs: { topic: 'a very safe topic' },
    });
    expect(withAvoid.system).toMatch(/Do NOT use or reference:/);
    expect(withAvoid.system).toMatch(/spiders, thunderstorms/);
  });

  it('renders interest topics when populated, falls back to canonical bank otherwise', () => {
    const skill = getSkillRegistry().get('story-writer');

    const cold = skill.buildPrompt({
      ctx: makeCtx({ interestTopics: [] }),
      inputs: { topic: 'patience' },
    });
    expect(cold.system).toMatch(/No specific interest topics yet/);
    expect(cold.system).toMatch(/Canonical interest bank/i);

    const warm = skill.buildPrompt({
      ctx: makeCtx({ interestTopics: ['dinosaurs', 'space'] }),
      inputs: { topic: 'patience' },
    });
    expect(warm.system).toMatch(/dinosaurs, space/);
  });

  it('echoes progressionDelta and effectiveAge in meta', () => {
    const skill = getSkillRegistry().get('story-writer');
    const { meta } = skill.buildPrompt({
      ctx: makeCtx({
        ageYears: 6,
        effectiveAgeYears: 6.8,
        progressionDelta: 0.8,
      }),
      inputs: { topic: 'shadows' },
    });
    expect(meta.progressionDelta).toBeCloseTo(0.8, 5);
    expect(meta.effectiveAgeYears).toBeCloseTo(6.8, 5);
    expect(meta.modelHint).toBe('flash');
    expect(meta.temperatureHint).toBeCloseTo(0.8, 2);
  });

  it('throws when a required input is missing', () => {
    const skill = getSkillRegistry().get('story-writer');
    expect(() =>
      skill.buildPrompt({
        ctx: makeCtx(),
        inputs: {},
      })
    ).toThrow(/missing required input "topic"/);
  });
});

// ---------------------------------------------------------------------------
// quiz-maker render behavior — S10-07. Mirrors the story-writer shape but
// with a stricter output contract (Zod validator attached) and an
// additional axis (conceptType + modality) that fans out into the partials.
// ---------------------------------------------------------------------------

describe('quiz-maker — buildPrompt variance by context', () => {
  beforeAll(async () => {
    const reg = __resetSkillRegistryForTests(resolveDefsDir());
    await reg.load();
  });

  it('is registered and exposes an outputSchema (Zod validator present)', () => {
    const reg = getSkillRegistry();
    expect(reg.has('quiz-maker')).toBe(true);
    const skill = reg.get('quiz-maker');
    expect(skill.manifest.name).toBe('quiz-maker');
    expect(skill.manifest.inputs.requires).toContain('concept');
    expect(skill.manifest.inputs.requires).toContain('conceptType');
    expect(skill.outputSchema).toBeDefined();
  });

  it('splits system and user halves on USER_PROMPT_MARKER and renders the JSON contract in system', () => {
    const skill = getSkillRegistry().get('quiz-maker');
    const { system, user } = skill.buildPrompt({
      ctx: makeCtx(),
      inputs: {
        concept: 'helium balloons float because helium is lighter than air',
        conceptType: 'causeEffect',
      },
    });
    // System half includes the Quiz Maker identity + JSON contract.
    expect(system).toMatch(/Novai's Quiz Maker/i);
    expect(system).toMatch(/"question"/);
    expect(system).toMatch(/"options"/);
    expect(system).toMatch(/"correctIndex"/);
    expect(system).toMatch(/"rationalePerOption"/);
    // User half includes the concrete concept.
    expect(user).toMatch(/Concept to probe/i);
    expect(user).toMatch(/helium balloons float/);
    // Marker itself must NOT appear in either half.
    expect(system.includes(USER_PROMPT_MARKER)).toBe(false);
    expect(user.includes(USER_PROMPT_MARKER)).toBe(false);
  });

  it('selects age-4 profile for a 4-year-old, age-8 for an 8-year-old', () => {
    const skill = getSkillRegistry().get('quiz-maker');

    const r4 = skill.buildPrompt({
      ctx: makeCtx({ ageYears: 4, effectiveAgeYears: 4 }),
      inputs: { concept: 'sharing', conceptType: 'abstract' },
    });
    expect(r4.meta.ageProfileUsed).toBe(4);
    expect(r4.system).toMatch(/preschool|pre-reader/i);

    const r8 = skill.buildPrompt({
      ctx: makeCtx({ ageYears: 8, effectiveAgeYears: 8 }),
      inputs: { concept: 'sharing', conceptType: 'abstract' },
    });
    expect(r8.meta.ageProfileUsed).toBe(8);
    expect(r8.system).toMatch(/independent reader/i);
  });

  it('selects the age-8 profile for a 7-year-old with +1.2 progression (effective 8.2)', () => {
    const skill = getSkillRegistry().get('quiz-maker');
    const { meta, system } = skill.buildPrompt({
      ctx: makeCtx({
        ageYears: 7,
        progressionDelta: 1.2,
        effectiveAgeYears: 8.2,
      }),
      inputs: { concept: 'friction slows things down', conceptType: 'causeEffect' },
    });
    expect(meta.ageProfileUsed).toBe(8);
    expect(system).toMatch(/independent reader/i);
  });

  it('difficultyOffset -2 picks easy (3 options); 0 picks medium (4); +2 picks hard (5)', () => {
    const skill = getSkillRegistry().get('quiz-maker');

    const easy = skill.buildPrompt({
      ctx: makeCtx({ difficultyOffset: -2 }),
      inputs: { concept: 'friction', conceptType: 'causeEffect' },
    });
    expect(easy.meta.difficultyUsed).toBe('easy');
    expect(easy.system).toMatch(/exactly 3/);
    expect(easy.system).toMatch(/Recognition/i);

    const medium = skill.buildPrompt({
      ctx: makeCtx({ difficultyOffset: 0 }),
      inputs: { concept: 'friction', conceptType: 'causeEffect' },
    });
    expect(medium.meta.difficultyUsed).toBe('medium');
    expect(medium.system).toMatch(/exactly 4/);
    expect(medium.system).toMatch(/Application/i);

    const hard = skill.buildPrompt({
      ctx: makeCtx({ difficultyOffset: 2 }),
      inputs: { concept: 'friction', conceptType: 'causeEffect' },
    });
    expect(hard.meta.difficultyUsed).toBe('hard');
    expect(hard.system).toMatch(/exactly 5/);
    expect(hard.system).toMatch(/Transfer/i);
  });

  it('modality partial branches per teachingStrategy.modality', () => {
    const skill = getSkillRegistry().get('quiz-maker');
    const base = makeCtx();

    const visual = skill.buildPrompt({
      ctx: {
        ...base,
        teachingStrategy: { ...base.teachingStrategy, modality: 'visual' },
      },
      inputs: { concept: 'shadows', conceptType: 'causeEffect' },
    });
    expect(visual.system).toMatch(/shown/i);
    expect(visual.system).toMatch(/visual imagery|visible property/i);

    const auditory = skill.buildPrompt({
      ctx: {
        ...base,
        teachingStrategy: { ...base.teachingStrategy, modality: 'auditory' },
      },
      inputs: { concept: 'shadows', conceptType: 'causeEffect' },
    });
    expect(auditory.system).toMatch(/sound and rhythm/i);

    const kinesthetic = skill.buildPrompt({
      ctx: {
        ...base,
        teachingStrategy: { ...base.teachingStrategy, modality: 'kinesthetic' },
      },
      inputs: { concept: 'shadows', conceptType: 'causeEffect' },
    });
    expect(kinesthetic.system).toMatch(/action/i);
    expect(kinesthetic.system).toMatch(/mime|physically/i);
  });

  it('embeds the progression nudge corresponding to the delta', () => {
    const skill = getSkillRegistry().get('quiz-maker');

    const ahead = skill.buildPrompt({
      ctx: makeCtx({
        ageYears: 6,
        effectiveAgeYears: 7.0,
        progressionDelta: 1.0,
      }),
      inputs: { concept: 'kindness', conceptType: 'abstract' },
    });
    expect(ahead.system).toMatch(/above-profile mastery/i);

    const struggling = skill.buildPrompt({
      ctx: makeCtx({
        ageYears: 6,
        effectiveAgeYears: 5.0,
        progressionDelta: -1.0,
      }),
      inputs: { concept: 'kindness', conceptType: 'abstract' },
    });
    expect(struggling.system).toMatch(/signs of struggle/i);
  });

  it('renders parent avoid list and disallowed keywords when populated', () => {
    const skill = getSkillRegistry().get('quiz-maker');
    const base = makeCtx();

    const blocked = skill.buildPrompt({
      ctx: {
        ...base,
        parentGuidance: {
          ...base.parentGuidance,
          topicAvoid: ['spiders', 'thunderstorms'],
          contentBoundaries: {
            ...base.parentGuidance.contentBoundaries,
            disallowedKeywords: ['scary'],
          },
        },
      },
      inputs: { concept: 'weather', conceptType: 'factual' },
    });
    expect(blocked.system).toMatch(/Do NOT mention or reference:/);
    expect(blocked.system).toMatch(/spiders, thunderstorms/);
    expect(blocked.system).toMatch(/Filter out keywords:/);
    expect(blocked.system).toMatch(/scary/);

    const clean = skill.buildPrompt({
      ctx: makeCtx(),
      inputs: { concept: 'weather', conceptType: 'factual' },
    });
    expect(clean.system).not.toMatch(/Do NOT mention or reference:/);
    expect(clean.system).not.toMatch(/Filter out keywords:/);
  });

  it('echoes skill metadata on meta (model + temperature hint from manifest)', () => {
    const skill = getSkillRegistry().get('quiz-maker');
    const { meta } = skill.buildPrompt({
      ctx: makeCtx({
        ageYears: 6,
        effectiveAgeYears: 6.2,
        progressionDelta: 0.2,
        difficultyOffset: 0,
      }),
      inputs: { concept: 'balance', conceptType: 'abstract' },
    });
    expect(meta.skillName).toBe('quiz-maker');
    expect(meta.modelHint).toBe('flash');
    // quiz-maker uses a tighter temperature than story-writer (0.4).
    expect(meta.temperatureHint).toBeCloseTo(0.4, 2);
    expect(meta.progressionDelta).toBeCloseTo(0.2, 5);
    expect(meta.effectiveAgeYears).toBeCloseTo(6.2, 5);
    expect(meta.ageProfileUsed).toBe(6);
    expect(meta.difficultyUsed).toBe('medium');
  });

  it('renders the distractors partial and the voice references (styles)', () => {
    const skill = getSkillRegistry().get('quiz-maker');
    const { system } = skill.buildPrompt({
      ctx: makeCtx(),
      inputs: { concept: 'gravity', conceptType: 'causeEffect' },
    });
    // Distractor guidance — canonical misconception patterns header.
    expect(system).toMatch(/Distractor design/i);
    expect(system).toMatch(/misconception/i);
    // Voice references — 3 voice dials for the quiz-maker.
    expect(system).toMatch(/Curious check-in/i);
    expect(system).toMatch(/Scene-based/i);
    expect(system).toMatch(/Side-by-side/i);
  });

  it('includes the concept type and optional lastStoryExcerpt in the user half when provided', () => {
    const skill = getSkillRegistry().get('quiz-maker');
    const { user } = skill.buildPrompt({
      ctx: makeCtx(),
      inputs: {
        concept: 'the moon orbits the earth',
        conceptType: 'factual',
        topic: 'astronomy basics',
        lastStoryExcerpt:
          'Luna watched the moon rise slowly above the garden fence.',
      },
    });
    expect(user).toMatch(/Concept type/);
    expect(user).toMatch(/factual/);
    expect(user).toMatch(/astronomy basics/);
    expect(user).toMatch(/Luna watched the moon rise/);
  });

  it('throws when `concept` is missing', () => {
    const skill = getSkillRegistry().get('quiz-maker');
    expect(() =>
      skill.buildPrompt({
        ctx: makeCtx(),
        inputs: { conceptType: 'abstract' },
      })
    ).toThrow(/missing required input "concept"/);
  });

  it('throws when `conceptType` is missing', () => {
    const skill = getSkillRegistry().get('quiz-maker');
    expect(() =>
      skill.buildPrompt({
        ctx: makeCtx(),
        inputs: { concept: 'sharing' },
      })
    ).toThrow(/missing required input "conceptType"/);
  });

  it('bans "all of the above" text from the system prompt itself', () => {
    // This is a meta-property test: the author must explicitly forbid the
    // phrase in the system prompt. If someone ever loosens the contract,
    // this test fails and the retry-loop risk reappears.
    const skill = getSkillRegistry().get('quiz-maker');
    const { system } = skill.buildPrompt({
      ctx: makeCtx(),
      inputs: { concept: 'gravity', conceptType: 'causeEffect' },
    });
    expect(system).toMatch(/all of the above/i);
    expect(system).toMatch(/none of the above/i);
    // And the ban must be phrased as a prohibition, not a permission.
    expect(system).toMatch(/never|No option may contain|Never/);
  });
});

// ---------------------------------------------------------------------------
// difficultyBucketFor — parent-offset mapping lives on the registry module.
// ---------------------------------------------------------------------------

describe('difficultyBucketFor', () => {
  it('maps negative offsets to easy, positive to hard, zero to medium', () => {
    expect(difficultyBucketFor(-2)).toBe('easy');
    expect(difficultyBucketFor(-1)).toBe('easy');
    expect(difficultyBucketFor(0)).toBe('medium');
    expect(difficultyBucketFor(1)).toBe('hard');
    expect(difficultyBucketFor(2)).toBe('hard');
  });

  it('returns medium for undefined / NaN', () => {
    expect(difficultyBucketFor(undefined)).toBe('medium');
    expect(difficultyBucketFor(NaN)).toBe('medium');
  });
});

// ---------------------------------------------------------------------------
// Loader validation — synthesized defs trees in tmp directories.
// These are synthetic to exercise the error paths without polluting
// the real checked-in tree.
// ---------------------------------------------------------------------------

describe('loader — validation errors', () => {
  const tmpDirs: string[] = [];

  afterEach(() => {
    while (tmpDirs.length > 0) {
      const d = tmpDirs.pop()!;
      try {
        fs.rmSync(d, { recursive: true, force: true });
      } catch {
        /* best effort */
      }
    }
  });

  function makeTmpDefs(): string {
    const d = fs.mkdtempSync(path.join(os.tmpdir(), 'novai-defs-'));
    tmpDirs.push(d);
    return d;
  }

  it('throws when defsDir does not exist', () => {
    const missing = path.join(os.tmpdir(), `does-not-exist-${Date.now()}`);
    expect(() => loadAllSkillsFromDisk(missing)).toThrow(/defs directory not found/);
  });

  it('throws when manifest.name does not match directory name', () => {
    const defs = makeTmpDefs();
    const skillDir = path.join(defs, 'actual-dir-name');
    fs.mkdirSync(skillDir);
    fs.writeFileSync(
      path.join(skillDir, 'manifest.json'),
      JSON.stringify({
        name: 'different-name',
        version: '0.1.0',
        description: 'x',
        modelHint: 'flash',
        temperatureHint: 0.5,
        inputs: { requires: [], optional: [] },
      })
    );
    fs.writeFileSync(path.join(skillDir, 'prompt.md'), 'hi');
    expect(() => loadSkillFromDisk(skillDir)).toThrow(
      /does not match directory name/
    );
  });

  it('throws when prompt.md is missing', () => {
    const defs = makeTmpDefs();
    const skillDir = path.join(defs, 'missing-prompt');
    fs.mkdirSync(skillDir);
    fs.writeFileSync(
      path.join(skillDir, 'manifest.json'),
      JSON.stringify({
        name: 'missing-prompt',
        version: '0.1.0',
        description: 'x',
        modelHint: 'flash',
        temperatureHint: 0.5,
        inputs: { requires: [], optional: [] },
      })
    );
    expect(() => loadSkillFromDisk(skillDir)).toThrow(/missing prompt\.md/);
  });

  it('throws when a declared age-profile file is missing', () => {
    const defs = makeTmpDefs();
    const skillDir = path.join(defs, 'ages-missing');
    fs.mkdirSync(skillDir);
    fs.mkdirSync(path.join(skillDir, 'age-profiles'));
    fs.writeFileSync(
      path.join(skillDir, 'manifest.json'),
      JSON.stringify({
        name: 'ages-missing',
        version: '0.1.0',
        description: 'x',
        modelHint: 'flash',
        temperatureHint: 0.5,
        inputs: { requires: [], optional: [] },
        ageProfiles: [4, 6],
      })
    );
    fs.writeFileSync(path.join(skillDir, 'prompt.md'), 'hi {{ctx.childId}}');
    // Only 4.md present — 6.md missing.
    fs.writeFileSync(path.join(skillDir, 'age-profiles', '4.md'), 'age 4 body');
    expect(() => loadSkillFromDisk(skillDir)).toThrow(/ageProfile 6/);
  });

  it('rejects a skill whose prompt contains triple-stache', async () => {
    const defs = makeTmpDefs();
    const skillDir = path.join(defs, 'triple-stache');
    fs.mkdirSync(skillDir);
    fs.writeFileSync(
      path.join(skillDir, 'manifest.json'),
      JSON.stringify({
        name: 'triple-stache',
        version: '0.1.0',
        description: 'x',
        modelHint: 'flash',
        temperatureHint: 0.5,
        inputs: { requires: [], optional: [] },
      })
    );
    fs.writeFileSync(
      path.join(skillDir, 'prompt.md'),
      'hello {{{ctx.childId}}}'
    );
    const reg = __resetSkillRegistryForTests(defs);
    await expect(reg.load()).rejects.toThrow(/triple-stache/);
  });

  it('rejects a manifest that fails Zod strict mode', () => {
    const defs = makeTmpDefs();
    const skillDir = path.join(defs, 'bad-manifest');
    fs.mkdirSync(skillDir);
    fs.writeFileSync(
      path.join(skillDir, 'manifest.json'),
      JSON.stringify({
        name: 'bad-manifest',
        version: '0.1.0',
        description: 'x',
        modelHint: 'flash',
        temperatureHint: 0.5,
        inputs: { requires: [], optional: [] },
        extraneousField: 'should fail strict()',
      })
    );
    fs.writeFileSync(path.join(skillDir, 'prompt.md'), 'hi');
    expect(() => loadSkillFromDisk(skillDir)).toThrow();
  });
});
