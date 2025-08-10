// Copyright © 2021 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// Encoding format for terminal control sequences.
///
/// Terminal control sequences can be encoded using either 7-bit or 8-bit
/// formats. Most modern terminals support both, but 7-bit encoding provides
/// better compatibility with older systems and network protocols.
public enum ControlSequenceEncoding: Sendable {
  /// 7-bit encoding using ESC sequences (more compatible).
  case b7
  /// 8-bit encoding using single control characters (more compact).
  case b8
}

/// C1 control characters as defined in ANSI X3.41-1974.
///
/// These control characters introduce different types of terminal control
/// sequences. CSI introduces most cursor and display commands, while OSC
/// introduces operating system specific commands.
public enum C1 {
  /// Control Sequence Introducer - starts most terminal control commands.
  case CSI
  /// Operating System Command - starts system-specific command sequences.
  case OSC
}

extension C1: CustomStringConvertible {
  @inlinable
  public var description: String {
    return switch self {
    case .CSI: self.encoded(as: .b7)
    case .OSC: self.encoded(as: .b7)
    }
  }
}

extension C1 {
  @inlinable
  public func encoded(as encoding: ControlSequenceEncoding) -> String {
    return switch (self, encoding) {
    case (.CSI, .b7):
      "\u{1b}\u{5b}"                                          // [
    case (.CSI, .b8):
      "\u{9b}"                                                // 
    case (.OSC, .b7):
      "\u{1b}\u{5d}"                                          // ]
    case (.OSC, .b8):
      "\u{9d}"                                                // 
    }
  }
}

/// Options for erasing portions of the terminal display.
///
/// These options control the direction and extent of erase operations,
/// allowing you to clear specific regions of the screen efficiently.
public enum ErasePage: Int, Sendable {
  /// Clear from cursor position to end of display.
  case ActivePositionToEnd = 0
  /// Clear from beginning of display to cursor position.
  case StartToActivePosition = 1
  /// Clear the entire display.
  case EntireDisplay = 2
  // case SavedLines = 3 (xterm only)
}

/// Options for erasing portions of the current line.
///
/// Line erase operations are commonly used for updating specific parts
/// of terminal output without affecting other content.
public enum EraseLine: Int, Sendable {
  /// Clear from cursor position to end of line.
  case ActivePositionToEnd = 0
  /// Clear from beginning of line to cursor position.
  case StartToActivePosition = 1
  /// Clear the entire current line.
  case EntireLine = 2
  // case SavedLines = 3 (xterm only)
}

/// Field-specific erase operations for form-based applications.
///
/// Similar to `EraseLine`, but operates on logical fields within forms
/// or structured text layouts. Fields represent logical units of data
/// input or display areas.
public enum EraseField: Int, Sendable {
  case ActivePositionToEnd = 0
  case StartToActivePosition = 1
  case EntireField = 2
}

/// Area-specific erase operations for complex layouts.
///
/// Operates on defined rectangular areas within the terminal display.
/// Useful for clearing specific regions without affecting surrounding
/// content in multi-panel or complex terminal applications.
public enum EraseArea: Int, Sendable {
  case ActivePositionToEnd = 0
  case StartToActivePosition = 1
  case EntireArea = 2
}

/// Defines the scope of editing operations.
///
/// Controls how editing commands (insert, delete, erase) affect the
/// terminal display. Different extents allow precise control over
/// which parts of the terminal are modified by editing operations.
public enum EditingExtent: Int, Sendable {
case ActivePage = 0
case ActiveLine = 1
case ActiveField = 2
case ActiveQualifiedArea = 3
case EntirePresentationArea = 4
}

/// Tab stop management for cursor positioning.
///
/// Controls horizontal and vertical tab stops that determine where
/// the cursor moves when tab characters are processed. Essential for
/// columnar text layout and form-based applications.
///
/// ## Usage Example
/// ```swift
/// // Set a tab stop at current column
/// await terminal <<< .HorizontalTabulationSet(.SetCharacterTabulationStop)
/// await terminal <<< "Column 1\tColumn 2\tColumn 3"  // Tabs to stops
/// ```
public enum CursorTabulationControl: Int, Sendable {
  case SetCharacterTabulationStop = 0
  case SetLineTabulationStop = 1
  case ClearCharacterTabulationStop = 2
  case ClearLineTabulationStop = 3
  case ClearCharacterTabulationStopsInLine = 4
  case ClearAllCharacterTabulationStops = 5
  case ClearAllLineTabulationStops = 6
}

/// Terminal device capability inquiry.
///
/// Used to request information about the terminal's capabilities and
/// features. The terminal responds with its supported features,
/// allowing applications to adapt their behavior accordingly.
public enum DeviceAttributes: Int, Sendable {
  case Request = 0
}

/// Tab stop clearing operations.
///
/// Provides precise control over which tab stops to clear. More
/// granular than `CursorTabulationControl`, allowing selective
/// removal of specific types of tab stops.
public enum ClearTabulation: Int, Sendable {
  case CharacterTabulationStopActivePosition = 0
  case LineTabulationStopActiveLine = 1
  case AllCharacterTabulationStopsActiveLine = 2
  case AllCharacterTabulationStops = 3
  case AllLineTabulationStops = 4
  case AllTabulationStops = 5
}

/// ANSI standard terminal modes.
///
/// Controls basic terminal behavior according to ANSI standards.
/// These modes affect fundamental terminal operations like error
/// handling and input processing.
public enum ANSIMode: Int, Sendable {
  case Error = 0                                              // Error
}

/// DEC private terminal modes.
///
/// Controls DEC-specific terminal features and behaviors. These modes
/// enable advanced functionality like alternate screen buffers,
/// synchronized updates, and cursor management that are commonly
/// used in modern terminal applications.
public enum DECMode: Int, Sendable {
  case ScrollingMode = 4                                      // DECSCLM (Scrolling Mode)
  case TextCursorEnableMode = 25                              // DECTCEM (Text Cursor Enable Mode)
  case UseAlternateScreenBuffer = 1047                        // xterm (Use Alternate Screen Buffer)
                                                              // DECGRPM (Graphics Rotated Print Mode)
  case SaveCursor = 1048                                      // xterm (Save Cursor Position)
                                                              // DECST8C (Set Tab at every 8 columns)
  case UseAlternateScreenBufferSaveCursor = 1049              // xterm (Use Alternate Screen Buffer and Save Cursor Position)
  case SynchronizedUpdate = 2026                              // DECSU (Synchronized Update)
}

/// Terminal mode configuration.
///
/// Combines ANSI standard modes and DEC private modes into a single
/// interface. Use this to enable or disable specific terminal
/// behaviors and features.
///
/// ## Usage Example
/// ```swift
/// // Enable alternate screen buffer (common for full-screen apps)
/// await terminal <<< .SetMode(.DEC(.UseAlternateScreenBuffer))
/// // ... application content ...
/// await terminal <<< .ResetMode(.DEC(.UseAlternateScreenBuffer))
/// ```
public enum Mode: Sendable {
  case ANSI(ANSIMode)                                         // SM, RM
  case DEC(DECMode)                                           // DECSET, DECRST
}

extension Mode: CustomStringConvertible {
  @inlinable
  public var description: String {
    return switch self {
    case .ANSI(let mode):
      String(mode.rawValue)
    case .DEC(let mode):
      "?\(mode.rawValue)"
    }
  }
}

/// Text styling and color attributes.
///
/// Controls the appearance of text in the terminal including colors,
/// bold, italic, underline, and other visual effects. Multiple
/// attributes can be combined to create rich text formatting.
///
/// ## Usage Examples
/// ```swift
/// // Basic text formatting
/// await terminal <<< .SelectGraphicRendition([.bold, .underline])
/// await terminal <<< "Important text"
/// await terminal <<< .SelectGraphicRendition([.reset])
///
/// // Color combinations
/// await terminal <<< .SelectGraphicRendition([
///   .foreground(.red), .background(.yellow), .bold
/// ])
/// await terminal <<< "Warning message"
/// await terminal <<< .SelectGraphicRendition([.reset])
/// ```
public enum GraphicRendition: Sendable {
  case Reset
  case Bold
  case Faint
  case Italic
  case Underline
  case SlowBlink
  case RapidBlink
  case Inverse
  case Conceal
  case CrossedOut
  case DoubleUnderline
  case Normal
  case ItalicOff
  case UnderlineOff
  case BlinkOff
  case InverseOff
  case Reveal
  case NotCrossedOut
  case Foreground(VTColor)
  case Background(VTColor)
}

extension GraphicRendition: CustomStringConvertible {
  @inlinable
  public var description: String {
    return switch self {
    case .Reset: "0"
    case .Bold: "1"
    case .Faint: "2"
    case .Italic: "3"
    case .Underline: "4"
    case .SlowBlink: "5"
    case .RapidBlink: "6"
    case .Inverse: "7"
    case .Conceal: "8"
    case .CrossedOut: "9"
    case .DoubleUnderline: "21"
    case .Normal: "22"
    case .ItalicOff: "23"
    case .UnderlineOff: "24"
    case .BlinkOff: "25"
    case .InverseOff: "27"
    case .Reveal: "28"
    case .NotCrossedOut: "29"
    case .Foreground(let color):
      switch color {
        case .ansi(let color, let intensity):
          switch (color, intensity) {
            case (.black, .normal): "30"
            case (.red, .normal): "31"
            case (.green, .normal): "32"
            case (.yellow, .normal): "33"
            case (.blue, .normal): "34"
            case (.magenta, .normal): "35"
            case (.cyan, .normal): "36"
            case (.white, .normal): "37"
            case (.default, .normal): "39"

            case (.black, .bright): "90"
            case (.red, .bright): "91"
            case (.green, .bright): "92"
            case (.yellow, .bright): "93"
            case (.blue, .bright): "94"
            case (.magenta, .bright): "95"
            case (.cyan, .bright): "96"
            case (.white, .bright): "97"
            case (.default, .bright): "99"
          }

        case .rgb(let red, let green, let blue):
          // 38;2;<r>;<g>;<b>
          "38;2;\(Int(red));\(Int(green));\(Int(blue))"
      }
    case .Background(let color):
      switch color {
        case .ansi(let color, let intensity):
          switch (color, intensity) {
            case (.black, .normal): "40"
            case (.red, .normal): "41"
            case (.green, .normal): "42"
            case (.yellow, .normal): "43"
            case (.blue, .normal): "44"
            case (.magenta, .normal): "45"
            case (.cyan, .normal): "46"
            case (.white, .normal): "47"
            case (.default, .normal): "49"

            case (.black, .bright): "100"
            case (.red, .bright): "101"
            case (.green, .bright): "102"
            case (.yellow, .bright): "103"
            case (.blue, .bright): "104"
            case (.magenta, .bright): "105"
            case (.cyan, .bright): "106"
            case (.white, .bright): "107"
            case (.default, .bright): "109"
          }

        case .rgb(let red, let green, let blue):
          // 48;2;<r>;<g>;<b>
          "48;2;\(Int(red));\(Int(green));\(Int(blue))"
      }
    }
  }
}

/// ISO 6429/ECMA-48 compliant terminal control sequences.
///
/// `ControlSequence` provides a comprehensive set of terminal control
/// commands that work across different terminal emulators and systems.
/// These sequences handle cursor movement, screen manipulation, text
/// formatting, and other terminal operations.
///
/// ## Usage Examples
///
/// ```swift
/// // Cursor positioning and movement
/// await terminal <<< .CursorPosition(10, 20)  // Move to row 10, column 20
/// await terminal <<< .CursorUp(5)             // Move up 5 rows
/// await terminal <<< .CursorForward(3)        // Move right 3 columns
///
/// // Screen manipulation
/// await terminal <<< .EraseDisplay(.EntireDisplay)  // Clear screen
/// await terminal <<< .EraseLine(.EntireLine)        // Clear current line
/// await terminal <<< .ScrollUp(2)                   // Scroll up 2 lines
///
/// // Text formatting
/// await terminal <<< .SelectGraphicRendition([.bold, .foreground(.red)])
/// await terminal <<< "Important message"
/// await terminal <<< .SelectGraphicRendition([.reset])
/// ```
///
/// ## Coordinate System
///
/// Terminal coordinates are 1-based, with (1,1) at the top-left corner.
/// This matches the traditional terminal and VT100 behavior.
public enum ControlSequence: Sendable {
  case InsertCharacter(Int = 1)                               // ICH
  case ShiftLeft(Int = 1)                                     // SL
  case CursorUp(Int = 1)                                      // CUU
  case ShiftRight(Int = 1)                                    // SR
  case CursorDown(Int = 1)                                    // CUD
  case CursorForward(Int = 1)                                 // CUF
  case CursorBackward(Int = 1)                                // CUB
  case CursorNextLine(Int = 1)                                // CNL
  case CursorPreviousLine(Int = 1)                            // CPL
  case CursorHorizontalAbsolute(Int = 1)                      // CHA
  case CursorPosition(Int = 1, Int = 1)                       // CUP
  case CursorHorizontalTabulation(Int = 1)                    // CHT
  case EraseDisplay(ErasePage = .ActivePositionToEnd)         // ED
  case EraseLine(EraseLine = .ActivePositionToEnd)            // EL
  case InsertLine(Int = 1)                                    // IL
  case DeleteLine(Int = 1)                                    // DL
  case EraseField(EraseField = .ActivePositionToEnd)          // EF
  case EraseArea(EraseArea = .ActivePositionToEnd)            // EA
  case DeleteCharacter(Int = 1)                               // DCH
  case SelectEditingExtent(EditingExtent = .ActivePage)       // SEE
  case CurrentPositionReport(Int = 1, Int = 1)                // CPR
  case ScrollUp(Int = 1)                                      // SU
  case ScrollDown(Int = 1)                                    // SD
  case NextPage(Int = 1)                                      // NP
  case PrecedingPage(Int = 1)                                 // PP
  case CursorTabulationControl(CursorTabulationControl = .SetCharacterTabulationStop)
                                                              // CTC
  case EraseCharacter(Int = 1)                                // ECH
  case CursorVerticalTabulation(Int = 1)                      // CVT
  case CursorBackwardTabulation(Int = 1)                      // CBT
  // SRS
  // PTX
  // SIMD
  // --
  case HorizontalPositionAbsolute(Int = 1)                    // HPA
  case HorizontalPositionRelative(Int = 1)                    // HPR
  case Repeat(Int = 1)                                        // REP
  case DeviceAttributes(DeviceAttributes = .Request)          // DA
  case VerticalPositionAbsolute(Int = 1)                      // VPA
  case VerticalPositionRelative(Int = 1)                      // VPR
  case HorizontalVerticalPosition(Int = 1, Int = 1)           // HVP
  case TabulationClear(ClearTabulation = .CharacterTabulationStopActivePosition)
                                                              // TBC
  case SetMode([Mode])                                        // SM
  // MC
  case HorizontalPositionBackwards(Int = 1)                   // HPB
  case VerticalPositionBackwards(Int = 1)                     // VPB
  case ResetMode([Mode])                                      // RM
  case SelectGraphicRendition([GraphicRendition])             // SGR
  // DSR
  // DAQ

  case FillRectangularArea(UInt8, Int = 1, Int = 1, Int = 1, Int = 1)
                                                              // DECFRA
}

extension ControlSequence: CustomStringConvertible {
  @inlinable
  public var description: String {
    self.encoded(as: .b7)
  }
}

@inlinable @inline(__always)
internal func CS(_ introducer: String, _ suffix: StaticString) -> String {
  return "\(introducer)\(suffix)"
}

@inlinable @inline(__always)
internal func CS<Pn: BinaryInteger>(_ introducer: String, _ pn: Pn, _ suffix: StaticString) -> String {
  return "\(introducer)\(pn)\(suffix)"
}

@inlinable @inline(__always)
internal func CS<Pm: BinaryInteger>(_ introducer: String, elided pm: Pm, _ suffix: StaticString) -> String {
  return "\(introducer);\(pm)\(suffix)"
}

@inlinable @inline(__always)
internal func CS<Pn: BinaryInteger, Pm: BinaryInteger>(_ introducer: String, _ pn: Pn, _ pm: Pm, _ suffix: StaticString) -> String {
  return "\(introducer)\(pn);\(pm)\(suffix)"
}

@inlinable @inline(__always)
internal func CS<Ps: Collection>(_ introducer: String, _ parameters: Ps, _ suffix: StaticString) -> String where Ps.Element: CustomStringConvertible {
  guard !parameters.isEmpty else { return "\(introducer)\(suffix)" }
  return "\(introducer)\(parameters.lazy.map(\.description).joined(separator: ";"))\(suffix)"
}

@inlinable @inline(__always)
internal func CS(_ introducer: String, _ Ps: Int..., intermediate: StaticString, _ suffix: StaticString) -> String {
  return "\(introducer)\(Ps.lazy.map(\.description).joined(separator: ";"))\(intermediate)\(suffix)"
}

extension ControlSequence {
  @inlinable
  public func encoded(as encoding: ControlSequenceEncoding) -> String {
    let I = C1.CSI.encoded(as: encoding)

    return switch self {
    case .InsertCharacter(1):
      CS(I, "@")
    case .InsertCharacter(let count):
      CS(I, count, "@")

    case .ShiftLeft(1):
      CS(I, " @")
    case .ShiftLeft(let count):
      CS(I, count, " @")

    case .CursorUp(1):
      CS(I, "A")
    case .CursorUp(let distance):
      CS(I, distance, "A")

    case .ShiftRight(1):
      CS(I, " A")
    case .ShiftRight(let distance):
      CS(I, distance, " A")

    case .CursorDown(1):
      CS(I, "B")
    case .CursorDown(let distance):
      CS(I, distance, "B")

    case .CursorForward(1):
      CS(I, "C")
    case .CursorForward(let distance):
      CS(I, distance, "C")

    case .CursorBackward(1):
      CS(I, "D")
    case .CursorBackward(let distance):
      CS(I, distance, "D")

    case .CursorNextLine(1):
      CS(I, "E")
    case .CursorNextLine(let lines):
      CS(I, lines, "E")

    case .CursorPreviousLine(1):
      CS(I, "F")
    case .CursorPreviousLine(let lines):
      CS(I, lines, "F")

    case .CursorHorizontalAbsolute(1):
      CS(I, "G")
    case .CursorHorizontalAbsolute(let column):
      CS(I, column, "G")

    case .CursorPosition(1, 1):
      CS(I, "H")
    case .CursorPosition(let row, 1):
      CS(I, row, "H")
    case .CursorPosition(1, let column):
      CS(I, elided: column, "H")
    case .CursorPosition(let row, let column):
      CS(I, row, column, "H")

    case .CursorHorizontalTabulation(1):
      CS(I, "I")
    case .CursorHorizontalTabulation(let count):
      CS(I, count, "I")

    case .EraseDisplay(.ActivePositionToEnd):
      CS(I, "J")
    case .EraseDisplay(let page):
      CS(I, page.rawValue, "J")

    case .EraseLine(.ActivePositionToEnd):
      CS(I, "K")
    case .EraseLine(let line):
      CS(I, line.rawValue, "K")

    case .InsertLine(1):
      CS(I, "L")
    case .InsertLine(let count):
      CS(I, count, "L")

    case .DeleteLine(1):
      CS(I, "M")
    case .DeleteLine(let count):
      CS(I, count, "M")

    case .EraseField(.ActivePositionToEnd):
      CS(I, "N")
    case .EraseField(let field):
      CS(I, field.rawValue, "N")

    case .EraseArea(.ActivePositionToEnd):
      CS(I, "O")
    case .EraseArea(let area):
      CS(I, area.rawValue, "O")

    case .DeleteCharacter(1):
      CS(I, "P")
    case .DeleteCharacter(let count):
      CS(I, count, "P")

    case .SelectEditingExtent(.ActivePage):
      CS(I, "Q")
    case .SelectEditingExtent(let extent):
      CS(I, extent.rawValue, "Q")

    case .CurrentPositionReport(1, 1):
      CS(I, "R")
    case .CurrentPositionReport(let row, let column):
      preconditionFailure("CPR(\(row), \(column)) is a response, not a request")

    case .ScrollUp(1):
      CS(I, "S")
    case .ScrollUp(let count):
      CS(I, count, "S")

    case .ScrollDown(1):
      CS(I, "T")
    case .ScrollDown(let count):
      CS(I, count, "T")

    case .NextPage(1):
      CS(I, "U")
    case .NextPage(let count):
      CS(I, count, "U")

    case .PrecedingPage(1):
      CS(I, "V")
    case .PrecedingPage(let count):
      CS(I, count, "V")

    case .CursorTabulationControl(.SetCharacterTabulationStop):
      CS(I, "W")
    case .CursorTabulationControl(let control):
      CS(I, control.rawValue, "W")

    case .EraseCharacter(1):
      CS(I, "X")
    case .EraseCharacter(let count):
      CS(I, count, "X")

    case .CursorVerticalTabulation(1):
      CS(I, "Y")
    case .CursorVerticalTabulation(let count):
      CS(I, count, "Y")

    case .CursorBackwardTabulation(1):
      CS(I, "Z")
    case .CursorBackwardTabulation(let count):
      CS(I, count, "Z")

    case .HorizontalPositionAbsolute(1):
      CS(I, "`")
    case .HorizontalPositionAbsolute(let column):
      CS(I, column, "`")

    case .HorizontalPositionRelative(1):
      CS(I, "a")
    case .HorizontalPositionRelative(let count):
      CS(I, count, "a")

    case .Repeat(1):
      CS(I, "b")
    case .Repeat(let count):
      CS(I, count, "b")

    case .DeviceAttributes(.Request):
      CS(I, "c")
    case .DeviceAttributes(let attributes):
      preconditionFailure("DA(\(attributes)) is a response, not a request")

    case .VerticalPositionAbsolute(1):
      CS(I, "d")
    case .VerticalPositionAbsolute(let row):
      CS(I, row, "d")

    case .VerticalPositionRelative(1):
      CS(I, "e")
    case .VerticalPositionRelative(let count):
      CS(I, count, "e")

    case .HorizontalVerticalPosition(1, 1):
      CS(I, "f")
    case .HorizontalVerticalPosition(let row, 1):
      CS(I, row, "f")
    case .HorizontalVerticalPosition(1, let column):
      CS(I, elided: column, "f")
    case .HorizontalVerticalPosition(let row, let column):
      CS(I, row, column, "f")

    case .TabulationClear(.CharacterTabulationStopActivePosition):
      CS(I, "g")
    case .TabulationClear(let tabulation):
      CS(I, tabulation.rawValue, "g")

    case .SetMode(let modes):
      CS(I, modes, "h")

    case .HorizontalPositionBackwards(1):
      CS(I, "j")
    case .HorizontalPositionBackwards(let count):
      CS(I, count, "j")

    case .VerticalPositionBackwards(1):
      CS(I, "k")
    case .VerticalPositionBackwards(let count):
      CS(I, count, "k")

    case .ResetMode(let modes):
      CS(I, modes, "l")

    case .SelectGraphicRendition(let renditions):
      CS(I, renditions, "m")

    case .FillRectangularArea(let character, let top, let left, let bottom, let right)
        where (32 ... 126).contains(character) || (160 ... 225).contains(character):
      CS(I, Int(character), top, left, bottom, right, intermediate: "$", "x")

    case .FillRectangularArea(let character, let top, let left, let bottom, let right):
      preconditionFailure("DECFRA(\(character), \(top), \(left), \(bottom), \(right)) is not supported for character outside of printable range")
    }
  }
}
