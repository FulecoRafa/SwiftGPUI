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

        let innerWidth = constraint.available.width - padding * 2
        let childConstraint = LayoutConstraint.loose(
            Size(width: innerWidth, height: constraint.available.height)
        )
        let childNodes: [LayoutNode] = children.map { child in
            let childYoga = YogaNode()
            node.addChild(childYoga)
            return child.layout(node: childYoga, constraint: childConstraint)
        }

        let frames = node.calculateLayout(constraint: constraint)
        let selfFrame = frames.first ?? .zero

        let positioned: [LayoutNode] = childNodes.enumerated().map { i, childNode in
            guard i + 1 < frames.count else { return childNode }
            let target = frames[i + 1]
            return childNode.offsetted(x: target.x - childNode.frame.x,
                                       y: target.y - childNode.frame.y)
        }

        return LayoutNode(
            frame: selfFrame,
            renderCommand: .roundedRect(
                radius: cornerRadius,
                fill: .surface,
                border: .border,
                shadow: .card
            ),
            children: positioned
        )
    }
}

// MARK: - Input

public struct Input: View {
    public enum Style { case text, password, email }

    private let label: String?
    private let placeholder: String
    private let style: Style
    private let binding: GPUIBinding<String>?

    /// Bind to a GPUIBinding — the platform renderer wires this to a native text field.
    public init(label: String? = nil, _ style: Style = .text, binding: GPUIBinding<String>) {
        self.label = label
        self.style = style
        self.placeholder = ""
        self.binding = binding
    }

    /// Read-only display (no editing).
    public init(label: String? = nil, _ style: Style = .text, value: String = "") {
        self.label = label
        self.style = style
        self.placeholder = value
        self.binding = nil
    }

    public func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        node.setHeight(52)
        // Leaf: do not call calculateLayout — the parent container owns that call.
        // Return a preliminary frame; the parent will reposition via offsetted().
        let frame = Rect(x: 0, y: 0, width: constraint.available.width, height: 52)
        return LayoutNode(
            frame: frame,
            renderCommand: .textField(
                placeholder: placeholder.isEmpty ? (label ?? "") : placeholder,
                label: label,
                value: binding?.value ?? placeholder,
                secure: style == .password,
                focused: false
            ),
            interaction: binding.map {
                .textInput(binding: $0, placeholder: placeholder.isEmpty ? (label ?? "") : placeholder)
            }
        )
    }
}

// MARK: - Flex

public struct Flex: View {
    public enum Direction { case horizontal, vertical }

    private let direction: Direction
    private let gap: Float
    private let padding: Float
    private let children: [any View]

    public init(
        direction: Direction = .vertical,
        gap: Float = 8,
        padding: Float = 0,
        @ViewBuilder content: () -> [any View]
    ) {
        self.direction = direction
        self.gap = gap
        self.padding = padding
        self.children = content()
    }

    public func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        node.setFlexDirection(direction == .horizontal ? .row : .column)
        node.setGap(gap)
        node.setPadding(padding)

        let innerWidth = constraint.available.width - padding * 2
        let childConstraint = LayoutConstraint.loose(
            Size(width: innerWidth, height: constraint.available.height)
        )
        let childNodes: [LayoutNode] = children.map { child in
            let childYoga = YogaNode()
            node.addChild(childYoga)
            return child.layout(node: childYoga, constraint: childConstraint)
        }

        let frames = node.calculateLayout(constraint: constraint)
        let frame = frames.first ?? .zero

        let positioned: [LayoutNode] = childNodes.enumerated().map { i, childNode in
            guard i + 1 < frames.count else { return childNode }
            let target = frames[i + 1]
            return childNode.offsetted(x: target.x - childNode.frame.x,
                                       y: target.y - childNode.frame.y)
        }

        return LayoutNode(
            frame: frame,
            renderCommand: .group([]),
            children: positioned
        )
    }
}

// MARK: - Button

public struct Button: View {
    public enum Color { case `default`, primary, destructive }

    private let colorStyle: Color
    private let label: String
    private let action: (() -> Void)?

    public init(color: Color = .default, label: () -> String, onClick: (() -> Void)? = nil) {
        self.colorStyle = color
        self.action = onClick
        self.label = label()
    }

    public func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        node.setHeight(44)
        // Leaf: parent container owns the calculateLayout call.
        let frame = Rect(x: 0, y: 0, width: constraint.available.width, height: 44)

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
            renderCommand: .button(label: label, fill: fillColor, labelColor: labelColor),
            interaction: action.map { .tap($0) }
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
        let h = Float(font.size) + 8
        node.setHeight(h)
        // Leaf: parent container owns the calculateLayout call.
        let frame = Rect(x: 0, y: 0, width: constraint.available.width, height: h)
        return LayoutNode(
            frame: frame,
            renderCommand: .text(content, font: font, color: color)
        )
    }
}
