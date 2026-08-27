import SwiftUI

struct SelectionActionToolbar: View {
    var onDuplicate: () -> Void
    var onDelete: () -> Void

    private static let tapTargetSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onDuplicate) {
                Image(systemName: "plus.square.on.square")
                    .frame(width: Self.tapTargetSize, height: Self.tapTargetSize)
                    .contentShape(Rectangle())
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
        .font(.system(size: 15))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .fixedSize()
    }
}

#Preview {
    SelectionActionToolbar(onDuplicate: {}, onDelete: {})
        .padding()
}
