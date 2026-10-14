# Live Supabase development validation — 14 October 2026

## Connected resources
- Supabase project: `veritrust-dev` (`cporcunlrlqoyiaazafe`), London `eu-west-2`
- API base: `https://cporcunlrlqoyiaazafe.supabase.co`
- Organization: kolade Adebimpe Database
- Source: `koladelampard1/veritrust-platform`

## Verified
- Initial database and atomic issuance migrations applied successfully.
- Follow-up `restrict_membership_helper` migration applied after security advisory flagged anonymous execution.
- Synthetic seed applied without error: 2 organizations, 1 product, 1 batch, 3 units, 3 issuance events.
- All ten application tables show PostgreSQL RLS enabled.
- Anonymous role has no direct SELECT privilege on serialized units.
- Authenticated role without a user JWT sees zero products, units, and organizations.
- `has_org_role` cannot be executed by `anon`, but can by `authenticated` for intended RLS helper use.
- `issue_units` cannot be called by `anon` or `authenticated`; restricted to server-side privileged role.
- Calling `issue_units` for a synthetic identity without manufacturer-admin membership is rejected and does not add units.

## Still not verified
- Actual Supabase Auth users and JWT-based multi-tenant isolation.
- Working hosted Next.js endpoints, E2E API requests, real positive authorized issuance.
- CI build/test status and preview deployment.
- Retailer transfer authorization and public verification rate limiting.

## Security advisory status
- Five RLS-enabled/no-policy notices correspond to intentional deny-by-default event/administrative tables. These must not be opened to clients casually.
- Authenticated SECURITY DEFINER function advisory remains for membership helper. Its execution is limited to the signed-in role and scoped to `auth.uid()`; consider moving the helper to a non-exposed private schema before external launch.
- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable

## Release gate
Do not make product verification public until database tenant tests, build/CI, secure server secret configuration, rate limiting, permission tests, and an independent security review pass.
