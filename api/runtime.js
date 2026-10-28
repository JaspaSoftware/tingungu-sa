const REQUIRED_TABLES = [
  'districts',
  'circuits',
  'societies',
  'persons',
  'categories',
  'appointments',
];

function validateEnvironment(env = process.env) {
  const required = ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'];
  const missing = required.filter((key) => !String(env[key] || '').trim());

  if (missing.length) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  if (!/^[A-Za-z0-9_]+$/.test(env.DB_NAME)) {
    throw new Error('DB_NAME may contain only letters, numbers, and underscores.');
  }

  const port = env.DB_PORT ? Number(env.DB_PORT) : 3306;
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('DB_PORT must be an integer between 1 and 65535.');
  }

  const apiPort = env.PORT ? Number(env.PORT) : 5000;
  if (!Number.isInteger(apiPort) || apiPort < 1 || apiPort > 65535) {
    throw new Error('PORT must be an integer between 1 and 65535.');
  }

  if (env.NODE_ENV === 'production') {
    const origins = String(env.ALLOWED_ORIGINS || '')
      .split(',')
      .map((origin) => origin.trim())
      .filter(Boolean);
    if (!origins.length) {
      throw new Error('ALLOWED_ORIGINS must be configured in production.');
    }
    for (const origin of origins) {
      let parsed;
      try {
        parsed = new URL(origin);
      } catch {
        throw new Error(`ALLOWED_ORIGINS contains an invalid URL: ${origin}`);
      }
      if (!['http:', 'https:'].includes(parsed.protocol) || parsed.origin !== origin) {
        throw new Error(`ALLOWED_ORIGINS entries must be plain HTTP(S) origins: ${origin}`);
      }
    }

    if (env.PAYFAST_SANDBOX !== 'false') {
      throw new Error('PAYFAST_SANDBOX must be false in production.');
    }

    const productionIntegrations = [
      'PAYFAST_MERCHANT_ID',
      'PAYFAST_MERCHANT_KEY',
      'PUBLIC_API_URL',
      'FLASH_BASE_URL',
      'FLASH_TOKEN',
      'FLASH_ACCOUNT_NUMBER',
    ];
    const missingIntegrations = productionIntegrations.filter(
      (key) => !String(env[key] || '').trim(),
    );
    if (missingIntegrations.length) {
      throw new Error(
        `Missing required production integration settings: ${missingIntegrations.join(', ')}`,
      );
    }

    for (const key of ['PUBLIC_API_URL', 'FLASH_BASE_URL']) {
      let parsed;
      try {
        parsed = new URL(env[key]);
      } catch {
        throw new Error(`${key} must be a valid HTTPS URL in production.`);
      }
      if (parsed.protocol !== 'https:') {
        throw new Error(`${key} must be a valid HTTPS URL in production.`);
      }
    }
  }

  return true;
}

async function validateDatabaseSchema(pool, databaseName = process.env.DB_NAME) {
  const [rows] = await pool.query(
    'SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema = ?',
    [databaseName],
  );
  const available = new Set(rows.map((row) => row.TABLE_NAME));
  const missing = REQUIRED_TABLES.filter((table) => !available.has(table));

  if (missing.length) {
    throw new Error(
      `Database "${databaseName}" is missing required tables: ${missing.join(', ')}. ` +
      'Run the API MySQL seed/migration before starting the service.',
    );
  }
}

module.exports = { REQUIRED_TABLES, validateEnvironment, validateDatabaseSchema };
