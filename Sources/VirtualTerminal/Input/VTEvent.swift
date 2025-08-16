// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Geometry

/// Terminal input events from user interactions.
///
/// `VTEvent` represents all types of input that can occur in a terminal
/// application, including keyboard input, mouse interactions, and terminal
/// resize events. This unified event system allows applications to handle
/// all user input through a single interface.
///
/// ## Usage Example
/// ```swift
/// func handleEvent(_ event: VTEvent) {
///   switch event {
///   case .key(let key):
///     handleKeyPress(key)
///   case .mouse(let mouse):
///     handleMouseInput(mouse)
///   case .resize(let resize):
///     handleTerminalResize(resize)
///   }
/// }
/// ```
public enum VTEvent: Equatable, Sendable {
  /// A keyboard input event.
  case key(KeyEvent)

  /// A mouse input event.
  case mouse(MouseEvent)

  /// A terminal resize event.
  case resize(ResizeEvent)

  /// A device response event.
  case response(VTDeviceAttributesResponse)
}

// MARK: - Key Event

/// Modifier keys that can be held during keyboard input.
///
/// `KeyModifiers` represents the state of modifier keys (Shift, Ctrl, Alt,
/// Meta) during a key event. Multiple modifiers can be combined using the
/// `OptionSet` interface to represent complex key combinations like
/// Ctrl+Shift+A.
///
/// ## Usage Example
/// ```swift
/// let modifiers: KeyModifiers = [.ctrl, .shift]
/// if key.modifiers.contains(.ctrl) {
///   // Handle Ctrl-modified key press
/// }
/// ```
public struct KeyModifiers: Equatable, OptionSet, Sendable {
  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }
}

extension KeyModifiers {
  public static var shift: KeyModifiers {
    KeyModifiers(rawValue: 1 << 0)
  }

  public static var ctrl: KeyModifiers {
    KeyModifiers(rawValue: 1 << 1)
  }

  public static var alt: KeyModifiers {
    KeyModifiers(rawValue: 1 << 2)
  }

  public static var meta: KeyModifiers {
    KeyModifiers(rawValue: 1 << 3)
  }
}

/// The type of keyboard interaction that occurred.
///
/// `KeyEventType` distinguishes between key press and release events,
/// allowing applications to respond differently to each phase of user
/// input. This is particularly useful for applications that need to
/// track key hold duration or implement custom repeat behavior.
public enum KeyEventType: Equatable, Sendable {
  case press
  case release
}

/// A keyboard input event with character and modifier information.
///
/// `KeyEvent` captures complete information about a keyboard interaction,
/// including the character generated, the raw keycode, any modifier keys
/// held, and whether this was a press or release event.
///
/// The character field contains the printable character for normal keys,
/// or nil for special keys like arrows, function keys, or modifier-only
/// events.
///
/// ## Usage Example
/// ```swift
/// func handleKeyEvent(_ event: KeyEvent) {
///   switch (event.character, event.modifiers) {
///   case ("q", []):
///     quit()
///   case ("c", .ctrl):
///     copySelection()
///   case (nil, []):
///     handleSpecialKey(event.keycode)
///   default:
///     insertText(event.character)
///   }
/// }
/// ```
public struct KeyEvent: Equatable, Sendable {
  public let character: Character?
  public let keycode: UInt16
  public let modifiers: KeyModifiers
  public let type: KeyEventType

  internal init(character: Character?, keycode: UInt16, modifiers: KeyModifiers = [], type: KeyEventType) {
    self.character = character
    self.keycode = keycode
    self.modifiers = modifiers
    self.type = type
  }

  internal init(scalar: UnicodeScalar?, keycode: UInt16, modifiers: KeyModifiers = [], type: KeyEventType) {
    self.character = if let scalar { Character(scalar) } else { nil }
    self.keycode = keycode
    self.modifiers = modifiers
    self.type = type
  }
}

// MARK: - Mouse Event

/// Mouse buttons that can be pressed or released.
///
/// `MouseButton` represents the physical mouse buttons available for
/// interaction. The standard three-button mouse (left, right, middle)
/// plus additional buttons (4, 5) commonly used for navigation are
/// supported. Multiple buttons can be combined for complex interactions.
///
/// ## Usage Example
/// ```swift
/// let buttons: MouseButton = [.left, .right]  // Both buttons pressed
/// if mouse.type == .pressed(.left) {
///   startSelection(at: mouseEvent.position)
/// }
/// ```
public struct MouseButton: Equatable, OptionSet, Sendable {
  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }
}

extension MouseButton {
  public static var left: MouseButton {
    MouseButton(rawValue: 1 << 0)
  }

  public static var right: MouseButton {
    MouseButton(rawValue: 1 << 1)
  }

  public static var middle: MouseButton {
    MouseButton(rawValue: 1 << 2)
  }

  public static var button4: MouseButton {
    MouseButton(rawValue: 1 << 3)
  }

  public static var button5: MouseButton {
    MouseButton(rawValue: 1 << 4)
  }
}

/// The type of mouse interaction that occurred.
///
/// `MouseEventType` captures different mouse actions including button
/// presses, releases, movement, and scroll wheel operations. This
/// comprehensive event model allows applications to implement rich
/// mouse-based user interfaces.
///
/// ## Usage Examples
/// ```swift
/// switch mouse.type {
/// case .pressed(.left):
///   beginDrag(at: mouse.position)
/// case .released(.left):
///   endDrag(at: mouse.position)
/// case .move:
///   updateHover(at: mouse.position)
/// case .scroll(let deltaX, let deltaY):
///   scrollContent(x: deltaX, y: deltaY)
/// }
/// ```
public enum MouseEventType: Equatable, Sendable {
  case pressed(MouseButton)
  case released(MouseButton)
  case move
  case scroll(deltaX: Int, deltaY: Int)
}

/// A mouse input event with position and interaction details.
///
/// `MouseEvent` combines the location of a mouse interaction with the
/// specific type of action that occurred. The position is given in
/// terminal character cell coordinates, making it easy to map mouse
/// interactions to specific locations in your terminal content.
///
/// ## Usage Example
/// ```swift
/// func handleMouseEvent(_ event: MouseEvent) {
///   let cell = (row: Int(event.position.y), column: Int(event.position.x))
///   switch event.type {
///   case .pressed(.left):
///     selectCell(row: cell.row, column: cell.column)
///   case .released(.right):
///     showContextMenu(row: cell.row, column: cell.column)
///   default:
///     break
///   }
/// }
/// ```
public struct MouseEvent: Equatable, Sendable {
  public let position: Point
  public let type: MouseEventType

  internal init(position: Point, type: MouseEventType) {
    self.position = position
    self.type = type
  }
}

// MARK: - Resize Event

/// A terminal window resize event.
///
/// `ResizeEvent` is generated when the terminal window changes size,
/// providing the new dimensions in character cells. Applications should
/// respond to resize events by updating their layout and potentially
/// redrawing content to fit the new terminal size.
///
/// ## Usage Example
/// ```swift
/// func handleResizeEvent(_ event: ResizeEvent) {
///   let target = Size(width: event.size.width, height: event.size.height)
///
///   // Update application layout for new terminal size
///   updateLayout(columns: target.width, rows: target.height)
///
///   // Redraw content to fit new dimensions
///   redrawScreen()
/// }
/// ```
public struct ResizeEvent: Equatable, Sendable {
  public let size: Size

  internal init(size: Size) {
    self.size = size
  }
}
