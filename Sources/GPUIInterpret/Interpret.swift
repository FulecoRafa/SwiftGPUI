import GPUIDraw
import GPUILayout

// MARK: - View protocol

public protocol View {
    /// Produz o LayoutNode (com frame e RenderCommand) para este componente.
    func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode
}

// MARK: - ViewBuilder (result builder)

@resultBuilder
public struct ViewBuilder {
    public static func buildBlock(_ views: any View...) -> [any View] { views }
    public static func buildBlock(_ views: [any View]) -> [any View] { views }
    public static func buildOptional(_ view: (any View)?) -> [any View] {
        view.map { [$0] } ?? []
    }
    public static func buildEither(first: any View) -> any View { first }
    public static func buildEither(second: any View) -> any View { second }
    public static func buildArray(_ views: [[any View]]) -> [any View] {
        views.flatMap { $0 }
    }
}

// MARK: - Traversal
//
// Percorre a árvore de LayoutNode e produz uma lista plana de
// (Rect, RenderCommand) ordenada por pintura (parents primeiro).

public struct Interpreter {
    public init() {}

    public func collect(_ node: LayoutNode) -> [(Rect, RenderCommand)] {
        var result: [(Rect, RenderCommand)] = [(node.frame, node.renderCommand)]
        for child in node.children {
            result.append(contentsOf: collect(child))
        }
        return result
    }

    /// Conveniência: layout + collect em uma chamada.
    public func interpret(
        view: any View,
        constraint: LayoutConstraint
    ) -> [(Rect, RenderCommand)] {
        let rootNode = YogaNode()
        let layoutNode = view.layout(node: rootNode, constraint: constraint)
        return collect(layoutNode)
    }
}
