# iOS↔backend auth contract fix — /auth/apple seam

> Slice run summary, 2026-06-10. Single slice from carry-debt (logged
> during the VOX-02 triage), executed directly by the session lead.

---

## Meta

- **Slice:** carry-debt row "iOS `/auth/signin` ↔ backend `/auth/apple` mismatch".
- **Agent:** session lead (Fable 5), direct execution.
- **Run window:** 2026-06-10.
- **Status:** ✅ delivered, gated, committed.

---

## 1. What was actually broken (worse than logged)

Five independent breaks meant real Apple SSO could never have worked:

1. **Wrong path** — iOS posted `/auth/signin`; the backend route is `/auth/apple`.
2. **Wrong request body** — iOS sent `{ token }`; the schema requires `{ identityToken, appleId, displayName?, email? }`. The login view never even extracted the identity token / name / email from the Apple credential.
3. **Encoder/schema key-case clash** — APIClient encodes bodies with `.convertToSnakeCase`, but the backend zod schemas are camelCase. iOS *cannot* emit camelCase keys under that encoder.
4. **Undecodable responses** — `SignInResponse`/`TokenResponse` expected snake_case keys and a full `User` (with `createdAt`); the backend ships camelCase and a minimal user.
5. **Refresh-rotation bug** — the backend rotates BOTH tokens on refresh; iOS stored the new access token but kept the stale refresh token → second refresh cycle dies.

## 2. Files changed

| Side | File | What |
|---|---|---|
| Backend | `src/routes/auth.ts` | `appleSignInSchema` + `refreshTokenSchema` wrapped in a `promoteSnakeCaseKeys` preprocess — tolerant reader accepting both key styles (same posture as the empty-body parser and iOS's QuizOption dual-decode). |
| Backend | `tests/authContract.test.ts` | 2 wire tests posting the EXACT bytes iOS produces (snake keys): sign-in accepted + camelCase response shape pinned + refresh-with-rotation round trip; camelCase body still accepted. |
| iOS | `NovaCore/API/Endpoint.swift` | `signIn` → path `/auth/apple`, full credential body. `refreshToken` body key fixed. |
| iOS | `NovaAuth/AuthManager.swift` | `signInWithApple(appleId:identityToken:displayName:email:)` (was `credential:`); decodes the unified `AuthTokenResponse` (replaces `SignInResponse`/`TokenResponse`/`DevBypassResponse` — the backend ships one shape for all three routes); `refreshToken()` now stores the rotated refresh token. |
| iOS | `NovaKids/ViewModels/AuthViewModel.swift`, `Views/Auth/KidsLoginView.swift` | The login flow now extracts identityToken (UTF-8), formatted full name, and email from `ASAuthorizationAppleIDCredential` (name/email arrive on FIRST authorization only) and passes them through. |

## 3. Validation

- Backend: new contract tests green; **vitest 845/845** (one flaky `sprint6` Dashy length test failed once, green in isolation and on full re-run — pre-existing flake, unrelated file); `tsc --noEmit` **0**.
- iOS: NovaKids `xcodebuild` **BUILD SUCCEEDED**.
- End-to-end Apple SSO still needs a device + Apple entitlements to exercise for real — but every layer now agrees on path, keys, and shapes, and the wire bytes iOS produces are pinned by backend tests.

## 4. New debt discovered (logged, not fixed here)

**The encode-side contract class is wider than auth.** The
`.convertToSnakeCase` encoder vs camelCase zod schemas affects other
POST bodies (`childAge` → `child_age` in the Dashy chat body; the sync
`interactions` payload; pipeline `ingest_id`/`lesson_id` bodies look
deliberately snake-cased — backend schemas need cross-referencing
endpoint by endpoint). Each mismatched optional key is silently
dropped; each mismatched required key 400s. Needs its own audit slice —
the decode side has ContractTests, the encode side has nothing.

## 5. Reviewer / next-agent notes

- Apple name/email are **first-authorization-only**: testing repeat
  sign-ins won't carry them; revoke the app's Sign in with Apple grant
  to re-test the first-auth path.
- The backend still doesn't verify `identityToken` with Apple
  (pre-existing TODO at the route) — fine for dev, required before
  production.
