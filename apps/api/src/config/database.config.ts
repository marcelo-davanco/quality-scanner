import { registerAs } from '@nestjs/config';

export default registerAs('database', () => ({
  host: process.env.API_DB_HOST || 'localhost',
  port: parseInt(process.env.API_DB_PORT || '5433', 10),
  username: process.env.API_DB_USER || 'scanner',
  password: process.env.API_DB_PASSWORD || 'scanner',
  database: process.env.API_DB_NAME || 'quality_scanner',
  synchronize: process.env.API_DB_SYNC === 'true',
}));
