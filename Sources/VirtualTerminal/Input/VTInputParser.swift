// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// Standard virtual key codes for terminal input.
///
/// `VTKeyCode` provides constants for common virtual key codes used in
/// terminal applications. These codes represent special keys that don't
/// generate printable characters, such as arrow keys, function keys,
/// and control keys.
///
/// The key codes follow standard virtual key conventions and can be used
/// to identify specific key presses in `KeyEvent` objects.
///
/// ## Usage Example
/// ```swift
/// func handleKeyEvent(_ event: KeyEvent) {
///   switch event.keycode {
///   case VTKeyCode.escape:
///     exitApplication()
///   case VTKeyCode.F1:
///     showHelp()
///   case VTKeyCode.up:
///     moveCursorUp()
///   default:
///     if let char = event.character {
///       insertText(char)
///     }
///   }
/// }
/// ```
public enum VTKeyCode {
  public static var escape: UInt16 { 0x1b }
  public static var left: UInt16 { 0x25 }
  public static var up: UInt16 { 0x26 }
  public static var right : UInt16 { 0x27 }
  public static var down: UInt16 { 0x28 }
  public static var F1: UInt16 { 0x70 }
  public static var F2: UInt16 { 0x71 }
  public static var F3: UInt16 { 0x72 }
  public static var F4: UInt16 { 0x73 }
  public static var F5: UInt16 { 0x74 }
  public static var F6: UInt16 { 0x75 }
  public static var F7: UInt16 { 0x76 }
  public static var F8: UInt16 { 0x77 }
  public static var F9: UInt16 { 0x78 }
  public static var F10: UInt16 { 0x79 }
  public static var F11: UInt16 { 0x7a }
  public static var F12: UInt16 { 0x7b }
  public static var F13: UInt16 { 0x7c }
  public static var F14: UInt16 { 0x7d }
}

/// Cursor movement directions for terminal input parsing.
///
/// Used internally by the input parser to represent directional movement
/// commands from arrow keys and other navigation sequences.
internal enum Direction {
  case up
  case down
  case left
  case right
}

/// Result type for incremental parsing operations.
///
/// The parser operates on partial input streams and may need to request
/// more data before completing a parse operation. This result type
/// captures the three possible outcomes of a parsing attempt.
internal enum ParseResult<Output> {
  case success(Output, buffer: ArraySlice<UInt8>)
  case failure(buffer: ArraySlice<UInt8>)
  case indeterminate
}

/// Device attribute response types based on intermediate characters.
///
/// Different device attribute queries return different types of information.
/// The intermediate character in the CSI sequence indicates which type of
/// response is being provided.
public enum VTDeviceAttributesResponse: Equatable, Sendable {
  /// Primary device attributes (DA1) - basic terminal identification
  case primary([Int])

  /// Secondary device attributes (DA2) - version and capability info
  case secondary([Int])

  /// Tertiary device attributes (DA3) - unit identification
  case tertiary([Int])
}

/// Represents different types of parsed terminal input sequences.
///
/// Terminal input consists of various sequence types, from simple characters
/// to complex escape sequences. This enum captures the different categories
/// of input that the parser can recognize and extract meaning from.
///
/// The parser handles:
/// - Regular printable characters
/// - Cursor movement sequences (arrow keys)
/// - Function key sequences
/// - Unknown or malformed sequences
internal enum ParsedSequence {
  case character(Character)
  case cursor(direction: Direction, count: Int)
  case DeviceAttributes(VTDeviceAttributesResponse)
  case function(number: Int, modifiers: KeyModifiers)
  case unknown(sequence: [UInt8])
}

/// A state machine parser for terminal input sequences.
///
/// `VTInputParser` implements a robust parser for terminal input that handles
/// the complexity of ANSI escape sequences, control sequences, and Unicode
/// text. The parser operates as a state machine that can process partial
/// input and request more data when needed.
///
/// ## Key Features
///
/// - **Incremental parsing**: Handles partial input streams gracefully
/// - **State preservation**: Maintains parse state across multiple calls
/// - **Error recovery**: Continues parsing after encountering malformed input
/// - **Unicode support**: Properly handles multi-byte character sequences
/// - **ANSI compatibility**: Supports standard terminal escape sequences
///
/// ## Usage Pattern
///
/// The parser is designed to be fed raw terminal input incrementally:
///
/// ```swift
/// var parser = VTInputParser()
/// let rawInput: [UInt8] = getTerminalInput()
/// let sequences = parser.parse(rawInput[...])
///
/// for sequence in sequences {
///   if let event = sequence.event {
///     handleKeyEvent(event)
///   }
/// }
/// ```
///
/// ## Error Handling
///
/// The parser is designed to be resilient to malformed input. When it
/// encounters invalid sequences, it drops the problematic bytes and
/// continues parsing the rest of the input stream.
internal struct VTInputParser {
  private enum State {
    /// Normal text parsing mode - looking for regular characters or escape.
    case normal
    /// Just received an escape character - determining sequence type.
    case escape
    /// Parsing a Control Sequence Introducer (CSI) sequence.
    case CSI(parameters: [Int], intermediate: [UInt8])
    /// Parsing an Operating System Command (OSC) sequence.
    case OSC(data: [UInt8])
    /// Parsing a Device Control String (DCS) sequence.
    case DCS(data: [UInt8])
    /// Parsing a Single Shift Three (SS3) sequence.
    case SS3
  }

  /// Current parser state - tracks what type of sequence is being parsed.
  private var state: State = .normal
  /// Internal buffer for incomplete sequences that need more input.
  private var buffer: [UInt8] = []

  /// Parses the current input based on the parser's current state.
  ///
  /// This is the core state machine dispatcher that routes parsing to the
  /// appropriate handler based on what type of sequence is being processed.
  private mutating func parse(_ input: inout ArraySlice<UInt8>)
      -> ParseResult<ParsedSequence> {
    return switch state {
    case .normal: parse(normal: &input)
    case .escape: parse(escape: &input)
    case .CSI(let parameters, let intermediate):
      parse(csi: &input, parameters: parameters, intermediate: intermediate)
    case .OSC(let data):
      parse(osc: &input, data: data)
    case .DCS(let data):
      parse(dcs: &input, data: data)
    case .SS3:
      parse(ss3: &input)
    }
  }

  /// Handles buffered input by combining with new input before parsing.
  ///
  /// When the parser has buffered incomplete sequences from previous calls,
  /// this method combines them with new input to attempt completion.
  private mutating func parse(next input: inout ArraySlice<UInt8>)
      -> ParseResult<ParsedSequence> {
    guard buffer.isEmpty else { return parse(&input) }

    // consume the previous buffer
    let combined = buffer + Array(input)
    buffer.removeAll()

    var buffer = combined[...]
    return parse(&buffer)
  }

  /// Parses a byte array into a sequence of recognized terminal input events.
  ///
  /// This is the main entry point for parsing terminal input. It processes
  /// the input incrementally, maintaining state between calls to handle
  /// incomplete escape sequences that span multiple input buffers.
  ///
  /// The parser is resilient to malformed input - when it encounters invalid
  /// sequences, it drops the problematic bytes and continues processing.
  ///
  /// ## Parameters
  /// - input: Raw bytes from terminal input to parse
  ///
  /// ## Returns
  /// Array of parsed sequences that can be converted to key events
  ///
  /// ## Example Usage
  /// ```swift
  /// var parser = VTInputParser()
  /// let rawInput: [UInt8] = [0x1b, 0x5b, 0x41]  // Up arrow sequence
  /// let sequences = parser.parse(rawInput[...])
  /// // sequences contains cursor movement for up arrow
  /// ```
  internal mutating func parse(_ input: ArraySlice<UInt8>) -> [ParsedSequence] {
    var results: [ParsedSequence] = []
    var input = input

    while !input.isEmpty {
      switch parse(next: &input) {
      case .success(let sequence, let buffer):
        results.append(sequence)
        input = buffer
      case .failure(let buffer):
        // drop invalid byte and continue
        input = buffer.dropFirst()
      case .indeterminate:
        buffer.append(contentsOf: input)
        break
      }
    }

    return results
  }
}

extension VTInputParser {
  private mutating func parse(normal input: inout ArraySlice<UInt8>)
      -> ParseResult<ParsedSequence> {
    guard let byte = input.first else { return .indeterminate }

    if byte == 0x1b {   // escape
      state = .escape
      input = input.dropFirst()
      return parse(next: &input)
    }

    // Regular Character
    input = input.dropFirst()
    state = .normal

    let scalar = UnicodeScalar(byte)
    if scalar.isASCII {
      return .success(.character(Character(scalar)), buffer: input)
    }

    // UTF-8 multibyte sequence
    return .failure(buffer: input)
  }

  private mutating func parse(escape input: inout ArraySlice<UInt8>)
      -> ParseResult<ParsedSequence> {
    guard let byte = input.first else {
      state = .normal
      return .success(.character("\u{1b}"),  buffer: input)
    }

    switch byte {
    case 0x4f:  // O (SS3)
      state = .SS3
      input = input.dropFirst()
      return parse(next: &input)

    case 0x50:  // P (DCS)
      state = .DCS(data: [])
      input = input.dropFirst()
      return parse(next: &input)

    case 0x5b:  // [ (CSI)
      state = .CSI(parameters: [], intermediate: [])
      input = input.dropFirst()
      return parse(next: &input)

    case 0x5d:  // ] (OSC)
      state = .OSC(data: [])
      input = input.dropFirst()
      return parse(next: &input)

    default:
      // invalid escape sequence
      state = .normal
      return .failure(buffer: input.dropFirst())
    }
  }

  private mutating func parse(csi input: inout ArraySlice<UInt8>,
                              parameters: [Int], intermediate: [UInt8])
      -> ParseResult<ParsedSequence> {
    guard let byte = input.first else { return .indeterminate }
    switch byte {
    case 0x20 ... 0x2f: // intermediate bytes
      state = .CSI(parameters: parameters, intermediate: intermediate + [byte])
      input = input.dropFirst()
      return parse(next: &input)

    case 0x30 ... 0x39: // '0'-'9' (Pn...Ps)
      let (parameters, buffer) = parse(parameters: input, parsed: parameters)
      state = .CSI(parameters: parameters, intermediate: intermediate)
      input = buffer
      return parse(next: &input)

    case 0x3b: // ';' (Parameter Separator)
      state = .CSI(parameters: parameters, intermediate: intermediate)
      input = input.dropFirst()
      return parse(next: &input)

    case 0x3d: // '=' (DEC Private Mode)
      state = .CSI(parameters: parameters, intermediate: intermediate + [byte])
      input = input.dropFirst()
      return parse(next: &input)

    case 0x3e: // '>' (DEC Private Mode)
      state = .CSI(parameters: parameters, intermediate: intermediate + [byte])
      input = input.dropFirst()
      return parse(next: &input)

    case 0x3f: // '?' (DEC Private Mode)
      state = .CSI(parameters: parameters, intermediate: intermediate + [byte])
      input = input.dropFirst()
      return parse(next: &input)

    case 0x40 ... 0x7e: // command
      state = .normal
      input = input.dropFirst()
      return .success(parse(csi: byte, parameters: parameters, intermediate: intermediate),
                      buffer: input)

    default:
      // invalid CSI sequence
      state = .normal
      input = input.dropFirst()
      return .failure(buffer: input)
    }
  }

  private mutating func parse(ss3 input: inout ArraySlice<UInt8>)
      -> ParseResult<ParsedSequence> {
    guard let byte = input.first else { return .indeterminate }

    input = input.dropFirst()
    state = .normal

    return switch byte {
    case 0x41: // 'A'
      .success(.cursor(direction: .up, count: 1), buffer: input)
    case 0x42: // 'B'
      .success(.cursor(direction: .down, count: 1), buffer: input)
    case 0x43: // 'C'
      .success(.cursor(direction: .right, count: 1), buffer: input)
    case 0x44: // 'D'
      .success(.cursor(direction: .left, count: 1), buffer: input)
    default:
      .success(.unknown(sequence: [0x1b, 0x4f, byte]), buffer: input)
    }
  }

  private mutating func parse(osc input: inout ArraySlice<UInt8>, data: [UInt8])
      -> ParseResult<ParsedSequence> {
    guard let byte = input.first else { return .indeterminate }

    if byte == 0x07 /* bell */ || byte == 0x1b /* escape */ {
      input = input.dropFirst()
      if byte == 0x1b {
        // Check for ESC \ terminator
        guard let next = input.first, next == 0x5c else {
          return .failure(buffer: input)
        }
        input = input.dropFirst()
      }
      state = .normal
      return .success(.unknown(sequence: [0x1b, 0x5d] + data + [byte]),
                      buffer: input)
    }

    input = input.dropFirst()
    state = .OSC(data: data + [byte])
    return parse(next: &input)
  }

  private mutating func parse(dcs input: inout ArraySlice<UInt8>, data: [UInt8])
      -> ParseResult<ParsedSequence> {
    guard let byte = input.first else { return .indeterminate }
    if byte == 0x1b /* escape */ {
      // Check for ESC \ terminator
      guard input.count >= 2,
          input[input.index(after: input.startIndex)] == 0x5c else {
        return .indeterminate
      }
      input = input.dropFirst(2)
      state = .normal
      return .success(.unknown(sequence: [0x1b, 0x50] + data + [0x1b, byte]),
                      buffer: input)
    }

    input = input.dropFirst()
    state = .DCS(data: data + [byte])
    return parse(next: &input)
  }
}

extension VTInputParser {
  private func parse(parameters input: ArraySlice<UInt8>, parsed parameters: [Int])
      -> ([Int], ArraySlice<UInt8>) {
    var parameters = parameters
    var input = input
    var parameter = ""

    while let byte = input.first, (0x30 ... 0x39).contains(byte) {
      parameter.append(Character(UnicodeScalar(byte)))
      input = input.dropFirst()
    }

    if !parameter.isEmpty {
      parameters.append(Int(parameter) ?? 0)
    }

    return (parameters, input)
  }

  private func parse(csi command: UInt8, parameters: [Int], intermediate: [UInt8])
      -> ParsedSequence {
    let count = parameters.first ?? 1
    switch command {
    case 0x41:  // 'A' (CUU)
      return .cursor(direction: .up, count: count)
    case 0x42:  // 'B' (CUD)
      return .cursor(direction: .down, count: count)
    case 0x43:  // 'C' (CUF)
      return .cursor(direction: .right, count: count)
    case 0x44:  // 'D' (CUB)
      return .cursor(direction: .left, count: count)
    case 0x63 where intermediate == [0x3f]:  // '\033[?...c' (DA1)
      return .DeviceAttributes(.primary(parameters))
    case 0x63 where intermediate == [0x3e]:  // '\033[>...c' (DA2)
      return .DeviceAttributes(.secondary(parameters))
    case 0x63 where intermediate == [0x3d]:  // '\033[=...c' (DA3)
      return .DeviceAttributes(.tertiary(parameters))
    default:
      let sequence: [UInt8] = [UInt8(0x1b), UInt8(0x5b)] + parameters.flatMap { String($0).utf8 } + [UInt8(0x3b)] + intermediate + [command]
      return .unknown(sequence: sequence)
    }
  }
}

extension ParsedSequence {
  /// Converts a parsed sequence into a key event if possible.
  ///
  /// Not all parsed sequences can be converted to key events. This property
  /// returns `nil` for sequences that represent non-key events (like unknown
  /// sequences) or sequences that don't map to keyboard input.
  ///
  /// The conversion handles:
  /// - Regular characters as character key events
  /// - Escape sequences as escape key events
  /// - Cursor movement sequences as arrow key events
  /// - Function key sequences as function key events
  ///
  /// ## Usage Example
  /// ```swift
  /// let sequences = parser.parse(inputBytes)
  /// for sequence in sequences {
  ///   if let keyEvent = sequence.event {
  ///     handleKeyInput(keyEvent)
  ///   } else {
  ///     // Handle non-key sequence (like unknown/malformed input)
  ///     handleUnknownSequence(sequence)
  ///   }
  /// }
  /// ```
  ///
  /// - Returns: A `VTEvent` if the sequence represents keyboard input,
  ///   or a terminal response, `nil` otherwise.
  internal var event: VTEvent? {
    return switch self {
    case let .character(character):
      if character == "\u{1b}" {
        .key(.init(character: character, keycode: VTKeyCode.escape, modifiers: [], type: .press))
      } else {
        .key(.init(character: character, keycode: 0, modifiers: [], type: .press))
      }

    case let .cursor(direction, _):
      switch direction {
      case .up:
        .key(.init(character: nil, keycode: VTKeyCode.up, modifiers: [], type: .press))
      case .down:
        .key(.init(character: nil, keycode: VTKeyCode.down, modifiers: [], type: .press))
      case .left:
        .key(.init(character: nil, keycode: VTKeyCode.left, modifiers: [], type: .press))
      case .right:
        .key(.init(character: nil, keycode: VTKeyCode.right, modifiers: [], type: .press))
      }

    case let .DeviceAttributes(attributes):
      .response(attributes)

    case let .function(number, modifiers):
      .key(.init(character: nil, keycode: UInt16(Int(VTKeyCode.F1) + number - 1),
                 modifiers: modifiers, type: .press))

    case .unknown(_):
      nil
    }
  }
}
