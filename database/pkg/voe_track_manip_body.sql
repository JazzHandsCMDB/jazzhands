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


create or replace package body voe_track_manip
IS
	GC_pkg_name CONSTANT USER_OBJECTS.OBJECT_NAME % TYPE := 
		'voe_track_manip';
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
	-- opens a voe track for adding packages.  returns the existing
	-- open one if its already in a pending state
	-------------------------------------------------------------------
	FUNCTION open_voe_track (
		in_name	voe_symbolic_track.symbolic_track_name%type,
		in_repo	voe_symbolic_track.sw_package_repository_id%type,
		in_newname voe_symbolic_track.symbolic_track_name%type
			DEFAULT NULL,
		in_prodstate voe.production_state%type
			DEFAULT 'production'
	) RETURN voe_symbolic_track.pending_voe_id%type
	IS
		voe	voe%rowtype;
		voesym	voe_symbolic_track%rowtype;
		pvoetyp	voe.voe_id%type;
		newname voe_symbolic_track.symbolic_track_name%type;
		prodstate voe.production_state%type;
	BEGIN
		BEGIN
			select	*
			  into	voesym
			  from	voe_symbolic_track
			 where	symbolic_track_name = in_name
			   and	sw_package_repository_id = in_repo;
		EXCEPTION when NO_DATA_FOUND then
			if(in_newname is NULL) THEN
				newname := in_name || '-' ||
				 	to_char ( time_util.epoch( sysdate ));
			ELSE
				newname := in_newname;
			END IF;

			pvoetyp := voe_manip_util.new_voe(newname,
				in_repo, in_prodstate);
			insert into voe_symbolic_track (
				SYMBOLIC_TRACK_NAME, ACTIVE_VOE_ID,
				PENDING_VOE_ID, UPGRADE_SEVERITY_THRESHOLD,
				SW_PACKAGE_REPOSITORY_ID
			) values (
				in_name, pvoetyp,
				pvoetyp, 'major',
				in_repo
			);
			return pvoetyp;
		END;

		if(voesym.PENDING_VOE_ID is not null) THEN
			return voesym.PENDING_VOE_ID;
		end if;


		select	*
		  into	voe
		  from	voe
		 where	voe_id = voesym.active_voe_id;

		-- ok, one doesn't exist, so clone

		--
		-- if name is not set, then come up with one by replacing the
		-- last numbers with a datestamp or tacking on a datestamp.
		--
		if(in_newname is NULL) THEN
			newname :=
				REGEXP_REPLACE(voe.voe_name,
					'-[[:digit:]]+$', '-' ||
					to_char ( time_util.epoch( sysdate )));
			if(newname = voe.voe_name) THEN
				newname :=
					voe.voe_name || '-' ||
					to_char ( time_util.epoch( sysdate ));
			end if;
		else
			newname := in_newname;
		end if;

		pvoetyp := voe_manip_util.new_copy_of_voe(
			voesym.ACTIVE_VOE_ID, newname);

		update voe_symbolic_track
		  set	pending_voe_id = pvoetyp
		 where	VOE_SYMBOLIC_TRACK_ID = voesym.VOE_SYMBOLIC_TRACK_ID;

		 return (pvoetyp);
	END;
	--end of procedure open_voe_track
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- opens a voe track for adding packages.  returns the existing
	-- open one if its already in a pending state
	-------------------------------------------------------------------
	PROCEDURE close_voe_track (
		in_name	voe_symbolic_track.symbolic_track_name%type,
		in_repo	voe_symbolic_track.sw_package_repository_id%type
	)
	IS
		voerel		voe_relation%rowtype;
		voesym		voe_symbolic_track%rowtype;
		severity	voe_relation.upgrade_severity%type;
		difftally	number;
		CURSOR old_voes ( in_related_id IN voe.voe_id%type) IS
			select	*
			 from	voe_relation
			 where	related_voe_id = in_related_id;
	BEGIN
		select	*
		  into	voesym
		  from	voe_symbolic_track
		 where	symbolic_track_name = in_name
		   and	sw_package_repository_id = in_repo;

		-- raise an exception that says that the symbolic track
		-- doesn't exist.

		--
		-- may actually want to throw an error.
		--
		if(voesym.pending_voe_id is NULL) THEN
			return;
		END IF;

		--
		-- this is a weird case
		--
		if(voesym.active_voe_id = voesym.pending_voe_id) THEN
			update	voe_symbolic_track
			   set	pending_voe_id = NULL
			 where	voe_symbolic_track_id = 
				voesym.voe_symbolic_track_id;
			return;
		END IF;

		--
		-- [XXX] a second version of the next query should probably 
		-- check to see if no changes happened at all and zap the
		-- pending voe without changing anything if so.
		--

		--
		-- figure out if any packages changed version
		--

		-- can just compare pk's instead
		select count(*) 
		  into	difftally
		  from  sw_package_release r1
			inner join voe_sw_package v1
				on v1.sw_package_release_id = 
					r1.sw_package_release_id 
			inner join sw_package_release r2
				on r1.sw_package_id = r2.sw_package_id
			inner join voe_sw_package v2
				on v2.sw_package_release_id = 
					r2.sw_package_release_id
		where   r1.sw_package_version != r2.sw_package_version
		 and    v1.voe_id = voesym.active_voe_id
		 and    v2.voe_id = voesym.pending_voe_id
		;
		if (difftally > 0) THEN
			severity := voesym.upgrade_severity_threshold;
		ELSE
			-- consider switching to a level 0 and not hardcoding
			severity := 'additiononly';
		END IF;

		dbms_output.put_line('severity is '|| severity);
		
		--
		--  insert a record to map the active to new pending.
		--
		insert into voe_relation
			(voe_id, related_voe_id, 
			 upgrade_severity, is_active)
		values
			(voesym.active_voe_id, voesym.pending_voe_id,
			 severity, 'Y')
		;

		-- XXX THIS IS WHAT MAKES vprac SLOW!!! XXX
		-- XXX we do not use the funcionality
		--
		-- save every record that currently points to active.
		-- OPEN old_voes(voesym.active_voe_id);
		-- LOOP
	 	--	FETCH old_voes INTO voerel;
	 	--	EXIT WHEN old_voes%NOTFOUND;
 
 		--	-- set all the records that point to the current active
 		--	-- as being inactive.  (words, words, words).
 		--	update	voe_relation
 		--	   set	is_active = 'N'
 		--	 where	voe_id = voerel.voe_id
 		--	   and 	related_voe_id = voerel.related_voe_id;

		--	--
		--	-- add a resplacement record 
		--	--
		--	insert into voe_relation (
		--		voe_id, related_voe_id, 
		--		upgrade_severity, is_active
		--	) values (
		--		voerel.voe_id, voesym.pending_voe_id, 
		--		voerel.upgrade_severity, 'Y'
		--	);
		--END LOOP;
		--LOSE old_voes;

		voe_manip_util.close_voe(voesym.pending_voe_id);
		--
		-- make the pending track the current track
		--
		update	voe_symbolic_track
		  set	active_voe_id = voesym.pending_voe_id,
			pending_voe_id = NULL
		 where	voe_symbolic_track_id = voesym.voe_symbolic_track_id;
	END;
	--end of procedure close_voe_track
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- creates a new symbolic track for a given repository.
	-- if in_clone_voe_id is not set, it doesn't clone any voes, just
	-- creates a new one.
	--
	-- in any case, leaves active and pending pointing to the same
	-- voe, which is marked as open.
	-- 
	-------------------------------------------------------------------
	FUNCTION add_voe_symbolic_track (
		in_symbolic_track_name	voe_symbolic_track.SYMBOLIC_TRACK_NAME%type,
		in_clone_voe_id			VOE.voe_id%type,
		in_threshold			voe_symbolic_track.UPGRADE_SEVERITY_THRESHOLD%type,
		in_sw_package_repository_id	sw_package_repository.sw_package_repository_id%type,
		in_production_state		VOE.production_state%type
	) RETURN voe_symbolic_track.pending_voe_id%type
	IS
		v_voe_id		VOE.voe_id%type;
		v_st_id			voe_symbolic_track.voe_symbolic_track_id%type;
	BEGIN
		insert into VOE
			(voe_name, 
			 voe_state, sw_package_repository_id, production_state)
		values
			(in_symbolic_track_name || '-0',
			 'open', in_sw_package_repository_id, in_production_state)
		returning voe_id into v_voe_id;

		if(in_clone_voe_id is not null) then
			insert into voe_sw_package
				(voe_id, SW_PACKAGE_RELEASE_ID)
				select	v_voe_id, SW_PACKAGE_RELEASE_ID
			  	  from	voe_sw_package
				 where	voe_id = in_clone_voe_id
			;
		end if;

		insert into voe_symbolic_track (
			SYMBOLIC_TRACK_NAME,
			ACTIVE_VOE_ID,
			PENDING_VOE_ID,
			UPGRADE_SEVERITY_THRESHOLD,
			SW_PACKAGE_REPOSITORY_ID
		) values (
			in_symbolic_track_name,
			v_voe_id,
			v_voe_id,
			in_threshold,
			in_sw_package_repository_id
		) returning voe_symbolic_track_id into v_st_id;

		return v_st_id;
	END;
	-- end of add_voe_symbolic_track
	-------------------------------------------------------------------

end;
/
show errors;
