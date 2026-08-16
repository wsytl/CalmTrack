//
//  HomeTabBar.swift
//  CalmTrack
//

import SwiftUI
import CoreData

/// 主页底部「慢养」风格操作栏：清新、低对比、与系统强调色协调。
struct HomeTabBar: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    var onSettings: () -> Void
    var onMetric: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tabButton(icon: "person.crop.circle", title: L10n.tr("tab.settings"), action: onSettings)
            historyLink
            tabButton(icon: "heart.text.square", title: L10n.tr("tab.metrics"), action: onMetric)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CalmChrome.tabBarFill(colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(CalmChrome.tabBarStroke(colorScheme), lineWidth: 1)
                }
                .shadow(color: CalmChrome.tabBarShadow(colorScheme), radius: 14, x: 0, y: 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private func tabButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            tabLabel(icon: icon, title: title)
        }
        .buttonStyle(CalmBarButtonStyle())
    }

    private var historyLink: some View {
        NavigationLink {
            MetricHistoryView()
                .environment(\.managedObjectContext, viewContext)
        } label: {
            tabLabel(icon: "chart.xyaxis.line", title: L10n.tr("tab.history"))
        }
        .buttonStyle(.plain)
    }

    private func tabLabel(icon: String, title: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 22, weight: .light))
                .imageScale(.medium)
            Text(title)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(CalmChrome.tabItemForeground(colorScheme))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        
    }
}
