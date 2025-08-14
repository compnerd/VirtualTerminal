// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

@_exported
import Geometry

/// A terminal interface that provides async access to terminal operations.
///
/// `VTTerminal` defines the core protocol for terminal implementations,
/// providing input event handling and output capabilities. Implementations
/// handle platform-specific details while presenting a unified async interface.
///
/// The protocol uses Swift's actor model to ensure thread-safe access to
/// terminal resources, preventing data races and ensuring consistent state.
///
/// ## Usage
///
/// ```swift
/// // Write text and control sequences
/// await terminal <<< .CursorPosition(10, 5)
///                <<< .SelectGraphicRendition([.bold, .foreground(.red)])
///                <<< "Hello, World in bold red!"
///
/// // Handle input events
/// for await event in terminal.input {
///     switch event {
///     case .key(let key):
///         // Process keyboard input
///     case .resize(let size):
///         // Handle terminal size changes
///     default:
///         break
///     }
/// }
/// ```
public protocol VTTerminal: Actor {
  /// The current dimensions of the terminal window.
  ///
  /// This property reflects the terminal's size in character cells and
  /// automatically updates when the terminal is resized. Access is
  /// non-isolated for performance since size queries are frequent.
  nonisolated var size: Size { get }

  /// An async stream of input events from the terminal.
  ///
  /// This stream provides keyboard input, mouse events, and terminal
  /// resize notifications. The stream remains active for the lifetime
  /// of the terminal and automatically handles platform-specific
  /// input parsing.
  ///
  /// Events are delivered in real-time as they occur, making this suitable
  /// for interactive applications and games.
  nonisolated var input: VTEventStream { get }

  /// Writes text or control sequences to the terminal output.
  ///
  /// Text is sent directly to the terminal and may include ANSI escape
  /// sequences for cursor movement, colors, and formatting. For structured
  /// output, consider using the `<<<` operators with `ControlSequence`
  /// values instead.
  ///
  /// - Parameter string: The text or escape sequences to write.
  func write(_ string: String)

  /// Manually restore termios attributes.
  func _restore()
}

extension VTTerminal {
  /// Writes a control sequence to the terminal using a fluent syntax.
  ///
  /// This operator provides a convenient way to send structured terminal
  /// commands while maintaining chainability for complex output operations.
  /// The sequence is automatically converted to its string representation.
  ///
  /// - Parameters:
  ///   - terminal: The terminal to write to.
  ///   - sequence: The control sequence to send.
  /// - Returns: The terminal instance for chaining additional operations.
  @inlinable
  @discardableResult
  public static func <<< (_ terminal: Self, _ sequence: ControlSequence) async -> Self {
    await terminal.write(sequence.description)
    return terminal
  }

  /// Writes a string to the terminal using a fluent syntax.
  ///
  /// This operator provides a chainable way to send text output while
  /// maintaining consistency with control sequence operations.
  ///
  /// - Parameters:
  ///   - terminal: The terminal to write to.
  ///   - string: The text to send.
  /// - Returns: The terminal instance for chaining additional operations.
  @inlinable
  @discardableResult
  public static func <<< (_ terminal: Self, _ string: String) async -> Self {
    await terminal.write(string)
    return terminal
  }
}
