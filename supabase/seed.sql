-- Synthetic-only sample organizations and inventory.
-- Apply to a dedicated development project, never production.
insert into public.organizations (id,name,kind,is_demo) values
 ('11111111-1111-4111-8111-111111111111','Demo Infant Nutrition Ltd','manufacturer',true),
 ('22222222-2222-4222-8222-222222222222','Demo Family Pharmacy','retailer',true)
on conflict (id) do nothing;

insert into public.products (id,manufacturer_id,product_name,sku,category,gtin) values
 ('33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','VeriTrust Demo Infant Formula 1','DEMO-FORMULA-1','infant_formula',null)
on conflict (id) do nothing;

insert into public.batches (id,product_id,lot_code,manufactured_on,expires_on) values
 ('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333','SYN-LOT-0001',date '2026-10-01',date '2027-10-01')
on conflict (id) do nothing;

-- These digests represent inert synthetic identifiers, not production security tokens.
insert into public.serialized_units(id,batch_id,serial_digest,current_holder_id,status) values
 ('55555555-5555-4555-8555-555555555551','44444444-4444-4444-8444-444444444444',encode(digest('demo-unit-1','sha256'),'hex'),'11111111-1111-4111-8111-111111111111','issued'),
 ('55555555-5555-4555-8555-555555555552','44444444-4444-4444-8444-444444444444',encode(digest('demo-unit-2','sha256'),'hex'),'11111111-1111-4111-8111-111111111111','issued'),
 ('55555555-5555-4555-8555-555555555553','44444444-4444-4444-8444-444444444444',encode(digest('demo-unit-3','sha256'),'hex'),'11111111-1111-4111-8111-111111111111','issued')
on conflict (id) do nothing;

insert into public.custody_events (id,unit_id,kind,to_org_id,idempotency_key,metadata) values
 ('66666666-6666-4666-8666-666666666651','55555555-5555-4555-8555-555555555551','issued','11111111-1111-4111-8111-111111111111','seed-issue-1','{"synthetic":true}'),
 ('66666666-6666-4666-8666-666666666652','55555555-5555-4555-8555-555555555552','issued','11111111-1111-4111-8111-111111111111','seed-issue-2','{"synthetic":true}'),
 ('66666666-6666-4666-8666-666666666653','55555555-5555-4555-8555-555555555553','issued','11111111-1111-4111-8111-111111111111','seed-issue-3','{"synthetic":true}')
on conflict (id) do nothing;
