// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// A single character cell in the terminal buffer with associated styling.
///
/// Terminal cells are the fundamental building blocks of terminal content.
/// Each cell holds exactly one displayable character (which may be a
/// multi-byte Unicode character) along with its visual styling information.
///
/// For wide characters like emoji or CJK text that span multiple columns,
/// only the first cell contains the actual character - subsequent cells
/// use continuation markers (typically NUL characters).
public struct VTCell: Sendable, Equatable {
  /// The character displayed in this terminal cell.
  ///
  /// This can be any Unicode character, including emoji, accented characters,
  /// and CJK text. For wide characters that don't fit in a single column,
  /// continuation cells will contain NUL characters.
  public let character: Character

  /// The visual styling applied to this character.
  public let style: VTStyle

  /// Creates a terminal cell with a character and styling.
  ///
  /// This is the primary way to create styled terminal content. The character
  /// can be any valid Unicode character, and the style determines colors and
  /// text attributes.
  ///
  /// - Parameters:
  ///   - character: The character to display in this cell.
  ///   - style: The visual styling to apply.
  public init(character: Character, style: VTStyle) {
    self.character = character
    self.style = style
  }

  /// Creates a terminal cell from an ASCII byte value.
  ///
  /// This convenience initializer is useful when working with ASCII text
  /// or control characters where you have the raw byte value.
  ///
  /// - Parameters:
  ///   - ascii: The ASCII byte value (0-127) to convert to a character.
  ///   - style: The visual styling to apply.
  ///
  /// - Precondition: The ascii value must be a valid ASCII character (0-127).
  public init(ascii: UInt8, style: VTStyle) {
    self.character = Character(UnicodeScalar(ascii))
    self.style = style
  }
}

extension VTCell {
  /// A cell containing a space character with default styling.
  ///
  /// This is commonly used to represent empty or cleared areas of the
  /// terminal. It's more efficient than creating new space cells repeatedly
  /// since this is a static value that can be reused.
  public static var blank: VTCell {
    VTCell(character: " ", style: .default)
  }
}
