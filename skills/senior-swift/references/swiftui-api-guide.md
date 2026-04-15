# SwiftUI API Reference — Exact Signatures

This file contains verified API signatures for commonly misused SwiftUI modifiers and types. When writing SwiftUI code, check this file to avoid parameter label and ordering errors.

## Table of Contents

1. State Change Observers (onChange)
2. Gestures (onLongPressGesture, onTapGesture)
3. Drag and Drop (Transferable, draggable, dropDestination)
4. Navigation (NavigationStack, NavigationLink)
5. Lists and ForEach
6. Sheets and Alerts
7. Environment and Preferences

---

## 1. State Change Observers

### onChange (iOS 17+ — CURRENT)

Two variants, both non-deprecated:

```swift
// Variant A: receives old and new values
func onChange<V>(
    of value: V,
    initial: Bool = false,
    _ action: @escaping (V, V) -> Void
) -> some View where V: Equatable

// Usage:
.onChange(of: searchText) { oldValue, newValue in
    performSearch(newValue)
}
```

```swift
// Variant B: no parameters, read property directly
func onChange<V>(
    of value: V,
    initial: Bool = false,
    _ action: @escaping () -> Void
) -> some View where V: Equatable

// Usage:
.onChange(of: searchText) {
    performSearch(searchText) // read the @State directly
}
```

### onChange (iOS 14-16 — DEPRECATED in iOS 17)

```swift
// DEPRECATED — do not use for iOS 17+ targets
func onChange<V>(
    of value: V,
    perform action: @escaping (V) -> Void
) -> some View where V: Equatable

// This old form uses `perform:` label and single parameter
.onChange(of: searchText, perform: { newValue in ... })
```

**Key differences:**
- iOS 17+: trailing closure, NO `perform:` label, 0 or 2 params
- iOS 16: `perform:` label, 1 param
- The `initial:` parameter (iOS 17+) controls whether action fires on first appear

---

## 2. Gestures

### onTapGesture

```swift
func onTapGesture(
    count: Int = 1,
    perform action: @escaping () -> Void
) -> some View

// Usage:
.onTapGesture {
    handleTap()
}
.onTapGesture(count: 2) {
    handleDoubleTap()
}
```

### onLongPressGesture

**CRITICAL: `perform:` ALWAYS comes before `onPressingChanged:`**

```swift
// Variant A: minimumDuration + perform (trailing closure)
func onLongPressGesture(
    minimumDuration: Double = 0.5,
    perform action: @escaping () -> Void
) -> some View

// Variant B: with onPressingChanged — perform: is labeled, onPressingChanged is trailing
func onLongPressGesture(
    minimumDuration: Double = 0.5,
    perform action: @escaping () -> Void,
    onPressingChanged: ((Bool) -> Void)?
) -> some View

// Usage:
.onLongPressGesture(minimumDuration: 0.5, perform: {
    handleLongPress()
}) { pressing in
    isBeingPressed = pressing
}
```

```swift
// Variant C: with maximumDistance
func onLongPressGesture(
    minimumDuration: Double = 0.5,
    maximumDistance: CGFloat = 10,
    perform action: @escaping () -> Void,
    onPressingChanged: ((Bool) -> Void)?
) -> some View
```

**DEPRECATED variant (iOS 17.4+):**
```swift
// DEPRECATED — note different parameter order with `pressing:` before `perform:`
func onLongPressGesture(
    minimumDuration: Double = 0.5,
    maximumDistance: CGFloat = 10,
    pressing: ((Bool) -> Void)? = nil,
    perform action: @escaping () -> Void
) -> some View
```

The deprecated variant uses `pressing:` (not `onPressingChanged:`) and puts it BEFORE `perform:`. The current variant flips the order. Do NOT mix them.

### LongPressGesture (standalone)

```swift
struct LongPressGesture {
    init(minimumDuration: Double = 0.5)
}

// Usage with .gesture():
.gesture(
    LongPressGesture(minimumDuration: 1.0)
        .onChanged { _ in isPressed = true }
        .onEnded { _ in handleComplete() }
)
```

### DragGesture

```swift
struct DragGesture {
    init(minimumDistance: CGFloat = 10, coordinateSpace: CoordinateSpace = .local)
}
```

---

## 3. Drag and Drop

### Transferable Protocol (iOS 16+)

```swift
public protocol Transferable {
    associatedtype Representation: TransferRepresentation
    static var transferRepresentation: Representation { get }
}
```

### TransferRepresentation Types

```swift
// For Codable types — most common
CodableRepresentation(contentType: UTType)
// Requires: import UniformTypeIdentifiers

// For raw Data
DataRepresentation(contentType: UTType, exporting: (Self) -> Data)
DataRepresentation(contentType: UTType, importing: (Data) -> Self)

// For files
FileRepresentation(contentType: UTType, exporting: ..., importing: ...)
```

### Complete Transferable Example

```swift
import UniformTypeIdentifiers

struct DragItem: Identifiable, Codable, Transferable {
    let id: String
    let label: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}
```

### .draggable()

```swift
func draggable<T: Transferable>(_ payload: T) -> some View
func draggable<T: Transferable>(_ payload: T, preview: () -> some View) -> some View

// Usage:
Text(item.label)
    .draggable(item) {
        // Preview view shown during drag
        Text(item.label)
            .padding()
            .background(.blue)
    }
```

### .dropDestination()

```swift
func dropDestination<T: Transferable>(
    for payloadType: T.Type,
    action: @escaping ([T], CGPoint) -> Bool,
    isTargeted: @escaping (Bool) -> Void
) -> some View

// Usage:
.dropDestination(for: DragItem.self) { items, location in
    if let item = items.first {
        handleDrop(item)
        return true
    }
    return false
} isTargeted: { targeted in
    isDropTargeted = targeted
}
```

### .onInsert — ONLY available on ForEach

```swift
// This modifier exists ONLY on ForEach, NOT on arbitrary Views
ForEach(items) { item in ... }
    .onInsert(of: [UTType.text]) { index, providers in ... }
```

---

## 4. Navigation

### NavigationStack (iOS 16+ — USE THIS)

```swift
NavigationStack {
    List { ... }
    .navigationTitle("Title")
    .navigationDestination(for: Item.self) { item in
        DetailView(item: item)
    }
}

// With path binding:
@State private var path = NavigationPath()

NavigationStack(path: $path) {
    ...
}
```

### NavigationView — DEPRECATED (iOS 16+)

Do not use `NavigationView` for iOS 16+ targets. Replace with `NavigationStack`.

**Migration checklist when replacing NavigationView → NavigationStack:**
1. Replace all `NavigationView {` with `NavigationStack {`
2. Replace `.navigationBarLeading` with `.topBarLeading`
3. Replace `.navigationBarTrailing` with `.topBarTrailing`
4. Replace `NavigationLink(destination:)` with value-based `NavigationLink(value:)` + `navigationDestination(for:)`
5. Check ALL child sheets/modals — they often have their own `NavigationView` wrapping `Form` or `List`

### NavigationLink

```swift
// Value-based (iOS 16+ with navigationDestination)
NavigationLink(value: item) {
    Text(item.name)
}

// Direct destination (still works but less flexible)
NavigationLink {
    DetailView(item: item)
} label: {
    Text(item.name)
}
```

---

## 5. Lists and ForEach

### ForEach Requirements

```swift
// Option A: Identifiable conformance
ForEach(items) { item in ... }  // items must be [Identifiable]

// Option B: explicit id keypath
ForEach(items, id: \.self) { item in ... }
ForEach(items, id: \.name) { item in ... }

// For ranges:
ForEach(0..<count, id: \.self) { index in ... }
ForEach(1...maxAttempts, id: \.self) { i in ... }
```

### Identifiable Protocol

```swift
public protocol Identifiable {
    associatedtype ID: Hashable
    var id: ID { get }
}

// Common patterns:
struct Item: Identifiable {
    let id: UUID  // direct stored property
}

struct Wrapper: Identifiable {
    var id: UUID { wrappedItem.id }  // computed from inner type
}
```

---

## 6. Sheets and Alerts

### .sheet

```swift
// Boolean binding
.sheet(isPresented: $showSheet) {
    SheetContent()
}

// Item binding (iOS 16+)
.sheet(item: $selectedItem) { item in
    DetailView(item: item)
}
```

### .alert (iOS 15+)

```swift
.alert("Title", isPresented: $showAlert) {
    Button("OK") { }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("Alert message")
}
```

---

## 7. Environment

### @Environment

```swift
@Environment(\.dismiss) var dismiss          // DismissAction
@Environment(\.colorScheme) var colorScheme  // ColorScheme
@Environment(\.openURL) var openURL          // OpenURLAction
```

### Custom EnvironmentKey

```swift
private struct MyKey: EnvironmentKey {
    static let defaultValue: MyType = .default
}

extension EnvironmentValues {
    var myProperty: MyType {
        get { self[MyKey.self] }
        set { self[MyKey.self] = newValue }
    }
}
```

---

## 8. Dynamic Type & Accessibility Sizing

### DynamicTypeSize — ALL valid cases

Standard sizes: `.xSmall`, `.small`, `.medium`, `.large` (default), `.xLarge`, `.xxLarge`, `.xxxLarge`

Accessibility sizes: `.accessibilityMedium`, `.accessibilityLarge`, `.accessibilityExtraLarge`, `.accessibilityExtraExtraLarge`, `.accessibility5`

**DOES NOT EXIST:** `.accessibilityExtraExtraExtraLarge` — use `.accessibility5` for the maximum.

```swift
// Constrain Dynamic Type range
.dynamicTypeSize(.xSmall ... .accessibility5)

// Check if accessibility size is active
@Environment(\.dynamicTypeSize) var dynamicTypeSize

if dynamicTypeSize.isAccessibilitySize {
    // Switch to vertical layout, simplify UI
}
```

### @ScaledMetric — Scale Custom Dimensions with Dynamic Type

Use `@ScaledMetric` for non-text dimensions (dots, icons, spacing) that should scale with Dynamic Type:

```swift
@ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 8
@ScaledMetric(relativeTo: .caption) private var minTapSize: CGFloat = 44

Circle()
    .frame(width: dotSize, height: dotSize)
    .frame(minWidth: minTapSize, minHeight: minTapSize)
```

### Font Size → Semantic Font Mapping

When migrating from `.font(.system(size:))` to Dynamic Type:

| Fixed Size | Semantic Font | Notes |
|-----------|--------------|-------|
| 8-10pt | `.caption2` | |
| 11-12pt | `.caption` | |
| 14pt | `.subheadline` | Add `.weight(.semibold)` if needed |
| 16pt (semibold) | `.headline` | |
| 16pt (regular) | `.body` | |
| 18-20pt | `.title3` | |
| 22-24pt | `.title2` | |
| 28-32pt | `.title` | |
| 36pt+ | `.largeTitle` | |

---

## 9. Toolbar Placement (iOS 16+)

### Current (non-deprecated) placements

```swift
ToolbarItem(placement: .topBarLeading) { ... }   // Was .navigationBarLeading
ToolbarItem(placement: .topBarTrailing) { ... }   // Was .navigationBarTrailing
ToolbarItem(placement: .bottomBar) { ... }
ToolbarItem(placement: .principal) { ... }         // Center of navigation bar
ToolbarItem(placement: .keyboard) { ... }
```

**DEPRECATED:** `.navigationBarLeading`, `.navigationBarTrailing` — always use `.topBarLeading`, `.topBarTrailing`.

---

## 10. CFArray/CFDictionary Bridging

Core Foundation types from Security/system frameworks don't support Swift subscripts. Always bridge:

```swift
// WRONG — CFArray has no subscripts
let cert = SecTrustCopyCertificateChain(trust)?[0]

// CORRECT — bridge to Swift array
guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else { return }
for certificate in chain { ... }
```
