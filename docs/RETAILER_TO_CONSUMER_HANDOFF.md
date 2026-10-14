# VeriTrust delivery — Retailer acceptance and Consumer verification phase

## Retailer: design approved, acceptance preparation
- The user approved the retailer UI direction.
- The confirmed development Auth identity `5e8a32fb-57b3-4eaf-ae64-883d4d1cdf6c` now has additional `retailer_operator` membership in Demo Family Pharmacy.
- Its existing manufacturer membership remains unchanged. This is convenient for dual-role demos; it is **not** a substitute for retailer-only isolation testing.
- Live database retailer workflows previously passed transaction-scoped manufacturer dispatch, retailer receipt, scan, inventory and quarantine tests. Genuine browser QR and retailer receipt testing remains unverified until user action.
- Next functional test: manufacturer generates 1-5 serials; download QR; dispatch a unit to Demo Family Pharmacy; sign into /retailer, scan the saved code, check batch/manufacturer, confirm receipt; quarantine a test unit.
- Important: physical scan before receipt is recommended but not enforced; clarify that in UX.

## Days 49–52: Consumer interface
- Added /consumer mobile-first camera-scanning and manual code entry interface.
- Added explanatory outcome examples: matched_record, caution, do_not_use, unverifiable, service_unavailable.
- Added safety warnings distinguishing database identifier match from physical authenticity and product quality.
- Added local-only suspicious-product report draft screen, clearly NOT transmitted to regulator.
- Explicitly did not enable anonymous real registry lookup. Public verification requires durable rate limiting, careful disclosure rules, event validation, abuse controls and adverse event reporting protocol.
- Camera decoding uses native BarcodeDetector where supported and provides manual fallback.

## Validation scope and release gate
- Consumer demo is only a UX preview, not an operational public authentication system.
- QR camera use on iOS Safari/Android Chrome and accessibility require device-based QA.
- User cannot use sample results to assess real products.
- Pending Day 49–52 improvements: approved risk controls, public verification API, connected and safely stored reporting, signed-off copy, browser QA and real customer field testing.
