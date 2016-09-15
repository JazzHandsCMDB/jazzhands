--
-- Copyright (c) 2016 Todd Kover
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

/*
Invoked:

	--suffix=v71
	--scan-tables
	--pre
	pre
	--pre
	../opensource/database/ddl/schema/pgsql/create_schema_support_tables.sql
	--post-first
	preauto
	--post
	../opensource/database/pkg/pgsql/backend_utils.sql
	--post
	../opensource/database/ddl//views/create_layer1_connection.sql
	--post
	../opensource/database/ddl//views/create_physical_port.sql
	--post
	../opensource/database/ddl//views/create_v_dev_col_user_prop_expanded.sql
	--post
	../opensource/database/ddl//views/pgsql/create_v_unix_group_overrides.sql
	--post
	../opensource/database/ddl//views/create_v_hotpants_account_attribute.sql
	--post
	../opensource/database/ddl//views/create_v_dns_changes_pending.sql
	--post
	../opensource/database/ddl//views/pgsql/create_v_unix_account_overrides.sql
	--post
	../opensource/database/ddl//views/create_v_hotpants_device_collection.sql
	--post
	post
	--first
	schema_support
	--reinsert-dir=./i
	x509_certificate:x509_signed_certificate
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();


-- BEGIN Misc that does not apply to above
DROP INDEX IF EXISTS ak_netblock_params;


-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above
/*
 * Copyright (c) 2016 Todd Kover
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


--
-- $HeadURL$
-- $Id$
--


-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'schema_support';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS schema_support;
		CREATE SCHEMA schema_support AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA schema_support IS 'part of jazzhands';

	END IF;
END;
$$;

--
-- These tables are meant to be used solely by schema_support functions.
--
CREATE TABLE schema_support.schema_audit_map (
	schema	text,
	audit_schema text,
	primary key(schema, audit_schema)
);

CREATE TABLE schema_support.mv_refresh (
	schema	text,
	view 	text,
	refresh	timestamp,
	primary key(schema, view)
);


CREATE TABLE schema_support.schema_version (
	schema	text,
	version	text,
	primary key(schema)
);


-- END Misc that does not apply to above
CREATE SCHEMA backend_utils AUTHORIZATION jazzhands;
--
-- Process middle (non-trigger) schema jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_automated_reporting_ac');
CREATE OR REPLACE FUNCTION jazzhands.account_automated_reporting_ac()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_numrpt	INTEGER;
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

	-- XXX check account realm to see if we should be inserting for this
	-- XXX account realm

	IF TG_OP = 'INSERT' THEN
		PERFORM auto_ac_manip.make_all_auto_acs_right(
			account_id := NEW.account_id,
			account_realm_id := NEW.account_realm_id,
			login := NEW.login
		);
	ELSIF TG_OP = 'UPDATE' THEN
		PERFORM auto_ac_manip.rename_automated_report_acs(
			NEW.account_id, OLD.login, NEW.login, NEW.account_realm_id);
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM account_collection_account WHERE account_id
			= OLD.account_id
		AND account_collection_id IN ( select account_collection_id
			FROM account_collection where account_collection_type
			= 'automated'
		);
		-- PERFORM auto_ac_manip.destroy_report_account_collections(
		-- 	account_id := OLD.account_id,
		-- 	account_realm_id := OLD.account_realm_id
		-- );
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_change_realm_aca_realm');
CREATE OR REPLACE FUNCTION jazzhands.account_change_realm_aca_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account_collection USING (account_collection_id)
			JOIN val_account_collection_type vt USING (account_collection_type)
	WHERE	vt.account_realm_id IS NOT NULL
	AND		vt.account_realm_id != NEW.account_realm_id
	AND		account_id = NEW.account_id;

	IF _tally > 0 THEN
		RAISE EXCEPTION 'New account realm (%) is part of % account collections with a type restriction',
			NEW.account_realm_id,
			_tally
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_collection_account_realm');
CREATE OR REPLACE FUNCTION jazzhands.account_collection_account_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_a	account%ROWTYPE;
	_at	val_account_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	_at
	FROM	val_account_collection_type
		JOIN account_collection USING (account_collection_type)
	WHERE
		account_collection_id = NEW.account_collection_id;

	-- no restrictions, so do not care
	IF _at.account_realm_id IS NULL THEN
		RETURN NEW;
	END IF;

	-- check to see if the account's account realm matches
	IF TG_OP = 'INSERT' OR OLD.account_id != NEW.account_id THEN
		SELECT	*
		INTO	_a
		FROM	account
		WHERE	account_id = NEW.account_id;

		IF _a.account_realm_id != _at.account_realm_id THEN
			RAISE EXCEPTION 'account realm of % does not match account realm restriction on account_collection %',
				NEW.account_id, NEW.account_collection_id
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_instance_step_auto_complete');
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_step_auto_complete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	--
	-- on insert, if the parent was already marked as completed, fail.
	-- arguably, this should happen on updates as well
	--	possibly should move this to a before trigger
	--
	IF TG_OP = 'INSERT' THEN
		SELECT	count(*)
		INTO	_tally
		FROM	approval_instance_step
		WHERE	approval_instance_step_id = NEW.approval_instance_step_id
		AND		is_completed = 'Y';

		IF _tally > 0 THEN
			RAISE EXCEPTION 'Completed attestation cycles may not have items added';
		END IF;
	END IF;

	IF NEW.is_approved IS NOT NULL THEN
		SELECT	count(*)
		INTO	_tally
		FROM	approval_instance_item
		WHERE	approval_instance_step_id = NEW.approval_instance_step_id
		AND		approval_instance_item_id != NEW.approval_instance_item_id
		AND		is_approved IS NOT NULL;

		IF _tally = 0 THEN
			UPDATE	approval_instance_step
			SET		is_completed = 'Y',
					approval_instance_step_end = now()
			WHERE	approval_instance_step_id = NEW.approval_instance_step_id;
		END IF;

	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_account');
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


	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(NEW.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(NEW.account_id);

		-- update the person's manager to match
		WITH RECURSIVE map AS (
			SELECT account_id as root_account_id,
				account_id, login, manager_account_id, manager_login
			FROM v_account_manager_map
			UNION
			SELECT map.root_account_id, m.account_id, m.login,
				m.manager_account_id, m.manager_login
				from v_account_manager_map m
					join map on m.account_id = map.manager_account_id
			), x AS ( SELECT auto_ac_manip.make_auto_report_acs_right(
					account_id := manager_account_id,
					account_realm_id := NEW.account_realm_id,
					login := manager_login)
				FROM map
				WHERE root_account_id = NEW.account_id
			) SELECT count(*) INTO _tally FROM x;
	END IF;

	IF TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(OLD.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(OLD.account_id);
	END IF;

	-- when deleting, do nothing rather than calling the above, same as
	-- update; pointless because account is getting deleted anyway.

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_person_company');
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
	IF ( TG_OP = 'INSERT' OR TG_OP = 'UPDATE' ) THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id
		AND		company_id = NEW.company_id;

		IF ( TG_OP = 'INSERT' OR ( TG_OP = 'UPDATE' AND
				NEW.manager_person_id != OLD.manager_person_id )
		) THEN
			-- update the person's manager to match
			WITH RECURSIVE map As (
				SELECT account_id as root_account_id,
					account_id, login, manager_account_id, manager_login
				FROM v_account_manager_map
				UNION
				SELECT map.root_account_id, m.account_id, m.login,
					m.manager_account_id, m.manager_login
					from v_account_manager_map m
						join map on m.account_id = map.manager_account_id
			), x AS ( SELECT auto_ac_manip.make_auto_report_acs_right(
						account_id := manager_account_id,
						account_realm_id := account_realm_id,
						login := manager_login)
					FROM map m
							join v_corp_family_account a ON
								a.account_id = m.root_account_id
					WHERE a.person_id = NEW.person_id
					AND a.company_id = NEW.company_id
			) SELECT count(*) into _tally from x;
			IF TG_OP = 'UPDATE' THEN
				PERFORM auto_ac_manip.make_auto_report_acs_right(
							account_id := account_id)
				FROM    v_corp_family_account
				WHERE   account_role = 'primary'
				AND     is_enabled = 'Y'
				AND     person_id = OLD.manager_person_id;
			END IF;
		END IF;
	END IF;

	IF ( TG_OP = 'DELETE' OR TG_OP = 'UPDATE' ) THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = OLD.person_id
		AND		company_id = OLD.company_id;
	END IF;
	IF ( TG_OP = 'UPDATE' ) THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id
		AND		company_id = NEW.company_id;
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'check_svcenv_colllection_hier_loop');
CREATE OR REPLACE FUNCTION jazzhands.check_svcenv_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.service_env_collection_id =
		NEW.child_service_env_coll_id THEN
			RAISE EXCEPTION 'svcenv Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'create_device_component_by_trigger');
CREATE OR REPLACE FUNCTION jazzhands.create_device_component_by_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	devtype		RECORD;
	ctid		integer;
	cid			integer;
	scarr       integer[];
	dcarr       integer[];
	server_ver	integer;
BEGIN

	SELECT
		dt.device_type_id,
		dt.component_type_id,
		dt.template_device_id,
		d.component_id
	INTO
		devtype
	FROM
		device_type dt LEFT JOIN
		device d ON (dt.template_device_id = d.device_id)
	WHERE
		dt.device_type_id = NEW.device_type_id;

	IF NEW.component_id IS NOT NULL THEN
		IF devtype.component_type_id IS NOT NULL THEN
			SELECT
				component_type_id INTO ctid
			FROM
				component c
			WHERE
				c.component_id = NEW.component_id;

			IF ctid != devtype.component_type_id THEN
				UPDATE
					component
				SET
					component_type_id = devtype.component_type_id
				WHERE
					component_id = NEW.component_id;
			END IF;
		END IF;

		RETURN NEW;
	END IF;

	--
	-- If template_device_id doesn't exist, then create an instance of
	-- the component_id if it exists
	--
	IF devtype.component_id IS NULL THEN
		--
		-- If the component_id doesn't exist, then we're done
		--
		IF devtype.component_type_id IS NULL THEN
			RETURN NEW;
		END IF;
		--
		-- Insert a component of the given type and tie it to the device
		--
		INSERT INTO component (component_type_id)
			VALUES (devtype.component_type_id)
			RETURNING component_id INTO cid;

		NEW.component_id := cid;
		RETURN NEW;
	ELSE
		SELECT setting INTO server_ver FROM pg_catalog.pg_settings
			WHERE name = 'server_version_num';

		IF (server_ver < 90400) THEN
			--
			-- This is pretty nasty; welcome to SQL
			--
			--
			-- This returns data into a temporary table (ugh) that's used as a
			-- key/value store to map each template component to the
			-- newly-created one
			--
			CREATE TEMPORARY TABLE trig_comp_ins AS
			WITH comp_ins AS (
				INSERT INTO component (
					component_type_id
				) SELECT
					c.component_type_id
				FROM
					device_type dt JOIN
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				WHERE
					device_type_id = NEW.device_type_id
				ORDER BY
					level, c.component_type_id
				RETURNING component_id
			)
			SELECT
				src_comp.component_id as src_component_id,
				dst_comp.component_id as dst_component_id,
				src_comp.level as level
			FROM
				(SELECT
					c.component_id,
					level,
					row_number() OVER (ORDER BY level, c.component_type_id)
						AS rownum
				 FROM
					device_type dt JOIN
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				 WHERE
					device_type_id = NEW.device_type_id
				) src_comp,
				(SELECT
					component_id,
					row_number() OVER () AS rownum
				 FROM
					comp_ins
				) dst_comp
			WHERE
				src_comp.rownum = dst_comp.rownum;

			/*
				 Now take the mapping of components that were inserted above,
				 and tie the new components to the appropriate slot on the
				 parent.
				 The logic below is:
					- Take the template component, and locate its parent slot
					- Find the correct slot on the corresponding new parent
					  component by locating one with the same slot_name and
					  slot_type_id on the mapped parent component_id
					- Update the parent_slot_id of the component with the
					  mapped component_id to this slot_id

				 This works even if the top-level component is attached to some
				 other device, since there will not be a mapping for those in
				 the table to locate.
			*/

			UPDATE
				component dc
			SET
				parent_slot_id = ds.slot_id
			FROM
				trig_comp_ins tt,
				trig_comp_ins ptt,
				component sc,
				slot ss,
				slot ds
			WHERE
				tt.src_component_id = sc.component_id AND
				tt.dst_component_id = dc.component_id AND
				ss.slot_id = sc.parent_slot_id AND
				ss.component_id = ptt.src_component_id AND
				ds.component_id = ptt.dst_component_id AND
				ss.slot_type_id = ds.slot_type_id AND
				ss.slot_name = ds.slot_name;

			SELECT dst_component_id INTO cid FROM trig_comp_ins WHERE
				level = 1;

			NEW.component_id := cid;

			DROP TABLE trig_comp_ins;

			RETURN NEW;
		ELSE
			WITH dev_comps AS (
				SELECT
					c.component_id,
					c.component_type_id,
					level,
					row_number() OVER (ORDER BY level, c.component_type_id) AS
						rownum
				FROM
					device_type dt JOIN
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				WHERE
					device_type_id = NEW.device_type_id
			),
			comp_ins AS (
				INSERT INTO component (
					component_type_id
				) SELECT
					component_type_id
				FROM
					dev_comps
				ORDER BY
					rownum
				RETURNING component_id, component_type_id
			),
			comp_ins_arr AS (
				SELECT
					array_agg(component_id) AS dst_arr
				FROM
					comp_ins
			),
			dev_comps_arr AS (
				SELECT
					array_agg(component_id) as src_arr
				FROM
					dev_comps
			)
			SELECT src_arr, dst_arr INTO scarr, dcarr FROM
				dev_comps_arr, comp_ins_arr;

			UPDATE
				component dc
			SET
				parent_slot_id = ds.slot_id
			FROM
				unnest(scarr, dcarr) AS
					tt(src_component_id, dst_component_id),
				unnest(scarr, dcarr) AS
					ptt(src_component_id, dst_component_id),
				component sc,
				slot ss,
				slot ds
			WHERE
				tt.src_component_id = sc.component_id AND
				tt.dst_component_id = dc.component_id AND
				ss.slot_id = sc.parent_slot_id AND
				ss.component_id = ptt.src_component_id AND
				ds.component_id = ptt.dst_component_id AND
				ss.slot_type_id = ds.slot_type_id AND
				ss.slot_name = ds.slot_name;

			SELECT
				component_id INTO NEW.component_id
			FROM
				component c
			WHERE
				component_id = ANY(dcarr) AND
				parent_slot_id IS NULL;

			RETURN NEW;
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'create_new_unix_account');
CREATE OR REPLACE FUNCTION jazzhands.create_new_unix_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	unix_id 		INTEGER;
	_account_collection_id 	INTEGER;
	_arid			INTEGER;
BEGIN
	--
	-- This should be a property that shows which account collections
	-- get unix accounts created by default, but the mapping of unix-groups
	-- to account collection across realms needs to be resolved
	--
	SELECT  account_realm_id
	INTO    _arid
	FROM    property
	WHERE   property_name = '_root_account_realm_id'
	AND     property_type = 'Defaults';

	IF _arid IS NOT NULL AND NEW.account_realm_id = _arid THEN
		IF NEW.person_id != 0 THEN
			PERFORM person_manip.setup_unix_account(
				in_account_id := NEW.account_id,
				in_account_type := NEW.account_type
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type_model_to_name');
CREATE OR REPLACE FUNCTION jazzhands.device_type_model_to_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND  (NEW.model IS DISTINCT FROM OLD.model AND
			NEW.device_type_name IS DISTINCT FROM OLD.device_type_name) THEN
		RAISE EXCEPTION 'Only device_type_name should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.model IS NOT NULL AND NEW.device_type_name IS NOT NULL THEN
			RAISE EXCEPTION 'Only model should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.model IS DISTINCT FROM NEW.model THEN
			NEW.device_type_name = NEW.model;
		ELSIF OLD.device_type_name IS DISTINCT FROM NEW.device_type_name THEN
			NEW.model = NEW.device_type_name;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.model IS NOT NULL THEN
			NEW.device_type_name = NEW.model;
		ELSIF NEW.device_type_name IS NOT NULL THEN
			NEW.model = NEW.device_type_name;
		END IF;
	ELSE
	END IF;

	-- company_id is going away
	IF NEW.company_id IS NULL THEN
		NEW.company_id := 0;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_a_rec_validation');
CREATE OR REPLACE FUNCTION jazzhands.dns_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_ip		netblock.ip_address%type;
	_sing	netblock.is_single_address%type;
BEGIN
	IF NEW.dns_type in ('A', 'AAAA') AND NEW.netblock_id IS NULL THEN
		RAISE EXCEPTION 'Attempt to set % record without a Netblock',
			NEW.dns_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	IF NEW.netblock_Id is not NULL and
			( NEW.dns_value IS NOT NULL OR NEW.dns_value_record_id IS NOT NULL ) THEN
		RAISE EXCEPTION 'Both dns_value and netblock_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	IF NEW.dns_value IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both dns_value and dns_value_record_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	IF NEW.netblock_id IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both netblock_id and dns_value_record_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	-- XXX need to deal with changing a netblock type and breaking dns_record..
	IF NEW.netblock_id IS NOT NULL THEN
		SELECT ip_address, is_single_address
		  INTO _ip, _sing
		  FROM netblock
		 WHERE netblock_id = NEW.netblock_id;

		IF NEW.dns_type = 'A' AND family(_ip) != '4' THEN
			RAISE EXCEPTION 'A records must be assigned to non-IPv4 records'
				USING ERRCODE = 'JH200';
		END IF;

		IF NEW.dns_type = 'AAAA' AND family(_ip) != '6' THEN
			RAISE EXCEPTION 'AAAA records must be assigned to non-IPv6 records'
				USING ERRCODE = 'JH200';
		END IF;

		IF _sing = 'N' AND NEW.dns_type IN ('A','AAAA') THEN
			RAISE EXCEPTION 'Non-single addresses may not have % records', NEW.dns_type
				USING ERRCODE = 'foreign_key_violation';
		END IF;

	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_trigger_change');
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_trigger_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF new.SHOULD_GENERATE = 'Y' THEN
		insert into DNS_CHANGE_RECORD
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_rec_prevent_dups');
CREATE OR REPLACE FUNCTION jazzhands.dns_rec_prevent_dups()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	-- should not be able to insert the same record(s) twice
	SELECT	count(*)
	  INTO	_tally
	  FROM	dns_record
	  WHERE
	  		( lower(dns_name) = lower(NEW.dns_name) OR
				(dns_name IS NULL AND NEW.dns_name is NULL)
			)
		AND
	  		( dns_domain_id = NEW.dns_domain_id )
		AND
	  		( dns_class = NEW.dns_class )
		AND
	  		( dns_type = NEW.dns_type )
		AND
	  		( dns_srv_service = NEW.dns_srv_service OR
				(dns_srv_service IS NULL and NEW.dns_srv_service is NULL)
			)
		AND
	  		( dns_srv_protocol = NEW.dns_srv_protocol OR
				(dns_srv_protocol IS NULL and NEW.dns_srv_protocol is NULL)
			)
		AND
	  		( dns_srv_port = NEW.dns_srv_port OR
				(dns_srv_port IS NULL and NEW.dns_srv_port is NULL)
			)
		AND
	  		( dns_value = NEW.dns_value OR
				(dns_value IS NULL and NEW.dns_value is NULL)
			)
		AND
	  		( netblock_id = NEW.netblock_id OR
				(netblock_id IS NULL AND NEW.netblock_id is NULL)
			)
		AND	is_enabled = 'Y'
	    AND dns_record_id != NEW.dns_record_id
	;

	IF _tally != 0 THEN
		RAISE EXCEPTION 'Attempt to insert the same dns record'
			USING ERRCODE = 'unique_violation';
	END IF;

	IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
		IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
			SELECT	count(*)
			 INTO	_tally
			 FROM	dns_record
			WHERE dns_class = 'IN'
			AND dns_type = 'A'
			AND should_generate_ptr = 'Y'
			AND is_enabled = 'Y'
			AND netblock_id = NEW.NETBLOCK_ID
			AND dns_record_id != NEW.DNS_RECORD_ID;

			IF _tally != 0 THEN
				RAISE EXCEPTION 'May not have more than one SHOULD_GENERATE_PTR record on the same IP on netblock_id %', NEW.netblock_id
					USING ERRCODE = 'JH201';
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_cname_checker');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_cname_checker()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_dom	TEXT;
BEGIN
	_tally := 0;
	IF TG_OP = 'INSERT' OR NEW.DNS_TYPE != OLD.DNS_TYPE THEN
		IF NEW.DNS_TYPE = 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
			SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
				 		NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
				 		NEW.dns_domain_id = x.dns_domain_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		-- this clause is basically the same as above except = 'CANME'
		ELSIF NEW.DNS_TYPE != 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		END IF;
	END IF;

	IF _tally > 0 THEN
		SELECT soa_name INTO _dom FROM dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id ;

		if NEW.dns_name IS NULL THEN
			RAISE EXCEPTION '% may not have CNAME and other records (%)',
				_dom, _tally
				USING ERRCODE = 'unique_violation';
		ELSE
			RAISE EXCEPTION '%.% may not have CNAME and other records (%)',
				NEW.dns_name, _dom, _tally
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_update_nontime');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_update_nontime()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_dnsdomainid	DNS_DOMAIN.DNS_DOMAIN_ID%type;
	_ipaddr			NETBLOCK.IP_ADDRESS%type;
	_mkold			boolean;
	_mknew			boolean;
	_mkdom			boolean;
	_mkip			boolean;
BEGIN
	_mkold = false;
	_mkold = false;
	_mknew = true;

	IF TG_OP = 'DELETE' THEN
		_mknew := false;
		_mkold := true;
		_mkdom := true;
		if  OLD.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		_mkold := false;
		_mkdom := true;
		if  NEW.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.DNS_DOMAIN_ID != NEW.DNS_DOMAIN_ID THEN
			_mkold := true;
			_mkip := true;
		END IF;
		_mkdom := true;

		IF OLD.dns_name IS DISTINCT FROM NEW.dns_name THEN
			_mknew := true;
			IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
				IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
					_mkip := true;
				END IF;
			END IF;
		END IF;

		IF OLD.SHOULD_GENERATE_PTR != NEW.SHOULD_GENERATE_PTR THEN
			_mkold := true;
			_mkip := true;
		END IF;

		IF (OLD.netblock_id IS DISTINCT FROM NEW.netblock_id) THEN
			_mkold := true;
			_mknew := true;
			_mkip := true;
		END IF;
	END IF;

	if _mkold THEN
		IF _mkdom THEN
			_dnsdomainid := OLD.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and OLD.netblock_id is not NULL THEN
			SELECT	ip_address
			  INTO	_ipaddr
			  FROM	netblock
			 WHERE	netblock_id  = OLD.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	if _mknew THEN
		if _mkdom THEN
			_dnsdomainid := NEW.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and NEW.netblock_id is not NULL THEN
			SELECT	ip_address
			  INTO	_ipaddr
			  FROM	netblock
			 WHERE	netblock_id  = NEW.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	IF TG_OP = 'DELETE' THEN
		return OLD;
	END IF;
	return NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'fix_person_image_oid_ownership');
CREATE OR REPLACE FUNCTION jazzhands.fix_person_image_oid_ownership()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
   b	integer;
   str	varchar;
BEGIN
	b := NEW.image_blob;
	BEGIN
		str := 'GRANT SELECT on LARGE OBJECT ' || b || ' to picture_image_ro';
		EXECUTE str;
		str :=  'GRANT UPDATE on LARGE OBJECT ' || b || ' to picture_image_rw';
		EXECUTE str;
	EXCEPTION WHEN OTHERS THEN
		RAISE NOTICE 'Unable to grant on %', b;
	END;

	BEGIN
		EXECUTE 'ALTER large object ' || b || ' owner to jazzhands';
	EXCEPTION WHEN OTHERS THEN
		RAISE NOTICE 'Unable to adjust ownership of %', b;
	END;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'net_int_physical_id_to_slot_id_enforce');
CREATE OR REPLACE FUNCTION jazzhands.net_int_physical_id_to_slot_id_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND  (NEW.slot_id IS DISTINCT FROM OLD.slot_ID AND
			NEW.physical_port_id IS DISTINCT FROM OLD.physical_port_id) THEN
		RAISE EXCEPTION 'Only slot_id should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.physical_port_id IS NOT NULL AND NEW.slot_id IS NOT NULL THEN
			RAISE EXCEPTION 'Only slot_id should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.slot_id IS DISTINCT FROM NEW.slot_id THEN
			NEW.physical_port_id = NEW.slot_id;
		ELSIF OLD.physical_port_id IS DISTINCT FROM NEW.physical_port_id THEN
			NEW.slot_id = NEW.physical_port_id;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.slot_id IS NOT NULL THEN
			NEW.physical_port_id = NEW.slot_id;
		ELSIF NEW.physical_port_id IS NOT NULL THEN
			NEW.slot_id = NEW.physical_port_id;
		END IF;
	ELSE
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'phys_conn_physical_id_to_slot_id_enforce');
CREATE OR REPLACE FUNCTION jazzhands.phys_conn_physical_id_to_slot_id_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND
		((NEW.slot1_id IS DISTINCT FROM OLD.slot1_ID AND
			NEW.physical_port1_id IS DISTINCT FROM OLD.physical_port1_id) OR
		(NEW.slot2_id IS DISTINCT FROM OLD.slot2_ID AND
			NEW.physical_port2_id IS DISTINCT FROM OLD.physical_port2_id))
	THEN
		RAISE EXCEPTION 'Only slot1_id OR slot2_id should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF (NEW.physical_port1_id IS NOT NULL AND NEW.slot1_id IS NOT NULL) OR
			(NEW.physical_port2_id IS NOT NULL AND NEW.slot2_id IS NOT NULL)
		THEN
			RAISE EXCEPTION 'Only slot1_id OR slot2_id should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.slot1_id IS DISTINCT FROM NEW.slot1_id THEN
			NEW.physical_port1_id = NEW.slot1_id;
		ELSIF OLD.physical_port1_id IS DISTINCT FROM NEW.physical_port1_id THEN
			NEW.slot1_id = NEW.physical_port1_id;
		END IF;
		IF OLD.slot2_id IS DISTINCT FROM NEW.slot2_id THEN
			NEW.physical_port2_id = NEW.slot2_id;
		ELSIF OLD.physical_port2_id IS DISTINCT FROM NEW.physical_port2_id THEN
			NEW.slot2_id = NEW.physical_port2_id;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.slot1_id IS NOT NULL THEN
			NEW.physical_port1_id = NEW.slot_id;
		ELSIF NEW.physical_port1_id IS NOT NULL THEN
			NEW.slot1_id = NEW.physical_port1_id;
		END IF;
		IF NEW.slot2_id IS NOT NULL THEN
			NEW.physical_port2_id = NEW.slot_id;
		ELSIF NEW.physical_port2_id IS NOT NULL THEN
			NEW.slot2_id = NEW.physical_port2_id;
		END IF;
	ELSE
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'property_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.property_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	pct	val_property_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	pct
	FROM	val_property_collection_type
	WHERE	property_collection_type =
		(select property_collection_type from property_collection
			where property_collection_id = NEW.property_collection_id);

	IF pct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from property_collection_property
		  where property_collection_id = NEW.property_collection_id;
		IF tally > pct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF pct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from property_collection_property
		  		inner join property_collection using (property_collection_id)
		  where
				property_name = NEW.property_name
		  and	property_type = NEW.property_type
		  and	property_collection_type = pct.property_collection_type;
		IF tally > pct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Property may not be a member of more than % collections of type %',
				pct.MAX_NUM_COLLECTIONS, pct.property_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_coll_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.service_environment_coll_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	svcenvt	val_service_env_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	svcenvt
	FROM	val_service_env_coll_type
	WHERE	service_env_collection_type =
		(select service_env_collection_type
			from service_environment_collection
			where service_env_collection_id =
				NEW.service_env_collection_id);

	IF svcenvt.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Service Environment Collections of type % may not be hierarcical',
			svcenvt.service_env_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.service_environment_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	svcenvt	val_service_env_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	svcenvt
	FROM	val_service_env_coll_type
	WHERE	service_env_collection_type =
		(select service_env_collection_type
			from service_environment_collection
			where service_env_collection_id =
				NEW.service_env_collection_id);

	IF svcenvt.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from svc_environment_coll_svc_env
		  where service_env_collection_id = NEW.service_env_collection_id;
		IF tally > svcenvt.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF svcenvt.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from svc_environment_coll_svc_env
		  		inner join service_environment_collection
					USING (service_env_collection_id)
		  where service_environment_id = NEW.service_environment_id
		  and	service_env_collection_type =
					svcenvt.service_env_collection_type;
		IF tally > svcenvt.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Service Environment may not be a member of more than % collections of type %',
				svcenvt.MAX_NUM_COLLECTIONS, svcenvt.service_env_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'upd_v_corp_family_account');
CREATE OR REPLACE FUNCTION jazzhands.upd_v_corp_family_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
	setstr		TEXT;
	_r		RECORD;
	val		TEXT;
BEGIN
	SELECT	account_realm_id
	INTO	acct_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND	property_type = 'Defaults';

	IF acct_realm_id != OLD.account_realm_id OR
			acct_realm_id != NEW.account_realm_id THEN
		RAISE EXCEPTION 'Invalid account_realm_id'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	setstr = '';
	FOR _r IN SELECT * FROM json_each_text( row_to_json(NEW) )
	LOOP
		IF _r.key NOT SIMILAR TO 'data_(ins|upd)_(user|date)' THEN
			EXECUTE 'SELECT ' || _r.key ||' FROM account
				WHERE account_id = ' || OLD.account_id
				INTO val;
			IF ( _r.value IS NULL  AND val IS NOT NULL) OR
				( _r.value IS NOT NULL AND val IS NULL) OR
				(_r.value::text NOT SIMILAR TO val::text) THEN
				-- RAISE NOTICE 'Changing %: "%" to "%"', _r.key, val, _r.value;
				IF char_length(setstr) > 0 THEN
					setstr = setstr || ',
					';
				END IF;
				IF _r.value IS NOT  NULL THEN
					setstr = setstr || _r.key || ' = ' ||
						quote_nullable(_r.value) || ' ' ;
				ELSE
					setstr = setstr || _r.key || ' = ' ||
						' NULL ' ;
				END IF;
			END IF;
		END IF;
	END LOOP;


	IF char_length(setstr) > 0 THEN
		setstr = 'UPDATE account SET ' || setstr || '
			WHERE	account_id = ' || OLD.account_id;
		-- RAISE NOTICE 'executing %', setstr;
		EXECUTE setstr;
	END IF;
	RETURN NEW;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_per_svc_env_svc_env_collection');
CREATE OR REPLACE FUNCTION jazzhands.update_per_svc_env_svc_env_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	secid		service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	IF TG_OP = 'INSERT' THEN
		insert into service_environment_collection
			(service_env_collection_name, service_env_collection_type)
		values
			(NEW.service_environment_name, 'per-environment')
		RETURNING service_env_collection_id INTO secid;
		insert into svc_environment_coll_svc_env
			(service_env_collection_id, service_environment_id)
		VALUES
			(secid, NEW.service_environment_id);
	ELSIF TG_OP = 'UPDATE'  AND OLD.service_environment_id != NEW.service_environment_id THEN
		UPDATE	service_environment_collection
		   SET	service_env_collection_name = NEW.service_environment_name
		 WHERE	service_env_collection_name != NEW.service_environment_name
		   AND	service_env_collection_type = 'per-environment'
		   AND	service_environment_id in (
			SELECT	service_environment_id
			  FROM	svc_environment_coll_svc_env
			 WHERE	service_environment_id =
				NEW.service_environment_id
			);
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_component_parent_slot_id');
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
		slot_type_prmt_comp_slot_type stpcst USING (slot_type_id) JOIN
		component_type ct ON (stpcst.component_slot_type_id = ct.slot_type_id)
	WHERE
		ct.component_type_id = NEW.component_type_id AND
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

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_component_property');
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
	v_num				bigint;
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
						component_property_name = NEW.component_property_name AND
						component_property_type = NEW.component_property_type AND
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

	IF v_comp_prop.permit_intcomp_conn_id = 'REQUIRED' THEN
		IF NEW.inter_component_connection_id IS NULL THEN
			RAISE 'inter_component_connection_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_intcomp_conn_id = 'PROHIBITED' THEN
		IF NEW.inter_component_connection_id IS NOT NULL THEN
			RAISE 'inter_component_connection_id is prohibited.'
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

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_device_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_device_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.device_collection_type != NEW.device_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.device_collection_type = OLD.device_collection_type
		AND	p.device_collection_id = NEW.device_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'device_collection % of type % is used by % restricted properties.',
				NEW.device_collection_id, NEW.device_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_device_component_assignment');
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
		component_id = NEW.component_id;

	IF NOT FOUND OR ctid IS DISTINCT FROM dt_ctid THEN
		RAISE EXCEPTION 'Component type of component_id % (%s) does not match component_type for device_type_id % (%)',
			NEW.component_id, ctid, dtid, dt_ctid
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_dns_domain_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_dns_domain_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.dns_domain_collection_type != NEW.dns_domain_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.dns_domain_collection_type = OLD.dns_domain_collection_type
		AND	p.dns_domain_collection_id = NEW.dns_domain_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'dns_domain_collection % of type % is used by % restricted properties.',
				NEW.dns_domain_collection_id, NEW.dns_domain_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_inter_component_connection');
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
		slot1_id,
		slot2_id
	INTO
		csid_rec
	FROM
		inter_component_connection icc
	WHERE
		icc.inter_component_connection_id != NEW.inter_component_connection_id
			AND
		(icc.slot1_id = NEW.slot1_id OR
		 icc.slot1_id = NEW.slot2_id OR
		 icc.slot2_id = NEW.slot1_id OR
		 icc.slot2_id = NEW.slot2_id )
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
		slot1.slot_id = NEW.slot1_id AND
		slot2.slot_id = NEW.slot2_id AND
		-- Remove next line if we ever decide to allow cross-function
		-- connections
		slot1.slot_function = slot2.slot_function AND
		((slot1.slot_type_id = pst.slot_type_id AND
				slot2.slot_type_id = pst.remote_slot_type_id) OR
			(slot2.slot_type_id = pst.slot_type_id AND
				slot1.slot_type_id = pst.remote_slot_type_id));

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Slot types are not allowed to be connected'
			USING ERRCODE = 'check_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_layer2_network_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_layer2_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer2_network_collection_type != NEW.layer2_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer2_network_collection_type = OLD.layer2_network_collection_type
		AND	p.layer2_network_collection_id = NEW.layer2_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer2_network_collection % of type % is used by % restricted properties.',
				NEW.layer2_network_collection_id, NEW.layer2_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_layer3_network_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_layer3_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer3_network_collection_type != NEW.layer3_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer3_network_collection_type = OLD.layer3_network_collection_type
		AND	p.layer3_network_collection_id = NEW.layer3_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer3_network_collection % of type % is used by % restricted properties.',
				NEW.layer3_network_collection_id, NEW.layer3_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.netblock_collection_type != NEW.netblock_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.netblock_collection_type = OLD.netblock_collection_type
		AND	p.netblock_collection_id = NEW.netblock_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'netblock_collection % of type % is used by % restricted properties.',
				NEW.netblock_collection_id, NEW.netblock_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_parentage');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_parentage()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	parent_nbid		netblock.netblock_id%type;
	ipaddr			inet;
	parent_ipaddr	inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		netblock.ip_address%type;
BEGIN

	RAISE DEBUG 'Validating % of netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */

	SELECT * INTO realnew FROM netblock WHERE netblock_id =
		NEW.netblock_id;
	IF NOT FOUND THEN
		/*
		 * If the netblock isn't there, it was subsequently deleted, so
		 * our parentage doesn't need to be checked
		 */
		RETURN NULL;
	END IF;


	/*
	 * If the parent changed above (or somewhere else between update and
	 * now), just bail, because another trigger will have been fired that
	 * we can do the full check with.
	 */
	IF NEW.parent_netblock_id != realnew.parent_netblock_id AND
		realnew.parent_netblock_id IS NOT NULL
	THEN
		RAISE DEBUG '... skipping for now';
		RETURN NULL;
	END IF;

	/*
	 * Validate that parent and all children are of the same netblock_type and
	 * in the same ip_universe.  We care about this even if the
	 * netblock type is not a validated type.
	 */

	RAISE DEBUG 'Verifying child ip_universe and type match';
	PERFORM netblock_id FROM netblock WHERE
		parent_netblock_id = realnew.netblock_id AND
		netblock_type != realnew.netblock_type AND
		ip_universe_id != realnew.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
	END IF;

	RAISE DEBUG '... OK';

	/*
	 * validate that this netblock is attached to its correct parent
	 */
	IF realnew.parent_netblock_id IS NULL THEN
		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		END IF;
		RAISE DEBUG 'Checking hierarchical netblock_id % with NULL parent',
			NEW.netblock_id;

		IF realnew.is_single_address = 'Y' THEN
			RAISE 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N',
				realnew.ip_address
				USING ERRCODE = 'JH105';
		END IF;

		/*
		 * Validate that a netblock has a parent, unless
		 * it is the root of a hierarchy
		 */
		parent_nbid := netblock_utils.find_best_parent_id(
			realnew.ip_address,
			NULL,
			realnew.netblock_type,
			realnew.ip_universe_id,
			realnew.is_single_address,
			realnew.netblock_id
		);

		IF parent_nbid IS NOT NULL THEN
			SELECT * INTO nbrec FROM netblock WHERE netblock_id =
				parent_nbid;

			RAISE EXCEPTION 'Netblock % (%) has NULL parent; should be % (%)',
				realnew.netblock_id, realnew.ip_address,
				parent_nbid, nbrec.ip_address USING ERRCODE = 'JH102';
		END IF;

		/*
		 * Validate that none of the other top-level netblocks should
		 * belong to this netblock
		 */
		PERFORM netblock_id FROM netblock WHERE
			parent_netblock_id IS NULL AND
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id AND
			ip_address <<= NEW.ip_address;
		IF FOUND THEN
			RAISE EXCEPTION 'Other top-level netblocks should belong to this parent'
				USING ERRCODE = 'JH108';
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF realnew.parent_netblock_id = realnew.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 'JH101';
		END IF;

		SELECT * INTO nbrec FROM netblock WHERE netblock_id =
			realnew.parent_netblock_id;

		/*
		 * This shouldn't happen, but may because of deferred constraints
		 */
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Parent netblock % does not exist',
			realnew.parent_netblock_id
			USING ERRCODE = 'foreign_key_violation';
		END IF;

		IF nbrec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'A parent netblock (% for %) may not be a single address',
			nbrec.netblock_id, realnew.ip_address
			USING ERRCODE = 'JH10A';
		END IF;

		IF nbrec.ip_universe_id != realnew.ip_universe_id OR
				nbrec.netblock_type != realnew.netblock_type THEN
			RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
		END IF;

		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		ELSE
			parent_nbid := netblock_utils.find_best_parent_id(
				realnew.ip_address,
				NULL,
				realnew.netblock_type,
				realnew.ip_universe_id,
				realnew.is_single_address,
				realnew.netblock_id
				);

			IF realnew.can_subnet = 'N' THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					is_single_address = 'N';
				IF FOUND THEN
					RAISE EXCEPTION 'A non-subnettable netblock (%) may not have child network netblocks',
					realnew.netblock_id
					USING ERRCODE = 'JH10B';
				END IF;
			END IF;
			IF realnew.is_single_address = 'Y' THEN
				SELECT * INTO nbrec FROM netblock
					WHERE netblock_id = realnew.parent_netblock_id;
				IF (nbrec.can_subnet = 'Y') THEN
					RAISE 'Parent netblock % for single-address % must have can_subnet=N',
						nbrec.netblock_id,
						realnew.ip_address
						USING ERRCODE = 'JH10D';
				END IF;
				IF (masklen(realnew.ip_address) !=
						masklen(nbrec.ip_address)) THEN
					RAISE 'Parent netblock % does not have the same netmask as single-address child % (% vs %)',
						parent_nbid, realnew.netblock_id,
						masklen(nbrec.ip_address),
						masklen(realnew.ip_address)
						USING ERRCODE = 'JH105';
				END IF;
			END IF;
			IF (parent_nbid IS NULL OR realnew.parent_netblock_id != parent_nbid) THEN
				SELECT ip_address INTO parent_ipaddr FROM netblock
				WHERE
					netblock_id = parent_nbid;
				SELECT ip_address INTO ipaddr FROM netblock WHERE
					netblock_id = realnew.parent_netblock_id;

				RAISE EXCEPTION
					'Parent netblock % (%) for netblock % (%) is not the correct parent (should be % (%))',
					realnew.parent_netblock_id, ipaddr,
					realnew.netblock_id, realnew.ip_address,
					parent_nbid, parent_ipaddr
					USING ERRCODE = 'JH102';
			END IF;
			/*
			 * Validate that all children are is_single_address='Y' or
			 * all children are is_single_address='N'
			 */
			SELECT count(*) INTO single_count FROM netblock WHERE
				is_single_address='Y' and parent_netblock_id =
				realnew.parent_netblock_id;
			SELECT count(*) INTO nonsingle_count FROM netblock WHERE
				is_single_address='N' and parent_netblock_id =
				realnew.parent_netblock_id;

			IF (single_count > 0 and nonsingle_count > 0) THEN
				SELECT * INTO nbrec FROM netblock WHERE netblock_id =
					realnew.parent_netblock_id;
				RAISE EXCEPTION 'Netblock % (%) may not have direct children for both single and multiple addresses simultaneously',
					nbrec.netblock_id, nbrec.ip_address
					USING ERRCODE = 'JH107';
			END IF;
			/*
			 *  If we're updating and we changed our ip_address (including
			 *  netmask bits), then check that our children still belong to
			 *  us
			 */
			 IF (TG_OP = 'UPDATE' AND NEW.ip_address != OLD.ip_address) THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					((is_single_address = 'Y' AND NEW.ip_address !=
						ip_address::cidr) OR
					(is_single_address = 'N' AND realnew.netblock_id !=
						netblock_utils.find_best_parent_id(netblock_id)));
				IF FOUND THEN
					RAISE EXCEPTION 'Update for netblock % (%) causes parent to have children that do not belong to it',
						realnew.netblock_id, realnew.ip_address
						USING ERRCODE = 'JH10E';
				END IF;
			END IF;

			/*
			 * Validate that none of the children of the parent netblock are
			 * children of this netblock (e.g. if inserting into the middle
			 * of the hierarchy)
			 */
			IF (realnew.is_single_address = 'N') THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.parent_netblock_id AND
					netblock_id != realnew.netblock_id AND
					ip_address <<= realnew.ip_address;
				IF FOUND THEN
					RAISE EXCEPTION 'Other netblocks have children that should belong to parent % (%)',
						realnew.parent_netblock_id, realnew.ip_address
						USING ERRCODE = 'JH108';
				END IF;
			END IF;
		END IF;
	END IF;

	RETURN NULL;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_to_range_changes');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_to_range_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM
	FROM	network_range nr
			JOIN netblock p on p.netblock_id = nr.parent_netblock_id
			JOIN netblock start on start.netblock_id = nr.start_netblock_id
			JOIN netblock stop on stop.netblock_id = nr.stop_netblock_id
			JOIN val_network_range_type vnrt USING (network_range_type)
	WHERE	( p.netblock_id = NEW.netblock_id
				OR start.netblock_id = NEW.netblock_id
				OR stop.netblock_id = NEW.netblock_id
			) AND (
					p.can_subnet = 'Y'
				OR 	start.is_single_address = 'N'
				OR 	stop.is_single_address = 'N'
				OR NOT (
					host(start.ip_address)::inet <<= p.ip_address
					AND host(stop.ip_address)::inet <<= p.ip_address
				)
				OR ( vnrt.netblock_type IS NOT NULL
				OR NOT
					( start.netblock_type IS NOT DISTINCT FROM vnrt.netblock_type
					AND	stop.netblock_type IS NOT DISTINCT FROM vnrt.netblock_type
					)
				)
			)
	;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock changes conflict with network range requirements '
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END; $function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_network_range_ips');
CREATE OR REPLACE FUNCTION jazzhands.validate_network_range_ips()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	v_nrt	val_network_range_type%ROWTYPE;
	v_nbt	val_netblock_type.netblock_type%TYPE;
BEGIN
	SELECT	*
	INTO	v_nrt
	FROM	val_network_range_type
	WHERE	network_range_type = NEW.network_range_type;

	--
	-- check to make sure type mapping works
	--
	IF v_nrt.netblock_type IS NOT NULL THEN
		SELECT	netblock_type
		INTO	v_nbt
		FROM	netblock
		WHERE	netblock_id = NEW.start_netblock_id
		AND		netblock_type != v_nrt.netblock_type;

		IF FOUND THEN
			RAISE EXCEPTION 'For range %, start netblock_type must be %, not %',
				NEW.network_range_type, v_nrt.netblock_type, v_nbt
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

		SELECT	netblock_type
		INTO	v_nbt
		FROM	netblock
		WHERE	netblock_id = NEW.stop_netblock_id
		AND		netblock_type != v_nrt.netblock_type;

		IF FOUND THEN
			RAISE EXCEPTION 'For range %, stop netblock_type must be %, not %',
				NEW.network_range_type, v_brt.netblock_type, v_nbt
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	--
	-- Check to ensure both stop and start have is_single_address = 'Y'
	--
	PERFORM
	FROM	netblock
	WHERE	( netblock_id = NEW.start_netblock_id
				OR netblock_id = NEW.stop_netblock_id
			) AND is_single_address = 'N';

	IF FOUND THEN
		RAISE EXCEPTION 'Start and stop types must be single addresses'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	PERFORM
	FROM	netblock
	WHERE	netblock_id = NEW.parent_netblock_id
	AND can_subnet = 'Y';

	IF FOUND THEN
		RAISE EXCEPTION 'Can not set ranges on subnetable netblocks'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	PERFORM
	FROM	netblock parent
			JOIN netblock start ON start.netblock_id = NEW.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = NEW.stop_netblock_id
	WHERE
			parent.netblock_id = NEW.parent_netblock_id
			AND NOT ( host(start.ip_address)::inet <<= parent.ip_address
				AND host(stop.ip_address)::inet <<= parent.ip_address
			)
	;

	IF FOUND THEN
		RAISE EXCEPTION 'Start and stop must be within parents'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	RETURN NEW;
END; $function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_service_env_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_service_env_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.service_env_collection_type != NEW.service_env_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.service_env_collection_type = OLD.service_env_collection_type
		AND	p.service_env_collection_id = NEW.service_env_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'service_env_collection % of type % is used by % restricted properties.',
				NEW.service_env_collection_id, NEW.service_env_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'verify_physical_connection');
CREATE OR REPLACE FUNCTION jazzhands.verify_physical_connection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM 1 FROM
		physical_connection l1
		JOIN physical_connection l2 ON
			l1.slot1_id = l2.slot2_id AND
			l1.slot2_id = l2.slot1_id;
	IF FOUND THEN
		RAISE EXCEPTION 'Connection already exists in opposite direction';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'verify_physicalish_volume');
CREATE OR REPLACE FUNCTION jazzhands.verify_physicalish_volume()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.company_insert_function_nudge()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		IF current_setting('jazzhands.permit_company_insert') != 'permit' THEN
			RAISE EXCEPTION  'You may not directly insert into company.'
				USING ERRCODE = 'insufficient_privilege';
		END IF;
	EXCEPTION WHEN undefined_object THEN
			RAISE EXCEPTION  'You may not directly insert into company'
				USING ERRCODE = 'insufficient_privilege';
	END;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_record_check_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.DNS_NAME IS NOT NULL THEN
		-- rfc rfc952
		IF NEW.DNS_NAME !~ '[-a-zA-Z0-9\._]*' THEN
			RAISE EXCEPTION 'Invalid DNS NAME %',
				NEW.DNS_NAME
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.l2_net_coll_member_enforce_on_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	l2ct		val_layer2_network_coll_type%ROWTYPE;
	old_l2ct	val_layer2_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	l2ct
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type = NEW.layer2_network_collection_type;

	SELECT *
	INTO	old_l2ct
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type = OLD.layer2_network_collection_type;

	--
	-- We only need to check this if we are enforcing now where we didn't used
	-- to need to
	--
	IF l2ct.max_num_members IS NOT NULL AND
			l2ct.max_num_members IS DISTINCT FROM old_l2ct.max_num_members THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  where layer2_network_collection_id = NEW.layer2_network_collection_id;
		IF tally > l2ct.max_num_members THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF l2ct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		SELECT MAX(l2count) FROM (
			SELECT
				COUNT(*) AS l2count
			FROM
				l2_network_coll_l2_network JOIN
				layer2_network_collection USING (layer2_network_collection_id)
			WHERE
				layer2_network_collection_type = NEW.layer2_network_collection_type
			GROUP BY
				layer2_network_id
		) x INTO tally;

		IF tally > l2ct.max_num_collections THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				l2ct.MAX_NUM_COLLECTIONS, l2ct.layer2_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.l3_net_coll_member_enforce_on_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	l3ct		val_layer3_network_coll_type%ROWTYPE;
	old_l3ct	val_layer3_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	l3ct
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type = NEW.layer3_network_collection_type;

	SELECT *
	INTO	old_l3ct
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type = OLD.layer3_network_collection_type;

	--
	-- We only need to check this if we are enforcing now where we didn't used
	-- to need to
	--
	IF l3ct.max_num_members IS NOT NULL AND
			l3ct.max_num_members IS DISTINCT FROM old_l3ct.max_num_members THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  where layer3_network_collection_id = NEW.layer3_network_collection_id;
		IF tally > l3ct.max_num_members THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF l3ct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		SELECT MAX(l3count) FROM (
			SELECT
				COUNT(*) AS l3count
			FROM
				l3_network_coll_l3_network JOIN
				layer3_network_collection USING (layer3_network_collection_id)
			WHERE
				layer3_network_collection_type = NEW.layer3_network_collection_type
			GROUP BY
				layer3_network_id
		) x INTO tally;

		IF tally > l3ct.max_num_collections THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				l3ct.MAX_NUM_COLLECTIONS, l3ct.layer3_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.nb_dns_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tal	integer;
BEGIN
	IF family(OLD.ip_address) != family(NEW.ip_address) THEN
		IF family(NEW.ip_address) == 6 THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	netblock_id = NEW.netblock_id
			AND		dns_type = 'A';

			IF _tal > 0 THEN
				RAISE EXCEPTION 'A records must be assigned to IPv4 records'
					USING ERRCODE = 'JH200';
			END IF;
		END IF;
	END IF;

	IF family(OLD.ip_address) != family(NEW.ip_address) THEN
		IF family(NEW.ip_address) == 4 THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	netblock_id = NEW.netblock_id
			AND		dns_type = 'AAAA';

			IF _tal > 0 THEN
				RAISE EXCEPTION 'AAAA records must be assigned to IPv6 records'
					USING ERRCODE = 'JH200';
			END IF;
		END IF;
	END IF;

	IF NEW.is_single_address = 'N' THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	netblock_id = NEW.netblock_id
			AND		dns_type IN ('A', 'AAAA');

		IF _tal > 0 THEN
			RAISE EXCEPTION 'Non-single addresses may not have % records', NEW.dns_type
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.pgnotify_account_collection_account_token_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
		PERFORM	*
		FROM	property_collection
				JOIN property_collection_property pcp
					USING (property_collection_id)
				JOIN property p
					USING (property_name, property_type)
		WHERE	p.account_collection_id = OLD.account_collection_id
		AND		property_collection_type = 'jazzhands-internal'
		AND		property_collection_name = 'notify-account_collection_account'
		;

		IF FOUND THEN
			PERFORM pg_notify('account_change', concat('account_id=', OLD.account_id));
		END IF;
	END IF;
	IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
		PERFORM	*
		FROM	property_collection
				JOIN property_collection_property pcp
					USING (property_collection_id)
				JOIN property p
					USING (property_name, property_type)
		WHERE	p.account_collection_id = NEW.account_collection_id
		AND		property_collection_type = 'jazzhands-internal'
		AND		property_collection_name = 'notify-account_collection_account'
		;

		IF FOUND THEN
			PERFORM pg_notify('account_change', concat('account_id=', NEW.account_id));
		END IF;
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.pgnotify_account_password_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM pg_notify ('account_password_change', 'account_id=' || NEW.account_id);
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.pgnotify_account_token_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM pg_notify ('account_id', 'account_id=' || NEW.account_id);
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.pgnotify_token_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM pg_notify ('token_change', 'token_id=' || NEW.token_id);
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.pvtkey_ski_signed_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	ski	TEXT;
BEGIN
	SELECT	subject_key_identifier
	INTO	ski
	FROM	x509_signed_certificate x
	WHERE	x.private_key_id = NEW.private_key_id;

	IF FOUND AND ski != NEW.subject_key_identifier THEN
		RAISE EXCEPTION 'subject key identifier must match private key in x509_signing_certificate' USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.unrequire_password_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	DELETE FROM account_collection_account
	WHERE (account_collection_id, account_id)
	IN (
		SELECT	a.account_collection_id, a.account_id
		FROM	v_acct_coll_acct_expanded a
				JOIN account_collection ac USING (account_collection_id)
				JOIN property p USING (account_collection_id)
		WHERE	p.property_type = 'UserMgmt'
		AND		p.property_name = 'NeedsPasswdChange'
		AND	 	a.account_id = NEW.account_id
	);
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.x509_signed_ski_pvtkey_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	ski	TEXT;
BEGIN
	--
	-- XXX needs to be tweaked to ensure that both are set or not set.
	--
	IF NEW.private_key_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	subject_key_identifier
	INTO	ski
	FROM	private_key p
	WHERE	p.private_key_id = NEW.private_key_id;

	IF FOUND AND ski != NEW.subject_key_identifier THEN
		RAISE EXCEPTION 'subject key identifier must match private key in private_key' USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

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
-- New function
CREATE OR REPLACE FUNCTION person_manip.add_user(company_id integer, person_company_relation character varying, login character varying DEFAULT NULL::character varying, first_name character varying DEFAULT NULL::character varying, middle_name character varying DEFAULT NULL::character varying, last_name character varying DEFAULT NULL::character varying, name_suffix character varying DEFAULT NULL::character varying, gender character varying DEFAULT NULL::character varying, preferred_last_name character varying DEFAULT NULL::character varying, preferred_first_name character varying DEFAULT NULL::character varying, birth_date date DEFAULT NULL::date, external_hr_id character varying DEFAULT NULL::character varying, person_company_status character varying DEFAULT 'enabled'::character varying, is_management character varying DEFAULT 'N'::character varying, is_manager character varying DEFAULT NULL::character varying, is_exempt character varying DEFAULT 'Y'::character varying, is_full_time character varying DEFAULT 'Y'::character varying, employee_id text DEFAULT NULL::text, hire_date date DEFAULT NULL::date, termination_date date DEFAULT NULL::date, position_title character varying DEFAULT NULL::character varying, job_title character varying DEFAULT NULL::character varying, department_name character varying DEFAULT NULL::character varying, manager_person_id integer DEFAULT NULL::integer, site_code character varying DEFAULT NULL::character varying, physical_address_id integer DEFAULT NULL::integer, person_location_type character varying DEFAULT 'office'::character varying, description character varying DEFAULT NULL::character varying, unix_uid character varying DEFAULT NULL::character varying, INOUT person_id integer DEFAULT NULL::integer, OUT dept_account_collection_id integer, OUT account_id integer)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    _account_realm_id INTEGER;
    _account_type VARCHAR;
    _uid INTEGER;
    _uxaccountid INTEGER;
    _companyid INTEGER;
    _personid INTEGER;
    _accountid INTEGER;
BEGIN
	IF is_manager IS NOT NULL THEN
		is_management := is_manager;
	END IF;

	IF job_title IS NOT NULL THEN
		position_title := job_title;
	END IF;

    IF company_id is NULL THEN
        RAISE EXCEPTION 'Must specify company id';
    END IF;
    _companyid := company_id;

    SELECT arc.account_realm_id 
      INTO _account_realm_id 
      FROM account_realm_company arc
     WHERE arc.company_id = _companyid;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cannot find account_realm_id with company id %', company_id;
    END IF;

    IF login is NULL THEN
        IF first_name IS NULL or last_name IS NULL THEN 
            RAISE EXCEPTION 'Must specify login name or first name+last name';
        ELSE 
            login := person_manip.pick_login(
                in_account_realm_id := _account_realm_id,
                in_first_name := coalesce(preferred_first_name, first_name),
                in_middle_name := middle_name,
                in_last_name := coalesce(preferred_last_name, last_name)
            );
        END IF;
    END IF;

    IF person_company_relation = 'pseudouser' THEN
        person_id := 0;
        _account_type := 'pseudouser';
    ELSE
        _account_type := 'person';
        IF person_id IS NULL THEN
            INSERT INTO person (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
                VALUES (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
            RETURNING person.person_id into _personid;
            person_id = _personid;
        ELSE
            INSERT INTO person (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
                VALUES (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date);
        END IF;
        INSERT INTO person_company
            (person_id, company_id, external_hr_id, person_company_status, is_management, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, position_title, manager_person_id)
            VALUES
            (person_id, company_id, external_hr_id, person_company_status, is_management, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, position_title, manager_person_id);
        INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( person_id, company_id, _account_realm_id);
    END IF;

    INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type)
        VALUES (login, person_id, company_id, _account_realm_id, person_company_status, description, 'primary', _account_type)
    RETURNING account.account_id INTO account_id;

    IF department_name IS NOT NULL THEN
        dept_account_collection_id = person_manip.get_account_collection_id(department_name, 'department');
        INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( dept_account_collection_id, account_id);
    END IF;

    IF site_code IS NOT NULL AND physical_address_id IS NOT NULL THEN
        RAISE EXCEPTION 'You must provide either site_code or physical_address_id NOT both';
    END IF;

    IF site_code IS NULL AND physical_address_id IS NOT NULL THEN
        site_code = person_manip.get_site_code_from_physical_address_id(physical_address_id);
    END IF;

    IF physical_address_id IS NULL AND site_code IS NOT NULL THEN
        physical_address_id = person_manip.get_physical_address_from_site_code(site_code);
    END IF;

    IF physical_address_id IS NOT NULL AND site_code IS NOT NULL THEN
        INSERT INTO person_location 
            (person_id, person_location_type, site_code, physical_address_id)
        VALUES
            (person_id, person_location_type, site_code, physical_address_id);
    END IF;


    IF unix_uid IS NOT NULL THEN
        _accountid = account_id;
        SELECT  aui.account_id
          INTO  _uxaccountid
          FROM  account_unix_info aui
        WHERE  aui.account_id = _accountid;

        --
        -- This is creatd by trigger for non-pseudousers, which will
        -- eventually change, so this is here once it goes away.
        --
        IF _uxaccountid IS NULL THEN
            IF unix_uid = 'auto' THEN
                _uid :=  person_manip.get_unix_uid(_account_type);
            ELSE
                _uid := unix_uid::int;
            END IF;

            PERFORM person_manip.setup_unix_account(
                in_account_id := account_id,
                in_account_type := _account_type,
                in_uid := _uid
            );
        END IF;
    END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION person_manip.get_physical_address_from_site_code(_site_code character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_physical_address_id INTEGER;
BEGIN
	SELECT physical_address_id INTO _physical_address_id
		FROM physical_address
		INNER JOIN site USING(physical_address_id)
		WHERE site_code = _site_code;
	RETURN _physical_address_id;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION person_manip.get_site_code_from_physical_address_id(_physical_address_id integer)
 RETURNS character varying
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_site_code VARCHAR;
BEGIN
	SELECT site_code INTO _site_code
		FROM physical_address
		INNER JOIN site USING(physical_address_id)
		WHERE physical_address_id = _physical_address_id;
	RETURN _site_code;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION person_manip.set_location(person_id integer, new_site_code character varying DEFAULT NULL::character varying, new_physical_address_id integer DEFAULT NULL::integer, person_location_type character varying DEFAULT 'office'::character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_person_id INTEGER;
	_person_location_type VARCHAR;
	_existing_person_location_id INTEGER;
BEGIN
	_person_id = person_id;
	_person_location_type = person_location_type;

	IF ( new_site_code IS NULL AND new_physical_address_id IS NULL )
		OR ( new_site_code IS NOT NULL AND new_physical_address_id IS NOT NULL ) THEN
			RAISE EXCEPTION 'Must specify either new_site_code or new_physical_address';
	END IF;

	IF new_site_code IS NOT NULL AND new_physical_address_id IS NULL THEN
		new_physical_address_id = person_manip.get_physical_address_from_site_code(new_site_code);
	END IF;

	IF new_physical_address_id IS NOT NULL AND new_site_code IS NULL THEN
		new_site_code = person_manip.get_site_code_from_physical_address_id(new_physical_address_id);
	END IF;

	SELECT person_location_id INTO _existing_person_location_id
	FROM person_location pl
	WHERE pl.person_id = _person_id AND pl.person_location_type = _person_location_type;

	IF _existing_person_location_id IS NULL THEN
		INSERT INTO person_location
			(person_id, person_location_type, site_code, physical_address_id)
		VALUES
			(_person_id, _person_location_type, new_site_code, new_physical_address_id);
	ELSE
		UPDATE person_location
		SET (site_code, physical_address_id, building, floor, section, seat_number)
		= (new_site_code, new_physical_address_id, NULL, NULL, NULL, NULL)
		WHERE person_location_id = _existing_person_location_id;
	END IF;
END;
$function$
;

--
-- Process middle (non-trigger) schema auto_ac_manip
--
--
-- Process middle (non-trigger) schema company_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('company_manip', 'add_company');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS company_manip.add_company ( _company_name text, _company_types text[], _parent_company_id integer, _account_realm_id integer, _company_short_name text, _description text );
CREATE OR REPLACE FUNCTION company_manip.add_company(_company_name text, _company_types text[] DEFAULT NULL::text[], _parent_company_id integer DEFAULT NULL::integer, _account_realm_id integer DEFAULT NULL::integer, _company_short_name text DEFAULT NULL::text, _description text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_cmpid	company.company_id%type;
	_short	text;
	_isfam	char(1);
	_perm	text;
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
	ELSE
		_short := _company_short_name;
	END IF;

	BEGIN
		_perm := current_setting('jazzhands.permit_company_insert');
	EXCEPTION WHEN undefined_object THEN
		_perm := '';
	END;

	SET jazzhands.permit_company_insert = 'permit';

	INSERT INTO company (
		company_name, company_short_name,
		parent_company_id, description
	) VALUES (
		_company_name, _short,
		_parent_company_id, _description
	) RETURNING company_id INTO _cmpid;

	SET jazzhands.permit_company_insert = _perm;

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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('company_manip', 'add_company_types');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS company_manip.add_company_types ( _company_id integer, _account_realm_id integer, _company_types text[] );
CREATE OR REPLACE FUNCTION company_manip.add_company_types(_company_id integer, _account_realm_id integer DEFAULT NULL::integer, _company_types text[] DEFAULT NULL::text[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	x		text;
	count	integer;
BEGIN
	count := 0;
	FOREACH x IN ARRAY _company_types
	LOOP
		INSERT INTO company_type (company_id, company_type)
			VALUES (_company_id, x);
		IF _account_realm_id IS NOT NULL THEN
			PERFORM company_manip.add_auto_collections(_company_id, _account_realm_id, x);
		END IF;
		count := count + 1;
	END LOOP;
	return count;
END;
$function$
;

--
-- Process middle (non-trigger) schema token_utils
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
-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_device');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_device ( in_device_id integer, retire_modules boolean );
CREATE OR REPLACE FUNCTION device_utils.retire_device(in_device_id integer, retire_modules boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally		INTEGER;
	_r			RECORD;
	_d			DEVICE%ROWTYPE;
	_mgrid		DEVICE.DEVICE_ID%TYPE;
	_purgedev	boolean;
BEGIN
	_purgedev := false;

	BEGIN
		PERFORM local_hooks.device_retire_early(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT * INTO _d FROM device WHERE device_id = in_Device_id;
	delete from dns_record where netblock_id in (
		select netblock_id 
		from network_interface where device_id = in_Device_id
	);

	delete from network_interface_purpose where device_id = in_Device_id;

	DELETE FROM network_interface_netblock
	WHERE network_interface_id IN (
			SELECT network_interface_id
		 	FROM network_interface
			WHERE device_id = in_Device_id
	);

	DELETE FROM network_interface WHERE device_id = in_Device_id;

	PERFORM device_utils.purge_physical_ports( in_Device_id);
--	PERFORM device_utils.purge_power_ports( in_Device_id);

	delete from property where device_collection_id in (
		SELECT	dc.device_collection_id 
		  FROM	device_collection dc
				INNER JOIN device_collection_device dcd
		 			USING (device_collection_id)
		WHERE	dc.device_collection_type = 'per-device'
		  AND	dcd.device_id = in_Device_id
	);

	delete from device_collection_device where device_id = in_Device_id;
	delete from snmp_commstr where device_id = in_Device_id;

		
	IF _d.rack_location_id IS NOT NULL  THEN
		UPDATE device SET rack_location_id = NULL 
		WHERE device_id = in_Device_id;

		-- This should not be permitted based on constraints, but in case
		-- that constraint had to be disabled...
		SELECT	count(*)
		  INTO	tally
		  FROM	device
		 WHERE	rack_location_id = _d.RACK_LOCATION_ID;

		IF tally = 0 THEN
			DELETE FROM rack_location 
			WHERE rack_location_id = _d.RACK_LOCATION_ID;
		END IF;
	END IF;

	IF _d.chassis_location_id IS NOT NULL THEN
		RAISE EXCEPTION 'Retiring modules is not supported yet.';
	END IF;

	SELECT	manager_device_id
	INTO	_mgrid
	 FROM	device_management_controller
	WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
	LIMIT 1;

	IF _mgrid IS NOT NULL THEN
		DELETE FROM device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
			AND manager_device_id = _mgrid;

		PERFORM device_utils.retire_device( manager_device_id)
		  FROM	device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc';
	END IF;

	BEGIN
		PERFORM local_hooks.device_retire_late(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT count(*)
	INTO tally
	FROM device_note
	WHERE device_id = in_Device_id;

	--
	-- If there is no notes or serial number its save to remove
	-- 
	IF tally = 0 AND _d.ASSET_ID is NULL THEN
		_purgedev := true;
	END IF;

	IF _purgedev THEN
		--
		-- If there is an fk violation, we just preserve the record but
		-- delete all the identifying characteristics
		--
		BEGIN
			DELETE FROM device where device_id = in_Device_Id;
			return false;
		EXCEPTION WHEN foreign_key_violation THEN
			PERFORM 1;
		END;
	END IF;

	UPDATE device SET 
		device_name =NULL,
		service_environment_id = (
			select service_environment_id from service_environment
			where service_environment_name = 'unallocated'),
		device_status = 'removed',
		voe_symbolic_track_id = NULL,
		is_monitored = 'N',
		should_fetch_config = 'N',
		description = NULL
	WHERE device_id = in_Device_id;

	return true;
END;
$function$
;

--
-- Process middle (non-trigger) schema netblock_utils
--
--
-- Process middle (non-trigger) schema netblock_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF netblock
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	netblock_rec	RECORD;
BEGIN
	RETURN QUERY 
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
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF netblock
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
			RETURN;
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
 		RETURN;
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
			RETURN;
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

		RETURN NEXT netblock_rec;
		RETURN;
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
			RETURN;
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

		RETURN NEXT netblock_rec;
		RETURN;
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
			RETURN;
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

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'create_network_range');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.create_network_range ( start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer, description character varying, allow_assigned boolean );
CREATE OR REPLACE FUNCTION netblock_manip.create_network_range(start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer DEFAULT NULL::integer, description character varying DEFAULT NULL::character varying, allow_assigned boolean DEFAULT false)
 RETURNS network_range
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	par_netblock	RECORD;
	start_netblock	RECORD;
	stop_netblock	RECORD;
	netrange		RECORD;
	nrtype			ALIAS FOR network_range_type;
	pnbid			ALIAS FOR parent_netblock_id;
BEGIN
	--
	-- If the network range already exists, then just return it
	--
	SELECT 
		nr.* INTO netrange
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON (nr.start_netblock_id = 
			startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND
		host(startnb.ip_address) = host(start_ip_address) AND
		host(stopnb.ip_address) = host(stop_ip_address) AND
		CASE WHEN pnbid IS NOT NULL THEN 
			(pnbid = nr.parent_netblock_id)
		ELSE
			true
		END;

	IF FOUND THEN
		RETURN netrange;
	END IF;

	--
	-- If any other network ranges exist that overlap this, then error
	--
	PERFORM 
		*
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON 
			(nr.start_netblock_id = startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND ((
			host(startnb.ip_address)::inet <= host(start_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(start_ip_address)::inet
		) OR (
			host(startnb.ip_address)::inet <= host(stop_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(stop_ip_address)::inet
		));

	IF FOUND THEN
		RAISE 'create_network_range: a network_range of type % already exists that has addresses between % and %',
			nrtype, start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	IF parent_netblock_id IS NOT NULL THEN
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE 
			netblock_id = pnbid;
		IF NOT FOUND THEN
			RAISE 'create_network_range: parent_netblock_id % does not exist',
				parent_netblock_id USING ERRCODE = 'foreign_key_violation';
		END IF;
	ELSE
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE netblock_id = (
			SELECT 
				*
			FROM
				netblock_utils.find_best_parent_id(
					in_ipaddress := start_ip_address,
					in_is_single_address := 'Y'
				)
		);

		IF NOT FOUND THEN
			RAISE 'create_network_range: valid parent netblock for start_ip_address % does not exist',
				start_ip_address USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	IF par_netblock.can_subnet != 'N' OR 
			par_netblock.is_single_address != 'N' THEN
		RAISE 'create_network_range: parent netblock % must not be subnettable or a single address',
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not contained by parent netblock % (%)',
			start_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (stop_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: stop_ip_address % is not contained by parent netblock % (%)',
			stop_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <= stop_ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not lower than stop_ip_address %',
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- Validate that there are not currently any addresses assigned in the
	-- range, unless allow_assigned is set
	--
	IF NOT allow_assigned THEN
		PERFORM 
			*
		FROM
			jazzhands.netblock n
		WHERE
			n.parent_netblock_id = par_netblock.netblock_id AND
			host(n.ip_address)::inet > host(start_ip_address)::inet AND
			host(n.ip_address)::inet < host(stop_ip_address)::inet;

		IF FOUND THEN
			RAISE 'create_network_range: netblocks are already present for parent netblock % betweeen % and %',
			par_netblock.netblock_id,
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	--
	-- Ok, well, we should be able to insert things now
	--

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		start_netblock
	WHERE
		host(n.ip_address)::inet = start_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(start_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO start_netblock;
	END IF;

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		stop_netblock
	WHERE
		host(n.ip_address)::inet = stop_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(stop_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO stop_netblock;
	END IF;

	INSERT INTO network_range (
		network_range_type,
		description,
		parent_netblock_id,
		start_netblock_id,
		stop_netblock_id
	) VALUES (
		nrtype,
		description,
		par_netblock.netblock_id,
		start_netblock.netblock_id,
		stop_netblock.netblock_id
	) RETURNING * INTO netrange;

	RETURN netrange;

	RETURN NULL;
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
				SELECT company_manip.add_company(
					_company_name := pci_vendor_name,
					_company_types := ARRAY['hardware provider'],
					 _description := 'PCI vendor auto-insert'
				) INTO comp_id;
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
				SELECT company_manip.add_company(
					_company_name := pci_sub_vendor_name,
					_company_types := ARRAY['hardware provider'],
					 _description := 'PCI vendor auto-insert'
				) INTO comp_id;
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

-- New function
CREATE OR REPLACE FUNCTION component_utils.fetch_component(component_type_id integer, serial_number text, no_create boolean DEFAULT false, ownership_status text DEFAULT 'unknown'::text)
 RETURNS component
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	ctid		ALIAS FOR component_type_id;
	sn			ALIAS FOR serial_number;
	os			ALIAS FOR ownership_status;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF sn IS NOT NULL THEN
		SELECT 
			comp.* INTO c
		FROM
			component comp JOIN
			asset a USING (component_id)
		WHERE
			comp.component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			return c;
		END IF;
	END IF;

	IF no_create THEN
		RETURN NULL;
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
			os
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
-- Process middle (non-trigger) schema approval_utils
--
--
-- Process middle (non-trigger) schema account_collection_manip
--
--
-- Process middle (non-trigger) schema schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'begin_maintenance');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.begin_maintenance ( shouldbesuper boolean );
CREATE OR REPLACE FUNCTION schema_support.begin_maintenance(shouldbesuper boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	issuper	boolean;
	_tally	integer;
BEGIN
	IF shouldbesuper THEN
		SELECT usesuper INTO issuper FROM pg_user where usename = current_user;
		IF issuper IS false THEN
			RAISE EXCEPTION 'User must be a super user.';
		END IF;
	END IF;
	-- Not sure how reliable this is.
	-- http://www.postgresql.org/docs/9.3/static/monitoring-stats.html
	SELECT count(*)
	  INTO _tally
	  FROM	pg_stat_activity
	 WHERE	pid = pg_backend_pid()
	   AND	query_start = xact_start;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Must run maintenance in a transaction.';
	END IF;
	RETURN true;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying, first_time boolean );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying, first_time boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	keys	RECORD;
	count	INTEGER;
	name	TEXT;
BEGIN
	BEGIN
	EXECUTE 'CREATE SEQUENCE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name || '_seq');
	EXCEPTION WHEN duplicate_table THEN
		NULL;
	END;

	EXECUTE 'CREATE TABLE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' AS '
		|| 'SELECT *, NULL::char(3) as "aud#action", now() as "aud#timestamp", '
		|| 'clock_timestamp() as "aud#realtime", '
		|| 'txid_current() as "aud#txid", '
		|| 'NULL::varchar(255) AS "aud#user", NULL::integer AS "aud#seq" '
		|| 'FROM ' || quote_ident(tbl_schema) || '.' || quote_ident(table_name)
		|| ' LIMIT 0';

	EXECUTE 'ALTER TABLE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name)
		|| $$ ALTER COLUMN "aud#seq" SET NOT NULL, $$
		|| $$ ALTER COLUMN "aud#seq" SET DEFAULT nextval('$$
		|| quote_ident(aud_schema) || '.' || quote_ident(table_name || '_seq')
		|| $$')$$;

	EXECUTE 'ALTER SEQUENCE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name || '_seq') || ' OWNED BY '
		|| quote_ident(aud_schema) || '.' || quote_ident(table_name)
		|| '.' || quote_ident('aud#seq');


	EXECUTE 'CREATE INDEX '
		|| quote_ident( table_name || '_aud#timestamp_idx')
		|| ' ON ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || '("aud#timestamp")';

	EXECUTE 'ALTER TABLE ' || quote_ident(aud_schema) || '.'
		|| quote_ident( table_name )
		|| ' ADD PRIMARY KEY ("aud#seq")';

	COUNT := 0;
	-- one day, I will want to construct the list of columns by hand rather
	-- than use pg_get_constraintdef.  watch me...
	FOR keys IN
		SELECT con.conname, c2.relname as index_name,
			pg_catalog.pg_get_constraintdef(con.oid, true) as condef,
				regexp_replace(
			pg_catalog.pg_get_constraintdef(con.oid, true),
					'^.*(\([^\)]+\)).*$', '\1') as cols,
			con.condeferrable,
			con.condeferred
		FROM pg_catalog.pg_class c
			INNER JOIN pg_namespace n
				ON relnamespace = n.oid
			INNER JOIN pg_catalog.pg_index i
				ON c.oid = i.indrelid
			INNER JOIN pg_catalog.pg_class c2
				ON i.indexrelid = c2.oid
			INNER JOIN pg_catalog.pg_constraint con ON
				(con.conrelid = i.indrelid
				AND con.conindid = i.indexrelid )
		WHERE c.relname =  table_name
		AND	 n.nspname = tbl_schema
		AND con.contype in ('p', 'u')
	LOOP
		name := 'aud_' || quote_ident( table_name || '_' || keys.conname);
		IF char_length(name) > 63 THEN
			name := 'aud_' || count || quote_ident( table_name || '_' || keys.conname);
			COUNT := COUNT + 1;
		END IF;
		EXECUTE 'CREATE INDEX ' || name
			|| ' ON ' || quote_ident(aud_schema) || '.'
			|| quote_ident(table_name) || keys.cols;
	END LOOP;

	IF first_time THEN
		PERFORM schema_support.rebuild_audit_trigger
			( aud_schema, tbl_schema, table_name );
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT table_name FROM information_schema.tables
	WHERE table_type = 'BASE TABLE' AND table_schema = tbl_schema
	AND NOT (
	    table_name IN (
		SELECT table_name FROM information_schema.tables
		WHERE table_schema = aud_schema
	    )
	)
	ORDER BY table_name
    LOOP
	PERFORM schema_support.build_audit_table
	    ( aud_schema, tbl_schema, table_list.table_name );
    END LOOP;

    PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_common_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_schema text, _table1 text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_q			text;
    cols        text[];
BEGIN
    _q := 'WITH cols AS (
        SELECT  n.nspname as schema, c.relname as relation, a.attname as colname,
		a.attnum
            FROM    pg_catalog.pg_attribute a
                INNER JOIN pg_catalog.pg_class c
                    on a.attrelid = c.oid
                INNER JOIN pg_catalog.pg_namespace n
                    on c.relnamespace = n.oid
            WHERE   a.attnum > 0
            AND   NOT a.attisdropped
            ORDER BY a.attnum
       ) SELECT array_agg(colname ORDER BY o.attnum) as cols
        FROM cols  o
            INNER JOIN cols n USING (schema, colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.relation =$3
	';
	EXECUTE _q INTO cols USING _schema, _table1, _table2;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_trigger');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_trigger ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_trigger(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    EXECUTE 'CREATE OR REPLACE FUNCTION ' || quote_ident(tbl_schema)
	|| '.' || quote_ident('perform_audit_' || table_name)
	|| $ZZ$() RETURNS TRIGGER AS $TQ$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( OLD.*, 'DEL', now(),
			clock_timestamp(), txid_current(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( NEW.*, 'UPD', now(),
			clock_timestamp(), txid_current(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( NEW.*, 'INS', now(),
			clock_timestamp(), txid_current(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$TQ$ LANGUAGE plpgsql SECURITY DEFINER
    $ZZ$;

    EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident('trigger_audit_'
	|| table_name) || ' ON ' || quote_ident(tbl_schema) || '.'
	|| quote_ident(table_name);

    EXECUTE 'CREATE TRIGGER ' || quote_ident('trigger_audit_' || table_name)
	|| ' AFTER INSERT OR UPDATE OR DELETE ON ' || quote_ident(tbl_schema)
	|| '.' || quote_ident(table_name) || ' FOR EACH ROW EXECUTE PROCEDURE '
	|| quote_ident(tbl_schema) || '.' || quote_ident('perform_audit_'
	|| table_name) || '()';
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_stamp_triggers');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_stamp_triggers ( tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_stamp_triggers(tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    DECLARE
	tab RECORD;
    BEGIN
	FOR tab IN
	    SELECT table_name FROM information_schema.tables
	    WHERE table_schema = tbl_schema AND table_type = 'BASE TABLE'
	    AND table_name NOT LIKE 'aud$%'
	LOOP
	    PERFORM schema_support.rebuild_stamp_trigger
		(tbl_schema, tab.table_name);
	END LOOP;
    END;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	_or	RECORD;
	_nr	RECORD;
	_t1	integer;
	_t2	integer;
	_cols TEXT[];
	_q TEXT;
	_f TEXT;
	_c RECORD;
	_w TEXT[];
	_ctl TEXT[];
	_rv	boolean;
BEGIN
	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, new_rel;
		_rv := false;
	END IF;

	IF _t1 != _t2 THEN
		RAISE NOTICE 'table % has % rows; table % has % rows', old_rel, _t1, new_rel, _t2;
		_rv := false;
	END IF;

	IF NOT _rv THEN
		IF raise_exception THEN
			RAISE EXCEPTION 'Relations do not match';
		END IF;
		RETURN false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(schema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(schema, old_rel, new_rel);

	FOREACH _f IN ARRAY _cols
	LOOP
		SELECT array_append(_ctl,
			quote_ident(_f) || '::text') INTO _ctl;
	END LOOP;

	_cols := _ctl;

	_q := 'SELECT '|| array_to_string(_cols,',') ||' FROM ' || quote_ident(schema) || '.' ||
		quote_ident(old_rel);

	FOR _or IN EXECUTE _q
	LOOP
		_w = NULL;
		FOREACH _f IN ARRAY prikeys
		LOOP
			FOR _c IN SELECT * FROM json_each_text( row_to_json(_or) )
			LOOP
				IF _c.key = _f THEN
					SELECT array_append(_w,
						quote_ident(_f) || '::text = ' || quote_literal(_c.value))
					INTO _w;
				END IF;
			END LOOP;
		END LOOP;
		_q := 'SELECT ' || array_to_string(_cols,',') ||
			' FROM ' || quote_ident(schema) || '.' ||
			quote_ident(new_rel) || ' WHERE ' ||
			array_to_string(_w, ' AND ' );
		EXECUTE _q INTO _nr;

		IF _or != _nr THEN
			RAISE NOTICE 'mismatched row:';
			RAISE NOTICE 'OLD: %', row_to_json(_or);
			RAISE NOTICE 'NEW: %', row_to_json(_nr);
			_rv := false;
		END IF;

	END LOOP;

	IF NOT _rv AND raise_exception THEN
		RAISE EXCEPTION 'Relations do not match';
	END IF;
	return _rv;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'replay_object_recreates');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.replay_object_recreates ( beverbose boolean );
CREATE OR REPLACE FUNCTION schema_support.replay_object_recreates(beverbose boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_tally	integer;
BEGIN
	SELECT	count(*)
	  INTO	_tally
	  FROM	pg_catalog.pg_class
	 WHERE	relname = '__recreate'
	   AND	relpersistence = 't';

	IF _tally > 0 THEN
		FOR _r in SELECT * from __recreate ORDER BY id DESC FOR UPDATE
		LOOP
			IF beverbose THEN
				RAISE NOTICE 'Regrant: %.%', _r.schema, _r.object;
			END IF;
			EXECUTE _r.ddl;
			IF _r.owner is not NULL THEN
				IF _r.type = 'view' THEN
					EXECUTE 'ALTER VIEW ' || _r.schema || '.' || _r.object ||
						' OWNER TO ' || _r.owner || ';';
				ELSIF _r.type = 'function' THEN
					EXECUTE 'ALTER FUNCTION ' || _r.schema || '.' || _r.object ||
						'(' || _r.idargs || ') OWNER TO ' || _r.owner || ';';
				ELSE
					RAISE EXCEPTION 'Unable to restore grant for %', _r;
				END IF;
			END IF;
			DELETE from __recreate where id = _r.id;
		END LOOP;

		SELECT count(*) INTO _tally from __recreate;
		IF _tally > 0 THEN
			RAISE EXCEPTION '% objects still exist for recreating after a complete loop', _tally;
		ELSE
			DROP TABLE __recreate;
		END IF;
	ELSE
		IF beverbose THEN
			RAISE NOTICE '**** WARNING: replay_object_recreates did NOT have anything to regrant!';
		END IF;
	END IF;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'replay_saved_grants');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.replay_saved_grants ( beverbose boolean );
CREATE OR REPLACE FUNCTION schema_support.replay_saved_grants(beverbose boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_tally	integer;
BEGIN
	 SELECT  count(*)
      INTO  _tally
      FROM  pg_catalog.pg_class
     WHERE  relname = '__regrants'
       AND  relpersistence = 't';

	IF _tally > 0 THEN
	    FOR _r in SELECT * from __regrants FOR UPDATE
	    LOOP
		    IF beverbose THEN
			    RAISE NOTICE 'Regrant Executing: %', _r.regrant;
		    END IF;
		    EXECUTE _r.regrant;
		    DELETE from __regrants where id = _r.id;
	    END LOOP;

	    SELECT count(*) INTO _tally from __regrants;
	    IF _tally > 0 THEN
		    RAISE EXCEPTION 'Grant extractions were run while replaying grants - %.', _tally;
	    ELSE
		    DROP TABLE __regrants;
	    END IF;
	ELSE
		IF beverbose THEN
			RAISE NOTICE '**** WARNING: replay_saved_grants did NOT have anything to regrant!';
		END IF;
	END IF;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'retrieve_functions');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.retrieve_functions ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.retrieve_functions(schema character varying, object character varying, dropit boolean DEFAULT false)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_fn		TEXT;
	_cmd	TEXT;
	_rv		TEXT[];
BEGIN
	FOR _r IN SELECT n.nspname, p.proname,
				coalesce(u.usename, 'public') as owner,
				pg_get_functiondef(p.oid) as funcdef,
				pg_get_function_identity_arguments(p.oid) as idargs
		FROM    pg_catalog.pg_proc  p
				INNER JOIN pg_catalog.pg_namespace n on n.oid = p.pronamespace
				INNER JOIN pg_catalog.pg_language l on l.oid = p.prolang
				INNER JOIN pg_catalog.pg_user u on u.usesysid = p.proowner
		WHERE   n.nspname = schema
		  AND	p.proname = object
	LOOP
		_fn = _r.nspname || '.' || _r.proname || '(' || _r.idargs || ')';
		_rv = _rv || _fn;

		IF dropit  THEN
			_cmd = 'DROP FUNCTION ' || _fn || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
	RETURN _rv;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_constraint_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_constraint_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in 	SELECT n.nspname, c.relname, con.conname,
				pg_get_constraintdef(con.oid, true) as def
		FROM pg_constraint con
			INNER JOIN pg_class c on (c.relnamespace, c.oid) =
				(con.connamespace, con.conrelid)
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE con.confrelid in (
			select c.oid
			from pg_class c
				inner join pg_namespace n on n.oid = c.relnamespace
			WHERE c.relname = object
			AND n.nspname = schema
		) AND n.nspname != schema
	LOOP
		_ddl := 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
			' ADD CONSTRAINT ' || _r.conname || ' ' || _r.def;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define constraint for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, type, ddl )
			VALUES (
				_r.nspname, _r.relname, 'constraint', _ddl
			);
		IF dropit  THEN
			_cmd = 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
				' DROP CONSTRAINT ' || _r.conname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependent_objects_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$

DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	-- process stored procedures
	FOR _r in SELECT  distinct np.nspname::text, dependent.proname::text
		FROM   pg_depend dep
			INNER join pg_type dependee on dependee.oid = dep.refobjid
			INNER join pg_namespace n on n.oid = dependee.typnamespace
			INNER join pg_proc dependent on dependent.oid = dep.objid
			INNER join pg_namespace np on np.oid = dependent.pronamespace
			WHERE   dependee.typname = object
			  AND	  n.nspname = schema
	LOOP
		-- RAISE NOTICE '1 dealing with  %.%', _r.nspname, _r.proname;
		PERFORM schema_support.save_constraint_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit);
	END LOOP;

	-- save any triggers on the view
	FOR _r in SELECT distinct n.nspname::text, dependee.relname::text, dependee.relkind
		FROM pg_depend
		JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
		JOIN pg_class as dependee ON pg_rewrite.ev_class = dependee.oid
		JOIN pg_class as dependent ON pg_depend.refobjid = dependent.oid
		JOIN pg_namespace n on n.oid = dependee.relnamespace
		JOIN pg_namespace sn on sn.oid = dependent.relnamespace
		JOIN pg_attribute ON pg_depend.refobjid = pg_attribute.attrelid
   			AND pg_depend.refobjsubid = pg_attribute.attnum
		WHERE dependent.relname = object
  		AND sn.nspname = schema
	LOOP
		IF _r.relkind = 'v' THEN
			-- RAISE NOTICE '2 dealing with  %.%', _r.nspname, _r.relname;
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);
		PERFORM schema_support.save_constraint_for_replay('jazzhands', 'table');
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_function_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_function_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_function_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object);
	FOR _r IN SELECT n.nspname, p.proname,
				coalesce(u.usename, 'public') as owner,
				pg_get_functiondef(p.oid) as funcdef,
				pg_get_function_identity_arguments(p.oid) as idargs
		FROM    pg_catalog.pg_proc  p
				INNER JOIN pg_catalog.pg_namespace n on n.oid = p.pronamespace
				INNER JOIN pg_catalog.pg_language l on l.oid = p.prolang
				INNER JOIN pg_catalog.pg_user u on u.usesysid = p.proowner
		WHERE   n.nspname = schema
		  AND	p.proname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, owner, ddl, idargs )
		VALUES (
			_r.nspname, _r.proname, 'function', _r.owner, _r.funcdef, _r.idargs
		);
		IF dropit  THEN
			_cmd = 'DROP FUNCTION ' || _r.nspname || '.' ||
				_r.proname || '(' || _r.idargs || ');';
			EXECUTE _cmd;
		END IF;

	END LOOP;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_functions');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_functions ( schema character varying, object character varying, newname character varying );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_functions(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_schema		varchar;
	_object		varchar;
	_procs		RECORD;
	_perm		RECORD;
	_grant		varchar;
	_role		varchar;
	_fullgrant		varchar;
BEGIN
	_schema := schema;
	_object := object;
	if newname IS NULL THEN
		newname := _object;
	END IF;
	PERFORM schema_support.prepare_for_grant_replay();
	FOR _procs IN SELECT  n.nspname as schema, p.proname,
			pg_get_function_identity_arguments(p.oid) as args,
			proacl as privs
		FROM    pg_catalog.pg_proc  p
				inner join pg_catalog.pg_namespace n on n.oid = p.pronamespace
		WHERE   n.nspname = _schema
		 AND    p.proname = _object
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _procs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on FUNCTION ' ||
				_schema || '.' ||
				newname || '(' || _procs.args || ')  to ' ||
				_role || _grant;
			-- RAISE DEBUG 'inserting % for %', _fullgrant, _perm;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_relations');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_relations ( schema character varying, object character varying, newname character varying );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_schema		varchar;
	_object	varchar;
	_tabs		RECORD;
	_perm		RECORD;
	_grant		varchar;
	_fullgrant		varchar;
	_role		varchar;
BEGIN
	_schema := schema;
	_object := object;
	if newname IS NULL THEN
		newname := _object;
	END IF;
	PERFORM schema_support.prepare_for_grant_replay();

	-- Handle table wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			c.relacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

	-- Handle column specific wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			a.attname as col,
			a.attacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
                ON a.attrelid = c.oid
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND a.attacl IS NOT NULL
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || '(' || _tabs.col || ')'
				' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_trigger_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_trigger_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_trigger_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in
		SELECT n.nspname, c.relname, trg.tgname,
				pg_get_triggerdef(trg.oid, true) as def
		FROM pg_trigger trg
			INNER JOIN pg_class c on trg.tgrelid =  c.oid
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE n.nspname = schema and c.relname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, ddl )
			VALUES (
				_r.nspname, _r.relname, 'trigger', _r.def
			);
		IF dropit  THEN
			_cmd = 'DROP TRIGGER ' || _r.tgname || ' ON ' ||
				_r.nspname || '.' || _r.relname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'undo_audit_row');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.undo_audit_row ( in_table text, in_audit_schema text, in_schema text, in_start_time timestamp without time zone, in_end_time timestamp without time zone, in_aud_user text, in_audit_ids integer[] );
CREATE OR REPLACE FUNCTION schema_support.undo_audit_row(in_table text, in_audit_schema text DEFAULT 'audit'::text, in_schema text DEFAULT 'jazzhands'::text, in_start_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_end_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_aud_user text DEFAULT NULL::text, in_audit_ids integer[] DEFAULT NULL::integer[])
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
	tally	integer;
	pks		text[];
	cols	text[];
	q		text;
	val		text;
	x		text;
	_whcl	text;
	_eq		text;
	setstr	text;
	_r		record;
	_c		record;
	_br		record;
	_vals	text[];
BEGIN
	tally := 0;
	pks := schema_support.get_pk_columns(in_schema, in_table);
	cols := schema_support.get_columns(in_schema, in_table);
	q = '';
	IF in_start_time is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#timestamp') || ' >= ' || quote_literal(in_start_time);
	END IF;
	IF in_end_time is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#timestamp') || ' <= ' || quote_literal(in_end_time);
	END IF;
	IF in_aud_user is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#user') || ' = ' || quote_literal(in_aud_user);
	END IF;
	IF in_audit_ids is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#seq') || ' IN ( ' ||
			array_to_string(in_audit_ids, ',') || ')';
	END IF;

	-- Iterate over all the rows that need to be replayed
	q := 'SELECT * from ' || quote_ident(in_audit_schema) || '.' ||
			quote_ident(in_table) || ' ' || q || ' ORDER BY "aud#seq" desc';
	FOR _r IN EXECUTE q
	LOOP
		IF _r."aud#action" = 'DEL' THEN
			-- Build up a list of rows that need to be inserted
			_vals = NULL;
			FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
			LOOP
				IF _c.key !~ 'data|aud' THEN
					IF _c.value IS NULL THEN
						SELECT array_append(_vals, 'NULL') INTO _vals;
					ELSE
						SELECT array_append(_vals, quote_literal(_c.value)) INTO _vals;
					END IF;
				END IF;
			END LOOP;
			_eq := 'INSERT INTO ' || quote_ident(in_schema) || '.' ||
				quote_ident(in_table) || ' ( ' ||
				array_to_string(
					schema_support.quote_ident_array(cols), ',') ||
					') VALUES (' ||  array_to_string(_vals, ',', NULL) || ')';
		ELSIF _r."aud#action" in ('INS', 'UPD') THEN
			-- Build up a where clause for this table to get a unique row
			-- based on the primary key
			FOREACH x IN ARRAY pks
			LOOP
				_whcl := '';
				FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
				LOOP
					IF _c.key = x THEN
						IF _whcl != '' THEN
							_whcl := _whcl || ', ';
						END IF;
						IF _c.value IS NULL THEN
							_whcl = _whcl || quote_ident(_c.key) || ' = NULL ';
						ELSE
							_whcl = _whcl || quote_ident(_c.key) || ' =  ' ||
								quote_nullable(_c.value);
						END IF;
					END IF;
				END LOOP;
			END LOOP;

			IF _r."aud#action" = 'INS' THEN
				_eq := 'DELETE FROM ' || quote_ident(in_schema) || '.' ||
					quote_ident(in_table) || ' WHERE ' || _whcl;
			ELSIF _r."aud#action" = 'UPD' THEN
				-- figure out what rows have changed and do an update if
				-- they have.  NOTE:  This may result in no change being
				-- replayed if a row did not actually change
				setstr = '';
				FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
				LOOP
					--
					-- Iterate over all the columns and if they have changed,
					-- then build an update statement
					--
					IF _c.key !~ 'aud#|data_(ins|upd)_(user|date)' THEN
						EXECUTE 'SELECT ' || _c.key || ' FROM ' ||
							quote_ident(in_schema) || '.' ||
								quote_ident(in_table)  ||
							' WHERE ' || _whcl
							INTO val;
						IF ( _c.value IS NULL  AND val IS NOT NULL) OR
							( _c.value IS NOT NULL AND val IS NULL) OR
							(_c.value::text NOT SIMILAR TO val::text) THEN
							IF char_length(setstr) > 0 THEN
								setstr = setstr || ',
								';
							END IF;
							IF _c.value IS NOT  NULL THEN
								setstr = setstr || _c.key || ' = ' ||
									quote_nullable(_c.value) || ' ' ;
							ELSE
								setstr = setstr || _c.key || ' = ' ||
									' NULL ' ;
							END IF;
						END IF;
					END IF;
				END LOOP;
				IF char_length(setstr) > 0 THEN
					_eq := 'UPDATE ' || quote_ident(in_schema) || '.' ||
						quote_ident(in_table) ||
						' SET ' || setstr || ' WHERE ' || _whcl;
				END IF;
			END IF;
		END IF;
		IF _eq IS NOT NULL THEN
			tally := tally + 1;
			RAISE NOTICE '%', _eq;
			EXECUTE _eq;
		END IF;
	END LOOP;
	RETURN tally;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.mv_last_updated(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO schema_support
AS $function$
DECLARE
	rv	timestamp;
BEGIN
	IF debug THEN
		RAISE NOTICE 'selecting for update...';
	END IF;

	SELECT	refresh
	INTO	rv
	FROM	schema_support.mv_refresh r
	WHERE	r.schema = mv_last_updated.schema
	AND	r.view = relation
	FOR UPDATE;

	IF debug THEN
		RAISE NOTICE 'returning %', rv;
	END IF;

	RETURN rv;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	idx		text[];
	keys	text[];
	cols	text[];
	i		text;
	seq		integer;
BEGIN
	-- rename all the old indexes and constraints on the old audit table
	SELECT	array_agg(c2.relname)
		INTO	 idx
		  FROM	pg_catalog.pg_index i
			LEFT JOIN pg_catalog.pg_class c
				ON c.oid = i.indrelid
			LEFT JOIN pg_catalog.pg_class c2
				ON i.indexrelid = c2.oid
			LEFT JOIN pg_catalog.pg_namespace n
				ON c2.relnamespace = n.oid
			LEFT JOIN pg_catalog.pg_constraint con
				ON (conrelid = i.indrelid
				AND conindid = i.indexrelid
				AND contype IN ('p','u','x'))
		 WHERE n.nspname = quote_ident(aud_schema)
		  AND	c.relname = quote_ident(table_name)
		  AND	contype is NULL
	;

	SELECT array_agg(con.conname)
	INTO	keys
    FROM pg_catalog.pg_class c
		INNER JOIN pg_namespace n
			ON relnamespace = n.oid
		INNER JOIN pg_catalog.pg_index i
			ON c.oid = i.indrelid
		INNER JOIN pg_catalog.pg_class c2
			ON i.indexrelid = c2.oid
		INNER JOIN pg_catalog.pg_constraint con ON
			(con.conrelid = i.indrelid
			AND con.conindid = i.indexrelid )
	WHERE  	n.nspname = quote_ident(aud_schema)
	AND		c.relname = quote_ident(table_name)
	AND con.contype in ('p', 'u')
	;

	FOREACH i IN ARRAY idx
	LOOP
		EXECUTE 'ALTER INDEX '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(i)
			|| ' RENAME TO '
			|| quote_ident('_' || i);
	END LOOP;

	IF array_length(keys, 1) > 0 THEN
		FOREACH i IN ARRAY keys
		LOOP
			EXECUTE 'ALTER TABLE '
				|| quote_ident(aud_schema) || '.'
				|| quote_ident(table_name)
				|| ' RENAME CONSTRAINT '
				|| quote_ident(i)
				|| ' TO '
			|| quote_ident('__old__' || i);
		END LOOP;
	END IF;

	--
	-- get columns
	--
	SELECT	array_agg(quote_ident(a.attname) ORDER BY a.attnum)
	INTO	cols
	FROM	pg_catalog.pg_attribute a
	INNER JOIN pg_catalog.pg_class c on a.attrelid = c.oid
	INNER JOIN pg_catalog.pg_namespace n on n.oid = c.relnamespace
	LEFT JOIN pg_catalog.pg_description d
			on d.objoid = a.attrelid
			and d.objsubid = a.attnum
	WHERE  	n.nspname = quote_ident(aud_schema)
	  AND	c.relname = quote_ident(table_name)
	  AND 	a.attnum > 0
	  AND 	NOT a.attisdropped
	;

	--
	-- rename table
	--
	EXECUTE 'ALTER TABLE '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name)
		|| ' RENAME TO '
		|| quote_ident('__old__' || table_name);


	--
	-- RENAME sequence
	--
	EXECUTE 'ALTER SEQUENCE '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name || '_seq')
		|| ' RENAME TO '
		|| quote_ident('_old_' || table_name || '_seq');

	--
	-- create a new audit table
	--
	PERFORM schema_support.build_audit_table(aud_schema,tbl_schema,table_name);

	EXECUTE 'INSERT INTO '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' ( '
		|| array_to_string(cols, ',') || ' ) SELECT '
		|| array_to_string(cols, ',') || ' FROM '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__' || table_name)
		|| ' ORDER BY '
		|| quote_ident('aud#seq');

	--
	-- fix sequence primary key to have the correct next value
	--
	EXECUTE 'SELECT max("aud#seq") + 1 FROM	 '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name) INTO seq;
	IF seq IS NOT NULL THEN
		EXECUTE 'ALTER SEQUENCE '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name || '_seq')
			|| ' RESTART WITH ' || seq;
	END IF;

	EXECUTE 'DROP TABLE '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__' || table_name);

	--
	-- drop audit sequence, in case it was nto dropped with table.
	--
	EXECUTE 'DROP SEQUENCE IF EXISTS '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('_old_' || table_name || '_seq');

	--
	-- drop indexes found before that did not get dropped.
	--
	FOR i IN SELECT	c2.relname
		  FROM	pg_catalog.pg_index i
			LEFT JOIN pg_catalog.pg_class c
				ON c.oid = i.indrelid
			LEFT JOIN pg_catalog.pg_class c2
				ON i.indexrelid = c2.oid
			LEFT JOIN pg_catalog.pg_namespace n
				ON c2.relnamespace = n.oid
			LEFT JOIN pg_catalog.pg_constraint con
				ON (conrelid = i.indrelid
				AND conindid = i.indexrelid
				AND contype IN ('p','u','x'))
		 WHERE n.nspname = quote_ident(aud_schema)
		  AND	c.relname = quote_ident('__old__' || table_name)
		  AND	contype is NULL
	LOOP
		EXECUTE 'DROP INDEX '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident('_' || i);
	END LOOP;


	--
	-- recreate audit trigger
	--
	PERFORM schema_support.rebuild_audit_trigger (
		aud_schema, tbl_schema, table_name );

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT b.table_name
	FROM information_schema.tables b
		INNER JOIN information_schema.tables a
			USING (table_name,table_type)
	WHERE table_type = 'BASE TABLE'
	AND a.table_schema = aud_schema
	AND b.table_schema = tbl_schema
	ORDER BY table_name
    LOOP
	PERFORM schema_support.save_dependent_objects_for_replay(aud_schema::varchar, table_list.table_name::varchar);
	PERFORM schema_support.rebuild_audit_table
	    ( aud_schema, tbl_schema, table_list.table_name );
	PERFORM schema_support.replay_object_recreates();
	PERFORM schema_support.replay_saved_grants();
    END LOOP;

    PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.refresh_mv_if_needed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	lastref	timestamp;
	lastdat	timestamp;
BEGIN
	SELECT coalesce(schema_support.mv_last_updated(relation, schema,debug),'-infinity') INTO lastref;
	SELECT coalesce(schema_support.relation_last_changed(relation, schema,debug),'-infinity') INTO lastdat;
	IF lastdat > lastref THEN
		EXECUTE 'REFRESH MATERIALIZED VIEW ' || quote_ident(schema)||'.'||quote_ident(relation);
		PERFORM schema_support.set_mv_last_updated(relation, schema);
	END IF;
	RETURN;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	audsch	text;
	rk	char;
	rv	timestamp;
	ts	timestamp;
	obj	text;
	objaud text;
BEGIN
	SELECT	audit_schema
	INTO	audsch
	FROM	schema_support.schema_audit_map m
	WHERE	m.schema = relation_last_changed.schema;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Schema % not configured for this', schema;
	END IF;

	SELECT 	relkind
	INTO	rk
	FROM	pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE	n.nspname = relation_last_changed.schema
	AND	c.relname = relation_last_changed.relation;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'No such object %.%', schema, relation;
	END IF;

	IF rk = 'r' THEN
		EXECUTE '
			SELECT	max("aud#timestamp")
			FROM	'||quote_ident(audsch)||'.'||quote_ident(relation)
		INTO rv;

		IF rv IS NULL THEN
			RETURN '-infinity'::interval;
		ELSE
			RETURN rv;
		END IF;
	END IF;

	IF rk = 'v' OR rk = 'm' THEN
		FOR obj,objaud IN WITH RECURSIVE recur AS (
				SELECT distinct rewrite.ev_class as root_oid, d.refobjid as oid
				FROM pg_depend d
        			JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
					JOIN pg_class c on rewrite.ev_class = c.oid
					JOIN pg_namespace n on n.oid = c.relnamespace
				WHERE c.relname = relation
				AND n.nspname = relation_last_changed.schema
				AND d.refobjsubid > 0
			UNION ALL
				SELECT recur.root_oid, d.refobjid as oid
				FROM pg_depend d
        			JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
				JOIN recur ON recur.oid = rewrite.ev_class
				AND d.refobjsubid > 0
			), list AS ( select distinct m.audit_schema, c.relname, c.relkind, recur.*
				FROM pg_class c
					JOIN recur on recur.oid = c.oid
					JOIN pg_namespace n on c.relnamespace = n.oid
					JOIN schema_support.schema_audit_map m
						ON m.schema = n.nspname
				WHERE relkind = 'r'
			) SELECT relname, audit_schema from list
		LOOP
			-- if there is no audit table, assume its kept current.  This is
			-- likely some sort of cache table.  XXX - should probably be
			-- updated to use the materialized view update bits
			BEGIN
				EXECUTE 'SELECT max("aud#timestamp")
					FROM '||quote_ident(objaud)||'.'|| quote_ident(obj)
					INTO ts;
				IF debug THEN
					RAISE NOTICE '%.% -> %', objaud, obj, ts;
				END IF;
				IF rv IS NULL OR ts > rv THEN
					rv := ts;
				END IF;
			EXCEPTION WHEN undefined_table THEN
				IF debug THEN
					RAISE NOTICE 'skipping %.%', schema, obj;
				END IF;
			END;
		END LOOP;
		RETURN rv;
	END IF;

	RAISE EXCEPTION 'Unable to process relkind %', rk;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.reset_all_schema_table_sequences(schema text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	_r	RECORD;
	tally INTEGER;
BEGIN
	tally := 0;
	FOR _r IN

		SELECT n.nspname, c.relname, c.relkind
		FROM	pg_class c
				INNER JOIN pg_namespace n ON n.oid = c.relnamespace
		WHERE	n.nspname = schema
		AND		c.relkind = 'r'
	LOOP
		PERFORM schema_support.reset_table_sequence(_r.nspname::text, _r.relname::text);
		tally := tally + 1;
	END LOOP;
	RETURN tally;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.reset_table_sequence(schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	_r	RECORD;
	m	BIGINT;
BEGIN
	FOR _r IN
		WITH s AS (
			SELECT	pg_get_serial_sequence(schema||'.'||table_name,
				a.attname) as seq, a.attname as column
			FROM	pg_attribute a
			JOIN pg_class c ON c.oid = a.attrelid
			JOIN pg_namespace n ON n.oid = c.relnamespace
			WHERE	c.relname = table_name
			AND	n.nspname = schema
				AND 	a.attnum > 0
				AND 	NOT a.attisdropped
		) SELECT s.*, nextval(s.seq) as nv FROM s WHERE seq IS NOT NULL
	LOOP
		EXECUTE 'SELECT max('||quote_ident(_r.column)||')+1 FROM  '
			|| quote_ident(schema)||'.'||quote_ident(table_name)
			INTO m;
		IF m IS NOT NULL THEN
			IF _r.nv > m THEN
				m := _r.nv;
			END IF;
			EXECUTE 'ALTER SEQUENCE ' || _r.seq || ' RESTART WITH '
				|| m;
		END IF;
	END LOOP;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.set_mv_last_updated(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO schema_support
AS $function$
DECLARE
	rv	timestamp;
BEGIN
	INSERT INTO schema_support.mv_refresh AS r (
		schema, view, refresh
	) VALUES (
		set_mv_last_updated.schema, relation, now()
	) ON CONFLICT ON CONSTRAINT mv_refresh_pkey DO UPDATE
		SET		refresh = now()
		WHERE	r.schema = set_mv_last_updated.schema
		AND		r.view = relation
	;

	RETURN rv;
END;
$function$
;

--
-- Process middle (non-trigger) schema script_hooks
--
--
-- Process middle (non-trigger) schema backend_utils
--
-- New function
CREATE OR REPLACE FUNCTION backend_utils.refresh_if_needed(object text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	rk char;
BEGIN
	SELECT  relkind
	INTO    rk
	FROM    pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE   n.nspname = 'jazzhands'
	AND     c.relname = relation_last_changed.relation;

	-- silently ignore things that are not materialized views
	IF rk = 'm' THEN
		PERFORM schema_support.refresh_mv_if_needed(object, 'jazzhands');
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION backend_utils.relation_last_changed(view text)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	RETURN schema_support.relation_last_changed(view);
END;
$function$
;



-- BEGIN Misc that does not apply to above
SELECT schema_support.save_dependent_objects_for_replay
        ('audit', 'person_company');
SELECT schema_support.rebuild_audit_table
        ('audit', 'jazzhands', 'person_company');

SELECT schema_support.save_dependent_objects_for_replay
        ('audit', 'account_collection_account');
SELECT schema_support.rebuild_audit_table
        ('audit', 'jazzhands', 'account_collection_account');

SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();


-- END Misc that does not apply to above
-- Creating new sequences....
CREATE SEQUENCE certificate_signing_request_certificate_signing_request_id_seq;
CREATE SEQUENCE private_key_private_key_id_seq;
CREATE SEQUENCE x509_signed_certificate_x509_signed_certificate_id_seq;


--------------------------------------------------------------------
-- DEALING WITH TABLE val_account_collection_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_account_collection_type', 'val_account_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE account_realm_acct_coll_type DROP CONSTRAINT IF EXISTS fk_acct_realm_acct_coll_typ;
ALTER TABLE account_collection DROP CONSTRAINT IF EXISTS fk_acctcol_usrcoltyp;
ALTER TABLE val_property_type DROP CONSTRAINT IF EXISTS fk_prop_typ_pv_uctyp_rst;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_val_prop_acct_coll_type;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_account_collection_type DROP CONSTRAINT IF EXISTS r_785;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_account_collection_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_account_collection_type DROP CONSTRAINT IF EXISTS pk_val_account_collection_type;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1val_account_collection_typ";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_account_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_1816418084;
ALTER TABLE jazzhands.val_account_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_act_chh;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_account_collection_type_realm ON jazzhands.val_account_collection_type;
DROP TRIGGER IF EXISTS trig_userlog_val_account_collection_type ON jazzhands.val_account_collection_type;
DROP TRIGGER IF EXISTS trigger_audit_val_account_collection_type ON jazzhands.val_account_collection_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_account_collection_type');
---- BEGIN audit.val_account_collection_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_account_collection_type', 'val_account_collection_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_account_collection_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_account_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_account_collection_type');
---- DONE audit.val_account_collection_type TEARDOWN


ALTER TABLE val_account_collection_type RENAME TO val_account_collection_type_v71;
ALTER TABLE audit.val_account_collection_type RENAME TO val_account_collection_type_v71;

CREATE TABLE val_account_collection_type
(
	account_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	is_infrastructure_type	character(1) NOT NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	account_realm_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_account_collection_type', false);
ALTER TABLE val_account_collection_type
	ALTER is_infrastructure_type
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_account_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_account_collection_type (
	account_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	account_realm_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	account_realm_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_account_collection_type_v71;

INSERT INTO audit.val_account_collection_type (
	account_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	account_realm_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	account_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	account_realm_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.val_account_collection_type_v71;

ALTER TABLE val_account_collection_type
	ALTER is_infrastructure_type
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_account_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_account_collection_type ADD CONSTRAINT pk_val_account_collection_type PRIMARY KEY (account_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_account_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';
COMMENT ON COLUMN val_account_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_account_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
COMMENT ON COLUMN val_account_collection_type.account_realm_id IS 'If set, all accounts in this collection must be of this realm, and all child account collections of this one must have the realm set to be the same.';
-- INDEXES
CREATE INDEX xif1val_account_collection_typ ON val_account_collection_type USING btree (account_realm_id);

-- CHECK CONSTRAINTS
ALTER TABLE val_account_collection_type ADD CONSTRAINT check_yes_no_1816418084
	CHECK (is_infrastructure_type = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_account_collection_type ADD CONSTRAINT check_yes_no_act_chh
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_account_collection_type and account_realm_acct_coll_type
ALTER TABLE account_realm_acct_coll_type
	ADD CONSTRAINT fk_acct_realm_acct_coll_typ
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK between val_account_collection_type and account_collection
ALTER TABLE account_collection
	ADD CONSTRAINT fk_acctcol_usrcoltyp
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK between val_account_collection_type and val_property_type
ALTER TABLE val_property_type
	ADD CONSTRAINT fk_prop_typ_pv_uctyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK between val_account_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_acct_coll_type
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK between val_account_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);

-- FOREIGN KEYS TO
-- consider FK val_account_collection_type and account_realm
ALTER TABLE val_account_collection_type
	ADD CONSTRAINT fk_account_realm_ac_type
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);

-- TRIGGERS
-- consider NEW jazzhands.account_collection_type_realm
CREATE OR REPLACE FUNCTION jazzhands.account_collection_type_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF NEW.account_realm_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account_collection USING (account_collection_id)
			JOIN account a USING (account_id)
	WHERE	account_collection_type = NEW.account_collection_type
	AND		a.account_realm_id != NEW.account_realm_id;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are accounts assigned that do not match it'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	-- This is probably useless.
	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_hier h
			JOIN account_collection pac USING (account_collection_id)
			JOIN val_account_collection_type pat USING (account_collection_type)
			JOIN account_collection cac ON
				h.child_account_collection_id = cac.account_collection_id
			JOIN val_account_collection_type cat ON
				cac.account_collection_type = cat.account_collection_type
	WHERE	(
				pac.account_collection_type = NEW.account_collection_type
			OR
				cac.account_collection_type = NEW.account_collection_type
			)
	AND		(
				pat.account_realm_id IS DISTINCT FROM NEW.account_realm_id
			OR
				cat.account_realm_id IS DISTINCT FROM NEW.account_realm_id
			)
	;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are account collections in the hierarchy that do not match'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trig_account_collection_type_realm AFTER UPDATE OF account_realm_id ON val_account_collection_type FOR EACH ROW EXECUTE PROCEDURE account_collection_type_realm();

-- XXX - may need to include trigger function
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_account_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_account_collection_type');
DROP TABLE IF EXISTS val_account_collection_type_v71;
DROP TABLE IF EXISTS audit.val_account_collection_type_v71;
-- DONE DEALING WITH TABLE val_account_collection_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_company_collection_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_company_collection_type', 'val_company_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE company_collection DROP CONSTRAINT IF EXISTS fk_comp_coll_com_coll_type;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_val_prop_comp_coll_type;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_company_collection_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_company_collection_type DROP CONSTRAINT IF EXISTS pk_company_collection_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_company_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_1614108214;
ALTER TABLE jazzhands.val_company_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_845966153;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_company_collection_type ON jazzhands.val_company_collection_type;
DROP TRIGGER IF EXISTS trigger_audit_val_company_collection_type ON jazzhands.val_company_collection_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_company_collection_type');
---- BEGIN audit.val_company_collection_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_company_collection_type', 'val_company_collection_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_company_collection_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_company_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_company_collection_type');
---- DONE audit.val_company_collection_type TEARDOWN


ALTER TABLE val_company_collection_type RENAME TO val_company_collection_type_v71;
ALTER TABLE audit.val_company_collection_type RENAME TO val_company_collection_type_v71;

CREATE TABLE val_company_collection_type
(
	company_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	is_infrastructure_type	character(1) NOT NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_company_collection_type', false);
ALTER TABLE val_company_collection_type
	ALTER is_infrastructure_type
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_company_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_company_collection_type (
	company_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	company_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_company_collection_type_v71;

INSERT INTO audit.val_company_collection_type (
	company_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	company_collection_type,
	description,
	is_infrastructure_type,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.val_company_collection_type_v71;

ALTER TABLE val_company_collection_type
	ALTER is_infrastructure_type
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_company_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_company_collection_type ADD CONSTRAINT pk_company_collection_type PRIMARY KEY (company_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_company_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';
COMMENT ON COLUMN val_company_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_company_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_company_collection_type ADD CONSTRAINT check_yes_no_1614108214
	CHECK (is_infrastructure_type = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_company_collection_type ADD CONSTRAINT check_yes_no_845966153
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_company_collection_type and company_collection
ALTER TABLE company_collection
	ADD CONSTRAINT fk_comp_coll_com_coll_type
	FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type);
-- consider FK between val_company_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_comp_coll_type
	FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_company_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_company_collection_type');
DROP TABLE IF EXISTS val_company_collection_type_v71;
DROP TABLE IF EXISTS audit.val_company_collection_type_v71;
-- DONE DEALING WITH TABLE val_company_collection_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_device_collection_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_device_collection_type', 'val_device_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE device_collection DROP CONSTRAINT IF EXISTS fk_devc_devctyp_id;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_prop_val_devcol_typ_rstr_dc;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_prop_val_devcoll_id;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_device_collection_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_device_collection_type DROP CONSTRAINT IF EXISTS pk_val_device_collection_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_device_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_dct_chh;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_device_collection_type ON jazzhands.val_device_collection_type;
DROP TRIGGER IF EXISTS trigger_audit_val_device_collection_type ON jazzhands.val_device_collection_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_device_collection_type');
---- BEGIN audit.val_device_collection_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_device_collection_type', 'val_device_collection_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_device_collection_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_device_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_device_collection_type');
---- DONE audit.val_device_collection_type TEARDOWN


ALTER TABLE val_device_collection_type RENAME TO val_device_collection_type_v71;
ALTER TABLE audit.val_device_collection_type RENAME TO val_device_collection_type_v71;

CREATE TABLE val_device_collection_type
(
	device_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_device_collection_type', false);
ALTER TABLE val_device_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_device_collection_type (
	device_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	device_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_device_collection_type_v71;

INSERT INTO audit.val_device_collection_type (
	device_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	device_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.val_device_collection_type_v71;

ALTER TABLE val_device_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_device_collection_type ADD CONSTRAINT pk_val_device_collection_type PRIMARY KEY (device_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_device_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';
COMMENT ON COLUMN val_device_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_device_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_device_collection_type ADD CONSTRAINT check_yes_no_dct_chh
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_device_collection_type and device_collection
ALTER TABLE device_collection
	ADD CONSTRAINT fk_devc_devctyp_id
	FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK between val_device_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcol_typ_rstr_dc
	FOREIGN KEY (prop_val_dev_coll_type_rstrct) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK between val_device_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcoll_id
	FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_device_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_device_collection_type');
DROP TABLE IF EXISTS val_device_collection_type_v71;
DROP TABLE IF EXISTS audit.val_device_collection_type_v71;
-- DONE DEALING WITH TABLE val_device_collection_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_layer2_network_coll_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_layer2_network_coll_type', 'val_layer2_network_coll_type');

-- FOREIGN KEYS FROM
ALTER TABLE layer2_network_collection DROP CONSTRAINT IF EXISTS fk_l2netcoll_type;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_val_prop_l2netype;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_layer2_network_coll_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_layer2_network_coll_type DROP CONSTRAINT IF EXISTS pk_val_layer2_network_coll_typ;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_layer2_network_coll_type DROP CONSTRAINT IF EXISTS check_yes_no_2053022263;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_layer2_network_coll_type ON jazzhands.val_layer2_network_coll_type;
DROP TRIGGER IF EXISTS trigger_audit_val_layer2_network_coll_type ON jazzhands.val_layer2_network_coll_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_layer2_network_coll_type');
---- BEGIN audit.val_layer2_network_coll_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_layer2_network_coll_type', 'val_layer2_network_coll_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_layer2_network_coll_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_layer2_network_coll_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_layer2_network_coll_type');
---- DONE audit.val_layer2_network_coll_type TEARDOWN


ALTER TABLE val_layer2_network_coll_type RENAME TO val_layer2_network_coll_type_v71;
ALTER TABLE audit.val_layer2_network_coll_type RENAME TO val_layer2_network_coll_type_v71;

CREATE TABLE val_layer2_network_coll_type
(
	layer2_network_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_layer2_network_coll_type', false);
ALTER TABLE val_layer2_network_coll_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_layer2_network_coll_type (
	layer2_network_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	layer2_network_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_layer2_network_coll_type_v71;

INSERT INTO audit.val_layer2_network_coll_type (
	layer2_network_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	layer2_network_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.val_layer2_network_coll_type_v71;

ALTER TABLE val_layer2_network_coll_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_layer2_network_coll_type ADD CONSTRAINT pk_val_layer2_network_coll_typ PRIMARY KEY (layer2_network_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_layer2_network_coll_type.max_num_members IS 'Maximum number of members in a given collection of this type
';
COMMENT ON COLUMN val_layer2_network_coll_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_layer2_network_coll_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_layer2_network_coll_type ADD CONSTRAINT check_yes_no_2053022263
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_layer2_network_coll_type and layer2_network_collection
ALTER TABLE layer2_network_collection
	ADD CONSTRAINT fk_l2netcoll_type
	FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_coll_type(layer2_network_collection_type);
-- consider FK between val_layer2_network_coll_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_l2netype
	FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_coll_type(layer2_network_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_layer2_network_coll_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_layer2_network_coll_type');
DROP TABLE IF EXISTS val_layer2_network_coll_type_v71;
DROP TABLE IF EXISTS audit.val_layer2_network_coll_type_v71;
-- DONE DEALING WITH TABLE val_layer2_network_coll_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_layer3_network_coll_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_layer3_network_coll_type', 'val_layer3_network_coll_type');

-- FOREIGN KEYS FROM
ALTER TABLE layer3_network_collection DROP CONSTRAINT IF EXISTS fk_l3_netcol_netcol_type;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_val_prop_l3netwok_type;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_layer3_network_coll_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_layer3_network_coll_type DROP CONSTRAINT IF EXISTS pk_val_layer3_network_coll_typ;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_layer3_network_coll_type DROP CONSTRAINT IF EXISTS check_yes_no_l3nc_chh;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_layer3_network_coll_type ON jazzhands.val_layer3_network_coll_type;
DROP TRIGGER IF EXISTS trigger_audit_val_layer3_network_coll_type ON jazzhands.val_layer3_network_coll_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_layer3_network_coll_type');
---- BEGIN audit.val_layer3_network_coll_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_layer3_network_coll_type', 'val_layer3_network_coll_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_layer3_network_coll_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_layer3_network_coll_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_layer3_network_coll_type');
---- DONE audit.val_layer3_network_coll_type TEARDOWN


ALTER TABLE val_layer3_network_coll_type RENAME TO val_layer3_network_coll_type_v71;
ALTER TABLE audit.val_layer3_network_coll_type RENAME TO val_layer3_network_coll_type_v71;

CREATE TABLE val_layer3_network_coll_type
(
	layer3_network_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_layer3_network_coll_type', false);
ALTER TABLE val_layer3_network_coll_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_layer3_network_coll_type (
	layer3_network_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	layer3_network_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_layer3_network_coll_type_v71;

INSERT INTO audit.val_layer3_network_coll_type (
	layer3_network_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	layer3_network_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.val_layer3_network_coll_type_v71;

ALTER TABLE val_layer3_network_coll_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_layer3_network_coll_type ADD CONSTRAINT pk_val_layer3_network_coll_typ PRIMARY KEY (layer3_network_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_layer3_network_coll_type.max_num_members IS 'Maximum number of members in a given collection of this type
';
COMMENT ON COLUMN val_layer3_network_coll_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_layer3_network_coll_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_layer3_network_coll_type ADD CONSTRAINT check_yes_no_l3nc_chh
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_layer3_network_coll_type and layer3_network_collection
ALTER TABLE layer3_network_collection
	ADD CONSTRAINT fk_l3_netcol_netcol_type
	FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_coll_type(layer3_network_collection_type);
-- consider FK between val_layer3_network_coll_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_l3netwok_type
	FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_coll_type(layer3_network_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_layer3_network_coll_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_layer3_network_coll_type');
DROP TABLE IF EXISTS val_layer3_network_coll_type_v71;
DROP TABLE IF EXISTS audit.val_layer3_network_coll_type_v71;
-- DONE DEALING WITH TABLE val_layer3_network_coll_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_netblock_collection_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_netblock_collection_type', 'val_netblock_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE netblock_collection DROP CONSTRAINT IF EXISTS fk_nblk_coll_v_nblk_c_typ;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_val_property_netblkcolltype;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_netblock_collection_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_netblock_collection_type DROP CONSTRAINT IF EXISTS pk_val_netblock_collection_typ;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_netblock_collection_type DROP CONSTRAINT IF EXISTS check_any_yes_no_nc_singaddr_r;
ALTER TABLE jazzhands.val_netblock_collection_type DROP CONSTRAINT IF EXISTS check_ip_family_v_nblk_col;
ALTER TABLE jazzhands.val_netblock_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_nct_chh;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_collection_type ON jazzhands.val_netblock_collection_type;
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_collection_type ON jazzhands.val_netblock_collection_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_netblock_collection_type');
---- BEGIN audit.val_netblock_collection_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_netblock_collection_type', 'val_netblock_collection_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_netblock_collection_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_netblock_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_netblock_collection_type');
---- DONE audit.val_netblock_collection_type TEARDOWN


ALTER TABLE val_netblock_collection_type RENAME TO val_netblock_collection_type_v71;
ALTER TABLE audit.val_netblock_collection_type RENAME TO val_netblock_collection_type_v71;

CREATE TABLE val_netblock_collection_type
(
	netblock_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	netblock_single_addr_restrict	varchar(3) NOT NULL,
	netblock_ip_family_restrict	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_netblock_collection_type', false);
ALTER TABLE val_netblock_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE val_netblock_collection_type
	ALTER netblock_single_addr_restrict
	SET DEFAULT 'ANY'::character varying;
INSERT INTO val_netblock_collection_type (
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	netblock_single_addr_restrict,
	netblock_ip_family_restrict,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	netblock_single_addr_restrict,
	netblock_ip_family_restrict,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_netblock_collection_type_v71;

INSERT INTO audit.val_netblock_collection_type (
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	netblock_single_addr_restrict,
	netblock_ip_family_restrict,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	netblock_single_addr_restrict,
	netblock_ip_family_restrict,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.val_netblock_collection_type_v71;

ALTER TABLE val_netblock_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE val_netblock_collection_type
	ALTER netblock_single_addr_restrict
	SET DEFAULT 'ANY'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT pk_val_netblock_collection_typ PRIMARY KEY (netblock_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_netblock_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';
COMMENT ON COLUMN val_netblock_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_netblock_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
COMMENT ON COLUMN val_netblock_collection_type.netblock_single_addr_restrict IS 'all collections of this types'' member netblocks must have is_single_address = ''Y''';
COMMENT ON COLUMN val_netblock_collection_type.netblock_ip_family_restrict IS 'all collections of this types'' member netblocks must have  and netblock collections must match this restriction, if set.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT check_any_yes_no_nc_singaddr_r
	CHECK ((netblock_single_addr_restrict)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying, 'ANY'::character varying])::text[]));
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT check_ip_family_v_nblk_col
	CHECK (netblock_ip_family_restrict = ANY (ARRAY[4, 6]));
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT check_yes_no_nct_chh
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_netblock_collection_type and netblock_collection
ALTER TABLE netblock_collection
	ADD CONSTRAINT fk_nblk_coll_v_nblk_c_typ
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK between val_netblock_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK between val_netblock_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_property_netblkcolltype
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_netblock_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_netblock_collection_type');
DROP TABLE IF EXISTS val_netblock_collection_type_v71;
DROP TABLE IF EXISTS audit.val_netblock_collection_type_v71;
-- DONE DEALING WITH TABLE val_netblock_collection_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property', 'val_property');

-- FOREIGN KEYS FROM
ALTER TABLE property_collection_property DROP CONSTRAINT IF EXISTS fk_prop_col_propnamtyp;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE val_property_value DROP CONSTRAINT IF EXISTS fk_valproval_namtyp;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_prop_svcemvcoll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_prop_val_devcol_typ_rstr_dc;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_prop_val_devcoll_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_acct_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_comp_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_l2netype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_l3netwok_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_property_dnsdomcolltype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_property_netblkcolltype;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_propdttyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_proptyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_vla_property_val_propcollty;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS pk_val_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif10val_property";
DROP INDEX IF EXISTS "jazzhands"."xif11val_property";
DROP INDEX IF EXISTS "jazzhands"."xif12val_property";
DROP INDEX IF EXISTS "jazzhands"."xif13val_property";
DROP INDEX IF EXISTS "jazzhands"."xif14val_property";
DROP INDEX IF EXISTS "jazzhands"."xif1val_property";
DROP INDEX IF EXISTS "jazzhands"."xif2val_property";
DROP INDEX IF EXISTS "jazzhands"."xif3val_property";
DROP INDEX IF EXISTS "jazzhands"."xif4val_property";
DROP INDEX IF EXISTS "jazzhands"."xif5val_property";
DROP INDEX IF EXISTS "jazzhands"."xif6val_property";
DROP INDEX IF EXISTS "jazzhands"."xif7val_property";
DROP INDEX IF EXISTS "jazzhands"."xif8val_property";
DROP INDEX IF EXISTS "jazzhands"."xif9val_property";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1494616001;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1664370664;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1804972034;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_185689986;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_185755522;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2016888554;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2139007167;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_271462566;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_354296970;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_366948481;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_606225804;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_cmp_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_ismulti;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_osid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pacct_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdevcol_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdnsdomid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_prodstate;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pucls_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_sitec;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trigger_audit_val_property ON jazzhands.val_property;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_property');
---- BEGIN audit.val_property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_property', 'val_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_property');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_property');
---- DONE audit.val_property TEARDOWN


ALTER TABLE val_property RENAME TO val_property_v71;
ALTER TABLE audit.val_property RENAME TO val_property_v71;

CREATE TABLE val_property
(
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	account_collection_type	varchar(50)  NULL,
	company_collection_type	varchar(50)  NULL,
	device_collection_type	varchar(50)  NULL,
	dns_domain_collection_type	varchar(50)  NULL,
	layer2_network_collection_type	varchar(50)  NULL,
	layer3_network_collection_type	varchar(50)  NULL,
	netblock_collection_type	varchar(50)  NULL,
	property_collection_type	varchar(50)  NULL,
	service_env_collection_type	varchar(50)  NULL,
	is_multivalue	character(1) NOT NULL,
	prop_val_acct_coll_type_rstrct	varchar(50)  NULL,
	prop_val_dev_coll_type_rstrct	varchar(50)  NULL,
	prop_val_nblk_coll_type_rstrct	varchar(50)  NULL,
	property_data_type	varchar(50) NOT NULL,
	permit_account_collection_id	character(10) NOT NULL,
	permit_account_id	character(10) NOT NULL,
	permit_account_realm_id	character(10) NOT NULL,
	permit_company_id	character(10) NOT NULL,
	permit_company_collection_id	character(10) NOT NULL,
	permit_device_collection_id	character(10) NOT NULL,
	permit_dns_domain_id	character(10) NOT NULL,
	permit_dns_domain_coll_id	character(10) NOT NULL,
	permit_layer2_network_coll_id	character(10) NOT NULL,
	permit_layer3_network_coll_id	character(10) NOT NULL,
	permit_netblock_collection_id	character(10) NOT NULL,
	permit_network_range_id	character(10) NOT NULL,
	permit_operating_system_id	character(10) NOT NULL,
	permit_os_snapshot_id	character(10) NOT NULL,
	permit_person_id	character(10) NOT NULL,
	permit_property_collection_id	character(10) NOT NULL,
	permit_service_env_collection	character(10) NOT NULL,
	permit_site_code	character(10) NOT NULL,
	permit_x509_signed_cert_id	varchar(50) NOT NULL,
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
	ALTER permit_company_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_network_range_id
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
	ALTER permit_x509_signed_cert_id
	SET DEFAULT 'PROHIBITED'::character varying;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;
INSERT INTO val_property (
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_x509_signed_cert_id,		-- new column (permit_x509_signed_cert_id)
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	'PROHIBITED'::character varying,		-- new column (permit_x509_signed_cert_id)
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v71;

INSERT INTO audit.val_property (
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_x509_signed_cert_id,		-- new column (permit_x509_signed_cert_id)
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	property_collection_type,
	service_env_collection_type,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_dns_domain_coll_id,
	permit_layer2_network_coll_id,
	permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	NULL,		-- new column (permit_x509_signed_cert_id)
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.val_property_v71;

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
	ALTER permit_company_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_network_range_id
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
	ALTER permit_x509_signed_cert_id
	SET DEFAULT 'PROHIBITED'::character varying;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_property ADD CONSTRAINT pk_val_property PRIMARY KEY (property_name, property_type);

-- Table/Column Comments
COMMENT ON TABLE val_property IS 'valid values and attributes for (name,type) pairs in the property table.  This defines how triggers enforce aspects of the property table';
COMMENT ON COLUMN val_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN val_property.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN val_property.account_collection_type IS 'type restriction of the account_collection_id on LHS';
COMMENT ON COLUMN val_property.company_collection_type IS 'type restriction of company_collection_id on LHS';
COMMENT ON COLUMN val_property.device_collection_type IS 'type restriction of device_collection_id on LHS';
COMMENT ON COLUMN val_property.dns_domain_collection_type IS 'type restriction of dns_domain_collection_id restriction on LHS';
COMMENT ON COLUMN val_property.netblock_collection_type IS 'type restriction of netblock_collection_id on LHS';
COMMENT ON COLUMN val_property.property_collection_type IS 'type restriction of property_collection_id on LHS';
COMMENT ON COLUMN val_property.service_env_collection_type IS 'type restriction of service_enviornment_collection_id on LHS';
COMMENT ON COLUMN val_property.is_multivalue IS 'If N, acts like an alternate key on property.(lhs,property_name,property_type)';
COMMENT ON COLUMN val_property.prop_val_acct_coll_type_rstrct IS 'if property_value is account_collection_Id, this limits the account_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.prop_val_dev_coll_type_rstrct IS 'if property_value is devicet_collection_Id, this limits the devicet_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.prop_val_nblk_coll_type_rstrct IS 'if property_value isnetblockt_collection_Id, this limits the netblockt_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.property_data_type IS 'which, if any, of the property_table_* columns should be used for this value.   May turn more complex enforcement via trigger';
COMMENT ON COLUMN val_property.permit_account_collection_id IS 'defines permissibility/requirement of account_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_account_id IS 'defines permissibility/requirement of account_idon LHS of property';
COMMENT ON COLUMN val_property.permit_account_realm_id IS 'defines permissibility/requirement of account_realm_id on LHS of property';
COMMENT ON COLUMN val_property.permit_company_id IS 'defines permissibility/requirement of company_id on LHS of property.  *NOTE*  THIS COLUMN WILL BE REMOVED IN >0.65';
COMMENT ON COLUMN val_property.permit_company_collection_id IS 'defines permissibility/requirement of company_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_device_collection_id IS 'defines permissibility/requirement of device_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_dns_domain_id IS 'defines permissibility/requirement of dns_domain_id on LHS of property. *NOTE*  THIS COLUMN WILL BE REMOVED IN >0.65';
COMMENT ON COLUMN val_property.permit_dns_domain_coll_id IS 'defines permissibility/requirement of dns_domain_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_layer2_network_coll_id IS 'defines permissibility/requirement of layer2_network_id on LHS of property';
COMMENT ON COLUMN val_property.permit_layer3_network_coll_id IS 'defines permissibility/requirement of layer3_network_id on LHS of property';
COMMENT ON COLUMN val_property.permit_netblock_collection_id IS 'defines permissibility/requirement of netblock_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_operating_system_id IS 'defines permissibility/requirement of operating_system_id on LHS of property';
COMMENT ON COLUMN val_property.permit_os_snapshot_id IS 'defines permissibility/requirement of operating_system_snapshot_id on LHS of property';
COMMENT ON COLUMN val_property.permit_person_id IS 'defines permissibility/requirement of person_id on LHS of property';
COMMENT ON COLUMN val_property.permit_property_collection_id IS 'defines permissibility/requirement of property_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_service_env_collection IS 'defines permissibility/requirement of service_env_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_site_code IS 'defines permissibility/requirement of site_code on LHS of property';
COMMENT ON COLUMN val_property.permit_property_rank IS 'defines permissibility of property_rank, and if it should be part of the "lhs" of the given property';
-- INDEXES
CREATE INDEX xif10val_property ON val_property USING btree (netblock_collection_type);
CREATE INDEX xif11val_property ON val_property USING btree (property_collection_type);
CREATE INDEX xif12val_property ON val_property USING btree (service_env_collection_type);
CREATE INDEX xif13val_property ON val_property USING btree (layer3_network_collection_type);
CREATE INDEX xif14val_property ON val_property USING btree (layer2_network_collection_type);
CREATE INDEX xif1val_property ON val_property USING btree (property_data_type);
CREATE INDEX xif2val_property ON val_property USING btree (property_type);
CREATE INDEX xif3val_property ON val_property USING btree (prop_val_acct_coll_type_rstrct);
CREATE INDEX xif4val_property ON val_property USING btree (prop_val_nblk_coll_type_rstrct);
CREATE INDEX xif5val_property ON val_property USING btree (prop_val_dev_coll_type_rstrct);
CREATE INDEX xif6val_property ON val_property USING btree (account_collection_type);
CREATE INDEX xif7val_property ON val_property USING btree (company_collection_type);
CREATE INDEX xif8val_property ON val_property USING btree (device_collection_type);
CREATE INDEX xif9val_property ON val_property USING btree (dns_domain_collection_type);

-- CHECK CONSTRAINTS
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1494616001
	CHECK (permit_dns_domain_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1664370664
	CHECK (permit_network_range_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1804972034
	CHECK (permit_os_snapshot_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_185689986
	CHECK (permit_layer2_network_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_185755522
	CHECK (permit_layer3_network_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2016888554
	CHECK (permit_account_realm_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2139007167
	CHECK (permit_property_rank = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_271462566
	CHECK (permit_property_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_354296970
	CHECK (permit_netblock_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_366948481
	CHECK (permit_company_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_606225804
	CHECK (permit_person_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_cmp_id
	CHECK (permit_company_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_ismulti
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_osid
	CHECK (permit_operating_system_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pacct_id
	CHECK (permit_account_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdevcol_id
	CHECK (permit_device_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdnsdomid
	CHECK (permit_dns_domain_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_prodstate
	CHECK (permit_service_env_collection = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pucls_id
	CHECK (permit_account_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_sitec
	CHECK (permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_property and property_collection_property
ALTER TABLE property_collection_property
	ADD CONSTRAINT fk_prop_col_propnamtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK between val_property and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK between val_property and val_property_value
ALTER TABLE val_property_value
	ADD CONSTRAINT fk_valproval_namtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- FOREIGN KEYS TO
-- consider FK val_property and val_service_env_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_svcemvcoll_type
	FOREIGN KEY (service_env_collection_type) REFERENCES val_service_env_coll_type(service_env_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcol_typ_rstr_dc
	FOREIGN KEY (prop_val_dev_coll_type_rstrct) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcoll_id
	FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_acct_coll_type
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_company_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_comp_coll_type
	FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type);
-- consider FK val_property and val_layer2_network_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_l2netype
	FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_coll_type(layer2_network_collection_type);
-- consider FK val_property and val_layer3_network_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_l3netwok_type
	FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_coll_type(layer3_network_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_dns_domain_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_property_dnsdomcolltype
	FOREIGN KEY (dns_domain_collection_type) REFERENCES val_dns_domain_collection_type(dns_domain_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_property_netblkcolltype
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_property_data_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type);
-- consider FK val_property and val_property_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_property_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_vla_property_val_propcollty
	FOREIGN KEY (property_collection_type) REFERENCES val_property_collection_type(property_collection_type);

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property');
DROP TABLE IF EXISTS val_property_v71;
DROP TABLE IF EXISTS audit.val_property_v71;
-- DONE DEALING WITH TABLE val_property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_property_collection_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property_collection_type', 'val_property_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE property_collection DROP CONSTRAINT IF EXISTS fk_propcol_propcoltype;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_vla_property_val_propcollty;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_property_collection_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_property_collection_type DROP CONSTRAINT IF EXISTS pk_property_collction_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_property_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_1132635988;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_property_collection_type ON jazzhands.val_property_collection_type;
DROP TRIGGER IF EXISTS trigger_audit_val_property_collection_type ON jazzhands.val_property_collection_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_property_collection_type');
---- BEGIN audit.val_property_collection_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_property_collection_type', 'val_property_collection_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_property_collection_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_property_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_property_collection_type');
---- DONE audit.val_property_collection_type TEARDOWN


ALTER TABLE val_property_collection_type RENAME TO val_property_collection_type_v71;
ALTER TABLE audit.val_property_collection_type RENAME TO val_property_collection_type_v71;

CREATE TABLE val_property_collection_type
(
	property_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_property_collection_type', false);
ALTER TABLE val_property_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_property_collection_type (
	property_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_collection_type_v71;

INSERT INTO audit.val_property_collection_type (
	property_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	property_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.val_property_collection_type_v71;

ALTER TABLE val_property_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_property_collection_type ADD CONSTRAINT pk_property_collction_type PRIMARY KEY (property_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_property_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';
COMMENT ON COLUMN val_property_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_property_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_property_collection_type ADD CONSTRAINT check_yes_no_1132635988
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_property_collection_type and property_collection
ALTER TABLE property_collection
	ADD CONSTRAINT fk_propcol_propcoltype
	FOREIGN KEY (property_collection_type) REFERENCES val_property_collection_type(property_collection_type);
-- consider FK between val_property_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_vla_property_val_propcollty
	FOREIGN KEY (property_collection_type) REFERENCES val_property_collection_type(property_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property_collection_type');
DROP TABLE IF EXISTS val_property_collection_type_v71;
DROP TABLE IF EXISTS audit.val_property_collection_type_v71;
-- DONE DEALING WITH TABLE val_property_collection_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_pvt_key_encryption_type
CREATE TABLE val_pvt_key_encryption_type
(
	private_key_encryption_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_pvt_key_encryption_type', true);
--
-- Copying initialization data
--

INSERT INTO val_pvt_key_encryption_type (
private_key_encryption_type,description
) VALUES
	('rsa',NULL),
	('dsa',NULL),
	('ecc',NULL)
;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_pvt_key_encryption_type ADD CONSTRAINT pk_val_pvt_key_encryption_type PRIMARY KEY (private_key_encryption_type);

-- Table/Column Comments
COMMENT ON TABLE val_pvt_key_encryption_type IS 'Encryption method for private keys.  This may want to merge with val_encryption_method.';
COMMENT ON COLUMN val_pvt_key_encryption_type.private_key_encryption_type IS 'encryption tyof private key (rsa, dsa, ec, etc).
';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_pvt_key_encryption_type and private_key
-- Skipping this FK since column does not exist yet
--ALTER TABLE private_key
--	ADD CONSTRAINT fk_pctkey_enctype
--	FOREIGN KEY (private_key_encryption_type) REFERENCES val_pvt_key_encryption_type(private_key_encryption_type);


-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_pvt_key_encryption_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_pvt_key_encryption_type');
-- DONE DEALING WITH TABLE val_pvt_key_encryption_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_raid_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_raid_type', 'val_raid_type');

-- FOREIGN KEYS FROM
ALTER TABLE volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_rd_type;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_raid_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_raid_type DROP CONSTRAINT IF EXISTS pk_raid_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_raid_type ON jazzhands.val_raid_type;
DROP TRIGGER IF EXISTS trigger_audit_val_raid_type ON jazzhands.val_raid_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_raid_type');
---- BEGIN audit.val_raid_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_raid_type', 'val_raid_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_raid_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_raid_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_raid_type');
---- DONE audit.val_raid_type TEARDOWN


ALTER TABLE val_raid_type RENAME TO val_raid_type_v71;
ALTER TABLE audit.val_raid_type RENAME TO val_raid_type_v71;

CREATE TABLE val_raid_type
(
	raid_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	primary_raid_level	integer  NULL,
	secondary_raid_level	integer  NULL,
	raid_level_qualifier	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_raid_type', false);
INSERT INTO val_raid_type (
	raid_type,
	description,
	primary_raid_level,
	secondary_raid_level,
	raid_level_qualifier,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	raid_type,
	description,
	primary_raid_level,
	secondary_raid_level,
	raid_level_qualifier,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_raid_type_v71;

INSERT INTO audit.val_raid_type (
	raid_type,
	description,
	primary_raid_level,
	secondary_raid_level,
	raid_level_qualifier,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	raid_type,
	description,
	primary_raid_level,
	secondary_raid_level,
	raid_level_qualifier,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.val_raid_type_v71;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_raid_type ADD CONSTRAINT pk_raid_type PRIMARY KEY (raid_type);

-- Table/Column Comments
COMMENT ON COLUMN val_raid_type.primary_raid_level IS 'Common RAID Disk Data Format Specification primary raid level.';
COMMENT ON COLUMN val_raid_type.secondary_raid_level IS 'Common RAID Disk Data Format Specification secondary raid level.';
COMMENT ON COLUMN val_raid_type.raid_level_qualifier IS 'Common RAID Disk Data Format Specification''s integer number that describes the raid.  Arguably, this should be split out to distinct fields and constructed, and maybe one day it will be and this field will go away.';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_raid_type and volume_group
ALTER TABLE volume_group
	ADD CONSTRAINT fk_volgrp_rd_type
	FOREIGN KEY (raid_type) REFERENCES val_raid_type(raid_type) DEFERRABLE;

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_raid_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_raid_type');
DROP TABLE IF EXISTS val_raid_type_v71;
DROP TABLE IF EXISTS audit.val_raid_type_v71;
-- DONE DEALING WITH TABLE val_raid_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_token_collection_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_token_collection_type', 'val_token_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE token_collection DROP CONSTRAINT IF EXISTS fk_tok_col_mem_token_col_type;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_token_collection_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_token_collection_type DROP CONSTRAINT IF EXISTS pk_val_token_collection_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_token_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_126727163;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_token_collection_type ON jazzhands.val_token_collection_type;
DROP TRIGGER IF EXISTS trigger_audit_val_token_collection_type ON jazzhands.val_token_collection_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_token_collection_type');
---- BEGIN audit.val_token_collection_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_token_collection_type', 'val_token_collection_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_token_collection_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_token_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_token_collection_type');
---- DONE audit.val_token_collection_type TEARDOWN


ALTER TABLE val_token_collection_type RENAME TO val_token_collection_type_v71;
ALTER TABLE audit.val_token_collection_type RENAME TO val_token_collection_type_v71;

CREATE TABLE val_token_collection_type
(
	token_collection_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_token_collection_type', false);
ALTER TABLE val_token_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
INSERT INTO val_token_collection_type (
	token_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	token_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_token_collection_type_v71;

INSERT INTO audit.val_token_collection_type (
	token_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	token_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.val_token_collection_type_v71;

ALTER TABLE val_token_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_token_collection_type ADD CONSTRAINT pk_val_token_collection_type PRIMARY KEY (token_collection_type);

-- Table/Column Comments
COMMENT ON TABLE val_token_collection_type IS 'Assign purposes to arbitrary groupings';
COMMENT ON COLUMN val_token_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type';
COMMENT ON COLUMN val_token_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.';
COMMENT ON COLUMN val_token_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_token_collection_type ADD CONSTRAINT check_yes_no_126727163
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between val_token_collection_type and token_collection
ALTER TABLE token_collection
	ADD CONSTRAINT fk_tok_col_mem_token_col_type
	FOREIGN KEY (token_collection_type) REFERENCES val_token_collection_type(token_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_token_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_token_collection_type');
DROP TABLE IF EXISTS val_token_collection_type_v71;
DROP TABLE IF EXISTS audit.val_token_collection_type_v71;
-- DONE DEALING WITH TABLE val_token_collection_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_x509_certificate_type
CREATE TABLE val_x509_certificate_type
(
	x509_certificate_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_x509_certificate_type', true);
--
-- Copying initialization data
--

INSERT INTO val_x509_certificate_type (
x509_certificate_type,description
) VALUES
	('default',NULL)
;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_x509_certificate_type ADD CONSTRAINT pk_x509_certificate_type PRIMARY KEY (x509_certificate_type);

-- Table/Column Comments
COMMENT ON TABLE val_x509_certificate_type IS 'Type of signed certificate; this is defined by a business rule and used for human clarity.';
COMMENT ON COLUMN val_x509_certificate_type.x509_certificate_type IS 'encryption tyof private key (rsa, dsa, ec, etc).
';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between val_x509_certificate_type and x509_signed_certificate
-- Skipping this FK since column does not exist yet
--ALTER TABLE x509_signed_certificate
--	ADD CONSTRAINT fk_x509crtid_crttype
--	FOREIGN KEY (x509_certificate_type) REFERENCES val_x509_certificate_type(x509_certificate_type);


-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_x509_certificate_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_x509_certificate_type');
-- DONE DEALING WITH TABLE val_x509_certificate_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE certificate_signing_request
CREATE TABLE certificate_signing_request
(
	certificate_signing_request_id	integer NOT NULL,
	friendly_name	varchar(255) NOT NULL,
	subject	varchar(255) NOT NULL,
	certificate_signing_request	text NOT NULL,
	private_key_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'certificate_signing_request', 'false');


-- BEGIN Manually written insert function

INSERT INTO certificate_signing_request
SELECT x509_cert_id, friendly_name, subject,
        certificate_sign_req,
        CASE WHEN private_key is NOT NULL THEN x509_cert_id ELSE NULL END,
        data_ins_user, data_ins_date,
        data_upd_user, data_upd_date
FROM x509_certificate
WHERE certificate_sign_req IS NOT NULL
ORDER BY x509_cert_id;

INSERT INTO audit.certificate_signing_request
SELECT x509_cert_id, friendly_name, subject,
        certificate_sign_req,
        CASE WHEN private_key is NOT NULL THEN x509_cert_id ELSE NULL END,
        data_ins_user, data_ins_date,
        data_upd_user, data_upd_date,
        "aud#action",
        "aud#timestamp",
        NULL,
        NULL,
        "aud#user",
        "aud#seq"
FROM audit.x509_certificate
WHERE x509_cert_id IN (select x509_cert_id FROM audit.x509_certificate
        WHERE certificate_sign_req IS NOT NULL)
ORDER BY "aud#seq";

/**************************************************************************/


-- END Manually written insert function
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'certificate_signing_request');
ALTER TABLE certificate_signing_request
	ALTER certificate_signing_request_id
	SET DEFAULT nextval('certificate_signing_request_certificate_signing_request_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE certificate_signing_request ADD CONSTRAINT pk_certificate_signing_request PRIMARY KEY (certificate_signing_request_id);

-- Table/Column Comments
COMMENT ON TABLE certificate_signing_request IS 'Certificiate Signing Requests generated from public key.  This is mostly kept for posterity since its possible to generate these at-wil from the private key.';
COMMENT ON COLUMN certificate_signing_request.certificate_signing_request_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN certificate_signing_request.friendly_name IS 'human readable name for certificate.  often just the CN.';
COMMENT ON COLUMN certificate_signing_request.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.  This is the full subject from the certificate.  Friendly Name provides a human readable one.';
COMMENT ON COLUMN certificate_signing_request.certificate_signing_request IS 'Textual representation of a certificate signing certificate';
COMMENT ON COLUMN certificate_signing_request.private_key_id IS '
';
-- INDEXES
CREATE INDEX fk_csr_pvtkeyid ON certificate_signing_request USING btree (private_key_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK between certificate_signing_request and x509_signed_certificate
-- Skipping this FK since column does not exist yet
--ALTER TABLE x509_signed_certificate
--	ADD CONSTRAINT fk_csr_pvtkeyid
--	FOREIGN KEY (certificate_signing_request_id) REFERENCES certificate_signing_request(certificate_signing_request_id);


-- FOREIGN KEYS TO
-- consider FK certificate_signing_request and private_key
-- Skipping this FK since column does not exist yet
--ALTER TABLE certificate_signing_request
--	ADD CONSTRAINT fk_pvtkey_csr
--	FOREIGN KEY (private_key_id) REFERENCES private_key(private_key_id);


-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'certificate_signing_request');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'certificate_signing_request');
ALTER SEQUENCE certificate_signing_request_certificate_signing_request_id_seq
	 OWNED BY certificate_signing_request.certificate_signing_request_id;
-- DONE DEALING WITH TABLE certificate_signing_request
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device_type
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type', 'device_type');

-- FOREIGN KEYS FROM
ALTER TABLE chassis_location DROP CONSTRAINT IF EXISTS fk_chass_loc_mod_dev_typ_id;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_dev_devtp_id;
ALTER TABLE device_type_module DROP CONSTRAINT IF EXISTS fk_devt_mod_dev_type_id;
ALTER TABLE device_type_module_device_type DROP CONSTRAINT IF EXISTS fk_dt_mod_dev_type_mod_dtid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS fk_dev_typ_tmplt_dev_typ_id;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS fk_device_t_fk_device_val_proc;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS fk_devtyp_company;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS fk_fevtyp_component_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'device_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS pk_device_type;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif4device_type";
DROP INDEX IF EXISTS "jazzhands"."xif_dev_typ_tmplt_dev_typ_id";
DROP INDEX IF EXISTS "jazzhands"."xif_fevtyp_component_id";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_devtyp_ischs;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_has_802_11_interf_device_t;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_has_802_3_interfa_device_t;
ALTER TABLE jazzhands.device_type DROP CONSTRAINT IF EXISTS ckc_snmp_capable_device_t;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_device_type ON jazzhands.device_type;
DROP TRIGGER IF EXISTS trigger_audit_device_type ON jazzhands.device_type;
DROP TRIGGER IF EXISTS trigger_device_type_chassis_check ON jazzhands.device_type;
DROP TRIGGER IF EXISTS trigger_device_type_model_to_name ON jazzhands.device_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'device_type');
---- BEGIN audit.device_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'device_type', 'device_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'device_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."device_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'device_type');
---- DONE audit.device_type TEARDOWN


ALTER TABLE device_type RENAME TO device_type_v71;
ALTER TABLE audit.device_type RENAME TO device_type_v71;

CREATE TABLE device_type
(
	device_type_id	integer NOT NULL,
	component_type_id	integer  NULL,
	device_type_name	varchar(50) NOT NULL,
	template_device_id	integer  NULL,
	idealized_device_id	integer  NULL,
	description	varchar(4000)  NULL,
	company_id	integer  NULL,
	model	varchar(255) NOT NULL,
	device_type_depth_in_cm	character(18)  NULL,
	processor_architecture	varchar(50)  NULL,
	config_fetch_type	varchar(50)  NULL,
	rack_units	integer  NULL,
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
	ALTER has_802_3_interface
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device_type
	ALTER has_802_11_interface
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device_type
	ALTER snmp_capable
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device_type
	ALTER is_chassis
	SET DEFAULT 'N'::bpchar;
INSERT INTO device_type (
	device_type_id,
	component_type_id,
	device_type_name,
	template_device_id,
	idealized_device_id,		-- new column (idealized_device_id)
	description,
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
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
	component_type_id,
	device_type_name,
	template_device_id,
	NULL,		-- new column (idealized_device_id)
	description,
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
	has_802_3_interface,
	has_802_11_interface,
	snmp_capable,
	is_chassis,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_type_v71;

INSERT INTO audit.device_type (
	device_type_id,
	component_type_id,
	device_type_name,
	template_device_id,
	idealized_device_id,		-- new column (idealized_device_id)
	description,
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
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
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	device_type_id,
	component_type_id,
	device_type_name,
	template_device_id,
	NULL,		-- new column (idealized_device_id)
	description,
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
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
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.device_type_v71;

ALTER TABLE device_type
	ALTER device_type_id
	SET DEFAULT nextval('device_type_device_type_id_seq'::regclass);
ALTER TABLE device_type
	ALTER has_802_3_interface
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device_type
	ALTER has_802_11_interface
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device_type
	ALTER snmp_capable
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device_type
	ALTER is_chassis
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_type ADD CONSTRAINT pk_device_type PRIMARY KEY (device_type_id);

-- Table/Column Comments
COMMENT ON TABLE device_type IS 'Conceptual device type.  This represents how it is typically referred to rather than a specific model number.  There may be many models (components) that are represented by one device type.';
COMMENT ON COLUMN device_type.component_type_id IS 'reference to the type of hardware that underlies this type';
COMMENT ON COLUMN device_type.device_type_name IS 'Human readable name of the device type.  The company and a model can be gleaned from component.';
COMMENT ON COLUMN device_type.template_device_id IS 'Represents a non-real but template device that is used to describe how to setup a device when its inserted into the database with this device type.  Its used to get port names and other information correct when it needs to be inserted before probing.  Probing may deviate from the template.';
COMMENT ON COLUMN device_type.idealized_device_id IS 'Indicates what a device of this type looks like; primarily used for either reverse engineering a probe to a device type or valdating that a device type has all the pieces it is expcted to.  This device is typically not real.';
-- INDEXES
CREATE INDEX xif4device_type ON device_type USING btree (company_id);
CREATE INDEX xif_dev_typ_idealized_dev_id ON device_type USING btree (idealized_device_id);
CREATE INDEX xif_dev_typ_tmplt_dev_typ_id ON device_type USING btree (template_device_id);
CREATE INDEX xif_fevtyp_component_id ON device_type USING btree (component_type_id);

-- CHECK CONSTRAINTS
ALTER TABLE device_type ADD CONSTRAINT ckc_devtyp_ischs
	CHECK (is_chassis = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE device_type ADD CONSTRAINT ckc_has_802_11_interf_device_t
	CHECK (has_802_11_interface = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE device_type ADD CONSTRAINT ckc_has_802_3_interfa_device_t
	CHECK (has_802_3_interface = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE device_type ADD CONSTRAINT ckc_snmp_capable_device_t
	CHECK (snmp_capable = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between device_type and chassis_location
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chass_loc_mod_dev_typ_id
	FOREIGN KEY (module_device_type_id) REFERENCES device_type(device_type_id);
-- consider FK between device_type and device
ALTER TABLE device
	ADD CONSTRAINT fk_dev_devtp_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK between device_type and device_type_module
ALTER TABLE device_type_module
	ADD CONSTRAINT fk_devt_mod_dev_type_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
-- consider FK between device_type and device_type_module_device_type
ALTER TABLE device_type_module_device_type
	ADD CONSTRAINT fk_dt_mod_dev_type_mod_dtid
	FOREIGN KEY (module_device_type_id) REFERENCES device_type(device_type_id);

-- FOREIGN KEYS TO
-- consider FK device_type and device
ALTER TABLE device_type
	ADD CONSTRAINT fk_dev_typ_idealized_dev_id
	FOREIGN KEY (idealized_device_id) REFERENCES device(device_id);
-- consider FK device_type and device
ALTER TABLE device_type
	ADD CONSTRAINT fk_dev_typ_tmplt_dev_typ_id
	FOREIGN KEY (template_device_id) REFERENCES device(device_id);
-- consider FK device_type and val_processor_architecture
ALTER TABLE device_type
	ADD CONSTRAINT fk_device_t_fk_device_val_proc
	FOREIGN KEY (processor_architecture) REFERENCES val_processor_architecture(processor_architecture);
-- consider FK device_type and company
ALTER TABLE device_type
	ADD CONSTRAINT fk_devtyp_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK device_type and component_type
ALTER TABLE device_type
	ADD CONSTRAINT fk_fevtyp_component_id
	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id);

-- TRIGGERS
-- consider NEW jazzhands.device_type_chassis_check
CREATE OR REPLACE FUNCTION jazzhands.device_type_chassis_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF TG_OP != 'UPDATE' THEN
		RAISE EXCEPTION 'This should not happen %!', TG_OP;
	END IF;
	IF OLD.is_chassis = 'Y' THEN
		IF NEW.is_chassis = 'N' THEN
			SELECT 	count(*)
			  INTO	_tally
			  FROM	device_type_module
			 WHERE	device_type_id = NEW.device_type_id;

			IF _tally >  0 THEN
				RAISE EXCEPTION 'Is_chassis must be Y when a device_type still has device_type_module s'
					USING ERRCODE = 'foreign_key_violation';
			END IF;
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_device_type_chassis_check BEFORE UPDATE OF is_chassis ON device_type FOR EACH ROW EXECUTE PROCEDURE device_type_chassis_check();

-- XXX - may need to include trigger function
-- consider NEW jazzhands.device_type_model_to_name
CREATE OR REPLACE FUNCTION jazzhands.device_type_model_to_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND  (NEW.model IS DISTINCT FROM OLD.model AND
			NEW.device_type_name IS DISTINCT FROM OLD.device_type_name) THEN
		RAISE EXCEPTION 'Only device_type_name should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.model IS NOT NULL AND NEW.device_type_name IS NOT NULL THEN
			RAISE EXCEPTION 'Only model should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.model IS DISTINCT FROM NEW.model THEN
			NEW.device_type_name = NEW.model;
		ELSIF OLD.device_type_name IS DISTINCT FROM NEW.device_type_name THEN
			NEW.model = NEW.device_type_name;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.model IS NOT NULL THEN
			NEW.device_type_name = NEW.model;
		ELSIF NEW.device_type_name IS NOT NULL THEN
			NEW.model = NEW.device_type_name;
		END IF;
	ELSE
	END IF;

	-- company_id is going away
	IF NEW.company_id IS NULL THEN
		NEW.company_id := 0;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_device_type_model_to_name BEFORE INSERT OR UPDATE OF device_type_name, model ON device_type FOR EACH ROW EXECUTE PROCEDURE device_type_model_to_name();

-- XXX - may need to include trigger function
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_type');
ALTER SEQUENCE device_type_device_type_id_seq
	 OWNED BY device_type.device_type_id;
DROP TABLE IF EXISTS device_type_v71;
DROP TABLE IF EXISTS audit.device_type_v71;
-- DONE DEALING WITH TABLE device_type
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE private_key
CREATE TABLE private_key
(
	private_key_id	integer NOT NULL,
	private_key_encryption_type	varchar(50) NOT NULL,
	is_active	character(1) NOT NULL,
	subject_key_identifier	varchar(255)  NULL,
	private_key	text NOT NULL,
	passphrase	varchar(255)  NULL,
	encryption_key_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'private_key', 'false');


-- BEGIN Manually written insert function

INSERT INTO private_key
SELECT x509_cert_id AS private_key_id,
        'rsa' AS private_key_encryption_type, is_active,
        subject_key_identifier, private_key, passphrase, encryption_key_id,
        data_ins_user, data_ins_date, data_upd_user, data_upd_date
FROM x509_certificate
WHERE private_key is NOT NULL
ORDER BY x509_cert_id;

INSERT INTO audit.private_key
SELECT x509_cert_id AS private_key_id,
        'rsa' AS private_key_encryption_type, is_active,
        subject_key_identifier, private_key, passphrase, encryption_key_id,
        data_ins_user, data_ins_date, data_upd_user, data_upd_date,
        "aud#action",
        "aud#timestamp",
        NULL,
        NULL,
        "aud#user",
        "aud#seq"
FROM audit.x509_certificate
WHERE x509_cert_id IN (select x509_cert_id FROM audit.x509_certificate
        WHERE private_key IS NOT NULL)
ORDER BY "aud#seq";


/**************************************************************************/


-- END Manually written insert function
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'private_key');
ALTER TABLE private_key
	ALTER private_key_id
	SET DEFAULT nextval('private_key_private_key_id_seq'::regclass);
ALTER TABLE private_key
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE private_key ADD CONSTRAINT ak_private_key UNIQUE (subject_key_identifier);
ALTER TABLE private_key ADD CONSTRAINT pk_private_key PRIMARY KEY (private_key_id);

-- Table/Column Comments
COMMENT ON TABLE private_key IS 'Signed X509 Certificate';
COMMENT ON COLUMN private_key.private_key_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN private_key.private_key_encryption_type IS 'encryption tyof private key (rsa, dsa, ec, etc).
';
COMMENT ON COLUMN private_key.is_active IS 'indicates certificate is in active use.  This is used by tools to decide how to show it; does not indicate revocation';
COMMENT ON COLUMN private_key.subject_key_identifier IS 'colon seperate byte hex string with X509v3 SKI hash of the key in the same form as the x509 extension.  This should be NOT NULL but its hard to extract sometimes';
COMMENT ON COLUMN private_key.private_key IS 'Textual representation of Certificate Private Key. Private Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN private_key.passphrase IS 'passphrase to decrypt key.  If encrypted, encryption_key_id indicates how to decrypt.';
COMMENT ON COLUMN private_key.encryption_key_id IS 'if set, encryption key information for decrypting passphrase.';
-- INDEXES
CREATE INDEX fk_pvtkey_enctype ON private_key USING btree (private_key_encryption_type);
CREATE INDEX xif2private_key ON private_key USING btree (encryption_key_id);

-- CHECK CONSTRAINTS
ALTER TABLE private_key ADD CONSTRAINT check_yes_no_1721461855
	CHECK (is_active = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between private_key and certificate_signing_request
ALTER TABLE certificate_signing_request
	ADD CONSTRAINT fk_pvtkey_csr
	FOREIGN KEY (private_key_id) REFERENCES private_key(private_key_id);
-- consider FK between private_key and x509_signed_certificate
-- Skipping this FK since column does not exist yet
--ALTER TABLE x509_signed_certificate
--	ADD CONSTRAINT fk_pvtkey_x509crt
--	FOREIGN KEY (private_key_id) REFERENCES private_key(private_key_id);


-- FOREIGN KEYS TO
-- consider FK private_key and val_pvt_key_encryption_type
ALTER TABLE private_key
	ADD CONSTRAINT fk_pctkey_enctype
	FOREIGN KEY (private_key_encryption_type) REFERENCES val_pvt_key_encryption_type(private_key_encryption_type);
-- consider FK private_key and encryption_key
ALTER TABLE private_key
	ADD CONSTRAINT fk_pvtkey_enckey_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);

-- TRIGGERS
-- consider NEW jazzhands.pvtkey_ski_signed_validate
CREATE OR REPLACE FUNCTION jazzhands.pvtkey_ski_signed_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	ski	TEXT;
BEGIN
	SELECT	subject_key_identifier
	INTO	ski
	FROM	x509_signed_certificate x
	WHERE	x.private_key_id = NEW.private_key_id;

	IF FOUND AND ski != NEW.subject_key_identifier THEN
		RAISE EXCEPTION 'subject key identifier must match private key in x509_signing_certificate' USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_pvtkey_ski_signed_validate AFTER UPDATE OF subject_key_identifier ON private_key FOR EACH ROW EXECUTE PROCEDURE pvtkey_ski_signed_validate();

-- XXX - may need to include trigger function
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'private_key');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'private_key');
ALTER SEQUENCE private_key_private_key_id_seq
	 OWNED BY private_key.private_key_id;
-- DONE DEALING WITH TABLE private_key
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_compcoll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l2_netcollid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l3_netcoll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_os_snapshot;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_pv_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_svc_env_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acct_col;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctrealmid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_dns_dom_collect;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_dnsdomid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nblk_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_osid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_person_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_prop_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pv_nblkcol_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_acct_colid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_pwdtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_swpkgid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_tokcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_site_code;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_val_prsnid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS r_784;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS pk_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif30property";
DROP INDEX IF EXISTS "jazzhands"."xif31property";
DROP INDEX IF EXISTS "jazzhands"."xif32property";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_compcoll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_os_snapshot";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_pv_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_svc_env_coll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_acctrealmid";
DROP INDEX IF EXISTS "jazzhands"."xif_property_dns_dom_collect";
DROP INDEX IF EXISTS "jazzhands"."xif_property_nblk_coll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_person_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_prop_coll_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_pv_nblkcol_id";
DROP INDEX IF EXISTS "jazzhands"."xif_property_val_prsnid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_account_id";
DROP INDEX IF EXISTS "jazzhands"."xifprop_acctcol_id";
DROP INDEX IF EXISTS "jazzhands"."xifprop_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_nmtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_osid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_acct_colid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_pwdtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_swpkgid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_tokcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_site_code";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS ckc_prop_isenbld;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_audit_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_validate_property ON jazzhands.property;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'property');
---- BEGIN audit.property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'property');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'property');
---- DONE audit.property TEARDOWN


ALTER TABLE property RENAME TO property_v71;
ALTER TABLE audit.property RENAME TO property_v71;

CREATE TABLE property
(
	property_id	integer NOT NULL,
	account_collection_id	integer  NULL,
	account_id	integer  NULL,
	account_realm_id	integer  NULL,
	company_collection_id	integer  NULL,
	company_id	integer  NULL,
	device_collection_id	integer  NULL,
	dns_domain_collection_id	integer  NULL,
	dns_domain_id	integer  NULL,
	layer2_network_collection_id	integer  NULL,
	layer3_network_collection_id	integer  NULL,
	netblock_collection_id	integer  NULL,
	network_range_id	integer  NULL,
	operating_system_id	integer  NULL,
	operating_system_snapshot_id	integer  NULL,
	person_id	integer  NULL,
	property_collection_id	integer  NULL,
	service_env_collection_id	integer  NULL,
	site_code	varchar(50)  NULL,
	x509_signed_certificate_id	integer  NULL,
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	property_value	varchar(1024)  NULL,
	property_value_timestamp	timestamp without time zone  NULL,
	property_value_company_id	integer  NULL,
	property_value_account_coll_id	integer  NULL,
	property_value_device_coll_id	integer  NULL,
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
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	dns_domain_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	x509_signed_certificate_id,		-- new column (x509_signed_certificate_id)
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
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
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	dns_domain_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	NULL,		-- new column (x509_signed_certificate_id)
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
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
FROM property_v71;

INSERT INTO audit.property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	dns_domain_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	x509_signed_certificate_id,		-- new column (x509_signed_certificate_id)
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
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
	"aud#realtime",		-- new column (aud#realtime)
	"aud#txid",		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
) SELECT
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	dns_domain_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	NULL,		-- new column (x509_signed_certificate_id)
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
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
	NULL,		-- new column (aud#realtime)
	NULL,		-- new column (aud#txid)
	"aud#user",
	"aud#seq"
FROM audit.property_v71;

ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE property ADD CONSTRAINT pk_property PRIMARY KEY (property_id);

-- Table/Column Comments
COMMENT ON TABLE property IS 'generic mechanism to create arbitrary associations between lhs database objects and assign them to zero or one other database objects/strings/lists/etc.  They are trigger enforced based on characteristics in val_property and val_property_value where foreign key enforcement does not work.';
COMMENT ON COLUMN property.property_id IS 'primary key for table to uniquely identify rows.';
COMMENT ON COLUMN property.account_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.account_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.account_realm_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.company_id IS 'LHS settable based on val_property.  THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';
COMMENT ON COLUMN property.device_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.dns_domain_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.dns_domain_id IS 'LHS settable based on val_property.   THIS COLUMN IS BEING DEPRECATED IN FAVOR OF DNS_DOMAIN_COLLECTION_ID IN >= 0.66';
COMMENT ON COLUMN property.netblock_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.operating_system_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.operating_system_snapshot_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.person_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.property_collection_id IS 'LHS settable based on val_property.  NOTE, this is actually collections of property_name,property_type';
COMMENT ON COLUMN property.service_env_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.site_code IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.x509_signed_certificate_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN property.property_name IS 'textual name of a property';
COMMENT ON COLUMN property.property_type IS 'textual type of a department';
COMMENT ON COLUMN property.property_value IS 'RHS - general purpose column for value of property not defined by other types.  This may be enforced by fk (trigger) if val_property.property_data_type is list (fk is to val_property_value).   permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_timestamp IS 'RHS - value is a timestamp , permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_company_id IS 'RHS - fk to company_id,  permitted based on val_property.property_data_type.  THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';
COMMENT ON COLUMN property.property_value_account_coll_id IS 'RHS, fk to account_collection,    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_device_coll_id IS 'RHS - fk to device_collection.    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_nblk_coll_id IS 'RHS - fk to network_collection.    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_password_type IS 'RHS - fk to val_password_type.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_person_id IS 'RHS - fk to person.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_sw_package_id IS 'RHS - fk to sw_package.  possibly will be deprecated.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_token_col_id IS 'RHS - fk to token_collection_id.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_rank IS 'for multivalues, specifies the order.  If set, this basically becomes part of the "ak" for the lhs.';
COMMENT ON COLUMN property.start_date IS 'date/time that the assignment takes effect or NULL.  .  The view v_property filters this out.';
COMMENT ON COLUMN property.finish_date IS 'date/time that the assignment ceases taking effect or NULL.  .  The view v_property filters this out.';
COMMENT ON COLUMN property.is_enabled IS 'indiciates if the property is temporarily disabled or not.  The view v_property filters this out.';
-- INDEXES
CREATE INDEX xif30property ON property USING btree (layer2_network_collection_id);
CREATE INDEX xif31property ON property USING btree (layer3_network_collection_id);
CREATE INDEX xif32property ON property USING btree (network_range_id);
CREATE INDEX xif33property ON property USING btree (x509_signed_certificate_id);
CREATE INDEX xif_prop_compcoll_id ON property USING btree (company_collection_id);
CREATE INDEX xif_prop_os_snapshot ON property USING btree (operating_system_snapshot_id);
CREATE INDEX xif_prop_pv_devcolid ON property USING btree (property_value_device_coll_id);
CREATE INDEX xif_prop_svc_env_coll_id ON property USING btree (service_env_collection_id);
CREATE INDEX xif_property_acctrealmid ON property USING btree (account_realm_id);
CREATE INDEX xif_property_dns_dom_collect ON property USING btree (dns_domain_collection_id);
CREATE INDEX xif_property_nblk_coll_id ON property USING btree (netblock_collection_id);
CREATE INDEX xif_property_person_id ON property USING btree (person_id);
CREATE INDEX xif_property_prop_coll_id ON property USING btree (property_collection_id);
CREATE INDEX xif_property_pv_nblkcol_id ON property USING btree (property_value_nblk_coll_id);
CREATE INDEX xif_property_val_prsnid ON property USING btree (property_value_person_id);
CREATE INDEX xifprop_account_id ON property USING btree (account_id);
CREATE INDEX xifprop_acctcol_id ON property USING btree (account_collection_id);
CREATE INDEX xifprop_compid ON property USING btree (company_id);
CREATE INDEX xifprop_devcolid ON property USING btree (device_collection_id);
CREATE INDEX xifprop_dnsdomid ON property USING btree (dns_domain_id);
CREATE INDEX xifprop_nmtyp ON property USING btree (property_name, property_type);
CREATE INDEX xifprop_osid ON property USING btree (operating_system_id);
CREATE INDEX xifprop_pval_acct_colid ON property USING btree (property_value_account_coll_id);
CREATE INDEX xifprop_pval_compid ON property USING btree (property_value_company_id);
CREATE INDEX xifprop_pval_pwdtyp ON property USING btree (property_value_password_type);
CREATE INDEX xifprop_pval_swpkgid ON property USING btree (property_value_sw_package_id);
CREATE INDEX xifprop_pval_tokcolid ON property USING btree (property_value_token_col_id);
CREATE INDEX xifprop_site_code ON property USING btree (site_code);

-- CHECK CONSTRAINTS
ALTER TABLE property ADD CONSTRAINT ckc_prop_isenbld
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK property and company_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_compcoll_id
	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);
-- consider FK property and layer2_network_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l2_netcollid
	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);
-- consider FK property and layer3_network_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l3_netcoll_id
	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);
-- consider FK property and network_range
ALTER TABLE property
	ADD CONSTRAINT fk_prop_net_range_id
	FOREIGN KEY (network_range_id) REFERENCES network_range(network_range_id);
-- consider FK property and operating_system_snapshot
ALTER TABLE property
	ADD CONSTRAINT fk_prop_os_snapshot
	FOREIGN KEY (operating_system_snapshot_id) REFERENCES operating_system_snapshot(operating_system_snapshot_id);
-- consider FK property and device_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_pv_devcolid
	FOREIGN KEY (property_value_device_coll_id) REFERENCES device_collection(device_collection_id);
-- consider FK property and service_environment_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_svc_env_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
-- consider FK property and x509_signed_certificate
-- Skipping this FK since column does not exist yet
--ALTER TABLE property
--	ADD CONSTRAINT fk_prop_x509_crt_id
--	FOREIGN KEY (x509_signed_certificate_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id);

-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and account
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK property and account_realm
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctrealmid
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK property and device_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK property and dns_domain_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_dns_dom_collect
	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);
-- consider FK property and dns_domain
ALTER TABLE property
	ADD CONSTRAINT fk_property_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK property and val_property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK property and operating_system
ALTER TABLE property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_person_id
	FOREIGN KEY (person_id) REFERENCES person(person_id);
-- consider FK property and property_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_prop_coll_id
	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pv_nblkcol_id
	FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_acct_colid
	FOREIGN KEY (property_value_account_coll_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK property and val_password_type
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_pwdtyp
	FOREIGN KEY (property_value_password_type) REFERENCES val_password_type(password_type);
-- consider FK property and sw_package
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_swpkgid
	FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id);
-- consider FK property and token_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_tokcolid
	FOREIGN KEY (property_value_token_col_id) REFERENCES token_collection(token_collection_id);
-- consider FK property and site
ALTER TABLE property
	ADD CONSTRAINT fk_property_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_val_prsnid
	FOREIGN KEY (property_value_person_id) REFERENCES person(person_id);

-- TRIGGERS
-- consider NEW jazzhands.validate_property
CREATE OR REPLACE FUNCTION jazzhands.validate_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally				integer;
	v_prop				VAL_Property%ROWTYPE;
	v_proptype			VAL_Property_Type%ROWTYPE;
	v_account_collection		account_collection%ROWTYPE;
	v_company_collection		company_collection%ROWTYPE;
	v_device_collection		device_collection%ROWTYPE;
	v_dns_domain_collection		dns_domain_collection%ROWTYPE;
	v_layer2_network_collection	layer2_network_collection%ROWTYPE;
	v_layer3_network_collection	layer3_network_collection%ROWTYPE;
	v_netblock_collection		netblock_collection%ROWTYPE;
	v_property_collection		property_collection%ROWTYPE;
	v_service_env_collection	service_environment_collection%ROWTYPE;
	v_num				integer;
	v_listvalue			Property.Property_Value%TYPE;
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
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property of type (%,%) already exists for given LHS and property is not multivalue',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	ELSE
		-- check for the same lhs+rhs existing, which is basically a dup row
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			property_value IS NOT DISTINCT FROM NEW.property_value AND
			property_value_timestamp IS NOT DISTINCT FROM
				NEW.property_value_timestamp AND
			property_value_company_id IS NOT DISTINCT FROM
				NEW.property_value_company_id AND
			property_value_account_coll_id IS NOT DISTINCT FROM
				NEW.property_value_account_coll_id AND
			property_value_device_coll_id IS NOT DISTINCT FROM
				NEW.property_value_device_coll_id AND
			property_value_nblk_coll_id IS NOT DISTINCT FROM
				NEW.property_value_nblk_coll_id AND
			property_value_password_type IS NOT DISTINCT FROM
				NEW.property_value_password_type AND
			property_value_person_id IS NOT DISTINCT FROM
				NEW.property_value_person_id AND
			property_value_sw_package_id IS NOT DISTINCT FROM
				NEW.property_value_sw_package_id AND
			property_value_token_col_id IS NOT DISTINCT FROM
				NEW.property_value_token_col_id AND
			start_date IS NOT DISTINCT FROM NEW.start_date AND
			finish_date IS NOT DISTINCT FROM NEW.finish_date
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property of (n,t) (%,%) already exists for given property',
				NEW.Property_Name, NEW.Property_Type
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
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			network_range_id IS NOT DISTINCT FROM NEW.network_range_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
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
	IF NEW.Property_Value_Person_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'person_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Person_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'device_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Device_Collection_Id' USING
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

	-- If the LHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.account_collection_id IS NOT NULL THEN
		IF v_prop.account_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.account_collection_id;
				IF v_account_collection.account_collection_Type != v_prop.account_collection_type
				THEN
					RAISE 'account_collection_id must be of type %',
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

	-- If the LHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.account_collection_id IS NOT NULL THEN
		IF v_prop.account_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.account_collection_id;
				IF v_account_collection.account_collection_Type != v_prop.account_collection_type
				THEN
					RAISE 'account_collection_id must be of type %',
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

	-- If the LHS contains a device_collection_ID, check to see if it must be a
	-- specific type (e.g. per-device), and verify that if so
	IF NEW.device_collection_id IS NOT NULL THEN
		IF v_prop.device_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_Id = NEW.device_collection_id;
				IF v_device_collection.device_collection_Type != v_prop.device_collection_type
				THEN
					RAISE 'device_collection_id must be of type %',
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

	-- If the LHS contains a dns_domain_collection_ID, check to see if it must be a
	-- specific type (e.g. per-dns_domain), and verify that if so
	IF NEW.dns_domain_collection_id IS NOT NULL THEN
		IF v_prop.dns_domain_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_dns_domain_collection
					FROM dns_domain_collection WHERE
					dns_domain_collection_Id = NEW.dns_domain_collection_id;
				IF v_dns_domain_collection.dns_domain_collection_Type != v_prop.dns_domain_collection_type
				THEN
					RAISE 'dns_domain_collection_id must be of type %',
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

	-- If the LHS contains a layer2_network_collection_ID, check to see if it must be a
	-- specific type (e.g. per-layer2_network), and verify that if so
	IF NEW.layer2_network_collection_id IS NOT NULL THEN
		IF v_prop.layer2_network_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_layer2_network_collection
					FROM layer2_network_collection WHERE
					layer2_network_collection_Id = NEW.layer2_network_collection_id;
				IF v_layer2_network_collection.layer2_network_collection_Type != v_prop.layer2_network_collection_type
				THEN
					RAISE 'layer2_network_collection_id must be of type %',
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

	-- If the LHS contains a layer3_network_collection_ID, check to see if it must be a
	-- specific type (e.g. per-layer3_network), and verify that if so
	IF NEW.layer3_network_collection_id IS NOT NULL THEN
		IF v_prop.layer3_network_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_layer3_network_collection
					FROM layer3_network_collection WHERE
					layer3_network_collection_Id = NEW.layer3_network_collection_id;
				IF v_layer3_network_collection.layer3_network_collection_Type != v_prop.layer3_network_collection_type
				THEN
					RAISE 'layer3_network_collection_id must be of type %',
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

	-- If the LHS contains a netblock_collection_ID, check to see if it must be a
	-- specific type (e.g. per-netblock), and verify that if so
	IF NEW.netblock_collection_id IS NOT NULL THEN
		IF v_prop.netblock_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.netblock_collection_id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.netblock_collection_type
				THEN
					RAISE 'netblock_collection_id must be of type %',
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

	-- If the LHS contains a property_collection_ID, check to see if it must be a
	-- specific type (e.g. per-property), and verify that if so
	IF NEW.property_collection_id IS NOT NULL THEN
		IF v_prop.property_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_property_collection
					FROM property_collection WHERE
					property_collection_Id = NEW.property_collection_id;
				IF v_property_collection.property_collection_Type != v_prop.property_collection_type
				THEN
					RAISE 'property_collection_id must be of type %',
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

	-- If the LHS contains a service_env_collection_ID, check to see if it must be a
	-- specific type (e.g. per-service_env), and verify that if so
	IF NEW.service_env_collection_id IS NOT NULL THEN
		IF v_prop.service_env_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_env_collection
					FROM service_env_collection WHERE
					service_env_collection_Id = NEW.service_env_collection_id;
				IF v_service_env_collection.service_env_collection_Type != v_prop.service_env_collection_type
				THEN
					RAISE 'service_env_collection_id must be of type %',
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

	-- If the RHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
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

	-- If the RHS contains a device_collection_id, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_dev_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_id = NEW.Property_Value_Device_Coll_Id;
				IF v_device_collection.device_collection_type !=
					v_prop.prop_val_dev_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Device_Coll_Id must be of type %',
					v_prop.prop_val_dev_coll_type_rstrct
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

	IF v_prop.Permit_Company_Collection_Id = 'REQUIRED' THEN
			IF NEW.Company_Collection_Id IS NULL THEN
				RAISE 'Company_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Company_Collection_Id = 'PROHIBITED' THEN
			IF NEW.Company_Collection_Id IS NOT NULL THEN
				RAISE 'Company_Collection_Id is prohibited.'
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

	IF v_prop.permit_layer2_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer2_network_collection_id IS NULL THEN
				RAISE 'layer2_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer2_network_coll_id = 'PROHIBITED' THEN
			IF NEW.layer2_network_collection_id IS NOT NULL THEN
				RAISE 'layer2_network_collection_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_layer3_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer3_network_collection_id IS NULL THEN
				RAISE 'layer3_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer3_network_coll_id = 'PROHIBITED' THEN
			IF NEW.layer3_network_collection_id IS NOT NULL THEN
				RAISE 'layer3_network_collection_id is prohibited.'
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

	IF v_prop.Permit_network_range_id = 'REQUIRED' THEN
			IF NEW.network_range_id IS NULL THEN
				RAISE 'network_range_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_network_range_id = 'PROHIBITED' THEN
			IF NEW.network_range_id IS NOT NULL THEN
				RAISE 'network_range_id is prohibited.'
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
$function$
;
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE ON property FOR EACH ROW EXECUTE PROCEDURE validate_property();

-- XXX - may need to include trigger function
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property');
ALTER SEQUENCE property_property_id_seq
	 OWNED BY property.property_id;
DROP TABLE IF EXISTS property_v71;
DROP TABLE IF EXISTS audit.property_v71;
-- DONE DEALING WITH TABLE property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE x509_certificate
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_certificate', 'x509_signed_certificate');
-- transfering grants from old object to new
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_certificate', 'x509_certificate');

-- FOREIGN KEYS FROM
ALTER TABLE x509_key_usage_attribute DROP CONSTRAINT IF EXISTS fk_x509_certificate;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS fk_x509_cert_cert;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS fk_x509_cert_revoc_reason;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS fk_x509cert_enc_id_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'x509_certificate');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS ak_x509_cert_cert_ca_ser;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS ak_x509_cert_ski;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS pk_x509_certificate;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif3x509_certificate";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS check_yes_no_1933598984;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS check_yes_no_31190954;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_x509_certificate ON jazzhands.x509_certificate;
DROP TRIGGER IF EXISTS trigger_audit_x509_certificate ON jazzhands.x509_certificate;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'x509_certificate');
---- BEGIN audit.x509_certificate TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'x509_certificate', 'x509_signed_certificate');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'x509_certificate');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."x509_certificate_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'x509_certificate');
---- DONE audit.x509_certificate TEARDOWN


ALTER TABLE x509_certificate RENAME TO x509_certificate_v71;
ALTER TABLE audit.x509_certificate RENAME TO x509_certificate_v71;

CREATE TABLE x509_signed_certificate
(
	x509_signed_certificate_id	integer NOT NULL,
	x509_certificate_type	varchar(50)  NULL,
	subject	varchar(255) NOT NULL,
	friendly_name	varchar(255) NOT NULL,
	subject_key_identifier	varchar(255)  NULL,
	is_active	character(1) NOT NULL,
	is_certificate_authority	character(1) NOT NULL,
	signing_cert_id	integer  NULL,
	x509_ca_cert_serial_number	numeric  NULL,
	public_key	text  NULL,
	private_key_id	integer  NULL,
	certificate_signing_request_id	integer  NULL,
	valid_from	timestamp(6) without time zone NOT NULL,
	valid_to	timestamp(6) without time zone NOT NULL,
	x509_revocation_date	timestamp with time zone  NULL,
	x509_revocation_reason	varchar(50)  NULL,
	ocsp_uri	varchar(255)  NULL,
	crl_uri	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
ALTER SEQUENCE audit.x509_certificate_seq  RENAME TO x509_signed_certificate_seq;
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'x509_signed_certificate', false);
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'x509_signed_certificate');
ALTER TABLE x509_signed_certificate
	ALTER x509_signed_certificate_id
	SET DEFAULT nextval('x509_signed_certificate_x509_signed_certificate_id_seq'::regclass);
ALTER TABLE x509_signed_certificate
	ALTER x509_certificate_type
	SET DEFAULT 'default'::character varying;
ALTER TABLE x509_signed_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE x509_signed_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;


-- BEGIN Manually written insert function
/**************************************************************************/

INSERT INTO x509_signed_certificate
SELECT
        x509_cert_id,
        'default',
        subject,
        friendly_name,
        subject_key_identifier,
        is_active,
        is_certificate_authority,
        signing_cert_id,
        x509_ca_cert_serial_number,
        public_key,
        CASE WHEN private_key is NOT NULL THEN x509_cert_id ELSE NULL END,
        CASE WHEN certificate_sign_req is NOT NULL THEN x509_cert_id ELSE NULL END,
        valid_from,
        valid_to,
        x509_revocation_date,
        x509_revocation_reason,
        ocsp_uri,
        crl_uri,
        data_ins_user,
        data_ins_date,
        data_upd_user,
        data_upd_date
FROM x509_certificate_v71
WHERE public_key IS NOT NULL
;

INSERT INTO audit.x509_signed_certificate
SELECT x509_cert_id,
        'default',
        subject,
        friendly_name,
        subject_key_identifier,
        is_active,
        is_certificate_authority,
        signing_cert_id,
        x509_ca_cert_serial_number,
        public_key,
        CASE WHEN private_key is NOT NULL THEN x509_cert_id ELSE NULL END,
        CASE WHEN certificate_sign_req is NOT NULL THEN x509_cert_id ELSE NULL END,
        valid_from,
        valid_to,
        x509_revocation_date,
        x509_revocation_reason,
        ocsp_uri,
        crl_uri,
        data_ins_user,
        data_ins_date,
        data_upd_user,
        data_upd_date,
        "aud#action",
        "aud#timestamp",
        NULL,
        NULL,
        "aud#user",
        "aud#seq"
FROM audit.x509_certificate_v71
WHERE x509_cert_id IN (select x509_cert_id FROM audit.x509_certificate_v71
        WHERE public_key IS NOT NULL)
ORDER BY "aud#seq";
;

/*
SELECT schema_support.rebuild_audit_trigger
                        ( 'audit', 'jazzhands', 'certificate_signing_request' );
SELECT schema_support.rebuild_audit_trigger
                        ( 'audit', 'jazzhands', 'private_key' );
SELECT schema_support.rebuild_audit_trigger
                        ( 'audit', 'jazzhands', 'x509_signed_certificate' );
*/

/**************************************************************************/




-- END Manually written insert function
ALTER TABLE x509_signed_certificate
	ALTER x509_signed_certificate_id
	SET DEFAULT nextval('x509_signed_certificate_x509_signed_certificate_id_seq'::regclass);
ALTER TABLE x509_signed_certificate
	ALTER x509_certificate_type
	SET DEFAULT 'default'::character varying;
ALTER TABLE x509_signed_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE x509_signed_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE x509_signed_certificate ADD CONSTRAINT ak_x509_cert_cert_ca_ser UNIQUE (signing_cert_id, x509_ca_cert_serial_number);
ALTER TABLE x509_signed_certificate ADD CONSTRAINT pk_x509_certificate PRIMARY KEY (x509_signed_certificate_id);

-- Table/Column Comments
COMMENT ON TABLE x509_signed_certificate IS 'Signed X509 Certificate';
COMMENT ON COLUMN x509_signed_certificate.x509_signed_certificate_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN x509_signed_certificate.x509_certificate_type IS 'business rule; default set but should be set to something else.
';
COMMENT ON COLUMN x509_signed_certificate.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.  This is the full subject from the certificate.  Friendly Name provides a human readable one.';
COMMENT ON COLUMN x509_signed_certificate.friendly_name IS 'human readable name for certificate.  often just the CN.';
COMMENT ON COLUMN x509_signed_certificate.subject_key_identifier IS 'x509 ski (hash, usually sha1 of public key).  must match private_key column if private key is set.';
COMMENT ON COLUMN x509_signed_certificate.is_active IS 'indicates certificate is in active use.  This is used by tools to decide how to show it; does not indicate revocation';
COMMENT ON COLUMN x509_signed_certificate.signing_cert_id IS 'x509_cert_id for the certificate that has signed this one.';
COMMENT ON COLUMN x509_signed_certificate.x509_ca_cert_serial_number IS 'Serial number assigned to the certificate within Certificate Authority. It uniquely identifies certificate within the realm of the CA.';
COMMENT ON COLUMN x509_signed_certificate.public_key IS 'Textual representation of Certificate Public Key. Public Key is a component of X509 standard and is used for encryption.  This will become mandatory in a future release.';
COMMENT ON COLUMN x509_signed_certificate.private_key_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN x509_signed_certificate.certificate_signing_request_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN x509_signed_certificate.valid_from IS 'Timestamp indicating when the certificate becomes valid and can be used.';
COMMENT ON COLUMN x509_signed_certificate.valid_to IS 'Timestamp indicating when the certificate becomes invalid and can''t be used.';
COMMENT ON COLUMN x509_signed_certificate.x509_revocation_date IS 'if certificate was revoked, when it was revokeed.  reason must also be set.   NULL means not revoked';
COMMENT ON COLUMN x509_signed_certificate.x509_revocation_reason IS 'if certificate was revoked, why iit was revokeed.  date must also be set.   NULL means not revoked';
COMMENT ON COLUMN x509_signed_certificate.ocsp_uri IS 'The URI (without URI: prefix) of the OCSP server for certs signed by this CA.  This is only valid for CAs.  This URI will be included in said certificates.';
COMMENT ON COLUMN x509_signed_certificate.crl_uri IS 'The URI (without URI: prefix) of the CRL for certs signed by this CA.  This is only valid for CAs.  This URI will be included in said certificates.';
-- INDEXES
CREATE INDEX xif3x509_signed_certificate ON x509_signed_certificate USING btree (x509_revocation_reason);
CREATE INDEX xif4x509_signed_certificate ON x509_signed_certificate USING btree (private_key_id);
CREATE INDEX xif5x509_signed_certificate ON x509_signed_certificate USING btree (certificate_signing_request_id);
CREATE INDEX xif6x509_signed_certificate ON x509_signed_certificate USING btree (x509_certificate_type);

-- CHECK CONSTRAINTS
ALTER TABLE x509_signed_certificate ADD CONSTRAINT check_yes_no_1566384929
	CHECK (is_active = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE x509_signed_certificate ADD CONSTRAINT check_yes_no_715951406
	CHECK (is_certificate_authority = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK between x509_signed_certificate and x509_key_usage_default
-- Skipping this FK since column does not exist yet
--ALTER TABLE x509_key_usage_default
--	ADD CONSTRAINT fk_keyusg_deflt_x509crtid
--	FOREIGN KEY (x509_signed_certificate_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id);

-- consider FK between x509_signed_certificate and property
ALTER TABLE property
	ADD CONSTRAINT fk_prop_x509_crt_id
	FOREIGN KEY (x509_signed_certificate_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id);
-- consider FK between x509_signed_certificate and x509_key_usage_attribute
ALTER TABLE x509_key_usage_attribute
	ADD CONSTRAINT fk_x509_certificate
	FOREIGN KEY (x509_cert_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id);

-- FOREIGN KEYS TO
-- consider FK x509_signed_certificate and certificate_signing_request
ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT fk_csr_pvtkeyid
	FOREIGN KEY (certificate_signing_request_id) REFERENCES certificate_signing_request(certificate_signing_request_id);
-- consider FK x509_signed_certificate and private_key
ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT fk_pvtkey_x509crt
	FOREIGN KEY (private_key_id) REFERENCES private_key(private_key_id);
-- consider FK x509_signed_certificate and x509_signed_certificate
ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT fk_x509_cert_cert
	FOREIGN KEY (signing_cert_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id);
-- consider FK x509_signed_certificate and val_x509_revocation_reason
ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT fk_x509_cert_revoc_reason
	FOREIGN KEY (x509_revocation_reason) REFERENCES val_x509_revocation_reason(x509_revocation_reason);
-- consider FK x509_signed_certificate and val_x509_certificate_type
ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT fk_x509crtid_crttype
	FOREIGN KEY (x509_certificate_type) REFERENCES val_x509_certificate_type(x509_certificate_type);

-- TRIGGERS
-- consider NEW jazzhands.x509_signed_ski_pvtkey_validate
CREATE OR REPLACE FUNCTION jazzhands.x509_signed_ski_pvtkey_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	ski	TEXT;
BEGIN
	--
	-- XXX needs to be tweaked to ensure that both are set or not set.
	--
	IF NEW.private_key_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	subject_key_identifier
	INTO	ski
	FROM	private_key p
	WHERE	p.private_key_id = NEW.private_key_id;

	IF FOUND AND ski != NEW.subject_key_identifier THEN
		RAISE EXCEPTION 'subject key identifier must match private key in private_key' USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_x509_signed_ski_pvtkey_validate AFTER INSERT OR UPDATE OF subject_key_identifier, private_key_id ON x509_signed_certificate FOR EACH ROW EXECUTE PROCEDURE x509_signed_ski_pvtkey_validate();

-- XXX - may need to include trigger function
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'x509_signed_certificate');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'x509_signed_certificate');
ALTER SEQUENCE x509_signed_certificate_x509_signed_certificate_id_seq
	 OWNED BY x509_signed_certificate.x509_signed_certificate_id;
DROP TABLE IF EXISTS x509_certificate_v71;
DROP TABLE IF EXISTS audit.x509_certificate_v71;
-- DONE DEALING WITH TABLE x509_signed_certificate
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE x509_key_usage_default
CREATE TABLE x509_key_usage_default
(
	x509_signed_certificate_id	integer NOT NULL,
	x509_key_usg	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'x509_key_usage_default', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE x509_key_usage_default ADD CONSTRAINT pk_x509_key_usage_default PRIMARY KEY (x509_signed_certificate_id, x509_key_usg);

-- Table/Column Comments
COMMENT ON TABLE x509_key_usage_default IS 'X509 Key Usage attributes set for certificates signed by a given CA.  Entries for this table for non-CAs make no sense.';
COMMENT ON COLUMN x509_key_usage_default.x509_signed_certificate_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN x509_key_usage_default.x509_key_usg IS 'key usage assigned by default for certificates signed by a given CA.';
COMMENT ON COLUMN x509_key_usage_default.description IS 'Textual Description of the certificate key usage.';
-- INDEXES
CREATE INDEX fk_x509keyusgdef_signcertid ON x509_key_usage_default USING btree (x509_signed_certificate_id);
CREATE INDEX xif2x509_key_usage_default ON x509_key_usage_default USING btree (x509_key_usg);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK x509_key_usage_default and x509_signed_certificate
ALTER TABLE x509_key_usage_default
	ADD CONSTRAINT fk_keyusg_deflt_x509crtid
	FOREIGN KEY (x509_signed_certificate_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id);
-- consider FK x509_key_usage_default and val_x509_key_usage
ALTER TABLE x509_key_usage_default
	ADD CONSTRAINT fk_keyusgdefault_keyusg
	FOREIGN KEY (x509_key_usg) REFERENCES val_x509_key_usage(x509_key_usg);

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'x509_key_usage_default');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'x509_key_usage_default');
-- DONE DEALING WITH TABLE x509_key_usage_default
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE x509_certificate
DROP VIEW IF EXISTS jazzhands.x509_certificate;
CREATE VIEW jazzhands.x509_certificate AS
 SELECT crt.x509_signed_certificate_id AS x509_cert_id,
    crt.friendly_name,
    crt.is_active,
    crt.is_certificate_authority,
    crt.signing_cert_id,
    crt.x509_ca_cert_serial_number,
    crt.public_key,
    key.private_key,
    csr.certificate_signing_request AS certificate_sign_req,
    crt.subject,
    crt.subject_key_identifier,
    crt.valid_from,
    crt.valid_to,
    crt.x509_revocation_date,
    crt.x509_revocation_reason,
    key.passphrase,
    key.encryption_key_id,
    crt.ocsp_uri,
    crt.crl_uri,
    crt.data_ins_user,
    crt.data_ins_date,
    crt.data_upd_user,
    crt.data_upd_date
   FROM x509_signed_certificate crt
     LEFT JOIN private_key key USING (private_key_id)
     LEFT JOIN certificate_signing_request csr USING (certificate_signing_request_id);

-- New function
CREATE OR REPLACE FUNCTION jazzhands.del_x509_certificate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	crt	x509_signed_certificate%ROWTYPE;
BEGIN
	SELECT * INTO crt FROM x509_signed_certificate
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	DELETE FROM x509_signed_certificate
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF crt.private_key_id IS NOT NULL THEN
		DELETE FROM private_key
		WHERE private_key_id = crt.private_key_id;
	END IF;

	IF crt.private_key_id IS NOT NULL THEN
		DELETE FROM certificate_signing_request
		WHERE certificate_signing_request_id =
			crt.certificate_signing_request_id;
	END IF;
	RETURN OLD;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.ins_x509_certificate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	key	private_key.private_key_id%TYPE;
	csr	certificate_signing_request.certificate_signing_request_id%TYPE;
	crt	x509_signed_certificate.x509_signed_certificate_id%TYPE;
BEGIN
	IF NEW.private_key IS NOT NULL THEN
		INSERT INTO private_key (
			private_key_encryption_type,
			is_active,
			subject_key_identifier,
			private_key,
			passphrase,
			encryption_key_id
		) VALUES (
			'rsa',
			NEW.is_active,
			NEW.subject_key_identifier,
			NEW.private_key,
			NEW.passphrase,
			NEW.encryption_key_id
		) RETURNING private_key_id INTO key;
		NEW.x509_cert_id := key;
	END IF;

	IF NEW.certificate_sign_req IS NOT NULL THEN
		INSERT INTO certificate_sign_req (
			friendly_name,
			subject,
			certificate_signing_request,
			private_key_id
		) VALUES (
			NEW.friendly_name,
			NEW.subject,
			NEW.certificate_sign_req,
			key
		) RETURNING certificate_signing_request_id INTO csr;
		IF NEW.x509_cert_id IS NULL THEN
			NEW.x509_cert_id := csr;
		END IF;
	END IF;

	IF NEW.public_key IS NOT NULL THEN
		INSERT INTO x509_signed_certificate (
			friendly_name,
			is_active,
			is_certificate_authority,
			signing_cert_id,
			x509_ca_cert_serial_number,
			public_key,
			subject,
			subject_key_identifier,
			valid_from,
			valid_to,
			x509_revocation_date,
			x509_revocation_reason,
			ocsp_uri,
			crl_uri,
			private_key_id,
			certificate_signing_request_id
		) VALUES (
			NEW.friendly_name,
			NEW.is_active,
			NEW.is_certificate_authority,
			NEW.signing_cert_id,
			NEW.x509_ca_cert_serial_number,
			NEW.public_key,
			NEW.subject,
			NEW.subject_key_identifier,
			NEW.valid_from,
			NEW.valid_to,
			NEW.x509_revocation_date,
			NEW.x509_revocation_reason,
			NEW.ocsp_uri,
			NEW.crl_uri,
			key,
			csr
		) RETURNING x509_signed_certificate_id INTO crt;
		NEW.x509_cert_id := crt;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.upd_x509_certificate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	upq	TEXT[];
	crt	x509_signed_certificate%ROWTYPE;
	key private_key.private_key_id%TYPE;
BEGIN
	SELECT * INTO crt FROM x509_signed_certificate
	WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF OLD.x509_cert_id != NEW.x509_cert_id THEN
		RAISE EXCEPTION 'Can not change x509_cert_id' USING ERRCODE = 'invalid_parameter_value';
	END IF;

	key := crt.private_key_id;

	IF crt.private_key_ID IS NULL AND NEW.private_key IS NOT NULL THEN
		WITH ins AS (
			INSERT INTO private_key (
				private_key_encryption_type,
				is_active,
				subject_key_identifier,
				private_key,
				passphrase,
				encryption_key_id
			) VALUES (
				'rsa',
				NEW.is_active,
				NEW.subject_key_identifier,
				NEW.private_key,
				NEW.passphrase,
				NEW.encryption_key_id
			) RETURNING *
		), upd AS (
			UPDATE x509_signed_certificate
			SET private_key_id = ins.private_key_id
			WHERE x509_signed_certificate_id = OLD.x509_cert_id
			RETURNING *
		)  SELECT private_key_id INTO key FROM upd;
	ELSIF crt.private_key_id IS NOT NULL AND NEW.private_key IS NULL THEN
		UPDATE x509_signed_certificate
			SET private_key_id = NULL
			WHERE x509_signed_certificate_id = OLD.x509_cert_id;
		BEGIN
			DELETE FROM private_key where private_key_id = crt.private_key_id;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	ELSE
		IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
			upq := array_append(upq,
				'is_active = ' || quote_literal(NEW.is_active)
			);
		END IF;

		IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
			upq := array_append(upq,
				'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
			);
		END IF;

		IF OLD.private_key IS DISTINCT FROM NEW.private_key THEN
			upq := array_append(upq,
				'private_key = ' || quote_nullable(NEW.private_key)
			);
		END IF;

		IF OLD.passphrase IS DISTINCT FROM NEW.passphrase THEN
			upq := array_append(upq,
				'passphrase = ' || quote_nullable(NEW.passphrase)
			);
		END IF;

		IF OLD.encryption_key_id IS DISTINCT FROM NEW.encryption_key_id THEN
			upq := array_append(upq,
				'encryption_key_id = ' || quote_nullable(NEW.encryption_key_id)
			);
		END IF;

		IF array_length(upq, 1) > 0 THEN
			EXECUTE 'UPDATE private_key SET '
				|| array_to_string(upq, ', ')
				|| ' WHERE private_key_id = '
				|| crt.private_key_id;
		END IF;
	END IF;

	upq := NULL;
	IF crt.certificate_signing_request_id IS NULL AND NEW.certificate_sign_req IS NOT NULL THEN
		WITH ins AS (
			INSERT INTO certificate_sign_req (
				friendly_name,
				subject,
				certificate_signing_request,
				private_key_id
			) VALUES (
				NEW.friendly_name,
				NEW.subject,
				NEW.certificate_sign_req,
				key
			) RETURNING *
		) UPDATE x509_signed_certificate
		SET certificate_signing_request_id = ins.certificate_signing_request_id
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;
	ELSIF crt.certificate_signing_request_id IS NOT NULL AND
				NEW.certificate_sign_req IS NULL THEN
		-- if its removed, we still keep the csr/key link
		WITH del AS (
			UPDATE x509_signed_certificate
			SET certificate_signing_request = NULL
			WHERE x509_signed_certificate_id = OLD.x509_cert_id
			RETURNING *
		) DELETE FROM certificate_signing_request
		WHERE certificate_signing_request_id =
			crt.certificate_signing_request_id;
	ELSE
		IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
			upq := array_append(upq,
				'friendly_name = ' || quote_literal(NEW.friendly_name)
			);
		END IF;

		IF OLD.subject IS DISTINCT FROM NEW.subject THEN
			upq := array_append(upq,
				'subject = ' || quote_literal(NEW.subject)
			);
		END IF;

		IF OLD.certificate_sign_req IS DISTINCT FROM
				NEW.certificate_sign_req THEN
			upq := array_append(upq,
				'certificate_signing_request = ' ||
					quote_literal(NEW.certificate_sign_req)
			);
		END IF;

		IF array_length(upq, 1) > 0 THEN
			EXECUTE 'UPDATE certificate_signing_request SET '
				|| array_to_string(upq, ', ')
				|| ' WHERE x509_signed_certificate_id = '
				|| crt.x509_signed_certificate_id;
		END IF;
	END IF;

	upq := NULL;
	IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
		upq := array_append(upq,
			'is_active = ' || quote_literal(NEW.is_active)
		);
	END IF;
	IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
		upq := array_append(upq,
			'friendly_name = ' || quote_literal(NEW.friendly_name)
		);
	END IF;
	IF OLD.subject IS DISTINCT FROM NEW.subject THEN
		upq := array_append(upq,
			'subject = ' || quote_literal(NEW.subject)
		);
	END IF;
	IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
		upq := array_append(upq,
			'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
		);
	END IF;
	IF OLD.is_certificate_authority IS DISTINCT FROM NEW.is_certificate_authority THEN
		upq := array_append(upq,
			'is_certificate_authority = ' || quote_nullable(NEW.is_certificate_authority)
		);
	END IF;
	IF OLD.signing_cert_id IS DISTINCT FROM NEW.signing_cert_id THEN
		upq := array_append(upq,
			'signing_cert_id = ' || quote_nullable(NEW.signing_cert_id)
		);
	END IF;
	IF OLD.x509_ca_cert_serial_number IS DISTINCT FROM NEW.x509_ca_cert_serial_number THEN
		upq := array_append(upq,
			'x509_ca_cert_serial_number = ' || quote_nullable(NEW.x509_ca_cert_serial_number)
		);
	END IF;
	IF OLD.public_key IS DISTINCT FROM NEW.public_key THEN
		upq := array_append(upq,
			'public_key = ' || quote_nullable(NEW.public_key)
		);
	END IF;
	IF OLD.valid_from IS DISTINCT FROM NEW.valid_from THEN
		upq := array_append(upq,
			'valid_from = ' || quote_nullable(NEW.valid_from)
		);
	END IF;
	IF OLD.valid_to IS DISTINCT FROM NEW.valid_to THEN
		upq := array_append(upq,
			'valid_to = ' || quote_nullable(NEW.valid_to)
		);
	END IF;
	IF OLD.x509_revocation_date IS DISTINCT FROM NEW.x509_revocation_date THEN
		upq := array_append(upq,
			'x509_revocation_date = ' || quote_nullable(NEW.x509_revocation_date)
		);
	END IF;
	IF OLD.x509_revocation_reason IS DISTINCT FROM NEW.x509_revocation_reason THEN
		upq := array_append(upq,
			'x509_revocation_reason = ' || quote_nullable(NEW.x509_revocation_reason)
		);
	END IF;
	IF OLD.ocsp_uri IS DISTINCT FROM NEW.ocsp_uri THEN
		upq := array_append(upq,
			'ocsp_uri = ' || quote_nullable(NEW.ocsp_uri)
		);
	END IF;
	IF OLD.crl_uri IS DISTINCT FROM NEW.crl_uri THEN
		upq := array_append(upq,
			'crl_uri = ' || quote_nullable(NEW.crl_uri)
		);
	END IF;

	IF array_length(upq, 1) > 0 THEN
		EXECUTE 'UPDATE x509_signed_certificate SET '
			|| array_to_string(upq, ', ')
			|| ' WHERE x509_signed_certificate_id = '
			|| NEW.x509_cert_id;
	END IF;

	RETURN NEW;
END;
$function$
;


-- DONE DEALING WITH TABLE x509_certificate
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_property
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_property', 'v_property');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_property');
DROP VIEW IF EXISTS jazzhands.v_property;
CREATE VIEW jazzhands.v_property AS
 SELECT property.property_id,
    property.account_collection_id,
    property.account_id,
    property.account_realm_id,
    property.company_collection_id,
    property.company_id,
    property.device_collection_id,
    property.dns_domain_collection_id,
    property.dns_domain_id,
    property.layer2_network_collection_id,
    property.layer3_network_collection_id,
    property.netblock_collection_id,
    property.network_range_id,
    property.operating_system_id,
    property.operating_system_snapshot_id,
    property.person_id,
    property.property_collection_id,
    property.service_env_collection_id,
    property.site_code,
    property.x509_signed_certificate_id,
    property.property_name,
    property.property_type,
    property.property_value,
    property.property_value_timestamp,
    property.property_value_company_id,
    property.property_value_account_coll_id,
    property.property_value_device_coll_id,
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
-- DONE DEALING WITH TABLE v_property
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE x509_certificate
DROP VIEW IF EXISTS jazzhands.x509_certificate;
CREATE VIEW jazzhands.x509_certificate AS
 SELECT crt.x509_signed_certificate_id AS x509_cert_id,
    crt.friendly_name,
    crt.is_active,
    crt.is_certificate_authority,
    crt.signing_cert_id,
    crt.x509_ca_cert_serial_number,
    crt.public_key,
    key.private_key,
    csr.certificate_signing_request AS certificate_sign_req,
    crt.subject,
    crt.subject_key_identifier,
    crt.valid_from,
    crt.valid_to,
    crt.x509_revocation_date,
    crt.x509_revocation_reason,
    key.passphrase,
    key.encryption_key_id,
    crt.ocsp_uri,
    crt.crl_uri,
    crt.data_ins_user,
    crt.data_ins_date,
    crt.data_upd_user,
    crt.data_upd_date
   FROM x509_signed_certificate crt
     LEFT JOIN private_key key USING (private_key_id)
     LEFT JOIN certificate_signing_request csr USING (certificate_signing_request_id);

-- DONE DEALING WITH TABLE x509_certificate
--------------------------------------------------------------------
SELECT schema_support.replay_object_recreates();
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE mv_unix_passwd_mappings
DROP MATERIALIZED VIEW IF EXISTS jazzhands.mv_unix_passwd_mappings;
CREATE MATERIALIZED VIEW jazzhands.mv_unix_passwd_mappings AS
 SELECT v_unix_passwd_mappings.device_collection_id,
    v_unix_passwd_mappings.account_id,
    v_unix_passwd_mappings.login,
    v_unix_passwd_mappings.crypt,
    v_unix_passwd_mappings.unix_uid,
    v_unix_passwd_mappings.unix_group_name,
    v_unix_passwd_mappings.gecos,
    v_unix_passwd_mappings.home,
    v_unix_passwd_mappings.shell,
    v_unix_passwd_mappings.ssh_public_key,
    v_unix_passwd_mappings.setting,
    v_unix_passwd_mappings.mclass_setting,
    v_unix_passwd_mappings.extra_groups
   FROM v_unix_passwd_mappings;

-- DONE DEALING WITH TABLE mv_unix_passwd_mappings
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE mv_unix_group_mappings
DROP MATERIALIZED VIEW IF EXISTS jazzhands.mv_unix_group_mappings;
CREATE MATERIALIZED VIEW jazzhands.mv_unix_group_mappings AS
 SELECT v_unix_group_mappings.device_collection_id,
    v_unix_group_mappings.account_collection_id,
    v_unix_group_mappings.group_name,
    v_unix_group_mappings.unix_gid,
    v_unix_group_mappings.group_password,
    v_unix_group_mappings.setting,
    v_unix_group_mappings.mclass_setting,
    v_unix_group_mappings.members
   FROM v_unix_group_mappings;

-- DONE DEALING WITH TABLE mv_unix_group_mappings
--------------------------------------------------------------------
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
--------------------------------------------------------------------
-- DEALING WITH TABLE v_person_company_audit_map
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_person_company_audit_map', 'v_person_company_audit_map');
SELECT schema_support.save_dependent_objects_for_replay('approval_utils', 'v_person_company_audit_map');
DROP VIEW IF EXISTS approval_utils.v_person_company_audit_map;
CREATE VIEW approval_utils.v_person_company_audit_map AS
 WITH all_audrecs AS (
         SELECT pca.company_id,
            pca.person_id,
            pca.person_company_status,
            pca.person_company_relation,
            pca.is_exempt,
            pca.is_management,
            pca.is_full_time,
            pca.description,
            pca.employee_id,
            pca.payroll_id,
            pca.external_hr_id,
            pca.position_title,
            pca.badge_system_id,
            pca.hire_date,
            pca.termination_date,
            pca.manager_person_id,
            pca.supervisor_person_id,
            pca.nickname,
            pca.data_ins_user,
            pca.data_ins_date,
            pca.data_upd_user,
            pca.data_upd_date,
            pca."aud#action",
            pca."aud#timestamp",
            pca."aud#realtime",
            pca."aud#txid",
            pca."aud#user",
            pca."aud#seq",
            row_number() OVER (PARTITION BY pc.person_id, pc.company_id ORDER BY pca."aud#timestamp" DESC) AS rownum
           FROM person_company pc
             JOIN audit.person_company pca USING (person_id, company_id)
          WHERE pca."aud#action" = ANY (ARRAY['UPD'::bpchar, 'INS'::bpchar])
        )
 SELECT all_audrecs."aud#seq" AS audit_seq_id,
    all_audrecs.company_id,
    all_audrecs.person_id,
    all_audrecs.person_company_status,
    all_audrecs.person_company_relation,
    all_audrecs.is_exempt,
    all_audrecs.is_management,
    all_audrecs.is_full_time,
    all_audrecs.description,
    all_audrecs.employee_id,
    all_audrecs.payroll_id,
    all_audrecs.external_hr_id,
    all_audrecs.position_title,
    all_audrecs.badge_system_id,
    all_audrecs.hire_date,
    all_audrecs.termination_date,
    all_audrecs.manager_person_id,
    all_audrecs.supervisor_person_id,
    all_audrecs.nickname,
    all_audrecs.data_ins_user,
    all_audrecs.data_ins_date,
    all_audrecs.data_upd_user,
    all_audrecs.data_upd_date,
    all_audrecs."aud#action",
    all_audrecs."aud#timestamp",
    all_audrecs."aud#realtime",
    all_audrecs."aud#txid",
    all_audrecs."aud#user",
    all_audrecs."aud#seq",
    all_audrecs.rownum
   FROM all_audrecs
  WHERE all_audrecs.rownum = 1;

delete from __recreate where type = 'view' and object = 'v_person_company_audit_map';
-- DONE DEALING WITH TABLE v_person_company_audit_map
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_account_collection_account_audit_map
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_account_collection_account_audit_map', 'v_account_collection_account_audit_map');
SELECT schema_support.save_dependent_objects_for_replay('approval_utils', 'v_account_collection_account_audit_map');
DROP VIEW IF EXISTS approval_utils.v_account_collection_account_audit_map;
CREATE VIEW approval_utils.v_account_collection_account_audit_map AS
 WITH all_audrecs AS (
         SELECT acaa.account_collection_id,
            acaa.account_id,
            acaa.account_id_rank,
            acaa.start_date,
            acaa.finish_date,
            acaa.data_ins_user,
            acaa.data_ins_date,
            acaa.data_upd_user,
            acaa.data_upd_date,
            acaa."aud#action",
            acaa."aud#timestamp",
            acaa."aud#realtime",
            acaa."aud#txid",
            acaa."aud#user",
            acaa."aud#seq",
            row_number() OVER (PARTITION BY aca.account_collection_id, aca.account_id ORDER BY acaa."aud#timestamp" DESC) AS rownum
           FROM account_collection_account aca
             JOIN audit.account_collection_account acaa USING (account_collection_id, account_id)
          WHERE acaa."aud#action" = ANY (ARRAY['UPD'::bpchar, 'INS'::bpchar])
        )
 SELECT all_audrecs."aud#seq" AS audit_seq_id,
    all_audrecs.account_collection_id,
    all_audrecs.account_id,
    all_audrecs.account_id_rank,
    all_audrecs.start_date,
    all_audrecs.finish_date,
    all_audrecs.data_ins_user,
    all_audrecs.data_ins_date,
    all_audrecs.data_upd_user,
    all_audrecs.data_upd_date,
    all_audrecs."aud#action",
    all_audrecs."aud#timestamp",
    all_audrecs."aud#realtime",
    all_audrecs."aud#txid",
    all_audrecs."aud#user",
    all_audrecs."aud#seq",
    all_audrecs.rownum
   FROM all_audrecs
  WHERE all_audrecs.rownum = 1;

delete from __recreate where type = 'view' and object = 'v_account_collection_account_audit_map';
-- DONE DEALING WITH TABLE v_account_collection_account_audit_map
--------------------------------------------------------------------
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_object_recreates();
--
-- Process drops in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_automated_reporting_ac');
CREATE OR REPLACE FUNCTION jazzhands.account_automated_reporting_ac()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_numrpt	INTEGER;
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

	-- XXX check account realm to see if we should be inserting for this
	-- XXX account realm

	IF TG_OP = 'INSERT' THEN
		PERFORM auto_ac_manip.make_all_auto_acs_right(
			account_id := NEW.account_id,
			account_realm_id := NEW.account_realm_id,
			login := NEW.login
		);
	ELSIF TG_OP = 'UPDATE' THEN
		PERFORM auto_ac_manip.rename_automated_report_acs(
			NEW.account_id, OLD.login, NEW.login, NEW.account_realm_id);
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM account_collection_account WHERE account_id
			= OLD.account_id
		AND account_collection_id IN ( select account_collection_id
			FROM account_collection where account_collection_type
			= 'automated'
		);
		-- PERFORM auto_ac_manip.destroy_report_account_collections(
		-- 	account_id := OLD.account_id,
		-- 	account_realm_id := OLD.account_realm_id
		-- );
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_change_realm_aca_realm');
CREATE OR REPLACE FUNCTION jazzhands.account_change_realm_aca_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account_collection USING (account_collection_id)
			JOIN val_account_collection_type vt USING (account_collection_type)
	WHERE	vt.account_realm_id IS NOT NULL
	AND		vt.account_realm_id != NEW.account_realm_id
	AND		account_id = NEW.account_id;

	IF _tally > 0 THEN
		RAISE EXCEPTION 'New account realm (%) is part of % account collections with a type restriction',
			NEW.account_realm_id,
			_tally
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_collection_account_realm');
CREATE OR REPLACE FUNCTION jazzhands.account_collection_account_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_a	account%ROWTYPE;
	_at	val_account_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	_at
	FROM	val_account_collection_type
		JOIN account_collection USING (account_collection_type)
	WHERE
		account_collection_id = NEW.account_collection_id;

	-- no restrictions, so do not care
	IF _at.account_realm_id IS NULL THEN
		RETURN NEW;
	END IF;

	-- check to see if the account's account realm matches
	IF TG_OP = 'INSERT' OR OLD.account_id != NEW.account_id THEN
		SELECT	*
		INTO	_a
		FROM	account
		WHERE	account_id = NEW.account_id;

		IF _a.account_realm_id != _at.account_realm_id THEN
			RAISE EXCEPTION 'account realm of % does not match account realm restriction on account_collection %',
				NEW.account_id, NEW.account_collection_id
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_instance_step_auto_complete');
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_step_auto_complete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	--
	-- on insert, if the parent was already marked as completed, fail.
	-- arguably, this should happen on updates as well
	--	possibly should move this to a before trigger
	--
	IF TG_OP = 'INSERT' THEN
		SELECT	count(*)
		INTO	_tally
		FROM	approval_instance_step
		WHERE	approval_instance_step_id = NEW.approval_instance_step_id
		AND		is_completed = 'Y';

		IF _tally > 0 THEN
			RAISE EXCEPTION 'Completed attestation cycles may not have items added';
		END IF;
	END IF;

	IF NEW.is_approved IS NOT NULL THEN
		SELECT	count(*)
		INTO	_tally
		FROM	approval_instance_item
		WHERE	approval_instance_step_id = NEW.approval_instance_step_id
		AND		approval_instance_item_id != NEW.approval_instance_item_id
		AND		is_approved IS NOT NULL;

		IF _tally = 0 THEN
			UPDATE	approval_instance_step
			SET		is_completed = 'Y',
					approval_instance_step_end = now()
			WHERE	approval_instance_step_id = NEW.approval_instance_step_id;
		END IF;

	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_account');
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


	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(NEW.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(NEW.account_id);

		-- update the person's manager to match
		WITH RECURSIVE map AS (
			SELECT account_id as root_account_id,
				account_id, login, manager_account_id, manager_login
			FROM v_account_manager_map
			UNION
			SELECT map.root_account_id, m.account_id, m.login,
				m.manager_account_id, m.manager_login
				from v_account_manager_map m
					join map on m.account_id = map.manager_account_id
			), x AS ( SELECT auto_ac_manip.make_auto_report_acs_right(
					account_id := manager_account_id,
					account_realm_id := NEW.account_realm_id,
					login := manager_login)
				FROM map
				WHERE root_account_id = NEW.account_id
			) SELECT count(*) INTO _tally FROM x;
	END IF;

	IF TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(OLD.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(OLD.account_id);
	END IF;

	-- when deleting, do nothing rather than calling the above, same as
	-- update; pointless because account is getting deleted anyway.

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_person_company');
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
	IF ( TG_OP = 'INSERT' OR TG_OP = 'UPDATE' ) THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id
		AND		company_id = NEW.company_id;

		IF ( TG_OP = 'INSERT' OR ( TG_OP = 'UPDATE' AND
				NEW.manager_person_id != OLD.manager_person_id )
		) THEN
			-- update the person's manager to match
			WITH RECURSIVE map As (
				SELECT account_id as root_account_id,
					account_id, login, manager_account_id, manager_login
				FROM v_account_manager_map
				UNION
				SELECT map.root_account_id, m.account_id, m.login,
					m.manager_account_id, m.manager_login
					from v_account_manager_map m
						join map on m.account_id = map.manager_account_id
			), x AS ( SELECT auto_ac_manip.make_auto_report_acs_right(
						account_id := manager_account_id,
						account_realm_id := account_realm_id,
						login := manager_login)
					FROM map m
							join v_corp_family_account a ON
								a.account_id = m.root_account_id
					WHERE a.person_id = NEW.person_id
					AND a.company_id = NEW.company_id
			) SELECT count(*) into _tally from x;
			IF TG_OP = 'UPDATE' THEN
				PERFORM auto_ac_manip.make_auto_report_acs_right(
							account_id := account_id)
				FROM    v_corp_family_account
				WHERE   account_role = 'primary'
				AND     is_enabled = 'Y'
				AND     person_id = OLD.manager_person_id;
			END IF;
		END IF;
	END IF;

	IF ( TG_OP = 'DELETE' OR TG_OP = 'UPDATE' ) THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = OLD.person_id
		AND		company_id = OLD.company_id;
	END IF;
	IF ( TG_OP = 'UPDATE' ) THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id
		AND		company_id = NEW.company_id;
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'check_svcenv_colllection_hier_loop');
CREATE OR REPLACE FUNCTION jazzhands.check_svcenv_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.service_env_collection_id =
		NEW.child_service_env_coll_id THEN
			RAISE EXCEPTION 'svcenv Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'create_device_component_by_trigger');
CREATE OR REPLACE FUNCTION jazzhands.create_device_component_by_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	devtype		RECORD;
	ctid		integer;
	cid			integer;
	scarr       integer[];
	dcarr       integer[];
	server_ver	integer;
BEGIN

	SELECT
		dt.device_type_id,
		dt.component_type_id,
		dt.template_device_id,
		d.component_id
	INTO
		devtype
	FROM
		device_type dt LEFT JOIN
		device d ON (dt.template_device_id = d.device_id)
	WHERE
		dt.device_type_id = NEW.device_type_id;

	IF NEW.component_id IS NOT NULL THEN
		IF devtype.component_type_id IS NOT NULL THEN
			SELECT
				component_type_id INTO ctid
			FROM
				component c
			WHERE
				c.component_id = NEW.component_id;

			IF ctid != devtype.component_type_id THEN
				UPDATE
					component
				SET
					component_type_id = devtype.component_type_id
				WHERE
					component_id = NEW.component_id;
			END IF;
		END IF;

		RETURN NEW;
	END IF;

	--
	-- If template_device_id doesn't exist, then create an instance of
	-- the component_id if it exists
	--
	IF devtype.component_id IS NULL THEN
		--
		-- If the component_id doesn't exist, then we're done
		--
		IF devtype.component_type_id IS NULL THEN
			RETURN NEW;
		END IF;
		--
		-- Insert a component of the given type and tie it to the device
		--
		INSERT INTO component (component_type_id)
			VALUES (devtype.component_type_id)
			RETURNING component_id INTO cid;

		NEW.component_id := cid;
		RETURN NEW;
	ELSE
		SELECT setting INTO server_ver FROM pg_catalog.pg_settings
			WHERE name = 'server_version_num';

		IF (server_ver < 90400) THEN
			--
			-- This is pretty nasty; welcome to SQL
			--
			--
			-- This returns data into a temporary table (ugh) that's used as a
			-- key/value store to map each template component to the
			-- newly-created one
			--
			CREATE TEMPORARY TABLE trig_comp_ins AS
			WITH comp_ins AS (
				INSERT INTO component (
					component_type_id
				) SELECT
					c.component_type_id
				FROM
					device_type dt JOIN
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				WHERE
					device_type_id = NEW.device_type_id
				ORDER BY
					level, c.component_type_id
				RETURNING component_id
			)
			SELECT
				src_comp.component_id as src_component_id,
				dst_comp.component_id as dst_component_id,
				src_comp.level as level
			FROM
				(SELECT
					c.component_id,
					level,
					row_number() OVER (ORDER BY level, c.component_type_id)
						AS rownum
				 FROM
					device_type dt JOIN
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				 WHERE
					device_type_id = NEW.device_type_id
				) src_comp,
				(SELECT
					component_id,
					row_number() OVER () AS rownum
				 FROM
					comp_ins
				) dst_comp
			WHERE
				src_comp.rownum = dst_comp.rownum;

			/*
				 Now take the mapping of components that were inserted above,
				 and tie the new components to the appropriate slot on the
				 parent.
				 The logic below is:
					- Take the template component, and locate its parent slot
					- Find the correct slot on the corresponding new parent
					  component by locating one with the same slot_name and
					  slot_type_id on the mapped parent component_id
					- Update the parent_slot_id of the component with the
					  mapped component_id to this slot_id

				 This works even if the top-level component is attached to some
				 other device, since there will not be a mapping for those in
				 the table to locate.
			*/

			UPDATE
				component dc
			SET
				parent_slot_id = ds.slot_id
			FROM
				trig_comp_ins tt,
				trig_comp_ins ptt,
				component sc,
				slot ss,
				slot ds
			WHERE
				tt.src_component_id = sc.component_id AND
				tt.dst_component_id = dc.component_id AND
				ss.slot_id = sc.parent_slot_id AND
				ss.component_id = ptt.src_component_id AND
				ds.component_id = ptt.dst_component_id AND
				ss.slot_type_id = ds.slot_type_id AND
				ss.slot_name = ds.slot_name;

			SELECT dst_component_id INTO cid FROM trig_comp_ins WHERE
				level = 1;

			NEW.component_id := cid;

			DROP TABLE trig_comp_ins;

			RETURN NEW;
		ELSE
			WITH dev_comps AS (
				SELECT
					c.component_id,
					c.component_type_id,
					level,
					row_number() OVER (ORDER BY level, c.component_type_id) AS
						rownum
				FROM
					device_type dt JOIN
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				WHERE
					device_type_id = NEW.device_type_id
			),
			comp_ins AS (
				INSERT INTO component (
					component_type_id
				) SELECT
					component_type_id
				FROM
					dev_comps
				ORDER BY
					rownum
				RETURNING component_id, component_type_id
			),
			comp_ins_arr AS (
				SELECT
					array_agg(component_id) AS dst_arr
				FROM
					comp_ins
			),
			dev_comps_arr AS (
				SELECT
					array_agg(component_id) as src_arr
				FROM
					dev_comps
			)
			SELECT src_arr, dst_arr INTO scarr, dcarr FROM
				dev_comps_arr, comp_ins_arr;

			UPDATE
				component dc
			SET
				parent_slot_id = ds.slot_id
			FROM
				unnest(scarr, dcarr) AS
					tt(src_component_id, dst_component_id),
				unnest(scarr, dcarr) AS
					ptt(src_component_id, dst_component_id),
				component sc,
				slot ss,
				slot ds
			WHERE
				tt.src_component_id = sc.component_id AND
				tt.dst_component_id = dc.component_id AND
				ss.slot_id = sc.parent_slot_id AND
				ss.component_id = ptt.src_component_id AND
				ds.component_id = ptt.dst_component_id AND
				ss.slot_type_id = ds.slot_type_id AND
				ss.slot_name = ds.slot_name;

			SELECT
				component_id INTO NEW.component_id
			FROM
				component c
			WHERE
				component_id = ANY(dcarr) AND
				parent_slot_id IS NULL;

			RETURN NEW;
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'create_new_unix_account');
CREATE OR REPLACE FUNCTION jazzhands.create_new_unix_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	unix_id 		INTEGER;
	_account_collection_id 	INTEGER;
	_arid			INTEGER;
BEGIN
	--
	-- This should be a property that shows which account collections
	-- get unix accounts created by default, but the mapping of unix-groups
	-- to account collection across realms needs to be resolved
	--
	SELECT  account_realm_id
	INTO    _arid
	FROM    property
	WHERE   property_name = '_root_account_realm_id'
	AND     property_type = 'Defaults';

	IF _arid IS NOT NULL AND NEW.account_realm_id = _arid THEN
		IF NEW.person_id != 0 THEN
			PERFORM person_manip.setup_unix_account(
				in_account_id := NEW.account_id,
				in_account_type := NEW.account_type
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type_model_to_name');
CREATE OR REPLACE FUNCTION jazzhands.device_type_model_to_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND  (NEW.model IS DISTINCT FROM OLD.model AND
			NEW.device_type_name IS DISTINCT FROM OLD.device_type_name) THEN
		RAISE EXCEPTION 'Only device_type_name should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.model IS NOT NULL AND NEW.device_type_name IS NOT NULL THEN
			RAISE EXCEPTION 'Only model should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.model IS DISTINCT FROM NEW.model THEN
			NEW.device_type_name = NEW.model;
		ELSIF OLD.device_type_name IS DISTINCT FROM NEW.device_type_name THEN
			NEW.model = NEW.device_type_name;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.model IS NOT NULL THEN
			NEW.device_type_name = NEW.model;
		ELSIF NEW.device_type_name IS NOT NULL THEN
			NEW.model = NEW.device_type_name;
		END IF;
	ELSE
	END IF;

	-- company_id is going away
	IF NEW.company_id IS NULL THEN
		NEW.company_id := 0;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_a_rec_validation');
CREATE OR REPLACE FUNCTION jazzhands.dns_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_ip		netblock.ip_address%type;
	_sing	netblock.is_single_address%type;
BEGIN
	IF NEW.dns_type in ('A', 'AAAA') AND NEW.netblock_id IS NULL THEN
		RAISE EXCEPTION 'Attempt to set % record without a Netblock',
			NEW.dns_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	IF NEW.netblock_Id is not NULL and
			( NEW.dns_value IS NOT NULL OR NEW.dns_value_record_id IS NOT NULL ) THEN
		RAISE EXCEPTION 'Both dns_value and netblock_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	IF NEW.dns_value IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both dns_value and dns_value_record_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	IF NEW.netblock_id IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both netblock_id and dns_value_record_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	-- XXX need to deal with changing a netblock type and breaking dns_record..
	IF NEW.netblock_id IS NOT NULL THEN
		SELECT ip_address, is_single_address
		  INTO _ip, _sing
		  FROM netblock
		 WHERE netblock_id = NEW.netblock_id;

		IF NEW.dns_type = 'A' AND family(_ip) != '4' THEN
			RAISE EXCEPTION 'A records must be assigned to non-IPv4 records'
				USING ERRCODE = 'JH200';
		END IF;

		IF NEW.dns_type = 'AAAA' AND family(_ip) != '6' THEN
			RAISE EXCEPTION 'AAAA records must be assigned to non-IPv6 records'
				USING ERRCODE = 'JH200';
		END IF;

		IF _sing = 'N' AND NEW.dns_type IN ('A','AAAA') THEN
			RAISE EXCEPTION 'Non-single addresses may not have % records', NEW.dns_type
				USING ERRCODE = 'foreign_key_violation';
		END IF;

	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_trigger_change');
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_trigger_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF new.SHOULD_GENERATE = 'Y' THEN
		insert into DNS_CHANGE_RECORD
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_rec_prevent_dups');
CREATE OR REPLACE FUNCTION jazzhands.dns_rec_prevent_dups()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	-- should not be able to insert the same record(s) twice
	SELECT	count(*)
	  INTO	_tally
	  FROM	dns_record
	  WHERE
	  		( lower(dns_name) = lower(NEW.dns_name) OR
				(dns_name IS NULL AND NEW.dns_name is NULL)
			)
		AND
	  		( dns_domain_id = NEW.dns_domain_id )
		AND
	  		( dns_class = NEW.dns_class )
		AND
	  		( dns_type = NEW.dns_type )
		AND
	  		( dns_srv_service = NEW.dns_srv_service OR
				(dns_srv_service IS NULL and NEW.dns_srv_service is NULL)
			)
		AND
	  		( dns_srv_protocol = NEW.dns_srv_protocol OR
				(dns_srv_protocol IS NULL and NEW.dns_srv_protocol is NULL)
			)
		AND
	  		( dns_srv_port = NEW.dns_srv_port OR
				(dns_srv_port IS NULL and NEW.dns_srv_port is NULL)
			)
		AND
	  		( dns_value = NEW.dns_value OR
				(dns_value IS NULL and NEW.dns_value is NULL)
			)
		AND
	  		( netblock_id = NEW.netblock_id OR
				(netblock_id IS NULL AND NEW.netblock_id is NULL)
			)
		AND	is_enabled = 'Y'
	    AND dns_record_id != NEW.dns_record_id
	;

	IF _tally != 0 THEN
		RAISE EXCEPTION 'Attempt to insert the same dns record'
			USING ERRCODE = 'unique_violation';
	END IF;

	IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
		IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
			SELECT	count(*)
			 INTO	_tally
			 FROM	dns_record
			WHERE dns_class = 'IN'
			AND dns_type = 'A'
			AND should_generate_ptr = 'Y'
			AND is_enabled = 'Y'
			AND netblock_id = NEW.NETBLOCK_ID
			AND dns_record_id != NEW.DNS_RECORD_ID;

			IF _tally != 0 THEN
				RAISE EXCEPTION 'May not have more than one SHOULD_GENERATE_PTR record on the same IP on netblock_id %', NEW.netblock_id
					USING ERRCODE = 'JH201';
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_cname_checker');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_cname_checker()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_dom	TEXT;
BEGIN
	_tally := 0;
	IF TG_OP = 'INSERT' OR NEW.DNS_TYPE != OLD.DNS_TYPE THEN
		IF NEW.DNS_TYPE = 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
			SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
				 		NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
				 		NEW.dns_domain_id = x.dns_domain_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		-- this clause is basically the same as above except = 'CANME'
		ELSIF NEW.DNS_TYPE != 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		END IF;
	END IF;

	IF _tally > 0 THEN
		SELECT soa_name INTO _dom FROM dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id ;

		if NEW.dns_name IS NULL THEN
			RAISE EXCEPTION '% may not have CNAME and other records (%)',
				_dom, _tally
				USING ERRCODE = 'unique_violation';
		ELSE
			RAISE EXCEPTION '%.% may not have CNAME and other records (%)',
				NEW.dns_name, _dom, _tally
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_update_nontime');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_update_nontime()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_dnsdomainid	DNS_DOMAIN.DNS_DOMAIN_ID%type;
	_ipaddr			NETBLOCK.IP_ADDRESS%type;
	_mkold			boolean;
	_mknew			boolean;
	_mkdom			boolean;
	_mkip			boolean;
BEGIN
	_mkold = false;
	_mkold = false;
	_mknew = true;

	IF TG_OP = 'DELETE' THEN
		_mknew := false;
		_mkold := true;
		_mkdom := true;
		if  OLD.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		_mkold := false;
		_mkdom := true;
		if  NEW.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.DNS_DOMAIN_ID != NEW.DNS_DOMAIN_ID THEN
			_mkold := true;
			_mkip := true;
		END IF;
		_mkdom := true;

		IF OLD.dns_name IS DISTINCT FROM NEW.dns_name THEN
			_mknew := true;
			IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
				IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
					_mkip := true;
				END IF;
			END IF;
		END IF;

		IF OLD.SHOULD_GENERATE_PTR != NEW.SHOULD_GENERATE_PTR THEN
			_mkold := true;
			_mkip := true;
		END IF;

		IF (OLD.netblock_id IS DISTINCT FROM NEW.netblock_id) THEN
			_mkold := true;
			_mknew := true;
			_mkip := true;
		END IF;
	END IF;

	if _mkold THEN
		IF _mkdom THEN
			_dnsdomainid := OLD.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and OLD.netblock_id is not NULL THEN
			SELECT	ip_address
			  INTO	_ipaddr
			  FROM	netblock
			 WHERE	netblock_id  = OLD.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	if _mknew THEN
		if _mkdom THEN
			_dnsdomainid := NEW.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and NEW.netblock_id is not NULL THEN
			SELECT	ip_address
			  INTO	_ipaddr
			  FROM	netblock
			 WHERE	netblock_id  = NEW.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	IF TG_OP = 'DELETE' THEN
		return OLD;
	END IF;
	return NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'fix_person_image_oid_ownership');
CREATE OR REPLACE FUNCTION jazzhands.fix_person_image_oid_ownership()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
   b	integer;
   str	varchar;
BEGIN
	b := NEW.image_blob;
	BEGIN
		str := 'GRANT SELECT on LARGE OBJECT ' || b || ' to picture_image_ro';
		EXECUTE str;
		str :=  'GRANT UPDATE on LARGE OBJECT ' || b || ' to picture_image_rw';
		EXECUTE str;
	EXCEPTION WHEN OTHERS THEN
		RAISE NOTICE 'Unable to grant on %', b;
	END;

	BEGIN
		EXECUTE 'ALTER large object ' || b || ' owner to jazzhands';
	EXCEPTION WHEN OTHERS THEN
		RAISE NOTICE 'Unable to adjust ownership of %', b;
	END;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'net_int_physical_id_to_slot_id_enforce');
CREATE OR REPLACE FUNCTION jazzhands.net_int_physical_id_to_slot_id_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND  (NEW.slot_id IS DISTINCT FROM OLD.slot_ID AND
			NEW.physical_port_id IS DISTINCT FROM OLD.physical_port_id) THEN
		RAISE EXCEPTION 'Only slot_id should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.physical_port_id IS NOT NULL AND NEW.slot_id IS NOT NULL THEN
			RAISE EXCEPTION 'Only slot_id should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.slot_id IS DISTINCT FROM NEW.slot_id THEN
			NEW.physical_port_id = NEW.slot_id;
		ELSIF OLD.physical_port_id IS DISTINCT FROM NEW.physical_port_id THEN
			NEW.slot_id = NEW.physical_port_id;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.slot_id IS NOT NULL THEN
			NEW.physical_port_id = NEW.slot_id;
		ELSIF NEW.physical_port_id IS NOT NULL THEN
			NEW.slot_id = NEW.physical_port_id;
		END IF;
	ELSE
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'phys_conn_physical_id_to_slot_id_enforce');
CREATE OR REPLACE FUNCTION jazzhands.phys_conn_physical_id_to_slot_id_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND
		((NEW.slot1_id IS DISTINCT FROM OLD.slot1_ID AND
			NEW.physical_port1_id IS DISTINCT FROM OLD.physical_port1_id) OR
		(NEW.slot2_id IS DISTINCT FROM OLD.slot2_ID AND
			NEW.physical_port2_id IS DISTINCT FROM OLD.physical_port2_id))
	THEN
		RAISE EXCEPTION 'Only slot1_id OR slot2_id should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF (NEW.physical_port1_id IS NOT NULL AND NEW.slot1_id IS NOT NULL) OR
			(NEW.physical_port2_id IS NOT NULL AND NEW.slot2_id IS NOT NULL)
		THEN
			RAISE EXCEPTION 'Only slot1_id OR slot2_id should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.slot1_id IS DISTINCT FROM NEW.slot1_id THEN
			NEW.physical_port1_id = NEW.slot1_id;
		ELSIF OLD.physical_port1_id IS DISTINCT FROM NEW.physical_port1_id THEN
			NEW.slot1_id = NEW.physical_port1_id;
		END IF;
		IF OLD.slot2_id IS DISTINCT FROM NEW.slot2_id THEN
			NEW.physical_port2_id = NEW.slot2_id;
		ELSIF OLD.physical_port2_id IS DISTINCT FROM NEW.physical_port2_id THEN
			NEW.slot2_id = NEW.physical_port2_id;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.slot1_id IS NOT NULL THEN
			NEW.physical_port1_id = NEW.slot_id;
		ELSIF NEW.physical_port1_id IS NOT NULL THEN
			NEW.slot1_id = NEW.physical_port1_id;
		END IF;
		IF NEW.slot2_id IS NOT NULL THEN
			NEW.physical_port2_id = NEW.slot_id;
		ELSIF NEW.physical_port2_id IS NOT NULL THEN
			NEW.slot2_id = NEW.physical_port2_id;
		END IF;
	ELSE
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'property_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.property_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	pct	val_property_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	pct
	FROM	val_property_collection_type
	WHERE	property_collection_type =
		(select property_collection_type from property_collection
			where property_collection_id = NEW.property_collection_id);

	IF pct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from property_collection_property
		  where property_collection_id = NEW.property_collection_id;
		IF tally > pct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF pct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from property_collection_property
		  		inner join property_collection using (property_collection_id)
		  where
				property_name = NEW.property_name
		  and	property_type = NEW.property_type
		  and	property_collection_type = pct.property_collection_type;
		IF tally > pct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Property may not be a member of more than % collections of type %',
				pct.MAX_NUM_COLLECTIONS, pct.property_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_coll_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.service_environment_coll_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	svcenvt	val_service_env_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	svcenvt
	FROM	val_service_env_coll_type
	WHERE	service_env_collection_type =
		(select service_env_collection_type
			from service_environment_collection
			where service_env_collection_id =
				NEW.service_env_collection_id);

	IF svcenvt.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Service Environment Collections of type % may not be hierarcical',
			svcenvt.service_env_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.service_environment_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	svcenvt	val_service_env_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	svcenvt
	FROM	val_service_env_coll_type
	WHERE	service_env_collection_type =
		(select service_env_collection_type
			from service_environment_collection
			where service_env_collection_id =
				NEW.service_env_collection_id);

	IF svcenvt.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from svc_environment_coll_svc_env
		  where service_env_collection_id = NEW.service_env_collection_id;
		IF tally > svcenvt.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF svcenvt.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from svc_environment_coll_svc_env
		  		inner join service_environment_collection
					USING (service_env_collection_id)
		  where service_environment_id = NEW.service_environment_id
		  and	service_env_collection_type =
					svcenvt.service_env_collection_type;
		IF tally > svcenvt.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Service Environment may not be a member of more than % collections of type %',
				svcenvt.MAX_NUM_COLLECTIONS, svcenvt.service_env_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'upd_v_corp_family_account');
CREATE OR REPLACE FUNCTION jazzhands.upd_v_corp_family_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
	setstr		TEXT;
	_r		RECORD;
	val		TEXT;
BEGIN
	SELECT	account_realm_id
	INTO	acct_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND	property_type = 'Defaults';

	IF acct_realm_id != OLD.account_realm_id OR
			acct_realm_id != NEW.account_realm_id THEN
		RAISE EXCEPTION 'Invalid account_realm_id'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	setstr = '';
	FOR _r IN SELECT * FROM json_each_text( row_to_json(NEW) )
	LOOP
		IF _r.key NOT SIMILAR TO 'data_(ins|upd)_(user|date)' THEN
			EXECUTE 'SELECT ' || _r.key ||' FROM account
				WHERE account_id = ' || OLD.account_id
				INTO val;
			IF ( _r.value IS NULL  AND val IS NOT NULL) OR
				( _r.value IS NOT NULL AND val IS NULL) OR
				(_r.value::text NOT SIMILAR TO val::text) THEN
				-- RAISE NOTICE 'Changing %: "%" to "%"', _r.key, val, _r.value;
				IF char_length(setstr) > 0 THEN
					setstr = setstr || ',
					';
				END IF;
				IF _r.value IS NOT  NULL THEN
					setstr = setstr || _r.key || ' = ' ||
						quote_nullable(_r.value) || ' ' ;
				ELSE
					setstr = setstr || _r.key || ' = ' ||
						' NULL ' ;
				END IF;
			END IF;
		END IF;
	END LOOP;


	IF char_length(setstr) > 0 THEN
		setstr = 'UPDATE account SET ' || setstr || '
			WHERE	account_id = ' || OLD.account_id;
		-- RAISE NOTICE 'executing %', setstr;
		EXECUTE setstr;
	END IF;
	RETURN NEW;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_per_svc_env_svc_env_collection');
CREATE OR REPLACE FUNCTION jazzhands.update_per_svc_env_svc_env_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	secid		service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	IF TG_OP = 'INSERT' THEN
		insert into service_environment_collection
			(service_env_collection_name, service_env_collection_type)
		values
			(NEW.service_environment_name, 'per-environment')
		RETURNING service_env_collection_id INTO secid;
		insert into svc_environment_coll_svc_env
			(service_env_collection_id, service_environment_id)
		VALUES
			(secid, NEW.service_environment_id);
	ELSIF TG_OP = 'UPDATE'  AND OLD.service_environment_id != NEW.service_environment_id THEN
		UPDATE	service_environment_collection
		   SET	service_env_collection_name = NEW.service_environment_name
		 WHERE	service_env_collection_name != NEW.service_environment_name
		   AND	service_env_collection_type = 'per-environment'
		   AND	service_environment_id in (
			SELECT	service_environment_id
			  FROM	svc_environment_coll_svc_env
			 WHERE	service_environment_id =
				NEW.service_environment_id
			);
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_component_parent_slot_id');
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
		slot_type_prmt_comp_slot_type stpcst USING (slot_type_id) JOIN
		component_type ct ON (stpcst.component_slot_type_id = ct.slot_type_id)
	WHERE
		ct.component_type_id = NEW.component_type_id AND
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

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_component_property');
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
	v_num				bigint;
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
						component_property_name = NEW.component_property_name AND
						component_property_type = NEW.component_property_type AND
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

	IF v_comp_prop.permit_intcomp_conn_id = 'REQUIRED' THEN
		IF NEW.inter_component_connection_id IS NULL THEN
			RAISE 'inter_component_connection_id is required.'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSIF v_comp_prop.permit_intcomp_conn_id = 'PROHIBITED' THEN
		IF NEW.inter_component_connection_id IS NOT NULL THEN
			RAISE 'inter_component_connection_id is prohibited.'
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

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_device_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_device_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.device_collection_type != NEW.device_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.device_collection_type = OLD.device_collection_type
		AND	p.device_collection_id = NEW.device_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'device_collection % of type % is used by % restricted properties.',
				NEW.device_collection_id, NEW.device_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_device_component_assignment');
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
		component_id = NEW.component_id;

	IF NOT FOUND OR ctid IS DISTINCT FROM dt_ctid THEN
		RAISE EXCEPTION 'Component type of component_id % (%s) does not match component_type for device_type_id % (%)',
			NEW.component_id, ctid, dtid, dt_ctid
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_dns_domain_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_dns_domain_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.dns_domain_collection_type != NEW.dns_domain_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.dns_domain_collection_type = OLD.dns_domain_collection_type
		AND	p.dns_domain_collection_id = NEW.dns_domain_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'dns_domain_collection % of type % is used by % restricted properties.',
				NEW.dns_domain_collection_id, NEW.dns_domain_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_inter_component_connection');
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
		slot1_id,
		slot2_id
	INTO
		csid_rec
	FROM
		inter_component_connection icc
	WHERE
		icc.inter_component_connection_id != NEW.inter_component_connection_id
			AND
		(icc.slot1_id = NEW.slot1_id OR
		 icc.slot1_id = NEW.slot2_id OR
		 icc.slot2_id = NEW.slot1_id OR
		 icc.slot2_id = NEW.slot2_id )
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
		slot1.slot_id = NEW.slot1_id AND
		slot2.slot_id = NEW.slot2_id AND
		-- Remove next line if we ever decide to allow cross-function
		-- connections
		slot1.slot_function = slot2.slot_function AND
		((slot1.slot_type_id = pst.slot_type_id AND
				slot2.slot_type_id = pst.remote_slot_type_id) OR
			(slot2.slot_type_id = pst.slot_type_id AND
				slot1.slot_type_id = pst.remote_slot_type_id));

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Slot types are not allowed to be connected'
			USING ERRCODE = 'check_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_layer2_network_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_layer2_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer2_network_collection_type != NEW.layer2_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer2_network_collection_type = OLD.layer2_network_collection_type
		AND	p.layer2_network_collection_id = NEW.layer2_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer2_network_collection % of type % is used by % restricted properties.',
				NEW.layer2_network_collection_id, NEW.layer2_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_layer3_network_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_layer3_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer3_network_collection_type != NEW.layer3_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer3_network_collection_type = OLD.layer3_network_collection_type
		AND	p.layer3_network_collection_id = NEW.layer3_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer3_network_collection % of type % is used by % restricted properties.',
				NEW.layer3_network_collection_id, NEW.layer3_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.netblock_collection_type != NEW.netblock_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.netblock_collection_type = OLD.netblock_collection_type
		AND	p.netblock_collection_id = NEW.netblock_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'netblock_collection % of type % is used by % restricted properties.',
				NEW.netblock_collection_id, NEW.netblock_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_parentage');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_parentage()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	parent_nbid		netblock.netblock_id%type;
	ipaddr			inet;
	parent_ipaddr	inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		netblock.ip_address%type;
BEGIN

	RAISE DEBUG 'Validating % of netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */

	SELECT * INTO realnew FROM netblock WHERE netblock_id =
		NEW.netblock_id;
	IF NOT FOUND THEN
		/*
		 * If the netblock isn't there, it was subsequently deleted, so
		 * our parentage doesn't need to be checked
		 */
		RETURN NULL;
	END IF;


	/*
	 * If the parent changed above (or somewhere else between update and
	 * now), just bail, because another trigger will have been fired that
	 * we can do the full check with.
	 */
	IF NEW.parent_netblock_id != realnew.parent_netblock_id AND
		realnew.parent_netblock_id IS NOT NULL
	THEN
		RAISE DEBUG '... skipping for now';
		RETURN NULL;
	END IF;

	/*
	 * Validate that parent and all children are of the same netblock_type and
	 * in the same ip_universe.  We care about this even if the
	 * netblock type is not a validated type.
	 */

	RAISE DEBUG 'Verifying child ip_universe and type match';
	PERFORM netblock_id FROM netblock WHERE
		parent_netblock_id = realnew.netblock_id AND
		netblock_type != realnew.netblock_type AND
		ip_universe_id != realnew.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
	END IF;

	RAISE DEBUG '... OK';

	/*
	 * validate that this netblock is attached to its correct parent
	 */
	IF realnew.parent_netblock_id IS NULL THEN
		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		END IF;
		RAISE DEBUG 'Checking hierarchical netblock_id % with NULL parent',
			NEW.netblock_id;

		IF realnew.is_single_address = 'Y' THEN
			RAISE 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N',
				realnew.ip_address
				USING ERRCODE = 'JH105';
		END IF;

		/*
		 * Validate that a netblock has a parent, unless
		 * it is the root of a hierarchy
		 */
		parent_nbid := netblock_utils.find_best_parent_id(
			realnew.ip_address,
			NULL,
			realnew.netblock_type,
			realnew.ip_universe_id,
			realnew.is_single_address,
			realnew.netblock_id
		);

		IF parent_nbid IS NOT NULL THEN
			SELECT * INTO nbrec FROM netblock WHERE netblock_id =
				parent_nbid;

			RAISE EXCEPTION 'Netblock % (%) has NULL parent; should be % (%)',
				realnew.netblock_id, realnew.ip_address,
				parent_nbid, nbrec.ip_address USING ERRCODE = 'JH102';
		END IF;

		/*
		 * Validate that none of the other top-level netblocks should
		 * belong to this netblock
		 */
		PERFORM netblock_id FROM netblock WHERE
			parent_netblock_id IS NULL AND
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id AND
			ip_address <<= NEW.ip_address;
		IF FOUND THEN
			RAISE EXCEPTION 'Other top-level netblocks should belong to this parent'
				USING ERRCODE = 'JH108';
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF realnew.parent_netblock_id = realnew.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 'JH101';
		END IF;

		SELECT * INTO nbrec FROM netblock WHERE netblock_id =
			realnew.parent_netblock_id;

		/*
		 * This shouldn't happen, but may because of deferred constraints
		 */
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Parent netblock % does not exist',
			realnew.parent_netblock_id
			USING ERRCODE = 'foreign_key_violation';
		END IF;

		IF nbrec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'A parent netblock (% for %) may not be a single address',
			nbrec.netblock_id, realnew.ip_address
			USING ERRCODE = 'JH10A';
		END IF;

		IF nbrec.ip_universe_id != realnew.ip_universe_id OR
				nbrec.netblock_type != realnew.netblock_type THEN
			RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
		END IF;

		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		ELSE
			parent_nbid := netblock_utils.find_best_parent_id(
				realnew.ip_address,
				NULL,
				realnew.netblock_type,
				realnew.ip_universe_id,
				realnew.is_single_address,
				realnew.netblock_id
				);

			IF realnew.can_subnet = 'N' THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					is_single_address = 'N';
				IF FOUND THEN
					RAISE EXCEPTION 'A non-subnettable netblock (%) may not have child network netblocks',
					realnew.netblock_id
					USING ERRCODE = 'JH10B';
				END IF;
			END IF;
			IF realnew.is_single_address = 'Y' THEN
				SELECT * INTO nbrec FROM netblock
					WHERE netblock_id = realnew.parent_netblock_id;
				IF (nbrec.can_subnet = 'Y') THEN
					RAISE 'Parent netblock % for single-address % must have can_subnet=N',
						nbrec.netblock_id,
						realnew.ip_address
						USING ERRCODE = 'JH10D';
				END IF;
				IF (masklen(realnew.ip_address) !=
						masklen(nbrec.ip_address)) THEN
					RAISE 'Parent netblock % does not have the same netmask as single-address child % (% vs %)',
						parent_nbid, realnew.netblock_id,
						masklen(nbrec.ip_address),
						masklen(realnew.ip_address)
						USING ERRCODE = 'JH105';
				END IF;
			END IF;
			IF (parent_nbid IS NULL OR realnew.parent_netblock_id != parent_nbid) THEN
				SELECT ip_address INTO parent_ipaddr FROM netblock
				WHERE
					netblock_id = parent_nbid;
				SELECT ip_address INTO ipaddr FROM netblock WHERE
					netblock_id = realnew.parent_netblock_id;

				RAISE EXCEPTION
					'Parent netblock % (%) for netblock % (%) is not the correct parent (should be % (%))',
					realnew.parent_netblock_id, ipaddr,
					realnew.netblock_id, realnew.ip_address,
					parent_nbid, parent_ipaddr
					USING ERRCODE = 'JH102';
			END IF;
			/*
			 * Validate that all children are is_single_address='Y' or
			 * all children are is_single_address='N'
			 */
			SELECT count(*) INTO single_count FROM netblock WHERE
				is_single_address='Y' and parent_netblock_id =
				realnew.parent_netblock_id;
			SELECT count(*) INTO nonsingle_count FROM netblock WHERE
				is_single_address='N' and parent_netblock_id =
				realnew.parent_netblock_id;

			IF (single_count > 0 and nonsingle_count > 0) THEN
				SELECT * INTO nbrec FROM netblock WHERE netblock_id =
					realnew.parent_netblock_id;
				RAISE EXCEPTION 'Netblock % (%) may not have direct children for both single and multiple addresses simultaneously',
					nbrec.netblock_id, nbrec.ip_address
					USING ERRCODE = 'JH107';
			END IF;
			/*
			 *  If we're updating and we changed our ip_address (including
			 *  netmask bits), then check that our children still belong to
			 *  us
			 */
			 IF (TG_OP = 'UPDATE' AND NEW.ip_address != OLD.ip_address) THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					((is_single_address = 'Y' AND NEW.ip_address !=
						ip_address::cidr) OR
					(is_single_address = 'N' AND realnew.netblock_id !=
						netblock_utils.find_best_parent_id(netblock_id)));
				IF FOUND THEN
					RAISE EXCEPTION 'Update for netblock % (%) causes parent to have children that do not belong to it',
						realnew.netblock_id, realnew.ip_address
						USING ERRCODE = 'JH10E';
				END IF;
			END IF;

			/*
			 * Validate that none of the children of the parent netblock are
			 * children of this netblock (e.g. if inserting into the middle
			 * of the hierarchy)
			 */
			IF (realnew.is_single_address = 'N') THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.parent_netblock_id AND
					netblock_id != realnew.netblock_id AND
					ip_address <<= realnew.ip_address;
				IF FOUND THEN
					RAISE EXCEPTION 'Other netblocks have children that should belong to parent % (%)',
						realnew.parent_netblock_id, realnew.ip_address
						USING ERRCODE = 'JH108';
				END IF;
			END IF;
		END IF;
	END IF;

	RETURN NULL;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_to_range_changes');
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_to_range_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM
	FROM	network_range nr
			JOIN netblock p on p.netblock_id = nr.parent_netblock_id
			JOIN netblock start on start.netblock_id = nr.start_netblock_id
			JOIN netblock stop on stop.netblock_id = nr.stop_netblock_id
			JOIN val_network_range_type vnrt USING (network_range_type)
	WHERE	( p.netblock_id = NEW.netblock_id
				OR start.netblock_id = NEW.netblock_id
				OR stop.netblock_id = NEW.netblock_id
			) AND (
					p.can_subnet = 'Y'
				OR 	start.is_single_address = 'N'
				OR 	stop.is_single_address = 'N'
				OR NOT (
					host(start.ip_address)::inet <<= p.ip_address
					AND host(stop.ip_address)::inet <<= p.ip_address
				)
				OR ( vnrt.netblock_type IS NOT NULL
				OR NOT
					( start.netblock_type IS NOT DISTINCT FROM vnrt.netblock_type
					AND	stop.netblock_type IS NOT DISTINCT FROM vnrt.netblock_type
					)
				)
			)
	;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock changes conflict with network range requirements '
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END; $function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_network_range_ips');
CREATE OR REPLACE FUNCTION jazzhands.validate_network_range_ips()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	v_nrt	val_network_range_type%ROWTYPE;
	v_nbt	val_netblock_type.netblock_type%TYPE;
BEGIN
	SELECT	*
	INTO	v_nrt
	FROM	val_network_range_type
	WHERE	network_range_type = NEW.network_range_type;

	--
	-- check to make sure type mapping works
	--
	IF v_nrt.netblock_type IS NOT NULL THEN
		SELECT	netblock_type
		INTO	v_nbt
		FROM	netblock
		WHERE	netblock_id = NEW.start_netblock_id
		AND		netblock_type != v_nrt.netblock_type;

		IF FOUND THEN
			RAISE EXCEPTION 'For range %, start netblock_type must be %, not %',
				NEW.network_range_type, v_nrt.netblock_type, v_nbt
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

		SELECT	netblock_type
		INTO	v_nbt
		FROM	netblock
		WHERE	netblock_id = NEW.stop_netblock_id
		AND		netblock_type != v_nrt.netblock_type;

		IF FOUND THEN
			RAISE EXCEPTION 'For range %, stop netblock_type must be %, not %',
				NEW.network_range_type, v_brt.netblock_type, v_nbt
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	--
	-- Check to ensure both stop and start have is_single_address = 'Y'
	--
	PERFORM
	FROM	netblock
	WHERE	( netblock_id = NEW.start_netblock_id
				OR netblock_id = NEW.stop_netblock_id
			) AND is_single_address = 'N';

	IF FOUND THEN
		RAISE EXCEPTION 'Start and stop types must be single addresses'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	PERFORM
	FROM	netblock
	WHERE	netblock_id = NEW.parent_netblock_id
	AND can_subnet = 'Y';

	IF FOUND THEN
		RAISE EXCEPTION 'Can not set ranges on subnetable netblocks'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	PERFORM
	FROM	netblock parent
			JOIN netblock start ON start.netblock_id = NEW.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = NEW.stop_netblock_id
	WHERE
			parent.netblock_id = NEW.parent_netblock_id
			AND NOT ( host(start.ip_address)::inet <<= parent.ip_address
				AND host(stop.ip_address)::inet <<= parent.ip_address
			)
	;

	IF FOUND THEN
		RAISE EXCEPTION 'Start and stop must be within parents'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	RETURN NEW;
END; $function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_service_env_collection_type_change');
CREATE OR REPLACE FUNCTION jazzhands.validate_service_env_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.service_env_collection_type != NEW.service_env_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.service_env_collection_type = OLD.service_env_collection_type
		AND	p.service_env_collection_id = NEW.service_env_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'service_env_collection % of type % is used by % restricted properties.',
				NEW.service_env_collection_id, NEW.service_env_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'verify_physical_connection');
CREATE OR REPLACE FUNCTION jazzhands.verify_physical_connection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM 1 FROM
		physical_connection l1
		JOIN physical_connection l2 ON
			l1.slot1_id = l2.slot2_id AND
			l1.slot2_id = l2.slot1_id;
	IF FOUND THEN
		RAISE EXCEPTION 'Connection already exists in opposite direction';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'verify_physicalish_volume');
CREATE OR REPLACE FUNCTION jazzhands.verify_physicalish_volume()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.company_insert_function_nudge()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		IF current_setting('jazzhands.permit_company_insert') != 'permit' THEN
			RAISE EXCEPTION  'You may not directly insert into company.'
				USING ERRCODE = 'insufficient_privilege';
		END IF;
	EXCEPTION WHEN undefined_object THEN
			RAISE EXCEPTION  'You may not directly insert into company'
				USING ERRCODE = 'insufficient_privilege';
	END;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.del_x509_certificate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	crt	x509_signed_certificate%ROWTYPE;
BEGIN
	SELECT * INTO crt FROM x509_signed_certificate
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	DELETE FROM x509_signed_certificate
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF crt.private_key_id IS NOT NULL THEN
		DELETE FROM private_key
		WHERE private_key_id = crt.private_key_id;
	END IF;

	IF crt.private_key_id IS NOT NULL THEN
		DELETE FROM certificate_signing_request
		WHERE certificate_signing_request_id =
			crt.certificate_signing_request_id;
	END IF;
	RETURN OLD;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_record_check_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.DNS_NAME IS NOT NULL THEN
		-- rfc rfc952
		IF NEW.DNS_NAME !~ '[-a-zA-Z0-9\._]*' THEN
			RAISE EXCEPTION 'Invalid DNS NAME %',
				NEW.DNS_NAME
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.ins_x509_certificate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	key	private_key.private_key_id%TYPE;
	csr	certificate_signing_request.certificate_signing_request_id%TYPE;
	crt	x509_signed_certificate.x509_signed_certificate_id%TYPE;
BEGIN
	IF NEW.private_key IS NOT NULL THEN
		INSERT INTO private_key (
			private_key_encryption_type,
			is_active,
			subject_key_identifier,
			private_key,
			passphrase,
			encryption_key_id
		) VALUES (
			'rsa',
			NEW.is_active,
			NEW.subject_key_identifier,
			NEW.private_key,
			NEW.passphrase,
			NEW.encryption_key_id
		) RETURNING private_key_id INTO key;
		NEW.x509_cert_id := key;
	END IF;

	IF NEW.certificate_sign_req IS NOT NULL THEN
		INSERT INTO certificate_sign_req (
			friendly_name,
			subject,
			certificate_signing_request,
			private_key_id
		) VALUES (
			NEW.friendly_name,
			NEW.subject,
			NEW.certificate_sign_req,
			key
		) RETURNING certificate_signing_request_id INTO csr;
		IF NEW.x509_cert_id IS NULL THEN
			NEW.x509_cert_id := csr;
		END IF;
	END IF;

	IF NEW.public_key IS NOT NULL THEN
		INSERT INTO x509_signed_certificate (
			friendly_name,
			is_active,
			is_certificate_authority,
			signing_cert_id,
			x509_ca_cert_serial_number,
			public_key,
			subject,
			subject_key_identifier,
			valid_from,
			valid_to,
			x509_revocation_date,
			x509_revocation_reason,
			ocsp_uri,
			crl_uri,
			private_key_id,
			certificate_signing_request_id
		) VALUES (
			NEW.friendly_name,
			NEW.is_active,
			NEW.is_certificate_authority,
			NEW.signing_cert_id,
			NEW.x509_ca_cert_serial_number,
			NEW.public_key,
			NEW.subject,
			NEW.subject_key_identifier,
			NEW.valid_from,
			NEW.valid_to,
			NEW.x509_revocation_date,
			NEW.x509_revocation_reason,
			NEW.ocsp_uri,
			NEW.crl_uri,
			key,
			csr
		) RETURNING x509_signed_certificate_id INTO crt;
		NEW.x509_cert_id := crt;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.l2_net_coll_member_enforce_on_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	l2ct		val_layer2_network_coll_type%ROWTYPE;
	old_l2ct	val_layer2_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	l2ct
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type = NEW.layer2_network_collection_type;

	SELECT *
	INTO	old_l2ct
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type = OLD.layer2_network_collection_type;

	--
	-- We only need to check this if we are enforcing now where we didn't used
	-- to need to
	--
	IF l2ct.max_num_members IS NOT NULL AND
			l2ct.max_num_members IS DISTINCT FROM old_l2ct.max_num_members THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  where layer2_network_collection_id = NEW.layer2_network_collection_id;
		IF tally > l2ct.max_num_members THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF l2ct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		SELECT MAX(l2count) FROM (
			SELECT
				COUNT(*) AS l2count
			FROM
				l2_network_coll_l2_network JOIN
				layer2_network_collection USING (layer2_network_collection_id)
			WHERE
				layer2_network_collection_type = NEW.layer2_network_collection_type
			GROUP BY
				layer2_network_id
		) x INTO tally;

		IF tally > l2ct.max_num_collections THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				l2ct.MAX_NUM_COLLECTIONS, l2ct.layer2_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.l3_net_coll_member_enforce_on_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	l3ct		val_layer3_network_coll_type%ROWTYPE;
	old_l3ct	val_layer3_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	l3ct
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type = NEW.layer3_network_collection_type;

	SELECT *
	INTO	old_l3ct
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type = OLD.layer3_network_collection_type;

	--
	-- We only need to check this if we are enforcing now where we didn't used
	-- to need to
	--
	IF l3ct.max_num_members IS NOT NULL AND
			l3ct.max_num_members IS DISTINCT FROM old_l3ct.max_num_members THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  where layer3_network_collection_id = NEW.layer3_network_collection_id;
		IF tally > l3ct.max_num_members THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF l3ct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		SELECT MAX(l3count) FROM (
			SELECT
				COUNT(*) AS l3count
			FROM
				l3_network_coll_l3_network JOIN
				layer3_network_collection USING (layer3_network_collection_id)
			WHERE
				layer3_network_collection_type = NEW.layer3_network_collection_type
			GROUP BY
				layer3_network_id
		) x INTO tally;

		IF tally > l3ct.max_num_collections THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				l3ct.MAX_NUM_COLLECTIONS, l3ct.layer3_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.nb_dns_a_rec_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tal	integer;
BEGIN
	IF family(OLD.ip_address) != family(NEW.ip_address) THEN
		IF family(NEW.ip_address) == 6 THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	netblock_id = NEW.netblock_id
			AND		dns_type = 'A';

			IF _tal > 0 THEN
				RAISE EXCEPTION 'A records must be assigned to IPv4 records'
					USING ERRCODE = 'JH200';
			END IF;
		END IF;
	END IF;

	IF family(OLD.ip_address) != family(NEW.ip_address) THEN
		IF family(NEW.ip_address) == 4 THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	netblock_id = NEW.netblock_id
			AND		dns_type = 'AAAA';

			IF _tal > 0 THEN
				RAISE EXCEPTION 'AAAA records must be assigned to IPv6 records'
					USING ERRCODE = 'JH200';
			END IF;
		END IF;
	END IF;

	IF NEW.is_single_address = 'N' THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	netblock_id = NEW.netblock_id
			AND		dns_type IN ('A', 'AAAA');

		IF _tal > 0 THEN
			RAISE EXCEPTION 'Non-single addresses may not have % records', NEW.dns_type
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.pgnotify_account_collection_account_token_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
		PERFORM	*
		FROM	property_collection
				JOIN property_collection_property pcp
					USING (property_collection_id)
				JOIN property p
					USING (property_name, property_type)
		WHERE	p.account_collection_id = OLD.account_collection_id
		AND		property_collection_type = 'jazzhands-internal'
		AND		property_collection_name = 'notify-account_collection_account'
		;

		IF FOUND THEN
			PERFORM pg_notify('account_change', concat('account_id=', OLD.account_id));
		END IF;
	END IF;
	IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
		PERFORM	*
		FROM	property_collection
				JOIN property_collection_property pcp
					USING (property_collection_id)
				JOIN property p
					USING (property_name, property_type)
		WHERE	p.account_collection_id = NEW.account_collection_id
		AND		property_collection_type = 'jazzhands-internal'
		AND		property_collection_name = 'notify-account_collection_account'
		;

		IF FOUND THEN
			PERFORM pg_notify('account_change', concat('account_id=', NEW.account_id));
		END IF;
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.pgnotify_account_password_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM pg_notify ('account_password_change', 'account_id=' || NEW.account_id);
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.pgnotify_account_token_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM pg_notify ('account_id', 'account_id=' || NEW.account_id);
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.pgnotify_token_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	PERFORM pg_notify ('token_change', 'token_id=' || NEW.token_id);
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.pvtkey_ski_signed_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	ski	TEXT;
BEGIN
	SELECT	subject_key_identifier
	INTO	ski
	FROM	x509_signed_certificate x
	WHERE	x.private_key_id = NEW.private_key_id;

	IF FOUND AND ski != NEW.subject_key_identifier THEN
		RAISE EXCEPTION 'subject key identifier must match private key in x509_signing_certificate' USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.unrequire_password_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	DELETE FROM account_collection_account
	WHERE (account_collection_id, account_id)
	IN (
		SELECT	a.account_collection_id, a.account_id
		FROM	v_acct_coll_acct_expanded a
				JOIN account_collection ac USING (account_collection_id)
				JOIN property p USING (account_collection_id)
		WHERE	p.property_type = 'UserMgmt'
		AND		p.property_name = 'NeedsPasswdChange'
		AND	 	a.account_id = NEW.account_id
	);
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.upd_x509_certificate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	upq	TEXT[];
	crt	x509_signed_certificate%ROWTYPE;
	key private_key.private_key_id%TYPE;
BEGIN
	SELECT * INTO crt FROM x509_signed_certificate
	WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF OLD.x509_cert_id != NEW.x509_cert_id THEN
		RAISE EXCEPTION 'Can not change x509_cert_id' USING ERRCODE = 'invalid_parameter_value';
	END IF;

	key := crt.private_key_id;

	IF crt.private_key_ID IS NULL AND NEW.private_key IS NOT NULL THEN
		WITH ins AS (
			INSERT INTO private_key (
				private_key_encryption_type,
				is_active,
				subject_key_identifier,
				private_key,
				passphrase,
				encryption_key_id
			) VALUES (
				'rsa',
				NEW.is_active,
				NEW.subject_key_identifier,
				NEW.private_key,
				NEW.passphrase,
				NEW.encryption_key_id
			) RETURNING *
		), upd AS (
			UPDATE x509_signed_certificate
			SET private_key_id = ins.private_key_id
			WHERE x509_signed_certificate_id = OLD.x509_cert_id
			RETURNING *
		)  SELECT private_key_id INTO key FROM upd;
	ELSIF crt.private_key_id IS NOT NULL AND NEW.private_key IS NULL THEN
		UPDATE x509_signed_certificate
			SET private_key_id = NULL
			WHERE x509_signed_certificate_id = OLD.x509_cert_id;
		BEGIN
			DELETE FROM private_key where private_key_id = crt.private_key_id;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	ELSE
		IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
			upq := array_append(upq,
				'is_active = ' || quote_literal(NEW.is_active)
			);
		END IF;

		IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
			upq := array_append(upq,
				'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
			);
		END IF;

		IF OLD.private_key IS DISTINCT FROM NEW.private_key THEN
			upq := array_append(upq,
				'private_key = ' || quote_nullable(NEW.private_key)
			);
		END IF;

		IF OLD.passphrase IS DISTINCT FROM NEW.passphrase THEN
			upq := array_append(upq,
				'passphrase = ' || quote_nullable(NEW.passphrase)
			);
		END IF;

		IF OLD.encryption_key_id IS DISTINCT FROM NEW.encryption_key_id THEN
			upq := array_append(upq,
				'encryption_key_id = ' || quote_nullable(NEW.encryption_key_id)
			);
		END IF;

		IF array_length(upq, 1) > 0 THEN
			EXECUTE 'UPDATE private_key SET '
				|| array_to_string(upq, ', ')
				|| ' WHERE private_key_id = '
				|| crt.private_key_id;
		END IF;
	END IF;

	upq := NULL;
	IF crt.certificate_signing_request_id IS NULL AND NEW.certificate_sign_req IS NOT NULL THEN
		WITH ins AS (
			INSERT INTO certificate_sign_req (
				friendly_name,
				subject,
				certificate_signing_request,
				private_key_id
			) VALUES (
				NEW.friendly_name,
				NEW.subject,
				NEW.certificate_sign_req,
				key
			) RETURNING *
		) UPDATE x509_signed_certificate
		SET certificate_signing_request_id = ins.certificate_signing_request_id
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;
	ELSIF crt.certificate_signing_request_id IS NOT NULL AND
				NEW.certificate_sign_req IS NULL THEN
		-- if its removed, we still keep the csr/key link
		WITH del AS (
			UPDATE x509_signed_certificate
			SET certificate_signing_request = NULL
			WHERE x509_signed_certificate_id = OLD.x509_cert_id
			RETURNING *
		) DELETE FROM certificate_signing_request
		WHERE certificate_signing_request_id =
			crt.certificate_signing_request_id;
	ELSE
		IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
			upq := array_append(upq,
				'friendly_name = ' || quote_literal(NEW.friendly_name)
			);
		END IF;

		IF OLD.subject IS DISTINCT FROM NEW.subject THEN
			upq := array_append(upq,
				'subject = ' || quote_literal(NEW.subject)
			);
		END IF;

		IF OLD.certificate_sign_req IS DISTINCT FROM
				NEW.certificate_sign_req THEN
			upq := array_append(upq,
				'certificate_signing_request = ' ||
					quote_literal(NEW.certificate_sign_req)
			);
		END IF;

		IF array_length(upq, 1) > 0 THEN
			EXECUTE 'UPDATE certificate_signing_request SET '
				|| array_to_string(upq, ', ')
				|| ' WHERE x509_signed_certificate_id = '
				|| crt.x509_signed_certificate_id;
		END IF;
	END IF;

	upq := NULL;
	IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
		upq := array_append(upq,
			'is_active = ' || quote_literal(NEW.is_active)
		);
	END IF;
	IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
		upq := array_append(upq,
			'friendly_name = ' || quote_literal(NEW.friendly_name)
		);
	END IF;
	IF OLD.subject IS DISTINCT FROM NEW.subject THEN
		upq := array_append(upq,
			'subject = ' || quote_literal(NEW.subject)
		);
	END IF;
	IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
		upq := array_append(upq,
			'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
		);
	END IF;
	IF OLD.is_certificate_authority IS DISTINCT FROM NEW.is_certificate_authority THEN
		upq := array_append(upq,
			'is_certificate_authority = ' || quote_nullable(NEW.is_certificate_authority)
		);
	END IF;
	IF OLD.signing_cert_id IS DISTINCT FROM NEW.signing_cert_id THEN
		upq := array_append(upq,
			'signing_cert_id = ' || quote_nullable(NEW.signing_cert_id)
		);
	END IF;
	IF OLD.x509_ca_cert_serial_number IS DISTINCT FROM NEW.x509_ca_cert_serial_number THEN
		upq := array_append(upq,
			'x509_ca_cert_serial_number = ' || quote_nullable(NEW.x509_ca_cert_serial_number)
		);
	END IF;
	IF OLD.public_key IS DISTINCT FROM NEW.public_key THEN
		upq := array_append(upq,
			'public_key = ' || quote_nullable(NEW.public_key)
		);
	END IF;
	IF OLD.valid_from IS DISTINCT FROM NEW.valid_from THEN
		upq := array_append(upq,
			'valid_from = ' || quote_nullable(NEW.valid_from)
		);
	END IF;
	IF OLD.valid_to IS DISTINCT FROM NEW.valid_to THEN
		upq := array_append(upq,
			'valid_to = ' || quote_nullable(NEW.valid_to)
		);
	END IF;
	IF OLD.x509_revocation_date IS DISTINCT FROM NEW.x509_revocation_date THEN
		upq := array_append(upq,
			'x509_revocation_date = ' || quote_nullable(NEW.x509_revocation_date)
		);
	END IF;
	IF OLD.x509_revocation_reason IS DISTINCT FROM NEW.x509_revocation_reason THEN
		upq := array_append(upq,
			'x509_revocation_reason = ' || quote_nullable(NEW.x509_revocation_reason)
		);
	END IF;
	IF OLD.ocsp_uri IS DISTINCT FROM NEW.ocsp_uri THEN
		upq := array_append(upq,
			'ocsp_uri = ' || quote_nullable(NEW.ocsp_uri)
		);
	END IF;
	IF OLD.crl_uri IS DISTINCT FROM NEW.crl_uri THEN
		upq := array_append(upq,
			'crl_uri = ' || quote_nullable(NEW.crl_uri)
		);
	END IF;

	IF array_length(upq, 1) > 0 THEN
		EXECUTE 'UPDATE x509_signed_certificate SET '
			|| array_to_string(upq, ', ')
			|| ' WHERE x509_signed_certificate_id = '
			|| NEW.x509_cert_id;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.x509_signed_ski_pvtkey_validate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	ski	TEXT;
BEGIN
	--
	-- XXX needs to be tweaked to ensure that both are set or not set.
	--
	IF NEW.private_key_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	subject_key_identifier
	INTO	ski
	FROM	private_key p
	WHERE	p.private_key_id = NEW.private_key_id;

	IF FOUND AND ski != NEW.subject_key_identifier THEN
		RAISE EXCEPTION 'subject key identifier must match private key in private_key' USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$function$
;

--
-- Process drops in net_manip
--
--
-- Process drops in network_strings
--
--
-- Process drops in time_util
--
--
-- Process drops in dns_utils
--
--
-- Process drops in person_manip
--
DROP FUNCTION IF EXISTS person_manip.add_user ( company_id integer, person_company_relation character varying, login character varying, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id text, hire_date date, termination_date date, job_title character varying, department_name character varying, description character varying, unix_uid character varying, INOUT person_id integer, OUT dept_account_collection_id integer, OUT account_id integer );
-- New function
CREATE OR REPLACE FUNCTION person_manip.add_user(company_id integer, person_company_relation character varying, login character varying DEFAULT NULL::character varying, first_name character varying DEFAULT NULL::character varying, middle_name character varying DEFAULT NULL::character varying, last_name character varying DEFAULT NULL::character varying, name_suffix character varying DEFAULT NULL::character varying, gender character varying DEFAULT NULL::character varying, preferred_last_name character varying DEFAULT NULL::character varying, preferred_first_name character varying DEFAULT NULL::character varying, birth_date date DEFAULT NULL::date, external_hr_id character varying DEFAULT NULL::character varying, person_company_status character varying DEFAULT 'enabled'::character varying, is_management character varying DEFAULT 'N'::character varying, is_manager character varying DEFAULT NULL::character varying, is_exempt character varying DEFAULT 'Y'::character varying, is_full_time character varying DEFAULT 'Y'::character varying, employee_id text DEFAULT NULL::text, hire_date date DEFAULT NULL::date, termination_date date DEFAULT NULL::date, position_title character varying DEFAULT NULL::character varying, job_title character varying DEFAULT NULL::character varying, department_name character varying DEFAULT NULL::character varying, manager_person_id integer DEFAULT NULL::integer, site_code character varying DEFAULT NULL::character varying, physical_address_id integer DEFAULT NULL::integer, person_location_type character varying DEFAULT 'office'::character varying, description character varying DEFAULT NULL::character varying, unix_uid character varying DEFAULT NULL::character varying, INOUT person_id integer DEFAULT NULL::integer, OUT dept_account_collection_id integer, OUT account_id integer)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    _account_realm_id INTEGER;
    _account_type VARCHAR;
    _uid INTEGER;
    _uxaccountid INTEGER;
    _companyid INTEGER;
    _personid INTEGER;
    _accountid INTEGER;
BEGIN
	IF is_manager IS NOT NULL THEN
		is_management := is_manager;
	END IF;

	IF job_title IS NOT NULL THEN
		position_title := job_title;
	END IF;

    IF company_id is NULL THEN
        RAISE EXCEPTION 'Must specify company id';
    END IF;
    _companyid := company_id;

    SELECT arc.account_realm_id 
      INTO _account_realm_id 
      FROM account_realm_company arc
     WHERE arc.company_id = _companyid;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cannot find account_realm_id with company id %', company_id;
    END IF;

    IF login is NULL THEN
        IF first_name IS NULL or last_name IS NULL THEN 
            RAISE EXCEPTION 'Must specify login name or first name+last name';
        ELSE 
            login := person_manip.pick_login(
                in_account_realm_id := _account_realm_id,
                in_first_name := coalesce(preferred_first_name, first_name),
                in_middle_name := middle_name,
                in_last_name := coalesce(preferred_last_name, last_name)
            );
        END IF;
    END IF;

    IF person_company_relation = 'pseudouser' THEN
        person_id := 0;
        _account_type := 'pseudouser';
    ELSE
        _account_type := 'person';
        IF person_id IS NULL THEN
            INSERT INTO person (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
                VALUES (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
            RETURNING person.person_id into _personid;
            person_id = _personid;
        ELSE
            INSERT INTO person (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
                VALUES (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date);
        END IF;
        INSERT INTO person_company
            (person_id, company_id, external_hr_id, person_company_status, is_management, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, position_title, manager_person_id)
            VALUES
            (person_id, company_id, external_hr_id, person_company_status, is_management, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, position_title, manager_person_id);
        INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( person_id, company_id, _account_realm_id);
    END IF;

    INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type)
        VALUES (login, person_id, company_id, _account_realm_id, person_company_status, description, 'primary', _account_type)
    RETURNING account.account_id INTO account_id;

    IF department_name IS NOT NULL THEN
        dept_account_collection_id = person_manip.get_account_collection_id(department_name, 'department');
        INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( dept_account_collection_id, account_id);
    END IF;

    IF site_code IS NOT NULL AND physical_address_id IS NOT NULL THEN
        RAISE EXCEPTION 'You must provide either site_code or physical_address_id NOT both';
    END IF;

    IF site_code IS NULL AND physical_address_id IS NOT NULL THEN
        site_code = person_manip.get_site_code_from_physical_address_id(physical_address_id);
    END IF;

    IF physical_address_id IS NULL AND site_code IS NOT NULL THEN
        physical_address_id = person_manip.get_physical_address_from_site_code(site_code);
    END IF;

    IF physical_address_id IS NOT NULL AND site_code IS NOT NULL THEN
        INSERT INTO person_location 
            (person_id, person_location_type, site_code, physical_address_id)
        VALUES
            (person_id, person_location_type, site_code, physical_address_id);
    END IF;


    IF unix_uid IS NOT NULL THEN
        _accountid = account_id;
        SELECT  aui.account_id
          INTO  _uxaccountid
          FROM  account_unix_info aui
        WHERE  aui.account_id = _accountid;

        --
        -- This is creatd by trigger for non-pseudousers, which will
        -- eventually change, so this is here once it goes away.
        --
        IF _uxaccountid IS NULL THEN
            IF unix_uid = 'auto' THEN
                _uid :=  person_manip.get_unix_uid(_account_type);
            ELSE
                _uid := unix_uid::int;
            END IF;

            PERFORM person_manip.setup_unix_account(
                in_account_id := account_id,
                in_account_type := _account_type,
                in_uid := _uid
            );
        END IF;
    END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION person_manip.get_physical_address_from_site_code(_site_code character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_physical_address_id INTEGER;
BEGIN
	SELECT physical_address_id INTO _physical_address_id
		FROM physical_address
		INNER JOIN site USING(physical_address_id)
		WHERE site_code = _site_code;
	RETURN _physical_address_id;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION person_manip.get_site_code_from_physical_address_id(_physical_address_id integer)
 RETURNS character varying
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_site_code VARCHAR;
BEGIN
	SELECT site_code INTO _site_code
		FROM physical_address
		INNER JOIN site USING(physical_address_id)
		WHERE physical_address_id = _physical_address_id;
	RETURN _site_code;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION person_manip.set_location(person_id integer, new_site_code character varying DEFAULT NULL::character varying, new_physical_address_id integer DEFAULT NULL::integer, person_location_type character varying DEFAULT 'office'::character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_person_id INTEGER;
	_person_location_type VARCHAR;
	_existing_person_location_id INTEGER;
BEGIN
	_person_id = person_id;
	_person_location_type = person_location_type;

	IF ( new_site_code IS NULL AND new_physical_address_id IS NULL )
		OR ( new_site_code IS NOT NULL AND new_physical_address_id IS NOT NULL ) THEN
			RAISE EXCEPTION 'Must specify either new_site_code or new_physical_address';
	END IF;

	IF new_site_code IS NOT NULL AND new_physical_address_id IS NULL THEN
		new_physical_address_id = person_manip.get_physical_address_from_site_code(new_site_code);
	END IF;

	IF new_physical_address_id IS NOT NULL AND new_site_code IS NULL THEN
		new_site_code = person_manip.get_site_code_from_physical_address_id(new_physical_address_id);
	END IF;

	SELECT person_location_id INTO _existing_person_location_id
	FROM person_location pl
	WHERE pl.person_id = _person_id AND pl.person_location_type = _person_location_type;

	IF _existing_person_location_id IS NULL THEN
		INSERT INTO person_location
			(person_id, person_location_type, site_code, physical_address_id)
		VALUES
			(_person_id, _person_location_type, new_site_code, new_physical_address_id);
	ELSE
		UPDATE person_location
		SET (site_code, physical_address_id, building, floor, section, seat_number)
		= (new_site_code, new_physical_address_id, NULL, NULL, NULL, NULL)
		WHERE person_location_id = _existing_person_location_id;
	END IF;
END;
$function$
;

--
-- Process drops in auto_ac_manip
--
--
-- Process drops in company_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('company_manip', 'add_company');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS company_manip.add_company ( _company_name text, _company_types text[], _parent_company_id integer, _account_realm_id integer, _company_short_name text, _description text );
CREATE OR REPLACE FUNCTION company_manip.add_company(_company_name text, _company_types text[] DEFAULT NULL::text[], _parent_company_id integer DEFAULT NULL::integer, _account_realm_id integer DEFAULT NULL::integer, _company_short_name text DEFAULT NULL::text, _description text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_cmpid	company.company_id%type;
	_short	text;
	_isfam	char(1);
	_perm	text;
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
	ELSE
		_short := _company_short_name;
	END IF;

	BEGIN
		_perm := current_setting('jazzhands.permit_company_insert');
	EXCEPTION WHEN undefined_object THEN
		_perm := '';
	END;

	SET jazzhands.permit_company_insert = 'permit';

	INSERT INTO company (
		company_name, company_short_name,
		parent_company_id, description
	) VALUES (
		_company_name, _short,
		_parent_company_id, _description
	) RETURNING company_id INTO _cmpid;

	SET jazzhands.permit_company_insert = _perm;

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
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('company_manip', 'add_company_types');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS company_manip.add_company_types ( _company_id integer, _account_realm_id integer, _company_types text[] );
CREATE OR REPLACE FUNCTION company_manip.add_company_types(_company_id integer, _account_realm_id integer DEFAULT NULL::integer, _company_types text[] DEFAULT NULL::text[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	x		text;
	count	integer;
BEGIN
	count := 0;
	FOREACH x IN ARRAY _company_types
	LOOP
		INSERT INTO company_type (company_id, company_type)
			VALUES (_company_id, x);
		IF _account_realm_id IS NOT NULL THEN
			PERFORM company_manip.add_auto_collections(_company_id, _account_realm_id, x);
		END IF;
		count := count + 1;
	END LOOP;
	return count;
END;
$function$
;

--
-- Process drops in token_utils
--
--
-- Process drops in port_support
--
--
-- Process drops in port_utils
--
--
-- Process drops in device_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_device');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_device ( in_device_id integer, retire_modules boolean );
CREATE OR REPLACE FUNCTION device_utils.retire_device(in_device_id integer, retire_modules boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally		INTEGER;
	_r			RECORD;
	_d			DEVICE%ROWTYPE;
	_mgrid		DEVICE.DEVICE_ID%TYPE;
	_purgedev	boolean;
BEGIN
	_purgedev := false;

	BEGIN
		PERFORM local_hooks.device_retire_early(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT * INTO _d FROM device WHERE device_id = in_Device_id;
	delete from dns_record where netblock_id in (
		select netblock_id 
		from network_interface where device_id = in_Device_id
	);

	delete from network_interface_purpose where device_id = in_Device_id;

	DELETE FROM network_interface_netblock
	WHERE network_interface_id IN (
			SELECT network_interface_id
		 	FROM network_interface
			WHERE device_id = in_Device_id
	);

	DELETE FROM network_interface WHERE device_id = in_Device_id;

	PERFORM device_utils.purge_physical_ports( in_Device_id);
--	PERFORM device_utils.purge_power_ports( in_Device_id);

	delete from property where device_collection_id in (
		SELECT	dc.device_collection_id 
		  FROM	device_collection dc
				INNER JOIN device_collection_device dcd
		 			USING (device_collection_id)
		WHERE	dc.device_collection_type = 'per-device'
		  AND	dcd.device_id = in_Device_id
	);

	delete from device_collection_device where device_id = in_Device_id;
	delete from snmp_commstr where device_id = in_Device_id;

		
	IF _d.rack_location_id IS NOT NULL  THEN
		UPDATE device SET rack_location_id = NULL 
		WHERE device_id = in_Device_id;

		-- This should not be permitted based on constraints, but in case
		-- that constraint had to be disabled...
		SELECT	count(*)
		  INTO	tally
		  FROM	device
		 WHERE	rack_location_id = _d.RACK_LOCATION_ID;

		IF tally = 0 THEN
			DELETE FROM rack_location 
			WHERE rack_location_id = _d.RACK_LOCATION_ID;
		END IF;
	END IF;

	IF _d.chassis_location_id IS NOT NULL THEN
		RAISE EXCEPTION 'Retiring modules is not supported yet.';
	END IF;

	SELECT	manager_device_id
	INTO	_mgrid
	 FROM	device_management_controller
	WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
	LIMIT 1;

	IF _mgrid IS NOT NULL THEN
		DELETE FROM device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
			AND manager_device_id = _mgrid;

		PERFORM device_utils.retire_device( manager_device_id)
		  FROM	device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc';
	END IF;

	BEGIN
		PERFORM local_hooks.device_retire_late(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT count(*)
	INTO tally
	FROM device_note
	WHERE device_id = in_Device_id;

	--
	-- If there is no notes or serial number its save to remove
	-- 
	IF tally = 0 AND _d.ASSET_ID is NULL THEN
		_purgedev := true;
	END IF;

	IF _purgedev THEN
		--
		-- If there is an fk violation, we just preserve the record but
		-- delete all the identifying characteristics
		--
		BEGIN
			DELETE FROM device where device_id = in_Device_Id;
			return false;
		EXCEPTION WHEN foreign_key_violation THEN
			PERFORM 1;
		END;
	END IF;

	UPDATE device SET 
		device_name =NULL,
		service_environment_id = (
			select service_environment_id from service_environment
			where service_environment_name = 'unallocated'),
		device_status = 'removed',
		voe_symbolic_track_id = NULL,
		is_monitored = 'N',
		should_fetch_config = 'N',
		description = NULL
	WHERE device_id = in_Device_id;

	return true;
END;
$function$
;

--
-- Process drops in netblock_utils
--
--
-- Process drops in netblock_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF netblock
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	netblock_rec	RECORD;
BEGIN
	RETURN QUERY 
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
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS SETOF netblock
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
			RETURN;
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
 		RETURN;
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
			RETURN;
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

		RETURN NEXT netblock_rec;
		RETURN;
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
			RETURN;
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

		RETURN NEXT netblock_rec;
		RETURN;
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
			RETURN;
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

		RETURN NEXT netblock_rec;
		RETURN;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'create_network_range');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.create_network_range ( start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer, description character varying, allow_assigned boolean );
CREATE OR REPLACE FUNCTION netblock_manip.create_network_range(start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer DEFAULT NULL::integer, description character varying DEFAULT NULL::character varying, allow_assigned boolean DEFAULT false)
 RETURNS network_range
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	par_netblock	RECORD;
	start_netblock	RECORD;
	stop_netblock	RECORD;
	netrange		RECORD;
	nrtype			ALIAS FOR network_range_type;
	pnbid			ALIAS FOR parent_netblock_id;
BEGIN
	--
	-- If the network range already exists, then just return it
	--
	SELECT 
		nr.* INTO netrange
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON (nr.start_netblock_id = 
			startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND
		host(startnb.ip_address) = host(start_ip_address) AND
		host(stopnb.ip_address) = host(stop_ip_address) AND
		CASE WHEN pnbid IS NOT NULL THEN 
			(pnbid = nr.parent_netblock_id)
		ELSE
			true
		END;

	IF FOUND THEN
		RETURN netrange;
	END IF;

	--
	-- If any other network ranges exist that overlap this, then error
	--
	PERFORM 
		*
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON 
			(nr.start_netblock_id = startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND ((
			host(startnb.ip_address)::inet <= host(start_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(start_ip_address)::inet
		) OR (
			host(startnb.ip_address)::inet <= host(stop_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(stop_ip_address)::inet
		));

	IF FOUND THEN
		RAISE 'create_network_range: a network_range of type % already exists that has addresses between % and %',
			nrtype, start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	IF parent_netblock_id IS NOT NULL THEN
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE 
			netblock_id = pnbid;
		IF NOT FOUND THEN
			RAISE 'create_network_range: parent_netblock_id % does not exist',
				parent_netblock_id USING ERRCODE = 'foreign_key_violation';
		END IF;
	ELSE
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE netblock_id = (
			SELECT 
				*
			FROM
				netblock_utils.find_best_parent_id(
					in_ipaddress := start_ip_address,
					in_is_single_address := 'Y'
				)
		);

		IF NOT FOUND THEN
			RAISE 'create_network_range: valid parent netblock for start_ip_address % does not exist',
				start_ip_address USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	IF par_netblock.can_subnet != 'N' OR 
			par_netblock.is_single_address != 'N' THEN
		RAISE 'create_network_range: parent netblock % must not be subnettable or a single address',
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not contained by parent netblock % (%)',
			start_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (stop_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: stop_ip_address % is not contained by parent netblock % (%)',
			stop_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <= stop_ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not lower than stop_ip_address %',
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- Validate that there are not currently any addresses assigned in the
	-- range, unless allow_assigned is set
	--
	IF NOT allow_assigned THEN
		PERFORM 
			*
		FROM
			jazzhands.netblock n
		WHERE
			n.parent_netblock_id = par_netblock.netblock_id AND
			host(n.ip_address)::inet > host(start_ip_address)::inet AND
			host(n.ip_address)::inet < host(stop_ip_address)::inet;

		IF FOUND THEN
			RAISE 'create_network_range: netblocks are already present for parent netblock % betweeen % and %',
			par_netblock.netblock_id,
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	--
	-- Ok, well, we should be able to insert things now
	--

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		start_netblock
	WHERE
		host(n.ip_address)::inet = start_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(start_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO start_netblock;
	END IF;

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		stop_netblock
	WHERE
		host(n.ip_address)::inet = stop_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(stop_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO stop_netblock;
	END IF;

	INSERT INTO network_range (
		network_range_type,
		description,
		parent_netblock_id,
		start_netblock_id,
		stop_netblock_id
	) VALUES (
		nrtype,
		description,
		par_netblock.netblock_id,
		start_netblock.netblock_id,
		stop_netblock.netblock_id
	) RETURNING * INTO netrange;

	RETURN netrange;

	RETURN NULL;
END;
$function$
;

--
-- Process drops in physical_address_utils
--
--
-- Process drops in component_utils
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
				SELECT company_manip.add_company(
					_company_name := pci_vendor_name,
					_company_types := ARRAY['hardware provider'],
					 _description := 'PCI vendor auto-insert'
				) INTO comp_id;
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
				SELECT company_manip.add_company(
					_company_name := pci_sub_vendor_name,
					_company_types := ARRAY['hardware provider'],
					 _description := 'PCI vendor auto-insert'
				) INTO comp_id;
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

-- New function
CREATE OR REPLACE FUNCTION component_utils.fetch_component(component_type_id integer, serial_number text, no_create boolean DEFAULT false, ownership_status text DEFAULT 'unknown'::text)
 RETURNS component
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	ctid		ALIAS FOR component_type_id;
	sn			ALIAS FOR serial_number;
	os			ALIAS FOR ownership_status;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF sn IS NOT NULL THEN
		SELECT 
			comp.* INTO c
		FROM
			component comp JOIN
			asset a USING (component_id)
		WHERE
			comp.component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			return c;
		END IF;
	END IF;

	IF no_create THEN
		RETURN NULL;
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
			os
		);
	END IF;

	RETURN c;
END;
$function$
;

--
-- Process drops in snapshot_manip
--
--
-- Process drops in lv_manip
--
--
-- Process drops in approval_utils
--
--
-- Process drops in account_collection_manip
--
--
-- Process drops in script_hooks
--
--
-- Process drops in schema_support
--
-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'begin_maintenance');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.begin_maintenance ( shouldbesuper boolean );
CREATE OR REPLACE FUNCTION schema_support.begin_maintenance(shouldbesuper boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	issuper	boolean;
	_tally	integer;
BEGIN
	IF shouldbesuper THEN
		SELECT usesuper INTO issuper FROM pg_user where usename = current_user;
		IF issuper IS false THEN
			RAISE EXCEPTION 'User must be a super user.';
		END IF;
	END IF;
	-- Not sure how reliable this is.
	-- http://www.postgresql.org/docs/9.3/static/monitoring-stats.html
	SELECT count(*)
	  INTO _tally
	  FROM	pg_stat_activity
	 WHERE	pid = pg_backend_pid()
	   AND	query_start = xact_start;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Must run maintenance in a transaction.';
	END IF;
	RETURN true;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_table');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_table ( aud_schema character varying, tbl_schema character varying, table_name character varying, first_time boolean );
CREATE OR REPLACE FUNCTION schema_support.build_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying, first_time boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	keys	RECORD;
	count	INTEGER;
	name	TEXT;
BEGIN
	BEGIN
	EXECUTE 'CREATE SEQUENCE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name || '_seq');
	EXCEPTION WHEN duplicate_table THEN
		NULL;
	END;

	EXECUTE 'CREATE TABLE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' AS '
		|| 'SELECT *, NULL::char(3) as "aud#action", now() as "aud#timestamp", '
		|| 'clock_timestamp() as "aud#realtime", '
		|| 'txid_current() as "aud#txid", '
		|| 'NULL::varchar(255) AS "aud#user", NULL::integer AS "aud#seq" '
		|| 'FROM ' || quote_ident(tbl_schema) || '.' || quote_ident(table_name)
		|| ' LIMIT 0';

	EXECUTE 'ALTER TABLE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name)
		|| $$ ALTER COLUMN "aud#seq" SET NOT NULL, $$
		|| $$ ALTER COLUMN "aud#seq" SET DEFAULT nextval('$$
		|| quote_ident(aud_schema) || '.' || quote_ident(table_name || '_seq')
		|| $$')$$;

	EXECUTE 'ALTER SEQUENCE ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name || '_seq') || ' OWNED BY '
		|| quote_ident(aud_schema) || '.' || quote_ident(table_name)
		|| '.' || quote_ident('aud#seq');


	EXECUTE 'CREATE INDEX '
		|| quote_ident( table_name || '_aud#timestamp_idx')
		|| ' ON ' || quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || '("aud#timestamp")';

	EXECUTE 'ALTER TABLE ' || quote_ident(aud_schema) || '.'
		|| quote_ident( table_name )
		|| ' ADD PRIMARY KEY ("aud#seq")';

	COUNT := 0;
	-- one day, I will want to construct the list of columns by hand rather
	-- than use pg_get_constraintdef.  watch me...
	FOR keys IN
		SELECT con.conname, c2.relname as index_name,
			pg_catalog.pg_get_constraintdef(con.oid, true) as condef,
				regexp_replace(
			pg_catalog.pg_get_constraintdef(con.oid, true),
					'^.*(\([^\)]+\)).*$', '\1') as cols,
			con.condeferrable,
			con.condeferred
		FROM pg_catalog.pg_class c
			INNER JOIN pg_namespace n
				ON relnamespace = n.oid
			INNER JOIN pg_catalog.pg_index i
				ON c.oid = i.indrelid
			INNER JOIN pg_catalog.pg_class c2
				ON i.indexrelid = c2.oid
			INNER JOIN pg_catalog.pg_constraint con ON
				(con.conrelid = i.indrelid
				AND con.conindid = i.indexrelid )
		WHERE c.relname =  table_name
		AND	 n.nspname = tbl_schema
		AND con.contype in ('p', 'u')
	LOOP
		name := 'aud_' || quote_ident( table_name || '_' || keys.conname);
		IF char_length(name) > 63 THEN
			name := 'aud_' || count || quote_ident( table_name || '_' || keys.conname);
			COUNT := COUNT + 1;
		END IF;
		EXECUTE 'CREATE INDEX ' || name
			|| ' ON ' || quote_ident(aud_schema) || '.'
			|| quote_ident(table_name) || keys.cols;
	END LOOP;

	IF first_time THEN
		PERFORM schema_support.rebuild_audit_trigger
			( aud_schema, tbl_schema, table_name );
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'build_audit_tables');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.build_audit_tables ( aud_schema character varying, tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.build_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT table_name FROM information_schema.tables
	WHERE table_type = 'BASE TABLE' AND table_schema = tbl_schema
	AND NOT (
	    table_name IN (
		SELECT table_name FROM information_schema.tables
		WHERE table_schema = aud_schema
	    )
	)
	ORDER BY table_name
    LOOP
	PERFORM schema_support.build_audit_table
	    ( aud_schema, tbl_schema, table_list.table_name );
    END LOOP;

    PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'get_common_columns');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.get_common_columns ( _schema text, _table1 text, _table2 text );
CREATE OR REPLACE FUNCTION schema_support.get_common_columns(_schema text, _table1 text, _table2 text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_q			text;
    cols        text[];
BEGIN
    _q := 'WITH cols AS (
        SELECT  n.nspname as schema, c.relname as relation, a.attname as colname,
		a.attnum
            FROM    pg_catalog.pg_attribute a
                INNER JOIN pg_catalog.pg_class c
                    on a.attrelid = c.oid
                INNER JOIN pg_catalog.pg_namespace n
                    on c.relnamespace = n.oid
            WHERE   a.attnum > 0
            AND   NOT a.attisdropped
            ORDER BY a.attnum
       ) SELECT array_agg(colname ORDER BY o.attnum) as cols
        FROM cols  o
            INNER JOIN cols n USING (schema, colname)
		WHERE
			o.schema = $1
		and o.relation = $2
		and n.relation =$3
	';
	EXECUTE _q INTO cols USING _schema, _table1, _table2;
	RETURN cols;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_audit_trigger');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_trigger ( aud_schema character varying, tbl_schema character varying, table_name character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_trigger(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    EXECUTE 'CREATE OR REPLACE FUNCTION ' || quote_ident(tbl_schema)
	|| '.' || quote_ident('perform_audit_' || table_name)
	|| $ZZ$() RETURNS TRIGGER AS $TQ$
	    DECLARE
		appuser VARCHAR;
	    BEGIN
		BEGIN
		    appuser := session_user
			|| '/' || current_setting('jazzhands.appuser');
		EXCEPTION WHEN OTHERS THEN
		    appuser := session_user;
		END;

    		appuser = substr(appuser, 1, 255);

		IF TG_OP = 'DELETE' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( OLD.*, 'DEL', now(),
			clock_timestamp(), txid_current(), appuser );
		    RETURN OLD;
		ELSIF TG_OP = 'UPDATE' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( NEW.*, 'UPD', now(),
			clock_timestamp(), txid_current(), appuser );
		    RETURN NEW;
		ELSIF TG_OP = 'INSERT' THEN
		    INSERT INTO $ZZ$ || quote_ident(aud_schema)
			|| '.' || quote_ident(table_name) || $ZZ$
		    VALUES ( NEW.*, 'INS', now(),
			clock_timestamp(), txid_current(), appuser );
		    RETURN NEW;
		END IF;
		RETURN NULL;
	    END;
	$TQ$ LANGUAGE plpgsql SECURITY DEFINER
    $ZZ$;

    EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident('trigger_audit_'
	|| table_name) || ' ON ' || quote_ident(tbl_schema) || '.'
	|| quote_ident(table_name);

    EXECUTE 'CREATE TRIGGER ' || quote_ident('trigger_audit_' || table_name)
	|| ' AFTER INSERT OR UPDATE OR DELETE ON ' || quote_ident(tbl_schema)
	|| '.' || quote_ident(table_name) || ' FOR EACH ROW EXECUTE PROCEDURE '
	|| quote_ident(tbl_schema) || '.' || quote_ident('perform_audit_'
	|| table_name) || '()';
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'rebuild_stamp_triggers');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.rebuild_stamp_triggers ( tbl_schema character varying );
CREATE OR REPLACE FUNCTION schema_support.rebuild_stamp_triggers(tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    DECLARE
	tab RECORD;
    BEGIN
	FOR tab IN
	    SELECT table_name FROM information_schema.tables
	    WHERE table_schema = tbl_schema AND table_type = 'BASE TABLE'
	    AND table_name NOT LIKE 'aud$%'
	LOOP
	    PERFORM schema_support.rebuild_stamp_trigger
		(tbl_schema, tab.table_name);
	END LOOP;
    END;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'relation_diff');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.relation_diff ( schema text, old_rel text, new_rel text, key_relation text, prikeys text[], raise_exception boolean );
CREATE OR REPLACE FUNCTION schema_support.relation_diff(schema text, old_rel text, new_rel text, key_relation text DEFAULT NULL::text, prikeys text[] DEFAULT NULL::text[], raise_exception boolean DEFAULT true)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
	_or	RECORD;
	_nr	RECORD;
	_t1	integer;
	_t2	integer;
	_cols TEXT[];
	_q TEXT;
	_f TEXT;
	_c RECORD;
	_w TEXT[];
	_ctl TEXT[];
	_rv	boolean;
BEGIN
	-- do a simple row count
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || old_rel || '"' INTO _t1;
	EXECUTE 'SELECT count(*) FROM ' || schema || '."' || new_rel || '"' INTO _t2;

	_rv := true;

	IF _t1 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, old_rel;
		_rv := false;
	END IF;
	IF _t2 IS NULL THEN
		RAISE NOTICE 'table %.% does not seem to exist', schema, new_rel;
		_rv := false;
	END IF;

	IF _t1 != _t2 THEN
		RAISE NOTICE 'table % has % rows; table % has % rows', old_rel, _t1, new_rel, _t2;
		_rv := false;
	END IF;

	IF NOT _rv THEN
		IF raise_exception THEN
			RAISE EXCEPTION 'Relations do not match';
		END IF;
		RETURN false;
	END IF;

	IF prikeys IS NULL THEN
		-- read into prikeys the primary key for the table
		IF key_relation IS NULL THEN
			key_relation := old_rel;
		END IF;
		prikeys := schema_support.get_pk_columns(schema, key_relation);
	END IF;

	-- read into _cols the column list in common between old_rel and new_rel
	_cols := schema_support.get_common_columns(schema, old_rel, new_rel);

	FOREACH _f IN ARRAY _cols
	LOOP
		SELECT array_append(_ctl,
			quote_ident(_f) || '::text') INTO _ctl;
	END LOOP;

	_cols := _ctl;

	_q := 'SELECT '|| array_to_string(_cols,',') ||' FROM ' || quote_ident(schema) || '.' ||
		quote_ident(old_rel);

	FOR _or IN EXECUTE _q
	LOOP
		_w = NULL;
		FOREACH _f IN ARRAY prikeys
		LOOP
			FOR _c IN SELECT * FROM json_each_text( row_to_json(_or) )
			LOOP
				IF _c.key = _f THEN
					SELECT array_append(_w,
						quote_ident(_f) || '::text = ' || quote_literal(_c.value))
					INTO _w;
				END IF;
			END LOOP;
		END LOOP;
		_q := 'SELECT ' || array_to_string(_cols,',') ||
			' FROM ' || quote_ident(schema) || '.' ||
			quote_ident(new_rel) || ' WHERE ' ||
			array_to_string(_w, ' AND ' );
		EXECUTE _q INTO _nr;

		IF _or != _nr THEN
			RAISE NOTICE 'mismatched row:';
			RAISE NOTICE 'OLD: %', row_to_json(_or);
			RAISE NOTICE 'NEW: %', row_to_json(_nr);
			_rv := false;
		END IF;

	END LOOP;

	IF NOT _rv AND raise_exception THEN
		RAISE EXCEPTION 'Relations do not match';
	END IF;
	return _rv;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'replay_object_recreates');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.replay_object_recreates ( beverbose boolean );
CREATE OR REPLACE FUNCTION schema_support.replay_object_recreates(beverbose boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_tally	integer;
BEGIN
	SELECT	count(*)
	  INTO	_tally
	  FROM	pg_catalog.pg_class
	 WHERE	relname = '__recreate'
	   AND	relpersistence = 't';

	IF _tally > 0 THEN
		FOR _r in SELECT * from __recreate ORDER BY id DESC FOR UPDATE
		LOOP
			IF beverbose THEN
				RAISE NOTICE 'Regrant: %.%', _r.schema, _r.object;
			END IF;
			EXECUTE _r.ddl;
			IF _r.owner is not NULL THEN
				IF _r.type = 'view' THEN
					EXECUTE 'ALTER VIEW ' || _r.schema || '.' || _r.object ||
						' OWNER TO ' || _r.owner || ';';
				ELSIF _r.type = 'function' THEN
					EXECUTE 'ALTER FUNCTION ' || _r.schema || '.' || _r.object ||
						'(' || _r.idargs || ') OWNER TO ' || _r.owner || ';';
				ELSE
					RAISE EXCEPTION 'Unable to restore grant for %', _r;
				END IF;
			END IF;
			DELETE from __recreate where id = _r.id;
		END LOOP;

		SELECT count(*) INTO _tally from __recreate;
		IF _tally > 0 THEN
			RAISE EXCEPTION '% objects still exist for recreating after a complete loop', _tally;
		ELSE
			DROP TABLE __recreate;
		END IF;
	ELSE
		IF beverbose THEN
			RAISE NOTICE '**** WARNING: replay_object_recreates did NOT have anything to regrant!';
		END IF;
	END IF;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'replay_saved_grants');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.replay_saved_grants ( beverbose boolean );
CREATE OR REPLACE FUNCTION schema_support.replay_saved_grants(beverbose boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_tally	integer;
BEGIN
	 SELECT  count(*)
      INTO  _tally
      FROM  pg_catalog.pg_class
     WHERE  relname = '__regrants'
       AND  relpersistence = 't';

	IF _tally > 0 THEN
	    FOR _r in SELECT * from __regrants FOR UPDATE
	    LOOP
		    IF beverbose THEN
			    RAISE NOTICE 'Regrant Executing: %', _r.regrant;
		    END IF;
		    EXECUTE _r.regrant;
		    DELETE from __regrants where id = _r.id;
	    END LOOP;

	    SELECT count(*) INTO _tally from __regrants;
	    IF _tally > 0 THEN
		    RAISE EXCEPTION 'Grant extractions were run while replaying grants - %.', _tally;
	    ELSE
		    DROP TABLE __regrants;
	    END IF;
	ELSE
		IF beverbose THEN
			RAISE NOTICE '**** WARNING: replay_saved_grants did NOT have anything to regrant!';
		END IF;
	END IF;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'retrieve_functions');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.retrieve_functions ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.retrieve_functions(schema character varying, object character varying, dropit boolean DEFAULT false)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_fn		TEXT;
	_cmd	TEXT;
	_rv		TEXT[];
BEGIN
	FOR _r IN SELECT n.nspname, p.proname,
				coalesce(u.usename, 'public') as owner,
				pg_get_functiondef(p.oid) as funcdef,
				pg_get_function_identity_arguments(p.oid) as idargs
		FROM    pg_catalog.pg_proc  p
				INNER JOIN pg_catalog.pg_namespace n on n.oid = p.pronamespace
				INNER JOIN pg_catalog.pg_language l on l.oid = p.prolang
				INNER JOIN pg_catalog.pg_user u on u.usesysid = p.proowner
		WHERE   n.nspname = schema
		  AND	p.proname = object
	LOOP
		_fn = _r.nspname || '.' || _r.proname || '(' || _r.idargs || ')';
		_rv = _rv || _fn;

		IF dropit  THEN
			_cmd = 'DROP FUNCTION ' || _fn || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
	RETURN _rv;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_constraint_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_constraint_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_constraint_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in 	SELECT n.nspname, c.relname, con.conname,
				pg_get_constraintdef(con.oid, true) as def
		FROM pg_constraint con
			INNER JOIN pg_class c on (c.relnamespace, c.oid) =
				(con.connamespace, con.conrelid)
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE con.confrelid in (
			select c.oid
			from pg_class c
				inner join pg_namespace n on n.oid = c.relnamespace
			WHERE c.relname = object
			AND n.nspname = schema
		) AND n.nspname != schema
	LOOP
		_ddl := 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
			' ADD CONSTRAINT ' || _r.conname || ' ' || _r.def;
		IF _ddl is NULL THEN
			RAISE EXCEPTION 'Unable to define constraint for %', _r;
		END IF;
		INSERT INTO __recreate (schema, object, type, ddl )
			VALUES (
				_r.nspname, _r.relname, 'constraint', _ddl
			);
		IF dropit  THEN
			_cmd = 'ALTER TABLE ' || _r.nspname || '.' || _r.relname ||
				' DROP CONSTRAINT ' || _r.conname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependent_objects_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_dependent_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
CREATE OR REPLACE FUNCTION schema_support.save_dependent_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$

DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE DEBUG 'processing %.%', schema, object;
	-- process stored procedures
	FOR _r in SELECT  distinct np.nspname::text, dependent.proname::text
		FROM   pg_depend dep
			INNER join pg_type dependee on dependee.oid = dep.refobjid
			INNER join pg_namespace n on n.oid = dependee.typnamespace
			INNER join pg_proc dependent on dependent.oid = dep.objid
			INNER join pg_namespace np on np.oid = dependent.pronamespace
			WHERE   dependee.typname = object
			  AND	  n.nspname = schema
	LOOP
		-- RAISE NOTICE '1 dealing with  %.%', _r.nspname, _r.proname;
		PERFORM schema_support.save_constraint_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_dependent_objects_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit);
	END LOOP;

	-- save any triggers on the view
	FOR _r in SELECT distinct n.nspname::text, dependee.relname::text, dependee.relkind
		FROM pg_depend
		JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
		JOIN pg_class as dependee ON pg_rewrite.ev_class = dependee.oid
		JOIN pg_class as dependent ON pg_depend.refobjid = dependent.oid
		JOIN pg_namespace n on n.oid = dependee.relnamespace
		JOIN pg_namespace sn on sn.oid = dependent.relnamespace
		JOIN pg_attribute ON pg_depend.refobjid = pg_attribute.attrelid
   			AND pg_depend.refobjsubid = pg_attribute.attnum
		WHERE dependent.relname = object
  		AND sn.nspname = schema
	LOOP
		IF _r.relkind = 'v' THEN
			-- RAISE NOTICE '2 dealing with  %.%', _r.nspname, _r.relname;
			PERFORM * FROM save_dependent_objects_for_replay(_r.nspname, _r.relname, dropit);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);
		PERFORM schema_support.save_constraint_for_replay('jazzhands', 'table');
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_function_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_function_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_function_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	-- implicitly save regrants
	PERFORM schema_support.save_grants_for_replay(schema, object);
	FOR _r IN SELECT n.nspname, p.proname,
				coalesce(u.usename, 'public') as owner,
				pg_get_functiondef(p.oid) as funcdef,
				pg_get_function_identity_arguments(p.oid) as idargs
		FROM    pg_catalog.pg_proc  p
				INNER JOIN pg_catalog.pg_namespace n on n.oid = p.pronamespace
				INNER JOIN pg_catalog.pg_language l on l.oid = p.prolang
				INNER JOIN pg_catalog.pg_user u on u.usesysid = p.proowner
		WHERE   n.nspname = schema
		  AND	p.proname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, owner, ddl, idargs )
		VALUES (
			_r.nspname, _r.proname, 'function', _r.owner, _r.funcdef, _r.idargs
		);
		IF dropit  THEN
			_cmd = 'DROP FUNCTION ' || _r.nspname || '.' ||
				_r.proname || '(' || _r.idargs || ');';
			EXECUTE _cmd;
		END IF;

	END LOOP;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_functions');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_functions ( schema character varying, object character varying, newname character varying );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_functions(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_schema		varchar;
	_object		varchar;
	_procs		RECORD;
	_perm		RECORD;
	_grant		varchar;
	_role		varchar;
	_fullgrant		varchar;
BEGIN
	_schema := schema;
	_object := object;
	if newname IS NULL THEN
		newname := _object;
	END IF;
	PERFORM schema_support.prepare_for_grant_replay();
	FOR _procs IN SELECT  n.nspname as schema, p.proname,
			pg_get_function_identity_arguments(p.oid) as args,
			proacl as privs
		FROM    pg_catalog.pg_proc  p
				inner join pg_catalog.pg_namespace n on n.oid = p.pronamespace
		WHERE   n.nspname = _schema
		 AND    p.proname = _object
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _procs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on FUNCTION ' ||
				_schema || '.' ||
				newname || '(' || _procs.args || ')  to ' ||
				_role || _grant;
			-- RAISE DEBUG 'inserting % for %', _fullgrant, _perm;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_grants_for_replay_relations');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_grants_for_replay_relations ( schema character varying, object character varying, newname character varying );
CREATE OR REPLACE FUNCTION schema_support.save_grants_for_replay_relations(schema character varying, object character varying, newname character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_schema		varchar;
	_object	varchar;
	_tabs		RECORD;
	_perm		RECORD;
	_grant		varchar;
	_fullgrant		varchar;
	_role		varchar;
BEGIN
	_schema := schema;
	_object := object;
	if newname IS NULL THEN
		newname := _object;
	END IF;
	PERFORM schema_support.prepare_for_grant_replay();

	-- Handle table wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			c.relacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || ' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

	-- Handle column specific wide grants
	FOR _tabs IN SELECT  n.nspname as schema,
			c.relname as name,
			CASE c.relkind
				WHEN 'r' THEN 'table'
				WHEN 'v' THEN 'view'
				WHEN 'S' THEN 'sequence'
				WHEN 'f' THEN 'foreign table'
				END as "Type",
			a.attname as col,
			a.attacl as privs
		FROM    pg_catalog.pg_class c
			INNER JOIN pg_catalog.pg_namespace n
				ON n.oid = c.relnamespace
			INNER JOIN pg_attribute a
                ON a.attrelid = c.oid
		WHERE c.relkind IN ('r', 'v', 'S', 'f')
		  AND a.attacl IS NOT NULL
		  AND c.relname = _object
		  AND n.nspname = _schema
		ORDER BY 1, 2
	LOOP
		-- NOTE:  We lose who granted it.  Oh Well.
		FOR _perm IN SELECT * FROM pg_catalog.aclexplode(acl := _tabs.privs)
		LOOP
			--  grantor | grantee | privilege_type | is_grantable
			IF _perm.is_grantable THEN
				_grant = ' WITH GRANT OPTION';
			ELSE
				_grant = '';
			END IF;
			IF _perm.grantee = 0 THEN
				_role := 'PUBLIC';
			ELSE
				_role := pg_get_userbyid(_perm.grantee);
			END IF;
			_fullgrant := 'GRANT ' ||
				_perm.privilege_type || '(' || _tabs.col || ')'
				' on ' ||
				_schema || '.' ||
				newname || ' to ' ||
				_role || _grant;
			IF _fullgrant IS NULL THEN
				RAISE EXCEPTION 'built up grant for %.% (%) is NULL',
					schema, object, newname;
	    END IF;
			INSERT INTO __regrants (schema, object, newname, regrant) values (schema,object, newname, _fullgrant );
		END LOOP;
	END LOOP;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'save_trigger_for_replay');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.save_trigger_for_replay ( schema character varying, object character varying, dropit boolean );
CREATE OR REPLACE FUNCTION schema_support.save_trigger_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
BEGIN
	PERFORM schema_support.prepare_for_object_replay();

	FOR _r in
		SELECT n.nspname, c.relname, trg.tgname,
				pg_get_triggerdef(trg.oid, true) as def
		FROM pg_trigger trg
			INNER JOIN pg_class c on trg.tgrelid =  c.oid
			INNER JOIN pg_namespace n on n.oid = c.relnamespace
		WHERE n.nspname = schema and c.relname = object
	LOOP
		INSERT INTO __recreate (schema, object, type, ddl )
			VALUES (
				_r.nspname, _r.relname, 'trigger', _r.def
			);
		IF dropit  THEN
			_cmd = 'DROP TRIGGER ' || _r.tgname || ' ON ' ||
				_r.nspname || '.' || _r.relname || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('schema_support', 'undo_audit_row');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS schema_support.undo_audit_row ( in_table text, in_audit_schema text, in_schema text, in_start_time timestamp without time zone, in_end_time timestamp without time zone, in_aud_user text, in_audit_ids integer[] );
CREATE OR REPLACE FUNCTION schema_support.undo_audit_row(in_table text, in_audit_schema text DEFAULT 'audit'::text, in_schema text DEFAULT 'jazzhands'::text, in_start_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_end_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_aud_user text DEFAULT NULL::text, in_audit_ids integer[] DEFAULT NULL::integer[])
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
	tally	integer;
	pks		text[];
	cols	text[];
	q		text;
	val		text;
	x		text;
	_whcl	text;
	_eq		text;
	setstr	text;
	_r		record;
	_c		record;
	_br		record;
	_vals	text[];
BEGIN
	tally := 0;
	pks := schema_support.get_pk_columns(in_schema, in_table);
	cols := schema_support.get_columns(in_schema, in_table);
	q = '';
	IF in_start_time is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#timestamp') || ' >= ' || quote_literal(in_start_time);
	END IF;
	IF in_end_time is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#timestamp') || ' <= ' || quote_literal(in_end_time);
	END IF;
	IF in_aud_user is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#user') || ' = ' || quote_literal(in_aud_user);
	END IF;
	IF in_audit_ids is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#seq') || ' IN ( ' ||
			array_to_string(in_audit_ids, ',') || ')';
	END IF;

	-- Iterate over all the rows that need to be replayed
	q := 'SELECT * from ' || quote_ident(in_audit_schema) || '.' ||
			quote_ident(in_table) || ' ' || q || ' ORDER BY "aud#seq" desc';
	FOR _r IN EXECUTE q
	LOOP
		IF _r."aud#action" = 'DEL' THEN
			-- Build up a list of rows that need to be inserted
			_vals = NULL;
			FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
			LOOP
				IF _c.key !~ 'data|aud' THEN
					IF _c.value IS NULL THEN
						SELECT array_append(_vals, 'NULL') INTO _vals;
					ELSE
						SELECT array_append(_vals, quote_literal(_c.value)) INTO _vals;
					END IF;
				END IF;
			END LOOP;
			_eq := 'INSERT INTO ' || quote_ident(in_schema) || '.' ||
				quote_ident(in_table) || ' ( ' ||
				array_to_string(
					schema_support.quote_ident_array(cols), ',') ||
					') VALUES (' ||  array_to_string(_vals, ',', NULL) || ')';
		ELSIF _r."aud#action" in ('INS', 'UPD') THEN
			-- Build up a where clause for this table to get a unique row
			-- based on the primary key
			FOREACH x IN ARRAY pks
			LOOP
				_whcl := '';
				FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
				LOOP
					IF _c.key = x THEN
						IF _whcl != '' THEN
							_whcl := _whcl || ', ';
						END IF;
						IF _c.value IS NULL THEN
							_whcl = _whcl || quote_ident(_c.key) || ' = NULL ';
						ELSE
							_whcl = _whcl || quote_ident(_c.key) || ' =  ' ||
								quote_nullable(_c.value);
						END IF;
					END IF;
				END LOOP;
			END LOOP;

			IF _r."aud#action" = 'INS' THEN
				_eq := 'DELETE FROM ' || quote_ident(in_schema) || '.' ||
					quote_ident(in_table) || ' WHERE ' || _whcl;
			ELSIF _r."aud#action" = 'UPD' THEN
				-- figure out what rows have changed and do an update if
				-- they have.  NOTE:  This may result in no change being
				-- replayed if a row did not actually change
				setstr = '';
				FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
				LOOP
					--
					-- Iterate over all the columns and if they have changed,
					-- then build an update statement
					--
					IF _c.key !~ 'aud#|data_(ins|upd)_(user|date)' THEN
						EXECUTE 'SELECT ' || _c.key || ' FROM ' ||
							quote_ident(in_schema) || '.' ||
								quote_ident(in_table)  ||
							' WHERE ' || _whcl
							INTO val;
						IF ( _c.value IS NULL  AND val IS NOT NULL) OR
							( _c.value IS NOT NULL AND val IS NULL) OR
							(_c.value::text NOT SIMILAR TO val::text) THEN
							IF char_length(setstr) > 0 THEN
								setstr = setstr || ',
								';
							END IF;
							IF _c.value IS NOT  NULL THEN
								setstr = setstr || _c.key || ' = ' ||
									quote_nullable(_c.value) || ' ' ;
							ELSE
								setstr = setstr || _c.key || ' = ' ||
									' NULL ' ;
							END IF;
						END IF;
					END IF;
				END LOOP;
				IF char_length(setstr) > 0 THEN
					_eq := 'UPDATE ' || quote_ident(in_schema) || '.' ||
						quote_ident(in_table) ||
						' SET ' || setstr || ' WHERE ' || _whcl;
				END IF;
			END IF;
		END IF;
		IF _eq IS NOT NULL THEN
			tally := tally + 1;
			RAISE NOTICE '%', _eq;
			EXECUTE _eq;
		END IF;
	END LOOP;
	RETURN tally;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.mv_last_updated(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO schema_support
AS $function$
DECLARE
	rv	timestamp;
BEGIN
	IF debug THEN
		RAISE NOTICE 'selecting for update...';
	END IF;

	SELECT	refresh
	INTO	rv
	FROM	schema_support.mv_refresh r
	WHERE	r.schema = mv_last_updated.schema
	AND	r.view = relation
	FOR UPDATE;

	IF debug THEN
		RAISE NOTICE 'returning %', rv;
	END IF;

	RETURN rv;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_table(aud_schema character varying, tbl_schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	idx		text[];
	keys	text[];
	cols	text[];
	i		text;
	seq		integer;
BEGIN
	-- rename all the old indexes and constraints on the old audit table
	SELECT	array_agg(c2.relname)
		INTO	 idx
		  FROM	pg_catalog.pg_index i
			LEFT JOIN pg_catalog.pg_class c
				ON c.oid = i.indrelid
			LEFT JOIN pg_catalog.pg_class c2
				ON i.indexrelid = c2.oid
			LEFT JOIN pg_catalog.pg_namespace n
				ON c2.relnamespace = n.oid
			LEFT JOIN pg_catalog.pg_constraint con
				ON (conrelid = i.indrelid
				AND conindid = i.indexrelid
				AND contype IN ('p','u','x'))
		 WHERE n.nspname = quote_ident(aud_schema)
		  AND	c.relname = quote_ident(table_name)
		  AND	contype is NULL
	;

	SELECT array_agg(con.conname)
	INTO	keys
    FROM pg_catalog.pg_class c
		INNER JOIN pg_namespace n
			ON relnamespace = n.oid
		INNER JOIN pg_catalog.pg_index i
			ON c.oid = i.indrelid
		INNER JOIN pg_catalog.pg_class c2
			ON i.indexrelid = c2.oid
		INNER JOIN pg_catalog.pg_constraint con ON
			(con.conrelid = i.indrelid
			AND con.conindid = i.indexrelid )
	WHERE  	n.nspname = quote_ident(aud_schema)
	AND		c.relname = quote_ident(table_name)
	AND con.contype in ('p', 'u')
	;

	FOREACH i IN ARRAY idx
	LOOP
		EXECUTE 'ALTER INDEX '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(i)
			|| ' RENAME TO '
			|| quote_ident('_' || i);
	END LOOP;

	IF array_length(keys, 1) > 0 THEN
		FOREACH i IN ARRAY keys
		LOOP
			EXECUTE 'ALTER TABLE '
				|| quote_ident(aud_schema) || '.'
				|| quote_ident(table_name)
				|| ' RENAME CONSTRAINT '
				|| quote_ident(i)
				|| ' TO '
			|| quote_ident('__old__' || i);
		END LOOP;
	END IF;

	--
	-- get columns
	--
	SELECT	array_agg(quote_ident(a.attname) ORDER BY a.attnum)
	INTO	cols
	FROM	pg_catalog.pg_attribute a
	INNER JOIN pg_catalog.pg_class c on a.attrelid = c.oid
	INNER JOIN pg_catalog.pg_namespace n on n.oid = c.relnamespace
	LEFT JOIN pg_catalog.pg_description d
			on d.objoid = a.attrelid
			and d.objsubid = a.attnum
	WHERE  	n.nspname = quote_ident(aud_schema)
	  AND	c.relname = quote_ident(table_name)
	  AND 	a.attnum > 0
	  AND 	NOT a.attisdropped
	;

	--
	-- rename table
	--
	EXECUTE 'ALTER TABLE '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name)
		|| ' RENAME TO '
		|| quote_ident('__old__' || table_name);


	--
	-- RENAME sequence
	--
	EXECUTE 'ALTER SEQUENCE '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name || '_seq')
		|| ' RENAME TO '
		|| quote_ident('_old_' || table_name || '_seq');

	--
	-- create a new audit table
	--
	PERFORM schema_support.build_audit_table(aud_schema,tbl_schema,table_name);

	EXECUTE 'INSERT INTO '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident(table_name) || ' ( '
		|| array_to_string(cols, ',') || ' ) SELECT '
		|| array_to_string(cols, ',') || ' FROM '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__' || table_name)
		|| ' ORDER BY '
		|| quote_ident('aud#seq');

	--
	-- fix sequence primary key to have the correct next value
	--
	EXECUTE 'SELECT max("aud#seq") + 1 FROM	 '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name) INTO seq;
	IF seq IS NOT NULL THEN
		EXECUTE 'ALTER SEQUENCE '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident(table_name || '_seq')
			|| ' RESTART WITH ' || seq;
	END IF;

	EXECUTE 'DROP TABLE '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('__old__' || table_name);

	--
	-- drop audit sequence, in case it was nto dropped with table.
	--
	EXECUTE 'DROP SEQUENCE IF EXISTS '
		|| quote_ident(aud_schema) || '.'
		|| quote_ident('_old_' || table_name || '_seq');

	--
	-- drop indexes found before that did not get dropped.
	--
	FOR i IN SELECT	c2.relname
		  FROM	pg_catalog.pg_index i
			LEFT JOIN pg_catalog.pg_class c
				ON c.oid = i.indrelid
			LEFT JOIN pg_catalog.pg_class c2
				ON i.indexrelid = c2.oid
			LEFT JOIN pg_catalog.pg_namespace n
				ON c2.relnamespace = n.oid
			LEFT JOIN pg_catalog.pg_constraint con
				ON (conrelid = i.indrelid
				AND conindid = i.indexrelid
				AND contype IN ('p','u','x'))
		 WHERE n.nspname = quote_ident(aud_schema)
		  AND	c.relname = quote_ident('__old__' || table_name)
		  AND	contype is NULL
	LOOP
		EXECUTE 'DROP INDEX '
			|| quote_ident(aud_schema) || '.'
			|| quote_ident('_' || i);
	END LOOP;


	--
	-- recreate audit trigger
	--
	PERFORM schema_support.rebuild_audit_trigger (
		aud_schema, tbl_schema, table_name );

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_tables(aud_schema character varying, tbl_schema character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
	SELECT b.table_name
	FROM information_schema.tables b
		INNER JOIN information_schema.tables a
			USING (table_name,table_type)
	WHERE table_type = 'BASE TABLE'
	AND a.table_schema = aud_schema
	AND b.table_schema = tbl_schema
	ORDER BY table_name
    LOOP
	PERFORM schema_support.save_dependent_objects_for_replay(aud_schema::varchar, table_list.table_name::varchar);
	PERFORM schema_support.rebuild_audit_table
	    ( aud_schema, tbl_schema, table_list.table_name );
	PERFORM schema_support.replay_object_recreates();
	PERFORM schema_support.replay_saved_grants();
    END LOOP;

    PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.refresh_mv_if_needed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	lastref	timestamp;
	lastdat	timestamp;
BEGIN
	SELECT coalesce(schema_support.mv_last_updated(relation, schema,debug),'-infinity') INTO lastref;
	SELECT coalesce(schema_support.relation_last_changed(relation, schema,debug),'-infinity') INTO lastdat;
	IF lastdat > lastref THEN
		EXECUTE 'REFRESH MATERIALIZED VIEW ' || quote_ident(schema)||'.'||quote_ident(relation);
		PERFORM schema_support.set_mv_last_updated(relation, schema);
	END IF;
	RETURN;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.relation_last_changed(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	audsch	text;
	rk	char;
	rv	timestamp;
	ts	timestamp;
	obj	text;
	objaud text;
BEGIN
	SELECT	audit_schema
	INTO	audsch
	FROM	schema_support.schema_audit_map m
	WHERE	m.schema = relation_last_changed.schema;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Schema % not configured for this', schema;
	END IF;

	SELECT 	relkind
	INTO	rk
	FROM	pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE	n.nspname = relation_last_changed.schema
	AND	c.relname = relation_last_changed.relation;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'No such object %.%', schema, relation;
	END IF;

	IF rk = 'r' THEN
		EXECUTE '
			SELECT	max("aud#timestamp")
			FROM	'||quote_ident(audsch)||'.'||quote_ident(relation)
		INTO rv;

		IF rv IS NULL THEN
			RETURN '-infinity'::interval;
		ELSE
			RETURN rv;
		END IF;
	END IF;

	IF rk = 'v' OR rk = 'm' THEN
		FOR obj,objaud IN WITH RECURSIVE recur AS (
				SELECT distinct rewrite.ev_class as root_oid, d.refobjid as oid
				FROM pg_depend d
        			JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
					JOIN pg_class c on rewrite.ev_class = c.oid
					JOIN pg_namespace n on n.oid = c.relnamespace
				WHERE c.relname = relation
				AND n.nspname = relation_last_changed.schema
				AND d.refobjsubid > 0
			UNION ALL
				SELECT recur.root_oid, d.refobjid as oid
				FROM pg_depend d
        			JOIN pg_rewrite rewrite ON d.objid = rewrite.oid
				JOIN recur ON recur.oid = rewrite.ev_class
				AND d.refobjsubid > 0
			), list AS ( select distinct m.audit_schema, c.relname, c.relkind, recur.*
				FROM pg_class c
					JOIN recur on recur.oid = c.oid
					JOIN pg_namespace n on c.relnamespace = n.oid
					JOIN schema_support.schema_audit_map m
						ON m.schema = n.nspname
				WHERE relkind = 'r'
			) SELECT relname, audit_schema from list
		LOOP
			-- if there is no audit table, assume its kept current.  This is
			-- likely some sort of cache table.  XXX - should probably be
			-- updated to use the materialized view update bits
			BEGIN
				EXECUTE 'SELECT max("aud#timestamp")
					FROM '||quote_ident(objaud)||'.'|| quote_ident(obj)
					INTO ts;
				IF debug THEN
					RAISE NOTICE '%.% -> %', objaud, obj, ts;
				END IF;
				IF rv IS NULL OR ts > rv THEN
					rv := ts;
				END IF;
			EXCEPTION WHEN undefined_table THEN
				IF debug THEN
					RAISE NOTICE 'skipping %.%', schema, obj;
				END IF;
			END;
		END LOOP;
		RETURN rv;
	END IF;

	RAISE EXCEPTION 'Unable to process relkind %', rk;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.reset_all_schema_table_sequences(schema text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	_r	RECORD;
	tally INTEGER;
BEGIN
	tally := 0;
	FOR _r IN

		SELECT n.nspname, c.relname, c.relkind
		FROM	pg_class c
				INNER JOIN pg_namespace n ON n.oid = c.relnamespace
		WHERE	n.nspname = schema
		AND		c.relkind = 'r'
	LOOP
		PERFORM schema_support.reset_table_sequence(_r.nspname::text, _r.relname::text);
		tally := tally + 1;
	END LOOP;
	RETURN tally;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.reset_table_sequence(schema character varying, table_name character varying)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	_r	RECORD;
	m	BIGINT;
BEGIN
	FOR _r IN
		WITH s AS (
			SELECT	pg_get_serial_sequence(schema||'.'||table_name,
				a.attname) as seq, a.attname as column
			FROM	pg_attribute a
			JOIN pg_class c ON c.oid = a.attrelid
			JOIN pg_namespace n ON n.oid = c.relnamespace
			WHERE	c.relname = table_name
			AND	n.nspname = schema
				AND 	a.attnum > 0
				AND 	NOT a.attisdropped
		) SELECT s.*, nextval(s.seq) as nv FROM s WHERE seq IS NOT NULL
	LOOP
		EXECUTE 'SELECT max('||quote_ident(_r.column)||')+1 FROM  '
			|| quote_ident(schema)||'.'||quote_ident(table_name)
			INTO m;
		IF m IS NOT NULL THEN
			IF _r.nv > m THEN
				m := _r.nv;
			END IF;
			EXECUTE 'ALTER SEQUENCE ' || _r.seq || ' RESTART WITH '
				|| m;
		END IF;
	END LOOP;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION schema_support.set_mv_last_updated(relation text, schema text DEFAULT 'jazzhands'::text, debug boolean DEFAULT false)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO schema_support
AS $function$
DECLARE
	rv	timestamp;
BEGIN
	INSERT INTO schema_support.mv_refresh AS r (
		schema, view, refresh
	) VALUES (
		set_mv_last_updated.schema, relation, now()
	) ON CONFLICT ON CONSTRAINT mv_refresh_pkey DO UPDATE
		SET		refresh = now()
		WHERE	r.schema = set_mv_last_updated.schema
		AND		r.view = relation
	;

	RETURN rv;
END;
$function$
;

--
-- Process drops in backend_utils
--
-- New function
CREATE OR REPLACE FUNCTION backend_utils.refresh_if_needed(object text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	rk char;
BEGIN
	SELECT  relkind
	INTO    rk
	FROM    pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE   n.nspname = 'jazzhands'
	AND     c.relname = relation_last_changed.relation;

	-- silently ignore things that are not materialized views
	IF rk = 'm' THEN
		PERFORM schema_support.refresh_mv_if_needed(object, 'jazzhands');
	END IF;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION backend_utils.relation_last_changed(view text)
 RETURNS timestamp without time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	RETURN schema_support.relation_last_changed(view);
END;
$function$
;

-- Dropping obsoleted sequences....
DROP SEQUENCE IF EXISTS x509_certificate_x509_cert_id_seq;


-- Dropping obsoleted audit sequences....
DROP SEQUENCE IF EXISTS audit.x509_certificate_seq;


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
ALTER TABLE val_country_code DROP CONSTRAINT IF EXISTS r_787;
ALTER TABLE val_country_code
	ADD CONSTRAINT fk_val_curcode_iso_cntry_code
	FOREIGN KEY (primary_iso_currency_code) REFERENCES val_iso_currency_code(iso_currency_code);

ALTER TABLE val_network_range_type DROP CONSTRAINT IF EXISTS r_786;
ALTER TABLE val_network_range_type
	ADD CONSTRAINT fk_netrange_type_nb_type
	FOREIGN KEY (netblock_type) REFERENCES val_netblock_type(netblock_type);

ALTER TABLE x509_key_usage_attribute DROP CONSTRAINT IF EXISTS fk_x509_certificate;
ALTER TABLE x509_key_usage_attribute
	ADD CONSTRAINT fk_x509_certificate
	FOREIGN KEY (x509_cert_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id);

ALTER TABLE netblock DROP CONSTRAINT IF EXISTS ak_netblock_params;
ALTER TABLE netblock
	ADD CONSTRAINT ak_netblock_params
	UNIQUE (ip_address, netblock_type, ip_universe_id, is_single_address);

-- index
-- triggers
DROP TRIGGER IF EXISTS trigger_pgnotify_account_collection_account_token_changes ON account_collection_account;
CREATE TRIGGER trigger_pgnotify_account_collection_account_token_changes AFTER INSERT OR DELETE OR UPDATE ON account_collection_account FOR EACH ROW EXECUTE PROCEDURE pgnotify_account_collection_account_token_changes();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_password_changes ON account_password;
CREATE TRIGGER trigger_pgnotify_account_password_changes AFTER INSERT OR UPDATE ON account_password FOR EACH ROW EXECUTE PROCEDURE pgnotify_account_password_changes();
DROP TRIGGER IF EXISTS trigger_unrequire_password_change ON account_password;
CREATE TRIGGER trigger_unrequire_password_change BEFORE INSERT OR UPDATE OF password ON account_password FOR EACH ROW EXECUTE PROCEDURE unrequire_password_change();
DROP TRIGGER IF EXISTS trigger_pgnotify_account_token_change ON account_token;
CREATE TRIGGER trigger_pgnotify_account_token_change AFTER INSERT OR UPDATE ON account_token FOR EACH ROW EXECUTE PROCEDURE pgnotify_account_token_change();
DROP TRIGGER IF EXISTS trigger_company_insert_function_nudge ON company;
CREATE TRIGGER trigger_company_insert_function_nudge BEFORE INSERT ON company FOR EACH ROW EXECUTE PROCEDURE company_insert_function_nudge();
DROP TRIGGER IF EXISTS trigger_dns_record_check_name ON dns_record;
CREATE TRIGGER trigger_dns_record_check_name BEFORE INSERT OR UPDATE OF dns_name ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_record_check_name();
DROP TRIGGER IF EXISTS l2_net_coll_member_enforce_on_type_change ON layer2_network_collection;
CREATE CONSTRAINT TRIGGER l2_net_coll_member_enforce_on_type_change AFTER UPDATE OF layer2_network_collection_type ON layer2_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE l2_net_coll_member_enforce_on_type_change();
DROP TRIGGER IF EXISTS l3_net_coll_member_enforce_on_type_change ON layer3_network_collection;
CREATE CONSTRAINT TRIGGER l3_net_coll_member_enforce_on_type_change AFTER UPDATE OF layer3_network_collection_type ON layer3_network_collection DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE l3_net_coll_member_enforce_on_type_change();
DROP TRIGGER IF EXISTS trigger_nb_dns_a_rec_validation ON netblock;
CREATE TRIGGER trigger_nb_dns_a_rec_validation BEFORE UPDATE OF ip_address, is_single_address ON netblock FOR EACH ROW EXECUTE PROCEDURE nb_dns_a_rec_validation();
DROP TRIGGER IF EXISTS trigger_pgnotify_token_change ON token;
CREATE TRIGGER trigger_pgnotify_token_change AFTER INSERT OR UPDATE ON token FOR EACH ROW EXECUTE PROCEDURE pgnotify_token_change();


-- BEGIN Misc that does not apply to above
/*
 * Copyright (c) 2016 Todd Kover
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
	where nspname = 'backend_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS backend_utils;
		CREATE SCHEMA backend_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA backend_utils IS 'part of jazzhands';
	END IF;
END;
$$;

		COMMENT ON SCHEMA backend_utils IS 'part of jazzhands';
------------------------------------------------------------------------------

--
-- used to trigger refreshes of materialized views
--
CREATE OR REPLACE FUNCTION backend_utils.refresh_if_needed(object text)
RETURNS void AS
$$
DECLARE
	rk char;
BEGIN
	SELECT  relkind
	INTO    rk
	FROM    pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE   n.nspname = 'jazzhands'
	AND     c.relname = relation_last_changed.relation;

	-- silently ignore things that are not materialized views
	IF rk = 'm' THEN
		PERFORM schema_support.refresh_mv_if_needed(object, 'jazzhands');
	END IF;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--
-- returns the last time an object was changed, based on audit tables, either
-- for the object itself in the case of tables, or dependent objects, in the
-- case of materialized views and views.
--
CREATE OR REPLACE FUNCTION backend_utils.relation_last_changed(view text)
RETURNS timestamp AS
$$
BEGIN
	RETURN schema_support.relation_last_changed(view);
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

grant select on all tables in schema backend_utils to iud_role;
grant usage on schema backend_utils to iud_role;
revoke all on schema backend_utils from public;
revoke all on  all functions in schema backend_utils from public;
grant execute on all functions in schema backend_utils to iud_role;



-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above
-- Copyright (c) 2015, Todd M. Kover, Matthew D. Ragan
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
--
-- $Id$
--

--
-- XXX NOTE: need to migrate network_interface.physical_port_id
--

create or replace view layer1_connection
AS
WITH conn_props AS (
	SELECT inter_component_connection_id,
			component_property_name, component_property_type,
			property_value
	FROM	component_property
	WHERE	component_property_type IN ('serial-connection')
), tcpsrv_device_id AS (
	SELECT inter_component_connection_id, device_id
	FROM	component_property
			INNER JOIN device USING (component_id)
	WHERE	component_property_type = 'tcpsrv-connections'
	AND		component_property_name = 'tcpsrv_device_id'
) , tcpsrv_enabled AS (
	SELECT inter_component_connection_id, property_value
	FROM	component_property
	WHERE	component_property_type = 'tcpsrv-connections'
	AND		component_property_name = 'tcpsrv_enabled'
) SELECT	
	icc.inter_component_connection_id  AS layer1_connection_id,
	icc.slot1_id			AS physical_port1_id,
	icc.slot2_id			AS physical_port2_id,
	icc.circuit_id,
	baud.property_value::integer			AS baud,
	dbits.property_value::integer		AS data_bits,
	sbits.property_value::integer		AS stop_bits,
	parity.property_value		AS parity,
	flow.property_value			AS flow_control,
	tcpsrv.device_id			AS tcpsrv_device_id,
	coalesce(tcpsrvon.property_value,'N')::char(1)	AS is_tcpsrv_enabled,
	icc.data_ins_user,
	icc.data_ins_date,
	icc.data_upd_user,
	icc.data_upd_date
FROM inter_component_connection icc
	INNER JOIN slot s1 ON icc.slot1_id = s1.slot_id
	INNER JOIN slot_type st1 ON st1.slot_type_id = s1.slot_type_id
	INNER JOIN slot s2 ON icc.slot2_id = s2.slot_id
	INNER JOIN slot_type st2 ON st2.slot_type_id = s2.slot_type_id
	LEFT JOIN tcpsrv_device_id tcpsrv USING (inter_component_connection_id)
	LEFT JOIN tcpsrv_enabled tcpsrvon USING (inter_component_connection_id)
	LEFT JOIN conn_props baud ON baud.inter_component_connection_id =
		icc.inter_component_connection_id AND
		baud.component_property_name = 'baud'
	LEFT JOIN conn_props dbits ON dbits.inter_component_connection_id =
		icc.inter_component_connection_id AND
		dbits.component_property_name = 'data-bits'
	LEFT JOIN conn_props sbits ON sbits.inter_component_connection_id =
		icc.inter_component_connection_id AND
		sbits.component_property_name = 'stop-bits'
	LEFT JOIN conn_props parity ON parity.inter_component_connection_id =
		icc.inter_component_connection_id AND
		parity.component_property_name = 'parity'
	LEFT JOIN conn_props flow ON flow.inter_component_connection_id =
		icc.inter_component_connection_id AND
		flow.component_property_name = 'flow-control'
 WHERE  st1.slot_function in ('network', 'serial', 'patchpanel')
	OR
 	st1.slot_function in ('network', 'serial', 'patchpanel')
;


-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above
-- Copyright (c) 2015, Todd M. Kover, Matthew D. Ragan
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
--
-- $Id$
--

--
-- XXX NOTE: need to migrate network_interface.physical_port_id
--

create or replace view physical_port
AS
SELECT	
	sl.slot_id			AS physical_port_id,
	d.device_id,
	sl.slot_name			AS port_name,
	st.slot_function		AS port_type,
	sl.description,
	st.slot_physical_interface_type	AS port_plug_style,
	NULL::text			AS port_medium,
	NULL::text			AS port_protocol,
	NULL::text			AS port_speed,
	sl.physical_label,
	NULL::text			AS port_purpose,
	NULL::integer			AS logical_port_id,
	NULL::integer			AS tcp_port,
	CASE WHEN ct.is_removable = 'Y' THEN 'N' ELSE 'Y' END AS is_hardwired,
	sl.data_ins_user,
	sl.data_ins_date,
	sl.data_upd_user,
	sl.data_upd_date
  FROM	slot sl 
	INNER JOIN slot_type st USING (slot_type_id)
	INNER JOIN v_device_slots d USING (slot_id)
	INNER JOIN component c ON (sl.component_id = c.component_id)
	INNER JOIN component_type ct USING (component_type_id)
 WHERE	st.slot_function in ('network', 'serial', 'patchpanel')
;


-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above
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
--
-- $Id$
--

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


-- This view maps users to device collections and lists properties
-- assigned to the users in order of their priorities.

CREATE OR REPLACE VIEW v_dev_col_user_prop_expanded AS
SELECT	
	property_id,
	dchd.device_collection_id,
	a.account_id, a.login, a.account_status,
	ar.account_realm_id, ar.account_realm_name,
	a.is_enabled,
	upo.property_type property_type,
	upo.property_name property_name, 
	upo.property_rank property_rank, 
	coalesce(Property_Value_Password_Type, Property_Value) AS property_value,
	CASE WHEN upn.is_multivalue = 'N' THEN 0
		ELSE 1 END is_multivalue,
	CASE WHEN pdt.property_data_type = 'boolean' THEN 1 ELSE 0 END is_boolean
FROM	v_acct_coll_acct_expanded_detail uued
	INNER JOIN Account_Collection u 
		USING (account_collection_id)
	INNER JOIN v_property upo ON 
		upo.Account_Collection_id = u.Account_Collection_id
		AND upo.property_type in (
			'CCAForceCreation', 'CCARight', 'ConsoleACL', 'RADIUS', 
			'TokenMgmt', 'UnixPasswdFileValue', 'UserMgmt', 'cca', 
			'feed-attributes', 'wwwgroup', 'HOTPants')
	INNER JOIN val_property upn
		ON upo.property_name = upn.property_name
		AND upo.property_type = upn.property_type
	INNER JOIN val_property_data_type pdt
		ON upn.property_data_type = pdt.property_data_type
	INNER JOIN account a ON uued.account_id = a.account_id
	INNER JOIN account_realm ar ON a.account_realm_id = ar.account_realm_id
	LEFT JOIN v_device_coll_hier_detail dchd
  		ON (dchd.parent_device_collection_id = upo.device_collection_id)
ORDER BY device_collection_level,
   CASE WHEN u.Account_Collection_type = 'per-account' THEN 0
	WHEN u.Account_Collection_type = 'property' THEN 1
	WHEN u.Account_Collection_type = 'systems' THEN 2
	ELSE 3 END,
  CASE WHEN uued.assign_method = 'Account_CollectionAssignedToPerson' THEN 0
	WHEN uued.assign_method = 'Account_CollectionAssignedToDept' THEN 1
	WHEN uued.assign_method = 
	'ParentAccount_CollectionOfAccount_CollectionAssignedToPerson' THEN 2
	WHEN uued.assign_method = 
	'ParentAccount_CollectionOfAccount_CollectionAssignedToDept' THEN 2
	WHEN uued.assign_method = 
	'Account_CollectionAssignedToParentDept' THEN 3
	WHEN uued.assign_method = 
	'ParentAccount_CollectionOfAccount_CollectionAssignedToParentDep' 
			THEN 3
        ELSE 6 END,
  uued.dept_level, uued.acct_coll_level, dchd.device_collection_id, 
  u.Account_Collection_id;


-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above
-- Copyright (c) 2014, Todd M. Kover
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
--
-- $Id$
--

--
-- This query pulls out all the device collection overrides for account
-- collections.
--
-- NOTE:  This view does not attempt to validate if a user has any
-- association with a device collection, just if a user is there, what
-- properties are set.  Its primary use is by other views.
--
CREATE OR REPLACE VIEW v_unix_group_overrides
AS
WITH perdevtomclass AS  (
	SELECT  hdc.device_collection_id as host_device_collection_id,
			mdc.device_collection_id as mclass_device_collection_id,
			device_id
	FROM    device_collection hdc
			INNER JOIN device_collection_device hdcd USING (device_collection_id)
			INNER JOIN device_collection_device mdcd USING (device_id)
			INNER JOIN device_collection mdc on
                        mdcd.device_collection_id = mdc.device_collection_id
	WHERE   hdc.device_collection_type = 'per-device'
	AND     mdc.device_collection_type = 'mclass'
), dcmap AS (
	SELECT device_collection_id, parent_device_collection_id,
		 device_collection_level
		 FROM v_device_coll_hier_detail
	UNION
	SELECT  p.host_device_collection_id as device_collection_id,
			d.parent_device_collection_id,
			d.device_collection_level
	FROM perdevtomclass p
		INNER JOIN v_device_coll_hier_detail d ON
			d.device_collection_id = p.mclass_device_collection_id
) 
SELECT device_collection_id, account_collection_id,
	array_agg(setting ORDER BY rn) AS setting
FROM (
	SELECT *, row_number() over () AS rn FROM (
		SELECT device_collection_id, account_collection_id,
				unnest(ARRAY[property_name, property_value]) AS setting
		FROM (
			SELECT  dchd.device_collection_id, 
					acpe.account_collection_id,
					p.property_name, 
					coalesce(p.property_value, 
						p.property_value_password_type) as property_value,
					row_number() OVER (partition by 
							dchd.device_collection_id,
							acpe.account_collection_id,
							acpe.property_name
							ORDER BY dchd.device_collection_level, assign_rank,
								property_id
					) AS ord
			FROM    v_acct_coll_prop_expanded acpe
				INNER JOIN unix_group ug USING (account_collection_id)
				INNER JOIN v_property p USING (property_id)
				INNER JOIN dcmap dchd
					ON dchd.parent_device_collection_id = 
						p.device_collection_id
			WHERE	p.property_type IN ('UnixPasswdFileValue', 
						'UnixGroupFileProperty',
						'MclassUnixProp')
			AND		p.property_name NOT IN 
					('UnixLogin','UnixGroup','UnixGroupMemberOverride')
		) dc_acct_prop_list
		WHERE ord = 1
	) select_for_ordering
) property_list
GROUP BY device_collection_id, account_collection_id
;


-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above
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

-- This likely needs to die in favor of making hotpants less aware of device
-- collection

CREATE OR REPLACE VIEW v_hotpants_account_attribute AS
SELECT	property_id,
	account_id,
	device_collection_id,
	login,
	property_name,
	property_type,
	property_value,
	property_rank,
	is_boolean
FROM	v_dev_col_user_prop_expanded 
	INNER JOIN Device_Collection USING (Device_Collection_ID)
WHERE	is_enabled = 'Y'
AND	(
		Device_Collection_Type IN ('HOTPants-app', 'HOTPants')
	OR
		Property_Type IN ('RADIUS', 'HOTPants') 
	)
;


-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above
--
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
--
-- $Id$
--

--
-- This is used by the zonegen software
--

CREATE OR REPLACE VIEW v_dns_changes_pending AS
WITH chg AS (
	SELECT dns_change_record_id, dns_domain_id,
		case WHEN family(ip_address)  = 4 THEN set_masklen(ip_address, 24)
			ELSE set_masklen(ip_address, 64) END as ip_address,
		dns_utils.get_domain_from_cidr(ip_address) as cidrdns
	FROM dns_change_record
	WHERE ip_address is not null
) SELECT DISTINCT *
FROM (
	SELECT	chg.dns_change_record_id, n.dns_domain_id,
		n.should_generate, n.last_generated,
		n.soa_name, chg.ip_address
	FROM   chg
		INNER JOIN dns_domain n on chg.cidrdns = n.soa_name
	UNION
	SELECT  chg.dns_change_record_id, d.dns_domain_id,
		d.should_generate, d.last_generated,
		d.soa_name, NULL
	FROM	dns_change_record chg
		INNER JOIN dns_domain d USING (dns_domain_id)
	WHERE   dns_domain_id IS NOT NULL
) x;



-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above
-- Copyright (c) 2014, Todd M. Kover
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
--
-- $Id$
--

--
-- This query pulls out all the device collection overrides
--
-- NOTE:  This view does not attempt to validate if a user has any
-- association with a device collection, just if a user is there, what
-- properties are set.  Its primary use is by other views.
--
-- It includes entries for all mclasses and will also include contrived entries
-- for every -- per-device device collection by mapping it through devices 
-- to an mclass.
-- That is, if there is a ForceHome (or whatever) on an mclass and that user is
-- added to the per-device collection, the ForceHome will show up on the
-- per-device collection too.  This is used to do the device mappings for
-- ownership and the like
--
CREATE OR REPLACE VIEW v_unix_account_overrides
AS
WITH perdevtomclass AS  (
	SELECT  hdc.device_collection_id as host_device_collection_id,
        	mdc.device_collection_id as mclass_device_collection_id,
        	device_id
	FROM    device_collection hdc
        	INNER JOIN device_collection_device hdcd USING (device_collection_id)
        	INNER JOIN device_collection_device mdcd USING (device_id)
        	INNER JOIN device_collection mdc on
                        mdcd.device_collection_id = mdc.device_collection_id
	WHERE   hdc.device_collection_type = 'per-device'
	AND     mdc.device_collection_type = 'mclass'
), dcmap AS (
	SELECT device_collection_id, parent_device_collection_id,
		 device_collection_level
		 FROM v_device_coll_hier_detail
	UNION
	SELECT  p.host_device_collection_id as device_collection_id,
			d.parent_device_collection_id,
			d.device_collection_level
	FROM perdevtomclass p
		INNER JOIN v_device_coll_hier_detail d ON
			d.device_collection_id = p.mclass_device_collection_id
) SELECT device_collection_id, account_id, 
	array_agg(setting ORDER BY rn) AS setting
FROM (
	SELECT *, row_number() over () AS rn FROM (
		SELECT device_collection_id, account_id,
				unnest(ARRAY[property_name, property_value]) AS setting
		FROM (
			SELECT  dchd.device_collection_id,
					acae.account_id,
					p.property_name, 
					coalesce(p.property_value, 
						p.property_value_password_type) as property_value,
					row_number() OVER (partition by 
							dchd.device_collection_id,
							acae.account_id,
							acpe.property_name
							ORDER BY dchd.device_collection_level, assign_rank,
								property_id
					) AS ord
			FROM    v_acct_coll_prop_expanded acpe
				INNER JOIN v_acct_coll_acct_expanded acae 
						USING (account_collection_id)
				INNER JOIN v_property p USING (property_id)
				INNER JOIN dcmap dchd
					ON dchd.parent_device_collection_id = p.device_collection_id
			WHERE	p.property_type IN ('UnixPasswdFileValue', 
						'UnixGroupFileProperty',
						'MclassUnixProp')
			AND		p.property_name NOT IN 
					('UnixLogin','UnixGroup','UnixGroupMemberOverride')
		) dc_acct_prop_list
		WHERE ord = 1
	) select_for_ordering
) property_list
GROUP BY device_collection_id, account_id
;


-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above
-- Copyright (c) 2015-2016, Todd M. Kover
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

CREATE OR REPLACE VIEW v_hotpants_device_collection AS
SELECT DISTINCT
                Device_Id,
                Device_Name,
                dc.Device_Collection_Id,
                dc.Device_Collection_Name,
                dc.Device_Collection_Type,
                host(IP_Address) as IP_address
	FROM	device_collection dc
		LEFT JOIN v_device_coll_hier_detail dcr ON
			dc.device_collection_id = dcr.parent_device_collection_id
                LEFT JOIN device_collection_device dcd ON
                        dcd.device_collection_id = dcr.device_collection_id
                LEFT JOIN Device USING (Device_Id) 
                LEFT JOIN Network_Interface NI USING (Device_ID) 
                LEFT JOIN Netblock NB USING (Netblock_id)
	WHERE
		device_collection_type IN ('HOTPants', 'HOTPants-app')
;


-- END Misc that does not apply to above


-- BEGIN Misc that does not apply to above
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS check_any_yes_no_1926994056;

ALTER TABLE network_interface ADD CONSTRAINT
CHECK_ANY_YES_NO_1926994056 CHECK (SHOULD_MONITOR IN ('Y', 'N', 'ANY'));

SELECT schema_support.rebuild_audit_tables('audit', 'jazzhands');
SELECT schema_support.reset_all_schema_table_sequences('jazzhands');
SELECT schema_support.reset_all_schema_table_sequences('audit');

DROP TRIGGER IF EXISTS trigger_audit_token_sequence ON token_sequence;

--
-- These should be noops and are used to make dumps less noisy because
-- constraints created by earlier versions of postgres have type overrides
-- spit out differently.
--
ALTER TABLE DNS_RECORD DROP CONSTRAINT IF EXISTS
	CKC_DNS_SRV_PROTOCOL_DNS_RECO;
ALTER TABLE DNS_RECORD
        ADD CONSTRAINT  CKC_DNS_SRV_PROTOCOL_DNS_RECO CHECK (DNS_SRV_PROTOCOL is null or (DNS_SRV_PROTOCOL in ('tcp','udp') and DNS_SRV_PROTOCOL = lower(DNS_SRV_PROTOCOL)));

ALTER TABLE KLOGIN_MCLASS DROP CONSTRAINT IF EXISTS
	CKC_INCLUDE_EXCLUDE_F_KLOGIN_M;
ALTER TABLE KLOGIN_MCLASS
        ADD CONSTRAINT  CKC_INCLUDE_EXCLUDE_F_KLOGIN_M CHECK (INCLUDE_EXCLUDE_FLAG in ('INCLUDE','EXCLUDE') and INCLUDE_EXCLUDE_FLAG = upper(INCLUDE_EXCLUDE_FLAG));

ALTER TABLE NETWORK_INTERFACE DROP CONSTRAINT IF EXISTS
	CKC_NETINT_PARENT_R_1604677531;
ALTER TABLE NETWORK_INTERFACE
        ADD CONSTRAINT  CKC_NETINT_PARENT_R_1604677531 CHECK (PARENT_RELATION_TYPE IN ('NONE', 'SUBINTERFACE', 'SECONDARY'));

ALTER TABLE PERSON DROP CONSTRAINT IF EXISTS
	Validation_Rule_1770_218378485;
ALTER TABLE PERSON
        ADD CONSTRAINT  Validation_Rule_1770_218378485 CHECK (SHIRT_SIZE is null or (SHIRT_SIZE in ('XS','S','M','L','XL','XXL','XXXL') and SHIRT_SIZE = upper(SHIRT_SIZE)));

ALTER TABLE PERSON DROP CONSTRAINT IF EXISTS
	Validation_Rule_177_1190387970;
ALTER TABLE PERSON
        ADD CONSTRAINT  Validation_Rule_177_1190387970 CHECK (PANT_SIZE is null or (PANT_SIZE in ('XS','S','M','L','XL','XXL','XXXL') and PANT_SIZE = upper(PANT_SIZE)));

ALTER TABLE PERSON_CONTACT DROP CONSTRAINT IF EXISTS
	CKC_CONTACT_PRIVACY_440865622;
ALTER TABLE PERSON_CONTACT
        ADD CONSTRAINT  CKC_CONTACT_PRIVACY_440865622 CHECK (PERSON_CONTACT_PRIVACY IN ('PRIVATE', 'PUBLIC', 'HIDDEN'));

ALTER TABLE RACK DROP CONSTRAINT IF EXISTS
	CKC_RACK_STYLE_RACK;
ALTER TABLE RACK
        ADD CONSTRAINT  CKC_RACK_STYLE_RACK CHECK (RACK_STYLE in ('RELAY','CABINET') and RACK_STYLE = upper(RACK_STYLE));

ALTER TABLE RACK_LOCATION DROP CONSTRAINT IF EXISTS
	CKC_RACK_SIDE_LOCATION;
ALTER TABLE RACK_LOCATION
        ADD CONSTRAINT  CKC_RACK_SIDE_LOCATION CHECK (RACK_SIDE in ('FRONT','BACK'));

ALTER TABLE SITE DROP CONSTRAINT IF EXISTS
	CKC_SITE_STATUS_SITE;
ALTER TABLE SITE
        ADD CONSTRAINT  CKC_SITE_STATUS_SITE CHECK (SITE_STATUS in ('ACTIVE','INACTIVE','OBSOLETE','PLANNED') and SITE_STATUS = upper(SITE_STATUS));

ALTER TABLE SLOT DROP CONSTRAINT IF EXISTS
	CKC_SLOT_SLOT_SIDE;
ALTER TABLE SLOT
        ADD CONSTRAINT  CKC_SLOT_SLOT_SIDE CHECK (SLOT_SIDE in ('FRONT','BACK'));

ALTER TABLE VAL_DNS_TYPE DROP CONSTRAINT IF EXISTS
	CKC_ID_TYPE_VAL_DNS_;
ALTER TABLE VAL_DNS_TYPE
        ADD CONSTRAINT  CKC_ID_TYPE_VAL_DNS_ CHECK (ID_TYPE IN ('ID', 'LINK', 'NON-ID', 'HIDDEN'));

ALTER TABLE VAL_NETBLOCK_COLLECTION_TYPE DROP CONSTRAINT IF EXISTS
	CHECK_ANY_YES_NO_nc_singaddr_r;
ALTER TABLE VAL_NETBLOCK_COLLECTION_TYPE
        ADD CONSTRAINT  CHECK_ANY_YES_NO_nc_singaddr_r CHECK (NETBLOCK_SINGLE_ADDR_RESTRICT IN ('Y', 'N', 'ANY'));


DROP TRIGGER IF EXISTS
	trigger_pgnotify_account_collection_account_token_changes_del
	ON account_collection_account;

--
-- tables renamed...
--
DROP FUNCTION IF EXISTS perform_audit_x509_certificate();

COMMENT ON TABLE device_type IS 'Conceptual device type.  This represents how it is typically referred to rather than a specific model number.  There may be many models (components) that are represented by one device type.';

DROP TRIGGER IF EXISTS trigger_ins_x509_certificate ON x509_certificate;
CREATE TRIGGER trigger_ins_x509_certificate
        INSTEAD OF INSERT ON x509_certificate
        FOR EACH ROW
        EXECUTE PROCEDURE ins_x509_certificate();
DROP TRIGGER IF EXISTS trigger_upd_x509_certificate ON x509_certificate;
CREATE TRIGGER trigger_upd_x509_certificate
        INSTEAD OF UPDATE ON x509_certificate
        FOR EACH ROW
        EXECUTE PROCEDURE upd_x509_certificate();
CREATE TRIGGER trigger_del_x509_certificate 
	INSTEAD OF DELETE ON x509_certificate 
	FOR EACH ROW EXECUTE 
	PROCEDURE del_x509_certificate();

--- view defaults
ALTER TABLE ONLY x509_certificate 
	ALTER COLUMN is_active SET DEFAULT 'Y'::bpchar;
ALTER TABLE ONLY x509_certificate 
	ALTER COLUMN is_certificate_authority SET DEFAULT 'N'::bpchar;



-- END Misc that does not apply to above


-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;
SELECT schema_support.end_maintenance();
select timeofday(), now();
