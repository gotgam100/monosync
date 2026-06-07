import SwiftUI

enum MonoTheme {
    static let ink = Color(light: 0xF2E7D1, dark: 0x111111)
    static let paper = Color(light: 0x171717, dark: 0xE7E7E7)
    static let mist = Color(light: 0x5D564B, dark: 0xB9B9B9)
    static let accent = Color(hex: 0xEC5C1D)
    static let live = Color(hex: 0x0A8A5A)
    static let panel = Color(light: 0xE8D9BE, dark: 0x181818)
    static let line = Color(light: 0xCDBFA6, dark: 0x303030)

    static let body = Font.custom("Paperlogy-4Regular", size: 16)
    static let bodyMedium = Font.custom("Paperlogy-5Medium", size: 16)
    static let small = Font.custom("Paperlogy-4Regular", size: 13)
    static let title = Font.custom("Paperlogy-7Bold", size: 26)
    static let compactTitle = Font.custom("Paperlogy-6SemiBold", size: 20)
    static let point = Font.custom("Cafe24PROSlimAir", size: 24)
    static let pointSmall = Font.custom("Cafe24PROSlimAir", size: 12)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xff) / 255
        let green = Double((hex >> 8) & 0xff) / 255
        let blue = Double(hex & 0xff) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traitCollection in
            UIColor(hex: traitCollection.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        let red = CGFloat((hex >> 16) & 0xff) / 255
        let green = CGFloat((hex >> 8) & 0xff) / 255
        let blue = CGFloat(hex & 0xff) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
