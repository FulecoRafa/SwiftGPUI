import CoreGraphics
import Foundation
import GPUIDraw
import GPUILayout
import GPUIInterpret
import CSkia
import Observation

// MARK: - RenderLoop

@MainActor
public final class RenderLoop {

    private let interpreter = Interpreter()
    private let renderer: any Renderer
    private var windowSize: Size
    private var rootView: any View
    private var isRunning = false

    public init(
        rootView: any View,
        windowSize: Size,
        renderer: any Renderer
    ) {
        self.rootView = rootView
        self.windowSize = windowSize
        self.renderer = renderer
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleFrame()
    }

    public func stop() {
        isRunning = false
    }

    public func resize(to size: Size) {
        windowSize = size
    }

    private func scheduleFrame() {
        guard isRunning else { return }
        withObservationTracking {
            let constraint = LayoutConstraint.loose(windowSize)
            let commands = interpreter.interpret(view: rootView, constraint: constraint)
            renderer.render(commands: commands)
        } onChange: {
            Task { @MainActor [weak self] in self?.scheduleFrame() }
        }
    }
}

// MARK: - Renderer protocol

public protocol Renderer: AnyObject {
    func render(commands: [(Rect, RenderCommand)])
}

// MARK: - MockRenderer

public final class MockRenderer: Renderer {
    public private(set) var lastCommands: [(Rect, RenderCommand)] = []
    public var onRender: ([(Rect, RenderCommand)]) -> Void = { _ in }
    public init() {}
    public func render(commands: [(Rect, RenderCommand)]) {
        lastCommands = commands
        onRender(commands)
    }
}

// MARK: - SkiaRenderer
//
// Raster renderer backed by a Skia offscreen surface.
// C types (typedef void*) arrive in Swift as UnsafeMutableRawPointer?.

public final class SkiaRenderer: Renderer {

    // OpaquePointer: Swift's representation of pointers to opaque C structs.
    private let surface: OpaquePointer
    private let canvas: OpaquePointer
    public let width: Int32
    public let height: Int32

    public init(width: Int32, height: Int32, scale: Float = 1) {
        self.width  = width
        self.height = height
        guard let surf = sk_surface_new_raster_n32_premul(width, height),
              let cvs  = sk_surface_get_canvas(surf) else {
            fatalError("SkiaRenderer: failed to create raster surface (\(width)x\(height))")
        }
        surface = surf
        canvas  = cvs
        // Scale the canvas so all draw calls use point coordinates.
        if scale != 1 {
            sk_canvas_scale(canvas, scale, scale)
        }
    }

    /// Copies the current surface pixels into a CGImage (N32Premul / BGRA).
    public var cgImage: CGImage? {
        var rowBytes: Int32 = 0
        guard let pixels = sk_surface_peek_pixels(surface, &rowBytes) else { return nil }
        let byteCount = Int(rowBytes) * Int(height)
        guard
            let data     = CFDataCreate(nil, pixels.assumingMemoryBound(to: UInt8.self), byteCount),
            let provider = CGDataProvider(data: data),
            let space    = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        // kN32_SkColorType on Apple = BGRA_8888_premul
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        return CGImage(
            width: Int(width), height: Int(height),
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: Int(rowBytes),
            space: space, bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil, shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    deinit {
        sk_surface_unref(surface)
    }

    public func render(commands: [(Rect, RenderCommand)]) {
        sk_canvas_clear(canvas, 0xFF1E1E2E)
        for (frame, command) in commands {
            draw(command: command, in: frame)
        }
        sk_canvas_flush(canvas)
    }

    // MARK: - Drawing

    private func draw(command: RenderCommand, in frame: Rect) {
        switch command {

        case .roundedRect(let radius, let fill, let border, let shadow):
            if let shadow { drawShadow(frame: frame, shadow: shadow) }

            let paint = sk_paint_new()!
            sk_paint_set_color(paint, fill.skColor)
            sk_paint_set_antialias(paint, true)
            let rr = sk_rrect_new()!
            var rect = frame.skRect
            sk_rrect_set_rect_radii(rr, &rect, radius)
            sk_canvas_draw_rrect(canvas, rr, paint)
            sk_rrect_delete(rr)
            sk_paint_delete(paint)

            if let border {
                let strokePaint = sk_paint_new()!
                sk_paint_set_color(strokePaint, border.skColor)
                sk_paint_set_antialias(strokePaint, true)
                sk_paint_set_style(strokePaint, 1)       // stroke
                sk_paint_set_stroke_width(strokePaint, 1.0)
                let brr = sk_rrect_new()!
                var brect = frame.skRect
                sk_rrect_set_rect_radii(brr, &brect, radius)
                sk_canvas_draw_rrect(canvas, brr, strokePaint)
                sk_rrect_delete(brr)
                sk_paint_delete(strokePaint)
            }

        case .text(let string, let font, let color):
            let paint = sk_paint_new()!
            sk_paint_set_color(paint, color.skColor)
            sk_paint_set_antialias(paint, true)
            let style: Int32 = font.weight == .bold ? 1 : 0
            let typeface = sk_typeface_default(style) // process-lifetime cache, never freed
            let skFont = sk_font_new(typeface, font.size)!
            let baseline = frame.y + frame.height / 2 + font.size * 0.35
            sk_canvas_draw_string(canvas, string, frame.x, baseline, skFont, paint)
            sk_font_delete(skFont)
            sk_paint_delete(paint)

        case .textField(let placeholder, let label, let value, let secure, let focused):
            drawTextField(frame: frame, placeholder: placeholder,
                          label: label, value: value, secure: secure, focused: focused)

        case .button(let label, let fill, let labelColor):
            draw(command: .roundedRect(radius: 6, fill: fill), in: frame)
            let textFrame = Rect(x: frame.x + 12, y: frame.y + 10,
                                 width: frame.width - 24, height: frame.height - 20)
            draw(command: .text(label, font: .body, color: labelColor), in: textFrame)

        case .checkbox(let checked, let label):
            let boxSize: Float = 18
            let boxFrame = Rect(x: frame.x + 2, y: frame.y + (frame.height - boxSize) / 2,
                                width: boxSize, height: boxSize)
            if checked {
                draw(command: .roundedRect(radius: 4, fill: .primary), in: boxFrame)
                // Draw checkmark
                let paint = sk_paint_new()!
                sk_paint_set_color(paint, Color(r: 1, g: 1, b: 1).skColor)
                sk_paint_set_antialias(paint, true)
                sk_paint_set_style(paint, 1)
                sk_paint_set_stroke_width(paint, 2.0)
                let x = boxFrame.x
                let y = boxFrame.y
                sk_canvas_draw_line(canvas, x + 4, y + 9,  x + 7,  y + 13, paint)
                sk_canvas_draw_line(canvas, x + 7, y + 13, x + 14, y + 5,  paint)
                sk_paint_delete(paint)
            } else {
                draw(command: .roundedRect(radius: 4, fill: .surface, border: .border), in: boxFrame)
            }
            if let label {
                let textFrame = Rect(x: frame.x + boxSize + 10, y: frame.y,
                                     width: frame.width - boxSize - 10, height: frame.height)
                draw(command: .text(label, font: .body, color: .onSurface), in: textFrame)
            }

        case .radio(let selected, let label):
            // Draw as a filled/outlined circle using roundedRect with full radius
            let circleSize: Float = 18
            let circleFrame = Rect(x: frame.x + 2, y: frame.y + (frame.height - circleSize) / 2,
                                   width: circleSize, height: circleSize)
            let bgColor: Color = selected ? .primary : .surface
            draw(command: .roundedRect(radius: circleSize / 2, fill: bgColor, border: selected ? nil : .border), in: circleFrame)
            if selected {
                let innerSize: Float = 8
                let innerFrame = Rect(
                    x: circleFrame.x + (circleSize - innerSize) / 2,
                    y: circleFrame.y + (circleSize - innerSize) / 2,
                    width: innerSize, height: innerSize
                )
                draw(command: .roundedRect(radius: innerSize / 2, fill: Color(r: 1, g: 1, b: 1)), in: innerFrame)
            }
            let textFrame = Rect(x: frame.x + circleSize + 10, y: frame.y,
                                 width: frame.width - circleSize - 10, height: frame.height)
            draw(command: .text(label, font: .body, color: .onSurface), in: textFrame)

        case .select(let label, let displayValue, let placeholder):
            draw(command: .roundedRect(radius: 6, fill: .surface, border: .border), in: frame)
            drawFloatingLabel(label, frame: frame)
            let text = displayValue.isEmpty ? placeholder : displayValue
            let color: Color = displayValue.isEmpty ? .border : .onSurface
            let textY = label != nil ? frame.y + 30 : frame.y + frame.height / 2 - 7
            let textFrame = Rect(x: frame.x + 12, y: textY, width: frame.width - 40, height: 20)
            draw(command: .text(text, font: .body, color: color), in: textFrame)
            // Chevron arrow
            let arrowPaint = sk_paint_new()!
            sk_paint_set_color(arrowPaint, Color.border.skColor)
            sk_paint_set_antialias(arrowPaint, true)
            sk_paint_set_style(arrowPaint, 1)
            sk_paint_set_stroke_width(arrowPaint, 1.5)
            let ax = frame.x + frame.width - 16
            let ay = frame.y + frame.height / 2
            sk_canvas_draw_line(canvas, ax - 4, ay - 3, ax, ay + 3, arrowPaint)
            sk_canvas_draw_line(canvas, ax,     ay + 3, ax + 4, ay - 3, arrowPaint)
            sk_paint_delete(arrowPaint)

        case .datePicker(let label, let displayValue):
            draw(command: .roundedRect(radius: 6, fill: .surface, border: .border), in: frame)
            drawFloatingLabel(label, frame: frame)
            let textY = label != nil ? frame.y + 30 : frame.y + frame.height / 2 - 7
            let textFrame = Rect(x: frame.x + 12, y: textY, width: frame.width - 40, height: 20)
            draw(command: .text(displayValue, font: .body, color: .onSurface), in: textFrame)

        case .textArea(_, let label, let value):
            draw(command: .roundedRect(radius: 6, fill: .surface, border: .border), in: frame)
            drawFloatingLabel(label, frame: frame)
            if value.isEmpty, let label {
                let textFrame = Rect(x: frame.x + 12, y: frame.y + 24, width: frame.width - 24, height: 20)
                draw(command: .text(label, font: .body, color: .border), in: textFrame)
            }

        case .searchBox(let placeholder, let value):
            draw(command: .roundedRect(radius: 22, fill: .surface, border: .border), in: frame)
            // Draw placeholder only when empty; TextField overlay renders the typed value.
            if value.isEmpty {
                let textFrame = Rect(x: frame.x + 30, y: frame.y + frame.height / 2 - 7,
                                     width: frame.width - 40, height: 20)
                draw(command: .text(placeholder, font: .body, color: .border), in: textFrame)
            }
            // Magnifying glass icon
            let iconPaint = sk_paint_new()!
            sk_paint_set_color(iconPaint, Color.border.skColor)
            sk_paint_set_antialias(iconPaint, true)
            sk_paint_set_style(iconPaint, 1)
            sk_paint_set_stroke_width(iconPaint, 1.5)
            let ix = frame.x + 14
            let iy = frame.y + frame.height / 2
            // Circle
            let circleR: Float = 5
            let steps = 16
            for i in 0..<steps {
                let a0 = Float(i)     / Float(steps) * 2 * Float.pi
                let a1 = Float(i + 1) / Float(steps) * 2 * Float.pi
                sk_canvas_draw_line(canvas,
                    ix + circleR * cos(a0), iy + circleR * sin(a0),
                    ix + circleR * cos(a1), iy + circleR * sin(a1),
                    iconPaint)
            }
            // Handle
            sk_canvas_draw_line(canvas, ix + circleR * 0.7, iy + circleR * 0.7,
                                         ix + circleR * 0.7 + 4, iy + circleR * 0.7 + 4, iconPaint)
            sk_paint_delete(iconPaint)

        case .clipped(let inner, let clipRect):
            sk_canvas_save(canvas)
            var r = clipRect.skRect
            sk_canvas_clip_rect(canvas, &r)
            draw(command: inner, in: clipRect)
            sk_canvas_restore(canvas)

        case .group(let cmds):
            for cmd in cmds { draw(command: cmd, in: frame) }
        }
    }

    private func drawFloatingLabel(_ label: String?, frame: Rect) {
        guard let label else { return }
        let labelColor = Color(r: 0.55, g: 0.60, b: 0.75, a: 1)
        let labelFrame = Rect(x: frame.x + 10, y: frame.y + 8, width: frame.width - 20, height: 14)
        draw(command: .text(label, font: .label, color: labelColor), in: labelFrame)
    }

    private func drawShadow(frame: Rect, shadow: Shadow) {
        let shadowFrame = Rect(
            x: frame.x + shadow.offset.x,
            y: frame.y + shadow.offset.y,
            width: frame.width,
            height: frame.height
        )
        let paint = sk_paint_new()!
        sk_paint_set_color(paint, shadow.color.skColor)
        sk_paint_set_antialias(paint, true)
        let rr = sk_rrect_new()!
        var rect = shadowFrame.skRect
        sk_rrect_set_rect_radii(rr, &rect, 8)
        sk_canvas_draw_rrect(canvas, rr, paint)
        sk_rrect_delete(rr)
        sk_paint_delete(paint)
    }

    private func drawTextField(
        frame: Rect, placeholder: String, label: String?, value: String, secure: Bool, focused: Bool
    ) {
        let borderColor: Color = focused ? .primary : .border
        draw(command: .roundedRect(radius: 6, fill: .surface, border: borderColor), in: frame)
        if let label {
            let labelColor = Color(r: 0.55, g: 0.60, b: 0.75, a: 1)
            let labelFrame = Rect(x: frame.x + 10, y: frame.y + 4, width: frame.width - 20, height: 14)
            draw(command: .text(label, font: .label, color: labelColor), in: labelFrame)
        }
        // Native TextField overlay renders both placeholder and typed value — Skia draws shell only.
    }
}

// MARK: - Rect → sk_rect_t

private extension Rect {
    var skRect: sk_rect_t {
        sk_rect_t(left: x, top: y, right: x + width, bottom: y + height)
    }
}
