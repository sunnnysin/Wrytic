import SwiftUI

struct TextObjectToolbar: View {
    @Binding var style: TextStyle
    var onDelete: () -> Void

    private static let sizeRange: ClosedRange<CGFloat> = 12...48
    private static let tapTargetSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(AppFont.allCases) { font in
                    Button(font.displayName) { style.font = font }
                }
            } label: {
                Text("Aa")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: Self.tapTargetSize, height: Self.tapTargetSize)
                    .contentShape(Rectangle())
            }

            Picker("Weight", selection: $style.weight) {
                ForEach(FontWeight.allCases) { weight in
                    Text(weight.displayName.prefix(1)).tag(weight)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 84)

            HStack(spacing: 0) {
                Button {
                    style.size = max(Self.sizeRange.lowerBound, style.size - 2)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: Self.tapTargetSize, height: Self.tapTargetSize)
                        .contentShape(Rectangle())
                }
                Text("\(Int(style.size))")
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 20)
                Button {
                    style.size = min(Self.sizeRange.upperBound, style.size + 2)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: Self.tapTargetSize, height: Self.tapTargetSize)
                        .contentShape(Rectangle())
                }
            }

            Divider().frame(height: 20)

            HStack(spacing: 4) {
                ForEach(Array(TextColor.presets.enumerated()), id: \.offset) { _, color in
                    Button {
                        style.color = color
                    } label: {
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(.primary, lineWidth: style.color == color ? 2 : 0)
                                    .padding(-2)
                            )
                            .frame(width: Self.tapTargetSize, height: Self.tapTargetSize)
                            .contentShape(Rectangle())
                    }
                }

                ColorPicker(
                    "",
                    selection: Binding(
                        get: { style.color.swiftUIColor },
                        set: { style.color = TextColor(color: $0) }
                    )
                )
                .labelsHidden()
                .frame(width: Self.tapTargetSize, height: Self.tapTargetSize)
            }

            Divider().frame(height: 20)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .frame(width: Self.tapTargetSize, height: Self.tapTargetSize)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 14))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .fixedSize()
    }
}

#Preview {
    TextObjectToolbar(style: .constant(.default), onDelete: {})
        .padding()
}
