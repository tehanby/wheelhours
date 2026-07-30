import SwiftUI

/// A generic, reusable circular progress ring for displaying a single
/// percent-based stat (e.g. "62% of total hours towards a DMV requirement").
///
/// Deliberately generic rather than DMV-specific — `DashboardView` lays out
/// several of these side by side (total / night / weather hours), but nothing
/// here references `StateDMVPresetEngine` or any other domain type, so this
/// component can be reused anywhere a labeled percent ring is useful.
struct ProgressRingView: View {
    /// Raw completion fraction, e.g. `0.62` for 62%. Intentionally NOT clamped
    /// for the displayed percent *text* — a value above `1.0` (a driver who
    /// exceeded a requirement) renders as e.g. "124%" — but the ring's stroke
    /// itself is visually capped at one full lap via `clampedPercent`, so it
    /// never wraps around itself. This mirrors
    /// `StateDMVPresetEngine.DMVProgress`'s own doc comment: percents aren't
    /// clamped at the data layer, and it's left to presentation to decide how
    /// to render "exceeded requirement".
    let percent: Double

    /// Short caption shown below the ring, e.g. "Total Hours".
    let label: String

    /// Ring/accent color. Callers typically use a different color per stat
    /// (e.g. blue for total, indigo for night, teal for weather) so several
    /// rings read clearly when placed side by side.
    let color: Color

    /// Optional secondary line under `label`, e.g. "31 / 50 hrs".
    var detailText: String? = nil

    var lineWidth: CGFloat = 10
    var diameter: CGFloat = 96

    private var clampedPercent: Double {
        min(max(percent, 0), 1)
    }

    private var displayPercentText: String {
        "\(Int((percent * 100).rounded()))%"
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: clampedPercent)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: clampedPercent)

                Text(displayPercentText)
                    .font(.headline)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
            .frame(width: diameter, height: diameter)

            VStack(spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let detailText {
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(detailText.map { "\(displayPercentText), \($0)" } ?? displayPercentText))
    }
}

#Preview {
    HStack(spacing: 24) {
        ProgressRingView(percent: 0.62, label: "Total Hours", color: .blue, detailText: "31 / 50 hrs")
        ProgressRingView(percent: 0.4, label: "Night Hours", color: .indigo, detailText: "4 / 10 hrs")
        ProgressRingView(percent: 1.2, label: "Weather Hours", color: .teal, detailText: "6 / 5 hrs")
    }
    .padding()
}
