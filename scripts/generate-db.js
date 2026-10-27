import { writeFile } from 'node:fs/promises';
import { errors } from '../server/errors.js';
export const procedures=['sp_register_user','sp_grant_role','sp_configure_repository','sp_create_issue','sp_update_issue_metadata','sp_configure_milestones','sp_top_up','sp_pledge','sp_withdraw_pledge','sp_claim_issue','sp_submit_pr','sp_set_pr_shares','sp_review_pr','sp_reject_pr','sp_merge_pr','sp_release_milestone','sp_resolve_issue','sp_extend_deadline','sp_close_issue','sp_expire_issue','sp_expire_claim','sp_open_dispute','sp_rule_dispute','sp_enqueue_content','sp_ack_content'];
export async function generate(){
 const failure=`DELIMITER $$\nDROP PROCEDURE IF EXISTS sp_fail$$\nCREATE PROCEDURE sp_fail(IN p_code VARCHAR(30)) BEGIN CASE p_code\n${Object.entries(errors).map(([code,[,message]],i)=>`WHEN '${code}' THEN SIGNAL SQLSTATE '${45001+i}' SET MESSAGE_TEXT='${code}: ${message.replaceAll("'","''")}';`).join('\n')}\nELSE SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='E_INPUT'; END CASE; END$$\nDELIMITER ;\n`;
 await writeFile('db/errors.sql',failure);
 await writeFile('db/public-routines.sql',`DELIMITER $$\n${procedures.map(name=>`DROP PROCEDURE IF EXISTS ${name}$$\nCREATE PROCEDURE ${name}(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'${name}',p_payload,p_result); END$$`).join('\n')}\nDELIMITER ;\n`);
 let triggers='DELIMITER $$\n';
 const entities={issues:'issue_id',claims:'claim_id',pull_requests:'pr_id',pledges:'pledge_id',escrows:'issue_id',milestones:'milestone_id',disputes:'dispute_id'};
 const context="IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;";
 const insertAudit=(table,id,field,old,next)=>`INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('${table}',${id},'${field}',${old},${next},@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id);`;
 for(const [table,id] of Object.entries(entities)){
  for(const event of ['INSERT','UPDATE']){
   const suffix=event==='INSERT'?'ai':'au'; let body=context;
   for(const field of table==='issues'?['status','is_disputed']:['status']){
    const insert=insertAudit(table,`NEW.${id}`,field,event==='INSERT'?'NULL':`CAST(OLD.${field} AS CHAR)`,`CAST(NEW.${field} AS CHAR)`);
    body+=event==='INSERT'?insert:`IF NOT(OLD.${field}<=>NEW.${field}) THEN ${insert} END IF;`;
   }
   triggers+=`DROP TRIGGER IF EXISTS trg_${table}_${suffix}$$\nCREATE TRIGGER trg_${table}_${suffix} AFTER ${event} ON ${table} FOR EACH ROW BEGIN ${body} END$$\n`;
  }
 }
 triggers+=`DROP TRIGGER IF EXISTS trg_milestones_ad$$\nCREATE TRIGGER trg_milestones_ad AFTER DELETE ON milestones FOR EACH ROW BEGIN ${context} IF OLD.status<>'PENDING' THEN CALL sp_fail('E_STATE'); END IF; ${insertAudit('milestones','OLD.milestone_id','status','OLD.status',"'REMOVED'")} END$$\n`;
 for(const table of ['ledger_entries','journal_transactions','releases','release_funding','payouts','refunds','reputation_events','audit_log','pr_reviews']) for(const [event,suffix] of [['UPDATE','bu'],['DELETE','bd']]) triggers+=`DROP TRIGGER IF EXISTS trg_${table}_${suffix}$$\nCREATE TRIGGER trg_${table}_${suffix} BEFORE ${event} ON ${table} FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$\n`;
 triggers+=`DROP TRIGGER IF EXISTS trg_ledger_entries_ai$$\nCREATE TRIGGER trg_ledger_entries_ai AFTER INSERT ON ledger_entries FOR EACH ROW BEGIN ${context} UPDATE wallets SET balance=balance+NEW.signed_amount WHERE account_id=NEW.account_id; UPDATE escrows SET held_amount=held_amount+NEW.signed_amount WHERE account_id=NEW.account_id; END$$\nDELIMITER ;\n`;
 await writeFile('db/triggers.sql',triggers);
 let events='DELIMITER $$\n';
 for(const [name,table,id,where,proc] of [['bounty_deadlines','issues','issue_id',"status NOT IN('RESOLVED','CLOSED') AND is_disputed=FALSE AND bounty_deadline<=SYSDATE(6)",'sp_expire_issue'],['claim_expiry','claims','claim_id',"status='ACTIVE' AND expires_at<=SYSDATE(6)",'sp_expire_claim']]){
  events+=`DROP EVENT IF EXISTS ev_${name}$$\nCREATE EVENT ev_${name} ON SCHEDULE EVERY 1 MINUTE STARTS CURRENT_TIMESTAMP + INTERVAL 1 MINUTE DISABLE DO BEGIN DECLARE done BOOLEAN DEFAULT FALSE; DECLARE entity BIGINT UNSIGNED; DECLARE cur CURSOR FOR SELECT ${id} FROM ${table} WHERE ${where} ORDER BY ${id}; DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=TRUE; DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END; OPEN cur; event_loop: LOOP FETCH cur INTO entity; IF done THEN LEAVE event_loop; END IF; CALL ${proc}(NULL,CONCAT(LEFT(MD5(CONCAT('${name}',entity)),32),'0000'),JSON_OBJECT('${id}',entity),@job_result); END LOOP; CLOSE cur; END$$\n`;
 }
 await writeFile('db/events.sql',events+'DELIMITER ;\n');
}
if(process.argv[1]?.endsWith('generate-db.js')) await generate();
