import {NextRequest} from 'next/server';
import {z} from 'zod';
import {actor,authorize} from '@/lib/authorization';
import {error,ok} from '@/lib/response';
const schema=z.object({unit_id:z.string().uuid(),destination_org_id:z.string().uuid(),idempotency_key:z.string().min(12).max(120)});
export async function POST(req:NextRequest){
 let b;try{b=schema.parse(await req.json())}catch{return error('Invalid dispatch request',422)}
 try{
  const a=await actor(req);if(!a)return error('Unauthorized',401);
  const {data:unit}=await a.db.from('serialized_units').select('current_holder_id,status').eq('id',b.unit_id).maybeSingle();
  if(!unit)return error('Forbidden',403);
  if(!await authorize(req,unit.current_holder_id,['manufacturer_admin','manufacturer_operator','retailer_admin']))return error('Forbidden',403);
  const {data,error:e}=await a.db.rpc('dispatch_unit',{p_unit_id:b.unit_id,p_destination_org:b.destination_org_id,p_idempotency_key:b.idempotency_key});
  if(e)return error('Dispatch rejected',409);
  return ok({event_id:data,unit_id:b.unit_id,status:'dispatched'},201);
 }catch{return error('Service unavailable',503)}
}
