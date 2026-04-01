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
    var windowMinSize: Size { get }
}

extension GPUIDesktopApp {
    public var windowTitle: String { "SwiftGPUI" }
    public var windowMinSize: Size { Size(width: 300, height: 200) }

    public var body: some SwiftUI.Scene {
        WindowGroup(windowTitle) {
            GPUICanvas(root: rootView)
                .frame(minWidth: CGFloat(windowMinSize.width), minHeight: CGFloat(windowMinSize.height))
                .background(WindowConfigurator())
        }
    }
}

// MARK: - GPUICanvas

/// The only SwiftUI surface. Everything visible is drawn by SwiftUIRenderer
/// onto a GraphicsContext — no SwiftUI views are composed for rendering.
///
/// The only exception are transparent TextField overlays: these are invisible
/// to the user (background/border come from the canvas), but they give the OS
/// a native text input target so the user can type. When Skia is linked, the
/// Canvas call is replaced by a Skia surface; the overlay pattern stays the same.
public struct GPUICanvas: SwiftUI.View {
    private let root: any SwiftGPUI.View

    public init(root: any SwiftGPUI.View) {
        self.root = root
    }

    public var body: some SwiftUI.View {
        GeometryReader { geo in
            let (commands, interactions) = layout(size: geo.size)

            ZStack(alignment: .topLeading) {
                // ── All rendering happens here ──────────────────────────
                Canvas { context, _ in
                    SwiftUIRenderer.draw(commands: commands, into: &context)
                }

                // ── Transparent input capture overlays ──────────────────
                // Invisible to the user — the canvas draws the visual shell.
                // Each overlay captures keystrokes for one textInput interaction.
                ForEach(Array(interactions.enumerated()), id: \.offset) { _, pair in
                    let (frame, interaction) = pair
                    // .position() sets the view's centre in the parent coordinate space,
                    // which correctly moves both the visual frame AND the hit-test region.
                    // .offset() only moves the visual frame — clicks still land at (0,0).
                    let centre = CGPoint(
                        x: CGFloat(frame.x) + CGFloat(frame.width) / 2,
                        y: CGFloat(frame.y) + CGFloat(frame.height) / 2
                    )
                    switch interaction {
                    case .textInput(let binding, let placeholder):
                        TextField(placeholder, text: SwiftUI.Binding(
                            get: { binding.value },
                            set: { binding.setValue($0) }
                        ))
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .background(.clear)
                        .padding(.horizontal, 12)
                        .frame(width: CGFloat(frame.width), height: CGFloat(frame.height))
                        .position(centre)

                    case .tap(let action):
                        TapOverlay(frame: frame, action: action)
                            .position(centre)
                    }
                }
            }
        }
        .background(SwiftUI.Color(red: 0.12, green: 0.12, blue: 0.18))
    }

    private func layout(size: CGSize) -> ([(Rect, RenderCommand)], [(Rect, Interaction)]) {
        let interpreter = Interpreter()
        let constraint = LayoutConstraint.loose(
            Size(width: Float(size.width), height: Float(size.height))
        )
        let rootNode = YogaNode()
        let layoutNode = root.layout(node: rootNode, constraint: constraint)
        return (interpreter.collect(layoutNode), interpreter.collectInteractions(layoutNode))
    }
}

// MARK: - TapOverlay

/// Transparent hit area placed over a drawn button.
/// Owns hover state so @State works correctly — ForEach closures can't hold state.
private struct TapOverlay: SwiftUI.View {
    let frame: Rect
    let action: () -> Void
    @State private var isHovered = false

    var body: some SwiftUI.View {
        RoundedRectangle(cornerRadius: 8)
            .fill(SwiftUI.Color.white.opacity(isHovered ? 0.10 : 0))
            .frame(width: CGFloat(frame.width), height: CGFloat(frame.height))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture { action() }
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

// MARK: - WindowConfigurator

/// NSViewRepresentable shim that configures the hosting NSWindow:
///   - ensures the window is resizable
///   - terminates the app when the window is closed
public struct WindowConfigurator: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
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

    public func updateNSView(_ nsView: NSView, context: Context) {}
}
