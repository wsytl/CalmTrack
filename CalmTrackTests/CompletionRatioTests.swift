import XCTest
@testable import CalmTrack

final class CompletionRatioTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - completionRatio

    func testRatioEmptyHabitSetIsZero() {
        let ratio = HabitService.shared.completionRatio(
            habitIDs: [], completedByDay: [:], day: day(2026, 8, 16)
        )
        XCTAssertEqual(ratio, 0)
    }

    func testRatioFutureDayIsZero() {
        let habit = UUID()
        let ratio = HabitService.shared.completionRatio(
            habitIDs: [habit],
            completedByDay: [day(2026, 8, 16): [habit]],
            day: day(2026, 8, 16),
            isFuture: true
        )
        XCTAssertEqual(ratio, 0)
    }

    func testRatioPartialCompletion() {
        let a = UUID(), b = UUID()
        let ratio = HabitService.shared.completionRatio(
            habitIDs: [a, b],
            completedByDay: [day(2026, 8, 16): [a]],
            day: day(2026, 8, 16)
        )
        XCTAssertEqual(ratio, 0.5, accuracy: 0.0001)
    }

    func testRatioFullCompletion() {
        let a = UUID(), b = UUID()
        let ratio = HabitService.shared.completionRatio(
            habitIDs: [a, b],
            completedByDay: [day(2026, 8, 16): [a, b]],
            day: day(2026, 8, 16)
        )
        XCTAssertEqual(ratio, 1)
    }

    // MARK: - fullCompletionStreak

    func testStreakCountsFromTodayWhenTodayIsFull() {
        let a = UUID()
        let byDay: [Date: Set<UUID>] = [
            day(2026, 8, 16): [a], day(2026, 8, 15): [a], day(2026, 8, 14): [a],
        ]
        let streak = HabitService.shared.fullCompletionStreak(
            habitIDs: [a], completedByDay: byDay, calendar: calendar, today: day(2026, 8, 16)
        )
        XCTAssertEqual(streak, 3)
    }

    func testStreakStartsFromYesterdayWhenTodayIncomplete() {
        let a = UUID()
        let byDay: [Date: Set<UUID>] = [day(2026, 8, 15): [a], day(2026, 8, 14): [a]]
        let streak = HabitService.shared.fullCompletionStreak(
            habitIDs: [a], completedByDay: byDay, calendar: calendar, today: day(2026, 8, 16)
        )
        XCTAssertEqual(streak, 2)
    }

    func testStreakBreaksOnMissingDay() {
        let a = UUID()
        let byDay: [Date: Set<UUID>] = [day(2026, 8, 15): [a], day(2026, 8, 13): [a]]
        let streak = HabitService.shared.fullCompletionStreak(
            habitIDs: [a], completedByDay: byDay, calendar: calendar, today: day(2026, 8, 16)
        )
        XCTAssertEqual(streak, 1)
    }

    func testStreakEmptyHabitSetIsZero() {
        let streak = HabitService.shared.fullCompletionStreak(
            habitIDs: [], completedByDay: [:], calendar: calendar, today: day(2026, 8, 16)
        )
        XCTAssertEqual(streak, 0)
    }

    func testStreakRequiresAllCurrentHabitsPerDay() {
        let a = UUID(), b = UUID()
        let byDay: [Date: Set<UUID>] = [day(2026, 8, 16): [a, b]]
        let streak = HabitService.shared.fullCompletionStreak(
            habitIDs: [a, b], completedByDay: byDay, calendar: calendar, today: day(2026, 8, 16)
        )
        XCTAssertEqual(streak, 1)
    }
}
