import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings: PortSettings
    @Environment(\.dismiss) private var dismiss

    @State private var launchAtLoginEnabled = false
    @State private var launchAtLoginStatus = "Disabled"
    @State private var launchAtLoginError: String?
    @State private var isUpdatingLaunchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

            Text("Port presets")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(PortPresetGroup.all, id: \.key) { preset in
                    Toggle(preset.label, isOn: binding(for: preset.key))
                }
            }

            Divider()

            Text("Custom ports")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("e.g. 4200, 9000-9010", text: $settings.customPortsInput)
                .textFieldStyle(.roundedBorder)

            if let message = settings.customPortsValidationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Add comma-separated values or ranges (1-65535). Ranges longer than 1000 ports are ignored.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Text("Refresh interval")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Stepper(value: $settings.refreshIntervalSeconds, in: 1...60) {
                Text("Refresh every \(settings.refreshIntervalSeconds) second\(settings.refreshIntervalSeconds == 1 ? "" : "s")")
            }
            Text("1-60 seconds.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text("Launch at login")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Toggle("Launch Porta at login", isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { isEnabled in
                    applyLaunchAtLoginChange(enabled: isEnabled)
                }
            ))
            .disabled(isUpdatingLaunchAtLogin)

            Text("Status: \(launchAtLoginStatus)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let message = launchAtLoginError {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear {
            refreshLaunchAtLoginState()
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

    private func refreshLaunchAtLoginState(clearError: Bool = true) {
        let status = SMAppService.mainApp.status
        launchAtLoginStatus = launchAtLoginStatusLabel(for: status)
        launchAtLoginEnabled = status == .enabled
        if clearError {
            launchAtLoginError = nil
        }
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
                updateError = "Could not update launch-at-login setting: \(error.localizedDescription)"
            }

            await MainActor.run {
                refreshLaunchAtLoginState(clearError: updateError == nil)
                launchAtLoginError = updateError
                isUpdatingLaunchAtLogin = false
            }
        }
    }

    private func launchAtLoginStatusLabel(for status: SMAppService.Status) -> String {
        switch status {
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Requires approval"
        case .notFound:
            return "Unavailable"
        case .notRegistered:
            return "Disabled"
        @unknown default:
            return "Unknown"
        }
    }
}

#if DEBUG
#Preview {
    SettingsView(settings: .shared)
}
#endif
