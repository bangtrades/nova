/**
 * Skill Loader (Sprint 10 — S10-06 / S10-07 support)
 *
 * Loads `defs/<name>/` trees from disk and returns in-memory records.
 * Boot-time (eager) — every manifest is validated, every MD partial is
 * parsed, every template is compiled up-front, so typos surface at
 * server-startup instead of at the first invocation.
 *
 * A skill folder looks like:
 *
 *   defs/story-writer/
 *     manifest.json
 *     prompt.md
 *     styles.md
 *     topics.md
 *     age-profiles/4.md, 6.md, 8.md
 *
 *   defs/quiz-maker/
 *     manifest.json
 *     prompt.md
 *     styles.md
 *     distractors.md
 *     difficulty-curves/easy.md, medium.md, hard.md
 *
 * Shared partials live under `defs/_shared/` — the loader walks that
 * directory separately and returns its contents for the registry to
 * install globally on the Handlebars instance.
 *
 * No filesystem touch after boot except when the Dev Console calls
 * `reloadSkillFromDisk()` via the hot-reload endpoint.
 */
import * as fs from 'fs';
import * as path from 'path';
import { z } from 'zod';
import { SkillManifestSchema, type SkillManifest } from './types';
import { SKILL_OUTPUT_SCHEMAS } from './validators';

// ---------------------------------------------------------------------------
// Disk layout constants
// ---------------------------------------------------------------------------

/** Repo-relative default. Overridden by env var in dev. */
const DEFAULT_DEFS_DIR = path.resolve(__dirname, 'defs');

/** Under `defs/_shared/` — partials registered globally by the registry. */
export const SHARED_DIR_NAME = '_shared';

/** Sub-directory inside a skill folder holding age-profile MD files. */
export const AGE_PROFILES_DIR = 'age-profiles';
/** Sub-directory inside a skill folder holding difficulty-curve MD files. */
export const DIFFICULTY_CURVES_DIR = 'difficulty-curves';

/** Files we recognize at the root of a skill directory. */
export const SKILL_ROOT_MD_FILES = [
  'prompt.md',
  'styles.md',
  'topics.md',
  'distractors.md',
] as const;

export type SkillRootMdFile = (typeof SKILL_ROOT_MD_FILES)[number];

// ---------------------------------------------------------------------------
// In-memory record shape
// ---------------------------------------------------------------------------

export interface LoadedSkillFiles {
  manifest: SkillManifest;
  /** Path on disk — useful for hot-reload and error messages. */
  dir: string;
  /** The top-level prompt.md contents (required). */
  promptBody: string;
  /** Optional skill-level Markdown partials, keyed by filename sans ext. */
  partials: Record<string, string>;
  /** age-profile name → body, e.g. `{ '4': '...', '6': '...', '8': '...' }`. */
  ageProfiles: Record<string, string>;
  /** difficulty-curve name → body, e.g. `{ easy: '...', medium: '...' }`. */
  difficultyCurves: Record<string, string>;
  /**
   * Optional per-skill Zod schema, loaded from `validators.ts` (dev/test)
   * or `validators.js` (compiled prod) if present in the skill dir. The
   * file must export the schema as its default export.
   */
  outputSchema?: z.ZodTypeAny;
}

export interface SharedPartials {
  /** filename sans ext → body. Registered by the registry globally. */
  files: Record<string, string>;
  /** Absolute path to `_shared/`. */
  dir: string;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Root-scan `defs/`. Returns one record per skill directory (skipping
 * `_shared/`). Throws if any manifest fails Zod validation, since a
 * bad manifest at boot should bring the server down loudly.
 */
export function loadAllSkillsFromDisk(defsDir: string = DEFAULT_DEFS_DIR): {
  skills: LoadedSkillFiles[];
  shared: SharedPartials;
} {
  if (!fs.existsSync(defsDir) || !fs.statSync(defsDir).isDirectory()) {
    throw new Error(`[skills:loader] defs directory not found at ${defsDir}`);
  }

  const entries = fs.readdirSync(defsDir, { withFileTypes: true });
  const skills: LoadedSkillFiles[] = [];
  let shared: SharedPartials = { files: {}, dir: path.join(defsDir, SHARED_DIR_NAME) };

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    if (entry.name === SHARED_DIR_NAME) {
      shared = loadSharedPartials(path.join(defsDir, entry.name));
      continue;
    }
    // Regular skill directory — must contain manifest.json + prompt.md.
    const skillDir = path.join(defsDir, entry.name);
    // Skip hidden / partially-formed skills (e.g. sketches without manifest).
    const manifestPath = path.join(skillDir, 'manifest.json');
    if (!fs.existsSync(manifestPath)) continue;
    skills.push(loadSkillFromDisk(skillDir));
  }

  // Determinism: sort by skill name so boot logs and `registry.list()`
  // return skills in the same order every time.
  skills.sort((a, b) => a.manifest.name.localeCompare(b.manifest.name));

  return { skills, shared };
}

/**
 * Load a single skill directory, re-validating the manifest. Exposed so
 * the Dev Console `POST /dev/skills/:name/reload` endpoint can re-read
 * just that one skill without restarting.
 */
export function loadSkillFromDisk(skillDir: string): LoadedSkillFiles {
  const manifestPath = path.join(skillDir, 'manifest.json');
  const raw = readJson(manifestPath);
  const manifest = SkillManifestSchema.parse(raw);

  // Enforce directory-name ↔ manifest.name invariant. A mismatch is
  // the kind of bug you want to catch before a downstream 500.
  const dirBasename = path.basename(skillDir);
  if (manifest.name !== dirBasename) {
    throw new Error(
      `[skills:loader] manifest.name "${manifest.name}" does not match directory name "${dirBasename}" at ${manifestPath}`
    );
  }

  const promptPath = path.join(skillDir, 'prompt.md');
  if (!fs.existsSync(promptPath)) {
    throw new Error(`[skills:loader] missing prompt.md for skill "${manifest.name}" at ${promptPath}`);
  }
  const promptBody = fs.readFileSync(promptPath, 'utf8');

  // Optional skill-level partials (styles.md, topics.md, distractors.md).
  const partials: Record<string, string> = {};
  for (const fname of SKILL_ROOT_MD_FILES) {
    if (fname === 'prompt.md') continue;
    const fp = path.join(skillDir, fname);
    if (fs.existsSync(fp)) {
      partials[path.basename(fname, '.md')] = fs.readFileSync(fp, 'utf8');
    }
  }

  // Age profiles — declared in the manifest, required to exist on disk.
  const ageProfiles: Record<string, string> = {};
  if (manifest.ageProfiles && manifest.ageProfiles.length > 0) {
    const ageDir = path.join(skillDir, AGE_PROFILES_DIR);
    if (!fs.existsSync(ageDir) || !fs.statSync(ageDir).isDirectory()) {
      throw new Error(
        `[skills:loader] skill "${manifest.name}" declares ageProfiles but ${ageDir} does not exist`
      );
    }
    for (const age of manifest.ageProfiles) {
      const fp = path.join(ageDir, `${age}.md`);
      if (!fs.existsSync(fp)) {
        throw new Error(
          `[skills:loader] skill "${manifest.name}" declares ageProfile ${age} but ${fp} does not exist`
        );
      }
      ageProfiles[String(age)] = fs.readFileSync(fp, 'utf8');
    }
  }

  // Difficulty curves — same rules.
  const difficultyCurves: Record<string, string> = {};
  if (manifest.difficulties && manifest.difficulties.length > 0) {
    const diffDir = path.join(skillDir, DIFFICULTY_CURVES_DIR);
    if (!fs.existsSync(diffDir) || !fs.statSync(diffDir).isDirectory()) {
      throw new Error(
        `[skills:loader] skill "${manifest.name}" declares difficulties but ${diffDir} does not exist`
      );
    }
    for (const level of manifest.difficulties) {
      const fp = path.join(diffDir, `${level}.md`);
      if (!fs.existsSync(fp)) {
        throw new Error(
          `[skills:loader] skill "${manifest.name}" declares difficulty "${level}" but ${fp} does not exist`
        );
      }
      difficultyCurves[level] = fs.readFileSync(fp, 'utf8');
    }
  }

  // Optional per-skill Zod output validator. Looked up from the central
  // static registry (`validators/index.ts`) so the loader never touches a
  // TypeScript module at runtime — keeps vitest / tsx / prod happy with
  // one path. See S10-06-07 spike decision #3.
  const outputSchema = getOutputSchemaFor(manifest.name);

  return {
    manifest,
    dir: skillDir,
    promptBody,
    partials,
    ageProfiles,
    difficultyCurves,
    outputSchema,
  };
}

/**
 * Central-registry accessor. Resolved synchronously from the statically
 * imported `validators/index.ts` registry — no dynamic `require()` so
 * vitest / tsx / prod-node all behave identically.
 */
function getOutputSchemaFor(skillName: string): z.ZodTypeAny | undefined {
  return SKILL_OUTPUT_SCHEMAS[skillName];
}

/**
 * Walk `defs/_shared/` for `.hbs` / `.md` files. Each becomes a named
 * partial, keyed by basename-without-ext. The registry installs these
 * globally on the Handlebars instance at boot.
 */
export function loadSharedPartials(dir: string): SharedPartials {
  if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
    return { files: {}, dir };
  }
  const files: Record<string, string> = {};
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (!entry.isFile()) continue;
    const ext = path.extname(entry.name);
    if (ext !== '.hbs' && ext !== '.md') continue;
    const fp = path.join(dir, entry.name);
    const key = path.basename(entry.name, ext);
    files[key] = fs.readFileSync(fp, 'utf8');
  }
  return { files, dir };
}

/**
 * Resolve the defs directory from env / defaults. Exposed so dev tools
 * (and tests) can pin a known location without stomping on the real
 * boot path.
 */
export function resolveDefsDir(): string {
  const envOverride = process.env.NOVA_SKILLS_DEFS_DIR;
  if (envOverride && envOverride.trim().length > 0) {
    return path.resolve(envOverride);
  }
  return DEFAULT_DEFS_DIR;
}

// ---------------------------------------------------------------------------
// Small internal helpers
// ---------------------------------------------------------------------------

function readJson(fp: string): unknown {
  const raw = fs.readFileSync(fp, 'utf8');
  try {
    return JSON.parse(raw);
  } catch (err) {
    throw new Error(
      `[skills:loader] failed to parse ${fp}: ${err instanceof Error ? err.message : String(err)}`
    );
  }
}
