// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// Cursor motion optimization extension for `VTBuffer`.
///
/// This extension provides intelligent cursor positioning that minimizes
/// the number of bytes sent to the terminal by choosing the most efficient
/// movement strategy from multiple alternatives.
extension VTBuffer {
  /// Generates the most efficient cursor movement sequence between two positions.
  ///
  /// This method analyzes multiple cursor movement strategies and selects
  /// the one that requires the fewest bytes when encoded. This optimization
  /// is particularly important for terminal applications that frequently
  /// reposition the cursor, as it can significantly reduce bandwidth usage
  /// and improve rendering performance.
  ///
  /// ## Movement Strategies
  ///
  /// The optimizer considers several approaches:
  /// - **Absolute positioning**: Direct jump to target coordinates
  /// - **Line-based movement**: Efficient moves to column 1 of different rows
  /// - **Horizontal-only**: Optimized left/right movement on the same row
  /// - **Relative movement**: Combination of vertical and horizontal steps
  ///
  /// ## Parameters
  /// - source: Current cursor position
  /// - target: Desired cursor position
  ///
  /// ## Returns
  /// An array of control sequences representing the optimal movement path.
  /// Returns an empty array if source and target positions are identical.
  ///
  /// ## Usage Example
  /// ```swift
  /// let buffer = VTBuffer(size: Size(width: 80, height: 24))
  /// let currentPos = VTPosition(row: 5, column: 10)
  /// let targetPos = VTPosition(row: 8, column: 1)
  ///
  /// let movements = buffer.reposition(from: currentPos, to: targetPos)
  /// for sequence in movements {
  ///   await terminal.write(sequence.description)
  /// }
  /// ```
  ///
  /// ## Performance Benefits
  ///
  /// This optimization reduces the number of bytes transmitted to the terminal
  /// by selecting the most compact cursor movement strategy available. The
  /// byte savings are particularly noticeable in applications that frequently
  /// reposition the cursor, such as when rendering forms, menus, or other
  /// structured layouts.
  ///
  /// ## Implementation Notes
  ///
  /// All strategies are evaluated and the shortest encoded representation
  /// is selected. This ensures optimal performance across different terminal
  /// types and cursor movement patterns.
  package func reposition(from source: VTPosition, to target: VTPosition)
      -> [ControlSequence] {
    // If the source and target are the same, no motion is needed.
    if source == target { return [] }

    let ΔRow = target.row - source.row
    let ΔColumn = target.column - source.column

    // Generate all possible movement strategies
    var strategies: [[ControlSequence]] = []

    // Strategy 1: Absolute positioning
    strategies.append([.CursorPosition(target.row, target.column)])

    // Strategy 2: Line-based movement to column 1 (when applicable)
    if ΔRow > 0 && target.column == 1 {
      strategies.append([.CursorNextLine(ΔRow)])
    } else if ΔRow < 0 && target.column == 1 {
      strategies.append([.CursorPreviousLine(-ΔRow)])
    }

    // Strategy 3: Horizontal-only movements (when applicable)
    if ΔRow == 0 && ΔColumn > 0 {
      strategies.append([.CursorHorizontalAbsolute(target.column)])
      strategies.append([.CursorForward(ΔColumn)])
    } else if ΔRow == 0 && ΔColumn < 0 {
      strategies.append([.CursorHorizontalAbsolute(target.column)])
      strategies.append([.CursorBackward(-ΔColumn)])
    }

    // Strategy 4: Relative movement (vertical + horizontal)
    var motions: [ControlSequence] = []

    if ΔRow > 0 {
      motions.append(.CursorDown(ΔRow))
    } else if ΔRow < 0 {
      motions.append(.CursorUp(-ΔRow))
    }

    if ΔColumn > 0 {
      motions.append(.CursorForward(ΔColumn))
    } else if ΔColumn < 0 {
      motions.append(.CursorBackward(-ΔColumn))
    }

    if motions.count > 0 { strategies.append(motions) }

    // Return the strategy with the minimum total character count
    return strategies.min { lhs, rhs in
      lhs.reduce(0) { $0 + $1.encoded(as: .b7).count } < rhs.reduce(0) { $0 + $1.encoded(as: .b7).count }
    } ?? [.CursorPosition(target.row, target.column)]
  }
}
