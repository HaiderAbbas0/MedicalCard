// ─────────────────────────────────────────────────────────────────────────────
//  Token utility — dependency-free signed tokens (prototype stand-in for JWT)
//
//  Format:  base64url(payload) "." base64url(HMAC-SHA256(payload))
//  Payload: { sub: <profileId>, role, cnic, iat, exp }
//
//  Production replaces this with Supabase/Keycloak JWTs (Scope §12.1).
// ─────────────────────────────────────────────────────────────────────────────

const crypto = require('crypto');

const SECRET = process.env.JWT_SECRET || 'cnic-health-card-prototype-secret';
const TTL_SECONDS = 60 * 60; // 60-minute access token (P-NFR-003)

const b64url = (buf) =>
  Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

const fromB64url = (str) =>
  Buffer.from(str.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8');

function sign(payload) {
  const body = { ...payload, iat: Math.floor(Date.now() / 1000) };
  body.exp = body.iat + TTL_SECONDS;
  const encoded = b64url(JSON.stringify(body));
  const sig = b64url(crypto.createHmac('sha256', SECRET).update(encoded).digest());
  return `${encoded}.${sig}`;
}

/** Verify a token. Returns the payload, or null when invalid/expired. */
function verify(token) {
  if (!token || typeof token !== 'string' || !token.includes('.')) return null;
  const [encoded, sig] = token.split('.');
  const expected = b64url(crypto.createHmac('sha256', SECRET).update(encoded).digest());
  // Constant-time comparison.
  if (sig.length !== expected.length) return null;
  if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) return null;
  let payload;
  try {
    payload = JSON.parse(fromB64url(encoded));
  } catch {
    return null;
  }
  if (payload.exp && Math.floor(Date.now() / 1000) > payload.exp) return null;
  return payload;
}

module.exports = { sign, verify, TTL_SECONDS };
