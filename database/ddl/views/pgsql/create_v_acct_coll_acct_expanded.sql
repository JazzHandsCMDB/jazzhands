CREATE OR REPLACE VIEW v_acct_coll_acct_expanded AS
SELECT DISTINCT
	account_id,
	account_collection_id,
	root_account_collection_id,
	acct_coll_level as acct_coll_level,
	dept_level dept_level,
	assign_method,
	array_to_string(array_path, '/') as text_path,
	array_path
FROM
	v_acct_coll_expanded_detail ace JOIN 
	v_account_collection_account aca ON
		(aca.account_collection_id = ace.root_account_collection_id);

