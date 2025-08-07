// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

@frozen
public struct Size {
  public let width: Int
  public let height: Int

  public init(width: Int, height: Int) {
    self.width = width
    self.height = height
  }
}

extension Size: AdditiveArithmetic {
  public static var zero: Size {
    Size(width: 0, height: 0)
  }

  public static func + (_ lhs: Size, _ rhs: Size) -> Size {
    Size(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
  }

  public static func - (_ lhs: Size, _ rhs: Size) -> Size {
    Size(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
  }
}

extension Size: Codable { }

extension Size: CustomStringConvertible {
  public var description: String {
    "\(width) × \(height)"
  }
}

extension Size: Equatable { }

extension Size: Hashable { }

extension Size: Sendable { }

extension Size {
  public static func * (_ size: Size, _ scalar: Int) -> Size {
    Size(width: size.width * scalar, height: size.height * scalar)
  }
}

extension Size {
  public static func / (_ size: Size, _ scalar: Int) -> Size {
    return Size(width: size.width / scalar, height: size.height / scalar)
  }
}

extension Size {
  public var area: Int {
    width * height
  }
}

extension Size {
  public var aspectRatio: Double {
    guard height != 0 else { return 0.0 }
    return Double(width) / Double(height)
  }
}

extension Size {
  public var isEmpty: Bool {
    width <= 0 || height <= 0
  }
}
