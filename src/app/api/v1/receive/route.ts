import {NextRequest} from 'next/server';
import {z} from 'zod';
import {actor,authorize} from '@/lib/authorization';
import {error,ok} from '@/lib/response';
const schema=z.object({unit_id:z.string().uuid(),receiver_org_id:z.string().uuid(),idempotency_key:z.string().min(12).max(120)});
export async function POST(req:NextRequest){
 let b;try{b=schema.parse(await req.json())}catch{return error('Invalid receiving request',422)}
 try{
  const a=await actor(req);if(!a)return error('Unauthorized',401);
  if(!await authorize(req,b.receiver_org_id,['retailer_admin','retailer_operator']))return error('Forbidden',403);
  const {data,error:e}=await a.db.rpc('receive_unit',{p_unit_id:b.unit_id,p_receiver_org:b.receiver_org_id,p_idempotency_key:b.idempotency_key});
  if(e)return error('Receipt rejected',409);
  return ok({event_id:data,unit_id:b.unit_id,status:'received'},201);
 }catch{return error('Service unavailable',503)}
}
