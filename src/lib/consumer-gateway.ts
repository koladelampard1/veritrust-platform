import {createHmac} from 'node:crypto';
import {createClient} from '@supabase/supabase-js';
import type {NextRequest} from 'next/server';
export function gatewayConfig(){
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
 const key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
 const secret=process.env.VERITRUST_CONSUMER_GATEWAY_SECRET;
 if(!url||!key||!secret||secret.length<48)throw new Error('Consumer gateway not configured');
 return {url,key,secret};
}
export function publicGateway(){
 const {url,key}=gatewayConfig();
 return createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
}
export function clientBucket(request:NextRequest){
 const {secret}=gatewayConfig();
 // Trusted edge client attribution when Vercel provides it; fallback to a shared bucket.
 const ip=request.headers.get('x-vercel-forwarded-for')?.split(',')[0]?.trim()||'unknown';
 const agent=request.headers.get('user-agent')?.slice(0,150)||'unknown';
 return createHmac('sha256',secret).update(ip+'|'+agent).digest('hex');
}
export function originAllowed(request:NextRequest){
 const origin=request.headers.get('origin');
 if(!origin)return true;
 try{const hostname=new URL(origin).hostname;return hostname==='veritrust-platform.vercel.app'||hostname==='localhost'||hostname.endsWith('.vercel.app')&&hostname.startsWith('veritrust-platform-')}catch{return false}
}
