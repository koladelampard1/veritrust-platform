import type { NextRequest } from 'next/server';
import { authDb } from './supabase';
export type Role='manufacturer_admin'|'manufacturer_operator'|'retailer_admin'|'retailer_operator'|'platform_admin';
export async function actor(req:NextRequest){const header=req.headers.get('authorization')??'';if(!header.startsWith('Bearer '))return null;const db=authDb(header.slice(7));const {data,error}=await db.auth.getUser(header.slice(7));if(error||!data.user)return null;return {db,userId:data.user.id};}
export async function authorize(req:NextRequest,orgId:string,roles:Role[]){const a=await actor(req);if(!a)return null;const {data,error}=await a.db.from('memberships').select('role').eq('organization_id',orgId).eq('user_id',a.userId).maybeSingle();if(error||!data||!roles.includes(data.role as Role))return null;return a;}
