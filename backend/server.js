// ─────────────────────────────────────────────────────────────────────────────
//  CNIC Health Card System — Prototype API
//
//  Modular Node/Express backend implementing the prototype API surface from the
//  "Prototype Scope" document (Section 11). In-memory data store stands in for
//  Supabase/PostgreSQL; the route layer is written so the store can be swapped
//  for a real database without changes.
//
//  Roles: patient · doctor · lab_worker · receptionist · admin
//  Run:   npm start   (from the backend/ directory)
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const cors = require('cors');
const path = require('path');

const { seed } = require('./src/seed');
const authRoutes = require('./src/routes/auth.routes');
const patientRoutes = require('./src/routes/patient.routes');
const doctorRoutes = require('./src/routes/doctor.routes');
const labRoutes = require('./src/routes/lab.routes');
const receptionistRoutes = require('./src/routes/receptionist.routes');
const adminRoutes = require('./src/routes/admin.routes');
const legacyRoutes = require('./src/routes/legacy.routes');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '2mb' }));

// Request logging.
app.use((req, _res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  next();
});

// Load demo data.
seed();

// Health check.
app.get('/api/health', (_req, res) => res.json({ status: 'ok', service: 'cnic-health-card-api' }));

// Serve uploaded lab-result files.
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ── API routes (all under /api to match the mobile/web clients) ───────────────
app.use('/api/auth', authRoutes);
app.use('/api', patientRoutes);
app.use('/api', doctorRoutes);
app.use('/api', labRoutes);
app.use('/api', receptionistRoutes);
app.use('/api', adminRoutes);

// Backward-compatible endpoints for the original patient demo build.
app.use('/api', legacyRoutes);

// 404.
app.use((req, res) => res.status(404).json({ message: `No route for ${req.method} ${req.originalUrl}` }));

// Central error handler.
// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ message: 'Internal server error.' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('=========================================');
  console.log(' HayaatID — CNIC Health Card Prototype API');
  console.log(` Listening on http://0.0.0.0:${PORT}`);
  console.log(' Demo accounts (password: password123):');
  console.log('   patient      → CNIC 3520112345671  (Ayesha Khan)');
  console.log('   doctor       → CNIC 3520199999991  (Dr. Imran Yousuf)');
  console.log('   lab_worker   → CNIC 3520177777771  (Zafar Iqbal)');
  console.log('   receptionist → CNIC 3520166666661  (Hina Saleem)');
  console.log('   admin        → CNIC 3520100000001  (System Administrator)');
  console.log('=========================================');
});

module.exports = app;
