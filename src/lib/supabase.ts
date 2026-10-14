import { createClient } from '@supabase/supabase-js';
function config(){const url=process.env.NEXT_PUBLIC_SUPABASE_URL;const anon=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;const role=process.env.SUPABASE_SERVICE_ROLE_KEY;if(!url||!anon||!role) throw new Error('Supabase environment is not configured');return {url,anon,role};}
export function adminDb(){const {url,role}=config();return createClient(url,role,{auth:{persistSession:false,autoRefreshToken:false}})}
export function authDb(jwt:string){const {url,anon}=config();return createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false},global:{headers:{Authorization:`Bearer ${jwt}`}}})}
