// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

#if os(Windows)

import Geometry
import WindowsCore

extension KeyModifiers {
  internal static func from(_ dwControlKeyState: DWORD) -> KeyModifiers {
    KeyModifiers([
      dwControlKeyState & SHIFT_PRESSED == SHIFT_PRESSED ? .shift : nil,
      dwControlKeyState & (LEFT_ALT_PRESSED | RIGHT_ALT_PRESSED) == 0 ? nil : .alt,
      dwControlKeyState & (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED) == 0 ? nil : .ctrl,
    ].compactMap { $0 })
  }
}

extension KeyEvent {
  internal static func from(_ record: KEY_EVENT_RECORD) -> KeyEvent {
    KeyEvent(scalar: UnicodeScalar(record.uChar.UnicodeChar),
             keycode: record.wVirtualKeyCode,
             modifiers: .from(record.dwControlKeyState),
             type: record.bKeyDown == true ? .press : .release)
  }
}

extension MouseEventType {
  internal static func from(_ record: MOUSE_EVENT_RECORD) -> MouseEventType {
    // TODO(compnerd) differentiate between button press/release
    return switch record.dwEventFlags {
    case MOUSE_MOVED:
      .move
    case MOUSE_WHEELED:
      .scroll(deltaX: 0, deltaY: Int(HIWORD(record.dwButtonState)) / 120)
    case MOUSE_HWHEELED:
      .scroll(deltaX: Int(HIWORD(record.dwButtonState)) / 120, deltaY: 0)
    default:
      .pressed(MouseButton([
        record.dwButtonState & FROM_LEFT_1ST_BUTTON_PRESSED == 0 ? nil : .left,
        record.dwButtonState & RIGHTMOST_BUTTON_PRESSED == 0 ? nil : .right,
        record.dwButtonState & FROM_LEFT_2ND_BUTTON_PRESSED == 0 ? nil : .middle,
      ].compactMap { $0 }))
    }
  }
}

extension MouseEvent {
  internal static func from(_ record: MOUSE_EVENT_RECORD) -> MouseEvent {
    MouseEvent(position: Point(x: Int(record.dwMousePosition.X), y: Int(record.dwMousePosition.Y)),
               type: .from(record))
  }
}

extension ResizeEvent {
  internal static func from(_ record: WINDOW_BUFFER_SIZE_RECORD) -> ResizeEvent {
    ResizeEvent(size: Size(width: Int(record.dwSize.X), height: Int(record.dwSize.Y)))
  }
}

#endif
