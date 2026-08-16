import CoreData
import XCTest
@testable import CalmTrack

final class TemplateCatalogTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        context = TestCoreData.makeInMemoryContext()
    }

    override func tearDownWithError() throws {
        context = nil
        try super.tearDownWithError()
    }

    func testKindAndUnitCountForCup() {
        let (kind, unit) = TemplateCatalog.kindAndUnit(for: "晨起温水一杯")
        XCTAssertEqual(kind, "count")
        XCTAssertEqual(unit, "杯")
    }

    func testKindAndUnitCheckForNonCup() {
        let (kind, unit) = TemplateCatalog.kindAndUnit(for: "饭后散步 10 分钟")
        XCTAssertEqual(kind, "check")
        XCTAssertNil(unit)
    }

    func testTemplateNamedFindsKnownAndUnknown() {
        XCTAssertNotNil(TemplateCatalog.template(named: "养胃 7 天"))
        XCTAssertNil(TemplateCatalog.template(named: "不存在的模板"))
    }

    func testApplyCreatesHabitsWithUnifiedKind() throws {
        let template = TemplateCatalog.template(named: "养胃 7 天")!
        TemplateCatalog.apply(template, in: context)

        let habits = try context.fetch(HabitItem.fetchRequest())
        XCTAssertFalse(habits.isEmpty)
        for habit in habits {
            if habit.title?.contains("杯") == true {
                XCTAssertEqual(habit.kind, "count")
                XCTAssertEqual(habit.unit, "杯")
            } else {
                XCTAssertEqual(habit.kind, "check")
            }
        }
    }

    func testApplyIsIdempotent() throws {
        let template = TemplateCatalog.template(named: "养胃 7 天")!
        TemplateCatalog.apply(template, in: context)
        TemplateCatalog.apply(template, in: context)

        let habits = try context.fetch(HabitItem.fetchRequest())
        let titles = habits.compactMap { $0.title }
        XCTAssertEqual(Set(titles).count, titles.count, "重复 apply 不应产生重复习惯")
    }
}
