import SwiftUI

struct SettingsView: View {
    @Bindable var fontSettings: FontSettingsStore
    @Bindable var recognitionSettings: RecognitionSettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Writing") {
                    Toggle("Convert Handwriting to Text", isOn: $recognitionSettings.isAutoConvertEnabled)
                    NavigationLink {
                        FontPickerView(style: $fontSettings.defaultStyle)
                    } label: {
                        LabeledContent("Default Font", value: defaultFontSummary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var defaultFontSummary: String {
        let style = fontSettings.defaultStyle
        return "\(style.font.displayName) (\(style.weight.displayName))"
    }
}

#Preview {
    SettingsView(fontSettings: FontSettingsStore(), recognitionSettings: RecognitionSettingsStore())
}
