import Foundation
import IOKit.pwr_mgt

/// 管理 IOPMAssertion 电源断言，实现"保持唤醒"（功能一）。
/// 与是否插电无关；进程退出时系统会自动回收断言，本类也提供显式释放。
public final class PowerAssertionManager {
    private var systemSleepAssertion = IOPMAssertionID(0)
    private var displaySleepAssertion = IOPMAssertionID(0)
    private var hasSystemAssertion = false
    private var hasDisplayAssertion = false

    // 断言名用 ASCII，便于在 `pmset -g assertions` 中识别（pmset 对 CJK 名称显示为空）。
    private let reason = "StayAwake is keeping this Mac awake" as CFString

    public init() {}

    /// 是否已激活系统唤醒断言。
    public var isActive: Bool { hasSystemAssertion }

    /// 按策略应用断言。enabled=false 时释放全部。
    public func apply(enabled: Bool, policy: DisplayPolicy) {
        guard enabled else {
            releaseAll()
            return
        }
        // 系统空闲休眠断言（核心，始终需要）
        if !hasSystemAssertion {
            hasSystemAssertion = createAssertion(
                type: kIOPMAssertionTypePreventUserIdleSystemSleep,
                into: &systemSleepAssertion
            )
        }
        // 显示器断言：仅 screenOn 策略需要
        switch policy {
        case .screenOn:
            if !hasDisplayAssertion {
                hasDisplayAssertion = createAssertion(
                    type: kIOPMAssertionTypePreventUserIdleDisplaySleep,
                    into: &displaySleepAssertion
                )
            }
        case .allowScreenOff:
            releaseDisplayAssertion()
        }
    }

    /// 释放全部断言，恢复系统默认休眠行为。
    public func releaseAll() {
        releaseDisplayAssertion()
        if hasSystemAssertion {
            IOPMAssertionRelease(systemSleepAssertion)
            hasSystemAssertion = false
        }
    }

    private func releaseDisplayAssertion() {
        if hasDisplayAssertion {
            IOPMAssertionRelease(displaySleepAssertion)
            hasDisplayAssertion = false
        }
    }

    private func createAssertion(type: String, into id: inout IOPMAssertionID) -> Bool {
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &id
        )
        return result == kIOReturnSuccess
    }

    deinit {
        releaseAll()
    }
}
