import SwiftUI
import AppKit

/// 离屏渲染面板为 PNG 用于设计走查。
/// 用 NSHostingView + cacheDisplay 渲染真实 AppKit 原生控件（ImageRenderer 无法渲染原生 Toggle/Picker）。
/// 不需要屏幕录制权限（应用绘制自身视图）。浅色/深色双外观核对。
@MainActor
enum SnapshotRenderer {
    static func renderAll(toDirectory dir: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let appearances: [(String, NSAppearance.Name)] = [
            ("light", .aqua),
            ("dark", .darkAqua)
        ]
        for (suffix, appearanceName) in appearances {
            let idle = AppState(skipReconcile: true)
            render(state: idle, name: "panel-idle-\(suffix)", appearance: appearanceName, dir: dir)

            let active = AppState(skipReconcile: true)
            active.keepAwake = true
            active.displayPolicy = .allowScreenOff
            active.duration = .minutes(60)
            active.remaining = 3600
            render(state: active, name: "panel-active-\(suffix)", appearance: appearanceName, dir: dir)
        }
        // 合盖内联确认态（仅浅色，验证确认 UI）
        render(state: AppState(skipReconcile: true), name: "panel-lidconfirm-light", appearance: .aqua, dir: dir, pendingLidConfirm: true)
        print("snapshots written to \(dir)")
    }

    private static func render(state: AppState, name: String, appearance: NSAppearance.Name, dir: String, pendingLidConfirm: Bool = false) {
        let appearanceValue = NSAppearance(named: appearance)
        let root = ControlPanelView(previewPendingLidConfirm: pendingLidConfirm).environmentObject(state)
        let hosting = NSHostingView(rootView: root)
        hosting.appearance = appearanceValue
        hosting.layoutSubtreeIfNeeded()

        var size = hosting.fittingSize
        if size.width < 10 { size.width = Tokens.panelWidth }
        if size.height < 10 { size.height = 520 }
        hosting.frame = CGRect(origin: .zero, size: size)

        // 放入窗口以获得正确外观与材质渲染
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = appearanceValue
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("render failed (no rep): \(name)")
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            print("render failed (no png): \(name)")
            return
        }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        do {
            try png.write(to: url)
            print("wrote \(url.path) (\(Int(size.width))x\(Int(size.height)))")
        } catch {
            print("write failed \(name): \(error.localizedDescription)")
        }
    }
}
