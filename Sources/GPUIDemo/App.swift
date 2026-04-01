import SwiftUI
import AppKit
import SwiftGPUI

@main
struct HelloWorldApp: SwiftUI.App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some SwiftUI.Scene {
        WindowGroup("SwiftGPUI") {
            HelloWorldCanvas()
                .background(FloatingWindowSetter())
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Reaches into the NSWindow hierarchy and pins the window level to .floating.
private struct FloatingWindowSetter: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.level = .floating
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct HelloWorldCanvas: SwiftUI.View {
    var body: some SwiftUI.View {
        Canvas { context, size in
            let root: any SwiftGPUI.View = SwiftGPUI.Text(
                "Hello, World!",
                font: .heading,
                color: .primary
            )
            let constraint = LayoutConstraint.loose(
                Size(width: Float(size.width), height: Float(size.height))
            )
            let commands = Interpreter().interpret(view: root, constraint: constraint)

            for (frame, command) in commands {
                guard case .text(let str, let font, let color) = command else { continue }

                let cgRect = CGRect(
                    x: CGFloat(frame.x), y: CGFloat(frame.y),
                    width: CGFloat(frame.width), height: CGFloat(frame.height)
                )
                let swiftColor = SwiftUI.Color(
                    red: Double(color.r),
                    green: Double(color.g),
                    blue: Double(color.b),
                    opacity: Double(color.a)
                )
                let swiftWeight: SwiftUI.Font.Weight
                switch font.weight {
                case .bold:    swiftWeight = .bold
                case .medium:  swiftWeight = .medium
                case .regular: swiftWeight = .regular
                }

                let resolved = context.resolve(
                    SwiftUI.Text(str)
                        .font(.system(size: CGFloat(font.size), weight: swiftWeight))
                        .foregroundColor(swiftColor)
                )
                context.draw(resolved, in: cgRect)
            }
        }
        .frame(width: 400, height: 300)
        .background(SwiftUI.Color(red: 0.12, green: 0.12, blue: 0.18))
    }
}
