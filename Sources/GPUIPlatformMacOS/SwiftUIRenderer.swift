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
            // Draw anchored to the leading-top of the frame.
            context.draw(resolved, at: CGPoint(x: cgRect.minX, y: cgRect.midY), anchor: .leading)

        case .roundedRect(let radius, let fill, let border, let shadow):
            let path = Path(roundedRect: cgRect, cornerRadius: CGFloat(radius))

            if let shadow {
                context.drawLayer { ctx in
                    ctx.addFilter(.shadow(
                        color: shadow.color.swiftUIColor,
                        radius: CGFloat(shadow.blur / 2),
                        x: CGFloat(shadow.offset.x),
                        y: CGFloat(shadow.offset.y)
                    ))
                    ctx.fill(path, with: .color(fill.swiftUIColor))
                }
            } else {
                context.fill(path, with: .color(fill.swiftUIColor))
            }

            if let border {
                context.stroke(path, with: .color(border.swiftUIColor), lineWidth: 1)
            }

        case .button(let label, let fill, let labelColor):
            let path = Path(roundedRect: cgRect, cornerRadius: 8)
            context.fill(path, with: .color(fill.swiftUIColor))

            let resolved = context.resolve(
                SwiftUI.Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(labelColor.swiftUIColor)
            )
            context.draw(resolved, at: CGPoint(x: cgRect.midX, y: cgRect.midY), anchor: .center)

        case .textField(_, let label, _, _, let focused):
            // Draw shell only: background + border + floating label.
            // The platform TextField overlay renders all text (placeholder + value + cursor).
            let borderColor: SwiftGPUI.Color = focused ? .primary : .border
            let path = Path(roundedRect: cgRect, cornerRadius: 6)
            context.fill(path, with: .color(SwiftGPUI.Color.surface.swiftUIColor))
            context.stroke(path, with: .color(borderColor.swiftUIColor), lineWidth: 1)

            if let label {
                let labelPos = CGPoint(x: cgRect.minX + 10, y: cgRect.minY + 8)
                let labelColor = SwiftGPUI.Color(r: 0.55, g: 0.60, b: 0.75, a: 1)
                let resolvedLabel = context.resolve(
                    SwiftUI.Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(labelColor.swiftUIColor)
                )
                context.draw(resolvedLabel, at: labelPos, anchor: .leading)
            }

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
