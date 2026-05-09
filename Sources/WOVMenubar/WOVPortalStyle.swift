import SwiftUI

enum WOVPortalStyle {
    static let background = Color(red: 0.982, green: 0.972, blue: 0.953)
    static let surface = Color.white
    static let inputBackground = Color(red: 0.998, green: 0.994, blue: 0.986)
    static let secondary = Color(red: 0.965, green: 0.949, blue: 0.929)
    static let accent = Color(red: 0.941, green: 0.914, blue: 0.886)
    static let border = Color(red: 0.888, green: 0.858, blue: 0.821)
    static let borderStrong = Color(red: 0.786, green: 0.731, blue: 0.674)
    static let foreground = Color(red: 0.114, green: 0.096, blue: 0.082)
    static let muted = Color(red: 0.478, green: 0.416, blue: 0.365)
    static let sidebar = Color(red: 0.105, green: 0.086, blue: 0.074)
    static let sidebarAccent = Color(red: 0.184, green: 0.145, blue: 0.119)
    static let primary = Color(red: 0.742, green: 0.385, blue: 0.105)
    static let primaryHover = Color(red: 0.645, green: 0.305, blue: 0.075)
    static let primarySoft = Color(red: 0.982, green: 0.914, blue: 0.858)
    static let success = Color(red: 0.145, green: 0.529, blue: 0.321)
    static let radius: CGFloat = 8
}

struct PortalPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .frame(minHeight: 34)
            .background(
                configuration.isPressed ? WOVPortalStyle.primaryHover : WOVPortalStyle.primary,
                in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
    }
}

struct PortalSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(WOVPortalStyle.foreground)
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background(
                configuration.isPressed ? WOVPortalStyle.accent : WOVPortalStyle.surface,
                in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
                    .stroke(WOVPortalStyle.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
    }
}

struct PortalIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(WOVPortalStyle.muted)
            .frame(width: 30, height: 30)
            .background(
                configuration.isPressed ? WOVPortalStyle.accent : Color.clear,
                in: RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: WOVPortalStyle.radius, style: .continuous))
    }
}
