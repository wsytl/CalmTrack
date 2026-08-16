//
//  Date+CalendarDay.swift
//  CalmTrack
//

import Foundation

extension Date {

    /// 当前日历下的「当天 0:00」，用于打卡 / 状态按自然日存库与查询。
    var calendarDayStart: Date {
        Calendar.current.startOfDay(for: self)
    }
}
