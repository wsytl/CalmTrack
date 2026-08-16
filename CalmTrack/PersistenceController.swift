//
//  PersistenceController.swift
//  CalmTrack
//
//  C6 优化：新增 inMemory 预览/测试容器（PersistenceController.preview）。
//  C2 优化：种子数据中的习惯类型判定改用 TemplateCatalog 的统一启发式。
//  顺带移除从未被读取、且写法矛盾的 MetricItem.type 写入。
//

import Foundation
import CoreData

struct PersistenceController {

    static let shared = PersistenceController()

    /// 内存存储的预览/测试容器：SwiftUI 预览与单测不再需要真实磁盘库。
    static var preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let pc = NSPersistentContainer(name: "CalmTrack")
        let description = pc.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        if inMemory {
            description?.type = NSInMemoryStoreType
        }

        pc.loadPersistentStores { _, error in
            if let error = error {
                fatalError("CoreData error: \(error)")
            }
            DispatchQueue.main.async {
                Self.seedFoodTherapyDefaultsIfNeeded(context: pc.viewContext)
            }
        }
        container = pc
    }

    private static func seedFoodTherapyDefaultsIfNeeded(context: NSManagedObjectContext) {
        context.performAndWait {
            let categoryRequest = HabitCategory.fetchRequest()
            let existingCategories = (try? context.fetch(categoryRequest)) ?? []
            let habitRequest = HabitItem.fetchRequest()
            let habitCount = (try? context.count(for: habitRequest)) ?? 0
            let shouldUpgradeLegacyDefaults = habitCount == 0 && Self.isLegacyEmptyDefault(existingCategories)

            let categoryNames = ["饮食调养", "忌口守护", "作息活动", "身体观察"]
            let categories: [HabitCategory]
            if existingCategories.isEmpty {
                categories = categoryNames.enumerated().map { index, name in
                    let category = HabitCategory(context: context)
                    category.id = UUID()
                    category.name = name
                    category.sortIndex = Int16(index)
                    return category
                }
            } else if shouldUpgradeLegacyDefaults {
                let sorted = existingCategories.sorted { $0.sortIndex < $1.sortIndex }
                for (index, name) in categoryNames.prefix(sorted.count).enumerated() {
                    sorted[index].name = name
                    sorted[index].sortIndex = Int16(index)
                }
                if sorted.count < categoryNames.count {
                    for index in sorted.count..<categoryNames.count {
                        let category = HabitCategory(context: context)
                        category.id = UUID()
                        category.name = categoryNames[index]
                        category.sortIndex = Int16(index)
                    }
                }
                categories = (try? context.fetch(categoryRequest)) ?? sorted
            } else {
                categories = existingCategories
            }

            if habitCount == 0, existingCategories.isEmpty || shouldUpgradeLegacyDefaults {
                let defaults: [(String, [String])] = [
                    ("饮食调养", ["晨起温水一杯", "早餐吃温热主食", "晚餐七分饱"]),
                    ("忌口守护", ["今天不喝冰饮", "睡前不吃夜宵"]),
                    ("作息活动", ["饭后散步 10 分钟", "23 点前准备休息"]),
                    ("身体观察", ["记录今日胃口与腹胀"])
                ]

                for (categoryName, titles) in defaults {
                    guard let category = categories.first(where: { $0.name == categoryName }) else { continue }
                    for (index, title) in titles.enumerated() {
                        let habit = HabitItem(context: context)
                        habit.id = UUID()
                        habit.title = title
                        let kindUnit = TemplateCatalog.kindAndUnit(for: title)
                        habit.kind = kindUnit.kind
                        habit.targetValue = 1
                        habit.unit = kindUnit.unit
                        habit.category = category
                        habit.sortIndex = Int16(index)
                    }
                }
            }

            let metricRequest = MetricItem.fetchRequest()
            let metricCount = (try? context.count(for: metricRequest)) ?? 0
            if metricCount == 0 {
                let metrics = ["胃口", "腹胀舒适", "睡眠", "精神", "排便顺畅"]
                for (index, name) in metrics.enumerated() {
                    let metric = MetricItem(context: context)
                    metric.id = UUID()
                    metric.name = name
                    metric.maxValue = 5
                    metric.sortIndex = Int16(index)
                }
            }

            if context.hasChanges {
                DayRecordStore.save(context)
            }
        }
    }

    private static func isLegacyEmptyDefault(_ categories: [HabitCategory]) -> Bool {
        let names = Set(categories.compactMap(\.name))
        return names == Set(["晨起", "日间", "晚间"])
    }
}
