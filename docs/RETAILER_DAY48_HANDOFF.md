# VeriTrust — Retailer Scanning & Inventory Workflow (Days 45–48)

## Shipped source
- Responsive retailer console: `/retailer`
- Demo preview: safe, read-only synthetic sample records, no production claims
- Protected endpoints:
  - GET `/api/v1/retailer/me`
  - GET `/api/v1/retailer/overview?organization_id=...`
  - POST `/api/v1/retailer/scan`: accepts code + retailer organization; computes keyed digest server-side
  - POST `/api/v1/receive`: authenticated retailer receipt of unit dispatched to its organization
  - POST `/api/v1/retailer/quarantine`: requires retailer-held unit, reason, and idempotency key
- Database migration `202610140007_retailer_scanning.sql` deployed to `veritrust-dev`.
- Existing manufacture-to-retailer dispatch and atomic receipt RPCs reused.
- Quarantine creates a custody event, sets unit status and raises an investigation alert.
- Retailer inventory includes product, lot, manufacturer, expiry, active recall and alert markers.
- Camera QR reader uses native BarcodeDetector when supported. Manual token entry is always available; unsupported browsers display an explicit fallback message.
- CSV inventory export; contextual warnings distinguish registry matching from physical quality or authenticity.

## Security and limitations
- All retailer data and scan RPCs verify real JWT membership and organization ID on the server/database.
- A scan of a serial not in the organization or a confirmed pending delivery does not disclose product metadata.
- An unknown identifier yields `unverifiable`, not `counterfeit`.
- Expired/recalled/blocked/quarantined records yield `do_not_use`.
- No external NAFDAC, GS1 or manufacturer-live verification exists; this is a synthetic prototype.
- In this build, receipt is not technically conditional on a physical QR scan; the UI advises scanning first. A strict scan-before-receipt policy is future work.
- No enforced fraud rule-based quarantine automation; retailer manually quarantines suspected items. Fraud rules are the next planned phase.
- No authenticated retailer browser QA yet, because the environment lacks a confirmed retailer test account.
- Camera rendering, responsive UX and accessible-device checks have not been independently verified on real mobile devices.
- Database APIs are limited to 500 rows; pagination required for scale.

## Integration tests executed on live Supabase development database
Tests were performed in a rollback transaction with synthetic auth identities and org memberships:
1. Manufacturer dispatch registered to Demo Family Pharmacy — PASS.
2. `retailer_incoming` returns only the intended pending unit — PASS.
3. Retailer scan resolves registered identifier to `matched_record` with `incoming` location — PASS.
4. Retailer receives; inventory status changes and ownership moves — PASS.
5. Retailer scan resolves received unit to `in_inventory` — PASS.
6. Retailer quarantine sets status, emits custody event, creates alert — PASS.
7. Subsequent scan yields `do_not_use` — PASS.
8. Unrelated user cannot list retailer inventory — PASS.

The seeded unit digest was used for the test. All transactional changes were rolled back; no actual stock records were modified.

## Final acceptance gate
- Create/confirm a distinct Supabase Auth retailer test account.
- Assign it `retailer_operator` membership in Demo Family Pharmacy.
- Use manufacturer portal to issue a fresh code, save/download its label, and dispatch the unit to Demo Family Pharmacy.
- Sign in as the retailer; scan the printed/displayed QR code, verify origin/lot/expiry, confirm receipt, observe updated inventory.
- Repeat with one intentionally suspicious unit; quarantine it, verify `do_not_use` and alert record.
- Confirm retailer cannot register manufacturer products or see another retailer's inventory.
- Validate camera permissions, Android Chrome and iOS Safari fallback, and label/camera UI.
- QA/PO approval required before declaring phase complete.
