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
/*
 * $Id$
 */

create or replace package body device_utils
IS
	-------------------------------------------------------------------
	-- returns the Id tag for CM
	-------------------------------------------------------------------
	FUNCTION id_tag
	RETURN VARCHAR2
	IS
	BEGIN
     		RETURN('<-- $Id$ -->');
	END;
	--end of procedure id_tag
	-------------------------------------------------------------------
	PROCEDURE retire_device_ancillary (
		in_Device_id device.device_id%type
	)
	IS
		v_loc_id	location.location_id%type;
	BEGIN
		delete from device_collection_member where device_id = in_Device_id;
		delete from device_function where device_id = in_Device_id;
		delete from snmp_commstr where device_id = in_Device_id;

		select	location_id
		  into	v_loc_id
		  from	device
		 where	device_id = in_Device_id;

		IF v_loc_id is not NULL  THEN
			update device set location_Id = NULL where device_id = in_device_id;
			delete from location where location_id = v_loc_id;
		END IF;
	END;
	--end of retire_device_ancillary id_tag
	-------------------------------------------------------------------

end;
/
show errors;
