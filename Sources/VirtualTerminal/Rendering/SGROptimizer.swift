// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// Optimizes terminal text styling by tracking state and minimizing redundant commands.
///
/// `SGRStateTracker` maintains the current terminal styling state and generates
/// only the minimal SGR (Select Graphic Rendition) commands needed to transition
/// between different text styles. This optimization reduces terminal output and
/// improves rendering performance by avoiding redundant style changes.
///
/// ## SGR Optimization Benefits
///
/// - Eliminates redundant style commands when styles haven't changed
/// - Minimizes terminal output by generating only necessary transitions
/// - Handles complex attribute combinations intelligently
/// - Manages terminal state consistency across style changes
///
/// ## Usage Pattern
///
/// The tracker is typically used in rendering pipelines where text styles
/// change frequently:
///
/// ```swift
/// var tracker = SGRStateTracker()
///
/// // First transition sets up initial styling
/// let commands = tracker.transition(to: VTStyle(foreground: .red,
///                                               attributes: [.bold]))
/// // Outputs: [.Foreground(.red), .Bold]
///
/// // Subsequent identical style produces no commands
/// let commands2 = tracker.transition(to: VTStyle(foreground: .red,
///                                    attributes: [.bold]))
/// // Outputs: [] (no change needed)
///
/// // Only changed attributes are updated
/// let commands3 = tracker.transition(to: VTStyle(foreground: .blue,  // changed
///                                                attributes: [.bold] // unchanged))
/// // Outputs: [.Foreground(.blue)]
/// ```
///
/// ## State Management
///
/// The tracker maintains internal state and uses the non-copyable `~Copyable`
/// constraint to ensure unique ownership and prevent state corruption.
package struct SGRStateTracker: ~Copyable {
  private var current: VTStyle = .default

  private static var irreversible: VTAttributes {
    []
  }

  package init() { }

  private static func rendition(for attribute: VTAttributes, disabled: Bool = false) -> GraphicRendition {
    switch attribute {
    case .bold: return disabled ? .Normal : .Bold
    case .italic: return disabled ? .ItalicOff : .Italic
    case .underline: return disabled ? .UnderlineOff : .Underline
    case .blink: return .SlowBlink
    case .strikethrough: return disabled ? .NotCrossedOut : .CrossedOut
    default: fatalError("Unsupported VTAttribute \(attribute)")
    }
  }

  /// Generates the minimal SGR commands to transition between text styles.
  ///
  /// This method compares the current tracked style with the target style
  /// and produces only the SGR commands necessary to achieve the transition.
  /// It handles complex scenarios like attribute removal, color changes,
  /// and combinations of multiple style properties.
  ///
  /// ## Optimization Logic
  ///
  /// The method analyzes differences between current and target styles:
  /// - **No-op optimization**: Returns empty array if styles are identical
  /// - **Attribute management**: Toggles only changed text attributes
  /// - **Color transitions**: Updates only foreground/background changes
  /// - **Reset handling**: Uses SGR reset only when necessary for irreversible changes
  ///
  /// ## Parameters
  /// - target: The desired text style to transition to
  ///
  /// ## Returns
  /// An array of `GraphicRendition` commands representing the minimal
  /// transition. Returns an empty array if no changes are needed.
  ///
  /// ## Usage Examples
  ///
  /// ### Basic Style Changes
  /// ```swift
  /// var tracker = SGRStateTracker()
  ///
  /// // Set initial style
  /// let initial = tracker.transition(to: VTStyle(foreground: .white,
  ///                                              background: .black,
  ///                                              attributes: [.bold]))
  /// // Result: [.Foreground(.white), .Background(.black), .Bold]
  ///
  /// // Change only color
  /// let colorChange = tracker.transition(to: VTStyle(foreground: .red,      // changed
  ///                                                  background: .black,    // unchanged
  ///                                                  attributes: [.bold]))  // unchanged
  /// // Result: [.Foreground(.red)]
  /// ```
  ///
  /// ### Complex Attribute Handling
  /// ```swift
  /// // Add italic, keep bold
  /// let addItalic = tracker.transition(to: VTStyle(foreground: .red,
  ///                                                attributes: [.bold, .italic]))
  /// // Result: [.Italic]
  ///
  /// // Remove bold, keep italic
  /// let removeBold = tracker.transition(to: VTStyle(foreground: .red,
  ///                                                 attributes: [.italic]))
  /// // Result: [.Normal]
  /// ```
  ///
  /// ## State Updates
  ///
  /// The tracker's internal state is automatically updated after each
  /// transition, ensuring subsequent calls have accurate baseline information
  /// for optimization decisions.
  ///
  /// ## Performance Characteristics
  ///
  /// This optimization is particularly effective in scenarios with:
  /// - Frequent style changes (syntax highlighting, UI elements)
  /// - Repetitive styling patterns (tables, formatted output)
  /// - Complex attribute combinations that would otherwise generate redundant commands
  package mutating func transition(to target: VTStyle) -> [GraphicRendition] {
    if current == target { return [] }

    var renditions: [GraphicRendition] = []

    let removed = current.attributes.subtracting(target.attributes)
    // let added = target.attributes.subtracting(current.attributes)
    let toggled = current.attributes.symmetricDifference(target.attributes)

    // Only reset if we need to clear attributes which cannot be individually
    // toggled.
    if !removed.intersection(Self.irreversible).isEmpty {
      renditions.append(.Reset)
      current = .default
    }

    // Foreground color.
    if current.foreground != target.foreground {
      renditions.append(.Foreground(target.foreground ?? .default))
    }

    // Background color.
    if current.background != target.background {
      renditions.append(.Background(target.background ?? .default))
    }

    // Attributes.
    if toggled.contains(.bold) {
      renditions.append(Self.rendition(for: .bold, disabled: removed.contains(.bold)))
    }
    if toggled.contains(.italic) {
      renditions.append(Self.rendition(for: .italic, disabled: removed.contains(.italic)))
    }
    if toggled.contains(.underline) {
      renditions.append(Self.rendition(for: .underline, disabled: removed.contains(.underline)))
    }
    if toggled.contains(.blink) {
      renditions.append(Self.rendition(for: .blink, disabled: removed.contains(.blink)))
    }
    if toggled.contains(.strikethrough) {
      renditions.append(Self.rendition(for: .strikethrough, disabled: removed.contains(.strikethrough)))
    }

    current = target
    return renditions
  }
}
