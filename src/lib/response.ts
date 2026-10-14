import { NextResponse } from 'next/server';
export function error(message:string,status=400){return NextResponse.json({error:message},{status,headers:{'Cache-Control':'no-store'}})}
export function ok(value:unknown,status=200){return NextResponse.json(value,{status,headers:{'Cache-Control':'no-store'}})}
