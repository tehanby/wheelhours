import Foundation
import StoreKit
import Combine

/// Errors surfaced by `StoreKitService` beyond what StoreKit itself throws.
@available(iOS 15, *)
enum StoreKitServiceError: Error {
    /// `Product.products(for:)` returned no product matching the configured
    /// product identifier. Usually means the product isn't set up (or isn't yet
    /// propagated) in App Store Connect, or the local `.storekit` config file
    /// isn't selected as the active scheme's StoreKit configuration.
    case productNotFound
    /// StoreKit returned a transaction/entitlement it could not cryptographically
    /// verify (`VerificationResult.unverified`). Treated as "not purchased".
    case failedVerification
}

/// Thin StoreKit 2 wrapper around DriveTrack's single non-consumable "lifetime
/// unlock" product.
///
/// Kept deliberately separate from `FreemiumGateService`, which holds the actual
/// free-tier gating rule and has zero StoreKit dependency — that separation is
/// what makes the gating logic unit-testable without a real purchase flow. This
/// type is the *only* one in the app that should import `StoreKit` directly.
///
/// ### Usage from a SwiftUI ViewModel
/// ```swift
/// @StateObject private var storeKitService = StoreKitService()
///
/// func loadPaywallProducts() async {
///     products = (try? await storeKitService.loadProducts()) ?? []
/// }
///
/// func buyLifetimeUnlock() async {
///     let didUnlock = (try? await storeKitService.purchase()) ?? false
/// }
/// ```
/// `isLifetimeUnlocked` is `@Published`, so a ViewModel can observe it directly
/// (e.g. via `.onReceive`/`.assign` or simply reading it inside a SwiftUI view
/// that owns/observes the service) rather than polling `isUnlocked()`. It is
/// kept current automatically by a `Transaction.updates` listener started in
/// `init`, which picks up purchases restored from another device, renewals, and
/// Ask-to-Buy approvals.
@available(iOS 15, *)
@MainActor
final class StoreKitService: ObservableObject {
    /// The single non-consumable "unlock everything" product DriveTrack sells.
    /// Display name ("Unlock DriveTrack Lifetime") and price ($4.99 at time of
    /// writing) are configured in App Store Connect (and mirrored in the local
    /// `.storekit` config for Xcode testing) — this identifier is just the
    /// lookup key used by StoreKit APIs.
    static let lifetimeUnlockProductID = "com.drivetrack.lifetime.unlock"

    /// Current known entitlement state for the lifetime unlock. Published so
    /// SwiftUI views/ViewModels can observe it directly. Kept in sync by
    /// `refreshEntitlementStatus()`, which runs on `init`, after every
    /// `purchase()` call, and whenever the `Transaction.updates` listener fires.
    @Published private(set) var isLifetimeUnlocked: Bool = false

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        // Unstructured `Task { }` created from this MainActor-isolated `init`
        // inherits MainActor isolation, so touching `self` inside is safe.
        transactionUpdatesTask = Task { [weak self] in
            await self?.listenForTransactionUpdates()
        }
        Task { [weak self] in
            await self?.refreshEntitlementStatus()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    /// Loads the store's product list (currently just the lifetime unlock).
    /// Throws whatever `Product.products(for:)` throws (e.g. network failure).
    func loadProducts() async throws -> [Product] {
        try await Product.products(for: [Self.lifetimeUnlockProductID])
    }

    /// Initiates a purchase of the lifetime unlock product.
    ///
    /// - Returns: `true` if the purchase completed and was verified
    ///   successfully (also updating `isLifetimeUnlocked`); `false` if the user
    ///   cancelled, or the purchase is pending external action (e.g. Ask to Buy,
    ///   which will complete later via the `Transaction.updates` listener).
    /// - Throws: `StoreKitServiceError.productNotFound` if the product can't be
    ///   looked up, `StoreKitServiceError.failedVerification` if StoreKit can't
    ///   verify the resulting transaction, or any error thrown by
    ///   `Product.purchase()` itself.
    func purchase() async throws -> Bool {
        let products = try await loadProducts()
        guard let product = products.first(where: { $0.id == Self.lifetimeUnlockProductID }) else {
            throw StoreKitServiceError.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verificationResult):
            let transaction = try Self.checkVerified(verificationResult)
            await transaction.finish()
            await refreshEntitlementStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            // Ask to Buy / SCA style flows: no entitlement yet. The
            // Transaction.updates listener will pick it up if/when it clears.
            return false

        @unknown default:
            return false
        }
    }

    /// Checks `Transaction.currentEntitlements` for a verified, non-revoked
    /// purchase of the lifetime unlock product. This is the source of truth for
    /// entitlement state, and also refreshes the published `isLifetimeUnlocked`
    /// property as a side effect.
    func isUnlocked() async -> Bool {
        await refreshEntitlementStatus()
        return isLifetimeUnlocked
    }

    /// Re-derives `isLifetimeUnlocked` from `Transaction.currentEntitlements`.
    private func refreshEntitlementStatus() async {
        for await verificationResult in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(verificationResult) else { continue }
            if transaction.productID == Self.lifetimeUnlockProductID, transaction.revocationDate == nil {
                isLifetimeUnlocked = true
                return
            }
        }
        isLifetimeUnlocked = false
    }

    /// Long-running listener for `Transaction.updates` (renewals, purchases made
    /// on another device, Ask-to-Buy approvals resolving later, etc). Started
    /// once in `init` and cancelled in `deinit`.
    private func listenForTransactionUpdates() async {
        for await verificationResult in Transaction.updates {
            guard let transaction = try? Self.checkVerified(verificationResult) else { continue }
            await transaction.finish()
            await refreshEntitlementStatus()
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitServiceError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
