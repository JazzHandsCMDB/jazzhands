-- Copyright (c) 2025, Matthew Ragan
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

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

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'network_strings';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS network_strings;
                CREATE SCHEMA network_strings AUTHORIZATION jazzhands;
		REVOKE ALL ON SCHEMA network_strings FROM public;
		COMMENT ON SCHEMA network_strings IS 'part of jazzhands';
        END IF;
END;
$$;

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
	iface := regexp_replace(iface, E'[^\\d+]+$/', '');
	if iface SIMILAR TO  E'^\\d+$'   THEN
		return p_intname;
	END IF;

	ary := regexp_split_to_array(iface, E'[=\\./]');
	for i in 1..array_length( ary, 1)
	LOOP
		rv := rv || lpad(ary[i], 5, '0') || '.';
	END LOOP; 
	return rv;
END;
$$ LANGUAGE plpgsql;
-- end of function numeric_interface
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION network_strings.number_to_asdot(
	asn	bigint
) RETURNS text
AS $$
BEGIN
	IF asn < 0 OR asn > 4294967295 THEN
		RAISE numeric_value_out_of_range;
	END IF;
	IF asn < 65535 THEN
		RETURN asn;
	ELSE
		RETURN concat_ws('.', ((asn / 65536)::bigint), ((asn % 65536)::bigint));
	END IF;
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT
SECURITY INVOKER
PARALLEL SAFE;
	
CREATE OR REPLACE FUNCTION network_strings.asdot_to_number(
	asn	text
) RETURNS bigint
AS $$
DECLARE
	astext	text[];
BEGIN
	IF asn ~ '^\d+$' THEN
		RETURN asn;
	END IF;
	IF asn !~ '^\d+\.\d+$' THEN
		RAISE 'ASN not in asdot notation' USING ERRCODE = 'data_exception';
	END IF;
	astext := regexp_split_to_array(asn, '\.');
	IF ((astext[1])::bigint > 65535 OR (astext[2])::bigint > 65535) THEN
		RAISE numeric_value_out_of_range;
	END IF;
	RETURN astext[1]::bigint * 65536 + astext[2]::bigint;
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT
SECURITY INVOKER
PARALLEL SAFE;
	
REVOKE ALL ON SCHEMA network_strings FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA network_strings FROM public;

GRANT USAGE ON SCHEMA network_strings TO ro_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA network_strings TO ro_role;
