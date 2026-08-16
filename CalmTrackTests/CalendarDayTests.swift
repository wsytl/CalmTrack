import XCTest
@testable import CalmTrack

final class CalendarDayTests: XCTestCase {

    func testCalendarDayStartIsMidnightOfSameDay() {
        let noon = TestCoreData.day(2026, 8, 16).addingTimeInterval(12 * 3600)
        let start = noon.calendarDayStart

        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: start)
        XCTAssertEqual(comps.hour, 0)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.second, 0)
        XCTAssertTrue(Calendar.current.isDate(noon, inSameDayAs: start))
    }

    func testCalendarDayStartIdempotent() {
        let start = TestCoreData.day(2026, 8, 16).calendarDayStart
        XCTAssertEqual(start.calendarDayStart, start)
    }

    func testLateNightBelongsToNextDayBoundary() {
        let lateNight = TestCoreData.day(2026, 8, 16).addingTimeInterval(23 * 3600 + 59 * 60)
        // 独立期望：Foundation 标准 API startOfDay（非被测代码路径）
        XCTAssertEqual(lateNight.calendarDayStart, Calendar.current.startOfDay(for: lateNight))
    }
}
