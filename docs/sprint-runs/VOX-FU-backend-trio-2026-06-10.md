# VOX-FU backend trio — PUBLIC_BASE_URL + empty-body POST + Oracle publish toggle

> Slice run summary, 2026-06-10. Single slice ("Slice D" from the
> session-handoff candidate list), executed directly by the session lead.
> Backend-only — gated by `tsc --noEmit` + vitest, no Xcode involved.
> Reconciled against `SPRINT-14-tracker.md` (VOX-FU carry-in, re-logged
> as debt when S14 was cancelled) and the V2 tracker's parallel dev lane.

---

## Meta

- **Slice:** S14-VOX-01 + S14-VOX-03 + S14-VOX-04 (the backend trio; S14-VOX-02 `devBypassLogin()` is iOS-side and stays open).
- **Agent:** session lead (Fable 5), direct execution.
- **Run window:** 2026-06-10.
- **Status:** ✅ delivered, fully gated, committed.

---

## 1. Goal restated

Retire the three backend items of the S13 touch-test follow-up debt:
(1) dev-mode asset URLs hard-code `http://localhost:3000` into the DB,
unreachable from the iPad; (2) no-body POSTs with a JSON content-type
are rejected by Fastify's stock parser, forcing the `curl -d '{}'`
workaround; (3) Oracle's Content Browser has no way to publish/unpublish
a lesson — the authoring → "real content on iOS" gap needs curl.

## 2. Files changed

| File | What |
|---|---|
| `src/config.ts` | New `PUBLIC_BASE_URL` env var (optional, validated URL). |
| `src/services/assets/assetUploader.ts` | Dev-mode local fallback URL uses `PUBLIC_BASE_URL ?? http://localhost:PORT` (trailing-slash safe). The iOS-side localhost rewrite stays as defensive fallback for pre-existing rows. |
| `src/server.ts` | Replacement `application/json` content-type parser: empty/whitespace body → `undefined` (same as no body); malformed JSON still 400. Registered before all routes — every no-body action endpoint benefits. |
| `src/routes/lessons.ts` | New `POST /lessons/:id/unpublish` — mirror of `/publish` (auth + ownership + 404 checks), sets `status: 'draft'`, `publishedAt: null`. |
| `public/dev-pipeline.html` | Content Browser: per-row ⬆ publish / ⬇ unpublish toggle (no confirm — reversible one-click actions), and a "⬆ Publish all drafts (N)" bulk bar above the lesson list when the selected path has drafts (native confirm, sequential POSTs so partial failure is legible). |
| `tests/voxFollowups.test.ts` | 4 new tests — see validation. |

## 3. Acceptance criteria (from S14 tracker rows)

| Criterion | Met |
|---|---|
| VOX-01: `assetUploader` reads `config.PUBLIC_BASE_URL`, default `http://localhost:PORT` | ✅ — test pins the exact URL shape with the var set. |
| VOX-03: no-body POST works without `-d '{}'` | ✅ — wire test proves the parser no longer 400s an empty-body JSON POST; malformed JSON still 400s. |
| VOX-04: per-lesson publish/unpublish in Oracle + bulk path-level publish | ✅ — row toggle + bulk bar; new `/unpublish` endpoint backs the revert direction. |

## 4. In-plan vs drift

In-plan, three notes:
1. The tracker's VOX-03 suggested per-route `{ Body: void }` typing; a
   **global tolerant parser** was chosen instead — one registration
   covers `/publish`, `/unpublish`, pipeline retriggers, and every
   future no-body action route, instead of whack-a-mole per route.
2. Bulk publish is **client-side sequential** over the existing
   `/publish` endpoint rather than a new bulk backend route — N ≤ 100
   in the dev console, and per-lesson failure reporting falls out free.
3. VOX-02 (`devBypassLogin()` mints a real JWT) is **not** in this
   slice — it's iOS-side, separate lane, still open debt.

## 5. Validation

- `npx tsc --noEmit` → **33 errors, exactly the pre-existing baseline** (zero new).
- `npx vitest run` → **842/842 passed, 31 files** — full suite, important because the JSON parser change is global wire behavior.
- New `tests/voxFollowups.test.ts` (4 tests): PUBLIC_BASE_URL baked into dev asset URL (env hoisted via `vi.hoisted` — config caches at first import-time `getConfig()`); empty-body POST not parser-rejected; malformed JSON still 400; `/unpublish` route registered (distinguishes router-404 from domain-404).
- Oracle UI verified by code review + the publish/unpublish endpoints exercised through the wire tests; a live click-through needs the backend + browser running (one-minute check next time Oracle is open).

## 6. Reviewer / next-agent notes

- `PUBLIC_BASE_URL` is **not** set in `.env` by this slice — bang sets
  it to his Mac's LAN IP (e.g. `http://192.168.7.50:3000`) when prepping
  an iPad demo. Unset behavior is unchanged.
- The empty-body parser returns `undefined` as the body, which is what
  Fastify produces for a POST with no content-type — downstream Zod
  `validateBody` schemas treat both shapes identically.
- Rows minted before `PUBLIC_BASE_URL` was set still carry localhost
  URLs — the iOS rewrite in `CardHeroImage` handles those; don't remove
  it.
