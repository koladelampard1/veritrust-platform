-- Atomic issuance, preserving unit and event consistency.
-- Intended for Supabase development only until integration and RLS testing passes.
create or replace function public.issue_units(
 p_batch_id uuid,p_issuer_org uuid,p_actor_id uuid,p_digests text[]
) returns table(id uuid,serial_digest text)
language plpgsql security definer set search_path = ''
as $$
declare n integer; k text; u uuid;
begin
 n:=coalesce(array_length(p_digests,1),0);
 if n<1 or n>100 then raise exception 'Invalid issuance quantity';end if;
 if exists(select 1 from unnest(p_digests) d group by d having count(*)>1)
 then raise exception 'Duplicate digests in request';end if;
 if not exists (
 select 1 from public.batches b join public.products p on p.id=b.product_id
 join public.organizations o on o.id=p.manufacturer_id
 where b.id=p_batch_id and p.manufacturer_id=p_issuer_org and o.kind='manufacturer'
 ) then raise exception 'Issuer does not own batch';end if;
 if not exists(
 select 1 from public.memberships m where m.organization_id=p_issuer_org
 and m.user_id=p_actor_id and m.role='manufacturer_admin'
 ) then raise exception 'Unauthorized issuance';end if;
 foreach k in array p_digests loop
  if length(k)<>64 or k !~ '^[0-9a-f]{64}$' then raise exception 'Malformed digest';end if;
  insert into public.serialized_units(batch_id,serial_digest,current_holder_id,status)
  values(p_batch_id,k,p_issuer_org,'issued') returning serialized_units.id into u;
  insert into public.custody_events(unit_id,kind,to_org_id,initiated_by,idempotency_key,metadata)
  values(u,'issued',p_issuer_org,p_actor_id,'issue-'||u::text,'{"synthetic":true}'::jsonb);
  insert into public.audit_events(actor_user_id,entity_type,entity_id,action)
  values(p_actor_id,'serialized_unit',u,'issued');
  id:=u; serial_digest:=k; return next;
 end loop;
end;
$$;
revoke all on function public.issue_units(uuid,uuid,uuid,text[]) from public,anon,authenticated;
grant execute on function public.issue_units(uuid,uuid,uuid,text[]) to service_role;
