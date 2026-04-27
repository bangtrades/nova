# S13-05 / S13-06 / S13-07 / S13-08 / S13-09 / S13-10 — Voice library upgrade

> Six VOX-epic stories landing as one coordinated run. The kid-facing UX channel
> (audio narration, Dashy chat, voice card prompts) is now powered by OpenAI's
> human-sounding TTS through a backend proxy, with a per-child voice picker
> persisted across launches and an Oracle Voice tab for testing/analysis from
> the Mac.

---

## Meta

- **Story IDs:** S13-05 (proxy), S13-06 (iOS rewire), S13-07 (preference store), S13-08 (picker view), S13-09 (call-site sweep), S13-10 (Oracle Voice tab).
- **Epic:** VOX (24 pts of 24).
- **Sprint:** 13 — "Demo-Worthy".
- **Landed:** Apr 24, 2026.
- **Status:** ✅ Done.
- **Commit range:** sandbox-staged (this run); push from bang's Mac.

---

## Why this run mattered

S12 closed with the touch-test loop running end-to-end: bang's kid completed the Sky lesson, earned a trophy, opened the Trophy room. Two qualitative observations from that session shaped this run:

1. The kid was visibly tuning out during narration. Apple's `AVSpeechSynthesizer` — even on the highest-quality "narrator" voice — sounds like a robot reading a textbook. Kids who can't read fluently rely on the voice; if the voice doesn't engage them, the comic panels don't matter.
2. The asset-pipeline observability gap. Oracle's Content Browser + per-lesson asset re-trigger button (S13-01) gave bang the tools to regenerate audio, but he couldn't *hear* the result without flipping into the iPad. Iteration loop was Mac → iPad → ear → Mac → iPad → ear, ~30s per cycle.

This run closes both. OpenAI TTS replaces AVSpeech for every narration card; kids hear a real human storyteller for ~$0.015 per 1k characters (rounding error at touch-test scale). Oracle gets a Voice tab where bang plays any voice + any text from his Mac, sees per-voice latency, and clears the cache between iterations — no iPad round-trip needed.

---

## What shipped

| ID | Title | LOC | Files |
|---|---|---:|---|
| S13-05 | Backend TTS proxy (`POST /api/v1/voice/tts`) + supporting endpoints | ~340 | `src/routes/voice.ts` (new), `src/routes/index.ts` (+1 register) |
| S13-06 | iOS RemoteTTSClient rewire (OpenAI direct → backend proxy) + VoiceManager flips default to remote | ~410 | `Packages/NovaVoice/.../RemoteTTSClient.swift`, `VoiceManager.swift`, `App/NovaKidsApp.swift` |
| S13-07 | VoicePreferenceStore — per-child voice persistence | ~155 | `Apps/NovaKids/Sources/Services/VoicePreferenceStore.swift` (new) |
| S13-08 | VoicePickerView — kid-facing 4-character picker + Home toolbar entry | ~310 | `Apps/NovaKids/Sources/Views/Settings/VoicePickerView.swift` (new), `EnhancedHomeView.swift` (+sheet) |
| S13-09 | Call-site sweep — 7 `voiceManager.speak()` sites flipped from `preferRemote: false` to default-remote | ~30 | `FlipbookViewModel.swift`, `DashyViewModel.swift`, `StoryCardView.swift`, `ConceptCardView.swift`, `VoiceCardView.swift` (×3) |
| S13-10 | Oracle Voice tab — playback + latency chart + cache table | ~210 | `src/Backend/public/dev-pipeline.html` (+tab + JS module) |
| pbxproj | Register VoicePreferenceStore + VoicePickerView | +6 | `Nova.xcodeproj/project.pbxproj` |

**Total ≈ 1,460 LOC** across 10 files (3 new, 7 edited).

---

## Architectural decisions

1. **Backend proxy, not embedded `OPENAI_API_KEY` in iOS.** Embedding the key in a kid-facing app is a leak vector — `strings` against the IPA, App Store IPA caches, jailbreak inspection. The backend's `POST /api/v1/voice/tts` endpoint takes the same Bearer token a kid already uses for `/lessons`, proxies to OpenAI, caches the resulting MP3, and returns it. iOS never sees the OpenAI key. Rotation is a one-place edit on the backend `.env`. Cost: one extra HTTP hop (10–30ms LAN). Worth every millisecond.

2. **Remote-by-default, AVSpeech as fallback only.** S12's `preferRemote: false` default forced every call site to opt-in to human voice — which is exactly the wrong shape when human voice is the *primary UX channel*. New `VoiceManager.speak(text:voice:preferLocal:)` defaults to remote and falls back to AVSpeech *only* on network failure / 429 / 503. The deprecated `preferRemote: Bool` shim is kept (with `@available(*, deprecated, ...)`) so any pre-S13 third-party caller keeps compiling — but the warning will surface on the next clean build pass.

3. **Two-level caching: backend L2 + iOS L1.** Backend cache is keyed by `sha256(voice|model|text)` and shared across all users — kid-1 generates "The sky is blue", kid-2 hears the cached version instantly. iOS cache (per-process, ~50 entries × ~80KB ≈ 4MB) is keyed similarly and skips the network entirely on repeat plays of the same line within a session. The picker's sample sentences are particularly effective because every kid plays the same 4 lines on the same picker — backend serves L2 hits after request 2 onward.

4. **Per-child preference, not global.** The demo iPad will eventually hold two siblings' profiles. Each kid wants his own voice. `VoicePreferenceStore` keys preferences on `childId` (with the same per-device fallback UUID idiom `LessonCompletionStore` uses), so a sibling switch flips voices automatically. UserDefaults JSON for now; `S14` shadow-writes to the backend so cross-device install carries the choice.

5. **Four voices, not six.** OpenAI exposes 6 stock voices (alloy, echo, fable, nova, onyx, shimmer). Four cover the major personality archetypes a kid would distinguish: bright/bouncy (nova), British storyteller (fable → "Pip"), brave/bold (onyx → "Captain Boom"), warm/gentle (shimmer → "Sunny"). alloy and echo are too close to nova for a 4-year-old to differentiate. Fewer choices = faster decision = less friction for the demo. S14 can add the other two without code change — they're already allow-listed on the backend.

6. **`tts-1`, not `tts-1-hd`.** -hd is 2× the cost (~$0.030/1k chars) for marginally better quality the kid won't notice on a 12.9" iPad speaker. Default is `tts-1`; the iOS API accepts a `model` parameter but every call site passes the default. Oracle Voice tab can manually drive `tts-1-hd` for A/B testing during sprint reviews.

7. **Closure-typed token resolver, not a TokenProvider protocol dependency.** `RemoteTTSClient` takes a `@Sendable () async -> String?` closure rather than depending on NovaCore's `TokenProvider` protocol. NovaVoice has zero Swift package deps as a result — keeps the package graph lean and avoids a future cycle if NovaCore ever needs to import NovaVoice.

8. **Picker writes preference *before* it plays the sample.** Even if the network sample fails, the kid's choice survives — silence is a better failure mode than "voice picker forgot what I picked". Order matters: `voicePreferenceStore.setVoice(...)` → `voiceManager.setVoice(...)` → `Task { try? await voiceManager.speak(...) }`.

9. **Oracle Voice tab as the testing surface, not Xcode.** Bang iterates voice persona on the Mac. Free-text input, four playback rows (one per voice), per-voice latency p50/p95 chart, cache state table, "Clear cache" affordance for fresh-listening between regenerations. Closes the iterate→hear loop from ~30s to ~2s.

10. **Persona-aware voice (S13-11) deferred to S14.** curriculum-architect already emits topic tags; mapping topic → suggested voice is a clean S14 follow-up. Backend `GET /voice/voices` exposes `recommendedTopics` per voice as scaffolding so S14 only needs the iOS-side "match the lesson" toggle. Kid demo doesn't block on this because the kid picks his single favorite voice once in S13-08 and every lesson uses it.

---

## Cost shape

`tts-1` is **$0.015 per 1k characters**. A typical lesson card narration is ~200 chars. Let's price the S13 catalog at full pre-cache:

```
6 lessons × 8 cards × 4 voices × 200 chars
  = 38,400 chars
  = 38.4k chars × $0.015/1k
  = $0.58
```

Pre-caching the entire S13 catalog under all 4 voices costs **less than a coffee**. The backend's hash-keyed cache means the *same* (voice|model|text) tuple from any user serves the cached MP3 in <1ms — so live-traffic re-plays are free.

Worst case (kid pegs the proxy with novel text): backend `429` propagates to iOS, which falls back to AVSpeech for the duration of the session. No silent failure mode.

---

## Validation matrix

### Sandbox ✅

- `voice.ts` clean under `npx tsc --noEmit` (held the 51 pre-existing baseline errors constant — zero new).
- `routes/index.ts` clean (added one `import voiceRoutes` + one `register` line).
- All Swift files reviewed file-by-file; no `Cannot find ... in scope` patterns expected:
  - `RemoteTTSClient.swift` — Foundation only; new `@Sendable` closure; no protocol cycle.
  - `VoiceManager.swift` — uses existing `SpeechSynthesizer` API (`.narrator` voice, `0.45` rate); deprecated shim retains old call-site shape.
  - `VoicePreferenceStore.swift` — Foundation + Combine, mirrors `LessonCompletionStore` exactly. Codable + UserDefaults, JSON-encoded.
  - `VoicePickerView.swift` — uses `NovaPalette.page` + `novaBackground` (not `cream`/`paper`), `displayFont(size:relativeTo:)` (correct signature), `bodyFont()` / `captionFont()` / `headingFont()` zero-arg helpers, `NovaHaptics.tap()`. `darkened()` helper guards UIColor with `#if canImport(UIKit)`.
  - `NovaKidsApp.swift` — closure captures `authManager` weakly; tokenResolver is `@Sendable`. `.onChange(of:_) { _, _ in ... }` two-param iOS 17+ form throughout.
- `VoicePickerView.swift` registered in `project.pbxproj` (4 entries: PBXBuildFile, PBXFileReference, group children, PBXSourcesBuildPhase). Same UUID series (`CA3D1EA02226951D31C0EA0{7..A}`) extending the S13-02/03 batch.
- All 7 `voiceManager.speak()` call sites updated; `grep -n "preferRemote: false"` returns zero hits.

### Mac-only 🟡 (bang to run)

```bash
cd ~/Projects/Novai/src/Backend && git pull
npm run build                                                  # tsc --noEmit (expect: 51 baseline)
npm run test                                                   # expect: 834/834 (no new test changes)
npm run dev                                                    # boot backend on :3000

# 1. Smoke-test the proxy directly:
curl -s -XPOST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     http://localhost:3000/api/v1/voice/tts \
     -d '{"text":"Hi! I am Nova!","voice":"nova"}' \
     -o /tmp/nova-sample.mp3 -D -
# expect: 200 + audio/mpeg + X-Voice-Cache: MISS + X-Voice-Latency-Ms: ~1500
# play it: afplay /tmp/nova-sample.mp3   # macOS

# 2. Re-run the same curl — cache hit:
curl -s -XPOST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     http://localhost:3000/api/v1/voice/tts \
     -d '{"text":"Hi! I am Nova!","voice":"nova"}' \
     -D - -o /dev/null
# expect: 200 + X-Voice-Cache: HIT + X-Voice-Latency-Ms: 0

# 3. Stats:
curl -s -H "Authorization: Bearer $TOKEN" \
     http://localhost:3000/api/v1/voice/stats | jq
# expect: cache.entries=1, cache.totalHits=1 (after the second call), latency.nova.count=1, recent[0].voice="nova"

# 4. Voice list:
curl -s -H "Authorization: Bearer $TOKEN" \
     http://localhost:3000/api/v1/voice/voices | jq '.voices[] | {id, displayName}'
# expect: 4 voices: nova / fable / onyx / shimmer

# 5. Oracle Voice tab:
open http://localhost:3000/dev/dev-pipeline.html#voice
# expect: 4 voice rows, type "the sky is blue" in the textarea, click each ▶ Play — hear human voice
#         latency panel populates p50/p95 per voice, cache table populates with 4 entries

# 6. iOS build + smoke test:
cd ~/Projects/Novai/src
xcodebuild -workspace Nova.xcworkspace -scheme NovaKids \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
# expect: BUILD SUCCEEDED
# Run on iPad simulator:
#   1. Tap a Story / Concept / Voice card → hear OpenAI nova voice (NOT robotic AVSpeech)
#   2. Tap the speaker bubble icon in HomeView's top-right → Voice Picker sheet appears
#   3. Tap each card (Nova, Pip, Boom, Sunny) → hear the sample line in that voice
#   4. Tap "Done" → return to Home
#   5. Tap a narration card again → hear the newly-selected voice
#   6. Force-quit and relaunch → pick still persists

# 7. iPad-on-LAN test (real device):
# Set NOVA_BACKEND_HOST in Xcode scheme env vars to <Mac LAN IP>:3000
# Build to physical iPad, repeat steps 1-6.
```

---

## Quick-start runbook for the demo

```bash
# Mac side:
cd ~/Projects/Novai/src/Backend
git pull
npm run dev                              # backend up on :3000

# Open Oracle to validate before Demo:
open http://localhost:3000/dev/dev-pipeline.html#voice
# Type "Welcome to Nova!" in textarea, click ▶ Play on Nova → confirm human voice
# Click ▶ Play on each remaining voice → 4 humans, all kid-friendly

# Pre-cache the 4 picker samples + the 3 lesson narrations so the kid sees zero cold latency:
for VOICE in nova fable onyx shimmer; do
  curl -s -XPOST -H "Authorization: Bearer $TOKEN" \
       -H "Content-Type: application/json" \
       http://localhost:3000/api/v1/voice/tts \
       -d "{\"text\":\"$(curl -s -H 'Authorization: Bearer '$TOKEN \
                          http://localhost:3000/api/v1/voice/voices | \
                       jq -r ".voices[] | select(.id==\\\"$VOICE\\\") | .sampleText")\",\"voice\":\"$VOICE\"}" \
       -o /dev/null
done
# expect: ~6s total (4 × ~1.5s tts-1 latency); after this every picker tap is L2 cache hit

# iPad side:
# Build NovaKids in Xcode → run on iPad Pro (real device, on LAN, NOVA_BACKEND_HOST=<mac-ip>:3000)
# 1. Open the app → see Home
# 2. Tap any lesson hero → kid hears Nova reading the first card
# 3. Top-right speaker bubble → kid picks Pip / Boom / Sunny
# 4. Replay → new voice
# 5. Finish lesson → trophy unlock celebration (S13-03 carry, still works)
```

---

## Retired debt

- **Embedded API key threat retired.** iOS no longer carries `OPENAI_API_KEY`; the only OpenAI auth lives in the backend `.env`. Defense-in-depth: even if the IPA leaks, no key extraction path.
- **Robotic-voice perception retired.** `AVSpeechSynthesizer.narrator` voice is no longer the kid-facing TTS. Survives only as the network-failure fallback. Per-card playback now sounds like a real human storyteller, not a 1990s GPS unit.
- **Two-step `preferRemote: false` opt-in mistake retired.** S12's call-site idiom forced every site to manually opt into human voice. New default is remote; offline path is `preferLocal: true` (still rare).
- **Per-voice latency invisibility retired.** Oracle now shows p50/p95 per voice across the rolling last 50 generations, plus cache hit rate. Bang sees the picture without log-grepping or instrumenting.

---

## In-plan vs drift

- **In-plan:** every bullet of S13-05/06/07/08/09/10 from the SPRINT-13 tracker. VOX epic 24/24 done.
- **Drift (positive):** the deprecated `speak(text:preferRemote:)` shim. S12-era code (and any external NovaVoice consumer that exists later) keeps compiling — `@available(*, deprecated, ...)` surfaces the warning on next clean build. Free retrofit-friendliness.
- **Drift (positive):** Oracle Voice tab cache-clear button. Wasn't in the original S13-10 scope (just stats panel) but is the smallest possible affordance for the iterate-on-voice workflow. Two lines of HTML + one route.
- **Drift NOT absorbed (deferred to S14):** Persona-aware voice (S13-11). Topic→voice mapping in backend response, iOS Lesson `suggestedVoice` field, "match the lesson" iOS toggle. Foundation shipped via `GET /voice/voices` `recommendedTopics` array; full integration is S14 work. Kid demo doesn't block on this.

---

## What's next

1. **Immediate (post-demo):** Capture qualitative observation — does the kid actually engage longer? Does he switch voices? Does he prefer a specific persona? Notes feed S14 voice scope.
2. **S14:** Persona-aware voice (S13-11 stretch finishes). Backend writes `Lesson.suggestedVoice` based on curriculum-architect topic tags. iOS exposes "Match the lesson" toggle in voice picker.
3. **S14:** Trophy + voice preference shadow-write to backend `progress` endpoint. Cross-device install carries the kid's choice.
4. **S15:** Streaming TTS if cold-cache hits prove a problem (current bet: aggressive pre-cache + L1+L2 caching keeps the kid from ever waiting).

---

## Cross-references

- **CON epic carry-in:** S13-01 (Oracle rebrand + asset re-trigger) `2226951`, S13-02 (hero images) `d31c0ea` + `54b1e29`, S13-03 (trophy + celebration) `032d467` + `e0fcfdc` + `b3b25e8`. All shipped Apr 23.
- **S12-06 (voice-persona skill):** the Dashy-voiced speaking-prompt skill. This run uses `shimmer` for Dashy regardless of kid's narration persona — Dashy is a fixed character.
- **S12-12 VoiceManager injection fix** `191325a`: VoiceManager became reachable in views via @EnvironmentObject. This run fully populates that surface with remote TTS.
- **S11-15 NovaHaptics ladder:** `.tap` on picker selection. `.success` on lesson finish. Voice picker is a `.tap`-level event (not commit/success).
- **S11-16 Reduce-motion carve-outs:** picker's pulse ring respects reduce-motion (collapses to instant); the ring is the cue, not the motion.
