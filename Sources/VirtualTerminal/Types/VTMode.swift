// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// Terminal input processing modes that control how user input is handled.
///
/// Terminal modes determine whether input is processed by the system before
/// being delivered to your application. This affects everything from line
/// editing to signal handling and special key processing.
///
/// ## Choosing the Right Mode
///
/// - **Canonical (Cooked)**: Best for line-oriented applications like shells
///   or utilities that read complete lines of input
/// - **Raw**: Required for interactive applications, games, or full-screen
///   programs that need immediate key press detection
public enum VTMode: Sendable {
  /// Line-buffered input mode with system processing enabled.
  ///
  /// In canonical mode, the terminal system handles:
  /// - Line editing (backspace, delete, cursor movement)
  /// - Signal generation (Ctrl+C for SIGINT, Ctrl+Z for SIGTSTP)
  /// - Input buffering until newline is pressed
  /// - Echo of typed characters to the terminal
  ///
  /// This mode is ideal for command-line utilities, shells, and applications
  /// that process complete lines of text rather than individual keystrokes.
  case canonical

  /// Immediate input mode with minimal system processing.
  ///
  /// In raw mode, your application receives:
  /// - Individual keystrokes without buffering
  /// - Special keys (arrows, function keys, etc.) as escape sequences
  /// - Control characters without signal generation
  /// - Complete control over input processing and display
  ///
  /// This mode is essential for interactive applications, text editors,
  /// games, and any program that needs real-time input handling.
  case raw
}

extension VTMode {
  /// Alias for canonical mode using traditional terminal terminology.
  ///
  /// "Cooked" mode is the traditional Unix term for canonical input
  /// processing, where the system "cooks" (processes) input before
  /// delivering it to applications. This provides better semantic
  /// clarity for developers familiar with Unix terminal concepts.
  public static var cooked: VTMode {
    return .canonical
  }
}
