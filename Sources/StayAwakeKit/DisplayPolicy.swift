import Foundation

/// 屏幕策略：保持唤醒时，是否同时阻止显示器休眠。
public enum DisplayPolicy: String, CaseIterable, Sendable, Codable {
    /// 屏幕也常亮（同时阻止显示器休眠）。
    case screenOn
    /// 仅系统唤醒，允许屏幕关闭（默认，省电）。
    case allowScreenOff

    public var title: String {
        switch self {
        case .screenOn: return "屏幕常亮"
        case .allowScreenOff: return "允许屏幕关闭"
        }
    }
}
