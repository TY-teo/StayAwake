# StayAwake

一个常驻 macOS 菜单栏的小工具，用最少的点击控制两件事：

1. **保持唤醒**：系统空闲时不休眠（无论是否插电），可选屏幕常亮或允许息屏，支持定时自动关闭。
2. **合盖继续运行**：合上盖子也不休眠，长任务持续运行（含一次性免密授权）。

界面完全采用原生 macOS 系统设置风格（原生控件、系统强调色、跟随系统浅/深外观），常驻菜单栏，无 Dock 图标。

## 安装（下载版）

1. 下载 `StayAwake-x.y.z.dmg`，打开后把 StayAwake 拖进 Applications。
2. 本版本为 ad-hoc 自签、未做 Apple 公证，首次打开会被门禁拦一次，二选一放行：
   - 系统设置 → 隐私与安全性 → 找到“已阻止 StayAwake”，点“仍要打开”；或
   - 终端执行：`xattr -dr com.apple.quarantine /Applications/StayAwake.app`
3. 之后双击即可，图标常驻菜单栏（无 Dock 图标）。

## 运行要求

- macOS 26.0 或更高（界面与底层 API 基于 macOS 26 SDK）。
- 构建需 Xcode 26（Swift 6 工具链）。首次构建前需接受 Xcode 许可：`sudo xcodebuild -license accept`。

## 构建与运行

```bash
# 编译并组装 StayAwake.app（输出到 dist/）
./scripts/build-app.sh release

# 启动
open dist/StayAwake.app
```

启动后图标常驻菜单栏；点击图标弹出控制面板。开发期也可：

```bash
swift build          # 编译
swift test           # 单元测试 + 运行时冒烟
```

## 使用说明

- **保持唤醒**：打开开关即阻止系统空闲休眠。
  - *屏幕策略*：`允许屏幕关闭`（默认，省电，系统不休眠但屏幕可息屏）/ `屏幕常亮`。
  - *保持时长*：`一直` 或 `30 分钟 / 1 / 2 / 5 小时`，到时自动关闭并恢复。
- **合盖继续运行**：打开开关后，面板内会就地出现风险说明与“开启 / 取消”，确认后生效。
  - 默认每次切换需输入一次管理员密码。
  - 打开 **“切换时免输密码”**（一次性授权）后，之后切换合盖不再需要密码（见下）。
- **开机自启**：注册为登录项，开机自动启动。
- **退出 StayAwake**：释放所有电源断言；若合盖处于开启状态会先恢复再退出。

## 合盖免密（一次性授权）

合盖功能依赖 root 权限执行 `pmset -a disablesleep`。本地 ad-hoc 构建无法使用需 Developer ID 的特权守护进程，因此采用 **`/etc/sudoers.d/stayawake` 精确限定的免密规则**：

```
<user> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
```

- 打开“切换时免输密码”会弹一次管理员授权，写入上述规则（`visudo` 校验、`root:wheel 0440`、原子落盘）。
- 之后切换合盖用 `sudo -n` 静默执行，无需密码。
- 关闭该开关会删除规则（再弹一次授权）。
- **安全**：权限严格限定到这两条精确命令，无法被放大用于其他用途。
- **自适应回退**：若未安装免密规则，切换合盖自动回退到管理员授权弹窗，功能不中断。

## 关于合盖（Apple Silicon 重要提示）

在 Apple Silicon（M 系列）上，合盖休眠部分由硬件门控。`pmset disablesleep` 是当前最佳可用机制（与 Amphetamine 同理），**但请在你的机器上实际合盖、放一个运行中的任务验证是否持续运行**。可靠性在**插电**和/或**接外接显示器**（标准 clamshell 模式）时最高。

## 卸载

1. 在面板关闭“切换时免输密码”（移除 sudoers 规则），或手动：`sudo rm -f /etc/sudoers.d/stayawake`。
2. 关闭“开机自启”，退出 StayAwake。
3. 删除 `dist/StayAwake.app`。

退出 / 重启后 `disablesleep` 会恢复；启动自检也会清理崩溃残留。

## 项目结构

```
Package.swift                     SwiftPM（macOS 26，语言模式 v5）
Resources/Info.plist              LSUIElement 菜单栏 App + 显示名 StayAwake
scripts/build-app.sh              编译并组装 StayAwake.app（内置嵌入 AppIcon）
scripts/make-icon.sh              从 icon/ 源 PNG 生成全幅透明 AppIcon.icns
scripts/iconprep.swift            图标预处理：近白转透明、裁白边、方形化
scripts/windowlist.swift          开发辅助：按 PID 列出窗口（截图定位）
Resources/AppIcon.png / .icns     处理后的全幅图标源与多分辨率图标
Sources/StayAwakeKit/             逻辑层（可单测）
  DisplayPolicy / KeepAwakeDuration / MenuBarIconModel
  PowerAssertionManager           保持唤醒：IOPMAssertion 断言
  PrivilegedRunner                AdminPromptRunner / AdaptivePrivilegedRunner / SudoersAuthorization
  LidCloseManager                 合盖：set/restore + 启动自检 + 失败回滚
  Preferences / LoginItemManager  偏好持久化 / 开机自启
Sources/StayAwake/                SwiftUI 界面
  StayAwakeApp                    入口（含 --snapshot 离屏渲染模式）
  AppState                        单一状态源 + 定时器编排
  ControlPanelView / DesignTokens 原生面板（GroupBox + 原生控件）
  SnapshotRenderer                NSHostingView + cacheDisplay 离屏快照
Tests/StayAwakeKitTests/          15 项：模型 / 时长 / 合盖还原 / sudoers 规则 / 断言运行时冒烟
docs/screenshots/                 浅/深外观面板快照
```

## 验证状态

- `swift build -c release`：零错误、零警告。
- `swift test`：15/15 通过（含真实创建电源断言并核对 `pmset -g assertions` 的运行时冒烟）。
- 源码零 emoji；界面浅/深外观快照均已核对。

设计规范见用户级 Skill `apple-native-ui`（`~/.claude/skills/apple-native-ui/`），后续 Apple 平台开发沿用同一套原生设计规则。

## 发布（GitHub Releases / 官网直接下载）

1. `scripts/make-dmg.sh release` 生成 `dist/StayAwake-<版本>.dmg`（含拖拽安装符号链接与首次打开说明）。
2. GitHub 仓库 → Releases → Draft a new release，打 tag（如 `v1.0.0`）。
3. 上传该 DMG 作为 release 附件，发布说明里粘贴上面“安装（下载版）”的放行步骤。
4. 升级版本：改 `Resources/Info.plist` 的 `CFBundleShortVersionString` / `CFBundleVersion`，重跑 make-dmg。
5. 将来若购买 Apple Developer（$99/年），可加 Developer ID 签名 + `notarytool` 公证 + `stapler` 装订，实现下载双击零警告（无需再让用户手动放行）。

未公证版本的限制：用户首次打开需手动放行一次（见“安装”）。合盖功能与所有能力不受影响。
