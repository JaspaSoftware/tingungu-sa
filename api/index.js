const express = require('express');
const mysql = require('mysql2/promise');
const dotenv = require('dotenv');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

dotenv.config();

const { requireAuth, requireAdmin } = require('./auth');
const { router: paymentsRouter } = require('./payments');
const { router: airtimeRouter, startReconciler } = require('./airtime');
const { router: contactRouter } = require('./contact');
const { router: givingOptionsRouter } = require('./giving-options');
const { validateEnvironment, validateDatabaseSchema } = require('./runtime');

const app = express();
const PORT = Number(process.env.PORT || 5000);

class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function asyncRoute(handler) {
  return (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
}

function requireString(value, field, { max = 150, pattern } = {}) {
  if (typeof value !== 'string' || !value.trim()) {
    throw new ApiError(400, 'VALIDATION_ERROR', `${field} is required.`);
  }
  const normalized = value.trim();
  if (normalized.length > max) {
    throw new ApiError(400, 'VALIDATION_ERROR', `${field} must be ${max} characters or fewer.`);
  }
  if (pattern && !pattern.test(normalized)) {
    throw new ApiError(400, 'VALIDATION_ERROR', `${field} has an invalid format.`);
  }
  return normalized;
}

function requirePositiveInt(value, field) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new ApiError(400, 'VALIDATION_ERROR', `${field} must be a positive integer.`);
  }
  return parsed;
}

function mapDatabaseError(error) {
  if (error.code === 'ER_DUP_ENTRY') {
    return new ApiError(409, 'CONFLICT', 'A record with those details already exists.');
  }
  if (error.code === 'ER_DATA_TOO_LONG' || error.code === 'ER_TRUNCATED_WRONG_VALUE') {
    return new ApiError(400, 'VALIDATION_ERROR', 'One or more values are not valid for this record.');
  }
  if (error.code === 'ER_NO_REFERENCED_ROW_2' || error.code === 'ER_NO_REFERENCED_ROW') {
    return new ApiError(400, 'INVALID_REFERENCE', 'The selected related record does not exist.');
  }
  if (error.code === 'ER_ROW_IS_REFERENCED_2') {
    return new ApiError(409, 'CONFLICT', 'This record is still referenced and cannot be deleted.');
  }
  if ([
    'ECONNREFUSED',
    'ETIMEDOUT',
    'ENOTFOUND',
    'PROTOCOL_CONNECTION_LOST',
    'ER_ACCESS_DENIED_ERROR',
    'ER_BAD_DB_ERROR',
    'ER_NO_SUCH_TABLE',
  ].includes(error.code)) {
    return new ApiError(503, 'DATABASE_UNAVAILABLE', 'The database is temporarily unavailable.');
  }
  return error;
}

app.use(express.json({ limit: '1mb' }));
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
app.use(cors({
  origin: (origin, callback) => callback(null, !origin || allowedOrigins.includes(origin)),
}));
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

let pool;
let ready = false;

function getPool() {
  if (!pool) {
    validateEnvironment();
    pool = mysql.createPool({
      host: process.env.DB_HOST,
      port: process.env.DB_PORT ? Number(process.env.DB_PORT) : 3306,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
      ssl: process.env.DB_SSL_CA
        ? {
            ca: fs.readFileSync(path.resolve(__dirname, process.env.DB_SSL_CA)),
            rejectUnauthorized: true,
          }
        : undefined,
    });
  }
  return pool;
}

app.get('/health/live', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/health', asyncRoute(async (req, res) => {
  if (!ready) {
    throw new ApiError(503, 'NOT_READY', 'API startup checks have not completed.');
  }
  await getPool().query('SELECT 1');
  res.json({ status: 'ok', database: 'connected' });
}));

app.use('/api/contact', contactRouter);
app.use('/api/payments', paymentsRouter);
app.use('/api/airtime', airtimeRouter);
app.use('/api/giving-options', givingOptionsRouter);

app.get('/', (req, res) => res.redirect('/health'));

// Public read-only church directory endpoints.
app.get('/api/districts', asyncRoute(async (req, res) => {
  const [rows] = await getPool().query(`
    SELECT district_id, district_name
    FROM districts
    ORDER BY district_name
  `);
  res.json(rows);
}));

app.get('/api/circuits', asyncRoute(async (req, res) => {
  const [rows] = await getPool().query(`
    SELECT c.circuit_id, c.circuit_code, c.circuit_name, c.district_id,
           d.district_name
    FROM circuits c
    LEFT JOIN districts d ON c.district_id = d.district_id
    ORDER BY c.circuit_name
  `);
  res.json(rows);
}));

app.get('/api/societies', asyncRoute(async (req, res) => {
  const [rows] = await getPool().query(`
    SELECT s.society_id, s.society_name, s.circuit_id, c.circuit_name
    FROM societies s
    JOIN circuits c ON s.circuit_id = c.circuit_id
    ORDER BY s.society_name
  `);
  res.json(rows);
}));

app.get('/api/circuits/:id/societies', asyncRoute(async (req, res) => {
  const circuitId = requirePositiveInt(req.params.id, 'Circuit ID');
  const [rows] = await getPool().query(
    `SELECT society_id, society_name, circuit_id
     FROM societies WHERE circuit_id = ? ORDER BY society_name`,
    [circuitId],
  );
  res.json(rows);
}));

// This is an intentionally public, read-only projection of published church
// directory contacts; it never returns unrestricted person records.
app.get('/api/ministers', asyncRoute(async (req, res) => {
  const [rows] = await getPool().query(`
    SELECT p.person_id, p.surname, p.first_name, p.cellphone, p.email,
           a.society_id, s.society_name, s.circuit_id, c.circuit_name,
           cat.category_name
    FROM appointments a
    JOIN persons p ON a.person_id = p.person_id
    JOIN societies s ON a.society_id = s.society_id
    JOIN circuits c ON s.circuit_id = c.circuit_id
    JOIN categories cat ON a.category_id = cat.category_id
    WHERE a.is_active = TRUE
    ORDER BY p.surname, p.first_name
  `);
  res.json(rows);
}));

// All remaining management endpoints require an authenticated Firebase admin.
app.use('/api', requireAuth, requireAdmin);

app.post('/api/societies', asyncRoute(async (req, res) => {
  const name = requireString(req.body?.name, 'Name', { max: 150 });
  const circuitId = requirePositiveInt(req.body?.circuit_id, 'Circuit ID');
  const [result] = await getPool().query(
    'INSERT INTO societies (society_name, circuit_id) VALUES (?, ?)',
    [name, circuitId],
  );
  res.status(201).json({ id: result.insertId, name, circuit_id: circuitId });
}));

app.put('/api/societies/:id', asyncRoute(async (req, res) => {
  const id = requirePositiveInt(req.params.id, 'Society ID');
  const name = requireString(req.body?.name, 'Name', { max: 150 });
  const circuitId = requirePositiveInt(req.body?.circuit_id, 'Circuit ID');
  const db = getPool();
  const [existing] = await db.query('SELECT society_id FROM societies WHERE society_id = ?', [id]);
  if (!existing.length) throw new ApiError(404, 'NOT_FOUND', 'Society not found.');
  await db.query(
    'UPDATE societies SET society_name = ?, circuit_id = ? WHERE society_id = ?',
    [name, circuitId, id],
  );
  res.json({ id, name, circuit_id: circuitId });
}));

app.delete('/api/societies/:id', asyncRoute(async (req, res) => {
  const id = requirePositiveInt(req.params.id, 'Society ID');
  const [result] = await getPool().query('DELETE FROM societies WHERE society_id = ?', [id]);
  if (!result.affectedRows) throw new ApiError(404, 'NOT_FOUND', 'Society not found.');
  res.status(204).end();
}));

app.post('/api/districts', asyncRoute(async (req, res) => {
  const name = requireString(req.body?.name, 'Name', { max: 150 });
  const [result] = await getPool().query(
    'INSERT INTO districts (district_name) VALUES (?)',
    [name],
  );
  res.status(201).json({ id: result.insertId, name });
}));

app.post('/api/circuits', asyncRoute(async (req, res) => {
  const code = requireString(req.body?.code, 'Code', {
    max: 20,
    pattern: /^[A-Za-z0-9-]+$/,
  });
  const name = requireString(req.body?.name, 'Name', { max: 150 });
  const districtId = requirePositiveInt(req.body?.district_id, 'District ID');
  const [result] = await getPool().query(
    'INSERT INTO circuits (circuit_code, circuit_name, district_id) VALUES (?, ?, ?)',
    [code, name, districtId],
  );
  res.status(201).json({ id: result.insertId, code, name, district_id: districtId });
}));

app.get('/api/stats', asyncRoute(async (req, res) => {
  const db = getPool();
  const [[{ count: districts }]] = await db.query('SELECT COUNT(*) AS count FROM districts');
  const [[{ count: circuits }]] = await db.query('SELECT COUNT(*) AS count FROM circuits');
  const [[{ count: societies }]] = await db.query('SELECT COUNT(*) AS count FROM societies');
  const [[{ count: ministers }]] = await db.query('SELECT COUNT(*) AS count FROM persons');
  res.json({ districts, circuits, societies, ministers });
}));

app.use((req, res) => {
  res.status(404).json({ error: 'Route not found.', code: 'NOT_FOUND' });
});

app.use((error, req, res, next) => {
  if (error.type === 'entity.too.large') {
    return res.status(413).json({ error: 'Request body is too large.', code: 'PAYLOAD_TOO_LARGE' });
  }
  if (error instanceof SyntaxError && error.status === 400 && 'body' in error) {
    return res.status(400).json({ error: 'Request body must contain valid JSON.', code: 'INVALID_JSON' });
  }
  const apiError = error instanceof ApiError ? error : mapDatabaseError(error);
  if (apiError.status >= 500) {
    console.error('API request failed:', error);
  }
  if (res.headersSent) return next(error);
  res.status(apiError.status || 500).json({
    error: apiError.status ? apiError.message : 'An unexpected server error occurred.',
    code: apiError.code || 'INTERNAL_ERROR',
  });
});

async function start() {
  validateEnvironment();
  const db = getPool();
  await db.query('SELECT 1');
  await validateDatabaseSchema(db, process.env.DB_NAME);
  ready = true;

  const server = app.listen(PORT, () => {
    startReconciler();
    console.log(`API listening on port ${PORT}; MySQL schema checks passed.`);
  });
  return server;
}

if (require.main === module) {
  start().catch((error) => {
    console.error(`API startup validation failed: ${error.message}`);
    process.exitCode = 1;
  });
}

module.exports = { app, start, getPool };
