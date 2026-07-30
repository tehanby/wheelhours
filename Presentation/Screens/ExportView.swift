import SwiftUI
import SwiftData
import PDFKit
import UIKit

/// The DMV supervised-driving-log export screen: pick which drives to include,
/// preview the generated PDF live, collect any missing supervisor signatures,
/// and hand the final PDF to the system share sheet (Print/AirDrop/Save to
/// Files/etc).
///
/// ### Wiring this screen up
/// A parent screen presents `ExportView` like:
/// ```swift
/// @Environment(\.modelContext) private var modelContext
/// // ... plus a single shared StoreKitService owned higher up (e.g. at the
/// // app root) so its StoreKit transaction listener isn't spun up repeatedly.
///
/// ExportView(driverProfile: driverProfile, modelContext: modelContext, storeKitService: sharedStoreKitService)
/// ```
///
/// `modelContext` is taken as an explicit init parameter (rather than read from
/// `@Environment` internally) because this view's `@StateObject private var
/// viewModel` needs a `ModelContext` at construction time, and `@Environment`
/// values aren't populated until after a view's `init` runs — so the
/// environment can't be read inside a `@StateObject`'s initial-value closure.
/// `@Query` below still reads the environment's context normally for fetching,
/// since it doesn't have that same initialization-order constraint.
@available(iOS 15, *)
struct ExportView: View {
    @StateObject private var viewModel: ExportViewModel

    /// All persisted drives, oldest first — the same chronological order the
    /// PDF renders rows in.
    @Query(sort: \DriveLog.startTime, order: .forward) private var allDriveLogs: [DriveLog]

    @State private var exportScope: ExportScope = .all
    @State private var rangeStart: Date
    @State private var rangeEnd: Date = Date()
    @State private var selectedLogIDs: Set<UUID> = []

    @State private var showPaywall = false

    @State private var signatureQueue: [Supervisor] = []
    @State private var currentSignatureSupervisor: Supervisor?

    @State private var isPresentingShareSheet = false
    @State private var shareFileURL: URL?

    @State private var exportErrorMessage: String?

    /// - Parameters:
    ///   - driverProfile: The driver whose profile/name is rendered in the PDF header.
    ///   - modelContext: The SwiftData context to save captured signatures into.
    ///     Pass the same context the rest of the app uses (e.g. `\.modelContext`
    ///     read by the parent).
    ///   - storeKitService: The app's shared `StoreKitService` instance. Defaults
    ///     to a fresh instance for previews/standalone use, but production call
    ///     sites should pass a single instance owned higher up (e.g. at the app
    ///     root) rather than relying on the default, since each `StoreKitService`
    ///     starts its own long-running `Transaction.updates` listener.
    ///   - freemiumGateService: The free-tier gating rule. Defaults to the
    ///     standard 5-free-drives configuration.
    init(
        driverProfile: DriverProfile,
        modelContext: ModelContext,
        storeKitService: StoreKitService = StoreKitService(),
        freemiumGateService: FreemiumGateService = FreemiumGateService()
    ) {
        _viewModel = StateObject(wrappedValue: ExportViewModel(
            driverProfile: driverProfile,
            modelContext: modelContext,
            freemiumGateService: freemiumGateService,
            storeKitService: storeKitService
        ))
        _rangeStart = State(initialValue: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date())
    }

    private enum ExportScope: String, CaseIterable, Identifiable {
        case all = "All Drives"
        case dateRange = "Date Range"
        case manualSelection = "Choose Drives"

        var id: String { rawValue }
    }

    /// The drives that will actually be included in the generated PDF, given
    /// the current scope selection.
    private var exportDriveLogs: [DriveLog] {
        switch exportScope {
        case .all:
            return allDriveLogs
        case .dateRange:
            return allDriveLogs.filter { $0.startTime >= rangeStart && $0.startTime <= rangeEnd }
        case .manualSelection:
            return allDriveLogs.filter { selectedLogIDs.contains($0.id) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scopePicker

                if exportScope == .dateRange {
                    dateRangeControls
                }
                if exportScope == .manualSelection {
                    driveSelectionList
                }

                Divider()

                previewSection
            }
            .navigationTitle("Export Drive Log")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") { beginExportFlow() }
                        .disabled(exportDriveLogs.isEmpty || viewModel.isCheckingEntitlement)
                }
            }
            .task {
                await viewModel.refreshEntitlement()
            }
            .task(id: exportDriveLogs) {
                viewModel.generatePreview(driveLogs: exportDriveLogs)
            }
            .onAppear {
                if selectedLogIDs.isEmpty {
                    selectedLogIDs = Set(allDriveLogs.map(\.id))
                }
            }
            .onChange(of: allDriveLogs) { _, newLogs in
                // Keep newly-logged drives selected by default in manual mode,
                // rather than silently excluding them from export.
                selectedLogIDs.formUnion(newLogs.map(\.id))
            }
            .sheet(isPresented: $showPaywall, onDismiss: {
                Task { await viewModel.refreshEntitlement() }
            }) {
                PaywallView(storeKitService: viewModel.storeKitService, onDismiss: { showPaywall = false })
            }
            .sheet(item: $currentSignatureSupervisor) { supervisor in
                SignatureCaptureView(
                    onSave: { data in handleSignatureSaved(data, for: supervisor) },
                    onCancel: { cancelSignatureQueue() }
                )
            }
            .sheet(isPresented: $isPresentingShareSheet, onDismiss: {
                // The PDF temp file (minor's name/signature/drive history) has
                // served its purpose once the share sheet closes — delete it
                // immediately rather than leaving it in temp storage.
                viewModel.deleteTempFile(at: shareFileURL)
                shareFileURL = nil
            }) {
                if let shareFileURL {
                    ActivityShareSheet(activityItems: [shareFileURL])
                }
            }
            .alert("Export Failed", isPresented: exportErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "Something went wrong while preparing the PDF.")
            }
        }
    }

    // MARK: - Subviews

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Export Scope", selection: $exportScope) {
                ForEach(ExportScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if !viewModel.isUnlocked && !viewModel.isCheckingEntitlement {
                let remaining = viewModel.remainingFreeDriveCount(loggedDriveCount: allDriveLogs.count)
                Text("\(remaining) free drive export\(remaining == 1 ? "" : "s") remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var dateRangeControls: some View {
        VStack(spacing: 8) {
            DatePicker("From", selection: $rangeStart, displayedComponents: .date)
            DatePicker("To", selection: $rangeEnd, displayedComponents: .date)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var driveSelectionList: some View {
        List(allDriveLogs) { log in
            Button {
                toggleSelection(for: log)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.startTime, style: .date)
                            .font(.body)
                        Text(log.startTime, style: .time) + Text(" – ") + Text(log.endTime, style: .time)
                    }
                    .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: selectedLogIDs.contains(log.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedLogIDs.contains(log.id) ? Color.accentColor : Color.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxHeight: 260)
        .listStyle(.plain)
    }

    private var previewSection: some View {
        Group {
            if exportDriveLogs.isEmpty {
                emptySelectionPlaceholder
            } else {
                PDFPreviewView(data: viewModel.pdfData)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptySelectionPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Drives Selected")
                .font(.headline)
            Text("Choose at least one drive to preview and export the PDF.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Actions

    private func toggleSelection(for log: DriveLog) {
        if selectedLogIDs.contains(log.id) {
            selectedLogIDs.remove(log.id)
        } else {
            selectedLogIDs.insert(log.id)
        }
    }

    private func beginExportFlow() {
        exportErrorMessage = nil

        guard viewModel.canExport(loggedDriveCount: allDriveLogs.count) else {
            showPaywall = true
            return
        }

        let missingSignatures = viewModel.supervisorsMissingSignature(in: exportDriveLogs)
        guard !missingSignatures.isEmpty else {
            performExport()
            return
        }

        signatureQueue = missingSignatures
        advanceSignatureQueue()
    }

    private func advanceSignatureQueue() {
        guard !signatureQueue.isEmpty else {
            performExport()
            return
        }
        currentSignatureSupervisor = signatureQueue.removeFirst()
    }

    private func handleSignatureSaved(_ data: Data, for supervisor: Supervisor) {
        viewModel.saveSignature(data, for: supervisor)
        currentSignatureSupervisor = nil
        // A brief delay before presenting the next signature sheet avoids a
        // known SwiftUI quirk where setting a `.sheet(item:)` binding back to
        // non-nil in the same run-loop turn it was set to nil can fail to
        // re-present the sheet.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            advanceSignatureQueue()
        }
    }

    private func cancelSignatureQueue() {
        currentSignatureSupervisor = nil
        signatureQueue = []
    }

    private func performExport() {
        guard let url = viewModel.writePDFToTempFile(driveLogs: exportDriveLogs) else {
            exportErrorMessage = "Could not prepare the PDF file for sharing."
            return
        }
        shareFileURL = url
        isPresentingShareSheet = true
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in if !isPresented { exportErrorMessage = nil } }
        )
    }
}

// MARK: - PDF preview

/// Renders in-memory PDF `Data` using `PDFKit`'s `PDFView`. Kept private to
/// this file since it's export-preview-specific rather than a general-purpose
/// component.
private struct PDFPreviewView: UIViewRepresentable {
    let data: Data

    func makeCoordinator() -> Coordinator {
        Coordinator(lastRenderedData: data)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Guard against reparsing/redrawing on every unrelated SwiftUI update
        // pass — only reload the document when the underlying bytes actually
        // changed since the last time we set it.
        guard context.coordinator.lastRenderedData != data else { return }
        context.coordinator.lastRenderedData = data
        pdfView.document = PDFDocument(data: data)
    }

    final class Coordinator {
        var lastRenderedData: Data
        init(lastRenderedData: Data) {
            self.lastRenderedData = lastRenderedData
        }
    }
}

// MARK: - Share sheet

/// Wraps `UIActivityViewController` so the export flow can offer the standard
/// Print/AirDrop/Save to Files/Mail/etc. activities for the generated PDF.
///
/// `UIActivityViewController` (rather than the newer `ShareLink`) is used here
/// deliberately: it's the well-established, most configurable API for this
/// job — explicit control over `applicationActivities`/`excludedActivityTypes`,
/// a completion handler if we ever want to know which activity the user
/// picked, and straightforward iPad popover anchoring — none of which
/// `ShareLink` exposes as directly. Since we already need a file URL (see
/// `writePDFToTempFile`) rather than raw `Data` for PDFs to show up correctly
/// named/typed in Print and Save-to-Files, wrapping `UIActivityViewController`
/// is no extra cost over adopting `ShareLink`.
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No dynamic updates needed after presentation.
    }
}
