import { randomBytes,scryptSync,timingSafeEqual,createHmac } from 'node:crypto';
import { config } from './config.js';
import { query } from './db.js';
export function hashPassword(password,salt=randomBytes(16).toString('hex')){return `${salt}:${scryptSync(password,salt,64).toString('hex')}`;}
export function verifyPassword(password,encoded){try{const [salt,hash]=encoded.split(':');const expected=Buffer.from(hash,'hex');const actual=scryptSync(password,salt,64);return expected.length===actual.length&&timingSafeEqual(expected,actual);}catch{return false;}}
const sessions=new Map();
const sign=body=>createHmac('sha256',config.secret).update(body).digest('base64url');
export function createSession(userId){
 const nonce=randomBytes(24).toString('hex');const exp=Date.now()+8*60*60*1000;
 for(const [key,value] of sessions)if(value.exp<Date.now())sessions.delete(key);
 sessions.set(nonce,{userId:String(userId),exp});const body=Buffer.from(JSON.stringify({sub:String(userId),exp,nonce})).toString('base64url');return `${body}.${sign(body)}`;
}
export function readSession(token){try{const [body,signature]=token.split('.');const expected=Buffer.from(sign(body));const supplied=Buffer.from(signature);if(expected.length!==supplied.length||!timingSafeEqual(expected,supplied))return null;const payload=JSON.parse(Buffer.from(body,'base64url'));const session=sessions.get(payload.nonce);return session&&session.exp>Date.now()&&session.userId===payload.sub?{...payload,userId:session.userId}:null;}catch{return null;}}
export const cookieOptions={httpOnly:true,sameSite:'strict',secure:process.env.NODE_ENV==='production',path:'/',maxAge:8*60*60*1000};
export function tokenFrom(req){return req.headers.cookie?.split(';').map(s=>s.trim()).find(s=>s.startsWith('bounty_session='))?.slice('bounty_session='.length)||'';}
export function invalidate(token){const session=readSession(token);if(session)sessions.delete(session.nonce);}
export async function userById(id){
 const [user]=await query('SELECT user_id,display_name,email FROM users WHERE user_id=?',[id]);if(!user)return null;
 user.roles=(await query('SELECT role_code FROM user_roles WHERE user_id=?',[id])).map(r=>r.role_code);
 user.repository_ids=(await query('SELECT repository_id FROM repository_maintainers WHERE user_id=?',[id])).map(r=>String(r.repository_id));
 return user;
}
export async function requireAuth(req,res,next){const session=readSession(tokenFrom(req));if(!session)return res.status(401).json({error:{code:'E_UNAUTHENTICATED',message:'Sign in to continue.',retryable:false}});req.user=await userById(session.userId);if(!req.user)return res.status(401).json({error:{code:'E_UNAUTHENTICATED',message:'Session no longer valid.',retryable:false}});next();}
