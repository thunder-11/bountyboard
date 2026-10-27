DELIMITER $$
DROP PROCEDURE IF EXISTS sp_register_user$$
CREATE PROCEDURE sp_register_user(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_register_user',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_grant_role$$
CREATE PROCEDURE sp_grant_role(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_grant_role',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_configure_repository$$
CREATE PROCEDURE sp_configure_repository(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_configure_repository',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_create_issue$$
CREATE PROCEDURE sp_create_issue(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_create_issue',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_update_issue_metadata$$
CREATE PROCEDURE sp_update_issue_metadata(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_update_issue_metadata',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_configure_milestones$$
CREATE PROCEDURE sp_configure_milestones(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_configure_milestones',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_top_up$$
CREATE PROCEDURE sp_top_up(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_top_up',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_pledge$$
CREATE PROCEDURE sp_pledge(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_pledge',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_withdraw_pledge$$
CREATE PROCEDURE sp_withdraw_pledge(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_withdraw_pledge',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_claim_issue$$
CREATE PROCEDURE sp_claim_issue(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_claim_issue',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_submit_pr$$
CREATE PROCEDURE sp_submit_pr(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_submit_pr',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_set_pr_shares$$
CREATE PROCEDURE sp_set_pr_shares(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_set_pr_shares',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_review_pr$$
CREATE PROCEDURE sp_review_pr(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_review_pr',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_reject_pr$$
CREATE PROCEDURE sp_reject_pr(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_reject_pr',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_merge_pr$$
CREATE PROCEDURE sp_merge_pr(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_merge_pr',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_release_milestone$$
CREATE PROCEDURE sp_release_milestone(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_release_milestone',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_resolve_issue$$
CREATE PROCEDURE sp_resolve_issue(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_resolve_issue',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_extend_deadline$$
CREATE PROCEDURE sp_extend_deadline(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_extend_deadline',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_close_issue$$
CREATE PROCEDURE sp_close_issue(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_close_issue',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_expire_issue$$
CREATE PROCEDURE sp_expire_issue(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_expire_issue',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_expire_claim$$
CREATE PROCEDURE sp_expire_claim(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_expire_claim',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_open_dispute$$
CREATE PROCEDURE sp_open_dispute(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_open_dispute',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_rule_dispute$$
CREATE PROCEDURE sp_rule_dispute(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_rule_dispute',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_enqueue_content$$
CREATE PROCEDURE sp_enqueue_content(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_enqueue_content',p_payload,p_result); END$$
DROP PROCEDURE IF EXISTS sp_ack_content$$
CREATE PROCEDURE sp_ack_content(IN p_actor_id BIGINT UNSIGNED,IN p_request_key CHAR(36),IN p_payload JSON,OUT p_result JSON) SQL SECURITY DEFINER BEGIN CALL sp_command(p_actor_id,p_request_key,'sp_ack_content',p_payload,p_result); END$$
DELIMITER ;
