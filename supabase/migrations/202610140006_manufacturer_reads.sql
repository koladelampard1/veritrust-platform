-- Manufacturer portal read models. All functions are scoped to authenticated organization members.
create or replace function public.manufacturer_destinations(p_org_id uuid)
returns table(id uuid,name text,kind public.org_kind)
language sql stable security definer set search_path=''
as $$
 select o.id,o.name,o.kind
 from public.organizations o
 where o.id<>p_org_id and o.kind in ('retailer','distributor')
 and o.is_demo=true
 and exists(select 1 from public.memberships m
 where m.user_id=auth.uid() and m.organization_id=p_org_id
 and m.role in ('manufacturer_admin','manufacturer_operator'))
 order by o.name limit 100;
$$;
revoke all on function public.manufacturer_destinations(uuid) from public,anon,authenticated;
grant execute on function public.manufacturer_destinations(uuid) to authenticated;

create or replace function public.manufacturer_activity(p_org_id uuid)
returns table(id uuid,unit_id uuid,kind public.event_kind,from_org text,to_org text,occurred_at timestamptz)
language sql stable security definer set search_path=''
as $$
 select e.id,e.unit_id,e.kind,src.name,dest.name,e.occurred_at
 from public.custody_events e
 left join public.organizations src on src.id=e.from_org_id
 left join public.organizations dest on dest.id=e.to_org_id
 where exists (select 1 from public.memberships m where m.user_id=auth.uid()
 and m.organization_id=p_org_id and m.role in ('manufacturer_admin','manufacturer_operator'))
 and (e.from_org_id=p_org_id or e.to_org_id=p_org_id)
 order by e.occurred_at desc,e.id desc
 limit 100;
$$;
revoke all on function public.manufacturer_activity(uuid) from public,anon,authenticated;
grant execute on function public.manufacturer_activity(uuid) to authenticated;
