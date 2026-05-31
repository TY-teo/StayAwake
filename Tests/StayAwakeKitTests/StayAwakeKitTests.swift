import XCTest
@testable import StayAwakeKit

final class MenuBarIconModelTests: XCTestCase {
    func testAllowSleepSymbol() {
        let icon = MenuBarIconModel(keepAwake: false, screenAlwaysOn: false, lidClose: false)
        XCTAssertEqual(icon.symbolName, "moon.zzz")
        XCTAssertFalse(icon.isActive)
    }

    func testKeepAwakeScreenOffSymbol() {
        let icon = MenuBarIconModel(keepAwake: true, screenAlwaysOn: false, lidClose: false)
        XCTAssertEqual(icon.symbolName, "sun.max")
        XCTAssertTrue(icon.isActive)
    }

    func testKeepAwakeScreenOnSymbol() {
        let icon = MenuBarIconModel(keepAwake: true, screenAlwaysOn: true, lidClose: false)
        XCTAssertEqual(icon.symbolName, "sun.max.fill")
    }

    func testLidCloseTakesPriority() {
        let icon = MenuBarIconModel(keepAwake: true, screenAlwaysOn: true, lidClose: true)
        XCTAssertEqual(icon.symbolName, "laptopcomputer")
        XCTAssertTrue(icon.isActive)
    }
}

final class KeepAwakeDurationTests: XCTestCase {
    func testShortLabels() {
        XCTAssertEqual(KeepAwakeDuration.indefinite.shortLabel, "一直")
        XCTAssertEqual(KeepAwakeDuration.minutes(30).shortLabel, "30m")
        XCTAssertEqual(KeepAwakeDuration.minutes(60).shortLabel, "1h")
        XCTAssertEqual(KeepAwakeDuration.minutes(120).shortLabel, "2h")
        XCTAssertEqual(KeepAwakeDuration.minutes(300).shortLabel, "5h")
    }

    func testSeconds() {
        XCTAssertNil(KeepAwakeDuration.indefinite.seconds)
        XCTAssertEqual(KeepAwakeDuration.minutes(2).seconds, 120)
    }

    func testPresetsAreUnique() {
        let labels = KeepAwakeDuration.presets.map(\.shortLabel)
        XCTAssertEqual(Set(labels).count, labels.count)
    }

    func testFormatCountdown() {
        XCTAssertEqual(formatCountdown(0), "00:00:00")
        XCTAssertEqual(formatCountdown(65), "00:01:05")
        XCTAssertEqual(formatCountdown(3661), "01:01:01")
        XCTAssertEqual(formatCountdown(-10), "00:00:00")
    }
}

/// 可控的特权层假实现，用于验证还原逻辑而不触发真实授权弹窗。
final class MockPrivilegedRunner: PrivilegedRunner, @unchecked Sendable {
    var disableSleepValue: Bool
    var shouldFail: Bool
    private(set) var setCalls: [Bool] = []

    init(initial: Bool = false, shouldFail: Bool = false) {
        self.disableSleepValue = initial
        self.shouldFail = shouldFail
    }

    func setDisableSleep(_ enabled: Bool) async throws {
        if shouldFail { throw PrivilegedRunnerError.authorizationFailed }
        setCalls.append(enabled)
        disableSleepValue = enabled
    }

    func currentDisableSleep() async -> Bool { disableSleepValue }
}

/// 运行时冒烟：真实创建电源断言并核对 `pmset -g assertions` 可见，释放后消失。
final class PowerAssertionIntegrationTests: XCTestCase {
    private func stayAwakeAssertionPresent() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "assertions"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return out.contains("StayAwake")
    }

    func testAssertionRegistersWithSystem() {
        let manager = PowerAssertionManager()
        XCTAssertFalse(manager.isActive)

        manager.apply(enabled: true, policy: .allowScreenOff)
        XCTAssertTrue(manager.isActive)

        // 轮询等待 powerd 反映断言（创建后有传播延迟）。
        var present = false
        for _ in 0..<20 {
            if stayAwakeAssertionPresent() { present = true; break }
            Thread.sleep(forTimeInterval: 0.1)
        }

        manager.releaseAll()
        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(present, "pmset 应在创建后显示 StayAwake 系统唤醒断言")
    }
}

final class SudoersAuthorizationTests: XCTestCase {
    func testSudoersLineScopedToExactCommands() {
        let line = SudoersAuthorization.sudoersLine(user: "chenran")
        XCTAssertEqual(
            line,
            "chenran ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
        )
        // 安全：不得出现通配符或放宽到任意命令。
        XCTAssertFalse(line.contains("ALL: ALL"))
        XCTAssertFalse(line.contains("pmset *"))
        XCTAssertTrue(line.contains("NOPASSWD"))
    }

    func testSudoersPath() {
        // 文件名无点、位于 sudoers.d，避免被 sudo 忽略。
        XCTAssertEqual(SudoersAuthorization.sudoersPath, "/etc/sudoers.d/stayawake")
        XCTAssertFalse((SudoersAuthorization.sudoersPath as NSString).lastPathComponent.contains("."))
    }
}

final class LidCloseManagerTests: XCTestCase {
    private func makePreferences() -> Preferences {
        let suite = "stayawake.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return Preferences(defaults: defaults)
    }

    @MainActor
    func testSetEnabledSuccess() async {
        let prefs = makePreferences()
        let runner = MockPrivilegedRunner()
        let manager = LidCloseManager(runner: runner, preferences: prefs)

        let ok = await manager.setEnabled(true)
        XCTAssertTrue(ok)
        XCTAssertTrue(manager.isEnabled)
        XCTAssertTrue(prefs.didSetDisableSleep)
        XCTAssertEqual(runner.setCalls, [true])
    }

    @MainActor
    func testSetEnabledFailureRollsBack() async {
        let prefs = makePreferences()
        let runner = MockPrivilegedRunner(shouldFail: true)
        let manager = LidCloseManager(runner: runner, preferences: prefs)

        let ok = await manager.setEnabled(true)
        XCTAssertFalse(ok)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(prefs.didSetDisableSleep)
    }

    @MainActor
    func testReconcileRestoresResidual() async {
        let prefs = makePreferences()
        prefs.didSetDisableSleep = true
        let runner = MockPrivilegedRunner(initial: true)
        let manager = LidCloseManager(runner: runner, preferences: prefs)

        await manager.reconcileOnLaunch()

        XCTAssertEqual(runner.setCalls, [false], "残留时应还原为关闭")
        XCTAssertFalse(prefs.didSetDisableSleep)
        XCTAssertFalse(manager.isEnabled)
    }

    @MainActor
    func testReconcileNoopWhenNoFlag() async {
        let prefs = makePreferences()
        prefs.didSetDisableSleep = false
        let runner = MockPrivilegedRunner(initial: true)
        let manager = LidCloseManager(runner: runner, preferences: prefs)

        await manager.reconcileOnLaunch()

        XCTAssertTrue(runner.setCalls.isEmpty, "无本 App 标记时不应改动系统设置")
    }
}
