# S12-10 Preflight iOS Audit — Card Views Touch-Test Readiness

Audit pass across the four card views (Story/Quiz/Experiment/Voice) that will render S12-10's seeded content. Two touch-test blockers **fixed in-sandbox**; five lower-severity findings **documented as carve-outs** for S13+ or noted for bang's iPad regression pass.

## 🔴 Fixed in-sandbox (blocks S12-10 DoD)

### Blocker 1 — `Card.CardContent` missing 3 S12-06 fields

**File:** `src/Packages/NovaCore/Sources/NovaCore/Models/Card.swift`

The S12-06 `voice-persona` skill emits five fields on every voice card: `promptText`, `expectedResponses`, **`celebration`**, **`retryHint`**, optional **`phonetics`**. The iPad decoder only declared the first two. The other three were silently dropped by `Codable`'s default behavior (unknown JSON keys ignored) — the entire Dashy-voice reward loop was invisible on the client.

**Fix applied:** added three new optional `String` properties + `CodingKeys` entries + init params. Decoder now picks up all five fields.

```swift
// Before
public var promptText: String?
public var expectedResponses: [String]?

// After
public var promptText: String?
public var expectedResponses: [String]?
public var celebration: String?
public var retryHint: String?
public var phonetics: String?
```

### Blocker 2 — `VoiceCardView` hardcoded "That's a great answer!" ignoring skill output

**File:** `src/Apps/NovaKids/Sources/Views/Flipbook/VoiceCardView.swift`

The S11-13 implementation of `VoiceCardView` was written before the voice-persona skill existed. Its `showResponse(for transcript:)` method generated a canned `"That's a great answer! You said: \"\(transcript.prefix(50))...\""` string regardless of whether the transcript matched any `expectedResponses` entry. The skill-engine-generated `celebration` + `retryHint` lines were never spoken — the whole validator-enforced Dashy-voice contract was wasted.

**Fix applied:** full rewrite (~300 LOC) that wires the skill output through:

- **Explicit `Phase` state machine** — `idle → listening → matching → celebrating | reprompting → idle|Next`. Replaces scattered `@State var isRecording/isProcessing/isResponding` booleans with an exhaustive union that the view can `switch` on.
- **Fuzzy bidirectional transcript match** against `expectedResponses` — `normalize(lowercase + whitespace-collapse + strip trailing .,!?)` both sides, then accept if either side `contains` the other. Tolerates the near-misses real kids produce ("a kitten" vs "kitten", "mammals" vs "a mammal").
- **TTS playback via `voiceManager.speak(text:)`** for both celebration (on match) and retryHint (on miss). After retryHint plays, loops back to `.idle` so the kid can try again with the same prompt visible.
- **S11-02 comic palette** (`ink` / `coral` / `sun` / `page` / `novaCardBackground`) instead of pre-rebase `novaPurple/novaBlue/novaOrange`.
- **S11-03 button styles** (`.novaPrimary()`, `.novaSecondary()`) for the Next / Skip-for-now footer buttons.
- **S11-04 `displayFont(size:relativeTo:)`** + `.minimumScaleFactor()` pairs for Dynamic Type scaling from `.xSmall` to `.accessibility5`.
- **S11-15 `NovaHaptics` ladder** — `.tap` on mic start, `.success` on match, `.wrong` on miss.
- **`TimelineView(.animation)` + source-level reduce-motion gate** for the listening pulse ring (previously `Timer.scheduledTimer` + direct `@State` mutation, which races under Swift 6 strict concurrency).
- **`@MainActor Task` for the speech recognizer loop** so the audio engine + transcript @Published mutations stay on the main actor.
- **Accessibility labels + hints on the mic button** — "Start listening / Stop listening" with "Double-tap to answer Dashy's question" hint (S11-17 + S11-18 standards).
- **"Skip for now" bail-out** after a miss so the kid isn't trapped in an infinite loop if speech recognition mis-transcribes systematically.

The rewrite preserves the public `init(card: Card)` signature so call sites (FlipbookView etc.) compile unchanged.

## 🟡 Carve-outs (non-blocking; flag for S13 or bang's iPad pass)

### Findings from the broader audit

These surfaced during the card-view sweep. None block S12-10 or S12-11, but all are worth noting.

### StoryCardView — Dynamic Type scale factor gap

**File:** `src/Apps/NovaKids/Sources/Views/Flipbook/StoryCardView.swift` line 80
**Issue:** `.lineLimit(3)` on `narrativeText` without `.minimumScaleFactor()`. At `.accessibility5` the text truncates mid-word rather than shrinking to fit.
**Fix (trivial, 1 line):** add `.minimumScaleFactor(0.8)` before the `.lineLimit(3)`.
**Deferred because:** not a touch-test blocker — prose still reads at standard sizes. Catch in the next S12-02-style sweep.

### ExperimentCardView — two palette + scale-factor nits

**File:** `src/Apps/NovaKids/Sources/Views/Flipbook/ExperimentCardView.swift`
- Line 82 — `.lineLimit(2)` on instructions missing `.minimumScaleFactor()`. Same pattern as StoryCardView:80.
- Line 148 — `.foregroundStyle(NovaPalette.novaYellow)` uses old back-compat alias. Should use `NovaPalette.sun` from the S11-02 3+1.
**Deferred because:** both cosmetic, touch-test still works.

### ExperimentCardView — `ShakeModifier` Timer data race

**File:** `src/Apps/NovaKids/Sources/Views/Flipbook/ExperimentCardView.swift` lines 457–495
**Issue:** `Timer.publish(every:on:in:).sink { offset = CGFloat.random(...) }` mutates `@State var offset` from a Combine sink without `@MainActor` isolation. Under Swift 6 strict concurrency this is a data race — the timer fires on the main runloop but not on MainActor, so the mutation can collide with SwiftUI's render phase. Symptoms would be rare frame jank or a console warning under strict-concurrency builds; it doesn't crash today.
**Fix:** either `.receive(on: DispatchQueue.main)` on the publisher or mark the sink closure `@MainActor`. Or replace the Timer+sink with a `TimelineView(.animation)` source.
**Deferred because:** NovaKids' current concurrency mode is permissive — the race is latent, not active. Touch test is safe. Catch in the Swift 6 migration sprint.

### VoiceCardView — `DashyCharacterView` migration not done

**File:** `src/Apps/NovaKids/Sources/Views/Flipbook/VoiceCardView.swift`
**Issue:** My rewrite focused on fixing the wire-contract + state machine. It does NOT use the `DashyCharacterView` component built in S11-10 — bang's kid will see a mic button on the voice card while Dashy appears as her proper comic-silhouette character everywhere else (chat, hint sheet, onboarding). The view is now clean + functional, but visually less integrated than it could be.
**Fix (future):** wrap the mic button in a composition with `DashyCharacterView(emotion: .thinking / .excited)` on the celebrating/reprompting states. Would take ~20 LOC + access to the Dashy avatar presentation patterns from `DashyView.swift`.
**Deferred because:** touch test works without it. Adding Dashy's face here is S13 polish (same territory as S12-17's voice-consistency audit).

### VoiceCardView — `phonetics` field decoded but unused

**File:** `src/Apps/NovaKids/Sources/Views/Flipbook/VoiceCardView.swift`
**Issue:** My rewrite decodes the new `phonetics` field from the backend but doesn't pass it anywhere. The intended use is `AVSpeechUtterance.pronunciations` (iOS 16+) so TTS pronounces "photosynthesis" with the skill's suggested `"pho-to-syn-the-sis"` syllable breakdown instead of the default phonemic engine guess.
**Fix (future):** thread `phonetics` into `voiceManager.speak(text:phonetics:)` — would require a new param on `VoiceManager.speak` plus the AVSpeechUtterance IPA construction.
**Deferred because:** the default TTS engine handles most words fine; phonetics is a polish item for 4+ syllable science vocabulary. Voice-persona skill emits it optionally; Simple Wikipedia's "sky/rainbow/planet" content won't need it.

## Verification

- `tsc` / `swiftc` can't run from the sandbox. Bang's Mac should `xcodebuild -scheme NovaKids -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch)'` and confirm zero new warnings/errors related to the two fixes. The Card.swift change is purely additive (new optional fields) so existing call sites stay compatible; the VoiceCardView change is a same-signature replacement.
- `VoiceCardView.swift` `#Preview` at the bottom exercises all five voice-persona fields so bang can see the rendered card chrome in Xcode Canvas before iPad boot.

## Summary

- **2 blockers fixed in-sandbox** (CardContent fields + VoiceCardView rewrite) — without these, voice cards would feel broken during the S12-11 touch test.
- **5 carve-outs documented** for future polish — none block S12-10 DoD or S12-11.
- **Next step:** bang compiles NovaKids on his Mac, confirms zero new errors, proceeds with the seed-plan URLs one at a time per [`runbook.md`](./runbook.md).
