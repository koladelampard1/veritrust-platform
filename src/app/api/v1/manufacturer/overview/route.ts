import {NextRequest} from 'next/server';
import {z} from 'zod';import {authorize} from '@/lib/authorization';import {error,ok} from '@/lib/response';
export async function GET(req:NextRequest){
 const org=req.nextUrl.searchParams.get('organization_id');
 if(!org||!z.string().uuid().safeParse(org).success)return error('Valid organization_id required',422);
 try{
 const a=await authorize(req,org,['manufacturer_admin','manufacturer_operator']);if(!a)return error('Forbidden',403);
 const {data:products,error:pe}=await a.db.from('products').select('id,product_name,sku,category,gtin,created_at').eq('manufacturer_id',org).order('created_at',{ascending:false}).limit(100);
 if(pe)return error('Unable to load catalog',500);
 const ids=(products??[]).map(p=>p.id);
 const batches=ids.length?await a.db.from('batches').select('id,product_id,lot_code,expires_on,manufactured_on,created_at').in('product_id',ids).order('created_at',{ascending:false}).limit(300):{data:[],error:null};
 if(batches.error)return error('Unable to load batches',500);
 const {data:inventory,error:ie}=await a.db.from('serialized_units').select('id,batch_id,status,issued_at').eq('current_holder_id',org).limit(1000);
 if(ie)return error('Unable to load inventory',500);
 const [{data:activity,error:ae},{data:destinations,error:de}]=await Promise.all([
 a.db.rpc('manufacturer_activity',{p_org_id:org}),
 a.db.rpc('manufacturer_destinations',{p_org_id:org})
 ]);
 if(ae||de)return error('Unable to load supply chain',500);
 return ok({products:products??[],batches:batches.data??[],inventory:inventory??[],activity:activity??[],destinations:destinations??[],
 counts:{products:(products??[]).length,batches:(batches.data??[]).length,inventory:(inventory??[]).length}});
 }catch{return error('Service unavailable',503)}
}
