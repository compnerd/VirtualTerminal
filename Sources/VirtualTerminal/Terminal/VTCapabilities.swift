// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// Terminal types for VT100-style devices.
///
/// These represent the basic terminal hardware identification returned by
/// legacy VT100 and compatible terminals.
public enum VTTerminalType: UInt8, Sendable {
  case vt100 = 1
  case vt101 = 2
  case vt132 = 4
  case vt131 = 5
  case vt102 = 6
  case vt125 = 12
}

/// Service class options for VT100-style terminals.
///
/// These values indicate which hardware options are installed in the
/// terminal, such as graphics processors or printer interfaces.
public enum VTServiceClass: UInt8, Sendable {
  case base = 0         // No Options
  case stp = 1          // Processor Option (STP)
  case avo = 2          // Advanced Video Option (AVO)
  case avo_stp = 3      // AVO + STP
  case gpo = 4          // Graphics Processor Option (GPO)
  case gpo_stp = 5      // GPO + STP
  case gpo_avo = 6      // GPO + AVO
  case gpo_avo_stp = 7  // GPO + AVO + STP
}

/// Terminal families for VT220+ style devices.
///
/// These represent the terminal family identification for newer terminals
/// that support extended feature reporting.
public enum VTTerminalFamily: UInt8, Sendable {
  case vt220 = 62
  case vt240 = 18
  case vt320 = 63
  case vt330 = 19
  case vt340 = 24
  case vt420 = 64
  case vt510 = 65
  case vt525 = 28
}

/// Individual terminal features that can be reported via Device Attributes.
///
/// These features correspond to capabilities that VT220+ terminals can
/// report through the Device Attributes response. Each feature represents
/// a specific terminal capability or character set support.
public enum VTDAFeature: UInt8, Sendable {
  case ExtendedColumns = 1  // 132 columns
  case PrinterPort = 2
  case ReGISGraphics = 3
  case SixelGraphics = 4
  case Katakana = 5
  case SelectiveErase = 6
  case SoftCharacterSet = 7
  case UserDefinedKeys = 8
  case NationalReplacementCharacterSet = 9
  case Kanji = 10
  case StatusDisplay = 11
  case Yugoslavian = 12
  case BlockMode = 13
  case EightBitInterfaceArchitecture = 14
  case TechnicalCharacterSet = 15
  case LocatorPort = 16
  case TerminalStateInterrogation = 17
  case WindowingCapability = 18
  case PrintExtent = 19
  case APL = 20
  case HorizontalScrolling = 21
  case ANSIColor = 22
  case Greek = 23
  case Turkish = 24
  case ArabicBilingualMode1 = 25
  case ArabicBilingualMode2 = 26
  case ArabicBilingualMode3 = 27
  case RectangularAreaOperations = 28
  case ANSITextLocator = 29
  case Hanzi = 30
  case TextMacros = 32
  case HangulHanza = 33
  case Icelandic = 34
  case ArabicBilingualTextControls = 35
  case ArabicBilingualNoTextControls = 36
  case Thai = 37
  case CharacterOutlining = 38
  case PageMemoryExtension = 39
  case ISOLatin2 = 42
  case Ruler = 43
  case PCTerm = 44
  case SoftKeyMapping = 45
  case ASCIIEmulation = 46
  case ClipboardAccess = 52
}

/// A set of terminal feature extensions.
///
/// This type uses a bitmask to efficiently store which terminal features
/// are supported. You can check for specific features using the
/// ``contains(_:)`` method.
///
/// ## Usage
///
/// ```swift
/// let extensions = VTExtensions()
/// if extensions.contains(.ANSIColor) {
///   // Terminal supports ANSI colors
/// }
/// ```
public struct VTExtensions: Sendable, OptionSet {
  public typealias RawValue = UInt64

  public let rawValue: RawValue

  public init(rawValue: RawValue) {
    self.rawValue = rawValue
  }

  internal init(_ parameter: VTDAFeature) {
    precondition(parameter.rawValue < 64,
                 "VTExtensions can only support up to 64 features")
    self.init(rawValue: 1 << parameter.rawValue)
  }

  /// Checks if a specific terminal feature is supported.
  ///
  /// - Parameter feature: The feature to check for support
  /// - Returns: `true` if the feature is supported, `false` otherwise
  public func contains(_ feature: VTDAFeature) -> Bool {
    precondition(feature.rawValue < 64,
                 "VTExtensions can only support up to 64 features")
    return rawValue & (1 << feature.rawValue) == 0 ? false : true
  }
}

extension VTExtensions {
  /// No terminal extensions are supported.
  public static var none: VTExtensions {
    VTExtensions(rawValue: 0)
  }
}

/// Terminal identity information returned by Device Attributes queries.
///
/// Terminals can identify themselves in two different ways:
/// - **Specific**: Legacy VT100-style terminals report a specific type
///   and service class
/// - **Compatible**: Modern VT220+ terminals report a family and list
///   of supported features
public enum VTTerminalIdentity: Sendable {
  case specific(VTTerminalType, VTServiceClass)
  case compatible(VTTerminalFamily, VTExtensions)
}

/// Terminal capability information.
///
/// This structure contains information about what a terminal can do,
/// including supported features and terminal identification. Use the
/// ``query(_:timeout:)`` method to detect capabilities from a live terminal.
///
/// ## Usage
///
/// ```swift
/// let capabilities = await VTCapabilities.query(terminal)
/// if capabilities.supports(.ANSIColor) {
///   // Use ANSI color codes
/// }
/// if capabilities.supports(.SixelGraphics) {
///   // Terminal can display sixel graphics
/// }
/// ```
public struct VTCapabilities: Sendable {
  public let identity: VTTerminalIdentity

  /// The set of supported terminal features.
  ///
  /// For legacy terminals that report specific types, this will be empty.
  /// For modern terminals, this contains the reported feature set.
  public var features: VTExtensions {
    return switch identity {
      case .specific(_, _):
        .none
      case let .compatible(_, features):
        features
    }
  }

  /// Checks if the terminal supports a specific feature.
  ///
  /// - Parameter feature: The feature to check for support
  /// - Returns: `true` if the feature is supported, `false` otherwise
  public func supports(_ feature: VTDAFeature) -> Bool {
    return features.contains(feature)
  }
}

extension VTCapabilities {
  /// Queries a terminal for its capabilities.
  ///
  /// This method sends a Device Attributes (DA1) query to the terminal and
  /// waits for the response. It handles both legacy VT100-style responses
  /// and modern VT220+ feature lists.
  ///
  /// The query will timeout if the terminal doesn't respond within the
  /// specified duration, returning ``unknown`` capabilities as a fallback.
  ///
  /// - Parameters:
  ///   - terminal: The terminal to query for capabilities
  ///   - timeout: Maximum time to wait for a response
  /// - Returns: The detected terminal capabilities
  ///
  /// ## Usage
  ///
  /// ```swift
  /// let capabilities = await VTCapabilities.query(terminal)
  /// print("Terminal supports ANSI color: \(capabilities.supports(.ANSIColor))")
  /// ```
  public static func query(_ terminal: some VTTerminal,
                           timeout: Duration = .milliseconds(250)) async
      -> VTCapabilities {
    async let capabilities = try? Task<VTCapabilities, Error>.withTimeout(timeout: timeout) {
      for try await event in terminal.input {
        guard case let .response(response) = event else { continue }

        switch response {
        case let .primary(parameters):
          // The general format of DA1 response is:
          //   \u{1b}[<Pt>;<Ps>c
          // Primary Device Attributes (DA1) has two distinct formats that
          // we must handle though.

          // VT100-style: \u{1b}[<terminal-type>;<service-class>c
          if parameters.count == 2,
              let type = parameters.first,
              let type = UInt8(exactly: type),
              let type = VTTerminalType(rawValue: type),
              let service = parameters.last,
              let service = UInt8(exactly: service),
              let service = VTServiceClass(rawValue: service) {
            return VTCapabilities(identity: .specific(type, service))
          }

          // VT220+style: \u{1b}[<terminal-type>;<extensions>c
          if let family = parameters.first,
              let family = UInt8(exactly: family),
              let family = VTTerminalFamily(rawValue: family) {
            let features = parameters.dropFirst()
              .compactMap(UInt8.init(exactly:))
              .compactMap(VTDAFeature.init(rawValue:))
              .compactMap(VTExtensions.init)
              .reduce(into: VTExtensions()) { $0.formUnion($1) }
            return VTCapabilities(identity: .compatible(family, features))
          }

        case .secondary(_), .tertiary(_):
          break
        }
      }

      return .unknown
    }

    await terminal <<< .DeviceAttributes(.Request)
    return await capabilities ?? .unknown
  }
}

extension VTCapabilities {
  /// Default capabilities for unknown or unresponsive terminals.
  ///
  /// This represents minimal VT101 compatibility with no extended features,
  /// suitable as a safe fallback when terminal detection fails.
  public static var unknown: VTCapabilities {
    VTCapabilities(identity: .specific(.vt101, .base))
  }
}
