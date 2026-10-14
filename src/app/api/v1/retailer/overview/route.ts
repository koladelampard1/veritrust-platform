import {NextRequest} from 'next/server';import {z} from 'zod';import {authorize} from '@/lib/authorization';import {error,ok} from '@/lib/response';
export async function GET(req:NextRequest){
 const org=req.nextUrl.searchParams.get('organization_id')||'';
 if(!z.string().uuid().safeParse(org).success)return error('Valid organization_id required',422);
 try{
  const a=await authorize(req,org,['retailer_admin','retailer_operator']);if(!a)return error('Forbidden',403);
  const [inventory,incoming]=await Promise.all([
    a.db.rpc('retailer_inventory',{p_org_id:org}),
    a.db.rpc('retailer_incoming',{p_org_id:org})
  ]);
  if(inventory.error||incoming.error)return error('Unable to read retailer records',500);
  return ok({inventory:inventory.data??[],incoming:incoming.data??[],counts:{held:(inventory.data??[]).length,pending:(incoming.data??[]).length,quarantined:(inventory.data??[]).filter((u:{status:string})=>u.status==='quarantined').length}});
 }catch{return error('Service unavailable',503)}
}
