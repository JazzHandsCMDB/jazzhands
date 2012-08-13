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

\i accountview.sql
\i sysuserphoneview.sql
-- not sure that we need these anymore.
-- \i create_v_login_changes.sql
-- \i create_v_user_deletions.sql

\i pgsql/create_v_netblock_hier.sql
\i create_v_user_extract.sql 
\i pgsql/create_v_property.sql
\i pgsql/create_v_nblk_coll_netblock_expanded.sql
\i pgsql/create_v_person_company_expanded.sql
\i pgsql/create_v_department_company_expanded.sql
-- \i pgsql/create_v_acct_collection_user_expanded_detail.sql

-- XXX needs to be ported
-- \i create_v_user_prop_exp_nomv.sql
\i create_token_views.sql
-- \i pgsql/create_v_acct_collection_user_expanded.sql
-- not sure that we need these anymore.
-- \i create_audit_views.sql

\i create_v_limited_users.sql
\i create_v_l1_all_physical_ports.sql

-- XXX these need to be ported
-- \i create_v_joined_acct_collection_user_detail.sql
-- \i pgsql/create_v_device_coll_hier_detail.sql
-- \i create_v_device_col_acct_collection_expanded.sql
-- \i create_v_dev_col_user_prop_expanded.sql
-- \i create_mv_account_last_auth.sql
-- \i pgsql/create_mv_acct_collection_user_expanded_detail.sql 
-- \i create_v_user_prop_expanded.sql 
-- \i pgsql/create_mv_acct_collection_user_expanded.sql
-- NOTE, some of these above may have been ported; need to dig into. XXX
\i pgsql/create_v_account_collection_account.sql
\i pgsql/create_v_account_collection_expanded.sql
\i pgsql/create_v_acct_coll_expanded_detail.sql
\i pgsql/create_v_acct_coll_expanded.sql
\i pgsql/create_v_acct_coll_acct_expanded.sql
\i pgsql/create_v_acct_coll_acct_expanded_detail.sql
\i pgsql/create_v_acct_coll_prop_expanded.sql

\i pgsql/create_v_account_collection_expanded.sql

\i pgsql/create_v_application_role.sql

