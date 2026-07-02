// ─────────────────────────────────────────────────────────────────────────────
//  Audit log helper (Scope §15)
//
//  audit_logs is append-only — no UPDATE or DELETE is ever exposed. Every
//  security-relevant action funnels through log().
// ─────────────────────────────────────────────────────────────────────────────

const { db, uuid, now } = require('./store');

/**
 * Append an audit entry.
 * @param {object} opts
 * @param {string|null} opts.actorId    profiles.id of the actor (null = system)
 * @param {string|null} opts.actorRole  role at time of action
 * @param {string} opts.action          login | logout | create | read | update | status_change
 * @param {string} [opts.resourceType]  table or entity name
 * @param {string} [opts.resourceId]    affected record id
 * @param {string} [opts.patientId]     patient involved, if any
 * @param {string} [opts.status]        success | failure
 */
function log({
  actorId = null,
  actorRole = null,
  action,
  resourceType = null,
  resourceId = null,
  patientId = null,
  status = 'success',
}) {
  const entry = {
    id: uuid(),
    actor_id: actorId,
    actor_role: actorRole,
    action,
    resource_type: resourceType,
    resource_id: resourceId,
    patient_id: patientId,
    status,
    timestamp: now(),
  };
  db.audit_logs.push(entry);
  return entry;
}

module.exports = { log };
