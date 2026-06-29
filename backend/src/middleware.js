// ─────────────────────────────────────────────────────────────────────────────
//  Auth & RBAC middleware (Scope §12.2 — role checks are server-side only)
// ─────────────────────────────────────────────────────────────────────────────

const { verify } = require('./token');
const { findById } = require('./store');

/**
 * Require a valid Bearer token. Attaches req.auth = { profile, payload }.
 * The role is read from the *stored profile*, never trusted from the client.
 */
function authenticate(req, res, next) {
  const header = req.headers['authorization'] || '';
  if (!header.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Missing or malformed Authorization header.' });
  }
  const payload = verify(header.substring(7));
  if (!payload) {
    return res.status(401).json({ message: 'Invalid or expired session. Please log in again.' });
  }
  const profile = findById('profiles', payload.sub);
  if (!profile) {
    return res.status(401).json({ message: 'Account no longer exists.' });
  }
  if (profile.status === 'suspended') {
    return res.status(403).json({ message: 'This account is suspended.' });
  }
  req.auth = { profile, role: profile.role, payload };
  next();
}

/**
 * Restrict a router to one or more roles. Use after authenticate.
 *
 * Several API paths legitimately collide across roles (e.g. POST /appointments
 * exists for both patient and receptionist). All role routers are mounted on the
 * same /api base, so on a role mismatch we call next('router') to fall through to
 * the next role router rather than terminating with 403 — letting the request
 * reach the router that actually owns it. If no router matches, the app's 404
 * handler responds.
 */
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.auth) return res.status(401).json({ message: 'Not authenticated.' });
    if (!roles.includes(req.auth.role)) return next('router');
    next();
  };
}

module.exports = { authenticate, requireRole };
