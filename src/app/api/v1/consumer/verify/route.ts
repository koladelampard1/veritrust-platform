import {NextRequest,NextResponse} from 'next/server';
import {z} from 'zod';
import {tokenDigest} from '@/lib/identifiers';
import {clientBucket,gatewayConfig,originAllowed,publicGateway} from '@/lib/consumer-gateway';
export const runtime='nodejs';
const schema=z.object({token:z.string().trim().min(16).max(256)});
const headers={'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'};
export async function POST(request:NextRequest){
 if(!originAllowed(request))return NextResponse.json({error:'Forbidden'},{status:403,headers});
 if(Number(request.headers.get('content-length')||0)>2048)return NextResponse.json({error:'Payload too large'},{status:413,headers});
 let input;try{input=schema.parse(await request.json())}catch{return NextResponse.json({error:'Invalid product identifier'},{status:422,headers})}
 try{
 const {secret}=gatewayConfig();
 const {data,error}=await publicGateway().rpc('consumer_gateway_verify',{p_secret:secret,p_digest:tokenDigest(input.token),p_client:clientBucket(request)});
 if(error)return NextResponse.json({state:'service_unavailable',message:'Verification is temporarily unavailable.'},{status:503,headers});
 const record=(data as Array<{verification_state:string;product_name:string|null;manufacturer_name:string|null;lot_code:string|null;expires_on:string|null}>|null)?.[0];
 if(!record)return NextResponse.json({state:'service_unavailable',message:'Verification is temporarily unavailable.'},{status:503,headers});
 if(record.verification_state==='rate_limited')return NextResponse.json({error:'Too many checks. Please try again later.'},{status:429,headers:{...headers,'Retry-After':'900'}});
 const state=record.verification_state;
 const message=state==='matched_record'?'This digital identifier matches a synthetic product record. This does not prove physical authenticity or safety.':state==='do_not_use'?'Do not use or sell this product. Contact the retailer and relevant authorities.':state==='caution'?'The product record has a warning requiring review.':state==='unverifiable'?'We could not authenticate this identifier. This is not proof of counterfeiting.':'Verification is temporarily unavailable.';
 return NextResponse.json({state,product_name:record.product_name,manufacturer_name:record.manufacturer_name,lot_code:record.lot_code,expires_on:record.expires_on,message,demo:true},{headers});
 }catch{return NextResponse.json({state:'service_unavailable',message:'Verification is temporarily unavailable.'},{status:503,headers})}
}
