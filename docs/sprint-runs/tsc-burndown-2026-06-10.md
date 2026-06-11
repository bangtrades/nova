# Backend tsc burndown — 33 → 0

> Slice run summary, 2026-06-10. Single slice from the V2 tracker's
> parallel dev lane (audit-recommended), executed directly by the
> session lead.

---

## Meta

- **Slice:** "Backend `tsc` baseline burndown — 33 errors (down from 51 cited in S12/S13 trackers); finish it to zero."
- **Agent:** session lead (Fable 5), direct execution.
- **Run window:** 2026-06-10.
- **Status:** ✅ delivered — `npx tsc --noEmit` is **clean**. The "non-zero by design" baseline era is over; CI/agents can now treat any tsc error as a regression.

---

## 1. Root cause (one class, 31 of 33 errors)

The schema stores JSON as TEXT (`content String // JSON stored as text
(SQLite compat)`) — but a Prisma `$use` middleware in `db/client.ts`
transparently stringifies those fields on write and parses them on
read. So the **runtime contract is "pass and receive objects"** while
the **generated client types say `string`**. Every call site that
honored the runtime contract type-errored; the codebase had been
carrying scattered `as Prisma.InputJsonValue` casts that silenced some
sites and not others.

## 2. The fix

Two documented helpers in `db/client.ts` — the single sanctioned cast
across the middleware boundary, greppable, deletable in one sweep if
the schema ever migrates to native `Json`:

- `toJsonColumn(value): string` — write-side.
- `fromJsonColumn<T>(value): T` — read-side.

Converted all sites: `db/seed.ts` (16 object literals, scripted with
brace-matching), `routes/cards.ts` (4), `routes/progress.ts`,
`routes/badges.ts`, `services/assets/assetJobProcessor.ts` (4 + 1),
`services/pipeline/pipelineOrchestrator.ts` (3),
`services/pipeline/badgeCriteriaEngine.ts`. Unused `Prisma` imports
dropped.

Two errors were different classes:
- `seedKnowledgeGraph.ts` — `import.meta` under a CJS tsconfig →
  replaced with a `process.argv` CLI-entrypoint check (identical
  behavior under `tsx`).
- `assetJobProcessor.ts:379` — `outputUrl: string | null` vs the
  declared `string | undefined` status shape → normalized at the
  boundary (`?? undefined`).

## 3. Latent bug fixed along the way

`routes/progress.ts` wrote `Prisma.JsonNull` into a **String** column
when an interaction had no result — the middleware would stringify
that sentinel object into garbage text. Now writes SQL `NULL`.

## 4. Validation

- `npx tsc --noEmit` → **0 errors** (was 33).
- `npx vitest run` → **843/843, 31 files** — full suite, deliberately,
  since seed/pipeline/asset paths were touched.
- Runtime behavior preserved: every conversion is a type-level cast at
  the documented middleware boundary; no serialization logic changed
  (except the JsonNull fix above, which corrects behavior).

## 5. Reviewer / next-agent notes

- **New invariant: `tsc --noEmit` must stay at 0.** Trackers citing the
  "33-error baseline" are historical.
- The long-term clean fix remains migrating the TEXT columns to native
  `Json` on Postgres (the SQLite-compat constraint is also what blocks
  prod deployment topology — S8 infrastructure territory). The helpers
  mark every site that migration must touch.
