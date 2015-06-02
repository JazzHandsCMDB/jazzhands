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
-- This query returns what can become a passwd entry for a given mclass,
-- applying all the various ways for mclass properties to tweak behavior
--
-- This relies on v_device_col_account_cart which limits the responses to
-- just mclasses/accounts mapped through the UnixLogin property
--
--
create or replace view v_unix_passwd_mappings AS
WITH  passtype AS (
	SELECT ap.account_id, ap.password, ap.expire_time, ap.change_time,
	subq.* FROM
	(
		SELECT	dchd.device_collection_id,
			p.property_value_password_type as password_type,
				row_number() OVER (partition by
					dchd.device_collection_id)  as ord
		FROM	v_property p
				INNER JOIN v_device_coll_hier_detail dchd
					ON dchd.parent_device_collection_id =
						p.device_collection_id
		WHERE
				p.property_name = 'UnixPwType'
		AND		p.property_type = 'MclassUnixProp'
	) subq 
			INNER JOIN account_password ap USING (password_type)
			INNER JOIN account_unix_info a USING (account_id)
	WHERE ord = 1 
), accts as (
	SELECT a.*, aui.unix_uid, aui.unix_group_acct_collection_id,
		aui.shell, aui.default_home
	FROM account a
		INNER JOIN account_unix_info aui using (account_id)
		INNER JOIN val_person_status vps
			ON a.account_status = vps.person_status
	WHERE vps.is_disabled = 'N'
), extra_groups AS (
	SELECT	device_collection_id, acae.account_id,
			array_agg(ac.account_collection_name) as group_names
	FROM	v_property p
			INNER JOIN device_collection dc USING (device_collection_id)
			INNER JOIN account_collection ac USING (account_collection_id)
			INNER JOIN account_collection pac ON
				pac.account_collection_id = p.property_value_account_coll_id
			INNER JOIN  v_acct_coll_acct_expanded acae ON
				pac.account_collection_id = acae.account_collection_id
	WHERE
			p.property_type = 'MclassUnixProp'
	AND		p.property_name = 'UnixGroupMemberOverride'
	AND		dc.device_collection_type != 'mclass'
	GROUP BY device_collection_id, acae.account_id
)
select
	device_collection_id, account_id, login, crypt,
	unix_uid,
	unix_group_name,
	regexp_replace(gecos, ' +', ' ', 'g') AS gecos,
	regexp_replace(
		CASE
			WHEN forcehome IS NOT NULL and forcehome ~ '/$' THEN
				concat(forcehome, login)
			WHEN home IS NOT NULL and home ~ '^/' THEN
				home
			WHEN hometype = 'generic' THEN
				concat( coalesce(homeplace, '/home'), '/', 'generic')
			WHEN home IS NOT NULL and home ~ '/$' THEN
				concat(home, '/', login)
			WHEN homeplace IS NOT NULL and homeplace ~ '/$' THEN
				concat(homeplace, '/', login)
			ELSE concat(coalesce(homeplace, '/home'), '/', login)
		END, '/+', '/', 'g') as home,
	shell, ssh_public_key,
	setting,
	mclass_setting,
	group_names as extra_groups
FROM
(
SELECT	o.device_collection_id,
		a.account_id, login,
		coalesce(setting[(select i + 1
			from generate_subscripts(setting, 1) as i
			where setting[i] = 'ForceCrypt')]::text, (
				CASE WHEN (expire_time is not NULL AND now() < expire_time) OR
						now() - change_time < (
								concat(coalesce((select property_value
									from v_property where property_type='Defaults'
										and property_name='_maxpasswdlife')::text,
								 90::text)::text, 'days')::text)::interval
					THEN password
				END
			), '*') as crypt,
		coalesce(setting[(select i + 1
			from generate_subscripts(setting, 1) as i
			where setting[i] = 'ForceUserUID')]::integer, unix_uid) as unix_uid,
		coalesce(setting[(select i + 1
			from generate_subscripts(setting, 1) as i
			where setting[i] = 'ForceUserGroup')]::varchar(255), 
				ugac.account_collection_name) AS unix_group_name,
		CASE WHEN a.description IS NOT NULL THEN a.description
			ELSE concat(coalesce(preferred_first_name, first_name), ' ',
				case WHEN middle_name is NOT NULL AND
					length(middle_name) = 1 THEN concat(middle_name,'.')
				ELSE middle_name END, ' ',
				coalesce(preferred_last_name, last_name))
			END as gecos,
		coalesce(setting[(select i + 1
			from generate_subscripts(setting, 1) as i
			where setting[i] = 'ForceHome')], default_home) as home,
		coalesce(setting[(select i + 1
			from generate_subscripts(setting, 1) as i
			where setting[i] = 'ForceShell')], shell) as shell,
		o.setting,
		mcs.mclass_setting,
		setting[(select i + 1
			from generate_subscripts(setting, 1) as i
			where setting[i] = 'ForceHome')] as forcehome,
		mclass_setting[(select i + 1
			from generate_subscripts(mcs.mclass_setting, 1) as i
			where mcs.mclass_setting[i] = 'HomePlace')] as homeplace,
		mclass_setting[(select i + 1
			from generate_subscripts(mcs.mclass_setting, 1) as i
			where mcs.mclass_setting[i] = 'UnixHomeType')] as hometype,
		ssh_public_key,
		extra_groups.group_names
FROM	accts a
			JOIN v_device_col_account_cart o using (account_id)
			JOIN device_collection dc USING (device_collection_id)
			JOIN person p USING (person_id)
			JOIN unix_group ug on (a.unix_group_acct_collection_id
				= ug.account_collection_id)
			JOIN account_collection ugac
				on (ugac.account_collection_id = ug.account_collection_id)
			LEFT JOIN extra_groups USING (device_collection_id, account_id)
			LEFT JOIN v_device_collection_account_ssh_key ssh
				ON (a.account_id = ssh.account_id  AND
					(ssh.device_collection_id is NULL
						or ssh.device_collection_id =
							o.device_collection_id ))
			LEFT JOIN v_unix_mclass_settings mcs
				ON mcs.device_collection_id = dc.device_collection_id
			LEFT JOIN passtype pwt
				ON o.device_collection_id = pwt.device_collection_id
				AND a.account_id = pwt.account_id
) s
order by device_collection_id, account_id
;
