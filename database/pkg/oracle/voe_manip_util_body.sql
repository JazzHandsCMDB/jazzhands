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

create or replace package body voe_manip_util
IS
	GC_pkg_name CONSTANT USER_OBJECTS.OBJECT_NAME % TYPE := 
		'voe_manip_util';
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
	-- given a voe, generates a copy
	-------------------------------------------------------------------
	FUNCTION new_copy_of_voe (
		in_version 	voe.voe_id%type,
		in_name  	voe.voe_name%type
	) RETURN voe.voe_id%type

	IS
		oldvoe		voe%rowtype;
		newvoeid	voe.voe_id%type;
	BEGIN
		select	* 
		  into	oldvoe
		  from	voe
		 where	voe_id = in_version;

		--
		-- create a new ID based on this one
		--
		newvoeid := new_voe(in_name,
			oldvoe.sw_package_repository_id,
			oldvoe.production_state);

		--
		-- copy packages from the source package into the new one
		--
		insert into voe_sw_package (voe_id, sw_package_release_id)
			select newvoeid, 
				sw_package_release_id
			  from	voe_sw_package
			  where	voe_id 
				= oldvoe.voe_id
		;
		return newvoeid;
	END;
	--end of function new_copy_of_voe
	-------------------------------------------------------------------
	
	-------------------------------------------------------------------
	-- creates a voe
	-------------------------------------------------------------------
	FUNCTION new_voe (
		in_name	 voe.voe_name%type,
		in_swpkgrep voe.sw_package_repository_id%type,
		in_prodstate voe.production_state%type
	) RETURN voe.voe_id%type

	IS
		new_voeid	voe.voe_id%type;
	BEGIN
		insert into voe (
			voe_name, voe_state,
			sw_package_repository_id,
			production_state
		) values (
			in_name, 'open',
			in_swpkgrep,
			in_prodstate
		) returning VOE_ID into new_voeid;

		return new_voeid;
	END;
	--end of function new_voe
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- adds a package to an OS if that's ok.
	-------------------------------------------------------------------
	PROCEDURE add_pkg_to_voe (
		in_voeverid	voe.voe_id%type,
		in_swpkgrid	sw_package_release.sw_package_release_id%type
	)
	IS
		oldvoe		voe%rowtype;
		oldpkgrelid	sw_package_release.sw_package_release_id%type;
		v_std_object_name   VARCHAR2(60) := GC_pkg_name || '.add_pkg_to_voe';
	BEGIN
		select	* 
		  into	oldvoe
		  from	voe
		 where	voe_id = in_voeverid;

		BEGIN
			-- let us hope the optimizer reduces the suck.
			SELECT	spr.sw_package_release_id
			 INTO	oldpkgrelid
			  FROM	sw_package_release spr
				inner join voe_sw_package voep
					on voep.sw_package_release_id =
						spr.sw_package_release_id
			 WHERE	voep.voe_id = in_voeverid
			   AND	spr.sw_package_id =
				(select sw_package_id
				   from	sw_package_release
				  where	sw_package_release_id = in_swpkgrid
				)
			   AND	spr.processor_architecture =
				(select processor_architecture
				   from	sw_package_release
				  where	sw_package_release_id = in_swpkgrid
				)
			;
			
		EXCEPTION when NO_DATA_FOUND THEN
			oldpkgrelid := NULL;
		END;

		if oldpkgrelid is not NULL THEN
			if oldpkgrelid != in_swpkgrid THEN
				if oldvoe.VOE_STATE != 'open' THEN
					G_err_num := global_errors.ERRNUM_PKGCONFLICT;
					G_err_msg := global_errors.ERRMSG_PKGCONFLICT;
					global_util.debug_msg(v_std_object_name || 
						':(' || G_err_num || ') "' || G_err_msg || '"');
					global_errors.log_error(G_err_num, v_std_object_name, 
						G_err_msg);
					raise_application_error(global_errors.ERRNUM_PKGCONFLICT, global_errors.ERRMSG_PKGCONFLICT);
				end if;
			end if;

			delete	from voe_sw_package
			 where	voe_id = in_voeverid
			   and	sw_package_release_id = oldpkgrelid;
		end if;

		insert into voe_sw_package
			(voe_id,sw_package_release_id)
		values
			(in_voeverid, in_swpkgrid);
	END;
	--end of function add_pkg_to_voe
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- closes a composite operating system
	-------------------------------------------------------------------
	PROCEDURE close_voe (
		in_voeverid	voe.voe_id%type
	)
	IS
		oldvoe		voe%rowtype;
		v_std_object_name   VARCHAR2(60) := GC_pkg_name || '.close_voe';
	BEGIN
		select	* 
		  into	oldvoe
		  from	voe
		 where	voe_id = in_voeverid;

		if(oldvoe.voe_state = 'closed') THEN
			return;
		elsif(oldvoe.voe_state != 'open') THEN
			G_err_num := global_errors.ERRNUM_PKGREPNOTOPEN;
			G_err_msg := global_errors.ERRMSG_PKGREPNOTOPEN;
			global_util.debug_msg(v_std_object_name || 
				':(' || G_err_num || ') "' || G_err_msg || '"');
			global_errors.log_error(G_err_num, v_std_object_name, 
				G_err_msg);
			raise_application_error(global_errors.ERRNUM_PKGREPNOTOPEN, global_errors.ERRMSG_PKGCONFLICT);
		end if;

		update voe set voe_state = 'closed'
		 where	voe_id = in_voeverid;
	END;
	-- end of function add_pkg_to_voe
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- adds a package to the database
	-------------------------------------------------------------------
	FUNCTION add_sw_pkg_revision (
		in_sw_package_name
			sw_package.sw_package_name%type,
		in_sw_package_desc
			sw_package.description%type DEFAULT NULL,
		in_version
			sw_package_release.sw_package_version%type,
		in_sw_package_format
			sw_package_release.sw_package_format%type,
		in_system_user_id
			sw_package_release.creation_system_user_id%type,
		in_uploading_principal
			sw_package_release.uploading_principal%type,
		in_sw_package_repository_id
			sw_package_release.sw_package_repository_id%type,
		in_package_size
			sw_package_release.package_size%type,
		in_pathname
			sw_package_release.pathname%type,
		in_md5sum
			sw_package_release.md5sum%type,
		in_proc_architecture  
			sw_package_release.processor_architecture%type,
		in_production_state
			sw_package_release.production_state%type,
		in_installed_size
			sw_package_release.INSTALLED_PACKAGE_SIZE_KB%type
				DEFAULT NULL
	) RETURN sw_package_release.sw_package_release_id%type
	IS
		sw_pkg		sw_package%rowtype;
		swpkgrel_id	sw_package_release.sw_package_release_id%type;
		found		boolean;
	BEGIN
		--
		-- find or create a sw_package
		--
		BEGIN
			select	*
			  into	sw_pkg
			  from	sw_package
			 where	lower(sw_package_name) = lower(in_sw_package_name);
			found := true;
		EXCEPTION when NO_DATA_FOUND THEN
			found := false;
			insert into sw_package
				(sw_package_name,description,sw_package_type)
			values
				(in_sw_package_name,in_sw_package_desc, 'local');
		END;

		IF (found = false) THEN
			BEGIN
				select	*
				  into	sw_pkg
				  from	sw_package
				 where	lower(sw_package_name) = lower(in_sw_package_name);
			-- EXCEPTION when NO_DATA_FOUND THEN
			END;
		end if;

		--
		-- check to see if the names don't match, and if they are
		-- a mixed case name.  Update to match new case
		-- 
		IF sw_pkg.sw_package_name != in_sw_package_name THEN
			if lower(in_sw_package_name) != in_sw_package_name THEN
				update	sw_package
				   set	sw_package_name = in_sw_package_name
				 where	sw_package_id = sw_pkg.sw_package_id;
			END IF;
		END IF;

		--
		-- see if description needs to be updated
		--
		if sw_pkg.description != in_sw_package_desc AND
			in_sw_package_desc is not NULL THEN
			update sw_package
			   set	description = in_sw_package_desc
			 where	sw_package_id = sw_pkg.sw_package_id;
		END IF;


		--
		-- insert new record
		--
		insert into sw_package_release
			(
				sw_package_id,
				sw_package_version,
				instantiation_date,
				sw_package_format,
				creation_system_user_id,
				uploading_principal,
				sw_package_repository_id,
				package_size,
				pathname,
				md5sum,
				processor_architecture,
				production_state,
				installed_package_size_kb
			) values (
				sw_pkg.sw_package_id,
				in_version,
				sysdate,
				in_sw_package_format,
				in_system_user_id,
				in_uploading_principal,
				in_sw_package_repository_id,
				in_package_size,
				in_pathname,
				in_md5sum,
				in_proc_architecture,
				in_production_state,
				in_installed_size
			) returning SW_PACKAGE_RELEASE_ID into swpkgrel_id;

		return swpkgrel_id;
	END;
	--end of add_sw_pkg_revision
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- adds a relationship
	-------------------------------------------------------------------
	PROCEDURE add_pkg_relation (
		in_sw_pkg_rep_id
			sw_package_relation.sw_package_release_id%type,
		in_relate_sw_pkg_id
			sw_package_relation.related_sw_package_id%type,
		pkg_relation_type
			sw_package_relation.package_relation_type%type
			DEFAULT 'depends',
		restriction
			sw_package_relation.relation_restriction%type
			DEFAULT NULL
	)
	IS
	BEGIN
		insert into sw_package_relation
			(
				SW_PACKAGE_RELEASE_ID,
				RELATED_SW_PACKAGE_ID,
				PACKAGE_RELATION_TYPE,
				RELATION_RESTRICTION
			) values (
				in_sw_pkg_rep_id,
				in_relate_sw_pkg_id,
				pkg_relation_type,
				restriction
			);
	END;
	--end of add_pkg_relation
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- sets the production state for a package release
	-------------------------------------------------------------------
	PROCEDURE set_pkgrel_prodstate (
		in_sw_pkg_rel_id 
			sw_package_release.sw_package_release_id%type,
		in_sw_pkg_prodstate 
			sw_package_release.production_state%type
	)
	IS
	BEGIN
		update	sw_package_release
		   set	production_state = in_sw_pkg_prodstate
		 where	sw_package_release_id = in_sw_pkg_rel_id;
	END;
	-- end of set_pkgrel_prodstate
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- removes traces of a package from the db.  This should almost
	-- always be avoided.
	-------------------------------------------------------------------
	PROCEDURE balefire_sw_package_relation (
		in_sw_pkg_rel_id 
			sw_package_release.sw_package_release_id%type
	)
	IS
	BEGIN
		delete	from voe_sw_package
		where	sw_package_release_id = in_sw_pkg_rel_id;
		delete	from sw_package_relation
		where	sw_package_release_id = in_sw_pkg_rel_id;
		delete	from sw_package_release
		where	sw_package_release_id = in_sw_pkg_rel_id;
	END;
	-- end of balefire_sw_package_relation
	-------------------------------------------------------------------
end;
/
show errors;
