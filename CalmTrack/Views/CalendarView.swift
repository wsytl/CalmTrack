//
//  CalendarView.swift
//  CalmTrack
//
//  C3：移除 refreshToken，改用 HabitService.changeToken 自动刷新。
//  C5：完成率计算收敛到 HabitService.completionRatio。
//  D：全量拉取 HabitRecord，月份窗口由纯函数 completedIDsByDay(from:inMonthOf:) 过滤——
//     修复 C7「fetch 窗口冻结在 init」导致切换月份后完成色块过期的问题。
//  C8：generateDays / dayNumber 收敛为私有方法，不再污染全局命名空间。
//

import SwiftUI
import Foundation
import CoreData

struct CalendarView: View {

    @Binding var selectedDate: Date

    /// C6：可注入的服务（默认共享实例）。
    @ObservedObject var habitService: HabitService = .shared

    @State private var showYearMonthPicker = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "sortIndex", ascending: true)]
    ) private var allHabits: FetchedResults<HabitItem>

    /// 全量拉取记录（方案 D）；月份窗口由纯函数在 body 中过滤，@FetchRequest 自动跟随写入刷新。
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HabitRecord.date, ascending: true)]
    ) private var allRecords: FetchedResults<HabitRecord>

    init(selectedDate: Binding<Date>, habitService: HabitService = .shared) {
        self._selectedDate = selectedDate
        self._habitService = ObservedObject(wrappedValue: habitService)
    }

    var body: some View {
        let habitSet = Set(allHabits.compactMap(\.id))
        let byDay = habitService.completedIDsByDay(from: Array(allRecords), inMonthOf: selectedDate)
        let days = generateDays(for: selectedDate)
        let todayStart = Date().calendarDayStart

        VStack(spacing: 10) {
            monthNavigationBar

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {

                ForEach(days, id: \.self) { day in
                let dayStart = day.calendarDayStart
                let selected = isSelectedDay(day)
                let isFuture = dayStart > todayStart
                let ratio = habitService.completionRatio(
                    habitIDs: habitSet,
                    completedByDay: byDay,
                    day: dayStart,
                    isFuture: isFuture
                )

                Text("\(dayNumber(day))")
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .foregroundStyle(labelColor(isFuture: isFuture, ratio: ratio, selected: selected))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(cellFill(ratio: ratio, isFuture: isFuture, selected: selected))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDate = dayStart
                    }
                    .accessibilityLabel(accessibilityDayLabel(day: day, ratio: ratio, isFuture: isFuture, selected: selected))
                }
            }
        }
        .sheet(isPresented: $showYearMonthPicker) {
            YearMonthPickerSheet(selectedDate: $selectedDate, isPresented: $showYearMonthPicker)
        }
    }

    private var monthNavigationBar: some View {
        HStack(spacing: 12) {
            Button {
                shiftCalendarMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 36, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(L10n.tr("cal.prev_month_a11y"))

            Button {
                showYearMonthPicker = true
            } label: {
                Text(LocalizedDateFormat.monthYear(selectedDate))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("cal.pick_month_a11y"))

            Button {
                shiftCalendarMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 36, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(L10n.tr("cal.next_month_a11y"))
        }
        .foregroundStyle(.primary)
    }

    private func shiftCalendarMonth(by delta: Int) {
        let cal = Calendar.current
        guard let targetMonth = cal.date(byAdding: .month, value: delta, to: selectedDate) else { return }
        let day = cal.component(.day, from: selectedDate)
        guard let range = cal.range(of: .day, in: .month, for: targetMonth) else { return }
        let clampedDay = min(day, range.count)
        var comps = cal.dateComponents([.year, .month], from: targetMonth)
        comps.day = clampedDay
        guard let newDate = cal.date(from: comps) else { return }
        selectedDate = newDate.calendarDayStart
    }

    private func isSelectedDay(_ day: Date) -> Bool {
        Calendar.current.isDate(day, inSameDayAs: selectedDate)
    }

    private func cellFill(ratio: Double, isFuture: Bool, selected: Bool) -> Color {
        if isFuture {
            return Color.secondary.opacity(0.06)
        }
        if ratio < 0.001 {
            return Color.secondary.opacity(0.1)
        }
        if ratio < 1 {
            return Color.orange.opacity(0.18 + ratio * 0.32)
        }
        return Color.green.opacity(0.38)
    }

    private func labelColor(isFuture: Bool, ratio: Double, selected: Bool) -> Color {
        if isFuture {
            return Color.secondary
        }
        if ratio >= 0.99 {
            return Color.primary.opacity(0.92)
        }
        return Color.primary
    }

    private func accessibilityDayLabel(day: Date, ratio: Double, isFuture: Bool, selected: Bool) -> String {
        let d = dayNumber(day)
        if isFuture {
            return L10n.trf("cal.a11y.future_fmt", d)
        }
        let pct = Int((ratio * 100).rounded())
        let sel = selected ? L10n.tr("cal.a11y.selected") : ""
        if ratio < 0.001 {
            return L10n.trf("cal.a11y.incomplete_body", d) + sel
        }
        if ratio < 1 {
            return L10n.trf("cal.a11y.partial_body", d, pct) + sel
        }
        return L10n.trf("cal.a11y.complete_body", d) + sel
    }

    // MARK: - 日期辅助（C8：从文件级全局函数收进视图私有方法）

    private func generateDays(for date: Date) -> [Date] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: date)!
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date))!

        return range.map {
            cal.date(byAdding: .day, value: $0 - 1, to: start)!
        }
    }

    private func dayNumber(_ date: Date) -> Int {
        Calendar.current.component(.day, from: date)
    }
}

private struct YearMonthPickerSheet: View {

    @Binding var selectedDate: Date
    @Binding var isPresented: Bool

    @State private var year: Int
    @State private var month: Int

    private let cal = Calendar.current

    init(selectedDate: Binding<Date>, isPresented: Binding<Bool>) {
        self._selectedDate = selectedDate
        self._isPresented = isPresented
        let d = selectedDate.wrappedValue
        _year = State(initialValue: Calendar.current.component(.year, from: d))
        _month = State(initialValue: Calendar.current.component(.month, from: d))
    }

    private var yearRange: ClosedRange<Int> {
        let y = cal.component(.year, from: Date())
        return (y - 20)...(y + 10)
    }

    var body: some View {
        NavigationView {
            Form {
                Picker(L10n.tr("cal.picker.year"), selection: $year) {
                    ForEach(Array(yearRange), id: \.self) { y in
                        Text(L10n.trf("cal.year_suffix_fmt", y)).tag(y)
                    }
                }
                Picker(L10n.tr("cal.picker.month"), selection: $month) {
                    ForEach(1...12, id: \.self) { m in
                        Text(LocalizedDateFormat.standaloneMonth(m)).tag(m)
                    }
                }
            }
            .navigationTitle(L10n.tr("cal.picker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.done")) {
                        applySelection()
                        isPresented = false
                    }
                }
            }
        }
    }

    private func applySelection() {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let anchor = cal.date(from: comps),
              let dayRange = cal.range(of: .day, in: .month, for: anchor) else { return }
        let prevDay = cal.component(.day, from: selectedDate)
        let clamped = min(prevDay, dayRange.count)
        comps.day = clamped
        guard let final = cal.date(from: comps) else { return }
        selectedDate = final.calendarDayStart
    }
}
