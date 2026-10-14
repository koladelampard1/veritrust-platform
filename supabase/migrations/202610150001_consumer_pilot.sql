-- VeriTrust synthetic consumer pilot: closed-by-default gateway, bounded anonymous lookups and reports.
-- All RPCs require the server-side service_role. Direct anonymous and authenticated calls are forbidden.
create table public.consumer_gateway_settings (
  id smallint primary key check(id=1),
  gateway_secret text not null check(length(gateway_secret)>=48),
  created_at timestamptz not null default now()
);
alter table public.consumer_gateway_settings enable row level security;
revoke all on public.consumer_gateway_settings from anon,authenticated;

create table public.consumer_rate_windows (
  bucket text not null,
  window_start timestamptz not null,
  requests integer not null default 0 check(requests>=0),
  primary key(bucket,window_start)
);
alter table public.consumer_rate_windows enable row level security;
revoke all on public.consumer_rate_windows from anon,authenticated;

create table public.consumer_reports (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid references public.serialized_units(id),
  reason text not null check(reason in ('suspected_tampering','altered_expiry','unexpected_packaging','adverse_effect','other')),
  details text not null check(char_length(details) between 10 and 800),
  reference_code text not null unique,
  source text not null default 'consumer',
  status text not null default 'new' check(status in ('new','reviewing','closed')),
  submitted_at timestamptz not null default now()
);
alter table public.consumer_reports enable row level security;
revoke all on public.consumer_reports from anon,authenticated;

create or replace function public.consumer_pilot_limit(p_client text,p_action text)
returns boolean language plpgsql security definer set search_path = ''
as $$
declare v_bucket text;v_start timestamptz;v_count integer;
begin
 if char_length(p_client)<>64 or p_client !~ '^[0-9a-f]{64}$' then raise exception 'Invalid client';end if;
 if p_action not in ('verify','report') then raise exception 'Invalid action';end if;
 -- This check and update is serialized per rate-limit bucket to avoid concurrent limit bypass.
 v_start:=to_timestamp(floor(extract(epoch from clock_timestamp())/900)*900);
 v_bucket:=p_action||':'||p_client;
 insert into public.consumer_rate_windows(bucket,window_start,requests)
 values(v_bucket,v_start,1)
 on conflict(bucket,window_start) do update set requests=public.consumer_rate_windows.requests+1
 returning requests into v_count;
 if v_count>case when p_action='verify' then 20 else 5 end then
  return false;
 end if;
 v_start:=to_timestamp(floor(extract(epoch from clock_timestamp())/60)*60);
 v_bucket:='global:'||p_action;
 insert into public.consumer_rate_windows(bucket,window_start,requests)
 values(v_bucket,v_start,1)
 on conflict(bucket,window_start) do update set requests=public.consumer_rate_windows.requests+1
 returning requests into v_count;
 if v_count>case when p_action='verify' then 300 else 50 end then
  return false;
 end if;
 return true;
end; $;

create or replace function public.consumer_pilot_verify(p_digest text,p_client text)
returns table(verification_state text,product_name text,manufacturer_name text,lot_code text,expires_on date)
language plpgsql security definer set search_path = ''
as $$
declare v_unit public.serialized_units%rowtype;v_batch public.batches%rowtype;v_product public.products%rowtype;v_mfr text;v_state text;
begin
 if not public.consumer_pilot_limit(p_client,'verify') then
 return query select 'rate_limited'::text,null::text,null::text,null::text,null::date;return;
 end if;
 if p_digest !~ '^[a-f0-9]{64}$' then raise exception 'Invalid digest'; end if;
 select * into v_unit from public.serialized_units where serial_digest=p_digest;
 if not found then
   insert into public.verification_events(result,metadata)
   values('unverifiable',jsonb_build_object('channel','public_pilot','reason','unknown_identifier'));
   return query select 'unverifiable'::text,null::text,null::text,null::text,null::date;return;
 end if;
 select * into v_batch from public.batches where id=v_unit.batch_id;
 select * into v_product from public.products where id=v_batch.product_id;
 select name into v_mfr from public.organizations where id=v_product.manufacturer_id;
 v_state:=case when v_batch.expires_on<current_date or v_unit.status in ('blocked','quarantined')
   or exists(select 1 from public.recalls r where r.batch_id=v_batch.id and r.active)
 then 'do_not_use'
 when exists(select 1 from public.fraud_alerts a where a.unit_id=v_unit.id and a.state<>'resolved')
 then 'caution'
 else 'matched_record' end;
 insert into public.verification_events(unit_id,result,metadata)
 values(v_unit.id,v_state,jsonb_build_object('channel','public_pilot'));
 return query select v_state,v_product.product_name,v_mfr,v_batch.lot_code,v_batch.expires_on;
end; $;

create or replace function public.consumer_pilot_report(p_digest text,p_client text,p_reason text,p_details text)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_unit uuid;v_id uuid;
begin
 if not public.consumer_pilot_limit(p_client,'report') then return null;end if;
 if p_reason not in ('suspected_tampering','altered_expiry','unexpected_packaging','adverse_effect','other')
   then raise exception 'Invalid reason';end if;
 if char_length(trim(p_details))<10 or char_length(p_details)>800 then raise exception 'Invalid description';end if;
 if p_digest is not null then
  if p_digest !~ '^[a-f0-9]{64}$' then raise exception 'Invalid digest';end if;
  select id into v_unit from public.serialized_units where serial_digest=p_digest;
 end if;
 insert into public.consumer_reports(unit_id,reason,details,reference_code)
 values(v_unit,p_reason,trim(p_details),upper(substr(encode(gen_random_bytes(10),'hex'),1,16)))
 returning id into v_id;
 return v_id;
end; $;
revoke all on function public.consumer_pilot_limit(text,text),
 public.consumer_pilot_verify(text,text),public.consumer_pilot_report(text,text,text,text)
 from public,anon,authenticated;
grant execute on function public.consumer_pilot_limit(text,text),
 public.consumer_pilot_verify(text,text),public.consumer_pilot_report(text,text,text,text) to service_role;
