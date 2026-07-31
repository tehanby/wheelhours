import XCTest
import PDFKit
import UIKit
@testable import DriveTrack

final class PDFExportServiceTests: XCTestCase {

    // MARK: - Fixtures

    private func makeDriverProfile() -> DriverProfile {
        DriverProfile(
            name: "Jamie Rivera",
            targetStateCode: "CA",
            permitIssueDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makeDriveLog(
        hoursAgo: Double = 1,
        supervisor: Supervisor? = nil
    ) -> DriveLog {
        let start = Date(timeIntervalSince1970: 1_700_000_000 + hoursAgo * 3600)
        let end = start.addingTimeInterval(45 * 60)
        return DriveLog(
            startTime: start,
            endTime: end,
            totalDurationMinutes: 45,
            nightDurationMinutes: 10,
            dayDurationMinutes: 35,
            roadConditions: [.city, .highway],
            supervisor: supervisor,
            notes: "Practice drive"
        )
    }

    // MARK: - Basic generation

    func testGeneratesNonEmptyData() {
        let profile = makeDriverProfile()
        let supervisor = Supervisor(name: "Pat Rivera", relationship: "Parent")
        let logs = [
            makeDriveLog(hoursAgo: 1, supervisor: supervisor),
            makeDriveLog(hoursAgo: 2, supervisor: supervisor)
        ]

        let data = PDFExportService.generatePDF(driverProfile: profile, driveLogs: logs)

        XCTAssertFalse(data.isEmpty)
    }

    func testDataStartsWithPDFMagicBytes() {
        let profile = makeDriverProfile()
        let logs = [makeDriveLog()]

        let data = PDFExportService.generatePDF(driverProfile: profile, driveLogs: logs)

        let magicBytes = Array(data.prefix(4))
        let expectedMagicBytes = Array("%PDF".utf8)
        XCTAssertEqual(magicBytes, expectedMagicBytes)
    }

    // MARK: - PDFKit round-trip

    func testParsesBackWithPDFKitAndMatchesPageSize() {
        let profile = makeDriverProfile()
        let logs = [makeDriveLog()]

        let data = PDFExportService.generatePDF(driverProfile: profile, driveLogs: logs)

        guard let document = PDFDocument(data: data) else {
            XCTFail("Expected PDFDocument to parse generated data")
            return
        }
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)

        guard let page = document.page(at: 0) else {
            XCTFail("Expected at least one page")
            return
        }

        let bounds = page.bounds(for: .mediaBox)
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
        XCTAssertEqual(Double(bounds.width), Double(PDFExportService.pageWidth), accuracy: 0.5)
        XCTAssertEqual(Double(bounds.height), Double(PDFExportService.pageHeight), accuracy: 0.5)
    }

    // MARK: - Edge cases

    func testZeroDriveLogsStillProducesValidPDF() {
        let profile = makeDriverProfile()

        let data = PDFExportService.generatePDF(driverProfile: profile, driveLogs: [])

        XCTAssertFalse(data.isEmpty)
        let document = PDFDocument(data: data)
        XCTAssertNotNil(document)
        XCTAssertEqual(document?.pageCount, 1)
    }

    func testLargeLogListPaginatesAcrossMultiplePages() {
        let profile = makeDriverProfile()
        let supervisor = Supervisor(name: "Pat Rivera", relationship: "Parent")
        let logs = (0..<60).map { makeDriveLog(hoursAgo: Double($0), supervisor: supervisor) }

        let data = PDFExportService.generatePDF(driverProfile: profile, driveLogs: logs)

        guard let document = PDFDocument(data: data) else {
            XCTFail("Expected PDFDocument to parse generated data")
            return
        }
        XCTAssertGreaterThan(document.pageCount, 1)
    }

    // MARK: - Signature rendering

    func testSignatureImageIsRenderedWithoutCrashing() {
        let profile = makeDriverProfile()

        let signatureImage = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 40)).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 40))
        }
        guard let signatureData = signatureImage.pngData() else {
            XCTFail("Failed to create sample signature PNG")
            return
        }

        let supervisor = Supervisor(name: "Pat Rivera", relationship: "Parent", signatureData: signatureData)
        let logs = [makeDriveLog(supervisor: supervisor)]

        let data = PDFExportService.generatePDF(driverProfile: profile, driveLogs: logs)

        XCTAssertFalse(data.isEmpty)
        XCTAssertNotNil(PDFDocument(data: data))
    }

    func testMissingSignatureLeavesCellBlankWithoutCrashing() {
        let profile = makeDriverProfile()
        let supervisorWithoutSignature = Supervisor(name: "Pat Rivera", relationship: "Parent")
        let logs = [makeDriveLog(supervisor: supervisorWithoutSignature)]

        let data = PDFExportService.generatePDF(driverProfile: profile, driveLogs: logs)

        XCTAssertFalse(data.isEmpty)
        XCTAssertNotNil(PDFDocument(data: data))
    }
}
