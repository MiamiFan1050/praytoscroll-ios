import Foundation
import StoreKit

/// StoreKit 2 abstraction for a future "PrayToScroll Pro" (v1.1). Not reachable from any v1.0 screen:
/// the Paid Apps Agreement isn't signed, and the gate, Strict Lock blocking, streaks and Circles stay free forever.
@MainActor
final class ProStore {
    static let shared = ProStore()

    static let productIDs: [String] = [
        "com.amenkeyapp.ios.pro.monthly",
        "com.amenkeyapp.ios.pro.yearly",
    ]

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private var updatesTask: Task<Void, Never>?

    /// v1.0 never calls this.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }

    func loadProducts() async {
        products = (try? await Product.products(for: Self.productIDs)) ?? []
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID), transaction.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    enum PurchaseOutcome { case success, cancelled, pending, failed }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    return .success
                }
                return .failed
            case .userCancelled: return .cancelled
            case .pending: return .pending
            @unknown default: return .failed
            }
        } catch {
            return .failed
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
