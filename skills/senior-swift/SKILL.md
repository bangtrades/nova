---
name: senior-swift
description: Senior Swift/SwiftUI engineering skill for writing, debugging, and fixing iOS/macOS code. Use this skill whenever writing Swift code, fixing Xcode compilation errors, building SwiftUI views, working with iOS frameworks (UIKit haptics, BackgroundTasks, Speech, AVFoundation), implementing drag-and-drop, gestures, or navigation, or troubleshooting type conformance and concurrency issues. Trigger on any mention of Swift, SwiftUI, Xcode, iOS, iPadOS, macOS, SPM, UIKit, compilation errors, build failures, or any Swift file (.swift). Also trigger when the user pastes Xcode error messages or screenshots of build failures. Use aggressively for ANY Swift-related task.
---

# Senior Swift / SwiftUI Engineering Skill

You are a senior Swift engineer with deep expertise in SwiftUI, UIKit interop, Swift concurrency, SPM package architecture, and Xcode build systems. You write code that compiles on the first try because you understand the exact API signatures, protocol requirements, and platform version constraints.

## Core Philosophy

The #1 cause of Swift compilation errors in AI-generated code is **using API signatures from memory rather than verified knowledge**. Swift APIs have precise parameter labels, ordering, and type requirements. A single wrong label or missing conformance cascades into dozens of downstream errors. This skill exists to prevent that.

## Before Writing Any Swift Code

1. **Know your deployment target.** iOS 17+ means you use the two-parameter `onChange`, `NavigationStack` (not `NavigationView`), and `Transferable` for drag-and-drop. Read `references/swiftui-api-guide.md` for version-specific API signatures.

2. **Know your Swift language version.** Swift 5.9/6.0+ auto-synthesizes `Equatable`/`Hashable` for enums with associated values IF all associated types conform. Swift 6.0+ has strict concurrency checking. Read `references/swift-language.md` for language-level patterns.

3. **Know the exact API you're calling.** Don't guess parameter labels. When in doubt, check the reference files or search the codebase for existing usage patterns with `grep`.

## Error Prevention Checklist

Before submitting any Swift code, mentally verify each of these. They represent the most common compilation errors encountered in real projects:

### 1. Protocol Conformance

**Problem:** Using a type in a context that requires a protocol it doesn't conform to.

**Common triggers:**
- `ForEach` requires `Identifiable` (or explicit `id:` parameter)
- `.draggable()` and `.dropDestination()` require `Transferable`
- `==` comparison requires `Equatable`
- `Set` membership requires `Hashable`
- JSON serialization requires `Codable`

**Fix pattern:** Add the conformance. For `Transferable`, you also need `Codable` and a `transferRepresentation`:

```swift
struct MyItem: Identifiable, Codable, Transferable {
    let id: String
    let label: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}
```

**For enums with associated values:** Swift auto-synthesizes `Equatable` and `Hashable` only if ALL associated value types themselves conform. An enum case like `.error(Error)` will NOT auto-synthesize because `Error` is not `Equatable`. Use `.error(String)` instead, or write a manual conformance.

### 2. Closure Type Mismatches

**Problem:** Passing a function reference where the closure signature doesn't match.

**The pattern that ALWAYS fails:**
```swift
// WRONG - handleTap(item:) is (Item) -> Void, but onTap expects () -> Void
MyButton(onTap: handleTap(item:))
```

**The fix:**
```swift
// CORRECT - wrap in a closure that captures the value
MyButton(onTap: { handleTap(item: item) })
```

This comes up constantly with `ForEach` + button callbacks. If a child view's callback is `() -> Void` but you need to pass context from the iteration, you MUST wrap in a closure.

### 3. API Method Names and Parameter Labels

**Problem:** Using a method name or parameter label that doesn't exist.

**Real examples encountered:**
- `setTaskAsCompleted(success:)` does NOT exist. The correct API is `setTaskCompleted(success:)`
- `UIImpactFeedbackGenerator(style: .warning)` does NOT exist. Valid styles are: `.light`, `.medium`, `.heavy`, `.soft`, `.rigid`
- `syncManager.syncNow()` — always verify method names exist on the type you're calling. Read the actual source file.

**Prevention:** When calling framework APIs, check `references/swiftui-api-guide.md`. When calling project APIs, `grep` for the method name in the codebase to confirm it exists.

### 4. SwiftUI Gesture API Signatures

**Problem:** Wrong parameter order in gesture modifiers.

**`onLongPressGesture` — the correct signatures (iOS 16+):**
```swift
// Signature 1: perform comes BEFORE onPressingChanged
.onLongPressGesture(minimumDuration: 0.5, perform: {
    // action on completion
}) { pressing in
    // pressing state changed
}

// Signature 2: with maximumDistance
.onLongPressGesture(minimumDuration: 0.5, maximumDistance: 10, perform: {
    // action
}) { pressing in
    // pressing changed
}
```

The `perform:` parameter ALWAYS comes before `onPressingChanged:` (which is the trailing closure). Never put `onPressingChanged:` as a labeled parameter before `perform:`.

### 5. onChange Syntax (iOS 17+)

**Problem:** Using deprecated single-parameter `onChange`.

```swift
// DEPRECATED (iOS 16 style)
.onChange(of: someValue) { newValue in ... }

// CORRECT (iOS 17+ — two parameters)
.onChange(of: someValue) { oldValue, newValue in ... }

// ALSO CORRECT (iOS 17+ — zero parameters, read property directly)
.onChange(of: someValue) {
    // read someValue directly here
}
```

### 6. Force Unwrapping Non-Optionals

**Problem:** Adding `!` to a value that isn't optional.

```swift
// WRONG — outputFormat(forBus:) returns AVAudioFormat, not AVAudioFormat?
let format = inputNode.outputFormat(forBus: 0)!

// CORRECT
let format = inputNode.outputFormat(forBus: 0)
```

Check whether the return type is actually optional before adding `!`. Xcode will error on force-unwrapping a non-optional.

### 7. Unreachable Catch Blocks

**Problem:** Using `try?` makes the catch block unreachable.

```swift
// WRONG — try? swallows the error, catch never executes
do {
    try? await someOperation()
} catch {
    // This is UNREACHABLE — compiler warning/error
    handleError(error)
}

// CORRECT — use try (not try?) when you have a catch block
do {
    try await someOperation()
} catch {
    handleError(error)
}
```

### 8. View Modifier Availability

**Problem:** Using a modifier that doesn't exist on the target type.

- `.onInsert(of:)` exists ONLY on `ForEach`, not on arbitrary `View` types
- `.searchable()` requires being inside a `NavigationStack`
- `.navigationTitle()` requires a navigation container

Before using a modifier, confirm it's available on the specific view type you're applying it to.

### 9. Encoding Non-Encodable Types

**Problem:** Trying to encode `[String: Any]` or `Any` — these are NOT `Encodable`.

```swift
// WRONG — [String: Any] does not conform to Encodable
let payload: [String: Any] = ["key": value]
try JSONEncoder().encode(payload)

// CORRECT — use concrete Codable types
struct Payload: Codable {
    let key: String
    let value: Int
}
```

If you absolutely need dynamic encoding, write a custom `Encodable` conformance that handles each concrete type (`String`, `Int`, `Double`, `Bool`) explicitly.

### 10. @MainActor and Concurrency

**Problem:** Publishing changes from background threads, or calling @MainActor methods from non-isolated contexts.

```swift
// All ObservableObject view models that publish UI state should be @MainActor
@MainActor
public class MyViewModel: ObservableObject {
    @Published var items: [Item] = []
}
```

**Swift 6.2+ note:** With `-default-isolation MainActor`, code is isolated to main actor by default. Use `@concurrent` to opt specific functions into parallel execution.

### 11. Child Structs Don't Inherit @Environment

**Problem:** A `private struct` extracted from a parent view references `@Environment` properties from the parent — they are NOT inherited.

**Error message:** `Cannot convert value of type '(ColorScheme) -> some View' to expected argument type 'ColorScheme'` (or similar cryptic type-inference failures)

```swift
// WRONG — DropTargetView references `colorScheme` but doesn't declare it
struct ParentView: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View { DropTargetView() }
}

private struct DropTargetView: View {
    var body: some View {
        // ERROR: colorScheme is not in scope
        Rectangle().fill(colorScheme == .dark ? Color.black : Color.white)
    }
}

// CORRECT — each struct declares its own @Environment
private struct DropTargetView: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Rectangle().fill(colorScheme == .dark ? Color.black : Color.white)
    }
}
```

**When to check:** Every time you extract a subview into a separate struct, verify it declares ALL `@Environment` properties it reads.

### 12. Type-Check Timeouts from Complex Inline Expressions

**Problem:** Complex inline expressions in SwiftUI view builders overwhelm the Swift type checker.

**Error message:** `The compiler is unable to type-check this expression in reasonable time`

```swift
// WRONG — inline date math kills the type checker
ForEach((1950...Int(Date().timeIntervalSince1970) / (365*24*3600) - 18).reversed(), id: \.self) { year in

// CORRECT — precompute the range
private var yearRange: [Int] {
    let currentYear = Calendar.current.component(.year, from: Date())
    return Array((1950...(currentYear - 18)).reversed())
}
```

**Rule:** Never put arithmetic, date calculations, or complex range expressions inside `ForEach` or view builder closures. Extract to a computed property.

### 13. Optional Grouping with Dictionary(grouping:by:)

**Problem:** Grouping by an optional key when the dictionary expects non-optional keys.

**Error message:** `Value of optional type 'UUID?' must be unwrapped to a value of type 'UUID'`

```swift
// WRONG — pathId is UUID?, dictionary key expects UUID
let grouped: [UUID: [Lesson]] = Dictionary(grouping: lessons, by: { $0.pathId })

// CORRECT — filter nils first
let grouped: [UUID: [Lesson]] = Dictionary(
    grouping: lessons.filter { $0.pathId != nil },
    by: { $0.pathId! }
)
```

### 14. Cross-Type Comparisons Give Cryptic Generic Errors

**Problem:** Comparing `String` to `Bool` (or mismatched types) in ternary expressions.

**Error message:** `Conflicting arguments to generic parameter 'Self' ('String' vs. ...)`

```swift
// WRONG — option.id is String, isSelected is Bool
.opacity(option.id != isSelected ? 0.5 : 1.0)

// CORRECT
.opacity(!isSelected ? 0.5 : 1.0)
```

### 15. Async Methods vs Completion Handler Trailing Closures

**Problem:** Calling an `async` method with a trailing closure as if it had a completion handler.

**Error message:** `Extra trailing closure passed in call`

```swift
// WRONG — speak() is async, not callback-based
speechSynthesizer.speak(text) { isSpeaking = false }

// CORRECT — await the async method
Task {
    await speechSynthesizer.speak(text)
    isSpeaking = false
}
```

### 16. NSLock in Async Contexts (Swift 6)

**Problem:** `NSLock.lock()`/`.unlock()` are unavailable from async contexts in Swift 6.

**Error message:** `Instance method 'lock' is unavailable from asynchronous contexts`

```swift
// WRONG — lock inside async function
func flush() async throws {
    lock.lock()  // ERROR in Swift 6
    defer { lock.unlock() }
    let items = loadQueue()
}

// CORRECT — extract synchronous lock scope
private func readQueueSynchronously() -> [Item] {
    lock.lock()
    defer { lock.unlock() }
    return (try? loadQueue()) ?? []
}
func flush() async throws {
    let items = readQueueSynchronously()
    try await apiRouter.request(.sync(items))
}
```

### 17. DynamicTypeSize Member Names

**Problem:** Using non-existent `DynamicTypeSize` member names.

**DOES NOT EXIST:** `.accessibilityExtraExtraExtraLarge`

**Valid accessibility sizes:** `.accessibilityMedium`, `.accessibilityLarge`, `.accessibilityExtraLarge`, `.accessibilityExtraExtraLarge`, `.accessibilityExtraExtraExtraLarge` was removed — use **`.accessibility5`** for the maximum size.

```swift
// WRONG
.dynamicTypeSize(.xSmall ... .accessibilityExtraExtraExtraLarge)

// CORRECT
.dynamicTypeSize(.xSmall ... .accessibility5)
```

### 18. Timer Callbacks Cross Actor Isolation

**Problem:** `Timer.scheduledTimer` callbacks run on a different isolation context than the SwiftUI view, even when the view is `@MainActor`.

**Error message:** `Main actor-isolated property 'X' can not be mutated from a nonisolated context`

```swift
// WRONG — Timer callback is nonisolated, can't mutate @State
Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
    blinkOpacity = 0  // ERROR: crosses isolation boundary
}

// CORRECT — hop to MainActor inside the callback
Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
    Task { @MainActor in
        blinkOpacity = 0
    }
}
```

### 19. Delegate Conformance on @MainActor Classes

**Problem:** Protocol delegate methods on `@MainActor` classes cross isolation boundaries because the delegate protocol isn't MainActor-isolated.

**Error message:** `Conformance of 'X' to protocol 'YDelegate' crosses into main actor-isolated code and can cause data races`

```swift
// WRONG — delegate method inherits @MainActor from class
@MainActor
class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    func speechRecognizer(_ sr: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        // ERROR: crosses isolation boundary
    }
}

// CORRECT — make delegate method nonisolated, hop to MainActor for state
@MainActor
class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ sr: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            self.isListening = available && self.isListening
        }
    }
}
```

## SPM Package Architecture

When working with multi-package Swift projects:

- Each package's public API must use `public` access control
- Types shared across packages need `public` on the type AND its members
- `import PackageName` must match the target name in Package.swift, not the product name (though they're often the same)
- Circular dependencies between packages are forbidden — factor shared types into a "Core" package

## Build Error Triage

When facing multiple compilation errors:

1. **Fix errors in dependency order.** Start with the lowest-level package (e.g., `NovaCore`) before app targets. Errors cascade — a single missing type in a package will cause dozens of errors in files that import it.

2. **Fix one file at a time.** Swift won't compile files that depend on a file with errors. Fixing one file often reveals errors in previously-uncompilable files. This is normal.

3. **Read the FIRST error in each file.** Later errors in the same file are often caused by the first one. Fix the first, rebuild, then see what remains.

4. **When an error message is cryptic**, look at the types involved. Swift's type inference errors often say "cannot convert X to Y" when the real issue is a missing protocol conformance or wrong closure signature.

## Reference Files

Read these for detailed API signatures and patterns:

- `references/swiftui-api-guide.md` — Exact signatures for SwiftUI modifiers, gestures, navigation, drag-drop, and state management APIs with iOS version annotations
- `references/swift-language.md` — Swift 6.x language features, concurrency model, Sendable, typed throws, ownership, and auto-synthesis rules
- `references/uikit-interop.md` — UIKit APIs commonly used in SwiftUI apps: haptics, background tasks, speech recognition, audio engine, notifications
