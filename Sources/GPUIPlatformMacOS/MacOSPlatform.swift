import SwiftUI
import AppKit
import SwiftGPUI

// MARK: - GPUIDesktopApp

/// Conform your @main struct to this protocol instead of SwiftUI.App.
///
/// Usage:
///   @main
///   struct MyApp: GPUIDesktopApp {
///       var rootView: any SwiftGPUI.View { Text("Hello") }
///   }
public protocol GPUIDesktopApp: SwiftUI.App {
    var rootView: any SwiftGPUI.View { get }
    var windowTitle: String { get }
    var windowMinSize: CGSize { get }
}

extension GPUIDesktopApp {
    public var windowTitle: String { "SwiftGPUI" }
    public var windowMinSize: CGSize { CGSize(width: 300, height: 200) }

    public var body: some SwiftUI.Scene {
        WindowGroup(windowTitle) {
            GPUICanvas(root: rootView)
                .frame(minWidth: windowMinSize.width, minHeight: windowMinSize.height)
                .background(WindowConfigurator())
        }
    }
}

// MARK: - GPUICanvas

/// Thin SwiftUI view: owns the Canvas surface and delegates all drawing
/// to SwiftUIRenderer. SwiftUI is only responsible for the window/canvas
/// lifecycle — no rendering logic lives here.
public struct GPUICanvas: SwiftUI.View {
    private let root: any SwiftGPUI.View

    public init(root: any SwiftGPUI.View) {
        self.root = root
    }

    public var body: some SwiftUI.View {
        Canvas { context, size in
            let constraint = LayoutConstraint.loose(
                Size(width: Float(size.width), height: Float(size.height))
            )
            let commands = Interpreter().interpret(view: root, constraint: constraint)
            SwiftUIRenderer.draw(commands: commands, into: &context)
        }
        .background(SwiftUI.Color(red: 0.12, green: 0.12, blue: 0.18))
    }
}

// MARK: - WindowConfigurator

/// NSViewRepresentable shim that configures the hosting NSWindow:
///   - ensures the window is resizable
///   - terminates the app when the window is closed
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.styleMask.insert(.resizable)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { _ in
                NSApplication.shared.terminate(nil)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
