# ScreenSleepControl - 架构设计 (Architecture)

> Super Dev | 阶段 2/9 docs | 主导专家: ARCHITECT
> 继承自: research.md + prd.md

## 1. 技术栈

| 层 | 选型 | 版本/要求 | 理由 |
| --- | --- | --- | --- |
| 语言 | Swift | 6 (Xcode 26.5) | 平台原生 |
| UI | SwiftUI + AppKit 桥接 | macOS 26 SDK | MenuBarExtra + Liquid Glass 原生支持 |
| 菜单栏 | `MenuBarExtra` (`.window` 样式) | macOS 13+ | 承载自定义玻璃面板 |
| 玻璃 | `glassEffect` / `GlassEffectContainer` | macOS 26 | 原生液态玻璃 |
| 防休眠 | `IOKit.pwr_mgt` IOPMAssertion | 系统框架 | 无特权、即时、自动释放 |
| 合盖 | `pmset disablesleep` (经特权层) | 系统命令 | 唯一可靠的合盖方案 |
| 登录项 | `ServiceManagement` `SMAppService` | macOS 13+ | 开机自启 |
| 工程 | SwiftPM + Xcode 项目 | - | 本地构建运行 |

最低部署目标：macOS 26.0。图标系统：SF Symbols（系统内置，满足"非 emoji 图标"红线）。

## 2. 模块划分

```
ScreenSleepControlApp (App 入口, MenuBarExtra scene)
├─ AppState (ObservableObject, 单一状态源)
│    ├─ keepAwakeEnabled / displayPolicy(.screenOn|.allowScreenOff)
│    ├─ keepAwakeDuration(.indefinite|.minutes(n)) + 倒计时
│    ├─ lidCloseEnabled
│    └─ launchAtLogin
├─ PowerAssertionManager      // 功能一：IOPMAssertion 创建/释放
├─ LidCloseManager            // 功能二：经 PrivilegedRunner 调 pmset，含还原兜底
│    └─ PrivilegedRunner      // 协议：执行需要 root 的命令（实现待定，见 §4）
├─ MenuBarController          // 图标状态映射 + SF Symbol 选择
├─ LoginItemManager          // SMAppService 登录项
├─ Persistence               // UserDefaults 偏好
└─ UI/
     ├─ ControlPanelView         // 玻璃面板根视图
     ├─ KeepAwakeCard            // 主开关 + 屏幕策略 + 时长
     ├─ LidCloseCard             // 合盖开关 + 风险提示
     ├─ StatusFooter             // 状态摘要 + 设置 + 退出
     └─ GlassToggleStyle / DesignTokens
```

依赖方向单向：UI 依赖 AppState；AppState 调用各 Manager；Manager 不反向依赖 UI。

## 3. 核心数据流

```
用户在面板切换开关
   → AppState 更新 @Published 状态
   → 对应 Manager 执行副作用 (创建/释放断言 或 调用 pmset)
   → Manager 回传结果(成功/失败/需授权)
   → AppState 反映真实状态 → UI + 菜单栏图标刷新
```

状态以"实际系统效果"为准：Manager 操作失败时回滚 AppState，避免 UI 显示与真实电源行为不一致。

## 4. 关键决策：合盖功能的特权执行（待用户确认）

`pmset disablesleep` 需要 root。两套方案：

### 方案 A — 管理员授权弹窗（推荐用于 v1 本地自用）

- 切换合盖开关时，通过 `osascript`/Authorization Services 以管理员身份执行 `pmset -a disablesleep <0|1>`。
- 优点：零额外组件、无需代码签名、本地构建即可运行、实现快。
- 代价：每次切换需输入一次管理员密码（合盖开关是低频操作，可接受）。
- 还原兜底：App 退出时尝试还原；启动时自检 `pmset -g`，若残留为 1 且标记位显示是本 App 设置，提示并还原。

### 方案 B — SMAppService 特权 LaunchDaemon

- 注册一个常驻 root 守护进程，App 经 XPC 调用它执行 `pmset`，并由守护进程在 App 退出/崩溃时兜底还原。
- 优点：授权一次、即时切换、最强还原保证、体验最佳。
- 代价：helper 需代码签名（分发需 Developer ID + 公证）；实现与调试更重。

接口抽象 `PrivilegedRunner`（两方案共用，便于后续从 A 升级到 B）：

```swift
protocol PrivilegedRunner {
    func setDisableSleep(_ enabled: Bool) async throws
    func currentDisableSleepValue() async -> Bool
}
```

**v1 采用方案 A（`AdminPromptRunner`）**——切换合盖开关时通过 `osascript ... with administrator privileges` 执行 `pmset -a disablesleep <0|1>`。显示名「StayAwake」，MVP 含定时自动关闭。

### v1.1 免密升级（2026-05-31，已实现）

调研结论：ad-hoc 本地构建无 Developer ID，SMAppService 守护进程不可用，Authorization Services 的 AEWP 已废弃且不安全。采用 **`/etc/sudoers.d/stayawake` 免密 drop-in**：

- 一次性授权（弹一次管理员）写入精确限定的 sudoers 行：
  `<user> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0`
  （root:wheel 0440，`visudo -c` 校验，原子 mv 落盘，文件名无点）。
- 之后切换合盖用 `sudo -n /usr/bin/pmset -a disablesleep <0|1>`，无需密码。
- `AdaptivePrivilegedRunner`：先试 `sudo -n`，失败（未配置/需密码）自动回退 `AdminPromptRunner`（弹窗），功能永不中断。
- 安全：权限严格限定到这两条命令；卸载即删除该文件（弹一次管理员）。
- 硬件提醒：Apple Silicon 合盖休眠部分由硬件门控，`disablesleep` 为最佳可用机制，需真机合盖验证；插电/接外显最稳。

## 5. 防休眠断言策略（功能一）

| 模式 | 创建的断言 | 效果 |
| --- | --- | --- |
| 保持唤醒 + 屏幕常亮 | PreventUserIdleSystemSleep + PreventUserIdleDisplaySleep | 系统与屏幕都不休眠 |
| 保持唤醒 + 允许屏幕关闭(默认) | PreventUserIdleSystemSleep | 系统不休眠，屏幕可息屏 |
| 关闭 | 释放全部断言 | 恢复系统默认 |

- 断言句柄保存在 `PowerAssertionManager`，切换/退出时显式 `IOPMAssertionRelease`。
- 进程崩溃时系统自动回收断言（天然安全）。
- 定时模式：用 `Task`/`Timer` 在到期时调用关闭逻辑。

## 6. 安全与还原兜底矩阵

| 场景 | 断言(功能一) | disablesleep(功能二) |
| --- | --- | --- |
| 用户关开关 | 立即释放 | 立即置 0 |
| App 正常退出 | 释放(applicationWillTerminate) | 置 0 |
| App 崩溃 | 系统自动回收 | 方案A：下次启动自检还原；方案B：守护进程还原 |
| 系统重启 | 断言消失 | disablesleep 不持久化跨重启(恢复默认) |

启动自检：读取 `pmset -g`，结合本 App 在 UserDefaults 写入的"我设置过 disablesleep"标记，决定是否自动还原，避免误改用户手动设置的值。

## 7. 权限与配置

- `Info.plist`：`LSUIElement = YES`（纯菜单栏，无 Dock）。
- App Sandbox：合盖功能需执行系统命令/授权，方案 A 下建议关闭 Sandbox（本地自用）；若上方案 B，由守护进程承担特权，主 App 可保持较严权限。最终随特权方案确定。
- 无网络、无用户数据采集、无外部服务。

## 8. 构建与验证

- `swift build` / Xcode 构建零错误零警告。
- 运行期冒烟：切换两个开关 → 用 `pmset -g assertions` 和 `pmset -g | grep disablesleep` 核对真实状态 → 退出后复核已还原。
- 该项目无传统单元可测业务逻辑较少，但对 `PowerAssertionManager` 的模式映射、`LidCloseManager` 的还原逻辑编写单元测试（注入 mock `PrivilegedRunner`）。
