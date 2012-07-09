CREATE OR REPLACE VIEW v_acct_coll_expanded AS
WITH RECURSIVE acct_coll_recurse (
	level,
	root_account_collection_id,
	account_collection_id,
	array_path,
	cycle
) AS (
		SELECT
			0 as level,
			ac.account_collection_id as root_account_collection_id,
			ac.account_collection_id as account_collection_id,
			ARRAY[ac.account_collection_id] as array_path,
			false
		FROM
			account_collection ac
	UNION ALL
		SELECT 
			x.level + 1 as level,
			x.root_account_collection_id as root_account_collection_id,
			ach.account_collection_id as account_collection_id,
			x.array_path || ach.account_collection_id as array_path,
			ach.account_collection_id = ANY(array_path) as cycle
		FROM
			acct_coll_recurse x JOIN account_collection_hier ach ON
				x.account_collection_id = ach.child_account_collection_id
		WHERE
			NOT cycle
) SELECT
		level,
		account_collection_id,
		root_account_collection_id,
		array_to_string(array_path, '/') as text_path,
		array_path
	FROM
		acct_coll_recurse;

