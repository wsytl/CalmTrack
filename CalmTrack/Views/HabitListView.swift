//
//  HabitListView.swift
//  CalmTrack
//
//  C3/C4/C6 优化：
//  - 移除手动 refreshToken：HabitService 作为 ObservableObject 在写入后自动通知。
//  - 视图只消费类型化的 HabitDayState，不再调用 blob 解码 helper。
//  - DietNote 的取/建逻辑收敛到 DayRecordStore。
//

import SwiftUI
import CoreData

struct HabitListView: View {

    var date: Date
    var showCalendar: Bool
    @Binding var selectedDate: Date

    /// C6：可注入的服务（默认共享实例）。
    @ObservedObject var habitService: HabitService = .shared

    /// 订阅当日打卡记录，以便 completedIDs 变更后立即刷新勾选状态。
    @FetchRequest private var dayHabitRecords: FetchedResults<HabitRecord>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HabitCategory.sortIndex, ascending: true)]
    ) private var categories: FetchedResults<HabitCategory>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "sortIndex", ascending: true)],
        predicate: NSPredicate(format: "category == nil")
    ) private var uncategorizedHabits: FetchedResults<HabitItem>

    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDietNote = false

    init(
        date: Date,
        showCalendar: Bool,
        selectedDate: Binding<Date>,
        habitService: HabitService = .shared
    ) {
        self.date = date
        self.showCalendar = showCalendar
        self._selectedDate = selectedDate
        self._habitService = ObservedObject(wrappedValue: habitService)
        let request = HabitRecord.fetchRequest()
        request.predicate = NSPredicate(format: "date == %@", date.calendarDayStart as NSDate)
        // 排序固定，避免同一天存在多条记录时解码结果不确定。
        request.sortDescriptors = [NSSortDescriptor(keyPath: \HabitRecord.date, ascending: true)]
        _dayHabitRecords = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        let dayState = habitService.dayState(from: Array(dayHabitRecords))
        let hasAnyHabit = categories.contains { !sortedHabits(for: $0).isEmpty } || !uncategorizedHabits.isEmpty

        List {
            if showCalendar {
                Section {
                    CalendarView(selectedDate: $selectedDate)
                        .padding(.vertical, 4)
                }
                .listRowSeparator(.hidden)
            }

            Section {
                TodayNourishmentCard()
                    .listCardRowStyle()

                HabitSummaryStrip(selectedDate: date)
                    .listCardRowStyle()

                Button {
                    showDietNote = true
                } label: {
                    Label(L10n.tr("diet_note.quick_entry"), systemImage: "note.text")
                        .font(.subheadline.weight(.medium))
                }
            }
            .listRowSeparator(.hidden)

            if hasAnyHabit {
                if isFutureDate {
                    Section {
                        Text(L10n.tr("habit.no_future_checkin"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if isPastDate {
                    Section {
                        Text(L10n.tr("habit.history_locked"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(categories, id: \.objectID) { category in
                    let habits = sortedHabits(for: category)
                    if !habits.isEmpty {
                        Section(header: Text(category.name ?? "")) {
                            habitRows(habits, dayState: dayState)
                        }
                    }
                }
                if !uncategorizedHabits.isEmpty {
                    Section(header: Text(L10n.tr("habit.uncategorized"))) {
                        habitRows(Array(uncategorizedHabits), dayState: dayState)
                    }
                }
            } else {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text(L10n.tr("habit.empty_title"))
                            .font(.headline)
                        Text(L10n.tr("habit.empty_subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .sheet(isPresented: $showDietNote) {
            DietNoteSheetView(date: date)
                .environment(\.managedObjectContext, context)
        }
    }

    private var todayStart: Date {
        Date().calendarDayStart
    }

    private var selectedDayStart: Date {
        date.calendarDayStart
    }

    private var isFutureDate: Bool {
        selectedDayStart > todayStart
    }

    private var isPastDate: Bool {
        selectedDayStart < todayStart
    }

    /// 仅允许修改「今天」的打卡；未来不可打，历史只读。
    private var canEditCheckIn: Bool {
        selectedDayStart == todayStart
    }

    private var accessibilityCheckInLabel: String {
        if isFutureDate { return L10n.tr("habit.checkin_future_a11y") }
        if isPastDate { return L10n.tr("habit.checkin_history_a11y") }
        return L10n.tr("habit.checkin_a11y")
    }

    private func sortedHabits(for category: HabitCategory) -> [HabitItem] {
        guard let set = category.habits as? Set<HabitItem> else { return [] }
        return set.sorted { $0.sortIndex < $1.sortIndex }
    }

    @ViewBuilder
    private func habitRows(_ habits: [HabitItem], dayState: HabitDayState) -> some View {
        ForEach(habits, id: \.objectID) { item in
            habitRow(item, dayState: dayState)
        }
    }

    private func isDone(itemID: UUID, dayState: HabitDayState) -> Bool {
        dayState.completedIDs.contains(itemID)
    }

    @ViewBuilder
    private func habitRow(_ item: HabitItem, dayState: HabitDayState) -> some View {
        if let itemID = item.id {
            let done = isDone(itemID: itemID, dayState: dayState)
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: iconName(for: item.category?.name))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(done ? CalmChrome.calmFill(colorScheme) : .secondary)
                    .frame(width: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title ?? "")
                    if item.kind == "count" || item.kind == "rating" {
                        Text(progressText(for: item, itemID: itemID, dayState: dayState))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                control(for: item, itemID: itemID, done: done)
            }
        }
    }

    @ViewBuilder
    private func control(for item: HabitItem, itemID: UUID, done: Bool) -> some View {
        switch item.kind {
        case "count":
            HStack(spacing: 10) {
                Button {
                    habitService.adjustProgress(item: item, delta: -1, date: date, in: context)
                } label: {
                    Image(systemName: "minus.circle")
                }
                Button {
                    habitService.adjustProgress(item: item, delta: 1, date: date, in: context)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .font(.title3)
            .foregroundStyle(CalmChrome.calmFill(colorScheme))
            .buttonStyle(.plain)
            .disabled(!canEditCheckIn)
        case "rating":
            Menu {
                ForEach(1...Int(max(1, item.targetValue)), id: \.self) { value in
                    Button("\(value)") {
                        habitService.setRating(item: item, value: Double(value), date: date, in: context)
                    }
                }
                Button(L10n.tr("common.clear")) {
                    habitService.setRating(item: item, value: 0, date: date, in: context)
                }
            } label: {
                Image(systemName: done ? "star.circle.fill" : "star.circle")
                    .font(.title3)
                    .foregroundStyle(done ? CalmChrome.calmFill(colorScheme) : CalmChrome.calmTrack(colorScheme))
            }
            .disabled(!canEditCheckIn)
        default:
            Button {
                habitService.toggle(
                    itemID: itemID,
                    date: date,
                    in: context
                )
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(done ? .hierarchical : .monochrome)
                    .foregroundStyle(done ? CalmChrome.calmFill(colorScheme) : CalmChrome.calmTrack(colorScheme))
            }
            .buttonStyle(.plain)
            .disabled(!canEditCheckIn)
            .accessibilityLabel(accessibilityCheckInLabel)
        }
    }

    private func progressText(for item: HabitItem, itemID: UUID, dayState: HabitDayState) -> String {
        let value = dayState.progress[itemID] ?? 0
        let target = Int(max(1, item.targetValue))
        if item.kind == "rating" {
            return value > 0 ? L10n.trf("habit.rating_value_fmt", Int(value), target) : L10n.tr("habit.rating_empty")
        }
        let unit = item.unit?.isEmpty == false ? item.unit! : L10n.tr("habit.count_unit_default")
        return L10n.trf("habit.count_value_fmt", Int(value), target, unit)
    }

    private func iconName(for categoryName: String?) -> String {
        switch categoryName {
        case "饮食调养":
            return "fork.knife"
        case "忌口守护":
            return "cup.and.saucer"
        case "作息活动":
            return "figure.walk"
        case "身体观察":
            return "heart.text.square"
        default:
            return "leaf"
        }
    }
}

private struct DietNoteSheetView: View {

    var date: Date

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var breakfast = ""
    @State private var lunch = ""
    @State private var dinner = ""
    @State private var reaction = ""
    @State private var isReactionPreview = false

    var body: some View {
        NavigationView {
            Form {
                Section(L10n.tr("diet_note.meals")) {
                    TextField(L10n.tr("diet_note.breakfast"), text: $breakfast)
                    TextField(L10n.tr("diet_note.lunch"), text: $lunch)
                    TextField(L10n.tr("diet_note.dinner"), text: $dinner)
                }
                Section {
                    Picker("", selection: $isReactionPreview) {
                        Text(L10n.tr("diet_note.markdown_edit")).tag(false)
                        Text(L10n.tr("diet_note.markdown_preview")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if isReactionPreview {
                        if reaction.isEmpty {
                            Text(L10n.tr("diet_note.markdown_preview_empty"))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            MarkdownText(text: reaction)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                    } else {
                        TextEditor(text: $reaction)
                            .frame(minHeight: 120)
                            .overlay(alignment: .topLeading) {
                                if reaction.isEmpty {
                                    Text(L10n.tr("diet_note.reaction_placeholder"))
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                } header: {
                    Text(L10n.tr("diet_note.reaction"))
                } footer: {
                    if !isReactionPreview {
                        Text(L10n.tr("diet_note.markdown_hint"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(L10n.tr("diet_note.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        let note = noteForDay(createIfNeeded: false)
        breakfast = note?.breakfast ?? ""
        lunch = note?.lunch ?? ""
        dinner = note?.dinner ?? ""
        reaction = note?.reaction ?? ""
    }

    private func save() {
        let note = noteForDay(createIfNeeded: true)
        note?.breakfast = breakfast
        note?.lunch = lunch
        note?.dinner = dinner
        note?.reaction = reaction
        try? context.save()
    }

    private func noteForDay(createIfNeeded: Bool) -> DietNote? {
        if let existing = DayRecordStore.existing(DietNote.self, for: date, in: context) {
            return existing
        }
        guard createIfNeeded else { return nil }
        return DayRecordStore.fetchOrCreate(DietNote.self, for: date, in: context) { _ in }
    }
}

private extension View {
    func listCardRowStyle() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
    }
}
