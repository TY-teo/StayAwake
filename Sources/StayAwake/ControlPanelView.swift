import SwiftUI
import StayAwakeKit

/// 菜单栏弹出面板。完全采用原生 macOS 控件（系统开关 / 下拉 / GroupBox），贴合系统设置风格。
struct ControlPanelView: View {
    @EnvironmentObject private var state: AppState
    // 内联确认，避免 confirmationDialog 这种模态导致菜单栏弹层失焦关闭。
    @State private var lidPendingConfirm: Bool

    init(previewPendingLidConfirm: Bool = false) {
        _lidPendingConfirm = State(initialValue: previewPendingLidConfirm)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleBar
            keepAwakeGroup
            lidCloseGroup
            statusGroup
            quitButton
        }
        .toggleStyle(.switch)
        .padding(14)
        .frame(width: Tokens.panelWidth)
    }

    // MARK: - 标题

    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: state.icon.symbolName)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("StayAwake")
                .font(.headline)
            Spacer()
            Text(state.statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - 保持唤醒

    private var keepAwakeGroup: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(
                    get: { state.keepAwake },
                    set: { state.setKeepAwake($0) }
                )) {
                    rowLabel("保持唤醒", "系统空闲时不休眠，无论是否插电")
                }

                if state.keepAwake {
                    Divider()
                    Picker("屏幕策略", selection: Binding(
                        get: { state.displayPolicy },
                        set: { state.setDisplayPolicy($0) }
                    )) {
                        ForEach(DisplayPolicy.allCases, id: \.self) { policy in
                            Text(policy.title).tag(policy)
                        }
                    }
                    Picker("保持时长", selection: Binding(
                        get: { state.duration },
                        set: { state.setDuration($0) }
                    )) {
                        ForEach(KeepAwakeDuration.presets, id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 合盖继续运行

    private var lidCloseGroup: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { state.lidClose || lidPendingConfirm },
                    set: { newValue in
                        if newValue {
                            if !state.lidClose { lidPendingConfirm = true }
                        } else {
                            lidPendingConfirm = false
                            if state.lidClose { state.requestLidClose(false) }
                        }
                    }
                )) {
                    rowLabel("合盖继续运行", "合上盖子也不休眠，任务持续运行")
                }
                .disabled(state.lidCloseBusy)
                .onChange(of: state.lidClose) { _, isOn in
                    if isOn { lidPendingConfirm = false }
                }
                .onChange(of: state.lidCloseBusy) { _, busy in
                    if !busy && !state.lidClose { lidPendingConfirm = false }
                }

                if state.lidCloseBusy {
                    Label("正在请求管理员授权…", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if lidPendingConfirm && !state.lidClose {
                    inlineLidConfirm
                } else {
                    Label("散热 / 电量风险，建议插电使用", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.monochrome)
                }

                Divider()

                Toggle(isOn: Binding(
                    get: { state.passwordlessEnabled },
                    set: { state.setPasswordless($0) }
                )) {
                    rowLabel(
                        "切换时免输密码",
                        state.passwordlessEnabled
                            ? "已一次性授权，切换合盖无需输密码"
                            : "一次性授权后，切换合盖无需每次输密码"
                    )
                }
                .disabled(state.passwordlessBusy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 内联的合盖开启确认（取代模态弹窗，避免菜单栏弹层被关闭）。
    private var inlineLidConfirm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("合盖后系统将不休眠，任务继续运行。机内散热受限，建议插电使用；关闭开关或退出会自动恢复。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Spacer()
                Button("取消") { lidPendingConfirm = false }
                    .controlSize(.small)
                Button("开启") { state.requestLidClose(true) }
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - 状态与设置

    private var statusGroup: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if let remaining = state.remaining {
                    LabeledContent("剩余时间") {
                        Text(formatCountdown(remaining))
                            .font(.body.monospacedDigit())
                    }
                }
                if let error = state.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("开机自启", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var quitButton: some View {
        Button {
            state.quit()
        } label: {
            Text("退出 StayAwake")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .accessibilityLabel("退出 StayAwake")
    }

    private func rowLabel(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
