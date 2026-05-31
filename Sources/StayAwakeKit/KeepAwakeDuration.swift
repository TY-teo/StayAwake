import Foundation

/// 保持唤醒时长。indefinite = 一直保持；minutes(n) = n 分钟后自动关闭。
public enum KeepAwakeDuration: Hashable, Sendable, Codable {
    case indefinite
    case minutes(Int)

    /// 面板预设项。
    public static let presets: [KeepAwakeDuration] = [
        .indefinite, .minutes(30), .minutes(60), .minutes(120), .minutes(300)
    ]

    /// 短标签。
    public var shortLabel: String {
        switch self {
        case .indefinite:
            return "一直"
        case .minutes(let m) where m % 60 == 0:
            return "\(m / 60)h"
        case .minutes(let m):
            return "\(m)m"
        }
    }

    /// 下拉菜单完整名称。
    public var displayName: String {
        switch self {
        case .indefinite:
            return "一直保持"
        case .minutes(let m) where m % 60 == 0:
            return "\(m / 60) 小时"
        case .minutes(let m):
            return "\(m) 分钟"
        }
    }

    /// 持续秒数；indefinite 返回 nil（不限时）。
    public var seconds: TimeInterval? {
        switch self {
        case .indefinite: return nil
        case .minutes(let m): return TimeInterval(m * 60)
        }
    }
}

/// 把秒数格式化为 HH:MM:SS。
public func formatCountdown(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}
