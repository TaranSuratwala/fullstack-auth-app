const { Pool } = require('pg');

const useSsl =
  process.env.DB_SSL === 'true' || process.env.PGSSLMODE === 'require';

const pool = new Pool({
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT, 10),
  database: process.env.DB_NAME,
  ssl: useSsl ? { rejectUnauthorized: false } : false,
});

// Test connection
pool.on('connect', () => {
  console.log('✅ Connected to PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('❌ Unexpected error on idle PostgreSQL client:', err);
  process.exit(-1);
});

module.exports = pool;
