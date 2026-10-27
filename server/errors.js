export const errors = {
  E_FORBIDDEN:[403,'Actor is not authorized for this action.'], E_NOT_FOUND:[404,'Referenced record does not exist.'], E_INPUT:[422,'Input violates the declared field contract.'], E_DUPLICATE:[409,'Unique identity already exists.'], E_AMOUNT:[422,'Amount must satisfy the operation minimum and scale.'], E_FUNDS:[409,'Wallet has insufficient available balance.'], E_FROZEN:[409,'Issue escrow is frozen by an open dispute.'], E_DEADLINE:[409,'Issue bounty deadline has elapsed.'], E_STATE:[409,'State transition is not permitted.'], E_CLAIM:[409,'Issue already has an exclusive claim.'], E_CLAIM_EXPIRED:[409,'Claim submission deadline has elapsed.'], E_PERCENT:[422,'Percentages must be positive and sum to 100.00.'], E_REVIEW:[409,'PR does not satisfy the review gate.'], E_ORDER:[409,'Milestone predecessors are not released.'], E_EXTENSION:[409,'Deadline extension is unavailable.'], E_WITHDRAWAL:[409,'Pledge is not eligible for voluntary withdrawal.'], E_DISPUTE:[409,'Issue already has an open dispute.'], E_KEY_REUSE:[409,'Operation key was used with a different request.'], E_INTEGRITY:[500,'Accounting reconciliation failed.'], E_OVERFLOW:[422,'Monetary result exceeds DECIMAL(12,2).'], E_IMMUTABLE:[409,'Append-only record cannot be modified or deleted.'], E_AUDIT_CONTEXT:[500,'Trusted actor and operation context is required.'], E_APPROVALS:[422,'Required approvals must be an integer from 1 to 3.'], E_CONTENT:[422,'Content reference or document contract is invalid.'], E_TRANSACTION:[409,'Procedure requires ownership of a new transaction.'], E_RETRY:[503,'Transaction retry limit reached.'],
};
export function fail(code='E_INPUT'){ const [status,message]=errors[code]; throw Object.assign(new Error(message),{code,status}); }
export function normalizeError(error){
  let code=/^(E_[A-Z_]+)(?::|$)/.exec(error.sqlMessage||error.message||'')?.[1] || error.code;
  if(error.errno===1062) code='E_DUPLICATE';
  if([1264,1690].includes(error.errno)) code='E_OVERFLOW';
  if([1048,1452,3819,1292,1366,1406].includes(error.errno)) code='E_INPUT';
  if(!errors[code]) return {status:error.status||503,body:{code:'E_UNAVAILABLE',message:'The service is temporarily unavailable. Check database health.',retryable:true}};
  return {status:error.status||errors[code][0],body:{code,message:errors[code][1],retryable:code==='E_RETRY'}};
}
