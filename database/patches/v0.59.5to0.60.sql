/*
 *
 * Copyright (c) 2014 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
  TODO before release:

	- check inner_device_commonet_trigger to make sure it is right
	- mdr to finish component triggers
	- resolve component issues
		- device_type becomes component_type?
		- rack becomes a component?
	- compatibility views
	- finish testing all the new account collection triggers
		(write stored procedures)
	- check init/ *.sql changes for updates that should happen 
	- search for XXX's

 */

/*
Invoked:
	--scan-tables
	--suffix=v59
	netblock_utils.calculate_intermediate_netblocks
	netblock_manip.allocate_netblock
	delete_peraccount_account_collection
	update_peraccount_account_collection
	asset
	device_type
	device
	val_volume_group_relation
	val_logical_volume_property
	val_component_property
	val_raid_type
	val_slot_function
	val_component_function
	val_filesystem_type
	val_slot_physical_interface
	val_component_property_value
	val_component_property_type
	slot_type_prmt_rem_slot_type
	inter_component_connection
	component_type
	component_property
	component_type_slot_tmplt
	slot_type_prmt_comp_slot_type
	slot_type
	logical_port_slot
	slot
	component_type_component_func
	component
	physicalish_volume
	volume_group_physicalish_vol
	logical_volume
	logical_volume_property
	volume_group
	delete_peruser_account_collection
	update_peruser_account_collection
	netblock_utils.list_unallocated_netblocks
	person_manip.purge_account
	automated_ac_on_account
	automated_ac_on_person_company
	automated_ac_on_person
	automated_realm_site_ac_pl
	val_operating_system_family
	val_os_snapshot_type
	operating_system_snapshot
	operating_system
	property
	val_property
	v_company_hier
	person_manip.change_company
	person_manip.change_company
	v_property
	validate_device_component_assignment
	validate_asset_component_assignment
	validate_slot_component_id
	validate_inter_component_connection
	validate_component_rack_location
	validate_component_property
	v_nblk_coll_netblock_expanded
*/

SELECT schema_support.begin_maintenance();
\set ON_ERROR_STOP

select now();

 ALTER TABLE ACCOUNT_REALM_COMPANY DROP CONSTRAINT FK_ACCT_RLM_CMPY_CMPY_ID;
 ALTER TABLE ACCOUNT_REALM_COMPANY 
	ADD CONSTRAINT FK_ACCT_RLM_CMPY_CMPY_ID FOREIGN KEY (COMPANY_ID) 
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE CIRCUIT DROP CONSTRAINT FK_CIRCUIT_VEND_COMPANYID;
 ALTER TABLE CIRCUIT
	ADD CONSTRAINT FK_CIRCUIT_VEND_COMPANYID FOREIGN KEY (VENDOR_COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE CIRCUIT DROP CONSTRAINT FK_CIRCUIT_ALOC_COMPANYID;
 ALTER TABLE CIRCUIT
	ADD CONSTRAINT FK_CIRCUIT_ALOC_COMPANYID FOREIGN KEY (ALOC_LEC_COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE CIRCUIT DROP CONSTRAINT FK_CIRCUIT_ZLOC_COMPANY_ID;
 ALTER TABLE CIRCUIT
	ADD CONSTRAINT FK_CIRCUIT_ZLOC_COMPANY_ID FOREIGN KEY (ZLOC_LEC_COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE COMPANY DROP CONSTRAINT FK_COMPANY_PARENT_COMPANY_ID;
 ALTER TABLE COMPANY
	ADD CONSTRAINT FK_COMPANY_PARENT_COMPANY_ID FOREIGN KEY (PARENT_COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE COMPANY_TYPE DROP CONSTRAINT FK_COMPANY_TYPE_COMPANY_ID;
 ALTER TABLE COMPANY_TYPE
	ADD CONSTRAINT FK_COMPANY_TYPE_COMPANY_ID FOREIGN KEY (COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE CONTRACT DROP CONSTRAINT FK_CONTRACT_COMPANY_ID;
 ALTER TABLE CONTRACT
	ADD CONSTRAINT FK_CONTRACT_COMPANY_ID FOREIGN KEY (COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE DEPARTMENT DROP CONSTRAINT FK_DEPT_COMPANY;
 ALTER TABLE DEPARTMENT
	ADD CONSTRAINT FK_DEPT_COMPANY FOREIGN KEY (COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE  ;

 ALTER TABLE DEVICE DROP CONSTRAINT FK_DEVICE_COMPANY__ID;
 ALTER TABLE DEVICE
	ADD CONSTRAINT FK_DEVICE_COMPANY__ID FOREIGN KEY (COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE DEVICE_TYPE DROP CONSTRAINT FK_DEVTYP_COMPANY;
 ALTER TABLE DEVICE_TYPE
	ADD CONSTRAINT FK_DEVTYP_COMPANY FOREIGN KEY (COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE NETBLOCK DROP CONSTRAINT FK_NETBLOCK_COMPANY;
 ALTER TABLE NETBLOCK
	ADD CONSTRAINT FK_NETBLOCK_COMPANY FOREIGN KEY (NIC_COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE OPERATING_SYSTEM DROP CONSTRAINT FK_OS_COMPANY;
 ALTER TABLE OPERATING_SYSTEM
	ADD CONSTRAINT FK_OS_COMPANY FOREIGN KEY (COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE PERSON_COMPANY DROP CONSTRAINT FK_PERSON_COMPANY_COMPANY_ID;
 ALTER TABLE PERSON_COMPANY
	ADD CONSTRAINT FK_PERSON_COMPANY_COMPANY_ID FOREIGN KEY (COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE PERSON_CONTACT DROP CONSTRAINT FK_PRSN_CONTECT_CR_CMPYID;
 ALTER TABLE PERSON_CONTACT
	ADD CONSTRAINT FK_PRSN_CONTECT_CR_CMPYID FOREIGN KEY (PERSON_CONTACT_CR_COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE PHYSICAL_ADDRESS DROP CONSTRAINT FK_PHYSADDR_COMPANY_ID;
 ALTER TABLE PHYSICAL_ADDRESS
	ADD CONSTRAINT FK_PHYSADDR_COMPANY_ID FOREIGN KEY (COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE PROPERTY DROP CONSTRAINT FK_PROPERTY_COMPID;
 ALTER TABLE PROPERTY
	ADD CONSTRAINT FK_PROPERTY_COMPID FOREIGN KEY (COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE PROPERTY DROP CONSTRAINT FK_PROPERTY_PVAL_COMPID;
 ALTER TABLE PROPERTY
	ADD CONSTRAINT FK_PROPERTY_PVAL_COMPID FOREIGN KEY (PROPERTY_VALUE_COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE SITE DROP CONSTRAINT FK_SITE_COLO_COMPANY_ID;
 ALTER TABLE SITE
	ADD CONSTRAINT FK_SITE_COLO_COMPANY_ID FOREIGN KEY (COLO_COMPANY_ID)
	REFERENCES COMPANY (COMPANY_ID)  DEFERRABLE  INITIALLY IMMEDIATE;

 ALTER TABLE PERSON_ACCOUNT_REALM_COMPANY 
	DROP CONSTRAINT FK_AC_AC_RLM_CPY_ACT_RLM_CPY;
 ALTER TABLE PERSON_ACCOUNT_REALM_COMPANY
       ADD CONSTRAINT FK_AC_AC_RLM_CPY_ACT_RLM_CPY 
	FOREIGN KEY (ACCOUNT_REALM_ID, COMPANY_ID) 
	REFERENCES ACCOUNT_REALM_COMPANY (ACCOUNT_REALM_ID, COMPANY_ID)  
	DEFERRABLE  INITIALLY IMMEDIATE;


--------------------------------------------------------------------
-- BEGIN kill IntegrityPackage
--------------------------------------------------------------------

DROP FUNCTION IF EXISTS "IntegrityPackage"."InitNestLevel"();
DROP FUNCTION IF EXISTS "IntegrityPackage"."NextNestLevel"();
DROP FUNCTION IF EXISTS "IntegrityPackage"."PreviousNestLevel"();
DROP FUNCTION IF EXISTS "IntegrityPackage"."GetNestLevel"();
DROP SCHEMA IF EXISTS "IntegrityPackage";

--------------------------------------------------------------------
-- END kill IntegrityPackage
--------------------------------------------------------------------

--------------------------------------------------------------------
-- migrate per-user to per-account and give a genericy name 
--------------------------------------------------------------------

alter table account_collection drop constraint "fk_acctcol_usrcoltyp";

WITH merge AS (
	SELECT  account_collection_id, account_id, login,
		account_collection_name
	FROM    account_collection
		INNER JOIN account_collection_account
			USING (account_collection_id)
		INNER JOIN account USING (account_id)
	WHERE   account_collection_type = 'per-account'
)  UPDATE account_collection ac
	SET account_collection_name =
		CONCAT(m.login, '_', m.account_id),
	account_collection_type = 'per-account'
FROM merge m
WHERE m.account_collection_id = ac.account_collection_Id;


update val_account_collection_type set account_collection_type = 'per-account'
where account_collection_type = 'per-user';

update account_collection set account_collection_type = 'per-account'
where account_collection_type = 'per-user';

ALTER TABLE ACCOUNT_COLLECTION
	ADD CONSTRAINT FK_ACCTCOL_USRCOLTYP 
	FOREIGN KEY (ACCOUNT_COLLECTION_TYPE) 
	REFERENCES VAL_ACCOUNT_COLLECTION_TYPE (ACCOUNT_COLLECTION_TYPE)  ;

-- related; the procedures are dropped later
-- triggers
DROP TRIGGER IF EXISTS trig_automated_ac ON account;
DROP TRIGGER IF EXISTS trigger_delete_peruser_account_collection ON account;
DROP TRIGGER IF EXISTS trigger_update_account_type_account_collection ON account;
DROP TRIGGER IF EXISTS trigger_update_peruser_account_collection ON account;

--------------------------------------------------------------------
-- DONE: migrate per-user to per-account and give a genericy name 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN add physical_address_utils
--------------------------------------------------------------------

--
-- Copyright (c) 2014 Matthew Ragan
-- All rights reserved.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'physical_address_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS physical_address_utils;
		CREATE SCHEMA physical_address_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA physical_address_utils IS 'part of jazzhands';
	END IF;
END;
$$;

CREATE OR REPLACE FUNCTION physical_address_utils.localized_physical_address(
	physical_address_id integer,
	line_separator text DEFAULT ', ',
	include_country boolean DEFAULT true
) RETURNS text AS $$
DECLARE
	address	text;
BEGIN
	SELECT concat_ws(line_separator,
			CASE WHEN iso_country_code IN 
					('SG', 'US', 'CA', 'UK', 'GB', 'FR', 'AU') THEN 
				concat_ws(' ', address_housename, address_street)
			WHEN iso_country_code IN ('IL') THEN
				concat_ws(', ', address_housename, address_street)
			WHEN iso_country_code IN ('ES') THEN
				concat_ws(', ', address_street, address_housename)
			ELSE
				concat_ws(' ', address_street, address_housename)
			END,
			address_pobox,
			address_building,
			address_neighborhood,
			CASE WHEN iso_country_code IN ('US', 'CA', 'UK') THEN 
				concat_ws(', ', address_city, 
					concat_ws(' ', address_region, postal_code))
			WHEN iso_country_code IN ('SG', 'AU') THEN
				concat_ws(' ', address_city, address_region, postal_code)
			ELSE
				concat_ws(' ', postal_code, address_city, address_region)
			END,
			iso_country_code
		)
	INTO address
	FROM
		physical_address pa
	WHERE
		pa.physical_address_id = 
			localized_physical_address.physical_address_id;
	RETURN address;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION physical_address_utils.localized_street_address(
	address_housename text DEFAULT NULL,
	address_street text DEFAULT NULL,
	address_building text DEFAULT NULL,
	address_pobox text DEFAULT NULL,
	iso_country_code text DEFAULT NULL,
	line_separator text DEFAULT ', '
) RETURNS text AS $$
BEGIN
	RETURN concat_ws(line_separator,
			CASE WHEN iso_country_code IN 
					('SG', 'US', 'CA', 'UK', 'GB', 'FR', 'AU') THEN 
				concat_ws(' ', address_housename, address_street)
			WHEN iso_country_code IN ('IL') THEN
				concat_ws(', ', address_housename, address_street)
			WHEN iso_country_code IN ('ES') THEN
				concat_ws(', ', address_street, address_housename)
			ELSE
				concat_ws(' ', address_street, address_housename)
			END,
			address_pobox,
			address_building
		);
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA physical_address_utils TO public;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA physical_address_utils TO ro_role;

--------------------------------------------------------------------
-- END add physical_address_utils
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN add company_manip
--------------------------------------------------------------------

/*
 * Copyright (c) 2015 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * $Id$
 */

\set ON_ERROR_STOP

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'company_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS company_manip;
		CREATE SCHEMA company_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA company_manip IS 'part of jazzhands';
	END IF;
END;
$$;

------------------------------------------------------------------------------

--
-- account realm is here because its possible for companies to be part of
-- multiple account realms.
--

--
-- sets up the automated account collections.  This assumes some carnal
-- knowledge of some of the types.
--
-- This is typically only called from add_company.
--
-- note that there is no 'remove_auto_collections'
--
CREATE OR REPLACE FUNCTION company_manip.add_auto_collections(
	_company_id		company.company_id%type,
	_account_realm_id	account_realm.account_realm_id%type,
	_company_type	text
) RETURNS void AS
$$
DECLARE
	_ar		account_realm.account_realm_name%TYPE;
	_csn	company.company_short_name%TYPE;
	_r		RECORD;
	_v		text[];
	i		text;
	acname	account_collection.account_collection_name%TYPE;
	acid	account_collection.account_collection_id%TYPE;
	propv	text;
	tally	integer;
BEGIN
	PERFORM *
	FROM	account_realm_company
	WHERE	company_id = _company_id
	AND		account_realm_id = _account_realm_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Company and Account Realm are not associated together'
			USING ERRCODE = 'not_null_violation';
	END IF;

	PERFORM *
	FROM	company_type
	WHERE	company_id = _company_id
	AND		company_type = _company_type;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Company % is not of type %', _company_id, _company_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	tally := 0;
	FOR _r IN SELECT	property_name, property_type, permit_company_id
				FROM    property_collection_property pcp
				INNER JOIN property_collection pc
					USING (property_collection_id)
				INNER JOIN val_property vp USING (property_name,property_type)
				WHERE property_collection_type = 'auto_ac_assignment'
				AND property_collection_name = _company_type
				AND property_name != 'site'
	LOOP
		IF _r.property_name = 'account_type' THEN
			SELECT array_agg( account_type)
			INTO _v
			FROM val_account_type
			WHERE account_type != 'blacklist';
		ELSE
			_v := ARRAY[NULL]::text[];
		END IF;

	SELECT	account_realm_name
	INTO	_ar
	FROM	account_realm
	WHERE	account_realm_id = _account_realm_id;

	SELECT	company_short_name
	INTO	_csn
	FROM	company
	WHERE	company_id = _company_id;

		FOREACH i IN ARRAY _v
		LOOP
			IF i IS NULL THEN
				acname := concat(_ar, '_', _csn, '_', _r.property_name);
				propv := NULL;
			ELSE
				acname := concat(_ar, '_', _csn, '_', i);
				propv := i;
			END IF;

			INSERT INTO account_collection (
				account_collection_name, account_collection_type
			) VALUES (
				acname, 'automated'
			) RETURNING account_collection_id INTO acid;

			INSERT INTO property (
				property_name, property_type, account_realm_id,
				account_collection_id,
				company_id, property_value
			) VALUES (
				_r.property_name, _r.property_type, _account_realm_id,
				acid,
				_company_id, propv
			);
			tally := tally + 1;
		END LOOP;
	END LOOP;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--
-- add site based automated account collections for the given realm to be
-- automanaged by trigger.
--
-- NOTE:  There is no remove_auto_collections_site.
--
CREATE OR REPLACE FUNCTION company_manip.add_auto_collections_site(
	_company_id		company.company_id%type,
	_account_realm_id	account_realm.account_realm_id%type,
	_site_code		site.site_code%type
) RETURNS void AS
$$
DECLARE
	_ar		account_realm.account_realm_name%TYPE;
	_csn	company.company_short_name%TYPE;
	acname	account_collection.account_collection_name%TYPE;
	acid	account_collection.account_collection_id%TYPE;
	tally	integer;
BEGIN
	PERFORM *
	FROM	account_realm_company
	WHERE	company_id = _company_id
	AND		account_realm_id = _account_realm_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Company and Account Realm are not associated together'
			USING ERRCODE = 'not_null_violation';
	END IF;

	acname := concat(_ar, '_', _site_code);

	INSERT INTO account_collection (
		account_collection_name, account_collection_type
	) VALUES (
		acname, 'automated'
	) RETURNING account_collection_id INTO acid;

	INSERT INTO property (
		property_name, property_type, account_realm_id,
		account_collection_id,
		site_code
	) VALUES (
		'site', 'auto_acct_coll', _account_realm_id,
		acid,
		_site_code
	);
	tally := tally + 1;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;



------------------------------------------------------------------------------

--
-- addds company types to company, and sets up any automated classes
-- associated via company_manip.add_auto_collections.
--
-- note that there is no 'remove_company_types'
--
CREATE OR REPLACE FUNCTION company_manip.add_company_types(
	_company_id		company.company_id%type,
	_account_realm_id	account_realm.account_realm_id%type DEFAULT NULL,
	_company_types	text[] default NULL
) RETURNS integer AS
$$
DECLARE
	x		text;
	count	integer;
BEGIN
	count := 0;
	FOREACH x IN ARRAY _company_types
	LOOP
		INSERT INTO company_type (company_id, company_type)
			VALUES (_company_id, x);
		PERFORM company_manip.add_auto_collections(_company_id, _account_realm_id, x);
		count := count + 1;
	END LOOP;
	return count;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

------------------------------------------------------------------------------

--
-- primary interface to add things to the company table.  It does other
-- necessary manipulations based on company types.
--
-- shortname is inferred if not set
--
-- NOTE: There is no remove_company.
--
CREATE OR REPLACE FUNCTION company_manip.add_company(
	_company_name		text,
	_company_types		text[] default NULL,
	_parent_company_id	company.company_id%type DEFAULT NULL,
	_account_realm_id	account_realm.account_realm_id%type DEFAULT NULL,
	_company_short_name	text DEFAULT NULL,
	_description		text DEFAULT NULL

) RETURNS integer AS
$$
DECLARE
	_cmpid	company.company_id%type;
	_short	text;
	_isfam	char(1);
BEGIN
	IF _company_types @> ARRAY['corporate family'] THEN
		_isfam := 'Y';
	ELSE
		_isfam := 'N';
	END IF;
	IF _company_short_name IS NULL and _isfam = 'Y' THEN
		_short := lower(regexp_replace(
				regexp_replace(
					regexp_replace(_company_name, 
						E'\\s+(ltd|sarl|limited|pt[ye]|GmbH|ag|ab|inc)', 
						'', 'gi'),
					E'[,\\.\\$#@]', '', 'mg'),
				E'\\s+', '_', 'gi'));
	END IF;

	INSERT INTO company (
		company_name, company_short_name, is_corporate_family,
		parent_company_id, description
	) VALUES (
		_company_name, _short, _isfam,
		_parent_company_id, _description
	) RETURNING company_id INTO _cmpid;

	IF _account_realm_id IS NOT NULL THEN
		INSERT INTO account_realm_company (
			account_realm_id, company_id
		) VALUES (
			_account_realm_id, _cmpid
		);
	END IF;

	IF _company_types IS NOT NULL THEN
		PERFORM company_manip.add_company_types(_cmpid, _account_realm_id, _company_types);
	END IF;

	RETURN _cmpid;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

------------------------------------------------------------------------------
--
-- Adds a location to a company with the given site code and address.  It will
-- take are of any automated account collections that are needed.
--
-- NOTE: There is no remove_location.
--
CREATE OR REPLACE FUNCTION company_manip.add_location(
	_company_id		company.company_id%type,
	_site_code		site.site_code%type,
	_physical_address_id	physical_address.physical_address_id%type,
	_account_realm_id	account_realm.account_realm_id%type DEFAULT NULL,
	_site_status		site.site_status%type DEFAULT 'ACTIVE',
	_description		text DEFAULT NULL
) RETURNS void AS
$$
DECLARE
BEGIN
	INSERT INTO site (site_code, colo_company_id,
		physical_address_id, site_status, description
	) VALUES (
		_site_code, _company_id,
		_physical_address_id, _site_status, _description
	);

	if _account_realm_id IS NOT NULL THEN
		PERFORM company_manip.add_auto_collections_site(
			_company_id,
			_account_realm_id,
			_site_code
		);
	END IF;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------
-- END add company_manip
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN add v_person_company_hier
--------------------------------------------------------------------

-- Copyright (c) 2015, Todd M. Kover
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

CREATE OR REPLACE VIEW v_person_company_hier AS
WITH RECURSIVE pc_recurse (
	level,
	person_id,
	subordinate_person_id,
	intermediate_person_id,
	person_company_relation,
	array_path,
	rvs_array_path,
	cycle
) AS (
		SELECT DISTINCT
			0 							as level,
			manager_person_id			as person_id,
			person_id					as subordinate_person_id,
			manager_person_id			as intermediate_person_id,
			person_company_relation		as person_company_relation,
			ARRAY[manager_person_id] 	as array_path,
			ARRAY[manager_person_id] 	as rvs_array_path,
			false
		FROM
			person_company pc
			JOIN val_person_status vps  on
				pc.person_company_status = vps.person_status
		WHERE	is_disabled = 'N'
	UNION ALL
		SELECT 
			x.level + 1 				as level,
			x.person_id					as person_id,
			pc.person_id				as subordinate_person_id,
			pc.manager_person_id		as intermediate_person_id,
			pc.person_company_relation	as person_company_relation,
			x.array_path || pc.person_id as array_path,
			pc.person_id || x.rvs_array_path 
				as rvs_array_path,
			pc.person_id = ANY(array_path) as cycle
		FROM
			pc_recurse x 
			JOIN person_company pc ON
				x.subordinate_person_id = pc.manager_person_id
			JOIN val_person_status vps  on
				pc.person_company_status = vps.person_status
		WHERE
			is_disabled = 'N'
		AND
			NOT cycle 
) SELECT
	level,
	person_id,
	subordinate_person_id,
	intermediate_person_id,
	person_company_relation,
	array_path,
	rvs_array_path,
	cycle
	FROM
		pc_recurse
;

--------------------------------------------------------------------
-- END add v_person_company_hier
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN AUTOGEN DDL
--------------------------------------------------------------------

-- Creating new sequences....
CREATE SEQUENCE component_property_component_property_id_seq;
CREATE SEQUENCE inter_component_connection_inter_component_connection_id_seq;
CREATE SEQUENCE component_type_component_type_id_seq;
CREATE SEQUENCE physicalish_volume_physicalish_volume_id_seq;
CREATE SEQUENCE component_component_id_seq;
CREATE SEQUENCE slot_slot_id_seq;
CREATE SEQUENCE component_type_slot_tmplt_component_type_slot_tmplt_id_seq;
CREATE SEQUENCE volume_group_volume_group_id_seq;
CREATE SEQUENCE logical_volume_logical_volume_id_seq;
CREATE SEQUENCE slot_type_slot_type_id_seq;


--------------------------------------------------------------------
-- DEALING WITH TABLE val_property_type [689365]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property_type', 'val_property_type');

-- FOREIGN KEYS FROM
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_valprop_proptyp;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_property_type DROP CONSTRAINT IF EXISTS fk_prop_typ_pv_uctyp_rst;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_property_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_property_type DROP CONSTRAINT IF EXISTS pk_val_property_type;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1val_property_type";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_property_type DROP CONSTRAINT IF EXISTS ckc_val_prop_typ_ismulti;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_property_type ON jazzhands.val_property_type;
DROP TRIGGER IF EXISTS trigger_audit_val_property_type ON jazzhands.val_property_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_property_type');
---- BEGIN audit.val_property_type TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_property_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_property_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_property_type');
---- DONE audit.val_property_type TEARDOWN


ALTER TABLE val_property_type RENAME TO val_property_type_v59;
ALTER TABLE audit.val_property_type RENAME TO val_property_type_v59;

CREATE TABLE val_property_type
(
	property_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	prop_val_acct_coll_type_rstrct	varchar(50)  NULL,
	is_multivalue	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_property_type', false);
ALTER TABLE val_property_type
	ALTER is_multivalue
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_property_type (
	property_type,
	description,
	prop_val_acct_coll_type_rstrct,
	is_multivalue,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_type,
	description,
	prop_val_acct_coll_type_rstrct,
	is_multivalue,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_type_v59;

INSERT INTO audit.val_property_type (
	property_type,
	description,
	prop_val_acct_coll_type_rstrct,
	is_multivalue,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	property_type,
	description,
	prop_val_acct_coll_type_rstrct,
	is_multivalue,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_property_type_v59;

ALTER TABLE val_property_type
	ALTER is_multivalue
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_property_type ADD CONSTRAINT pk_val_property_type PRIMARY KEY (property_type);

-- Table/Column Comments
COMMENT ON TABLE val_property_type IS 'validation table for property types';
COMMENT ON COLUMN val_property_type.is_multivalue IS 'If N, this acts like an alternate key on lhs,property_type';
-- INDEXES
CREATE INDEX xif1val_property_type ON val_property_type USING btree (prop_val_acct_coll_type_rstrct);

-- CHECK CONSTRAINTS
ALTER TABLE val_property_type ADD CONSTRAINT ckc_val_prop_typ_ismulti
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_property_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);

-- FOREIGN KEYS TO
-- consider FK val_property_type and val_account_collection_type
ALTER TABLE val_property_type
	ADD CONSTRAINT fk_prop_typ_pv_uctyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property_type');
DROP TABLE IF EXISTS val_property_type_v59;
DROP TABLE IF EXISTS audit.val_property_type_v59;
-- DONE DEALING WITH TABLE val_property_type [681049]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE company [687476]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'company', 'company');

-- FOREIGN KEYS FROM
ALTER TABLE site DROP CONSTRAINT IF EXISTS fk_site_colo_company_id;
ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_aloc_companyid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_compid;
ALTER TABLE account_realm_company DROP CONSTRAINT IF EXISTS fk_acct_rlm_cmpy_cmpy_id;
ALTER TABLE company_type DROP CONSTRAINT IF EXISTS fk_company_type_company_id;
ALTER TABLE operating_system DROP CONSTRAINT IF EXISTS fk_os_company;
ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_zloc_company_id;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_pval_compid;
ALTER TABLE department DROP CONSTRAINT IF EXISTS fk_dept_company;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_company__id;
ALTER TABLE contract DROP CONSTRAINT IF EXISTS fk_contract_company_id;
ALTER TABLE person_contact DROP CONSTRAINT IF EXISTS fk_prsn_contect_cr_cmpyid;
ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_vend_companyid;
ALTER TABLE person_company DROP CONSTRAINT IF EXISTS fk_person_company_company_id;
ALTER TABLE netblock DROP CONSTRAINT IF EXISTS fk_netblock_company;
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS fk_devtyp_company;
ALTER TABLE physical_address DROP CONSTRAINT IF EXISTS fk_physaddr_company_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.company DROP CONSTRAINT IF EXISTS fk_company_parent_company_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'company');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.company DROP CONSTRAINT IF EXISTS pk_company;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_company_companycode";
DROP INDEX IF EXISTS "jazzhands"."xif1company";
DROP INDEX IF EXISTS "jazzhands"."idx_company_iscorpfamily";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.company DROP CONSTRAINT IF EXISTS ckc_cmpy_shrt_name_195335815;
ALTER TABLE jazzhands.company DROP CONSTRAINT IF EXISTS ckc_is_corporate_fami_company;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_company ON jazzhands.company;
DROP TRIGGER IF EXISTS trig_userlog_company ON jazzhands.company;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'company');
---- BEGIN audit.company TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'company');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."company_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'company');
---- DONE audit.company TEARDOWN


ALTER TABLE company RENAME TO company_v59;
ALTER TABLE audit.company RENAME TO company_v59;

CREATE TABLE company
(
	company_id	integer NOT NULL,
	company_name	varchar(255) NOT NULL,
	company_short_name	varchar(50)  NULL,
	is_corporate_family	character(1) NOT NULL,
	parent_company_id	integer  NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'company', false);
ALTER TABLE company
	ALTER company_id
	SET DEFAULT nextval('company_company_id_seq'::regclass);
ALTER TABLE company
	ALTER is_corporate_family
	SET DEFAULT 'N'::bpchar;
INSERT INTO company (
	company_id,
	company_name,
	company_short_name,
	is_corporate_family,
	parent_company_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	company_id,
	company_name,
	company_short_name,
	is_corporate_family,
	parent_company_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM company_v59;

INSERT INTO audit.company (
	company_id,
	company_name,
	company_short_name,
	is_corporate_family,
	parent_company_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	company_id,
	company_name,
	company_short_name,
	is_corporate_family,
	parent_company_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.company_v59;

ALTER TABLE company
	ALTER company_id
	SET DEFAULT nextval('company_company_id_seq'::regclass);
ALTER TABLE company
	ALTER is_corporate_family
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE company ADD CONSTRAINT pk_company PRIMARY KEY (company_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1company ON company USING btree (parent_company_id);
CREATE INDEX idx_company_iscorpfamily ON company USING btree (is_corporate_family);

-- CHECK CONSTRAINTS
ALTER TABLE company ADD CONSTRAINT ckc_cmpy_shrt_name_195335815
	CHECK (((company_short_name)::text = lower((company_short_name)::text)) AND ((company_short_name)::text !~~ '% %'::text));
ALTER TABLE company ADD CONSTRAINT ckc_is_corporate_fami_company
	CHECK ((is_corporate_family = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_corporate_family)::text = upper((is_corporate_family)::text)));

-- FOREIGN KEYS FROM
-- consider FK company and circuit
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_vend_companyid
	FOREIGN KEY (vendor_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and person_company
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and netblock
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_company
	FOREIGN KEY (nic_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and device_type
ALTER TABLE device_type
	ADD CONSTRAINT fk_devtyp_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and physical_address
ALTER TABLE physical_address
	ADD CONSTRAINT fk_physaddr_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and department
ALTER TABLE department
	ADD CONSTRAINT fk_dept_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_company__id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and person_contact
ALTER TABLE person_contact
	ADD CONSTRAINT fk_prsn_contect_cr_cmpyid
	FOREIGN KEY (person_contact_cr_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and contract
ALTER TABLE contract
	ADD CONSTRAINT fk_contract_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and component_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_type
--	ADD CONSTRAINT fk_component_type_company_id
--	FOREIGN KEY (company_id) REFERENCES company(company_id);

-- consider FK company and operating_system
ALTER TABLE operating_system
	ADD CONSTRAINT fk_os_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and circuit
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_zloc_company_id
	FOREIGN KEY (zloc_lec_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and site
ALTER TABLE site
	ADD CONSTRAINT fk_site_colo_company_id
	FOREIGN KEY (colo_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and account_realm_company
ALTER TABLE account_realm_company
	ADD CONSTRAINT fk_acct_rlm_cmpy_cmpy_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and circuit
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_aloc_companyid
	FOREIGN KEY (aloc_lec_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and company_type
ALTER TABLE company_type
	ADD CONSTRAINT fk_company_type_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;

-- FOREIGN KEYS TO
-- consider FK company and company
ALTER TABLE company
	ADD CONSTRAINT fk_company_parent_company_id
	FOREIGN KEY (parent_company_id) REFERENCES company(company_id) DEFERRABLE;

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'company');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'company');
ALTER SEQUENCE company_company_id_seq
	 OWNED BY company.company_id;
DROP TABLE IF EXISTS company_v59;
DROP TABLE IF EXISTS audit.company_v59;
-- DONE DEALING WITH TABLE company [678854]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE site [688563]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'site', 'site');

-- FOREIGN KEYS FROM
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_site_code;
ALTER TABLE rack DROP CONSTRAINT IF EXISTS fk_site_rack;
ALTER TABLE person_location DROP CONSTRAINT IF EXISTS fk_persloc_site_code;
ALTER TABLE encapsulation_range DROP CONSTRAINT IF EXISTS fk_encap_range_sitecode;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_site_code;
ALTER TABLE site_netblock DROP CONSTRAINT IF EXISTS fk_site_netblock_ref_site;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.site DROP CONSTRAINT IF EXISTS fk_site_colo_company_id;
ALTER TABLE jazzhands.site DROP CONSTRAINT IF EXISTS fk_site_physaddr_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'site');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.site DROP CONSTRAINT IF EXISTS pk_site_code;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifsite_physaddr_id";
DROP INDEX IF EXISTS "jazzhands"."fk_site_colo_company_id";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.site DROP CONSTRAINT IF EXISTS ckc_site_status_site;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_site ON jazzhands.site;
DROP TRIGGER IF EXISTS trigger_audit_site ON jazzhands.site;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'site');
---- BEGIN audit.site TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'site');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."site_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'site');
---- DONE audit.site TEARDOWN


ALTER TABLE site RENAME TO site_v59;
ALTER TABLE audit.site RENAME TO site_v59;

CREATE TABLE site
(
	site_code	varchar(50) NOT NULL,
	colo_company_id	integer  NULL,
	physical_address_id	integer  NULL,
	site_status	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'site', false);
INSERT INTO site (
	site_code,
	colo_company_id,
	physical_address_id,
	site_status,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	site_code,
	colo_company_id,
	physical_address_id,
	site_status,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM site_v59;

INSERT INTO audit.site (
	site_code,
	colo_company_id,
	physical_address_id,
	site_status,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	site_code,
	colo_company_id,
	physical_address_id,
	site_status,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.site_v59;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE site ADD CONSTRAINT pk_site_code PRIMARY KEY (site_code);

-- Table/Column Comments
-- INDEXES
CREATE INDEX fk_site_colo_company_id ON site USING btree (colo_company_id);
CREATE INDEX xifsite_physaddr_id ON site USING btree (physical_address_id);

-- CHECK CONSTRAINTS
ALTER TABLE site ADD CONSTRAINT ckc_site_status_site
	CHECK (((site_status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'INACTIVE'::character varying, 'OBSOLETE'::character varying, 'PLANNED'::character varying])::text[])) AND ((site_status)::text = upper((site_status)::text)));

-- FOREIGN KEYS FROM
-- consider FK site and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK site and site_netblock
ALTER TABLE site_netblock
	ADD CONSTRAINT fk_site_netblock_ref_site
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK site and rack
ALTER TABLE rack
	ADD CONSTRAINT fk_site_rack
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK site and person_location
ALTER TABLE person_location
	ADD CONSTRAINT fk_persloc_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK site and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK site and encapsulation_range
ALTER TABLE encapsulation_range
	ADD CONSTRAINT fk_encap_range_sitecode
	FOREIGN KEY (site_code) REFERENCES site(site_code);

-- FOREIGN KEYS TO
-- consider FK site and physical_address
ALTER TABLE site
	ADD CONSTRAINT fk_site_physaddr_id
	FOREIGN KEY (physical_address_id) REFERENCES physical_address(physical_address_id);
-- consider FK site and company
ALTER TABLE site
	ADD CONSTRAINT fk_site_colo_company_id
	FOREIGN KEY (colo_company_id) REFERENCES company(company_id) DEFERRABLE;

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'site');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'site');
DROP TABLE IF EXISTS site_v59;
DROP TABLE IF EXISTS audit.site_v59;
-- DONE DEALING WITH TABLE site [680101]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.calculate_intermediate_netblocks -> calculate_intermediate_netblocks 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_utils', 'calculate_intermediate_netblocks', 'calculate_intermediate_netblocks');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 694534
DROP FUNCTION IF EXISTS netblock_utils.calculate_intermediate_netblocks(ip_block_1 inet, ip_block_2 inet);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 686968
CREATE OR REPLACE FUNCTION netblock_utils.calculate_intermediate_netblocks(ip_block_1 inet DEFAULT NULL::inet, ip_block_2 inet DEFAULT NULL::inet, netblock_type text DEFAULT 'default'::text, ip_universe_id integer DEFAULT 0)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
AS $function$
DECLARE
	current_nb		inet;
	new_nb			inet;
	min_addr		inet;
	max_addr		inet;
BEGIN
	IF ip_block_1 IS NULL OR ip_block_2 IS NULL THEN
		RAISE EXCEPTION 'Must specify both ip_block_1 and ip_block_2';
	END IF;

	IF family(ip_block_1) != family(ip_block_2) THEN
		RAISE EXCEPTION 'families of ip_block_1 and ip_block_2 must match';
	END IF;

	-- Make sure these are network blocks
	ip_block_1 := network(ip_block_1);
	ip_block_2 := network(ip_block_2);

	-- If the blocks are subsets of each other, then error

	IF ip_block_1 <<= ip_block_2 OR ip_block_2 <<= ip_block_1 THEN
		RAISE EXCEPTION 'netblocks intersect each other';
	END IF;

	-- Order the blocks correctly

	IF ip_block_1 > ip_block_2 THEN
		new_nb := ip_block_1;
		ip_block_1 := ip_block_2;
		ip_block_2 := new_nb;
	END IF;

	current_nb := ip_block_1;
	max_addr := broadcast(ip_block_1);

	-- Loop through bumping the netmask up and seeing if the destination block is in the new block
	LOOP
		new_nb := network(set_masklen(current_nb, masklen(current_nb) - 1));

		-- If the block is in our new larger netblock, then exit this loop
		IF (new_nb >>= ip_block_2) THEN
			current_nb := broadcast(current_nb) + 1;
			EXIT;
		END IF;

		-- If the max address of the new netblock is larger than the last one, then it's empty
		IF set_masklen(broadcast(new_nb), 32) > set_masklen(max_addr, 32) THEN
			ip_addr := set_masklen(max_addr + 1, masklen(current_nb));
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			max_addr := broadcast(new_nb);
		END IF;
		current_nb := new_nb;
	END LOOP;

	-- Now loop through there to find the unused blocks at the front

	LOOP
		IF host(current_nb) = host(ip_block_2) THEN
			RETURN;
		END IF;
		current_nb := set_masklen(current_nb, masklen(current_nb) + 1);
		IF NOT (current_nb >>= ip_block_2) THEN
			ip_addr := current_nb;
			-- Validate that this isn't an empty can_subnet='Y' block already
			-- If it is, split it in half and return both halves
			PERFORM * FROM netblock n WHERE
				n.ip_address = ip_addr AND
				n.ip_universe_id =
					calculate_intermediate_netblocks.ip_universe_id AND
				n.netblock_type =
					calculate_intermediate_netblocks.netblock_type;
			IF FOUND THEN
				ip_addr := set_masklen(ip_addr, masklen(ip_addr) + 1);
				RAISE NOTICE 'IP is %', ip_addr;
				RETURN NEXT;
				ip_addr := broadcast(ip_addr) + 1;
				RETURN NEXT;
			ELSE
				RETURN NEXT;
			END IF;
			current_nb := broadcast(current_nb) + 1;
			CONTINUE;
		END IF;
	END LOOP;
	RETURN;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc netblock_utils.calculate_intermediate_netblocks -> calculate_intermediate_netblocks 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_manip.allocate_netblock -> allocate_netblock 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock', 'allocate_netblock');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 694539
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying);
-- consider old oid 694540
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 686973
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS netblock
 LANGUAGE plpgsql
AS $function$
DECLARE
	netblock_rec	RECORD;
BEGIN
	SELECT * into netblock_rec FROM netblock_manip.allocate_netblock(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		address_type := address_type,
		can_subnet := can_subnet,
		description := description,
		allocation_method := allocation_method,
		ip_address := ip_address,
		rnd_masklen_threshold := rnd_masklen_threshold,
		rnd_max_count := rnd_max_count,
		netblock_status := netblock_status
	);
	RETURN netblock_rec;
END;
$function$
;
-- consider NEW oid 686974
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS netblock
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		RECORD;
	loopback_bits	integer;
	inet_family		integer;
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

	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	FOR parent_rec IN SELECT * FROM jazzhands.netblock WHERE netblock_id = 
			ANY(allocate_netblock.parent_netblock_list) FOR UPDATE LOOP

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

		RETURN netblock_rec;
	END IF;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc netblock_manip.allocate_netblock -> allocate_netblock 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc delete_peraccount_account_collection -> delete_peraccount_account_collection 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 687000
CREATE OR REPLACE FUNCTION jazzhands.delete_peraccount_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	acid			account_collection.account_collection_id%TYPE;
BEGIN
	IF TG_OP = 'DELETE' THEN
		SELECT	account_collection_id
		  INTO	acid
		  FROM	account_collection ac
				INNER JOIN account_collection_account aca
					USING (account_collection_id)
		 WHERE	aca.account_id = OLD.account_Id
		   AND	ac.account_collection_type = 'per-account';

		 DELETE from account_collection_account
		  where account_collection_id = acid;

		 DELETE from account_collection
		  where account_collection_id = acid;
	END IF;
	RETURN OLD;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc delete_peraccount_account_collection -> delete_peraccount_account_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_peraccount_account_collection -> update_peraccount_account_collection 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 687002
CREATE OR REPLACE FUNCTION jazzhands.update_peraccount_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	def_acct_rlm	account_realm.account_realm_id%TYPE;
	acid			account_collection.account_collection_id%TYPE;
DECLARE
	newname	TEXT;
BEGIN
	newname = concat(NEW.login, '_', NEW.account_id);
	if TG_OP = 'INSERT' THEN
		insert into account_collection 
			(account_collection_name, account_collection_type)
		values
			(newname, 'per-account')
		RETURNING account_collection_id INTO acid;
		insert into account_collection_account 
			(account_collection_id, account_id)
		VALUES
			(acid, NEW.account_id);
	END IF;

	IF TG_OP = 'UPDATE' AND OLD.login != NEW.login THEN
		UPDATE	account_collection
		    set	account_collection_name = newname
		  where	account_collection_type = 'per-account'
		    and	account_collection_id = (
				SELECT	account_collection_id
		  		FROM	account_collection ac
						INNER JOIN account_collection_account aca
							USING (account_collection_id)
		 		WHERE	aca.account_id = OLD.account_Id
		   		AND	ac.account_collection_type = 'per-account'
			);
	END IF;
	return NEW;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc update_peraccount_account_collection -> update_peraccount_account_collection 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE asset [687403]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'asset', 'asset');

-- FOREIGN KEYS FROM
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_asset_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.asset DROP CONSTRAINT IF EXISTS fk_asset_ownshp_stat;
ALTER TABLE jazzhands.asset DROP CONSTRAINT IF EXISTS fk_asset_contract_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'asset');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.asset DROP CONSTRAINT IF EXISTS pk_asset;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_asset_ownshp_stat";
DROP INDEX IF EXISTS "jazzhands"."xif_asset_contract_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_asset ON jazzhands.asset;
DROP TRIGGER IF EXISTS trigger_audit_asset ON jazzhands.asset;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'asset');
---- BEGIN audit.asset TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'asset');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."asset_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'asset');
---- DONE audit.asset TEARDOWN


ALTER TABLE asset RENAME TO asset_v59;
ALTER TABLE audit.asset RENAME TO asset_v59;

CREATE TABLE asset
(
	asset_id	integer NOT NULL,
	component_id	integer  NULL,
	description	varchar(255)  NULL,
	contract_id	integer  NULL,
	serial_number	varchar(255)  NULL,
	part_number	varchar(255)  NULL,
	asset_tag	varchar(255)  NULL,
	ownership_status	varchar(50) NOT NULL,
	lease_expiration_date	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'asset', false);
ALTER TABLE asset
	ALTER asset_id
	SET DEFAULT nextval('asset_asset_id_seq'::regclass);
INSERT INTO asset (
	asset_id,
	component_id,		-- new column (component_id)
	description,
	contract_id,
	serial_number,
	part_number,
	asset_tag,
	ownership_status,
	lease_expiration_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	asset_id,
	NULL,		-- new column (component_id)
	description,
	contract_id,
	serial_number,
	part_number,
	asset_tag,
	ownership_status,
	lease_expiration_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM asset_v59;

INSERT INTO audit.asset (
	asset_id,
	component_id,		-- new column (component_id)
	description,
	contract_id,
	serial_number,
	part_number,
	asset_tag,
	ownership_status,
	lease_expiration_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	asset_id,
	NULL,		-- new column (component_id)
	description,
	contract_id,
	serial_number,
	part_number,
	asset_tag,
	ownership_status,
	lease_expiration_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.asset_v59;

ALTER TABLE asset
	ALTER asset_id
	SET DEFAULT nextval('asset_asset_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE asset ADD CONSTRAINT pk_asset PRIMARY KEY (asset_id);
ALTER TABLE asset ADD CONSTRAINT ak_asset_component_id UNIQUE (component_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_asset_contract_id ON asset USING btree (contract_id);
CREATE INDEX xif_asset_ownshp_stat ON asset USING btree (ownership_status);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK asset and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_asset_id
	FOREIGN KEY (asset_id) REFERENCES asset(asset_id);

-- FOREIGN KEYS TO
-- consider FK asset and val_ownership_status
ALTER TABLE asset
	ADD CONSTRAINT fk_asset_ownshp_stat
	FOREIGN KEY (ownership_status) REFERENCES val_ownership_status(ownership_status);
-- consider FK asset and component
-- Skipping this FK since table does not exist yet
--ALTER TABLE asset
--	ADD CONSTRAINT fk_asset_comp_id
--	FOREIGN KEY (component_id) REFERENCES component(component_id);

-- consider FK asset and contract
ALTER TABLE asset
	ADD CONSTRAINT fk_asset_contract_id
	FOREIGN KEY (contract_id) REFERENCES contract(contract_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'asset');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'asset');
ALTER SEQUENCE asset_asset_id_seq
	 OWNED BY asset.asset_id;
DROP TABLE IF EXISTS asset_v59;
DROP TABLE IF EXISTS audit.asset_v59;
-- DONE DEALING WITH TABLE asset [678779]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device_type [687714]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type', 'device_type');

-- FOREIGN KEYS FROM
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_devtp_id;
ALTER TABLE device_type_phys_port_templt DROP CONSTRAINT IF EXISTS fk_devtype_ref_devtphysprttmpl;
ALTER TABLE device_type_module DROP CONSTRAINT IF EXISTS fk_devt_mod_dev_type_id;
ALTER TABLE device_type_module_device_type DROP CONSTRAINT IF EXISTS fk_dt_mod_dev_type_mod_dtid;
ALTER TABLE device_type_power_port_templt DROP CONSTRAINT IF EXISTS fk_dev_type_dev_pwr_prt_tmpl;
ALTER TABLE chassis_location DROP CONSTRAINT IF EXISTS fk_chass_loc_mod_dev_typ_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS fk_devtyp_company;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS fk_device_t_fk_device_val_proc;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'device_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS pk_device_type;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif4device_type";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_has_802_3_interfa_device_t;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_snmp_capable_device_t;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_has_802_11_interf_device_t;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_devtyp_ischs;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_device_type_chassis_check ON jazzhands.device_type;
DROP TRIGGER IF EXISTS trigger_audit_device_type ON jazzhands.device_type;
DROP TRIGGER IF EXISTS trig_userlog_device_type ON jazzhands.device_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'device_type');
---- BEGIN audit.device_type TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'device_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."device_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'device_type');
---- DONE audit.device_type TEARDOWN


ALTER TABLE device_type RENAME TO device_type_v59;
ALTER TABLE audit.device_type RENAME TO device_type_v59;

CREATE TABLE device_type
(
	device_type_id	integer NOT NULL,
	component_type_id	integer  NULL,
	company_id	integer  NULL,
	model	varchar(255) NOT NULL,
	device_type_depth_in_cm	character(18)  NULL,
	processor_architecture	varchar(50)  NULL,
	config_fetch_type	varchar(50)  NULL,
	rack_units	integer NOT NULL,
	description	varchar(4000)  NULL,
	has_802_3_interface	character(1) NOT NULL,
	has_802_11_interface	character(1) NOT NULL,
	snmp_capable	character(1) NOT NULL,
	is_chassis	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_type', false);
ALTER TABLE device_type
	ALTER device_type_id
	SET DEFAULT nextval('device_type_device_type_id_seq'::regclass);
ALTER TABLE device_type
	ALTER is_chassis
	SET DEFAULT 'N'::bpchar;
INSERT INTO device_type (
	device_type_id,
	component_type_id,		-- new column (component_type_id)
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
	description,
	has_802_3_interface,
	has_802_11_interface,
	snmp_capable,
	is_chassis,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_type_id,
	NULL,		-- new column (component_type_id)
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
	description,
	has_802_3_interface,
	has_802_11_interface,
	snmp_capable,
	is_chassis,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_type_v59;

INSERT INTO audit.device_type (
	device_type_id,
	component_type_id,		-- new column (component_type_id)
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
	description,
	has_802_3_interface,
	has_802_11_interface,
	snmp_capable,
	is_chassis,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	device_type_id,
	NULL,		-- new column (component_type_id)
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
	description,
	has_802_3_interface,
	has_802_11_interface,
	snmp_capable,
	is_chassis,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_type_v59;

ALTER TABLE device_type
	ALTER device_type_id
	SET DEFAULT nextval('device_type_device_type_id_seq'::regclass);
ALTER TABLE device_type
	ALTER is_chassis
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_type ADD CONSTRAINT pk_device_type PRIMARY KEY (device_type_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_fevtyp_component_id ON device_type USING btree (component_type_id);
CREATE INDEX xif4device_type ON device_type USING btree (company_id);

-- CHECK CONSTRAINTS
ALTER TABLE device_type ADD CONSTRAINT ckc_has_802_3_interfa_device_t
	CHECK (has_802_3_interface = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE device_type ADD CONSTRAINT ckc_devtyp_ischs
	CHECK (is_chassis = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE device_type ADD CONSTRAINT ckc_has_802_11_interf_device_t
	CHECK (has_802_11_interface = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE device_type ADD CONSTRAINT ckc_snmp_capable_device_t
	CHECK (snmp_capable = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK device_type and device_type_module
ALTER TABLE device_type_module
	ADD CONSTRAINT fk_devt_mod_dev_type_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK device_type and device_type_phys_port_templt
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_devtype_ref_devtphysprttmpl
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK device_type and device
ALTER TABLE device
	ADD CONSTRAINT fk_dev_devtp_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK device_type and chassis_location
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chass_loc_mod_dev_typ_id
	FOREIGN KEY (module_device_type_id) REFERENCES device_type(device_type_id);
-- consider FK device_type and device_type_power_port_templt
ALTER TABLE device_type_power_port_templt
	ADD CONSTRAINT fk_dev_type_dev_pwr_prt_tmpl
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK device_type and device_type_module_device_type
ALTER TABLE device_type_module_device_type
	ADD CONSTRAINT fk_dt_mod_dev_type_mod_dtid
	FOREIGN KEY (module_device_type_id) REFERENCES device_type(device_type_id);

-- FOREIGN KEYS TO
-- consider FK device_type and company
ALTER TABLE device_type
	ADD CONSTRAINT fk_devtyp_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK device_type and val_processor_architecture
ALTER TABLE device_type
	ADD CONSTRAINT fk_device_t_fk_device_val_proc
	FOREIGN KEY (processor_architecture) REFERENCES val_processor_architecture(processor_architecture);
-- consider FK device_type and component_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE device_type
--	ADD CONSTRAINT fk_fevtyp_component_id
--	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);


-- TRIGGERS
CREATE TRIGGER trigger_device_type_chassis_check BEFORE UPDATE OF is_chassis ON device_type FOR EACH ROW EXECUTE PROCEDURE device_type_chassis_check();

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_type');
ALTER SEQUENCE device_type_device_type_id_seq
	 OWNED BY device_type.device_type_id;
DROP TABLE IF EXISTS device_type_v59;
DROP TABLE IF EXISTS audit.device_type_v59;
-- DONE DEALING WITH TABLE device_type [679173]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device [687535]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device', 'device');

-- FOREIGN KEYS FROM
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dvc_mgmt_ctrl_mgr_dev_id;
ALTER TABLE device_layer2_network DROP CONSTRAINT IF EXISTS fk_device_l2_net_devid;
ALTER TABLE device_power_interface DROP CONSTRAINT IF EXISTS fk_device_device_power_supp;
ALTER TABLE chassis_location DROP CONSTRAINT IF EXISTS fk_chass_loc_chass_devid;
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_dev_id;
ALTER TABLE mlag_peering DROP CONSTRAINT IF EXISTS fk_mlag_peering_devid2;
ALTER TABLE device_ticket DROP CONSTRAINT IF EXISTS fk_dev_tkt_dev_id;
ALTER TABLE device_note DROP CONSTRAINT IF EXISTS fk_device_note_device;
ALTER TABLE device_collection_device DROP CONSTRAINT IF EXISTS fk_devcolldev_dev_id;
ALTER TABLE static_route DROP CONSTRAINT IF EXISTS fk_statrt_devsrc_id;
ALTER TABLE mlag_peering DROP CONSTRAINT IF EXISTS fk_mlag_peering_devid1;
ALTER TABLE device_encapsulation_domain DROP CONSTRAINT IF EXISTS fk_dev_encap_domain_devid;
ALTER TABLE layer1_connection DROP CONSTRAINT IF EXISTS fk_l1conn_ref_device;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_device_id;
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dev_mgmt_ctlr_dev_id;
ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purpose_device_id;
ALTER TABLE device_ssh_key DROP CONSTRAINT IF EXISTS fk_dev_ssh_key_ssh_key_id;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_netint_device_id;
ALTER TABLE snmp_commstr DROP CONSTRAINT IF EXISTS fk_snmpstr_device_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_company__id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_ref_parent_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_chasloc_chass_devid;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_os_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_ref_voesymbtrk;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_asset_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_fk_voe;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_rack_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_devtp_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_chass_loc_id_mod_enfc;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_reference_val_devi;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_site_code;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_dnsrecord;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_fk_dev_val_stat;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_fk_dev_v_svcenv;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'device');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS pk_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ak_device_chassis_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ak_device_rack_location_id;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif17device";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_islclymgd";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_osid";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_iddnsrec";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_voeid";
DROP INDEX IF EXISTS "jazzhands"."xifdevice_sitecode";
DROP INDEX IF EXISTS "jazzhands"."xif18device";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_ismonitored";
DROP INDEX IF EXISTS "jazzhands"."idx_device_type_location";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_svcenv";
DROP INDEX IF EXISTS "jazzhands"."xif16device";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_dev_status";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069059;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_should_fetch_conf_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_locally_manage_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069057;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_virtual_device_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_monitored_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS dev_osid_notnull;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069060;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069051;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069052;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_device ON jazzhands.device;
DROP TRIGGER IF EXISTS trig_userlog_device ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_verify_device_voe ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_device_one_location_validate ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON jazzhands.device;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'device');
---- BEGIN audit.device TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'device');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."device_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'device');
---- DONE audit.device TEARDOWN


ALTER TABLE device RENAME TO device_v59;
ALTER TABLE audit.device RENAME TO device_v59;

CREATE TABLE device
(
	device_id	integer NOT NULL,
	component_id	integer  NULL,
	device_type_id	integer NOT NULL,
	company_id	integer  NULL,
	asset_id	integer  NULL,
	device_name	varchar(255)  NULL,
	site_code	varchar(50)  NULL,
	identifying_dns_record_id	integer  NULL,
	host_id	varchar(255)  NULL,
	physical_label	varchar(255)  NULL,
	rack_location_id	integer  NULL,
	chassis_location_id	integer  NULL,
	parent_device_id	integer  NULL,
	description	varchar(255)  NULL,
	device_status	varchar(50) NOT NULL,
	operating_system_id	integer NOT NULL,
	service_environment_id	integer NOT NULL,
	voe_id	integer  NULL,
	auto_mgmt_protocol	varchar(50)  NULL,
	voe_symbolic_track_id	integer  NULL,
	is_locally_managed	character(1) NOT NULL,
	is_monitored	character(1) NOT NULL,
	is_virtual_device	character(1) NOT NULL,
	should_fetch_config	character(1) NOT NULL,
	date_in_service	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device', false);
ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
ALTER TABLE device
	ALTER operating_system_id
	SET DEFAULT 0;
ALTER TABLE device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;
INSERT INTO device (
	device_id,
	component_id,		-- new column (component_id)
	device_type_id,
	company_id,
	asset_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	operating_system_id,
	service_environment_id,
	voe_id,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_id,
	NULL,		-- new column (component_id)
	device_type_id,
	company_id,
	asset_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	operating_system_id,
	service_environment_id,
	voe_id,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_v59;

INSERT INTO audit.device (
	device_id,
	component_id,		-- new column (component_id)
	device_type_id,
	company_id,
	asset_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	operating_system_id,
	service_environment_id,
	voe_id,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	device_id,
	NULL,		-- new column (component_id)
	device_type_id,
	company_id,
	asset_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	operating_system_id,
	service_environment_id,
	voe_id,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_v59;

ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
ALTER TABLE device
	ALTER operating_system_id
	SET DEFAULT 0;
ALTER TABLE device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device ADD CONSTRAINT pk_device PRIMARY KEY (device_id);
ALTER TABLE device ADD CONSTRAINT ak_device_chassis_location_id UNIQUE (chassis_location_id);
-- ALTER TABLE device ADD CONSTRAINT ak_device_rack_location_id UNIQUE (rack_location_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_device_comp_id ON device USING btree (component_id);
CREATE INDEX xif_device_asset_id ON device USING btree (asset_id);
CREATE INDEX xif_device_site_code ON device USING btree (site_code);
CREATE INDEX idx_dev_islclymgd ON device USING btree (is_locally_managed);
CREATE INDEX xif_device_fk_voe ON device USING btree (voe_id);
CREATE INDEX xif_device_company__id ON device USING btree (company_id);
CREATE INDEX xif_device_dev_v_svcenv ON device USING btree (service_environment_id);
CREATE INDEX xif_dev_chass_loc_id_mod_enfc ON device USING btree (chassis_location_id, parent_device_id, device_type_id);
CREATE INDEX xif_device_dev_val_status ON device USING btree (device_status);
CREATE INDEX xif_device_id_dnsrecord ON device USING btree (identifying_dns_record_id);
CREATE INDEX idx_dev_ismonitored ON device USING btree (is_monitored);
CREATE INDEX xif_dev_os_id ON device USING btree (operating_system_id);
CREATE INDEX idx_device_type_location ON device USING btree (device_type_id);

-- CHECK CONSTRAINTS
ALTER TABLE device ADD CONSTRAINT ckc_is_virtual_device_device
	CHECK ((is_virtual_device = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_virtual_device)::text = upper((is_virtual_device)::text)));
ALTER TABLE device ADD CONSTRAINT ckc_should_fetch_conf_device
	CHECK ((should_fetch_config = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_fetch_config)::text = upper((should_fetch_config)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069059
	CHECK (is_virtual_device IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_is_locally_manage_device
	CHECK ((is_locally_managed = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_locally_managed)::text = upper((is_locally_managed)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069057
	CHECK (is_monitored IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069051
	CHECK (device_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069052
	CHECK (device_type_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_is_monitored_device
	CHECK ((is_monitored = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_monitored)::text = upper((is_monitored)::text)));
ALTER TABLE device ADD CONSTRAINT dev_osid_notnull
	CHECK (operating_system_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069060
	CHECK (should_fetch_config IS NOT NULL);

-- FOREIGN KEYS FROM
-- consider FK device and snmp_commstr
ALTER TABLE snmp_commstr
	ADD CONSTRAINT fk_snmpstr_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_ssh_key
ALTER TABLE device_ssh_key
	ADD CONSTRAINT fk_dev_ssh_key_ssh_key_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_management_controller
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dev_mgmt_ctlr_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and network_interface_purpose
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purpose_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and network_service
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and layer1_connection
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_l1conn_ref_device
	FOREIGN KEY (tcpsrv_device_id) REFERENCES device(device_id);
-- consider FK device and device_encapsulation_domain
ALTER TABLE device_encapsulation_domain
	ADD CONSTRAINT fk_dev_encap_domain_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and mlag_peering
ALTER TABLE mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid1
	FOREIGN KEY (device1_id) REFERENCES device(device_id);
-- consider FK device and static_route
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_devsrc_id
	FOREIGN KEY (device_src_id) REFERENCES device(device_id);
-- consider FK device and device_collection_device
ALTER TABLE device_collection_device
	ADD CONSTRAINT fk_devcolldev_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_ticket
ALTER TABLE device_ticket
	ADD CONSTRAINT fk_dev_tkt_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_note
ALTER TABLE device_note
	ADD CONSTRAINT fk_device_note_device
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and mlag_peering
ALTER TABLE mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid2
	FOREIGN KEY (device2_id) REFERENCES device(device_id);
-- consider FK device and physical_port
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and chassis_location
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chass_loc_chass_devid
	FOREIGN KEY (chassis_device_id) REFERENCES device(device_id) DEFERRABLE;
-- consider FK device and device_power_interface
ALTER TABLE device_power_interface
	ADD CONSTRAINT fk_device_device_power_supp
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_layer2_network
ALTER TABLE device_layer2_network
	ADD CONSTRAINT fk_device_l2_net_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK device and device_management_controller
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dvc_mgmt_ctrl_mgr_dev_id
	FOREIGN KEY (manager_device_id) REFERENCES device(device_id);

-- FOREIGN KEYS TO
-- consider FK device and service_environment
ALTER TABLE device
	ADD CONSTRAINT fk_device_dev_v_svcenv
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);
-- consider FK device and val_device_status
ALTER TABLE device
	ADD CONSTRAINT fk_device_dev_val_status
	FOREIGN KEY (device_status) REFERENCES val_device_status(device_status);
-- consider FK device and chassis_location
ALTER TABLE device
	ADD CONSTRAINT fk_dev_chass_loc_id_mod_enfc
	FOREIGN KEY (chassis_location_id, parent_device_id, device_type_id) REFERENCES chassis_location(chassis_location_id, chassis_device_id, module_device_type_id) DEFERRABLE;
-- consider FK device and asset
ALTER TABLE device
	ADD CONSTRAINT fk_device_asset_id
	FOREIGN KEY (asset_id) REFERENCES asset(asset_id);
-- consider FK device and device_type
ALTER TABLE device
	ADD CONSTRAINT fk_dev_devtp_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK device and val_device_auto_mgmt_protocol
ALTER TABLE device
	ADD CONSTRAINT fk_dev_ref_mgmt_proto
	FOREIGN KEY (auto_mgmt_protocol) REFERENCES val_device_auto_mgmt_protocol(auto_mgmt_protocol);
-- consider FK device and operating_system
ALTER TABLE device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK device and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_parent_device
	FOREIGN KEY (parent_device_id) REFERENCES device(device_id);
-- consider FK device and chassis_location
ALTER TABLE device
	ADD CONSTRAINT fk_chasloc_chass_devid
	FOREIGN KEY (chassis_location_id) REFERENCES chassis_location(chassis_location_id) DEFERRABLE;
-- consider FK device and site
ALTER TABLE device
	ADD CONSTRAINT fk_device_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK device and voe
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);
-- consider FK device and rack_location
ALTER TABLE device
	ADD CONSTRAINT fk_dev_rack_location_id
	FOREIGN KEY (rack_location_id) REFERENCES rack_location(rack_location_id);
-- consider FK device and voe_symbolic_track
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_voesymbtrk
	FOREIGN KEY (voe_symbolic_track_id) REFERENCES voe_symbolic_track(voe_symbolic_track_id);
-- consider FK device and company
ALTER TABLE device
	ADD CONSTRAINT fk_device_company__id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK device and dns_record
ALTER TABLE device
	ADD CONSTRAINT fk_device_id_dnsrecord
	FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id);
-- consider FK device and component
-- Skipping this FK since table does not exist yet
--ALTER TABLE device
--	ADD CONSTRAINT fk_device_comp_id
--	FOREIGN KEY (component_id) REFERENCES component(component_id);


-- TRIGGERS
CREATE TRIGGER trigger_delete_per_device_device_collection BEFORE DELETE ON device FOR EACH ROW EXECUTE PROCEDURE delete_per_device_device_collection();

CREATE TRIGGER trigger_verify_device_voe BEFORE INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE verify_device_voe();

CREATE TRIGGER trigger_device_one_location_validate BEFORE INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE device_one_location_validate();

CREATE TRIGGER trigger_update_per_device_device_collection AFTER INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE update_per_device_device_collection();

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device');
ALTER SEQUENCE device_device_id_seq
	 OWNED BY device.device_id;
DROP TABLE IF EXISTS device_v59;
DROP TABLE IF EXISTS audit.device_v59;
-- DONE DEALING WITH TABLE device [678993]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_volume_group_relation
CREATE TABLE val_volume_group_relation
(
	volume_group_relation	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_volume_group_relation', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_volume_group_relation ADD CONSTRAINT pk_val_volume_group_relation PRIMARY KEY (volume_group_relation);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_volume_group_relation and volume_group_physicalish_vol
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_vg_physvol_vgrel
--	FOREIGN KEY (volume_group_relation) REFERENCES val_volume_group_relation(volume_group_relation);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_volume_group_relation');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_volume_group_relation');
-- DONE DEALING WITH TABLE val_volume_group_relation [681202]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_logical_volume_property
CREATE TABLE val_logical_volume_property
(
	logical_volume_property_name	varchar(50) NOT NULL,
	filesystem_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_logical_volume_property', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_logical_volume_property ADD CONSTRAINT pk_val_logical_volume_property PRIMARY KEY (logical_volume_property_name, filesystem_type);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_val_lvol_prop_fstype ON val_logical_volume_property USING btree (filesystem_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_logical_volume_property and logical_volume_property
-- Skipping this FK since table does not exist yet
--ALTER TABLE logical_volume_property
--	ADD CONSTRAINT fk_lvol_prop_lvpn_fsty
--	FOREIGN KEY (logical_volume_property_name, filesystem_type) REFERENCES val_logical_volume_property(logical_volume_property_name, filesystem_type);


-- FOREIGN KEYS TO
-- consider FK val_logical_volume_property and val_filesystem_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_logical_volume_property
--	ADD CONSTRAINT fk_val_lvol_prop_fstype
--	FOREIGN KEY (filesystem_type) REFERENCES val_filesystem_type(filesystem_type);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_logical_volume_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_logical_volume_property');
-- DONE DEALING WITH TABLE val_logical_volume_property [680730]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_component_property
CREATE TABLE val_component_property
(
	component_property_name	varchar(50) NOT NULL,
	component_property_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	is_multivalue	character(1) NOT NULL,
	property_data_type	varchar(50) NOT NULL,
	permit_component_type_id	character(10) NOT NULL,
	required_component_type_id	integer  NULL,
	permit_component_function	character(10) NOT NULL,
	required_component_function	varchar(50)  NULL,
	permit_component_id	character(10) NOT NULL,
	permit_slot_type_id	character(10) NOT NULL,
	required_slot_type_id	integer  NULL,
	permit_slot_function	character(10) NOT NULL,
	required_slot_function	varchar(50)  NULL,
	permit_slot_id	character(10) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_component_property', true);
ALTER TABLE val_component_property
	ALTER permit_component_type_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_component_property
	ALTER permit_component_function
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_component_property
	ALTER permit_component_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_component_property
	ALTER permit_slot_type_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_component_property
	ALTER permit_slot_function
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_component_property
	ALTER permit_slot_id
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_component_property ADD CONSTRAINT pk_val_component_property PRIMARY KEY (component_property_name, component_property_type);

-- Table/Column Comments
COMMENT ON TABLE val_component_property IS 'Contains a list of all valid properties for component tables (component, component_type, component_function, slot, slot_type, slot_function)';
-- INDEXES
CREATE INDEX xif_vcomp_prop_rqd_cmpfunc ON val_component_property USING btree (required_component_function);
CREATE INDEX xif_prop_rqd_slt_func ON val_component_property USING btree (required_slot_function);
CREATE INDEX xif_vcomp_prop_comp_prop_type ON val_component_property USING btree (component_property_type);
CREATE INDEX xif_vcomp_prop_rqd_cmptypid ON val_component_property USING btree (required_component_type_id);
CREATE INDEX xif_vcomp_prop_rqd_slttyp_id ON val_component_property USING btree (required_slot_type_id);

-- CHECK CONSTRAINTS
ALTER TABLE val_component_property ADD CONSTRAINT check_prp_prmt_1784750469
	CHECK (permit_slot_function = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_component_property ADD CONSTRAINT check_yes_no_1709686918
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_component_property ADD CONSTRAINT check_prp_prmt_27441051
	CHECK (permit_component_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_component_property ADD CONSTRAINT check_prp_prmt_1618700758
	CHECK (permit_component_function = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_component_property ADD CONSTRAINT check_prp_prmt_1984425150
	CHECK (permit_slot_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_component_property ADD CONSTRAINT check_prp_prmt_1181188899
	CHECK (permit_component_type_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_component_property ADD CONSTRAINT check_prp_prmt_342055273
	CHECK (permit_slot_type_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_component_property and val_component_property_value
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_component_property_value
--	ADD CONSTRAINT fk_comp_prop_val_nametyp
--	FOREIGN KEY (component_property_name, component_property_type) REFERENCES val_component_property(component_property_name, component_property_type);

-- consider FK val_component_property and component_property
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_property
--	ADD CONSTRAINT fk_comp_prop_prop_nmty
--	FOREIGN KEY (component_property_name, component_property_type) REFERENCES val_component_property(component_property_name, component_property_type);


-- FOREIGN KEYS TO
-- consider FK val_component_property and val_slot_function
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_component_property
--	ADD CONSTRAINT fk_vcomp_prop_rqd_slt_func
--	FOREIGN KEY (required_slot_function) REFERENCES val_slot_function(slot_function);

-- consider FK val_component_property and component_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_component_property
--	ADD CONSTRAINT fk_comp_prop_rqd_cmptypid
--	FOREIGN KEY (required_component_type_id) REFERENCES component_type(component_type_id);

-- consider FK val_component_property and val_component_function
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_component_property
--	ADD CONSTRAINT fk_cmop_prop_rqd_cmpfunc
--	FOREIGN KEY (required_component_function) REFERENCES val_component_function(component_function);

-- consider FK val_component_property and val_component_property_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_component_property
--	ADD CONSTRAINT fk_comp_prop_comp_prop_type
--	FOREIGN KEY (component_property_type) REFERENCES val_component_property_type(component_property_type);

-- consider FK val_component_property and slot_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_component_property
--	ADD CONSTRAINT fk_vcomp_prop_rqd_slttyp_id
--	FOREIGN KEY (required_slot_type_id) REFERENCES slot_type(slot_type_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_component_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_component_property');
-- DONE DEALING WITH TABLE val_component_property [680497]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_raid_type
CREATE TABLE val_raid_type
(
	raid_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_raid_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_raid_type ADD CONSTRAINT pk_raid_type PRIMARY KEY (raid_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_raid_type and volume_group
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group
--	ADD CONSTRAINT fk_volgrp_rd_type
--	FOREIGN KEY (raid_type) REFERENCES val_raid_type(raid_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_raid_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_raid_type');
-- DONE DEALING WITH TABLE val_raid_type [681077]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_slot_function
CREATE TABLE val_slot_function
(
	slot_function	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_slot_function', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_slot_function ADD CONSTRAINT pk_val_slot_function PRIMARY KEY (slot_function);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_slot_function and val_component_property
ALTER TABLE val_component_property
	ADD CONSTRAINT fk_vcomp_prop_rqd_slt_func
	FOREIGN KEY (required_slot_function) REFERENCES val_slot_function(slot_function);
-- consider FK val_slot_function and slot_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE slot_type
--	ADD CONSTRAINT fk_slot_type_slt_func
--	FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function);

-- consider FK val_slot_function and val_slot_physical_interface
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_slot_physical_interface
--	ADD CONSTRAINT fk_slot_phys_int_slot_func
--	FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function);

-- consider FK val_slot_function and component_property
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_property
--	ADD CONSTRAINT fk_comp_prop_sltfuncid
--	FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_slot_function');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_slot_function');
-- DONE DEALING WITH TABLE val_slot_function [681095]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_component_function
CREATE TABLE val_component_function
(
	component_function	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_component_function', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_component_function ADD CONSTRAINT pk_val_component_function PRIMARY KEY (component_function);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_component_function and component_property
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_property
--	ADD CONSTRAINT fk_comp_prop_comp_func
--	FOREIGN KEY (component_function) REFERENCES val_component_function(component_function);

-- consider FK val_component_function and component_type_component_func
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_type_component_func
--	ADD CONSTRAINT fk_cmptypcf_comp_func
--	FOREIGN KEY (component_function) REFERENCES val_component_function(component_function);

-- consider FK val_component_function and val_component_property
ALTER TABLE val_component_property
	ADD CONSTRAINT fk_cmop_prop_rqd_cmpfunc
	FOREIGN KEY (required_component_function) REFERENCES val_component_function(component_function);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_component_function');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_component_function');
-- DONE DEALING WITH TABLE val_component_function [680489]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_filesystem_type
CREATE TABLE val_filesystem_type
(
	filesystem_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_filesystem_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_filesystem_type ADD CONSTRAINT pk_val_filesytem_type PRIMARY KEY (filesystem_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_filesystem_type and logical_volume
-- Skipping this FK since table does not exist yet
--ALTER TABLE logical_volume
--	ADD CONSTRAINT fk_logvol_fstype
--	FOREIGN KEY (filesystem_type) REFERENCES val_filesystem_type(filesystem_type);

-- consider FK val_filesystem_type and val_logical_volume_property
ALTER TABLE val_logical_volume_property
	ADD CONSTRAINT fk_val_lvol_prop_fstype
	FOREIGN KEY (filesystem_type) REFERENCES val_filesystem_type(filesystem_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_filesystem_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_filesystem_type');
-- DONE DEALING WITH TABLE val_filesystem_type [680682]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_slot_physical_interface
CREATE TABLE val_slot_physical_interface
(
	slot_physical_interface_type	varchar(50) NOT NULL,
	slot_function	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_slot_physical_interface', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_slot_physical_interface ADD CONSTRAINT pk_val_slot_physical_interface PRIMARY KEY (slot_physical_interface_type, slot_function);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_slot_phys_int_slot_func ON val_slot_physical_interface USING btree (slot_function);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_slot_physical_interface and slot_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE slot_type
--	ADD CONSTRAINT fk_slot_type_physint_func
--	FOREIGN KEY (slot_physical_interface_type, slot_function) REFERENCES val_slot_physical_interface(slot_physical_interface_type, slot_function);


-- FOREIGN KEYS TO
-- consider FK val_slot_physical_interface and val_slot_function
ALTER TABLE val_slot_physical_interface
	ADD CONSTRAINT fk_slot_phys_int_slot_func
	FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_slot_physical_interface');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_slot_physical_interface');
-- DONE DEALING WITH TABLE val_slot_physical_interface [681103]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_component_property_value
CREATE TABLE val_component_property_value
(
	component_property_name	varchar(50) NOT NULL,
	component_property_type	varchar(50) NOT NULL,
	valid_property_value	varchar(255) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_component_property_value', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_component_property_value ADD CONSTRAINT pk_val_component_property_valu PRIMARY KEY (component_property_name, component_property_type, valid_property_value);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_comp_prop_val_nametyp ON val_component_property_value USING btree (component_property_name, component_property_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK val_component_property_value and val_component_property
ALTER TABLE val_component_property_value
	ADD CONSTRAINT fk_comp_prop_val_nametyp
	FOREIGN KEY (component_property_name, component_property_type) REFERENCES val_component_property(component_property_name, component_property_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_component_property_value');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_component_property_value');
-- DONE DEALING WITH TABLE val_component_property_value [680533]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_component_property_type
CREATE TABLE val_component_property_type
(
	component_property_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	is_multivalue	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_component_property_type', true);
ALTER TABLE val_component_property_type
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_component_property_type ADD CONSTRAINT pk_val_component_property_type PRIMARY KEY (component_property_type);

-- Table/Column Comments
COMMENT ON TABLE val_component_property_type IS 'Contains list of valid component_property_types';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_component_property_type ADD CONSTRAINT check_yes_no_46206456
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_component_property_type and val_component_property
ALTER TABLE val_component_property
	ADD CONSTRAINT fk_comp_prop_comp_prop_type
	FOREIGN KEY (component_property_type) REFERENCES val_component_property_type(component_property_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_component_property_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_component_property_type');
-- DONE DEALING WITH TABLE val_component_property_type [680523]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE slot_type_prmt_rem_slot_type
CREATE TABLE slot_type_prmt_rem_slot_type
(
	slot_type_id	integer NOT NULL,
	remote_slot_type_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'slot_type_prmt_rem_slot_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE slot_type_prmt_rem_slot_type ADD CONSTRAINT pk_slot_type_prmt_rem_slot_typ PRIMARY KEY (slot_type_id, remote_slot_type_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_stprst_slot_type_id ON slot_type_prmt_rem_slot_type USING btree (slot_type_id);
CREATE INDEX xif_stprst_remote_slot_type_id ON slot_type_prmt_rem_slot_type USING btree (remote_slot_type_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK slot_type_prmt_rem_slot_type and slot_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE slot_type_prmt_rem_slot_type
--	ADD CONSTRAINT fk_stprst_remote_slot_type_id
--	FOREIGN KEY (remote_slot_type_id) REFERENCES slot_type(slot_type_id);

-- consider FK slot_type_prmt_rem_slot_type and slot_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE slot_type_prmt_rem_slot_type
--	ADD CONSTRAINT fk_stprst_slot_type_id
--	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'slot_type_prmt_rem_slot_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'slot_type_prmt_rem_slot_type');
-- DONE DEALING WITH TABLE slot_type_prmt_rem_slot_type [680167]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE inter_component_connection
CREATE TABLE inter_component_connection
(
	inter_component_connection_id	integer NOT NULL,
	slot1_id	integer NOT NULL,
	slot2_id	integer NOT NULL,
	circuit_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'inter_component_connection', true);
ALTER TABLE inter_component_connection
	ALTER inter_component_connection_id
	SET DEFAULT nextval('inter_component_connection_inter_component_connection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE inter_component_connection ADD CONSTRAINT pk_inter_component_connection PRIMARY KEY (inter_component_connection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_intercomp_conn_slot1_id ON inter_component_connection USING btree (slot1_id);
CREATE INDEX xif_intercomp_conn_slot2_id ON inter_component_connection USING btree (slot2_id);
CREATE INDEX xif_intercom_conn_circ_id ON inter_component_connection USING btree (circuit_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK inter_component_connection and slot
-- Skipping this FK since table does not exist yet
--ALTER TABLE inter_component_connection
--	ADD CONSTRAINT fk_intercomp_conn_slot1_id
--	FOREIGN KEY (slot1_id) REFERENCES slot(slot_id);

-- consider FK inter_component_connection and slot
-- Skipping this FK since table does not exist yet
--ALTER TABLE inter_component_connection
--	ADD CONSTRAINT fk_intercomp_conn_slot2_id
--	FOREIGN KEY (slot2_id) REFERENCES slot(slot_id);

-- consider FK inter_component_connection and circuit
ALTER TABLE inter_component_connection
	ADD CONSTRAINT fk_intercom_conn_circ_id
	FOREIGN KEY (circuit_id) REFERENCES circuit(circuit_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'inter_component_connection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'inter_component_connection');
ALTER SEQUENCE inter_component_connection_inter_component_connection_id_seq
	 OWNED BY inter_component_connection.inter_component_connection_id;
-- DONE DEALING WITH TABLE inter_component_connection [679326]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE component_type
CREATE TABLE component_type
(
	component_type_id	integer NOT NULL,
	company_id	integer  NULL,
	model	varchar(255)  NULL,
	slot_type_id	integer  NULL,
	description	varchar(255)  NULL,
	part_number	varchar(255)  NULL,
	is_removable	character(1) NOT NULL,
	asset_permitted	character(1) NOT NULL,
	is_rack_mountable	character(1) NOT NULL,
	is_virtual_component	character(1) NOT NULL,
	size_units	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'component_type', true);
ALTER TABLE component_type
	ALTER component_type_id
	SET DEFAULT nextval('component_type_component_type_id_seq'::regclass);
ALTER TABLE component_type
	ALTER is_removable
	SET DEFAULT 'N'::bpchar;
ALTER TABLE component_type
	ALTER asset_permitted
	SET DEFAULT 'N'::bpchar;
ALTER TABLE component_type
	ALTER is_rack_mountable
	SET DEFAULT 'N'::bpchar;
ALTER TABLE component_type
	ALTER is_virtual_component
	SET DEFAULT 'N'::bpchar;
ALTER TABLE component_type
	ALTER size_units
	SET DEFAULT 0;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE component_type ADD CONSTRAINT pk_component_type PRIMARY KEY (component_type_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_component_type_slt_type_id ON component_type USING btree (slot_type_id);
CREATE INDEX xif_component_type_company_id ON component_type USING btree (company_id);

-- CHECK CONSTRAINTS
ALTER TABLE component_type ADD CONSTRAINT check_yes_no_53094976
	CHECK (asset_permitted = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE component_type ADD CONSTRAINT check_yes_no_981718444
	CHECK (is_virtual_component = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE component_type ADD CONSTRAINT check_yes_no_1730011385
	CHECK (is_removable = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE component_type ADD CONSTRAINT check_yes_no_25197360
	CHECK (is_rack_mountable = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK component_type and component
-- Skipping this FK since table does not exist yet
--ALTER TABLE component
--	ADD CONSTRAINT fk_component_comp_type_i
--	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);

-- consider FK component_type and device_type
ALTER TABLE device_type
	ADD CONSTRAINT fk_fevtyp_component_id
	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);
-- consider FK component_type and val_component_property
ALTER TABLE val_component_property
	ADD CONSTRAINT fk_comp_prop_rqd_cmptypid
	FOREIGN KEY (required_component_type_id) REFERENCES component_type(component_type_id);
-- consider FK component_type and component_property
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_property
--	ADD CONSTRAINT fk_comp_prop_comp_typ_id
--	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);

-- consider FK component_type and component_type_slot_tmplt
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_type_slot_tmplt
--	ADD CONSTRAINT fk_comp_typ_slt_tmplt_cmptypid
--	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);

-- consider FK component_type and component_type_component_func
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_type_component_func
--	ADD CONSTRAINT fk_cmptypecf_comp_typ_id
--	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);


-- FOREIGN KEYS TO
-- consider FK component_type and company
ALTER TABLE component_type
	ADD CONSTRAINT fk_component_type_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);
-- consider FK component_type and slot_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_type
--	ADD CONSTRAINT fk_component_type_slt_type_id
--	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'component_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'component_type');
ALTER SEQUENCE component_type_component_type_id_seq
	 OWNED BY component_type.component_type_id;
-- DONE DEALING WITH TABLE component_type [678915]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE component_property
CREATE TABLE component_property
(
	component_property_id	integer NOT NULL,
	component_function	varchar(50)  NULL,
	component_type_id	integer  NULL,
	component_id	integer  NULL,
	slot_function	varchar(50)  NULL,
	slot_type_id	integer  NULL,
	slot_id	integer  NULL,
	component_property_name	varchar(50)  NULL,
	component_property_type	varchar(50)  NULL,
	property_value	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'component_property', true);
ALTER TABLE component_property
	ALTER component_property_id
	SET DEFAULT nextval('component_property_component_property_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE component_property ADD CONSTRAINT pk_component_property PRIMARY KEY (component_property_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_comp_prop_prop_nmty ON component_property USING btree (component_property_name, component_property_type);
CREATE INDEX xif_comp_prop_slt_slt_id ON component_property USING btree (slot_id);
CREATE INDEX xif_comp_prop_cmp_id ON component_property USING btree (component_id);
CREATE INDEX xif_comp_prop_sltfuncid ON component_property USING btree (slot_function);
CREATE INDEX xif_comp_prop_comp_func ON component_property USING btree (component_function);
CREATE INDEX xif_comp_prop_slt_typ_id ON component_property USING btree (slot_type_id);
CREATE INDEX xif_comp_prop_comp_typ_id ON component_property USING btree (component_type_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK component_property and component
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_property
--	ADD CONSTRAINT fk_comp_prop_cmp_id
--	FOREIGN KEY (component_id) REFERENCES component(component_id);

-- consider FK component_property and val_component_property
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_prop_nmty
	FOREIGN KEY (component_property_name, component_property_type) REFERENCES val_component_property(component_property_name, component_property_type);
-- consider FK component_property and val_slot_function
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_sltfuncid
	FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function);
-- consider FK component_property and val_component_function
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_comp_func
	FOREIGN KEY (component_function) REFERENCES val_component_function(component_function);
-- consider FK component_property and slot_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_property
--	ADD CONSTRAINT fk_comp_prop_slt_typ_id
--	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);

-- consider FK component_property and component_type
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_comp_typ_id
	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);
-- consider FK component_property and slot
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_property
--	ADD CONSTRAINT fk_comp_prop_slt_slt_id
--	FOREIGN KEY (slot_id) REFERENCES slot(slot_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'component_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'component_property');
ALTER SEQUENCE component_property_component_property_id_seq
	 OWNED BY component_property.component_property_id;
-- DONE DEALING WITH TABLE component_property [678897]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE component_type_slot_tmplt
CREATE TABLE component_type_slot_tmplt
(
	component_type_slot_tmplt_id	integer NOT NULL,
	component_type_id	integer NOT NULL,
	slot_type_id	integer NOT NULL,
	slot_name_template	varchar(50) NOT NULL,
	child_slot_name_template	varchar(50)  NULL,
	child_slot_offset	integer  NULL,
	slot_index	integer  NULL,
	physical_label	varchar(50)  NULL,
	slot_x_offset	integer  NULL,
	slot_y_offset	integer  NULL,
	slot_z_offset	integer  NULL,
	slot_side	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'component_type_slot_tmplt', true);
ALTER TABLE component_type_slot_tmplt
	ALTER component_type_slot_tmplt_id
	SET DEFAULT nextval('component_type_slot_tmplt_component_type_slot_tmplt_id_seq'::regclass);
ALTER TABLE component_type_slot_tmplt
	ALTER slot_side
	SET DEFAULT 'FRONT'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE component_type_slot_tmplt ADD CONSTRAINT pk_component_type_slot_tmplt PRIMARY KEY (component_type_slot_tmplt_id);


-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_comp_typ_slt_tmplt_slttypi ON component_type_slot_tmplt USING btree (slot_type_id);
CREATE INDEX xif_comp_typ_slt_tmplt_cmptypi ON component_type_slot_tmplt USING btree (component_type_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK component_type_slot_tmplt and slot
-- Skipping this FK since table does not exist yet
--ALTER TABLE slot
--	ADD CONSTRAINT fk_slot_cmp_typ_tmp_id
--	FOREIGN KEY (component_type_slot_tmplt_id) REFERENCES component_type_slot_tmplt(component_type_slot_tmplt_id);


-- FOREIGN KEYS TO
-- consider FK component_type_slot_tmplt and slot_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE component_type_slot_tmplt
--	ADD CONSTRAINT fk_comp_typ_slt_tmplt_slttypid
--	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);

-- consider FK component_type_slot_tmplt and component_type
ALTER TABLE component_type_slot_tmplt
	ADD CONSTRAINT fk_comp_typ_slt_tmplt_cmptypid
	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'component_type_slot_tmplt');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'component_type_slot_tmplt');
ALTER SEQUENCE component_type_slot_tmplt_component_type_slot_tmplt_id_seq
	 OWNED BY component_type_slot_tmplt.component_type_slot_tmplt_id;
-- DONE DEALING WITH TABLE component_type_slot_tmplt [678947]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE slot_type_prmt_comp_slot_type
CREATE TABLE slot_type_prmt_comp_slot_type
(
	slot_type_id	integer NOT NULL,
	component_slot_type_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'slot_type_prmt_comp_slot_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE slot_type_prmt_comp_slot_type ADD CONSTRAINT pk_slot_type_prmt_comp_slot_ty PRIMARY KEY (slot_type_id, component_slot_type_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_stpcst_cmp_slt_typ_id ON slot_type_prmt_comp_slot_type USING btree (slot_type_id);
CREATE INDEX xif_stpcst_slot_type_id ON slot_type_prmt_comp_slot_type USING btree (component_slot_type_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK slot_type_prmt_comp_slot_type and slot_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE slot_type_prmt_comp_slot_type
--	ADD CONSTRAINT fk_stpcst_cmp_slt_typ_id
--	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);

-- consider FK slot_type_prmt_comp_slot_type and slot_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE slot_type_prmt_comp_slot_type
--	ADD CONSTRAINT fk_stpcst_slot_type_id
--	FOREIGN KEY (component_slot_type_id) REFERENCES slot_type(slot_type_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'slot_type_prmt_comp_slot_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'slot_type_prmt_comp_slot_type');
-- DONE DEALING WITH TABLE slot_type_prmt_comp_slot_type [680157]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE slot_type
CREATE TABLE slot_type
(
	slot_type_id	integer NOT NULL,
	slot_type	varchar(50) NOT NULL,
	slot_function	varchar(50) NOT NULL,
	slot_physical_interface_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	remote_slot_permitted	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'slot_type', true);
ALTER TABLE slot_type
	ALTER slot_type_id
	SET DEFAULT nextval('slot_type_slot_type_id_seq'::regclass);
ALTER TABLE slot_type
	ALTER remote_slot_permitted
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE slot_type ADD CONSTRAINT pk_slot_type PRIMARY KEY (slot_type_id);
ALTER TABLE slot_type ADD CONSTRAINT ak_slot_type_name_type UNIQUE (slot_type, slot_function);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_slot_type_physint_func ON slot_type USING btree (slot_physical_interface_type, slot_function);
CREATE INDEX xif_slot_type_slt_func ON slot_type USING btree (slot_function);

-- CHECK CONSTRAINTS
ALTER TABLE slot_type ADD CONSTRAINT check_yes_no_28083896
	CHECK (remote_slot_permitted = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK slot_type and slot_type_prmt_rem_slot_type
ALTER TABLE slot_type_prmt_rem_slot_type
	ADD CONSTRAINT fk_stprst_slot_type_id
	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);
-- consider FK slot_type and val_component_property
ALTER TABLE val_component_property
	ADD CONSTRAINT fk_vcomp_prop_rqd_slttyp_id
	FOREIGN KEY (required_slot_type_id) REFERENCES slot_type(slot_type_id);
-- consider FK slot_type and slot_type_prmt_rem_slot_type
ALTER TABLE slot_type_prmt_rem_slot_type
	ADD CONSTRAINT fk_stprst_remote_slot_type_id
	FOREIGN KEY (remote_slot_type_id) REFERENCES slot_type(slot_type_id);
-- consider FK slot_type and component_type
ALTER TABLE component_type
	ADD CONSTRAINT fk_component_type_slt_type_id
	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);
-- consider FK slot_type and slot
-- Skipping this FK since table does not exist yet
--ALTER TABLE slot
--	ADD CONSTRAINT fk_slot_slot_type_id
--	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);

-- consider FK slot_type and component_property
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_slt_typ_id
	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);
-- consider FK slot_type and slot_type_prmt_comp_slot_type
ALTER TABLE slot_type_prmt_comp_slot_type
	ADD CONSTRAINT fk_stpcst_slot_type_id
	FOREIGN KEY (component_slot_type_id) REFERENCES slot_type(slot_type_id);
-- consider FK slot_type and slot_type_prmt_comp_slot_type
ALTER TABLE slot_type_prmt_comp_slot_type
	ADD CONSTRAINT fk_stpcst_cmp_slt_typ_id
	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);
-- consider FK slot_type and component_type_slot_tmplt
ALTER TABLE component_type_slot_tmplt
	ADD CONSTRAINT fk_comp_typ_slt_tmplt_slttypid
	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);

-- FOREIGN KEYS TO
-- consider FK slot_type and val_slot_physical_interface
ALTER TABLE slot_type
	ADD CONSTRAINT fk_slot_type_physint_func
	FOREIGN KEY (slot_physical_interface_type, slot_function) REFERENCES val_slot_physical_interface(slot_physical_interface_type, slot_function);
-- consider FK slot_type and val_slot_function
ALTER TABLE slot_type
	ADD CONSTRAINT fk_slot_type_slt_func
	FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'slot_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'slot_type');
ALTER SEQUENCE slot_type_slot_type_id_seq
	 OWNED BY slot_type.slot_type_id;
-- DONE DEALING WITH TABLE slot_type [680142]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE logical_port_slot
CREATE TABLE logical_port_slot
(
	logical_port_id	integer NOT NULL,
	slot_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'logical_port_slot', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE logical_port_slot ADD CONSTRAINT pk_logical_port_slot PRIMARY KEY (logical_port_id, slot_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_lgl_port_slot_slot_id ON logical_port_slot USING btree (slot_id);
CREATE INDEX xif_lgl_port_slot_lgl_port_id ON logical_port_slot USING btree (logical_port_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK logical_port_slot and slot
-- Skipping this FK since table does not exist yet
--ALTER TABLE logical_port_slot
--	ADD CONSTRAINT fk_lgl_port_slot_slot_id
--	FOREIGN KEY (slot_id) REFERENCES slot(slot_id);

-- consider FK logical_port_slot and logical_port
ALTER TABLE logical_port_slot
	ADD CONSTRAINT fk_lgl_port_slot_lgl_port_id
	FOREIGN KEY (logical_port_id) REFERENCES logical_port(logical_port_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'logical_port_slot');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'logical_port_slot');
-- DONE DEALING WITH TABLE logical_port_slot [679496]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE slot
CREATE TABLE slot
(
	slot_id	integer NOT NULL,
	component_id	integer NOT NULL,
	slot_name	varchar(50) NOT NULL,
	slot_type_id	integer NOT NULL,
	component_type_slot_tmplt_id	integer  NULL,
	is_enabled	character(1) NOT NULL,
	physical_label	varchar(50)  NULL,
	description	varchar(255)  NULL,
	slot_x_offset	integer  NULL,
	slot_y_offset	integer  NULL,
	slot_z_offset	integer  NULL,
	slot_side	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'slot', true);
ALTER TABLE slot
	ALTER slot_id
	SET DEFAULT nextval('slot_slot_id_seq'::regclass);
ALTER TABLE slot
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE slot
	ALTER slot_side
	SET DEFAULT 'FRONT'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE slot ADD CONSTRAINT ak_slot_slot_type_id UNIQUE (slot_id, slot_type_id);
ALTER TABLE slot ADD CONSTRAINT pk_slot_id PRIMARY KEY (slot_id);

ALTER TABLE SLOT
ADD CONSTRAINT
	UQ_SLOT_CMP_SLT_TMPLT_ID UNIQUE 
	(COMPONENT_ID,COMPONENT_TYPE_SLOT_TMPLT_ID);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_slot_cmp_typ_tmp_id ON slot USING btree (component_type_slot_tmplt_id);
CREATE INDEX xif_slot_component_id ON slot USING btree (component_id);
CREATE INDEX xif_slot_slot_type_id ON slot USING btree (slot_type_id);

-- CHECK CONSTRAINTS
ALTER TABLE slot ADD CONSTRAINT ckc_slot_slot_side
	CHECK ((slot_side)::text = ANY ((ARRAY['FRONT'::character varying, 'BACK'::character varying])::text[]));
ALTER TABLE slot ADD CONSTRAINT checkslot_enbled__yes_no
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK slot and inter_component_connection
ALTER TABLE inter_component_connection
	ADD CONSTRAINT fk_intercomp_conn_slot2_id
	FOREIGN KEY (slot2_id) REFERENCES slot(slot_id);
-- consider FK slot and inter_component_connection
ALTER TABLE inter_component_connection
	ADD CONSTRAINT fk_intercomp_conn_slot1_id
	FOREIGN KEY (slot1_id) REFERENCES slot(slot_id);
-- consider FK slot and logical_port_slot
ALTER TABLE logical_port_slot
	ADD CONSTRAINT fk_lgl_port_slot_slot_id
	FOREIGN KEY (slot_id) REFERENCES slot(slot_id);
-- consider FK slot and component_property
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_slt_slt_id
	FOREIGN KEY (slot_id) REFERENCES slot(slot_id);
-- consider FK slot and component
-- Skipping this FK since table does not exist yet
--ALTER TABLE component
--	ADD CONSTRAINT fk_component_prnt_slt_id
--	FOREIGN KEY (parent_slot_id) REFERENCES slot(slot_id);


-- FOREIGN KEYS TO
-- consider FK slot and component
-- Skipping this FK since table does not exist yet
--ALTER TABLE slot
--	ADD CONSTRAINT fk_slot_component_id
--	FOREIGN KEY (component_id) REFERENCES component(component_id);

-- consider FK slot and slot_type
ALTER TABLE slot
	ADD CONSTRAINT fk_slot_slot_type_id
	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);
-- consider FK slot and component_type_slot_tmplt
ALTER TABLE slot
	ADD CONSTRAINT fk_slot_cmp_typ_tmp_id
	FOREIGN KEY (component_type_slot_tmplt_id) REFERENCES component_type_slot_tmplt(component_type_slot_tmplt_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'slot');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'slot');
ALTER SEQUENCE slot_slot_id_seq
	 OWNED BY slot.slot_id;
-- DONE DEALING WITH TABLE slot [680122]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE component_type_component_func
CREATE TABLE component_type_component_func
(
	component_function	varchar(50) NOT NULL,
	component_type_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'component_type_component_func', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE component_type_component_func ADD CONSTRAINT pk_component_type_component_fu PRIMARY KEY (component_function, component_type_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_cmptypecf_comp_typ_id ON component_type_component_func USING btree (component_type_id);
CREATE INDEX xif_cmptypcf_comp_func ON component_type_component_func USING btree (component_function);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK component_type_component_func and val_component_function
ALTER TABLE component_type_component_func
	ADD CONSTRAINT fk_cmptypcf_comp_func
	FOREIGN KEY (component_function) REFERENCES val_component_function(component_function);
-- consider FK component_type_component_func and component_type
ALTER TABLE component_type_component_func
	ADD CONSTRAINT fk_cmptypecf_comp_typ_id
	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'component_type_component_func');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'component_type_component_func');
-- DONE DEALING WITH TABLE component_type_component_func [678935]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE component
CREATE TABLE component
(
	component_id	integer NOT NULL,
	component_type_id	integer NOT NULL,
	component_name	varchar(255)  NULL,
	rack_location_id	integer  NULL,
	parent_slot_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'component', true);
ALTER TABLE component
	ALTER component_id
	SET DEFAULT nextval('component_component_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE component ADD CONSTRAINT ak_component_parent_slot_id UNIQUE (parent_slot_id);
ALTER TABLE component ADD CONSTRAINT pk_component PRIMARY KEY (component_id);
ALTER TABLE component ADD CONSTRAINT ak_component_component_type_id UNIQUE (component_id, component_type_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_component_comp_type_id ON component USING btree (component_type_id);
CREATE INDEX xif_component_rack_loc_id ON component USING btree (rack_location_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK component and component_property
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_cmp_id
	FOREIGN KEY (component_id) REFERENCES component(component_id);
-- consider FK component and asset
ALTER TABLE asset
	ADD CONSTRAINT fk_asset_comp_id
	FOREIGN KEY (component_id) REFERENCES component(component_id);
-- consider FK component and slot
ALTER TABLE slot
	ADD CONSTRAINT fk_slot_component_id
	FOREIGN KEY (component_id) REFERENCES component(component_id);
-- consider FK component and physicalish_volume
-- Skipping this FK since table does not exist yet
--ALTER TABLE physicalish_volume
--	ADD CONSTRAINT fk_physvol_compid
--	FOREIGN KEY (component_id) REFERENCES component(component_id);

-- consider FK component and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_comp_id
	FOREIGN KEY (component_id) REFERENCES component(component_id);

-- FOREIGN KEYS TO
-- consider FK component and slot
ALTER TABLE component
	ADD CONSTRAINT fk_component_prnt_slt_id
	FOREIGN KEY (parent_slot_id) REFERENCES slot(slot_id);
-- consider FK component and rack_location
ALTER TABLE component
	ADD CONSTRAINT fk_component_rack_loc_id
	FOREIGN KEY (rack_location_id) REFERENCES rack_location(rack_location_id);
-- consider FK component and component_type
ALTER TABLE component
	ADD CONSTRAINT fk_component_comp_type_i
	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'component');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'component');
ALTER SEQUENCE component_component_id_seq
	 OWNED BY component.component_id;
-- DONE DEALING WITH TABLE component [678880]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE physicalish_volume
CREATE TABLE physicalish_volume
(
	physicalish_volume_id	integer NOT NULL,
	logical_volume_id	integer  NULL,
	component_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'physicalish_volume', true);
ALTER TABLE physicalish_volume
	ALTER physicalish_volume_id
	SET DEFAULT nextval('physicalish_volume_physicalish_volume_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE physicalish_volume ADD CONSTRAINT pk_physicalish_volume PRIMARY KEY (physicalish_volume_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_physvol_compid ON physicalish_volume USING btree (component_id);
CREATE INDEX xif_physvol_lvid ON physicalish_volume USING btree (logical_volume_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK physicalish_volume and volume_group_physicalish_vol
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_vgp_phy_phyid
--	FOREIGN KEY (physicalish_volume_id) REFERENCES physicalish_volume(physicalish_volume_id);


-- FOREIGN KEYS TO
-- consider FK physicalish_volume and component
ALTER TABLE physicalish_volume
	ADD CONSTRAINT fk_physvol_compid
	FOREIGN KEY (component_id) REFERENCES component(component_id);
-- consider FK physicalish_volume and logical_volume
-- Skipping this FK since table does not exist yet
--ALTER TABLE physicalish_volume
--	ADD CONSTRAINT fk_physvol_lvid
--	FOREIGN KEY (logical_volume_id) REFERENCES logical_volume(logical_volume_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'physicalish_volume');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'physicalish_volume');
ALTER SEQUENCE physicalish_volume_physicalish_volume_id_seq
	 OWNED BY physicalish_volume.physicalish_volume_id;
-- DONE DEALING WITH TABLE physicalish_volume [679938]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE volume_group_physicalish_vol
CREATE TABLE volume_group_physicalish_vol
(
	physicalish_volume_id	integer NOT NULL,
	volume_group_id	integer NOT NULL,
	volume_group_position	integer NOT NULL,
	volume_group_relation	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'volume_group_physicalish_vol', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE volume_group_physicalish_vol ADD CONSTRAINT pk_volume_group_physicalish_vo PRIMARY KEY (physicalish_volume_id, volume_group_id);
ALTER TABLE volume_group_physicalish_vol ADD CONSTRAINT ak_volgrp_pv_position UNIQUE (volume_group_id, volume_group_position);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_vgp_phy_phyid ON volume_group_physicalish_vol USING btree (physicalish_volume_id);
CREATE INDEX xif_vg_physvol_vgrel ON volume_group_physicalish_vol USING btree (volume_group_relation);
CREATE INDEX xif_vgp_phy_vgrpid ON volume_group_physicalish_vol USING btree (volume_group_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK volume_group_physicalish_vol and volume_group
-- Skipping this FK since table does not exist yet
--ALTER TABLE volume_group_physicalish_vol
--	ADD CONSTRAINT fk_vgp_phy_vgrpid
--	FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id);

-- consider FK volume_group_physicalish_vol and physicalish_volume
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_phyid
	FOREIGN KEY (physicalish_volume_id) REFERENCES physicalish_volume(physicalish_volume_id);
-- consider FK volume_group_physicalish_vol and val_volume_group_relation
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vg_physvol_vgrel
	FOREIGN KEY (volume_group_relation) REFERENCES val_volume_group_relation(volume_group_relation);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'volume_group_physicalish_vol');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'volume_group_physicalish_vol');
-- DONE DEALING WITH TABLE volume_group_physicalish_vol [681297]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE logical_volume
CREATE TABLE logical_volume
(
	logical_volume_id	integer NOT NULL,
	volume_group_id	integer NOT NULL,
	logical_volume_name	varchar(50) NOT NULL,
	logical_volume_size_in_mb	integer NOT NULL,
	logical_volume_offset_in_mb	integer  NULL,
	filesystem_type	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'logical_volume', true);
ALTER TABLE logical_volume
	ALTER logical_volume_id
	SET DEFAULT nextval('logical_volume_logical_volume_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE logical_volume ADD CONSTRAINT pk_logical_volume PRIMARY KEY (logical_volume_id);
ALTER TABLE logical_volume ADD CONSTRAINT ak_logical_volume_filesystem UNIQUE (logical_volume_id, filesystem_type);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_logvol_fstype ON logical_volume USING btree (filesystem_type);
CREATE INDEX xif_logvol_vgid ON logical_volume USING btree (volume_group_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK logical_volume and physicalish_volume
ALTER TABLE physicalish_volume
	ADD CONSTRAINT fk_physvol_lvid
	FOREIGN KEY (logical_volume_id) REFERENCES logical_volume(logical_volume_id);
-- consider FK logical_volume and logical_volume_property
-- Skipping this FK since table does not exist yet
--ALTER TABLE logical_volume_property
--	ADD CONSTRAINT fk_lvol_prop_lvid_fstyp
--	FOREIGN KEY (logical_volume_id, filesystem_type) REFERENCES logical_volume(logical_volume_id, filesystem_type);


-- FOREIGN KEYS TO
-- consider FK logical_volume and volume_group
-- Skipping this FK since table does not exist yet
--ALTER TABLE logical_volume
--	ADD CONSTRAINT fk_logvol_vgid
--	FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id);

-- consider FK logical_volume and val_filesystem_type
ALTER TABLE logical_volume
	ADD CONSTRAINT fk_logvol_fstype
	FOREIGN KEY (filesystem_type) REFERENCES val_filesystem_type(filesystem_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'logical_volume');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'logical_volume');
ALTER SEQUENCE logical_volume_logical_volume_id_seq
	 OWNED BY logical_volume.logical_volume_id;

CREATE OR REPLACE FUNCTION verify_physicalish_volume() 
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.logical_volume_id IS NOT NULL AND NEW.component_Id IS NOT NULL THEN
		RAISE EXCEPTION 'One and only one of logical_volume_id or component_id must be set'
			USING ERRCODE = 'unique_violation'; 
	END IF;
	IF NEW.logical_volume_id IS NULL AND NEW.component_Id IS NULL THEN
		RAISE EXCEPTION 'One and only one of logical_volume_id or component_id must be set'
			USING ERRCODE = 'not_null_violation'; 
	END IF;
	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_verify_physicalish_volume
	ON physicalish_volume;
CREATE TRIGGER trigger_verify_physicalish_volume 
	BEFORE INSERT OR UPDATE 
	ON physicalish_volume 
	FOR EACH ROW
	EXECUTE PROCEDURE verify_physicalish_volume();

-- DONE DEALING WITH TABLE logical_volume [679508]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE logical_volume_property
CREATE TABLE logical_volume_property
(
	logical_volume_property_id	integer NOT NULL,
	logical_volume_id	integer  NULL,
	filesystem_type	varchar(50)  NULL,
	logical_volume_property_name	varchar(50)  NULL,
	logical_volume_property_value	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'logical_volume_property', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE logical_volume_property ADD CONSTRAINT pk_logical_volume_property PRIMARY KEY (logical_volume_property_id);
ALTER TABLE logical_volume_property ADD CONSTRAINT ak_logical_vol_prop_fs_lv_name UNIQUE (logical_volume_id, logical_volume_property_name);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_lvol_prop_lvid_fstyp ON logical_volume_property USING btree (logical_volume_id, filesystem_type);
CREATE INDEX xif_lvol_prop_lvpn_fsty ON logical_volume_property USING btree (logical_volume_property_name, filesystem_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK logical_volume_property and logical_volume
ALTER TABLE logical_volume_property
	ADD CONSTRAINT fk_lvol_prop_lvid_fstyp
	FOREIGN KEY (logical_volume_id, filesystem_type) REFERENCES logical_volume(logical_volume_id, filesystem_type);
-- consider FK logical_volume_property and val_logical_volume_property
ALTER TABLE logical_volume_property
	ADD CONSTRAINT fk_lvol_prop_lvpn_fsty
	FOREIGN KEY (logical_volume_property_name, filesystem_type) REFERENCES val_logical_volume_property(logical_volume_property_name, filesystem_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'logical_volume_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'logical_volume_property');
-- DONE DEALING WITH TABLE logical_volume_property [679521]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE volume_group
CREATE TABLE volume_group
(
	volume_group_id	integer NOT NULL,
	volume_group_name	varchar(50) NOT NULL,
	raid_type	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'volume_group', true);
ALTER TABLE volume_group
	ALTER volume_group_id
	SET DEFAULT nextval('volume_group_volume_group_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE volume_group ADD CONSTRAINT pk_volume_group PRIMARY KEY (volume_group_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_volgrp_rd_type ON volume_group USING btree (raid_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK volume_group and logical_volume
ALTER TABLE logical_volume
	ADD CONSTRAINT fk_logvol_vgid
	FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id);
-- consider FK volume_group and volume_group_physicalish_vol
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_vgrpid
	FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id);

-- FOREIGN KEYS TO
-- consider FK volume_group and val_raid_type
ALTER TABLE volume_group
	ADD CONSTRAINT fk_volgrp_rd_type
	FOREIGN KEY (raid_type) REFERENCES val_raid_type(raid_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'volume_group');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'volume_group');
ALTER SEQUENCE volume_group_volume_group_id_seq
	 OWNED BY volume_group.volume_group_id;
-- DONE DEALING WITH TABLE volume_group [681287]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc delete_peruser_account_collection -> delete_peruser_account_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'delete_peruser_account_collection', 'delete_peruser_account_collection');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_delete_peruser_account_collection ON jazzhands.account;
-- consider old oid 694555
DROP FUNCTION IF EXISTS delete_peruser_account_collection();

-- DONE WITH proc delete_peruser_account_collection -> delete_peruser_account_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_peruser_account_collection -> update_peruser_account_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_peruser_account_collection', 'update_peruser_account_collection');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_update_peruser_account_collection ON jazzhands.account;
-- consider old oid 694557
DROP FUNCTION IF EXISTS update_peruser_account_collection();

-- DONE WITH proc update_peruser_account_collection -> update_peruser_account_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.list_unallocated_netblocks -> list_unallocated_netblocks 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_utils', 'list_unallocated_netblocks', 'list_unallocated_netblocks');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 694533
DROP FUNCTION IF EXISTS netblock_utils.list_unallocated_netblocks(netblock_id integer, ip_address inet, ip_universe_id integer, netblock_type text);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 686967
CREATE OR REPLACE FUNCTION netblock_utils.list_unallocated_netblocks(netblock_id integer DEFAULT NULL::integer, ip_address inet DEFAULT NULL::inet, ip_universe_id integer DEFAULT 0, netblock_type text DEFAULT 'default'::text)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
AS $function$
DECLARE
	ip_array		inet[];
	netblock_rec	RECORD;
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	family_bits		integer;
	idx				integer;
BEGIN
	IF netblock_id IS NOT NULL THEN
		SELECT * INTO netblock_rec FROM jazzhands.netblock n WHERE n.netblock_id = 
			list_unallocated_netblocks.netblock_id;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'netblock_id % not found', netblock_id;
		END IF;
		IF netblock_rec.is_single_address = 'Y' THEN
			RETURN;
		END IF;
		ip_address := netblock_rec.ip_address;
		ip_universe_id := netblock_rec.ip_universe_id;
		netblock_type := netblock_rec.netblock_type;
	ELSIF ip_address IS NOT NULL THEN
		ip_universe_id := 0;
		netblock_type := 'default';
	ELSE
		RAISE EXCEPTION 'netblock_id or ip_address must be passed';
	END IF;
	SELECT ARRAY(
		SELECT 
			n.ip_address
		FROM
			netblock n
		WHERE
			n.ip_address <<= list_unallocated_netblocks.ip_address AND
			n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
			n.netblock_type = list_unallocated_netblocks.netblock_type AND
			is_single_address = 'N' AND
			can_subnet = 'N'
		ORDER BY
			n.ip_address
	) INTO ip_array;

	IF array_length(ip_array, 1) IS NULL THEN
		ip_addr := ip_address;
		RETURN NEXT;
		RETURN;
	END IF;

	ip_array := array_prepend(
		list_unallocated_netblocks.ip_address - 1, 
		array_append(
			ip_array, 
			broadcast(list_unallocated_netblocks.ip_address) + 1
			));

	idx := 1;
	WHILE idx < array_length(ip_array, 1) LOOP
		RETURN QUERY SELECT cin.ip_addr FROM
			netblock_utils.calculate_intermediate_netblocks(ip_array[idx], ip_array[idx + 1]) cin;
		idx := idx + 1;
	END LOOP;

	RETURN;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc netblock_utils.list_unallocated_netblocks -> list_unallocated_netblocks 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.purge_account -> purge_account 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('person_manip', 'purge_account', 'purge_account');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 694487
DROP FUNCTION IF EXISTS person_manip.purge_account(in_account_id integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 686920
CREATE OR REPLACE FUNCTION person_manip.purge_account(in_account_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	-- note the per-account account collection is removed in triggers

	DELETE FROM account_assignd_cert where ACCOUNT_ID = in_account_id;
	DELETE FROM account_token where ACCOUNT_ID = in_account_id;
	DELETE FROM account_unix_info where ACCOUNT_ID = in_account_id;
	DELETE FROM klogin where ACCOUNT_ID = in_account_id;
	DELETE FROM property where ACCOUNT_ID = in_account_id;
	DELETE FROM account_password where ACCOUNT_ID = in_account_id;
	DELETE FROM unix_group where account_collection_id in
		(select account_collection_id from account_collection 
			where account_collection_name in
				(select login from account where account_id = in_account_id)
				and account_collection_type in ('unix-group')
		);
	DELETE FROM account_collection_account where ACCOUNT_ID = in_account_id;

	DELETE FROM account_collection where account_collection_name in
		(select login from account where account_id = in_account_id)
		and account_collection_type in ('per-account', 'unix-group');

	DELETE FROM account where ACCOUNT_ID = in_account_id;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc person_manip.purge_account -> purge_account 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc automated_ac_on_account -> automated_ac_on_account 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 687064
CREATE OR REPLACE FUNCTION jazzhands.automated_ac_on_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.account_role != 'primary' THEN
			RETURN OLD;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_role != 'primary' AND OLD.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	END IF;


	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__automated_ac__'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __automated_ac__ (account_collection_id integer, account_id integer, direction text);
	END IF;


	--
	-- based on the old and new values, check for account collections that
	-- may need to be changed based on data.  Note that this may end up being
	-- a no-op.
	-- 
	IF TG_OP = 'INSERT' or TG_OP = 'UPDATE' THEN
		WITH acct AS (
			    SELECT  a.account_id, a.account_type, a.account_role, parc.*,
				    pc.is_management, pc.is_full_time, pc.is_exempt,
				    p.gender
			     FROM   account a
				    INNER JOIN person_account_realm_company parc
					    USING (person_id, company_id, account_realm_id)
				    INNER JOIN person_company pc USING (person_id,company_id)
				    INNER JOIN person p USING (person_id)
			),
		list AS (
			SELECT  p.account_collection_id, a.account_id, a.account_type,
				a.account_role,
				a.person_id, a.company_id
			FROM    property p
			    INNER JOIN acct a
				ON a.account_realm_id = p.account_realm_id
			WHERE   (p.company_id is NULL or a.company_id = p.company_id)
			    AND     property_type = 'auto_acct_coll'
			    AND     (
				    property_name =
					CASE WHEN a.is_exempt = 'N'
					    THEN 'non_exempt'
					    ELSE 'exempt' END
				OR
				    property_name =
					CASE WHEN a.is_management = 'N'
					    THEN 'non_management'
					    ELSE 'management' END
				OR
				    property_name =
					CASE WHEN a.is_full_time = 'N'
					    THEN 'non_full_time'
					    ELSE 'full_time' END
				OR
				    property_name =
					CASE WHEN a.gender = 'M' THEN 'male'
					    WHEN a.gender = 'F' THEN 'female'
					    ELSE 'unspecified_gender' END
				OR (
				    property_name = 'account_type'
				    AND property_value = a.account_type
				    )
				)
		) 
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		) select account_collection_id, account_id, 'add'
		FROM list 
		WHERE account_id = NEW.account_id
		AND NEW.account_role = 'primary'
		;
	END IF;
	IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
		WITH acct AS (
			    SELECT  a.account_id, a.account_type, a.account_role, parc.*,
				    pc.is_management, pc.is_full_time, pc.is_exempt,
				    p.gender
			     FROM   account a
				    INNER JOIN person_account_realm_company parc
					    USING (person_id, company_id, account_realm_id)
				    INNER JOIN person_company pc USING (person_id,company_id)
				    INNER JOIN person p USING (person_id)
			),
		list AS (
			SELECT  p.account_collection_id, a.account_id, a.account_type,
				a.account_role,
				a.person_id, a.company_id
			FROM    property p
			    INNER JOIN acct a
				ON a.account_realm_id = p.account_realm_id
			WHERE   (p.company_id is NULL or a.company_id = p.company_id)
			    AND     property_type = 'auto_acct_coll'
				AND (
					( account_role != 'primary' AND
						property_name in ('non_exempt', 'exempt',
						'management', 'non_management', 'full_time',
						'non_full_time', 'male', 'female', 'unspecified_gender')
				) OR (
					account_role != 'primary'
				    AND property_name = 'account_type'
				    AND property_value = a.account_type
				    )
				)
		) 
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		) select account_collection_id, account_id, 'remove'
		FROM list 
		WHERE account_id = OLD.account_id
		;
	END IF;

/*
	FOR _r IN SELECT * from __automated_ac__
	LOOP
		RAISE NOTICE '%', _r;
	END LOOP;
*/

	--
	-- Remove rows from the temporary table that are in "remove" but not in
	-- "add".
	--
	DELETE FROM account_collection_account
	WHERE (account_collection_id, account_id) IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
		)
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'add'
	)
	;
	--
	-- Add rows from the temporary table that are in 'add" but not "remove"
	-- "add".
	--
	INSERT INTO account_collection_account (
		account_collection_id, account_id)
	SELECT account_collection_id, account_id 
	FROM __automated_ac__
	WHERE direction = 'add'
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
	)
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM account_collection_account)
	;

	DROP TABLE IF EXISTS __automated_ac__;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc automated_ac_on_account -> automated_ac_on_account 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc automated_ac_on_person_company -> automated_ac_on_person_company 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_person_company', 'automated_ac_on_person_company');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person_company ON jazzhands.person_company;
-- consider old oid 694636
DROP FUNCTION IF EXISTS automated_ac_on_person_company();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 687067
CREATE OR REPLACE FUNCTION jazzhands.automated_ac_on_person_company()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_r		RECORD;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__automated_ac__'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __automated_ac__ (account_collection_id integer, account_id integer, direction text);
	END IF;


	RAISE NOTICE 'Here!';

	--
	-- based on the old and new values, check for account collections that
	-- may need to be changed based on data.  Note that this may end up being
	-- a no-op.
	-- 
	IF TG_OP = 'INSERT' or TG_OP = 'UPDATE' THEN
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'add'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE	arc.company_id = NEW.company_id
		AND     (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = NEW.person_id
			AND     property_type = 'auto_acct_coll'
			AND     (
				    property_name =
				    CASE WHEN NEW.is_exempt = 'N'
					THEN 'non_exempt'
					ELSE 'exempt' END
				OR
				    property_name =
				    CASE WHEN NEW.is_management = 'N'
					THEN 'non_management'
					ELSE 'management' END
				OR
				    property_name =
				    CASE WHEN NEW.is_full_time = 'N'
					THEN 'non_full_time'
					ELSE 'full_time' END
				);
	END IF;
	IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'remove'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE	arc.company_id = OLD.company_id
		AND     (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = OLD.person_id
			AND     property_type = 'auto_acct_coll'
			AND     (
				    property_name =
				    CASE WHEN OLD.is_exempt = 'N'
					THEN 'non_exempt'
					ELSE 'exempt' END
				OR
				    property_name =
				    CASE WHEN OLD.is_management = 'N'
					THEN 'non_management'
					ELSE 'management' END
				OR
				    property_name =
				    CASE WHEN OLD.is_full_time = 'N'
					THEN 'non_full_time'
					ELSE 'full_time' END
				);
	END IF;

	FOR _r IN SELECT * from __automated_ac__
	LOOP
		RAISE NOTICE '%', _r;
	END LOOP;

	--
	-- Remove rows from the temporary table that are in "remove" but not in
	-- "add".
	--
	DELETE FROM account_collection_account
	WHERE (account_collection_id, account_id) IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
		)
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'add'
	);

	--
	-- Add rows from the temporary table that are in 'add" but not "remove"
	-- "add".
	--
	INSERT INTO account_collection_account (
		account_collection_id, account_id)
	SELECT account_collection_id, account_id 
	FROM __automated_ac__
	WHERE direction = 'add'
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
	);

	DROP TABLE IF EXISTS __automated_ac__;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;
-- triggers on this function (if applicable)
CREATE TRIGGER trigger_automated_ac_on_person_company AFTER UPDATE ON person_company FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person_company();

-- DONE WITH proc automated_ac_on_person_company -> automated_ac_on_person_company 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc automated_ac_on_person -> automated_ac_on_person 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_person', 'automated_ac_on_person');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person ON jazzhands.person;
-- consider old oid 694638
DROP FUNCTION IF EXISTS automated_ac_on_person();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 687069
CREATE OR REPLACE FUNCTION jazzhands.automated_ac_on_person()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__automated_ac__'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __automated_ac__ (account_collection_id integer, account_id integer, direction text);
	END IF;


	--
	-- based on the old and new values, check for account collections that
	-- may need to be changed based on data.  Note that this may end up being
	-- a no-op.
	-- 
	IF TG_OP = 'UPDATE' THEN
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'add'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE	arc.company_id = NEW.company_id
		AND     (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = NEW.person_id
			AND     property_type = 'auto_acct_coll'
			AND     (
				    property_name =
				    	CASE WHEN NEW.gender = 'M' THEN 'male'
				    		WHEN NEW.gender = 'F' THEN 'female'
							ELSE 'unspecified_gender' END
					);

		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'remove'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE	arc.company_id = OLD.company_id
		AND     (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = OLD.person_id
			AND     property_type = 'auto_acct_coll'
			AND     (
				    property_name =
				    	CASE WHEN OLD.gender = 'M' THEN 'male'
				    	WHEN OLD.gender = 'F' THEN 'female'
						ELSE 'unspecified_gender' END
				);
	END IF;

	--
	-- Remove rows from the temporary table that are in "remove" but not in
	-- "add".
	--
	DELETE FROM account_collection_account
	WHERE (account_collection_id, account_id) IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
		)
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'add'
	);

	--
	-- Add rows from the temporary table that are in 'add" but not "remove"
	-- "add".
	--
	INSERT INTO account_collection_account (
		account_collection_id, account_id)
	SELECT account_collection_id, account_id 
	FROM __automated_ac__
	WHERE direction = 'add'
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
	);

	DROP TABLE IF EXISTS __automated_ac__;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;

END;
$function$
;
-- triggers on this function (if applicable)
CREATE TRIGGER trigger_automated_ac_on_person AFTER UPDATE ON person FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person();

-- DONE WITH proc automated_ac_on_person -> automated_ac_on_person 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc automated_realm_site_ac_pl -> automated_realm_site_ac_pl 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_realm_site_ac_pl', 'automated_realm_site_ac_pl');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trig_automated_realm_site_ac_pl ON jazzhands.person_location;
-- consider old oid 694640
DROP FUNCTION IF EXISTS automated_realm_site_ac_pl();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 687071
CREATE OR REPLACE FUNCTION jazzhands.automated_realm_site_ac_pl()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__automated_ac__'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __automated_ac__ (account_collection_id integer, account_id integer, direction text);
	END IF;

	--
	-- based on the old and new values, check for account collections that
	-- may need to be changed based on data.  Note that this may end up being
	-- a no-op.
	-- 
	IF TG_OP = 'INSERT' or TG_OP = 'UPDATE' THEN
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'add'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE   (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = NEW.person_id
			AND		p.site_code = NEW.site_code
			AND     property_type = 'auto_acct_coll'
			AND     property_name = 'site'
		;
	END IF;
	IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
		INSERT INTO __automated_ac__ (
			account_collection_id, account_id, direction
		)
		SELECT	p.account_collection_id, a.account_id, 'remove'
		FROM    property p
			INNER JOIN account_realm_company arc USING (account_realm_id)
			INNER JOIN account a 
				ON a.account_realm_id = arc.account_realm_id
				AND a.company_id = arc.company_id
		WHERE   (p.company_id is NULL or arc.company_id = p.company_id)
			AND	a.person_id = OLD.person_id
			AND		p.site_code = OLD.site_code
			AND     property_type = 'auto_acct_coll'
			AND     property_name = 'site'
		;
	END IF;
	--
	-- Remove rows from the temporary table that are in "remove" but not in
	-- "add".
	--
	DELETE FROM account_collection_account
	WHERE (account_collection_id, account_id) IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
		)
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'add'
	);

	--
	-- Add rows from the temporary table that are in 'add" but not "remove"
	-- "add".
	--
	INSERT INTO account_collection_account (
		account_collection_id, account_id)
	SELECT account_collection_id, account_id 
	FROM __automated_ac__
	WHERE direction = 'add'
	AND (account_collection_id, account_id) NOT IN
		(select account_collection_id, account_id FROM __automated_ac__
			WHERE direction = 'remove'
	);

	DROP TABLE IF EXISTS __automated_ac__;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;

END;
$function$
;
-- triggers on this function (if applicable)
CREATE TRIGGER trig_automated_realm_site_ac_pl AFTER INSERT OR DELETE OR UPDATE ON person_location FOR EACH ROW EXECUTE PROCEDURE automated_realm_site_ac_pl();

-- DONE WITH proc automated_realm_site_ac_pl -> automated_realm_site_ac_pl 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_operating_system_family
CREATE TABLE val_operating_system_family
(
	operating_system_family	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_operating_system_family', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_operating_system_family ADD CONSTRAINT pk_val_operating_system_family PRIMARY KEY (operating_system_family);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_operating_system_family and operating_system
--ALTER TABLE operating_system
--	ADD CONSTRAINT fk_os_os_family
--	FOREIGN KEY (operating_system_family) REFERENCES val_operating_system_family(operating_system_family);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_operating_system_family');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_operating_system_family');
-- DONE DEALING WITH TABLE val_operating_system_family [680791]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_os_snapshot_type
CREATE TABLE val_os_snapshot_type
(
	operating_system_snapshot_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_os_snapshot_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_os_snapshot_type ADD CONSTRAINT pk_val_os_snapshot_type PRIMARY KEY (operating_system_snapshot_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_os_snapshot_type and operating_system_snapshot
-- Skipping this FK since table does not exist yet
--ALTER TABLE operating_system_snapshot
--	ADD CONSTRAINT fk_os_snap_snap_type
--	FOREIGN KEY (operating_system_snapshot_type) REFERENCES val_os_snapshot_type(operating_system_snapshot_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_os_snapshot_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_os_snapshot_type');
-- DONE DEALING WITH TABLE val_os_snapshot_type [680799]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE operating_system_snapshot
CREATE TABLE operating_system_snapshot
(
	operating_system_snapshot_id	integer NOT NULL,
	operating_system_snapshot_name	varchar(255) NOT NULL,
	operating_system_snapshot_type	varchar(50)  NULL,
	operating_system_id	integer  NULL,
	image_path	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'operating_system_snapshot', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE operating_system_snapshot ADD CONSTRAINT ak_os_snap_name_type UNIQUE (operating_system_id, operating_system_snapshot_name, operating_system_snapshot_type);
ALTER TABLE operating_system_snapshot ADD CONSTRAINT pk_val_operating_system_snapsh PRIMARY KEY (operating_system_snapshot_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_os_snap_osid ON operating_system_snapshot USING btree (operating_system_id);
CREATE INDEX xif_os_snap_snap_type ON operating_system_snapshot USING btree (operating_system_snapshot_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK operating_system_snapshot and property
--ALTER TABLE property
--	ADD CONSTRAINT fk_prop_os_snapshot
--	FOREIGN KEY (operating_system_snapshot_id) REFERENCES operating_system_snapshot(operating_system_snapshot_id);

-- FOREIGN KEYS TO
-- consider FK operating_system_snapshot and operating_system
--ALTER TABLE operating_system_snapshot
--	ADD CONSTRAINT fk_os_snap_osid
--	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK operating_system_snapshot and val_os_snapshot_type
ALTER TABLE operating_system_snapshot
	ADD CONSTRAINT fk_os_snap_snap_type
	FOREIGN KEY (operating_system_snapshot_type) REFERENCES val_os_snapshot_type(operating_system_snapshot_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'operating_system_snapshot');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'operating_system_snapshot');
-- DONE DEALING WITH TABLE operating_system_snapshot [679707]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE operating_system [688185]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'operating_system', 'operating_system');

-- FOREIGN KEYS FROM
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_osid;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_os_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_company;
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_fk_val_dev_arch;
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS fk_os_ref_swpkgrepos;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'operating_system');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.operating_system DROP CONSTRAINT IF EXISTS pk_operating_system;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif5operating_system";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_operating_system ON jazzhands.operating_system;
DROP TRIGGER IF EXISTS trigger_audit_operating_system ON jazzhands.operating_system;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'operating_system');
---- BEGIN audit.operating_system TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'operating_system');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."operating_system_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'operating_system');
---- DONE audit.operating_system TEARDOWN


ALTER TABLE operating_system RENAME TO operating_system_v59;
ALTER TABLE audit.operating_system RENAME TO operating_system_v59;

CREATE TABLE operating_system
(
	operating_system_id	integer NOT NULL,
	operating_system_name	varchar(255) NOT NULL,
	company_id	integer  NULL,
	major_version	varchar(50) NOT NULL,
	version	varchar(255) NOT NULL,
	operating_system_family	varchar(50)  NULL,
	image_url	varchar(255)  NULL,
	processor_architecture	varchar(50)  NULL,
	sw_package_repository_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'operating_system', false);
ALTER TABLE operating_system
	ALTER operating_system_id
	SET DEFAULT nextval('operating_system_operating_system_id_seq'::regclass);
INSERT INTO operating_system (
	operating_system_id,
	operating_system_name,
	company_id,
	major_version,		-- new column (major_version)
	version,
	operating_system_family,		-- new column (operating_system_family)
	image_url,		-- new column (image_url)
	processor_architecture,
	sw_package_repository_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	operating_system_id,
	operating_system_name,
	company_id,
	regexp_replace(version, '\..*', ''),	-- new column (major_version)
	version,
	NULL,		-- new column (operating_system_family)
	NULL,		-- new column (image_url)
	processor_architecture,
	sw_package_repository_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM operating_system_v59;

INSERT INTO audit.operating_system (
	operating_system_id,
	operating_system_name,
	company_id,
	major_version,		-- new column (major_version)
	version,
	operating_system_family,		-- new column (operating_system_family)
	image_url,		-- new column (image_url)
	processor_architecture,
	sw_package_repository_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	operating_system_id,
	operating_system_name,
	company_id,
	regexp_replace(version, '\..*', ''),	-- new column (major_version)
	version,
	NULL,		-- new column (operating_system_family)
	NULL,		-- new column (image_url)
	processor_architecture,
	sw_package_repository_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.operating_system_v59;

ALTER TABLE operating_system
	ALTER operating_system_id
	SET DEFAULT nextval('operating_system_operating_system_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE operating_system ADD CONSTRAINT pk_operating_system PRIMARY KEY (operating_system_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_os_company ON operating_system USING btree (company_id);
CREATE INDEX xif_os_os_family ON operating_system USING btree (operating_system_family);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK operating_system and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK operating_system and device
ALTER TABLE device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK operating_system and operating_system_snapshot
ALTER TABLE operating_system_snapshot
	ADD CONSTRAINT fk_os_snap_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);

-- FOREIGN KEYS TO
-- consider FK operating_system and sw_package_repository
ALTER TABLE operating_system
	ADD CONSTRAINT fk_os_ref_swpkgrepos
	FOREIGN KEY (sw_package_repository_id) REFERENCES sw_package_repository(sw_package_repository_id);
-- consider FK operating_system and val_processor_architecture
ALTER TABLE operating_system
	ADD CONSTRAINT fk_os_fk_val_dev_arch
	FOREIGN KEY (processor_architecture) REFERENCES val_processor_architecture(processor_architecture);
-- consider FK operating_system and company
ALTER TABLE operating_system
	ADD CONSTRAINT fk_os_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK operating_system and val_operating_system_family
ALTER TABLE operating_system
	ADD CONSTRAINT fk_os_os_family
	FOREIGN KEY (operating_system_family) REFERENCES val_operating_system_family(operating_system_family);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'operating_system');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'operating_system');
ALTER SEQUENCE operating_system_operating_system_id_seq
	 OWNED BY operating_system.operating_system_id;
DROP TABLE IF EXISTS operating_system_v59;
DROP TABLE IF EXISTS audit.operating_system_v59;
-- DONE DEALING WITH TABLE operating_system [679696]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE property [688414]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l3netid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_acct_colid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_svc_env_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_val_prsnid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_site_code;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_tokcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_person_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acct_col;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nblk_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_prop_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_swpkgid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_dnsdomid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctrealmid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pv_nblkcol_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l2netid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_dnsdomid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_osid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_pwdtyp;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS pk_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifprop_account_id";
DROP INDEX IF EXISTS "jazzhands"."xif19property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xif17property";
DROP INDEX IF EXISTS "jazzhands"."xif24property";
DROP INDEX IF EXISTS "jazzhands"."xif18property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_swpkgid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_acct_colid";
DROP INDEX IF EXISTS "jazzhands"."xif23property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_tokcolid";
DROP INDEX IF EXISTS "jazzhands"."xif25property";
DROP INDEX IF EXISTS "jazzhands"."xif20property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_site_code";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_pwdtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_osid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_acctcol_id";
DROP INDEX IF EXISTS "jazzhands"."xif22property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_nmtyp";
DROP INDEX IF EXISTS "jazzhands"."xif21property";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS ckc_prop_isenbld;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_audit_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_validate_property ON jazzhands.property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'property');
---- BEGIN audit.property TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'property');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'property');
---- DONE audit.property TEARDOWN


ALTER TABLE property RENAME TO property_v59;
ALTER TABLE audit.property RENAME TO property_v59;

CREATE TABLE property
(
	property_id	integer NOT NULL,
	account_collection_id	integer  NULL,
	account_id	integer  NULL,
	account_realm_id	integer  NULL,
	company_id	integer  NULL,
	device_collection_id	integer  NULL,
	dns_domain_id	integer  NULL,
	netblock_collection_id	integer  NULL,
	layer2_network_id	integer  NULL,
	layer3_network_id	integer  NULL,
	operating_system_id	integer  NULL,
	operating_system_snapshot_id	integer  NULL,
	person_id	integer  NULL,
	property_collection_id	integer  NULL,
	service_env_collection_id	integer  NULL,
	site_code	varchar(50)  NULL,
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	property_value	varchar(1024)  NULL,
	property_value_timestamp	timestamp without time zone  NULL,
	property_value_company_id	integer  NULL,
	property_value_account_coll_id	integer  NULL,
	property_value_dns_domain_id	integer  NULL,
	property_value_nblk_coll_id	integer  NULL,
	property_value_password_type	varchar(50)  NULL,
	property_value_person_id	integer  NULL,
	property_value_sw_package_id	integer  NULL,
	property_value_token_col_id	integer  NULL,
	property_rank	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	is_enabled	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'property', false);
ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;
INSERT INTO property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	layer2_network_id,
	layer3_network_id,
	operating_system_id,
	operating_system_snapshot_id,		-- new column (operating_system_snapshot_id)
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
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
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	layer2_network_id,
	layer3_network_id,
	operating_system_id,
	NULL,		-- new column (operating_system_snapshot_id)
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
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
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM property_v59;

INSERT INTO audit.property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	layer2_network_id,
	layer3_network_id,
	operating_system_id,
	operating_system_snapshot_id,		-- new column (operating_system_snapshot_id)
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
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
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	layer2_network_id,
	layer3_network_id,
	operating_system_id,
	NULL,		-- new column (operating_system_snapshot_id)
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
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
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.property_v59;

ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE property ADD CONSTRAINT pk_property PRIMARY KEY (property_id);

-- Table/Column Comments
COMMENT ON TABLE property IS 'generic property instance that describes system wide properties, as well as properties for various values of columns used throughout the db for configuration, acls, defaults, etc; also used to relate some tables';
COMMENT ON COLUMN property.property_id IS 'primary key for table to uniquely identify rows.';
COMMENT ON COLUMN property.account_collection_id IS 'user collection that properties may be set on.';
COMMENT ON COLUMN property.account_id IS 'system user that properties may be set on.';
COMMENT ON COLUMN property.company_id IS 'company that properties may be set on.';
COMMENT ON COLUMN property.device_collection_id IS 'device collection that properties may be set on.';
COMMENT ON COLUMN property.dns_domain_id IS 'dns domain that properties may be set on.';
COMMENT ON COLUMN property.operating_system_id IS 'operating system that properties may be set on.';
COMMENT ON COLUMN property.site_code IS 'site_code that properties may be set on';
COMMENT ON COLUMN property.property_name IS 'textual name of a property';
COMMENT ON COLUMN property.property_type IS 'textual type of a department';
COMMENT ON COLUMN property.property_value IS 'general purpose column for value of property not defined by other types.  This may be enforced by fk (trigger) if val_property.property_data_type is list (fk is to val_property_value).';
COMMENT ON COLUMN property.property_value_timestamp IS 'property is defined as a timestamp';
COMMENT ON COLUMN property.start_date IS 'date/time that the assignment takes effect';
COMMENT ON COLUMN property.finish_date IS 'date/time that the assignment ceases taking effect';
COMMENT ON COLUMN property.is_enabled IS 'indiciates if the property is temporarily disabled or not.';
-- INDEXES
CREATE INDEX xifprop_pval_acct_colid ON property USING btree (property_value_account_coll_id);
CREATE INDEX xif23property ON property USING btree (layer2_network_id);
CREATE INDEX xifprop_pval_tokcolid ON property USING btree (property_value_token_col_id);
CREATE INDEX xif25property ON property USING btree (property_collection_id);
CREATE INDEX xif20property ON property USING btree (netblock_collection_id);
CREATE INDEX xifprop_site_code ON property USING btree (site_code);
CREATE INDEX xifprop_devcolid ON property USING btree (device_collection_id);
CREATE INDEX xifprop_dnsdomid ON property USING btree (dns_domain_id);
CREATE INDEX xifprop_account_id ON property USING btree (account_id);
CREATE INDEX xif19property ON property USING btree (property_value_nblk_coll_id);
CREATE INDEX xifprop_pval_dnsdomid ON property USING btree (property_value_dns_domain_id);
CREATE INDEX xif24property ON property USING btree (layer3_network_id);
CREATE INDEX xif17property ON property USING btree (property_value_person_id);
CREATE INDEX xif18property ON property USING btree (person_id);
CREATE INDEX xifprop_pval_swpkgid ON property USING btree (property_value_sw_package_id);
CREATE INDEX xifprop_acctcol_id ON property USING btree (account_collection_id);
CREATE INDEX xif22property ON property USING btree (account_realm_id);
CREATE INDEX xifprop_nmtyp ON property USING btree (property_name, property_type);
CREATE INDEX xif_prop_os_snapshot ON property USING btree (operating_system_snapshot_id);
CREATE INDEX xif21property ON property USING btree (service_env_collection_id);
CREATE INDEX xifprop_pval_pwdtyp ON property USING btree (property_value_password_type);
CREATE INDEX xifprop_compid ON property USING btree (company_id);
CREATE INDEX xifprop_osid ON property USING btree (operating_system_id);
CREATE INDEX xifprop_pval_compid ON property USING btree (property_value_company_id);

-- CHECK CONSTRAINTS
ALTER TABLE property ADD CONSTRAINT ckc_prop_isenbld
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK property and site
ALTER TABLE property
	ADD CONSTRAINT fk_property_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_val_prsnid
	FOREIGN KEY (property_value_person_id) REFERENCES person(person_id);
-- consider FK property and token_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_tokcolid
	FOREIGN KEY (property_value_token_col_id) REFERENCES token_collection(token_collection_id);
-- consider FK property and account
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK property and service_environment_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_svc_env_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
-- consider FK property and layer3_network
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l3netid
	FOREIGN KEY (layer3_network_id) REFERENCES layer3_network(layer3_network_id);
-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_acct_colid
	FOREIGN KEY (property_value_account_coll_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pv_nblkcol_id
	FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK property and layer2_network
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l2netid
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK property and account_realm
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctrealmid
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);
-- consider FK property and operating_system
ALTER TABLE property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK property and val_password_type
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_pwdtyp
	FOREIGN KEY (property_value_password_type) REFERENCES val_password_type(password_type);
-- consider FK property and dns_domain
ALTER TABLE property
	ADD CONSTRAINT fk_property_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK property and sw_package
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_swpkgid
	FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id);
-- consider FK property and dns_domain
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_dnsdomid
	FOREIGN KEY (property_value_dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK property and property_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_prop_coll_id
	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);
-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_person_id
	FOREIGN KEY (person_id) REFERENCES person(person_id);
-- consider FK property and device_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK property and operating_system_snapshot
ALTER TABLE property
	ADD CONSTRAINT fk_prop_os_snapshot
	FOREIGN KEY (operating_system_snapshot_id) REFERENCES operating_system_snapshot(operating_system_snapshot_id);
-- consider FK property and val_property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);

-- TRIGGERS
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE ON property FOR EACH ROW EXECUTE PROCEDURE validate_property();

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property');
ALTER SEQUENCE property_property_id_seq
	 OWNED BY property.property_id;
DROP TABLE IF EXISTS property_v59;
DROP TABLE IF EXISTS audit.property_v59;
-- DONE DEALING WITH TABLE property [679951]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_property [689304]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property', 'val_property');

-- FOREIGN KEYS FROM
ALTER TABLE val_property_value DROP CONSTRAINT IF EXISTS fk_valproval_namtyp;
ALTER TABLE property_collection_property DROP CONSTRAINT IF EXISTS fk_prop_col_propnamtyp;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_propdttyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_proptyp;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS pk_val_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif3val_property";
DROP INDEX IF EXISTS "jazzhands"."xif1val_property";
DROP INDEX IF EXISTS "jazzhands"."xif4val_property";
DROP INDEX IF EXISTS "jazzhands"."xif2val_property";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_osid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_ismulti;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pucls_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_354296970;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2016888554;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2139007167;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1279736503;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pacct_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_sitec;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_cmp_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_606225804;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdevcol_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdnsdomid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_prodstate;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1279736247;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_271462566;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trig_userlog_val_property ON jazzhands.val_property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_property');
---- BEGIN audit.val_property TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_property');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_property');
---- DONE audit.val_property TEARDOWN


ALTER TABLE val_property RENAME TO val_property_v59;
ALTER TABLE audit.val_property RENAME TO val_property_v59;

CREATE TABLE val_property
(
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	is_multivalue	character(1) NOT NULL,
	prop_val_acct_coll_type_rstrct	varchar(50)  NULL,
	prop_val_nblk_coll_type_rstrct	varchar(50)  NULL,
	property_data_type	varchar(50) NOT NULL,
	permit_account_collection_id	character(10) NOT NULL,
	permit_account_id	character(10) NOT NULL,
	permit_account_realm_id	character(10) NOT NULL,
	permit_company_id	character(10) NOT NULL,
	permit_device_collection_id	character(10) NOT NULL,
	permit_dns_domain_id	character(10) NOT NULL,
	permit_layer2_network_id	character(10) NOT NULL,
	permit_layer3_network_id	character(10) NOT NULL,
	permit_netblock_collection_id	character(10) NOT NULL,
	permit_operating_system_id	character(10) NOT NULL,
	permit_os_snapshot_id	character(10) NOT NULL,
	permit_person_id	character(10) NOT NULL,
	permit_property_collection_id	character(10) NOT NULL,
	permit_service_env_collection	character(10) NOT NULL,
	permit_site_code	character(10) NOT NULL,
	permit_property_rank	character(10) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_property', false);
ALTER TABLE val_property
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_os_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;
INSERT INTO val_property (
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_os_snapshot_id,		-- new column (permit_os_snapshot_id)
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	'PROHIBITED'::bpchar,		-- new column (permit_os_snapshot_id)
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v59;

INSERT INTO audit.val_property (
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_os_snapshot_id,		-- new column (permit_os_snapshot_id)
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	NULL,		-- new column (permit_os_snapshot_id)
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_property_v59;

ALTER TABLE val_property
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_os_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_property ADD CONSTRAINT pk_val_property PRIMARY KEY (property_name, property_type);

-- Table/Column Comments
COMMENT ON TABLE val_property IS 'valid values and attributes for (name,type) pairs in the property table';
COMMENT ON COLUMN val_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN val_property.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN val_property.is_multivalue IS 'If N, acts like an alternate key on property.(lhs,property_type)';
COMMENT ON COLUMN val_property.property_data_type IS 'which of the property_table_* columns should be used for this value';
COMMENT ON COLUMN val_property.permit_account_collection_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_account_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_company_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_device_collection_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_dns_domain_id IS 'defines how company id should be used in the property for this (name,type)';
-- INDEXES
CREATE INDEX xif3val_property ON val_property USING btree (prop_val_acct_coll_type_rstrct);
CREATE INDEX xif2val_property ON val_property USING btree (property_type);
CREATE INDEX xif1val_property ON val_property USING btree (property_data_type);
CREATE INDEX xif4val_property ON val_property USING btree (prop_val_nblk_coll_type_rstrct);

-- CHECK CONSTRAINTS
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pucls_id
	CHECK (permit_account_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_354296970
	CHECK (permit_netblock_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_ismulti
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_osid
	CHECK (permit_operating_system_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2139007167
	CHECK (permit_property_rank = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2016888554
	CHECK (permit_account_realm_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_cmp_id
	CHECK (permit_company_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_606225804
	CHECK (permit_person_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdevcol_id
	CHECK (permit_device_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pacct_id
	CHECK (permit_account_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1804972034
	CHECK (permit_os_snapshot_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_sitec
	CHECK (permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1279736503
	CHECK (permit_layer2_network_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_prodstate
	CHECK (permit_service_env_collection = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_271462566
	CHECK (permit_property_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1279736247
	CHECK (permit_layer3_network_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdnsdomid
	CHECK (permit_dns_domain_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_property and val_property_value
ALTER TABLE val_property_value
	ADD CONSTRAINT fk_valproval_namtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK val_property and property_collection_property
ALTER TABLE property_collection_property
	ADD CONSTRAINT fk_prop_col_propnamtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK val_property and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- FOREIGN KEYS TO
-- consider FK val_property and val_property_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_property_data_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property');
DROP TABLE IF EXISTS val_property_v59;
DROP TABLE IF EXISTS audit.val_property_v59;
-- DONE DEALING WITH TABLE val_property [680985]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE v_company_hier [892176]
-- Save grants for later reapplication

CREATE OR REPLACE VIEW v_company_hier AS
WITH RECURSIVE var_recurse (
	level,
	root_company_id,
	company_id,
	array_path,
	cycle
) as (
	SELECT	
		0				as level,
		c.company_id			as root_company_id,
		c.company_id			as company_id,
		ARRAY[c.company_id]		as array_path,
		false				as cycle
	  FROM	company c
UNION ALL
	SELECT	
		x.level + 1			as level,
		x.root_company_id		as root_company_id,
		c.company_id			as company_id,
		c.company_id || x.array_path	as array_path,
		c.company_id = ANY(x.array_path) as cycle
	  FROM	var_recurse x
		inner join company c
			on c.parent_company_id = x.company_id
	WHERE	NOT x.cycle
) SELECT	distinct root_company_id as root_company_id, company_id
  from 		var_recurse;

delete from __recreate where type = 'view' and object = 'v_company_hier';
GRANT INSERT,UPDATE,DELETE ON v_company_hier TO iud_role;
GRANT ALL ON v_company_hier TO jazzhands;
GRANT SELECT ON v_company_hier TO ro_role;
-- DONE DEALING WITH TABLE v_company_hier [900630]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
ALTER TABLE account_realm_company DROP CONSTRAINT IF EXISTS fk_acct_rlm_cmpy_cmpy_id;
ALTER TABLE account_realm_company
	ADD CONSTRAINT fk_acct_rlm_cmpy_cmpy_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;

ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_aloc_companyid;
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_aloc_companyid
	FOREIGN KEY (aloc_lec_company_id) REFERENCES company(company_id) DEFERRABLE;

ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_vend_companyid;
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_vend_companyid
	FOREIGN KEY (vendor_company_id) REFERENCES company(company_id) DEFERRABLE;

ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_zloc_company_id;
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_zloc_company_id
	FOREIGN KEY (zloc_lec_company_id) REFERENCES company(company_id) DEFERRABLE;

ALTER TABLE company_type DROP CONSTRAINT IF EXISTS fk_company_type_company_id;
ALTER TABLE company_type
	ADD CONSTRAINT fk_company_type_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;

ALTER TABLE contract DROP CONSTRAINT IF EXISTS fk_contract_company_id;
ALTER TABLE contract
	ADD CONSTRAINT fk_contract_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;

ALTER TABLE department DROP CONSTRAINT IF EXISTS fk_dept_company;
ALTER TABLE department
	ADD CONSTRAINT fk_dept_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;

ALTER TABLE netblock DROP CONSTRAINT IF EXISTS fk_netblock_company;
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_company
	FOREIGN KEY (nic_company_id) REFERENCES company(company_id) DEFERRABLE;

ALTER TABLE person_account_realm_company DROP CONSTRAINT IF EXISTS fk_ac_ac_rlm_cpy_act_rlm_cpy;
ALTER TABLE person_account_realm_company
	ADD CONSTRAINT fk_ac_ac_rlm_cpy_act_rlm_cpy
	FOREIGN KEY (account_realm_id, company_id) REFERENCES account_realm_company(account_realm_id, company_id) DEFERRABLE;

ALTER TABLE person_company DROP CONSTRAINT IF EXISTS fk_person_company_company_id;
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;

ALTER TABLE person_contact DROP CONSTRAINT IF EXISTS fk_prsn_contect_cr_cmpyid;
ALTER TABLE person_contact
	ADD CONSTRAINT fk_prsn_contect_cr_cmpyid
	FOREIGN KEY (person_contact_cr_company_id) REFERENCES company(company_id) DEFERRABLE;

ALTER TABLE physical_address DROP CONSTRAINT IF EXISTS fk_physaddr_company_id;
ALTER TABLE physical_address
	ADD CONSTRAINT fk_physaddr_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;

-- triggers
DROP TRIGGER IF EXISTS trig_automated_ac ON account;
DROP TRIGGER IF EXISTS trigger_delete_peruser_account_collection ON account;
DROP TRIGGER IF EXISTS trigger_update_account_type_account_collection ON account;
DROP TRIGGER IF EXISTS trigger_update_peruser_account_collection ON account;
CREATE TRIGGER trig_add_automated_ac_on_account AFTER INSERT OR UPDATE OF account_type, account_role ON account FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_account();
CREATE TRIGGER trig_rm_automated_ac_on_account BEFORE DELETE ON account FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_account();
CREATE TRIGGER trigger_delete_peraccount_account_collection BEFORE DELETE ON account FOR EACH ROW EXECUTE PROCEDURE delete_peraccount_account_collection();
CREATE TRIGGER trigger_update_peraccount_account_collection AFTER INSERT OR UPDATE ON account FOR EACH ROW EXECUTE PROCEDURE update_peraccount_account_collection();

--------------------------------------------------------------------
-- DEALING WITH proc person_manip.change_company -> change_company 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('person_manip', 'change_company', 'change_company');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
-- consider old oid 694490
DROP FUNCTION IF EXISTS person_manip.change_company(final_company_id integer, _person_id integer, initial_company_id integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 686923
CREATE OR REPLACE FUNCTION person_manip.change_company(final_company_id integer, _person_id integer, initial_company_id integer, _account_realm_id integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands, pg_temp
AS $function$
DECLARE
	initial_person_company  person_company%ROWTYPE;
	_arid			account_realm.account_realm_id%TYPE;
BEGIN
	IF _account_realm_id IS NULL THEN
		SELECT	account_realm_id
		INTO	_arid
		FROM	property
		WHERE	property_type = 'Defaults'
		AND	property_name = '_root_account_realm_id';
	ELSE
		_arid := _account_realm_id;
	END IF;
	set constraints fk_ac_ac_rlm_cpy_act_rlm_cpy DEFERRED;
	set constraints fk_account_prsn_cmpy_acct DEFERRED;
	set constraints fk_account_company_person DEFERRED;

	UPDATE person_account_realm_company
		SET company_id = final_company_id
	WHERE person_id = _person_id
	AND company_id = initial_company_id
	AND account_realm_id = _arid;

	SELECT * 
	INTO initial_person_company 
	FROM person_company 
	WHERE person_id = _person_id 
	AND company_id = initial_company_id;

	UPDATE person_company
	SET company_id = final_company_id
	WHERE company_id = initial_company_id
	AND person_id = _person_id;

	UPDATE account 
	SET company_id = final_company_id 
	WHERE company_id = initial_company_id 
	AND person_id = _person_id
	AND account_realm_id = _arid;

	set constraints fk_ac_ac_rlm_cpy_act_rlm_cpy IMMEDIATE;
	set constraints fk_account_prsn_cmpy_acct IMMEDIATE;
	set constraints fk_account_company_person IMMEDIATE;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc person_manip.change_company -> change_company 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE v_property [745605]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_property', 'v_property');
CREATE VIEW v_property AS
 SELECT property.property_id,
    property.account_collection_id,
    property.account_id,
    property.account_realm_id,
    property.company_id,
    property.device_collection_id,
    property.dns_domain_id,
    property.netblock_collection_id,
    property.layer2_network_id,
    property.layer3_network_id,
    property.operating_system_id,
    property.operating_system_snapshot_id,
    property.person_id,
    property.property_collection_id,
    property.service_env_collection_id,
    property.site_code,
    property.property_name,
    property.property_type,
    property.property_value,
    property.property_value_timestamp,
    property.property_value_company_id,
    property.property_value_account_coll_id,
    property.property_value_dns_domain_id,
    property.property_value_nblk_coll_id,
    property.property_value_password_type,
    property.property_value_person_id,
    property.property_value_sw_package_id,
    property.property_value_token_col_id,
    property.property_rank,
    property.start_date,
    property.finish_date,
    property.is_enabled,
    property.data_ins_user,
    property.data_ins_date,
    property.data_upd_user,
    property.data_upd_date
   FROM property
  WHERE property.is_enabled = 'Y'::bpchar AND (property.start_date IS NULL AND property.finish_date IS NULL OR property.start_date IS NULL AND now() <= property.finish_date OR property.start_date <= now() AND property.finish_date IS NULL OR property.start_date <= now() AND now() <= property.finish_date);

delete from __recreate where type = 'view' and object = 'v_property';
GRANT ALL ON v_property TO jazzhands;
GRANT INSERT,UPDATE,DELETE ON v_property TO iud_role;
GRANT SELECT ON v_property TO ro_role;
-- DONE DEALING WITH TABLE v_property [686737]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc validate_device_component_assignment -> validate_device_component_assignment 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 885759
CREATE OR REPLACE FUNCTION jazzhands.validate_device_component_assignment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dtid		device_type.device_type_id%TYPE;
	dt_ctid		component.component_type_id%TYPE;
	ctid		component.component_type_id%TYPE;
BEGIN
	-- If no component_id is set, then we're done

	IF NEW.component_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT
		device_type_id, component_type_id 
	INTO
		dtid, dt_ctid
	FROM
		device_type
	WHERE
		device_type_id = NEW.device_type_id;

	IF NOT FOUND OR dt_ctid IS NULL THEN
		RAISE EXCEPTION 'No component_type_id set for device type'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	SELECT
		component_type_id INTO ctid
	FROM
		component
	WHERE
		component_id = NEW.component.id;

	IF NOT FOUND OR ctid IS DISTINCT FROM dt_ctid THEN
		RAISE EXCEPTION 'Component type of component_id % does not match component_type for device_type_id % (%)',
			ctid, dtid, dt_ctid
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc validate_device_component_assignment -> validate_device_component_assignment 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc validate_asset_component_assignment -> validate_asset_component_assignment 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 885762
CREATE OR REPLACE FUNCTION jazzhands.validate_asset_component_assignment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	asset_permitted		BOOLEAN;
BEGIN
	-- If no component_id is set, then we're done

	IF NEW.component_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT
		ct.asset_permitted INTO asset_permitted
	FROM
		component c JOIN
		component_type ct USING (component_type_id)
	WHERE
		c.component_id = NEW.component_id;

	IF asset_permitted != TRUE THEN
		RAISE EXCEPTION 'Component type of component_id % may not be assigned to an asset',
			NEW.component_id
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc validate_asset_component_assignment -> validate_asset_component_assignment 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc validate_component_parent_slot_id -> validate_component_parent_slot_id 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 885765
CREATE OR REPLACE FUNCTION jazzhands.validate_component_parent_slot_id()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	stid	integer;
BEGIN
	IF NEW.parent_slot_id IS NULL THEN
		RETURN NEW;
	END IF;

	PERFORM
		*
	FROM
		slot s JOIN
		slot_type_prmt_comp_slot_type stpcst USING (slot_type_id)
	WHERE
		stpcst.component_slot_type_id = NEW.slot_type_id AND
		s.slot_id = NEW.parent_slot_id;

	IF NOT FOUND THEN
		SELECT slot_type_id INTO stid FROM slot WHERE slot_id = NEW.parent_slot_id;
		RAISE EXCEPTION 'Component type % is not permitted in slot % (slot type %)',
			NEW.component_type_id, NEW.parent_slot_id, stid
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc validate_slot_component_id -> validate_slot_component_id 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc validate_inter_component_connection -> validate_inter_component_connection 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 885768
CREATE OR REPLACE FUNCTION jazzhands.validate_inter_component_connection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	slot_type_info	RECORD;
	csid_rec	RECORD;
BEGIN
	IF NEW.slot1_id = NEW.slot2_id THEN
		RAISE EXCEPTION 'A slot may not be connected to itself'
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- Validate that slot_ids are not already connected
	-- to something else
	--

	SELECT
		slot1_id
		slot2_id
	INTO
		csid_rec
	FROM
		inter_component_connection icc
	WHERE
		icc.slot1_id = NEW.slot1_id OR
		icc.slot1_id = NEW.slot2_id OR
		icc.slot2_id = NEW.slot1_id OR
		icc.slot2_id = NEW.slot2_id
	LIMIT 1;

	IF FOUND THEN
		IF csid_rec.slot1_id = NEW.slot1_id THEN
			RAISE EXCEPTION 
				'slot_id % is already attached to slot_id %',
				NEW.slot1_id, csid_rec.slot2_id
				USING ERRCODE = 'unique_violation';
		ELSIF csid_rec.slot1_id = NEW.slot2_id THEN
			RAISE EXCEPTION 
				'slot_id % is already attached to slot_id %',
				NEW.slot1_id, csid_rec.slot1_id
				USING ERRCODE = 'unique_violation';
		ELSIF csid_rec.slot2_id = NEW.slot1_id THEN
			RAISE EXCEPTION 
				'slot_id % is already attached to slot_id %',
				NEW.slot2_id, csid_rec.slot2_id
				USING ERRCODE = 'unique_violation';
		ELSIF csid_rec.slot2_id = NEW.slot2_id THEN
			RAISE EXCEPTION 
				'slot_id % is already attached to slot_id %',
				NEW.slot2_id, csid_rec.slot1_id
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	PERFORM
		*
	FROM
		(slot cs1 JOIN slot_type st1 USING (slot_type_id)) slot1,
		(slot cs2 JOIN slot_type st2 USING (slot_type_id)) slot2,
		slot_type_prmt_rem_slot_type pst
	WHERE
		cs1.slot_id = NEW.slot1_id AND
		cs2.slot_id = NEW.slot2_id AND
		-- Remove next line if we ever decide to allow cross-function
		-- connections
		cs1.slot_function = cs2.slot_function AND
		((cs1.slot_type_id = pst.slot_type_id AND
				cs2.slot_type_id = pst.remote_slot_type_id) OR
			(cs2.slot_type_id = pst.slot_type_id AND
				cs1.slot_type_id = pst.remote_slot_type_id));

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Slot types are not allowed to be connected'
			USING ERRCODE = 'check_violation';
	END IF;

	RETURN NEW;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc validate_inter_component_connection -> validate_inter_component_connection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc validate_component_rack_location -> validate_component_rack_location 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 885771
CREATE OR REPLACE FUNCTION jazzhands.validate_component_rack_location()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	ct_rec	RECORD;
BEGIN
	IF NEW.rack_location_id IS NULL THEN
		RETURN NEW;
	END IF;
	SELECT
		component_type_id,
		is_rack_mountable
	INTO
		ct_rec
	FROM
		component c JOIN
		component_type ct USING (component_type_id)
	WHERE
		component_id = NEW.component_id;

	IF ct_rec.is_rack_mountable != 'Y' THEN
		RAISE EXCEPTION 'component_type_id % may not be assigned a rack_location',
			ct_rec.component_type_id
			USING ERRCODE = 'check_violation';
	END IF;

	RETURN NEW;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc validate_component_rack_location -> validate_component_rack_location 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc validate_component_property -> validate_component_property 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 885774
CREATE OR REPLACE FUNCTION jazzhands.validate_component_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally				INTEGER;
	v_comp_prop			RECORD;
	v_comp_prop_type	RECORD;
	v_num				INTEGER;
	v_listvalue			TEXT;
	component_attrs		RECORD;
BEGIN

	-- Pull in the data from the property and property_type so we can
	-- figure out what is and is not valid

	BEGIN
		SELECT * INTO STRICT v_comp_prop FROM val_component_property WHERE
			component_property_name = NEW.component_property_name AND
			component_property_type = NEW.component_property_type;

		SELECT * INTO STRICT v_comp_prop_type FROM val_component_property_type 
			WHERE component_property_type = NEW.component_property_type;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE EXCEPTION 
				'Component property name or type does not exist'
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue.  That is, if only
	-- one value can be set for this property for a specific property LHS

	IF (v_comp_prop.is_multivalue != 'Y') THEN
		PERFORM 1 FROM component_property WHERE
			component_property_id != NEW.component_property_id AND
			component_property_name = NEW.component_property_name AND
			component_property_type = NEW.component_property_type AND
			component_type_id IS NOT DISTINCT FROM NEW.component_type_id AND
			component_function IS NOT DISTINCT FROM NEW.component_function AND
			component_id iS NOT DISTINCT FROM NEW.component_id AND
			slot_type_id IS NOT DISTINCT FROM NEW.slot_type_id AND
			slot_function IS NOT DISTINCT FROM NEW.slot_function AND
			slot_id IS NOT DISTINCT FROM NEW.slot_id;

		IF FOUND THEN
			RAISE EXCEPTION 
				'Property with name % and type % already exists for given LHS and property is not multivalue',
				NEW.component_property_name,
				NEW.component_property_type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_comp_prop_type.is_multivalue != 'Y') THEN
		PERFORM 1 FROM component_property WHERE
			component_property_id != NEW.component_property_id AND
			component_property_type = NEW.component_property_type AND
			component_type_id IS NOT DISTINCT FROM NEW.component_type_id AND
			component_function IS NOT DISTINCT FROM NEW.component_function AND
			component_id iS NOT DISTINCT FROM NEW.component_id AND
			slot_type_id IS NOT DISTINCT FROM NEW.slot_type_id AND
			slot_function IS NOT DISTINCT FROM NEW.slot_function AND
			slot_id IS NOT DISTINCT FROM NEW.slot_id;

		IF FOUND THEN
			RAISE EXCEPTION 
				'Property % of type % already exists for given LHS and property type is not multivalue',
				NEW.component_property_name, NEW.component_property_type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- now validate the property_value columns.
	tally := 0;

	--
	-- first determine if the property_value is set properly.
	--

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid.  Now, check the various options for
	-- PROPERTY_VALUE itself.  If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid.  If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification.  This should be considered bad.

	IF NEW.property_value IS NOT NULL THEN
		tally := tally + 1;
		IF v_comp_prop.property_data_type = 'boolean' THEN
			IF NEW.Property_Value != 'Y' AND NEW.Property_Value != 'N' THEN
				RAISE 'Boolean property_value must be Y or N' USING
					ERRCODE = 'invalid_parameter_value';
			END IF;
		ELSIF v_comp_prop.property_data_type = 'number' THEN
			BEGIN
				v_num := to_number(NEW.property_value, '9');
			EXCEPTION
				WHEN OTHERS THEN
					RAISE 'property_value must be numeric' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_comp_prop.property_data_type = 'list' THEN
			BEGIN
				SELECT valid_property_value INTO STRICT v_listvalue FROM 
					val_component_property_value WHERE
						property_name = NEW.property_name AND
						property_type = NEW.property_type AND
						valid_property_value = NEW.property_value;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE 'property_value must be a valid value' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_comp_prop.property_data_type != 'string' THEN
			RAISE 'property_data_type is not a known type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.property_data_type != 'none' AND tally = 0 THEN
		RAISE 'One of the property_value fields must be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	IF tally > 1 THEN
		RAISE 'Only one of the property_value fields may be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- At this point, the value itself is valid for this property, now
	-- determine whether the property is allowed on the target
	--
	-- There needs to be a stanza here for every "lhs".  If a new column is
	-- added to the component_property table, a new stanza needs to be added
	-- here, otherwise it will not be validated.  This should be considered bad.

	IF v_comp_prop.permit_component_type_id = 'REQUIRED' THEN
		IF NEW.component_type_id IS NULL THEN
			RAISE 'component_type_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_type_id = 'PROHIBITED' THEN
		IF NEW.component_type_id IS NOT NULL THEN
			RAISE 'component_type_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_component_function = 'REQUIRED' THEN
		IF NEW.component_function IS NULL THEN
			RAISE 'component_function is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_function = 'PROHIBITED' THEN
		IF NEW.component_function IS NOT NULL THEN
			RAISE 'component_function is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_component_id = 'REQUIRED' THEN
		IF NEW.component_id IS NULL THEN
			RAISE 'component_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_component_id = 'PROHIBITED' THEN
		IF NEW.component_id IS NOT NULL THEN
			RAISE 'component_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_type_id = 'REQUIRED' THEN
		IF NEW.slot_type_id IS NULL THEN
			RAISE 'slot_type_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_type_id = 'PROHIBITED' THEN
		IF NEW.slot_type_id IS NOT NULL THEN
			RAISE 'slot_type_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_function = 'REQUIRED' THEN
		IF NEW.slot_function IS NULL THEN
			RAISE 'slot_function is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_function = 'PROHIBITED' THEN
		IF NEW.slot_function IS NOT NULL THEN
			RAISE 'slot_function is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_comp_prop.permit_slot_id = 'REQUIRED' THEN
		IF NEW.slot_id IS NULL THEN
			RAISE 'slot_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_slot_id = 'PROHIBITED' THEN
		IF NEW.slot_id IS NOT NULL THEN
			RAISE 'slot_id is prohibited.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	--
	-- LHS population is verified; now validate any particular restrictions
	-- on individual values
	--

	--
	-- For slot_id, validate that the component_type, component_function,
	-- slot_type, and slot_function are all valid
	--
	IF NEW.slot_id IS NOT NULL AND COALESCE(
			v_comp_prop.required_component_type_id::text,
			v_comp_prop.required_component_function,
			v_comp_prop.required_slot_type_id::text,
			v_comp_prop.required_slot_function) IS NOT NULL THEN

		WITH x AS (
			SELECT
				component_type_id,
				array_agg(component_function) as component_function
			FROM
				component_type_component_func
			GROUP BY
				component_type_id
		) SELECT
			component_type_id,
			component_function,
			st.slot_type_id,
			slot_function
		INTO
			component_attrs
		FROM
			slot cs JOIN
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) JOIN
			component_type ct USING (component_type_id) LEFT JOIN
			x USING (component_type_id)
		WHERE
			slot_id = NEW.slot_id;

		IF v_comp_prop.required_component_type_id IS NOT NULL AND
				v_comp_prop.required_component_type_id !=
				component_attrs.component_type_id THEN
			RAISE 'component_type for slot_id must be % (is: %)',
					v_comp_prop.required_component_type_id,
					component_attrs.component_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for slot_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_slot_type_id IS NOT NULL AND
				v_comp_prop.required_slot_type_id !=
				component_attrs.slot_type_id THEN
			RAISE 'slot_type_id for slot_id must be % (is: %)',
					v_comp_prop.required_slot_type_id,
					component_attrs.slot_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_slot_function IS NOT NULL AND
				v_comp_prop.required_slot_function !=
				component_attrs.slot_function THEN
			RAISE 'slot_function for slot_id must be % (is: %)',
					v_comp_prop.required_slot_function,
					component_attrs.slot_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.slot_type_id IS NOT NULL AND 
			v_comp_prop.required_slot_function IS NOT NULL THEN

		SELECT
			slot_function
		INTO
			component_attrs
		FROM
			slot_type st
		WHERE
			slot_type_id = NEW.slot_type_id;

		IF v_comp_prop.required_slot_function !=
				component_attrs.slot_function THEN
			RAISE 'slot_function for slot_type_id must be % (is: %)',
					v_comp_prop.required_slot_function,
					component_attrs.slot_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.component_id IS NOT NULL AND COALESCE(
			v_comp_prop.required_component_type_id::text,
			v_comp_prop.required_component_function) IS NOT NULL THEN

		SELECT
			component_type_id,
			array_agg(component_function) as component_function
		INTO
			component_attrs
		FROM
			component c JOIN
			component_type_component_func ctcf USING (component_type_id)
		WHERE
			component_id = NEW.component_id
		GROUP BY
			component_type_id;

		IF v_comp_prop.required_component_type_id IS NOT NULL AND
				v_comp_prop.required_component_type_id !=
				component_attrs.component_type_id THEN
			RAISE 'component_type for component_id must be % (is: %)',
					v_comp_prop.required_component_type_id,
					component_attrs.component_type_id
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for component_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.component_type_id IS NOT NULL AND 
			v_comp_prop.required_component_function IS NOT NULL THEN

		SELECT
			component_type_id,
			array_agg(component_function) as component_function
		INTO
			component_attrs
		FROM
			component_type_component_func ctcf
		WHERE
			component_type_id = NEW.component_type_id
		GROUP BY
			component_type_id;

		IF v_comp_prop.required_component_function IS NOT NULL AND
				NOT (v_comp_prop.required_component_function =
					ANY(component_attrs.component_function)) THEN
			RAISE 'component_function for component_type_id must be % (is: %)',
					v_comp_prop.required_component_function,
					component_attrs.component_function
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
-- triggers on this function (if applicable)

-- DONE WITH proc validate_component_property -> validate_component_property 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE v_nblk_coll_netblock_expanded [908145]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_nblk_coll_netblock_expanded', 'v_nblk_coll_netblock_expanded');

CREATE OR REPLACE VIEW v_nblk_coll_netblock_expanded AS
WITH RECURSIVE var_recurse (
	level,
	root_collection_id,
	netblock_collection_id,
	child_netblock_collection_id,
	array_path,
	cycle
) as (
	SELECT	
		0				as level,
		u.netblock_collection_id		as root_collection_id, 
		u.netblock_collection_id		as netblock_collection_id, 
		u.netblock_collection_id		as child_netblock_collection_id,
		ARRAY[u.netblock_collection_id]	as array_path,
		false							as cycle
	  FROM	netblock_collection u
UNION ALL
	SELECT	
		x.level + 1			as level,
		x.netblock_collection_id		as root_netblock_collection_id, 
		uch.child_netblock_collection_id		as netblock_collection_id, 
		uch.child_netblock_collection_id	as child_netblock_collection_id,
		uch.child_netblock_collection_id ||
			x.array_path				as array_path,
		uch.child_netblock_collection_id =
			ANY(x.array_path)			as cycle

	  FROM	var_recurse x
		inner join netblock_collection_hier uch
			on x.child_netblock_collection_id =
				uch.netblock_collection_id
	WHERE	NOT x.cycle
) SELECT	distinct root_collection_id as netblock_collection_id,
		netblock_id as netblock_id
  from 		var_recurse
	join netblock_collection_netblock using (netblock_collection_id);

delete from __recreate where type = 'view' and object = 'v_nblk_coll_netblock_expanded';
GRANT ALL ON v_nblk_coll_netblock_expanded TO jazzhands;
GRANT INSERT,UPDATE,DELETE ON v_nblk_coll_netblock_expanded TO iud_role;
GRANT SELECT ON v_nblk_coll_netblock_expanded TO ro_role;
-- DONE DEALING WITH TABLE v_nblk_coll_netblock_expanded [900552]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DONE AUTOGEN DDL
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN validate_property
--------------------------------------------------------------------

/*
 * Copyright (c) 2011-2013 Matthew Ragan
 * Copyright (c) 2012-2015 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

CREATE OR REPLACE FUNCTION validate_property() RETURNS TRIGGER AS $$
DECLARE
	tally			integer;
	v_prop			VAL_Property%ROWTYPE;
	v_proptype		VAL_Property_Type%ROWTYPE;
	v_account_collection	account_collection%ROWTYPE;
	v_netblock_collection	netblock_collection%ROWTYPE;
	v_num			integer;
	v_listvalue		Property.Property_Value%TYPE;
BEGIN

	-- Pull in the data from the property and property_type so we can
	-- figure out what is and is not valid

	BEGIN
		SELECT * INTO STRICT v_prop FROM VAL_Property WHERE
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type;

		SELECT * INTO STRICT v_proptype FROM VAL_Property_Type WHERE
			Property_Type = NEW.Property_Type;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE EXCEPTION 
				'Property name or type does not exist'
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue.  That is, if only
	-- one value can be set for this property for a specific property LHS

	IF (v_prop.is_multivalue = 'N') THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			((Company_Id IS NULL AND NEW.Company_Id IS NULL) OR
				(Company_Id = NEW.Company_Id)) AND
			((Device_Collection_Id IS NULL AND NEW.Device_Collection_Id IS NULL) OR
				(Device_Collection_Id = NEW.Device_Collection_Id)) AND
			((DNS_Domain_Id IS NULL AND NEW.DNS_Domain_Id IS NULL) OR
				(DNS_Domain_Id = NEW.DNS_Domain_Id)) AND
			((Operating_System_Id IS NULL AND NEW.Operating_System_Id IS NULL) OR
				(Operating_System_Id = NEW.Operating_System_Id)) AND
			((operating_system_snapshot_id IS NULL AND NEW.operating_system_snapshot_id IS NULL) OR
				(operating_system_snapshot_id = NEW.operating_system_snapshot_id)) AND
			((service_env_collection_id IS NULL AND NEW.service_env_collection_id IS NULL) OR
				(service_env_collection_id = NEW.service_env_collection_id)) AND
			((Site_Code IS NULL AND NEW.Site_Code IS NULL) OR
				(Site_Code = NEW.Site_Code)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((Account_Realm_Id IS NULL AND NEW.Account_Realm_Id IS NULL) OR
				(Account_Realm_Id = NEW.Account_Realm_Id)) AND
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id)) AND
			((netblock_collection_Id IS NULL AND NEW.netblock_collection_Id IS NULL) OR
				(netblock_collection_Id = NEW.netblock_collection_Id)) AND
			((layer2_network_id IS NULL AND NEW.layer2_network_id IS NULL) OR
				(layer2_network_id = NEW.layer2_network_id)) AND
			((layer3_network_id IS NULL AND NEW.layer3_network_id IS NULL) OR
				(layer3_network_id = NEW.layer3_network_id)) AND
			((person_id IS NULL AND NEW.Person_id IS NULL) OR
				(Person_Id = NEW.person_id)) AND
			((property_collection_id IS NULL AND NEW.property_collection_id IS NULL) OR
				(property_collection_id = NEW.property_collection_id))
			;

		IF FOUND THEN
			RAISE EXCEPTION 
				'Property of type % already exists for given LHS and property is not multivalue',
				NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_proptype.is_multivalue = 'N') THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Type = NEW.Property_Type AND
			((Company_Id IS NULL AND NEW.Company_Id IS NULL) OR
				(Company_Id = NEW.Company_Id)) AND
			((Device_Collection_Id IS NULL AND NEW.Device_Collection_Id IS NULL) OR
				(Device_Collection_Id = NEW.Device_Collection_Id)) AND
			((DNS_Domain_Id IS NULL AND NEW.DNS_Domain_Id IS NULL) OR
				(DNS_Domain_Id = NEW.DNS_Domain_Id)) AND
			((Operating_System_Id IS NULL AND NEW.Operating_System_Id IS NULL) OR
				(Operating_System_Id = NEW.Operating_System_Id)) AND
			((operating_system_snapshot_id IS NULL AND NEW.operating_system_snapshot_id IS NULL) OR
				(operating_system_snapshot_id = NEW.operating_system_snapshot_id)) AND
			((service_env_collection_id IS NULL AND NEW.service_env_collection_id IS NULL) OR
				(service_env_collection_id = NEW.service_env_collection_id)) AND
			((Site_Code IS NULL AND NEW.Site_Code IS NULL) OR
				(Site_Code = NEW.Site_Code)) AND
			((Person_id IS NULL AND NEW.Person_id IS NULL) OR
				(Person_Id = NEW.Person_Id)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((Account_Realm_id IS NULL AND NEW.Account_Realm_id IS NULL) OR
				(Account_Realm_id = NEW.Account_Realm_id)) AND
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id)) AND
			((layer2_network_id IS NULL AND NEW.layer2_network_id IS NULL) OR
				(layer2_network_id = NEW.layer2_network_id)) AND
			((layer3_network_id IS NULL AND NEW.layer3_network_id IS NULL) OR
				(layer3_network_id = NEW.layer3_network_id)) AND
			((netblock_collection_Id IS NULL AND NEW.netblock_collection_Id IS NULL) OR
				(netblock_collection_Id = NEW.netblock_collection_Id)) AND
			((property_collection_Id IS NULL AND NEW.property_collection_Id IS NULL) OR
				(property_collection_Id = NEW.property_collection_Id))
		;

		IF FOUND THEN
			RAISE EXCEPTION 
				'Property % of type % already exists for given LHS and property type is not multivalue',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- now validate the property_value columns.
	tally := 0;

	--
	-- first determine if the property_value is set properly.
	--

	-- iterate over each of fk PROPERTY_VALUE columns and if a valid
	-- value is set, increment tally, otherwise raise an exception.
	IF NEW.Property_Value_Company_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'company_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Company_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Password_Type IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'password_type' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Password_Type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Token_Col_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'token_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Token_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_SW_Package_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'sw_package_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be SW_Package_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'account_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be account_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'netblock_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be nblk_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Timestamp IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'timestamp' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Timestamp' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_DNS_Domain_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'dns_domain_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be DNS_Domain_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Person_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'Person_Id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Person_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid.  Now, check the various options for
	-- PROPERTY_VALUE itself.  If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid.  If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification.  This should be considered bad.

	IF NEW.Property_Value IS NOT NULL THEN
		tally := tally + 1;
		IF v_prop.Property_Data_Type = 'boolean' THEN
			IF NEW.Property_Value != 'Y' AND NEW.Property_Value != 'N' THEN
				RAISE 'Boolean Property_Value must be Y or N' USING
					ERRCODE = 'invalid_parameter_value';
			END IF;
		ELSIF v_prop.Property_Data_Type = 'number' THEN
			BEGIN
				v_num := to_number(NEW.property_value, '9');
			EXCEPTION
				WHEN OTHERS THEN
					RAISE 'Property_Value must be numeric' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type = 'list' THEN
			BEGIN
				SELECT Valid_Property_Value INTO STRICT v_listvalue FROM 
					VAL_Property_Value WHERE
						Property_Name = NEW.Property_Name AND
						Property_Type = NEW.Property_Type AND
						Valid_Property_Value = NEW.Property_Value;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE 'Property_Value must be a valid value' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type != 'string' THEN
			RAISE 'Property_Data_Type is not a known type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_prop.Property_Data_Type != 'none' AND tally = 0 THEN
		RAISE 'One of the PROPERTY_VALUE fields must be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	IF tally > 1 THEN
		RAISE 'Only one of the PROPERTY_VALUE fields may be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	-- If the RHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-user), and verify that if so
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection 
					FROM account_collection WHERE
					account_collection_Id = NEW.Property_Value_Account_Coll_Id;
				IF v_account_collection.account_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Account_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a netblock_collection_ID, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection 
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.Property_Value_nblk_Coll_Id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_nblk_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- At this point, the RHS has been checked, so now we verify data
	-- set on the LHS

	-- There needs to be a stanza here for every "lhs".  If a new column is
	-- added to the property table, a new stanza needs to be added here,
	-- otherwise it will not be validated.  This should be considered bad.

	IF v_prop.Permit_Company_Id = 'REQUIRED' THEN
			IF NEW.Company_Id IS NULL THEN
				RAISE 'Company_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Company_Id = 'PROHIBITED' THEN
			IF NEW.Company_Id IS NOT NULL THEN
				RAISE 'Company_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Device_Collection_Id = 'REQUIRED' THEN
			IF NEW.Device_Collection_Id IS NULL THEN
				RAISE 'Device_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;

	ELSIF v_prop.Permit_Device_Collection_Id = 'PROHIBITED' THEN
			IF NEW.Device_Collection_Id IS NOT NULL THEN
				RAISE 'Device_Collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_DNS_Domain_Id = 'REQUIRED' THEN
			IF NEW.DNS_Domain_Id IS NULL THEN
				RAISE 'DNS_Domain_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_DNS_Domain_Id = 'PROHIBITED' THEN
			IF NEW.DNS_Domain_Id IS NOT NULL THEN
				RAISE 'DNS_Domain_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_service_env_collection = 'REQUIRED' THEN
			IF NEW.service_env_collection_id IS NULL THEN
				RAISE 'service_env_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_env_collection = 'PROHIBITED' THEN
			IF NEW.service_env_collection_id IS NOT NULL THEN
				RAISE 'service_environment is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Operating_System_Id = 'REQUIRED' THEN
			IF NEW.Operating_System_Id IS NULL THEN
				RAISE 'Operating_System_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Operating_System_Id = 'PROHIBITED' THEN
			IF NEW.Operating_System_Id IS NOT NULL THEN
				RAISE 'Operating_System_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_os_snapshot_id = 'REQUIRED' THEN
			IF NEW.operating_system_snapshot_id IS NULL THEN
				RAISE 'operating_system_snapshot_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_os_snapshot_id = 'PROHIBITED' THEN
			IF NEW.operating_system_snapshot_id IS NOT NULL THEN
				RAISE 'operating_system_snapshot_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Site_Code = 'REQUIRED' THEN
			IF NEW.Site_Code IS NULL THEN
				RAISE 'Site_Code is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Site_Code = 'PROHIBITED' THEN
			IF NEW.Site_Code IS NOT NULL THEN
				RAISE 'Site_Code is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Account_Id = 'REQUIRED' THEN
			IF NEW.Account_Id IS NULL THEN
				RAISE 'Account_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Account_Id = 'PROHIBITED' THEN
			IF NEW.Account_Id IS NOT NULL THEN
				RAISE 'Account_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Account_Realm_Id = 'REQUIRED' THEN
			IF NEW.Account_Realm_Id IS NULL THEN
				RAISE 'Account_Realm_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Account_Realm_Id = 'PROHIBITED' THEN
			IF NEW.Account_Realm_Id IS NOT NULL THEN
				RAISE 'Account_Realm_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_account_collection_Id = 'REQUIRED' THEN
			IF NEW.account_collection_Id IS NULL THEN
				RAISE 'account_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_account_collection_Id = 'PROHIBITED' THEN
			IF NEW.account_collection_Id IS NOT NULL THEN
				RAISE 'account_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_layer2_network_id = 'REQUIRED' THEN
			IF NEW.layer2_network_id IS NULL THEN
				RAISE 'layer2_network_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_layer2_network_id = 'PROHIBITED' THEN
			IF NEW.layer2_network_id IS NOT NULL THEN
				RAISE 'layer2_network_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_layer3_network_id = 'REQUIRED' THEN
			IF NEW.layer3_network_id IS NULL THEN
				RAISE 'layer3_network_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_layer3_network_id = 'PROHIBITED' THEN
			IF NEW.layer3_network_id IS NOT NULL THEN
				RAISE 'layer3_network_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_netblock_collection_Id = 'REQUIRED' THEN
			IF NEW.netblock_collection_Id IS NULL THEN
				RAISE 'netblock_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_netblock_collection_Id = 'PROHIBITED' THEN
			IF NEW.netblock_collection_Id IS NOT NULL THEN
				RAISE 'netblock_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_property_collection_Id = 'REQUIRED' THEN
			IF NEW.property_collection_Id IS NULL THEN
				RAISE 'property_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_property_collection_Id = 'PROHIBITED' THEN
			IF NEW.property_collection_Id IS NOT NULL THEN
				RAISE 'property_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Person_Id = 'REQUIRED' THEN
			IF NEW.Person_Id IS NULL THEN
				RAISE 'Person_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Person_Id = 'PROHIBITED' THEN
			IF NEW.Person_Id IS NOT NULL THEN
				RAISE 'Person_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Property_Rank = 'REQUIRED' THEN
			IF NEW.property_rank IS NULL THEN
				RAISE 'property_rank is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Property_Rank = 'PROHIBITED' THEN
			IF NEW.property_rank IS NOT NULL THEN
				RAISE 'property_rank is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_property ON Property;
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE 
	ON Property FOR EACH ROW EXECUTE PROCEDURE validate_property();


--------------------------------------------------------------------
-- END validate_property
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN redo account automated triggers
--------------------------------------------------------------------

DROP TRIGGER IF EXISTS trig_automated_ac ON account;
DROP FUNCTION IF EXISTS automated_ac();

DROP FUNCTION IF EXISTS acct_coll_manip.get_automated_account_collection_id(varchar);
DROP FUNCTION IF EXISTS acct_coll_manip.insert_or_delete_automated_ac(boolean, integer, integer[]);
DROP FUNCTION IF EXISTS acct_coll_manip.person_company_flags_to_automated_ac_name(varchar, varchar, OUT varchar, OUT varchar);
DROP FUNCTION IF EXISTS acct_coll_manip.person_gender_char_to_automated_ac_name(varchar);
DROP SCHEMA IF EXISTS acct_coll_manip;

DROP TRIGGER IF EXISTS trigger_update_account_type_account_collection ON account;
DROP FUNCTION IF EXISTS update_account_type_account_collection(); 


delete from property where property_type = 'auto_acct_coll';
delete from val_property_value where property_type = 'auto_acct_coll';
delete from val_property where property_type = 'auto_acct_coll';
delete from val_property_type where property_type = 'auto_acct_coll';

insert into val_property_type (
	property_type, is_multivalue,
	description
) values (
	'auto_acct_coll', 'Y',
	'properties that define how people are added to account collections automatically based on column changes'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'exempt', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'non_exempt', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'male', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'female', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'unspecified_gender', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'management', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'non_management', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'full_time', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'non_full_time', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'none',
	'N'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'account_type', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'PROHIBITED',
	'list',
	'N'
);

insert into val_property_value (
	property_name, property_type, valid_property_value
) values (
	'account_type', 'auto_acct_coll', 'person'
);

insert into val_property_value (
	property_name, property_type, valid_property_value
) values (
	'account_type', 'auto_acct_coll', 'pseudouser'
);

insert into val_property (
	property_name, property_type,
	permit_account_collection_id,
	permit_account_realm_id,
	permit_company_id,
	permit_site_code,
	property_data_type,
	is_multivalue
) values (
	'site', 'auto_acct_coll',
	'REQUIRED',
	'REQUIRED',
	'ALLOWED',
	'REQUIRED',
	'none',
	'N'
);


create or replace function _v60_add_person_company_ac(
	acname text, 
	propname text DEFAULT NULL,
	val text DEFAULT NULL
)
RETURNS void
AS
$$
BEGIN
	IF propname IS NULL THEN
		propname := acname;
	END IF;
	WITH acmap AS (
		select account_realm_id, company_id,
		array_to_string(ARRAY[account_realm_name, company_short_name,
			acname], '_') as company_ac
		from account_realm, company
	), ac AS (
		select	*
		from	account_collection ac
			join acmap on ac.account_collection_name = company_ac
		where	account_collection_type = 'automated'
	) insert into property (property_name, property_type, 
		account_realm_id, company_id,
		account_collection_id, property_value
	) select propname, 'auto_acct_coll', 
		account_realm_id, company_id,
		account_collection_id, val
	from ac;
END;
$$ LANGUAGE plpgsql;

create or replace function _v60_add_account_realm_ac(
	acname text, 
	propname text DEFAULT NULL,
	val text DEFAULT NULL
)
RETURNS void
AS
$$
BEGIN
	IF propname IS NULL THEN
		propname := acname;
	END IF;
	WITH acmap AS (
		select account_realm_id,
		array_to_string(ARRAY[account_realm_name, acname], '_') 
			as company_ac
		from account_realm
	), ac AS (
		select	*
		from	account_collection ac
			join acmap on ac.account_collection_name = company_ac
		where	account_collection_type = 'automated'
	) insert into property (property_name, property_type, 
		account_realm_id,
		account_collection_id, property_value
	) select propname, 'auto_acct_coll', 
		account_realm_id,
		account_collection_id, val
	from ac;
END;
$$ LANGUAGE plpgsql;

create or replace function _v60_add_sitecode_ac(
	propname text DEFAULT NULL,
	val text DEFAULT NULL
)
RETURNS void
AS
$$
BEGIN
	WITH acmap AS (
		select account_realm_id, site_code,
		array_to_string(ARRAY[account_realm_name, site_code], '_') 
			as company_ac
		from account_realm, site
	), ac AS (
		select	*
		from	account_collection ac
			join acmap on ac.account_collection_name = company_ac
		where	account_collection_type = 'automated'
	) insert into property (property_name, property_type, 
		account_realm_id, site_code,
		account_collection_id, property_value
	) select propname, 'auto_acct_coll', 
		account_realm_id, site_code,
		account_collection_id, val
	from ac;
END;
$$ LANGUAGE plpgsql;

select _v60_add_person_company_ac('exempt');
select _v60_add_person_company_ac('non_exempt');
select _v60_add_person_company_ac('male');
select _v60_add_person_company_ac('female');
select _v60_add_person_company_ac('unspecified_gender');
select _v60_add_person_company_ac('management');
select _v60_add_person_company_ac('non_management');
select _v60_add_person_company_ac('full_time');
select _v60_add_person_company_ac('non_full_time');

select _v60_add_person_company_ac('person', 'account_type', 'person');
select _v60_add_person_company_ac('pseudouser', 'account_type', 'pseudouser');

select _v60_add_account_realm_ac('person', 'account_type', 'person');
select _v60_add_account_realm_ac('pseudouser', 'account_type', 'pseudouser');

select _v60_add_sitecode_ac('site');

drop function IF EXISTS _v60_add_person_company_ac(text, text, text);
drop function IF EXISTS _v60_add_account_realm_ac(text, text, text);
drop function IF EXISTS _v60_add_sitecode_ac(text, text);

delete from account_collection_account where account_collection_id in (
	select account_collection_id from account_collection
	where account_collection_type = 'usertype'
);

delete from account_collection_hier where account_collection_id in (
	select account_collection_id from account_collection
	where account_collection_type = 'usertype'
);

delete from account_collection_hier where child_account_collection_id in (
	select account_collection_id from account_collection
	where account_collection_type = 'usertype'
);

delete from account_collection where 
	account_collection_type = 'usertype';

delete from val_account_collection_type where 
	account_collection_type IN ('usertype', 'company');

--------------------------------------------------------------------
-- DONE redo account automated triggers
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN dns_record_cname_checker search path
--------------------------------------------------------------------
alter function dns_record_cname_checker() set search_path=jazzhands;
--------------------------------------------------------------------
-- END dns_record_cname_checker search path
--------------------------------------------------------------------

DROP TRIGGER IF EXISTS trig_add_automated_ac_on_account ON account;
DROP TRIGGER IF EXISTS trig_rm_automated_ac_on_account ON account;
DROP TRIGGER IF EXISTS trig_automated_realm_site_ac_pl ON person_location;
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person ON person;
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person_company ON person_company;

CREATE TRIGGER trig_add_automated_ac_on_account AFTER INSERT OR UPDATE OF account_type, account_role ON account FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_account();
CREATE TRIGGER trig_rm_automated_ac_on_account BEFORE DELETE ON account FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_account();
CREATE TRIGGER trig_automated_realm_site_ac_pl AFTER INSERT OR DELETE OR UPDATE OF site_code, person_id ON person_location FOR EACH ROW EXECUTE PROCEDURE automated_realm_site_ac_pl();
CREATE TRIGGER trigger_automated_ac_on_person AFTER UPDATE OF gender ON person FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person();
CREATE TRIGGER trigger_automated_ac_on_person_company AFTER UPDATE OF is_management, is_exempt, is_full_time, person_id, company_id ON person_company FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person_company();

-------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_validate_device_component_assignment
	ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_validate_component_parent_slot_id
	ON slot;
DROP TRIGGER IF EXISTS trigger_validate_inter_component_connection
	ON inter_component_connection;
DROP TRIGGER IF EXISTS trigger_validate_component_rack_location
	ON jazzhands.component;
DROP TRIGGER IF EXISTS trigger_validate_component_property ON
	component_property;

CREATE CONSTRAINT TRIGGER trigger_validate_device_component_assignment
	AFTER INSERT OR UPDATE OF device_type_id, component_id
	ON jazzhands.device
	DEFERRABLE INITIALLY IMMEDIATE
 	FOR EACH ROW 
	EXECUTE PROCEDURE jazzhands.validate_device_component_assignment();
CREATE CONSTRAINT TRIGGER trigger_validate_asset_component_assignment
	AFTER INSERT OR UPDATE OF component_id
	ON asset
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW EXECUTE PROCEDURE validate_asset_component_assignment();
CREATE CONSTRAINT TRIGGER trigger_validate_component_parent_slot_id
	AFTER INSERT OR UPDATE OF parent_slot_id,component_type_id
	ON component
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE validate_component_parent_slot_id();
CREATE CONSTRAINT TRIGGER trigger_validate_inter_component_connection
	AFTER INSERT OR UPDATE
	ON inter_component_connection
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE validate_inter_component_connection();
CREATE CONSTRAINT TRIGGER trigger_validate_component_rack_location
	AFTER INSERT OR UPDATE OF rack_location_id
	ON component
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE validate_component_rack_location();
CREATE CONSTRAINT TRIGGER trigger_validate_component_property
	AFTER INSERT OR UPDATE
	ON component_property
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW EXECUTE PROCEDURE validate_component_property();

-------------------------------------------------------------------------


-- Processing tables with no structural changes
-- Some of these may be redundant
ALTER TABLE rack_location 
	DROP CONSTRAINT IF EXISTS ak_uq_rack_offset_sid_location;
ALTER TABLE ONLY rack_location
	ADD CONSTRAINT ak_uq_rack_offset_sid_location 
	UNIQUE (rack_id, rack_u_offset_of_device_top, rack_side);

ALTER TABLE RACK_LOCATION DROP CONSTRAINT IF EXISTS CKC_RACK_SIDE_LOCATION;
ALTER TABLE RACK_LOCATION
	ADD CONSTRAINT  CKC_RACK_SIDE_LOCATION CHECK (RACK_SIDE in ('FRONT','BACK'));


-- fk constraints
-- triggers

-- temporarily deal with device_type moving to component_type in the
-- next release

DO $$
DECLARE
	foo integer;
BEGIN
	select coalesce(max(device_type_id),0)+1 into foo from device_type;

	ALTER TABLE device_type ALTER COLUMN device_type_id
	SET DEFAULT nextval('component_type_component_type_id_seq'::regclass);

	EXECUTE
	'ALTER SEQUENCE component_type_component_type_id_seq START WITH ' ||
	foo;
	EXECUTE 'ALTER SEQUENCE component_type_component_type_id_seq restart';
END;
$$
;



-- Function arguments changed, so adjust the regrant
UPDATE __regrants SET regrant=
	regexp_replace(regrant, 'calculate_intermediate_netblocks\([^\)]+\)',
		'calculate_intermediate_netblocks(ip_block_1 inet, ip_block_2 inet, netblock_type text, ip_universe_id integer)');

UPDATE __regrants SET regrant=
	regexp_replace(regrant, 'person_manip.change_company\([^\)]+\)',
		'person_manip.change_company(final_company_id integer, _person_id integer, initial_company_id integer, _account_realm_id integer)');

INSERT INTO company_type (company_id, company_type)
	SELECT company_id, 'corporate family'
	FROM company
	WHERE is_corporate_family = 'Y'
	AND company_id NOT IN (
		SELECT company_id 
		FROM company_type 
		WHERE company_type = 'corporate family'
	)
; 

-- random comments
COMMENT ON SCHEMA audit IS 'part of jazzhands project';
COMMENT ON SCHEMA jazzhands IS 'http://sourceforge.net/projects/jazzhands/';
COMMENT ON SCHEMA device_utils IS 'part of jazzhands';
COMMENT ON SCHEMA net_manip IS 'part of jazzhands';
COMMENT ON SCHEMA netblock_utils IS 'part of jazzhands';
COMMENT ON SCHEMA network_strings IS 'part of jazzhands';
COMMENT ON SCHEMA person_manip IS 'part of jazzhands';
COMMENT ON SCHEMA port_support IS 'part of jazzhands';
COMMENT ON SCHEMA port_utils IS 'part of jazzhands';
COMMENT ON SCHEMA schema_support IS 'part of jazzhands';
COMMENT ON SCHEMA time_util IS 'part of jazzhands';
COMMENT ON SCHEMA physical_address_utils IS 'part of jazzhands';
-- random comments
COMMENT ON SCHEMA audit IS 'part of jazzhands project';
COMMENT ON SCHEMA jazzhands IS 'http://sourceforge.net/projects/jazzhands/';
COMMENT ON SCHEMA device_utils IS 'part of jazzhands';
COMMENT ON SCHEMA net_manip IS 'part of jazzhands';
COMMENT ON SCHEMA netblock_utils IS 'part of jazzhands';
COMMENT ON SCHEMA network_strings IS 'part of jazzhands';
COMMENT ON SCHEMA person_manip IS 'part of jazzhands';
COMMENT ON SCHEMA port_support IS 'part of jazzhands';
COMMENT ON SCHEMA port_utils IS 'part of jazzhands';
COMMENT ON SCHEMA schema_support IS 'part of jazzhands';
COMMENT ON SCHEMA time_util IS 'part of jazzhands';
COMMENT ON SCHEMA physical_address_utils IS 'part of jazzhands';

-- cleanup some random bits
update val_property_value 
	set description = replace(description, 'per-user', 'per-account')
	where property_name = 'UnixHomeType' 
	and property_type = 'MclassUnixProp'
	and description like '%per-user%';

-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;

select now();
SELECT schema_support.end_maintenance();
