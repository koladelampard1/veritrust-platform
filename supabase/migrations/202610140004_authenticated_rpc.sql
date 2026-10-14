-- Harden issuance RPC for authenticated callers. Enforce caller identity as well as org role.
create or replace function public.issue_units(p_batch_id uuid,p_issuer_org uuid,p_actor_id uuid,p_digests text[])
returns table(id uuid,serial_digest text)
language plpgsql security definer set search_path=''
as $$
declare n integer; k text; u uuid;
begin
 if auth.uid() is null or auth.uid() <> p_actor_id then raise exception 'Unauthorized caller';end if;
 n:=coalesce(array_length(p_digests,1),0);
 if n<1 or n>100 then raise exception 'Invalid quantity';end if;
 if exists(select 1 from unnest(p_digests) d group by d having count(*)>1) then raise exception 'Duplicate digests';end if;
 if not exists(
  select 1 from public.batches b join public.products p on p.id=b.product_id
  join public.organizations o on o.id=p.manufacturer_id
  where b.id=p_batch_id and p.manufacturer_id=p_issuer_org and o.kind='manufacturer'
 ) then raise exception 'Issuer does not own batch';end if;
 if not exists(select 1 from public.memberships m
 where m.organization_id=p_issuer_org and m.user_id=auth.uid()
 and m.role='manufacturer_admin') then raise exception 'Unauthorized issuance';end if;
 foreach k in array p_digests loop
  if length(k)<>64 or k !~ '^[0-9a-f]{64}$' then raise exception 'Invalid digest';end if;
  insert into public.serialized_units(batch_id,serial_digest,current_holder_id,status)
  values(p_batch_id,k,p_issuer_org,'issued') returning serialized_units.id into u;
  insert into public.custody_events(unit_id,kind,to_org_id,initiated_by,idempotency_key,metadata)
  values(u,'issued',p_issuer_org,auth.uid(),'issue-'||u::text,'{"synthetic":true}'::jsonb);
  insert into public.audit_events(actor_user_id,entity_type,entity_id,action)
  values(auth.uid(),'serialized_unit',u,'issued');
  id:=u;serial_digest:=k;return next;
 end loop;
end;
$$;
revoke all on function public.issue_units(uuid,uuid,uuid,text[]) from public,anon,authenticated;
grant execute on function public.issue_units(uuid,uuid,uuid,text[]) to authenticated,service_role;

-- Privately inspect a token digest under a validated signed-in Supabase JWT.
-- Only limited result fields; no direct exposure of the registry.
create or replace function public.verify_unit_digest(p_digest text)
returns table(unit_exists boolean,unit_status text,lot_code text,expires_on date,has_recall boolean,has_alert boolean)
language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if length(p_digest)<>64 or p_digest !~ '^[0-9a-f]{64}$' then raise exception 'Invalid digest';end if;
 return query select true,u.status::text,b.lot_code,b.expires_on,
 exists(select 1 from public.recalls r where r.batch_id=b.id and r.active),
 exists(select 1 from public.fraud_alerts a where a.unit_id=u.id and a.state<>'resolved')
 from public.serialized_units u join public.batches b on b.id=u.batch_id
 where u.serial_digest=p_digest limit 1;
 if not found then return query select false,null::text,null::text,null::date,false,false;end if;
end;
$$;
revoke all on function public.verify_unit_digest(text) from public,anon,authenticated;
grant execute on function public.verify_unit_digest(text) to authenticated;
