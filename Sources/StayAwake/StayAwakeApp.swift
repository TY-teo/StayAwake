import SwiftUI
import AppKit

/// 程序入口：支持 `--snapshot <dir>` 离屏渲染面板为 PNG（用于设计走查，无需屏幕录制权限）。
@main
struct EntryPoint {
    static func main() {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--snapshot"), idx + 1 < args.count {
            MainActor.assumeIsolated {
                SnapshotRenderer.renderAll(toDirectory: args[idx + 1])
            }
            return
        }
        StayAwakeApp.main()
    }
}

struct StayAwakeApp: App {
    @StateObject private var state = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            ControlPanelView()
                .environmentObject(state)
        } label: {
            Image(systemName: state.icon.symbolName)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 设为 accessory，仅驻留菜单栏、不在 Dock 显示。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
