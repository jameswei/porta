import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings: PortSettings
    @EnvironmentObject var lm: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var launchAtLoginEnabled = false
    @State private var launchAtLoginError: String?
    @State private var isUpdatingLaunchAtLogin = false

    @State private var newEntryInput = ""
    @State private var newEntryError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: L("settings_title"))
                .font(.headline)

            Text(verbatim: L("settings_presets"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(PortPresetGroup.all, id: \.key) { preset in
                    Toggle(isOn: binding(for: preset.key)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.label)
                            Text(preset.portsLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Divider()

            Text(verbatim: L("settings_custom_ports"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !settings.customPortEntries.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(settings.customPortEntries.enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 6) {
                            Text(entry)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                settings.removeCustomEntry(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(L("settings_port_placeholder"), text: $newEntryInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { tryAddEntry() }
                    .onChange(of: newEntryInput) { _ in newEntryError = nil }
                Button(L("btn_add")) { tryAddEntry() }
                    .disabled(newEntryInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let error = newEntryError {
                Text(verbatim: error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Text(verbatim: L("settings_refresh"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("", selection: $settings.refreshIntervalSeconds) {
                ForEach(PortSettings.allowedRefreshIntervals, id: \.self) { seconds in
                    Text("\(seconds)s").tag(seconds)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Divider()

            Text(verbatim: L("settings_startup"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Toggle(L("toggle_open_at_login"), isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { applyLaunchAtLoginChange(enabled: $0) }
            ))
            .disabled(isUpdatingLaunchAtLogin)

            if let message = launchAtLoginError {
                Text(verbatim: message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "checkmark.circle")
                        .imageScale(.large)
                }
                .help(L("tooltip_done"))
                Spacer()
                Text(verbatim: appVersionString)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear {
            refreshLaunchAtLoginState()
        }
    }

    private func tryAddEntry() {
        let trimmed = newEntryInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if settings.isValidEntry(trimmed) {
            settings.addCustomEntry(trimmed)
            newEntryInput = ""
            newEntryError = nil
        } else {
            newEntryError = Lf("error_invalid_port_fmt", trimmed)
        }
    }

    private func binding(for presetKey: String) -> Binding<Bool> {
        Binding(
            get: { settings.enabledPresetKeys.contains(presetKey) },
            set: { isEnabled in
                var updated = settings.enabledPresetKeys
                if isEnabled {
                    updated.insert(presetKey)
                } else {
                    updated.remove(presetKey)
                }
                settings.enabledPresetKeys = updated
            }
        )
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Porta v\(version) (\(build))"
    }

    private func refreshLaunchAtLoginState(clearError: Bool = true) {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        if clearError { launchAtLoginError = nil }
    }

    private func applyLaunchAtLoginChange(enabled: Bool) {
        launchAtLoginEnabled = enabled
        launchAtLoginError = nil
        isUpdatingLaunchAtLogin = true

        Task {
            var updateError: String?
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try await SMAppService.mainApp.unregister()
                }
            } catch {
                updateError = Lf("error_launch_at_login_fmt", error.localizedDescription)
            }

            await MainActor.run {
                refreshLaunchAtLoginState(clearError: updateError == nil)
                launchAtLoginError = updateError
                isUpdatingLaunchAtLogin = false
            }
        }
    }
}

#if DEBUG
#Preview {
    SettingsView(settings: .shared)
        .environmentObject(LanguageManager.shared)
}
#endif
