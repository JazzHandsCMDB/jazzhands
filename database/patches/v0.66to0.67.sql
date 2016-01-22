/*
Invoked:

	--scan-tables
	--suffix=v66
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();
--
-- Process middle (non-trigger) schema jazzhands
--
--
-- Process middle (non-trigger) schema net_manip
--
--
-- Process middle (non-trigger) schema network_strings
--
--
-- Process middle (non-trigger) schema time_util
--
--
-- Process middle (non-trigger) schema dns_utils
--
--
-- Process middle (non-trigger) schema person_manip
--
--
-- Process middle (non-trigger) schema auto_ac_manip
--
--
-- Process middle (non-trigger) schema company_manip
--
--
-- Process middle (non-trigger) schema port_support
--
--
-- Process middle (non-trigger) schema port_utils
--
--
-- Process middle (non-trigger) schema device_utils
--
--
-- Process middle (non-trigger) schema netblock_utils
--
--
-- Process middle (non-trigger) schema netblock_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS netblock
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		RECORD;
	loopback_bits	integer;
	inet_family		integer;
	ip_addr			ALIAS FOR ip_address;
BEGIN
	IF parent_netblock_list IS NULL THEN
		RAISE 'parent_netblock_list must be specified'
		USING ERRCODE = 'null_value_not_allowed';
	END IF;

	IF address_type NOT IN ('netblock', 'single', 'loopback') THEN
		RAISE 'address_type must be one of netblock, single, or loopback'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF netmask_bits IS NULL AND address_type = 'netblock' THEN
		RAISE EXCEPTION
			'You must specify a netmask when address_type is netblock'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF ip_address IS NOT NULL THEN
		SELECT 
			array_agg(netblock_id)
		INTO
			parent_netblock_list
		FROM
			netblock n
		WHERE
			ip_addr <<= n.ip_address AND
			netblock_id = ANY(parent_netblock_list);

		IF parent_netblock_list IS NULL THEN
			RETURN NULL;
		END IF;
	END IF;

	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	FOR parent_rec IN SELECT * FROM jazzhands.netblock WHERE netblock_id = 
			ANY(allocate_netblock.parent_netblock_list) ORDER BY netblock_id
			FOR UPDATE LOOP

		IF parent_rec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'parent_netblock_id refers to a single_address netblock'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF inet_family IS NULL THEN
			inet_family := family(parent_rec.ip_address);
		ELSIF inet_family != family(parent_rec.ip_address) 
				AND ip_address IS NULL THEN
			RAISE EXCEPTION 'Allocation may not mix IPv4 and IPv6 addresses'
			USING ERRCODE = 'JH10F';
		END IF;

		IF address_type = 'loopback' THEN
			loopback_bits := 
				CASE WHEN 
					family(parent_rec.ip_address) = 4 THEN 32 ELSE 128 END;

			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'single' THEN
			IF parent_rec.can_subnet = 'Y' THEN
				RAISE EXCEPTION
					'parent subnet for single address must have can_subnet set to N'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'netblock' THEN
			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		END IF;
	END LOOP;

 	IF NOT FOUND THEN
 		RETURN NULL;
 	END IF;

	IF address_type = 'loopback' THEN
		-- If we're allocating a loopback address, then we need to create
		-- a new parent to hold the single loopback address

		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := loopback_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO parent_rec;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			parent_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN netblock_rec;
	END IF;

	IF address_type = 'single' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			single_address := true,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			rnd_masklen_threshold := rnd_masklen_threshold,
			rnd_max_count := rnd_max_count,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		RAISE DEBUG 'ip_address is %', inet_rec.ip_address;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN netblock_rec;
	END IF;
	IF address_type = 'netblock' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := netmask_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			CASE WHEN can_subnet THEN 'Y' ELSE 'N' END,
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;
		
		RAISE DEBUG 'Allocated netblock_id % for %',
			netblock_rec.netblock_id,
			netblock_rec.ip_address;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN netblock_rec;
	END IF;
END;
$function$
;

--
-- Process middle (non-trigger) schema physical_address_utils
--
--
-- Process middle (non-trigger) schema component_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('component_utils', 'insert_pci_component');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS component_utils.insert_pci_component ( pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer, pci_subsystem_id integer, pci_vendor_name text, pci_device_name text, pci_sub_vendor_name text, pci_sub_device_name text, component_function_list text[], slot_type text, serial_number text );
CREATE OR REPLACE FUNCTION component_utils.insert_pci_component(pci_vendor_id integer, pci_device_id integer, pci_sub_vendor_id integer DEFAULT NULL::integer, pci_subsystem_id integer DEFAULT NULL::integer, pci_vendor_name text DEFAULT NULL::text, pci_device_name text DEFAULT NULL::text, pci_sub_vendor_name text DEFAULT NULL::text, pci_sub_device_name text DEFAULT NULL::text, component_function_list text[] DEFAULT NULL::text[], slot_type text DEFAULT 'unknown'::text, serial_number text DEFAULT NULL::text)
 RETURNS component
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	sn			ALIAS FOR serial_number;
	ctid		integer;
	comp_id		integer;
	sub_comp_id	integer;
	stid		integer;
	vendor_name	text;
	sub_vendor_name	text;
	model_name	text;
	c			RECORD;
BEGIN
	IF (pci_sub_vendor_id IS NULL AND pci_subsystem_id IS NOT NULL) OR
			(pci_sub_vendor_id IS NOT NULL AND pci_subsystem_id IS NULL) THEN
		RAISE EXCEPTION
			'pci_sub_vendor_id and pci_subsystem_id must be set together';
	END IF;

	--
	-- See if we have this component type in the database already
	--
	SELECT
		vid.component_type_id INTO ctid
	FROM
		component_property vid JOIN
		component_property did ON (
			vid.component_property_name = 'PCIVendorID' AND
			vid.component_property_type = 'PCI' AND
			did.component_property_name = 'PCIDeviceID' AND
			did.component_property_type = 'PCI' AND
			vid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property svid ON (
			svid.component_property_name = 'PCISubsystemVendorID' AND
			svid.component_property_type = 'PCI' AND
			svid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property sid ON (
			sid.component_property_name = 'PCISubsystemID' AND
			sid.component_property_type = 'PCI' AND
			sid.component_type_id = did.component_type_id )
	WHERE
		vid.property_value = pci_vendor_id::varchar AND
		did.property_value = pci_device_id::varchar AND
		svid.property_value IS NOT DISTINCT FROM pci_sub_vendor_id::varchar AND
		sid.property_value IS NOT DISTINCT FROM pci_subsystem_id::varchar;

	--
	-- The device type doesn't exist, so attempt to insert it
	--

	IF NOT FOUND THEN	
		IF pci_device_name IS NULL OR component_function_list IS NULL THEN
			RAISE EXCEPTION 'component_id not found and pci_device_name or component_function_list was not passed' USING ERRCODE = 'JH501';
		END IF;

		--
		-- Ensure that there's a company linkage for the PCI (subsystem)vendor
		--
		SELECT
			company_id, company_name INTO comp_id, vendor_name
		FROM
			property p JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			property_value = pci_vendor_id::text;
		
		IF NOT FOUND THEN
			IF pci_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI vendor id mapping not found and pci_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO comp_id FROM company
			WHERE company_name = pci_vendor_name;
		
			IF NOT FOUND THEN
				INSERT INTO company (company_name, description)
				VALUES (pci_vendor_name, 'PCI vendor auto-insert')
				RETURNING company_id INTO comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_vendor_id,
				comp_id
			);
			vendor_name := pci_vendor_name;
		END IF;

		SELECT
			company_id, company_name INTO sub_comp_id, sub_vendor_name
		FROM
			property JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			property_value = pci_sub_vendor_id::text;
		
		IF NOT FOUND THEN
			IF pci_sub_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI subsystem vendor id mapping not found and pci_sub_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO sub_comp_id FROM company
			WHERE company_name = pci_sub_vendor_name;
		
			IF NOT FOUND THEN
				INSERT INTO company (company_name, description)
				VALUES (pci_sub_vendor_name, 'PCI vendor auto-insert')
				RETURNING company_id INTO sub_comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_sub_vendor_id,
				sub_comp_id
			);
			sub_vendor_name := pci_sub_vendor_name;
		END IF;

		--
		-- Fetch the slot type
		--

		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = insert_pci_component.slot_type AND
			slot_function = 'PCI';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function PCI not found adding component_type',
				insert_pci_component.slot_type
				USING ERRCODE = 'JH501';
		END IF;

		--
		-- Figure out the best name/description to insert this component with
		--
		IF pci_sub_device_name IS NOT NULL AND pci_sub_device_name != 'Device' THEN
			model_name = concat_ws(' ', 
				sub_vendor_name, pci_sub_device_name,
				'(' || vendor_name, pci_device_name || ')');
		ELSIF pci_sub_device_name = 'Device' THEN
			model_name = concat_ws(' ', 
				vendor_name, '(' || sub_vendor_name || ')', pci_device_name);
		ELSE
			model_name = concat_ws(' ', vendor_name, pci_device_name);
		END IF;
		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			CASE WHEN 
				sub_comp_id IS NULL OR
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				comp_id
			ELSE
				sub_comp_id
			END,
			CASE WHEN
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				pci_device_name
			ELSE
				pci_sub_device_name
			END,
			stid,
			'Y',
			model_name
		) RETURNING component_type_id INTO ctid;
		--
		-- Insert properties for the PCI vendor/device IDs
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('PCIVendorID', 'PCI', ctid, pci_vendor_id),
			('PCIDeviceID', 'PCI', ctid, pci_device_id);
		
		IF (pci_subsystem_id IS NOT NULL) THEN
			INSERT INTO component_property (
				component_property_name,
				component_property_type,
				component_type_id,
				property_value
			) VALUES 
				('PCISubsystemVendorID', 'PCI', ctid, pci_sub_vendor_id),
				('PCISubsystemID', 'PCI', ctid, pci_subsystem_id);
		END IF;
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(array_append(component_function_list, 'PCI')) x(cf);
	END IF;


	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$function$
;

--
-- Process middle (non-trigger) schema snapshot_manip
--
--
-- Process middle (non-trigger) schema lv_manip
--
--
-- Process middle (non-trigger) schema schema_support
--
--
-- Process middle (non-trigger) schema approval_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('approval_utils', 'approve');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS approval_utils.approve ( approval_instance_item_id integer, approved character, approving_account_id integer, new_value text );
CREATE OR REPLACE FUNCTION approval_utils.approve(approval_instance_item_id integer, approved character, approving_account_id integer, new_value text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	_r		RECORD;
	_aii	approval_instance_item%ROWTYPE;	
	_new	approval_instance_item.approval_instance_item_id%TYPE;	
	_chid	approval_process_chain.approval_process_chain_id%TYPE;
	_tally	INTEGER;
BEGIN
	EXECUTE '
		SELECT 	aii.approval_instance_item_id,
			ais.approval_instance_step_id,
			ais.approval_instance_id,
			ais.approver_account_id,
			ais.approval_type,
			aii.is_approved,
			ais.is_completed,
			aic.accept_app_process_chain_id,
			aic.reject_app_process_chain_id
   	     FROM    approval_instance ai
   		     INNER JOIN approval_instance_step ais
   			 USING (approval_instance_id)
   		     INNER JOIN approval_instance_item aii
   			 USING (approval_instance_step_id)
   		     INNER JOIN approval_instance_link ail
   			 USING (approval_instance_link_id)
			INNER JOIN approval_process_chain aic
				USING (approval_process_chain_id)
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id INTO 	_r;

	--
	-- Ensure that only the person or their management chain can approve
	-- others; this may want to be a property on val_approval_type rather
	-- than hard coded on account...
	IF (_r.approval_type = 'account' AND _r.approver_account_id != approving_account_id ) THEN
		EXECUTE '
			WITH RECURSIVE rec (
					root_account_id,
					account_id,
					manager_account_id,
					apath, cycle
	    			) as (
		    			SELECT  account_id as root_account_id,
			    			account_id, manager_account_id,
			    			ARRAY[account_id] as apath, false as cycle
		    			FROM    v_account_manager_map
					UNION ALL
		    			SELECT a.root_account_id, m.account_id, m.manager_account_id,
						a.apath || m.account_id, m.account_id=ANY(a.apath)
		    			FROM rec a join v_account_manager_map m
						ON a.manager_account_id = m.account_id
		    			WHERE not a.cycle
			) SELECT count(*) from rec where root_account_id = $1
				and manager_account_id = $2
		' INTO _tally USING _r.approver_account_id, approving_account_id;

		IF _tally = 0 THEN
			EXECUTE '
				SELECT	count(*)
				FROM	property
						INNER JOIN v_acct_coll_acct_expanded e
						USING (account_collection_id)
				WHERE	property_type = ''Defaults''
				AND		property_name = ''_can_approve_all''
				AND		e.account_id = $1
			' INTO _tally USING approving_account_id;

			IF _tally = 0 THEN
				RAISE EXCEPTION 'Only a person and their management chain may approve others';
			END IF;
		END IF;

	END IF;

	IF _r.approval_instance_item_id IS NULL THEN
		RAISE EXCEPTION 'Unknown approval_instance_item_id %',
			approval_instance_item_id;
	END IF;

	IF _r.is_approved IS NOT NULL THEN
		RAISE EXCEPTION 'Approval is already completed.';
	END IF;

	IF approved = 'N' THEN
		IF _r.reject_app_process_chain_id IS NOT NULL THEN
			_chid := _r.reject_app_process_chain_id;	
		END IF;
	ELSIF approved = 'Y' THEN
		IF _r.accept_app_process_chain_id IS NOT NULL THEN
			_chid := _r.accept_app_process_chain_id;
		END IF;
	ELSE
		RAISE EXCEPTION 'Approved must be Y or N';
	END IF;

	IF _chid IS NOT NULL THEN
		_new := approval_utils.build_next_approval_item(
			approval_instance_item_id, _chid,
			_r.approval_instance_id, approved,
			approving_account_id, new_value);

		EXECUTE '
			UPDATE approval_instance_item
			SET next_approval_instance_item_id = $2
			WHERE approval_instance_item_id = $1
		' USING approval_instance_item_id, _new;
	END IF;

	--
	-- This needs to happen after the next steps are created
	-- or the entire process gets marked as done on the second to last
	-- update instead of the list.

	EXECUTE '
		UPDATE approval_instance_item
		SET is_approved = $2,
		approved_account_id = $3
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id, approved, approving_account_id;

	RETURN true;
END;
$function$
;

-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH TABLE v_dev_col_user_prop_expanded [5456720]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dev_col_user_prop_expanded', 'v_dev_col_user_prop_expanded');
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_dev_col_user_prop_expanded');
DROP VIEW IF EXISTS jazzhands.v_dev_col_user_prop_expanded;
CREATE VIEW jazzhands.v_dev_col_user_prop_expanded AS
 SELECT upo.property_id,
    dchd.device_collection_id,
    a.account_id,
    a.login,
    a.account_status,
    ar.account_realm_id,
    ar.account_realm_name,
    a.is_enabled,
    upo.property_type,
    upo.property_name,
    COALESCE(upo.property_value_password_type, upo.property_value) AS property_value,
        CASE
            WHEN upn.is_multivalue = 'N'::bpchar THEN 0
            ELSE 1
        END AS is_multivalue,
        CASE
            WHEN pdt.property_data_type::text = 'boolean'::text THEN 1
            ELSE 0
        END AS is_boolean
   FROM v_acct_coll_acct_expanded_detail uued
     JOIN account_collection u USING (account_collection_id)
     JOIN v_property upo ON upo.account_collection_id = u.account_collection_id AND (upo.property_type::text = ANY (ARRAY['CCAForceCreation'::character varying, 'CCARight'::character varying, 'ConsoleACL'::character varying, 'RADIUS'::character varying, 'TokenMgmt'::character varying, 'UnixPasswdFileValue'::character varying, 'UserMgmt'::character varying, 'cca'::character varying, 'feed-attributes'::character varying, 'wwwgroup'::character varying, 'HOTPants'::character varying]::text[]))
     JOIN val_property upn ON upo.property_name::text = upn.property_name::text AND upo.property_type::text = upn.property_type::text
     JOIN val_property_data_type pdt ON upn.property_data_type::text = pdt.property_data_type::text
     JOIN account a ON uued.account_id = a.account_id
     JOIN account_realm ar ON a.account_realm_id = ar.account_realm_id
     LEFT JOIN v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = upo.device_collection_id
  ORDER BY dchd.device_collection_level,
        CASE
            WHEN u.account_collection_type::text = 'per-account'::text THEN 0
            WHEN u.account_collection_type::text = 'property'::text THEN 1
            WHEN u.account_collection_type::text = 'systems'::text THEN 2
            ELSE 3
        END,
        CASE
            WHEN uued.assign_method = 'Account_CollectionAssignedToPerson'::text THEN 0
            WHEN uued.assign_method = 'Account_CollectionAssignedToDept'::text THEN 1
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToPerson'::text THEN 2
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToDept'::text THEN 2
            WHEN uued.assign_method = 'Account_CollectionAssignedToParentDept'::text THEN 3
            WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToParentDep'::text THEN 3
            ELSE 6
        END, uued.dept_level, uued.acct_coll_level, dchd.device_collection_id, u.account_collection_id;

-- DONE DEALING WITH TABLE v_dev_col_user_prop_expanded [5436873]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_coll_device_expanded
DROP VIEW IF EXISTS jazzhands.v_device_coll_device_expanded;
CREATE VIEW jazzhands.v_device_coll_device_expanded AS
 WITH RECURSIVE var_recurse(root_device_collection_id, device_collection_id, parent_device_collection_id, device_collection_level, array_path, cycle) AS (
         SELECT device_collection.device_collection_id AS root_device_collection_id,
            device_collection.device_collection_id,
            device_collection.device_collection_id AS parent_device_collection_id,
            0 AS device_collection_level,
            ARRAY[device_collection.device_collection_id] AS "array",
            false AS bool
           FROM device_collection
        UNION ALL
         SELECT x.root_device_collection_id,
            dch.device_collection_id,
            dch.parent_device_collection_id,
            x.device_collection_level + 1 AS device_collection_level,
            dch.parent_device_collection_id || x.array_path AS array_path,
            dch.parent_device_collection_id = ANY (x.array_path)
           FROM var_recurse x
             JOIN device_collection_hier dch ON x.device_collection_id = dch.parent_device_collection_id
          WHERE NOT x.cycle
        )
 SELECT DISTINCT var_recurse.root_device_collection_id AS device_collection_id,
    device_collection_device.device_id
   FROM var_recurse
     JOIN device_collection_device USING (device_collection_id);

-- DONE DEALING WITH TABLE v_device_coll_device_expanded [5436834]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_hotpants_account_attribute
DROP VIEW IF EXISTS jazzhands.v_hotpants_account_attribute;
CREATE VIEW jazzhands.v_hotpants_account_attribute AS
 SELECT v_dev_col_user_prop_expanded.property_id,
    v_dev_col_user_prop_expanded.account_id,
    v_dev_col_user_prop_expanded.device_collection_id,
    v_dev_col_user_prop_expanded.login,
    v_dev_col_user_prop_expanded.property_name,
    v_dev_col_user_prop_expanded.property_type,
    v_dev_col_user_prop_expanded.property_value,
    v_dev_col_user_prop_expanded.is_boolean
   FROM v_dev_col_user_prop_expanded
     JOIN device_collection USING (device_collection_id)
  WHERE v_dev_col_user_prop_expanded.is_enabled = 'Y'::bpchar AND ((device_collection.device_collection_type::text = ANY (ARRAY['HOTPants-app'::character varying, 'HOTPants'::character varying]::text[])) OR (v_dev_col_user_prop_expanded.property_type::text = ANY (ARRAY['RADIUS'::character varying, 'HOTPants'::character varying]::text[])));

-- DONE DEALING WITH TABLE v_hotpants_account_attribute [5437040]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_hotpants_client
DROP VIEW IF EXISTS jazzhands.v_hotpants_client;
CREATE VIEW jazzhands.v_hotpants_client AS
 SELECT dc.device_id,
    d.device_name,
    netblock.ip_address,
    p.property_value AS radius_secret
   FROM property p
     JOIN v_device_coll_device_expanded dc USING (device_collection_id)
     JOIN device d USING (device_id)
     JOIN network_interface ni USING (device_id)
     JOIN netblock USING (netblock_id)
  WHERE p.property_name::text = 'RadiusSharedSecret'::text AND p.property_type::text = 'HOTPants'::text;

-- DONE DEALING WITH TABLE v_hotpants_client [5437035]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_hotpants_dc_attribute
DROP VIEW IF EXISTS jazzhands.v_hotpants_dc_attribute;
CREATE VIEW jazzhands.v_hotpants_dc_attribute AS
 SELECT property.property_id,
    property.device_collection_id,
    property.property_name,
    property.property_type,
    property.property_value_password_type AS property_value
   FROM property
  WHERE property.property_name::text = 'PWType'::text AND property.property_type::text = 'HOTPants'::text AND property.account_collection_id IS NULL;

-- DONE DEALING WITH TABLE v_hotpants_dc_attribute [5437045]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_hotpants_device_collection
DROP VIEW IF EXISTS jazzhands.v_hotpants_device_collection;
CREATE VIEW jazzhands.v_hotpants_device_collection AS
 SELECT DISTINCT device_collection_device.device_id,
    device.device_name,
    device_collection.device_collection_id,
    device_collection.device_collection_name,
    device_collection.device_collection_type,
    host(nb.ip_address) AS ip_address
   FROM device_collection
     JOIN property p USING (device_collection_id)
     JOIN device_collection_device USING (device_collection_id)
     JOIN device USING (device_id)
     JOIN network_interface ni USING (device_id)
     JOIN netblock nb USING (netblock_id)
  WHERE p.property_type::text = ANY (ARRAY['HOTPants'::character varying, 'HOTPants-app'::character varying]::text[]);

-- DONE DEALING WITH TABLE v_hotpants_device_collection [5437025]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_hotpants_token
DROP VIEW IF EXISTS jazzhands.v_hotpants_token;
CREATE VIEW jazzhands.v_hotpants_token AS
 SELECT t.token_id,
    t.token_type,
    t.token_status,
    t.token_serial,
    t.token_key,
    t.zero_time,
    t.time_modulo,
    t.token_password,
    t.is_token_locked,
    t.token_unlock_time,
    t.bad_logins,
    ts.token_sequence,
    ts.last_updated,
    en.encryption_key_db_value,
    en.encryption_key_purpose,
    en.encryption_key_purpose_version,
    en.encryption_method
   FROM token t
     JOIN token_sequence ts USING (token_id)
     LEFT JOIN encryption_key en USING (encryption_key_id);

-- DONE DEALING WITH TABLE v_hotpants_token [5437030]
--------------------------------------------------------------------
--
-- Process trigger procs in jazzhands
--
--
-- Process trigger procs in net_manip
--
--
-- Process trigger procs in network_strings
--
--
-- Process trigger procs in time_util
--
--
-- Process trigger procs in dns_utils
--
--
-- Process trigger procs in person_manip
--
--
-- Process trigger procs in auto_ac_manip
--
--
-- Process trigger procs in company_manip
--
--
-- Process trigger procs in token_utils
--
--
-- Process trigger procs in port_support
--
--
-- Process trigger procs in port_utils
--
--
-- Process trigger procs in device_utils
--
--
-- Process trigger procs in netblock_utils
--
--
-- Process trigger procs in netblock_manip
--
--
-- Process trigger procs in physical_address_utils
--
--
-- Process trigger procs in component_utils
--
--
-- Process trigger procs in snapshot_manip
--
--
-- Process trigger procs in lv_manip
--
--
-- Process trigger procs in schema_support
--
--
-- Process trigger procs in approval_utils
--
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
-- triggers


-- Copyright (c) 2016, Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.


-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


\set ON_ERROR_STOP

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'token_utils';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS token_utils;
                CREATE SCHEMA token_utils AUTHORIZATION jazzhands;
                COMMENT ON SCHEMA token_utils IS 'part of jazzhands';
        END IF;
END;
$$;

--
-- set_sequence allows the sequence of a token to be set or reset either
-- due to normal usage or if it's skewed for some reason
--
CREATE OR REPLACE FUNCTION token_utils.set_sequence(
	p_token_id		Token_Sequence.Token_ID % TYPE,
	p_token_sequence	Token_Sequence.Token_Sequence % TYPE,
	p_reset_time		timestamp DEFAULT NULL
) RETURNS void AS $$
DECLARE
	_cur		token_sequence%ROWTYPE;
BEGIN

	IF p_token_id IS NULL THEN
		RAISE EXCEPTION 'Invalid token %', p_token_id
			USING ERRCODE = invalid_parameter_value;
	END IF;

	EXECUTE '
		SELECT *
		FROM token_sequence
		WHERE token_id = $1
	' INTO _cur USING p_token_id;

	IF _cur.token_id IS NULL THEN
		raise notice 'insert';
		EXECUTE '
			INSERT INTO token_sequence (
				token_id, token_sequence, last_updated
			) VALUES (
				$1, $2, $3
			);
		' USING p_token_id, p_token_sequence, p_reset_time;
	ELSE
		IF p_reset_time IS NULL THEN
			-- Using this code path, do not reset the sequence back, ever
			raise notice 'update without date';
			UPDATE Token_Sequence SET
				Token_Sequence = p_token_sequence,
				last_updated = now()
			WHERE
				Token_ID = p_token_id
				AND Token_Sequence < p_token_sequence;
		ELSE
			--
			-- Only reset the sequence back if its newer than what's in the
			-- db
			raise notice 'update with date';
			UPDATE Token_Sequence SET
				Token_Sequence = p_token_sequence,
				Last_Updated = p_reset_time
			WHERE Token_ID = p_token_id
			AND Last_Updated <= p_reset_time;
		END IF;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- set_lock_status changes the lock status of the token.  
--
CREATE OR REPLACE FUNCTION token_utils.set_lock_status(
	p_token_id	token.token_id % TYPE,
	p_lock_status	token.is_token_locked % TYPE,
	p_unlock_time	token.token_unlock_time % TYPE,
	p_bad_logins	token.bad_logins % TYPE,
	p_last_updated	token.last_updated % TYPE
) RETURNS void AS $$
DECLARE
	_cur		token%ROWTYPE;
BEGIN

	IF p_token_id IS NULL THEN
		RAISE EXCEPTION 'Invalid token %', p_token_id
			USING ERRCODE = invalid_parameter_value;
	END IF;

	EXECUTE '
		SELECT *
		FROM token
		WHERE token_id = $1
	' INTO _cur USING p_token_id;

	IF _cur.last_updated < p_last_updated THEN
		UPDATE token SET
		is_token_locked = p_lock_status,
			token_unlock_time = p_unlock_time,
			bad_logins = p_bad_logins,
			last_updated = p_last_updated
		WHERE
			Token_ID = p_token_id;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

grant select on all tables in schema token_utils to iud_role;
grant usage on schema token_utils to iud_role;
revoke all on schema token_utils from public;
revoke all on  all functions in schema token_utils from public;
grant execute on all functions in schema token_utils to iud_role;


INSERT INTO val_property_type
	(property_type, description)
VALUES
	('HOTPants', 'properties that define HOTPants behavior')
;

insert into val_property (property_name, property_type,
        permit_device_collection_id, property_data_type, description
) values (
        'RadiusSharedSecret', 'HOTPants',
        'REQUIRED', 'string', 'RADIUS share secret consumed by HOTPants'
);

UPDATE val_property
SET property_type = 'HOTPants'
WHERE property_type = 'RADIUS'
AND property_name IN ('GrantAccess');

update val_property 
SET property_data_type = 'password_type', property_type = 'HOTPants'
WHERE property_type = 'RADIUS' and property_name = 'PWType';

insert into val_property (property_name, property_type,
        permit_device_collection_id,  permit_account_collection_id,
        property_data_type, description
) values (
        'Group', 'RADIUS',
        'REQUIRED', 'REQUIRED',
        'string', 'group used by radius client'
);


insert into val_token_status (token_status)
values
	('disabled'),
	('enabled'),
	('lost'),
	('destored'),
	('stolen');

insert into val_token_type (token_type, description, token_digit_count)
values
	('soft_seq', 'sequence based soft token', 6),
	('soft_time', 'time-based soft token', 6);

insert into val_encryption_key_purpose (
	encryption_key_purpose, encryption_key_purpose_version, description
) values (
	'tokenkey', 1, 'Passwords for Token Keys'
);


-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;
-- SELECT schema_support.end_maintenance();
select timeofday(), now();
