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

Prompt 'Enter new password for ap_stab_stats: '

create user ap_stab_stats identified by &1;

create role stab_stats_role;

grant create session to stab_stats_role;

grant execute 			on jazzhands.ip_manip to stab_stats_role;

grant select			on jazzhands.device_function to stab_stats_role;
grant select			on jazzhands.val_device_function_type to stab_stats_role;
grant select			on jazzhands.device_collection_device to stab_stats_role;
grant select			on jazzhands.device_collection to stab_stats_role;
grant select			on jazzhands.device to stab_stats_role;
grant select			on jazzhands.composite_os_version to stab_stats_role;
grant insert,update,select	on jazzhands_stats.dev_function_history 
					to stab_stats_role;
grant insert,update,select	on jazzhands_stats.dev_function_mclass_history 
					to stab_stats_role;
grant insert,update,select	on jazzhands_stats.dev_baseline_history 
					to stab_stats_role;

grant stab_stats_role to ap_stab_stats;

create synonym ap_stab_stats.device_function for jazzhands.device_function;
create synonym ap_stab_stats.val_device_function_type for jazzhands.val_device_function_type;
create synonym ap_stab_stats.device_collection_device for jazzhands.device_collection_device;
create synonym ap_stab_stats.device_collection for jazzhands.device_collection;
create synonym ap_stab_stats.composite_os_version for jazzhands.composite_os_version;
create synonym ap_stab_stats.device for jazzhands.device;
create synonym ap_stab_stats.dev_function_history for 
	jazzhands_stats.dev_function_history;
create synonym ap_stab_stats.dev_function_mclass_history for 
	jazzhands_stats.dev_function_mclass_history;
create synonym ap_stab_stats.dev_baseline_history for 
	jazzhands_stats.dev_baseline_history;
