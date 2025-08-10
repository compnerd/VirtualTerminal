// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// Standard ANSI color identifiers supported by most terminals.
///
/// These colors correspond to the traditional 8-color ANSI palette that
/// has been supported since early terminal systems. The actual appearance
/// of these colors depends on the terminal's color scheme and user
/// customization.
public enum ANSIColor: Int, Equatable, Sendable {
  case black
  case red
  case green
  case yellow
  case blue
  case magenta
  case cyan
  case white
  /// Uses the terminal's configured default color.
  case `default` = 9
}

/// Intensity variations for ANSI colors.
///
/// Most terminals support both normal and bright variants of the standard
/// ANSI colors, effectively providing a 16-color palette. Bright colors
/// are often rendered with higher luminosity or as completely different
/// hues depending on the terminal's color scheme.
public enum ANSIColorIntensity: Equatable, Sendable {
  /// Standard color intensity.
  case normal
  /// Bright or bold color intensity.
  case bright
}

/// Terminal color representation supporting both ANSI and RGB color spaces.
///
/// `VTColor` provides a unified interface for terminal colors while
/// maintaining optimal compatibility. ANSI colors work with all terminals
/// and respect user theming, while RGB colors provide precise control
/// for modern terminal emulators.
///
/// ## Color Space Comparison
///
/// - **ANSI**: Universal compatibility, user-customizable, accessibility-
///   friendly
/// - **RGB**: Precise colors, consistent across terminals, larger palette
///
/// ## Usage Examples
///
/// ```swift
/// // ANSI colors (recommended for most use cases)
/// let warning = VTColor.yellow
/// let error = VTColor.red
/// let normal = VTColor.default
///
/// // RGB colors for precise branding
/// let blue = VTColor.rgb(red: 0, green: 123, blue: 255)
/// let green = VTColor.rgb(red: 40, green: 167, blue: 69)
/// ```
public enum VTColor: Equatable, Hashable, Sendable {
  /// A 24-bit RGB color with precise component control.
  case rgb(red: UInt8, green: UInt8, blue: UInt8)
  /// An ANSI color that adapts to terminal themes and settings.
  case ansi(_ color: ANSIColor, intensity: ANSIColorIntensity = .normal)
}

extension VTColor {
  /// The terminal's default color, respecting user customization.
  public static var `default`: VTColor {
    .ansi(.default)
  }

  public static var black: VTColor {
    .ansi(.black)
  }

  public static var red: VTColor {
    .ansi(.red)
  }

  public static var green: VTColor {
    .ansi(.green)
  }

  public static var yellow: VTColor {
    .ansi(.yellow)
  }

  public static var blue: VTColor {
    .ansi(.blue)
  }

  public static var magenta: VTColor {
    .ansi(.magenta)
  }

  public static var cyan: VTColor {
    .ansi(.cyan)
  }

  public static var white: VTColor {
    .ansi(.white)
  }
}
