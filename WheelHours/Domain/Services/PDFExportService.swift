import Foundation
import UIKit

/// Generates the printable DMV supervised-driving log PDF from a driver's profile
/// and their recorded drive logs.
///
/// This service is intentionally synchronous and side-effect free: given a
/// `DriverProfile` and an array of `DriveLog`s it returns raw PDF `Data`. It performs
/// no file I/O, no SwiftData fetches, and no UI presentation — callers (e.g. an
/// Export screen) are responsible for fetching the logs (sorted however they like),
/// invoking this function, and then sharing/saving/printing the resulting `Data`.
/// Being pure input -> output makes it straightforward to unit test without any
/// live UI or persistence stack.
enum PDFExportService {

    // MARK: - Page layout constants

    /// US Letter page size in points (72 points per inch): 8.5in x 11in.
    static let pageWidth: CGFloat = 612
    static let pageHeight: CGFloat = 792

    private static let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    private static let margin: CGFloat = 36
    private static let contentWidth: CGFloat = pageWidth - margin * 2

    private static let tableHeaderRowHeight: CGFloat = 22
    private static let tableRowHeight: CGFloat = 46

    /// Column widths, left to right. Must sum to `contentWidth` (540pt).
    /// Date, Start Time, End Time, Total Minutes, Night Minutes, Road Conditions,
    /// Supervisor Name, Supervisor Signature (image).
    private static let columnWidths: [CGFloat] = [60, 55, 55, 50, 50, 100, 80, 90]
    private static let columnTitles: [String] = [
        "Date", "Start", "End", "Total\nMin", "Night\nMin", "Road Conditions", "Supervisor", "Signature"
    ]

    // MARK: - Public API

    /// Generates the DMV log PDF for the given driver and drive logs.
    ///
    /// - Parameters:
    ///   - driverProfile: The driver whose name/target state appear in the header.
    ///   - driveLogs: The drive log rows to render, in the order supplied. Callers
    ///     should pre-sort these (e.g. chronologically) — this function renders rows
    ///     in the given order without re-sorting them. Table pagination is handled
    ///     automatically: long lists spill onto additional pages, each with its own
    ///     repeated column header row.
    /// - Returns: PDF file data starting with the `%PDF` magic bytes. Always
    ///   produces valid, parseable PDF data — including for an empty `driveLogs`
    ///   array, which renders a single page with a "no drives" placeholder row.
    static func generatePDF(driverProfile: DriverProfile, driveLogs: [DriveLog]) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "DriveTrack Supervised Driving Log",
            kCGPDFContextAuthor as String: driverProfile.name
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            var cursorY: CGFloat = margin

            func beginNewPage(drawHeader: Bool) {
                context.beginPage()
                cursorY = margin
                if drawHeader {
                    drawHeaderBlock(driverProfile: driverProfile, at: &cursorY)
                }
                drawTableHeaderRow(at: &cursorY)
            }

            beginNewPage(drawHeader: true)

            if driveLogs.isEmpty {
                drawEmptyStateRow(at: &cursorY)
            } else {
                for driveLog in driveLogs {
                    if cursorY + tableRowHeight > pageHeight - margin {
                        beginNewPage(drawHeader: false)
                    }
                    drawRow(for: driveLog, at: &cursorY)
                }
            }
        }
    }

    // MARK: - Drawing: header

    private static func drawHeaderBlock(driverProfile: DriverProfile, at cursorY: inout CGFloat) {
        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let subtitleFont = UIFont.systemFont(ofSize: 12)

        drawText(
            "Supervised Driving Log",
            in: CGRect(x: margin, y: cursorY, width: contentWidth, height: 24),
            font: titleFont
        )
        cursorY += 26

        let driverLine = "Driver: \(driverProfile.name)      Target State: \(driverProfile.targetStateCode)"
        drawText(
            driverLine,
            in: CGRect(x: margin, y: cursorY, width: contentWidth, height: 18),
            font: subtitleFont
        )
        cursorY += 20

        let generatedLine = "Generated: \(headerDateFormatter.string(from: Date()))"
        drawText(
            generatedLine,
            in: CGRect(x: margin, y: cursorY, width: contentWidth, height: 16),
            font: subtitleFont,
            color: .darkGray
        )
        cursorY += 24
    }

    // MARK: - Drawing: table

    private static func drawTableHeaderRow(at cursorY: inout CGFloat) {
        let rowRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: tableHeaderRowHeight)
        UIColor(white: 0.85, alpha: 1).setFill()
        UIBezierPath(rect: rowRect).fill()

        let font = UIFont.boldSystemFont(ofSize: 9)
        var x = margin
        for (index, width) in columnWidths.enumerated() {
            let cellRect = CGRect(x: x, y: cursorY, width: width, height: tableHeaderRowHeight)
                .insetBy(dx: 2, dy: 2)
            drawText(columnTitles[index], in: cellRect, font: font, alignment: .center)
            x += width
        }

        drawRowBorders(y: cursorY, height: tableHeaderRowHeight)
        cursorY += tableHeaderRowHeight
    }

    private static func drawRow(for driveLog: DriveLog, at cursorY: inout CGFloat) {
        let rowTop = cursorY
        let font = UIFont.systemFont(ofSize: 8)

        let textValues: [String] = [
            dateFormatter.string(from: driveLog.startTime),
            timeFormatter.string(from: driveLog.startTime),
            timeFormatter.string(from: driveLog.endTime),
            "\(driveLog.totalDurationMinutes)",
            "\(driveLog.nightDurationMinutes)",
            driveLog.roadConditions.map(\.displayName).joined(separator: ", "),
            driveLog.supervisor?.name ?? "—"
        ]

        var x = margin
        for (index, width) in columnWidths.enumerated() {
            let cellRect = CGRect(x: x, y: rowTop, width: width, height: tableRowHeight).insetBy(dx: 3, dy: 3)
            if index < textValues.count {
                let alignment: NSTextAlignment = (index == 5) ? .left : .center
                drawText(textValues[index], in: cellRect, font: font, alignment: alignment)
            } else {
                // Last column: supervisor signature image, if one has been captured.
                drawSignature(for: driveLog, in: cellRect)
            }
            x += width
        }

        drawRowBorders(y: rowTop, height: tableRowHeight)
        cursorY += tableRowHeight
    }

    private static func drawEmptyStateRow(at cursorY: inout CGFloat) {
        let rowRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: tableRowHeight)
        drawText(
            "No supervised drives recorded yet.",
            in: rowRect.insetBy(dx: 4, dy: 4),
            font: .italicSystemFont(ofSize: 10),
            color: .darkGray,
            alignment: .center
        )
        drawRowBorders(y: cursorY, height: tableRowHeight)
        cursorY += tableRowHeight
    }

    private static func drawSignature(for driveLog: DriveLog, in rect: CGRect) {
        // If no signature has been captured yet, leave the cell blank. Prompting
        // the user to collect a missing signature before export is the Export
        // screen's responsibility, not this service's.
        guard let data = driveLog.supervisor?.signatureData, let image = UIImage(data: data) else {
            return
        }
        image.draw(in: aspectFitRect(for: image.size, in: rect))
    }

    // MARK: - Low-level drawing helpers

    private static func drawRowBorders(y: CGFloat, height: CGFloat) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.gray.cgColor)
        ctx.setLineWidth(0.5)

        // Top and bottom horizontal rules.
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        ctx.move(to: CGPoint(x: margin, y: y + height))
        ctx.addLine(to: CGPoint(x: margin + contentWidth, y: y + height))

        // Vertical column separators (including the leading and trailing edges).
        var x = margin
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x, y: y + height))
        for width in columnWidths {
            x += width
            ctx.move(to: CGPoint(x: x, y: y))
            ctx.addLine(to: CGPoint(x: x, y: y + height))
        }

        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor = .black,
        alignment: NSTextAlignment = .left
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private static func aspectFitRect(for size: CGSize, in bounds: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return bounds }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let scaledWidth = size.width * scale
        let scaledHeight = size.height * scale
        return CGRect(
            x: bounds.midX - scaledWidth / 2,
            y: bounds.midY - scaledHeight / 2,
            width: scaledWidth,
            height: scaledHeight
        )
    }

    // MARK: - Formatters

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
