// Test harness: runs the real payments/airtime routers against an in-memory
// Firestore, so money logic is exercised without any network or credentials.
const Module = require('module');
const path = require('path');
const express = require('express');

class Timestamp {
  constructor(ms) {
    this.ms = ms;
  }
  toMillis() {
    return this.ms;
  }
}
const SERVER_TS = Symbol('serverTimestamp');

const store = new Map();
let counter = 0;

const resolveValue = (v) => (v === SERVER_TS ? new Timestamp(Date.now()) : v);
const clean = (data) =>
  Object.fromEntries(Object.entries(data).map(([k, v]) => [k, resolveValue(v)]));

function applySet(p, data, opts) {
  store.set(p, opts && opts.merge ? { ...(store.get(p) || {}), ...clean(data) } : clean(data));
}
function applyUpdate(p, data) {
  if (!store.has(p)) throw new Error(`NOT_FOUND: ${p}`);
  store.set(p, { ...store.get(p), ...clean(data) });
}

function snapshot(p, ref) {
  return {
    id: ref.id,
    ref,
    exists: store.has(p),
    data: () => (store.has(p) ? { ...store.get(p) } : undefined),
  };
}

function docRef(p) {
  const ref = {
    id: p.split('/').pop(),
    path: p,
    get: async () => snapshot(p, ref),
    set: async (data, opts) => applySet(p, data, opts),
    update: async (data) => applyUpdate(p, data),
    collection: (name) => collectionRef(`${p}/${name}`),
  };
  return ref;
}

function childPaths(collectionPath) {
  return [...store.keys()].filter(
    (k) => k.startsWith(`${collectionPath}/`) && !k.slice(collectionPath.length + 1).includes('/')
  );
}

function collectionRef(p) {
  return {
    doc: (id) => docRef(`${p}/${id || `auto${++counter}`}`),
    where: (field, op, values) => ({
      get: async () => ({
        docs: childPaths(p)
          .filter((k) => values.includes(store.get(k)[field]))
          .map((k) => snapshot(k, docRef(k))),
      }),
    }),
  };
}

// Writes are buffered and only applied if the callback resolves, like Firestore.
async function runTransaction(fn) {
  const writes = [];
  const tx = {
    get: (ref) => ref.get(),
    set: (ref, data, opts) => {
      writes.push(() => applySet(ref.path, data, opts));
    },
    update: (ref, data) => {
      if (!store.has(ref.path)) throw new Error(`NOT_FOUND: ${ref.path}`);
      writes.push(() => applyUpdate(ref.path, data));
    },
  };
  const result = await fn(tx);
  writes.forEach((w) => w());
  return result;
}

const firestore = { collection: (name) => collectionRef(name), runTransaction };
const fakeAdmin = {
  firestore: Object.assign(() => firestore, {
    FieldValue: { serverTimestamp: () => SERVER_TS },
  }),
};

// Sign-in is simulated with an x-test-uid header.
const fakeAuth = {
  requireAuth: (req, res, next) => {
    const uid = req.headers['x-test-uid'];
    if (!uid) return res.status(401).json({ error: 'Authentication required' });
    req.user = { uid, name: 'Test Member', email: 'member@example.com' };
    next();
  },
};

const originalLoad = Module._load;
Module._load = function patchedLoad(request, parent, isMain) {
  if (request === 'firebase-admin') return fakeAdmin;
  if (request === './auth' && parent && path.dirname(parent.filename) === path.resolve(__dirname, '..')) {
    return fakeAuth;
  }
  return originalLoad.call(this, request, parent, isMain);
};

function load(name) {
  const file = require.resolve(path.join('..', name));
  delete require.cache[file];
  return require(file);
}

const db = {
  reset: () => {
    store.clear();
    counter = 0;
  },
  seed: (p, data) => store.set(p, { ...data }),
  read: (p) => (store.has(p) ? { ...store.get(p) } : undefined),
  list: (collectionPath) => childPaths(collectionPath).map((k) => ({ id: k.split('/').pop(), ...store.get(k) })),
};

async function startServer(mountPath, router) {
  const app = express();
  app.use(express.json());
  app.use(mountPath, router);
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (method, urlPath, { uid, body, raw, headers } = {}) => {
    const res = await fetch(`${base}${urlPath}`, {
      method,
      headers: {
        ...(uid ? { 'x-test-uid': uid } : {}),
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(headers || {}),
      },
      body: raw !== undefined ? raw : body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let json;
    try {
      json = JSON.parse(text);
    } catch {
      json = undefined;
    }
    return { status: res.status, json, text };
  };
  return { call, close: () => new Promise((resolve) => server.close(resolve)) };
}

// Replaces global fetch for outbound calls (PayFast validation, airtime provider).
function mockFetch(handler) {
  const original = global.fetch;
  const realFetch = original.bind(global);
  global.fetch = async (url, opts) => {
    if (String(url).startsWith('http://127.0.0.1')) return realFetch(url, opts);
    return handler(String(url), opts);
  };
  return () => {
    global.fetch = original;
  };
}

const reply = (status, body) => ({
  status,
  ok: status >= 200 && status < 300,
  json: async () => body,
  text: async () => (typeof body === 'string' ? body : JSON.stringify(body)),
});

module.exports = { load, db, startServer, mockFetch, reply, Timestamp };
