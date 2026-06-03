import SwiftUI

enum AppDesign {
    static let background = Color(red: 0.04, green: 0.07, blue: 0.12)
    static let card = Color(red: 0.10, green: 0.14, blue: 0.20)
    static let cardSecondary = Color(red: 0.13, green: 0.18, blue: 0.26)
    static let accent = Color(red: 0.14, green: 0.87, blue: 0.76)
    static let accent2 = Color(red: 0.24, green: 0.55, blue: 0.98)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppDesign.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardModifier())
    }
}
