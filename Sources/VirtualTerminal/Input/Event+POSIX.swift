// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

#if !os(Windows)

extension KeyEvent {
  internal static func from(_ character: Character) -> KeyEvent {
    KeyEvent(character: character, keycode: .max, modifiers: [], type: .press)
  }
}

#endif
