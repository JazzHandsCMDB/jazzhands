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

---------------------------------------------------------------------------
-- Provide Helpful functions for dealing with VOEs
---------------------------------------------------------------------------
-- $Id$

create or replace package voe_manip_util
as 
	GC_spec_id_tag       CONSTANT global_types.id_tag_var_type:='$Id$';

	FUNCTION id_tag RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;

	FUNCTION new_copy_of_voe (
		in_version voe.voe_id%type,
		in_name  voe.voe_name%type
	) RETURN voe.voe_id%type;
	FUNCTION new_voe (
		in_name	 voe.voe_name%type,
		in_swpkgrep voe.sw_package_repository_id%type,
		in_prodstate voe.production_state%type
	) RETURN voe.voe_id%type;
	PROCEDURE add_pkg_to_voe (
		in_voeverid	voe.voe_id%type,
		in_swpkgrid	sw_package_release.sw_package_release_id%type
	);
	PROCEDURE close_voe (
		in_voeverid	voe.voe_id%type
	);
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
	) RETURN sw_package_release.sw_package_release_id%type;
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
	);
	PROCEDURE set_pkgrel_prodstate (
		in_sw_pkg_rel_id 
			sw_package_release.sw_package_release_id%type,
		in_sw_pkg_prodstate 
			sw_package_release.production_state%type
	);

	-- this should possibly be pulled out into its own package because
	-- of who should be able to run it (though its here now because acls
	-- in the calling programs limit it)
	PROCEDURE balefire_sw_package_relation (
		in_sw_pkg_rel_id 
			sw_package_release.sw_package_release_id%type
	);

end;
/
show errors;
/
