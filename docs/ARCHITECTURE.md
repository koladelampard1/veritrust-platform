# VeriTrust Backend Architecture — Day 40

## Trust boundaries
- Supabase Auth authenticates employees; public consumers do not need accounts.
- Postgres RLS enforces membership to an organization and its role.
- A manufacturer can create product and batch metadata only within its own organization.
- Serial generation must occur only within a trusted backend after role checks. No public/anon direct writes to units.
- Custody events are server-authorized operations that verify sender ownership, receiver organization, and unit state.
- Public verification uses a throttled server endpoint, not direct SELECT on serial tables.
- A valid digital identity never asserts physical authenticity, quality or safety.

## Entities
organizations, memberships, products, batches, serialized_units, custody_events, verification_events, fraud_alerts, recalls, audit_events.

## Role capabilities
- manufacturer_admin: create/update own product catalog, create batches, request issuance; see own issued units.
- manufacturer_operator: view own catalog, submit dispatch requests for approved units.
- retailer_admin: receive explicitly dispatched units to own retailer organization; inventory visibility.
- retailer_operator: receive inventory, report suspicious stock.
- platform_admin: case triage using separate server-side operations, not a universal client bypass.
- consumer: anonymous verification via a public server route; no registry access.

## Unit state transition model
issued -> dispatched -> received -> sold; rejected receipts and quarantines are additional state branches. A duplicated receipt is idempotent if its event idempotency key matches, otherwise rejected.

## Public verification outcomes
- matched_record: code exists and is not blocked; NOT proof that physical product is safe.
- caution: inconsistent logistics or other anomalies.
- do_not_use: expired, recalled, blocked or confirmed high-priority alert.
- unverifiable: not enrolled, unknown code, or insufficient evidence.
- service_unavailable: retry later.

## Data protections
- Synthetic data only during development.
- Keep service-role secrets out of the repository and browser bundles.
- Use signed-in employee JWTs; deny by default at tables.
- Only trusted functions can append custody/verification/audit events.
- Avoid immutable claims until append-only enforcement and audit retention are implemented.
- Avoid personal information and precise consumer tracking during development.

## Production gate
RLS and cross-tenant tests, per-route authorization, rate-limiting, serial uniqueness, idempotency, incident handling, threat modeling, load testing and independent security review.
