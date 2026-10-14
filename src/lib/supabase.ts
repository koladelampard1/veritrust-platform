import { createClient } from '@supabase/supabase-js';
function publicConfig(){
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
 const anon=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
 if(!url||!anon)throw new Error('Supabase public configuration is missing');
 return {url,anon};
}
export function adminDb(){
 const {url}=publicConfig();
 const role=process.env.SUPABASE_SERVICE_ROLE_KEY;
 if(!role)throw new Error('Server-only Supabase credential is not configured');
 return createClient(url,role,{auth:{persistSession:false,autoRefreshToken:false}});
}
export function authDb(jwt:string){
 const {url,anon}=publicConfig();
 return createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false},global:{headers:{Authorization:`Bearer ${jwt}`}}});
}
