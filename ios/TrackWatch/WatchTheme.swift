import SwiftUI

/// Lume design tokens (dark palette) — mirrors `lib/theme.dart` on the
/// Flutter side so phone and watch feel like one app. Watch is dark-only.
enum WatchTheme {
    static let bg = Color(hex: 0x0A0C0D)
    static let s1 = Color(hex: 0x10161A)
    static let s2 = Color(hex: 0x182228)
    static let line = Color(hex: 0x2A3A44)
    static let txt = Color(hex: 0xEAF2F5)
    static let txt2 = Color(hex: 0x9FB2BC)
    static let txt3 = Color(hex: 0x5F727C)
    static let accent = Color(hex: 0x22D3EE)
    static let pause = Color(hex: 0xF5B833)
    static let stop = Color(hex: 0xFF5A52)

    static func typeTint(_ activityType: String) -> Color {
        switch activityType {
        case "Ride": return Color(hex: 0x38BDF8)
        case "Walk": return Color(hex: 0x34D399)
        case "Run": return Color(hex: 0xFBBF6B)
        case "Football": return Color(hex: 0xC084FC)
        case "Swim": return Color(hex: 0x22D3EE)
        default: return accent
        }
    }

    static func typeSymbol(_ activityType: String) -> String {
        switch activityType {
        case "Ride": return "bicycle"
        case "Walk": return "figure.walk"
        case "Run": return "figure.run"
        case "Football": return "soccerball"
        case "Swim": return "figure.pool.swim"
        default: return "record.circle"
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
