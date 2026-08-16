import CoreData
import XCTest
@testable import CalmTrack

final class MetricServiceTests: XCTestCase {

    private var context: NSManagedObjectContext!
    private var service: MetricService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        context = TestCoreData.makeInMemoryContext()
        service = MetricService.shared
    }

    override func tearDownWithError() throws {
        context = nil
        service = nil
        try super.tearDownWithError()
    }

    private func insertDuplicateRecord(day: Date, values: [UUID: Double]) -> MetricRecord {
        let record = MetricRecord(context: context)
        record.id = UUID()
        record.date = day.calendarDayStart
        let dict = NSMutableDictionary()
        for (id, value) in values {
            dict[id.uuidString] = NSNumber(value: value)
        }
        record.values = dict
        return record
    }

    func testReadDoesNotCreateRecord() throws {
        let values = service.values(for: TestCoreData.day(2026, 8, 16), in: context)
        XCTAssertTrue(values.isEmpty)

        let count = try context.count(for: MetricRecord.fetchRequest())
        XCTAssertEqual(count, 0)
    }

    func testSetValuesThenReadBack() {
        let metricID = UUID()
        let day = TestCoreData.day(2026, 8, 16)

        service.setValues([metricID: 4], for: day, in: context)

        let values = service.values(for: day, in: context)
        XCTAssertEqual(values[metricID], 4)
    }

    func testValuesFromMergesDuplicateRecordsLaterWins() {
        let id = UUID()
        let day = TestCoreData.day(2026, 8, 16)
        insertDuplicateRecord(day: day, values: [id: 1])
        insertDuplicateRecord(day: day, values: [id: 5])

        let values = service.values(from: Array(try! context.fetch(MetricRecord.fetchRequest())))

        XCTAssertEqual(values[id], 5)
    }

    func testSetValuesHealsDuplicateDayRecords() throws {
        let id = UUID()
        let day = TestCoreData.day(2026, 8, 16)
        insertDuplicateRecord(day: day, values: [id: 1])
        insertDuplicateRecord(day: day, values: [id: 5])

        service.setValues([id: 3], for: day, in: context)

        let remaining = try context.fetch(MetricRecord.fetchRequest())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(service.values(from: remaining)[id], 3)
    }
}
