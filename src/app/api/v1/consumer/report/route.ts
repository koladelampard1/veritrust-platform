import {NextRequest,NextResponse} from 'next/server';
import {z} from 'zod';
import {tokenDigest} from '@/lib/identifiers';
import {clientBucket,gatewayConfig,originAllowed,publicGateway} from '@/lib/consumer-gateway';
export const runtime='nodejs';
const schema=z.object({
 token:z.string().trim().max(256).optional(),
 reason:z.enum(['suspected_tampering','altered_expiry','unexpected_packaging','adverse_effect','other']),
 details:z.string().trim().min(10).max(800)
});
const headers={'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'};
export async function POST(request:NextRequest){
 if(!originAllowed(request))return NextResponse.json({error:'Forbidden'},{status:403,headers});
 if(Number(request.headers.get('content-length')||0)>3000)return NextResponse.json({error:'Payload too large'},{status:413,headers});
 let body;try{body=schema.parse(await request.json());if(body.token&&body.token.length<16)throw Error()}catch{return NextResponse.json({error:'Invalid report'},{status:422,headers})}
 try{
 const {secret}=gatewayConfig();
 const {data,error}=await publicGateway().rpc('consumer_gateway_report',{
 p_secret:secret,p_digest:body.token?tokenDigest(body.token):null,
 p_client:clientBucket(request),p_reason:body.reason,p_details:body.details
 });
 if(error)return NextResponse.json({error:'Unable to save report. Try again later.'},{status:503,headers});
 if(!data)return NextResponse.json({error:'Too many reports. Please try again later.'},{status:429,headers:{...headers,'Retry-After':'900'}});
 return NextResponse.json({reference:data,status:'received',message:'Your concern has been saved in the VeriTrust demonstration system. This is not a regulatory submission.'},{status:201,headers});
 }catch{return NextResponse.json({error:'Report service unavailable'},{status:503,headers})}
}
