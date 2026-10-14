import {describe,it,expect,vi,afterEach} from 'vitest';import {generateTokens,tokenDigest} from './identifiers';
afterEach(()=>vi.unstubAllEnvs());
describe('serial identifiers',()=>{
it('rejects unbounded issuance',()=>expect(()=>generateTokens(1001)).toThrow());
it('issues 200 distinct high entropy identifiers',()=>{const ts=generateTokens(200);expect(new Set(ts).size).toBe(200);expect(ts.every(t=>t.length>=32)).toBe(true)});
it('refuses missing signing key',()=>{vi.stubEnv('VERITRUST_SERIAL_HMAC_KEY','short');expect(()=>tokenDigest('token')).toThrow()});
it('creates stable keyed digests',()=>{vi.stubEnv('VERITRUST_SERIAL_HMAC_KEY','test-hmac-key-which-is-long-enough-123456');expect(tokenDigest('abc')).toBe(tokenDigest('abc'));expect(tokenDigest('abc')).not.toBe(tokenDigest('abd'))});
});
