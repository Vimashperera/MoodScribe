import SwiftUI

struct MoodCardModifier: ViewModifier {
    var tint: Color = .accentColor

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(tint.opacity(0.14))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: tint.opacity(0.22), radius: 16, y: 8)
            }
    }
}

extension View {
    func moodCardStyle(tint: Color = .accentColor) -> some View {
        modifier(MoodCardModifier(tint: tint))
    }
}
