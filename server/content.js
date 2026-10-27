import { Long } from 'mongodb';
import { mongo, mongoClient, query, command } from './db.js';
import { fail } from './errors.js';
export const collections=['issue_bodies','comments','code_snippets','commit_logs'];
const long=value=>Long.fromString(String(value));
const uuid={bsonType:'string',pattern:'^[0-9a-f-]{36}$'};
export async function setupMongo(){
 await mongoClient.connect();
 const common={_id:{bsonType:'string'},event_id:uuid,issue_id:{bsonType:'long'},author_id:{bsonType:'long'}};
 const schemas={
  issue_bodies:{version:{bsonType:'int',minimum:1},body_markdown:{bsonType:'string',minLength:1},updated_at:{bsonType:'date'}},
  comments:{parent_comment_id:{bsonType:['string','null']},body_markdown:{bsonType:'string',minLength:1},created_at:{bsonType:'date'}},
  code_snippets:{language:{enum:['SQL','JAVA','PYTHON','JAVASCRIPT']},code:{bsonType:'string',minLength:1},created_at:{bsonType:'date'}},
  commit_logs:{pr_id:{bsonType:'long'},commit_sha:{bsonType:'string',pattern:'^[0-9a-f]{40}$'},message:{bsonType:'string',minLength:1},committed_at:{bsonType:'date'},created_at:{bsonType:'date'}},
 };
 for(const name of collections){
  const validator={$jsonSchema:{bsonType:'object',required:[...Object.keys(common),...Object.keys(schemas[name])],additionalProperties:false,properties:{...common,...schemas[name]}}};
  if(await mongo.listCollections({name}).hasNext()) await mongo.command({collMod:name,validator}); else await mongo.createCollection(name,{validator});
  await mongo.collection(name).createIndex({event_id:1},{unique:true});
 }
 await mongo.collection('issue_bodies').createIndex({issue_id:1},{unique:true});
 await mongo.collection('issue_bodies').createIndex({body_markdown:'text'},{default_language:'none'});
 await mongo.collection('comments').createIndex({issue_id:1,created_at:1,_id:1});
 await mongo.collection('comments').createIndex({parent_comment_id:1,created_at:1,_id:1});
 await mongo.collection('comments').createIndex({body_markdown:'text'},{default_language:'none'});
 await mongo.collection('code_snippets').createIndex({issue_id:1,language:1,created_at:1});
 await mongo.collection('commit_logs').createIndex({pr_id:1,commit_sha:1},{unique:true});
 await mongo.collection('commit_logs').createIndex({issue_id:1,committed_at:1,_id:1});
 await mongo.collection('commit_logs').createIndex({author_id:1,committed_at:-1});
}
export function validateContent(name,payload){
 if(!collections.includes(name) || !payload || typeof payload!=='object' || Array.isArray(payload)) fail('E_CONTENT');
 const fields={issue_bodies:['body_markdown'],comments:['body_markdown','parent_comment_id'],code_snippets:['language','code'],commit_logs:['pr_id','commit_sha','message','committed_at']};
 if(Object.keys(payload).some(key=>!fields[name].includes(key))) fail('E_CONTENT');
 const text=(field,max)=>{if(typeof payload[field]!=='string'||!payload[field].trim()||Buffer.byteLength(payload[field],'utf8')>max)fail('E_CONTENT');};
 if(name==='issue_bodies') text('body_markdown',65536);
 if(name==='comments'){text('body_markdown',8192);if(payload.parent_comment_id!=null&&!/^[0-9a-f-]{36}$/.test(payload.parent_comment_id))fail('E_CONTENT');}
 if(name==='code_snippets'){text('code',16384);if(!['SQL','JAVA','PYTHON','JAVASCRIPT'].includes(payload.language))fail('E_CONTENT');}
 if(name==='commit_logs'){text('message',1024);if(!/^[0-9a-f]{40}$/.test(payload.commit_sha)||!/^\d+$/.test(String(payload.pr_id))||!Number.isFinite(Date.parse(payload.committed_at))||Date.parse(payload.committed_at)>Date.now())fail('E_CONTENT');}
 return payload;
}
export async function deliverEvent(row,{ack=true}={}){
 const payload=typeof row.payload_json==='string'?JSON.parse(row.payload_json):row.payload_json;
 const base={_id:row.event_id,event_id:row.event_id,issue_id:long(row.issue_id),author_id:long(payload.author_id)};
 const time=new Date(row.created_at);
 let document;
 if(row.collection_name==='issue_bodies') document={...base,_id:`issue:${row.issue_id}`,version:Number(payload.version),body_markdown:payload.body_markdown,updated_at:time};
 if(row.collection_name==='comments'){
  if(payload.parent_comment_id&&!await mongo.collection('comments').findOne({_id:payload.parent_comment_id}))throw new Error('Parent delivery pending');
  document={...base,parent_comment_id:payload.parent_comment_id||null,body_markdown:payload.body_markdown,created_at:time};
 }
 if(row.collection_name==='code_snippets') document={...base,language:payload.language,code:payload.code,created_at:time};
 if(row.collection_name==='commit_logs') document={...base,pr_id:long(payload.pr_id),commit_sha:payload.commit_sha,message:payload.message,committed_at:new Date(payload.committed_at),created_at:time};
 const target=mongo.collection(row.collection_name);
 if(row.collection_name==='issue_bodies') await target.updateOne({_id:document._id},[{$replaceWith:{$cond:[{$gt:[document.version,{$ifNull:['$version',0]}]},{$literal:document},'$$ROOT']}}],{upsert:true,writeConcern:{w:'majority'}});
 else {try{await target.insertOne(document,{writeConcern:{w:'majority'}});}catch(error){if(error.code!==11000||!await target.findOne({_id:document._id,event_id:row.event_id}))throw error;}}
 if(ack)await command(null,row.event_id,'sp_ack_content',{event_id:row.event_id});
}
export async function flushOutbox(){
 const pending=await query("SELECT * FROM content_outbox WHERE delivery_status='PENDING' ORDER BY created_at,event_id LIMIT 100");
 let delivered=0;
 for(const row of pending){try{await deliverEvent(row);delivered++;}catch(error){console.error(`Content ${row.event_id}: ${error.message}`);}}
 return {pending:pending.length,delivered};
}
export function startWorker(){
 let running=false,failures=0,next=0;
 const timer=setInterval(async()=>{if(running||Date.now()<next)return;running=true;try{const result=await flushOutbox();failures=result.delivered<result.pending?failures+1:0;}catch(error){failures++;console.error('Outbox:',error.message);}finally{next=Date.now()+Math.min(30000,failures?1000*2**Math.min(failures-1,5):0);running=false;}},1000);
 timer.unref(); return ()=>clearInterval(timer);
}
export async function pipeline(name,params){
 const iid=long(params.issue_id||'1'); let collection='comments',stages;
 const stringId=field=>({$toString:`$${field}`});
 switch(name){
 case 'M-01': stages=[{$match:{issue_id:iid}},{$sort:{created_at:1,_id:1}},{$project:{_id:0,comment_id:'$_id',issue_id:stringId('issue_id'),author_id:stringId('author_id'),parent_comment_id:1,body_markdown:1,created_at:1}}];break;
 case 'M-02': stages=[{$match:{issue_id:iid,_id:params.root_comment_id}},{$graphLookup:{from:'comments',startWith:'$_id',connectFromField:'_id',connectToField:'parent_comment_id',as:'replies',restrictSearchWithMatch:{issue_id:iid},maxDepth:9,depthField:'depth'}},{$project:{_id:0,root_comment_id:'$_id',issue_id:stringId('issue_id'),replies:{$map:{input:{$sortArray:{input:'$replies',sortBy:{created_at:1,_id:1}}},as:'r',in:{comment_id:'$$r._id',parent_comment_id:'$$r.parent_comment_id',author_id:{$toString:'$$r.author_id'},body_markdown:'$$r.body_markdown',depth:'$$r.depth',created_at:'$$r.created_at'}}}}}];break;
 case 'M-03': stages=[{$match:{issue_id:iid}},{$group:{_id:{$dateToString:{format:'%Y-%m-%d',date:'$created_at',timezone:'UTC'}},comment_count:{$sum:1},authors:{$addToSet:'$author_id'}}},{$project:{_id:0,day:'$_id',comment_count:1,distinct_authors:{$size:'$authors'}}},{$sort:{day:1}}];break;
 case 'M-04': collection='code_snippets';stages=[{$match:{issue_id:iid}},{$group:{_id:'$language',snippet_count:{$sum:1},total_code_bytes:{$sum:{$strLenBytes:'$code'}},mean_code_bytes:{$avg:{$strLenBytes:'$code'}}}},{$project:{_id:0,language:'$_id',snippet_count:1,total_code_bytes:1,mean_code_bytes:1}},{$sort:{snippet_count:-1,language:1}}];break;
 case 'M-05': {
  if(typeof params.token!=='string'||!/^\S{1,40}$/.test(params.token))fail('E_INPUT');
  const project=source=>({$project:{_id:0,issue_id:1,source:{$literal:source},document_id:'$_id',score:{$meta:'textScore'},excerpt:{$substrCP:['$body_markdown',0,120]}}});
  collection='issue_bodies'; stages=[{$match:{$text:{$search:params.token}}},project('issue_bodies'),{$unionWith:{coll:'comments',pipeline:[{$match:{$text:{$search:params.token}}},project('comments')]}},{$sort:{score:-1,issue_id:1,source:1,document_id:1}},{$limit:20},{$set:{issue_id:{$toString:'$issue_id'}}}];break;
 }
 case 'M-06': collection='commit_logs';stages=[{$match:{issue_id:iid}},{$sort:{committed_at:1,_id:1}},{$project:{_id:0,issue_id:stringId('issue_id'),pr_id:stringId('pr_id'),author_id:stringId('author_id'),commit_sha:1,message:1,committed_at:1}}];break;
 case 'M-07': {
  const from=new Date(params.from),to=new Date(params.to);if(!Number.isFinite(+from)||!Number.isFinite(+to)||from>=to)fail('E_INPUT');
  collection='commit_logs';stages=[{$match:{committed_at:{$gte:from,$lt:to}}},{$group:{_id:'$author_id',commit_count:{$sum:1},issues:{$addToSet:'$issue_id'},first_commit_at:{$min:'$committed_at'},last_commit_at:{$max:'$committed_at'}}},{$sort:{commit_count:-1,_id:1}},{$project:{_id:0,author_id:{$toString:'$_id'},commit_count:1,distinct_issues:{$size:'$issues'},first_commit_at:1,last_commit_at:1}}];break;
 }
 case 'M-08': collection='issue_bodies';stages=[{$match:{issue_id:iid}},...['comments','code_snippets','commit_logs'].map(from=>({$lookup:{from,let:{issue:'$issue_id'},pipeline:[{$match:{$expr:{$eq:['$issue_id','$$issue']}}},{$count:'count'}],as:from}})),{$project:{_id:0,issue_id:stringId('issue_id'),body_version:'$version',body_bytes:{$strLenBytes:'$body_markdown'},comment_count:{$ifNull:[{$first:'$comments.count'},0]},snippet_count:{$ifNull:[{$first:'$code_snippets.count'},0]},commit_count:{$ifNull:[{$first:'$commit_logs.count'},0]}}}];break;
 default:fail('E_NOT_FOUND');
 }
 return mongo.collection(collection).aggregate(stages).toArray();
}
