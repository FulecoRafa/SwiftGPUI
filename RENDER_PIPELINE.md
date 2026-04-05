# SwiftGPUI Render Pipeline

A high-level walkthrough of how a component goes from Swift declaration to pixels on screen.

---

## Overview

```
View (Swift DSL)
    │
    ▼
Layout  ──  Yoga (C++)
    │
    ▼
LayoutNode tree
    │
    ▼
Interpreter  →  [(Rect, RenderCommand)]  +  [(Rect, Interaction)]
    │                                              │
    ▼                                              ▼
SkiaRenderer  →  CGImage              SwiftUI overlays
    │                                  (TextField, Menu, …)
    ▼
SwiftUI Image (display only)
```

---

## Stage 1 — View Declaration

**File:** [Sources/SwiftGPUI/Components.swift](Sources/SwiftGPUI/Components.swift)

The user writes components using the Swift DSL:

```swift
Card(padding: 20) {
    Input(label: "Email", .email, binding: GPUIBinding(model, \.email))
    Button(color: .primary) { "Submit" } onClick: { model.submit() }
}
```

Every component conforms to the [`View` protocol](Sources/GPUIInterpret/Interpret.swift#L6):

```swift
public protocol View {
    func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode
}
```

---

## Stage 2 — Layout (Yoga)

**Files:**
- [Sources/GPUILayout/Layout.swift](Sources/GPUILayout/Layout.swift) — `YogaNode`, `LayoutNode`, `LayoutConstraint`, `Interaction`
- [Vendors/SwiftYoga/Sources/CYoga/include/CYoga.h](Vendors/SwiftYoga/Sources/CYoga/include/CYoga.h) — C API header

Each component's `layout(node:constraint:)` method:

1. Configures a `YogaNode` (flex direction, gap, padding, fixed height)
2. Recursively calls `layout` on children, adding their `YogaNode`s as children
3. Calls `YGNodeCalculateLayout` **once at the container root** with `Float.nan` for height so Yoga sizes to content
4. Returns a `LayoutNode` carrying:
   - `frame: Rect` — absolute position in window coordinates
   - `renderCommand: RenderCommand` — what to draw
   - `children: [LayoutNode]` — subtree
   - `interaction: Interaction?` — optional native control hint

Leaf nodes (`Text`, `Input`, `Button`, `Checkbox`, …) set a fixed height and return a preliminary frame — the parent container repositions them via [`offsetted(x:y:)`](Sources/GPUILayout/Layout.swift#L41).

---

## Stage 3 — Interpretation (tree → flat list)

**File:** [Sources/GPUIInterpret/Interpret.swift](Sources/GPUIInterpret/Interpret.swift)

`Interpreter` does two depth-first traversals of the `LayoutNode` tree:

```swift
// Render commands — painter's order (parent before children)
func collect(_ node: LayoutNode) -> [(Rect, RenderCommand)]

// Native overlay targets — frames where SwiftUI controls sit
func collectInteractions(_ node: LayoutNode) -> [(Rect, Interaction)]
```

The result is two flat arrays:

| Array | Purpose |
|---|---|
| `[(Rect, RenderCommand)]` | Handed to `SkiaRenderer` |
| `[(Rect, Interaction)]` | Handed to `GPUICanvas` for SwiftUI overlays |

---

## Stage 4 — Skia Rendering

**Files:**
- [Sources/GPUIObserve/Observe.swift](Sources/GPUIObserve/Observe.swift) — `SkiaRenderer`
- [Vendors/SwiftSkia/Sources/CSkia/skia_bridge.cpp](Vendors/SwiftSkia/Sources/CSkia/skia_bridge.cpp) — C++ bridge
- [Vendors/SwiftSkia/Sources/CSkia/include/CSkia.h](Vendors/SwiftSkia/Sources/CSkia/include/CSkia.h) — C API exposed to Swift

`SkiaRenderer` owns a persistent offscreen raster surface (allocated once, recreated only on resize by [`SkiaState`](Sources/GPUIPlatformMacOS/MacOSPlatform.swift#L42)).

### Per-frame sequence

```
render(commands:)
 │
 ├─ sk_canvas_clear          — fill background
 │
 └─ for each (Rect, RenderCommand):
      draw(command:in:)
       │
       ├─ .roundedRect  →  sk_rrect_set_rect_radii + sk_canvas_draw_rrect
       ├─ .text         →  sk_typeface_default (cached) + sk_font_new + sk_canvas_draw_string
       ├─ .button       →  roundedRect + text
       ├─ .checkbox     →  roundedRect + sk_canvas_draw_line (tick)
       ├─ .radio        →  roundedRect (circle) + roundedRect (inner dot)
       ├─ .select       →  roundedRect + text + sk_canvas_draw_line (chevron)
       ├─ .datePicker   →  roundedRect + text
       ├─ .textArea     →  roundedRect + placeholder text when empty
       ├─ .searchBox    →  roundedRect + placeholder when empty + lines (icon)
       └─ .textField    →  roundedRect (shell only — native overlay owns text)
```

### Typeface cache

[`sk_typeface_default(style)`](Vendors/SwiftSkia/Sources/CSkia/skia_bridge.cpp) resolves `.AppleSystemUIFont` via CoreText **once** on first call and returns the same pointer for the process lifetime — zero allocation cost on subsequent frames.

### Reading back pixels

After all draw calls, [`SkiaRenderer.cgImage`](Sources/GPUIObserve/Observe.swift#L97) calls `sk_surface_peek_pixels` to get a direct pointer into the raster buffer, wraps it in a `CGImage` (BGRA-8888 premultiplied), and returns it to SwiftUI.

---

## Stage 5 — Display + Native Overlays

**File:** [Sources/GPUIPlatformMacOS/MacOSPlatform.swift](Sources/GPUIPlatformMacOS/MacOSPlatform.swift)

`GPUICanvas` is the only SwiftUI surface. It:

1. Calls `layout(size:)` to produce commands + interactions
2. Asks `SkiaState` for the cached/resized `SkiaRenderer`
3. Calls `render(commands:)` → gets `cgImage` → displays it via `SwiftUI.Image`
4. Places transparent native overlays on top for interactive elements:

| Interaction | SwiftUI overlay | Purpose |
|---|---|---|
| `.textInput` | [`TextInputOverlay`](Sources/GPUIPlatformMacOS/MacOSPlatform.swift#L183) (`TextField` / `SecureField`) | Keyboard input + iBeam cursor |
| `.textArea` | `TextEditor` | Multi-line keyboard input |
| `.tap` | [`TapOverlay`](Sources/GPUIPlatformMacOS/MacOSPlatform.swift#L180) | Click + pointer cursor |
| `.selectPick` | [`SelectOverlay`](Sources/GPUIPlatformMacOS/MacOSPlatform.swift#L222) (popover) | Option list |
| `.datePick` | [`DatePickOverlay`](Sources/GPUIPlatformMacOS/MacOSPlatform.swift#L257) (popover) | Calendar picker |

The overlays are invisible — their backgrounds are `.clear`. Skia draws every visual; SwiftUI only captures input.

---

## Reactivity

**File:** [Sources/GPUIObserve/Observe.swift](Sources/GPUIObserve/Observe.swift#L11) — `RenderLoop`

`RenderLoop` uses Swift `Observation` (`withObservationTracking`) to automatically re-schedule a frame whenever any `@Observable` model property read during layout changes:

```
model.name changes
    → withObservationTracking onChange fires
    → scheduleFrame() called on MainActor
    → layout + render + display
```

In the macOS demo, SwiftUI's own state engine drives re-evaluation of `GPUICanvas.body` instead, achieving the same result through `@StateObject` + `@Observable`.

---

## Data flow summary

```
@Observable model
       │  (property change)
       ▼
GPUICanvas.body re-evaluates
       │
       ├─ layout(size:)
       │    └─ root.layout(node:constraint:)   [Components.swift]
       │         └─ YGNodeCalculateLayout      [CYoga / Yoga C++]
       │              └─ returns LayoutNode tree
       │
       ├─ Interpreter.collect()               [Interpret.swift]
       │    └─ [(Rect, RenderCommand)]
       │
       ├─ SkiaRenderer.render(commands:)      [Observe.swift]
       │    └─ sk_canvas_* calls              [skia_bridge.cpp → libskia.a]
       │         └─ cgImage (pixel readback)
       │
       ├─ SwiftUI.Image(cgImage)              display
       │
       └─ SwiftUI overlays (TextField, …)     input capture
```
