-- Authenticated, atomic dispatch and retailer receipt for synthetic prototype.
create or replace function public.dispatch_unit(
  p_unit_id uuid,p_destination_org uuid,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_unit public.serialized_units%rowtype; v_event uuid; v_caller uuid:=auth.uid();
begin
 if v_caller is null then raise exception 'Authentication required'; end if;
 if length(p_idempotency_key)<12 or length(p_idempotency_key)>120 then raise exception 'Invalid idempotency key'; end if;
 select id into v_event from public.custody_events
 where idempotency_key=p_idempotency_key and unit_id=p_unit_id and kind='dispatched'
 and initiated_by=v_caller and to_org_id=p_destination_org;
 if found then return v_event; end if;
 select * into v_unit from public.serialized_units where id=p_unit_id for update;
 if not found or v_unit.status not in ('issued','received') then raise exception 'Unit unavailable for dispatch'; end if;
 if not exists(select 1 from public.memberships m where m.user_id=v_caller
 and m.organization_id=v_unit.current_holder_id
 and m.role in ('manufacturer_admin','manufacturer_operator','retailer_admin')) then
 raise exception 'Not authorized to dispatch unit';end if;
 if not exists(select 1 from public.organizations o where o.id=p_destination_org
 and o.kind in ('retailer','distributor')) then raise exception 'Invalid recipient';end if;
 if p_destination_org=v_unit.current_holder_id then raise exception 'Cannot dispatch to same organization';end if;
 insert into public.custody_events(unit_id,kind,from_org_id,to_org_id,initiated_by,idempotency_key,metadata)
 values(p_unit_id,'dispatched',v_unit.current_holder_id,p_destination_org,v_caller,p_idempotency_key,'{"synthetic":true}'::jsonb)
 returning id into v_event;
 update public.serialized_units set status='dispatched' where id=p_unit_id;
 insert into public.audit_events(actor_user_id,entity_type,entity_id,action)
 values(v_caller,'serialized_unit',p_unit_id,'dispatched');
 return v_event;
end $$;

create or replace function public.receive_unit(
 p_unit_id uuid,p_receiver_org uuid,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_unit public.serialized_units%rowtype; v_dispatch public.custody_events%rowtype;
 v_event uuid; v_caller uuid:=auth.uid();
begin
 if v_caller is null then raise exception 'Authentication required';end if;
 if length(p_idempotency_key)<12 or length(p_idempotency_key)>120 then raise exception 'Invalid idempotency key';end if;
 select id into v_event from public.custody_events
 where idempotency_key=p_idempotency_key and unit_id=p_unit_id and kind='received'
 and initiated_by=v_caller and to_org_id=p_receiver_org;
 if found then return v_event;end if;
 if not exists(select 1 from public.memberships m where m.user_id=v_caller
 and m.organization_id=p_receiver_org and m.role in ('retailer_admin','retailer_operator')) then
 raise exception 'Not authorized to receive for organization';end if;
 select * into v_unit from public.serialized_units where id=p_unit_id for update;
 if not found or v_unit.status<>'dispatched' then raise exception 'No pending dispatch for unit';end if;
 select * into v_dispatch from public.custody_events where unit_id=p_unit_id
 and kind='dispatched' order by occurred_at desc,id desc limit 1;
 if not found or v_dispatch.to_org_id<>p_receiver_org
 or v_dispatch.from_org_id<>v_unit.current_holder_id then raise exception 'Dispatch recipient mismatch';end if;
 insert into public.custody_events(unit_id,kind,from_org_id,to_org_id,initiated_by,idempotency_key,metadata)
 values(p_unit_id,'received',v_unit.current_holder_id,p_receiver_org,v_caller,p_idempotency_key,
 jsonb_build_object('synthetic',true,'dispatch_event_id',v_dispatch.id)) returning id into v_event;
 update public.serialized_units set current_holder_id=p_receiver_org,status='received' where id=p_unit_id;
 insert into public.audit_events(actor_user_id,entity_type,entity_id,action)
 values(v_caller,'serialized_unit',p_unit_id,'received');
 return v_event;
end $$;
revoke all on function public.dispatch_unit(uuid,uuid,text),public.receive_unit(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.dispatch_unit(uuid,uuid,text),public.receive_unit(uuid,uuid,text) to authenticated;
