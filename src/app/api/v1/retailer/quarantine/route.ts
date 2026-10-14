import {NextRequest} from 'next/server';import {z} from 'zod';import {authorize} from '@/lib/authorization';import {error,ok} from '@/lib/response';
const schema=z.object({organization_id:z.string().uuid(),unit_id:z.string().uuid(),reason:z.string().trim().min(10).max(500),idempotency_key:z.string().min(12).max(120)});
export async function POST(req:NextRequest){
 let input;try{input=schema.parse(await req.json())}catch{return error('Invalid quarantine request',422)}
 try{
 const a=await authorize(req,input.organization_id,['retailer_admin','retailer_operator']);if(!a)return error('Forbidden',403);
 const {data,error:e}=await a.db.rpc('retailer_quarantine_unit',{p_org_id:input.organization_id,p_unit_id:input.unit_id,p_reason:input.reason,p_idempotency_key:input.idempotency_key});
 if(e)return error('Quarantine rejected',409);
 return ok({event_id:data,status:'quarantined',unit_id:input.unit_id},201);
 }catch{return error('Service unavailable',503)}
}
