# StayAwake - 交付说明 / Proof-Pack

> Super Dev | 阶段 9/9 delivery | 2026-05-31
> 工程名 ScreenSleepControl，显示名/产品名 StayAwake，bundle id com.chenran.stayawake

## 1. 交付物

| 类型 | 路径 |
| --- | --- |
| 可运行应用 | `dist/StayAwake.app`（菜单栏 App，LSUIElement） |
| 构建脚本 | `scripts/build-app.sh release` |
| 源码 | `Sources/StayAwakeKit/`（逻辑）、`Sources/StayAwake/`（UI） |
| 测试 | `Tests/StayAwakeKitTests/`（15 项） |
| 文档 | `output/*-research/prd/architecture/uiux/delivery.md` |
| 设计规范 Skill | `~/.claude/skills/apple-native-ui/` |
| 使用说明 | `README.md` |

## 2. 需求达成

| 需求 | 状态 | 实现 |
| --- | --- | --- |
| 一键不休眠（插电/电池均生效） | 完成 | IOPMAssertion `PreventUserIdleSystemSleep` |
| 屏幕策略（常亮 / 允许息屏） | 完成 | 可选叠加 `PreventUserIdleDisplaySleep` |
| 定时自动关闭 | 完成 | 30m/1h/2h/5h/一直，倒计时 |
| 合盖继续运行 | 完成 | `pmset -a disablesleep`（经特权层） |
| 合盖免密（一次授权后免密） | 完成 | `/etc/sudoers.d/stayawake` + `sudo -n`，自适应回退弹窗 |
| 菜单栏常驻 + 直接操作 | 完成 | `MenuBarExtra(.window)` + accessory |
| 贴合 iOS 26 / 系统设计 | 完成 | 原生 macOS 系统设置风格（去 AI 感返工后） |
| 开机自启 | 完成 | `SMAppService.mainApp` |

## 3. 质量门禁结果

- 构建：`swift build -c release` 零错误、零警告（干净重建核验）。
- 测试：`swift test` 15/15 通过。
  - 逻辑：图标状态映射、时长格式化、合盖还原与失败回滚、sudoers 规则限定与路径。
  - 运行时冒烟：真实创建 `PreventUserIdleSystemSleep` 断言并在 `pmset -g assertions` 核对存在，释放后消失。
- 红线：源码零 emoji；图标全部 SF Symbols；颜色取自语义色/系统强调色；跟随系统外观。
- UI：浅/深外观面板快照（`docs/screenshots/`）均已核对可读、风格一致。

## 4. 安全与还原

- 特权操作仅 `pmset -a disablesleep`，sudoers 规则精确限定到两条命令（root:wheel 0440，`visudo` 校验通过）。
- 不硬编码任何凭证；管理员授权由系统弹窗处理。
- 还原兜底：关开关 / 退出释放断言并 disablesleep=0；启动自检清理崩溃残留；断言随进程退出由系统回收。

## 5. 已知限制（诚实声明）

- **Apple Silicon 合盖**：合盖休眠部分由硬件门控；`disablesleep` 为最佳可用机制，需真机合盖实测；插电/接外显最稳。当前机型 M5 MacBook Air、无外显时尤需验证。
- **分发**：当前为 ad-hoc 本地签名，未用 Developer ID / 公证；如需更顺滑的免密（特权守护进程 SMAppService）或对外分发，需 Developer ID。
- **登录项**：未签名分发时 `SMAppService` 登录项注册可能受限；本地构建可用。

## 6. 待用户实测项

1. 合盖开关：点开后面板内联“开启/取消”，确认面板不消失。
2. 免密：开启“切换时免输密码”一次（输一次密码），其后反复切换合盖应零弹框。
3. 物理合盖：放一个运行中的任务，合盖后确认持续运行（建议先插电验证）。
