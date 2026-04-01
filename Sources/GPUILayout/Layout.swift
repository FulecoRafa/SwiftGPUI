import GPUIDraw

// MARK: - LayoutNode
//
// Resultado do cálculo de layout: frame absoluto na janela
// e o comando de renderização associado a esse nó.

public struct LayoutNode: Sendable {
    public var frame: Rect
    public var renderCommand: RenderCommand
    public var children: [LayoutNode]

    public init(
        frame: Rect,
        renderCommand: RenderCommand,
        children: [LayoutNode] = []
    ) {
        self.frame = frame
        self.renderCommand = renderCommand
        self.children = children
    }
}

// MARK: - Constraints

public struct LayoutConstraint: Sendable {
    public var available: Size
    public var minSize: Size
    public var maxSize: Size

    public static func tight(_ size: Size) -> Self {
        Self(available: size, minSize: size, maxSize: size)
    }

    public static func loose(_ size: Size) -> Self {
        Self(available: size, minSize: .zero, maxSize: size)
    }
}

// MARK: - YogaNode
//
// Wrapper Swift sobre a API C do Yoga.
// Encapsula YGNodeRef e expõe uma interface com value semantics.
// Quando a lib Yoga real estiver linkada, basta descomentar as
// chamadas e remover os stubs de fallback.

public final class YogaNode {

    // Em produção: private let ref: YGNodeRef = YGNodeNew()
    private var _flexDirection: FlexDirection = .column
    private var _padding: Float = 0
    private var _gap: Float = 0
    private var _width: Float? = nil
    private var _height: Float? = nil
    private var _children: [YogaNode] = []

    public enum FlexDirection { case row, column }

    public init() {}

    public func setFlexDirection(_ d: FlexDirection) { _flexDirection = d }
    public func setPadding(_ value: Float)            { _padding = value  }
    public func setGap(_ value: Float)                { _gap = value      }
    public func setWidth(_ value: Float)              { _width = value    }
    public func setHeight(_ value: Float)             { _height = value   }

    public func addChild(_ child: YogaNode) {
        _children.append(child)
    }

    /// Calcula o layout dentro do constraint dado.
    /// Retorna frames absolutos para self e todos os descendentes.
    public func calculateLayout(constraint: LayoutConstraint) -> [Rect] {
        // ── Stub de layout manual ────────────────────────────────────
        // Quando o Yoga real estiver linkado, substitua por:
        //   YGNodeCalculateLayout(ref, constraint.available.width,
        //                         constraint.available.height, YGDirectionLTR)
        // e leia os resultados com YGNodeLayoutGet*(ref).
        //
        // Por ora: stack linear simples que respeita padding e gap.

        let w = _width  ?? constraint.available.width
        let p = _padding
        let g = _gap

        var frames: [Rect] = []
        var cursor: Float = p

        for child in _children {
            let childConstraint = LayoutConstraint.loose(
                Size(width: w - p * 2, height: constraint.available.height)
            )
            let childFrames = child.calculateLayout(constraint: childConstraint)
            let childH = child._height ?? 44  // altura padrão se não especificada

            let childFrame = Rect(x: p, y: cursor, width: w - p * 2, height: childH)
            frames.append(childFrame)

            // frames dos netos (offset relativo ao filho)
            for var sub in childFrames.dropFirst() {
                sub.origin.x += childFrame.x
                sub.origin.y += childFrame.y
                frames.append(sub)
            }

            cursor += childH + g
        }

        let selfH = _height ?? (cursor + p)
        let selfFrame = Rect(x: 0, y: 0, width: w, height: selfH)
        return [selfFrame] + frames
    }
}
