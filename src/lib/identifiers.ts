import {createHmac,randomBytes} from 'node:crypto';
export function generateTokens(count:number){if(!Number.isInteger(count)||count<1||count>1000)throw new Error('Invalid unit count');return Array.from({length:count},()=>randomBytes(24).toString('base64url'));}
export function tokenDigest(token:string){const key=process.env.VERITRUST_SERIAL_HMAC_KEY;if(!key||key.length<32)throw new Error('Missing secure serialization key');return createHmac('sha256',key).update(token).digest('hex');}
