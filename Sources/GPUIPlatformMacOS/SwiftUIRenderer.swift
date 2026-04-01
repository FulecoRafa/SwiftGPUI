import SwiftUI
import SwiftGPUI

// MARK: - SwiftUIRenderer

/// Translates a flat list of (Rect, RenderCommand) produced by the GPUI
/// interpreter into SwiftUI GraphicsContext draw calls.
///
/// This is the macOS display backend. When Skia is linked, SkiaRenderer
/// in GPUIObserve replaces this entirely — SwiftUI is no longer involved.
public enum SwiftUIRenderer {

    public static func draw(
        commands: [(Rect, RenderCommand)],
        into context: inout GraphicsContext
    ) {
        for (frame, command) in commands {
            draw(command: command, frame: frame, into: &context)
        }
    }

    // MARK: Private

    private static func draw(
        command: RenderCommand,
        frame: Rect,
        into context: inout GraphicsContext
    ) {
        let cgRect = CGRect(frame)

        switch command {

        case .text(let str, let font, let color):
            let resolved = context.resolve(
                SwiftUI.Text(str)
                    .font(.system(size: CGFloat(font.size), weight: font.swiftUIWeight))
                    .foregroundColor(color.swiftUIColor)
            )
            context.draw(resolved, in: cgRect)

        case .roundedRect(let radius, let fill, let border, _):
            let path = Path(roundedRect: cgRect, cornerRadius: CGFloat(radius))
            context.fill(path, with: .color(fill.swiftUIColor))
            if let border {
                context.stroke(path, with: .color(border.swiftUIColor), lineWidth: 1)
            }

        case .button(let label, let fill, let labelColor):
            let path = Path(roundedRect: cgRect, cornerRadius: 6)
            context.fill(path, with: .color(fill.swiftUIColor))
            let inner = Rect(
                x: frame.x + 12, y: frame.y + 10,
                width: frame.width - 24, height: frame.height - 20
            )
            draw(command: .text(label, font: .body, color: labelColor),
                 frame: inner, into: &context)

        case .textField(let placeholder, let label, _, let secure, let focused):
            let borderColor: SwiftGPUI.Color = focused ? .primary : .border
            let path = Path(roundedRect: cgRect, cornerRadius: 4)
            context.fill(path, with: .color(SwiftGPUI.Color.surface.swiftUIColor))
            context.stroke(path, with: .color(borderColor.swiftUIColor), lineWidth: 1)

            if let label {
                let labelFrame = Rect(x: frame.x + 8, y: frame.y - 10, width: 200, height: 16)
                draw(command: .text(label, font: .label, color: .onSurface),
                     frame: labelFrame, into: &context)
            }
            let display = secure ? String(repeating: "•", count: 8) : placeholder
            let textFrame = Rect(x: frame.x + 12, y: frame.y + 12,
                                 width: frame.width - 24, height: frame.height - 24)
            draw(command: .text(display, font: .body, color: .onSurface),
                 frame: textFrame, into: &context)

        case .clipped(let inner, let clipRect):
            context.clip(to: Path(CGRect(clipRect)))
            draw(command: inner, frame: clipRect, into: &context)

        case .group(let cmds):
            for cmd in cmds {
                draw(command: cmd, frame: frame, into: &context)
            }
        }
    }
}

// MARK: - Conversion helpers

private extension CGRect {
    init(_ r: Rect) {
        self.init(x: CGFloat(r.x), y: CGFloat(r.y),
                  width: CGFloat(r.width), height: CGFloat(r.height))
    }
}

private extension SwiftGPUI.Color {
    var swiftUIColor: SwiftUI.Color {
        SwiftUI.Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
}

private extension SwiftGPUI.Font {
    var swiftUIWeight: SwiftUI.Font.Weight {
        switch weight {
        case .bold:    return .bold
        case .medium:  return .medium
        case .regular: return .regular
        }
    }
}
