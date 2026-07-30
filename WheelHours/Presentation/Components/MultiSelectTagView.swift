import SwiftUI

/// Generic, reusable tappable "chip" picker.
///
/// Reused across the manual-entry form for three different kinds of field:
///
/// - **Road conditions** (`allowsMultipleSelection: true`) — genuinely multi-select,
///   since a single drive can legitimately be tagged both `.highway` and `.wetRain`.
/// - **Supervisor** and **vehicle** (`allowsMultipleSelection: false`) — a drive has
///   exactly one supervisor and is driven in exactly one vehicle, so these are
///   presented as single-select chip pickers instead of a genuinely multi-select
///   list, even though they're built from the same component.
///
/// Selection is tracked by `Item.ID` (via `Identifiable`) rather than by `Item`
/// itself. This is deliberate: it lets this view work uniformly for value-type
/// enums (`RoadCondition`, whose `ID == String`) *and* SwiftData `@Model` reference
/// types (`Supervisor`, `Vehicle`) without requiring `Item` to be `Hashable` beyond
/// whatever `Identifiable` already guarantees (`ID: Hashable`), and without this
/// file needing to know or assume anything about how a `@Model` class's `ID` is
/// implemented.
///
/// ## Single-select semantics
/// For `allowsMultipleSelection == false`, tapping an unselected chip replaces
/// `selection` with just that item's ID; tapping the *already*-selected chip clears
/// the selection entirely (rather than being a no-op). That gives the user a way to
/// get back to "nothing chosen" (e.g. "no supervisor recorded yet") without a
/// separate Clear button cluttering the field.
struct MultiSelectTagView<Item: Identifiable>: View {
    let items: [Item]
    let label: (Item) -> String
    var allowsMultipleSelection: Bool = true
    @Binding var selection: Set<Item.ID>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { item in
                chip(for: item)
            }
        }
    }

    private func chip(for item: Item) -> some View {
        let isSelected = selection.contains(item.id)
        return Button {
            toggle(item)
        } label: {
            Text(label(item))
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor : Color.gray.opacity(0.18))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func toggle(_ item: Item) {
        if allowsMultipleSelection {
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
        } else {
            selection = selection.contains(item.id) ? [] : [item.id]
        }
    }
}

/// Minimal left-to-right, top-to-bottom wrapping layout for chip-style content —
/// standard library SwiftUI has no built-in "wrap" container, and a fixed `HStack`
/// would either overflow off-screen or require manual row-splitting by callers.
/// Implemented with the `Layout` protocol (iOS 16+) rather than a `GeometryReader`
/// hack so it composes normally with `Form`/`List` row sizing.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrangeRows(subviews: subviews, maxWidth: maxWidth)

        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        var index = 0
        let rows = arrangeRows(subviews: subviews, maxWidth: bounds.width)

        for row in rows {
            var x = bounds.minX
            for _ in row.items {
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += row.height + spacing
        }
    }

    // MARK: - Row arrangement

    private struct Row {
        var items: [Int]
        var width: CGFloat
        var height: CGFloat
    }

    private func arrangeRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var currentItems: [Int] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let addedWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if addedWidth > maxWidth, !currentItems.isEmpty {
                rows.append(Row(items: currentItems, width: currentWidth, height: currentHeight))
                currentItems = []
                currentWidth = 0
                currentHeight = 0
            }

            currentItems.append(index)
            currentWidth = currentItems.count == 1 ? size.width : currentWidth + spacing + size.width
            currentHeight = max(currentHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(Row(items: currentItems, width: currentWidth, height: currentHeight))
        }

        return rows
    }
}

#Preview {
    struct PreviewItem: Identifiable {
        let id: String
        let name: String
    }

    struct PreviewWrapper: View {
        @State private var selection: Set<String> = ["b"]
        let items = [
            PreviewItem(id: "a", name: "City"),
            PreviewItem(id: "b", name: "Highway"),
            PreviewItem(id: "c", name: "Rural"),
            PreviewItem(id: "d", name: "Wet/Rain"),
            PreviewItem(id: "e", name: "Snow")
        ]

        var body: some View {
            MultiSelectTagView(
                items: items,
                label: { $0.name },
                selection: $selection
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
