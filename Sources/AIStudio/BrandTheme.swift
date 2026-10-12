import SwiftUI

enum BrandTheme {
    static let background = Color(red: 5.0 / 255.0, green: 5 / 255, blue: 7.0 / 255.0)
    static let panel = Color(red: 13 / 255, green: 13 / 255, blue: 17 / 255)
    static let panelRaised = Color(red: 20 / 255, green: 20 / 255, blue: 25 / 255)
    static let border = Color.white.opacity(0.085)
    static let orange = Color(red: 1.0, green: 0.27, blue: 0.10)
    static let hotOrange = Color(red: 1.0, green: 0.31, blue: 0.13)
    static let deepRed = Color(red: 0.86, green: 0.08, blue: 0.12)
    static let muted = Color(red: 0.62, green: 0.62, blue: 0.66)

    static let appBuilderGradient = LinearGradient(
        colors: [
            Color(red: 0.12, green: 0.12, blue: 0.13),
            Color(red: 1.0, green: 0.30, blue: 0.13),
            Color(red: 0.88, green: 0.10, blue: 0.14)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
