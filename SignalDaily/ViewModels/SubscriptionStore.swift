import Foundation
import Observation

@MainActor
@Observable
final class SubscriptionStore {
    private let service: SubscriptionServicing
    private(set) var products: [SubscriptionDisplayProduct] = []
    private(set) var accessState: SubscriptionAccessState = .checking
    private(set) var isWorking = false
    private(set) var message: String?

    var primaryProduct: SubscriptionDisplayProduct {
        products.first ?? SubscriptionDisplayProduct(
            id: SignalSubscriptionProduct.monthly,
            displayName: "Monthly",
            displayPrice: SubscriptionCopy.monthlyPriceFallback,
            description: SubscriptionCopy.subtitle
        )
    }

    init(service: SubscriptionServicing = StoreKitSubscriptionService()) {
        self.service = service
    }

    func refresh() async {
        isWorking = true
        defer { isWorking = false }

        do {
            products = try await service.loadProducts()
            accessState = await service.hasActiveSubscription() ? .subscribed : .unsubscribed
            message = nil
        } catch {
            accessState = .unavailable("Subscriptions are not available right now.")
            message = "Subscriptions are not available right now."
        }
    }

    func purchaseMonthly() async {
        isWorking = true
        defer { isWorking = false }

        do {
            let didSubscribe = try await service.purchase(productID: primaryProduct.id)
            accessState = didSubscribe ? .subscribed : .unsubscribed
            message = didSubscribe ? "Subscription active." : "Purchase was not completed."
        } catch {
            accessState = .unavailable("Purchase failed.")
            message = "Purchase failed. Please try again."
        }
    }

    func restorePurchases() async {
        isWorking = true
        defer { isWorking = false }

        do {
            let restored = try await service.restorePurchases()
            accessState = restored ? .subscribed : .unsubscribed
            message = restored ? "Subscription restored." : "No active subscription was found."
        } catch {
            accessState = .unavailable("Restore failed.")
            message = "Restore failed. Please try again."
        }
    }
}
