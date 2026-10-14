# VeriTrust Platform

Mobile-first product verification and serialized traceability prototype for Nigeria.

> **DEMONSTRATION ONLY.** Uses synthetic products and organizations. This repository is not an official NAFDAC/GS1/PATS service. Matching an identifier does not certify physical authenticity or safety.

## Scope
- Manufacturer-owned products, batches and serialized product units
- Organization-scoped authentication and authorization
- Append-only custody and verification history
- Retailer receiving controls and public verification status
- Explainable fraud-rule flags and investigation workflow

## Development architecture
Target: Next.js + TypeScript, Supabase Postgres/Auth with row-level security, Vercel preview. The available Day 40 reference backend uses a localhost-only SQLite demonstration and is **not suitable for public hosting**.

## Security requirements
No credentials, production data, service-role keys or bearer-token examples are to be committed. Manufacturer issuance and retailer receipt require authorization on the server and at the database boundary. Public verification must minimize disclosed data and use rate limiting.

## Planned work
1. Database migrations and deny-by-default RLS
2. Server-side issuance, custody event and verification endpoints
3. Synthetic test fixtures and multi-tenant isolation tests
4. Approved UX implementation, protected staging deployment and security review

See `docs/ARCHITECTURE.md` and `supabase/migrations/` for the implementation baseline.
