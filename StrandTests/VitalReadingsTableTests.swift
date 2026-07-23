import XCTest
@testable import Strand

/// The readings table under a series-backed vital detail (task #8) — Swift twin of Android's
/// `VitalReadingsTableTest`. Pins the pure projection `vitalReadingRows` the MetricDetailView table
/// renders: rows and the "N readings" caption derive from the SAME windowed list (so their counts can't
/// disagree), rows are NEWEST-FIRST, each raw source id resolves through the shared
/// `TodayView.provenanceDisplayLabel` (strap → "Whoop", Health Connect → "Health Connect", Apple Health →
/// "Apple Health", the "-noop" sibling → "On-device"), and each value reuses the model's own formatter +
/// unit. Blood Oxygen (SpO2) is the acceptance case.
final class VitalReadingsTableTests: XCTestCase {

    private let strap = Repository.whoopSource                  // "my-whoop"
    private let healthConnect = Repository.healthConnectSource  // "health-connect"
    private let appleHealth = Repository.appleHealthSource      // "apple-health"

    /// A fixed "now" long after the sample January-2026 readings, so none resolve as Today/Yesterday.
    private let now = ISO8601DateFormatter().date(from: "2026-07-09T00:00:00Z")!

    /// Blood Oxygen: %-formatted, ascending readings from three different sources — a strap reading, a
    /// Health Connect import (e.g. a Galaxy Watch), and an Apple Health import.
    private func spo2Readings() -> [VitalReading] {
        [
            VitalReading(day: "2026-01-01", value: 96, source: strap),
            VitalReading(day: "2026-01-02", value: 95, source: healthConnect),
            VitalReading(day: "2026-01-03", value: 97, source: appleHealth),
        ]
    }
    private func spo2Format(_ v: Double) -> String { "\(String(format: "%.0f", v)) %" }

    func testRowCountEqualsReadingsCount() {
        let rows = vitalReadingRows(readings: spo2Readings(), strapDeviceId: strap,
                                    now: now, format: spo2Format)
        XCTAssertEqual(rows.count, spo2Readings().count)
    }

    func testRowsAreNewestFirst() {
        let rows = vitalReadingRows(readings: spo2Readings(), strapDeviceId: strap,
                                    now: now, format: spo2Format)
        // Ascending input (01 → 03) must render descending (03 → 01).
        // Date order is localized ("3 Jan" in many locales, "Jan 3" in US English), so pin the
        // descending day numbers without hard-coding one locale's word order.
        XCTAssertEqual(rows.map { $0.time.filter(\.isNumber) }, ["3", "2", "1"])
        XCTAssertEqual(rows.first?.value, "97 %")   // the newest reading leads
    }

    func testSourceLabelsResolvePerSample() {
        let rows = vitalReadingRows(readings: spo2Readings(), strapDeviceId: strap,
                                    now: now, format: spo2Format)
        // Newest-first, so: Apple Health (03), Health Connect (02), Whoop strap (01).
        XCTAssertEqual(rows.map(\.source), ["Apple Health", "Health Connect", "Whoop"])
    }

    func testComputedStrapSiblingReadsOnDevice() {
        let rows = vitalReadingRows(
            readings: [VitalReading(day: "2026-01-04", value: 55, source: strap + "-noop")],
            strapDeviceId: strap, now: now, format: { "\(String(format: "%.0f", $0)) yrs" }
        )
        XCTAssertEqual(rows.first?.source, "On-device")
    }

    func testValueReusesModelFormatAndUnit() {
        // The row value is the model's complete formatter output — including its unit —
        // 41.7 ms formats (%.0f) to "42 ms".
        let rows = vitalReadingRows(
            readings: [VitalReading(day: "2026-01-01", value: 41.7, source: strap)],
            strapDeviceId: strap, now: now, format: { "\(String(format: "%.0f", $0)) ms" }
        )
        XCTAssertEqual(rows.first?.value, "42 ms")
    }

    func testTemperatureFormatterDoesNotDuplicateUnit() {
        let rows = vitalReadingRows(
            readings: [VitalReading(day: "2026-01-01", value: 1.2, source: strap + "-noop")],
            strapDeviceId: strap, now: now, format: { _ in "+1.2°C" }
        )
        XCTAssertEqual(rows.first?.value, "+1.2°C")
    }

    func testUnitlessMetricLeavesNoTrailingSpace() {
        // Vitality has an empty unit; the value must not carry a dangling space.
        let rows = vitalReadingRows(
            readings: [VitalReading(day: "2026-01-01", value: 72, source: strap + "-noop")],
            strapDeviceId: strap, now: now, format: { String(format: "%.0f", $0) }
        )
        XCTAssertEqual(rows.first?.value, "72")
    }
}
