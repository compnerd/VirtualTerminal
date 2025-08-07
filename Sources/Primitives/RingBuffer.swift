// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// A high-performance ring buffer implementation using safe Swift types
/// with optimal memory layout and minimal overhead.
package struct RingBuffer<Element> {
  private var storage: ContiguousArray<Element?>
  // Points to first valid element (oldest)
  private var head: ContiguousArray<Element?>.Index = 0
  // Points to next insertion position
  private var tail: ContiguousArray<Element?>.Index = 0
  private var size: Int = 0

  /// The maximum number of elements this buffer can hold
  public let capacity: Int

  /// Creates a new ring buffer with the specified capacity.
  /// - Parameter capacity: The maximum number of elements the buffer can hold
  package init(capacity: Int) {
    precondition(capacity > 0, "Capacity must be positive")
    self.capacity = capacity
    // Pre-allocate storage to full capacity with nil values
    self.storage = ContiguousArray(repeating: nil, count: capacity)
  }

  /// The number of elements currently in the buffer
  @inline(__always)
  package var count: Int { size }

  /// Returns true if the buffer contains no elements
  @inline(__always)
  package var isEmpty: Bool { count == 0 }

  /// Returns true if the buffer is at maximum capacity
  @inline(__always)
  package var isFull: Bool { count == capacity }

  /// Pushes an element to the buffer, potentially overwriting the oldest element if full
  package mutating func push(_ element: Element) {
    if isFull {
      storage[head] = nil
      head = _index(after: head)
    } else {
      size += 1
    }
    
    storage[tail] = element
    tail = _index(after: tail)
  }

  /// Returns the oldest element without removing it
  package borrowing func peek() -> Element? {
    guard !isEmpty else { return nil }
    return storage[head]
  }

  /// Removes and returns the oldest element if available
  package mutating func pop() -> Element? {
    guard !isEmpty else { return nil }
    defer {
      storage[head] = nil
      head = _index(after: head)
      size -= 1
    }
    return storage[head]
  }
}

// MARK: - Private Helpers

extension RingBuffer {
  @inline(__always)
  private func _index(after index: ContiguousArray<Element?>.Index)
      -> ContiguousArray<Element?>.Index {
    (index + 1) % capacity
  }

  @inline(__always)
  private func _index(before index: ContiguousArray<Element?>.Index)
      -> ContiguousArray<Element?>.Index {
    (index - 1 + capacity) % capacity
  }
}

// MARK: - Collection Conformance

extension RingBuffer: Collection {
  package typealias Index = Int

  package var startIndex: Index { 0 }
  package var endIndex: Index { count }

  package borrowing func index(after i: Index) -> Index {
    precondition(i < count, "Index out of bounds")
    return i + 1
  }

  package subscript(position: Index) -> Element {
    @inline(__always)
    _read {
      precondition(position >= 0 && position < count, "Index out of bounds")
      let offset = (head + position) % capacity
      guard let element = storage[offset] else {
        fatalError("Ring buffer invariant violated: found nil at valid position \(position)")
      }
      yield element
    }

    @inline(__always)
    _modify {
      precondition(position >= 0 && position < count, "Index out of bounds")
      let offset = (head + position) % capacity
      guard var element = storage[offset] else {
        fatalError("Ring buffer invariant violated: found nil at valid position \(position)")
      }
      yield &element
      storage[offset] = element
    }
  }
}

// MARK: - Sequence Conformance for Enhanced Performance

extension RingBuffer: Sequence {
  package struct Iterator: IteratorProtocol {
    private let buffer: RingBuffer<Element>
    private var currentIndex: Int = 0
    
    internal init(_ buffer: RingBuffer<Element>) {
      self.buffer = buffer
    }
    
    package mutating func next() -> Element? {
      guard currentIndex < buffer.count else { return nil }
      let element = buffer[currentIndex]
      currentIndex += 1
      return element
    }
  }
  
  package func makeIterator() -> Iterator {
    Iterator(self)
  }
}

// MARK: - Additional Access Methods

extension RingBuffer {
  /// Returns the most recently added element without removing it
  package borrowing func last() -> Element? {
    guard !isEmpty else { return nil }
    let lastIndex = _index(before: tail)
    return storage[lastIndex]
  }

  /// Removes and returns the newest element if available  
  package mutating func popLast() -> Element? {
    guard !isEmpty else { return nil }
    tail = _index(before: tail)
    defer {
      storage[tail] = nil
      size -= 1
    }
    return storage[tail]
  }

  /// Removes all elements from the buffer
  package mutating func removeAll() {
    // Clear all elements efficiently
    for i in 0..<capacity {
      storage[i] = nil
    }
    head = 0
    tail = 0
    size = 0
  }

  /// Removes all elements and keeps storage capacity
  package mutating func removeAll(keepingCapacity: Bool) {
    if keepingCapacity {
      removeAll()
    } else {
      storage = ContiguousArray(repeating: nil, count: capacity)
      head = 0
      tail = 0
      size = 0
    }
  }
}

// MARK: - Functional Access Methods

extension RingBuffer {
  /// Executes a closure with efficient access to all elements, handling wraparound
  package borrowing func forEach(_ body: (borrowing Element) throws -> Void) rethrows {
    for index in 0 ..< count {
      try body(self[index])
    }
  }

  /// Efficiently maps over all elements maintaining order
  package borrowing func map<U>(_ transform: (borrowing Element) throws -> U) rethrows -> [U] {
    var result: [U] = []
    result.reserveCapacity(count)
    
    try forEach { element in
      result.append(try transform(element))
    }
    
    return result
  }

  /// Efficiently reduces all elements
  package borrowing func reduce<Result>(
    _ initialResult: Result,
    _ nextPartialResult: (Result, borrowing Element) throws -> Result
  ) rethrows -> Result {
    var result = initialResult
    try forEach { element in
      result = try nextPartialResult(result, element)
    }
    return result
  }
}
