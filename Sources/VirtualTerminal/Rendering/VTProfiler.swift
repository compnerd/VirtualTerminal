// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Primitives

/// Comprehensive rendering performance metrics over a sliding time window.
///
/// `FrameStatistics` provides detailed insights into terminal rendering
/// performance, including frame rate analysis, timing data, and dropped
/// frame tracking. These metrics help optimize application performance
/// and identify rendering bottlenecks.
///
/// ## Usage Example
/// ```swift
/// let stats = profiler.statistics
/// print("Current FPS: \(stats.fps.current)")
/// print("Average frame time: \(stats.frametime.average)")
/// print("Dropped frames: \(stats.frames.dropped)")
///
/// if stats.frames.dropped > 0 {
///   print("Warning: Frame drops detected - consider optimizing render loop")
/// }
/// ```
public struct FrameStatistics: Sendable {
  /// Frame rate metrics across different time scales.
  ///
  /// - `current`: Instantaneous FPS based on the most recent frame
  /// - `average`: Mean FPS over the entire sampling window
  /// - `max`: Peak FPS achieved (from shortest frame time)
  /// - `min`: Lowest FPS recorded (from longest frame time)
  public let fps: (current: Double, average: Double, max: Double, min: Double)

  /// Frame timing measurements for performance analysis.
  ///
  /// - `current`: Duration of the most recent frame
  /// - `average`: Mean frame duration over the sampling window
  ///
  /// Use these metrics to identify performance regressions and optimize
  /// rendering code. Consistent frame times indicate stable performance.
  public let frametime: (current: Duration, average: Duration)

  /// Frame processing counters for drop detection.
  ///
  /// - `rendered`: Total frames processed by the profiler
  /// - `dropped`: Frames that exceeded the target frame time
  ///
  /// Dropped frames indicate the rendering loop is taking longer than
  /// the target frame duration, potentially causing visual stuttering.
  public let frames: (rendered: Int, dropped: Int)
}

/// High-performance frame timing profiler for terminal rendering.
///
/// `VTProfiler` provides efficient performance monitoring for terminal
/// applications with minimal overhead. It uses a ring buffer to maintain
/// a sliding window of recent frame times and incrementally updates
/// statistics to avoid expensive recalculations.
///
/// ## Key Features
///
/// - **Low overhead**: Ring buffer design minimizes memory allocations
/// - **Incremental statistics**: Efficient min/max tracking without full scans
/// - **Configurable window**: Adapts sampling window to target frame rate
/// - **Drop detection**: Identifies frames exceeding target duration
/// - **~Copyable**: Prevents accidental expensive copies
///
/// ## Usage with VTRenderer
///
/// The profiler integrates seamlessly with `VTRenderer`'s automatic
/// rendering loop:
///
/// ```swift
/// try await renderer.rendering(fps: 60) { buffer in
///   // Your rendering code here
///   drawContent(&buffer)
/// }
///
/// // Access performance metrics
/// let stats = renderer.statistics
/// if stats.fps.current < 30 {
///   optimizeRenderingPath()
/// }
/// ```
///
/// ## Manual Profiling
///
/// For custom timing scenarios outside of the renderer:
///
/// ```swift
/// var profiler = VTProfiler(target: 60.0)
///
/// // Profile a specific operation
/// let (duration, result) = profiler.measure {
///   performExpensiveOperation()
/// }
///
/// // Check if operation was too slow
/// let stats = profiler.statistics
/// if stats.frames.dropped > 0 {
///   print("Operation exceeded target time")
/// }
/// ```
///
/// ## Performance Considerations
///
/// The profiler automatically sizes its sampling window based on the
/// target frame rate (minimum 60 samples, or 2 seconds worth of frames).
/// This provides stable statistics while keeping memory usage bounded.
public struct VTProfiler: ~Copyable {
  /// Target frame duration for drop detection.
  private let target: Duration
  /// Ring buffer maintaining recent frame time samples.
  private var samples: RingBuffer<Duration>

  /// Frame counters for rendered and dropped frame tracking.
  private var frames: (rendered: Int, dropped: Int) = (0, 0)
  /// Incrementally maintained min/max values for efficient statistics.
  private var extrema: (min: Duration, max: Duration) =
      (.nanoseconds(Int64.max), .zero)

  /// Creates a profiler configured for the specified target frame rate.
  ///
  /// The profiler automatically configures its sampling window size based
  /// on the target frame rate to provide stable statistics. The minimum
  /// window size is 60 samples, with larger windows for higher frame rates
  /// to maintain approximately 2 seconds of sample history.
  ///
  /// ## Parameters
  /// - fps: Target frames per second (must be > 0)
  ///
  /// ## Usage Example
  /// ```swift
  /// // Create profiler for 60 FPS target
  /// let profiler = VTProfiler(target: 60.0)
  ///
  /// // For high-refresh displays
  /// let profiler120 = VTProfiler(target: 120.0)
  /// ```
  ///
  /// ## Preconditions
  /// The target FPS must be greater than zero. Invalid values will trigger
  /// a runtime assertion in debug builds.
  public init(target fps: Double) {
    precondition(fps > 0, "Target FPS must be greater than zero")
    self.target = .nanoseconds(Int64(1_000_000_000.0 / fps))
    self.samples = RingBuffer(capacity: max(Int(fps * 2.0), 60))
  }

  /// Records a frame time sample and updates performance statistics.
  ///
  /// This method efficiently maintains all profiling statistics:
  /// - Increments frame counters
  /// - Tracks dropped frames (exceeding target duration)
  /// - Updates min/max extrema incrementally
  /// - Handles ring buffer overflow with extrema recalculation
  ///
  /// The incremental approach avoids expensive full-buffer scans on
  /// every sample, maintaining O(1) complexity in the common case.
  ///
  /// ## Performance Notes
  /// When the ring buffer evicts a sample that was a minimum or maximum
  /// value, the method performs a full scan to recalculate extrema.
  /// This ensures accuracy while keeping the common case efficient.
  private mutating func record(sample: Duration) {
    frames.rendered += 1
    if sample > target {
      frames.dropped += 1
    }

    // Handle ring buffer capacity
    let evicted: Duration? = samples.isFull ? samples.peek() : nil

    samples.push(sample)
    if evicted == extrema.min || evicted == extrema.max {
      // Recalculate min/max if evicted sample was an extremum
      extrema.min = samples.reduce(.nanoseconds(Int64.max)) { min($0, $1) }
      extrema.max = samples.reduce(.zero) { max($0, $1) }
    } else {
      extrema.min = min(extrema.min, sample)
      extrema.max = max(extrema.max, sample)
    }
  }

  /// Measures the execution time of a synchronous operation.
  ///
  /// This method provides precise timing measurement with automatic
  /// sample recording. It's ideal for profiling specific operations
  /// or integrating with custom rendering loops that need detailed
  /// performance analysis.
  ///
  /// ## Usage Examples
  /// ```swift
  /// // Profile a specific rendering operation
  /// let (duration, result) = profiler.measure {
  ///   return complexRenderingOperation()
  /// }
  /// print("Operation took \(duration)")
  ///
  /// // Profile without caring about the result
  /// profiler.measure {
  ///   updateGameState()
  /// }
  /// ```
  ///
  /// ## Error Handling
  /// If the operation throws an error, the timing is still recorded
  /// before the error is re-thrown, ensuring accurate profiling
  /// even for failed operations.
  ///
  /// - Parameter operation: The operation to time and profile
  /// - Returns: Tuple containing measured duration and operation result
  /// - Throws: Any error thrown by the operation
  @discardableResult
  public mutating func measure<Result>(_ operation: () throws -> Result) rethrows -> (Duration, Result) {
    let start = ContinuousClock.now
    let result = try operation()
    let delta = ContinuousClock.now - start

    record(sample: delta)
    return (delta, result)
  }

  /// Measures the execution time of an asynchronous operation.
  ///
  /// This async variant provides the same timing capabilities for
  /// asynchronous operations, making it perfect for profiling async
  /// rendering operations, I/O operations, or any async work that
  /// affects frame timing.
  ///
  /// ## Usage Examples
  /// ```swift
  /// // Profile async rendering operations
  /// let (duration, _) = await profiler.measure {
  ///   await renderComplexScene()
  /// }
  ///
  /// // Profile async I/O that affects rendering
  /// await profiler.measure {
  ///   await loadTextureAsync()
  /// }
  /// ```
  ///
  /// ## Concurrency Notes
  /// The profiler itself is not thread-safe and should be used from
  /// a single actor or protected by appropriate synchronization when
  /// accessed from multiple concurrent contexts.
  ///
  /// - Parameter operation: The async operation to time and profile
  /// - Returns: Tuple containing measured duration and operation result
  /// - Throws: Any error thrown by the async operation
  @discardableResult
  public mutating func measure<Result>(_ operation: @Sendable () async throws -> Result) async rethrows -> (Duration, Result) {
    let start = ContinuousClock.now
    let result = try await operation()
    let delta = ContinuousClock.now - start

    record(sample: delta)
    return (delta, result)
  }

  /// Comprehensive performance statistics computed from current samples.
  ///
  /// This property provides real-time performance analysis based on all
  /// samples in the current window. The statistics are computed on-demand
  /// using efficient algorithms to minimize overhead.
  ///
  /// ## Statistical Accuracy
  ///
  /// - **FPS calculations**: Computed as 1/duration for each metric
  /// - **Averages**: True arithmetic mean over the sample window
  /// - **Extrema**: Tracked incrementally for efficiency
  ///
  /// ## Empty Sample Handling
  ///
  /// When no samples are available, returns zero values for all metrics.
  /// This ensures the property is always safe to access without
  /// additional nil checking.
  ///
  /// ## Usage Examples
  /// ```swift
  /// let stats = profiler.statistics
  ///
  /// // Performance monitoring
  /// if stats.fps.current < targetFps * 0.8 {
  ///   print("Performance warning: FPS dropped to \(stats.fps.current)")
  /// }
  ///
  /// // Frame drop analysis
  /// let dropRate = Double(stats.frames.dropped) / Double(stats.frames.rendered)
  /// if dropRate > 0.05 {
  ///   print("High drop rate: \(dropRate * 100)% of frames dropped")
  /// }
  ///
  /// // Timing analysis
  /// print("Average frame time: \(stats.frametime.average)")
  /// ```
  public var statistics: FrameStatistics {
    guard !samples.isEmpty, let current = samples.last() else {
      return FrameStatistics(fps: (current: 0, average: 0, max: 0, min: 0),
                             frametime: (current: .zero, average: .zero),
                             frames: (rendered: 0, dropped: 0))
    }

    func fps(_ duration: Duration) -> Double {
      guard duration > .zero else { return 0 }
      return 1_000_000_000.0 / Double(duration.nanoseconds)
    }

    let total = samples.reduce(0) { $0 + $1.nanoseconds }
    let average = Duration.nanoseconds(total / Int64(samples.count))

    return FrameStatistics(fps: (current: fps(current),
                                 average: fps(average),
                                 max: fps(extrema.min),
                                 min: fps(extrema.max)),
                           frametime: (current: current, average: average),
                           frames: frames)
  }
}
