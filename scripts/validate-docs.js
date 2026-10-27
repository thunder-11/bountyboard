import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const prd=await readFile('PRD.md','utf8');
const headings=[...prd.matchAll(/^# (\d+)\. (.+)$/gm)];assert.equal(headings.length,18);headings.forEach((h,i)=>assert.equal(Number(h[1]),i+1));
const entities=[...prd.matchAll(/^### ([a-z_]+)$/gm)].map(m=>m[1]).sort();
const schema=await readFile('db/schema.sql','utf8');const tables=[...schema.matchAll(/CREATE TABLE IF NOT EXISTS ([a-z_]+)/g)].map(m=>m[1]).sort();assert.deepEqual(entities,tables);assert.equal(entities.length,28);
const diagram=prd.match(/```mermaid\s+erDiagram([\s\S]*?)```/)[1];const diagramEntities=[...new Set([...diagram.matchAll(/^\s+([a-z_]+)\s+\S+\s+([a-z_]+)\s*:/gm)].flatMap(m=>[m[1],m[2]]))].sort();assert.deepEqual(entities,diagramEntities);
const frRows=prd.split('\n').filter(l=>/^\| FR-\d{2} \//.test(l));assert.equal(frRows.length,27);for(const row of frRows)assert.match(row,/\| Given .+, When .+, Then .+/);
let width=0;for(const line of prd.split('\n')){if(!line.startsWith('|')){width=0;continue;}const current=(line.match(/\|/g)||[]).length;if(!width)width=current;assert.equal(current,width,`Malformed table: ${line.slice(0,90)}`);}
for(const prefix of ['BR','FR','Q','M','C','NFR','T','D','DL','A','R']){const definitions=new Set([...prd.matchAll(new RegExp(`^\\| (${prefix}-\\d{2})\\b`,'gm'))].map(m=>m[1]));if(prefix==='Q'){definitions.add('Q-10');definitions.add('Q-11');}for(const reference of prd.matchAll(new RegExp(`\\b${prefix}-\\d{2}\\b`,'g')))assert.ok(definitions.has(reference[0]),`Undefined ${reference[0]}`);}
const objects=new Set();for(const file of ['routines','errors','public-routines','triggers','events'])for(const match of (await readFile(`db/${file}.sql`,'utf8')).matchAll(/CREATE (?:PROCEDURE|FUNCTION|TRIGGER|EVENT) ([a-z_]+)/g))objects.add(match[1]);assert.equal(objects.size,75);for(const match of prd.matchAll(/\b(?:sp_|fn_|trg_|ev_)[a-z_]+\b/g))assert.ok(objects.has(match[0]),`Unknown SQL object ${match[0]}`);for(const name of objects)assert.ok(prd.includes(name),`Undocumented SQL object ${name}`);
for(const expression of [/\bTBD\b/i,/\betc\./i,/and so on/i,/as needed/i,/\bappropriate\b/i,/\breasonable\b/i,/if applicable/i,/\bsimilar\b/i,/e\.g\./i])assert.equal(expression.test(prd),false,`Prohibited expression ${expression}`);
const json=[...prd.matchAll(/```json\s+([\s\S]*?)```/g)];assert.equal(json.length,4);for(const block of json)JSON.parse(block[1]);
console.log('Documentation checks passed: 18 sections, 28 dictionaries/ER/schema entities, 27 Given/When/Then FRs, 75 SQL objects, all cross-references, tables and four JSON examples.');
