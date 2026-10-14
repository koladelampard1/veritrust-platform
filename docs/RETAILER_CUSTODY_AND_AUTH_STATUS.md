# VeriTrust — retailer custody and Auth testing status

Environment: `veritrust-dev` / `cporcunlrlqoyiaazafe`

## Implemented and verified
- Supabase migration `retailer_custody_workflow` applied successfully.
- Secure PostgreSQL `dispatch_unit` and `receive_unit` functions enforce organization permissions using authenticated identity context.
- Each operation records custody and audit events atomically and enforces idempotency keys.
- API routes committed: `POST /api/v1/dispatch`, `POST /api/v1/receive`.
- Latest Vercel production deployment `dpl_CXNYNJBgHbY2ppAifci1bRLtGWRZ` is READY at commit `a6b1214ee192aed2ac0de322dc20e02c958bb552`.

## Database acceptance
Transaction-scoped synthetic identity test passed:
1. Manufacturer dispatches existing seeded unit.
2. Same dispatch idempotency key produces same event.
3. Outsider cannot receive unit.
4. Retailer-member receives unit.
5. Same receive idempotency key returns same event.
6. Unit holder and status correctly transition to retailer/received.
Transaction rolled back; persistent demo stock unchanged.

## Still pending
- No real Supabase Auth test identities were created. Available Supabase connector does not expose Auth Admin user creation or password sign-in.
- Direct HTTP from container has no external DNS/network access. An attempt to orchestrate auth signup/login through SQL was blocked by tool safety controls, so that route was not used.
- Therefore **there are no verified Supabase-issued JWT-based HTTP test results**; database role simulations do not replace this.
- Creation of genuine users should use official Supabase Auth dashboard/Admin API with proper Auth configuration. Avoid direct modifications to managed `auth.users` and `auth.identities`.
- Once two test users exist, assign membership to test organizations and execute manufacturer product, batch, issuance, dispatch, retailer receipt, read isolation, invalid JWT and cross-tenant negative API tests.
- Consumer verification remains a non-public demo endpoint. Before release add durable rate limiting, anomaly review and real-world safety validation.

## User provisioning procedure
1. In the Supabase `veritrust-dev` Dashboard → Authentication → Users, add two controlled test identities with valid accessible email addresses.
2. Store temporary passwords securely, outside GitHub and chat.
3. Assign roles `manufacturer_admin` to Demo Infant Nutrition Ltd and `retailer_operator` to Demo Family Pharmacy using their returned `auth.users.id` values.
4. Run HTTPS API tests using actual access tokens issued by Supabase Auth.
