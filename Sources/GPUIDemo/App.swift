import SwiftGPUI
import GPUIPlatformMacOS

@main
struct FormDemoApp: GPUIDesktopApp {
    let model = FormModel()

    var windowTitle: String { "GPUI Form Demo" }
    var windowMinSize: Size { Size(width: 480, height: 520) }

    var rootView: any SwiftGPUI.View {
        FormView(model: model)
    }
}
