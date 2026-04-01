// SwiftGPUI — API pública de componentes.
// Re-exporta os módulos internos e define os componentes de alto nível
// que o usuário escreve (Card, Input, Flex, Button…).

@_exported import GPUIDraw
@_exported import GPUILayout
@_exported import GPUIInterpret
@_exported import GPUIObserve

// MARK: - Card

public struct Card: View {
    private let children: [any View]
    private let padding: Float
    private let cornerRadius: Float

    public init(
        padding: Float = 16,
        cornerRadius: Float = 12,
        @ViewBuilder content: () -> [any View]
    ) {
        self.children = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    public func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        node.setFlexDirection(.column)
        node.setPadding(padding)
        node.setGap(12)

        let childNodes: [LayoutNode] = children.map { child in
            let childYoga = YogaNode()
            node.addChild(childYoga)
            return child.layout(node: childYoga, constraint: constraint)
        }

        let frames = node.calculateLayout(constraint: constraint)
        let selfFrame = frames.first ?? .zero

        return LayoutNode(
            frame: selfFrame,
            renderCommand: .roundedRect(
                radius: cornerRadius,
                fill: .surface,
                shadow: .card
            ),
            children: childNodes
        )
    }
}

// MARK: - Input

public struct Input: View {
    public enum Style { case text, password, email }

    private let label: String?
    private let placeholder: String
    private let style: Style
    private let value: String

    public init(
        label: String? = nil,
        _ style: Style = .text,
        value: String = "",
        @ViewBuilder placeholder: () -> String = { "" }
    ) {
        self.label = label
        self.style = style
        self.value = value
        self.placeholder = placeholder()
    }

    /// Conveniência para `Input(label:)` sem placeholder builder.
    public init(label: String? = nil, _ style: Style = .text, value: String = "") {
        self.label = label
        self.style = style
        self.value = value
        self.placeholder = ""
    }

    public func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        node.setHeight(52)

        let frames = node.calculateLayout(constraint: constraint)
        let frame = frames.first ?? .zero

        return LayoutNode(
            frame: frame,
            renderCommand: .textField(
                placeholder: placeholder.isEmpty ? (label ?? "") : placeholder,
                label: label,
                value: value,
                secure: style == .password,
                focused: false
            )
        )
    }
}

// MARK: - Flex

public struct Flex: View {
    public enum Direction { case horizontal, vertical }

    private let direction: Direction
    private let gap: Float
    private let children: [any View]

    public init(
        direction: Direction = .vertical,
        gap: Float = 8,
        @ViewBuilder content: () -> [any View]
    ) {
        self.direction = direction
        self.gap = gap
        self.children = content()
    }

    public func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        node.setFlexDirection(direction == .horizontal ? .row : .column)
        node.setGap(gap)

        let childNodes: [LayoutNode] = children.map { child in
            let childYoga = YogaNode()
            node.addChild(childYoga)
            return child.layout(node: childYoga, constraint: constraint)
        }

        let frames = node.calculateLayout(constraint: constraint)
        let frame = frames.first ?? .zero

        return LayoutNode(
            frame: frame,
            renderCommand: .group([]),
            children: childNodes
        )
    }
}

// MARK: - Button

public struct Button: View {
    public enum Color { case `default`, primary, destructive }

    private let colorStyle: Color
    private let label: String

    public init(color: Color = .default, @ViewBuilder label: () -> String) {
        self.colorStyle = color
        self.label = label()
    }

    public func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        node.setHeight(44)

        let frames = node.calculateLayout(constraint: constraint)
        let frame = frames.first ?? .zero

        let fillColor: GPUIDraw.Color
        let labelColor: GPUIDraw.Color

        switch colorStyle {
        case .default:
            fillColor  = GPUIDraw.Color(r: 0.20, g: 0.20, b: 0.26)
            labelColor = .onSurface
        case .primary:
            fillColor  = .primary
            labelColor = GPUIDraw.Color(r: 1, g: 1, b: 1)
        case .destructive:
            fillColor  = GPUIDraw.Color(r: 0.85, g: 0.20, b: 0.20)
            labelColor = GPUIDraw.Color(r: 1, g: 1, b: 1)
        }

        return LayoutNode(
            frame: frame,
            renderCommand: .button(label: label, fill: fillColor, labelColor: labelColor)
        )
    }
}

// MARK: - Text

public struct Text: View {
    private let content: String
    private let font: Font
    private let color: GPUIDraw.Color

    public init(
        _ content: String,
        font: Font = .body,
        color: GPUIDraw.Color = .onSurface
    ) {
        self.content = content
        self.font = font
        self.color = color
    }

    public func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        node.setHeight(Float(font.size) + 8)
        let frames = node.calculateLayout(constraint: constraint)
        return LayoutNode(
            frame: frames.first ?? .zero,
            renderCommand: .text(content, font: font, color: color)
        )
    }
}
