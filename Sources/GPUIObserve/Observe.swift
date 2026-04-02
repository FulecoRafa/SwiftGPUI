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

    public init(width: Int32, height: Int32) {
        guard let surf = sk_surface_new_raster_n32_premul(width, height),
              let cvs  = sk_surface_get_canvas(surf) else {
            fatalError("SkiaRenderer: failed to create raster surface (\(width)x\(height))")
        }
        surface = surf
        canvas  = cvs
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
            let skFont = sk_font_new(nil, font.size)!
            sk_canvas_draw_string(canvas, string, frame.x, frame.y + font.size, skFont, paint)
            sk_font_delete(skFont)
            sk_paint_delete(paint)

        case .textField(let placeholder, let label, _, let secure, let focused):
            drawTextField(frame: frame, placeholder: placeholder,
                          label: label, secure: secure, focused: focused)

        case .button(let label, let fill, let labelColor):
            draw(command: .roundedRect(radius: 6, fill: fill), in: frame)
            let textFrame = Rect(x: frame.x + 12, y: frame.y + 10,
                                 width: frame.width - 24, height: frame.height - 20)
            draw(command: .text(label, font: .body, color: labelColor), in: textFrame)

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
        frame: Rect, placeholder: String, label: String?, secure: Bool, focused: Bool
    ) {
        let borderColor: Color = focused ? .primary : .border
        draw(command: .roundedRect(radius: 4, fill: .surface, border: borderColor), in: frame)
        if let label {
            let labelFrame = Rect(x: frame.x + 8, y: frame.y - 10, width: 200, height: 16)
            draw(command: .text(label, font: .label, color: .onSurface), in: labelFrame)
        }
        let text = secure ? String(repeating: "•", count: 8) : placeholder
        let textFrame = Rect(x: frame.x + 12, y: frame.y + 12,
                             width: frame.width - 24, height: frame.height - 24)
        draw(command: .text(text, font: .body, color: .onSurface), in: textFrame)
    }
}

// MARK: - Rect → sk_rect_t

private extension Rect {
    var skRect: sk_rect_t {
        sk_rect_t(left: x, top: y, right: x + width, bottom: y + height)
    }
}
