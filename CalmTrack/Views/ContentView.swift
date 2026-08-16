//
//  ContentView.swift
//  CalmTrack
//
//  Created by tianli on 2026/5/2.
//

import SwiftUI
import CoreData

struct ContentView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    /// 与 Core Data 中按「自然日」存库一致，避免冷启动带时分秒的 Date 与日历格子不一致导致读不到记录。
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showCalendar = false
    @State private var showSettings = false
    @State private var showMetric = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {

        NavigationView {

            VStack {

                // 顶部
                HStack(alignment: .center, spacing: 12) {
                    Text(LocalizedDateFormat.monthYear(selectedDate))
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.92))

                    Spacer(minLength: 8)

                    calendarToolbarButton
                }
                .padding(.horizontal)

                Divider()

                // 打卡列表
                HabitListView(
                    date: selectedDate,
                    showCalendar: showCalendar,
                    selectedDate: $selectedDate
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HomeTabBar(
                    onSettings: { showSettings = true },
                    onMetric: { showMetric = true }
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showMetric) {
                MetricSheetView(date: selectedDate)
                    .environment(\.managedObjectContext, viewContext)
            }
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { hasCompletedOnboarding = !$0 }
            )) {
                OnboardingView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .navigationTitle(L10n.tr("app.display_name"))
        }
    }

    private var calendarToolbarButton: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                showCalendar.toggle()
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: showCalendar ? "calendar.circle.fill" : "calendar")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 17, weight: .regular))
                Text(L10n.tr("home.calendar"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(CalmChrome.tabItemForeground(colorScheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CalmChrome.calendarPillFill(colorScheme, isExpanded: showCalendar))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                CalmChrome.calendarPillStroke(colorScheme, isExpanded: showCalendar),
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(CalmBarButtonStyle())
        .accessibilityLabel(showCalendar ? L10n.tr("home.calendar.collapse_a11y") : L10n.tr("home.calendar.expand_a11y"))
    }
}

private struct OnboardingView: View {

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("nourishmentGoal") private var selectedGoal = "健脾养胃"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var templateName = "养胃 7 天"

    private let goals = ["健脾养胃", "祛湿轻身", "控糖饮食", "改善睡眠", "清淡减脂"]
    private let templates = ["养胃 7 天", "祛湿轻身", "控糖饮食", "早睡温养"]

    var body: some View {
        NavigationView {
            List {
                Section(L10n.tr("onboarding.goal_header")) {
                    Picker(L10n.tr("settings.goal_profile"), selection: $selectedGoal) {
                        ForEach(goals, id: \.self) { goal in
                            Text(goal).tag(goal)
                        }
                    }
                }

                Section(L10n.tr("onboarding.template_header")) {
                    Picker(L10n.tr("settings.templates"), selection: $templateName) {
                        ForEach(templates, id: \.self) { template in
                            Text(template).tag(template)
                        }
                    }
                }

                Section {
                    Button {
                        applyTemplate(named: templateName)
                        hasCompletedOnboarding = true
                        dismiss()
                    } label: {
                        Text(L10n.tr("onboarding.start"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle(L10n.tr("onboarding.nav_title"))
        }
    }

    private func applyTemplate(named name: String) {
        guard let template = TemplateCatalog.template(named: name) else { return }
        TemplateCatalog.apply(template, in: context)
    }
}

struct TodayNourishmentCard: View {

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("nourishmentGoal") private var selectedGoal = "健脾养胃"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MetricRecord.date, ascending: false)]
    ) private var records: FetchedResults<MetricRecord>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MetricItem.sortIndex, ascending: true)]
    ) private var metrics: FetchedResults<MetricItem>

    /// C6：可注入的服务（默认共享实例）。
    var metricService: MetricService = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CalmChrome.calmFill(colorScheme))
                Text(L10n.tr("home.nourishment_title"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(selectedGoal)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CalmChrome.calmFill(colorScheme))
            }

            Text(todayTip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                compactGuidance(
                    title: L10n.tr("home.today_suitable"),
                    body: L10n.tr("home.today_suitable_body"),
                    color: CalmChrome.calmFill(colorScheme)
                )
                compactGuidance(
                    title: L10n.tr("home.today_avoid"),
                    body: L10n.tr("home.today_avoid_body"),
                    color: Color(red: 0.72, green: 0.38, blue: 0.22)
                )
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CalmChrome.nourishmentCardFill(colorScheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(CalmChrome.nourishmentCardStroke(colorScheme), lineWidth: 1)
        }
    }

    private func compactGuidance(title: String, body: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var todayTip: String {
        guard let latestRecord = records.first else {
            return goalTip
        }

        let values = metricService.values(from: [latestRecord])
        let metricByID = Dictionary(uniqueKeysWithValues: metrics.compactMap { metric -> (UUID, MetricItem)? in
            guard let id = metric.id else { return nil }
            return (id, metric)
        })

        let lowItems = values
            .filter { $0.value <= 2 }
            .compactMap { metricByID[$0.key]?.name }

        if lowItems.contains("睡眠") {
            return L10n.tr("home.tip_sleep")
        }
        if lowItems.contains(where: { $0.contains("胃口") || $0.contains("腹胀") }) {
            return L10n.tr("home.tip_stomach")
        }
        if lowItems.contains("精神") {
            return L10n.tr("home.tip_energy")
        }
        return goalTip
    }

    private var goalTip: String {
        switch selectedGoal {
        case "祛湿轻身":
            return L10n.tr("home.tip_dampness")
        case "控糖饮食":
            return L10n.tr("home.tip_sugar")
        case "改善睡眠":
            return L10n.tr("home.tip_sleep_goal")
        case "清淡减脂":
            return L10n.tr("home.tip_light")
        default:
            return L10n.tr("home.tip_stomach_goal")
        }
    }
}
