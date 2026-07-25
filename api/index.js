const express = require('express');
const mysql = require('mysql2/promise');
const dotenv = require('dotenv');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;
app.use(express.json());
app.use(cors());

// Simple Logger
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

// Health Check
app.get('/health', async (req, res) => {
  try {
    const db = await getPool();
    
    // Test connection
    await db.query('SELECT 1');

    // Fetch sample data
    const [districts] = await db.query('SELECT * FROM districts LIMIT 2');
    const [circuits] = await db.query('SELECT * FROM circuits LIMIT 2');
    const [societies] = await db.query('SELECT * FROM societies LIMIT 2');
    const [ministers] = await db.query('SELECT * FROM persons LIMIT 2');

    res.json({
      status: 'API is running',
      database: 'Connected',
      db_host: process.env.DB_HOST,
      samples: {
        districts,
        circuits,
        societies,
        ministers
      }
    });
  } catch (err) {
    res.status(500).json({
      status: 'API Error',
      database: 'Disconnected',
      error: err.message
    });
  }
});

app.get('/', (req, res) => {
  res.redirect('/health');
});

// MySQL Connection Pool
let pool;
async function getPool() {
  if (!pool) {
    pool = mysql.createPool({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'methodist_church_db',
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
      ssl: {
        ca: process.env.DB_SSL_CA ? fs.readFileSync(path.join(__dirname, process.env.DB_SSL_CA)) : undefined,
        rejectUnauthorized: true
      }
    });
  }
  return pool;
}

// Routes
app.get('/api/districts', async (req, res) => {
  try {
    const db = await getPool();
    const [rows] = await db.query('SELECT * FROM districts');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/circuits', async (req, res) => {
  try {
    const db = await getPool();
    const [rows] = await db.query(`
      SELECT c.*, d.district_name 
      FROM circuits c 
      LEFT JOIN districts d ON c.district_id = d.district_id
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Societies
app.get('/api/societies', async (req, res) => {
  try {
    const db = await getPool();
    const [rows] = await db.query(`
      SELECT s.*, c.circuit_name 
      FROM societies s 
      JOIN circuits c ON s.circuit_id = c.circuit_id
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/societies', async (req, res) => {
  const { name, circuit_id } = req.body;
  try {
    const db = await getPool();
    const [result] = await db.query('INSERT INTO societies (society_name, circuit_id) VALUES (?, ?)', [name, circuit_id]);
    res.status(201).json({ id: result.insertId, name, circuit_id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/societies/:id', async (req, res) => {
  const { name, circuit_id } = req.body;
  try {
    const db = await getPool();
    await db.query('UPDATE societies SET society_name = ?, circuit_id = ? WHERE society_id = ?', [name, circuit_id, req.params.id]);
    res.json({ id: req.params.id, name, circuit_id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/societies/:id', async (req, res) => {
  try {
    const db = await getPool();
    await db.query('DELETE FROM societies WHERE society_id = ?', [req.params.id]);
    res.status(204).end();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Districts
app.post('/api/districts', async (req, res) => {
  const { name } = req.body;
  try {
    const db = await getPool();
    const [result] = await db.query('INSERT INTO districts (district_name) VALUES (?)', [name]);
    res.status(201).json({ id: result.insertId, name });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Circuits
app.post('/api/circuits', async (req, res) => {
  const { code, name, district_id } = req.body;
  try {
    const db = await getPool();
    const [result] = await db.query('INSERT INTO circuits (circuit_code, circuit_name, district_id) VALUES (?, ?, ?)', [code, name, district_id]);
    res.status(201).json({ id: result.insertId, code, name, district_id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update/Sync User Profile with MySQL Database
app.put('/api/users/:email', async (req, res) => {
  const { email } = req.params;
  const { firstname, lastname, cellphone } = req.body;
  try {
    const db = await getPool();
    const [rows] = await db.query('SELECT * FROM persons WHERE email = ?', [email]);
    if (rows.length > 0) {
      await db.query(
        'UPDATE persons SET first_name = ?, surname = ?, cellphone = ? WHERE email = ?',
        [firstname || '', lastname || '', cellphone || null, email]
      );
      res.json({ message: 'User updated in MySQL database successfully', email });
    } else {
      await db.query(
        'INSERT INTO persons (first_name, surname, cellphone, email) VALUES (?, ?, ?, ?)',
        [firstname || '', lastname || '', cellphone || null, email]
      );
      res.json({ message: 'User created in MySQL database successfully', email });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete User Profile from MySQL Database
app.delete('/api/users/:email', async (req, res) => {
  const { email } = req.params;
  try {
    const db = await getPool();
    await db.query('DELETE FROM persons WHERE email = ?', [email]);
    res.json({ message: 'User deleted from MySQL database successfully', email });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});



// Ministers
app.get('/api/ministers', async (req, res) => {
  try {
    const db = await getPool();
    const [rows] = await db.query(`
      SELECT 
        p.*, 
        s.society_name, 
        c.circuit_name, 
        cat.category_name
      FROM appointments a
      JOIN persons p ON a.person_id = p.person_id
      JOIN societies s ON a.society_id = s.society_id
      JOIN circuits c ON s.circuit_id = c.circuit_id
      JOIN categories cat ON a.category_id = cat.category_id
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get societies for a specific circuit
app.get('/api/circuits/:id/societies', async (req, res) => {
  try {
    const db = await getPool();
    const [rows] = await db.query('SELECT * FROM societies WHERE circuit_id = ?', [req.params.id]);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Stats
app.get('/api/stats', async (req, res) => {
  try {
    const db = await getPool();
    const [[{ count: districts }]] = await db.query('SELECT COUNT(*) as count FROM districts');
    const [[{ count: circuits }]] = await db.query('SELECT COUNT(*) as count FROM circuits');
    const [[{ count: societies }]] = await db.query('SELECT COUNT(*) as count FROM societies');
    const [[{ count: ministers }]] = await db.query('SELECT COUNT(*) as count FROM persons');
    
    res.json({
      districts,
      circuits,
      societies,
      ministers
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Connected to database host: ${process.env.DB_HOST}`);
  // Redeploy trigger
});
