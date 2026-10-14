import {NextRequest} from 'next/server';import {z} from 'zod';import {authorize} from '@/lib/authorization';import {tokenDigest} from '@/lib/identifiers';import {error,ok} from '@/lib/response';
const schema=z.object({organization_id:z.string().uuid(),token:z.string().min(16).max(256)});
export async function POST(req:NextRequest){
 let input;try{input=schema.parse(await req.json())}catch{return error('Invalid scan request',422)}
 try{
 const a=await authorize(req,input.organization_id,['retailer_admin','retailer_operator']);if(!a)return error('Forbidden',403);
 const {data,error:e}=await a.db.rpc('retailer_scan_unit',{p_org_id:input.organization_id,p_digest:tokenDigest(input.token)});
 if(e)return error('Verification unavailable',503);
 const row=(data as Array<Record<string,unknown>>|null)?.[0];
 if(!row)return error('Verification unavailable',503);
 return ok({result:row,message:row.verification_state==='matched_record'?'Digital record matched. This is not a guarantee of physical authenticity or product safety.':row.verification_state==='do_not_use'?'Do not use or sell this unit. Isolate it for investigation.':'Unable to certify this physical product. Review the warning.'});
 }catch{return error('Verification unavailable',503)}
}
