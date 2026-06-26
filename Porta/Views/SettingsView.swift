import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: PortSettings
    @Environment(\.dismiss) private var dismiss

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
}

#if DEBUG
#Preview {
    SettingsView(settings: .shared)
}
#endif
