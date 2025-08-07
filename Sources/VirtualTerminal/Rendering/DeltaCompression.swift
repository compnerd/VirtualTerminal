// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// Represents a contiguous range of changed cells with consistent styling.
///
/// `DamageSpan` is the fundamental unit of delta compression in the terminal
/// rendering system. Each span identifies a continuous region of the terminal
/// buffer that has changed and shares the same text styling, allowing for
/// efficient batch updates to the terminal.
///
/// ## Memory Efficiency
///
/// By grouping consecutive cells with identical styling, damage spans
/// reduce the number of style change operations sent to the terminal,
/// which improves both performance and reduces output size.
package struct DamageSpan: Sendable {
  /// The range of buffer indices affected by this damage span.
  ///
  /// This range identifies the contiguous sequence of cells in the terminal
  /// buffer that have changed. The range uses linear buffer indices, where
  /// position `row * width + column` maps to the buffer index.
  package let range: Range<Int>

  /// The consistent text style applied to all cells in this span.
  ///
  /// All cells within the damage span share this same style, which allows
  /// the renderer to apply the style once and then output all the character
  /// data without additional style changes.
  package let style: VTStyle

  internal init(range: Range<Int>, style: VTStyle) {
    self.range = range
    self.style = style
  }
}

private func split(span: Range<Int>, from buffer: borrowing VTBuffer, into damages: inout [DamageSpan]) {
  guard !span.isEmpty else { return }

  var start = span.lowerBound
  var current = buffer.buffer[span.lowerBound].style

  for offset in span.dropFirst() {
    let style = buffer.buffer[offset].style
    if style == current { continue }
    damages.append(DamageSpan(range: start ..< offset, style: current))
    start = offset
    current = style
  }

  damages.append(DamageSpan(range: start ..< span.upperBound, style: current))
}

/// Computes the minimal set of changes between two terminal buffers.
///
/// This function performs delta compression by comparing two `VTBuffer`
/// instances and identifying only the regions that have actually changed.
/// The result is an optimized list of damage spans that represent the
/// minimal updates needed to transform the current buffer to the updated state.
///
/// ## Delta Compression Benefits
///
/// Instead of redrawing the entire terminal screen, delta compression:
/// - Reduces terminal output by only updating changed regions
/// - Minimizes bandwidth usage for remote terminal sessions
/// - Decreases rendering latency by avoiding unnecessary updates
/// - Preserves terminal scrollback by not clearing unchanged regions
///
/// ## Parameters
/// - current: The baseline buffer state (what's currently displayed)
/// - updated: The target buffer state (what should be displayed)
///
/// ## Returns
/// An array of `DamageSpan` objects representing the minimal changes needed.
/// Returns a single full-screen span if the buffer sizes differ.
///
/// ## Usage Example
/// ```swift
/// let currentBuffer = VTBuffer(size: Size(width: 80, height: 24))
/// let updatedBuffer = currentBuffer.copy()
///
/// // Make some changes to updatedBuffer
/// updatedBuffer.setCursor(position: VTPosition(row: 5, column: 10))
/// updatedBuffer.write("Hello, World!")
///
/// let changes = damages(from: currentBuffer, to: updatedBuffer)
/// for span in changes {
///   // Only update the changed regions
///   await renderSpan(span, in: updatedBuffer)
/// }
/// ```
///
/// ## Algorithm Behavior
///
/// The function scans through both buffers simultaneously, identifying
/// contiguous regions of change. When style boundaries are encountered
/// within a changed region, the span is automatically split to maintain
/// the invariant that each damage span has consistent styling.
///
/// ## Performance Characteristics
///
/// The algorithm runs in O(n) time where n is the buffer size, making
/// it efficient enough for real-time terminal applications running at
/// high frame rates.
package func damages(from current: borrowing VTBuffer, to updated: borrowing VTBuffer) -> [DamageSpan] {
  guard updated.size == current.size else {
    // Full screen damage if the size has changed.
    return [DamageSpan(range: 0 ..< updated.buffer.count, style: .default)]
  }

  var start: ContiguousArray<VTCell>.Index?
  var damages: [DamageSpan] = []
  for index in updated.buffer.indices {
    switch (start, current.buffer[index] == updated.buffer[index]) {
    case let (.some(position), true):
      // If the current cell is unchanged and we have a start position,
      // end the current damage span.
      split(span: position ..< index, from: updated, into: &damages)
      start = nil
    case (.none, false):
      // If the current cell is changed and we don't have a start position,
      // start a new damage span.
      start = index
    default:
      continue
    }
  }

  // Handle the final damage span if it exists.
  if let position = start {
    split(span: position ..< updated.buffer.endIndex, from: updated, into: &damages)
  }

  return damages
}
