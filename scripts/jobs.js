import mysql from 'mysql2/promise';
import {config} from '../server/config.js';
const action=process.argv[2]||'status';if(!['enable','disable','status'].includes(action))throw new Error('Usage: node scripts/jobs.js enable|disable|status');
const db=await mysql.createConnection({...config.mysql,user:'root',password:process.env.MYSQL_ROOT_PASSWORD||'bounty_local_root'});
try{if(action!=='status')for(const name of ['ev_bounty_deadlines','ev_claim_expiry'])await db.query(`ALTER EVENT ${name} ${action.toUpperCase()}`);const [rows]=await db.query('SELECT EVENT_NAME,STATUS,LAST_EXECUTED FROM information_schema.EVENTS WHERE EVENT_SCHEMA=?',[config.mysql.database]);console.table(rows);}finally{await db.end();}
