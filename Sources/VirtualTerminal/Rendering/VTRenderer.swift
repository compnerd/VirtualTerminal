// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Geometry

#if os(Windows)
internal typealias PlatformTerminal = WindowsTerminal
#else
internal typealias PlatformTerminal = POSIXTerminal
#endif

/// Optimized segment types for efficient terminal output.
///
/// The renderer analyzes buffer content to identify patterns that can be
/// optimized during output. Repeated characters are encoded as run-length
/// segments, while diverse content is sent as literal strings.
package enum Segment {
  /// A run of repeated characters that can be optimized with repeat commands.
  case run(Character, Int)
  /// A literal string segment containing diverse characters.
  case literal(String)
}

extension VTBuffer {
  /// Analyzes a buffer range to create optimized output segments.
  ///
  /// This method performs run-length analysis to identify sequences of
  /// repeated characters that can be efficiently encoded using terminal
  /// repeat commands. Short runs below the minimum length threshold are
  /// grouped into literal segments for optimal output.
  ///
  /// ## Performance Optimization
  ///
  /// The segmentation process reduces terminal output by:
  /// - Using repeat commands for character runs ≥ `minlength`
  /// - Grouping short runs into efficient literal segments
  /// - Minimizing the number of escape sequences sent
  ///
  /// ## Parameters
  /// - range: Linear buffer range to analyze for segments
  /// - minlength: Minimum run length to qualify for run-length encoding
  ///
  /// ## Returns
  /// Array of segments optimized for terminal transmission
  package borrowing func segment(_ range: Range<Int>, minlength: Int = 5) -> [Segment] {
    assert(!range.isEmpty, "Range must not be empty")

    var segments: [Segment] = []

    var index: ContiguousArray<VTCell>.Index = range.lowerBound
    while index < range.upperBound {
      let start = index
      let character = buffer[index].character

      while index < range.upperBound && buffer[index].character == character {
        index += 1
      }

      let length = index - start
      if length >= minlength {
        // This is a repeated character run, so we store it as a run segment.
        segments.append(.run(character, length))
        continue
      }

      // This is a short run, so we store it as a literal segment. Continue
      // to the next run.
      var end = index

      while index < range.upperBound {
        let start = index
        let character = buffer[index].character

        while index < range.upperBound && buffer[index].character == character {
          index += 1
        }

        let length = index - start
        if length >= minlength {
          // This will form a new run, stop the literal segment here.
          index = start
          break
        }

        // Otherwise, we extend the literal segment to include this short run.
        end = index
      }

      segments.append(.literal(String(buffer[start ..< end].map(\.character))))
    }

    return segments
  }
}

/// A high-performance double-buffered terminal renderer.
///
/// `VTRenderer` implements an efficient rendering system that minimizes
/// terminal output through damage-based updates and intelligent optimization.
/// The renderer uses double buffering to track changes between frames and
/// only redraws modified areas.
///
/// ## Architecture
///
/// The renderer maintains two buffers:
/// - **Back buffer**: Where your application draws new content
/// - **Front buffer**: The current displayed state
///
/// During `present()`, the renderer compares buffers to identify changes
/// (damage) and sends only the necessary updates to the terminal.
///
/// ## Performance Features
///
/// - **Damage-based rendering**: Only updates changed areas
/// - **Run-length encoding**: Optimizes repeated character output
/// - **Cursor optimization**: Minimizes cursor movement commands
/// - **Synchronized updates**: Uses terminal synchronization for flicker-free rendering
/// - **SGR state tracking**: Minimizes style change commands
///
/// ## Usage Example
///
/// ```swift
/// let renderer = try await VTRenderer(mode: .raw)
///
/// // Render loop with automatic frame rate control
/// try await renderer.rendering(fps: 60) { buffer in
///   // Draw your content to the buffer
///   buffer.write(string: "Hello, World!", at: VTPosition(row: 1, column: 1))
///   buffer.fill(rect: Rect(x: 0, y: 10, width: 20, height: 5),
///               with: "█", style: .default)
/// }
/// ```
public final class VTRenderer: Sendable {
  /// The underlying platform-specific terminal implementation.
  private let _terminal: PlatformTerminal
  /// The currently displayed buffer state (visible to the user).
  package nonisolated(unsafe) var front: VTBuffer
  /// The buffer where new content is drawn (back buffer for double buffering).
  package nonisolated(unsafe) var back: VTBuffer

  /// Performance profiler for tracking rendering statistics (optional).
  public private(set) nonisolated(unsafe) var profiler: VTProfiler?

  /// Creates a new renderer with the specified terminal mode.
  ///
  /// Initializes the double-buffered rendering system and establishes
  /// connection to the terminal. The renderer automatically detects
  /// the terminal size and creates appropriately sized buffers.
  ///
  /// ## Error Conditions
  /// Throws if terminal initialization fails, which can happen if:
  /// - Terminal is not available (non-interactive environment)
  /// - Terminal capabilities are insufficient
  /// - Platform-specific terminal setup fails
  ///
  /// - Parameter mode: Terminal mode configuration for capabilities and behavior
  /// - Throws: Terminal initialization errors
  public init(mode: VTMode) async throws {
    self._terminal = try await PlatformTerminal(mode: mode)
    self.front = VTBuffer(size: _terminal.size)
    self.back = VTBuffer(size: _terminal.size)
  }

  /// Provides access to the underlying terminal for direct operations.
  ///
  /// Use this property when you need to send control sequences directly
  /// or access terminal-specific functionality that isn't part of the
  /// standard rendering pipeline.
  ///
  /// ## Usage Example
  /// ```swift
  /// // Send a direct control sequence
  /// await renderer.terminal.write(.SetMode(.DEC(.UseAlternateScreenBuffer)))
  ///
  /// // Access terminal properties
  /// let size = renderer.terminal.size
  /// ```
  public var terminal: some VTTerminal {
    self._terminal
  }

  /// Current rendering performance statistics.
  ///
  /// Provides real-time performance metrics when profiling is enabled
  /// through the `rendering(fps:_:)` method. Returns zero values when
  /// profiling is not active.
  ///
  /// ## Metrics Available
  /// - **FPS**: Current, average, minimum, and maximum frame rates
  /// - **Frame time**: Current and average frame rendering duration
  /// - **Frame counts**: Total rendered and dropped frame counts
  ///
  /// ## Usage Example
  /// ```swift
  /// let stats = renderer.statistics
  /// print("FPS: \(stats.fps.current), Frame time: \(stats.frametime.current)")
  /// ```
  public nonisolated var statistics: FrameStatistics {
    profiler?.statistics
        ?? FrameStatistics(fps: (current: 0, average: 0, max: 0, min: 0),
                           frametime: (current: .zero, average: .zero),
                           frames: (rendered: 0, dropped: 0))
  }

  /// Renders damage spans to the terminal with optimized output.
  ///
  /// This is the core rendering method that converts buffer differences
  /// into efficient terminal commands. It performs several optimizations:
  ///
  /// - **Synchronized updates**: Prevents flicker during complex updates
  /// - **Cursor optimization**: Minimizes cursor movement by leveraging auto-wrap
  /// - **SGR state tracking**: Reduces style change commands
  /// - **Run-length encoding**: Optimizes repeated character sequences
  ///
  /// The method uses terminal synchronization to ensure atomic updates
  /// and maintains minimal cursor movement for optimal performance.
  private borrowing func paint(_ damages: [DamageSpan]) async {
    // If there is no damage, we can skip the reconciliation.
    guard !damages.isEmpty else { return }

    await withBufferedOutput(terminal: terminal) { stream in
      stream <<< .SetMode([.DEC(.SynchronizedUpdate)])
      defer { stream <<< .ResetMode([.DEC(.SynchronizedUpdate)]) }

      var tracker = SGRStateTracker()
      var current = VTPosition(row: .max, column: .max)

      for span in damages {
        let position = back.position(at: span.range.lowerBound)

        // Only move cursor if we're not already at the right position.  This
        // leverages terminal auto-wrapping for contiguous spans
        if position != current {
          for motion in back.reposition(from: current, to: position) {
            stream <<< motion
          }
        }

        // Update rendition state.
        let transition = tracker.transition(to: span.style)
        if !transition.isEmpty {
          stream <<< .SelectGraphicRendition(transition)
        }

        // Write all characters in the span - terminal will auto-wrap at row boundaries
        for segment in back.segment(span.range) {
          switch segment {
          case .run(let character, let count):
            stream <<< String(character) <<< .Repeat(count - 1)
          case .literal(let string):
            stream <<< string
          }
        }

        // "deferred wrap" or "soft-wrap" puts the parser into a pending wrap
        // state where the cursor is still at the end of the line, but the next
        // character will be written at the start of the next line.
        let deferred =
            back.position(at: span.range.upperBound - 1).column == back.size.width
        // Update the current position.
        current = back.position(at: span.range.upperBound - (deferred ? 1 : 0))
      }

      stream <<< .SelectGraphicRendition([.Reset])
    }
  }

  /// Presents the back buffer to the terminal and swaps buffers.
  ///
  /// This method performs the core double-buffering operation:
  /// 1. Compares back and front buffers to identify damaged areas
  /// 2. Sends optimized updates for only the changed regions
  /// 3. Swaps buffers to prepare for the next frame
  ///
  /// The damage detection ensures minimal terminal output by sending
  /// only the changes since the last frame, dramatically improving
  /// performance for applications with partial screen updates.
  ///
  /// ## Usage in Manual Rendering
  /// ```swift
  /// // Draw content to back buffer
  /// renderer.back.write(string: "Updated content", at: position)
  ///
  /// // Present changes and swap buffers
  /// await renderer.present()
  ///
  /// // Back buffer is now ready for next frame
  /// renderer.back.clear()
  /// ```
  ///
  /// ## Performance Characteristics
  /// - Only changed areas are redrawn
  /// - Cursor movement is optimized
  /// - Style changes are minimized
  /// - Output is synchronized to prevent flicker
  public borrowing func present() async {
    // Compute the damage between the front and back buffers and repaint.
    await paint(damages(from: front, to: back))
    // Swap the front and back buffers to prepare for the next frame.
    swap(&front, &back)
  }

  /// Runs an automatic rendering loop with frame rate control and profiling.
  ///
  /// This method provides a complete rendering solution with automatic
  /// frame rate control, performance profiling, and buffer management.
  /// Your render callback is called at the specified frame rate, and
  /// the renderer handles all timing and optimization automatically.
  ///
  /// ## Features
  /// - **Frame rate control**: Maintains consistent timing
  /// - **Performance profiling**: Tracks FPS and frame time metrics
  /// - **Automatic buffer management**: Handles present and clear operations
  /// - **Structured concurrency**: Properly manages the rendering task
  ///
  /// ## Parameters
  /// - fps: Target frame rate (frames per second)
  /// - render: Callback that draws content to the back buffer
  ///
  /// ## Usage Example
  /// ```swift
  /// try await renderer.rendering(fps: 60) { buffer in
  ///   // Draw your application content
  ///   drawUI(&buffer)
  ///   drawGame(&buffer)
  /// }
  /// ```
  ///
  /// ## Error Handling
  /// The method propagates any errors thrown by your render callback
  /// and properly cleans up the rendering loop. The rendering task
  /// is automatically cancelled when the method exits.
  ///
  /// ## Performance Monitoring
  /// While this method runs, use the `statistics` property to monitor
  /// rendering performance and detect frame drops or timing issues.
  public func rendering(fps: Double, _ render: @escaping @Sendable (inout VTBuffer) throws -> Void) async throws {
    self.profiler = VTProfiler(target: fps)
    let link = VTDisplayLink(fps: fps) { [unowned self] _ in
      try render(&back)
      await profiler!.measure { await present() }
      back.clear()
    }

    try await withThrowingTaskGroup(of: Void.self) { group in
      defer { group.cancelAll() }

      // Add the display link task to the group.
      link.add(to: &group)

      // Wait for the display link task to complete.
      try await group.next()
    }
  }
}
