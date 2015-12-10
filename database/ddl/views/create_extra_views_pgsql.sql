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
--
--
--
-- $Id$
--

-- XXX - Not sure if these two are still needed.  Leaving out until it is
-- \ir accountview.sql
-- \ir sysuserphoneview.sql

-- not sure that we need these anymore.
-- \ir create_v_login_changes.sql
-- \ir create_v_user_deletions.sql

\ir pgsql/create_v_netblock_hier.sql

-- XXX - not sure if this is still needed.  Leaving out until it is
-- \ir create_v_user_extract.sql 
\ir pgsql/create_v_property.sql
\ir pgsql/create_v_nblk_coll_netblock_expanded.sql
\ir pgsql/create_v_person_company_expanded.sql
\ir pgsql/create_v_department_company_expanded.sql
-- \ir pgsql/create_v_acct_collection_user_expanded_detail.sql

-- XXX needs to be ported
-- \ir create_v_user_prop_exp_nomv.sql
\ir create_token_views.sql
-- \ir pgsql/create_v_acct_collection_user_expanded.sql
-- not sure that we need these anymore.
-- \ir create_audit_views.sql

-- XXX - not sure if this is still needed.  Leaving out until it is.
-- \ir create_v_limited_users.sql

\ir pgsql/create_v_device_slots.sql
\ir pgsql/create_v_device_components.sql

\ir create_physical_port.sql
\ir create_layer1_connection.sql
\ir create_v_l1_all_physical_ports.sql

\ir create_device_power_connection.sql
\ir create_device_power_interface.sql

-- XXX these need to be ported
-- \ir create_v_joined_acct_collection_user_detail.sql
-- this needs to be rethought...
\ir create_v_device_coll_device_expanded.sql
\ir pgsql/create_v_device_coll_hier_detail.sql
-- \ir create_v_device_col_acct_collection_expanded.sql
-- \ir create_mv_account_last_auth.sql
-- \ir pgsql/create_mv_acct_collection_user_expanded_detail.sql 
-- \ir create_v_user_prop_expanded.sql 
-- \ir pgsql/create_mv_acct_collection_user_expanded.sql
-- NOTE, some of these above may have been ported; need to dig into. XXX
\ir pgsql/create_v_account_collection_account.sql
\ir pgsql/create_v_account_collection_expanded.sql
\ir pgsql/create_v_acct_coll_expanded_detail.sql
\ir pgsql/create_v_acct_coll_expanded.sql
\ir pgsql/create_v_acct_coll_acct_expanded.sql
\ir pgsql/create_v_acct_coll_acct_expanded_detail.sql
\ir create_v_dev_col_user_prop_expanded.sql
\ir pgsql/create_v_acct_coll_prop_expanded.sql

\ir pgsql/create_v_device_coll_device_expanded.sql

\ir pgsql/create_v_account_collection_expanded.sql

\ir pgsql/create_v_application_role.sql

\ir pgsql/create_v_company_hier.sql
\ir pgsql/create_v_site_netblock_expanded.sql
\ir pgsql/create_v_physical_connection.sql

\ir create_v_device_col_acct_col_expanded.sql
\ir create_v_corp_family_account.sql

\ir pgsql/create_v_person_company_hier.sql

-- possibly to replace v_device_col_acct_col_expanded
\ir create_v_device_col_acct_col_unixlogin.sql
\ir create_v_device_col_acct_col_unixgroup.sql

-- passwd file generation
\ir pgsql/create_v_device_collection_account_ssh_key.sql
\ir pgsql/create_v_unix_mclass_settings.sql

\ir pgsql/create_v_unix_account_overrides.sql
\ir pgsql/create_v_device_col_account_cart.sql
\ir pgsql/create_v_unix_passwd_mappings.sql

-- group file generation
\ir pgsql/create_v_unix_group_overrides.sql
\ir pgsql/create_v_device_col_account_col_cart.sql
\ir pgsql/create_v_unix_group_mappings.sql

-- dns
\ir create_v_dns_changes_pending.sql

-- logical volumes
\ir pgsql/create_v_lv_hier.sql
\ir pgsql/create_v_component_hier.sql

\ir create_v_account_manager_map.sql
\ir approval/create_approval_views.sql
-- not clear if this belongs in the approval views or not.  probably?
\ir pgsql/create_v_approval_instance_step_expanded.sql

-- hotpants
\i create_v_hotpants_device_collection.sql
\i create_v_hotpants_token.sql
