// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

@frozen
public struct Point {
  public let x: Int
  public let y: Int

  public init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }
}

extension Point: AdditiveArithmetic {
  public static var zero: Point {
    Point(x: 0, y: 0)
  }

  public static func + (_ lhs: Point, _ rhs: Point) -> Point {
    Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
  }

  public static func - (_ lhs: Point, _ rhs: Point) -> Point {
    Point(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }
}

extension Point: Codable { }

extension Point: CustomStringConvertible {
  public var description: String {
    "(\(x), \(y))"
  }
}

extension Point: Equatable { }

extension Point: Hashable { }

extension Point: Sendable { }

extension Point {
  public static func * (_ point: Point, _ scalar: Int) -> Point {
    Point(x: point.x * scalar, y: point.y * scalar)
  }
}

extension Point {
  public static func / (_ point: Point, _ scalar: Int) -> Point {
    return Point(x: point.x / scalar, y: point.y / scalar)
  }
}

extension Point {
  public func distance(to point: Point) -> Double {
    let dx = self.x - point.x
    let dy = self.y - point.y
    return Double(dx * dx + dy * dy).squareRoot()
  }
}

extension Point {
  public var magnitude: Double {
    distance(to: .zero)
  }
}

extension Point {
  public func midpoint(to point: Point) -> Point {
    return Point(x: (self.x + point.x) / 2, y: (self.y + point.y) / 2)
  }
}
