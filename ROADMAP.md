# Roadmap

Work planned for The Brief over the coming months, roughly in order.

## Next

- **Rename Signal Daily to The Brief** across the Xcode targets, bundle IDs, Worker name and API client, without breaking existing installs or the live Worker URL.
- **Regional editions.** The pipeline already reserves `uk.json`. Build the UK edition end to end, then add Europe and North America, with the region picker driving which file the app loads.
- **Editorial pipeline hardening.** Move the editorial pass onto a schedule, validate every rewritten payload before it reaches R2, and add tests for clustering, ranking and the generic-language checks.
- **CI.** GitHub Actions running the Worker tests and typecheck, plus the iOS unit tests on a simulator, on every push.

## Then

- **Home screen widget** showing how many stories are left today and the next reminder time.
- **Offline reading** for the last seven days instead of only the latest briefing, with cache size limits.
- **Accessibility pass** on the card deck: full VoiceOver order, Dynamic Type up to the largest sizes, and Reduce Motion for the water and sway effects.
- **Plus subscription polish:** clearer restore flow, entitlement edge cases and StoreKit test coverage.

## Later

- **Source pages** with a short track record for each outlet and how often its reports were corroborated.
- **Continuing stories** that link today's update to earlier briefings on the same topic.
- **Localisation**, starting with Welsh and Spanish.

Ideas and bugs are tracked as GitHub issues.
