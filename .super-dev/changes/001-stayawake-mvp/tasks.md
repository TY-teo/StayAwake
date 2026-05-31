# Tasks - StayAwake (001-stayawake-mvp)

前端优先，每步建/构建后做运行验证。

## T0 工程脚手架
- [ ] Package.swift（executable, platforms macOS "26.0", test target）
- [ ] 目录结构 Sources/StayAwake/...
- [ ] Resources/Info.plist（LSUIElement, bundle id, display name）
- [ ] scripts/build-app.sh（swift build -c release → 组装 StayAwake.app）
- [ ] 门禁: Xcode license 已 accept；`swift build` 零错误

## T1 模型与设计 token（前端基座）
- [ ] DesignTokens.swift（颜色/间距/字阶语义）
- [ ] DisplayPolicy.swift（.screenOn/.allowScreenOff）
- [ ] KeepAwakeDuration.swift（.indefinite/.minutes(n) + 预设列表 + 倒计时格式化）

## T2 菜单栏 + 玻璃面板（frontend，预览确认门）
- [ ] StayAwakeApp.swift（@main, MenuBarExtra(.window), accessory policy）
- [ ] MenuBarController/icon 状态机（SF Symbols 随状态切换）
- [ ] ControlPanelView + KeepAwakeCard + LidCloseCard + StatusFooter
- [ ] GlassToggleStyle / 原生控件（不 glass-on-glass）
- [ ] 自检: 源码零 emoji；颜色取自 token；Reduce Transparency 降级可用
- [ ] 运行: 启动 .app → 菜单栏出现图标 → 弹出面板截图 → 预览确认门

## T3 防休眠后端（backend）
- [ ] PowerAssertionManager（按 DisplayPolicy 建/释放断言）
- [ ] 接入 AppState 主开关 + 屏幕策略
- [ ] 定时器：到期自动关闭并还原图标
- [ ] 验证: pmset -g assertions 出现/消失

## T4 合盖特权层（backend）
- [ ] PrivilegedRunner 协议 + AdminPromptRunner（osascript 管理员授权）
- [ ] LidCloseManager（set/restore + 启动自检 + 退出还原）
- [ ] 接入 LidCloseCard 开关 + 首次风险确认 sheet
- [ ] 验证: 开=disablesleep 1, 关/退出=0

## T5 系统集成
- [ ] LoginItemManager（SMAppService 开机自启）
- [ ] Preferences（UserDefaults 持久化偏好 + 还原标记）
- [ ] applicationWillTerminate 还原钩子

## T6 质量与交付
- [ ] 单测: PowerAssertion 模式映射 / LidClose 还原逻辑（mock PrivilegedRunner）
- [ ] swift build 零警告；运行无控制台红错
- [ ] 运行冒烟核对 AC-1..AC-7
- [ ] README + 交付说明（构建/安装/使用/风险）
