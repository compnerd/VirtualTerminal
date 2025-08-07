// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Geometry

/// A precise frame timing system for smooth terminal animations and rendering.
///
/// `VTDisplayLink` provides accurate frame rate control by synchronizing
/// callback execution to a specified target frame rate. It handles timing
/// precision, frame drops, and pause/resume functionality for creating
/// smooth terminal-based animations and interactive applications.
///
/// ## Key Features
///
/// - **Precise timing**: Synchronizes to target frame intervals using system clocks
/// - **Frame rate control**: Maintains consistent timing even under varying load
/// - **Pause/resume**: Allows temporary suspension without losing timing accuracy
/// - **Task group integration**: Works seamlessly with Swift's structured concurrency
/// - **Frame drop handling**: Automatically catches up when frames are delayed
///
/// ## Usage with VTRenderer
///
/// The display link integrates automatically with `VTRenderer`:
///
/// ```swift
/// try await renderer.rendering(fps: 60) { buffer in
///   // Your rendering code runs at exactly 60 FPS
///   drawAnimatedContent(&buffer, frame: frameCounter++)
/// }
/// ```
///
/// ## Manual Usage
///
/// For custom animation loops or precise timing control:
///
/// ```swift
/// let displayLink = VTDisplayLink(fps: 30) { link in
///   guard !gameIsPaused else { return }
///   updateGameLogic(deltaTime: link.duration.seconds)
///   renderFrame(timestamp: link.timestamp)
/// }
///
/// try await withThrowingTaskGroup(of: Void.self) { group in
///   displayLink.add(to: &group)
///   try await group.next()
/// }
/// ```
///
/// ## Performance Characteristics
///
/// The display link uses `ContinuousClock` for microsecond-level precision
/// and employs `Task.sleep(for:)` for efficient CPU usage. It automatically
/// handles frame catching-up when the system is under load, ensuring
/// animations remain smooth even when individual frames are delayed.
public final class VTDisplayLink: Sendable {
  /// The target time interval between frame callbacks.
  ///
  /// This duration represents the ideal time between frame updates based
  /// on the configured frame rate. For example, at 60 FPS this would be
  /// approximately 16.67 milliseconds.
  public let duration: Duration

  /// The configured target frame rate in frames per second.
  ///
  /// This computed property provides the frame rate that was specified
  /// during initialization. Use this to display current frame rate settings
  /// or verify the display link configuration.
  ///
  /// ## Usage Example
  /// ```swift
  /// print("Display link running at \(displayLink.preferredFramesPerSecond) FPS")
  /// ```
  public var preferredFramesPerSecond: Double {
    1.0 / duration.seconds
  }

  /// A Boolean value that indicates whether the system suspends the display
  /// link’s notifications to the target.
  public private(set) nonisolated(unsafe) var isPaused: Bool = false

  /// The instant that represents when the last frame displayed.
  public private(set) nonisolated(unsafe) var timestamp: ContinuousClock.Instant = .now

  /// The time stamp of the next frame.
  public var targetTimestamp: ContinuousClock.Instant {
    let elapsed = ContinuousClock.now - timestamp
    let intervals = elapsed.nanoseconds / duration.nanoseconds
    return timestamp + Duration.seconds(Double(intervals) * duration.seconds)
  }

  private let callback: @Sendable (borrowing VTDisplayLink) async throws -> Void

  /// Creates a display link with the specified frame rate and callback.
  ///
  /// The display link will attempt to call the provided callback at the
  /// specified frame rate. The callback receives a reference to the display
  /// link, allowing access to timing information and control methods.
  ///
  /// ## Parameters
  /// - fps: Target frames per second (must be > 0)
  /// - callback: Function to execute at each frame interval
  ///
  /// ## Usage Example
  /// ```swift
  /// let displayLink = VTDisplayLink(fps: 60) { link in
  ///   // Frame callback executed 60 times per second
  ///   await renderFrame()
  ///
  ///   // Access timing for animations
  ///   animateWithTime(link.timestamp)
  /// }
  /// ```
  ///
  /// ## Error Handling
  /// If the callback throws an error, it will propagate up through the
  /// task group and terminate the display link execution.
  public init(fps: Double, _ callback: @escaping @Sendable (borrowing VTDisplayLink) async throws -> Void) {
    self.duration = Duration.seconds(1.0 / fps)
    self.callback = callback
  }

  /// Temporarily suspends frame callback execution.
  ///
  /// When paused, the display link continues running and maintaining
  /// accurate timing, but skips executing the frame callback. This
  /// allows you to temporarily suspend animations or rendering without
  /// losing synchronization when resumed.
  ///
  /// ## Usage Example
  /// ```swift
  /// // Pause during menu screens
  /// displayLink.pause()
  /// await showMenu()
  /// displayLink.resume()
  /// ```
  ///
  /// ## Timing Behavior
  /// The display link continues tracking frame timestamps while paused,
  /// so when resumed, it will continue from the correct timing position
  /// without catching up on missed frames.
  public func pause() {
    self.isPaused = true
  }

  /// Resumes frame callback execution after being paused.
  ///
  /// Restores normal frame callback execution at the configured frame rate.
  /// The display link will continue from its current timing position
  /// without attempting to catch up on frames that occurred while paused.
  ///
  /// ## Usage Example
  /// ```swift
  /// displayLink.resume()
  /// // Frame callbacks resume at the next frame boundary
  /// ```
  public func resume() {
    self.isPaused = false
  }

  /// Adds the display link to a task group for concurrent execution.
  ///
  /// This method integrates the display link into Swift's structured
  /// concurrency system by adding it as a task to a `ThrowingTaskGroup`.
  /// The display link will run concurrently with other tasks in the group,
  /// executing its callback at the configured frame rate.
  ///
  /// ## Parameters
  /// - group: A throwing task group that will manage the display link's execution
  ///
  /// ## Usage Example
  /// ```swift
  /// let displayLink = VTDisplayLink(fps: 60) { link in
  ///   await updateAnimation()
  /// }
  ///
  /// try await withThrowingTaskGroup(of: Void.self) { group in
  ///   displayLink.add(to: &group)
  ///
  ///   // Add other concurrent tasks
  ///   group.addTask { await handleUserInput() }
  ///
  ///   // Wait for any task to complete or throw
  ///   try await group.next()
  /// }
  /// ```
  ///
  /// ## Behavior
  /// The display link task will continue running until:
  /// - The task is cancelled (via `Task.isCancelled`)
  /// - The callback throws an error
  /// - The task group is cancelled
  ///
  /// ## Performance Notes
  /// The task uses an unowned reference to `self` to avoid retain cycles,
  /// so ensure the display link instance remains alive while the task is running.
  public func add(to group: inout ThrowingTaskGroup<Void, Error>) {
    group.addTask { [unowned self] in
      timestamp = .now
      repeat {
        // Synchronise to the display link interval.
        let remainder = targetTimestamp - ContinuousClock.now
        if remainder > .zero {
          try await Task.sleep(for: remainder)
        }

        // Update the frame timing.
        timestamp = targetTimestamp

        guard !isPaused else { continue }
        try await callback(self)
      } while !Task.isCancelled
    }
  }
}
