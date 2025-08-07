// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

#if os(Windows)
@preconcurrency
import WinSDK
#elseif os(macOS)
import Darwin
#else
import Glibc
#endif

#if os(Windows)
private typealias NativeLock = SRWLOCK
#elseif os(macOS)
private typealias NativeLock = os_unfair_lock_s
#else
private typealias NativeLock = pthread_mutex_t
#endif

/// A fast, platform-agnostic unfair lock.
///
/// This lock provides mutual exclusion with minimal overhead using
/// platform-specific unfair locking primitives. Being unfair means
/// threads may not acquire the lock in FIFO order, but this typically
/// provides better performance.
///
/// The lock is `~Copyable` to prevent accidental duplication which
/// could lead to synchronization issues.
public struct UnfairLock: ~Copyable, Sendable {
  private var storage: NativeLock = NativeLock()

  /// Creates a new lock.
  public init() {
    #if os(Windows)
    InitializeSRWLock(&storage)
    #elseif os(macOS)
    // os_unfair_lock_s is zero-initialized by default
    #else
    var attr = pthread_mutexattr_t()
    pthread_mutexattr_init(&attr)
    defer { pthread_mutexattr_destroy(&attr) }
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL)
    pthread_mutex_init(&storage, &attr)
    #endif
  }

  deinit {
    #if os(Windows)
    // SRW locks don't require explicit cleanup
    #elseif os(macOS)
    // os_unfair_lock doesn't require explicit cleanup
    #else
    pthread_mutex_destroy(&storage)
    #endif
  }

  /// Executes a closure while holding the lock.
  ///
  /// The lock is automatically acquired before executing the closure
  /// and released when the closure completes, even if an error is thrown.
  ///
  /// - Parameter body: The closure to execute while holding the lock.
  /// - Returns: The value returned by the closure.
  /// - Throws: Any error thrown by the closure.
  public mutating func withLock<T>(_ body: () throws -> T) rethrows -> T {
    #if os(Windows)
    AcquireSRWLockExclusive(&storage)
    defer { ReleaseSRWLockExclusive(&storage) }
    #elseif os(macOS)
    os_unfair_lock_lock(&storage)
    defer { os_unfair_lock_unlock(&storage) }
    #else
    pthread_mutex_lock(&storage)
    defer { pthread_mutex_unlock(&storage) }
    #endif

    return try body()
  }

  /// Attempts to acquire the lock without blocking.
  ///
  /// - Returns: `true` if the lock was successfully acquired, `false` otherwise.
  /// - Note: If this returns `true`, you must call `unlock()` to release the lock.
  public mutating func tryLock() -> Bool {
    #if os(Windows)
    return TryAcquireSRWLockExclusive(&storage) != 0
    #elseif os(macOS)
    return os_unfair_lock_trylock(&storage)
    #else
    return pthread_mutex_trylock(&storage) == 0
    #endif
  }

  /// Acquires the lock, blocking until it becomes available.
  ///
  /// - Warning: You must call `unlock()` to release the lock.
  ///   Prefer `withLock(_:)` for automatic lock management.
  public mutating func lock() {
    #if os(Windows)
    AcquireSRWLockExclusive(&storage)
    #elseif os(macOS)
    os_unfair_lock_lock(&storage)
    #else
    pthread_mutex_lock(&storage)
    #endif
  }

  /// Releases the lock.
  ///
  /// - Warning: This should only be called if you previously called `lock()` or
  ///   `tryLock()` returned `true`. Calling this without holding the lock
  ///   results in undefined behavior.
  public mutating func unlock() {
    #if os(Windows)
    ReleaseSRWLockExclusive(&storage)
    #elseif os(macOS)
    os_unfair_lock_unlock(&storage)
    #else
    pthread_mutex_unlock(&storage)
    #endif
  }

  /// Executes a closure while holding the lock, if the lock can be acquired immediately.
  ///
  /// This method attempts to acquire the lock without blocking. If successful,
  /// it executes the closure and releases the lock. If the lock cannot be
  /// acquired immediately, the closure is not executed.
  ///
  /// - Parameter body: The closure to execute if the lock is acquired.
  /// - Returns: The value returned by the closure, or `nil` if the lock could not be acquired.
  /// - Throws: Any error thrown by the closure.
  public mutating func withLockIfAvailable<T>(_ body: () throws -> T) rethrows -> T? {
    guard tryLock() else { return nil }
    defer { unlock() }
    return try body()
  }
}
