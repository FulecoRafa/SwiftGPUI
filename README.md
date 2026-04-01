# SwiftGPUI

Render engine experimental para UI declarativa em Swift, inspirada em SwiftUI,
com renderização via GPU usando **Skia** e layout via **Yoga** (Flexbox).

## Arquitetura

```
SwiftGPUI (componentes de alto nível: Card, Input, Button, Flex…)
    │
    ├── GPUIObserve   → render loop + integração @Observable
    ├── GPUIInterpret → protocolo View, ViewBuilder, traversal
    ├── GPUILayout    → bridge Yoga → LayoutNode
    ├── GPUIDraw      → tipos puros (Color, Rect, RenderCommand…)
    │
    ├── CYoga         → C bindings para o Yoga (layout Flexbox)
    └── CSkia         → C bindings para o Skia (renderização GPU)
```

## Uso rápido

```swift
import SwiftGPUI

// Estado reativo
@Observable class LoginState {
    var email    = ""
    var password = ""
}

// UI declarativa
struct LoginForm: View {
    let state: LoginState

    func layout(node: YogaNode, constraint: LayoutConstraint) -> LayoutNode {
        Card {
            Input(label: "usuário", value: state.email)
            Input(.password,        value: state.password)
            Flex(direction: .horizontal) {
                Button             { "Cancel" }
                Button(color: .primary) { "Login"  }
            }
        }.layout(node: node, constraint: constraint)
    }
}

// Inicializar engine
let state    = LoginState()
let renderer = MockRenderer()   // troque por SkiaRenderer quando Skia estiver linkado
let loop     = await RenderLoop(
    rootView:   LoginForm(state: state),
    windowSize: Size(width: 360, height: 800),
    renderer:   renderer
)
await loop.start()

// Qualquer mutação em `state` dispara re-render automaticamente
state.email = "rafael@kaffa.com.br"
```

## Integrando as libs C

### Yoga
```bash
# Clone o fork Swift-friendly dentro de Sources/CYoga
git submodule add https://github.com/nicklockwood/Yoga Sources/CYoga/yoga
# Aponte os sources no Package.swift para Sources/CYoga/yoga/yoga
```

### Skia
Baixe binários pré-compilados ou compile do fonte:
- https://skia.org/docs/user/build/
- Adicione `linkerSettings: [.linkedLibrary("skia")]` no target CSkia

## Módulos

| Módulo | Responsabilidade |
|--------|-----------------|
| `GPUIDraw` | Tipos de valor puros — Color, Rect, Font, RenderCommand |
| `GPUILayout` | Bridge Yoga → LayoutNode. Calcula frames absolutos |
| `GPUIInterpret` | Protocolo View, ViewBuilder, traversal da árvore |
| `GPUIObserve` | Render loop + `@Observable` tracking + Renderer protocol |
| `SwiftGPUI` | Re-exporta tudo + componentes prontos (Card, Input…) |
| `CYoga` | Bindings C para o Yoga |
| `CSkia` | Bindings C para o Skia (API sk_*) |

## Roadmap

- [ ] Integrar Yoga real (substituir stub de layout)
- [ ] Integrar Skia real (substituir stub de renderer)
- [ ] Gerenciamento de eventos (mouse, teclado, touch)
- [ ] Componentes: ScrollView, List, Modal, Toast
- [ ] Hot reload via file watching (SwiftWatch 👀)
- [ ] Suporte a temas / design tokens
- [ ] Backend alternativo: wgpu-native (WebGPU)
