// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// A thread-safe atomic wrapper for value types.
///
/// This class provides atomic load and store operations for any value type,
/// using an unfair lock for synchronization. Being a class, it doesn't 
/// propagate `~Copyable` constraints to containing types.
///
/// Use this when you need simple atomic semantics for complex value types
/// that can't use hardware atomic operations.
public final class Atomic<T>: @unchecked Sendable {
  private var lock = UnfairLock()
  private var storage: T

  /// Creates a new atomic wrapper with the given initial value.
  ///
  /// - Parameter value: The initial value to store.
  public init(_ value: T) {
    self.storage = value
  }

  /// Atomically loads and returns the current value.
  ///
  /// - Returns: The current value.
  public func load() -> T {
    return lock.withLock { storage }
  }

  /// Atomically stores a new value.
  ///
  /// - Parameter newValue: The new value to store.
  public func store(_ newValue: T) {
    lock.withLock { storage = newValue }
  }

  /// Atomically exchanges the stored value with a new value.
  ///
  /// - Parameter newValue: The new value to store.
  /// - Returns: The previous value.
  public func exchange(_ newValue: T) -> T {
    return lock.withLock {
      let oldValue = storage
      storage = newValue
      return oldValue
    }
  }

  /// Atomically executes a closure with mutable access to the stored value.
  ///
  /// This is useful for atomic read-modify-write operations that are more
  /// complex than simple assignment.
  ///
  /// - Parameter body: A closure that receives mutable access to the stored value.
  /// - Returns: The value returned by the closure.
  /// - Throws: Any error thrown by the closure.
  public func withValue<R>(_ body: (inout T) throws -> R) rethrows -> R {
    return try lock.withLock { try body(&storage) }
  }

  /// Atomically executes a closure with read-only access to the stored value.
  ///
  /// Use this when you need to perform complex operations on the value
  /// without copying it (useful for large value types).
  ///
  /// - Parameter body: A closure that receives read-only access to the stored value.
  /// - Returns: The value returned by the closure.
  /// - Throws: Any error thrown by the closure.
  public func withValue<R>(_ body: (T) throws -> R) rethrows -> R {
    return try lock.withLock { try body(storage) }
  }
}

// MARK: - Convenience Extensions

extension Atomic where T: Equatable {
  /// Atomically compares the stored value with an expected value and,
  /// if they are equal, replaces the stored value with a new value.
  ///
  /// - Parameters:
  ///   - expected: The value to compare against.
  ///   - desired: The new value to store if comparison succeeds.
  /// - Returns: `true` if the exchange was successful, `false` otherwise.
  public func compareExchange(expected: T, desired: T) -> Bool {
    return lock.withLock {
      guard storage == expected else { return false }
      storage = desired
      return true
    }
  }
}

extension Atomic where T: AdditiveArithmetic {
  /// Atomically adds a value to the stored value.
  ///
  /// - Parameter value: The value to add.
  /// - Returns: The new value after addition.
  @discardableResult
  public func add(_ value: T) -> T {
    return lock.withLock {
      storage = storage + value
      return storage
    }
  }

  /// Atomically subtracts a value from the stored value.
  ///
  /// - Parameter value: The value to subtract.
  /// - Returns: The new value after subtraction.
  @discardableResult
  public func subtract(_ value: T) -> T {
    return lock.withLock {
      storage = storage - value
      return storage
    }
  }
}

extension Atomic where T: BinaryInteger {
  /// Atomically increments the stored value by 1.
  ///
  /// - Returns: The new value after incrementing.
  @discardableResult
  public func increment() -> T {
    return add(1)
  }

  /// Atomically decrements the stored value by 1.
  ///
  /// - Returns: The new value after decrementing.
  @discardableResult
  public func decrement() -> T {
    return subtract(1)
  }
}
