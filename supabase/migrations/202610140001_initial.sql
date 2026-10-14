-- VeriTrust prototype: initial database schema and tenant isolation policies
-- Synthetic development records ONLY.
create extension if not exists pgcrypto;

create type public.org_kind as enum ('manufacturer','distributor','retailer');
create type public.member_role as enum ('manufacturer_admin','manufacturer_operator','retailer_admin','retailer_operator','platform_admin');
create type public.unit_status as enum ('issued','dispatched','received','sold','quarantined','blocked');
create type public.event_kind as enum ('issued','dispatched','received','sold','quarantined','blocked');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind public.org_kind not null,
  is_demo boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.memberships (
  organization_id uuid not null references public.organizations(id),
  user_id uuid not null references auth.users(id),
  role public.member_role not null,
  created_at timestamptz not null default now(),
  primary key (organization_id,user_id)
);
create table public.products (
  id uuid primary key default gen_random_uuid(),
  manufacturer_id uuid not null references public.organizations(id),
  product_name text not null,
  sku text not null,
  gtin text,
  category text not null,
  created_at timestamptz not null default now(),
  unique(manufacturer_id,sku),
  unique(id,manufacturer_id)
);
create table public.batches (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  lot_code text not null,
  manufactured_on date,
  expires_on date not null,
  created_at timestamptz not null default now(),
  unique(product_id,lot_code),
  constraint batch_dates_ok check (manufactured_on is null or expires_on > manufactured_on)
);
create table public.serialized_units (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.batches(id),
  -- Digest only. Do not store easily enumerable or plain-text public scan tokens here.
  serial_digest text not null unique,
  current_holder_id uuid not null references public.organizations(id),
  status public.unit_status not null default 'issued',
  issued_at timestamptz not null default now(),
  unique(id,batch_id)
);
create table public.custody_events (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.serialized_units(id),
  kind public.event_kind not null,
  from_org_id uuid references public.organizations(id),
  to_org_id uuid references public.organizations(id),
  initiated_by uuid references auth.users(id),
  idempotency_key text not null unique,
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create table public.verification_events (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid references public.serialized_units(id),
  result text not null check (result in ('matched_record','caution','do_not_use','unverifiable','service_unavailable')),
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create table public.recalls (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.batches(id),
  reason text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.fraud_alerts (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid references public.serialized_units(id),
  rule_code text not null,
  severity text not null check (severity in ('low','medium','high')),
  state text not null default 'open' check (state in ('open','investigating','resolved')),
  created_at timestamptz not null default now()
);
create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id),
  entity_type text not null,
  entity_id uuid not null,
  action text not null,
  occurred_at timestamptz not null default now()
);

create index memberships_user_idx on public.memberships(user_id);
create index products_manufacturer_idx on public.products(manufacturer_id);
create index batches_product_idx on public.batches(product_id);
create index units_batch_idx on public.serialized_units(batch_id);
create index units_holder_idx on public.serialized_units(current_holder_id);
create index custody_unit_time_idx on public.custody_events(unit_id,occurred_at desc);
create index verification_unit_time_idx on public.verification_events(unit_id,occurred_at desc);

create function public.has_org_role(org_id uuid, allowed public.member_role[])
returns boolean language sql stable security definer
set search_path = ''
as $$
  select exists(
    select 1 from public.memberships m
    where m.organization_id = org_id
      and m.user_id = (select auth.uid())
      and m.role = any(allowed)
  );
$$;
revoke all on function public.has_org_role(uuid,public.member_role[]) from public;
grant execute on function public.has_org_role(uuid,public.member_role[]) to authenticated;

alter table public.organizations enable row level security;
alter table public.memberships enable row level security;
alter table public.products enable row level security;
alter table public.batches enable row level security;
alter table public.serialized_units enable row level security;
alter table public.custody_events enable row level security;
alter table public.verification_events enable row level security;
alter table public.recalls enable row level security;
alter table public.fraud_alerts enable row level security;
alter table public.audit_events enable row level security;

create policy org_member_read on public.organizations for select to authenticated
using (public.has_org_role(id,array['manufacturer_admin','manufacturer_operator','retailer_admin','retailer_operator','platform_admin']::public.member_role[]));
create policy own_membership_read on public.memberships for select to authenticated
using (user_id = (select auth.uid()));
create policy product_member_read on public.products for select to authenticated
using (public.has_org_role(manufacturer_id,array['manufacturer_admin','manufacturer_operator','platform_admin']::public.member_role[]));
create policy product_manufacturer_create on public.products for insert to authenticated
with check (public.has_org_role(manufacturer_id,array['manufacturer_admin']::public.member_role[]));
create policy batch_member_read on public.batches for select to authenticated
using (exists (
  select 1 from public.products p
  where p.id=product_id and public.has_org_role(p.manufacturer_id,array['manufacturer_admin','manufacturer_operator','platform_admin']::public.member_role[])
));
create policy batch_manufacturer_create on public.batches for insert to authenticated
with check (exists (
  select 1 from public.products p
  where p.id=product_id and public.has_org_role(p.manufacturer_id,array['manufacturer_admin']::public.member_role[])
));
create policy unit_holder_read on public.serialized_units for select to authenticated
using (
 public.has_org_role(current_holder_id,array['manufacturer_admin','manufacturer_operator','retailer_admin','retailer_operator','platform_admin']::public.member_role[])
 or exists (
  select 1 from public.batches b join public.products p on p.id=b.product_id
  where b.id=batch_id and public.has_org_role(p.manufacturer_id,array['manufacturer_admin','manufacturer_operator','platform_admin']::public.member_role[])
 )
);
-- No client-facing INSERT/UPDATE/DELETE policies for units or event tables.
-- Implement authorized transitions through audited server-only procedures.
revoke all on public.serialized_units,public.custody_events,public.verification_events,public.recalls,public.fraud_alerts,public.audit_events from anon;
-- No public SELECT policies on registry or serial identifiers.
