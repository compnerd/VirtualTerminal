// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Geometry

/// Represents a position in terminal coordinate space using 1-based indexing.
///
/// Terminal positions follow the traditional terminal convention where the
/// top-left corner is at row 1, column 1 (not 0, 0 as in many programming
/// contexts). This matches VT100 terminal behavior and ANSI escape sequence
/// expectations.
@frozen
public struct VTPosition: Sendable, Equatable {
  /// The row coordinate, with 1 representing the topmost row.
  public let row: Int

  /// The column coordinate, with 1 representing the leftmost column.
  public let column: Int

  /// Creates a terminal position with explicit row and column coordinates.
  ///
  /// - Parameters:
  ///   - row: The 1-based row coordinate (vertical position).
  ///   - column: The 1-based column coordinate (horizontal position).
  public init(row: Int, column: Int) {
    self.row = row
    self.column = column
  }

  /// Converts a geometric point to terminal coordinates.
  ///
  /// This convenience initializer translates from 0-based geometric
  /// coordinates to 1-based terminal coordinates by adding 1 to both x and y
  /// components.
  ///
  /// - Parameter point: A geometric point with 0-based coordinates.
  public init(point: Point) {
    self.row = Int(point.y) + 1
    self.column = Int(point.x) + 1
  }
}

extension VTPosition {
  /// Tests whether this position lies within the bounds of a terminal buffer.
  ///
  /// Terminal positions are valid when both coordinates fall within the
  /// 1-based ranges: row ∈ [1, height] and column ∈ [1, width].
  ///
  /// - Parameter size: The dimensions of the terminal buffer to test against.
  /// - Returns: `true` if the position is within bounds, `false` otherwise.
  @inlinable
  internal func valid(in size: Size) -> Bool {
    return 1 ... size.height ~= row && 1 ... size.width ~= column
  }

  /// Converts this 1-based position to a linear buffer offset.
  ///
  /// Terminal buffers store cells in row-major order as a flat array. This
  /// method transforms 2D terminal coordinates into the corresponding 1D
  /// array index, accounting for the coordinate system difference (1-based
  /// vs 0-based).
  ///
  /// - Parameter size: The buffer dimensions used for offset calculation.
  /// - Returns: The zero-based linear offset into the buffer array.
  ///
  /// - Precondition: The position must be valid within the given size.
  @inlinable
  internal func offset(in size: Size) -> Int {
    assert(valid(in: size), "Invalid position '\(self)' for size '\(size)'")
    return (row - 1) &* size.width &+ (column - 1)
  }
}

extension VTPosition {
  /// The origin position at the top-left corner of the terminal.
  ///
  /// This represents the traditional terminal origin point at row 1, column 1,
  /// following VT100 conventions. Use this instead of creating
  /// `VTPosition(row: 1, column: 1)` for better semantic clarity and
  /// consistency.
  public static var zero: VTPosition {
    VTPosition(row: 1, column: 1)
  }
}
