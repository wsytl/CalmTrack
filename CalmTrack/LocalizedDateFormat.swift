//
//  LocalizedDateFormat.swift
//  CalmTrack
//

import Foundation

enum LocalizedDateFormat {

    /// 顶部 / 日历条：年月（随系统区域，如「2026年5月」或「May 2026」）。
    static func monthYear(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("yMMMM")
        return f.string(from: date)
    }

    /// 历史状态月份 Section 标题。
    static func monthSection(_ monthStart: Date) -> String {
        monthYear(monthStart)
    }

    /// 历史状态某日内标题（月日 + 星期）。
    static func dayInMonthWithWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("MMMdEEEE")
        return f.string(from: date)
    }

    /// 日历年月选择器中的月份名称。
    static func standaloneMonth(_ month1To12: Int) -> String {
        var c = DateComponents()
        c.year = 2000
        c.month = month1To12
        c.day = 1
        guard let d = Calendar.current.date(from: c) else { return "\(month1To12)" }
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("MMMM")
        return f.string(from: d)
    }
}
