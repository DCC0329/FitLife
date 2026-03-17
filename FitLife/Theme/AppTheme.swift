import SwiftUI

struct AppTheme {
    // MARK: - Primary Colors
    static let primaryGreen = Color(hex: "4ECB71")
    static let lightGreen = Color(hex: "E8F8EE")
    static let darkGreen = Color(hex: "2DA85A")

    // MARK: - Accent Colors
    static let lavender = Color(hex: "A89FEC")
    static let coral = Color(hex: "F5A3B5")
    static let softBlue = Color(hex: "6CB4EE")
    static let warmYellow = Color(hex: "F5C842")
    static let softIndigo = Color(hex: "7B6CF6")

    // MARK: - Background Colors
    static let background = Color(hex: "F2F3F7")
    static let cardBackground = Color(hex: "F7F8FA")
    static let surfaceColor = Color.white

    // MARK: - Text Colors
    static let primaryText = Color(hex: "1A1D26")
    static let secondaryText = Color(hex: "8E8E93")

    // MARK: - Gradient
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primaryGreen, Color(hex: "8BE4A8")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Card Style
    static func cardStyle() -> some ViewModifier {
        CardModifier()
    }

    // MARK: - Corner Radius
    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 10

    // MARK: - Padding
    static let padding: CGFloat = 16
    static let smallPadding: CGFloat = 8
    static let largePadding: CGFloat = 24

    // MARK: - Shadow
    static let shadowColor = Color.black.opacity(0.06)
    static let shadowRadius: CGFloat = 8
    static let shadowY: CGFloat = 4
}

// MARK: - Card Modifier
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.padding)
            .background(AppTheme.surfaceColor)
            .cornerRadius(AppTheme.cornerRadius)
            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, x: 0, y: AppTheme.shadowY)
    }
}

// MARK: - View Extension
extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
