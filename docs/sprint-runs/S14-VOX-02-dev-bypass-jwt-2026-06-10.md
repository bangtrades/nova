# S14-VOX-02 — devBypassLogin() mints a real JWT

> Slice run summary, 2026-06-10. Single slice (the last open VOX-FU
> item), executed directly by the session lead. Spans the iOS↔backend
> seam — gated on both sides.

---

## Meta

- **Slice:** S14-VOX-02 ("iOS `AuthManager.devBypassLogin()` actually hits `POST /api/v1/auth/dev-bypass`, gets a JWT, stores via `updateTokens(...)`").
- **Agent:** session lead (Fable 5), direct execution.
- **Run window:** 2026-06-10.
- **Status:** ✅ delivered, gated, committed. **VOX-FU debt is now fully retired.**

---

## 1. Goal restated

`devBypassLogin()` faked authenticated state with a locally-fabricated
`User` and **no tokens** — the UI said signed-in while every API call
rode whatever stale token the keychain held (the failure mode that cost
30 minutes of demo prep). The backend had no dev-bypass endpoint at all.

## 2. Files changed

| Side | File | What |
|---|---|---|
| Backend | `src/routes/auth.ts` | New `POST /auth/dev-bypass`: finds-or-creates the deterministic `dev.tester` user (+ free subscription, mirroring `/apple`), mints a real pair via `generateTokenPair`. **Hard-gated**: `NODE_ENV=production` → 404 in the same shape as an unregistered route. |
| Backend | `src/middleware/auth.ts` | `/api/v1/auth/dev-bypass` added to `PUBLIC_ROUTES` (a login can't require a token; the handler's production 404 keeps it non-discoverable where it matters). |
| Backend | `tests/voxFollowups.test.ts` | VOX-02 wire test — 200 + tokens + "Dev Tester" with a live DB, 500 without one, never router-404. Caught the missing PUBLIC_ROUTES entry on first run (401). |
| iOS | `Packages/NovaCore/.../Endpoint.swift` | `Endpoint.devBypass()` — POST, no body, `requiresAuth: false`. |
| iOS | `Packages/NovaAuth/.../AuthManager.swift` | `devBypassLogin()` now calls the endpoint, stores the real pair via `updateTokens(...)`, and builds the session user from the response. Backend unreachable → falls back to the legacy local-only mock (offline UI work still possible, explicitly documented as token-less). New `DevBypassResponse` type keyed to the actual camelCase wire shape — the existing `SignInResponse` expects snake-case keys and a full `User` (with `createdAt`) that this endpoint doesn't ship. |

## 3. Acceptance criteria

| Criterion | Met |
|---|---|
| `devBypassLogin()` hits `POST /api/v1/auth/dev-bypass` | ✅ |
| Gets a real JWT pair, stored via `updateTokens(...)` | ✅ |
| Stale-keychain failure mode eliminated | ✅ — fresh tokens on every bypass login when the backend is up. |
| Production exposure | ✅ none — handler 404s under `NODE_ENV=production`. |

## 4. In-plan vs drift

In-plan. One addition beyond the tracker row: the offline fallback to
the old mock behavior, so UI development without a running backend
doesn't regress to a login wall.

## 5. Validation

- Backend: `tsc --noEmit` at the **33-error baseline** (zero new); **vitest 843/843** (suite-wide).
- iOS: `xcodebuild` NovaKids → **BUILD SUCCEEDED**.
- **Triage finding:** NovaCompanion's scheme does **not** build — `CompanionPalette.swift` references `NovaPalette`, which lives only in the NovaKids target, and has since the initial commit. Pre-existing (zero diffs under NovaCompanion this session; the only pbxproj edit was the 4 EnhancedHomeView deletions). Logged as new carry-debt, not fixed here.

## 6. Reviewer / next-agent notes

- The dev user is deterministic (`appleId: dev.tester`) — repeated
  bypass logins reuse one row, no DB litter.
- iOS's legacy `/auth/signin` + snake-case `SignInResponse` looks
  mismatched against the backend's `/auth/apple` + camelCase response —
  pre-existing, untouched, worth its own look before Apple SSO is
  exercised end-to-end (noted, not in this slice's scope).
