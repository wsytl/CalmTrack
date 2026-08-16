//
//  CalmStyle.swift
//  CalmTrack
//

import SwiftUI

/// 「慢养」界面用色与按钮反馈，供顶栏、底栏等共用。
enum CalmChrome {

    static func tabBarFill(_ scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.14, green: 0.17, blue: 0.16)
        default:
            return Color(red: 0.97, green: 0.99, blue: 0.98)
        }
    }

    static func tabBarStroke(_ scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color.white.opacity(0.10)
        default:
            return Color(red: 0.72, green: 0.84, blue: 0.78).opacity(0.55)
        }
    }

    static func tabBarShadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.45) : Color(red: 0.2, green: 0.35, blue: 0.3).opacity(0.12)
    }

    static func tabItemForeground(_ scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.78, green: 0.88, blue: 0.84)
        default:
            return Color(red: 0.32, green: 0.45, blue: 0.40)
        }
    }

    /// 进度条、环形进度、打卡「已完成」图标（统一主色，略深于标签字色以便辨认）。
    static func calmFill(_ scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.52, green: 0.80, blue: 0.69)
        default:
            return Color(red: 0.22, green: 0.46, blue: 0.38)
        }
    }

    /// 未完成轨迹、空选圈底（与 `calmFill` 同系、低对比）。
    static func calmTrack(_ scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color.white.opacity(0.14)
        default:
            return Color(red: 0.70, green: 0.82, blue: 0.76).opacity(0.55)
        }
    }

    /// 摘要卡背景（与完成色同系浅铺）。
    static func calmCardWash(_ scheme: ColorScheme) -> Color {
        calmFill(scheme).opacity(scheme == .dark ? 0.16 : 0.10)
    }

    /// 今日调养提示卡：略带米杏底色，和食疗语境更贴合。
    static func nourishmentCardFill(_ scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.20, green: 0.18, blue: 0.14)
        default:
            return Color(red: 0.99, green: 0.97, blue: 0.91)
        }
    }

    static func nourishmentCardStroke(_ scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.72, green: 0.64, blue: 0.46).opacity(0.18)
        default:
            return Color(red: 0.78, green: 0.68, blue: 0.46).opacity(0.28)
        }
    }

    /// 顶栏「日历」胶囊：收起时与底栏块面一致；展开时略强调。
    static func calendarPillFill(_ scheme: ColorScheme, isExpanded: Bool) -> Color {
        guard isExpanded else { return tabBarFill(scheme) }
        switch scheme {
        case .dark:
            return Color.accentColor.opacity(0.22)
        default:
            return Color.accentColor.opacity(0.13)
        }
    }

    static func calendarPillStroke(_ scheme: ColorScheme, isExpanded: Bool) -> Color {
        guard isExpanded else { return tabBarStroke(scheme) }
        return Color.accentColor.opacity(scheme == .dark ? 0.42 : 0.32)
    }
}

struct CalmBarButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}
