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

// MARK: - SkiaState

/// Owns the SkiaRenderer and only recreates the surface when pixel dimensions change.
/// Stored as a @StateObject so it survives SwiftUI body re-evaluations.
private final class SkiaState: ObservableObject {
    private(set) var renderer: SkiaRenderer?
    private var lastWidth:  Int32 = 0
    private var lastHeight: Int32 = 0

    func renderer(width: Int32, height: Int32, scale: Float) -> SkiaRenderer {
        if renderer == nil || width != lastWidth || height != lastHeight {
            renderer  = SkiaRenderer(width: width, height: height, scale: scale)
            lastWidth  = width
            lastHeight = height
        }
        return renderer!
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
    @StateObject private var skiaState = SkiaState()

    public init(root: any SwiftGPUI.View) {
        self.root = root
    }

    public var body: some SwiftUI.View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: true) {
            let scale = CGFloat(NSScreen.main?.backingScaleFactor ?? 1)
            let (commands, interactions) = layout(size: geo.size)
            let contentHeight = commands.map { $0.0.maxY }.max().map { CGFloat($0) } ?? geo.size.height

            // Reuse or recreate the Skia surface only when pixel dimensions change.
            // SwiftUI is only used for the transparent interactive overlays below.
            let skia = skiaState.renderer(
                width:  Int32(geo.size.width * scale),
                height: Int32(contentHeight  * scale),
                scale:  Float(scale)
            )
            let _ = { skia.render(commands: commands) }()

            ZStack(alignment: .topLeading) {
                // ── Skia-rendered frame ─────────────────────────────────
                if let img = skia.cgImage {
                    Image(img, scale: scale, label: SwiftUI.Text(""))
                        .resizable()
                        .frame(width: geo.size.width, height: contentHeight)
                }
                // ── frame placeholder so ZStack has the right size ──────
                SwiftUI.Color.clear.frame(height: contentHeight)

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
                    case .textInput(let binding, let placeholder, let secure, let leadingInset):
                        TextInputOverlay(
                            frame: frame,
                            binding: binding,
                            placeholder: placeholder,
                            secure: secure,
                            leadingInset: leadingInset
                        )
                        .position(centre)

                    case .textArea(let binding, _):
                        TextEditor(text: SwiftUI.Binding(
                            get: { binding.value },
                            set: { binding.setValue($0) }
                        ))
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .padding(.horizontal, 8)
                        .padding(.top, 20)
                        .frame(width: CGFloat(frame.width), height: CGFloat(frame.height))
                        .position(centre)

                    case .tap(let action):
                        TapOverlay(frame: frame, action: action)
                            .position(centre)

                    case .selectPick(let options, let selectedIndex, let onSelect):
                        SelectOverlay(frame: frame, options: options, selectedIndex: selectedIndex, onSelect: onSelect)
                            .position(centre)

                    case .datePick(let get, let set):
                        DatePickOverlay(frame: frame, get: get, set: set)
                            .position(centre)
                    }
                }
            }
            .frame(width: geo.size.width, height: contentHeight)
            } // ScrollView
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

// MARK: - TextInputOverlay

/// Transparent field overlay that owns hover state for cursor + Skia re-render signal.
private struct TextInputOverlay: SwiftUI.View {
    let frame: Rect
    let binding: GPUIBinding<String>
    let placeholder: String
    let secure: Bool
    let leadingInset: CGFloat
    @State private var isHovered = false

    var body: some SwiftUI.View {
        ZStack {
            if isHovered {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(SwiftGPUI.Color.border.swiftUIColor.opacity(0.5), lineWidth: 1)
            }
            Group {
                if secure {
                    SecureField(placeholder, text: SwiftUI.Binding(
                        get: { binding.value }, set: { binding.setValue($0) }
                    ))
                } else {
                    TextField(placeholder, text: SwiftUI.Binding(
                        get: { binding.value }, set: { binding.setValue($0) }
                    ))
                }
            }
            .textFieldStyle(.plain)
            .foregroundColor(.white)
            .background(.clear)
            .padding(.leading, leadingInset)
            .padding(.trailing, 12)
        }
        .frame(width: CGFloat(frame.width), height: CGFloat(frame.height))
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.iBeam.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - SelectOverlay

/// Popover-based select overlay — avoids Menu chrome bleeding over the Skia shell.
private struct SelectOverlay: SwiftUI.View {
    let frame: Rect
    let options: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    @State private var isPresented = false

    var body: some SwiftUI.View {
        SwiftUI.Color.clear
            .frame(width: CGFloat(frame.width), height: CGFloat(frame.height))
            .contentShape(Rectangle())
            .onTapGesture { isPresented = true }
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { i, opt in
                        Button {
                            onSelect(i)
                            isPresented = false
                        } label: {
                            HStack {
                                SwiftUI.Text(opt)
                                    .foregroundColor(i == selectedIndex ? .accentColor : .primary)
                                Spacer()
                                if i == selectedIndex {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if i < options.count - 1 {
                            Divider()
                        }
                    }
                }
                .frame(minWidth: CGFloat(frame.width))
                .padding(.vertical, 4)
            }
    }
}

// MARK: - DatePickOverlay

/// Transparent tap area that presents a graphical date picker in a popover.
private struct DatePickOverlay: SwiftUI.View {
    let frame: Rect
    let get: () -> Date
    let set: (Date) -> Void
    @State private var isPresented = false

    var body: some SwiftUI.View {
        SwiftUI.Color.clear
            .frame(width: CGFloat(frame.width), height: CGFloat(frame.height))
            .contentShape(Rectangle())
            .onTapGesture { isPresented = true }
            .popover(isPresented: $isPresented) {
                SwiftUI.DatePicker(
                    "",
                    selection: SwiftUI.Binding(get: get, set: set),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
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
