// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

#if !os(Windows)

#if canImport(Glibc)
import Glibc
#endif

import Geometry
import POSIXCore
import Primitives

/// POSIX/Unix terminal implementation using standard file descriptors.
///
/// `POSIXTerminal` provides a cross-platform Unix/Linux implementation that
/// interfaces directly with POSIX terminal APIs. It handles terminal attribute
/// management, input parsing, and output rendering using standard POSIX system
/// calls like `tcgetattr`, `tcsetattr`, and terminal I/O operations.
///
/// ## POSIX Terminal Features
///
/// This implementation leverages standard POSIX terminal capabilities:
/// - **Terminal Attributes**: Manages canonical vs. raw mode, echo, and flow control
/// - **Window Size Detection**: Uses `TIOCGWINSZ` ioctl for accurate terminal dimensions
/// - **Input Parsing**: Processes escape sequences and control characters
/// - **Attribute Restoration**: Automatically restores original terminal state on cleanup
///
/// ## Terminal Modes
///
/// The implementation supports two primary terminal interaction modes:
///
/// ### Raw Mode
/// ```swift
/// let terminal = try await POSIXTerminal(mode: .raw)
/// ```
/// - Disables line buffering (canonical mode)
/// - Disables echo of typed characters
/// - Disables XON/XOFF flow control
/// - Disables CR-to-NL translation
/// - Ideal for interactive applications and games
///
/// ### Canonical Mode
/// ```swift
/// let terminal = try await POSIXTerminal(mode: .canonical)
/// ```
/// - Enables line buffering (input available after Enter)
/// - Enables character echo
/// - Enables XON/XOFF flow control
/// - Enables CR-to-NL translation
/// - Suitable for line-oriented applications
///
/// ## Usage Example
///
/// ```swift
/// // Create terminal for interactive application
/// let terminal = try await POSIXTerminal(mode: .raw)
///
/// // Clear screen and position cursor
/// await terminal.write("\u{1B}[2J\u{1B}[H")
/// await terminal.write("Interactive Terminal Application\n")
///
/// // Process keyboard input
/// for await events in terminal.input {
///   for event in events {
///     switch event {
///     case .key(let keyEvent):
///       if keyEvent.key == .escape {
///         return  // Exit application
///       }
///       // Handle other keys
///     }
///   }
/// }
/// // Terminal attributes automatically restored on deinit
/// ```
///
/// ## Platform Compatibility
///
/// This implementation works on all POSIX-compliant systems including:
/// - Linux distributions
/// - macOS
/// - FreeBSD, OpenBSD, NetBSD
/// - Other Unix-like systems
///
/// ## Thread Safety
///
/// The actor-based design ensures thread-safe access to terminal file
/// descriptors and prevents race conditions in terminal attribute management.
internal final actor POSIXTerminal: VTTerminal {
  private let hIn: CInt
  private let hOut: CInt
  private let sAttributes: termios

  /// Stream of terminal input events parsed from POSIX terminal input.
  ///
  /// This stream continuously reads from the terminal's input file descriptor
  /// and parses escape sequences, control characters, and regular key presses
  /// into structured `VTEvent` instances. The parsing handles complex sequences
  /// like function keys, arrow keys, and mouse events.
  public nonisolated let input: VTEventStream

  /// Current terminal dimensions in character units.
  ///
  /// This property reflects the terminal window size obtained from the
  /// `TIOCGWINSZ` ioctl call. It represents the visible character grid
  /// available for output and is determined during initialization.
  ///
  /// ## Note
  /// Window resize detection is not yet implemented (SIGWINCH handler).
  /// The size remains static after terminal initialization.
  private let _size: Atomic<Size>
  public nonisolated var size: Size {
    return _size.load()
  }

  /// Creates a new POSIX terminal interface with the specified mode.
  ///
  /// This initializer configures the terminal attributes according to the
  /// requested mode and sets up input parsing. It preserves the original
  /// terminal configuration for restoration during cleanup.
  ///
  /// ## Parameters
  /// - mode: Terminal interaction mode (`.raw` or `.canonical`)
  ///
  /// ## Initialization Process
  /// 1. Queries current terminal attributes with `tcgetattr`
  /// 2. Saves original attributes for later restoration
  /// 3. Modifies attributes based on the requested mode
  /// 4. Applies new attributes with `tcsetattr`
  /// 5. Determines terminal window size using `TIOCGWINSZ`
  /// 6. Starts asynchronous input parsing task
  ///
  /// ## Mode Differences
  ///
  /// ### Raw Mode Configuration
  /// - Disables `ICANON`: No line buffering, characters available immediately
  /// - Disables `ECHO`: Typed characters are not echoed to terminal
  /// - Disables `IXON`: No XON/XOFF software flow control
  /// - Disables `ICRNL`: Carriage return not translated to newline
  ///
  /// ### Canonical Mode Configuration
  /// - Enables `ICANON`: Line buffering, input available after newline
  /// - Enables `ECHO`: Characters are echoed as typed
  /// - Enables `IXON`: XON/XOFF flow control active
  /// - Enables `ICRNL`: Carriage return translated to newline
  ///
  /// ## Usage Examples
  ///
  /// ### Interactive Application (Raw Mode)
  /// ```swift
  /// let terminal = try await POSIXTerminal(mode: .raw)
  /// // Immediate character response, no echo
  /// // Suitable for games, editors, interactive UIs
  /// ```
  ///
  /// ### Command-Line Tool (Canonical Mode)
  /// ```swift
  /// let terminal = try await POSIXTerminal(mode: .canonical)
  /// // Line-based input with echo
  /// // Suitable for traditional command-line interfaces
  /// ```
  ///
  /// ## Error Conditions
  /// Throws `POSIXError` if:
  /// - Terminal attribute queries fail (`tcgetattr`)
  /// - Terminal attribute setting fails (`tcsetattr`)
  /// - Window size query fails (`ioctl` with `TIOCGWINSZ`)
  /// - Terminal dimensions are invalid (zero width or height)
  ///
  /// ## Cleanup Behavior
  /// Original terminal attributes are automatically restored when the
  /// terminal is deallocated, ensuring the shell remains usable.
  public init(mode: VTMode) async throws {
    self.hIn = STDIN_FILENO
    self.hOut = STDOUT_FILENO

    var attr: termios = termios()
    guard tcgetattr(hIn, &attr) == 0 else {
      throw POSIXError()
    }

    // Save the original terminal attributes
    self.sAttributes = attr

    switch mode {
    case .raw:
      // Disable canonical mode, echo, XON/XOFF, and CR to NL translation
      #if os(Linux)
      attr.c_lflag &= UInt32(~(UInt32(ICANON | ECHO | IXON | ICRNL)))
      #else
      attr.c_lflag &= ~(ICANON | ECHO | IXON | ICRNL)
      #endif
    case .canonical:
      // Enable canonical mode, echo, XON/XOFF, and CR to NL translation
      #if os(Linux)
      attr.c_lflag |= UInt32(ICANON | ECHO | IXON | ICRNL)
      #else
      attr.c_lflag |= (ICANON | ECHO | IXON | ICRNL)
      #endif
    }

    guard tcsetattr(hOut, TCSANOW, &attr) == 0 else {
      throw POSIXError()
    }

    var ws = winsize()
    guard ioctl(hOut, UInt(TIOCGWINSZ), &ws) == 0 else {
      throw POSIXError()
    }

    let size = Size(width: Int(ws.ws_col), height: Int(ws.ws_row))
    guard size.width > 0 && size.height > 0 else {
      throw POSIXError(EINVAL)
    }
    _size = Atomic(size)

    // TODO(compnerd): setup SIGWINCH handler to update size

    self.input = VTEventStream(AsyncThrowingStream { [hIn] continuation in
      Task {
        var parser = VTInputParser()

        while !Task.isCancelled {
          do {
            let events = try withUnsafeTemporaryAllocation(of: CChar.self, capacity: 128) {
              guard let baseAddress = $0.baseAddress else { throw POSIXError() }
              let count = read(hIn, baseAddress, $0.count)
              guard count >= 0 else { throw POSIXError() }

              let sequences = baseAddress.withMemoryRebound(to: UInt8.self, capacity: count) {
                let buffer = UnsafeBufferPointer<UInt8>(start: $0, count: count)
                return parser.parse(ArraySlice(buffer))
              }

              return sequences.compactMap { $0.event.map { VTEvent.key($0) } }
            }
            continuation.yield(events)
          } catch {
            continuation.finish(throwing: error)
          }
        }
        continuation.finish()
      }
    })
  }

  deinit {
    // Restore the original terminal attributes on deinitialization
    var attr = self.sAttributes
    _ = tcsetattr(self.hOut, TCSAFLUSH, &attr)
  }

  public func _restore() {
    var attr = self.sAttributes
    _ = tcsetattr(self.hOut, TCSAFLUSH, &attr)
  }

  /// Writes string data directly to the terminal output.
  ///
  /// This method sends UTF-8 encoded string data to the terminal using the
  /// POSIX `write` system call. The string can contain VT100/ANSI escape
  /// sequences which will be interpreted by the terminal emulator.
  ///
  /// ## Parameters
  /// - string: The text to write, including any escape sequences
  ///
  /// ## Usage Examples
  /// ```swift
  /// // Write plain text
  /// await terminal.write("Hello, Unix Terminal!")
  ///
  /// // Write with ANSI color codes
  /// await terminal.write("\u{1B}[32mGreen text\u{1B}[0m")
  ///
  /// // Complex cursor positioning
  /// await terminal.write("\u{1B}[10;5H")  // Move to row 10, column 5
  /// await terminal.write("Positioned text")
  /// ```
  ///
  /// ## Performance Characteristics
  /// Each call results in a single `write` system call. For applications
  /// generating substantial output, consider using `VTBufferedTerminalStream`
  /// to batch writes and reduce system call overhead.
  ///
  /// ## Error Handling
  /// Write failures are silently ignored in this implementation. The POSIX
  /// `write` call may fail if the output file descriptor is closed or the
  /// process lacks write permissions, but these errors are not propagated.
  ///
  /// ## Terminal Interpretation
  /// The terminal emulator will interpret escape sequences in the string:
  /// - Color and style changes (SGR sequences)
  /// - Cursor positioning and movement
  /// - Screen clearing and scrolling commands
  /// - Other VT100/ANSI control sequences
  public func write(_ string: String) {
    #if canImport(Glibc)
    _ = Glibc.write(self.hOut, string, string.utf8.count)
    #else
    _ = unistd.write(self.hOut, string, string.utf8.count)
    #endif
  }
}

#endif
