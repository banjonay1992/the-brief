import Foundation
import StoreKit

protocol SubscriptionServicing: Sendable {
    func loadProducts() async throws -> [SubscriptionDisplayProduct]
    func hasActiveSubscription() async -> Bool
    func purchase(productID: String) async throws -> Bool
    func restorePurchases() async throws -> Bool
}

struct StoreKitSubscriptionService: SubscriptionServicing {
    func loadProducts() async throws -> [SubscriptionDisplayProduct] {
        let products = try await Product.products(for: SignalSubscriptionProduct.all)
        return products
            .sorted { $0.price < $1.price }
            .map {
                SubscriptionDisplayProduct(
                    id: $0.id,
                    displayName: $0.displayName,
                    displayPrice: $0.displayPrice,
                    description: $0.description
                )
            }
    }

    func hasActiveSubscription() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if SignalSubscriptionProduct.all.contains(transaction.productID), transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    func purchase(productID: String) async throws -> Bool {
        guard let product = try await Product.products(for: [productID]).first else {
            return false
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                return false
            }
            await transaction.finish()
            return SignalSubscriptionProduct.all.contains(transaction.productID)
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async throws -> Bool {
        try await AppStore.sync()
        return await hasActiveSubscription()
    }
}
