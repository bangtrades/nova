/**
 * Skill Registry (Sprint 10 — S10-06 / S10-07)
 *
 * Orchestrates the skill engine end-to-end:
 *   - Spins up a dedicated Handlebars environment (isolated from globals).
 *   - Registers built-in helpers (`gt`, `lt`, `eq`, `ne`, `formatFloat`).
 *   - Loads shared partials from `defs/_shared/` and installs them globally.
 *   - Loads every skill directory under `defs/` via `loader.ts`.
 *   - Per skill, registers per-skill partials (`ageProfile`, `difficultyCurve`,
 *     `styleExamples`, `topics`, `distractors`) on a per-invocation basis —
 *     lets every skill have its own set of age profiles / difficulty curves
 *     without the partials colliding.
 *   - Exposes `registry.get(name).buildPrompt({ ctx, inputs })`.
 *
 * Key design choice: a **single shared Handlebars instance** owns all
 * templates and partials. Per-invocation variance (which age profile,
 * which difficulty curve) is handled by registering the partial *just
 * before* the render with the invocation-specific content, then
 * unregistering. This keeps the hot path lock-free and fast.
 */
import Handlebars from 'handlebars';
import {
  type LoadedSkillFiles,
  loadAllSkillsFromDisk,
  loadSkillFromDisk,
  resolveDefsDir,
  type SharedPartials,
} from './loader';
import {
  type BuildPromptInput,
  type BuildPromptOutput,
  type ChildContext,
  type Skill,
  type SkillManifest,
  type SkillPromptMeta,
  type SkillRegistry,
} from './types';
import {
  computeEffectiveAge,
  selectAgeProfile,
} from './progression';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Marker separating system from user prompt. Everything before → system. */
export const USER_PROMPT_MARKER = '<!-- user-prompt -->';

/**
 * Mapping from parent-driven difficulty offset (−2..+2) → bucket name.
 * Shared across skills so quiz-maker, experiment-designer, etc. all
 * interpret the slider identically.
 */
export function difficultyBucketFor(offset: number | undefined): 'easy' | 'medium' | 'hard' {
  if (!Number.isFinite(offset ?? NaN)) return 'medium';
  const v = offset as number;
  if (v <= -1) return 'easy';
  if (v >= 1) return 'hard';
  return 'medium';
}

// ---------------------------------------------------------------------------
// Internal built skill record
// ---------------------------------------------------------------------------

interface CompiledSkill {
  files: LoadedSkillFiles;
  systemTemplate: HandlebarsTemplateDelegate<unknown>;
  userTemplate: HandlebarsTemplateDelegate<unknown>;
}

// ---------------------------------------------------------------------------
// Registry implementation
// ---------------------------------------------------------------------------

class SkillRegistryImpl implements SkillRegistry {
  private hb: typeof Handlebars;
  private compiled: Map<string, CompiledSkill> = new Map();
  private loaded = false;
  private defsDir: string;

  constructor(defsDir?: string) {
    this.defsDir = defsDir ?? resolveDefsDir();
    this.hb = Handlebars.create();
    this.registerHelpers();
  }

  // -----------------------------------------------------------------------
  // Public SkillRegistry surface
  // -----------------------------------------------------------------------

  async load(): Promise<void> {
    const { skills, shared } = loadAllSkillsFromDisk(this.defsDir);
    this.registerSharedPartials(shared);
    this.compiled.clear();
    for (const skill of skills) {
      this.compiled.set(skill.manifest.name, this.compileSkill(skill));
    }
    this.loaded = true;
  }

  isLoaded(): boolean {
    return this.loaded;
  }

  list(): Skill[] {
    this.ensureLoaded();
    return [...this.compiled.values()]
      .map((c) => this.wrap(c))
      .sort((a, b) => a.manifest.name.localeCompare(b.manifest.name));
  }

  get(name: string): Skill {
    this.ensureLoaded();
    const c = this.compiled.get(name);
    if (!c) throw new Error(`[skills:registry] no skill named "${name}"`);
    return this.wrap(c);
  }

  has(name: string): boolean {
    if (!this.loaded) return false;
    return this.compiled.has(name);
  }

  async reload(name?: string): Promise<void> {
    if (!name) {
      await this.load();
      return;
    }
    const existing = this.compiled.get(name);
    if (!existing) throw new Error(`[skills:registry] cannot reload unknown skill "${name}"`);
    const files = loadSkillFromDisk(existing.files.dir);
    this.compiled.set(name, this.compileSkill(files));
  }

  // -----------------------------------------------------------------------
  // Handlebars environment setup
  // -----------------------------------------------------------------------

  private registerHelpers(): void {
    // Comparison helpers — used by the progressionModifier partial.
    // Written as subexpressions (`{{#if (gt a b)}}`) so they compose
    // with the built-in `if` block.
    this.hb.registerHelper('gt', (a: unknown, b: unknown) =>
      toNumber(a) > toNumber(b)
    );
    this.hb.registerHelper('lt', (a: unknown, b: unknown) =>
      toNumber(a) < toNumber(b)
    );
    this.hb.registerHelper('gte', (a: unknown, b: unknown) =>
      toNumber(a) >= toNumber(b)
    );
    this.hb.registerHelper('lte', (a: unknown, b: unknown) =>
      toNumber(a) <= toNumber(b)
    );
    this.hb.registerHelper('eq', (a: unknown, b: unknown) => a === b);
    this.hb.registerHelper('ne', (a: unknown, b: unknown) => a !== b);

    // formatFloat — rounds to one decimal place for human-readable
    // effective age output. Avoids "5.8000000000003" rendering.
    this.hb.registerHelper('formatFloat', (v: unknown, digits: unknown) => {
      const n = toNumber(v);
      if (!Number.isFinite(n)) return '';
      const d = Number.isFinite(toNumber(digits)) ? toNumber(digits) : 1;
      return n.toFixed(Math.max(0, Math.min(6, d)));
    });

    // join — utility for interest-topic lists.
    this.hb.registerHelper('join', (arr: unknown, sep: unknown) => {
      if (!Array.isArray(arr)) return '';
      const s = typeof sep === 'string' ? sep : ', ';
      return arr.filter((v) => typeof v === 'string' || typeof v === 'number').join(s);
    });
  }

  private registerSharedPartials(shared: SharedPartials): void {
    for (const [key, body] of Object.entries(shared.files)) {
      assertNoTripleStache(body, `_shared/${key}`);
      this.hb.registerPartial(key, body);
    }
  }

  // -----------------------------------------------------------------------
  // Compile a skill: split system/user, compile both, store.
  // -----------------------------------------------------------------------

  private compileSkill(files: LoadedSkillFiles): CompiledSkill {
    assertNoTripleStache(files.promptBody, `${files.manifest.name}/prompt.md`);

    // Split into system + user — everything before USER_PROMPT_MARKER goes
    // to system; everything after goes to user. If marker absent, whole
    // body is system and user is empty.
    const idx = files.promptBody.indexOf(USER_PROMPT_MARKER);
    let systemSrc: string;
    let userSrc: string;
    if (idx === -1) {
      systemSrc = files.promptBody;
      userSrc = '';
    } else {
      systemSrc = files.promptBody.slice(0, idx);
      userSrc = files.promptBody.slice(idx + USER_PROMPT_MARKER.length);
    }

    // Compile with `noEscape: true` — prompt text must pass through
    // literally. We're not rendering HTML, so HTML-entity escaping of
    // angle brackets and quotes would only corrupt the LLM input.
    const opts: CompileOptions = { noEscape: true, strict: true };
    const systemTemplate = this.hb.compile(systemSrc, opts);
    const userTemplate = this.hb.compile(userSrc, opts);

    return { files, systemTemplate, userTemplate };
  }

  // -----------------------------------------------------------------------
  // Wrap a compiled skill in the public Skill interface. Each call
  // produces a fresh object bound to the compiled template — cheap,
  // and keeps the registry itself a private implementation detail.
  // -----------------------------------------------------------------------

  private wrap(compiled: CompiledSkill): Skill {
    const self = this;
    return {
      manifest: compiled.files.manifest,
      outputSchema: compiled.files.outputSchema,
      buildPrompt(input: BuildPromptInput): BuildPromptOutput {
        return self.buildPromptForSkill(compiled, input);
      },
    };
  }

  // -----------------------------------------------------------------------
  // The hot path — called once per invocation.
  // -----------------------------------------------------------------------

  private buildPromptForSkill(
    compiled: CompiledSkill,
    input: BuildPromptInput
  ): BuildPromptOutput {
    const { files } = compiled;
    const { manifest } = files;
    const { ctx, inputs } = input;

    // Validate required inputs.
    for (const key of manifest.inputs.requires) {
      if (inputs[key] === undefined || inputs[key] === null || inputs[key] === '') {
        throw new Error(
          `[skills:${manifest.name}] missing required input "${key}"`
        );
      }
    }

    // Resolve age profile by effective age.
    let ageProfileUsed: number | undefined;
    let ageProfileBody = '';
    if (manifest.ageProfiles && manifest.ageProfiles.length > 0) {
      const eff = Number.isFinite(ctx.effectiveAgeYears)
        ? ctx.effectiveAgeYears
        : computeEffectiveAge(ctx.ageYears, ctx.progressionDelta ?? 0);
      ageProfileUsed = selectAgeProfile(manifest.ageProfiles, eff);
      ageProfileBody = files.ageProfiles[String(ageProfileUsed)] ?? '';
    }

    // Resolve difficulty curve by offset.
    let difficultyUsed: 'easy' | 'medium' | 'hard' | undefined;
    let difficultyBody = '';
    if (manifest.difficulties && manifest.difficulties.length > 0) {
      difficultyUsed = difficultyBucketFor(ctx.difficultyOffset);
      if (!manifest.difficulties.includes(difficultyUsed)) {
        // Fall back to the first declared difficulty rather than error —
        // never kill a render over a config mismatch. The meta field
        // records what we actually picked so the Dev Console can flag it.
        difficultyUsed = manifest.difficulties[0]!;
      }
      difficultyBody = files.difficultyCurves[difficultyUsed] ?? '';
    }

    // Register per-skill partials fresh for this render. Unregistering
    // at the end keeps the global namespace tidy across skills.
    const partialNames: string[] = [];
    const register = (name: string, body: string): void => {
      this.hb.registerPartial(name, body);
      partialNames.push(name);
    };

    if (ageProfileBody) register('ageProfile', ageProfileBody);
    if (difficultyBody) register('difficultyCurve', difficultyBody);
    if (files.partials.styles) register('styleExamples', files.partials.styles);
    if (files.partials.topics) register('topics', files.partials.topics);
    if (files.partials.distractors) register('distractors', files.partials.distractors);

    try {
      // Normalize the ctx so strict-mode Handlebars never throws on an
      // optional field. Authorial typos still fail loudly (they'd
      // reference a path we don't construct here), but legitimately
      // absent guidance/interest/engagement fields render cleanly as
      // empty arrays / empty strings.
      const data = {
        ctx: normalizeCtxForTemplate(ctx),
        inputs,
        // Flatten ageProfile / difficultyCurve tokens so authors can
        // reference e.g. {{ageProfile.maxSentenceWords}} directly if
        // they choose to YAML-front-matter their MD. For the MVP we
        // expose the raw partial and keep the tokens optional.
        meta: {
          skillName: manifest.name,
          version: manifest.version,
          ageProfileUsed,
          difficultyUsed,
        },
      };

      const system = compiled.systemTemplate(data).trim();
      const user = compiled.userTemplate(data).trim();

      const meta: SkillPromptMeta = {
        skillName: manifest.name,
        version: manifest.version,
        ageProfileUsed,
        difficultyUsed,
        modelHint: manifest.modelHint,
        temperatureHint: manifest.temperatureHint,
        progressionDelta: ctx.progressionDelta ?? 0,
        effectiveAgeYears: ctx.effectiveAgeYears ?? ctx.ageYears,
      };

      return { system, user, meta };
    } finally {
      for (const n of partialNames) this.hb.unregisterPartial(n);
    }
  }

  private ensureLoaded(): void {
    if (!this.loaded) {
      throw new Error('[skills:registry] not loaded — call registry.load() at boot');
    }
  }
}

// ---------------------------------------------------------------------------
// Module-level singleton
// ---------------------------------------------------------------------------

let singleton: SkillRegistryImpl | null = null;

export function getSkillRegistry(): SkillRegistry {
  if (!singleton) singleton = new SkillRegistryImpl();
  return singleton;
}

/** Test-only — reset the singleton so tests can pin a fresh registry. */
export function __resetSkillRegistryForTests(defsDir?: string): SkillRegistry {
  singleton = new SkillRegistryImpl(defsDir);
  return singleton;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Backfill the optional-but-referenced paths on ChildContext so that
 * strict-mode Handlebars never has to `lookupProperty` into `undefined`.
 * Returns a shallow copy — does NOT mutate the caller's ctx.
 *
 * Why do it here rather than at buildChildContext time? Skills are the
 * only consumer that cares, and keeping the contract narrow means the
 * rest of the backend can treat these fields as legitimately optional.
 */
function normalizeCtxForTemplate(ctx: ChildContext): ChildContext {
  const pg = ctx.parentGuidance;
  const normalizedPG = {
    ...pg,
    topicFocus: pg.topicFocus ?? [],
    topicAvoid: pg.topicAvoid ?? [],
    contentBoundaries: {
      disallowedKeywords: pg.contentBoundaries?.disallowedKeywords ?? [],
      allowedTags: pg.contentBoundaries?.allowedTags ?? [],
    },
  };
  return {
    ...ctx,
    parentGuidance: normalizedPG,
    interestTopics: ctx.interestTopics ?? [],
    recentSessionEvents: ctx.recentSessionEvents ?? {
      flow: 0,
      frustration: 0,
      abandon: 0,
    },
    mastery: ctx.mastery ?? { averageScore: 0, totalAttempts: 0 },
    engagement: ctx.engagement ?? {
      recentQuizWinRate: 0,
      preferredCardTypes: [],
    },
    progressionDelta: ctx.progressionDelta ?? 0,
    effectiveAgeYears: ctx.effectiveAgeYears ?? ctx.ageYears,
    difficultyOffset: ctx.difficultyOffset ?? 0,
  };
}

function toNumber(v: unknown): number {
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return Number(v);
  if (v === true) return 1;
  if (v === false) return 0;
  return NaN;
}

/**
 * Triple-stache (`{{{...}}}`) disables HTML escaping in Handlebars.
 * We keep it forbidden so a buggy skill can't accidentally let the
 * LLM receive template directives from user input. Also forbid
 * `{{&...}}` which has the same effect.
 */
function assertNoTripleStache(src: string, where: string): void {
  if (/\{\{\{/.test(src)) {
    throw new Error(
      `[skills:registry] triple-stache {{{ ... }}} is not allowed in "${where}" — use {{ ... }} instead`
    );
  }
  if (/\{\{\s*&/.test(src)) {
    throw new Error(
      `[skills:registry] {{& ... }} (unescaped partial) is not allowed in "${where}"`
    );
  }
}

// Re-exports so `import ... from '@services/skills/registry'` reaches
// the common downstream types.
export type { Skill, SkillManifest, SkillRegistry, ChildContext, BuildPromptInput, BuildPromptOutput, SkillPromptMeta };
