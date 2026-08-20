import SwiftUI

struct SettingsView: View {
    @Bindable var fontSettings: FontSettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Writing") {
                    NavigationLink {
                        FontPickerView(style: $fontSettings.defaultStyle)
                    } label: {
                        LabeledContent("Default Font", value: fontSettings.defaultStyle.font.displayName)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(fontSettings: FontSettingsStore())
}
