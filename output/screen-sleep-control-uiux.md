# ScreenSleepControl - UI/UX 设计 (UIUX)

> Super Dev | 阶段 2/9 docs | 主导专家: UIUX
> 设计语言: macOS 26 Liquid Glass (贴合 iOS 26)

## 1. 设计原则

- 玻璃只用于悬浮控制层，内容保持在基底层；禁止玻璃叠玻璃。
- 直接在菜单栏弹出的玻璃面板上操作，两个核心开关一目了然、即点即生效。
- 信息层级清晰：状态优先于装饰；去掉无意义的大色块/渐变 hero。
- 尊重无障碍：减弱透明度开启时降级为不透明材质仍可用；所有控件有 accessibility label。

## 2. 锁定的工具链（编码前必须确认，编码中不得更换）

| 项 | 选型 |
| --- | --- |
| 图标库 | SF Symbols（系统内置，禁止 emoji 作为图标/占位） |
| 字体 | 系统 San Francisco（`.title3`/`.headline`/`.subheadline`/`.caption` 语义字阶，非"默认直出"——显式定义字阶与字重层级） |
| 玻璃 | `glassEffect(.regular[.interactive()])` + `GlassEffectContainer` |
| 组件库 | 原生 SwiftUI 控件 + 自定义 `GlassToggleStyle` |
| 主题 | 菜单栏面板锁定深色外观，保证玻璃质感一致 |

## 3. 设计 Token

```
颜色（语义化，非硬编码散落）
  accent.awake      = Color.green   (保持唤醒激活)
  accent.lid        = Color.orange  (合盖运行激活, 警示性暖色)
  accent.idle       = Color.secondary (允许休眠/未激活)
  text.primary      = .primary
  text.secondary    = .secondary
  surface           = .glassEffect(.regular)        // 卡片
  surface.warn      = .glassEffect(.regular.tint(.orange.opacity(0.18)))

圆角
  radius.card = 16  (in: .rect(cornerRadius: .containerConcentric))
  radius.control = capsule

间距（8pt 栅格）
  space.xs=4  space.s=8  space.m=12  space.l=16  space.xl=24
  面板内边距 = 16, 卡片间距 = 12

字阶
  panel.title     = .headline / semibold
  card.title      = .subheadline / medium
  card.subtitle   = .caption / regular / text.secondary
  status          = .caption / monospaced-digit (倒计时)
```

禁止：紫/粉渐变、emoji 图标、纯默认字体直出、无层级卡片墙。

## 4. 菜单栏图标状态机（SF Symbols）

| 状态 | Symbol | 着色 |
| --- | --- | --- |
| 允许休眠（全关） | `moon.zzz` | 单色 secondary |
| 保持唤醒（屏幕可关） | `sun.max` | accent.awake |
| 保持唤醒 + 屏幕常亮 | `sun.max.fill` | accent.awake |
| 合盖运行启用 | 叠加 `laptopcomputer` 角标或切 `bolt.shield` | accent.lid |

图标用 `MenuBarExtra(... systemImage:)`，状态变化时切换 symbol 名与 `.symbolRenderingMode`。

## 5. 弹出面板布局（`.menuBarExtraStyle(.window)`，宽约 300pt）

```
┌──────────────────────────────────────────┐
│  ScreenSleepControl              [当前状态] │   ← panel.title + 状态徽标
│                                            │
│  ┌────────────────────────────────────┐   │ ← KeepAwakeCard (glass card)
│  │  [sun.max]  保持唤醒          (●—○) │   │   主开关 GlassToggle
│  │  系统空闲时不休眠                    │   │   card.subtitle
│  │  ── 屏幕策略 ───────────────────    │   │
│  │   ○ 屏幕常亮   ◉ 允许屏幕关闭        │   │   分段控制
│  │  ── 时长 ──────────────────────     │   │
│  │   [一直] [30m] [1h] [2h] [5h]       │   │   胶囊选择 + 倒计时显示
│  └────────────────────────────────────┘   │
│                                            │
│  ┌────────────────────────────────────┐   │ ← LidCloseCard (glass, warn tint)
│  │  [laptopcomputer] 合盖继续运行 (○—●)│   │   独立开关
│  │  合上盖子也不休眠，任务持续运行       │   │
│  │  [exclamationmark.triangle] 散热/   │   │   风险提示行(开启前)
│  │   电量风险，建议插电使用             │   │
│  └────────────────────────────────────┘   │
│                                            │
│  ── StatusFooter ───────────────────────  │
│  [info] 已保持唤醒 01:23:45                 │   状态摘要(monospaced-digit)
│  [gearshape] 开机自启 ▢      [退出 App]    │   登录项开关 + 退出
└──────────────────────────────────────────┘
```

- 两张卡片放入同一 `GlassEffectContainer(spacing:)`，邻近时自然融合。
- 开关用自定义 `GlassToggleStyle`（胶囊轨道 + `.glassEffect(.regular.interactive())`），不要把 `Menu` 套进容器（会破坏融合动画）。
- 分段/胶囊选择项激活态用 accent 色填充 + 玻璃高亮。

## 6. 交互与组件状态

| 组件 | 默认 | Hover | 激活/选中 | 禁用 |
| --- | --- | --- | --- | --- |
| 主开关 | 灰轨道 | 轨道微亮 | accent 填充 + 滑块右移动画 | 降透明度 |
| 屏幕策略分段 | 描边 | 高亮 | accent 填充文字反白 | - |
| 时长胶囊 | 描边 | 高亮 | accent 描边/填充 | 关闭唤醒时整组禁用 |
| 合盖开关 | 灰轨道 | - | orange 填充 + 首次弹确认 | - |
| 退出按钮 | 文本按钮 | 背景微亮 | - | - |

关键交互细节：

- 合盖开关首次开启 → 弹出确认 sheet（风险说明 + 管理员授权），取消则回弹到关。
- 时长选择非"一直"时，StatusFooter 显示倒计时；到时自动归位并刷新图标。
- 关闭"保持唤醒"主开关时，屏幕策略与时长子项随之禁用置灰。
- 减弱透明度开启：`glassEffect` 区域回退为 `.ultraThinMaterial`/不透明卡片，布局与可读性不变。

## 7. 动效

- 开关切换：滑块 spring 动画（轻量），玻璃高光随状态过渡。
- 面板出现：跟随 MenuBarExtra 默认弹出，不额外加重动画。
- 不使用浮夸过场；动效服务于状态反馈。

## 7b. v2 视觉精修（preview 返工，2026-05-31）

首版（原生 .switch / 分段 Picker / .buttonStyle(.glass)）走查后判定"像通用深色设置面板，不够精致、不够液态"。精修方向：

- **强制深色**面板（`environment(\.colorScheme, .dark)`），由 MenuBarExtra(.window) 自带玻璃做底，内容层不再叠玻璃；自定义控件做"悬浮感"。
- **自定义纯 SwiftUI 控件**取代 AppKit 原生控件（既更精致可控，又能离屏快照验证）：
  - `LiquidToggleStyle`：胶囊轨道(46x28) + 白色圆钮 + spring 动画；关=白 16% 轨道，开=accent 轨道。
  - `SegmentedSelector`：胶囊容器内两段，选中段填 accent、文字反白。
  - `DurationPill`：胶囊按钮，选中=accent 实心反白，未选=白 8% 底。
  - `IconBadge`：30x30 圆角方块承载 SF Symbol；未激活=白 10% 底 + accent 符号，激活=accent 底 + 白符号。
  - `Card`：白 6% 填充 + 白 10% 1px 描边，圆角 16，制造轻微层级而非玻璃叠玻璃。
- **头部重构**：IconBadge + 粗体标题"StayAwake" + 副行状态文案 + 右侧状态圆点（accent 着色）。
- **行布局**：徽标(leading) + 标题/副标题(center) + 自定义开关(trailing, 垂直居中)。
- **配色**：唤醒绿 `rgb(0.30,0.80,0.42)`、合盖橙 `rgb(1.0,0.62,0.20)`；激活态卡片的徽标/开关点亮 accent，强化"开启"反馈。
- **间距**：卡片内边距 14、行间距 10-12、控件圆角胶囊化，整体更紧凑有节奏。
- **基线可用**：纯控件在"减弱透明度"下天然可用；真机再由系统玻璃叠加液态质感（属增强，非依赖）。

## 7c. v3 去 AI 感：回归原生 macOS 设置风格（2026-05-31）

v2 的自定义控件（彩色圆角徽标、饱和绿填充、液态胶囊开关）被判定"AI 味过重"。v3 改为完全贴合苹果系统设置：

- **原生控件**取代所有自定义控件：
  - `Toggle().toggleStyle(.switch)` 系统开关（用系统强调色，不再强行染绿）。
  - `Picker().pickerStyle(.menu)` 下拉选择（屏幕策略、时长）——比分段+胶囊更"设置感"。
  - `GroupBox` 原生分组卡片承载每个区块。
  - 原生 `Button`（退出）。
- **去掉**彩色 IconBadge / 饱和填充 / 自定义胶囊；颜色回归中性，强调色交给系统。
- **克制配色**：文本 `.primary`/`.secondary`；开关用系统强调色；仅合盖风险用小号橙色符号点缀。
- 跟随系统外观（浅/深），语义色自适应。
- **快照工具升级**：改用 `NSHostingView` + `cacheDisplay(in:to:)` 离屏渲染真实 AppKit 控件（`ImageRenderer` 无法渲染原生控件），浅/深双外观核对，无需屏幕录制权限。
- 布局：标题行（小号 + 状态符号）→ 保持唤醒 GroupBox（开关 + 屏幕/时长下拉）→ 合盖 GroupBox（开关 + 风险脚注）→ 状态 GroupBox（倒计时 + 开机自启）→ 退出按钮。

## 8. 可访问性

- 所有图标 `accessibilityHidden(true)`，控件提供文字 label（如"保持唤醒开关，当前开启"）。
- 颜色不作为唯一状态线索（同时有图标 + 文案）。
- 满足 WCAG AA 对比度；尊重"减弱透明度"与"增强对比度"。
