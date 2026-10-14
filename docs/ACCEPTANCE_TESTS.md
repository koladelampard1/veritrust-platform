# Day 40 acceptance tests — developer checklist

**Do not mark complete until run on the connected Supabase development project.**

## Authentication & tenancy
- [ ] Unauthenticated callers cannot SELECT product units, custody events or membership records.
- [ ] Users see only organizations in which they hold membership.
- [ ] Manufacturer A cannot create a product or batch for manufacturer B.
- [ ] Manufacturer B cannot read manufacturer A private inventory.
- [ ] Retailer users cannot issue serialized units or modify product registrations.
- [ ] Changing an organization ID in a request never escalates privileges.
- [ ] Platform administrator privileges are implemented through explicitly authorized server actions, not broad client grants.

## Registry and event lifecycle
- [ ] Product SKU and batch lot uniqueness enforced.
- [ ] Random unit token generation uses a cryptographic source, hashes tokens before storing and rejects duplicates.
- [ ] Issuance records an immutable audit event.
- [ ] Dispatch validates current holder and transitions atomically.
- [ ] Receipt validates an outstanding dispatch to receiving organization.
- [ ] Replayed idempotency keys do not duplicate a custody event.
- [ ] Expiry and active recall override code-match status.
- [ ] Unknown code never returns a product identity match.
- [ ] Verification requests are rate limited and do not expose serial lists.

## Operational checks
- [ ] Migration applies cleanly to fresh Supabase Postgres.
- [ ] Synthetic seed applies cleanly and is idempotent.
- [ ] Minimal privileges verified with real JWTs, not service-role test accounts.
- [ ] Secrets are configured only in the hosted environment, never in Git.
- [ ] CI confirms schema and integration tests before merging.
- [ ] Security review and API tests completed before external exposure.

## Explicit remaining work
This repository currently includes schema, sample fixtures and architecture, not running hosted APIs, live authentication, or proved RLS test results.
