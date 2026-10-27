import mysql from 'mysql2/promise';
import { readFile, copyFile, writeFile } from 'node:fs/promises';
import { randomBytes } from 'node:crypto';
import { config } from '../server/config.js';
import { generate, procedures } from './generate-db.js';
import { setupMongo } from '../server/content.js';
import { pool, mongoClient } from '../server/db.js';
try { await copyFile('.env.example','.env',2); } catch(error){if(error.code!=='EEXIST') throw error;}
const environmentFile=await readFile('.env','utf8');
if(environmentFile.includes('SESSION_SECRET=replace-with-at-least-32-random-characters'))await writeFile('.env',environmentFile.replace('SESSION_SECRET=replace-with-at-least-32-random-characters',`SESSION_SECRET=${randomBytes(48).toString('hex')}`));
await generate();
const database=config.mysql.database;
if(!/^[a-z_][a-z0-9_]*$/.test(database)) throw new Error('Invalid database name');
const db=await mysql.createConnection({...config.mysql,user:'root',password:process.env.MYSQL_ROOT_PASSWORD||'bounty_local_root',database:undefined,multipleStatements:true});
try {
 await db.query(`CREATE DATABASE IF NOT EXISTS \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci`);
 await db.query(`USE \`${database}\``); await db.query("SET time_zone='+00:00'");
 await db.query('SET GLOBAL log_bin_trust_function_creators=1');
 for(const file of ['schema','errors','views','routines','public-routines','triggers','events']){
  const sql=await readFile(`db/${file}.sql`,'utf8');
  if(sql.includes('DELIMITER $$')){for(const statement of sql.replace('DELIMITER $$','').replace('DELIMITER ;','').split('$$').map(s=>s.trim()).filter(Boolean))await db.query(statement);}
  else await db.query(sql);
  console.log(`Applied db/${file}.sql`);
 }
 await db.query('CREATE USER IF NOT EXISTS ?@\'%\' IDENTIFIED BY ?',[config.mysql.user,config.mysql.password]);
 await db.query(`GRANT SELECT ON \`${database}\`.* TO ?@'%'`,[config.mysql.user]);
 for(const name of procedures) await db.query(`GRANT EXECUTE ON PROCEDURE \`${database}\`.${name} TO ?@'%'`,[config.mysql.user]);
 for(const name of ['fn_is_participant','fn_is_maintainer','fn_has_role','fn_pledge_remaining'])await db.query(`GRANT EXECUTE ON FUNCTION \`${database}\`.${name} TO ?@'%'`,[config.mysql.user]);
 const [[auditIndex]]=await db.query("SELECT COUNT(*) n FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=? AND TABLE_NAME='audit_log' AND INDEX_NAME='ix_audit_log_time'",[database]);
 if(!Number(auditIndex.n))await db.query('CREATE INDEX ix_audit_log_time ON audit_log(changed_at,audit_id)');
 await setupMongo(); console.log('Both databases are ready. Run npm run db:seed on an empty database.');
} finally { await db.end(); await pool.end(); await mongoClient.close(); }
