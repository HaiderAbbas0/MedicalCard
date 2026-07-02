// ─────────────────────────────────────────────────────────────────────────────
//  Notifications helper (Scope §14)
//
//  Prototype stores notifications in the DB (the "FCM push" is simulated). Bodies
//  never contain clinical details, patient names, or diagnosis names — generic
//  text + a deep-link resource id only.
// ─────────────────────────────────────────────────────────────────────────────

const { db, uuid, now } = require('./store');

/**
 * @param {string} recipientId  profiles.id of the recipient
 * @param {string} type         appointment_confirmed | appointment_cancelled |
 *                              lab_result_uploaded | lab_result_ready |
 *                              doctor_approved | doctor_rejected
 * @param {string} title
 * @param {string} body
 * @param {string} [resourceId] deep-link target
 */
function notify(recipientId, type, title, body, resourceId = null) {
  const n = {
    id: uuid(),
    recipient_id: recipientId,
    type,
    title,
    body,
    is_read: false,
    resource_id: resourceId,
    created_at: now(),
  };
  db.notifications.push(n);
  return n;
}

module.exports = { notify };
