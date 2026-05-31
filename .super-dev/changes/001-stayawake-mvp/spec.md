# Spec - StayAwake (001-stayawake-mvp)

> 继承: output/screen-sleep-control-{research,prd,architecture,uiux}.md
> 已确认决策: 合盖=方案A 管理员弹窗; 默认"允许屏幕关闭"; MVP 含定时; 显示名"StayAwake"

## 1. 技术契约

| 项 | 确定值 |
| --- | --- |
| 语言/UI | Swift 6 / SwiftUI, 最低 macOS 26.0 |
| 工程 | SwiftPM 可执行目标 + 脚本组装 `.app` bundle |
| Bundle ID | com.chenran.stayawake |
| 显示名 | StayAwake (CFBundleDisplayName) |
| 进程角色 | LSUIElement=true, NSApp.setActivationPolicy(.accessory) |
| 图标系统 | SF Symbols（禁止 emoji） |
| 防休眠 | IOKit IOPMAssertionCreateWithName |
| 合盖 | osascript `do shell script "pmset -a disablesleep N" with administrator privileges` |
| 登录项 | SMAppService.mainApp |

## 2. 关键 API（已核对，不猜）

- `IOPMAssertionCreateWithName(_ AssertionType: CFString, _ AssertionLevel: IOPMAssertionLevel(=255 on), _ Name: CFString, _ AssertionID: UnsafeMutablePointer<IOPMAssertionID>) -> IOReturn`
  - 类型常量: `kIOPMAssertionTypePreventUserIdleSystemSleep`, `kIOPMAssertionTypePreventUserIdleDisplaySleep`
  - 释放: `IOPMAssertionRelease(_ AssertionID)`
- SwiftUI: `MenuBarExtra(_:systemImage:content:)` + `.menuBarExtraStyle(.window)`（macOS 13+）
- Liquid Glass（macOS 26+）: `glassEffect(_ glass: Glass = .regular, in: some Shape, isEnabled:)`, `Glass.regular/.clear/.tint(_:)`, `GlassEffectContainer(spacing:)`, `buttonStyle(.glass)`
  - 约束: 玻璃只用于悬浮控制层；popover 自带玻璃底，内容卡片不再叠 glass（避免 glass-on-glass）。
- `SMAppService.mainApp.register()/unregister()`, `.status`（macOS 13+）

## 3. 验收映射（来自 PRD AC-1..AC-7）

实现需逐条满足 PRD §5。运行期用以下命令核对真实状态：
- `pmset -g assertions` 应出现/消失本 App 的 PreventUserIdleSystemSleep。
- `pmset -g | grep -i disablesleep` 在合盖开关开=1、关/退出=0。

## 4. 还原兜底（强制）

- 关开关、`applicationWillTerminate` → 释放断言 + disablesleep=0。
- 启动自检: 若 UserDefaults 标记 `didSetDisableSleep==true` 且系统仍为 1 → 还原为 0 并清标记。
- 断言句柄异常时进程退出系统自动回收。
