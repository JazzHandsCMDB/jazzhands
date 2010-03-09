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

------------------------------------------------------------------
-- Provide Helpful functions for dealing with legacy voe tracks
------------------------------------------------------------------
-- $Id$

create or replace package voe_track_manip
as 
	GC_spec_id_tag       CONSTANT global_types.id_tag_var_type:='$Id$';

	FUNCTION id_tag RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;

	FUNCTION open_voe_track (
		in_name voe_symbolic_track.symbolic_track_name%type,
		in_repo voe_symbolic_track.sw_package_repository_id%type,
		in_newname voe_symbolic_track.symbolic_track_name%type
			DEFAULT NULL,
		in_prodstate voe.production_state%type
			DEFAULT 'production'
	) RETURN voe_symbolic_track.pending_voe_id%type;
	PROCEDURE close_voe_track (
		in_name voe_symbolic_track.symbolic_track_name%type,
		in_repo voe_symbolic_track.sw_package_repository_id%type
	);
	FUNCTION add_voe_symbolic_track (
		in_symbolic_track_name	voe_symbolic_track.SYMBOLIC_TRACK_NAME%type,
		in_clone_voe_id			VOE.voe_id%type,
		in_threshold			voe_symbolic_track.UPGRADE_SEVERITY_THRESHOLD%type,
		in_sw_package_repository_id	sw_package_repository.sw_package_repository_id%type,
		in_production_state		VOE.production_state%type

	) RETURN voe_symbolic_track.pending_voe_id%type;
end;
/
show errors;
/
