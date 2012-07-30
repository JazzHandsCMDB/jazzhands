CREATE OR REPLACE VIEW v_acct_coll_acct_expanded AS
	SELECT DISTINCT 
		ace.account_collection_id,
		aca.account_id
	FROM 
		v_acct_coll_expanded ace JOIN
		v_account_collection_account aca ON
			aca.account_collection_id = ace.root_account_collection_id;
