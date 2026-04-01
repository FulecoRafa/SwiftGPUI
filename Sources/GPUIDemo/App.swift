import SwiftGPUI
import GPUIPlatformMacOS

@main
struct HelloWorldApp: GPUIDesktopApp {
    var rootView: any SwiftGPUI.View {
        SwiftGPUI.Text("Hello, World!", font: .heading, color: .primary)
    }
}
