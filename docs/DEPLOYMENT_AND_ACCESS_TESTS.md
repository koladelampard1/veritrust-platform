# Supabase development bring-up and acceptance

## Connection needed
Supabase plugin must be connected to run this checklist. Do not share service-role keys in chat or commit them.

## Provision
1. Create an isolated Supabase project named veritrust-dev in an approved organization and region.
2. Configure Auth with email/password for test accounts and no anonymous employee access.
3. Apply migrations `202610140001_initial.sql` then `202610140002_atomic_issuance.sql`.
4. Run `supabase/seed.sql` (synthetic records only).
5. Create separate test Auth users with verified test identities; grant manufacturer_admin for first organization and retailer_operator for second using privileged SQL.
6. Set project URL and anon key for server-side JWT clients and store service-role/HMAC keys only in server-side hosting secrets.
7. Deploy authenticated demo endpoints to protected preview; keep public verification disabled.
8. Run integration tests against real JWTs; audit RLS with multiple users/organizations.

## Contract routes
- POST /api/v1/products — manufacturer_admin JWT, own org
- GET /api/v1/products?manufacturer_id= — manufacturer role JWT
- POST /api/v1/batches — manufacturer_admin JWT, own product
- POST /api/v1/units — manufacturer_admin JWT; atomic issuance RPC
- GET /api/v1/inventory?organization_id= — organization member JWT
- POST /api/v1/verify — authenticated demo JWT only, NOT consumer/public; public rate limiting and security controls pending

## Nonnegotiable checks
- JWT missing/invalid => 401/403; no privileged fallback.
- Manufacturer A cannot create/read manufacturer B assets.
- Retailer cannot issue units.
- Replayed digest collisions abort full issuance transaction.
- Issuance event count equals unit issuance count.
- Unknown identifiers yield unverifiable, not counterfeit.
- Recall and expiry override record-match.
- Secrets remain absent from source and browser bundles.

## Known incomplete implementation
The product and batch APIs are committed but not run against Supabase.
No dedicated Supabase project is connected, no migrations have been applied and no live integration tests have passed.
Custody transfers and retailer receipt API remain for the next milestone.
Consumer public verification remains disabled until persistent rate limiting and abuse mitigation exist.
CI is configured but its first GitHub Actions result has not yet been inspected.
