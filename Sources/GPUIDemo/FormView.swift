import SwiftGPUI

struct FormView: SwiftGPUI.View {
    let model: FormModel

    func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        Flex(direction: .vertical, gap: 16, padding: 24) {
            Card(padding: 20) {
                Input(label: "Name", binding: GPUIBinding(model, \.name))
                Input(label: "Occupation", binding: GPUIBinding(model, \.occupation))
            }
            Card(padding: 20) {
                SwiftGPUI.Text(model.greeting, font: .heading, color: .primary)
                SwiftGPUI.Text(model.subtitle, font: .body, color: .onSurface)
                Button(color: .primary) { "Submit" } onClick: { model.submit() }
            }
        }
        .layout(node: node, constraint: constraint)
    }
}
