# ScreenSleepControl - 研究报告 (Research)

> Super Dev | 阶段 1/9 research | 主导专家: PM + ARCHITECT
> 生成时间: 2026-05-30 | 宿主: Claude Code | 平台: macOS 26.4 (Tahoe), Xcode 26.5

## 1. 目标与背景

用户需要一个常驻 macOS 菜单栏的小工具，提供两个核心控制开关：

1. 一键"不休眠"：无论是否插电源，系统都保持唤醒，便于长任务持续运行。
2. 合盖持续运行：盖上 MacBook 盖子后系统仍继续运行，不进入休眠。

视觉风格要求贴合 iOS 26 / macOS 26 的"液态玻璃 (Liquid Glass)"语言，并允许直接在菜单栏弹出的组件上操作。

## 2. 同类产品调研

| 产品 | 形态 | 防空闲休眠 | 合盖运行 | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- |
| Amphetamine | 菜单栏 | 支持 | 5.0+ 支持(开关) | 电源断言 + 触发器 | 功能最全，但合盖模式在新系统上可靠性依赖版本 |
| KeepingYouAwake | 菜单栏(开源) | 支持 | 不可靠 | 封装 `caffeinate` / IOKit 断言 | 轻量，无合盖专项处理 |
| Caffeine / Theine / Lungo | 菜单栏 | 支持 | 不支持 | 电源断言 | 仅防空闲休眠 |
| 系统设置 + `pmset` | 命令行 | 仅插电时 | `pmset disablesleep 1` | 修改电源管理属性(需 root) | 官方但需手动且全局生效 |

调研结论：

- 防空闲休眠是成熟能力，标准做法是创建电源断言 (IOPMAssertion)，等价于系统 `caffeinate` 工具，无需特权，可即时开关，且不修改用户的"节能"系统设置。
- 合盖持续运行是真正的难点。电源断言与 `caffeinate` 在"合盖 + 不插电"场景下不可靠（Apple 在新系统/Apple Silicon 上为省电与散热强制合盖休眠）。业界可靠做法是设置 `pmset -a disablesleep 1`，但该命令需要 root 权限，且是全局开关，必须在关闭功能/退出应用时还原为 `0`。

## 3. 关键技术结论

### 3.1 防空闲休眠（功能一）

通过 `IOKit.pwr_mgt` 的 `IOPMAssertionCreateWithName` 创建断言，常用断言类型：

- `kIOPMAssertionTypePreventUserIdleSystemSleep`：阻止系统因空闲而休眠（核心）。
- `kIOPMAssertionTypePreventUserIdleDisplaySleep`：阻止显示器休眠（可选，决定"屏幕是否常亮"）。
- `kIOPMAssertionTypePreventSystemSleep`：阻止系统休眠（含部分外部触发场景）。

特性：

- 与是否插电无关，断言生效后空闲不再休眠，满足"无论是否插电源"的要求。
- 进程退出 / 崩溃时断言自动释放，安全，不会把机器永久卡在不休眠状态。
- 可叠加"屏幕可关闭但系统不休眠"模式：仅创建 SystemSleep 断言，不创建 DisplaySleep 断言——长任务时省电（黑屏但任务继续）。

### 3.2 合盖持续运行（功能二）

唯一可靠的方式是修改电源管理属性：

```
pmset -a disablesleep 1   # 开启：合盖也不休眠（全局）
pmset -a disablesleep 0   # 关闭：恢复默认合盖休眠
```

约束与风险：

- 需要管理员/root 权限执行。
- 全局生效，是"关闭一切休眠"的开关，必须谨慎，并在关闭开关、应用退出时主动还原。
- 合盖运行会带来散热与电量风险（机内散热受限），UI 需明确告警。
- 若应用异常崩溃且未还原，设置会残留——需要"启动时自检并还原"的兜底逻辑。

特权执行的候选方案（架构文档详述并待用户确认）：

- 方案 A：管理员授权弹窗，每次切换合盖开关时通过 Authorization Services / `osascript ... with administrator privileges` 执行 `pmset`。最简单、无需签名、无需常驻守护进程，但每次切换需输入密码。
- 方案 B：`SMAppService` 注册特权 LaunchDaemon（macOS 13+），首次授权一次，之后通过 XPC 即时切换并可由守护进程兜底还原。体验最佳，但需要对 helper 进行代码签名（分发需 Developer ID）。

### 3.3 菜单栏与界面（macOS 26 Liquid Glass）

- 使用 SwiftUI `MenuBarExtra` 场景作为常驻入口；采用 `.menuBarExtraStyle(.window)` 以获得可自定义的弹出面板（默认 `.menu` 样式只能做下拉菜单，无法承载玻璃化控件）。
- 菜单栏图标使用 SF Symbols（Apple 官方符号系统，非 emoji），随状态切换（唤醒 / 允许休眠 / 合盖模式启用）。
- 液态玻璃通过 `.glassEffect(_:in:)` 修饰符实现，变体含 `.regular` / `.clear` / `.tint(_:)` / `.interactive()`；多个玻璃元素需放入 `GlassEffectContainer` 共享采样区并支持邻近融合。
- 设计纪律（来自 Apple HIG 与社区最佳实践）：
  - 玻璃只用于"悬浮的导航/控制层"，不要给内容本身套玻璃，禁止玻璃叠玻璃。
  - `Menu` 放进 `GlassEffectContainer` 会破坏融合动画——交互控件直接用 `.glassEffect(.regular.interactive())`。
  - 菜单栏面板建议锁定外观（可在 scene 级固定为深色），保证玻璃质感稳定。
  - 必须测试"减弱透明度 (Reduce Transparency)"无障碍开关：关闭透明后布局仍可用，玻璃只承担装饰而非信息层级。
- 旧系统兜底：本项目最低目标 macOS 26，原生使用 `glassEffect`；若未来需兼容 26 以下，需 `if #available` 回退到 `.ultraThinMaterial`。

## 4. 风险登记

| 风险 | 等级 | 缓解 |
| --- | --- | --- |
| 合盖模式散热/电量风险 | 高 | UI 强提示；建议插电使用；提供快捷关闭 |
| `pmset disablesleep` 残留未还原 | 高 | 退出时还原 + 启动自检还原 + 守护兜底（方案 B） |
| 特权 helper 需要签名 | 中 | 个人本地构建可用方案 A 规避；分发再上方案 B |
| Liquid Glass API 版本差异 | 中 | 锁定 macOS 26 最低目标；编码前用官方文档核对 API 签名 |
| 菜单栏图标语义不清 | 低 | 用 SF Symbols 多状态图标 + 文案 |

## 5. 引用来源

- Amphetamine 官方支持 / TechPP 合盖说明 — https://iffy.freshdesk.com/support/solutions/articles/48000078314 ; https://techpp.com/2021/06/18/macbook-clamshell-mode-keep-awake-amphetamine/
- Macworld 合盖与 `pmset disablesleep` 说明 — https://www.macworld.com/article/673295/
- SwiftUI MenuBarExtra 菜单栏工具 — https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/
- iOS 26 / macOS Tahoe Liquid Glass 指南与参考 — https://www.atelier-socle.com/en/articles/swiftui-liquid-glass-guide ; https://github.com/conorluddy/LiquidGlassReference
- 苹果开发者文档与 WWDC25 Session 219/323/310（Meet Liquid Glass / Build a SwiftUI app with the new design）
