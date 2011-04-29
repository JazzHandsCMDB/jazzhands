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
 * $HeadURL$
 */

create or replace package body appgroup_util
IS
        GC_spec_id_tag       CONSTANT global_types.id_tag_var_type:='$Id$';

        GC_pkg_name CONSTANT USER_OBJECTS.OBJECT_NAME % TYPE :=
                'appgroup_util';
        G_err_num NUMBER;
        G_err_msg VARCHAR2(200);

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

	-------------------------------------------------------------------
	-- setos up power ports for a device if they are not there.
	-------------------------------------------------------------------
	PROCEDURE add_role (
		p_device_id 		device.device_Id%type,
		p_device_collection_id 	
				device_collection.device_collection_id%type
	)
	IS
		v_dc_id	device_collection.device_collection_id%type;
		v_std_object_name	VARCHAR2(60) 
			:= GC_pkg_name || '.add_role';
	BEGIN
		BEGIN
			select	device_collection_id
			  into	v_dc_id
			  from	device_collection
			  where	device_collection_id = p_device_collection_id
			  and	device_collection_type = 'appgroup';
		EXCEPTION when NO_DATA_FOUND THEN
			G_err_num := global_errors.ERRNUM_APPGROUP_BADTYPE;
			G_err_msg := global_errors.ERRMSG_APPGROUP_BADTYPE;
			global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
			raise_application_error(G_err_num, G_err_msg);
		END;

		-- insert the device into the entire hierarchy but exclude
		-- membership that is already assigned
		insert into device_collection_member
		(
			device_id, device_collection_id
		)
			select p_device_id, device_collection_id
			 from	device_collection
			 where	device_collection_type = 'appgroup'
			  and	(
					 device_collection_id in (
				select	parent_device_collection_id
 				  from	device_collection_hier
 				connect by prior parent_device_collection_id =
		 				device_collection_id   
		 			start with device_collection_id = p_device_collection_id 
		 			) or device_collection_id = p_device_collection_id
			) and device_collection_id not in
				(select device_collection_id
				  from	device_collection_member
				where	device_id = p_device_id
				);
	END;

	PROCEDURE remove_role (
		p_device_id 		device.device_Id%type,
		p_device_collection_id 	
				device_collection.device_collection_id%type
	)
	IS
		v_dc_id	device_collection.device_collection_id%type;
		v_std_object_name	VARCHAR2(60) 
			:= GC_pkg_name || '.remove_role';
	BEGIN
		BEGIN
			select	device_collection_id
			  into	v_dc_id
			  from	device_collection
			  where	device_collection_id = p_device_collection_id
			  and	device_collection_type = 'appgroup';
		EXCEPTION when NO_DATA_FOUND THEN
			G_err_num := global_errors.ERRNUM_APPGROUP_BADTYPE;
			G_err_msg := global_errors.ERRMSG_APPGROUP_BADTYPE;
			global_errors.log_error(G_err_num, v_std_object_name, G_err_msg);
			raise_application_error(G_err_num, G_err_msg);
		END;

		delete from device_collection_member
		where 
			device_id = p_device_id
			and (
					-- get the entire hierarchy rooted at the passed in
					-- device_collection_id as candidates to remove
					device_collection_id in 
					(
						select parent_device_collection_id
						 from   device_collection_hier
						connect by prior parent_device_collection_id =
								device_collection_id  
						start with device_collection_id = p_device_collection_id
					) 
					or device_collection_id = p_device_collection_id 
				)
			-- essentially, all the other device_collections rooted at
			-- a leaf (something that does not serve as a 
			-- parent_device_collection_id, is of type appgroup, and is
			-- not the one we are trying to remove the device from.
			and device_collection_id not in
				(
					select	parent_device_collection_id
					 from	device_collection_hier
						connect by prior parent_device_collection_id =
								device_collection_id
						start with device_collection_id in 
						(
							select	dc.device_collection_Id
						  	  from	device_collection dc
									left join device_collection_member dm 
										ON dm.device_collection_id = 
											dc.device_collection_id
						     where	dc.device_collection_type = 'appgroup'
						       and	dc.device_collection_Id 
										!= p_device_collection_id
						  	   and	dm.device_id = p_device_id  
						  	   and	dc.device_collection_id not in
									(select parent_device_collection_id
							  		 from  device_collection_hier
									)
						)
				)
			;
	END;
end;
/
