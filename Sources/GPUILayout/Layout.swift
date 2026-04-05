import Foundation
import GPUIDraw
import CYoga

// MARK: - LayoutNode
//
// Result of layout calculation: absolute frame in window coordinates
// plus the associated render command for this node.

// MARK: - Interaction

public enum Interaction: @unchecked Sendable {
    case textInput(binding: GPUIBinding<String>, placeholder: String, secure: Bool = false, leadingInset: CGFloat = 12)
    case textArea(binding: GPUIBinding<String>, placeholder: String)
    case tap(() -> Void)
    case selectPick(options: [String], selectedIndex: Int, onSelect: (Int) -> Void)
    case datePick(get: () -> Date, set: (Date) -> Void)
}

// MARK: - LayoutNode

public struct LayoutNode: @unchecked Sendable {
    public var frame: Rect
    public var renderCommand: RenderCommand
    public var children: [LayoutNode]
    public var interaction: Interaction?

    public init(
        frame: Rect,
        renderCommand: RenderCommand,
        children: [LayoutNode] = [],
        interaction: Interaction? = nil
    ) {
        self.frame = frame
        self.renderCommand = renderCommand
        self.children = children
        self.interaction = interaction
    }
}

extension LayoutNode {
    /// Recursively shifts this node and all its descendants by (dx, dy).
    /// Used by container components to apply the parent-computed absolute
    /// position to a child subtree that was laid out in local (0,0) space.
    public func offsetted(x dx: Float, y dy: Float) -> LayoutNode {
        var copy = self
        copy.frame = Rect(x: frame.x + dx, y: frame.y + dy,
                          width: frame.width, height: frame.height)
        copy.children = children.map { $0.offsetted(x: dx, y: dy) }
        return copy
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
// Swift wrapper around the Yoga C API (YGNode*).
// Each instance owns a YGNodeRef and frees it on deinit.

public final class YogaNode {

    private let ref: YGNodeRef

    public enum FlexDirection { case row, column }

    public init() {
        ref = YGNodeNew()
    }

    deinit {
        YGNodeFree(ref)
    }

    public func setFlexDirection(_ d: FlexDirection) {
        let yg: YGFlexDirection = d == .row ? YGFlexDirectionRow : YGFlexDirectionColumn
        YGNodeStyleSetFlexDirection(ref, yg)
    }

    public func setPadding(_ value: Float) {
        YGNodeStyleSetPadding(ref, YGEdgeAll, value)
    }

    public func setGap(_ value: Float) {
        YGNodeStyleSetGap(ref, YGGutterAll, value)
    }

    public func setWidth(_ value: Float) {
        YGNodeStyleSetWidth(ref, value)
    }

    public func setHeight(_ value: Float) {
        YGNodeStyleSetHeight(ref, value)
    }

    public func addChild(_ child: YogaNode) {
        let index = YGNodeGetChildCount(ref)
        YGNodeInsertChild(ref, child.ref, index)
        // Retain child so it isn't freed before the parent finishes layout.
        _children.append(child)
    }

    /// Calculates layout and returns frames for self followed by each child,
    /// in the same order they were added via addChild(_:).
    public func calculateLayout(constraint: LayoutConstraint) -> [Rect] {
        // Pass Float.nan (= YGUndefined) for height so Yoga sizes containers
        // to their content rather than stretching to fill the available height.
        // Width is constrained so items wrap/clip correctly.
        YGNodeCalculateLayout(
            ref,
            constraint.available.width,
            Float.nan,
            YGDirectionLTR
        )

        let selfFrame = Rect(
            x: YGNodeLayoutGetLeft(ref),
            y: YGNodeLayoutGetTop(ref),
            width: YGNodeLayoutGetWidth(ref),
            height: YGNodeLayoutGetHeight(ref)
        )

        let childFrames: [Rect] = _children.map { child in
            Rect(
                x: YGNodeLayoutGetLeft(child.ref),
                y: YGNodeLayoutGetTop(child.ref),
                width: YGNodeLayoutGetWidth(child.ref),
                height: YGNodeLayoutGetHeight(child.ref)
            )
        }

        return [selfFrame] + childFrames
    }

    // Keeps children alive for the lifetime of this node.
    private var _children: [YogaNode] = []
}
