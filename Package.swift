// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StayAwake",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        // 纯逻辑层：模型、电源管理、特权层、持久化、登录项、图标映射。可单测。
        .target(
            name: "StayAwakeKit",
            path: "Sources/StayAwakeKit"
        ),
        // 可执行：SwiftUI App 入口与界面，依赖 StayAwakeKit。
        .executableTarget(
            name: "StayAwake",
            dependencies: ["StayAwakeKit"],
            path: "Sources/StayAwake"
        ),
        .testTarget(
            name: "StayAwakeKitTests",
            dependencies: ["StayAwakeKit"],
            path: "Tests/StayAwakeKitTests"
        )
    ],
    // v5 语言模式：保证首次构建稳定（UI 已用 @MainActor 隔离），后续可收紧到 v6。
    swiftLanguageModes: [.v5]
)
