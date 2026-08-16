import CoreData
import XCTest
@testable import CalmTrack

/// 测试辅助：in-memory Core Data 上下文（不跑 PersistenceController 的种子逻辑）。
enum TestCoreData {

    static func makeInMemoryContext() -> NSManagedObjectContext {
        let bundle = Bundle(for: HabitService.self)
        guard let modelURL = bundle.url(forResource: "CalmTrack", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("找不到 CalmTrack.momd 数据模型")
        }
        let container = NSPersistentContainer(name: "CalmTrack", managedObjectModel: model)
        container.persistentStoreDescriptions.first?.type = NSInMemoryStoreType
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("in-memory store 加载失败: \(error)")
            }
        }
        return container.viewContext
    }

    /// 用系统时区构造一个自然日零点（独立于被测代码的期望值来源）。
    static func day(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
