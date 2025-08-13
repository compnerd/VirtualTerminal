// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Geometry
import Primitives
import VirtualTerminal

extension VTBuffer {
  internal var center: Point {
    Point(x: size.width / 2, y: size.height / 2)
  }
}

// MARK: - Scene

private protocol Scene {
  static var name: String { get }
  static var description: String { get }

  init(size: Size)

  mutating func update(ΔTime: Duration)
  mutating func render(into buffer: inout VTBuffer)
  mutating func process(input: VTEvent)
}

extension Scene {
  mutating func update(ΔTime: Duration) { }
  mutating func process(input: VTEvent) { }
}

// MARK: - Matrix Rain Effect

private struct MatrixRain: Scene {
  private struct MatrixDrop {
    static var Characters: String {
      "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝ0123456789"
    }

    let column: Int
    private let height: Int
    private let speed: Int = Int.random(in: 1 ... 5)
    private var length: Int = 0

    private var position: Int = 0
    private var trail: [Character] = []

    private static func trailLength() -> Int {
      return switch Int.random(in: 1 ... 100) {
      case 1 ... 15:    // 15% chance - very short drops (3-8 chars)
        Int.random(in: 3 ... 8)
      case 16 ... 70:   // 55% chance - normal drops (6-20 chars)
        Int.random(in: 6 ... 20)
      case 71 ... 90:   // 20% chance - long drops (20-35 chars)
        Int.random(in: 20 ... 35)
      case 91 ... 100:  // 10% chance - very long drops (35-50 chars)
        Int.random(in: 35 ... 50)
      default:
        Int.random(in: 6 ... 35)
      }
    }

    private mutating func reset() {
      length = Self.trailLength()
      position = -length
      trail = (0 ..< length).map { _ in MatrixDrop.Characters.randomElement() ?? "0" }
    }

    public init(column: Int, height: Int) {
      self.column = column
      self.height = height

      reset()
      self.length = Self.trailLength()
    }

    internal mutating func update() {
      position += speed
      guard position < height + length else { return reset() }
    }

    public func render(into buffer: inout VTBuffer) {
      guard (1 ... buffer.size.width).contains(column) else { return }

      for character in trail.enumerated() {
        let row = position + character.offset
        guard (1 ... buffer.size.height).contains(row) else { continue }

        let intensity =
            character.offset == 0 ? 255 : max(50, 255 - 20 * character.offset)
        let style = VTStyle(foreground: .rgb(red: 0, green: UInt8(intensity), blue: 0),
                            attributes: [.bold])
        buffer.write(string: String(character.element),
                     at: VTPosition(row: row, column: column), style: style)
      }
    }
  }

  private var drops: [MatrixDrop] = []
  private var update: ContinuousClock.Instant = .now
  private var fade: ContinuousClock.Instant = .now

  public init(size: Size) {
    drops = stride(from: 1, to: size.width, by: 2)
                .map { MatrixDrop(column: $0, height: size.height) }
  }

  public mutating func render(into buffer: inout VTBuffer) {
    if ContinuousClock.now - update >= Duration.milliseconds(150) {
      for column in drops.indices {
        drops[column].update()
      }
      update = .now
    }

    // Fade every ~200ms
    if ContinuousClock.now - fade >= Duration.milliseconds(200) {
      defer { fade = .now }

      for row in 1 ... buffer.size.height {
        for column in 1 ... buffer.size.width {
          let position = VTPosition(row: row, column: column)
          let character = buffer[position].character
          if character == " " { continue }
          buffer[position] =
              VTCell(character: character,
                     style: VTStyle(foreground: .rgb(red: 0, green: 64, blue: 0)))
        }
      }
    }

    for drop in drops {
      drop.render(into: &buffer)
    }
  }
}

extension MatrixRain {
  static var name: String {
    "Matrix Terminal Rain"
  }

  static var description: String {
    "The iconic Matrix terminal rain - random characters falling down the screen."
  }
}

// MARK: - Menu Scene

private struct Menu: Scene {
  package struct Option: Sendable {
    let scene: Scene.Type
    let hotkey: Character
  }

  public init(size: Size) { }

  package static let Options: [Option] = [
    Option(scene: MatrixRain.self, hotkey: "1"),
  ]

  private let start: ContinuousClock.Instant = .now

  private var selection: Array<Option>.Index = 0

  public var scene: Scene.Type? {
    guard selection < Menu.Options.count else { return nil }
    return Menu.Options[selection].scene
  }

  public mutating func render(into buffer: inout VTBuffer) {
    let title = "🚀 VirtualTerminal Demo Showcase 🚀"
    let subtitle = "Experience the power of high-performance terminal rendering"

    let time = (ContinuousClock.now - start).seconds

    let red = sin(2.0 * time) * 0.5 + 0.5
    let green = sin(2.5 * time + 2.094) * 0.5 + 0.5 // 2π/3 phase shift
    let blue = sin(3.0 * time + 4.189) * 0.5 + 0.5  // 4π/3 phase shift
    let color = VTColor.rgb(red: UInt8(red * 255),
                            green: UInt8(green * 255),
                            blue: UInt8(blue * 255))

    // Center the title and subtitle
    buffer.write(string: title,
                 at: VTPosition(row: buffer.size.height / 4,
                                column: (buffer.size.width - title.width) / 2),
                 style: VTStyle(foreground: color, attributes: [.bold]))
    buffer.write(string: subtitle,
                 at: VTPosition(row: buffer.size.height / 4 + 1,
                                column: (buffer.size.width - subtitle.width) / 2),
                 style: VTStyle(foreground: .ansi(.cyan, intensity: .bright),
                                attributes: [.bold]))

    // Render the menu options
    for option in Menu.Options.enumerated() {
      let selected = option.offset == selection

      let row = (buffer.size.height / 4) + 4 + option.offset * 3
      let column = buffer.size.width / 2 - 24

      if selected {
        let arrow = ["\u{25b8}", "\u{25b9}"][Int((ContinuousClock.now - start).seconds) % 2]
        buffer.write(string: arrow,
                     at: VTPosition(row: row, column: column - 2),
                     style: VTStyle(foreground: .yellow, attributes: [.bold]))
      }

      buffer.write(string: "\(option.offset + 1). \(option.element.scene.name)",
                   at: VTPosition(row: row, column: column),
                   style: VTStyle(foreground: selected ? .white : .green,
                                  attributes: selected ? [.bold] : []))
      buffer.write(string: option.element.scene.description,
                   at: VTPosition(row: row + 1, column: column),
                   style: VTStyle(foreground: .ansi(.magenta)))
    }

    // Render controls
    let controls = [
      "┌───────── 🎮 Controls ──────────┐",
      "  ↑↓: Select demo",
      "   \u{23ce}: Run selected demo",
      "   \u{238b}: Return to menu",
      "   P: Toggle Performance Overlay",
      "   Q: Quit",
      "└────────────────────────────────┘"
    ]

    let width = controls.map(\.width).max() ?? 0
    let row = buffer.size.height - controls.count - 1
    let column = (buffer.size.width - width) / 2

    let body = VTStyle(foreground: .ansi(.white),
                        background: .rgb(red: 40, green: 40, blue: 60))
    let border = VTStyle(foreground: .ansi(.yellow),
                          background: .rgb(red: 40, green: 40, blue: 60),
                          attributes: [.bold])

    for control in controls.enumerated() {
      let style = (control.offset == 0 || control.offset == controls.count - 1)
                      ? border
                      : body
      buffer.write(string: control.element.padding(toLength: width, withPad: " ",
                                                   startingAt: 0),
                   at: VTPosition(row: row + control.offset, column: column),
                   style: style)
    }
  }
}

extension Menu {
  static var name: String { "" }
  static var description: String { "" }
}

// MARK: - Performance Overlay

private func render(statistics: FrameStatistics, into buffer: inout VTBuffer) {
  let FPSCurrent = if statistics.fps.current >= 1000 {
    String(format: "%4.1fk", statistics.fps.current / 1000.0)
  } else {
    String(format: "%4.1f", statistics.fps.current)
  }

  let FPSAverage = if statistics.fps.average >= 1000 {
    String(format: "%4.1fk", statistics.fps.average / 1000.0)
  } else {
    String(format: "%4.1f", statistics.fps.average)
  }

  let lines = [
    "┌─── Performance Stats ───┐",
    "      FPS: \(FPSCurrent)",
    "  Avg FPS: \(FPSAverage)",
    "      msf: \(String(format: "%5.2f", statistics.frametime.current.seconds * 1000)) ms",
    "  Avg msf: \(String(format: "%5.2f", statistics.frametime.average.seconds * 1000)) ms",
    "   Frames: \(statistics.frames.rendered)",
    "  Dropped: \(statistics.frames.dropped)",
    "   Drop %: \(String(format: "%4.1f", statistics.frames.rendered > 0 ? Double(statistics.frames.dropped) / Double(statistics.frames.rendered) * 100 : 0.0))%",
    "└─────────────────────────┘"
  ]

  let body = VTStyle(foreground: .ansi(.white),
                      background: .rgb(red: 40, green: 40, blue: 60))
  let border = VTStyle(foreground: .ansi(.yellow),
                        background: .rgb(red: 40, green: 40, blue: 60),
                        attributes: [.bold])

  let width = lines.map { $0.count }.max() ?? 0
  for line in lines.enumerated() {
    let style = (line.offset == 0 || line.offset == lines.count - 1) ? border : body
    let position =
        VTPosition(row: line.offset + 2, column: buffer.size.width - width - 2)

    buffer.write(string: line.element.padding(toLength: width, withPad: " ",
                                              startingAt: 0),
                 at: position, style: style)
  }
}

// MARK: - Application

@main
private struct VTDemo {
  internal enum ApplicationState {
    case menu
    case display(Scene)
  }

  private static var PreferredFPS: Double {
    60.0
  }

  private static nonisolated(unsafe) var statistics = true
  private static nonisolated(unsafe) var state = ApplicationState.menu
  private static nonisolated(unsafe) var menu = Menu(size: .zero)

  static func main() async throws {
    let renderer = try await VTRenderer(mode: .raw)
    let terminal = renderer.terminal

    await terminal <<< .SetMode([.DEC(.UseAlternateScreenBufferSaveCursor)])
                   <<< .ResetMode([.DEC(.TextCursorEnableMode)])

    defer {
      Task.synchronously {
        await terminal <<< .ResetMode([.DEC(.UseAlternateScreenBufferSaveCursor)])
                       <<< .SetMode([.DEC(.TextCursorEnableMode)])
      }
    }

    try await withThrowingTaskGroup(of: Void.self) { group in
      defer { group.cancelAll() }

      // Input handling task
      group.addTask {
        for try await event in terminal.input {
          switch event {
          case .key(let key) where key.type == .press:
            // Global Key Handling
            switch key.character {
            case "q", "Q": return
            case "p", "P": statistics.toggle()
            case "m", "M":
              state = .menu
              continue
            default:
              break
            }

            // Handle escape key
            if key.keycode == VTKeyCode.escape {
              switch VTDemo.state {
              case .menu:
                return

              case .display(_):
                VTDemo.state = .menu
              }
            }

            switch VTDemo.state {
            case .menu:
              if ["\r", "\n"].contains(key.character) {
                if let scene = menu.scene {
                  state = .display(scene.init(size: renderer.back.size))
                }
                continue
              }

              for option in Menu.Options {
                if option.hotkey == key.character {
                  VTDemo.state = .display(option.scene.init(size: renderer.back.size))
                  break
                }
              }

              menu.process(input: event)

            case .display(var scene):
              // Process scene-specific input
              scene.process(input: event)
              VTDemo.state = .display(scene)
            }

          default: continue
          }
        }
      }

      // Rendering task
      nonisolated(unsafe) var previous: ContinuousClock.Instant?
      nonisolated(unsafe) var profiler = VTProfiler(target: VTDemo.PreferredFPS)
      let link = VTDisplayLink(fps: VTDemo.PreferredFPS) { link in
        let ΔTime = previous.map { link.timestamp - $0 } ?? .zero 

        previous = .now
        profiler.measure {
          switch VTDemo.state {
          case .menu:
            VTDemo.menu.update(ΔTime: ΔTime)
            VTDemo.menu.render(into: &renderer.back)

          case .display(var scene):
            scene.update(ΔTime: ΔTime)
            scene.render(into: &renderer.back)
            VTDemo.state = .display(scene)
          }
        }

        if VTDemo.statistics {
          render(statistics: profiler.statistics, into: &renderer.back)
        }

        await renderer.present()

        // This would theoretically be best done during the vblank, but we don't
        // have that in this environment.
        renderer.back.clear()
      }
      link.add(to: &group)

      try await group.next()
    }
  }
}
