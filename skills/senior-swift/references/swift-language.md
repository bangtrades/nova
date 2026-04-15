# Swift Language Reference — Versions 5.9 through 6.3

## Table of Contents

1. Swift 6 Language Mode & Concurrency
2. Protocol Conformance Auto-Synthesis
3. Typed Throws
4. Ownership & Non-Copyable Types
5. Swift 6.2 Features (InlineArray, Span, @concurrent)
6. Swift 6.3 Features (@c, Module Selectors)
7. Common Type System Pitfalls

---

## 1. Swift 6 Language Mode & Concurrency

### Data Race Safety

Swift 6 introduces an opt-in language mode that makes potential data races into compiler errors. Previously these were warnings with `-strict-concurrency=complete`.

### Sendable

Types shared across concurrency domains must conform to `Sendable`:

```swift
// Value types with Sendable stored properties are implicitly Sendable
struct Config: Sendable {
    let timeout: TimeInterval
    let retryCount: Int
}

// Reference types must explicitly conform and be final
final class Cache: Sendable {
    let items: [String: Data]  // must be immutable
}

// Closures crossing isolation boundaries must be @Sendable
Task { @Sendable in
    await fetchData()
}
```

### Actor Isolation

```swift
// Actor — serial execution, safe mutable state
actor DataStore {
    var items: [Item] = []

    func add(_ item: Item) {
        items.append(item)
    }
}

// @MainActor — isolated to main thread
@MainActor
class ViewModel: ObservableObject {
    @Published var state: ViewState = .idle
}

// Calling actor methods requires await
let store = DataStore()
await store.add(newItem)
```

### @MainActor on ObservableObject

ALL view models that use `@Published` for UI state should be `@MainActor`:

```swift
@MainActor
public class HomeViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false

    func loadItems() async {
        isLoading = true
        // Network call happens here
        isLoading = false
    }
}
```

Without `@MainActor`, publishing changes from async contexts may trigger runtime warnings or crashes.

### Swift 6.2: Default Main Actor Isolation

With `-default-isolation MainActor` compiler flag, all code is isolated to the main actor by default. Use `@concurrent` to opt specific functions into parallel execution:

```swift
@concurrent
static func fetchImage(at url: URL) async throws -> Image {
    let (data, _) = try await URLSession.shared.data(from: url)
    return await decode(data: data)
}
```

### nonisolated

Use `nonisolated` to remove actor isolation from specific methods:

```swift
@MainActor
class ViewModel: ObservableObject {
    nonisolated func computeHash(_ data: Data) -> String {
        // This can run on any thread
        data.sha256String
    }
}
```

### Key Isolation Rules Learned from Real Builds

**1. Task { } inherits actor isolation from calling context:**
```swift
// Inside a SwiftUI View (which is MainActor), this Task inherits MainActor:
func startRecording() {
    Task {
        // This is ALREADY on MainActor — no await needed for MainActor methods
        speechRecognizer.stopListening()  // No await needed
        let text = speechRecognizer.transcript  // No await needed

        // But async methods still need await regardless of actor:
        let stream = try await speechRecognizer.startListening()  // NEEDS await (async)
    }
}
```

**2. Timer callbacks are NOT on MainActor:**
```swift
// Timer.scheduledTimer callback runs on RunLoop thread, not MainActor
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    // This is nonisolated! Can't mutate @State or @Published here
    Task { @MainActor in
        self.counter += 1  // Must hop to MainActor
    }
}
```

**3. Protocol delegate methods cross isolation:**
```swift
// On @MainActor classes, delegate protocol methods need nonisolated
@MainActor
class MyClass: NSObject, SomeDelegateProtocol {
    nonisolated func delegateCallback(_ sender: Any) {
        Task { @MainActor in
            self.handleCallback()
        }
    }
}
```

**4. NSLock is forbidden in async contexts (Swift 6):**
```swift
// Extract lock scopes to synchronous helper methods
private func readSynchronously() -> [Item] {
    lock.lock()
    defer { lock.unlock() }
    return items
}
// Call from async: let items = readSynchronously()
```

**5. Unreachable catch blocks — non-throwing async functions:**
```swift
// If action() is async but NOT throws, the catch block is unreachable
do {
    await action()  // WARNING: catch is unreachable
} catch { ... }

// Fix: remove do/catch
await action()
```

---

## 2. Protocol Conformance Auto-Synthesis

### Equatable (since Swift 4.1)

Swift auto-synthesizes `Equatable` conformance when you declare it, IF:
- For structs: all stored properties conform to `Equatable`
- For enums: all associated value types conform to `Equatable`
- Enums without associated values are automatically `Equatable` (no declaration needed)

```swift
// Auto-synthesized — String is Equatable
enum AppState: Equatable {
    case idle
    case loading
    case error(String)  // String is Equatable, so this works
}

// Will NOT auto-synthesize — Error is NOT Equatable
enum BadState: Equatable {
    case error(Error)  // COMPILE ERROR: Error doesn't conform to Equatable
}

// Fix: use String for the error message
enum GoodState: Equatable {
    case error(String)
}
```

### Hashable

Same rules as Equatable. If all components are Hashable, synthesis works.

```swift
// Enums without associated values are implicitly Hashable
enum Direction {
    case north, south, east, west  // automatically Hashable
}

// With associated values: must declare and all types must be Hashable
enum Token: Hashable {
    case word(String)
    case number(Int)
}
```

### Codable (since Swift 4.0, enums with associated values since Swift 5.5)

```swift
// Structs: all stored properties must be Codable
struct User: Codable {
    let id: UUID
    let name: String
    let email: String
}

// Enums with associated values (Swift 5.5+):
enum Response: Codable {
    case success(User)
    case error(String)
}
```

### Identifiable

NOT auto-synthesized. You must either:
- Have a stored property `let id: SomeHashableType`
- Provide a computed `var id` property

```swift
struct Item: Identifiable {
    let id: UUID  // stored — works automatically
}

struct Wrapper: Identifiable {
    let badge: Badge
    var id: UUID { badge.id }  // computed — also works
}
```

---

## 3. Typed Throws (Swift 6.0+)

Functions can specify their error type:

```swift
func parse(_ input: String) throws(ParseError) -> Record {
    guard !input.isEmpty else {
        throw ParseError.emptyInput
    }
    // ...
}

// catch block infers ParseError
do {
    let record = try parse(data)
} catch {
    // error is ParseError, not any Error
    switch error {
    case .emptyInput: ...
    case .invalidFormat: ...
    }
}
```

Generic typed throws:
```swift
extension Sequence {
    func map<T, E>(_ body: (Element) throws(E) -> T) throws(E) -> [T]
}
```

---

## 4. Ownership & Non-Copyable Types (Swift 6.0+)

```swift
struct FileHandle: ~Copyable {
    private let fd: Int32

    consuming func close() {
        // fd is consumed, can't use FileHandle after this
    }
}

// Generic support
func process<T: ~Copyable>(_ item: consuming T) { ... }
```

---

## 5. Swift 6.2 Features

### InlineArray

Fixed-size array with inline storage:
```swift
var bricks: [40 of Sprite]  // Shorthand for InlineArray<40, Sprite>
```

### Span

Safe, zero-overhead access to contiguous memory:
```swift
func process(_ data: Span<UInt8>) { ... }
```

### Int128 / UInt128

128-bit integer types (introduced in Swift 6.0).

---

## 6. Swift 6.3 Features

### @c Attribute

Expose Swift functions to C:
```swift
@c func callFromC() { ... }
// Generates: void callFromC(void);

@c(MyLib_doWork)
func doWork() { ... }
// Generates: void MyLib_doWork(void);
```

### Module Name Selectors

Disambiguate identically-named APIs:
```swift
let x = ModuleA::getValue()
let y = ModuleB::getValue()
```

---

## 7. Common Type System Pitfalls

### [String: Any] is NOT Encodable

`Any` does not conform to `Encodable`. You cannot encode dictionaries with `Any` values:

```swift
// WRONG
let dict: [String: Any] = ["key": "value", "count": 42]
try JSONEncoder().encode(dict)  // COMPILE ERROR

// CORRECT — use a concrete Codable struct
struct Payload: Codable {
    let key: String
    let count: Int
}
```

If you need dynamic keys, write a custom Encodable:

```swift
struct DynamicPayload: Encodable {
    let values: [String: Any]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        for (key, value) in values {
            let codingKey = DynamicKey(stringValue: key)!
            switch value {
            case let v as String: try container.encode(v, forKey: codingKey)
            case let v as Int:    try container.encode(v, forKey: codingKey)
            case let v as Double: try container.encode(v, forKey: codingKey)
            case let v as Bool:   try container.encode(v, forKey: codingKey)
            default: break  // skip unsupported types
            }
        }
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
    }
}
```

### Force Unwrapping Non-Optionals

Many Apple APIs return non-optional values. Adding `!` to these is a compile error:

```swift
// These are NON-OPTIONAL — do NOT force unwrap
audioEngine.inputNode                      // AVAudioInputNode (not optional)
inputNode.outputFormat(forBus: 0)          // AVAudioFormat (not optional)
UIApplication.shared                        // UIApplication (not optional)
```

### try vs try? vs try!

```swift
// try — propagates error to caller or catch block (REQUIRED if you have a catch)
do {
    try riskyOperation()
} catch {
    handleError(error)
}

// try? — converts to optional, swallows error (DO NOT use with catch blocks)
let result = try? riskyOperation()  // result is Optional

// try! — force unwrap, crashes on error (use only when failure is impossible)
let result = try! guaranteedOperation()
```

**Common mistake:** Using `try?` inside a `do/catch` makes the `catch` unreachable:
```swift
do {
    try? something()  // ERROR: catch block is unreachable
} catch {
    // This never executes
}
```
