CREATE OR REPLACE VIEW v_acct_coll_acct_expanded_detail AS
WITH RECURSIVE var_recurse(
	account_collection_id,
	root_account_collection_id,
	account_id,
	acct_coll_level,
	dept_level,
	assign_method,
	array_path,
	cycle
) AS (
	SELECT 
		aca.account_collection_id,
		aca.account_collection_id,
		aca.account_id, 
		CASE ac.account_collection_type
			WHEN 'department'::text THEN 0
			ELSE 1
		END,
		CASE ac.account_collection_type
			WHEN 'department'::text THEN 1
			ELSE 0
		END,
		CASE ac.account_collection_type
			WHEN 'department'::text THEN 'DirectDepartmentAssignment'::text
			ELSE 'DirectAccountCollectionAssignment'::text
		END,
		ARRAY[aca.account_collection_id],
		false
	FROM
		account_collection ac JOIN
		account_collection_account aca USING (account_collection_id)
	UNION ALL 
	SELECT
		ach.account_collection_id,
		x.root_account_collection_id,
		x.account_id, 
		CASE ac.account_collection_type
			WHEN 'department'::text THEN x.dept_level
			ELSE x.acct_coll_level + 1
		END,
		CASE ac.account_collection_type
			WHEN 'department'::text THEN x.dept_level + 1
			ELSE x.dept_level
		END,
		CASE
			WHEN ac.account_collection_type::text = 'department'::text THEN 'AccountAssignedToChildDepartment'::text
			WHEN x.dept_level > 1 AND x.acct_coll_level > 0 THEN 'ParentDepartmentAssignedToParentAccountCollection'::text
			WHEN x.dept_level > 1 THEN 'ParentDepartmentAssignedToAccountCollection'::text
			WHEN x.dept_level = 1 AND x.acct_coll_level > 0 THEN 'DepartmentAssignedToParentAccountCollection'::text
			WHEN x.dept_level = 1 THEN 'DepartmentAssignedToAccountCollection'::text
			ELSE 'AccountAssignedToParentAccountCollection'::text
		END AS assign_method, x.array_path || ach.account_collection_id AS array_path, ach.account_collection_id = ANY (x.array_path)
	FROM
		var_recurse x JOIN
		account_collection_hier ach ON x.account_collection_id = ach.child_account_collection_id JOIN
		account_collection ac ON ach.account_collection_id = ac.account_collection_id
	WHERE
		NOT x.cycle
) SELECT 
	account_collection_id,
	root_account_collection_id,
	account_id,
	acct_coll_level,
	dept_level,
	assign_method,
	array_to_string(var_recurse.array_path, '/'::text) AS text_path,
	array_path
FROM
	var_recurse;

