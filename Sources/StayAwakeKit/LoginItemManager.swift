import Foundation
import ServiceManagement

/// 开机自启（SMAppService.mainApp）。需要应用以正确签名的包形式运行才稳定。
@MainActor
public final class LoginItemManager {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 注册/注销登录项。失败仅记录日志，不抛出（避免影响主流程）。
    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("StayAwake 登录项切换失败: \(error.localizedDescription)")
        }
    }
}
