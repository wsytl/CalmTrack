//
//  HabitItemManagementView.swift
//  CalmTrack
//

import SwiftUI
import CoreData

struct HabitItemManagementView: View {

    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(key: "category.sortIndex", ascending: true),
            NSSortDescriptor(key: "sortIndex", ascending: true),
        ]
    ) private var habits: FetchedResults<HabitItem>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HabitCategory.sortIndex, ascending: true)]
    ) private var categories: FetchedResults<HabitCategory>

    @State private var showNewSheet = false

    var body: some View {
        Group {
            if habits.isEmpty {
                emptyPlaceholder(
                    title: L10n.tr("habitproj.empty_title"),
                    subtitle: L10n.tr("habitproj.empty_subtitle"),
                    systemImage: "checklist"
                )
            } else {
                List {
                    ForEach(habits, id: \.objectID) { habit in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(habit.title ?? "")
                                .font(.body)
                            Text(habit.category?.name ?? L10n.tr("habit.uncategorized"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(typeSummary(for: habit))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                context.delete(habit)
                                try? context.save()
                            } label: {
                                Label(L10n.tr("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("habitproj.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.tr("habitproj.add_a11y"))
                .disabled(categories.isEmpty)
            }
        }
        .sheet(isPresented: $showNewSheet) {
            NewHabitItemSheet(categories: Array(categories)) {
                showNewSheet = false
            }
            .environment(\.managedObjectContext, context)
        }
    }

    private func typeSummary(for habit: HabitItem) -> String {
        switch habit.kind {
        case "count":
            let unit = habit.unit?.isEmpty == false ? habit.unit! : L10n.tr("habit.count_unit_default")
            return L10n.trf("habitproj.type_count_summary_fmt", Int(max(1, habit.targetValue)), unit)
        case "rating":
            return L10n.trf("habitproj.type_rating_summary_fmt", Int(max(1, habit.targetValue)))
        default:
            return L10n.tr("habitproj.type_check")
        }
    }
}

private struct NewHabitItemSheet: View {

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let categories: [HabitCategory]
    let onDone: () -> Void

    @State private var selectedCategoryObjectID: NSManagedObjectID?
    @State private var title = ""
    @State private var kind = "check"
    @State private var targetValue = 1
    @State private var unit = ""

    var body: some View {
        NavigationView {
            Form {
                Picker(L10n.tr("habitproj.picker_category"), selection: $selectedCategoryObjectID) {
                    ForEach(categories, id: \.objectID) { cat in
                        Text(cat.name ?? "").tag(Optional(cat.objectID))
                    }
                }
                TextField(L10n.tr("habitproj.name_field"), text: $title)
                Picker(L10n.tr("habitproj.type_picker"), selection: $kind) {
                    Text(L10n.tr("habitproj.type_check")).tag("check")
                    Text(L10n.tr("habitproj.type_count")).tag("count")
                    Text(L10n.tr("habitproj.type_rating")).tag("rating")
                }
                .pickerStyle(.segmented)

                if kind == "count" {
                    Stepper(
                        L10n.trf("habitproj.target_fmt", targetValue),
                        value: $targetValue,
                        in: 1...20
                    )
                    TextField(L10n.tr("habitproj.unit_field"), text: $unit)
                }

                if kind == "rating" {
                    Stepper(
                        L10n.trf("habitproj.rating_max_fmt", targetValue),
                        value: $targetValue,
                        in: 3...10
                    )
                }
            }
            .navigationTitle(L10n.tr("habitproj.new_title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedCategoryObjectID == nil {
                    selectedCategoryObjectID = categories.first?.objectID
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) {
                        dismiss()
                        onDone()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        save()
                        dismiss()
                        onDone()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        selectedCategoryObjectID != nil
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard let oid = selectedCategoryObjectID,
              let category = try? context.existingObject(with: oid) as? HabitCategory else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let request = HabitItem.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category)
        let siblings = (try? context.fetch(request)) ?? []
        let nextIndex = (siblings.map(\.sortIndex).max() ?? -1) + 1

        let habit = HabitItem(context: context)
        habit.id = UUID()
        habit.title = trimmed
        habit.category = category
        habit.kind = kind
        habit.targetValue = Int16(targetValue)
        habit.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.sortIndex = nextIndex
        try? context.save()
    }
}
