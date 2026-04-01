// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftGPUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Demo executável — rode com: swift run GPUIDemo
        .executable(name: "GPUIDemo", targets: ["GPUIDemo"]),

        // Platform backend: macOS SwiftUI canvas + window management
        .library(name: "GPUIPlatformMacOS", targets: ["GPUIPlatformMacOS"]),

        // Biblioteca principal — o que consumidores importam
        .library(name: "SwiftGPUI", targets: ["SwiftGPUI"]),

        // Módulos internos expostos separadamente para quem quiser
        // usar só partes da stack (ex: apenas o layout engine)
        .library(name: "GPUIDraw",     targets: ["GPUIDraw"]),
        .library(name: "GPUILayout",   targets: ["GPUILayout"]),
        .library(name: "GPUIInterpret",targets: ["GPUIInterpret"]),
        .library(name: "GPUIObserve",  targets: ["GPUIObserve"]),

        // Bindings C expostos para quem quiser portar / wrappear
        .library(name: "CYoga",  targets: ["CYoga"]),
        .library(name: "CSkia",  targets: ["CSkia"]),
    ],
    targets: [

        // ── C Bindings ───────────────────────────────────────────────
        //
        // CYoga: wraps a biblioteca Yoga (layout Flexbox do Meta).
        // Os headers reais ficam em Sources/CYoga/include/ após você
        // copiar (ou fazer git submodule add) do repositório oficial:
        //   https://github.com/nicklockwood/Yoga  (fork Swift-friendly)
        // ou o original: https://github.com/facebook/yoga
        //
        // Por enquanto os headers são stubs para o projeto compilar.
        .target(
            name: "CYoga",
            path: "Sources/CYoga",
            sources: ["yoga_stub.c"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        ),

        // CSkia: wraps a API C estável do Skia (sk_*).
        // Baixe o binário pré-compilado ou compile via:
        //   https://skia.org/docs/user/build/
        // e aponte o linker para a lib via pkgConfig ou linkerSettings.
        //
        // Por enquanto stubs para o projeto compilar.
        .target(
            name: "CSkia",
            path: "Sources/CSkia",
            sources: ["skia_stub.c"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        ),

        // ── GPUIDraw ─────────────────────────────────────────────────
        // Tipos de valor puros: Color, Rect, Size, Font, RenderCommand.
        // Sem dependências externas — importável de qualquer camada.
        .target(
            name: "GPUIDraw",
            dependencies: [],
            path: "Sources/GPUIDraw"
        ),

        // ── GPUILayout ───────────────────────────────────────────────
        // Bridge entre a árvore de View e o Yoga.
        // Consome CYoga e produz LayoutNode (frame calculado + comando).
        .target(
            name: "GPUILayout",
            dependencies: ["CYoga", "GPUIDraw"],
            path: "Sources/GPUILayout"
        ),

        // ── GPUIInterpret ────────────────────────────────────────────
        // Traversal da LayoutNode tree → lista plana de (Rect, RenderCommand).
        // Também contém o result builder ViewBuilder e o protocolo View.
        .target(
            name: "GPUIInterpret",
            dependencies: ["GPUIDraw", "GPUILayout"],
            path: "Sources/GPUIInterpret"
        ),

        // ── GPUIObserve ──────────────────────────────────────────────
        // Render loop, diff de subgraphs, integração com @Observable.
        // Chama GPUIInterpret para obter comandos e CSkia para renderizar.
        .target(
            name: "GPUIObserve",
            dependencies: ["GPUIInterpret", "CSkia"],
            path: "Sources/GPUIObserve"
        ),

        // ── SwiftGPUI (produto principal) ────────────────────────────
        // Re-exporta tudo. Ponto de entrada único para apps.
        // Componentes de alto nível (Card, Input, Button, Flex…) vivem aqui.
        .target(
            name: "SwiftGPUI",
            dependencies: [
                "GPUIDraw",
                "GPUILayout",
                "GPUIInterpret",
                "GPUIObserve",
                "CYoga",
                "CSkia",
            ],
            path: "Sources/SwiftGPUI"
        ),

        // ── GPUIPlatformMacOS ─────────────────────────────────────
        // SwiftUI/AppKit display backend for macOS.
        // Provides GPUIDesktopApp, GPUICanvas, and window management.
        .target(
            name: "GPUIPlatformMacOS",
            dependencies: ["SwiftGPUI"],
            path: "Sources/GPUIPlatformMacOS"
        ),

        // ── GPUIDemo (executável Hello World) ────────────────────
        // Usa SwiftUI Canvas como display backend enquanto o Skia
        // não está linkado. Rode com: swift run GPUIDemo
        .executableTarget(
            name: "GPUIDemo",
            dependencies: ["SwiftGPUI", "GPUIPlatformMacOS"],
            path: "Sources/GPUIDemo",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),

        // ── Testes ───────────────────────────────────────────────────
        .testTarget(
            name: "GPUIDrawTests",
            dependencies: ["GPUIDraw"],
            path: "Tests/GPUIDrawTests"
        ),
        .testTarget(
            name: "GPUILayoutTests",
            dependencies: ["GPUILayout"],
            path: "Tests/GPUILayoutTests"
        ),
        .testTarget(
            name: "GPUIInterpretTests",
            dependencies: ["GPUIInterpret"],
            path: "Tests/GPUIInterpretTests"
        ),
    ]
)
