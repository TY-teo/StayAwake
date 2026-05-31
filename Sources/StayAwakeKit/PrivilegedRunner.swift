import Foundation

public enum PrivilegedRunnerError: Error, LocalizedError, Equatable {
    case authorizationFailed
    case commandFailed(status: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .authorizationFailed:
            return "未获得管理员授权"
        case .commandFailed(let status, let message):
            return "命令执行失败 (\(status)): \(message)"
        }
    }
}

/// 进程执行帮助。
enum Shell {
    /// 执行进程，返回 (status, stdout, stderr)。在后台线程运行，不阻塞调用方 actor。
    static func run(_ launchPath: String, _ arguments: [String]) async -> (status: Int32, out: String, err: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchPath)
                process.arguments = arguments
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    continuation.resume(returning: (process.terminationStatus, out, err))
                } catch {
                    continuation.resume(returning: (-1, "", error.localizedDescription))
                }
            }
        }
    }

    /// 以管理员身份执行 shell 命令（osascript 授权弹窗）。取消授权抛 authorizationFailed。
    static func runAdmin(_ command: String) async throws {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        let result = await run("/usr/bin/osascript", ["-e", script])
        guard result.status != 0 else { return }
        if result.err.contains("-128") || result.err.localizedCaseInsensitiveContains("cancel") {
            throw PrivilegedRunnerError.authorizationFailed
        }
        throw PrivilegedRunnerError.commandFailed(
            status: result.status,
            message: result.err.isEmpty ? result.out : result.err
        )
    }
}

/// 读取当前系统 disablesleep 状态（无需特权）。
func systemDisableSleepValue() async -> Bool {
    let result = await Shell.run("/usr/bin/pmset", ["-g"])
    for rawLine in result.out.split(separator: "\n") {
        let line = rawLine.lowercased()
        if line.contains("sleepdisabled") || line.contains("disablesleep") {
            return line.contains(" 1") || line.hasSuffix("1")
        }
    }
    return false
}

/// 需要 root 权限设置 pmset disablesleep 的抽象。
public protocol PrivilegedRunner: Sendable {
    func setDisableSleep(_ enabled: Bool) async throws
    func currentDisableSleep() async -> Bool
}

/// 方案 A：每次通过 osascript 弹管理员授权执行 pmset。
public struct AdminPromptRunner: PrivilegedRunner {
    public init() {}

    public func setDisableSleep(_ enabled: Bool) async throws {
        try await Shell.runAdmin("/usr/bin/pmset -a disablesleep \(enabled ? 1 : 0)")
    }

    public func currentDisableSleep() async -> Bool {
        await systemDisableSleepValue()
    }
}

/// 自适应执行器：先试免密 `sudo -n`，失败（未配置/需密码）则回退到管理员授权弹窗。
public struct AdaptivePrivilegedRunner: PrivilegedRunner {
    public init() {}

    public func setDisableSleep(_ enabled: Bool) async throws {
        let value = enabled ? "1" : "0"
        let result = await Shell.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", value])
        if result.status == 0 { return }
        // sudo -n 失败：未配置免密或需要密码 -> 回退到授权弹窗。
        try await AdminPromptRunner().setDisableSleep(enabled)
    }

    public func currentDisableSleep() async -> Bool {
        await systemDisableSleepValue()
    }
}

/// 免密授权管理：在 /etc/sudoers.d 安装/卸载精确限定到 pmset disablesleep 的 NOPASSWD 规则。
public struct SudoersAuthorization: Sendable {
    public static let sudoersPath = "/etc/sudoers.d/stayawake"

    public init() {}

    /// 生成 sudoers 规则行（纯函数，便于测试）。严格限定到两条精确命令。
    public static func sudoersLine(user: String) -> String {
        "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
    }

    /// 一次性安装免密授权（弹一次管理员授权）。校验、原子落盘、正确权限。
    public func install(user: String) async throws {
        let line = Self.sudoersLine(user: user)
        let tmp = "/tmp/stayawake.sudoers"
        let command = [
            "/bin/echo '# Installed by StayAwake (com.chenran.stayawake)' > \(tmp)",
            "/bin/echo '\(line)' >> \(tmp)",
            "/usr/sbin/visudo -cf \(tmp)",
            "/usr/sbin/chown root:wheel \(tmp)",
            "/bin/chmod 0440 \(tmp)",
            "/bin/mv -f \(tmp) \(Self.sudoersPath)",
            "/usr/sbin/visudo -c"
        ].joined(separator: " && ")
        try await Shell.runAdmin(command)
    }

    /// 卸载免密授权（弹一次管理员授权）。
    public func uninstall() async throws {
        try await Shell.runAdmin("/bin/rm -f \(Self.sudoersPath)")
    }
}
