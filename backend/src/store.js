// ─────────────────────────────────────────────────────────────────────────────
//  In-memory data store
//
//  Mirrors the 12 prototype tables described in the CNIC Health Card "Prototype
//  Scope" document (Section 4 — Database Schema). For the prototype we keep
//  everything in memory; production swaps this module for Supabase/PostgreSQL
//  without touching the route layer.
// ─────────────────────────────────────────────────────────────────────────────

const crypto = require('crypto');

/** Generate a UUID (matches Postgres gen_random_uuid()). */
const uuid = () => crypto.randomUUID();

/** Current ISO timestamp (TIMESTAMPTZ). */
const now = () => new Date().toISOString();

/**
 * The database. Each property is a "table" (array of row objects).
 * Seed data is loaded by seed.js after this module is required.
 */
const db = {
  // Identity & profiles
  profiles: [],
  patient_profiles: [],
  doctor_profiles: [],
  lab_worker_profiles: [],
  receptionist_profiles: [],
  admin_profiles: [],

  // Supporting entities
  clinics: [],
  diagnostic_labs: [],

  // Scheduling
  doctor_availability: [],
  appointments: [],

  // Clinical data
  encounters: [],
  conditions: [],
  medication_requests: [],
  observations: [],
  allergies: [],

  // Lab workflow
  lab_orders: [],
  lab_results: [],

  // Cross-cutting
  audit_logs: [],
  notifications: [],
};

// ── Generic helpers ──────────────────────────────────────────────────────────

/** Find a single row in a table by id. */
const findById = (table, id) => db[table].find((r) => r.id === id);

/** Find all rows in a table matching a predicate. */
const where = (table, predicate) => db[table].filter(predicate);

/** Insert a row, auto-filling id / created_at / updated_at when absent. */
function insert(table, row) {
  const ts = now();
  const record = {
    id: row.id || uuid(),
    created_at: ts,
    updated_at: ts,
    ...row,
  };
  db[table].push(record);
  return record;
}

/** Patch a row in place and bump updated_at if the column exists. */
function update(table, id, patch) {
  const row = findById(table, id);
  if (!row) return null;
  Object.assign(row, patch);
  if ('updated_at' in row) row.updated_at = now();
  return row;
}

// ── Composite profile helper ─────────────────────────────────────────────────

/**
 * Build the full profile object for a base profile id by joining the matching
 * role-extended profile. Returns null when the base profile is missing.
 */
function fullProfile(profileId) {
  const base = findById('profiles', profileId);
  if (!base) return null;
  const extTable = {
    patient: 'patient_profiles',
    doctor: 'doctor_profiles',
    lab_worker: 'lab_worker_profiles',
    receptionist: 'receptionist_profiles',
    admin: 'admin_profiles',
  }[base.role];
  const ext = extTable ? findById(extTable, profileId) : null;
  // Never leak password / auth columns to clients.
  const { password, auth_user_id, ...safeBase } = base;
  return { ...safeBase, extended: ext || {} };
}

/** Look up a base profile by CNIC, email, or phone (case-insensitive). */
function findProfileByLogin(identifier) {
  if (!identifier) return null;
  const id = String(identifier).trim().toLowerCase();
  return db.profiles.find(
    (p) =>
      p.cnic === identifier.trim() ||
      (p.email && p.email.toLowerCase() === id) ||
      (p.phone_primary && p.phone_primary.toLowerCase() === id),
  );
}

module.exports = {
  db,
  uuid,
  now,
  findById,
  where,
  insert,
  update,
  fullProfile,
  findProfileByLogin,
};
