import {NextRequest} from 'next/server';
import {actor} from '@/lib/authorization';
import {error,ok} from '@/lib/response';
export async function GET(req:NextRequest){
 try{
 const a=await actor(req);if(!a)return error('Unauthorized',401);
 const {data,error:e}=await a.db.from('memberships').select('organization_id,role,organizations(id,name,kind)').in('role',['manufacturer_admin','manufacturer_operator']).limit(50);
 if(e)return error('Unable to retrieve organizations',500);
 return ok({user_id:a.userId,memberships:data??[]});
 }catch{return error('Service unavailable',503)}
}
