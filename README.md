# VirtualTerminal

**Modern, high-performance terminal UI library for Swift**

Build beautiful, fast command-line applications with native Swift. VirtualTerminal provides efficient rendering, cross-platform compatibility, and Swift 6 concurrency support—without the complexity of C bindings.

## Why VirtualTerminal?

### 🚀 **Built for Performance**
- **Damage-based rendering**: Only redraw changed cells, not entire screens
- **Intelligent cursor optimization**: Minimal escape sequences for movement
- **Double buffering**: Smooth animations without screen tearing
- **Output batching**: Batch multiple operations into fewer writes

### 🛡️ **Swift-Native Design**
- **Memory safety**: No unsafe pointers or C interop required
- **Modern concurrency**: Built on Swift 6 actors and async/await
- **Type safety**: Compile-time guarantees for colors, positions, and styles
- **Zero dependencies**: Pure Swift implementation

### 🌍 **True Cross-Platform**
- **macOS, Linux, Windows**: Single codebase, platform-optimized internals
- **Consistent APIs**: Write once, run everywhere
- **Native input handling**: Platform-specific optimizations under the hood

## Quick Example

```swift
import VirtualTerminal

// Create a high-performance terminal renderer
let renderer = try await VTRenderer(mode: .raw)

// Render at 60 FPS with automatic optimization
try await renderer.rendering(fps: 60) { buffer in
    buffer.write("Hello, World!", 
                 at: VTPosition(row: 1, column: 1),
                 style: VTStyle(foreground: .green, attributes: [.bold]))
}

// Handle input events with modern Swift concurrency
for await event in renderer.terminal.input {
    switch event {
    case .key(let key) where key.character == "q":
        return  // Clean exit
    case .resize(let size):
        renderer.resize(to: size)
    default:
        break
    }
}
```

## Core Features

### Efficient Rendering
- **Damage detection**: Only update changed regions
- **Style optimization**: Minimize escape sequence overhead  
- **Cursor movement**: Intelligent positioning algorithms
- **Unicode support**: Proper width calculation for CJK, emoji, and symbols

### Modern Input Handling
```swift
// AsyncSequence-based input processing
for await event in terminal.input {
    switch event {
    case .key(let key):
        handleKeyPress(key)
    case .mouse(let mouse):
        handleMouseEvent(mouse)
    case .resize(let size):
        handleResize(size)
    }
}
```

### Rich Styling
```swift
let style = VTStyle(foreground: .rgb(red: 255, green: 100, blue: 50),
                    background: .ansi(.blue),
                    attributes: [.bold, .italic])
buffer.write("Styled text", at: position, style: style)
```

### Structured Terminal Control Sequences

Beyond high-level UI rendering, VirtualTerminal provides a structured, type-safe API for formulating terminal escape sequences. Rather than hardcoding string literals like `"\033[31;1m"`, you express terminal commands using semantic Swift types.

The `ControlSequence` enum covers ISO 6429/ECMA-48 compliant terminal operations:

```swift
import VirtualTerminal

// Type-safe cursor positioning and styling
await terminal <<< .CursorPosition(10, 20)
await terminal <<< .SelectGraphicRendition([.bold, .foreground(.red)])
await terminal <<< "Important text"
await terminal <<< .SelectGraphicRendition([.reset])

// Structured screen manipulation
await terminal <<< .EraseDisplay(.EntireDisplay)
await terminal <<< .SetMode([.DEC(.UseAlternateScreenBuffer)])
```

This approach offers:
- **Semantic clarity**: Express intent with Swift types, not escape code memorization
- **Compile-time validation**: Prevents malformed sequences and parameter errors
- **Encoding abstraction**: Handles 7-bit vs 8-bit encoding automatically
- **Composability**: Chain operations with fluent syntax using the `<<<` operator

The library generates correct ANSI/VT100 escape sequences from these structured commands, making it both a UI toolkit and a robust terminal control sequence generator.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/compnerd/VirtualTerminal.git", branch: "main")
],
targets: [
    .target(name: "YourCLI", dependencies: ["VirtualTerminal"])
]
```

## Requirements

- **Swift 6.0+**
- **macOS 14+**, **Linux**, or **Windows 10+**  
- Terminal with basic ANSI support (any modern terminal)
