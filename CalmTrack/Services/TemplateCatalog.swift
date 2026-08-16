//
//  TemplateCatalog.swift
//  CalmTrack
//
//  C2：食疗模板的唯一数据源。
//  - Onboarding 与「设置 → 模板」共用同一份模板定义与同一套应用逻辑，
//    消除同名模板内容不一致的问题。
//  - 计数型习惯的判定启发式也集中在这里，与种子数据共用。
//

import Foundation
import CoreData

struct HabitTemplate: Identifiable {
    var id: String { name }
    let name: String
    let subtitle: String
    let categories: [(String, [String])]
}

enum TemplateCatalog {

    static let all: [HabitTemplate] = [
        HabitTemplate(
            name: "养胃 7 天",
            subtitle: "温热规律，减少刺激",
            categories: [
                ("饮食调养", ["晨起温水一杯", "早餐吃温热主食", "晚餐七分饱"]),
                ("忌口守护", ["今天不喝冰饮", "少辛辣刺激"]),
                ("身体观察", ["记录胃口与腹胀"])
            ]
        ),
        HabitTemplate(
            name: "祛湿轻身",
            subtitle: "少甜腻，保持轻活动",
            categories: [
                ("饮食调养", ["晚餐少油少甜", "今日吃温热熟食"]),
                ("作息活动", ["饭后散步 10 分钟", "出汗后及时擦干"]),
                ("忌口守护", ["少奶茶甜品", "今天不喝冰饮"])
            ]
        ),
        HabitTemplate(
            name: "控糖饮食",
            subtitle: "稳定主食和甜食摄入",
            categories: [
                ("饮食调养", ["主食定量不过量", "每餐搭配蔬菜"]),
                ("忌口守护", ["不喝含糖饮料", "少精制甜点"]),
                ("身体观察", ["记录餐后精神状态"])
            ]
        ),
        HabitTemplate(
            name: "早睡温养",
            subtitle: "清淡晚餐，提前收心",
            categories: [
                ("作息活动", ["23 点前准备休息", "睡前远离屏幕 20 分钟"]),
                ("饮食调养", ["晚餐七分饱"]),
                ("忌口守护", ["睡前不吃夜宵"])
            ]
        )
    ]

    static func template(named name: String) -> HabitTemplate? {
        all.first { $0.name == name }
    }

    /// 统一判定习惯类型：含「杯」视为计数型（带单位），否则为勾选型。
    /// 替代原来散落各处的「一杯」/「温水」两种不一致的启发式。
    static func kindAndUnit(for title: String) -> (kind: String, unit: String?) {
        if title.contains("杯") {
            return ("count", "杯")
        }
        return ("check", nil)
    }

    /// 应用模板：按分类去重追加习惯。
    static func apply(_ template: HabitTemplate, in context: NSManagedObjectContext) {
        for (categoryName, taskTitles) in template.categories {
            guard let category = category(named: categoryName, in: context) else { continue }
            let existingTitles = Set(sortedHabits(for: category).compactMap(\.title))
            var nextIndex = (sortedHabits(for: category).map(\.sortIndex).max() ?? -1) + 1
            for title in taskTitles where !existingTitles.contains(title) {
                let habit = HabitItem(context: context)
                habit.id = UUID()
                habit.title = title
                let kindUnit = kindAndUnit(for: title)
                habit.kind = kindUnit.kind
                habit.targetValue = 1
                habit.unit = kindUnit.unit
                habit.category = category
                habit.sortIndex = Int16(nextIndex)
                nextIndex += 1
            }
        }
        DayRecordStore.save(context)
    }

    private static func category(named name: String, in context: NSManagedObjectContext) -> HabitCategory? {
        let request = HabitCategory.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        if let existing = try? context.fetch(request).first {
            return existing
        }

        let allRequest = HabitCategory.fetchRequest()
        let categories = (try? context.fetch(allRequest)) ?? []
        let category = HabitCategory(context: context)
        category.id = UUID()
        category.name = name
        category.sortIndex = (categories.map(\.sortIndex).max() ?? -1) + 1
        return category
    }

    private static func sortedHabits(for category: HabitCategory) -> [HabitItem] {
        guard let set = category.habits as? Set<HabitItem> else { return [] }
        return set.sorted { $0.sortIndex < $1.sortIndex }
    }
}
