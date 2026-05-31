import Foundation

/// UserDefaults 持久化偏好 + 合盖还原标记。
public final class Preferences {
    private let defaults: UserDefaults

    private enum Key {
        static let displayPolicy = "displayPolicy"
        static let lastDurationMinutes = "lastDurationMinutes" // -1 = indefinite
        static let didSetDisableSleep = "didSetDisableSleep"
        static let passwordlessInstalled = "passwordlessInstalled"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var displayPolicy: DisplayPolicy {
        get { DisplayPolicy(rawValue: defaults.string(forKey: Key.displayPolicy) ?? "") ?? .allowScreenOff }
        set { defaults.set(newValue.rawValue, forKey: Key.displayPolicy) }
    }

    public var lastDuration: KeepAwakeDuration {
        get {
            let value = defaults.object(forKey: Key.lastDurationMinutes) as? Int ?? -1
            return value < 0 ? .indefinite : .minutes(value)
        }
        set {
            switch newValue {
            case .indefinite: defaults.set(-1, forKey: Key.lastDurationMinutes)
            case .minutes(let m): defaults.set(m, forKey: Key.lastDurationMinutes)
            }
        }
    }

    /// 是否由本 App 设置过 disablesleep（用于启动自检还原，避免误改用户手动设置）。
    public var didSetDisableSleep: Bool {
        get { defaults.bool(forKey: Key.didSetDisableSleep) }
        set { defaults.set(newValue, forKey: Key.didSetDisableSleep) }
    }

    /// 是否已安装合盖免密授权（/etc/sudoers.d 规则）。
    public var passwordlessInstalled: Bool {
        get { defaults.bool(forKey: Key.passwordlessInstalled) }
        set { defaults.set(newValue, forKey: Key.passwordlessInstalled) }
    }
}
