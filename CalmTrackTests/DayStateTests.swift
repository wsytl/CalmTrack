import CoreData
import XCTest
@testable import CalmTrack

final class DayStateTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        context = TestCoreData.makeInMemoryContext()
    }

    override func tearDownWithError() throws {
        context = nil
        try super.tearDownWithError()
    }

    private func makeRecord(
        day: Date,
        completedIDs: [UUID] = [],
        progress: [UUID: Double] = [:]
    ) -> HabitRecord {
        let record = HabitRecord(context: context)
        record.id = UUID()
        record.date = day.calendarDayStart
        record.completedIDs = completedIDs.map { NSUUID(uuidString: $0.uuidString)! } as NSArray
        let dict = NSMutableDictionary()
        for (id, value) in progress {
            dict[id.uuidString] = NSNumber(value: value)
        }
        record.progressValues = dict
        return record
    }

    func testEmptyRecordsYieldEmptyState() {
        let state = HabitService.shared.dayState(from: [])
        XCTAssertTrue(state.completedIDs.isEmpty)
        XCTAssertTrue(state.progress.isEmpty)
    }

    func testDecodesCompletedIDsAndProgress() {
        let id = UUID()
        let record = makeRecord(day: TestCoreData.day(2026, 8, 16), completedIDs: [id], progress: [id: 3])

        let state = HabitService.shared.dayState(from: [record])

        XCTAssertEqual(state.completedIDs, Set([id]))
        XCTAssertEqual(state.progress[id], 3)
    }

    func testMergesRecordsWithUnionAndLaterWins() {
        let a = UUID(), b = UUID()
        let first = makeRecord(day: TestCoreData.day(2026, 8, 16), completedIDs: [a], progress: [a: 1])
        let second = makeRecord(day: TestCoreData.day(2026, 8, 16), completedIDs: [b], progress: [a: 5, b: 2])

        let state = HabitService.shared.dayState(from: [first, second])

        XCTAssertEqual(state.completedIDs, Set([a, b]))
        XCTAssertEqual(state.progress[a], 5)
        XCTAssertEqual(state.progress[b], 2)
    }

    func testIgnoresMalformedBlobs() {
        let record = makeRecord(day: TestCoreData.day(2026, 8, 16))
        // 类型合法但内容非法：数组里是非 UUID，字典里是非法 key/value。
        record.completedIDs = NSArray(object: "not-a-uuid")
        record.progressValues = NSDictionary(object: "not-a-number", forKey: "not-a-uuid" as NSString)

        let state = HabitService.shared.dayState(from: [record])

        XCTAssertTrue(state.completedIDs.isEmpty)
        XCTAssertTrue(state.progress.isEmpty)
    }
}
