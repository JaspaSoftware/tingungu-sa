const test = require('node:test');
const assert = require('node:assert/strict');
const { REQUIRED_TABLES, validateEnvironment, validateDatabaseSchema } = require('../runtime');

const validEnvironment = {
  DB_HOST: 'db.example.com',
  DB_USER: 'tingungu',
  DB_PASSWORD: 'not-a-real-password',
  DB_NAME: 'church_data',
};
const validProductionEnvironment = {
  ...validEnvironment,
  NODE_ENV: 'production',
  ALLOWED_ORIGINS: 'https://site.example',
  PAYFAST_SANDBOX: 'false',
  PAYFAST_MERCHANT_ID: 'production-merchant',
  PAYFAST_MERCHANT_KEY: 'production-key',
  PUBLIC_API_URL: 'https://api.example',
  FLASH_BASE_URL: 'https://flash.example/api',
  FLASH_TOKEN: 'production-token',
  FLASH_ACCOUNT_NUMBER: '123456',
};

test('validateEnvironment()', async (t) => {
  await t.test('requires database credentials', () => {
    assert.throws(
      () => validateEnvironment({ DB_HOST: 'localhost' }),
      /DB_USER, DB_PASSWORD, DB_NAME/,
    );
  });

  await t.test('rejects unsafe database names and invalid ports', () => {
    assert.throws(
      () => validateEnvironment({ ...validEnvironment, DB_NAME: 'church-data' }),
      /DB_NAME/,
    );
    assert.throws(
      () => validateEnvironment({ ...validEnvironment, DB_PORT: '70000' }),
      /DB_PORT/,
    );
  });

  await t.test('requires valid origins in production', () => {
    assert.throws(
      () => validateEnvironment({ ...validEnvironment, NODE_ENV: 'production' }),
      /ALLOWED_ORIGINS/,
    );
    assert.throws(
      () => validateEnvironment({
        ...validProductionEnvironment,
        ALLOWED_ORIGINS: 'https://site.example/path',
      }),
      /plain HTTP\(S\) origins/,
    );
  });

  await t.test('requires production payment and airtime settings', () => {
    assert.throws(
      () => validateEnvironment({
        ...validEnvironment,
        NODE_ENV: 'production',
        ALLOWED_ORIGINS: 'https://site.example',
      }),
      /PAYFAST_SANDBOX must be false/,
    );
    assert.throws(
      () => validateEnvironment({
        ...validProductionEnvironment,
        PAYFAST_MERCHANT_KEY: '',
      }),
      /PAYFAST_MERCHANT_KEY/,
    );
    assert.throws(
      () => validateEnvironment({
        ...validProductionEnvironment,
        FLASH_BASE_URL: 'http://flash.example/api',
      }),
      /FLASH_BASE_URL must be a valid HTTPS URL/,
    );
  });

  await t.test('accepts complete valid configuration', () => {
    assert.equal(validateEnvironment({
      ...validProductionEnvironment,
      DB_PORT: '3306',
    }), true);
  });
});

test('validateDatabaseSchema()', async (t) => {
  await t.test('passes when every route-required table exists', async () => {
    const pool = {
      query: async () => [REQUIRED_TABLES.map((TABLE_NAME) => ({ TABLE_NAME }))],
    };
    await assert.doesNotReject(validateDatabaseSchema(pool, 'church_data'));
  });

  await t.test('fails with actionable information when tables are missing', async () => {
    const pool = {
      query: async () => [[{ TABLE_NAME: 'districts' }]],
    };
    await assert.rejects(
      validateDatabaseSchema(pool, 'church_data'),
      /missing required tables: circuits, societies, persons, categories, appointments/,
    );
  });
});
