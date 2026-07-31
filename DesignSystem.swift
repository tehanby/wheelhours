import SwiftUI

struct DesignSystem {
    // MARK: - Color Palette
    static let primaryColorLight = Color("PrimaryColorLight")
    static let primaryColorDark = Color("PrimaryColorDark")
    static let secondaryColorLight = Color("SecondaryColorLight")
    static let secondaryColorDark = Color("SecondaryColorDark")
    static let backgroundColorLight = Color("BackgroundColorLight")
    static let backgroundColorDark = Color("BackgroundColorDark")
    static let borderColorLight = Color("BorderColorLight")
    static let borderColorDark = Color("BorderColorDark")

    // MARK: - Typography
    enum FontSize {
        case small, medium, large

        var rawValue: CGFloat {
            switch self {
            case .small:
                return 14
            case .medium:
                return 16
            case .large:
                return 20
            }
        }

        func systemFont() -> Font {
            return .system(size: rawValue, weight: .regular)
        }
    }

    enum FontWeight {
        case regular, medium, bold

        var rawValue: Font.Weight {
            switch self {
            case .regular:
                return .regular
            case .medium:
                return .medium
            case .bold:
                return .bold
            }
        }

        func systemFont(size: CGFloat) -> Font {
            return .system(size: size, weight: rawValue)
        }
    }

    // MARK: - Layout Rules
    static let gridUnit = 8.0

    struct Spacing {
        static let small = gridUnit * 1
        static let medium = gridUnit * 2
        static let large = gridUnit * 3
    }

    struct Corners {
        static let small = gridUnit * 1.5
        static let medium = gridUnit * 2
        static let large = gridUnit * 2.5
    }
}

// Usage example in a SwiftUI view
struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Hello, World!")
                .font(DesignSystem.FontSize.large.systemFont())
                .padding(.vertical, DesignSystem.Spacing.small)

            Button(action: {}) {
                Text("Action")
                    .padding([.leading, .trailing], DesignSystem.Spacing.large)
                    .background(DesignSystem.primaryColorLight)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.Corners.medium)
            }
        }
        .background(DesignSystem.backgroundColorLight)
    }
}
