import Foundation

/// 合盖继续运行（功能二）：通过特权层设置/还原 pmset disablesleep，并保证不残留。
@MainActor
public final class LidCloseManager {
    private let runner: PrivilegedRunner
    private let preferences: Preferences

    public private(set) var isEnabled = false

    public init(runner: PrivilegedRunner, preferences: Preferences) {
        self.runner = runner
        self.preferences = preferences
    }

    /// 启动自检：若上次由本 App 设置了 disablesleep 且系统仍开启，则还原，避免崩溃后残留。
    public func reconcileOnLaunch() async {
        guard preferences.didSetDisableSleep else { return }
        let current = await runner.currentDisableSleep()
        if current {
            try? await runner.setDisableSleep(false)
        }
        preferences.didSetDisableSleep = false
        isEnabled = false
    }

    /// 切换合盖模式。返回是否成功；失败时调用方应回滚 UI。
    @discardableResult
    public func setEnabled(_ enabled: Bool) async -> Bool {
        do {
            try await runner.setDisableSleep(enabled)
            isEnabled = enabled
            preferences.didSetDisableSleep = enabled
            return true
        } catch {
            return false
        }
    }
}
