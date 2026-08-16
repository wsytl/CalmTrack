import CoreData
import XCTest
@testable import CalmTrack

final class DayRecordStoreTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        context = TestCoreData.makeInMemoryContext()
    }

    override func tearDownWithError() throws {
        context = nil
        try super.tearDownWithError()
    }

    func testExistingDoesNotCreate() throws {
        let day = TestCoreData.day(2026, 8, 16)
        XCTAssertNil(DayRecordStore.existing(HabitRecord.self, for: day, in: context))

        let count = try context.count(for: HabitRecord.fetchRequest())
        XCTAssertEqual(count, 0)
    }

    func testFetchOrCreateReusesSameObjectForSameDay() {
        let day = TestCoreData.day(2026, 8, 16)
        let first = DayRecordStore.fetchOrCreate(HabitRecord.self, for: day, in: context) { $0.completedIDs = NSArray() }
        let second = DayRecordStore.fetchOrCreate(HabitRecord.self, for: day, in: context) { $0.completedIDs = NSArray() }

        XCTAssertEqual(first?.objectID, second?.objectID)
    }

    func testFetchOrCreateNormalizesDateToDayStart() {
        let raw = TestCoreData.day(2026, 8, 16).addingTimeInterval(12 * 3600)
        let record = DayRecordStore.fetchOrCreate(HabitRecord.self, for: raw, in: context) { $0.completedIDs = NSArray() }

        XCTAssertEqual(record?.date, Optional(TestCoreData.day(2026, 8, 16)))
    }

    func testRecordsReturnsAllRecordsForSameDay() {
        let day = TestCoreData.day(2026, 8, 16)
        for _ in 0..<2 {
            let record = HabitRecord(context: context)
            record.id = UUID()
            record.date = day
            record.completedIDs = NSArray()
            record.progressValues = NSDictionary()
        }

        let records = DayRecordStore.records(HabitRecord.self, for: day, in: context)
        XCTAssertEqual(records.count, 2)
        let keys = records.map { DayRecordStore.stableKey($0) }
        XCTAssertEqual(keys, keys.sorted(), "同一天多条记录应按 stableKey 稳定排序")
    }
}
