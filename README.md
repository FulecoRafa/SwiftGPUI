# SwiftGPUI

An experimental declarative UI framework for Swift. You write views in a SwiftUI-like DSL — the framework handles layout, rendering, and reactive state updates. The long-term rendering target is GPU-accelerated via **Skia**; layout is powered by **Yoga** (Meta's Flexbox engine). While those C libraries are being integrated, a **SwiftUI Canvas** backend renders everything so the framework is fully runnable today.

This is built as a mixture of what Flutter does, by basically using a rendering engine and drawing everything on it. Even though Flutter has
migrated from Skia, it is still very much used all around, so it seems
good enough. It also takes inspiration in Rust's GPUI and Go's Gogpu UI, both projects for rendering directly no GPU. 


## How it works

You never touch SwiftUI directly. Your app conforms to `GPUIDesktopApp`, declares a `rootView` using GPUI components, and the platform layer handles the rest.

```swift
import SwiftGPUI
import GPUIPlatformMacOS

@main
struct MyApp: GPUIDesktopApp {
    let model = MyModel()

    var rootView: any SwiftGPUI.View {
        MyView(model: model)
    }
}
```

Your views compose GPUI components and bind to `@Observable` models:

```swift
import SwiftGPUI

struct MyView: SwiftGPUI.View {
    let model: MyModel

    func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        Flex(direction: .vertical, gap: 16, padding: 24) {
            Card(padding: 20) {
                Input(label: "Name", binding: GPUIBinding(model, \.name))
                Input(label: "Email", binding: GPUIBinding(model, \.email))
            }
            Card(padding: 20) {
                Text(model.greeting, font: .heading, color: .primary)
                Button(color: .primary, onClick: model.submit) { "Submit" }
            }
        }
        .layout(node: node, constraint: constraint)
    }
}
```

Mutating an `@Observable` property automatically schedules a re-render — no manual state management needed.

## Architecture

```
Your App
  └── GPUIDesktopApp (GPUIPlatformMacOS)
        └── GPUICanvas — SwiftUI Canvas surface + native input overlays
              │
              └── Interpreter.interpret(rootView, constraint)
                    │
                    ├── View.layout()           each component builds a LayoutNode tree
                    ├── YogaNode.calculateLayout()  computes absolute frames
                    └── collect() / collectInteractions()  flattens to draw list + interactions
                          │
                          ├── SwiftUIRenderer.draw()   draws everything onto the Canvas
                          └── Platform overlays        transparent TextField / tap targets
```

### Module breakdown

| Module | Responsibility |
|--------|----------------|
| `GPUIDraw` | Pure value types — `Color`, `Rect`, `Font`, `RenderCommand`, `GPUIBinding` |
| `GPUILayout` | `YogaNode` wrapper, `LayoutNode` tree, `Interaction` enum |
| `GPUIInterpret` | `View` protocol, `ViewBuilder` DSL, `Interpreter` traversal |
| `GPUIObserve` | `RenderLoop` + `@Observable` tracking, `Renderer` protocol, `SkiaRenderer` stub |
| `SwiftGPUI` | Re-exports all modules + built-in components (`Card`, `Input`, `Button`, `Flex`, `Text`) |
| `GPUIPlatformMacOS` | macOS window management, `GPUICanvas`, `SwiftUIRenderer` |
| `CYoga` | C bindings for Meta's Yoga layout engine |
| `CSkia` | C bindings for Skia's stable C API (`sk_*`) |

## Components

| Component | API |
|-----------|-----|
| `Text` | `Text("Hello", font: .heading, color: .primary)` |
| `Button` | `Button(color: .primary, onClick: action) { "Label" }` |
| `Input` | `Input(label: "Name", binding: GPUIBinding(model, \.name))` |
| `Card` | `Card(padding: 20, cornerRadius: 12) { ... }` |
| `Flex` | `Flex(direction: .horizontal, gap: 8, padding: 16) { ... }` |

## Reactivity

`GPUIBinding` bridges an `@Observable` model property to interactive components. Create one with a key path — no boilerplate:

```swift
GPUIBinding(model, \.fieldName)
```

The render loop uses `withObservationTracking` to detect any property access during layout and automatically re-renders when those properties change.

## Running the demo

```bash
swift run GPUIDemo
```

Opens a macOS window with a reactive form: type into the Name and Occupation fields, the output card updates live. Clicking Submit commits the values.

## Integrating the C libraries

### Yoga
```bash
git submodule add https://github.com/facebook/yoga Sources/CYoga/yoga
# then replace the stub in YogaNode.calculateLayout() with real YGNode* calls
```

### Skia
Download prebuilt binaries or build from source:
```
https://skia.org/docs/user/build/
```
Add `linkerSettings: [.linkedLibrary("skia")]` to the `CSkia` target in `Package.swift`, then uncomment the `sk_*` calls in `SkiaRenderer`. The `SwiftUIRenderer` in `GPUIPlatformMacOS` can then be removed.

## Roadmap

- [ ] Integrate real Yoga (replace layout stub)
- [ ] Integrate real Skia (replace SwiftUI Canvas backend)
- [ ] Mouse and keyboard event handling
- [ ] `ScrollView`, `List`, `Modal`, `Toast` components
- [ ] Design tokens / theming
- [ ] Hot reload via file watching
- [ ] Linux platform backend (via Skia + native windowing)
- [ ] WebGPU backend (wgpu-native)
