//
//  CategoryManagementView.swift
//  CalmTrack
//

import SwiftUI
import CoreData

struct CategoryManagementView: View {

    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HabitCategory.sortIndex, ascending: true)]
    ) private var categories: FetchedResults<HabitCategory>

    @State private var showNewSheet = false
    @State private var newName = ""

    var body: some View {
        Group {
            if categories.isEmpty {
                emptyPlaceholder(
                    title: L10n.tr("cat.empty_title"),
                    subtitle: L10n.tr("cat.empty_subtitle"),
                    systemImage: "folder"
                )
            } else {
                List {
                    ForEach(categories, id: \.objectID) { category in
                        TextField(L10n.tr("cat.field_name"), text: Binding(
                            get: { category.name ?? "" },
                            set: {
                                category.name = $0
                                try? context.save()
                            }
                        ))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                context.delete(category)
                                try? context.save()
                            } label: {
                                Label(L10n.tr("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("cat.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newName = ""
                    showNewSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.tr("cat.add_a11y"))
            }
        }
        .sheet(isPresented: $showNewSheet) {
            NavigationView {
                Form {
                    TextField(L10n.tr("cat.name_placeholder"), text: $newName)
                }
                .navigationTitle(L10n.tr("cat.new_title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.tr("common.cancel")) { showNewSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.tr("common.save")) {
                            addCategory()
                            showNewSheet = false
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func addCategory() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let maxIndex = categories.map(\.sortIndex).max() ?? -1
        let category = HabitCategory(context: context)
        category.id = UUID()
        category.name = trimmed
        category.sortIndex = maxIndex + 1
        try? context.save()
    }
}

