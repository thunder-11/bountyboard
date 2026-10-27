import {spawnSync} from 'node:child_process';
import mysql from 'mysql2/promise';
import {MongoClient} from 'mongodb';
import {config} from '../server/config.js';
const mode=process.argv[2]||'integration';const database=`bountyboard_test_${Date.now()}`;
const env={...process.env,MYSQL_DATABASE:database,MONGO_DATABASE:database,ENABLE_JOBS:'false',PORT:'3111',DEMO_MODE:'true'};
function run(args){const result=spawnSync(process.execPath,args,{stdio:'inherit',env});if(result.status!==0)throw new Error(`${args.join(' ')} failed (${result.status})`);}
try{run(['scripts/setup.js']);run(['scripts/seed.js']);if(mode==='e2e')run(['node_modules/@playwright/test/cli.js','test']);else run(['--test','--test-concurrency=1','tests/integration/application.test.js']);}
catch(error){console.error(error.message);process.exitCode=1;}
finally{
 if(!/^bountyboard_test_\d+$/.test(database))throw new Error('Refusing unsafe test cleanup');
 const db=await mysql.createConnection({...config.mysql,user:'root',password:process.env.MYSQL_ROOT_PASSWORD||'bounty_local_root',database:undefined});
 try{await db.query(`DROP DATABASE IF EXISTS \`${database}\``);}finally{await db.end();}
 const client=new MongoClient(config.mongoUrl);try{await client.db(database).dropDatabase();}finally{await client.close();}
}
