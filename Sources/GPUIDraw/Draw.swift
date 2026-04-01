// GPUIDraw — Tipos primitivos de desenho.
// Sem dependências externas. Pode ser importado por qualquer camada.

// MARK: - Geometria

public struct Point: Sendable {
    public var x: Float
    public var y: Float
    public init(x: Float = 0, y: Float = 0) {
        self.x = x; self.y = y
    }
}

public struct Size: Sendable {
    public var width: Float
    public var height: Float
    public static let zero = Size(width: 0, height: 0)
    public init(width: Float, height: Float) {
        self.width = width; self.height = height
    }
}

public struct Rect: Sendable {
    public var origin: Point
    public var size: Size

    public var x: Float { origin.x }
    public var y: Float { origin.y }
    public var width: Float { size.width }
    public var height: Float { size.height }
    public var maxX: Float { x + width }
    public var maxY: Float { y + height }

    public static let zero = Rect(x: 0, y: 0, width: 0, height: 0)

    public init(x: Float, y: Float, width: Float, height: Float) {
        self.origin = Point(x: x, y: y)
        self.size = Size(width: width, height: height)
    }
}

// MARK: - Cor

public struct Color: Sendable {
    public var r: Float  // 0…1
    public var g: Float
    public var b: Float
    public var a: Float

    public init(r: Float, g: Float, b: Float, a: Float = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// Converte para 0xAARRGGBB esperado pelo Skia
    public var skColor: UInt32 {
        let aa = UInt32(a * 255) & 0xFF
        let rr = UInt32(r * 255) & 0xFF
        let gg = UInt32(g * 255) & 0xFF
        let bb = UInt32(b * 255) & 0xFF
        return (aa << 24) | (rr << 16) | (gg << 8) | bb
    }

    // Paleta semântica — substituir por tokens de design
    public static let primary   = Color(r: 0.38, g: 0.47, b: 1.00)
    public static let surface   = Color(r: 0.15, g: 0.15, b: 0.20)
    public static let onSurface = Color(r: 0.90, g: 0.90, b: 0.95)
    public static let border    = Color(r: 0.30, g: 0.30, b: 0.38)
    public static let clear     = Color(r: 0, g: 0, b: 0, a: 0)
}

// MARK: - Tipografia

public struct Font: Sendable {
    public var family: String
    public var size: Float
    public var weight: Weight

    public enum Weight: Sendable { case regular, medium, bold }

    public static let body    = Font(family: "Inter", size: 14, weight: .regular)
    public static let label   = Font(family: "Inter", size: 12, weight: .medium)
    public static let heading = Font(family: "Inter", size: 18, weight: .bold)

    public init(family: String, size: Float, weight: Weight = .regular) {
        self.family = family; self.size = size; self.weight = weight
    }
}

// MARK: - Sombra

public struct Shadow: Sendable {
    public var offset: Point
    public var blur: Float
    public var color: Color

    public static let card = Shadow(
        offset: Point(x: 0, y: 4),
        blur: 12,
        color: Color(r: 0, g: 0, b: 0, a: 0.35)
    )
}

// MARK: - RenderCommand
//
// Lista plana de primitivas que o SkiaRenderer sabe desenhar.
// O Interpret layer produz essa lista; o Observe layer a consome.

public indirect enum RenderCommand: Sendable {
    /// Retângulo com cantos arredondados, opcionalmente com sombra.
    case roundedRect(
        radius: Float,
        fill: Color,
        border: Color? = nil,
        shadow: Shadow? = nil
    )

    /// Texto simples.
    case text(String, font: Font, color: Color)

    /// Campo de texto (label flutuante + placeholder + borda).
    case textField(
        placeholder: String,
        label: String?,
        value: String,
        secure: Bool,
        focused: Bool
    )

    /// Botão com fundo colorido e label.
    case button(label: String, fill: Color, labelColor: Color)

    /// Clipa o conteúdo ao rect antes de desenhar.
    case clipped(RenderCommand, to: Rect)

    /// Grupo de comandos desenhado em ordem.
    case group([RenderCommand])
}
