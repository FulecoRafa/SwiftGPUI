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

        case .checkbox(let checked, let label):
            let boxSize: CGFloat = 18
            let boxRect = CGRect(
                x: cgRect.minX + 2, y: cgRect.midY - boxSize / 2,
                width: boxSize, height: boxSize
            )
            let boxPath = Path(roundedRect: boxRect, cornerRadius: 4)
            if checked {
                context.fill(boxPath, with: .color(SwiftGPUI.Color.primary.swiftUIColor))
                var check = Path()
                check.move(to:    CGPoint(x: boxRect.minX + 4,  y: boxRect.midY))
                check.addLine(to: CGPoint(x: boxRect.minX + 7,  y: boxRect.maxY - 4))
                check.addLine(to: CGPoint(x: boxRect.maxX - 3,  y: boxRect.minY + 4))
                context.stroke(check, with: .color(.white), lineWidth: 2)
            } else {
                context.stroke(boxPath, with: .color(SwiftGPUI.Color.border.swiftUIColor), lineWidth: 1.5)
            }
            if let label {
                let resolved = context.resolve(
                    SwiftUI.Text(label)
                        .font(.system(size: 14))
                        .foregroundColor(SwiftGPUI.Color.onSurface.swiftUIColor)
                )
                context.draw(resolved, at: CGPoint(x: boxRect.maxX + 8, y: cgRect.midY), anchor: .leading)
            }

        case .radio(let selected, let label):
            let circleSize: CGFloat = 18
            let circleRect = CGRect(
                x: cgRect.minX + 2, y: cgRect.midY - circleSize / 2,
                width: circleSize, height: circleSize
            )
            let circlePath = Path(ellipseIn: circleRect)
            if selected {
                context.fill(circlePath, with: .color(SwiftGPUI.Color.primary.swiftUIColor))
                let inner: CGFloat = 8
                let innerRect = CGRect(
                    x: circleRect.midX - inner / 2, y: circleRect.midY - inner / 2,
                    width: inner, height: inner
                )
                context.fill(Path(ellipseIn: innerRect), with: .color(.white))
            } else {
                context.stroke(circlePath, with: .color(SwiftGPUI.Color.border.swiftUIColor), lineWidth: 1.5)
            }
            let resolved = context.resolve(
                SwiftUI.Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(SwiftGPUI.Color.onSurface.swiftUIColor)
            )
            context.draw(resolved, at: CGPoint(x: circleRect.maxX + 8, y: cgRect.midY), anchor: .leading)

        case .select(let label, let displayValue, let placeholder):
            let path = Path(roundedRect: cgRect, cornerRadius: 6)
            context.fill(path, with: .color(SwiftGPUI.Color.surface.swiftUIColor))
            context.stroke(path, with: .color(SwiftGPUI.Color.border.swiftUIColor), lineWidth: 1)
            if let label {
                let lc = SwiftGPUI.Color(r: 0.55, g: 0.60, b: 0.75, a: 1)
                let rl = context.resolve(
                    SwiftUI.Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(lc.swiftUIColor)
                )
                context.draw(rl, at: CGPoint(x: cgRect.minX + 10, y: cgRect.minY + 8), anchor: .leading)
            }
            let text = displayValue.isEmpty ? placeholder : displayValue
            let textColor = displayValue.isEmpty ? SwiftGPUI.Color.border : SwiftGPUI.Color.onSurface
            let textY = label != nil ? cgRect.minY + 30 : cgRect.midY
            let rv = context.resolve(
                SwiftUI.Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(textColor.swiftUIColor)
            )
            context.draw(rv, at: CGPoint(x: cgRect.minX + 12, y: textY), anchor: .leading)
            // Chevron
            var chevron = Path()
            let cx = cgRect.maxX - 16
            let cy = cgRect.midY
            chevron.move(to:    CGPoint(x: cx - 5, y: cy - 3))
            chevron.addLine(to: CGPoint(x: cx,     y: cy + 3))
            chevron.addLine(to: CGPoint(x: cx + 5, y: cy - 3))
            context.stroke(chevron, with: .color(SwiftGPUI.Color.border.swiftUIColor), lineWidth: 1.5)

        case .datePicker(let label, let displayValue):
            let path = Path(roundedRect: cgRect, cornerRadius: 6)
            context.fill(path, with: .color(SwiftGPUI.Color.surface.swiftUIColor))
            context.stroke(path, with: .color(SwiftGPUI.Color.border.swiftUIColor), lineWidth: 1)
            if let label {
                let lc = SwiftGPUI.Color(r: 0.55, g: 0.60, b: 0.75, a: 1)
                let rl = context.resolve(
                    SwiftUI.Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(lc.swiftUIColor)
                )
                context.draw(rl, at: CGPoint(x: cgRect.minX + 10, y: cgRect.minY + 8), anchor: .leading)
            }
            let textY = label != nil ? cgRect.minY + 30 : cgRect.midY
            let rv = context.resolve(
                SwiftUI.Text(displayValue)
                    .font(.system(size: 14))
                    .foregroundColor(SwiftGPUI.Color.onSurface.swiftUIColor)
            )
            context.draw(rv, at: CGPoint(x: cgRect.minX + 12, y: textY), anchor: .leading)
            // Calendar icon hint
            let ic = SwiftGPUI.Color.border.swiftUIColor
            let calX = cgRect.maxX - 28
            let calY = cgRect.midY - 8
            let calRect = CGRect(x: calX, y: calY, width: 16, height: 14)
            context.stroke(Path(roundedRect: calRect, cornerRadius: 2), with: .color(ic), lineWidth: 1)

        case .textArea(let placeholder, let label, let value):
            let path = Path(roundedRect: cgRect, cornerRadius: 6)
            context.fill(path, with: .color(SwiftGPUI.Color.surface.swiftUIColor))
            context.stroke(path, with: .color(SwiftGPUI.Color.border.swiftUIColor), lineWidth: 1)
            if let label {
                let lc = SwiftGPUI.Color(r: 0.55, g: 0.60, b: 0.75, a: 1)
                let rl = context.resolve(
                    SwiftUI.Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(lc.swiftUIColor)
                )
                context.draw(rl, at: CGPoint(x: cgRect.minX + 10, y: cgRect.minY + 8), anchor: .leading)
            }
            // Show placeholder when empty (the overlay TextEditor handles actual text)
            if value.isEmpty {
                let ph = label ?? placeholder
                let rc = context.resolve(
                    SwiftUI.Text(ph)
                        .font(.system(size: 14))
                        .foregroundColor(SwiftGPUI.Color.border.swiftUIColor)
                )
                let topPad: CGFloat = label != nil ? 24 : 12
                context.draw(rc, at: CGPoint(x: cgRect.minX + 12, y: cgRect.minY + topPad), anchor: .topLeading)
            }

        case .searchBox(let placeholder, let value):
            let path = Path(roundedRect: cgRect, cornerRadius: 22)
            context.fill(path, with: .color(SwiftGPUI.Color.surface.swiftUIColor))
            context.stroke(path, with: .color(SwiftGPUI.Color.border.swiftUIColor), lineWidth: 1)
            // Magnifying glass
            let iconX = cgRect.minX + 14
            let iconY = cgRect.midY
            let iconRect = CGRect(x: iconX - 6, y: iconY - 6, width: 12, height: 12)
            context.stroke(
                Path(ellipseIn: iconRect),
                with: .color(SwiftGPUI.Color.border.swiftUIColor),
                lineWidth: 1.5
            )
            var handle = Path()
            handle.move(to:    CGPoint(x: iconRect.maxX - 2, y: iconRect.maxY - 2))
            handle.addLine(to: CGPoint(x: iconRect.maxX + 3, y: iconRect.maxY + 3))
            context.stroke(handle, with: .color(SwiftGPUI.Color.border.swiftUIColor), lineWidth: 1.5)
            let text = value.isEmpty ? placeholder : value
            let textColor = value.isEmpty ? SwiftGPUI.Color.border : SwiftGPUI.Color.onSurface
            let rt = context.resolve(
                SwiftUI.Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(textColor.swiftUIColor)
            )
            context.draw(rt, at: CGPoint(x: cgRect.minX + 30, y: cgRect.midY), anchor: .leading)

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

extension SwiftGPUI.Color {
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
