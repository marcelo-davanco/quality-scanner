import { DataSource } from 'typeorm';
import { config } from 'dotenv';
import { join } from 'path';

config({ path: join(__dirname, '..', '..', '..', '..', '.env') });

export default new DataSource({
  type: 'postgres',
  host: process.env.API_DB_HOST || 'localhost',
  port: parseInt(process.env.API_DB_PORT || '5433', 10),
  username: process.env.API_DB_USER || 'scanner',
  password: process.env.API_DB_PASSWORD || 'scanner',
  database: process.env.API_DB_NAME || 'quality_scanner',
  entities: [join(__dirname, '..', 'modules', '**', '*.entity.{ts,js}')],
  migrations: [join(__dirname, '..', 'migrations', '*.{ts,js}')],
  synchronize: false,
});
