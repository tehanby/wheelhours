import SwiftUI
import UIKit

/// A SwiftUI view that lets a supervisor draw a freehand signature and captures it
/// as a fixed-size PNG image.
///
/// Drawing is implemented with a plain `DragGesture` accumulating `[CGPoint]`
/// strokes, rendered live with `Canvas`. This is more portable than requiring
/// PencilKit (works in any SwiftUI deployment target, simulator, or finger-only
/// device) at the cost of pressure/tilt sensitivity. If richer pen input is wanted
/// later, `PKCanvasView` wrapped in a `UIViewRepresentable` is a drop-in alternative
/// drawing surface — it can keep the same `onSave(Data) -> Void` contract this view
/// exposes, so call sites (e.g. the Export screen) wouldn't need to change.
struct SignatureCaptureView: View {
    /// Fixed size of the rendered signature canvas and the exported PNG image, in
    /// points. Chosen to be wide enough for a natural signature while staying small
    /// as an embedded PDF table cell image.
    static let canvasSize = CGSize(width: 400, height: 150)

    /// Called with PNG-encoded signature image data when the user taps Save.
    /// Never called with an empty canvas — the Save button is disabled until at
    /// least one stroke has been drawn.
    var onSave: (Data) -> Void

    /// Optional callback for a Cancel action, e.g. to dismiss a presenting sheet
    /// without saving. If `nil`, no Cancel button is shown.
    var onCancel: (() -> Void)?

    @State private var completedStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []

    private var allStrokes: [[CGPoint]] {
        currentStroke.isEmpty ? completedStrokes : completedStrokes + [currentStroke]
    }

    private var hasContent: Bool {
        !completedStrokes.isEmpty || currentStroke.count > 1
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Sign below")
                .font(.headline)

            signatureCanvas
                .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
                .background(Color(white: 0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5))
                )
                .gesture(dragGesture)

            HStack {
                Button("Clear", role: .destructive) {
                    completedStrokes = []
                    currentStroke = []
                }
                .disabled(!hasContent)

                Spacer()

                if let onCancel {
                    Button("Cancel", action: onCancel)
                }

                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasContent)
            }
        }
        .padding()
    }

    private var signatureCanvas: some View {
        Canvas { context, _ in
            for stroke in allStrokes {
                context.stroke(path(for: stroke), with: .color(.black), style: strokeStyle)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                currentStroke.append(value.location)
            }
            .onEnded { _ in
                guard !currentStroke.isEmpty else { return }
                completedStrokes.append(currentStroke)
                currentStroke = []
            }
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
    }

    private func path(for points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    /// Renders the current strokes into a fixed-size `UIImage` and hands PNG data
    /// back via `onSave`. No-ops if nothing has been drawn yet.
    private func save() {
        guard hasContent else { return }

        let renderer = UIGraphicsImageRenderer(size: Self.canvasSize)
        let image = renderer.image { rendererContext in
            let cgContext = rendererContext.cgContext

            UIColor.white.setFill()
            cgContext.fill(CGRect(origin: .zero, size: Self.canvasSize))

            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(3)
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)

            for stroke in allStrokes {
                guard let first = stroke.first, stroke.count > 1 else { continue }
                cgContext.move(to: first)
                for point in stroke.dropFirst() {
                    cgContext.addLine(to: point)
                }
                cgContext.strokePath()
            }
        }

        guard let pngData = image.pngData() else { return }
        onSave(pngData)
    }
}

#Preview {
    SignatureCaptureView(onSave: { _ in }, onCancel: {})
}
