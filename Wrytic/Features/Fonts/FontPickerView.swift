import SwiftUI

struct FontPickerView: View {
    @Binding var style: TextStyle
    private let availabilityService: FontAvailabilityService = SystemFontAvailabilityService()

    var body: some View {
        Form {
            Section("Font") {
                Picker("Font", selection: $style.font) {
                    ForEach(AppFont.allCases) { font in
                        Text(font.displayName).tag(font)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: style.font) { adjustWeightIfUnavailable() }
            }

            Section("Weight") {
                Picker("Weight", selection: $style.weight) {
                    ForEach(availableWeights) { weight in
                        Text(weight.displayName).tag(weight)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Size") {
                Slider(value: $style.size, in: 12...48, step: 1)
                Text("\(Int(style.size)) pt")
                    .foregroundStyle(.secondary)
            }

            Section("Color") {
                HStack(spacing: 12) {
                    ForEach(Array(TextColor.presets.enumerated()), id: \.offset) { _, color in
                        Button {
                            style.color = color
                        } label: {
                            Circle()
                                .fill(color.swiftUIColor)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(.primary, lineWidth: style.color == color ? 2 : 0)
                                        .padding(-3)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    ColorPicker(
                        "Custom",
                        selection: Binding(
                            get: { style.color.swiftUIColor },
                            set: { style.color = TextColor(color: $0) }
                        )
                    )
                    .labelsHidden()
                }
            }

            Section("Preview") {
                Text("The quick brown fox")
                    .font(availabilityService.resolvedFont(for: style.font, weight: style.weight, size: style.size))
                    .foregroundStyle(style.color.swiftUIColor)
            }
        }
        .navigationTitle("Font")
    }

    private var availableWeights: [FontWeight] {
        FontWeight.allCases.filter { availabilityService.isAvailable(style.font, weight: $0) }
    }

    private func adjustWeightIfUnavailable() {
        guard !availabilityService.isAvailable(style.font, weight: style.weight) else { return }
        style.weight = availableWeights.first ?? .regular
    }
}

#Preview {
    NavigationStack {
        FontPickerView(style: .constant(.default))
    }
}
