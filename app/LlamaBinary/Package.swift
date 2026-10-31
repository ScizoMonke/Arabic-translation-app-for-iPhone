// swift-tools-version: 5.10
// llama.cpp for Egypt Talk, as upstream ships it for Apple platforms: a prebuilt
// llama.xcframework (ios-arm64 + macOS, ggml with Metal, shaders embedded) attached
// to every release. llama.cpp itself has no Package.swift any more, so this local
// package exists only to hand that binary to SwiftPM; the pattern is upstream's own
// docs/xcframework.md. Nothing is compiled from source on the runner.
//
// Pinned release: b12020 (tag commit 0ec4027a2a0183de87c007069adddc06e665f7de,
// 2026-10-30). The checksum is the SHA-256 of the zip, measured on the Windows PC
// on 2026-10-31 and identical to the digest GitHub lists for the asset. To move to
// another release, change both lines together and re-read include/llama.h at that
// tag against LlamaEngine.swift.
//
// The binary target is named "llama" to match the framework's own module name
// (framework module llama), so Swift code says `import llama`.
import PackageDescription

let package = Package(
    name: "LlamaBinary",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "llama", targets: ["llama"]),
    ],
    targets: [
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b12020/llama-b12020-xcframework.zip",
            checksum: "78fdf6ec32fad1f0e55a3fd78401841ba0a7b34f26b30078c6dc8d7951d81ae5"
        ),
    ]
)
