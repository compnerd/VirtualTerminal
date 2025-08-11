// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

#if !os(Windows)

import POSIXCore

/// A type that provides asynchronous signal handling on POSIX systems.
///
/// `SignalHandler` allows you to register async handlers for POSIX signals,
/// providing a Swift-friendly interface to traditional C signal handling.
/// Multiple handlers can be registered for the same signal, and they will
/// execute concurrently when the signal is received.
///
/// ## Usage
///
/// ```swift
/// // Register a handler for SIGINT
/// let token = try await SignalHandler.install(SIGINT) { signal in
///     print("Received SIGINT (\(signal))")
/// }
///
/// // The handler remains active until the token is deallocated or removed
/// ```
public struct SignalHandler {
  /// A token that represents an active signal handler registration.
  ///
  /// The handler remains active as long as this token exists. When the token
  /// is deallocated or explicitly removed, the handler is unregistered.
  /// If this is the last handler for a signal, the original signal
  /// disposition is restored.
  ///
  /// - Important: On macOS versions prior to 26, manual removal requires
  ///   `Task.immediate` availability. The token will trigger a
  ///   precondition failure if automatic cleanup occurs on unsupported
  ///   versions.
  public struct RemovalToken: ~Copyable, Sendable {
    private let termination: @Sendable () async -> Void

    internal init(_ termination: @escaping @Sendable () async -> Void) {
      self.termination = termination
    }

    deinit {
      guard #available(macOS 26, *) else {
        preconditionFailure("Task.immediate is not available; cannot remove signal handler")
      }

      Task<Void, Never>.immediate { [termination] in
        await termination()
      }
    }

    /// Explicitly removes the signal handler.
    ///
    /// Call this method to immediately unregister the handler instead of
    /// waiting for the token to be deallocated. After calling this method,
    /// the token becomes invalid and should not be used further.
    ///
    /// - Important: Requires `Task.immediate` availability (macOS 26+).
    public consuming func remove() {
      guard #available(macOS 26, *) else {
        preconditionFailure("Task.immediate is not available; cannot remove signal handler")
      }

      Task<Void, Never>.immediate { [termination] in
        await termination()
      }
    }
  }

  /// Installs an asynchronous handler for the specified signal.
  ///
  /// Registers a handler that will be called asynchronously when the
  /// specified signal is received. Multiple handlers can be registered
  /// for the same signal, and they will execute concurrently.
  ///
  /// The handler runs in an async context and can perform any async
  /// operations. However, be mindful of performance as signal handling
  /// should typically be fast.
  ///
  /// - Parameters:
  ///   - signal: The POSIX signal number to handle (e.g., `SIGINT`,
  ///     `SIGTERM`).
  ///   - handler: An async closure that receives the signal number and
  ///     performs the handling logic.
  /// - Returns: A `RemovalToken` that represents the active handler.
  ///   Keep this token alive to maintain the handler registration.
  /// - Throws: `POSIXError` if signal installation fails.
  public static func install(_ signal: CInt,
                             _ handler: @escaping @Sendable (CInt) async -> Void) async throws
      -> RemovalToken {
    return try await Registry.shared.register(signal: signal, handler: handler)
  }
}

private final actor Registry {
  static let shared = Registry()

  private final class Handler: Sendable {
    package let implementation: @Sendable (CInt) async -> Void

    package init(callback: @escaping @Sendable (CInt) async -> Void) {
      self.implementation = callback
    }

    public func callAsFunction(_ signal: CInt) async {
      await implementation(signal)
    }
  }

  private var handlers: [CInt:[ObjectIdentifier:Handler]] = [:]
  private var dispositions: [CInt:sigaction] = [:]
#if $InlineArray
  private nonisolated(unsafe) static var fds = InlineArray<2, CInt>(repeating: -1)
#else
  private nonisolated(unsafe) static var fds = Array<CInt>(repeating: -1, count: 2)
#endif
  private var monitor: Task<Void, Never>?

  private init() { }

  deinit {
    // Cancel monitoring task.
    if let monitor = self.monitor {
      Task.detached { monitor.cancel() }
    }

    // Close channel.
    if Registry.fds[0] != -1 {
      _ = close(Registry.fds[0])
    }

    if Registry.fds[1] != -1 {
      _ = close(Registry.fds[1])
    }
  }

  private func start() throws {
    guard monitor == nil else { return }

    // TODO(compnerd): use `signalfd` on Linux
    guard pipe(&Registry.fds) == 0 else { throw POSIXError() }

    // Make the write non-blocking for the handler
    let flags = fcntl(Registry.fds[1], F_GETFL)
    guard flags >= 0, fcntl(Registry.fds[1], F_SETFL, flags | O_NONBLOCK) == 0 else {
      throw POSIXError()
    }

    monitor = Task { [weak self] in
      var buffer = Array<UInt8>(repeating: 0, count: 32)
      while !Task.isCancelled {
        guard let self else { return }

        let count = read(Registry.fds[0], &buffer, buffer.count)
        guard count > 0 else {
          if errno == EINTR { continue }
          fatalError("read failure from signal pipe: \(POSIXError())")
        }

        for signal in buffer[..<count].lazy.map(CInt.init) {
          await self.handle(signal)
        }
      }
    }
  }

  private func stop() {
    let monitor = self.monitor
    self.monitor = nil

    // Cancel monitoring task.
    if let monitor {
      Task.detached { monitor.cancel() }
    }

    // Close channel.
    if Registry.fds[0] != -1 {
      _ = close(Registry.fds[0])
      Registry.fds[0] = -1
    }

    if Registry.fds[1] != -1 {
      _ = close(Registry.fds[1])
      Registry.fds[1] = -1
    }
  }

  /// Installs a new signal handler and sets up the signal if needed.
  public func register(signal: CInt, handler: @escaping @Sendable (CInt) async -> Void) throws
      -> SignalHandler.RemovalToken {
    let handler = Handler(callback: handler)
    let id = ObjectIdentifier(handler)

    // Setup notifier if this is the first handler
    try start()

    // Install signal handler if this is first handler for this signal
    if handlers[signal, default: [:]].isEmpty {
      try listen(for: signal)
    }

    handlers[signal, default: [:]][id] = handler

    return SignalHandler.RemovalToken { [weak self] in
      await self?.unregister(signal: signal, id: id)
    }
  }

  /// Removes a specific handler and restores original signal disposition if
  /// no handlers remain.
  private func unregister(signal: CInt, id: ObjectIdentifier) {
    handlers[signal]?[id] = nil
    if handlers[signal, default: [:]].isEmpty {
      if var disposition = dispositions.removeValue(forKey: signal) {
        // Ignore errors - there is not much that can be done in the cleanup.
        _ = sigaction(signal, &disposition, nil)
      }
      handlers.removeValue(forKey: signal)
    }

    if handlers.isEmpty {
      stop()
    }
  }

  /// Installs the C signal handler for the specified signal.
  private func listen(for signal: CInt) throws {
    guard dispositions[signal] == nil else { return }

    // Save the original signal action
    var disposition = sigaction()
    guard sigaction(signal, nil, &disposition) == 0 else { throw POSIXError() }
    dispositions[signal] = disposition

    // Install minimal signal handler
    var action = sigaction()
    let handler: @convention(c) (CInt) -> Void = { signal in
      // Ignore errors - there is not much that can be done safely in the
      // signal context.
      var signal = UInt8(signal)
      _ = write(Registry.fds[1], &signal, 1)
    }
    #if os(Linux)
    action.sa_handler = handler
    #else
    action.__sigaction_u.__sa_handler = handler
    #endif
    guard sigemptyset(&action.sa_mask) == 0 else { throw POSIXError() }
    action.sa_flags = SA_RESTART

    guard sigaction(signal, &action, nil) == 0 else { throw POSIXError() }
  }

  private func handle(_ signal: CInt) async {
    let handlers = self.handlers[signal, default: [:]].values
    switch handlers.count {
    case 0: return
    case 1:
      guard let handler = handlers.first else { return }
      await handler(signal)
    default:
      await withTaskGroup(of: Void.self) { group in
        for handler in handlers {
          group.addTask {
            await handler(signal)
          }
        }
      }
    }
  }
}

#endif
