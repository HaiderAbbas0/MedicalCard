// ─────────────────────────────────────────────────────────────────────────────
//  Shared route helpers
// ─────────────────────────────────────────────────────────────────────────────

const { sign } = require('./token');
const { fullProfile } = require('./store');

/** 13-digit Pakistan CNIC, no dashes (Scope §3.1 — format checked only). */
const isValidCnic = (cnic) => /^\d{13}$/.test(String(cnic || '').trim());

/**
 * Build the standard auth response: a signed token plus a safe user object that
 * carries the role at the top level so the client can route immediately.
 */
function authResponse(profile) {
  const token = sign({ sub: profile.id, role: profile.role, cnic: profile.cnic });
  return { token, user: fullProfile(profile.id) };
}

/** Express async wrapper so thrown errors hit the error handler. */
const asyncH = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

module.exports = { isValidCnic, authResponse, asyncH };
