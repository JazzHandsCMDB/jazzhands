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
-- dns auto generation utilties.
---------------------------------------------------------------------------
-- $Id$

create or replace package body dns_gen_utils
IS 
	GC_pkg_name CONSTANT USER_OBJECTS.OBJECT_NAME % TYPE := 
		'dns_gen_utils';
	G_err_num NUMBER;
	G_err_msg VARCHAR2(200);

	C_autogen_cfg_zone CONSTANT varchar2(200) := 'autogen.zonecfg.example.com';

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
	-- turn on dns auto generation
	PROCEDURE generation_on (
		in_domid 	dns_domain.dns_domain_id%type
	) IS
		dom		dns_domain%rowtype;
		zoneid		dns_record.dns_record_id%type;
		zonename	dns_record.dns_record_id%type;
		cfgdomid	dns_domain.dns_domain_id%type;
	BEGIN
		--
		-- This needs to change once there's a way to link two
		-- dns_records together.
		--
		SELECT	DNS_DOMAIN_ID
		  into	cfgdomid
		  FROM	DNS_DOMAIN
		 where	SOA_NAME = C_autogen_cfg_zone;

		SELECT	*
		  INTO	dom
		  from	DNS_DOMAIN
		 where	DNS_DOMAIN_ID = in_domid;

		BEGIN
			select	dns_record_id
			  into	zoneid
			  from	dns_record
			 where	dns_domain_id = cfgdomid
			   and	dns_name = 'zone'
			   and	dns_value = '_CFG=>zone_id=>' || dom.soa_name;
		EXCEPTION when NO_DATA_FOUND THEN
			INSERT INTO DNS_RECORD (
				DNS_NAME, DNS_DOMAIN_ID,
				DNS_CLASS, DNS_TYPE,
				DNS_VALUE
			) VALUES (
				'zone', cfgdomid,
				'IN', 'TXT',
				'_CFG=>zone_id=>' || dom.soa_name
			) returning DNS_RECORD_ID into zoneid;
		END;

		BEGIN
			select	dns_record_id
			  into	zonename
			  from	dns_record
			 where	dns_domain_id = cfgdomid
			   and	dns_name = dom.soa_name || '.zone'
			   and	dns_value = '_CFG=>zonename=>' || dom.soa_name;
		EXCEPTION when NO_DATA_FOUND THEN
			INSERT INTO DNS_RECORD (
				DNS_NAME, DNS_DOMAIN_ID,
				DNS_CLASS, DNS_TYPE,
				DNS_VALUE
			) VALUES (
				dom.soa_name || '.zone', cfgdomid,
				'IN', 'TXT',
				'_CFG=>zonename=>' || dom.soa_name
			) returning DNS_RECORD_ID into zonename;
		END;

		update	dns_domain 
		   set	should_generate = 'Y' 
		 where	dns_domain_id = in_domid
		   and	should_generate = 'N';

	END;

	-------------------------------------------------------------------
	-- turn off dns auto generation
	PROCEDURE generation_off (
		in_domid 	dns_domain.dns_domain_id%type
	) IS
		dom		dns_domain%rowtype;
		cfgdomid	dns_domain.dns_domain_id%type;
	BEGIN
		SELECT	*
		  INTO	dom
		  from	DNS_DOMAIN
		 where	DNS_DOMAIN_ID = in_domid;

		SELECT	DNS_DOMAIN_ID
		  into	cfgdomid
		  FROM	DNS_DOMAIN
		 where	SOA_NAME = C_autogen_cfg_zone;

		delete	from dns_record
		 where	dns_domain_id = cfgdomid
		   and	dns_type = 'TXT'
		   and	dns_name = 'zone'
		   and	dns_value = '_CFG=>zone_id=>' || dom.soa_name;

		delete	from dns_record
		 where	dns_domain_id = cfgdomid
		   and	dns_type = 'TXT'
		   and	dns_name = dom.soa_name || '.zone'
		   and	dns_value = '_CFG=>zonename=>' || dom.soa_name;

		update	dns_domain
		   set	should_generate = 'N'
		 where	dns_domain_id = in_domid
		   and	should_generate = 'Y';
	EXCEPTION WHEN NO_DATA_FOUND THEN
		return;
	END;

		
end;
/
show errors;
/
