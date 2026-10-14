# VeriTrust Manufacturer Portal — Day 44 Handoff

## Entry points
- Landing page: https://veritrust-platform.vercel.app
- Manufacturer portal: https://veritrust-platform.vercel.app/manufacturer
- GitHub: https://github.com/koladelampard1/veritrust-platform

## Implemented
1. Responsive manufacturer workspace with branded desktop/sidebar and mobile navigation.
2. Six workspaces: Overview, Products, Batches, Serialization, Distribution, Labels.
3. Read-only synthetic preview mode with sample catalogue, batches, unit inventory and custody events.
4. Supabase password sign-in UI, session restoration, membership retrieval, organization switching and sign-out.
5. Role-scoped product onboarding POST and GET; role-scoped batch creation and query.
6. Signed-in dashboard overview API with product, batch and inventory reads and restricted supply-chain RPCs.
7. Authorized unit issuance through authenticated RPC; random opaque unit codes hashed before database storage.
8. Printable QR code labels and CSV export from newly issued tokens, without storing plaintext serials in the database.
9. Manufacturer-to-retailer stock dispatch through existing authorized custody API, with idempotency keys.
10. Display of recent distribution events and partner destinations.

## Safety design
- Demonstration is clearly marked as synthetic and not NAFDAC approved.
- QR payload carries a raw opaque identifier; public consumer verification is deliberately not enabled.
- Labels appear only immediately following issuance; they are not recoverable once the browser session closes.
- Manufacturer permissions are server and database enforced.
- No live brand claims or externally validated authenticity checks.

## Backend changes
- Migration: `202610140006_manufacturer_reads.sql` (applied to `veritrust-dev`).
- New endpoints: `GET /api/v1/me`, `GET /api/v1/manufacturer/overview`, `GET /api/v1/batches`.
- Existing endpoints: `POST /api/v1/products`, `POST /api/v1/batches`, `POST /api/v1/units`, `POST /api/v1/dispatch`.

## Limitations and acceptance gate
1. The database currently has **no permanent Auth test users or organization memberships**. As a consequence, a manufacturer cannot yet sign in and exercise writes in the hosted portal.
2. Real JWT login and live HTTP integration tests remain pending. Supabase database role simulations passed previously but are not a substitute.
3. Manufacturer portal supports issuing max 100 units per request. The generated label download workflow should be treated as a prototype, not approved for regulated production use.
4. Printable labels are not tamper-proof. Code cloning remains possible; physical safeguards and fraud detection are later phases.
5. Product dashboard rows limited to 100 products, 300 batches and 1,000 held units; replace with pagination for scale.
6. Customer-facing verification and retailer receiving UX belong to subsequent stages.
7. Vercel Ready only confirms a deployment build, not successful authenticated browser E2E.
8. Validate accessibility, camera/print performance, production-like device behaviour, and supply-chain workflows before acceptance.

## Day 44 acceptance criteria
- [x] Responsive manufacturer dashboard source deployed to GitHub and built by Vercel (build confirmation to be validated for latest commit).
- [x] Product create form connected to existing API.
- [x] Batch create form connected to existing API.
- [x] Issuance and QR label rendering flow connected to existing API.
- [x] CSV and printable labels implemented.
- [x] Dispatch form connected to protected API.
- [x] Synthetic read-only review environment.
- [ ] Real manufacturer admin can sign in and create a product in browser.
- [ ] Real manufacturer admin can create batch, issue codes and download labels.
- [ ] Authorized manufacturer operator can dispatch inventory.
- [ ] External reviewer mobile-device UAT and accessibility verification.
