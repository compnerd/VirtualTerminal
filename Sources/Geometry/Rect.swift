// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

@frozen
public struct Rect {
  public let origin: Point
  public let size: Size

  public init(origin: Point, size: Size) {
    self.origin = origin
    self.size = size
  }
}

extension Rect: AdditiveArithmetic {
  public static var zero: Rect {
    Rect(origin: .zero, size: .zero)
  }

  public static func + (_ lhs: Rect, _ rhs: Rect) -> Rect {
    Rect(origin: lhs.origin + rhs.origin, size: lhs.size + rhs.size)
  }

  public static func - (_ lhs: Rect, _ rhs: Rect) -> Rect {
    Rect(origin: lhs.origin - rhs.origin, size: lhs.size - rhs.size)
  }
}

extension Rect: Codable { }

extension Rect: CustomStringConvertible {
  public var description: String {
    "{\(origin), \(size)}"
  }
}

extension Rect: Equatable { }

extension Rect: Hashable { }

extension Rect: Sendable { }

extension Rect {
  public var isEmpty: Bool {
    size.width <= 0 || size.height <= 0
  }
}

extension Rect {
  public var center: Point {
    Point(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
  }
}

extension Rect {
  public func contains(_ point: Point) -> Bool {
    return point.x >= origin.x && point.x < (origin.x + size.width) &&
           point.y >= origin.y && point.y < (origin.y + size.height)
  }

  public func contains(_ rect: Rect) -> Bool {
    return rect.origin.x >= origin.x &&
           (rect.origin.x + rect.size.width) <= (origin.x + size.width) &&
           rect.origin.y >= origin.y &&
           (rect.origin.y + rect.size.height) <= (origin.y + size.height)
  }
}

extension Rect {
  public func intersects(_ rect: Rect) -> Bool {
    return (origin.x + size.width) > rect.origin.x &&
           origin.x < (rect.origin.x + rect.size.width) &&
           (origin.y + size.height) > rect.origin.y &&
           origin.y < (rect.origin.y + rect.size.height)
  }
}

extension Rect {
  public func union(_ rect: Rect) -> Rect {
    let x = (min: min(origin.x, rect.origin.x), 
             max: max(origin.x + size.width, rect.origin.x + rect.size.width))
    let y = (min: min(origin.y, rect.origin.y),
             max: max(origin.y + size.height, rect.origin.y + rect.size.height))

    return Rect(origin: Point(x: x.min, y: y.min),
                size: Size(width: x.max - x.min, height: y.max - y.min))
  }
}

extension Rect {
  public func intersection(with rect: Rect) -> Rect? {
    let x = (min: max(origin.x, rect.origin.x),
             max: min(origin.x + size.width, rect.origin.x + rect.size.width))
    let y = (min: max(origin.y, rect.origin.y),
             max: min(origin.y + size.height, rect.origin.y + rect.size.height))

    guard x.min < x.max, y.min < y.max else { return nil }
    return Rect(origin: Point(x: x.min, y: y.min),
                size: Size(width: x.max - x.min, height: y.max - y.min))
  }
}

extension Rect {
  public func offset(by point: Point) -> Rect {
    return Rect(origin: origin + point, size: size)
  }
}
