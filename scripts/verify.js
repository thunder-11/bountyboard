import assert from 'node:assert/strict';
import {query,pool,mongoClient,mongo} from '../server/db.js';
import {config} from '../server/config.js';
import mysql from 'mysql2/promise';
const catalog=await mysql.createConnection({...config.mysql,user:'root',password:process.env.MYSQL_ROOT_PASSWORD||'bounty_local_root'});
try{
 const counts={};for(const table of ['users','repositories','issues','pledges','pull_requests'])counts[table]=Number((await query(`SELECT COUNT(*) n FROM ${table}`))[0].n);
 const discrepancies=await query('SELECT * FROM v_reconciliation WHERE delta<>0');assert.equal(discrepancies.length,0,'Accounting discrepancies detected');
 const [totals]=await query('SELECT SUM(total_pledged) pledged,SUM(escrow_held) held,SUM(total_released) released,SUM(total_refunded) refunded FROM v_issue_funding');
 const [supply]=await query("SELECT (SELECT SUM(balance) FROM wallets) wallets,(SELECT SUM(held_amount) FROM escrows) held,-COALESCE((SELECT SUM(l.signed_amount) FROM ledger_entries l JOIN accounts a USING(account_id) WHERE a.account_kind='ISSUANCE'),0) issuance");
 const objects={};for(const [name,sql] of Object.entries({tables:"SELECT COUNT(*) n FROM information_schema.TABLES WHERE TABLE_SCHEMA=? AND TABLE_TYPE='BASE TABLE'",views:"SELECT COUNT(*) n FROM information_schema.VIEWS WHERE TABLE_SCHEMA=?",routines:"SELECT COUNT(*) n FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=?",triggers:"SELECT COUNT(*) n FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=?",events:"SELECT COUNT(*) n FROM information_schema.EVENTS WHERE EVENT_SCHEMA=?"})){const [[row]]=await catalog.execute(sql,[config.mysql.database]);objects[name]=Number(row.n);}
 for(const [name,minimum] of Object.entries({tables:28,views:5,routines:39,triggers:34,events:2}))assert.ok(objects[name]>=minimum,`Missing ${name}`);
 const engines=await query("SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA=? AND TABLE_TYPE='BASE TABLE' AND ENGINE<>'InnoDB'",[config.mysql.database]);assert.equal(engines.length,0,'All tables must be InnoDB');
 const documents={};for(const name of ['issue_bodies','comments','code_snippets','commit_logs'])documents[name]=await mongo.collection(name).countDocuments();
 const health=await fetch(`http://127.0.0.1:${config.port}/api/health`);assert.equal(health.status,200,'API database health');
 const page=await fetch(`http://127.0.0.1:${config.port}/`);assert.equal(page.status,200);assert.match(await page.text(),/Bountyboard/);
 console.log(JSON.stringify({database:config.mysql.database,counts,objects,documents,totals,supply,accounting_discrepancies:discrepancies.length,api_health:await health.json(),built_frontend:'ready'},null,2));
}finally{await catalog.end();await pool.end();await mongoClient.close();}
