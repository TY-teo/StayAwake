# Super Dev Workflow - ScreenSleepControl

- CONTRACT: SUPER_DEV_FLOW_CONTRACT_V1
- MODE: standard (/super-dev)
- PHASE_CHAIN: research>docs>docs_confirm>spec>frontend>preview_confirm>backend>quality>delivery
- CURRENT_PHASE: docs_confirm (等待用户确认三份核心文档)
- DOC_CONFIRM_GATE: required (PENDING)
- PREVIEW_CONFIRM_GATE: required

## 项目
Mac 菜单栏工具：一键不休眠 + 合盖继续运行，macOS 26 Liquid Glass 风格。

## 已产出
- output/screen-sleep-control-research.md
- output/screen-sleep-control-prd.md
- output/screen-sleep-control-architecture.md
- output/screen-sleep-control-uiux.md

## 待确认决策（docs 确认门）
1. 合盖特权方案：A 管理员弹窗(推荐 v1) / B 特权守护进程
2. 屏幕策略默认值：默认"允许屏幕关闭"省电
3. 显示名 / 时长功能是否纳入 MVP

## 下一步（用户确认后）
spec -> 前端(SwiftUI 玻璃面板+菜单栏) 运行验证 -> 后端(IOPMAssertion + pmset 特权层) -> 测试/质量 -> 交付
