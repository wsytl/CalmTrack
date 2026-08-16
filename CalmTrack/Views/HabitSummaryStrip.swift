//
//  HabitSummaryStrip.swift
//  CalmTrack
//
//  C3：移除 refreshToken，改由 HabitService.changeToken 自动触发重算。
//  C5：完成率计算收敛到 HabitService.completionRatio。
//

import SwiftUI
import CoreData

/// 今日 / 当日完成率与连续「全部完成」天数。
struct HabitSummaryStrip: View {

    var selectedDate: Date

    /// C6：可注入的服务（默认共享实例）。
    @ObservedObject var habitService: HabitService = .shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "sortIndex", ascending: true)]
    ) private var allHabits: FetchedResults<HabitItem>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HabitRecord.date, ascending: true)]
    ) private var allRecords: FetchedResults<HabitRecord>

    @Environment(\.colorScheme) private var colorScheme

    private var habitIDs: Set<UUID> {
        Set(allHabits.compactMap(\.id))
    }

    private var completedByDay: [Date: Set<UUID>] {
        habitService.completedIDsByDay(from: Array(allRecords))
    }

    private var isFutureSelectedDay: Bool {
        selectedDate.calendarDayStart > Date().calendarDayStart
    }

    private var completionRatio: Double {
        habitService.completionRatio(
            habitIDs: habitIDs,
            completedByDay: completedByDay,
            day: selectedDate,
            isFuture: isFutureSelectedDay
        )
    }

    private var streak: Int {
        habitService.fullCompletionStreak(
            habitIDs: habitIDs,
            completedByDay: completedByDay
        )
    }

    var body: some View {
        let total = habitIDs.count
        if total == 0 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 14) {
                    completionRing(ratio: completionRatio, isFuture: isFutureSelectedDay)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(titleText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if !isFutureSelectedDay {
                            ProgressView(value: completionRatio)
                                .tint(CalmChrome.calmFill(colorScheme))
                        } else {
                            Text(L10n.tr("summary.future_no_rate"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(CalmChrome.calmFill(colorScheme))
                        .accessibilityHidden(true)
                    Text(streak == 0 ? L10n.tr("summary.streak_none") : L10n.trf("summary.streak_days_fmt", streak))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CalmChrome.calmCardWash(colorScheme))
            )
        }
    }

    private var titleText: String {
        if isFutureSelectedDay {
            return L10n.tr("summary.title_future_day")
        }
        let pct = Int((completionRatio * 100).rounded())
        if Calendar.current.isDateInToday(selectedDate) {
            return L10n.trf("summary.title_today_fmt", pct)
        }
        return L10n.trf("summary.title_day_fmt", pct)
    }

    private func completionRing(ratio: Double, isFuture: Bool) -> some View {
        let clamped = min(1, max(0, ratio))
        return ZStack {
            Circle()
                .stroke(CalmChrome.calmTrack(colorScheme), lineWidth: 6)
            if !isFuture {
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(CalmChrome.calmFill(colorScheme), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text(isFuture ? "—" : "\(Int((clamped * 100).rounded()))%")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isFuture ? Color.secondary : Color.primary)
        }
        .frame(width: 52, height: 52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isFuture
                ? L10n.tr("summary.a11y.future")
                : L10n.trf("summary.a11y.progress_fmt", Int((clamped * 100).rounded()))
        )
    }
}
