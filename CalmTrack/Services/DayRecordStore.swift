//
//  DayRecordStore.swift
//  CalmTrack
//
//  C1：统一「按自然日取/建记录」的存储入口。
//  - HabitRecord / MetricRecord / DietNote 共用同一套 fetch-or-create、
//    去重与保存逻辑，避免各调用点重复实现「date == calendarDayStart」。
//  - 模型层没有唯一性约束，因此「一日一记录」的不变量在写入路径强制：
//    同一天存在多条记录时，合并进第一条并删除其余。
//

import Foundation
import CoreData

enum DayRecordStore {

    /// 取某一天的全部记录（只读，不创建）。结果按日期升序，顺序确定。
    static func records<T: NSManagedObject>(_ type: T.Type, for date: Date, in context: NSManagedObjectContext) -> [T] {
        let request = NSFetchRequest<T>(entityName: T.entity().name ?? String(describing: T.self))
        request.predicate = NSPredicate(format: "date == %@", date.calendarDayStart as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    /// 取某一天的第一条记录（只读，不创建）。
    static func existing<T: NSManagedObject>(_ type: T.Type, for date: Date, in context: NSManagedObjectContext) -> T? {
        records(type, for: date, in: context).first
    }

    /// 写入路径专用：已有记录则复用，否则创建（自动补 id / 归一化 date），再执行 configure。
    static func fetchOrCreate<T: NSManagedObject>(
        _ type: T.Type,
        for date: Date,
        in context: NSManagedObjectContext,
        configure: (T) -> Void
    ) -> T? {
        if let existing = existing(type, for: date, in: context) {
            return existing
        }
        let entityName = T.entity().name ?? String(describing: T.self)
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            return nil
        }
        let object = T(entity: entity, insertInto: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue(date.calendarDayStart, forKey: "date")
        configure(object)
        return object
    }

    /// 统一保存；失败在调试期直接暴露。
    static func save(_ context: NSManagedObjectContext) {
        do {
            try context.save()
        } catch {
            assertionFailure("Core Data save failed: \(error)")
        }
    }

    /// 稳定排序键：同一天多条记录时按 objectID 排序，合并顺序确定。
    static func stableKey<T: NSManagedObject>(_ object: T) -> String {
        object.objectID.uriRepresentation().absoluteString
    }
}
