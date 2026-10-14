-- Public gateway RPC: signed server secret is verified at the database boundary.
-- The raw secret is NEVER persisted: consumer_gateway_settings.gateway_secret contains SHA-256 hex only.
create or replace function public.consumer_gateway_verify(p_secret text,p_digest text,p_client text)
returns table(verification_state text,product_name text,manufacturer_name text,lot_code text,expires_on date)
language plpgsql security definer set search_path='' as $body$
begin
 if p_secret is null or length(p_secret)<48 or not exists(
 select 1 from public.consumer_gateway_settings s
 where s.id=1 and s.gateway_secret=encode(extensions.digest(p_secret,'sha256'),'hex')
 ) then raise exception 'Not authorized';end if;
 return query select * from public.consumer_pilot_verify(p_digest,p_client);
end; $body$;
create or replace function public.consumer_gateway_report(p_secret text,p_digest text,p_client text,p_reason text,p_details text)
returns uuid language plpgsql security definer set search_path='' as $body$
begin
 if p_secret is null or length(p_secret)<48 or not exists(
 select 1 from public.consumer_gateway_settings s
 where s.id=1 and s.gateway_secret=encode(extensions.digest(p_secret,'sha256'),'hex')
 ) then raise exception 'Not authorized';end if;
 return public.consumer_pilot_report(p_digest,p_client,p_reason,p_details);
end; $body$;
revoke all on function public.consumer_gateway_verify(text,text,text),public.consumer_gateway_report(text,text,text,text,text)
from public,anon,authenticated;
grant execute on function public.consumer_gateway_verify(text,text,text),public.consumer_gateway_report(text,text,text,text,text)
to anon,authenticated;
