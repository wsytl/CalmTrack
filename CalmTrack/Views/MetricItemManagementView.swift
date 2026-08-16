//
//  MetricItemManagementView.swift
//  CalmTrack
//

import SwiftUI
import CoreData

struct MetricItemManagementView: View {

    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MetricItem.sortIndex, ascending: true)]
    ) private var metrics: FetchedResults<MetricItem>

    @State private var showNewSheet = false

    var body: some View {
        Group {
            if metrics.isEmpty {
                emptyPlaceholder(
                    title: L10n.tr("metricmgmt.empty_title"),
                    subtitle: L10n.tr("metricmgmt.empty_subtitle"),
                    systemImage: "slider.horizontal.3"
                )
            } else {
                List {
                    ForEach(metrics, id: \.objectID) { metric in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(L10n.tr("metricmgmt.field_metric_name"), text: Binding(
                                get: { metric.name ?? "" },
                                set: {
                                    metric.name = $0
                                    try? context.save()
                                }
                            ))
                            Text(L10n.trf("metricmgmt.hint_range_fmt", Int(metric.maxValue)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                context.delete(metric)
                                try? context.save()
                            } label: {
                                Label(L10n.tr("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("metricmgmt.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.tr("metricmgmt.add_a11y"))
            }
        }
        .sheet(isPresented: $showNewSheet) {
            NavigationView {
                NewMetricItemForm {
                    showNewSheet = false
                }
                .environment(\.managedObjectContext, context)
            }
        }
    }
}

private struct NewMetricItemForm: View {

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let onDone: () -> Void

    @State private var name = ""

    var body: some View {
        Form {
            TextField(L10n.tr("habitproj.name_field"), text: $name)
            Text(L10n.tr("metricmgmt.new_hint"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(L10n.tr("metricmgmt.new_title"))
        .navigationBarTitleDisplayMode(.inline)
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
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let request = MetricItem.fetchRequest()
        let count = (try? context.count(for: request)) ?? 0
        let metric = MetricItem(context: context)
        metric.id = UUID()
        metric.name = trimmed
        metric.maxValue = 5
        metric.sortIndex = Int16(count)
        try? context.save()
    }
}
