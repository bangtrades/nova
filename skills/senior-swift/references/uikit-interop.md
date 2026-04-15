# UIKit Interop & iOS Framework APIs

Reference for UIKit and system framework APIs commonly used alongside SwiftUI. These are the APIs most frequently called with wrong signatures or non-existent methods.

## Table of Contents

1. Haptic Feedback (UIImpactFeedbackGenerator)
2. Background Tasks (BGTaskScheduler)
3. Speech Recognition (SFSpeechRecognizer + AVAudioEngine)
4. Notifications (UNUserNotificationCenter)
5. Audio Session (AVAudioSession)

---

## 1. Haptic Feedback

### UIImpactFeedbackGenerator

```swift
// Initialization
let impact = UIImpactFeedbackGenerator(style: FeedbackStyle)
impact.impactOccurred()

// With intensity (0.0 to 1.0)
impact.impactOccurred(intensity: 0.7)
```

### FeedbackStyle — ALL valid options

| Style    | Description                                           |
|----------|-------------------------------------------------------|
| `.light`  | Small, light UI elements                             |
| `.medium` | Moderately sized elements                            |
| `.heavy`  | Large, heavy elements                                |
| `.soft`   | Soft collision, large compression/elasticity          |
| `.rigid`  | Rigid collision, small compression/elasticity         |

**DOES NOT EXIST:** `.warning`, `.error`, `.success` — these are on `UINotificationFeedbackGenerator`, not `UIImpactFeedbackGenerator`.

### UINotificationFeedbackGenerator (different class)

```swift
let notification = UINotificationFeedbackGenerator()
notification.notificationOccurred(.success)   // .success, .warning, .error
```

### UISelectionFeedbackGenerator

```swift
let selection = UISelectionFeedbackGenerator()
selection.selectionChanged()
```

**Summary:** If you want `.warning` or `.error` feedback, use `UINotificationFeedbackGenerator`, not `UIImpactFeedbackGenerator`.

---

## 2. Background Tasks

### BGTaskScheduler Registration

```swift
// In app init or applicationDidFinishLaunching
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.myapp.refresh",
    using: nil  // nil = main queue
) { task in
    handleRefreshTask(task as! BGAppRefreshTask)
}
```

### Task Types

```swift
// App Refresh — lightweight, short-lived
let request = BGAppRefreshTaskRequest(identifier: "com.myapp.refresh")
request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

// Processing — long-running, can require power/network
let request = BGProcessingTaskRequest(identifier: "com.myapp.processing")
request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
request.requiresNetworkConnectivity = true
request.requiresExternalPower = true
```

### Submitting Tasks

```swift
do {
    try BGTaskScheduler.shared.submit(request)
} catch {
    print("Failed to schedule: \(error)")
}
```

### Completing Tasks — CORRECT METHOD NAME

```swift
// CORRECT
task.setTaskCompleted(success: true)
task.setTaskCompleted(success: false)

// WRONG — these DO NOT EXIST:
// task.setTaskAsCompleted(success: true)
// task.markCompleted()
// task.complete()
```

### Expiration Handler

```swift
task.expirationHandler = {
    // Clean up, then:
    task.setTaskCompleted(success: false)
}
```

### Info.plist Requirement

Add task identifiers to `BGTaskSchedulerPermittedIdentifiers` array in Info.plist.

---

## 3. Speech Recognition

### Setup Pattern

```swift
import Speech

// 1. Request authorization (do this once, early)
SFSpeechRecognizer.requestAuthorization { status in
    switch status {
    case .authorized: break
    case .denied, .restricted, .notDetermined: break
    @unknown default: break
    }
}

// 2. Create recognizer
let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
```

### Live Audio Recognition

```swift
let audioEngine = AVAudioEngine()
var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
var recognitionTask: SFSpeechRecognitionTask?

func startListening() throws {
    // Cancel existing task
    recognitionTask?.cancel()
    recognitionTask = nil

    // Configure audio session
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    // Create request
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest = recognitionRequest else { return }
    recognitionRequest.shouldReportPartialResults = true

    // Get input node and install tap
    let inputNode = audioEngine.inputNode  // NOT optional
    let recordingFormat = inputNode.outputFormat(forBus: 0)  // NOT optional

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
        recognitionRequest.append(buffer)
    }

    // Start engine THEN recognition task
    try audioEngine.start()

    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
        if let result = result {
            let transcript = result.bestTranscription.formattedString
            if result.isFinal {
                // Handle final result
            }
        }
        if let error = error {
            // Handle error
        }
    }
}
```

### Stopping Recognition

```swift
func stopListening() {
    audioEngine.inputNode.removeTap(onBus: 0)
    audioEngine.stop()
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
}
```

### AVAudioEngine Key Facts

- `audioEngine.inputNode` returns `AVAudioInputNode` — **NOT optional**, do NOT force unwrap
- `inputNode.outputFormat(forBus: 0)` returns `AVAudioFormat` — **NOT optional**, do NOT force unwrap
- `inputNode` does NOT have a `lastRenderingSampleTime` property
- Always `removeTap(onBus: 0)` before installing a new tap
- Always check `audioEngine.isRunning` before calling `stop()`

### Microphone Permission (iOS 17+)

```swift
// DEPRECATED in iOS 17.0:
AVAudioSession.sharedInstance().requestRecordPermission { granted in }

// CORRECT for iOS 17+:
AVAudioApplication.requestRecordPermission { granted in }
```

### SFSpeechRecognizerDelegate on @MainActor Classes

When your speech recognizer class is `@MainActor`, delegate methods must be `nonisolated`:

```swift
@MainActor
class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    // MUST be nonisolated — delegate protocol isn't MainActor-isolated
    nonisolated func speechRecognizer(
        _ speechRecognizer: SFSpeechRecognizer,
        availabilityDidChange available: Bool
    ) {
        Task { @MainActor in
            self.isListening = available && self.isListening
        }
    }
}
```

---

## 4. Notifications

### UNUserNotificationCenter

```swift
let center = UNUserNotificationCenter.current()

// Request permission
center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
    // Handle
}

// Schedule notification
let content = UNMutableNotificationContent()
content.title = "Title"
content.body = "Body"
content.sound = .default

let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
let request = UNNotificationRequest(identifier: "id", content: content, trigger: trigger)

center.add(request) { error in
    // Handle
}
```

### Notification Categories (for actions)

```swift
let action = UNNotificationAction(identifier: "ACCEPT", title: "Accept")
let category = UNNotificationCategory(
    identifier: "INVITE",
    actions: [action],
    intentIdentifiers: []
)
center.setNotificationCategories([category])
```

---

## 5. Audio Session

### AVAudioSession Categories

```swift
try AVAudioSession.sharedInstance().setCategory(
    .playback,           // or .record, .playAndRecord, .ambient, etc.
    mode: .default,      // or .measurement, .gameChat, .moviePlayback, etc.
    options: [.duckOthers, .allowBluetooth]
)
try AVAudioSession.sharedInstance().setActive(true)
```

### Common Categories

| Category        | Use Case                          |
|----------------|-----------------------------------|
| `.ambient`     | Background audio, mixes with others |
| `.playback`    | Music/podcast playback             |
| `.record`      | Audio recording only               |
| `.playAndRecord` | Recording + playback (voice chat) |

### Common Modes

| Mode           | Use Case                          |
|---------------|-----------------------------------|
| `.default`    | Standard audio                     |
| `.measurement`| Audio level metering / speech recognition |
| `.gameChat`   | Voice chat in games                |

---

## 6. Network Monitoring (NWPathMonitor)

### One-Shot Connectivity Check (Async Pattern)

Don't mutate a `var` from a callback — use `withCheckedContinuation` for a clean one-shot read:

```swift
import Network

// WRONG — mutates captured var in concurrent callback
var isExpensive = false
monitor.pathUpdateHandler = { path in
    isExpensive = path.isExpensive  // Data race!
}

// CORRECT — one-shot async check
let isExpensive = await withCheckedContinuation { continuation in
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { path in
        monitor.cancel()
        continuation.resume(returning: path.isExpensive)
    }
    monitor.start(queue: DispatchQueue(label: "ConnCheck"))
}
```

### Continuous Monitoring

For long-lived monitoring, use a `weak self` capture and hop to MainActor:

```swift
monitor.pathUpdateHandler = { [weak self] path in
    Task { @MainActor in
        self?.isConnected = (path.status == .satisfied)
    }
}
```

---

## 7. Security Framework Bridging

### SecTrust Certificate Chain

`SecTrustCopyCertificateChain` returns `CFArray`, which does NOT support Swift subscripts:

```swift
// WRONG — CFArray has no subscripts
let cert = SecTrustCopyCertificateChain(trust)?[0]

// CORRECT — bridge to Swift array
guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else { return }
for certificate in chain {
    guard let key = SecCertificateCopyKey(certificate) else { continue }
    // ...
}
```
