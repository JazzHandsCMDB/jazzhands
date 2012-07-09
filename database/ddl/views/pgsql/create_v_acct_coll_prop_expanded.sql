CREATE OR REPLACE VIEW v_acct_coll_prop_expanded AS
	SELECT
		root_account_collection_id as account_collection_id,
		property_name,
		property_type,
		property_value,
		property_value_timestamp,
		property_value_company_id,
		property_value_account_coll_id,
		property_value_dns_domain_id,
		property_value_nblk_coll_id,
		property_value_password_type,
		property_value_person_id,
		property_value_sw_package_id,
		property_value_token_col_id,
		CASE is_multivalue WHEN 'N' THEN false WHEN 'Y' THEN true END 
			is_multivalue
	FROM
		v_acct_coll_expanded_detail JOIN
		account_collection ac USING (account_collection_id) JOIN
		v_property USING (account_collection_id) JOIN
		val_property USING (property_name, property_type)
	ORDER BY
		CASE account_collection_type
			WHEN 'per-user' THEN 0
			ELSE 99
			END,
		CASE assign_method
			WHEN 'DirectAccountCollectionAssignment' THEN 0
			WHEN 'DirectDepartmentAssignment' THEN 1
			WHEN 'DepartmentAssignedToAccountCollection' THEN 2
			WHEN 'AccountAssignedToChildDepartment' THEN 3
			WHEN 'AccountAssignedToChildAccountCollection' THEN 4
			WHEN 'DepartmentAssignedToChildAccountCollection' THEN 5
			WHEN 'ChildDepartmentAssignedToAccountCollection' THEN 6
			WHEN 'ChildDepartmentAssignedToChildAccountCollection' THEN 7
			ELSE 99
			END,
		dept_level,
		acct_coll_level,
		account_collection_id;
