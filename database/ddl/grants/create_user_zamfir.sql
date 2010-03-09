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

Prompt 'Enter new password for ap_zamfir: '

create user ap_zamfir identified by &1;

create role zamfir_role;

grant create session to zamfir_role;

grant execute		on jazzhands.ip_manip to zamfir_role;
grant select		on jazzhands.device to zamfir_role;
grant select		on jazzhands.device_type to zamfir_role;
grant select		on jazzhands.device_function to zamfir_role;
grant select		on jazzhands.network_interface to zamfir_role;
grant select		on jazzhands.netblock to zamfir_role;
grant select		on jazzhands.operating_system to zamfir_role;


grant zamfir_role to ap_zamfir;

create synonym ap_zamfir.ip_manip for jazzhands.ip_manip;
create synonym ap_zamfir.device for jazzhands.device;
create synonym ap_zamfir.device_type for jazzhands.device_type;
create synonym ap_zamfir.device_function for jazzhands.device_function;
create synonym ap_zamfir.network_interface for jazzhands.network_interface;
create synonym ap_zamfir.netblock for jazzhands.netblock;
create synonym ap_zamfir.operating_system for jazzhands.operating_system;
