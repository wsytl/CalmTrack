//
//  MetricService.swift
//  CalmTrack
//
//  C1/C4/C6 优化：
//  - 读路径只取不建（values(for:in:)），不再因为「打开弹窗」就插入空 MetricRecord。
//  - 写入路径经 DayRecordStore 统一 fetch-or-create 并删除同日重复记录。
//  - 视图只接触 [UUID: Double]，不再读取 Transformable 的 NSDictionary。
//

import Foundation
import CoreData

final class MetricService {

    static let shared = MetricService()

    /// 读取某一天的全部指标值（只读，不创建记录；重复记录按顺序合并，后者覆盖前者）。
    func values(for date: Date, in context: NSManagedObjectContext) -> [UUID: Double] {
        values(from: DayRecordStore.records(MetricRecord.self, for: date, in: context))
    }

    /// 由已取回的记录解码合并出指标值。
    func values(from records: [MetricRecord]) -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        for record in records {
            for (id, value) in decode(record.values) {
                result[id] = value
            }
        }
        return result
    }

    /// 保存某一天的指标值。写入路径才创建记录；同日历史重复记录先合并删除。
    func setValues(_ values: [UUID: Double], for date: Date, in context: NSManagedObjectContext) {
        let records = DayRecordStore.records(MetricRecord.self, for: date, in: context)
        let record: MetricRecord?
        if let first = records.first {
            for extra in records.dropFirst() {
                context.delete(extra)
            }
            record = first
        } else {
            record = DayRecordStore.fetchOrCreate(MetricRecord.self, for: date, in: context) { metricRecord in
                metricRecord.values = NSDictionary()
            }
        }
        guard let record = record else { return }
        record.values = encode(values)
        DayRecordStore.save(context)
    }

    private func decode(_ value: NSObject?) -> [UUID: Double] {
        guard let dict = value as? NSDictionary else { return [:] }
        var result: [UUID: Double] = [:]
        dict.enumerateKeysAndObjects { key, value, _ in
            guard let stringKey = key as? String,
                  let id = UUID(uuidString: stringKey),
                  let number = value as? NSNumber else { return }
            result[id] = number.doubleValue
        }
        return result
    }

    private func encode(_ values: [UUID: Double]) -> NSDictionary {
        let mutable = NSMutableDictionary()
        for (id, value) in values {
            mutable[id.uuidString] = NSNumber(value: value)
        }
        return mutable
    }
}
