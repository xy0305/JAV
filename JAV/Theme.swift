import SwiftUI

enum Theme {
    static let accent = Color(red: 0.96, green: 0.42, blue: 0.26)      // warm orange
    static let bg = Color(red: 0.045, green: 0.055, blue: 0.09)        // near-black
    static let card = Color(red: 0.09, green: 0.105, blue: 0.15)
    static let cardHighlight = Color(red: 0.13, green: 0.15, blue: 0.21)
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.55)

    static func scoreColor(_ s: Double) -> Color {
        if s >= 4.5 { return Color(red: 0.99, green: 0.55, blue: 0.25) }
        if s >= 4.0 { return Color(red: 0.99, green: 0.72, blue: 0.28) }
        if s >= 3.0 { return Color(red: 0.55, green: 0.78, blue: 0.35) }
        return Color.white.opacity(0.45)
    }
}

extension View {
    func cardStyle() -> some View {
        self.background(Theme.card)
            .cornerRadius(14)
    }
}
