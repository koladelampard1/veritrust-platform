import {NextRequest} from 'next/server';
import {z} from 'zod';
import {actor} from '@/lib/authorization';
import {tokenDigest} from '@/lib/identifiers';
import {error,ok} from '@/lib/response';
import {evaluate} from '@/lib/verification';
const schema=z.object({token:z.string().min(16).max(256)});
export async function POST(req:NextRequest){
 let body;try{body=schema.parse(await req.json())}catch{return error('Invalid token',422)}
 // Authenticated DEMO only. Public verification needs durable throttling and abuse monitoring.
 try{
  const a=await actor(req);if(!a)return error('Unauthorized; public verification not enabled',401);
  const {data,error:e}=await a.db.rpc('verify_unit_digest',{p_digest:tokenDigest(body.token)});
  if(e)return error('Verification unavailable',503);
  const record=(data as Array<{unit_exists:boolean;unit_status:string|null;lot_code:string|null;expires_on:string|null;has_recall:boolean;has_alert:boolean}>|null)?.[0];
  if(!record||!record.unit_exists)return ok({state:'unverifiable',message:'No matching enrolled record; this does not establish counterfeiting.'});
  const state=evaluate({known:true,expired:!!record.expires_on&&record.expires_on<new Date().toISOString().slice(0,10),recalled:record.has_recall,blocked:record.unit_status==='blocked',suspicious:record.has_alert});
  return ok({state,lot_code:record.lot_code,message:state==='matched_record'?'Digital record matched; physical authenticity and safety are not certified.':'Review warnings before use.'});
 }catch{return error('Verification unavailable',503)}
}
