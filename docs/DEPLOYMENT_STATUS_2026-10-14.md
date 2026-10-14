# Deployment and authenticated testing status — 2026-10-14

## Verified environment
- GitHub: koladelampard1/veritrust-platform
- Supabase: veritrust-dev / cporcunlrlqoyiaazafe (ACTIVE_HEALTHY), London
- Existing migrations: initial schema, atomic issuance, restrict membership helper
- Database: 2 synthetic organizations, 1 product, 1 batch, 3 serialized units
- Supabase Auth: 0 users

## Deployment blocker
- Vercel team: team_F6DAxERqmjo0E8cTeI5lXSgW
- create_git_project for koladelampard1/veritrust-platform failed with HTTP 403: project creation forbidden. No project or deployment created.
- No deployment secrets configured. Never put service-role key in GitHub, browser, or plain chat.

## Executed database security tests
- Authenticated role with fabricated, non-member JWT claim cannot SELECT manufacturers' product, batch, unit, or organization rows (0 rows).
- Unauthorized manufacturer product insertion denied.
- Database issuance RPC was previously verified to deny synthetic identity without membership and leave zero side effects.
- This does NOT count as testing authentic Supabase Auth login sessions or valid role-owner permissions.

## Code CI status
- CI workflow install fixed to use npm install before lockfile exists.
- GitHub combined commit-status API showed no reported statuses for most recent commit.
- Local clone/build attempt failed because the runtime could not resolve github.com.
- No successful build, hosted endpoint test, or live JWT authorization result can be claimed yet.

## Required before launching
1. Give Vercel integration create-project rights for user's chosen team, or import repository through Vercel UI.
2. Configure SUPABASE_SERVICE_ROLE_KEY, VERITRUST_SERIAL_HMAC_KEY as server-only sensitive environment variables in the project.
3. Configure NEXT_PUBLIC_SUPABASE_URL and Supabase publishable/anon key as appropriate; verify deployment settings.
4. Generate and commit package-lock.json and ensure CI typecheck/test/build passes.
5. Create Auth test users through supported Supabase Auth admin path, then grant organization memberships.
6. Test authorized manufacturer issuance and retailer read, cross-tenant rejects, expiry/recall outcomes with genuine JWTs.
7. Keep consumer verification non-public until abuse/rate controls pass.
