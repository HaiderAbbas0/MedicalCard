// ─────────────────────────────────────────────────────────────────────────────
//  Lab worker routes  (Scope §11.4)  — all require role: lab_worker
//
//  Data-access boundary (P-FR-039 / UC-L002): a lab worker only ever sees orders
//  for THEIR lab, and only a minimal patient view (first name + last initial) —
//  no CNIC, no address, no clinical history.
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { findById, where, update, insert } = require('../store');
const { authenticate, requireRole } = require('../middleware');
const { asyncH } = require('../helpers');
const { log } = require('../audit');
const { notify } = require('../notify');

const router = express.Router();
router.use(authenticate, requireRole('lab_worker'));

// Disk storage for uploaded result PDFs, served statically from /uploads.
const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });
const upload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
    filename: (_req, file, cb) => cb(null, `${Date.now()}-${file.originalname.replace(/[^\w.\-]/g, '_')}`),
  }),
  limits: { fileSize: 25 * 1024 * 1024 }, // P-FR-055 — 25 MB per file
});

const myLabId = (req) => (findById('lab_worker_profiles', req.auth.profile.id) || {}).lab_id;

const PRIORITY_RANK = { stat: 0, urgent: 1, routine: 2 };

/** Minimal patient view — first name + last initial only. */
function maskedPatient(patientId) {
  const p = findById('profiles', patientId);
  if (!p) return { display_name: 'Unknown' };
  const parts = p.full_name.trim().split(/\s+/);
  const first = parts[0];
  const lastInitial = parts.length > 1 ? `${parts[parts.length - 1][0]}.` : '';
  return { display_name: `${first} ${lastInitial}`.trim() };
}

function orderView(o) {
  return {
    id: o.id,
    test_name: o.test_name,
    priority: o.priority,
    status: o.status,
    clinical_indication: o.clinical_indication,
    special_instructions: o.special_instructions,
    ordered_at: o.ordered_at,
    sample_collected_at: o.sample_collected_at,
    patient: maskedPatient(o.patient_id),
  };
}

// ── GET /lab/orders ───────────────────────────────────────────────────────────
router.get(
  '/lab/orders',
  asyncH((req, res) => {
    const labId = myLabId(req);
    const orders = where('lab_orders', (o) => o.lab_id === labId && !['released_to_patient', 'cancelled'].includes(o.status))
      .sort((a, b) => (PRIORITY_RANK[a.priority] ?? 9) - (PRIORITY_RANK[b.priority] ?? 9) || new Date(a.ordered_at) - new Date(b.ordered_at))
      .map(orderView);
    res.json(orders);
  }),
);

// Guard: an order that belongs to this worker's lab.
function ownOrder(req, res) {
  const o = findById('lab_orders', req.params.id);
  if (!o || o.lab_id !== myLabId(req)) { res.status(404).json({ message: 'Order not found.' }); return null; }
  return o;
}

// ── GET /lab/orders/:id ───────────────────────────────────────────────────────
router.get('/lab/orders/:id', asyncH((req, res) => {
  const o = ownOrder(req, res); if (!o) return;
  res.json(orderView(o));
}));

// ── PATCH /lab/orders/:id/collect (P-FR-037) ──────────────────────────────────
router.patch('/lab/orders/:id/collect', asyncH((req, res) => {
  const o = ownOrder(req, res); if (!o) return;
  update('lab_orders', o.id, { status: 'sample_collected', sample_collected_at: new Date().toISOString() });
  res.json(orderView(findById('lab_orders', o.id)));
}));

// ── PATCH /lab/orders/:id/processing ──────────────────────────────────────────
router.patch('/lab/orders/:id/processing', asyncH((req, res) => {
  const o = ownOrder(req, res); if (!o) return;
  update('lab_orders', o.id, { status: 'processing' });
  res.json(orderView(findById('lab_orders', o.id)));
}));

// ── POST /lab/orders/:id/result (P-FR-037/038) ────────────────────────────────
router.post('/lab/orders/:id/result', asyncH((req, res) => {
  const o = ownOrder(req, res); if (!o) return;
  const { result_file_url, result_file_name, structured_results, comments } = req.body;

  const result = insert('lab_results', {
    lab_order_id: o.id,
    lab_id: o.lab_id,
    uploaded_by: req.auth.profile.id,
    patient_id: o.patient_id,
    result_file_url: result_file_url || null,
    result_file_name: result_file_name || null,
    structured_results: structured_results || null,
    comments: comments || null,
  });
  update('lab_orders', o.id, { status: 'resulted', resulted_at: new Date().toISOString() });

  log({ actorId: req.auth.profile.id, actorRole: 'lab_worker', action: 'create', resourceType: 'lab_results', resourceId: result.id, patientId: o.patient_id });
  // P-FR-038 — uploading a result notifies the ordering doctor.
  notify(o.ordering_doctor_id, 'lab_result_uploaded', 'Lab result uploaded', 'A lab result is ready for your review.', o.id);
  res.status(201).json(result);
}));

// ── POST /lab/orders/:id/result-file (real multipart PDF upload, P-FR-055) ────
router.post(
  '/lab/orders/:id/result-file',
  (req, res, next) =>
    upload.single('file')(req, res, (err) => {
      if (err) {
        const msg = err.code === 'LIMIT_FILE_SIZE' ? 'File exceeds the 25 MB limit.' : 'Upload failed.';
        return res.status(400).json({ message: msg });
      }
      next();
    }),
  asyncH((req, res) => {
    const o = ownOrder(req, res);
    if (!o) return;
    if (!req.file) return res.status(400).json({ message: 'A result file is required.' });

    let structured = null;
    if (req.body.structured_results) {
      try {
        structured = JSON.parse(req.body.structured_results);
      } catch {
        /* ignore malformed structured payload */
      }
    }

    const result = insert('lab_results', {
      lab_order_id: o.id,
      lab_id: o.lab_id,
      uploaded_by: req.auth.profile.id,
      patient_id: o.patient_id,
      result_file_url: `/uploads/${req.file.filename}`,
      result_file_name: req.file.originalname,
      structured_results: structured,
      comments: req.body.comments || null,
    });
    update('lab_orders', o.id, { status: 'resulted', resulted_at: new Date().toISOString() });

    log({ actorId: req.auth.profile.id, actorRole: 'lab_worker', action: 'create', resourceType: 'lab_results', resourceId: result.id, patientId: o.patient_id });
    notify(o.ordering_doctor_id, 'lab_result_uploaded', 'Lab result uploaded', 'A lab result is ready for your review.', o.id);
    res.status(201).json(result);
  }),
);

module.exports = router;
