<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="StayAwake">
</p>

<h1 align="center">StayAwake</h1>

<p align="center">常驻 macOS 菜单栏的「保持唤醒 / 合盖继续运行」小工具 · Keep your Mac awake, even with the lid closed.</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2026%2B-007AFF" alt="platform">
  <img src="https://img.shields.io/badge/Swift-6-F05138" alt="swift">
  <img src="https://img.shields.io/github/v/release/TY-teo/StayAwake?display_name=tag&color=2ea44f" alt="release">
  <img src="https://img.shields.io/github/downloads/TY-teo/StayAwake/total?color=2ea44f" alt="downloads">
  <img src="https://img.shields.io/github/license/TY-teo/StayAwake?color=8957e5" alt="license">
</p>

<p align="center">
  <a href="https://ty-teo.github.io/StayAwake/"><img src="https://img.shields.io/badge/官网-在线预览-37A6FF?style=for-the-badge" alt="Website"></a>
  &nbsp;
  <a href="https://github.com/TY-teo/StayAwake/releases/latest"><img src="https://img.shields.io/badge/下载-最新版本-2ea44f?style=for-the-badge" alt="Download"></a>
</p>

StayAwake 用最少的点击控制两件事：让系统空闲时不休眠，以及合上盖子也能继续跑任务。界面完全采用原生 macOS 系统设置风格，跟随系统浅/深外观，常驻菜单栏、不占 Dock。

> 在线预览产品页：<https://ty-teo.github.io/StayAwake/>

<p align="center">
  <img src="docs/screenshots/panel-active-light.png" width="280" alt="浅色">
  &nbsp;&nbsp;
  <img src="docs/screenshots/panel-active-dark.png" width="280" alt="深色">
</p>

## 下载

- 直接下载（v1.0.0）：[StayAwake-1.0.0.dmg](https://github.com/TY-teo/StayAwake/releases/download/v1.0.0/StayAwake-1.0.0.dmg)
- 全部版本：[Releases](https://github.com/TY-teo/StayAwake/releases)

> 要求 macOS 26.0+。本版本为 ad-hoc 自签、未做 Apple 公证，首次打开会被门禁拦一次，二选一放行：
> - 系统设置 → 隐私与安全性 → 找到「已阻止 StayAwake」，点「仍要打开」；或
> - 终端执行：`xattr -dr com.apple.quarantine /Applications/StayAwake.app`

## 功能

- **保持唤醒**：基于 IOPMAssertion 阻止系统空闲休眠，无论插电或电池。
- **屏幕策略**：`允许屏幕关闭`（默认，省电，系统不休眠但屏幕可息屏）或 `屏幕常亮`。
- **定时自动关闭**：一直 / 30 分钟 / 1 / 2 / 5 小时，到时自动恢复。
- **合盖继续运行**：合上盖子也不休眠，任务持续运行。
- **合盖免密**：一次性授权后，开关合盖无需每次输入密码。
- **开机自启**：基于 `SMAppService` 注册登录项。
- **原生体验**：系统设置风格、系统强调色、SF Symbols、菜单栏常驻。

## 使用

1. 打开菜单栏的 StayAwake 图标。
2. 打开「保持唤醒」即阻止空闲休眠；按需选择屏幕策略与保持时长。
3. 打开「合盖继续运行」，面板内会就地出现风险说明与「开启 / 取消」，确认后生效（默认需一次管理员授权）。
4. 打开「切换时免输密码」（一次性授权）后，之后切换合盖不再需要密码。
5. 退出 App 会自动释放保持唤醒并恢复合盖休眠设置。

### 合盖免密如何工作（安全说明）

合盖功能需要 root 执行 `pmset -a disablesleep`。开启「切换时免输密码」会经一次管理员授权，向 `/etc/sudoers.d/stayawake` 写入**严格限定到这两条命令**的免密规则：

```
<user> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
```

之后用 `sudo -n` 静默切换；关闭该开关即删除规则。权限范围仅限「开关合盖防睡」，无法被放大。未安装免密时，自动回退到管理员授权弹窗，功能不中断。

### 关于 Apple Silicon 合盖

在 Apple Silicon（M 系列）上，合盖休眠部分由硬件门控。`pmset disablesleep` 是当前最佳可用机制，但请在你的机器上实际合盖、放一个运行中的任务验证。可靠性在**插电**和/或**接外接显示器**（标准 clamshell）时最高。

## 从源码构建

要求 Xcode 26（Swift 6）。首次构建前接受许可：`sudo xcodebuild -license accept`。

```bash
swift build && swift test          # 编译 + 单元测试（含 pmset 运行时冒烟）
./scripts/build-app.sh release     # 组装 StayAwake.app（内嵌图标）-> dist/
./scripts/make-dmg.sh release      # 打包发布 DMG -> dist/StayAwake-<版本>.dmg
./scripts/make-icon.sh             # 从 icon/ 源 PNG 重新生成 AppIcon.icns
```

## 项目结构

```
Sources/StayAwakeKit/   逻辑层（可单测）：电源断言、特权层、合盖管理、偏好、登录项、图标映射
Sources/StayAwake/      SwiftUI 界面：MenuBarExtra 面板、状态编排、设计 token、离屏快照
Tests/                  15 项单元测试 + 运行时冒烟
Resources/              Info.plist、AppIcon（png/icns）
scripts/                build-app / make-dmg / make-icon / iconprep / windowlist
output/                 研究 / PRD / 架构 / UIUX / 交付文档
docs/screenshots/       浅/深外观面板快照
```

## 发布新版本

1. 改 `Resources/Info.plist` 的 `CFBundleShortVersionString` 与 `CFBundleVersion`。
2. `./scripts/make-dmg.sh release` 生成新 DMG。
3. GitHub → Releases → 新建 tag（如 `v1.1.0`）→ 上传 DMG → 填写说明（参考 `CHANGELOG.md`）→ 发布。
4. 升级到「双击零警告」：购买 Apple Developer（$99/年）后加 Developer ID 签名 + `notarytool` 公证 + `stapler` 装订即可，功能不变。

## 设计规范

界面遵循一套「原生、非 AI 感」的 macOS 设计规则（原生控件、克制配色、系统外观、SF Symbols、玻璃只用于悬浮层）。详见随附的 Claude Code 技能 `apple-native-ui`。

## 许可证

[MIT](LICENSE) © 2026 TY-teo
