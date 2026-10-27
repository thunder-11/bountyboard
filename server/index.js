import { app } from './app.js';
import { config } from './config.js';
import { pool,mongoClient } from './db.js';
import { startWorker } from './content.js';
const stopWorker=startWorker();
const server=app.listen(config.port,'127.0.0.1',()=>console.log(`Bountyboard API: http://127.0.0.1:${config.port}`));
async function stop(){stopWorker();server.close(async()=>{await pool.end();await mongoClient.close();process.exit(0);});}
process.on('SIGINT',stop);process.on('SIGTERM',stop);
