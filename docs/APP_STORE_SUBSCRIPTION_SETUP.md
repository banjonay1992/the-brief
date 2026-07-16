# App Store Subscription Setup

Signal Daily sells digital content and app functionality, so the iOS app should use App Store in-app purchase for the monthly plan.

## Product

- Type: Auto-renewable subscription
- Subscription group: `Signal Daily Plus`
- Product ID: `signal_daily_monthly`
- Reference name: `Signal Daily Plus Monthly`
- Duration: 1 month
- UK target price: `£0.99` or the nearest available App Store Connect price point

## App Review Notes

- The paywall must show the product name, price, billing period, and renewal/cancellation note.
- The app must provide a restore purchases action.
- Do not link to Stripe or another external checkout for this digital subscription inside the iOS app.
- Submit the first in-app purchase with the app build so App Review can test the purchase flow.

## Backend Follow-Up

The current app checks StoreKit entitlements on-device. Before launch, add App Store Server Notifications and server-side entitlement verification if subscriptions unlock backend-only features.
