import 'dotenv/config';
import { randomBytes } from 'node:crypto';
export const config = {
  port: Number(process.env.PORT || 3001),
  mysql: { host: process.env.MYSQL_HOST || '127.0.0.1', port: Number(process.env.MYSQL_PORT || 3308), user: process.env.MYSQL_USER || 'bounty_app', password: process.env.MYSQL_PASSWORD || 'bounty_local_app', database: process.env.MYSQL_DATABASE || 'bountyboard', timezone: 'Z', supportBigNumbers: true, bigNumberStrings: true, decimalNumbers: false, connectionLimit: 10, multipleStatements: false },
  mongoUrl: process.env.MONGO_URL || 'mongodb://127.0.0.1:27019/?replicaSet=rs0&directConnection=true',
  mongoDatabase: process.env.MONGO_DATABASE || 'bountyboard',
  secret: process.env.SESSION_SECRET || randomBytes(48).toString('hex'),
  demo: process.env.DEMO_MODE !== 'false',
  jobs: process.env.ENABLE_JOBS !== 'false',
};
if (process.env.NODE_ENV === 'production' && (!process.env.SESSION_SECRET || process.env.SESSION_SECRET.length < 32)) throw new Error('Production requires SESSION_SECRET with at least 32 characters.');
