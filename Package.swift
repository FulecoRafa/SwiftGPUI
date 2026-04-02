// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftGPUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "GPUIDemo", targets: ["GPUIDemo"]),
        .library(name: "GPUIPlatformMacOS", targets: ["GPUIPlatformMacOS"]),
        .library(name: "SwiftGPUI",     targets: ["SwiftGPUI"]),
        .library(name: "GPUIDraw",      targets: ["GPUIDraw"]),
        .library(name: "GPUILayout",    targets: ["GPUILayout"]),
        .library(name: "GPUIInterpret", targets: ["GPUIInterpret"]),
        .library(name: "GPUIObserve",   targets: ["GPUIObserve"]),
    ],
    dependencies: [
        // Standalone packages — each lives in its own git repo and is
        // pulled in here as a git submodule under Vendors/.
        .package(path: "Vendors/SwiftYoga"),
        .package(path: "Vendors/SwiftSkia"),
    ],
    targets: [

        // ── GPUIDraw ─────────────────────────────────────────────────
        .target(
            name: "GPUIDraw",
            dependencies: [],
            path: "Sources/GPUIDraw"
        ),

        // ── GPUILayout ───────────────────────────────────────────────
        .target(
            name: "GPUILayout",
            dependencies: [
                .product(name: "CYoga", package: "SwiftYoga"),
                "GPUIDraw",
            ],
            path: "Sources/GPUILayout"
        ),

        // ── GPUIInterpret ────────────────────────────────────────────
        .target(
            name: "GPUIInterpret",
            dependencies: ["GPUIDraw", "GPUILayout"],
            path: "Sources/GPUIInterpret"
        ),

        // ── GPUIObserve ──────────────────────────────────────────────
        .target(
            name: "GPUIObserve",
            dependencies: [
                "GPUIInterpret",
                .product(name: "CSkia", package: "SwiftSkia"),
            ],
            path: "Sources/GPUIObserve"
        ),

        // ── SwiftGPUI (produto principal) ────────────────────────────
        .target(
            name: "SwiftGPUI",
            dependencies: [
                "GPUIDraw",
                "GPUILayout",
                "GPUIInterpret",
                "GPUIObserve",
            ],
            path: "Sources/SwiftGPUI"
        ),

        // ── GPUIPlatformMacOS ─────────────────────────────────────
        .target(
            name: "GPUIPlatformMacOS",
            dependencies: ["SwiftGPUI"],
            path: "Sources/GPUIPlatformMacOS"
        ),

        // ── GPUIDemo ────────────────────────────────────────────
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
            dependencies: ["GPUIInterpret", "SwiftGPUI"],
            path: "Tests/GPUIInterpretTests"
        ),
    ]
)
