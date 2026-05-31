import Foundation

/// 菜单栏图标状态 -> SF Symbol 名称的纯映射，便于单测。
/// 仅使用稳定存在的 SF Symbols；用 实心/描边 差异在菜单栏（通常单色）中传达状态。
public struct MenuBarIconModel: Equatable, Sendable {
    public let keepAwake: Bool
    public let screenAlwaysOn: Bool
    public let lidClose: Bool

    public init(keepAwake: Bool, screenAlwaysOn: Bool, lidClose: Bool) {
        self.keepAwake = keepAwake
        self.screenAlwaysOn = screenAlwaysOn
        self.lidClose = lidClose
    }

    /// 当前应展示的 SF Symbol 名称。lidClose 优先级最高。
    public var symbolName: String {
        if lidClose { return "laptopcomputer" }
        if keepAwake { return screenAlwaysOn ? "sun.max.fill" : "sun.max" }
        return "moon.zzz"
    }

    /// 是否处于激活态（用于面板内着色，菜单栏单色时仍以 symbol 形态区分）。
    public var isActive: Bool { keepAwake || lidClose }
}
