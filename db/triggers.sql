DELIMITER $$
DROP TRIGGER IF EXISTS trg_issues_ai$$
CREATE TRIGGER trg_issues_ai AFTER INSERT ON issues FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('issues',NEW.issue_id,'status',NULL,CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id);INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('issues',NEW.issue_id,'is_disputed',NULL,CAST(NEW.is_disputed AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END$$
DROP TRIGGER IF EXISTS trg_issues_au$$
CREATE TRIGGER trg_issues_au AFTER UPDATE ON issues FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;IF NOT(OLD.status<=>NEW.status) THEN INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('issues',NEW.issue_id,'status',CAST(OLD.status AS CHAR),CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END IF;IF NOT(OLD.is_disputed<=>NEW.is_disputed) THEN INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('issues',NEW.issue_id,'is_disputed',CAST(OLD.is_disputed AS CHAR),CAST(NEW.is_disputed AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END IF; END$$
DROP TRIGGER IF EXISTS trg_claims_ai$$
CREATE TRIGGER trg_claims_ai AFTER INSERT ON claims FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('claims',NEW.claim_id,'status',NULL,CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END$$
DROP TRIGGER IF EXISTS trg_claims_au$$
CREATE TRIGGER trg_claims_au AFTER UPDATE ON claims FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;IF NOT(OLD.status<=>NEW.status) THEN INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('claims',NEW.claim_id,'status',CAST(OLD.status AS CHAR),CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END IF; END$$
DROP TRIGGER IF EXISTS trg_pull_requests_ai$$
CREATE TRIGGER trg_pull_requests_ai AFTER INSERT ON pull_requests FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('pull_requests',NEW.pr_id,'status',NULL,CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END$$
DROP TRIGGER IF EXISTS trg_pull_requests_au$$
CREATE TRIGGER trg_pull_requests_au AFTER UPDATE ON pull_requests FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;IF NOT(OLD.status<=>NEW.status) THEN INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('pull_requests',NEW.pr_id,'status',CAST(OLD.status AS CHAR),CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END IF; END$$
DROP TRIGGER IF EXISTS trg_pledges_ai$$
CREATE TRIGGER trg_pledges_ai AFTER INSERT ON pledges FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('pledges',NEW.pledge_id,'status',NULL,CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END$$
DROP TRIGGER IF EXISTS trg_pledges_au$$
CREATE TRIGGER trg_pledges_au AFTER UPDATE ON pledges FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;IF NOT(OLD.status<=>NEW.status) THEN INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('pledges',NEW.pledge_id,'status',CAST(OLD.status AS CHAR),CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END IF; END$$
DROP TRIGGER IF EXISTS trg_escrows_ai$$
CREATE TRIGGER trg_escrows_ai AFTER INSERT ON escrows FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('escrows',NEW.issue_id,'status',NULL,CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END$$
DROP TRIGGER IF EXISTS trg_escrows_au$$
CREATE TRIGGER trg_escrows_au AFTER UPDATE ON escrows FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;IF NOT(OLD.status<=>NEW.status) THEN INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('escrows',NEW.issue_id,'status',CAST(OLD.status AS CHAR),CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END IF; END$$
DROP TRIGGER IF EXISTS trg_milestones_ai$$
CREATE TRIGGER trg_milestones_ai AFTER INSERT ON milestones FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('milestones',NEW.milestone_id,'status',NULL,CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END$$
DROP TRIGGER IF EXISTS trg_milestones_au$$
CREATE TRIGGER trg_milestones_au AFTER UPDATE ON milestones FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;IF NOT(OLD.status<=>NEW.status) THEN INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('milestones',NEW.milestone_id,'status',CAST(OLD.status AS CHAR),CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END IF; END$$
DROP TRIGGER IF EXISTS trg_disputes_ai$$
CREATE TRIGGER trg_disputes_ai AFTER INSERT ON disputes FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('disputes',NEW.dispute_id,'status',NULL,CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END$$
DROP TRIGGER IF EXISTS trg_disputes_au$$
CREATE TRIGGER trg_disputes_au AFTER UPDATE ON disputes FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF;IF NOT(OLD.status<=>NEW.status) THEN INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('disputes',NEW.dispute_id,'status',CAST(OLD.status AS CHAR),CAST(NEW.status AS CHAR),@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END IF; END$$
DROP TRIGGER IF EXISTS trg_milestones_ad$$
CREATE TRIGGER trg_milestones_ad AFTER DELETE ON milestones FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF; IF OLD.status<>'PENDING' THEN CALL sp_fail('E_STATE'); END IF; INSERT INTO audit_log(entity_type,entity_id,field_name,old_value,new_value,actor_id,actor_kind,operation_id) VALUES('milestones',OLD.milestone_id,'status',OLD.status,'REMOVED',@actor_id,IF(@actor_id IS NULL,'SYSTEM','USER'),@operation_id); END$$
DROP TRIGGER IF EXISTS trg_ledger_entries_bu$$
CREATE TRIGGER trg_ledger_entries_bu BEFORE UPDATE ON ledger_entries FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_ledger_entries_bd$$
CREATE TRIGGER trg_ledger_entries_bd BEFORE DELETE ON ledger_entries FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_journal_transactions_bu$$
CREATE TRIGGER trg_journal_transactions_bu BEFORE UPDATE ON journal_transactions FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_journal_transactions_bd$$
CREATE TRIGGER trg_journal_transactions_bd BEFORE DELETE ON journal_transactions FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_releases_bu$$
CREATE TRIGGER trg_releases_bu BEFORE UPDATE ON releases FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_releases_bd$$
CREATE TRIGGER trg_releases_bd BEFORE DELETE ON releases FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_release_funding_bu$$
CREATE TRIGGER trg_release_funding_bu BEFORE UPDATE ON release_funding FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_release_funding_bd$$
CREATE TRIGGER trg_release_funding_bd BEFORE DELETE ON release_funding FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_payouts_bu$$
CREATE TRIGGER trg_payouts_bu BEFORE UPDATE ON payouts FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_payouts_bd$$
CREATE TRIGGER trg_payouts_bd BEFORE DELETE ON payouts FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_refunds_bu$$
CREATE TRIGGER trg_refunds_bu BEFORE UPDATE ON refunds FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_refunds_bd$$
CREATE TRIGGER trg_refunds_bd BEFORE DELETE ON refunds FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_reputation_events_bu$$
CREATE TRIGGER trg_reputation_events_bu BEFORE UPDATE ON reputation_events FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_reputation_events_bd$$
CREATE TRIGGER trg_reputation_events_bd BEFORE DELETE ON reputation_events FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_audit_log_bu$$
CREATE TRIGGER trg_audit_log_bu BEFORE UPDATE ON audit_log FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_audit_log_bd$$
CREATE TRIGGER trg_audit_log_bd BEFORE DELETE ON audit_log FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_pr_reviews_bu$$
CREATE TRIGGER trg_pr_reviews_bu BEFORE UPDATE ON pr_reviews FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_pr_reviews_bd$$
CREATE TRIGGER trg_pr_reviews_bd BEFORE DELETE ON pr_reviews FOR EACH ROW BEGIN CALL sp_fail('E_IMMUTABLE'); END$$
DROP TRIGGER IF EXISTS trg_ledger_entries_ai$$
CREATE TRIGGER trg_ledger_entries_ai AFTER INSERT ON ledger_entries FOR EACH ROW BEGIN IF @operation_id IS NULL THEN CALL sp_fail('E_AUDIT_CONTEXT'); END IF; UPDATE wallets SET balance=balance+NEW.signed_amount WHERE account_id=NEW.account_id; UPDATE escrows SET held_amount=held_amount+NEW.signed_amount WHERE account_id=NEW.account_id; END$$
DELIMITER ;
