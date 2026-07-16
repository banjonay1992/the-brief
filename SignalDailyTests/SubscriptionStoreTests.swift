import XCTest
@testable import SignalDaily

@MainActor
final class SubscriptionStoreTests: XCTestCase {
    func testRefreshLoadsProductsAndSubscribedState() async {
        let store = SubscriptionStore(service: MockSubscriptionService(hasAccess: true))

        await store.refresh()

        XCTAssertEqual(store.products.first?.id, SignalSubscriptionProduct.monthly)
        XCTAssertEqual(store.accessState, .subscribed)
        XCTAssertTrue(store.accessState.hasAccess)
    }

    func testPurchaseUpdatesAccessState() async {
        let store = SubscriptionStore(service: MockSubscriptionService(purchaseSucceeds: true))

        await store.refresh()
        await store.purchaseMonthly()

        XCTAssertEqual(store.accessState, .subscribed)
        XCTAssertEqual(store.message, "Subscription active.")
    }

    func testRestoreHandlesMissingSubscription() async {
        let store = SubscriptionStore(service: MockSubscriptionService(restoreSucceeds: false))

        await store.restorePurchases()

        XCTAssertEqual(store.accessState, .unsubscribed)
        XCTAssertEqual(store.message, "No active subscription was found.")
    }
}

private struct MockSubscriptionService: SubscriptionServicing {
    var hasAccess = false
    var purchaseSucceeds = false
    var restoreSucceeds = false

    func loadProducts() async throws -> [SubscriptionDisplayProduct] {
        [
            SubscriptionDisplayProduct(
                id: SignalSubscriptionProduct.monthly,
                displayName: "Monthly",
                displayPrice: "£0.99",
                description: "Test subscription"
            )
        ]
    }

    func hasActiveSubscription() async -> Bool {
        hasAccess
    }

    func purchase(productID: String) async throws -> Bool {
        productID == SignalSubscriptionProduct.monthly && purchaseSucceeds
    }

    func restorePurchases() async throws -> Bool {
        restoreSucceeds
    }
}
