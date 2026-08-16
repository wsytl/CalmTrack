//
//  SettingsView.swift
//  CalmTrack
//
//  C2：模板定义与应用逻辑收敛到 TemplateCatalog，删除本地重复副本。
//

import SwiftUI
import CoreData

struct SettingsView: View {

    var body: some View {
        NavigationView {
            List {
                Section(L10n.tr("settings.section.profile")) {
                    NavigationLink {
                        NourishmentGoalView()
                    } label: {
                        Label(L10n.tr("settings.goal_profile"), systemImage: "person.text.rectangle")
                    }
                    NavigationLink {
                        NourishmentTemplateView()
                    } label: {
                        Label(L10n.tr("settings.templates"), systemImage: "square.stack.3d.up")
                    }
                }
                Section(L10n.tr("settings.section.manage")) {
                    NavigationLink {
                        CategoryManagementView()
                    } label: {
                        Label(L10n.tr("settings.cat_manage"), systemImage: "square.grid.2x2")
                    }
                    NavigationLink {
                        HabitItemManagementView()
                    } label: {
                        Label(L10n.tr("settings.project_manage"), systemImage: "leaf")
                    }
                }
                Section(L10n.tr("settings.section.metrics")) {
                    NavigationLink {
                        MetricHistoryView()
                    } label: {
                        Label(L10n.tr("settings.metric_history"), systemImage: "chart.xyaxis.line")
                    }
                    NavigationLink {
                        MetricItemManagementView()
                    } label: {
                        Label(L10n.tr("settings.metric_manage"), systemImage: "heart.text.square")
                    }
                }
            }
            .navigationTitle(L10n.tr("settings.nav_title"))
        }
    }
}

private struct NourishmentGoalView: View {

    @AppStorage("nourishmentGoal") private var selectedGoal = "健脾养胃"

    private let goals = [
        ("健脾养胃", "少生冷，重规律，关注胃口与腹胀"),
        ("祛湿轻身", "少甜腻，多温热，关注精神与排便"),
        ("控糖饮食", "稳主食，少精制糖，关注饭后状态"),
        ("改善睡眠", "晚餐清淡，睡前放松，关注入睡质量"),
        ("清淡减脂", "七分饱，少油炸，保持轻量活动")
    ]

    var body: some View {
        List {
            Section {
                ForEach(goals, id: \.0) { goal in
                    Button {
                        selectedGoal = goal.0
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.0)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(goal.1)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedGoal == goal.0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(L10n.tr("goal.profile_footer"))
            }
        }
        .navigationTitle(L10n.tr("goal.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NourishmentTemplateView: View {

    @Environment(\.managedObjectContext) private var context
    @State private var appliedTemplateName: String?

    var body: some View {
        List {
            Section {
                ForEach(TemplateCatalog.all) { template in
                    Button {
                        apply(template)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "leaf")
                                .foregroundStyle(.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(template.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if appliedTemplateName == template.name {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(L10n.tr("templates.footer"))
            }
        }
        .navigationTitle(L10n.tr("templates.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func apply(_ template: HabitTemplate) {
        TemplateCatalog.apply(template, in: context)
        appliedTemplateName = template.name
    }
}
