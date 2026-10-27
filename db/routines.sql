DELIMITER $$
DROP FUNCTION IF EXISTS fn_has_role$$
CREATE FUNCTION fn_has_role(p_user BIGINT UNSIGNED,p_role VARCHAR(11)) RETURNS BOOLEAN READS SQL DATA
RETURN EXISTS(SELECT 1 FROM user_roles WHERE user_id=p_user AND role_code=p_role)$$
DROP FUNCTION IF EXISTS fn_is_maintainer$$
CREATE FUNCTION fn_is_maintainer(p_user BIGINT UNSIGNED,p_repo BIGINT UNSIGNED) RETURNS BOOLEAN READS SQL DATA
RETURN fn_has_role(p_user,'MAINTAINER') AND EXISTS(SELECT 1 FROM repository_maintainers WHERE user_id=p_user AND repository_id=p_repo)$$
DROP FUNCTION IF EXISTS fn_is_participant$$
CREATE FUNCTION fn_is_participant(p_user BIGINT UNSIGNED,p_issue BIGINT UNSIGNED) RETURNS BOOLEAN READS SQL DATA
RETURN EXISTS(SELECT 1 FROM pledges WHERE backer_id=p_user AND issue_id=p_issue) OR EXISTS(SELECT 1 FROM claims WHERE claimant_id=p_user AND issue_id=p_issue)$$
DROP FUNCTION IF EXISTS fn_difficulty_multiplier$$
CREATE FUNCTION fn_difficulty_multiplier(p_difficulty VARCHAR(6)) RETURNS TINYINT UNSIGNED DETERMINISTIC
RETURN CASE p_difficulty WHEN 'EASY' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'HARD' THEN 3 ELSE 0 END$$
DROP FUNCTION IF EXISTS fn_pledge_remaining$$
CREATE FUNCTION fn_pledge_remaining(p_pledge_id BIGINT UNSIGNED) RETURNS DECIMAL(12,2) READS SQL DATA
RETURN (SELECT p.amount-COALESCE((SELECT SUM(f.amount) FROM release_funding f WHERE f.pledge_id=p.pledge_id),0)-COALESCE((SELECT SUM(r.amount) FROM refunds r WHERE r.pledge_id=p.pledge_id),0) FROM pledges p WHERE p.pledge_id=p_pledge_id)$$
DROP PROCEDURE IF EXISTS sp_lock_wallets$$
CREATE PROCEDURE sp_lock_wallets()
BEGIN
 DECLARE done BOOLEAN DEFAULT FALSE; DECLARE uid BIGINT UNSIGNED; DECLARE b DECIMAL(12,2);
 DECLARE cur CURSOR FOR SELECT user_id FROM wallets ORDER BY user_id;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=TRUE;
 OPEN cur;
 lock_loop: LOOP FETCH cur INTO uid; IF done THEN LEAVE lock_loop; END IF; SELECT balance INTO b FROM wallets WHERE user_id=uid FOR UPDATE; END LOOP;
 CLOSE cur;
END$$
DROP PROCEDURE IF EXISTS sp_assert_financial_integrity$$
DROP PROCEDURE IF EXISTS sp_lock_workflow$$
CREATE PROCEDURE sp_lock_workflow(IN p_issue BIGINT UNSIGNED)
BEGIN
 DECLARE done BOOLEAN DEFAULT FALSE; DECLARE phase_var INT; DECLARE lock_a BIGINT UNSIGNED; DECLARE lock_b BIGINT UNSIGNED; DECLARE locked_var BIGINT UNSIGNED;
 DECLARE cur CURSOR FOR
 SELECT 1 phase,claim_id pk_one,0 pk_two FROM claims WHERE issue_id=p_issue
 UNION ALL SELECT 2,r.pr_id,0 FROM pull_requests r JOIN claims c USING(claim_id) WHERE c.issue_id=p_issue
 UNION ALL SELECT 3,pc.pr_id,pc.user_id FROM pr_contributors pc JOIN pull_requests r USING(pr_id) JOIN claims c USING(claim_id) WHERE c.issue_id=p_issue
 UNION ALL SELECT 4,v.review_id,0 FROM pr_reviews v JOIN pull_requests r USING(pr_id) JOIN claims c USING(claim_id) WHERE c.issue_id=p_issue
 UNION ALL SELECT 5,milestone_id,0 FROM milestones WHERE issue_id=p_issue
 UNION ALL SELECT 6,pledge_id,0 FROM pledges WHERE issue_id=p_issue
 UNION ALL SELECT 7,f.release_id,f.pledge_id FROM release_funding f JOIN pledges p USING(pledge_id) WHERE p.issue_id=p_issue
 UNION ALL SELECT 8,r.release_id,0 FROM releases r JOIN milestones m USING(milestone_id) WHERE m.issue_id=p_issue
 UNION ALL SELECT 9,f.refund_id,0 FROM refunds f JOIN pledges p USING(pledge_id) WHERE p.issue_id=p_issue
 UNION ALL SELECT 10,dispute_id,0 FROM disputes WHERE issue_id=p_issue
 ORDER BY phase,pk_one,pk_two;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=TRUE;
 OPEN cur;
 lock_loop: LOOP
  FETCH cur INTO phase_var,lock_a,lock_b; IF done THEN LEAVE lock_loop; END IF;
  CASE phase_var
   WHEN 1 THEN SELECT claim_id INTO locked_var FROM claims WHERE claim_id=lock_a FOR UPDATE;
   WHEN 2 THEN SELECT pr_id INTO locked_var FROM pull_requests WHERE pr_id=lock_a FOR UPDATE;
   WHEN 3 THEN SELECT pr_id INTO locked_var FROM pr_contributors WHERE pr_id=lock_a AND user_id=lock_b FOR UPDATE;
   WHEN 4 THEN SELECT review_id INTO locked_var FROM pr_reviews WHERE review_id=lock_a FOR UPDATE;
   WHEN 5 THEN SELECT milestone_id INTO locked_var FROM milestones WHERE milestone_id=lock_a FOR UPDATE;
   WHEN 6 THEN SELECT pledge_id INTO locked_var FROM pledges WHERE pledge_id=lock_a FOR UPDATE;
   WHEN 7 THEN SELECT release_id INTO locked_var FROM release_funding WHERE release_id=lock_a AND pledge_id=lock_b FOR UPDATE;
   WHEN 8 THEN SELECT release_id INTO locked_var FROM releases WHERE release_id=lock_a FOR UPDATE;
   WHEN 9 THEN SELECT refund_id INTO locked_var FROM refunds WHERE refund_id=lock_a FOR UPDATE;
   WHEN 10 THEN SELECT dispute_id INTO locked_var FROM disputes WHERE dispute_id=lock_a FOR UPDATE;
  END CASE;
 END LOOP;
 CLOSE cur;
END$$
CREATE PROCEDURE sp_assert_financial_integrity(IN p_issue_id BIGINT UNSIGNED,IN p_user_ids JSON,IN p_transaction_id BIGINT UNSIGNED,OUT p_ok BOOLEAN)
BEGIN
 IF EXISTS(SELECT 1 FROM v_reconciliation WHERE delta<>0) THEN CALL sp_fail('E_INTEGRITY'); END IF;
 IF EXISTS(SELECT 1 FROM pledges WHERE fn_pledge_remaining(pledge_id)<0) THEN CALL sp_fail('E_INTEGRITY'); END IF;
 IF EXISTS(SELECT 1 FROM releases r WHERE r.amount<>COALESCE((SELECT SUM(amount) FROM payouts WHERE release_id=r.release_id),0) OR r.amount<>COALESCE((SELECT SUM(amount) FROM release_funding WHERE release_id=r.release_id),0)) THEN CALL sp_fail('E_INTEGRITY'); END IF;
 SET p_ok=TRUE;
END$$
DROP PROCEDURE IF EXISTS sp_refund_remaining$$
CREATE PROCEDURE sp_refund_remaining(IN p_issue_id BIGINT UNSIGNED,IN p_reason VARCHAR(10),IN p_pledge_id BIGINT UNSIGNED,OUT p_total DECIMAL(12,2))
BEGIN
 DECLARE done BOOLEAN DEFAULT FALSE; DECLARE pid BIGINT UNSIGNED; DECLARE uid BIGINT UNSIGNED; DECLARE wallet_account BIGINT UNSIGNED; DECLARE amt DECIMAL(12,2); DECLARE tx BIGINT UNSIGNED; DECLARE escrow_account BIGINT UNSIGNED;
 DECLARE cur CURSOR FOR SELECT pledge_id,backer_id FROM pledges WHERE issue_id=p_issue_id AND(p_pledge_id IS NULL OR pledge_id=p_pledge_id) ORDER BY pledge_id;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=TRUE;
 SELECT COALESCE(SUM(fn_pledge_remaining(pledge_id)),0) INTO p_total FROM pledges WHERE issue_id=p_issue_id AND(p_pledge_id IS NULL OR pledge_id=p_pledge_id);
 IF p_total>0 THEN
  CALL sp_lock_wallets();
  SELECT account_id INTO escrow_account FROM escrows WHERE issue_id=p_issue_id;
  INSERT INTO journal_transactions(operation_id,transaction_kind) VALUES(@operation_id,'REFUND'); SET tx=LAST_INSERT_ID();
  INSERT INTO ledger_entries(transaction_id,account_id,signed_amount) VALUES(tx,escrow_account,-p_total);
  OPEN cur;
  refund_loop: LOOP
   FETCH cur INTO pid,uid; IF done THEN LEAVE refund_loop; END IF;
   SET amt=fn_pledge_remaining(pid);
   IF amt>0 THEN
    IF(SELECT balance+amt>9999999999.99 FROM wallets WHERE user_id=uid) THEN CALL sp_fail('E_OVERFLOW'); END IF;
    INSERT INTO refunds(pledge_id,amount,reason,transaction_id) VALUES(pid,amt,p_reason,tx);
    SELECT account_id INTO wallet_account FROM wallets WHERE user_id=uid;
    INSERT INTO ledger_entries(transaction_id,account_id,signed_amount) VALUES(tx,wallet_account,amt);
    UPDATE pledges SET status=IF(amt=amount,'REFUNDED','PARTIALLY_REFUNDED') WHERE pledge_id=pid;
   END IF;
  END LOOP;
  CLOSE cur;
 END IF;
END$$
DROP PROCEDURE IF EXISTS sp_close_locked_issue$$
CREATE PROCEDURE sp_close_locked_issue(IN p_issue_id BIGINT UNSIGNED,IN p_reason VARCHAR(10),OUT p_total DECIMAL(12,2))
BEGIN
 CALL sp_refund_remaining(p_issue_id,p_reason,NULL,p_total);
 UPDATE pull_requests p JOIN claims c ON c.claim_id=p.claim_id SET p.status='CANCELLED' WHERE c.issue_id=p_issue_id AND p.status='SUBMITTED';
 UPDATE claims SET status='CANCELLED' WHERE issue_id=p_issue_id AND status IN('ACTIVE','SUBMITTED');
 UPDATE milestones SET status='CANCELLED' WHERE issue_id=p_issue_id AND status='PENDING';
 UPDATE issues SET status='CLOSED',is_disputed=FALSE WHERE issue_id=p_issue_id;
 UPDATE escrows SET status='SETTLED' WHERE issue_id=p_issue_id;
END$$
DROP PROCEDURE IF EXISTS sp_post_release$$
CREATE PROCEDURE sp_post_release(IN p_milestone_id BIGINT UNSIGNED,OUT p_release_id BIGINT UNSIGNED)
BEGIN
 DECLARE iid BIGINT UNSIGNED; DECLARE prid BIGINT UNSIGNED; DECLARE tx BIGINT UNSIGNED; DECLARE seq SMALLINT; DECLARE pool_paise DECIMAL(32,0); DECLARE amount_paise DECIMAL(32,0); DECLARE extras INT; DECLARE amt DECIMAL(12,2); DECLARE remaining DECIMAL(12,2); DECLARE take_amount DECIMAL(12,2); DECLARE escrow_account BIGINT UNSIGNED;
 DECLARE done BOOLEAN DEFAULT FALSE; DECLARE pid BIGINT UNSIGNED; DECLARE uid BIGINT UNSIGNED; DECLARE wallet_account BIGINT UNSIGNED; DECLARE payout_paise DECIMAL(32,0);
 DECLARE funding CURSOR FOR SELECT pledge_id FROM pledges WHERE issue_id=iid ORDER BY created_at,pledge_id;
 DECLARE payees CURSOR FOR SELECT user_id,FLOOR(amount_paise*share_percent/100)+IF(ROW_NUMBER() OVER(ORDER BY MOD(amount_paise*(share_percent*100),10000) DESC,user_id)<=extras,1,0) FROM pr_contributors WHERE pr_id=prid ORDER BY user_id;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=TRUE;
 SELECT issue_id,sequence_no INTO iid,seq FROM milestones WHERE milestone_id=p_milestone_id;
 IF EXISTS(SELECT 1 FROM milestones WHERE issue_id=iid AND sequence_no<seq AND status<>'RELEASED') THEN CALL sp_fail('E_ORDER'); END IF;
 SELECT p.pr_id INTO prid FROM pull_requests p JOIN claims c USING(claim_id) WHERE c.issue_id=iid AND p.status='MERGED';
 IF prid IS NULL THEN CALL sp_fail('E_REVIEW'); END IF;
 SELECT (total_pledged-total_refunded)*100 INTO pool_paise FROM v_issue_funding WHERE issue_id=iid;
 SELECT pool_paise-SUM(FLOOR(pool_paise*percent/100)) INTO extras FROM milestones WHERE issue_id=iid;
 SELECT allocated INTO amount_paise FROM(SELECT milestone_id,FLOOR(pool_paise*percent/100)+IF(ROW_NUMBER() OVER(ORDER BY MOD(pool_paise*(percent*100),10000) DESC,sequence_no)<=extras,1,0) allocated FROM milestones WHERE issue_id=iid)budgets WHERE milestone_id=p_milestone_id;
 SET amt=amount_paise/100; SET remaining=amt;
 CALL sp_lock_wallets();
 SELECT account_id INTO escrow_account FROM escrows WHERE issue_id=iid;
 IF(SELECT held_amount FROM escrows WHERE issue_id=iid)<amt THEN CALL sp_fail('E_INTEGRITY'); END IF;
 INSERT INTO journal_transactions(operation_id,transaction_kind) VALUES(@operation_id,'RELEASE'); SET tx=LAST_INSERT_ID();
 INSERT INTO releases(milestone_id,amount,transaction_id) VALUES(p_milestone_id,amt,tx); SET p_release_id=LAST_INSERT_ID();
 IF amt>0 THEN INSERT INTO ledger_entries(transaction_id,account_id,signed_amount) VALUES(tx,escrow_account,-amt); END IF;
 SET done=FALSE; OPEN funding;
 funding_loop: LOOP
  FETCH funding INTO pid; IF done OR remaining=0 THEN LEAVE funding_loop; END IF;
  SET take_amount=LEAST(remaining,fn_pledge_remaining(pid));
  IF take_amount>0 THEN
   INSERT INTO release_funding VALUES(p_release_id,pid,take_amount);
   UPDATE pledges SET status=IF(fn_pledge_remaining(pid)=0,'RELEASED','PARTIALLY_RELEASED') WHERE pledge_id=pid;
   SET remaining=remaining-take_amount;
  END IF;
 END LOOP; CLOSE funding;
 IF remaining<>0 THEN CALL sp_fail('E_INTEGRITY'); END IF;
 SELECT amount_paise-SUM(FLOOR(amount_paise*share_percent/100)) INTO extras FROM pr_contributors WHERE pr_id=prid;
 SET done=FALSE; OPEN payees;
 payout_loop: LOOP
  FETCH payees INTO uid,payout_paise; IF done THEN LEAVE payout_loop; END IF;
  IF(SELECT balance+payout_paise/100>9999999999.99 FROM wallets WHERE user_id=uid) THEN CALL sp_fail('E_OVERFLOW'); END IF;
  INSERT INTO payouts VALUES(p_release_id,uid,payout_paise/100);
  IF payout_paise>0 THEN SELECT account_id INTO wallet_account FROM wallets WHERE user_id=uid; INSERT INTO ledger_entries(transaction_id,account_id,signed_amount) VALUES(tx,wallet_account,payout_paise/100); END IF;
 END LOOP; CLOSE payees;
 UPDATE milestones SET status='RELEASED' WHERE milestone_id=p_milestone_id;
END$$
DROP PROCEDURE IF EXISTS sp_replace_shares$$
CREATE PROCEDURE sp_replace_shares(IN p_pr BIGINT UNSIGNED,IN p_author BIGINT UNSIGNED,IN p_shares JSON)
BEGIN
 IF JSON_TYPE(p_shares)<>'ARRAY' OR JSON_LENGTH(p_shares)=0 OR (SELECT COALESCE(SUM(share_percent),0) FROM JSON_TABLE(p_shares,'$[*]' COLUMNS(share_percent DECIMAL(8,2) PATH '$.share_percent'))j)<>100 THEN CALL sp_fail('E_PERCENT'); END IF;
 IF EXISTS(SELECT 1 FROM JSON_TABLE(p_shares,'$[*]' COLUMNS(user_id BIGINT PATH '$.user_id',share_percent DECIMAL(8,2) PATH '$.share_percent'))j WHERE share_percent<=0 OR share_percent>100) THEN CALL sp_fail('E_PERCENT'); END IF;
 IF(SELECT COUNT(DISTINCT user_id) FROM JSON_TABLE(p_shares,'$[*]' COLUMNS(user_id BIGINT PATH '$.user_id'))j)<>JSON_LENGTH(p_shares) OR NOT EXISTS(SELECT 1 FROM JSON_TABLE(p_shares,'$[*]' COLUMNS(user_id BIGINT PATH '$.user_id'))j WHERE user_id=p_author) OR EXISTS(SELECT 1 FROM JSON_TABLE(p_shares,'$[*]' COLUMNS(user_id BIGINT PATH '$.user_id'))j WHERE NOT fn_has_role(user_id,'CONTRIBUTOR')) THEN CALL sp_fail('E_INPUT'); END IF;
 DELETE FROM pr_contributors WHERE pr_id=p_pr;
 INSERT INTO pr_contributors SELECT p_pr,user_id,share_percent FROM JSON_TABLE(p_shares,'$[*]' COLUMNS(user_id BIGINT PATH '$.user_id',share_percent DECIMAL(5,2) PATH '$.share_percent'))j;
END$$
DROP PROCEDURE IF EXISTS sp_command$$
CREATE PROCEDURE sp_command(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_action VARCHAR(40),IN p JSON,OUT p_result JSON)
main: BEGIN
 DECLARE iid BIGINT UNSIGNED; DECLARE rid BIGINT UNSIGNED; DECLARE cid BIGINT UNSIGNED; DECLARE prid BIGINT UNSIGNED; DECLARE mid BIGINT UNSIGNED; DECLARE pid BIGINT UNSIGNED; DECLARE did BIGINT UNSIGNED; DECLARE uid BIGINT UNSIGNED; DECLARE aid BIGINT UNSIGNED; DECLARE eid BIGINT UNSIGNED; DECLARE tx BIGINT UNSIGNED; DECLARE release_id_var BIGINT UNSIGNED;
 DECLARE status_var VARCHAR(20); DECLARE pr_status VARCHAR(20); DECLARE difficulty_var VARCHAR(6); DECLARE frozen BOOLEAN; DECLARE deadline_var DATETIME(6); DECLARE now_var DATETIME(6); DECLARE expires_var DATETIME(6); DECLARE author_var BIGINT UNSIGNED; DECLARE amount_var DECIMAL(12,2); DECLARE total_var DECIMAL(12,2); DECLARE balance_var DECIMAL(12,2); DECLARE percent_var DECIMAL(10,2); DECLARE count_var INT; DECLARE index_var INT DEFAULT 0; DECLARE text_var LONGTEXT; DECLARE parent_var CHAR(36); DECLARE depth_var INT DEFAULT 0; DECLARE event_var CHAR(36); DECLARE hash_var BINARY(32); DECLARE stored_hash BINARY(32); DECLARE result_var JSON; DECLARE ok_var BOOLEAN;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @actor_id=NULL,@operation_id=NULL; RESIGNAL; END;
 IF @@session.autocommit=0 OR EXISTS(SELECT 1 FROM information_schema.innodb_trx WHERE trx_mysql_thread_id=CONNECTION_ID()) THEN CALL sp_fail('E_TRANSACTION'); END IF;
 SET TRANSACTION ISOLATION LEVEL READ COMMITTED; START TRANSACTION;
 IF p_actor_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor_id) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
 SET hash_var=UNHEX(SHA2(CONCAT(p_action,CAST(p AS CHAR)),256));
 INSERT INTO operation_requests(actor_key,request_key,operation_kind,payload_hash,result_json) VALUES(COALESCE(p_actor_id,0),p_request_key,p_action,hash_var,JSON_OBJECT('pending',TRUE)) ON DUPLICATE KEY UPDATE operation_id=LAST_INSERT_ID(operation_id);
 SET @operation_id=LAST_INSERT_ID(),@actor_id=p_actor_id;
 SELECT payload_hash,result_json INTO stored_hash,result_var FROM operation_requests WHERE operation_id=@operation_id FOR UPDATE;
 IF stored_hash<>hash_var THEN CALL sp_fail('E_KEY_REUSE'); END IF;
 IF JSON_EXTRACT(result_var,'$.pending') IS NULL THEN SET p_result=result_var; COMMIT; SET @actor_id=NULL,@operation_id=NULL; LEAVE main; END IF;
 SET iid=JSON_VALUE(p,'$.issue_id' RETURNING UNSIGNED),rid=JSON_VALUE(p,'$.repository_id' RETURNING UNSIGNED),cid=JSON_VALUE(p,'$.claim_id' RETURNING UNSIGNED),prid=JSON_VALUE(p,'$.pr_id' RETURNING UNSIGNED),mid=JSON_VALUE(p,'$.milestone_id' RETURNING UNSIGNED),pid=JSON_VALUE(p,'$.pledge_id' RETURNING UNSIGNED),did=JSON_VALUE(p,'$.dispute_id' RETURNING UNSIGNED),uid=JSON_VALUE(p,'$.user_id' RETURNING UNSIGNED);
 IF cid IS NOT NULL THEN SELECT issue_id INTO iid FROM claims WHERE claim_id=cid; END IF;
 IF prid IS NOT NULL THEN SELECT c.issue_id,c.claimant_id,c.claim_id,r.status INTO iid,author_var,cid,pr_status FROM pull_requests r JOIN claims c USING(claim_id) WHERE r.pr_id=prid; END IF;
 IF mid IS NOT NULL THEN SELECT issue_id INTO iid FROM milestones WHERE milestone_id=mid; END IF;
 IF pid IS NOT NULL THEN SELECT issue_id INTO iid FROM pledges WHERE pledge_id=pid; END IF;
 IF did IS NOT NULL THEN SELECT issue_id INTO iid FROM disputes WHERE dispute_id=did; END IF;
 IF (cid IS NOT NULL OR prid IS NOT NULL OR mid IS NOT NULL OR pid IS NOT NULL OR did IS NOT NULL) AND iid IS NULL THEN CALL sp_fail('E_NOT_FOUND'); END IF;
 IF iid IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM issues WHERE issue_id=iid) THEN CALL sp_fail('E_NOT_FOUND'); END IF;
  SELECT repository_id,status,is_disputed,bounty_deadline,difficulty INTO rid,status_var,frozen,deadline_var,difficulty_var FROM issues WHERE issue_id=iid FOR UPDATE;
  SELECT account_id INTO eid FROM escrows WHERE issue_id=iid FOR UPDATE;
  IF mid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM milestones WHERE milestone_id=mid AND issue_id=iid) THEN CALL sp_fail('E_NOT_FOUND'); END IF;
  IF p_action='sp_merge_pr' THEN SELECT required_approvals INTO count_var FROM repositories WHERE repository_id=rid FOR SHARE; END IF;
  CALL sp_lock_workflow(iid);
  IF prid IS NOT NULL THEN SELECT status INTO pr_status FROM pull_requests WHERE pr_id=prid; END IF;
 END IF;
 SET now_var=SYSDATE(6);
 IF p_action IN('sp_update_issue_metadata','sp_configure_milestones','sp_review_pr','sp_reject_pr','sp_merge_pr','sp_release_milestone','sp_resolve_issue','sp_extend_deadline','sp_close_issue') AND NOT fn_is_maintainer(p_actor_id,rid) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
 IF p_action='sp_pledge' AND NOT fn_has_role(p_actor_id,'BACKER') THEN CALL sp_fail('E_FORBIDDEN'); END IF;
 IF p_action='sp_claim_issue' AND NOT fn_has_role(p_actor_id,'CONTRIBUTOR') THEN CALL sp_fail('E_FORBIDDEN'); END IF;
 IF p_action IN('sp_submit_pr','sp_set_pr_shares') AND NOT EXISTS(SELECT 1 FROM claims WHERE claim_id=cid AND claimant_id=p_actor_id) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
 IF p_action='sp_withdraw_pledge' AND NOT EXISTS(SELECT 1 FROM pledges WHERE pledge_id=pid AND backer_id=p_actor_id) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
 IF p_action IN('sp_release_milestone','sp_resolve_issue') THEN
  IF NOT fn_is_maintainer(p_actor_id,rid) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF mid IS NULL THEN SELECT milestone_id INTO mid FROM milestones WHERE issue_id=iid ORDER BY sequence_no DESC LIMIT 1; END IF;
  IF p_action='sp_release_milestone' AND mid=(SELECT milestone_id FROM milestones WHERE issue_id=iid ORDER BY sequence_no DESC LIMIT 1) THEN CALL sp_fail('E_STATE'); END IF;
  IF EXISTS(SELECT 1 FROM releases WHERE milestone_id=mid) THEN
   SELECT JSON_OBJECT('operation_id',@operation_id,'release_id',release_id,'transaction_id',transaction_id,'amount',CAST(amount AS CHAR),'replayed',TRUE) INTO result_var FROM releases WHERE milestone_id=mid;
   UPDATE operation_requests SET result_json=result_var WHERE operation_id=@operation_id; COMMIT; SET p_result=result_var,@operation_id=NULL,@actor_id=NULL; LEAVE main;
  END IF;
 END IF;
 IF frozen AND p_action NOT IN('sp_review_pr','sp_open_dispute','sp_rule_dispute','sp_enqueue_content','sp_ack_content','sp_expire_issue','sp_expire_claim') THEN CALL sp_fail('E_FROZEN'); END IF;
 IF iid IS NOT NULL AND p_action IN('sp_pledge','sp_claim_issue','sp_submit_pr','sp_set_pr_shares','sp_reject_pr','sp_merge_pr','sp_release_milestone','sp_resolve_issue','sp_extend_deadline') AND now_var>=deadline_var THEN CALL sp_fail('E_DEADLINE'); END IF;
 SET result_var=JSON_OBJECT('operation_id',@operation_id);
 CASE p_action
 WHEN 'sp_register_user' THEN
  IF NOT fn_has_role(p_actor_id,'ADMIN') THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF JSON_LENGTH(JSON_EXTRACT(p,'$.roles'))=0 OR EXISTS(SELECT 1 FROM JSON_TABLE(p,'$.roles[*]' COLUMNS(role_code VARCHAR(11) PATH '$'))j WHERE role_code NOT IN('ADMIN','MAINTAINER','CONTRIBUTOR','BACKER')) THEN CALL sp_fail('E_INPUT'); END IF;
  INSERT INTO users(display_name,email,password_hash) VALUES(JSON_UNQUOTE(p->'$.display_name'),LOWER(JSON_UNQUOTE(p->'$.email')),JSON_UNQUOTE(p->'$.password_hash')); SET uid=LAST_INSERT_ID();
  INSERT INTO user_roles SELECT uid,role_code FROM JSON_TABLE(p,'$.roles[*]' COLUMNS(role_code VARCHAR(11) PATH '$'))j;
  INSERT INTO accounts(account_kind) VALUES('WALLET'); SET aid=LAST_INSERT_ID(); INSERT INTO wallets(user_id,account_id) VALUES(uid,aid);
  SET result_var=JSON_SET(result_var,'$.user_id',uid);
 WHEN 'sp_grant_role' THEN
  IF NOT fn_has_role(p_actor_id,'ADMIN') THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  INSERT IGNORE INTO user_roles VALUES(uid,JSON_UNQUOTE(p->'$.role_code'));
 WHEN 'sp_configure_repository' THEN
  IF NOT fn_has_role(p_actor_id,'ADMIN') THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  SET count_var=JSON_VALUE(p,'$.required_approvals' RETURNING UNSIGNED);
  IF count_var NOT BETWEEN 1 AND 3 THEN CALL sp_fail('E_APPROVALS'); END IF;
  IF JSON_LENGTH(p->'$.maintainer_ids')=0 OR EXISTS(SELECT 1 FROM JSON_TABLE(p,'$.maintainer_ids[*]' COLUMNS(user_id BIGINT PATH '$'))j WHERE NOT fn_has_role(user_id,'MAINTAINER')) THEN CALL sp_fail('E_INPUT'); END IF;
  IF rid IS NULL THEN INSERT INTO repositories(repository_name,required_approvals) VALUES(JSON_UNQUOTE(p->'$.repository_name'),count_var); SET rid=LAST_INSERT_ID(); ELSE UPDATE repositories SET repository_name=JSON_UNQUOTE(p->'$.repository_name'),required_approvals=count_var WHERE repository_id=rid; END IF;
  DELETE FROM repository_maintainers WHERE repository_id=rid;
  INSERT INTO repository_maintainers SELECT rid,user_id FROM JSON_TABLE(p,'$.maintainer_ids[*]' COLUMNS(user_id BIGINT PATH '$'))j;
  SET result_var=JSON_SET(result_var,'$.repository_id',rid);
 WHEN 'sp_create_issue' THEN
  IF NOT fn_is_maintainer(p_actor_id,rid) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  INSERT INTO issues(repository_id,created_by,title,issue_kind,difficulty,bounty_deadline) VALUES(rid,p_actor_id,JSON_UNQUOTE(p->'$.title'),JSON_UNQUOTE(p->'$.issue_kind'),JSON_UNQUOTE(p->'$.difficulty'),now_var+INTERVAL 60 DAY); SET iid=LAST_INSERT_ID();
  INSERT INTO accounts(account_kind) VALUES('ESCROW'); SET eid=LAST_INSERT_ID(); INSERT INTO escrows(issue_id,account_id) VALUES(iid,eid);
  INSERT INTO milestones(issue_id,sequence_no,title,percent) VALUES(iid,1,'Issue resolved',100);
  INSERT INTO issue_labels SELECT iid,label_id FROM JSON_TABLE(p,'$.label_ids[*]' COLUMNS(label_id BIGINT PATH '$'))j;
  SET event_var=UUID(); INSERT INTO content_outbox(event_id,operation_id,issue_id,collection_name,payload_json) VALUES(event_var,@operation_id,iid,'issue_bodies',JSON_OBJECT('body_markdown',JSON_UNQUOTE(p->'$.body_markdown'),'version',1,'author_id',p_actor_id));
  SET result_var=JSON_SET(result_var,'$.issue_id',iid,'$.event_id',event_var);
 WHEN 'sp_update_issue_metadata' THEN
  IF NOT fn_is_maintainer(p_actor_id,rid) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF status_var IN('RESOLVED','CLOSED') THEN CALL sp_fail('E_STATE'); END IF;
  IF EXISTS(SELECT 1 FROM claims WHERE issue_id=iid) AND EXISTS(SELECT 1 FROM issues WHERE issue_id=iid AND(difficulty<>JSON_UNQUOTE(p->'$.difficulty') OR issue_kind<>JSON_UNQUOTE(p->'$.issue_kind'))) THEN CALL sp_fail('E_STATE'); END IF;
  UPDATE issues SET title=JSON_UNQUOTE(p->'$.title'),difficulty=JSON_UNQUOTE(p->'$.difficulty'),issue_kind=JSON_UNQUOTE(p->'$.issue_kind') WHERE issue_id=iid;
  DELETE FROM issue_labels WHERE issue_id=iid; INSERT INTO issue_labels SELECT iid,label_id FROM JSON_TABLE(p,'$.label_ids[*]' COLUMNS(label_id BIGINT PATH '$'))j;
 WHEN 'sp_configure_milestones' THEN
  IF NOT fn_is_maintainer(p_actor_id,rid) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF status_var<>'OPEN' OR EXISTS(SELECT 1 FROM claims WHERE issue_id=iid) OR EXISTS(SELECT 1 FROM pledges WHERE issue_id=iid) THEN CALL sp_fail('E_STATE'); END IF;
  SET count_var=JSON_LENGTH(p->'$.stages');
  IF count_var NOT BETWEEN 1 AND 10 OR (SELECT SUM(percent) FROM JSON_TABLE(p,'$.stages[*]' COLUMNS(percent DECIMAL(8,2) PATH '$.percent'))j)<>100 OR EXISTS(SELECT 1 FROM JSON_TABLE(p,'$.stages[*]' COLUMNS(percent DECIMAL(8,2) PATH '$.percent'))j WHERE percent<=0 OR percent>100) THEN CALL sp_fail('E_PERCENT'); END IF;
  IF(SELECT COUNT(DISTINCT sequence_no) FROM JSON_TABLE(p,'$.stages[*]' COLUMNS(sequence_no INT PATH '$.sequence_no'))j)<>count_var OR EXISTS(SELECT 1 FROM JSON_TABLE(p,'$.stages[*]' COLUMNS(sequence_no INT PATH '$.sequence_no'))j WHERE sequence_no<1 OR sequence_no>count_var) THEN CALL sp_fail('E_INPUT'); END IF;
  DELETE FROM milestones WHERE issue_id=iid;
  INSERT INTO milestones(issue_id,sequence_no,title,percent) SELECT iid,sequence_no,title,percent FROM JSON_TABLE(p,'$.stages[*]' COLUMNS(sequence_no INT PATH '$.sequence_no',title VARCHAR(100) PATH '$.title',percent DECIMAL(5,2) PATH '$.percent'))j;
 WHEN 'sp_top_up' THEN
  IF NOT fn_has_role(p_actor_id,'ADMIN') THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  SET amount_var=JSON_UNQUOTE(p->'$.amount'); IF amount_var<=0 THEN CALL sp_fail('E_AMOUNT'); END IF;
  CALL sp_lock_wallets(); SELECT account_id,balance INTO aid,balance_var FROM wallets WHERE user_id=uid;
  IF aid IS NULL THEN CALL sp_fail('E_NOT_FOUND'); END IF; IF balance_var+amount_var>9999999999.99 THEN CALL sp_fail('E_OVERFLOW'); END IF;
  INSERT INTO journal_transactions(operation_id,transaction_kind) VALUES(@operation_id,'TOP_UP'); SET tx=LAST_INSERT_ID();
  INSERT INTO ledger_entries(transaction_id,account_id,signed_amount) SELECT tx,account_id,-amount_var FROM accounts WHERE account_kind='ISSUANCE';
  INSERT INTO ledger_entries(transaction_id,account_id,signed_amount) VALUES(tx,aid,amount_var);
 WHEN 'sp_pledge' THEN
  IF NOT fn_has_role(p_actor_id,'BACKER') THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF status_var IN('RESOLVED','CLOSED') OR EXISTS(SELECT 1 FROM pull_requests r JOIN claims c USING(claim_id) WHERE c.issue_id=iid AND r.status='MERGED') THEN CALL sp_fail('E_STATE'); END IF;
  SET amount_var=JSON_UNQUOTE(p->'$.amount'); IF amount_var<10 THEN CALL sp_fail('E_AMOUNT'); END IF;
  CALL sp_lock_wallets(); SELECT account_id,balance INTO aid,balance_var FROM wallets WHERE user_id=p_actor_id;
  IF balance_var<amount_var THEN CALL sp_fail('E_FUNDS'); END IF; IF (SELECT held_amount+amount_var>9999999999.99 FROM escrows WHERE issue_id=iid) THEN CALL sp_fail('E_OVERFLOW'); END IF;
  INSERT INTO pledges(issue_id,backer_id,amount) VALUES(iid,p_actor_id,amount_var); SET pid=LAST_INSERT_ID();
  INSERT INTO journal_transactions(operation_id,transaction_kind) VALUES(@operation_id,'PLEDGE'); SET tx=LAST_INSERT_ID();
  INSERT INTO ledger_entries(transaction_id,account_id,signed_amount) VALUES(tx,aid,-amount_var),(tx,eid,amount_var);
  SET result_var=JSON_SET(result_var,'$.pledge_id',pid);
 WHEN 'sp_withdraw_pledge' THEN
  IF NOT EXISTS(SELECT 1 FROM pledges WHERE pledge_id=pid AND backer_id=p_actor_id) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF status_var<>'OPEN' OR EXISTS(SELECT 1 FROM claims WHERE issue_id=iid) OR (SELECT status FROM pledges WHERE pledge_id=pid)<>'HELD' THEN CALL sp_fail('E_WITHDRAWAL'); END IF;
  CALL sp_refund_remaining(iid,'WITHDRAWAL',pid,total_var);
 WHEN 'sp_claim_issue' THEN
  IF NOT fn_has_role(p_actor_id,'CONTRIBUTOR') THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF EXISTS(SELECT 1 FROM claims WHERE issue_id=iid AND status IN('ACTIVE','SUBMITTED')) THEN CALL sp_fail('E_CLAIM'); END IF;
  IF status_var<>'OPEN' THEN CALL sp_fail('E_STATE'); END IF;
  INSERT INTO claims(issue_id,claimant_id,expires_at) VALUES(iid,p_actor_id,now_var+INTERVAL 7 DAY); SET cid=LAST_INSERT_ID(); UPDATE issues SET status='CLAIMED' WHERE issue_id=iid;
  SET result_var=JSON_SET(result_var,'$.claim_id',cid);
 WHEN 'sp_submit_pr' THEN
  SELECT claimant_id,status,expires_at INTO author_var,pr_status,expires_var FROM claims WHERE claim_id=cid;
  IF p_actor_id<>author_var THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF now_var>=expires_var OR pr_status='EXPIRED' THEN CALL sp_fail('E_CLAIM_EXPIRED'); END IF;
  IF pr_status<>'ACTIVE' OR status_var<>'CLAIMED' THEN CALL sp_fail('E_STATE'); END IF;
  INSERT INTO pull_requests(claim_id,title) VALUES(cid,JSON_UNQUOTE(p->'$.title')); SET prid=LAST_INSERT_ID(); CALL sp_replace_shares(prid,author_var,p->'$.shares');
  UPDATE claims SET status='SUBMITTED' WHERE claim_id=cid; UPDATE issues SET status='IN_REVIEW' WHERE issue_id=iid;
  SET result_var=JSON_SET(result_var,'$.pr_id',prid);
 WHEN 'sp_set_pr_shares' THEN
  IF p_actor_id<>author_var THEN CALL sp_fail('E_FORBIDDEN'); END IF; IF pr_status<>'SUBMITTED' THEN CALL sp_fail('E_STATE'); END IF;
  CALL sp_replace_shares(prid,author_var,p->'$.shares'); UPDATE pull_requests SET share_revision=share_revision+1 WHERE pr_id=prid;
 WHEN 'sp_review_pr' THEN
  IF NOT fn_is_maintainer(p_actor_id,rid) OR EXISTS(SELECT 1 FROM pr_contributors WHERE pr_id=prid AND user_id=p_actor_id) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF pr_status<>'SUBMITTED' THEN CALL sp_fail('E_STATE'); END IF;
  INSERT INTO pr_reviews(pr_id,reviewer_id,decision,comment_text,share_revision) SELECT prid,p_actor_id,JSON_UNQUOTE(p->'$.decision'),JSON_UNQUOTE(p->'$.comment_text'),share_revision FROM pull_requests WHERE pr_id=prid;
 WHEN 'sp_reject_pr' THEN
  IF NOT fn_is_maintainer(p_actor_id,rid) OR EXISTS(SELECT 1 FROM pr_contributors WHERE pr_id=prid AND user_id=p_actor_id) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF pr_status<>'SUBMITTED' THEN CALL sp_fail('E_STATE'); END IF;
  INSERT INTO pr_reviews(pr_id,reviewer_id,decision,comment_text,share_revision) SELECT prid,p_actor_id,'REQUEST_CHANGES',JSON_UNQUOTE(p->'$.comment_text'),share_revision FROM pull_requests WHERE pr_id=prid;
  UPDATE pull_requests SET status='REJECTED' WHERE pr_id=prid; UPDATE claims SET status='CANCELLED' WHERE claim_id=cid; UPDATE issues SET status='OPEN' WHERE issue_id=iid;
  INSERT INTO reputation_events(user_id,repository_id,event_kind,source_id,points) VALUES(author_var,rid,'PR_REJECTED',prid,-2);
 WHEN 'sp_merge_pr' THEN
  IF NOT fn_is_maintainer(p_actor_id,rid) OR EXISTS(SELECT 1 FROM pr_contributors WHERE pr_id=prid AND user_id=p_actor_id) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF pr_status<>'SUBMITTED' OR EXISTS(SELECT 1 FROM pull_requests r JOIN claims c USING(claim_id) WHERE c.issue_id=iid AND r.status='MERGED') THEN CALL sp_fail('E_STATE'); END IF;
  SELECT required_approvals INTO count_var FROM repositories WHERE repository_id=rid FOR SHARE;
  IF(SELECT COUNT(*) FROM v_latest_pr_reviews WHERE pr_id=prid AND decision='APPROVE')<count_var OR EXISTS(SELECT 1 FROM v_latest_pr_reviews WHERE pr_id=prid AND decision='REQUEST_CHANGES') THEN CALL sp_fail('E_REVIEW'); END IF;
  IF(SELECT SUM(share_percent) FROM pr_contributors WHERE pr_id=prid)<>100 THEN CALL sp_fail('E_PERCENT'); END IF;
  UPDATE pull_requests SET status='MERGED',merged_at=now_var WHERE pr_id=prid;
  INSERT INTO reputation_events(user_id,repository_id,event_kind,source_id,points) SELECT user_id,rid,'PR_MERGED',prid,10*fn_difficulty_multiplier(difficulty_var) FROM pr_contributors WHERE pr_id=prid;
 WHEN 'sp_release_milestone' THEN
  IF NOT fn_is_maintainer(p_actor_id,rid) OR EXISTS(SELECT 1 FROM pr_contributors pc JOIN pull_requests r USING(pr_id) JOIN claims c USING(claim_id) WHERE c.issue_id=iid AND r.status='MERGED' AND pc.user_id=p_actor_id) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF status_var<>'IN_REVIEW' OR (SELECT status FROM milestones WHERE milestone_id=mid)<>'PENDING' OR mid=(SELECT milestone_id FROM milestones WHERE issue_id=iid ORDER BY sequence_no DESC LIMIT 1) THEN CALL sp_fail('E_STATE'); END IF;
  CALL sp_post_release(mid,release_id_var); SET result_var=JSON_SET(result_var,'$.release_id',release_id_var);
 WHEN 'sp_resolve_issue' THEN
  IF NOT fn_is_maintainer(p_actor_id,rid) OR EXISTS(SELECT 1 FROM pr_contributors pc JOIN pull_requests r USING(pr_id) JOIN claims c USING(claim_id) WHERE c.issue_id=iid AND r.status='MERGED' AND pc.user_id=p_actor_id) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF status_var<>'IN_REVIEW' THEN CALL sp_fail('E_STATE'); END IF;
  CALL sp_post_release(mid,release_id_var); UPDATE issues SET status='RESOLVED',resolved_at=now_var WHERE issue_id=iid; UPDATE claims SET status='COMPLETED' WHERE issue_id=iid AND status='SUBMITTED'; UPDATE escrows SET status='SETTLED' WHERE issue_id=iid;
  SET result_var=JSON_SET(result_var,'$.release_id',release_id_var);
 WHEN 'sp_extend_deadline' THEN
  IF NOT fn_is_maintainer(p_actor_id,rid) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF status_var IN('RESOLVED','CLOSED') THEN CALL sp_fail('E_STATE'); END IF; IF(SELECT deadline_extended FROM issues WHERE issue_id=iid) THEN CALL sp_fail('E_EXTENSION'); END IF;
  UPDATE issues SET bounty_deadline=bounty_deadline+INTERVAL 30 DAY,deadline_extended=TRUE WHERE issue_id=iid;
 WHEN 'sp_close_issue' THEN
  IF NOT fn_is_maintainer(p_actor_id,rid) THEN CALL sp_fail('E_FORBIDDEN'); END IF; IF status_var IN('RESOLVED','CLOSED') THEN CALL sp_fail('E_STATE'); END IF;
  CALL sp_close_locked_issue(iid,'CLOSURE',total_var);
 WHEN 'sp_expire_issue' THEN
  IF p_actor_id IS NOT NULL THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF frozen OR now_var<deadline_var OR status_var IN('RESOLVED','CLOSED') THEN ROLLBACK; SET p_result=JSON_OBJECT('processed',FALSE),@actor_id=NULL,@operation_id=NULL; LEAVE main; END IF;
  CALL sp_close_locked_issue(iid,'DEADLINE',total_var);
 WHEN 'sp_expire_claim' THEN
  IF p_actor_id IS NOT NULL THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  SELECT status,expires_at INTO pr_status,expires_var FROM claims WHERE claim_id=cid;
  IF frozen OR pr_status<>'ACTIVE' OR now_var<expires_var OR status_var IN('RESOLVED','CLOSED') THEN ROLLBACK; SET p_result=JSON_OBJECT('processed',FALSE),@actor_id=NULL,@operation_id=NULL; LEAVE main; END IF;
  IF now_var>=deadline_var THEN CALL sp_close_locked_issue(iid,'DEADLINE',total_var); ELSE UPDATE claims SET status='EXPIRED' WHERE claim_id=cid; UPDATE issues SET status='OPEN' WHERE issue_id=iid; END IF;
 WHEN 'sp_open_dispute' THEN
  IF NOT fn_is_participant(p_actor_id,iid) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF EXISTS(SELECT 1 FROM disputes WHERE issue_id=iid AND status='OPEN') THEN CALL sp_fail('E_DISPUTE'); END IF;
  IF status_var IN('RESOLVED','CLOSED') THEN CALL sp_fail('E_STATE'); END IF;
  INSERT INTO disputes(issue_id,opened_by,reason_text) VALUES(iid,p_actor_id,JSON_UNQUOTE(p->'$.reason_text')); SET did=LAST_INSERT_ID();
  UPDATE issues SET is_disputed=TRUE WHERE issue_id=iid; UPDATE escrows SET status='FROZEN' WHERE issue_id=iid; SET result_var=JSON_SET(result_var,'$.dispute_id',did);
 WHEN 'sp_rule_dispute' THEN
  IF NOT fn_has_role(p_actor_id,'ADMIN') OR fn_is_participant(p_actor_id,iid) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF(SELECT status FROM disputes WHERE dispute_id=did)<>'OPEN' THEN CALL sp_fail('E_STATE'); END IF;
  IF NOT fn_is_participant(JSON_VALUE(p,'$.losing_user_id' RETURNING UNSIGNED),iid) OR JSON_UNQUOTE(p->'$.ruling') NOT IN('RESUME','REFUND') THEN CALL sp_fail('E_INPUT'); END IF;
  UPDATE disputes SET status=CONCAT('RULED_',JSON_UNQUOTE(p->'$.ruling')),ruled_by=p_actor_id,ruled_at=now_var,ruling_text=JSON_UNQUOTE(p->'$.ruling_text'),losing_user_id=JSON_VALUE(p,'$.losing_user_id' RETURNING UNSIGNED) WHERE dispute_id=did;
  INSERT INTO reputation_events(user_id,repository_id,event_kind,source_id,points) VALUES(JSON_VALUE(p,'$.losing_user_id' RETURNING UNSIGNED),rid,'DISPUTE_LOST',did,-5);
  UPDATE issues SET is_disputed=FALSE WHERE issue_id=iid;
  IF JSON_UNQUOTE(p->'$.ruling')='REFUND' OR now_var>=deadline_var THEN CALL sp_close_locked_issue(iid,IF(JSON_UNQUOTE(p->'$.ruling')='REFUND','DISPUTE','DEADLINE'),total_var);
  ELSE UPDATE escrows SET status='ACTIVE' WHERE issue_id=iid; UPDATE claims SET status='EXPIRED' WHERE issue_id=iid AND status='ACTIVE' AND expires_at<=now_var; IF status_var='CLAIMED' AND NOT EXISTS(SELECT 1 FROM claims WHERE issue_id=iid AND status='ACTIVE') THEN UPDATE issues SET status='OPEN' WHERE issue_id=iid; END IF; END IF;
 WHEN 'sp_enqueue_content' THEN
  SET text_var=JSON_UNQUOTE(p->'$.collection_name');
  IF text_var='issue_bodies' AND NOT fn_is_maintainer(p_actor_id,rid) THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF text_var='commit_logs' AND NOT EXISTS(SELECT 1 FROM pull_requests r JOIN claims c USING(claim_id) WHERE r.pr_id=JSON_VALUE(p,'$.payload.pr_id' RETURNING UNSIGNED) AND c.issue_id=iid AND c.claimant_id=p_actor_id AND r.status='SUBMITTED') THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  IF text_var='comments' AND JSON_UNQUOTE(p->'$.payload.parent_comment_id') IS NOT NULL AND JSON_TYPE(p->'$.payload.parent_comment_id')<>'NULL' AND NOT EXISTS(SELECT 1 FROM content_outbox WHERE event_id=JSON_UNQUOTE(p->'$.payload.parent_comment_id') AND issue_id=iid AND collection_name='comments') THEN CALL sp_fail('E_CONTENT'); END IF;
  IF text_var='comments' THEN
   SET parent_var=JSON_UNQUOTE(p->'$.payload.parent_comment_id');
   WHILE parent_var IS NOT NULL AND parent_var<>'null' DO
    SET depth_var=depth_var+1; IF depth_var>10 THEN CALL sp_fail('E_CONTENT'); END IF;
    SELECT JSON_UNQUOTE(payload_json->'$.parent_comment_id') INTO parent_var FROM content_outbox WHERE event_id=parent_var AND issue_id=iid AND collection_name='comments';
   END WHILE;
  END IF;
  IF text_var='commit_logs' AND EXISTS(SELECT 1 FROM content_outbox WHERE issue_id=iid AND collection_name='commit_logs' AND JSON_UNQUOTE(payload_json->'$.pr_id')=JSON_UNQUOTE(p->'$.payload.pr_id') AND JSON_UNQUOTE(payload_json->'$.commit_sha')=JSON_UNQUOTE(p->'$.payload.commit_sha')) THEN CALL sp_fail('E_DUPLICATE'); END IF;
  SET event_var=UUID(); SET result_var=JSON_SET(result_var,'$.event_id',event_var);
  SET @content_payload=JSON_SET(p->'$.payload','$.author_id',p_actor_id);
  IF text_var='issue_bodies' THEN SELECT COALESCE(MAX(JSON_VALUE(payload_json,'$.version' RETURNING UNSIGNED)),0)+1 INTO count_var FROM content_outbox WHERE issue_id=iid AND collection_name='issue_bodies'; SET @content_payload=JSON_SET(@content_payload,'$.version',count_var); END IF;
  INSERT INTO content_outbox(event_id,operation_id,issue_id,collection_name,payload_json) VALUES(event_var,@operation_id,iid,text_var,@content_payload);
 WHEN 'sp_ack_content' THEN
  IF p_actor_id IS NOT NULL THEN CALL sp_fail('E_FORBIDDEN'); END IF;
  UPDATE content_outbox SET delivery_status='DELIVERED',delivered_at=COALESCE(delivered_at,now_var) WHERE event_id=JSON_UNQUOTE(p->'$.event_id');
 ELSE CALL sp_fail('E_INPUT'); END CASE;
 CALL sp_assert_financial_integrity(iid,JSON_ARRAY(),NULL,ok_var);
 IF p_action='sp_register_user' THEN SET result_var=JSON_SET(result_var,'$.account_id',aid); END IF;
 IF p_action='sp_top_up' THEN SET result_var=JSON_SET(result_var,'$.balance',CAST((SELECT balance FROM wallets WHERE user_id=uid) AS CHAR)); END IF;
 IF p_action IN('sp_pledge','sp_withdraw_pledge') THEN SET result_var=JSON_SET(result_var,'$.balance',CAST((SELECT balance FROM wallets WHERE user_id=p_actor_id) AS CHAR)); END IF;
 IF p_action='sp_withdraw_pledge' THEN SET result_var=JSON_SET(result_var,'$.refund_id',(SELECT refund_id FROM refunds WHERE pledge_id=pid)); END IF;
 IF p_action='sp_claim_issue' THEN SET result_var=JSON_SET(result_var,'$.expires_at',(SELECT expires_at FROM claims WHERE claim_id=cid)); END IF;
 IF p_action IN('sp_review_pr','sp_reject_pr') THEN SET result_var=JSON_SET(result_var,'$.review_id',(SELECT MAX(review_id) FROM pr_reviews WHERE pr_id=prid AND reviewer_id=p_actor_id)); END IF;
 IF p_action IN('sp_merge_pr','sp_reject_pr','sp_set_pr_shares') THEN SET result_var=JSON_SET(result_var,'$.pr_id',prid,'$.share_revision',(SELECT share_revision FROM pull_requests WHERE pr_id=prid)); END IF;
 IF p_action='sp_merge_pr' THEN SET result_var=JSON_SET(result_var,'$.merged_at',(SELECT merged_at FROM pull_requests WHERE pr_id=prid)); END IF;
 IF p_action='sp_extend_deadline' THEN SET result_var=JSON_SET(result_var,'$.bounty_deadline',(SELECT bounty_deadline FROM issues WHERE issue_id=iid),'$.deadline_extended',TRUE); END IF;
 IF p_action IN('sp_close_issue','sp_expire_issue','sp_rule_dispute') THEN SET result_var=JSON_SET(result_var,'$.total_refunded',CAST(COALESCE(total_var,0) AS CHAR)); END IF;
 IF p_action IN('sp_expire_issue','sp_expire_claim') THEN SET result_var=JSON_SET(result_var,'$.processed',TRUE); END IF;
 IF p_action='sp_rule_dispute' THEN SET result_var=JSON_SET(result_var,'$.dispute_id',did); END IF;
 IF p_action IN('sp_create_issue','sp_enqueue_content') THEN SET result_var=JSON_SET(result_var,'$.delivery_status','PENDING'); END IF;
 IF p_action='sp_ack_content' THEN SET result_var=JSON_SET(result_var,'$.event_id',JSON_UNQUOTE(p->'$.event_id'),'$.delivery_status','DELIVERED'); END IF;
 IF release_id_var IS NOT NULL THEN SET result_var=JSON_SET(result_var,'$.payouts',(SELECT JSON_ARRAYAGG(JSON_OBJECT('user_id',user_id,'amount',CAST(amount AS CHAR))) FROM payouts WHERE release_id=release_id_var)); END IF;
 IF iid IS NOT NULL THEN SET result_var=JSON_SET(result_var,'$.issue_id',iid,'$.status',(SELECT status FROM issues WHERE issue_id=iid),'$.held_amount',CAST((SELECT held_amount FROM escrows WHERE issue_id=iid) AS CHAR)); END IF;
 SELECT transaction_id INTO tx FROM journal_transactions WHERE operation_id=@operation_id;
 IF tx IS NOT NULL THEN SET result_var=JSON_SET(result_var,'$.transaction_id',tx,'$.amount',CAST((SELECT COALESCE(SUM(signed_amount),0) FROM ledger_entries WHERE transaction_id=tx AND signed_amount>0) AS CHAR)); END IF;
 UPDATE operation_requests SET result_json=result_var WHERE operation_id=@operation_id;
 SET p_result=result_var; COMMIT; SET @actor_id=NULL,@operation_id=NULL,@content_payload=NULL;
END$$
DELIMITER ;
