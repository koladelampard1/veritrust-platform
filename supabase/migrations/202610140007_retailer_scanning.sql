-- Retailer scoped stock visibility, token checks and quarantine, synthetic development environment.
create or replace function public.retailer_inventory(p_org_id uuid)
returns table(unit_id uuid, batch_id uuid, status text, product_name text, sku text,
  lot_code text, expires_on date, manufacturer_name text, recalled boolean, flagged boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not exists (
   select 1 from public.memberships m where m.user_id=auth.uid()
    and m.organization_id=p_org_id and m.role in ('retailer_admin','retailer_operator')
 ) then raise exception 'Retailer membership required'; end if;
 return query
 select u.id,u.batch_id,u.status::text,p.product_name,p.sku,b.lot_code,b.expires_on,
        manufacturer.name,
        exists(select 1 from public.recalls r where r.batch_id=b.id and r.active),
        exists(select 1 from public.fraud_alerts f where f.unit_id=u.id and f.state<>'resolved')
 from public.serialized_units u
 join public.batches b on b.id=u.batch_id
 join public.products p on p.id=b.product_id
 join public.organizations manufacturer on manufacturer.id=p.manufacturer_id
 where u.current_holder_id=p_org_id and u.status in ('received','quarantined','blocked')
 order by u.issued_at desc limit 500;
end; $$;

create or replace function public.retailer_incoming(p_org_id uuid)
returns table(unit_id uuid, batch_id uuid, product_name text, sku text, lot_code text,
  expires_on date, sender_name text, dispatch_event_id uuid, dispatched_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not exists (
  select 1 from public.memberships m where m.user_id=auth.uid()
  and m.organization_id=p_org_id and m.role in ('retailer_admin','retailer_operator')
 ) then raise exception 'Retailer membership required';end if;
 return query
 select u.id,u.batch_id,p.product_name,p.sku,b.lot_code,b.expires_on,origin.name,e.id,e.occurred_at
 from public.custody_events e
 join public.serialized_units u on u.id=e.unit_id
 join public.batches b on b.id=u.batch_id
 join public.products p on p.id=b.product_id
 join public.organizations origin on origin.id=e.from_org_id
 where e.kind='dispatched' and e.to_org_id=p_org_id and u.status='dispatched'
 and u.current_holder_id=e.from_org_id
 and e.id = (select e2.id from public.custody_events e2
   where e2.unit_id=u.id and e2.kind='dispatched'
   order by e2.occurred_at desc,e2.id desc limit 1)
 order by e.occurred_at desc limit 500;
end; $$;

create or replace function public.retailer_scan_unit(p_org_id uuid,p_digest text)
returns table(unit_id uuid, verification_state text, location_state text, product_name text,sku text,
 lot_code text,expires_on date,manufacturer_name text,dispatched_to_org boolean)
language plpgsql security definer set search_path='' as $$
declare v_unit public.serialized_units%rowtype; v_batch public.batches%rowtype;
 v_product public.products%rowtype; v_manufacturer text;v_state text;v_location text;
 v_authorized boolean := false;v_dispatched boolean := false;
begin
 if auth.uid() is null or not exists (
  select 1 from public.memberships m where m.user_id=auth.uid()
  and m.organization_id=p_org_id and m.role in ('retailer_admin','retailer_operator')
 ) then raise exception 'Retailer membership required';end if;
 if p_digest !~ '^[a-f0-9]{64}$' then raise exception 'Invalid digest';end if;
 select * into v_unit from public.serialized_units where serial_digest=p_digest;
 if not found then
  insert into public.verification_events(result,metadata)
   values('unverifiable',jsonb_build_object('channel','retailer','org_id',p_org_id,'reason','unknown_identifier'));
  return query select null::uuid,'unverifiable'::text,'unknown'::text,null::text,null::text,null::text,
   null::date,null::text,false;return;
 end if;
 if v_unit.current_holder_id=p_org_id then
  v_authorized:=true;v_location:='in_inventory';
 elsif v_unit.status='dispatched' and exists (
  select 1 from public.custody_events e where e.unit_id=v_unit.id
  and e.kind='dispatched' and e.to_org_id=p_org_id
  and e.from_org_id=v_unit.current_holder_id
  and e.id=(select x.id from public.custody_events x where x.unit_id=e.unit_id and x.kind='dispatched'
    order by x.occurred_at desc,x.id desc limit 1)
 ) then
  v_authorized:=true;v_dispatched:=true;v_location:='incoming';
 end if;
 if not v_authorized then
  insert into public.verification_events(unit_id,result,metadata)
   values(v_unit.id,'caution',jsonb_build_object('channel','retailer','org_id',p_org_id,'reason','not_assigned_to_retailer'));
  return query select null::uuid,'caution'::text,'not_assigned'::text,null::text,null::text,null::text,
   null::date,null::text,false;return;
 end if;
 select * into v_batch from public.batches where id=v_unit.batch_id;
 select * into v_product from public.products where id=v_batch.product_id;
 select name into v_manufacturer from public.organizations where id=v_product.manufacturer_id;
 v_state:=case when v_unit.status in ('blocked','quarantined') or v_batch.expires_on<current_date
   or exists(select 1 from public.recalls r where r.batch_id=v_batch.id and r.active)
   then 'do_not_use'
   when exists(select 1 from public.fraud_alerts a where a.unit_id=v_unit.id and a.state<>'resolved')
   then 'caution'
   else 'matched_record' end;
 insert into public.verification_events(unit_id,result,metadata)
 values(v_unit.id,v_state,jsonb_build_object('channel','retailer','org_id',p_org_id,'location',v_location));
 return query select v_unit.id,v_state,v_location,v_product.product_name,v_product.sku,
   v_batch.lot_code,v_batch.expires_on,v_manufacturer,v_dispatched;
end; $$;

create or replace function public.retailer_quarantine_unit(
 p_org_id uuid,p_unit_id uuid,p_reason text,p_idempotency_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_unit public.serialized_units%rowtype;v_event uuid;
begin
 if auth.uid() is null or not exists (
  select 1 from public.memberships m where m.user_id=auth.uid()
  and m.organization_id=p_org_id and m.role in ('retailer_admin','retailer_operator')
 ) then raise exception 'Retailer membership required';end if;
 if char_length(trim(p_reason))<10 or char_length(p_reason)>500 then raise exception 'Provide a reason between 10 and 500 characters';end if;
 if char_length(p_idempotency_key)<12 or char_length(p_idempotency_key)>120 then raise exception 'Invalid idempotency key';end if;
 select id into v_event from public.custody_events
 where idempotency_key=p_idempotency_key and kind='quarantined' and unit_id=p_unit_id
 and to_org_id=p_org_id and initiated_by=auth.uid();
 if found then return v_event;end if;
 select * into v_unit from public.serialized_units where id=p_unit_id for update;
 if not found or v_unit.current_holder_id<>p_org_id or v_unit.status not in ('received','quarantined')
 then raise exception 'Unit not in retailer custody';end if;
 if v_unit.status='quarantined' then raise exception 'Already quarantined';end if;
 update public.serialized_units set status='quarantined' where id=p_unit_id;
 insert into public.custody_events(unit_id,kind,from_org_id,to_org_id,initiated_by,idempotency_key,metadata)
 values(p_unit_id,'quarantined',p_org_id,p_org_id,auth.uid(),p_idempotency_key,
 jsonb_build_object('reason',trim(p_reason),'synthetic',true)) returning id into v_event;
 insert into public.fraud_alerts(unit_id,rule_code,severity,state)
 values(p_unit_id,'RETAILER_QUARANTINE','high','open');
 insert into public.audit_events(actor_user_id,entity_type,entity_id,action)
 values(auth.uid(),'serialized_unit',p_unit_id,'quarantined');
 return v_event;
end; $$;

revoke all on function public.retailer_inventory(uuid),public.retailer_incoming(uuid),public.retailer_scan_unit(uuid,text),
public.retailer_quarantine_unit(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.retailer_inventory(uuid),public.retailer_incoming(uuid),public.retailer_scan_unit(uuid,text),
public.retailer_quarantine_unit(uuid,uuid,text,text) to authenticated;
