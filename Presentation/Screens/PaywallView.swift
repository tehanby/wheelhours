import SwiftUI
import StoreKit

/// WheelHours's monetization screen: presented (typically as a sheet) when a
/// free-tier gate blocks an action, e.g. the Dashboard's "log a drive" button
/// or the Export screen's export button after
/// `FreemiumGateService.canLogOrExportDrive` returns `false`.
///
/// This screen's job is monetization, but per the app's zero-friction ethos
/// it must never trap the user — "Maybe Later" is always available and always
/// dismisses without requiring a purchase.
@available(iOS 15, *)
@MainActor
struct PaywallView: View {
    @ObservedObject var storeKitService: StoreKitService

    /// Called when the user backs out without purchasing (via "Maybe Later"
    /// or the nav-bar close button). This view does not call it automatically
    /// after a successful purchase — callers observing
    /// `storeKitService.isLifetimeUnlocked` typically dismiss the sheet
    /// themselves at that point, but they're free to also treat `onDismiss`
    /// as "go back to what I was doing" in either case.
    let onDismiss: () -> Void

    @State private var product: Product?
    @State private var isPurchasing = false
    @State private var purchaseErrorMessage: String?

    /// Shown only if `loadProducts()` fails or returns no match for the
    /// lifetime-unlock product ID — keeps the button legible (with a
    /// best-effort price) even offline or in a misconfigured StoreKit test
    /// environment, rather than showing a blank/broken price.
    private static let fallbackDisplayPrice = "$4.99"

    init(storeKitService: StoreKitService, onDismiss: @escaping () -> Void) {
        self.storeKitService = storeKitService
        self.onDismiss = onDismiss
    }

    private var displayPrice: String {
        product?.displayPrice ?? Self.fallbackDisplayPrice
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList
                    purchaseSection
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Maybe Later", action: onDismiss)
                }
            }
            .task {
                await loadProduct()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "steeringwheel")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Unlock WheelHours Lifetime")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("One purchase. Everything, forever. No subscription, no account required.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureRow(
                icon: "infinity",
                title: "Unlimited drive logging",
                subtitle: "No cap on the number of drives you can track."
            )
            featureRow(
                icon: "doc.richtext",
                title: "PDF export for the DMV",
                subtitle: "Generate a signed, ready-to-submit supervised driving log."
            )
            featureRow(
                icon: "car.2",
                title: "Multi-vehicle support",
                subtitle: "Track hours across every car your driver uses."
            )
            featureRow(
                icon: "person.2",
                title: "Unlimited supervisors",
                subtitle: "Add every parent, guardian, or instructor who supervises drives."
            )
            featureRow(
                icon: "location",
                title: "Automatic drive detection",
                subtitle: "Background start/stop and night-hours tracking via location."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            Button(action: purchase) {
                Group {
                    if isPurchasing {
                        ProgressView()
                    } else {
                        Text("Unlock WheelHours Lifetime — \(displayPrice)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchasing)

            if let purchaseErrorMessage {
                Text(purchaseErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("Maybe Later", action: onDismiss)
                .font(.footnote)
        }
    }

    private func loadProduct() async {
        let products = (try? await storeKitService.loadProducts()) ?? []
        product = products.first { $0.id == StoreKitService.lifetimeUnlockProductID }
    }

    private func purchase() {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseErrorMessage = nil

        Task {
            defer { isPurchasing = false }
            do {
                let didUnlock = try await storeKitService.purchase()
                if didUnlock {
                    onDismiss()
                }
                // If `false` (user cancelled, or pending e.g. Ask to Buy),
                // stay on the paywall — the user can retry or back out via
                // "Maybe Later".
            } catch {
                purchaseErrorMessage = "Something went wrong completing the purchase. Please try again."
            }
        }
    }
}

#Preview {
    PaywallView(storeKitService: StoreKitService(), onDismiss: {})
}
