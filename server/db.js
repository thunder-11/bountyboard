import mysql from 'mysql2/promise';
import { MongoClient } from 'mongodb';
import { config } from './config.js';
export const pool = mysql.createPool(config.mysql);
export const mongoClient = new MongoClient(config.mongoUrl, { serverSelectionTimeoutMS: 2500 });
export const mongo = mongoClient.db(config.mongoDatabase);
export async function query(sql, params=[]) { const [rows] = await pool.execute(sql, params); return rows; }
export async function command(actor, key, name, payload) {
  if(!/^sp_[a-z_]+$/.test(name)) throw new Error('Invalid procedure');
  for(let attempt=0; attempt<3; attempt++) {
    const connection = await pool.getConnection();
    try {
      await connection.query("SET time_zone='+00:00'");
      await connection.query(`CALL ${name}(?,?,?,@command_result)`, [actor,key,JSON.stringify(payload)]);
      const [[row]] = await connection.query('SELECT @command_result result');
      return typeof row.result === 'string' ? JSON.parse(row.result) : row.result;
    } catch(error) {
      if(![1213,1205].includes(error.errno)) throw error;
      if(attempt===2) throw Object.assign(new Error('Transaction retry limit reached.'),{code:'E_RETRY',status:503});
    } finally { connection.release(); }
    await new Promise(resolve=>setTimeout(resolve,50*(attempt+1)));
  }
}
