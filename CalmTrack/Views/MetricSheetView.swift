//
//  MetricSheetView.swift
//  CalmTrack
//
//  修复两个 bug：
//  - 打开弹窗不再创建空 MetricRecord（读路径只读）。
//  - 保存只写「本次真正动过的滑杆 + 已有的旧值」：未触碰的指标不再被写成 0，
//    避免 7 天反馈均值被幽灵 0 拉低。
//

import SwiftUI
import CoreData

struct MetricSheetView: View {

    var date: Date

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// C6：可注入的服务（默认共享实例，预览/测试可换）。
    var metricService: MetricService = .shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MetricItem.sortIndex, ascending: true)]
    ) private var metrics: FetchedResults<MetricItem>

    @State private var values: [UUID: Double] = [:]
    @State private var loadedValues: [UUID: Double] = [:]
    @State private var touched: Set<UUID> = []

    var body: some View {
        NavigationView {
            Form {
                if metrics.isEmpty {
                    Section {
                        Text(L10n.tr("metric.add_in_settings_first"))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(metrics, id: \.objectID) { metric in
                        if let id = metric.id {
                            Section(header: Text(metric.name ?? "")) {
                                let maxV = Double(metric.maxValue)
                                VStack(spacing: 8) {
                                    Slider(
                                        value: Binding(
                                            get: { values[id] ?? 0 },
                                            set: {
                                                values[id] = $0
                                                touched.insert(id)
                                            }
                                        ),
                                        in: 0...max(1, maxV),
                                        step: 1
                                    )
                                    .tint(CalmChrome.calmFill(colorScheme))

                                    HStack {
                                        Text(L10n.tr("metric.score_low"))
                                        Spacer()
                                        Text(L10n.tr("metric.score_high"))
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }

                                HStack {
                                    Spacer()
                                    Text(L10n.tr("metric.current_score"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(Int(values[id] ?? 0))")
                                        .font(.title2.monospacedDigit())
                                        .fontWeight(.semibold)
                                        .foregroundStyle(CalmChrome.calmFill(colorScheme))
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("metric.record_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("metric.close")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("metric.save")) {
                        save()
                        dismiss()
                    }
                    .disabled(metrics.isEmpty)
                }
            }
            .onAppear {
                load()
            }
        }
    }

    private func load() {
        // 只读：不创建记录。
        loadedValues = metricService.values(for: date, in: context)
        values = loadedValues
        touched = []
        for metric in metrics {
            guard let id = metric.id else { continue }
            if values[id] == nil {
                values[id] = 0
            }
        }
    }

    private func save() {
        // 合并「已有旧值 + 本次触碰项」：未触碰的指标保持原状，避免写成 0；
        // 没有任何数据可写时（无旧记录且什么都没动）不创建记录。
        var toSave = loadedValues
        for id in touched {
            toSave[id] = values[id] ?? 0
        }
        guard !toSave.isEmpty else { return }
        metricService.setValues(toSave, for: date, in: context)
    }
}
