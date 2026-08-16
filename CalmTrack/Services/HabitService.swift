//
//  HabitService.swift
//  CalmTrack
//
//  C3/C4/C5/C6 优化：
//  - 类型化的 HabitDayState 暴露给视图，NSArray/NSDictionary 的 Transformable
//    编解码全部收进私有实现（视图不再触碰 blob 格式）。
//  - ObservableObject + changeToken：打卡写入后自动通知摘要/日历重算，
//    取代视图手动 +1 的 refreshToken。
//  - 写入路径经 DayRecordStore 统一 fetch-or-create 并去重，读路径只读不建。
//  - completionRatio 收敛完成率语义（原来在 3 个视图里各写一遍）。
//

import Foundation
import Combine
import CoreData

/// 某一天的习惯打卡状态（已完成的习惯 ID + 各习惯的计数/评分进度）。
struct HabitDayState {
    var completedIDs: Set<UUID> = []
    var progress: [UUID: Double] = [:]
}

final class HabitService: ObservableObject {

    static let shared = HabitService()

    /// 任何打卡写入都会递增；观察它的视图据此重算摘要/日历色块。
    @Published private(set) var changeToken = 0

    // MARK: - 读取（只读，不创建记录）

    /// 读取某一天的打卡状态（当日无记录返回空状态，不会创建空记录）。
    func dayState(for date: Date, in context: NSManagedObjectContext) -> HabitDayState {
        dayState(from: DayRecordStore.records(HabitRecord.self, for: date, in: context))
    }

    /// 由已取回的记录解码合并出打卡状态（重复记录按顺序合并）。
    func dayState(from records: [HabitRecord]) -> HabitDayState {
        var state = HabitDayState()
        for record in records {
            state.completedIDs.formUnion(decodeCompletedIDs(record.completedIDs))
            for (id, value) in decodeProgress(record.progressValues) {
                state.progress[id] = value
            }
        }
        return state
    }

    /// 将多条 HabitRecord 按自然日合并为「当日已完成 ID 集合」。
    func completedIDsByDay(from records: [HabitRecord]) -> [Date: Set<UUID>] {
        var dict: [Date: Set<UUID>] = [:]
        for record in records {
            guard let raw = record.date else { continue }
            let day = raw.calendarDayStart
            dict[day, default: []].formUnion(decodeCompletedIDs(record.completedIDs))
        }
        return dict
    }

    /// 窗口纯函数（方案 D）：只合并「month 所在月份」内的记录，其余照 completedIDsByDay(from:)。
    /// 窗口过滤是 in-process 纯计算——日历切换月份时由视图传入新的 month，无需重建 fetch。
    func completedIDsByDay(from records: [HabitRecord], inMonthOf month: Date) -> [Date: Set<UUID>] {
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month.calendarDayStart
        guard let nextMonth = cal.date(byAdding: .month, value: 1, to: monthStart) else { return [:] }
        var dict: [Date: Set<UUID>] = [:]
        for record in records {
            guard let raw = record.date else { continue }
            let day = raw.calendarDayStart
            guard day >= monthStart, day < nextMonth else { continue }
            dict[day, default: []].formUnion(decodeCompletedIDs(record.completedIDs))
        }
        return dict
    }

    /// 窗口纯函数（MetricHistoryView 的 7 天趋势条同构方案）：只合并 endingOn 往前 lastNDays 天（含当天）内的记录。
    func completedIDsByDay(from records: [HabitRecord], lastNDays: Int, endingOn end: Date) -> [Date: Set<UUID>] {
        let cal = Calendar.current
        let endDay = end.calendarDayStart
        guard let startDay = cal.date(byAdding: .day, value: -(lastNDays - 1), to: endDay) else { return [:] }
        var dict: [Date: Set<UUID>] = [:]
        for record in records {
            guard let raw = record.date else { continue }
            let day = raw.calendarDayStart
            guard day >= startDay, day <= endDay else { continue }
            dict[day, default: []].formUnion(decodeCompletedIDs(record.completedIDs))
        }
        return dict
    }

    /// 连续「当日全部打卡项都完成」的天数：今日未满则从昨日起算；按当前项目集回看历史。
    func fullCompletionStreak(
        habitIDs: Set<UUID>,
        completedByDay: [Date: Set<UUID>],
        calendar: Calendar = .current,
        today: Date = Date()
    ) -> Int {
        guard !habitIDs.isEmpty else { return 0 }
        let todayStart = today.calendarDayStart

        func isFullDay(_ day: Date) -> Bool {
            let done = completedByDay[day, default: []].intersection(habitIDs)
            return done.count == habitIDs.count
        }

        var streak = 0
        let startCursor: Date
        if isFullDay(todayStart) {
            startCursor = todayStart
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return 0 }
            startCursor = yesterday
        }

        var cursor = startCursor
        while isFullDay(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// 某一天（相对当前习惯集）的完成率；未来日期返回 0。
    func completionRatio(
        habitIDs: Set<UUID>,
        completedByDay: [Date: Set<UUID>],
        day: Date,
        isFuture: Bool = false
    ) -> Double {
        guard !habitIDs.isEmpty, !isFuture else { return 0 }
        let dayStart = day.calendarDayStart
        let done = completedByDay[dayStart, default: []].intersection(habitIDs).count
        return Double(done) / Double(habitIDs.count)
    }

    // MARK: - 写入（只对「今天」生效）

    func toggle(itemID: UUID, date: Date, in context: NSManagedObjectContext) {
        guard Calendar.current.isDateInToday(date) else { return }
        guard let record = record(for: date, in: context) else { return }

        var ids = decodeCompletedIDs(record.completedIDs)
        if let index = ids.firstIndex(of: itemID) {
            ids.remove(at: index)
        } else {
            ids.append(itemID)
        }
        record.completedIDs = encodeCompletedIDs(ids)
        DayRecordStore.save(context)
        bump()
    }

    func adjustProgress(
        item: HabitItem,
        delta: Double,
        date: Date,
        in context: NSManagedObjectContext
    ) {
        guard Calendar.current.isDateInToday(date), let itemID = item.id else { return }
        guard let record = record(for: date, in: context) else { return }

        var values = decodeProgress(record.progressValues)
        let target = targetValue(for: item)
        let current = values[itemID] ?? 0
        values[itemID] = min(target, max(0, current + delta))
        record.progressValues = encodeProgress(values)
        syncCompletion(item: item, record: record)
        DayRecordStore.save(context)
        bump()
    }

    func setRating(
        item: HabitItem,
        value: Double,
        date: Date,
        in context: NSManagedObjectContext
    ) {
        guard Calendar.current.isDateInToday(date), let itemID = item.id else { return }
        guard let record = record(for: date, in: context) else { return }

        var values = decodeProgress(record.progressValues)
        values[itemID] = min(targetValue(for: item), max(0, value))
        record.progressValues = encodeProgress(values)
        syncCompletion(item: item, record: record)
        DayRecordStore.save(context)
        bump()
    }

    // MARK: - 私有

    /// 写入路径的 fetch-or-create；同时把同一天的历史重复记录合并进第一条并删除，
    /// 保证「一日一记录」的不变量（模型层没有唯一性约束，故在此强制）。
    private func record(for date: Date, in context: NSManagedObjectContext) -> HabitRecord? {
        let records = DayRecordStore.records(HabitRecord.self, for: date, in: context)
        if let first = records.first {
            var ids = decodeCompletedIDs(first.completedIDs)
            var progress = decodeProgress(first.progressValues)
            let extras = records.dropFirst().sorted { DayRecordStore.stableKey($0) < DayRecordStore.stableKey($1) }
            if !extras.isEmpty {
                for extra in extras {
                    for id in decodeCompletedIDs(extra.completedIDs) where !ids.contains(id) {
                        ids.append(id)
                    }
                    for (id, value) in decodeProgress(extra.progressValues) {
                        progress[id] = value
                    }
                    context.delete(extra)
                }
                first.completedIDs = encodeCompletedIDs(ids)
                first.progressValues = encodeProgress(progress)
            }
            return first
        }
        return DayRecordStore.fetchOrCreate(HabitRecord.self, for: date, in: context) { record in
            record.completedIDs = NSArray()
            record.progressValues = NSDictionary()
        }
    }

    private func decodeCompletedIDs(_ value: NSObject?) -> [UUID] {
        guard let arr = value as? NSArray else { return [] }
        var out: [UUID] = []
        for element in arr {
            if let u = element as? UUID {
                out.append(u)
            } else if let nu = element as? NSUUID {
                out.append(nu as UUID)
            }
        }
        return out
    }

    private func encodeCompletedIDs(_ ids: [UUID]) -> NSArray {
        ids.map { NSUUID(uuidString: $0.uuidString)! } as NSArray
    }

    private func decodeProgress(_ value: NSObject?) -> [UUID: Double] {
        guard let dict = value as? NSDictionary else { return [:] }
        var result: [UUID: Double] = [:]
        dict.enumerateKeysAndObjects { key, value, _ in
            guard let key = key as? String,
                  let id = UUID(uuidString: key),
                  let number = value as? NSNumber else { return }
            result[id] = number.doubleValue
        }
        return result
    }

    private func encodeProgress(_ values: [UUID: Double]) -> NSDictionary {
        let dict = NSMutableDictionary()
        for (id, value) in values {
            dict[id.uuidString] = NSNumber(value: value)
        }
        return dict
    }

    private func syncCompletion(item: HabitItem, record: HabitRecord) {
        guard let itemID = item.id else { return }
        let values = decodeProgress(record.progressValues)
        let progress = values[itemID] ?? 0
        let isComplete: Bool
        if item.kind == "rating" {
            isComplete = progress > 0
        } else {
            isComplete = progress >= targetValue(for: item)
        }

        var ids = decodeCompletedIDs(record.completedIDs)
        if isComplete, !ids.contains(itemID) {
            ids.append(itemID)
        }
        if !isComplete, let index = ids.firstIndex(of: itemID) {
            ids.remove(at: index)
        }
        record.completedIDs = encodeCompletedIDs(ids)
    }

    private func targetValue(for item: HabitItem) -> Double {
        let value = Double(item.targetValue)
        return value > 0 ? value : 1
    }

    private func bump() {
        changeToken += 1
    }
}
