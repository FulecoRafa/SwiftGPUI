import Testing
import GPUIDraw
import GPUILayout

@Suite("YogaNode stub layout")
struct YogaNodeTests {

    @Test("single child respeita padding")
    func singleChildWithPadding() {
        let root = YogaNode()
        root.setPadding(16)
        let child = YogaNode()
        child.setHeight(44)
        root.addChild(child)

        let constraint = LayoutConstraint.loose(Size(width: 320, height: 600))
        let frames = root.calculateLayout(constraint: constraint)

        // frame do filho deve começar em (padding, padding)
        let childFrame = frames[1]
        #expect(childFrame.x == 16)
        #expect(childFrame.y == 16)
        #expect(childFrame.height == 44)
    }

    @Test("dois filhos ficam empilhados com gap")
    func twoChildrenWithGap() {
        let root = YogaNode()
        root.setPadding(0)
        root.setGap(8)

        let c1 = YogaNode(); c1.setHeight(44); root.addChild(c1)
        let c2 = YogaNode(); c2.setHeight(44); root.addChild(c2)

        let frames = root.calculateLayout(
            constraint: .loose(Size(width: 320, height: 600))
        )

        let f1 = frames[1]
        let f2 = frames[2]
        #expect(f1.y == 0)
        #expect(f2.y == 44 + 8)
    }
}
