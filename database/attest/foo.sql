-- queries in development...

SELECT approver_account_id, aisi.*, aii.*, approval_instance_link_id
FROM	approval_instance ai
		INNER JOIN approval_instance_step ais
			USING (approval_instance_id)
		INNER JOIN approval_instance_step_item aisi
			USING (approval_instance_step_id)
		INNER JOIN approval_instance_item aii USING (approval_instance_item_id)
		INNER JOIN approval_instance_link ail USING (approval_instance_link_id)
WHERE	approver_account_id = 25;


