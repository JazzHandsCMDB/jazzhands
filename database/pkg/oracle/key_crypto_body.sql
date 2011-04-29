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

create or replace package body key_crypto
IS 
	GC_pkg_name CONSTANT USER_OBJECTS.OBJECT_NAME % TYPE := 
		'dns_gen_utils';
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
	-- encrypt key; returns the encrypted value for dumping into the db

	FUNCTION encrypt_key (
		p_encstring	VARCHAR2,
		p_dbphrase	ENCRYPTION_KEY.ENCRYPTION_KEY_DB_VALUE%type,
		p_appphrase	VARCHAR2,
		p_enc_method	ENCRYPTION_KEY.ENCRYPTION_METHOD%type
	) RETURN VARCHAR2
	IS
	BEGIN
		RETURN null;
	END;
	-- end of function encrypt_key
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- decrypt key; returns the decrypted value for extracting from db
	FUNCTION decrypt_key (
		p_decstring	VARCHAR2,
		p_dbphrase	ENCRYPTION_KEY.ENCRYPTION_KEY_DB_VALUE%type,
		p_appphrase	VARCHAR2,
		p_enc_method	ENCRYPTION_KEY.ENCRYPTION_METHOD%type
	) RETURN VARCHAR2
	IS
	BEGIN
		RETURN null;
	END;
	-- end of function decrypt_key
	-------------------------------------------------------------------
		
end;
/
show errors;
/
