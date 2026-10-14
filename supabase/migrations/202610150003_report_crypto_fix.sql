create or replace function public.consumer_pilot_report(p_digest text,p_client text,p_reason text,p_details text)
returns uuid language plpgsql security definer set search_path=''
as $body$
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
 values(v_unit,p_reason,trim(p_details),upper(substr(encode(extensions.gen_random_bytes(10),'hex'),1,16)))
 returning id into v_id;
 return v_id;
end; $body$;
