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

drop schema if exists network_strings cascade;
create schema network_strings authorization jazzhands;

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION network_strings.id_tag()
RETURNS VARCHAR AS $$
BEGIN
        RETURN('<-- $Id -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag
-------------------------------------------------------------------


-------------------------------------------------------------------
-- returns something with the different elements split out into
-- something with leading zeros for better sorting.
--
CREATE OR REPLACE FUNCTION network_strings.numeric_interface
(
	p_intname			varchar
) RETURNS VARCHAR AS $$
DECLARE
	rv varchar(200);
	iface varchar(200);
	ary TEXT ARRAY;
	x text;
BEGIN
	rv := '';
	iface := regexp_replace(p_intname, E'^[^\\d]+', ''); 
	RAISE NOTICE '% to %', p_intname, iface;
	iface := regexp_replace(iface, E'[^\\d+]+$/', '');
	if( regexp_matches( iface, E'^\\d+$') ) THEN
		return p_intname;
	END IF;

	ary := regexp_split_to_array(iface, E'[=\\./]');
	for i in 1..array_length( ary, 1)
	LOOP
		RAISE NOTICE 'considering %', ary[i];
		rv := rv || lpad(ary[i], 5, '0') || '.';
	END LOOP; 
	return rv;
END;
$$ LANGUAGE plpgsql;
-- end of function numeric_interface
-------------------------------------------------------------------
