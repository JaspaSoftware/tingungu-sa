const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function initFirebase() {
  if (admin.apps.length) return;
  const keyPath = process.env.FIREBASE_SERVICE_ACCOUNT
    ? path.resolve(__dirname, process.env.FIREBASE_SERVICE_ACCOUNT)
    : null;
  if (keyPath && fs.existsSync(keyPath)) {
    admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
  } else {
    // Falls back to Application Default Credentials (e.g. a managed identity).
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: process.env.FIREBASE_PROJECT_ID || 'tingungu-sa',
    });
  }
}

initFirebase();

async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer (.+)$/);
  if (!match) return res.status(401).json({ error: 'Authentication required' });
  try {
    req.user = await admin.auth().verifyIdToken(match[1]);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function requireAdmin(req, res, next) {
  if (req.user && req.user.admin === true) return next();
  res.status(403).json({ error: 'Administrator access required' });
}

module.exports = { requireAuth, requireAdmin };
