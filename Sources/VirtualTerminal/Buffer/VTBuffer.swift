// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Geometry

/// A high-performance terminal buffer that manages a 2D grid of terminal cells.
///
/// `VTBuffer` provides efficient storage and manipulation of terminal content
/// using a contiguous array for optimal cache performance. It supports Unicode
/// characters with proper width handling for CJK text, emoji, and other wide
/// characters.
///
/// The buffer uses `~Copyable` semantics to ensure efficient memory usage and
/// prevent accidental expensive copies during rendering operations.
public struct VTBuffer: ~Copyable, Sendable {
  /// The dimensions of the terminal buffer in columns and rows.
  public let size: Size

  /// Internal storage for terminal cells in row-major order.
  package private(set) var buffer: ContiguousArray<VTCell>

  /// Creates a new terminal buffer with the specified dimensions.
  ///
  /// The buffer is initialized with blank cells using the default style.
  ///
  /// - Parameter size: The width and height of the buffer in character cells.
  public init(size: Size) {
    self.size = size
    self.buffer =
        ContiguousArray(repeating: .blank, count: size.width * size.height)
  }
}

extension VTBuffer {
  public typealias Index = ContiguousArray<VTCell>.Index
  public typealias Element = VTCell

  /// Accesses the terminal cell at the specified position.
  ///
  /// If the position is outside the buffer bounds, reading returns a blank
  /// cell and writing operations are ignored. This provides safe access
  /// without runtime crashes for out-of-bounds coordinates.
  ///
  /// - Parameter position: The 1-based row and column position in the buffer.
  /// - Returns: The terminal cell at the specified position, or a blank cell
  ///   if out of bounds.
  public subscript(position: VTPosition) -> Element {
    _read {
      guard position.valid(in: size) else {
        yield VTCell.blank
        return
      }
      yield buffer[position.offset(in: size)]
    }
    _modify {
      guard position.valid(in: size) else {
        var blank = VTCell.blank
        yield &blank
        return
      }
      yield &buffer[position.offset(in: size)]
    }
  }
}

extension VTBuffer {
  /// Converts a linear buffer offset to a terminal position.
  ///
  /// This method is used internally for converting between the buffer's
  /// linear storage and 2D terminal coordinates.
  ///
  /// - Parameter offset: The linear offset into the buffer array.
  /// - Returns: The corresponding 1-based terminal position.
  package func position(at offset: ContiguousArray<VTCell>.Index) -> VTPosition {
    let offset = max(0, min(offset, buffer.count - 1))
    return VTPosition(row: 1 + (offset / size.width),
                      column: 1 + (offset % size.width))
  }
}

extension VTBuffer {
  /// Writes a string to the buffer starting at the specified position.
  ///
  /// This method handles various control characters and Unicode text:
  /// - `\n`: Moves to the same column on the next row
  /// - `\r`: Moves to the beginning of the current row
  /// - `\t`: Moves to the next tab stop (every 8 characters)
  /// - Wide characters: Automatically handles CJK text and emoji with
  ///   continuation cells
  ///
  /// Text that extends beyond the buffer boundaries is clipped. Wide
  /// characters that don't fit at the end of a line are moved to the next
  /// line.
  ///
  /// - Parameters:
  ///   - text: The string to write to the buffer.
  ///   - position: The starting position for writing (1-based coordinates).
  ///   - style: The visual style to apply to the text. Defaults to `.default`.
  public mutating func write(string text: String, at position: VTPosition,
                             style: VTStyle = .default) {
    // Validate position is within buffer bounds
    guard position.valid(in: size) else { return }

    var cursor = position.offset(in: size)
    for character in text {
      switch character {
      case "\n":
        cursor = min(size.height - 1, (cursor / size.width) + 1) * size.width
               + (cursor % size.width)
      case "\r":
        cursor = (cursor / size.width) * size.width
      case "\t":
        // Move to the next tab stop, which is every 8 characters.
        cursor = cursor - (cursor % size.width)
               + min(size.width - 1, (((cursor % size.width) / 8) + 1) * 8)
      default:
        guard cursor < buffer.count else { return }
        let width = character.width

        // Check if wide character fits in current row
        if (cursor % size.width) + width > size.width {
          // Wide character doesn't fit, move to next line
          cursor = ((cursor / size.width) + 1) * size.width
          guard cursor < buffer.count else { return }
        }

        // Check if entire character (including continuation) fits in buffer
        guard cursor + width < buffer.count else { return }

        buffer[cursor] = VTCell(character: character, style: style)
        for offset in 1 ..< width {
          // Mark continuation cells with the NUL character
          buffer[cursor + offset] = VTCell(character: "\u{0000}", style: style)
        }
        cursor = cursor + width
      }
    }
  }

  /// Clears the entire buffer by filling it with space characters.
  ///
  /// This operation resets all cells in the buffer to contain a space
  /// character with the specified style, effectively clearing any existing
  /// content.
  ///
  /// - Parameter style: The style to apply to the cleared cells. Defaults
  ///   to `.default`.
  public mutating func clear(style: VTStyle = .default) {
    for index in buffer.indices {
      buffer[index] = VTCell(character: " ", style: style)
    }
  }

  /// Fills a rectangular region of the buffer with a specific character.
  ///
  /// This method efficiently fills a rectangular area with the same character
  /// and style. It handles wide characters correctly by placing continuation
  /// cells as needed. The rectangle is automatically clipped to the buffer
  /// boundaries.
  ///
  /// - Parameters:
  ///   - rect: The rectangular region to fill (0-based coordinates).
  ///   - character: The character to fill the region with.
  ///   - style: The visual style to apply. Defaults to `.default`.
  public mutating func fill(rect: Rect, with character: Character,
                            style: VTStyle = .default) {
    guard !rect.isEmpty else { return }

    let fill = VTCell(character: character, style: style)
    let continuation = VTCell(character: "\u{0000}", style: style)
    let width = character.width

    // Clamp rectangle bounds to valid buffer coordinates
    let rows = (start: max(0, rect.origin.y),
                end: min(rect.origin.y + rect.size.height, size.height))
    let columns = (start: max(0, rect.origin.x),
                   end: min(rect.origin.x + rect.size.width, size.width))

    // Early exit if clipped rectangle is empty
    guard rows.start < rows.end && columns.start < columns.end else { return }

    if width == 1 {
      // Fast path for single-width characters
      for row in rows.start ..< rows.end {
        for column in columns.start ..< columns.end {
          buffer[row * size.width + column] = fill
        }
      }
    } else {
      // Wide character path
      for row in rows.start ..< rows.end {
        for column in stride(from: columns.start, to: columns.end, by: width) {
          buffer[row * size.width + column] = fill
          // Fill continuation cells for wide characters
          for offset in 1 ..< min(width, columns.end - column) {
            let index = row * size.width + column + offset
            if index >= buffer.count { break }
            buffer[index] = continuation
          }
        }
      }
    }
  }
}
