// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// Text formatting attributes that can be combined for rich terminal styling.
///
/// Use these attributes to make text bold, italic, underlined, or apply other
/// visual effects. Multiple attributes can be combined using set operations:
///
/// ```swift
/// let emphasis: VTAttributes = [.bold, .italic]
/// let decorated: VTAttributes = [.underline, .strikethrough]
/// ```
public struct VTAttributes: OptionSet, Sendable, Equatable {
  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }
}

extension VTAttributes {
  /// Makes text appear in bold or increased intensity.
  public static var bold: VTAttributes {
    VTAttributes(rawValue: 1 << 1)
  }

  /// Renders text in italic or oblique style.
  public static var italic: VTAttributes {
    VTAttributes(rawValue: 1 << 2)
  }

  /// Adds an underline beneath the text.
  public static var underline: VTAttributes {
    VTAttributes(rawValue: 1 << 3)
  }

  /// Draws a line through the text (crossed out).
  public static var strikethrough: VTAttributes {
    VTAttributes(rawValue: 1 << 5)
  }

  /// Makes text blink or flash intermittently.
  ///
  /// Note that blink support varies by terminal and may be disabled in
  /// some environments for accessibility reasons.
  public static var blink: VTAttributes {
    VTAttributes(rawValue: 1 << 4)
  }
}

private func pack(_ color: VTColor) -> UInt64 {
  return switch color {
  case let .rgb(red, green, blue):
    // [23-16: red][15-8: green][7-0: blue]
    (UInt64(red) << 16) | (UInt64(green) << 8) | (UInt64(blue) << 0)
  case let .ansi(color):
    // [23-9: reserved][8: intensity][7-0: color]
    (UInt64(color.intensity == .bright ? 1 : 0) << 8) | (UInt64(color.color.rawValue) & 0xff)
  }
}

private struct Flags: OptionSet {
  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }
}

extension Flags {
  public static var ANSIForeground: Flags {
    Flags(rawValue: 1 << 0)
  }

  public static var RGBForeground: Flags {
    Flags(rawValue: 1 << 1)
  }

  public static var ANSIBackground: Flags {
    Flags(rawValue: 1 << 2)
  }

  public static var RGBBackground: Flags {
    Flags(rawValue: 1 << 3)
  }
}

/// Defines the complete visual appearance of terminal text.
///
/// A style combines foreground color, background color, and text attributes
/// into a single value. Styles are efficiently packed into a single 64-bit
/// integer for optimal memory usage and comparison performance.
///
/// ## Usage Examples
///
/// ```swift
/// // Basic colored text
/// let red = VTStyle(foreground: .ansi(.init(color: .red, intensity: .bright)))
///
/// // Styled text with multiple attributes
/// let heading = VTStyle(foreground: .rgb(red: 255, green: 255, blue: 255),
///                       background: .ansi(.init(color: .blue, intensity: .normal)),
///                       attributes: [.bold, .underline])
///
/// // Use default system colors with formatting
/// let emphasis = VTStyle(attributes: [.italic])
/// ```
public struct VTStyle: Sendable, Equatable {
  // [63-40: background][39-16: foreground][15-8: attributes][7-0: flags]
  private let representation: UInt64

  /// Creates a new text style with the specified visual properties.
  ///
  /// All parameters are optional, allowing you to specify only the styling
  /// you need. Omitted colors will use the terminal's default colors.
  ///
  /// - Parameters:
  ///   - foreground: The text color, or `nil` for terminal default.
  ///   - background: The background color, or `nil` for terminal default.
  ///   - attributes: Text formatting attributes to apply.
  public init(foreground: VTColor? = nil, background: VTColor? = nil, attributes: VTAttributes = []) {
    var representation = (UInt64(attributes.rawValue) << 8)

    if let foreground {
      switch foreground {
      case .ansi(_):
        representation |= (pack(foreground) << 16) | UInt64(Flags.ANSIForeground.rawValue)
      case .rgb(_, _, _):
        representation |= (pack(foreground) << 16) | UInt64(Flags.RGBForeground.rawValue)
      }
    }

    if let background {
      switch background {
      case .ansi(_):
        representation |= (pack(background) << 40) | UInt64(Flags.ANSIBackground.rawValue)
      case .rgb(_, _, _):
        representation |= (pack(background) << 40) | UInt64(Flags.RGBBackground.rawValue)
      }
    }

    self.representation = representation
  }

  /// The foreground (text) color, or `nil` if using terminal default.
  public var foreground: VTColor? {
    let flags = Flags(rawValue: UInt8(representation & 0xff))

    if flags.contains(.ANSIForeground) {
      let bits = representation >> 16
      guard let color = ANSIColorIdentifier(rawValue: (Int(bits) & 0xff)) else {
        return nil
      }
      let intensity = (bits >> 8) & 1 == 1 ? ANSIColorIntensity.bright
                                           : ANSIColorIntensity.normal
      return .ansi(ANSIColor(color: color, intensity: intensity))
    }

    if flags.contains(.RGBForeground) {
      // [15-8: red][7-0: green][0-0: blue]
      let bits = representation >> 16
      let red = UInt8((bits >> 0x10) & 0xff)
      let green = UInt8((bits >> 0x08) & 0xff)
      let blue = UInt8((bits >> 0x00) & 0xff)
      return .rgb(red: red, green: green, blue: blue)
    }

    return nil
  }

  /// The background color, or `nil` if using terminal default.
  public var background: VTColor? {
    let flags = Flags(rawValue: UInt8(representation & 0xff))

    if flags.contains(.ANSIBackground) {
      let bits = representation >> 40
      guard let color = ANSIColorIdentifier(rawValue: (Int(bits) & 0xff)) else {
        return nil
      }
      let intensity = (bits >> 8) & 1 == 1 ? ANSIColorIntensity.bright
                                            : ANSIColorIntensity.normal
      return .ansi(ANSIColor(color: color, intensity: intensity))
    }

    if flags.contains(.RGBBackground) {
      let bits = representation >> 40
      let red = UInt8((bits >> 0x10) & 0xff)
      let green = UInt8((bits >> 0x08) & 0xff)
      let blue = UInt8((bits >> 0x00) & 0xff)
      return .rgb(red: red, green: green, blue: blue)
    }

    return nil
  }

  /// The set of text formatting attributes applied to this style.
  public var attributes: VTAttributes {
    return VTAttributes(rawValue: UInt8((representation >> 8) & 0xff))
  }
}

extension VTStyle {
  internal func with(foreground: VTColor?) -> VTStyle {
    VTStyle(foreground: foreground, background: background, attributes: attributes)
  }

  internal func with(background: VTColor?) -> VTStyle {
    VTStyle(foreground: foreground, background: background, attributes: attributes)
  }

  internal func with(attributes: VTAttributes) -> VTStyle {
    VTStyle(foreground: foreground, background: background, attributes: attributes)
  }
}

extension VTStyle {
  /// A style with no formatting that uses terminal default colors.
  ///
  /// This is equivalent to creating `VTStyle()` with no parameters, but
  /// provides better semantic clarity when resetting text to unstyled
  /// appearance.
  public static var `default`: VTStyle {
    VTStyle(foreground: nil, background: nil, attributes: [])
  }
}
