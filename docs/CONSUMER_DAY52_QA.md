# VeriTrust Consumer Days 49–52 — QA and release record

## Implemented
- Public-facing synthetic product verification endpoint with server-secret authentication to database gateway.
- Supabase database RPCs restricted with privileged executor checks and server-side access control.
- Atomic database limits: per client 20 checks / 15 min; global 300 checks / min. Report limits: per client 5 / 15 min; global 50 / min.
- Cryptographically keyed unit lookup; no raw product codes stored in public reports.
- Private persistent `consumer_reports` storage with restricted access and unique reference identifier.
- Mobile-first consumer UI supports manual input, conditional camera scanning, five differentiated outcomes, complaint submission and clearly labeled sample scenarios.
- Wrong-secret access rejected.
- Database tests passed: enrolled synthetic record, unknown record, report storage, throttling after 20, rejected request counts remain persisted, no sensitive table read granted anonymously.
- Applied Supabase migrations `consumer_pilot_verification_reports`, `consumer_gateway_secret_rpc`, `consumer_report_crypto_fix`.
- Consumer gateway secret exists only in Vercel encrypted environment config; database stores SHA-256 hash, not raw key.
- No actual NAFDAC, GS1 or independent laboratory certification. Consumer copy must not claim product safety.

## QA still required
- Live anonymous HTTPS POST /api/v1/consumer/verify from a smartphone browser.
- Live submission and retrieval of an intentionally synthetic report, followed by deletion of QA report by an authorized administrator.
- Browser camera permission and QR decode: Android Chrome, iPhone Safari and a low-end Android model.
- Slow 3G, denied camera permission, no camera, rotated device, 320px layout, screen reader and 200% text zoom.
- Observe application logs and check spam/abuse patterns without retaining raw IP addresses.
- Confirm Vercel's latest production deployment includes both consumer endpoints and gateway environment variable.
- Independent security review before allowing public real-world product verification or use with actual goods.

## Safety and operational restrictions
- Not for genuine health decisions or product authentication.
- No regulator integration or automatic reporting to authorities. Users should use official channels for suspected counterfeits.
- Camera QR is based on Browser BarcodeDetector API; browsers without support fall back to manual entry.
- IP throttling depends on trusted Vercel edge headers; monitor real traffic and adjust fallback handling if multiple consumers share a single bucket.
- Plaintext QR tokens cannot be reconstructed from the registry.
- Read-model status only. An identity match does not verify physical tamper-evidence or laboratory quality.
- Public consumer reporting currently captures a 10–800 character description. Add privacy policy, retention rules, consent and safeguarding processes before broad field use.
