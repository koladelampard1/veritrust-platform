import {NextRequest} from 'next/server';import {z} from 'zod';import {actor} from '@/lib/authorization';import {adminDb} from '@/lib/supabase';import {tokenDigest} from '@/lib/identifiers';import {error,ok} from '@/lib/response';import {evaluate} from '@/lib/verification';
const schema=z.object({token:z.string().min(16).max(256)});
export async function POST(req:NextRequest){let body;try{body=schema.parse(await req.json())}catch{return error('Invalid token',422)}
// Authenticated DEMO endpoint only. Public endpoint requires durable per-client rate-limiting and abuse controls.
try{const a=await actor(req);if(!a)return error('Unauthorized; public verification not yet enabled',401);const db=adminDb();const digest=tokenDigest(body.token);const {data:unit,error:e}=await db.from('serialized_units').select('id,batch_id,status').eq('serial_digest',digest).maybeSingle();if(e)return error('Verification unavailable',503);
if(!unit)return ok({state:'unverifiable',message:'No matching enrolled record. This does not establish counterfeiting.'});
const [{data:batch},{data:recalls},{data:alerts}]=await Promise.all([db.from('batches').select('expires_on,lot_code').eq('id',unit.batch_id).single(),db.from('recalls').select('id').eq('batch_id',unit.batch_id).eq('active',true).limit(1),db.from('fraud_alerts').select('severity').eq('unit_id',unit.id).neq('state','resolved')]);
if(!batch)return error('Verification unavailable',503);
const state=evaluate({known:true,expired:batch.expires_on<new Date().toISOString().slice(0,10),recalled:(recalls?.length??0)>0,blocked:unit.status==='blocked',suspicious:(alerts?.length??0)>0});
await db.from('verification_events').insert({unit_id:unit.id,result:state,metadata:{source:'authenticated_demo'}});
return ok({state,lot_code:batch.lot_code,message:state==='matched_record'?'Digital record matched; physical authenticity and safety are not certified.':'Check product record and any warnings before use.'})}catch{return error('Verification unavailable',503)}}
