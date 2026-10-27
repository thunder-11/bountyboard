export async function api(path,{method='GET',body,key}={}){
 const headers={};if(body!==undefined)headers['Content-Type']='application/json';if(method!=='GET')headers['Idempotency-Key']=key||crypto.randomUUID();
 let response;try{response=await fetch(`/api${path}`,{method,headers,credentials:'same-origin',body:body===undefined?undefined:JSON.stringify(body)});}catch{throw new Error('Cannot reach Bountyboard. Check your connection and try again.');}
 const result=await response.json().catch(()=>({error:{message:'The server returned an invalid response.'}}));
 if(!response.ok)throw Object.assign(new Error(result.error?.message||'Request failed.'),{code:result.error?.code,status:response.status});return result.data;
}
export const money=value=>new Intl.NumberFormat('en-IN',{style:'currency',currency:'INR',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(value||0));
export const day=value=>value?new Date(value).toLocaleDateString('en-IN',{day:'numeric',month:'short',year:'numeric'}):'—';
export const initials=name=>name?.split(/[ _/]+/).filter(Boolean).map(n=>n[0]).slice(0,2).join('').toUpperCase()||'BB';
