-- VeriTrust consumer pilot: anonymous lookup and persistent safety concerns.
-- Direct table access is denied to anonymous users. Only constrained RPCs exposed.
create table if not exists public.public_rate_buckets(
 bucket_key text not null,
 window_start timestamptz not null,
 attempts integer not null default 0,
 primary key(bucket_key,window_start)
);
create table if not exists public.consumer_reports(
 id uuid primary key default gen_random_uuid(),
 created_at timestamptz not null default now(),
 category text not null check(category in ('tampered_seal','altered_expiry','unexpected_packaging','adverse_reaction','other')),
 description text not null check(length(description) between 10 and 800),
 serial_digest text,
 scan_result text check(scan_result is null or scan_result in ('matched_record','caution','do_not_use','unverifiable','service_unavailable')),
 review_state text not null default 'new' check(review_state in ('new','triaged','investigating','closed')),
 source text not null default 'consumer_web',
 is_synthetic boolean not null default true
);
create index if not exists consumer_reports_recent on public.consumer_reports(created_at desc);
create index if not exists consumer_reports_state on public.consumer_reports(review_state,created_at desc);
alter table public.public_rate_buckets enable row level security;
alter table public.consumer_reports enable row level security;
revoke all on public.public_rate_buckets,public.consumer_reports from anon,authenticated;

create or replace function public._consume_public_bucket(p_bucket text,p_limit integer,p_seconds integer)
returns boolean language plpgsql volatile security definer set search_path='' as $$
declare v_count integer;v_window timestamptz;
begin
 if p_seconds not in (60,86400) or p_limit<1 or p_limit>10000 or length(p_bucket)>150 then return false;end if;
 v_window:=to_timestamp(floor(extract(epoch from clock_timestamp())/p_seconds)*p_seconds);
 insert into public.public_rate_buckets(bucket_key,window_start,attempts)
 values(p_bucket,v_window,1)
 on conflict(bucket_key,window_start) do update set attempts=public.public_rate_buckets.attempts+1
 returning attempts into v_count;
 return v_count<=p_limit;
end;$$;
revoke all on function public._consume_public_bucket(text,integer,integer) from public,anon,authenticated;

create or replace function public.public_verify_digest(p_digest text,p_actor_key text)
returns table(state text, product_name text, manufacturer_name text,lot_code text,expires_on date,advice text)
language plpgsql volatile security definer set search_path='' as $$
declare u public.serialized_units%rowtype;b public.batches%rowtype;p public.products%rowtype;
v_manufacturer text;v_state text;
begin
 if p_digest !~ '^[0-9a-f]{64}$' or p_actor_key !~ '^[0-9a-f]{64}$'
 then raise exception 'Invalid verification input';end if;
 if not public._consume_public_bucket('public:verify:global',360,60)
 or not public._consume_public_bucket('public:verify:actor:'||p_actor_key,12,60)
 or not public._consume_public_bucket('public:verify:unit:'||p_digest,120,86400)
 then raise exception 'Too many verification requests';end if;
 select * into u from public.serialized_units where serial_digest=p_digest;
 if not found then
  insert into public.verification_events(result,metadata)
  values('unverifiable',jsonb_build_object('source','consumer_pilot','actor_key',left(p_actor_key,12)));
  return query select 'unverifiable'::text,null::text,null::text,null::text,null::date,
   'Identifier not found in this synthetic registry. This does not establish counterfeiting.'::text;
  return;
 end if;
 select * into b from public.batches where id=u.batch_id;
 select * into p from public.products where id=b.product_id;
 select name into v_manufacturer from public.organizations where id=p.manufacturer_id;
 v_state:=case
 when u.status in ('quarantined','blocked') or b.expires_on<current_date
  or exists(select 1 from public.recalls r where r.batch_id=b.id and r.active)
 then 'do_not_use'
 when exists(select 1 from public.fraud_alerts f where f.unit_id=u.id and f.state<>'resolved')
 then 'caution'
 else 'matched_record' end;
 insert into public.verification_events(unit_id,result,metadata)
 values(u.id,v_state,jsonb_build_object('source','consumer_pilot','actor_key',left(p_actor_key,12)));
 return query select v_state,p.product_name,v_manufacturer,b.lot_code,b.expires_on,
 case when v_state='do_not_use' then 'Do not use or sell this product. Isolate it and contact the seller.'
 when v_state='caution' then 'Suspicious activity is under review. Do not rely on the code alone.'
 else 'A digital registry record matched. This does NOT prove the physical product is genuine, safe, or correctly formulated.' end;
end;$$;

create or replace function public.public_submit_concern(
 p_actor_key text,p_category text,p_description text,p_digest text default null,
 p_scan_result text default null)
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare v_id uuid;
begin
 if p_actor_key !~ '^[0-9a-f]{64}$'
 or p_category not in ('tampered_seal','altered_expiry','unexpected_packaging','adverse_reaction','other')
 or length(trim(coalesce(p_description,''))) not between 10 and 800
 or (p_digest is not null and p_digest !~ '^[0-9a-f]{64}$')
 or (p_scan_result is not null and p_scan_result not in ('matched_record','caution','do_not_use','unverifiable','service_unavailable'))
 then raise exception 'Invalid report'; end if;
 if not public._consume_public_bucket('public:report:global',120,60)
 or not public._consume_public_bucket('public:report:actor:'||p_actor_key,3,86400)
 then raise exception 'Too many reports';end if;
 insert into public.consumer_reports(category,description,serial_digest,scan_result,is_synthetic)
 values(p_category,trim(p_description),p_digest,p_scan_result,true)
 returning id into v_id;
 return v_id;
end;$$;
revoke all on function public.public_verify_digest(text,text),
 public.public_submit_concern(text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.public_verify_digest(text,text),
 public.public_submit_concern(text,text,text,text,text) to anon,authenticated;
-- No read/update/delete policies on consumer_reports or rate buckets.
