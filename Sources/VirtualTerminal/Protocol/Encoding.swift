// Copyright © 2021 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// A control sequence paired with its encoding format.
///
/// `EncodedControlSequence` represents a terminal control sequence that has
/// been associated with a specific encoding (7-bit or 8-bit). This is useful
/// when you need to store or pass around sequences with their encoding
/// information intact.
///
/// ## Usage Example
/// ```swift
/// let encoded = EncodedControlSequence(.CursorUp(5), encoding: .b7)
/// // The sequence retains both the command and encoding information
/// ```
public struct EncodedControlSequence: Sendable {
  public let sequence: ControlSequence
  public let encoding: ControlSequenceEncoding

  public init(_ sequence: ControlSequence, encoding: ControlSequenceEncoding) {
    self.sequence = sequence
    self.encoding = encoding
  }
}

/// Context for writing control sequences with a specific encoding.
///
/// `EncodedStreamContext` provides a fluent interface for writing terminal
/// control sequences and text with a consistent encoding format. This ensures
/// all sequences sent through the context use the same 7-bit or 8-bit
/// encoding, which is important for terminal compatibility.
///
/// The context maintains a reference to the underlying terminal stream and
/// automatically encodes all control sequences before sending them.
///
/// ## Usage Example
/// ```swift
/// let terminal: any Terminal = ...
/// let context = terminal(encoding: .b7)
///
/// // All sequences will use 7-bit encoding
/// await context <<< .CursorPosition(10, 20)
///               <<< "Hello, World!"
/// await context <<< .SelectGraphicRendition([.bold, .foreground(.red)])
/// ```
public final class EncodedStreamContext: Sendable {
  @usableFromInline
  internal nonisolated(unsafe) var stream: any VTTerminal

  @usableFromInline
  internal let encoding: ControlSequenceEncoding

  @inlinable
  public init(stream: any VTTerminal, encoding: ControlSequenceEncoding) {
    self.stream = stream
    self.encoding = encoding
  }
}

extension VTTerminal {
  /// Creates an encoded stream context with the specified encoding.
  ///
  /// This method provides a convenient way to create a context that will
  /// encode all control sequences using the specified format. Use this
  /// when you need consistent encoding across multiple terminal operations.
  ///
  /// - Parameter encoding: The encoding format to use for all sequences.
  /// - Returns: An encoded stream context bound to this terminal.
  @inlinable
  public func callAsFunction(encoding: ControlSequenceEncoding) -> EncodedStreamContext {
    EncodedStreamContext(stream: self, encoding: encoding)
  }
}

extension EncodedStreamContext {
  /// Writes a control sequence to the terminal using the context's encoding.
  ///
  /// This operator provides a fluent interface for sending control sequences
  /// through the encoded context. The sequence is automatically encoded
  /// using the context's encoding format before being sent to the terminal.
  ///
  /// - Parameters:
  ///   - context: The encoded stream context to write through.
  ///   - sequence: The control sequence to send.
  /// - Returns: The same context for method chaining.
  @inlinable
  @discardableResult
  public static func <<< (_ context: EncodedStreamContext, _ sequence: ControlSequence) async -> EncodedStreamContext {
    await context.stream.write(sequence.encoded(as: context.encoding))
    return context
  }

  /// Writes plain text to the terminal through the encoded context.
  ///
  /// This operator allows writing text content through the encoded context.
  /// The text is sent directly to the terminal without encoding (only
  /// control sequences require encoding).
  ///
  /// - Parameters:
  ///   - context: The encoded stream context to write through.
  ///   - string: The text string to send.
  /// - Returns: The same context for method chaining.
  @inlinable
  @discardableResult
  public static func <<< (_ context: inout EncodedStreamContext, _ string: String) async -> EncodedStreamContext {
    await context.stream.write(string)
    return context
  }
}

/// Context for scoped encoding operations - operates directly on base stream.
///
/// `EncodedBufferedStreamContext` provides a fluent interface for buffered
/// terminal operations with consistent encoding. Unlike `EncodedStreamContext`,
/// this operates on buffered streams where sequences are accumulated and
/// then flushed together, improving performance for batch operations.
///
/// This context is particularly useful when you need to build up a series
/// of terminal commands before sending them all at once.
///
/// ## Usage Example
/// ```swift
/// let buffer = VTBufferedTerminalStream(terminal)
/// let context = buffer(encoding: .b8)
///
/// // Build up a series of operations
/// context <<< .SaveCursor
///         <<< .CursorPosition(1, 1)
///         <<< .SelectGraphicRendition([.bold])
///         <<< "Status: Ready"
///         <<< .RestoreCursor
///
/// // All operations are sent together when buffer is flushed
/// await buffer.flush()
/// ```
public final class EncodedBufferedStreamContext {
  @usableFromInline
  internal var stream: VTBufferedTerminalStream

  @usableFromInline
  internal let encoding: ControlSequenceEncoding

  @inlinable
  internal init(stream: VTBufferedTerminalStream, encoding: ControlSequenceEncoding) {
    self.stream = stream
    self.encoding = encoding
  }
}

extension VTBufferedTerminalStream {
  /// Creates an encoded buffered stream context with the specified encoding.
  ///
  /// This method provides a convenient way to create a context for buffered
  /// operations that will encode all control sequences using the specified
  /// format. The context accumulates operations until the underlying
  /// buffered stream is flushed.
  ///
  /// - Parameter encoding: The encoding format to use for all sequences.
  /// - Returns: An encoded buffered stream context bound to this stream.
  @inlinable
  public func callAsFunction(encoding: ControlSequenceEncoding) -> EncodedBufferedStreamContext {
    EncodedBufferedStreamContext(stream: self, encoding: encoding)
  }
}

extension EncodedBufferedStreamContext {
  /// Appends a control sequence to the buffer using the context's encoding.
  ///
  /// This operator provides a fluent interface for adding control sequences
  /// to the buffered stream. The sequence is encoded using the context's
  /// encoding format and added to the buffer. The actual transmission occurs
  /// when the buffer is flushed.
  ///
  /// - Parameters:
  ///   - context: The encoded buffered stream context to append to.
  ///   - sequence: The control sequence to add to the buffer.
  /// - Returns: The same context for method chaining.
  @inlinable
  @discardableResult
  public static func <<< (_ context: EncodedBufferedStreamContext, _ sequence: ControlSequence) -> EncodedBufferedStreamContext {
    context.stream.append(sequence.encoded(as: context.encoding))
    return context
  }

  /// Appends plain text to the buffer through the encoded context.
  ///
  /// This operator allows adding text content to the buffered stream through
  /// the encoded context. The text is added directly to the buffer without
  /// encoding (only control sequences require encoding). The text will be
  /// sent when the buffer is flushed.
  ///
  /// - Parameters:
  ///   - context: The encoded buffered stream context to append to.
  ///   - string: The text string to add to the buffer.
  /// - Returns: The same context for method chaining.
  @inlinable
  @discardableResult
  public static func <<< (_ context: EncodedBufferedStreamContext, _ string: String) -> EncodedBufferedStreamContext {
    context.stream.append(string)
    return context
  }
}
