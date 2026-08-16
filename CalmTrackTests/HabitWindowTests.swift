import CoreData
import XCTest
@testable import CalmTrack

final class HabitWindowTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        context = TestCoreData.makeInMemoryContext()
    }

    override func tearDownWithError() throws {
        context = nil
        try super.tearDownWithError()
    }

    @discardableResult
    private func makeRecord(on day: Date, completed ids: [UUID] = []) -> HabitRecord {
        let record = HabitRecord(context: context)
        record.id = UUID()
        record.date = day.calendarDayStart
        record.completedIDs = ids.map { NSUUID(uuidString: $0.uuidString)! } as NSArray
        record.progressValues = NSDictionary()
        return record
    }

    // MARK: - inMonthOf

    func testMonthWindowKeepsOnlyRecordsInsideTheMonth() {
        makeRecord(on: TestCoreData.day(2026, 7, 31), completed: [UUID()])
        makeRecord(on: TestCoreData.day(2026, 8, 1), completed: [UUID()])
        makeRecord(on: TestCoreData.day(2026, 8, 15), completed: [UUID()])
        makeRecord(on: TestCoreData.day(2026, 9, 1), completed: [UUID()])

        let byDay = HabitService.shared.completedIDsByDay(
            from: Array(try! context.fetch(HabitRecord.fetchRequest())),
            inMonthOf: TestCoreData.day(2026, 8, 10)
        )

        XCTAssertEqual(byDay.keys.sorted(), [
            TestCoreData.day(2026, 8, 1),
            TestCoreData.day(2026, 8, 15),
        ])
    }

    func testMonthWindowEmptyMonthReturnsEmptyDict() {
        makeRecord(on: TestCoreData.day(2026, 7, 31))

        let byDay = HabitService.shared.completedIDsByDay(
            from: Array(try! context.fetch(HabitRecord.fetchRequest())),
            inMonthOf: TestCoreData.day(2026, 8, 1)
        )

        XCTAssertTrue(byDay.isEmpty)
    }

    func testMonthWindowUnionsMultipleRecordsOnSameDay() {
        let idA = UUID()
        let idB = UUID()
        makeRecord(on: TestCoreData.day(2026, 8, 5), completed: [idA])
        makeRecord(on: TestCoreData.day(2026, 8, 5), completed: [idB])

        let byDay = HabitService.shared.completedIDsByDay(
            from: Array(try! context.fetch(HabitRecord.fetchRequest())),
            inMonthOf: TestCoreData.day(2026, 8, 1)
        )

        XCTAssertEqual(byDay[TestCoreData.day(2026, 8, 5)], Set([idA, idB]))
    }

    // MARK: - lastNDays

    func testLastNDaysIncludesTodayAndExcludesEdges() {
        makeRecord(on: TestCoreData.day(2026, 8, 9), completed: [UUID()])
        makeRecord(on: TestCoreData.day(2026, 8, 10), completed: [UUID()])
        makeRecord(on: TestCoreData.day(2026, 8, 16), completed: [UUID()])
        makeRecord(on: TestCoreData.day(2026, 8, 17), completed: [UUID()])

        let byDay = HabitService.shared.completedIDsByDay(
            from: Array(try! context.fetch(HabitRecord.fetchRequest())),
            lastNDays: 7,
            endingOn: TestCoreData.day(2026, 8, 16)
        )

        XCTAssertEqual(byDay.keys.sorted(), [
            TestCoreData.day(2026, 8, 10),
            TestCoreData.day(2026, 8, 16),
        ])
    }

    func testLastNDaysSingleDayWindow() {
        makeRecord(on: TestCoreData.day(2026, 8, 15))
        makeRecord(on: TestCoreData.day(2026, 8, 16), completed: [UUID()])

        let byDay = HabitService.shared.completedIDsByDay(
            from: Array(try! context.fetch(HabitRecord.fetchRequest())),
            lastNDays: 1,
            endingOn: TestCoreData.day(2026, 8, 16)
        )

        XCTAssertEqual(Array(byDay.keys), [TestCoreData.day(2026, 8, 16)])
    }
}
