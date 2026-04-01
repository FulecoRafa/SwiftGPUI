import GPUIDraw
import GPUILayout
import GPUIInterpret
import Observation

// MARK: - RenderLoop
//
// Gerencia o ciclo de atualização:
//   1. Chama Interpreter para obter a lista de RenderCommands
//   2. Passa para o SkiaRenderer (ou mock) para desenhar
//   3. Usa withObservationTracking para detectar mudanças de estado
//      e agendar um novo frame automaticamente

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

    // MARK: Private

    private func scheduleFrame() {
        guard isRunning else { return }

        withObservationTracking {
            // Qualquer acesso a @Observable durante layout/interpret
            // registra dependência automaticamente.
            let constraint = LayoutConstraint.loose(windowSize)
            let commands = interpreter.interpret(
                view: rootView,
                constraint: constraint
            )
            renderer.render(commands: commands)
        } onChange: {
            // Chamado na thread de observação — volta pra MainActor.
            Task { @MainActor [weak self] in
                self?.scheduleFrame()
            }
        }
    }
}

// MARK: - Renderer protocol
//
// Abstração sobre o backend de renderização.
// Implementações concretas: SkiaRenderer (produção), MockRenderer (testes).

public protocol Renderer: AnyObject {
    func render(commands: [(Rect, RenderCommand)])
}

// MARK: - MockRenderer
//
// Útil para testes e para rodar sem a lib Skia linkada.

public final class MockRenderer: Renderer {
    public private(set) var lastCommands: [(Rect, RenderCommand)] = []
    public var onRender: ([(Rect, RenderCommand)]) -> Void = { _ in }

    public init() {}

    public func render(commands: [(Rect, RenderCommand)]) {
        lastCommands = commands
        onRender(commands)
    }
}

// MARK: - SkiaRenderer (stub)
//
// Quando o Skia estiver linkado, descomente as chamadas sk_* e
// remova os comentários de stub.

public final class SkiaRenderer: Renderer {

    // private let surface: OpaquePointer   // sk_surface_t*
    // private let canvas: OpaquePointer    // sk_canvas_t*

    public init(width: Int32, height: Int32) {
        // surface = sk_surface_new_raster_n32_premul(width, height)
        // canvas  = sk_surface_get_canvas(surface)
    }

    public func render(commands: [(Rect, RenderCommand)]) {
        // sk_canvas_clear(canvas, 0xFF1E1E2E)

        for (frame, command) in commands {
            draw(command: command, in: frame)
        }

        // sk_canvas_flush(canvas)
    }

    // MARK: Private drawing

    private func draw(command: RenderCommand, in frame: Rect) {
        switch command {

        case .roundedRect(let radius, let fill, let border, let shadow):
            if let shadow {
                drawShadow(frame: frame, shadow: shadow)
            }
            // let paint = sk_paint_new()
            // sk_paint_set_color(paint, fill.skColor)
            // sk_paint_set_antialias(paint, true)
            // let rrect = sk_rrect_new()
            // sk_rrect_set_rect_radii(rrect, frame.skRect, radius)
            // sk_canvas_draw_rrect(canvas, rrect, paint)
            _ = (radius, fill, border)  // evitar warnings no stub

        case .text(let string, let font, let color):
            // let paint = sk_paint_new()
            // sk_paint_set_color(paint, color.skColor)
            // let skFont = sk_font_new(typeface(for: font), font.size)
            // sk_canvas_draw_string(canvas, string, frame.x, frame.maxY, skFont, paint)
            _ = (string, font, color)

        case .textField(let placeholder, let label, _, let secure, let focused):
            drawTextField(frame: frame, placeholder: placeholder,
                          label: label, secure: secure, focused: focused)

        case .button(let label, let fill, let labelColor):
            draw(command: .roundedRect(radius: 6, fill: fill), in: frame)
            let textFrame = Rect(
                x: frame.x + 12, y: frame.y + 10,
                width: frame.width - 24, height: frame.height - 20
            )
            draw(command: .text(label, font: .body, color: labelColor), in: textFrame)

        case .clipped(let inner, let clipRect):
            // sk_canvas_save(canvas)
            // sk_canvas_clip_rect(canvas, clipRect.skRect)
            draw(command: inner, in: clipRect)
            // sk_canvas_restore(canvas)

        case .group(let cmds):
            for cmd in cmds { draw(command: cmd, in: frame) }
        }
    }

    private func drawShadow(frame: Rect, shadow: Shadow) {
        // Implementar com sk_paint + blur mask filter
        _ = (frame, shadow)
    }

    private func drawTextField(
        frame: Rect,
        placeholder: String,
        label: String?,
        secure: Bool,
        focused: Bool
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
