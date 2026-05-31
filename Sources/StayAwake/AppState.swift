import SwiftUI
import AppKit
import StayAwakeKit

/// 单一状态源：编排电源断言、合盖特权层、定时器、登录项。
@MainActor
final class AppState: ObservableObject {
    // 保持唤醒
    @Published var keepAwake = false
    @Published var displayPolicy: DisplayPolicy
    @Published var duration: KeepAwakeDuration
    @Published var remaining: TimeInterval?

    // 合盖
    @Published var lidClose = false
    @Published var lidCloseBusy = false

    // 合盖免密（一次性 sudoers 授权）
    @Published var passwordlessEnabled: Bool
    @Published var passwordlessBusy = false

    // 系统集成
    @Published var launchAtLogin: Bool
    @Published var lastError: String?

    private let assertions = PowerAssertionManager()
    private let preferences: Preferences
    private let lidManager: LidCloseManager
    private let loginItems: LoginItemManager
    private let sudoers = SudoersAuthorization()

    private var endDate: Date?
    private var ticker: Timer?

    init(skipReconcile: Bool = false) {
        let prefs = Preferences()
        let logins = LoginItemManager()
        self.preferences = prefs
        self.loginItems = logins
        self.displayPolicy = prefs.displayPolicy
        self.duration = prefs.lastDuration
        self.launchAtLogin = logins.isEnabled
        self.passwordlessEnabled = prefs.passwordlessInstalled
        // 自适应执行器：免密已装则 sudo -n 静默执行，否则回退授权弹窗。
        self.lidManager = LidCloseManager(runner: AdaptivePrivilegedRunner(), preferences: prefs)

        // 启动自检：清理崩溃后可能残留的 disablesleep。（快照模式跳过。）
        if !skipReconcile {
            Task { [lidManager] in await lidManager.reconcileOnLaunch() }
        }
    }

    /// 菜单栏图标状态。
    var icon: MenuBarIconModel {
        MenuBarIconModel(
            keepAwake: keepAwake,
            screenAlwaysOn: displayPolicy == .screenOn,
            lidClose: lidClose
        )
    }

    var statusText: String {
        if lidClose { return "合盖运行中" }
        if keepAwake { return "保持唤醒中" }
        return "允许休眠"
    }

    // MARK: - 保持唤醒

    func setKeepAwake(_ on: Bool) {
        keepAwake = on
        assertions.apply(enabled: on, policy: displayPolicy)
        if on { restartTimer() } else { stopTimer() }
    }

    func setDisplayPolicy(_ policy: DisplayPolicy) {
        displayPolicy = policy
        preferences.displayPolicy = policy
        if keepAwake { assertions.apply(enabled: true, policy: policy) }
    }

    func setDuration(_ value: KeepAwakeDuration) {
        duration = value
        preferences.lastDuration = value
        if keepAwake { restartTimer() }
    }

    private func restartTimer() {
        stopTimer()
        guard let seconds = duration.seconds else {
            remaining = nil
            return
        }
        endDate = Date().addingTimeInterval(seconds)
        remaining = seconds
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            setKeepAwake(false)
        } else {
            remaining = left
        }
    }

    private func stopTimer() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        remaining = nil
    }

    // MARK: - 合盖继续运行

    func requestLidClose(_ on: Bool) {
        guard !lidCloseBusy else { return }
        lidCloseBusy = true
        lastError = nil
        Task { [lidManager] in
            let ok = await lidManager.setEnabled(on)
            lidClose = ok ? on : lidClose
            if !ok {
                lastError = on ? "未能开启合盖运行（授权取消或失败）" : "未能关闭合盖运行"
            }
            lidCloseBusy = false
        }
    }

    /// 启用/关闭合盖免密（一次性 sudoers 授权）。启用后切换合盖无需每次输密码。
    func setPasswordless(_ on: Bool) {
        guard !passwordlessBusy else { return }
        passwordlessBusy = true
        lastError = nil
        Task { [sudoers, preferences] in
            do {
                if on {
                    try await sudoers.install(user: NSUserName())
                } else {
                    try await sudoers.uninstall()
                }
                preferences.passwordlessInstalled = on
                passwordlessEnabled = on
            } catch {
                lastError = on ? "未能启用免密（授权取消或失败）" : "未能关闭免密"
            }
            passwordlessBusy = false
        }
    }

    // MARK: - 系统集成

    func setLaunchAtLogin(_ on: Bool) {
        loginItems.setEnabled(on)
        launchAtLogin = loginItems.isEnabled
    }

    /// 退出：先释放断言；若合盖开启则先关闭（会弹授权）再退出，确保不残留。
    func quit() {
        assertions.releaseAll()
        stopTimer()
        if lidClose {
            Task { [lidManager] in
                _ = await lidManager.setEnabled(false)
                NSApp.terminate(nil)
            }
        } else {
            NSApp.terminate(nil)
        }
    }
}
