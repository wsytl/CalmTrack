//
//  MetricHistoryView.swift
//  CalmTrack
//
//  C4/C5/C6/C7 优化：
//  - 同日多记录合并收敛到 MetricService.values(from:)，视图不再手写 merge。
//  - 7 天完成率改用 HabitService.completionRatio 统一语义。
//  - 习惯记录全量拉取，7 天窗口由纯函数 completedIDsByDay(from:lastNDays:endingOn:) 过滤（与方案 D 同构）。
//

import SwiftUI
import CoreData

/// 按月份分组列出已保存的状态指标数值。
struct MetricHistoryView: View {

    /// C6：可注入的服务（默认共享实例）。
    @ObservedObject var habitService: HabitService = .shared
    var metricService: MetricService = .shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MetricRecord.date, ascending: false)]
    ) private var records: FetchedResults<MetricRecord>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MetricItem.sortIndex, ascending: true)]
    ) private var metrics: FetchedResults<MetricItem>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "sortIndex", ascending: true)]
    ) private var allHabits: FetchedResults<HabitItem>

    /// 全量拉取习惯记录（方案 D）；7 天窗口由纯函数在 body 中过滤，@FetchRequest 自动跟随写入刷新。
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HabitRecord.date, ascending: true)]
    ) private var allHabitRecords: FetchedResults<HabitRecord>

    init(habitService: HabitService = .shared, metricService: MetricService = .shared) {
        self._habitService = ObservedObject(wrappedValue: habitService)
        self.metricService = metricService
    }

    /// 同一自然日可能有多条 MetricRecord，合并为一条展示（同指标以后写入为准）。
    private var mergedRowsByDay: [(day: Date, values: [UUID: Double])] {
        var byDay: [Date: [MetricRecord]] = [:]
        for record in records {
            guard let raw = record.date else { continue }
            byDay[raw.calendarDayStart, default: []].append(record)
        }
        return byDay.keys.sorted(by: >).map { day in
            let dayRecords = byDay[day]!.sorted {
                $0.objectID.uriRepresentation().absoluteString < $1.objectID.uriRepresentation().absoluteString
            }
            return (day: day, values: metricService.values(from: dayRecords))
        }
    }

    /// 按自然月分组，月内日期从新到旧。
    private var monthSections: [(month: Date, rows: [(day: Date, values: [UUID: Double])])] {
        let cal = Calendar.current
        var dict: [Date: [(day: Date, values: [UUID: Double])]] = [:]
        for row in mergedRowsByDay {
            let comps = cal.dateComponents([.year, .month], from: row.day)
            guard let monthStart = cal.date(from: comps)?.calendarDayStart else { continue }
            dict[monthStart, default: []].append(row)
        }
        let months = dict.keys.sorted(by: >)
        return months.map { m in
            let rows = (dict[m] ?? []).sorted { $0.day > $1.day }
            return (month: m, rows: rows)
        }
    }

    var body: some View {
        List {
            Section {
                sevenDayOverview
            } header: {
                Text(L10n.tr("trend.week_header"))
            }

            if records.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text(L10n.tr("metric_history.empty_title"))
                            .font(.headline)
                        Text(L10n.tr("metric_history.empty_body"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                ForEach(monthSections, id: \.month) { section in
                    Section {
                        ForEach(section.rows, id: \.day) { row in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(LocalizedDateFormat.dayInMonthWithWeekday(row.day))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                if metrics.isEmpty {
                                    Text(L10n.tr("metric_history.no_metrics_hint"))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(metrics, id: \.objectID) { metric in
                                        if let id = metric.id {
                                            metricRow(metric: metric, value: row.values[id] ?? 0)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text(LocalizedDateFormat.monthSection(section.month))
                            .font(.headline)
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("metric_history.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricRow(metric: MetricItem, value: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(metric.name ?? L10n.tr("metric_history.unnamed"))
            Spacer()
            Text(L10n.trf("metric.value_fmt", Int(value), Int(metric.maxValue)))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var sevenDayOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            sevenDayBars
            overviewRow(
                title: L10n.tr("trend.completion_title"),
                value: "\(Int((recentCompletionRatio * 100).rounded()))%",
                progress: recentCompletionRatio
            )
            overviewRow(
                title: L10n.tr("trend.feedback_title"),
                value: feedbackAverageText,
                progress: feedbackAverageProgress
            )
            Text(trendInsight)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var sevenDayBars: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(recentCompletionRatios.enumerated()), id: \.offset) { _, ratio in
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor.opacity(0.75))
                        .frame(height: max(8, 48 * ratio))
                    Circle()
                        .fill(ratio >= 0.99 ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 64)
    }

    private func overviewRow(title: String, value: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(value)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(1, max(0, progress)))
        }
    }

    private var recentDays: [Date] {
        let today = Date().calendarDayStart
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }.reversed()
    }

    private var recentCompletionRatio: Double {
        let ratios = recentCompletionRatios
        guard !ratios.isEmpty else { return 0 }
        return ratios.reduce(0, +) / Double(ratios.count)
    }

    private var recentCompletionRatios: [Double] {
        let habitIDs = Set(allHabits.compactMap(\.id))
        guard !habitIDs.isEmpty else { return Array(repeating: 0, count: 7) }
        let completedByDay = habitService.completedIDsByDay(from: Array(allHabitRecords), lastNDays: 7, endingOn: Date())
        return recentDays.map { day in
            habitService.completionRatio(
                habitIDs: habitIDs,
                completedByDay: completedByDay,
                day: day
            )
        }
    }

    private var recentFeedbackAverage: Double? {
        let recentSet = Set(recentDays)
        let values = mergedRowsByDay
            .filter { recentSet.contains($0.day) }
            .flatMap { $0.values.values }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var feedbackAverageText: String {
        guard let average = recentFeedbackAverage else { return L10n.tr("trend.no_feedback") }
        return String(format: "%.1f / 5", average)
    }

    private var feedbackAverageProgress: Double {
        guard let average = recentFeedbackAverage else { return 0 }
        return average / 5
    }

    private var trendInsight: String {
        if recentCompletionRatio >= 0.8 {
            return L10n.tr("trend.insight_good")
        }
        if recentCompletionRatio >= 0.45 {
            return L10n.tr("trend.insight_middle")
        }
        return L10n.tr("trend.insight_low")
    }
}
