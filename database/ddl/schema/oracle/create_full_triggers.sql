
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
--
--
--
-- $Id$
--

DROP TRIGGER C_TIUBR_ACCOUNT;

DROP TRIGGER C_TIB_ACCOUNT;

DROP TRIGGER TUB_ACCOUNT;

DROP TRIGGER K_TAIU_ACCOUNT_COMPANY;

DROP TRIGGER K_TAU_ACCOUNT_STATUS;

DROP TRIGGER K_TAIU_ACCOUNT_TYPE;

DROP TRIGGER C_TIUBR_SYS_USER_ASSIGND_CERT;

DROP TRIGGER TUB_SYS_USER_ASSIGND_CERT;

DROP TRIGGER C_TIUBR_ACCOUNT_AUTH_LOG;

DROP TRIGGER TUB_ACCOUNT_AUTH_LOG;

DROP TRIGGER TIB_ACCOUNT_AUTH_LOG;

DROP TRIGGER C_TIUBR_ACCOUNT_COLLECTION;

DROP TRIGGER TIB_ACCOUNT_COLLECTION;

DROP TRIGGER TUB_ACCOUNT_COLLECTION;

DROP TRIGGER C_TIUBR_ACCOUNT_COLLECTION_ACC;

DROP TRIGGER TUB_ACCOUNT_COLLECTION_ACCOUNT;

DROP TRIGGER C_TIUBR_ACCOUNT_COLLECTION_HIE;

DROP TRIGGER TUB_ACCOUNT_COLLECTION_HIER;

DROP TRIGGER C_TIUBR_ACCOUNT_PASSWORD;

DROP TRIGGER TUB_ACCOUNT_PASSWORD;

DROP TRIGGER C_TIUBR_ACCOUNT_REALM;

DROP TRIGGER TIB_ACCOUNT_REALM;

DROP TRIGGER TUB_ACCOUNT_REALM;

DROP TRIGGER C_TIUBR_ACCOUNT_REALM_COMPANY;

DROP TRIGGER TUB_ACCOUNT_REALM_COMPANY;

DROP TRIGGER C_TIUBR_ACCOUNT_SSH_KEY;

DROP TRIGGER TUB_ACCOUNT_SSH_KEY;

DROP TRIGGER TUB_ACCOUNT_TOKEN;

DROP TRIGGER C_TIUBR_ACCOUNT_TOKEN;

DROP TRIGGER TIB_ACCOUNT_TOKEN;

DROP TRIGGER C_TIUBR_USER_UNIX_INFO;

DROP TRIGGER TUB_USER_UNIX_INFO;

DROP TRIGGER C_TIUBR_APPAAL;

DROP TRIGGER TUB_APPAAL;

DROP TRIGGER TIB_APPAAL;

DROP TRIGGER C_TIUBR_APPAAL_INSTANCE;

DROP TRIGGER TIB_APPAAL_INSTANCE;

DROP TRIGGER TUB_APPAAL_INSTANCE;

DROP TRIGGER C_TIUBR_APPAAL_INSTANCE_DEVICE;

DROP TRIGGER TUB_APPAAL_INSTANCE_DEVICE_COL;

DROP TRIGGER C_TIUBR_APPAAL_INSTANCE_PROPER;

DROP TRIGGER TUB_APPAAL_INSTANCE_PROPERTY;

DROP TRIGGER C_TIUBR_BADGE;

DROP TRIGGER TUB_BADGE;

DROP TRIGGER C_TIUBR_BADGE_TYPE;

DROP TRIGGER TIB_BADGE_TYPE;

DROP TRIGGER TUB_BADGE_TYPE;

DROP TRIGGER C_TIUBR_CIRCUIT;

DROP TRIGGER TIB_CIRCUIT;

DROP TRIGGER TUB_CIRCUIT;

DROP TRIGGER C_TIUBR_COMPANY;

DROP TRIGGER TIB_COMPANY;

DROP TRIGGER TUB_COMPANY;

DROP TRIGGER Trigger_13102;

DROP TRIGGER Trigger_13103;

DROP TRIGGER C_TIUBR_DEPT;

DROP TRIGGER TIB_DEPT;

DROP TRIGGER TUB_DEPT;

DROP TRIGGER C_TIUBR_DEVICE;

DROP TRIGGER K_TIUBR_DEVICE;

DROP TRIGGER TIB_DEVICE;

DROP TRIGGER TUB_DEVICE;

DROP TRIGGER C_TIUBR_DEVICE_COLL_ACCOUNT_CO;

DROP TRIGGER TUB_DEVICE_COLL_ACCOUNT_COLL;

DROP TRIGGER C_TIUBR_DEVICE_COLLECTION;

DROP TRIGGER TIB_DEVICE_COLLECTION;

DROP TRIGGER TUB_DEVICE_COLLECTION;

DROP TRIGGER C_TIUBR_DEV_COLL_ASSIGND_CERT;

DROP TRIGGER TUB_DEV_COLL_ASSIGND_CERT;

DROP TRIGGER C_TIUBR_DEVICE_COLLECTION_DEVI;

DROP TRIGGER TUB_DEVICE_COLLECTION_DEVICE;

DROP TRIGGER C_TIUBR_DEVICE_COLLECTION_HIER;

DROP TRIGGER TUB_DEVICE_COLLECTION_HIER;

DROP TRIGGER C_TIUBR_DEVICE_NOTE;

DROP TRIGGER TIB_DEVICE_NOTE;

DROP TRIGGER TUB_DEVICE_NOTE;

DROP TRIGGER C_TIUBR_DEVICE_POWER_CONNECTIO;

DROP TRIGGER TIB_DEVICE_POWER_CONNECTION;

DROP TRIGGER TUB_DEVICE_POWER_CONNECTION;

DROP TRIGGER C_TIUBR_DEVICE_POWER_INTERFACE;

DROP TRIGGER TUB_DEVICE_POWER_INTERFACE;

DROP TRIGGER C_TIUBR_DEVICE_SSH_KEY;

DROP TRIGGER TUB_DEVICE_SSH_KEY;

DROP TRIGGER C_TIBUR_DEVICE_TICKET;

DROP TRIGGER TUB_DEVICE_TICKET;

DROP TRIGGER C_TIUBR_DEVICE_TYPE;

DROP TRIGGER TIB_DEVICE_TYPE;

DROP TRIGGER TUB_DEVICE_TYPE;

DROP TRIGGER C_TIUBR_DEVICE_TYPE_PHYS_PORT_;

DROP TRIGGER TUB_DEVICE_TYPE_PHYS_PORT_TEMP;

DROP TRIGGER C_TIUBR_DEVICE_TYPE_POWER_PORT;

DROP TRIGGER TUB_DEVICE_TYPE_POWER_PORT_TEM;

DROP TRIGGER C_TIUBR_DHCP_RANGE;

DROP TRIGGER TIB_DHCP_RANGE;

DROP TRIGGER TUB_DHCP_RANGE;

DROP TRIGGER C_TIUBR_DNS_DOMAIN;

DROP TRIGGER K_TIUBR_DNS_DOMAIN;

DROP TRIGGER TIB_DNS_DOMAIN;

DROP TRIGGER TUB_DNS_DOMAIN;

DROP TRIGGER C_TIUBR_DNS_RECORD;

DROP TRIGGER K_TIUDBR_DNS_RECORD;

DROP TRIGGER TIB_DNS_RECORD;

DROP TRIGGER TUB_DNS_RECORD;

DROP TRIGGER TUB_DNS_RECORD_RELATION;

DROP TRIGGER C_TIUBR_DNS_RECORD_RELATION;

DROP TRIGGER C_TIUBR_ENCAPSULATION;

DROP TRIGGER TIB_ENCAPSULATION;

DROP TRIGGER TUB_ENCAPSULATION;

DROP TRIGGER C_TIUBR_ENCRYPTION_KEY;

DROP TRIGGER TIB_ENCRYPTION_KEY;

DROP TRIGGER TUB_ENCRYPTION_KEY;

DROP TRIGGER C_TIUBR_IP_UNIVERSE;

DROP TRIGGER TUB_IP_UNIVERSE;

DROP TRIGGER TIB_IP_UNIVERSE;

DROP TRIGGER C_TIUBR_KERBEROS_REALM;

DROP TRIGGER TIB_KERBEROS_REALM;

DROP TRIGGER TUB_KERBEROS_REALM;

DROP TRIGGER C_TIUBR_KLOGIN;

DROP TRIGGER TIB_KLOGIN;

DROP TRIGGER TUB_KLOGIN;

DROP TRIGGER C_TIUBR_KLOGIN_MCLASS;

DROP TRIGGER TUB_KLOGIN_MCLASS;

DROP TRIGGER C_TIUBR_LAYER1_CONNECTION;

DROP TRIGGER TIB_LAYER1_CONNECTION;

DROP TRIGGER TUB_LAYER1_CONNECTION;

DROP TRIGGER C_TIUA_LAYER1_CONNECTION;

DROP TRIGGER C_TIUBR_LAYER2_ENCAPSULATION;

DROP TRIGGER TIB_LAYER2_ENCAPSULATION;

DROP TRIGGER TUB_LAYER2_ENCAPSULATION;

DROP TRIGGER C_TIUBR_LOCATION;

DROP TRIGGER TIB_LOCATION;

DROP TRIGGER TUB_LOCATION;

DROP TRIGGER C_TIUBR_NETBLOCK;

DROP TRIGGER K_TAIU_NONROW_NETBLOCK;

DROP TRIGGER K_TBIU_NETBLOCK;

DROP TRIGGER K_TBIU_NONROW_NETBLOCK;

DROP TRIGGER TIB_NETBLOCK;

DROP TRIGGER TUB_NETBLOCK;

DROP TRIGGER K_TIUB_NETBLOCK;

DROP TRIGGER C_TIUBR_NETBLOCK_COLLECTION;

DROP TRIGGER TIB_NETBLOCK_COLLECTION;

DROP TRIGGER TUB_NETBLOCK_COLLECTION;

DROP TRIGGER C_TIUBR_NETBLOCK_COLLECTION_HI;

DROP TRIGGER TUB_NETBLOCK_COLLECTION_HIER;

DROP TRIGGER C_TIUBR_ACCOUNT_COLLECTION_ACC;

DROP TRIGGER TUB_ACCOUNT_COLLECTION_ACCOUNT;

DROP TRIGGER C_TIUBR_NETWORK_INTERFACE;

DROP TRIGGER TIB_NETWORK_INTERFACE;

DROP TRIGGER TUB_NETWORK_INTERFACE;

DROP TRIGGER C_TIUBR_NETWORK_SERVICE;

DROP TRIGGER TIB_NETWORK_SERVICE;

DROP TRIGGER TUB_NETWORK_SERVICE;

DROP TRIGGER C_TIUBR_OPERATING_SYSTEM;

DROP TRIGGER TIB_OPERATING_SYSTEM;

DROP TRIGGER TUB_OPERATING_SYSTEM;

DROP TRIGGER C_TIUBR_PERSON;

DROP TRIGGER C_TIB_PERSON;

DROP TRIGGER TUB_PERSON;

DROP TRIGGER C_TIUBR_PERSON_ACCT_REALM_COMP;

DROP TRIGGER TUB_PERSON_ACCT_REALM_COMPANY;

DROP TRIGGER TUB_PERSON_AUTH_QUESTION;

DROP TRIGGER C_TIUBR_PERSON_AUTH_QUESTION;

DROP TRIGGER C_TIUBR_PERSON_COMPANY;

DROP TRIGGER TUB_PERSON_COMPANY;

DROP TRIGGER C_TIUBR_PERSON_CONTACT;

DROP TRIGGER TIB_PERSON_CONTACT;

DROP TRIGGER TUB_PERSON_CONTACT;

DROP TRIGGER C_TIUBR_PERSON_IMAGE;

DROP TRIGGER TIB_PERSON_IMAGE;

DROP TRIGGER TUB_PERSON_IMAGE;

DROP TRIGGER C_TIUBR_PERSON_IMAGE_USAGE;

DROP TRIGGER TUB_PERSON_IMAGE_USAGE;

DROP TRIGGER C_TIUBR_PERSON_LOCATION;

DROP TRIGGER TIB_PERSON_LOCATION;

DROP TRIGGER TUB_PERSON_LOCATION;

DROP TRIGGER K_TAIUD_PERSON_SITE;

DROP TRIGGER TIB_PRESON_NOTE;

DROP TRIGGER TUB_PERSON_NOTE;

DROP TRIGGER C_TIUBR_PERSON_NOTE;

DROP TRIGGER C_TIUBR_PERSON_PARKING_PASS;

DROP TRIGGER TIB_PERSON_PARKING_PASS;

DROP TRIGGER TUB_PERSON_PARKING_PASS;

DROP TRIGGER C_TIUBR_PERSON_VEHICLE;

DROP TRIGGER TIB_PERSON_VEHICLE;

DROP TRIGGER TUB_PERSON_VEHICLE;

DROP TRIGGER C_TIUBR_PHYSICAL_ADDRESS;

DROP TRIGGER TUB_PHYSICAL_ADDRESS;

DROP TRIGGER TIB_PHYSICAL_ADDRESS;

DROP TRIGGER C_TIUBR_PHYSICAL_CONNECTION;

DROP TRIGGER TIB_PHYSICAL_CONNECTION;

DROP TRIGGER TUB_PHYSICAL_CONNECTION;

DROP TRIGGER C_TIUA_PHYSICAL_CONNECTION;

DROP TRIGGER C_TIUBR_PHYSICAL_PORT;

DROP TRIGGER TIB_PHYSICAL_PORT;

DROP TRIGGER TUB_PHYSICAL_PORT;

DROP TRIGGER TIB_PROPERTY;

DROP TRIGGER C_TIBUR_PROPERTY;

DROP TRIGGER TUB_PROPERTY;

DROP TRIGGER K_TAIU_NONROW_PROPERTY;

DROP TRIGGER K_TBIU_NONROW_PROPERTY;

DROP TRIGGER K_TBIU_PROPERTY;

DROP TRIGGER C_TIUBR_PSEUDO_KLOGIN;

DROP TRIGGER TIB_PSEUDO_KLOGIN;

DROP TRIGGER TUB_PSEUDO_KLOGIN;

DROP TRIGGER TIB_RACK;

DROP TRIGGER C_TIUBR_RACK;

DROP TRIGGER TUB_RACK;

DROP TRIGGER C_TIUBR_SECONDARY_NETBLOCK;

DROP TRIGGER TIB_SECONDARY_NETBLOCK;

DROP TRIGGER TUB_SECONDARY_NETBLOCK;

DROP TRIGGER C_TIUBR_SITE;

DROP TRIGGER TUB_SITE;

DROP TRIGGER C_TIUBR_SITE_NETBLOCK;

DROP TRIGGER TUB_SITE_NETBLOCK;

DROP TRIGGER C_TIUBR_SNMP_COMMSTR;

DROP TRIGGER K_TBIU_SNMP_COMMSTR;

DROP TRIGGER TIB_SNMP_COMMSTR;

DROP TRIGGER TUB_SNMP_COMMSTR;

DROP TRIGGER C_TIUBR_SSH_KEY;

DROP TRIGGER TUB_SSH_KEY;

DROP TRIGGER TIB_SSH_KEY;

DROP TRIGGER C_TIUBR_STATIC_ROUTE;

DROP TRIGGER TIB_STATIC_ROUTE;

DROP TRIGGER TUB_STATIC_ROUTE;

DROP TRIGGER C_TIUBR_STATIC_ROUTE_TEMPLATE;

DROP TRIGGER TIB_STATIC_ROUTE_TEMPLATE;

DROP TRIGGER TUB_STATIC_ROUTE_TEMPLATE;

DROP TRIGGER C_TIUBR_SUDO_USERCOL_DEVCOL;

DROP TRIGGER TUB_SUDO_USERCOL_DEVCOL;

DROP TRIGGER TUB_SUDO_ALIAS;

DROP TRIGGER C_TIUBR_SUDO_ALIAS;

DROP TRIGGER TIB_SW_PACKAGE;

DROP TRIGGER TUB_SW_PACKAGE;

DROP TRIGGER C_TIUBR_SW_PACKAGE;

DROP TRIGGER TIB_SW_PACKAGE_RELATION;

DROP TRIGGER TUB_SW_PACKAGE_RELATION;

DROP TRIGGER C_TIUBR_SW_PACKAGE_RELATION;

DROP TRIGGER C_TIUBR_SW_PACKAGE_RELEASE;

DROP TRIGGER TIB_SW_PACKAGE_RELEASE;

DROP TRIGGER TUB_SW_PACKAGE_RELEASE;

DROP TRIGGER TIB_SW_PACKAGE_REPOSITORY;

DROP TRIGGER TUB_SW_PACKAGE_REPOSITORY;

DROP TRIGGER C_TIUBR_SW_PACKAGE_REPOSITORY;

DROP TRIGGER C_TIUBR_TOKEN;

DROP TRIGGER TIB_TOKEN;

DROP TRIGGER TUB_TOKEN;

DROP TRIGGER TIB_TOKEN_COLLECTION;

DROP TRIGGER TUB_TOKEN_COLLECTION;

DROP TRIGGER C_TIUBR_TOKEN_COLLECTION;

DROP TRIGGER TUB_TOKEN_COL_MEMBR;

DROP TRIGGER C_TIUBR_COL_MEMBR;

DROP TRIGGER C_TIUBR_UNIX_GROUP;

DROP TRIGGER TUB_UNIX_GROUP;

DROP TRIGGER C_TIUBR_VAL_ACCT_COL_TYPE;

DROP TRIGGER TUB_VAL_ACCT_COL_TYPE;

DROP TRIGGER C_TIUBR_VAL_ACCOUNT_ROLE;

DROP TRIGGER TUB_VAL_ACCOUNT_ROLE;

DROP TRIGGER C_TIUBR_VAL_ACCOUNT_TYPE;

DROP TRIGGER TUB_VAL_ACCOUNT_TYPE;

DROP TRIGGER C_TIUBR_VAL_APP_KEY;

DROP TRIGGER TUB_VAL_APP_KEY;

DROP TRIGGER C_TIUBR_VAL_APP_KEY_VALUES;

DROP TRIGGER TUB_VAL_APP_KEY_VALUES;

DROP TRIGGER C_TIUBR_VAL_AUTH_QUESTION;

DROP TRIGGER TIB_VAL_AUTH_QUESTION;

DROP TRIGGER TUB_VAL_AUTH_QUESTION;

DROP TRIGGER C_TIUBR_VAL_AUTH_RESOURCE;

DROP TRIGGER TUB_VAL_AUTH_RESOURCE;

DROP TRIGGER C_TIUBR_VAL_BADGE_STATUS;

DROP TRIGGER TUB_VAL_BADGE_STATUS;

DROP TRIGGER TUB_VAL_BAUD;

DROP TRIGGER C_TIUBR_VAL_BAUD;

DROP TRIGGER C_TIUBR_VAL_CABLE_TYPE;

DROP TRIGGER TUB_VAL_CABLE_TYPE;

DROP TRIGGER Trigger_13051;

DROP TRIGGER Trigger_13052;

DROP TRIGGER C_TIUBR_VAL_COUNTRY_CODE;

DROP TRIGGER TUB_VAL_COUNTRY_CODE;

DROP TRIGGER TUB_VAL_DATA_BITS;

DROP TRIGGER C_TIUBR_VAL_DATA_BITS;

DROP TRIGGER TUB_VAL_DEVICE_AUTO_MGMT_PROTO;

DROP TRIGGER C_TIUBR_VAL_DEVICE_AUTO_MGMT_P;

DROP TRIGGER C_TIUBR_VAL_DEVICE_COLLECTION_;

DROP TRIGGER TUB_VAL_DEVICE_COLLECTION_TYPE;

DROP TRIGGER C_TIUBR_VAL_STATUS;

DROP TRIGGER TUB_VAL_STATUS;

DROP TRIGGER C_TIUBR_VAL_DIET;

DROP TRIGGER TUB_VAL_DIET;

DROP TRIGGER C_TIUBR_VAL_DNS_CLASS;

DROP TRIGGER TUB_VAL_DNS_CLASS;

DROP TRIGGER TUB_VAL_DNS_DOMAIN_TYPE;

DROP TRIGGER C_TIUBR_VAL_DNS_DOMAIN_TYPE;

DROP TRIGGER TUB_VAL_DNS_RECORD_RELATION_TY;

DROP TRIGGER C_TIUBR_VAL_DNS_RECORD_RELATIO;

DROP TRIGGER C_TIUBR_VAL_DNS_SRV_SERVICE;

DROP TRIGGER TUB_VAL_DNS_SRV_SERVICE;

DROP TRIGGER C_TIUBR_VAL_DNS_TYPE;

DROP TRIGGER TUB_VAL_DNS_TYPE;

DROP TRIGGER C_TIUBR_VAL_ENCAPSULATION_TYPE;

DROP TRIGGER TUB_VAL_ENCAPSULATION_TYPE;

DROP TRIGGER C_TIUBR_VAL_ENCRYPT_KEY_PURP;

DROP TRIGGER TUB_VAL_ENCRYPT_KEY_PURPOSE;

DROP TRIGGER C_TIUBR_VAL_ENCRYPT_METHOD;

DROP TRIGGER C_TUB_VAL_ENCRYPT_METHOD;

DROP TRIGGER TUB_VAL_FLOW_CONTROL;

DROP TRIGGER C_TIUBR_VAL_FLOW_CONTROL;

DROP TRIGGER C_TIUBR_VAL_IMAGE_TYPE;

DROP TRIGGER TUB_VAL_IMAGE_TYPE;

DROP TRIGGER C_TIUBR_REASON_FOR_ASSIGN;

DROP TRIGGER TUB_REASON_FOR_ASSIGN;

DROP TRIGGER CTIUBR_VAL_NETBLOCK_COLLECTION;

DROP TRIGGER TUB_VAL_NETBLOCK_COLLECTION_TY;

DROP TRIGGER C_TIUBR_VAL_NETBLOCK_STATUS;

DROP TRIGGER TUB_VAL_NETBLOCK_STATUS;

DROP TRIGGER C_TIUBR_NETBLOCK_TYPE;

DROP TRIGGER TUB_NETBLOCK_TYPE;

DROP TRIGGER R_TIUBR_VAL_NETWORK_INT_PURP;

DROP TRIGGER TUB_VAL_NETWORK_INTERFACE_PURP;

DROP TRIGGER R_TIUBR_VAL_NETWORK_INT_TYPE;

DROP TRIGGER TUB_VAL_NETWORK_INTERFACE_TYPE;

DROP TRIGGER C_TIUBR_VAL_NETWORK_SERVICE_TY;

DROP TRIGGER TUB_VAL_NETWORK_SERVICE_TYPE;

DROP TRIGGER C_TIUBR_VAL_OWNERSHIP_STATUS;

DROP TRIGGER TUB_VAL_OWNERSHIP_STATUS;

DROP TRIGGER TUB_VAL_PACKAGE_RELATION_TYPE;

DROP TRIGGER C_TIUBR_VAL_PACKAGE_RELATION_T;

DROP TRIGGER TUB_VAL_PARITY;

DROP TRIGGER C_TIUBR_VAL_PARITY;

DROP TRIGGER C_TIUBR_VAL_PASSWORD_TYPE;

DROP TRIGGER TUB_VAL_PASSWORD_TYPE;

DROP TRIGGER C_TIUBR_VAL_PERSON_COMPANY_REL;

DROP TRIGGER TUB_VAL_PRESON_COMPANY_RELATIO;

DROP TRIGGER C_TIUBR_VAL_PERSON_LOC_TYPE;

DROP TRIGGER TUB_VAL_PERSON_CONTACT_LOC_TYP;

DROP TRIGGER C_TIUBR_VAL_PERSON_CONTACT_TEC;

DROP TRIGGER TUB_VAL_PERSON_CONTACT_TECH;

DROP TRIGGER C_TIUBR_VAL_PERSON_CONTACT_TYP;

DROP TRIGGER TUB_VAL_PERSON_CONTACT_TYPE;

DROP TRIGGER C_TIUBR_VAL_PERSON_IMAGE_USAGE;

DROP TRIGGER TUB_VAL_PERSON_IMAGE_USAGE;

DROP TRIGGER C_TIUBR_VAL_USER_LOCATION_TYPE;

DROP TRIGGER TUB_VAL_USER_LOCATION_TYPE;

DROP TRIGGER C_TIUBR_VAL_PERSON_STATUS;

DROP TRIGGER TUB_VAL_PERSON_STATUS;

DROP TRIGGER C_TIUBR_VAL_PLUG_STYLE;

DROP TRIGGER TUB_VAL_PLUG_STYLE;

DROP TRIGGER TUB_VAL_PORT_PURPOSE;

DROP TRIGGER C_TIUBR_VAL_PORT_PURPOSE;

DROP TRIGGER C_TIUBR_VAL_PORT_TYPE;

DROP TRIGGER TUB_VAL_PORT_TYPE;

DROP TRIGGER TUB_VAL_PROCESSOR_ARCHITECTURE;

DROP TRIGGER C_TIUBR_VAL_PROCESSOR_ARCHITEC;

DROP TRIGGER T_CIUBR_VAL_PRODUCTION_STATE;

DROP TRIGGER TUB_VAL_PRODUCTION_STATE;

DROP TRIGGER C_TIBUR_VAL_PROPERTY;

DROP TRIGGER TUB_VAL_PROPERTY;

DROP TRIGGER C_TIBUR_VAL_PROPERTY_DATA_TYPE;

DROP TRIGGER TUB_VAL_PROPERTY_DATA_TYPE;

DROP TRIGGER C_TIBUR_VAL_PROPERTY_TYPE;

DROP TRIGGER TUB_VAL_PROPERTY_TYPE;

DROP TRIGGER C_TIBUR_VAL_PROPERTY_VALUE;

DROP TRIGGER TUB_VAL_PROPERTY_VALUE;

DROP TRIGGER C_TIUBR_VAL_SERVICE_ENVIRONMEN;

DROP TRIGGER TUB_VAL_SERVICE_ENVIRONMENT;

DROP TRIGGER C_TIUBR_VAL_SNMP_COMMSTR_TYPE;

DROP TRIGGER TUB_VAL_SNMP_COMMSTR_TYPE;

DROP TRIGGER Trigger_14950;

DROP TRIGGER Trigger_14951;

DROP TRIGGER TUB_VAL_STOP_BITS;

DROP TRIGGER C_TIUBR_VAL_STOP_BITS;

DROP TRIGGER TUB_VAL_SW_PACKAGE_FORMAT;

DROP TRIGGER C_TIUBR_VAL_SW_PACKAGE_FORMAT;

DROP TRIGGER TUB_VAL_SW_PACKAGE_TYPE;

DROP TRIGGER C_TIUBR_VAL_SW_PACKAGE_TYPE;

DROP TRIGGER TUB_VAL_SYMBOLIC_TRACK_NAME;

DROP TRIGGER C_TIUBR_VAL_SYMBOLIC_TRACK_NAM;

DROP TRIGGER TUB_TOKEN_COL_TYPE;

DROP TRIGGER C_TIUBR_VAL_TOKEN_COL_TYPE;

DROP TRIGGER TUB_VAL_TOKEN_STATUS;

DROP TRIGGER C_TIUBR_VAL_TOKEN_STATUS;

DROP TRIGGER TUB_VAL_TOKEN_TYPE;

DROP TRIGGER C_TIUBR_VAL_TOKEN_TYPE;

DROP TRIGGER TUB_VAL_UPGRADE_SEVERITY;

DROP TRIGGER C_TIUBR_VAL_UPGRADE_SEVERITY;

DROP TRIGGER TUB_VAL_VOE_STATE;

DROP TRIGGER C_TIUBR_VAL_VOE_STATE;

DROP TRIGGER C_TIUBR_CERT_FILE_FMT;

DROP TRIGGER TUB_CERT_FILE_FMT;

DROP TRIGGER C_TIBUR_X509_KEY_USAGE;

DROP TRIGGER TUB_X509_KEY_USAGE;

DROP TRIGGER C_TIBUR_KEY_USAGE_CATEGORY;

DROP TRIGGER TUB_X509_KEY_USAGE_CAT;

DROP TRIGGER TIB_VLAN_RANGE;

DROP TRIGGER TUB_VLAN_RANGE;

DROP TRIGGER C_TIUBR_VLAN_RANGE;

DROP TRIGGER C_TIUBR_VOE;

DROP TRIGGER TIB_VOE;

DROP TRIGGER TUB_VOE;

DROP TRIGGER C_TIUBR_VOE_RELATION;

DROP TRIGGER TUB_VOE_RELATION;

DROP TRIGGER C_TIUBR_VOE_SW_PACKAGE;

DROP TRIGGER TUB_VOE_SW_PACKAGE;

DROP TRIGGER TIB_VOE_SYMBOLIC_TRACK;

DROP TRIGGER TUB_VOE_SYMBOLIC_TRACK;

DROP TRIGGER C_TIUBR_VOE_SYMBOLIC_TRACK;

DROP TRIGGER C_TIUBR_X509_CERTIFICATE;

DROP TRIGGER TIB_X509_CERTIFICATE;

DROP TRIGGER TUB_X509_CERTIFICATE;

DROP TRIGGER C_TIUBR_KEY_USAGE_ATTRB;

DROP TRIGGER TUB_KEY_USAGE_ATTRB;

DROP TRIGGER C_TIBUR_KEY_USAGE_CTGRZTION;

DROP TRIGGER TUB_KEY_USAGE_CATEGRZTN;


CREATE  OR REPLACE  TRIGGER C_TIB_ACCOUNT
 BEFORE INSERT
 ON ACCOUNT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "ACCOUNT_ID" uses sequence SYSDB.SEQ_ACCOUNT_ID
    IF (:new.ACCOUNT_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_ACCOUNT_ID.NEXTVAL
        select SEQ_ACCOUNT_ID.NEXTVAL
        INTO :new.ACCOUNT_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIB_ACCOUNT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ACCOUNT
 BEFORE INSERT OR UPDATE
 ON ACCOUNT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ACCOUNT
	ENABLE;


CREATE  OR REPLACE  TRIGGER K_TAIU_ACCOUNT_COMPANY
 AFTER INSERT OR UPDATE
 ON ACCOUNT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
DECLARE
	integrity_error	exception;
	errno			integer;
	errmsg			char(200);
	compname		Company.Company_Name%TYPE;
	account_collection_name		account_collection.Name%TYPE;
	ucid			account_collection.account_collection_ID%TYPE;
BEGIN
	IF UPDATING THEN
		IF :OLD.Company_ID = :NEW.Company_ID THEN
			RETURN;
		END IF;

		-- Remove the user out of the old company account_collection
		BEGIN
			SELECT Company_Name INTO compname FROM Company WHERE
				Company_ID = :OLD.Company_ID;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				compname := NULL;
		END;
		IF compname IS NOT NULL THEN
			--
			-- The following awesome nested regex does the following to the
			-- company name:
			--   - eliminate anything after the first comma or parens
			--   - eliminate all non-alphanumerics (except spaces)
			--   - remove any trailing 'corporation', 'inc', 'llc' or 'inc'
			--   - convert spaces to underscores
			--   - lowercase
			--
			account_collection_name := 'all_company_' || regexp_replace(
						regexp_replace(
							regexp_replace(
								regexp_replace(
									regexp_replace(lower(compname),
									' ?[,(].*$'),
								'&', 'and'),
							'[^A-Za-z0-9 ]', ''),
						' (corporation|inc|llc|ltd|co|corp|llp)$'),
					' ', '_');

			DELETE FROM account_collection_User WHERE
				account_ID = :OLD.account_ID AND
				account_collection_ID = (
					SELECT account_collection_ID FROM account_collection WHERE
						Name = account_collection_name AND
						account_collection_Type = 'systems'
				);
		END IF;
	END IF;

	-- Insert the user into the new company account_collection
	BEGIN
		SELECT Company_Name INTO compname FROM Company WHERE
			Company_ID = :NEW.Company_ID;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			compname := NULL;
	END;
	IF compname IS NOT NULL THEN
		--
		-- The following awesome nested regex does the following to the
		-- company name:
		--   - eliminate anything after the first comma or parens
		--   - eliminate all non-alphanumerics (except spaces)
		--   - remove any trailing 'corporation', 'inc', 'llc' or 'inc'
		--   - convert spaces to underscores
		--   - lowercase
		--
		account_collection_name := 'all_company_' || regexp_replace(
						regexp_replace(
							regexp_replace(
								regexp_replace(
									regexp_replace(lower(compname),
									' ?[,(].*$'),
								'&', 'and'),
							'[^A-Za-z0-9 ]', ''),
						' (corporation|inc|llc|ltd|co|corp|llp)$'),
					' ', '_');

		BEGIN
			SELECT account_collection_ID INTO ucid FROM account_collection WHERE
				Name = account_collection_name AND
				account_collection_Type = 'systems';
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				INSERT INTO account_collection (
					Name, account_collection_Type
				) VALUES (
					account_collection_name, 'systems'
				) RETURNING account_collection_ID INTO ucid;
		END;
		IF ucid IS NOT NULL THEN
			INSERT INTO account_collection_User (
					account_collection_ID,
					account_ID
				) VALUES (
					ucid,
					:NEW.account_ID
				);
		END IF;
	END IF;
END;
/



ALTER TRIGGER K_TAIU_ACCOUNT_COMPANY
	DISABLE;


CREATE  OR REPLACE  TRIGGER K_TAIU_ACCOUNT_TYPE
 AFTER INSERT OR UPDATE OF 
       ACCOUNT_TYPE
 ON ACCOUNT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
DECLARE
    integrity_error exception;
    errno           integer;
    errmsg          char(200);
    account_collection_name     account_collection.Name%TYPE;
    ucid            account_collection.account_collection_ID%TYPE;
BEGIN
    IF UPDATING THEN
        IF :OLD.account_Type = :NEW.account_Type THEN
            RETURN;
        END IF;

        account_collection_name := 'all_' || :OLD.account_Type;

        DELETE FROM account_collection_User WHERE
            account_ID = :OLD.account_ID AND
            account_collection_ID = (
                SELECT account_collection_ID FROM account_collection WHERE
                    Name = account_collection_name AND
                    account_collection_Type = 'systems'
        );
    END IF;
    account_collection_name := 'all_' || :NEW.account_Type;
    BEGIN
        SELECT account_collection_ID INTO ucid FROM account_collection WHERE
            Name = account_collection_name AND
            account_collection_Type = 'systems';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO account_collection (
                Name, account_collection_Type
            ) VALUES (
                account_collection_name, 'systems'
            ) RETURNING account_collection_ID INTO ucid;
    END;
    IF ucid IS NOT NULL THEN
        INSERT INTO account_collection_user (
                account_collection_ID,
                account_ID
            ) VALUES (
                ucid,
                :NEW.account_ID
            );
    END IF;
END;
/



ALTER TRIGGER K_TAIU_ACCOUNT_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER K_TAU_ACCOUNT_STATUS
 AFTER UPDATE OF 
       ACCOUNT_STATUS
 ON ACCOUNT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
DECLARE
	no_fk	EXCEPTION;
	PRAGMA	EXCEPTION_INIT(no_fk, -02291);
BEGIN
	IF :old.account_status <> :new.account_status AND
			:new.account_status = 'enabled' THEN
		insert into account_auth_log (
			account_ID,
			account_AUTH_TS,
			account_AUTH_SEQ, WAS_AUTH_SUCCESS,
			AUTH_RESOURCE, AUTH_RESOURCE_INSTANCE, AUTH_ORIGIN
		) values (
			:new.account_id,
			(sysdate - 90 + 5),
			0, 'Y',
			'fake', 'enabled user', 'trigger'
		);
	END IF;
	-- if it becomes necessary to limit this to just the fk of 'fake' not
	-- existing. This insert failing should not cause any issues.
	-- EXCEPTION WHEN  no_fk THEN
EXCEPTION WHEN OTHERS THEN
	NULL;
END;

/



ALTER TRIGGER K_TAU_ACCOUNT_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ACCOUNT
 BEFORE UPDATE OF 
        LOGIN,
        ACCOUNT_ID,
        DATA_INS_DATE,
        ACCOUNT_TYPE,
        DATA_INS_USER,
        ACCOUNT_STATUS
 ON ACCOUNT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ACCOUNT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SYS_USER_ASSIGND_CERT
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_ASSIGND_CERT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SYS_USER_ASSIGND_CERT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SYS_USER_ASSIGND_CERT
 BEFORE UPDATE
 ON ACCOUNT_ASSIGND_CERT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SYS_USER_ASSIGND_CERT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ACCOUNT_AUTH_LOG
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_AUTH_LOG
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ACCOUNT_AUTH_LOG
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_ACCOUNT_AUTH_LOG
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_AUTH_LOG
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;
begin
	if(:new.ACCOUNT_AUTH_SEQ is NULL) THEN
		select	SEQ_ACCOUNT_AUTH.nextval
		into	:new.ACCOUNT_AUTH_SEQ
		from	dual;
	end if;
end;

/



ALTER TRIGGER TIB_ACCOUNT_AUTH_LOG
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ACCOUNT_AUTH_LOG
 BEFORE UPDATE
 ON ACCOUNT_AUTH_LOG
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER
    then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE
     then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ACCOUNT_AUTH_LOG
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ACCOUNT_COLLECTION
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ACCOUNT_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_ACCOUNT_COLLECTION
 BEFORE INSERT
 ON ACCOUNT_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    IF (:new.ACCOUNT_COLLECTION_ID IS NULL)
    THEN
        select SEQ_ACCOUNT_COLLECTION_ID.NEXTVAL
        INTO :new.ACCOUNT_COLLECTION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_ACCOUNT_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ACCOUNT_COLLECTION
 BEFORE UPDATE OF 
        ACCOUNT_COLLECTION_TYPE,
        ACCOUNT_COLLECTION_NAME,
        DATA_INS_DATE,
        DATA_INS_USER,
        ACCOUNT_COLLECTION_ID
 ON ACCOUNT_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ACCOUNT_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ACCOUNT_COLLECTION_ACC
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_COLLECTION_ACCOUNT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ACCOUNT_COLLECTION_ACC
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ACCOUNT_COLLECTION_ACCOUNT
 BEFORE UPDATE OF 
        ACCOUNT_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        ACCOUNT_COLLECTION_ID
 ON ACCOUNT_COLLECTION_ACCOUNT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ACCOUNT_COLLECTION_ACCOUNT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ACCOUNT_COLLECTION_HIE
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_COLLECTION_HIER
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ACCOUNT_COLLECTION_HIE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ACCOUNT_COLLECTION_HIER
 BEFORE UPDATE OF 
        CHILD_ACCOUNT_COLLECTION_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        ACCOUNT_COLLECTION_ID
 ON ACCOUNT_COLLECTION_HIER
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ACCOUNT_COLLECTION_HIER
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ACCOUNT_PASSWORD
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_PASSWORD
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ACCOUNT_PASSWORD
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ACCOUNT_PASSWORD
 BEFORE UPDATE OF 
        PASSWORD_TYPE,
        ACCOUNT_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON ACCOUNT_PASSWORD
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ACCOUNT_PASSWORD
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ACCOUNT_REALM
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_REALM
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ACCOUNT_REALM
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_ACCOUNT_REALM
 BEFORE INSERT
 ON ACCOUNT_REALM
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "ACCOUNT_REALM_ID" uses sequence SYSDB.SEQ_ACCOUNT_REALM_ID
    IF (:new.ACCOUNT_REALM_ID IS NULL)
    THEN
        select SEQ_ACCOUNT_REALM_ID.NEXTVAL
        INTO :new.ACCOUNT_REALM_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_ACCOUNT_REALM
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ACCOUNT_REALM
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        ACCOUNT_REALM_ID
 ON ACCOUNT_REALM
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ACCOUNT_REALM
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ACCOUNT_REALM_COMPANY
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_REALM_COMPANY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ACCOUNT_REALM_COMPANY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ACCOUNT_REALM_COMPANY
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        ACCOUNT_REALM_ID
 ON ACCOUNT_REALM_COMPANY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ACCOUNT_REALM_COMPANY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ACCOUNT_SSH_KEY
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_SSH_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ACCOUNT_SSH_KEY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ACCOUNT_SSH_KEY
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER
 ON ACCOUNT_SSH_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ACCOUNT_SSH_KEY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ACCOUNT_TOKEN
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_TOKEN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ACCOUNT_TOKEN
	ENABLE;


CREATE  TRIGGER TIB_ACCOUNT_TOKEN
 BEFORE INSERT
 ON ACCOUNT_TOKEN
 
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    IF (:new.ACCOUNT_TOKEN_ID IS NULL)
    THEN
        select SEQ_ACCOUNT_TOKEN_ID.NEXTVAL
        INTO :new.ACCOUNT_TOKEN_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_ACCOUNT_TOKEN
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ACCOUNT_TOKEN
 BEFORE UPDATE OF 
        ACCOUNT_ID,
        TOKEN_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON ACCOUNT_TOKEN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ACCOUNT_TOKEN
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_USER_UNIX_INFO
 BEFORE INSERT OR UPDATE
 ON ACCOUNT_UNIX_INFO
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_USER_UNIX_INFO
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_USER_UNIX_INFO
 BEFORE UPDATE OF 
        ACCOUNT_ID,
        DATA_INS_DATE,
        UNIX_UID,
        DATA_INS_USER
 ON ACCOUNT_UNIX_INFO
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;
--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER TUB_USER_UNIX_INFO
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_APPAAL
 BEFORE INSERT OR UPDATE
 ON APPAAL
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_APPAAL
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_APPAAL
 BEFORE INSERT
 ON APPAAL
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "APPAAL_ID" uses sequence SYSDB.SEQ_APPAAL_ID
    IF (:new.APPAAL_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_APPAAL_ID.NEXTVAL
        select SEQ_APPAAL_ID.NEXTVAL
        INTO :new.APPAAL_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_APPAAL
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_APPAAL
 BEFORE UPDATE OF 
        APPAAL_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON APPAAL
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_APPAAL
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_APPAAL_INSTANCE
 BEFORE INSERT OR UPDATE
 ON APPAAL_INSTANCE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_APPAAL_INSTANCE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_APPAAL_INSTANCE
 BEFORE INSERT
 ON APPAAL_INSTANCE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "APPAAL_INSTANCE_ID" uses sequence SYSDB.SEQ_APPAAL_INSTANCE_ID
    IF (:new.APPAAL_INSTANCE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_APPAAL_INSTANCE_ID.NEXTVAL
        select SEQ_APPAAL_INSTANCE_ID.NEXTVAL
        INTO :new.APPAAL_INSTANCE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_APPAAL_INSTANCE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_APPAAL_INSTANCE
 BEFORE UPDATE OF 
        FILE_OWNER_ACCOUNT_ID,
        APPAAL_INSTANCE_ID,
        APPAAL_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        SERVICE_ENVIRONMENT
 ON APPAAL_INSTANCE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_APPAAL_INSTANCE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_APPAAL_INSTANCE_DEVICE
 BEFORE INSERT OR UPDATE
 ON APPAAL_INSTANCE_DEVICE_COLL
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_APPAAL_INSTANCE_DEVICE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_APPAAL_INSTANCE_DEVICE_COL
 BEFORE UPDATE OF 
        DEVICE_COLLECTION_ID,
        APPAAL_INSTANCE_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON APPAAL_INSTANCE_DEVICE_COLL
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_APPAAL_INSTANCE_DEVICE_COL
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_APPAAL_INSTANCE_PROPER
 BEFORE INSERT OR UPDATE
 ON APPAAL_INSTANCE_PROPERTY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_APPAAL_INSTANCE_PROPER
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_APPAAL_INSTANCE_PROPERTY
 BEFORE UPDATE OF 
        APPAAL_INSTANCE_ID,
        DATA_INS_DATE,
        APP_KEY,
        DATA_INS_USER
 ON APPAAL_INSTANCE_PROPERTY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_APPAAL_INSTANCE_PROPERTY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_BADGE
 BEFORE INSERT OR UPDATE
 ON BADGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_BADGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_BADGE
 BEFORE UPDATE OF 
        CARD_NUMBER,
        BADGE_STATUS,
        DATA_INS_DATE,
        BADGE_TYPE_ID,
        DATA_INS_USER
 ON BADGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_BADGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_BADGE_TYPE
 BEFORE INSERT OR UPDATE
 ON BADGE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_BADGE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_BADGE_TYPE
 BEFORE INSERT
 ON BADGE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "BADGE_TYPE_ID" uses sequence SYSDB.SEQ_BADGE_TYPE_ID
    IF (:new.BADGE_TYPE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_BADGE_TYPE_ID.NEXTVAL
        select SEQ_BADGE_TYPE_ID.NEXTVAL
        INTO :new.BADGE_TYPE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_BADGE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_BADGE_TYPE
 BEFORE UPDATE OF 
        BADGE_COLOR,
        BADGE_TYPE_NAME,
        DATA_INS_DATE,
        BADGE_TYPE_ID,
        DATA_INS_USER
 ON BADGE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_BADGE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_CIRCUIT
 BEFORE INSERT OR UPDATE
 ON CIRCUIT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_CIRCUIT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_CIRCUIT
 BEFORE INSERT
 ON CIRCUIT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "CIRCUIT_ID" uses sequence SYSDB.SEQ_CIRCUIT_ID
    IF (:new.CIRCUIT_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_CIRCUIT_ID.NEXTVAL
        select SEQ_CIRCUIT_ID.NEXTVAL
        INTO :new.CIRCUIT_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_CIRCUIT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_CIRCUIT
 BEFORE UPDATE OF 
        ZLOC_PARENT_CIRCUIT_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        CIRCUIT_ID,
        ALOC_PARENT_CIRCUIT_ID
 ON CIRCUIT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_CIRCUIT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_COMPANY
 BEFORE INSERT OR UPDATE
 ON COMPANY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_COMPANY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_COMPANY
 BEFORE INSERT
 ON COMPANY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "COMPANY_ID" uses sequence SYSDB.SEQ_COMPANY_ID
    IF (:new.COMPANY_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_COMPANY_ID.NEXTVAL
        select SEQ_COMPANY_ID.NEXTVAL
        INTO :new.COMPANY_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_COMPANY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_COMPANY
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        COMPANY_ID,
        DATA_INS_USER
 ON COMPANY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_COMPANY
	ENABLE;


CREATE  OR REPLACE  TRIGGER Trigger_13102
 BEFORE INSERT OR UPDATE
 ON COMPANY_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER Trigger_13102
	ENABLE;


CREATE  OR REPLACE  TRIGGER Trigger_13103
 BEFORE UPDATE OF 
        COMPANY_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON COMPANY_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER Trigger_13103
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEPT
 BEFORE INSERT OR UPDATE
 ON DEPARTMENT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEPT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_DEPT
 BEFORE INSERT
 ON DEPARTMENT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "DEPT_ID" uses sequence SYSDB.SEQ_DEPT_ID
    IF (:new.DEPT_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_DEPT_ID.NEXTVAL
        select SEQ_DEPT_ID.NEXTVAL
        INTO :new.DEPT_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_DEPT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEPT
 BEFORE UPDATE OF 
        DEFAULT_BADGE_TYPE_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        COMPANY_ID
 ON DEPARTMENT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEPT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEVICE
 BEFORE INSERT OR UPDATE
 ON DEVICE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER C_TIUBR_DEVICE
	ENABLE;


CREATE  OR REPLACE  TRIGGER K_TIUBR_DEVICE
 BEFORE INSERT OR UPDATE OF 
        VOE_SYMBOLIC_TRACK_ID,
        OPERATING_SYSTEM_ID,
        VOE_ID
 ON DEVICE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

    v_voe_sw_pkg_repos      SW_PACKAGE_REPOSITORY.SW_PACKAGE_REPOSITORY_ID%TYPE;
    v_os_sw_pkg_repos      OPERATING_SYSTEM.SW_PACKAGE_REPOSITORY_ID%TYPE;
    v_voe_sym_trx_sw_pkg_repo_id    VOE_SYMBOLIC_TRACK.SW_PACKAGE_REPOSITORY_ID%TYPE;

begin


    SELECT SW_PACKAGE_REPOSITORY_ID into v_os_sw_pkg_repos
    FROM OPERATING_SYSTEM
    WHERE OPERATING_SYSTEM_ID=:new.OPERATING_SYSTEM_ID;

    IF (:new.VOE_ID is NOT NULL)
    THEN
        SELECT SW_PACKAGE_REPOSITORY_ID into v_voe_sw_pkg_repos
        FROM VOE
        WHERE VOE_ID=:new.VOE_ID;


        IF (  v_voe_sw_pkg_repos !=  v_os_sw_pkg_repos )
        THEN
                RAISE_APPLICATION_ERROR(global_errors.ERRNUM_DEV_SWPKGREPOS_MISMATCH,global_errors.ERRMSG_DEV_SWPKGREPOS_MISMATCH);
        END IF;
     END IF;


    IF( :new.voe_symbolic_track_id is not null)
    THEN

        SELECT  SW_PACKAGE_REPOSITORY_ID into  v_voe_sym_trx_sw_pkg_repo_id
        FROM  VOE_SYMBOLIC_TRACK
        WHERE   VOE_SYMBOLIC_TRACK_ID = :new.voe_symbolic_track_id;


        if( v_os_sw_pkg_repos != v_voe_sym_trx_sw_pkg_repo_id )
        THEN
             RAISE_APPLICATION_ERROR(global_errors.ERRNUM_DEV_VTRKOSREP_MISMATCH,global_errors.ERRMSG_DEV_VTRKOSREP_MISMATCH);
        END IF;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER K_TIUBR_DEVICE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_DEVICE
 BEFORE INSERT
 ON DEVICE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "DEVICE_ID" uses sequence SYSDB.SEQ_DEVICE_ID
    IF (:new.DEVICE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_DEVICE_ID.NEXTVAL
        select SEQ_DEVICE_ID.NEXTVAL
        INTO :new.DEVICE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER TIB_DEVICE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEVICE
 BEFORE UPDATE OF 
        VOE_SYMBOLIC_TRACK_ID,
        LOCATION_ID,
        DEVICE_TYPE_ID,
        OPERATING_SYSTEM_ID,
        IDENTIFYING_DNS_RECORD_ID,
        OWNERSHIP_STATUS,
        DEVICE_STATUS,
        DATA_INS_DATE,
        DATA_INS_USER,
        VOE_ID,
        DEVICE_ID,
        AUTO_MGMT_PROTOCOL,
        SERVICE_ENVIRONMENT,
        PARENT_DEVICE_ID
 ON DEVICE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER TUB_DEVICE
	ENABLE;


CREATE  TRIGGER C_TIUBR_DEVICE_COLL_ACCOUNT_CO
 BEFORE INSERT OR UPDATE
 ON DEVICE_COLL_ACCOUNT_COLL
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEVICE_COLL_ACCOUNT_CO
	ENABLE;


CREATE  TRIGGER TUB_DEVICE_COLL_ACCOUNT_COLL
 BEFORE UPDATE
 ON DEVICE_COLL_ACCOUNT_COLL
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEVICE_COLL_ACCOUNT_COLL
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEVICE_COLLECTION
 BEFORE INSERT OR UPDATE
 ON DEVICE_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEVICE_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_DEVICE_COLLECTION
 BEFORE INSERT
 ON DEVICE_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "DEVICE_COLLECTION_ID" uses sequence SYSDB.SEQ_DEVICE_COLLECTION_ID
    IF (:new.DEVICE_COLLECTION_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_DEVICE_COLLECTION_ID.NEXTVAL
        select SEQ_DEVICE_COLLECTION_ID.NEXTVAL
        INTO :new.DEVICE_COLLECTION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_DEVICE_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEVICE_COLLECTION
 BEFORE UPDATE OF 
        DEVICE_COLLECTION_ID,
        DEVICE_COLLECTION_NAME,
        DATA_INS_DATE,
        DATA_INS_USER,
        DEVICE_COLLECTION_TYPE
 ON DEVICE_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if; \

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER TUB_DEVICE_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEV_COLL_ASSIGND_CERT
 BEFORE INSERT OR UPDATE
 ON DEVICE_COLLECTION_ASSIGND_CERT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEV_COLL_ASSIGND_CERT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEV_COLL_ASSIGND_CERT
 BEFORE UPDATE
 ON DEVICE_COLLECTION_ASSIGND_CERT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEV_COLL_ASSIGND_CERT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEVICE_COLLECTION_DEVI
 BEFORE INSERT OR UPDATE
 ON DEVICE_COLLECTION_DEVICE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEVICE_COLLECTION_DEVI
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEVICE_COLLECTION_DEVICE
 BEFORE UPDATE OF 
        DEVICE_COLLECTION_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        DEVICE_ID
 ON DEVICE_COLLECTION_DEVICE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEVICE_COLLECTION_DEVICE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEVICE_COLLECTION_HIER
 BEFORE INSERT OR UPDATE
 ON DEVICE_COLLECTION_HIER
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEVICE_COLLECTION_HIER
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEVICE_COLLECTION_HIER
 BEFORE UPDATE OF 
        DEVICE_COLLECTION_ID,
        PARENT_DEVICE_COLLECTION_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON DEVICE_COLLECTION_HIER
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEVICE_COLLECTION_HIER
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEVICE_NOTE
 BEFORE INSERT OR UPDATE
 ON DEVICE_NOTE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEVICE_NOTE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_DEVICE_NOTE
 BEFORE INSERT
 ON DEVICE_NOTE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "NOTE_ID" uses sequence SYSDB.SEQ_NOTE_ID
    IF (:new.NOTE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_NOTE_ID.NEXTVAL
        select SEQ_NOTE_ID.NEXTVAL
        INTO :new.NOTE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_DEVICE_NOTE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEVICE_NOTE
 BEFORE UPDATE OF 
        NOTE_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        DEVICE_ID
 ON DEVICE_NOTE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEVICE_NOTE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEVICE_POWER_CONNECTIO
 BEFORE INSERT OR UPDATE
 ON DEVICE_POWER_CONNECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEVICE_POWER_CONNECTIO
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_DEVICE_POWER_CONNECTION
 BEFORE INSERT
 ON DEVICE_POWER_CONNECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "DEVICE_POWER_CONNECTION_ID" uses sequence SYSDB.SEQ_DEVICE_POWER_CONNECTION_ID
    IF (:new.DEVICE_POWER_CONNECTION_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_DEVICE_POWER_CONNECTION_ID.NEXTVAL
        select SEQ_DEVICE_POWER_CONNECTION_ID.NEXTVAL
        INTO :new.DEVICE_POWER_CONNECTION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_DEVICE_POWER_CONNECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEVICE_POWER_CONNECTION
 BEFORE UPDATE OF 
        POWER_INTERFACE_PORT,
        RPC_POWER_INTERFACE_PORT,
        DEVICE_POWER_CONNECTION_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        DEVICE_ID,
        RPC_DEVICE_ID
 ON DEVICE_POWER_CONNECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEVICE_POWER_CONNECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEVICE_POWER_INTERFACE
 BEFORE INSERT OR UPDATE
 ON DEVICE_POWER_INTERFACE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEVICE_POWER_INTERFACE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEVICE_POWER_INTERFACE
 BEFORE UPDATE OF 
        POWER_INTERFACE_PORT,
        DATA_INS_DATE,
        DATA_INS_USER,
        DEVICE_ID
 ON DEVICE_POWER_INTERFACE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEVICE_POWER_INTERFACE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEVICE_SSH_KEY
 BEFORE INSERT OR UPDATE
 ON DEVICE_SSH_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEVICE_SSH_KEY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEVICE_SSH_KEY
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER
 ON DEVICE_SSH_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEVICE_SSH_KEY
	ENABLE;


CREATE  TRIGGER C_TIBUR_DEVICE_TICKET
  BEFORE INSERT OR UPDATE
  ON DEVICE_TICKET
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
  
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;



/



ALTER TRIGGER C_TIBUR_DEVICE_TICKET
	ENABLE;


CREATE  TRIGGER TUB_DEVICE_TICKET
  BEFORE UPDATE
  ON DEVICE_TICKET
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
  
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;



/



ALTER TRIGGER TUB_DEVICE_TICKET
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEVICE_TYPE
 BEFORE INSERT OR UPDATE
 ON DEVICE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEVICE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_DEVICE_TYPE
 BEFORE INSERT
 ON DEVICE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "DEVICE_TYPE_ID" uses sequence SYSDB.SEQ_DEVICE_TYPE_ID
    IF (:new.DEVICE_TYPE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_DEVICE_TYPE_ID.NEXTVAL
        select SEQ_DEVICE_TYPE_ID.NEXTVAL
        INTO :new.DEVICE_TYPE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_DEVICE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEVICE_TYPE
 BEFORE UPDATE OF 
        DEVICE_TYPE_ID,
        DATA_INS_DATE,
        PROCESSOR_ARCHITECTURE,
        DATA_INS_USER
 ON DEVICE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEVICE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEVICE_TYPE_PHYS_PORT_
 BEFORE INSERT OR UPDATE
 ON DEVICE_TYPE_PHYS_PORT_TEMPLT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEVICE_TYPE_PHYS_PORT_
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEVICE_TYPE_PHYS_PORT_TEMP
 BEFORE UPDATE OF 
        PORT_NAME,
        DEVICE_TYPE_ID,
        PORT_PURPOSE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON DEVICE_TYPE_PHYS_PORT_TEMPLT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEVICE_TYPE_PHYS_PORT_TEMP
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DEVICE_TYPE_POWER_PORT
 BEFORE INSERT OR UPDATE
 ON DEVICE_TYPE_POWER_PORT_TEMPLT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DEVICE_TYPE_POWER_PORT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DEVICE_TYPE_POWER_PORT_TEM
 BEFORE UPDATE OF 
        POWER_INTERFACE_PORT,
        DEVICE_TYPE_ID,
        PLUG_STYLE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON DEVICE_TYPE_POWER_PORT_TEMPLT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DEVICE_TYPE_POWER_PORT_TEM
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DHCP_RANGE
 BEFORE INSERT OR UPDATE
 ON DHCP_RANGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DHCP_RANGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_DHCP_RANGE
 BEFORE INSERT
 ON DHCP_RANGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "DHCP_RANGE_ID" uses sequence SYSDB.SEQ_DHCP_RANGE_ID
    IF (:new.DHCP_RANGE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_DHCP_RANGE_ID.NEXTVAL
        select SEQ_DHCP_RANGE_ID.NEXTVAL
        INTO :new.DHCP_RANGE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_DHCP_RANGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DHCP_RANGE
 BEFORE UPDATE OF 
        DHCP_RANGE_ID,
        START_NETBLOCK_ID,
        NETWORK_INTERFACE_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        STOP_NETBLOCK_ID
 ON DHCP_RANGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DHCP_RANGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DNS_DOMAIN
 BEFORE INSERT OR UPDATE
 ON DNS_DOMAIN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DNS_DOMAIN
	ENABLE;


CREATE  OR REPLACE  TRIGGER K_TIUBR_DNS_DOMAIN
 BEFORE INSERT OR UPDATE
 ON DNS_DOMAIN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
begin

-- Overwrite the zone_last_updated, but only if updating the record where the generation is the same or insert of a new record
  if INSERTING OR (UPDATING AND :old.last_generated = :new.last_generated) THEN
        :new.zone_last_updated := sysdate;
   end if;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER K_TIUBR_DNS_DOMAIN
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_DNS_DOMAIN
 BEFORE INSERT
 ON DNS_DOMAIN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "DNS_DOMAIN_ID" uses sequence SYSDB.SEQ_DNS_DOMAIN_ID
    IF (:new.DNS_DOMAIN_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_DNS_DOMAIN_ID.NEXTVAL
        select SEQ_DNS_DOMAIN_ID.NEXTVAL
        INTO :new.DNS_DOMAIN_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_DNS_DOMAIN
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DNS_DOMAIN
 BEFORE UPDATE OF 
        PARENT_DNS_DOMAIN_ID,
        DNS_DOMAIN_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON DNS_DOMAIN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DNS_DOMAIN
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DNS_RECORD
 BEFORE INSERT OR UPDATE
 ON DNS_RECORD
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DNS_RECORD
	ENABLE;


CREATE  OR REPLACE  TRIGGER K_TIUDBR_DNS_RECORD
 BEFORE DELETE OR INSERT OR UPDATE
 ON DNS_RECORD
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
begin
    IF INSERTING or UPDATING
    THEN
            update  dns_domain
            set  zone_last_updated = sysdate
            where   dns_domain_id = :new.dns_domain_id;

            if :new.dns_type = 'A' THEN
                    update  dns_domain
                    set  zone_last_updated = sysdate
                    where  dns_domain_id =
                            netblock_utils.find_rvs_zone_from_netblock_id(:new.netblock_id);
            end if;

            IF UPDATING
            THEN
                if (:old.dns_domain_id <> :new.dns_domain_id)
                then
                        update  dns_domain
                           set  zone_last_updated = sysdate
                         where  dns_domain_id = :old.dns_domain_id;
                end if;
                if (:new.dns_type = 'A' )
                THEN
                        if :old.netblock_id <> :new.netblock_id then
                                update  dns_domain
                                   set  zone_last_updated = sysdate
                                 where  dns_domain_id =
                                        netblock_utils.find_rvs_zone_from_netblock_id(:old.netblock_id);
                        end if;
                END IF;
            END IF;
    END IF;

    IF DELETING
    THEN
        update  dns_domain
           set  zone_last_updated = sysdate
        where   dns_domain_id = :old.dns_domain_id;

        if :old.dns_type = 'A' THEN
                update  dns_domain
                   set  zone_last_updated = sysdate
                 where  dns_domain_id =
                        netblock_utils.find_rvs_zone_from_netblock_id(:old.netblock_id);
        END IF;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER K_TIUDBR_DNS_RECORD
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_DNS_RECORD
 BEFORE INSERT
 ON DNS_RECORD
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "DNS_RECORD_ID" uses sequence SYSDB.SEQ_DNS_RECORD_ID
    IF (:new.DNS_RECORD_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_DNS_RECORD_ID.NEXTVAL
        select SEQ_DNS_RECORD_ID.NEXTVAL
        INTO :new.DNS_RECORD_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_DNS_RECORD
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DNS_RECORD
 BEFORE UPDATE OF 
        NETBLOCK_ID,
        DNS_TYPE,
        DNS_VALUE_RECORD_ID,
        DNS_CLASS,
        DNS_DOMAIN_ID,
        DATA_INS_DATE,
        DNS_SRV_SERVICE,
        DATA_INS_USER,
        REFERENCE_DNS_RECORD_ID,
        DNS_RECORD_ID
 ON DNS_RECORD
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DNS_RECORD
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_DNS_RECORD_RELATION
 BEFORE INSERT OR UPDATE
 ON DNS_RECORD_RELATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_DNS_RECORD_RELATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_DNS_RECORD_RELATION
 BEFORE UPDATE OF 
        RELATED_DNS_RECORD_ID,
        DNS_RECORD_RELATION_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER,
        DNS_RECORD_ID
 ON DNS_RECORD_RELATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_DNS_RECORD_RELATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ENCAPSULATION
 BEFORE INSERT OR UPDATE
 ON ENCAPSULATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ENCAPSULATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_ENCAPSULATION
 BEFORE INSERT
 ON ENCAPSULATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "ENCAPSULATION_ID" uses sequence SYSDB.SEQ_ENCAPSULATION_ID
    IF (:new.ENCAPSULATION_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_ENCAPSULATION_ID.NEXTVAL
        select SEQ_ENCAPSULATION_ID.NEXTVAL
        INTO :new.ENCAPSULATION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_ENCAPSULATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ENCAPSULATION
 BEFORE UPDATE OF 
        ENCAPSULATION_TYPE,
        VLAN_RANGE_ID,
        DATA_INS_DATE,
        ENCAPSULATION_ID,
        DATA_INS_USER
 ON ENCAPSULATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ENCAPSULATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ENCRYPTION_KEY
 BEFORE INSERT OR UPDATE
 ON ENCRYPTION_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ENCRYPTION_KEY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_ENCRYPTION_KEY
 BEFORE INSERT
 ON ENCRYPTION_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
	integrity_error  exception;
	errno			integer;
	errmsg		   char(200);
	dummy			integer;
	found			boolean;

begin
	-- For sequences, only update column if null
	--  Column "ENCRYPTION_KEY_ID" uses sequence SYSDB.SEQ_ENCRYPTION_KEY_ID
	IF (:new.ENCRYPTION_KEY_ID IS NULL)
	THEN
		-- Was the following.  Removed owner because quest
		-- doesn't handle it properly (for non owner builds)
		--select SYSDB.SEQ_ENCRYPTION_KEY_ID.NEXTVAL
		select SEQ_ENCRYPTION_KEY_ID.NEXTVAL
		INTO :new.ENCRYPTION_KEY_ID
		from dual;
	END IF;

--  Errors handling
exception
	when integrity_error then
	   raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_ENCRYPTION_KEY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ENCRYPTION_KEY
 BEFORE UPDATE
 ON ENCRYPTION_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ENCRYPTION_KEY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_IP_UNIVERSE
 BEFORE INSERT OR UPDATE
 ON IP_UNIVERSE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_IP_UNIVERSE
	ENABLE;


CREATE  TRIGGER TIB_IP_UNIVERSE
 BEFORE INSERT
 ON IP_UNIVERSE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    IF (:new.IP_UNIVERSE_ID IS NULL)
    THEN

        select SEQ_IP_UNIVERSE_ID.NEXTVAL
        INTO :new.IP_UNIVERSE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_IP_UNIVERSE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_IP_UNIVERSE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        IP_UNIVERSE_NAME
 ON IP_UNIVERSE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_IP_UNIVERSE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_KERBEROS_REALM
 BEFORE INSERT OR UPDATE
 ON KERBEROS_REALM
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_KERBEROS_REALM
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_KERBEROS_REALM
 BEFORE INSERT
 ON KERBEROS_REALM
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "KRB_REALM_ID" uses sequence SYSDB.SEQ_KRB_REALM_ID
    IF (:new.KRB_REALM_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_KRB_REALM_ID.NEXTVAL
        select SEQ_KRB_REALM_ID.NEXTVAL
        INTO :new.KRB_REALM_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_KERBEROS_REALM
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_KERBEROS_REALM
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        KRB_REALM_ID
 ON KERBEROS_REALM
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_KERBEROS_REALM
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_KLOGIN
 BEFORE INSERT OR UPDATE
 ON KLOGIN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_KLOGIN
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_KLOGIN
 BEFORE INSERT
 ON KLOGIN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "KLOGIN_ID" uses sequence SYSDB.SEQ_KLOGIN_ID
    IF (:new.KLOGIN_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_KLOGIN_ID.NEXTVAL
        select SEQ_KLOGIN_ID.NEXTVAL
        INTO :new.KLOGIN_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_KLOGIN
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_KLOGIN
 BEFORE UPDATE OF 
        KLOGIN_ID,
        ACCOUNT_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        KRB_REALM_ID,
        DEST_ACCOUNT_ID,
        ACCOUNT_COLLECTION_ID
 ON KLOGIN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_KLOGIN
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_KLOGIN_MCLASS
 BEFORE INSERT OR UPDATE
 ON KLOGIN_MCLASS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_KLOGIN_MCLASS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_KLOGIN_MCLASS
 BEFORE UPDATE OF 
        DEVICE_COLLECTION_ID,
        KLOGIN_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON KLOGIN_MCLASS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_KLOGIN_MCLASS
	ENABLE;


CREATE  TRIGGER C_TIUA_LAYER1_CONNECTION
  AFTER INSERT OR UPDATE OF 
        PHYSICAL_PORT1_ID,
        PHYSICAL_PORT2_ID
  ON LAYER1_CONNECTION
  
  
  
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    v_cnt            number;
begin
    select count(*) into v_cnt
    from layer1_connection l1 join layer1_connection l2
    on  l1.physical_port1_id = l2.physical_port2_id
    and l1.physical_port2_id = l2.physical_port1_id;

    if ( v_cnt > 0 ) then
        errno  := -20001;
        errmsg := 'Connection already exists in opposite direction';
        raise integrity_error;
    end if;

exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER C_TIUA_LAYER1_CONNECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_LAYER1_CONNECTION
 BEFORE INSERT OR UPDATE
 ON LAYER1_CONNECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_LAYER1_CONNECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_LAYER1_CONNECTION
 BEFORE INSERT
 ON LAYER1_CONNECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "LAYER1_CONNECTION_ID" uses sequence SYSDB.SEQ_LAYER1_CONNECTION_ID
    IF (:new.LAYER1_CONNECTION_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_LAYER1_CONNECTION_ID.NEXTVAL
        select SEQ_LAYER1_CONNECTION_ID.NEXTVAL
        INTO :new.LAYER1_CONNECTION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_LAYER1_CONNECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_LAYER1_CONNECTION
 BEFORE UPDATE OF 
        TCPSRV_DEVICE_ID,
        LAYER1_CONNECTION_ID,
        PHYSICAL_PORT2_ID,
        PARITY,
        STOP_BITS,
        DATA_INS_DATE,
        DATA_BITS,
        DATA_INS_USER,
        FLOW_CONTROL,
        CIRCUIT_ID,
        BAUD,
        PHYSICAL_PORT1_ID
 ON LAYER1_CONNECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_LAYER1_CONNECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_LAYER2_ENCAPSULATION
 BEFORE INSERT OR UPDATE
 ON LAYER2_ENCAPSULATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_LAYER2_ENCAPSULATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_LAYER2_ENCAPSULATION
 BEFORE INSERT
 ON LAYER2_ENCAPSULATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "LAYER2_ENCAPSULATION_ID" uses sequence SEQ_LAYER2_ENCAPSULATION_ID
    IF (:new.LAYER2_ENCAPSULATION_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SEQ_LAYER2_ENCAPSULATION_ID.NEXTVAL
        select SEQ_LAYER2_ENCAPSULATION_ID.NEXTVAL
        INTO :new.LAYER2_ENCAPSULATION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_LAYER2_ENCAPSULATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_LAYER2_ENCAPSULATION
 BEFORE UPDATE OF 
        LAYER2_ENCAPSULATION_ID,
        PHYSICAL_PORT_ID,
        DATA_INS_DATE,
        ENCAPSULATION_ID,
        DATA_INS_USER
 ON LAYER2_ENCAPSULATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_LAYER2_ENCAPSULATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_LOCATION
 BEFORE INSERT OR UPDATE
 ON LOCATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_LOCATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_LOCATION
 BEFORE INSERT
 ON LOCATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "LOCATION_ID" uses sequence SYSDB.SEQ_LOCATION_ID
    IF (:new.LOCATION_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_LOCATION_ID.NEXTVAL
        select SEQ_LOCATION_ID.NEXTVAL
        INTO :new.LOCATION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_LOCATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_LOCATION
 BEFORE UPDATE OF 
        LOCATION_ID,
        RACK_U_OFFSET_OF_DEVICE_TOP,
        INTER_DEVICE_OFFSET,
        DATA_INS_DATE,
        RACK_SIDE,
        RACK_ID,
        DATA_INS_USER
 ON LOCATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_LOCATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_NETBLOCK
 BEFORE INSERT OR UPDATE
 ON NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_NETBLOCK
	ENABLE;


CREATE  OR REPLACE  TRIGGER K_TAIU_NONROW_NETBLOCK
 AFTER INSERT OR UPDATE
 ON NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 
 
declare
    integrity_error  exception;
    errno           integer;
    errmsg         char(200);
    found          boolean;

begin
        netblock_verify.check_parent_child;

        -- Remove all entries in the global list
        netblock_verify.G_changed_netblock_ids.delete;
end;

/



ALTER TRIGGER K_TAIU_NONROW_NETBLOCK
	DISABLE;


CREATE  OR REPLACE  TRIGGER K_TBIU_NETBLOCK
 BEFORE INSERT OR UPDATE
 ON NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
        numrows integer;
        bits    integer;
        pip         netblock.ip_address%type;
        pbits   netblock.netmask_bits%type;
begin
        /*
         * XXX consider being nice and converting a dotted quad or IPv6
         * address to a numeric version; this may be too nice, though.
         */

        /*
         * for now only support ipv4 addresses
         */
        if( :new.netmask_bits > 32) then
                raise_application_error(global_errors.ERRNUM_NETBLOCK_IPV4ONLY, global_errors.ERRMSG_NETBLOCK_IPV4ONLY);
        end if;

        /*
         * require that ip address + bits do not  match another entry,
         * unless it's in 1918 space in which case multiple entries can
         * exist.
         */
        if net_manip.inet_is_private(:new.ip_address) = false then
                numrows := netblock_verify.count_matching_rows(:new.ip_address, :new.netmask_bits);
                if(inserting and numrows > 0) then
                        raise_application_error(global_errors.ERRNUM_NETBLOCK_NODUPS, global_errors.ERRMSG_NETBLOCK_NODUPS || ': ' || :new.ip_address || '/' || :new.netmask_bits);
                end if;
                if(updating and :new.ip_address != :old.ip_address and numrows > 0) then
                        raise_application_error(global_errors.ERRNUM_NETBLOCK_NODUPS, global_errors.ERRMSG_NETBLOCK_NODUPS || ': ' || :new.ip_address || '/' || :new.netmask_bits);

                end if;
        end if;

        --
        -- check to see that the new netblock is still within the parent
        -- netblock of the old netblock

        if((:new.parent_netblock_Id is not NULL) and
           (:new.ip_address != :old.ip_address or
            :new.netmask_bits != :old.netmask_bits)) then

                netblock_verify.get_netblock_ip_and_bits(:new.parent_netblock_id, pip, pbits);
                if(pbits > :new.netmask_bits) then
                        raise_application_error(global_errors.ERRNUM_NETBLOCK_SMALLPARENT, global_errors.ERRMSG_NETBLOCK_SMALLPARENT || '(' || :new.parent_netblock_Id || ')');
                end if;

                if(net_manip.inet_inblock(pip, pbits, :new.ip_address) = 'N') then
                        raise_application_error(global_errors.ERRNUM_NETBLOCK_RANGEERROR, global_errors.ERRMSG_NETBLOCK_RANGEERROR);
                end if;

        end if;


        /*
         * no need to burden new inserts with having to pick out a unique
         * _Id, although I would imagine most would do this on their own...
         *
         */
        if( :new.Netblock_Id is null ) then
                select
                        SEQ_Netblock_Id.nextval into :new.Netblock_Id
                from
                        DUAL;
        end if;

        --
        -- toss this new netblock id into the list of modified netblocks that
        -- will later be checked to see that their children are still their
        -- children
        if(netblock_verify.G_changed_netblock_ids.last is NULL) THEN
                netblock_verify.G_changed_netblock_ids(1) :=
                        :new.netblock_id;
        else
                netblock_verify.G_changed_netblock_ids(netblock_verify.G_changed_netblock_ids.last+1) :=
                        :new.netblock_id;
        end if;


end;

/



ALTER TRIGGER K_TBIU_NETBLOCK
	DISABLE;


CREATE  OR REPLACE  TRIGGER K_TBIU_NONROW_NETBLOCK
 BEFORE INSERT OR UPDATE
 ON NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 
 
begin
    -- Remove all entries in the global list
    -- This before statement trigger will fire before the before row triggers.
        netblock_verify.G_changed_netblock_ids.delete;
end;

/



ALTER TRIGGER K_TBIU_NONROW_NETBLOCK
	DISABLE;


CREATE  OR REPLACE  TRIGGER K_TIUB_NETBLOCK
 BEFORE INSERT OR UPDATE
 ON NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    v_domid         dns_record.dns_record_id%type;
begin
        if  (:new.ip_address <> :old.ip_address) OR
            (:new.netmask_bits <> :old.netmask_bits) THEN
                update  dns_domain
                   set  zone_last_updated = sysdate
                 where  dns_domain_id =
                        netblock_utils.find_rvs_zone_from_netblock_id(:new.netblock_id);
                update  dns_domain
                   set  zone_last_updated = sysdate
                 where  dns_domain_id =
                        netblock_utils.find_rvs_zone_from_netblock_id(:old.netblock_id);
        end if;

        update  dns_domain
           set  zone_last_updated = sysdate
          where dns_domain_id in
                        (select dns_domain_id
                          from  dns_record
                          where netblock_id = :new.netblock_id
                        );

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER K_TIUB_NETBLOCK
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_NETBLOCK
 BEFORE INSERT
 ON NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "NETBLOCK_ID" uses sequence SYSDB.SEQ_NETBLOCK_ID
    IF (:new.NETBLOCK_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_NETBLOCK_ID.NEXTVAL
        select SEQ_NETBLOCK_ID.NEXTVAL
        INTO :new.NETBLOCK_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_NETBLOCK
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_NETBLOCK
 BEFORE UPDATE OF 
        NETBLOCK_ID,
        PARENT_NETBLOCK_ID,
        DATA_INS_DATE,
        NETBLOCK_STATUS,
        DATA_INS_USER
 ON NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_NETBLOCK
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_NETBLOCK_COLLECTION
 BEFORE INSERT OR UPDATE
 ON NETBLOCK_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_NETBLOCK_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_NETBLOCK_COLLECTION
 BEFORE INSERT
 ON NETBLOCK_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    IF (:new.NETBLOCK_COLLECTION_ID IS NULL)
    THEN
        select SEQ_NETBLOCK_COLLECTION_ID.NEXTVAL
        INTO :new.NETBLOCK_COLLECTION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_NETBLOCK_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_NETBLOCK_COLLECTION
 BEFORE UPDATE OF 
        NETBLOCK_COLLECTION_NAME,
        DATA_INS_DATE,
        DATA_INS_USER,
        NETBLOCK_COLLECTION_ID
 ON NETBLOCK_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_NETBLOCK_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_NETBLOCK_COLLECTION_HI
 BEFORE INSERT OR UPDATE
 ON NETBLOCK_COLLECTION_HIER
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_NETBLOCK_COLLECTION_HI
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_NETBLOCK_COLLECTION_HIER
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER
 ON NETBLOCK_COLLECTION_HIER
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_NETBLOCK_COLLECTION_HIER
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_ACCOUNT_COLLECTION_ACC
 BEFORE INSERT OR UPDATE
 ON NETBLOCK_COLLECTION_NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_ACCOUNT_COLLECTION_ACC
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_ACCOUNT_COLLECTION_ACCOUNT
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER
 ON NETBLOCK_COLLECTION_NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_ACCOUNT_COLLECTION_ACCOUNT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_NETWORK_INTERFACE
 BEFORE INSERT OR UPDATE
 ON NETWORK_INTERFACE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_NETWORK_INTERFACE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_NETWORK_INTERFACE
 BEFORE INSERT
 ON NETWORK_INTERFACE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "NETWORK_INTERFACE_ID" uses sequence SYSDB.SEQ_NETWORK_INTERFACE_ID
    IF (:new.NETWORK_INTERFACE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_NETWORK_INTERFACE_ID.NEXTVAL
        select SEQ_NETWORK_INTERFACE_ID.NEXTVAL
        INTO :new.NETWORK_INTERFACE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_NETWORK_INTERFACE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_NETWORK_INTERFACE
 BEFORE UPDATE OF 
        V4_NETBLOCK_ID,
        NETWORK_INTERFACE_TYPE,
        PHYSICAL_PORT_ID,
        PARENT_NETWORK_INTERFACE_ID,
        V6_NETBLOCK_ID,
        NETWORK_INTERFACE_ID,
        DATA_INS_DATE,
        NETWORK_INTERFACE_PURPOSE,
        DATA_INS_USER,
        DEVICE_ID
 ON NETWORK_INTERFACE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_NETWORK_INTERFACE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_NETWORK_SERVICE
 BEFORE INSERT OR UPDATE
 ON NETWORK_SERVICE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_NETWORK_SERVICE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_NETWORK_SERVICE
 BEFORE INSERT
 ON NETWORK_SERVICE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "NETWORK_SERVICE_ID" uses sequence SYSDB.SEQ_NETWORK_SERVICE_ID
    IF (:new.NETWORK_SERVICE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_NETWORK_SERVICE_ID.NEXTVAL
        select SEQ_NETWORK_SERVICE_ID.NEXTVAL
        INTO :new.NETWORK_SERVICE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_NETWORK_SERVICE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_NETWORK_SERVICE
 BEFORE UPDATE OF 
        NETWORK_SERVICE_ID,
        NETWORK_INTERFACE_ID,
        DATA_INS_DATE,
        NETWORK_SERVICE_TYPE,
        DATA_INS_USER,
        DEVICE_ID,
        SERVICE_ENVIRONMENT,
        DNS_RECORD_ID
 ON NETWORK_SERVICE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_NETWORK_SERVICE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_OPERATING_SYSTEM
 BEFORE INSERT OR UPDATE
 ON OPERATING_SYSTEM
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_OPERATING_SYSTEM
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_OPERATING_SYSTEM
 BEFORE INSERT
 ON OPERATING_SYSTEM
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "OPERATING_SYSTEM_ID" uses sequence SYSDB.SEQ_OPERATING_SYSTEM_ID
    IF (:new.OPERATING_SYSTEM_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_OPERATING_SYSTEM_ID.NEXTVAL
        select SEQ_OPERATING_SYSTEM_ID.NEXTVAL
        INTO :new.OPERATING_SYSTEM_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_OPERATING_SYSTEM
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_OPERATING_SYSTEM
 BEFORE UPDATE OF 
        OPERATING_SYSTEM_ID,
        DATA_INS_DATE,
        PROCESSOR_ARCHITECTURE,
        DATA_INS_USER,
        SW_PACKAGE_REPOSITORY_ID
 ON OPERATING_SYSTEM
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_OPERATING_SYSTEM
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIB_PERSON
 BEFORE INSERT
 ON PERSON
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "PERSON_ID" uses sequence SYSDB.SEQ_PERSON_ID
    IF (:new.PERSON_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_PERSON_ID.NEXTVAL
        select SEQ_PERSON_ID.NEXTVAL
        INTO :new.PERSON_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIB_PERSON
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PERSON
 BEFORE INSERT OR UPDATE
 ON PERSON
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PERSON
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PERSON
 BEFORE UPDATE OF 
        PERSON_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON PERSON
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PERSON
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PERSON_ACCT_REALM_COMP
 BEFORE INSERT OR UPDATE
 ON PERSON_ACCOUNT_REALM_COMPANY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PERSON_ACCT_REALM_COMP
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PERSON_ACCT_REALM_COMPANY
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER
 ON PERSON_ACCOUNT_REALM_COMPANY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PERSON_ACCT_REALM_COMPANY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PERSON_AUTH_QUESTION
 BEFORE INSERT OR UPDATE
 ON PERSON_AUTH_QUESTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
	integrity_error  exception;
	errno			integer;
	errmsg		   char(200);
	dummy			integer;
	found			boolean;
	V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
	-- Context should be used by apps to list the end-user id.
	-- if it is filled, then concatenate it on.
	V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
	V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

	IF INSERTING
	THEN
		-- Override whatever is passed with context user
		:new.data_ins_user:=V_CONTEXT_USER;

		-- Force date to be sysdate
		:new.data_ins_date:=sysdate;
	END IF;

	IF UPDATING
	THEN
		-- Preventing changes to insert user and date columns happens in
		-- another trigger

		-- Override whatever is passed with context user
		:new.data_upd_user:=V_CONTEXT_USER;

		-- Force date to be sysdate
		:new.data_upd_date:=sysdate;
	END IF;



--  Errors handling
exception
	when integrity_error then
	   raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PERSON_AUTH_QUESTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PERSON_AUTH_QUESTION
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER
 ON PERSON_AUTH_QUESTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
	integrity_error  exception;
	errno			integer;
	errmsg		   char(200);
	dummy			integer;
	found			boolean;

begin
	--  Non modifiable column "DATA_INS_USER" cannot be modified
	if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
	   errno  := -20001;
	   errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
	   raise integrity_error;
	end if;

	--  Non modifiable column "DATA_INS_DATE" cannot be modified
	if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
	   errno  := -20001;
	   errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
	   raise integrity_error;
	end if;


--  Errors handling
exception
	when integrity_error then
	   raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PERSON_AUTH_QUESTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PERSON_COMPANY
 BEFORE INSERT OR UPDATE
 ON PERSON_COMPANY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PERSON_COMPANY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PERSON_COMPANY
 BEFORE UPDATE OF 
        BADGE_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        COMPANY_ID,
        EMPLOYEE_ID
 ON PERSON_COMPANY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PERSON_COMPANY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PERSON_CONTACT
 BEFORE INSERT OR UPDATE
 ON PERSON_CONTACT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PERSON_CONTACT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_PERSON_CONTACT
 BEFORE INSERT
 ON PERSON_CONTACT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    IF (:new.PERSON_CONTACT_ID IS NULL)
    THEN
        select SEQ_PERSON_CONTACT_ID.NEXTVAL
        INTO :new.PERSON_CONTACT_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_PERSON_CONTACT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PERSON_CONTACT
 BEFORE UPDATE OF 
        PERSON_CONTACT_ORDER,
        ISO_COUNTRY_CODE,
        PERSON_CONTACT_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON PERSON_CONTACT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PERSON_CONTACT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PERSON_IMAGE
 BEFORE INSERT OR UPDATE
 ON PERSON_IMAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PERSON_IMAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_PERSON_IMAGE
 BEFORE INSERT
 ON PERSON_IMAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    IF (:new.PERSON_IMAGE_ID IS NULL)
    THEN
        select SEQ_PERSON_IMAGE_ID.NEXTVAL
        INTO :new.PERSON_IMAGE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_PERSON_IMAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PERSON_IMAGE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        PERSON_IMAGE_ID,
        IMAGE_TYPE
 ON PERSON_IMAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PERSON_IMAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PERSON_IMAGE_USAGE
 BEFORE INSERT OR UPDATE
 ON PERSON_IMAGE_USAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PERSON_IMAGE_USAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PERSON_IMAGE_USAGE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER
 ON PERSON_IMAGE_USAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PERSON_IMAGE_USAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PERSON_LOCATION
 BEFORE INSERT OR UPDATE
 ON PERSON_LOCATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PERSON_LOCATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER K_TAIUD_PERSON_SITE
 AFTER DELETE OR INSERT OR UPDATE
 ON PERSON_LOCATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
DECLARE
	integrity_error	exception;
	errno			integer;
	errmsg			char(200);
	site			System_User_Location.Office_Site%TYPE;
	uclass_name		UClass.Name%TYPE;
	ucid			UClass.UClass_ID%TYPE;
BEGIN
	IF UPDATING OR DELETING THEN
		IF UPDATING THEN
			IF :OLD.Office_Site = :NEW.Office_Site THEN
				RETURN;
			END IF;
		END IF;

		-- Remove the user out of the old site uclass

		site := :OLD.Office_Site;
		IF site IS NULL THEN
			site := 'none';
		END IF;
		--
		-- The following awesome nested regex does the following to the
		-- site name:
		--   - eliminate anything after the first comma or parens
		--   - eliminate all non-alphanumerics (except spaces)
		--   - convert spaces to underscores
		--   - lowercase
		--
		uclass_name := 'all_site_' || regexp_replace(
					regexp_replace(
						regexp_replace(
							regexp_replace(lower(site),
							' ?[,(].*$'),
						'&', 'and'),
					'[^A-Za-z0-9 ]', ''),
				' ', '_');


		DELETE FROM UClass_User WHERE
			System_User_ID = :OLD.System_User_ID AND
			UClass_ID = (
				SELECT UClass_ID FROM UClass WHERE
					Name = uclass_name AND
					UClass_Type = 'systems'
			);
	END IF;

	IF DELETING THEN
		RETURN;
	END IF;

	-- Insert the user into the new site uclass

	site := :NEW.Office_Site;
	IF site IS NULL THEN
		site := 'none';
	END IF;
	--
	-- The following awesome nested regex does the following to the
	-- site name:
	--   - eliminate anything after the first comma or parens
	--   - eliminate all non-alphanumerics (except spaces)
	--   - convert spaces to underscores
	--   - lowercase
	--
	uclass_name := 'all_site_' || regexp_replace(
					regexp_replace(
						regexp_replace(
							regexp_replace(lower(site),
							' ?[,(].*$'),
						'&', 'and'),
					'[^A-Za-z0-9 ]', ''),
				' ', '_');

	BEGIN
		SELECT UClass_ID INTO ucid FROM UClass WHERE
			Name = uclass_name AND
			UClass_Type = 'systems';
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			INSERT INTO UClass (
				Name, UClass_Type
			) VALUES (
				uclass_name, 'systems'
			) RETURNING UClass_ID INTO ucid;
	END;
	IF ucid IS NOT NULL THEN
		INSERT INTO UClass_User (
				UClass_ID,
				System_User_ID
			) VALUES (
				ucid,
				:NEW.System_User_ID
			);
	END IF;
END;
/



ALTER TRIGGER K_TAIUD_PERSON_SITE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_PERSON_LOCATION
 BEFORE INSERT
 ON PERSON_LOCATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    IF (:new.PERSON_LOCATION_ID IS NULL)
    THEN

        select SEQ_PERSON_LOCATION_ID.NEXTVAL
        INTO :new.PERSON_LOCATION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_PERSON_LOCATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PERSON_LOCATION
 BEFORE UPDATE OF 
        PERSON_LOCATION_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON PERSON_LOCATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PERSON_LOCATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PERSON_NOTE
 BEFORE INSERT OR UPDATE
 ON PERSON_NOTE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PERSON_NOTE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_PRESON_NOTE
 BEFORE INSERT
 ON PERSON_NOTE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "NOTE_ID" uses sequence SYSDB.SEQ_NOTE_ID
    IF (:new.NOTE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_NOTE_ID.NEXTVAL
        select SEQ_NOTE_ID.NEXTVAL
        INTO :new.NOTE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_PRESON_NOTE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PERSON_NOTE
 BEFORE UPDATE OF 
        NOTE_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON PERSON_NOTE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PERSON_NOTE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PERSON_PARKING_PASS
 BEFORE INSERT OR UPDATE
 ON PERSON_PARKING_PASS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PERSON_PARKING_PASS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_PERSON_PARKING_PASS
 BEFORE INSERT
 ON PERSON_PARKING_PASS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "PERSON_PARKING_PASS_ID" uses sequence SYSDB.SEQ_SYSTEM_PARKING_PASS_ID
    IF (:new.PERSON_PARKING_PASS_ID IS NULL)
    THEN
        select SEQ_SYSTEM_PARKING_PASS_ID.NEXTVAL
        INTO :new.PERSON_PARKING_PASS_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_PERSON_PARKING_PASS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PERSON_PARKING_PASS
 BEFORE UPDATE OF 
        PERSON_PARKING_PASS_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON PERSON_PARKING_PASS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PERSON_PARKING_PASS
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PERSON_VEHICLE
 BEFORE INSERT OR UPDATE
 ON PERSON_VEHICLE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PERSON_VEHICLE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_PERSON_VEHICLE
 BEFORE INSERT
 ON PERSON_VEHICLE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    IF (:new.PERSON_VEHICLE_ID IS NULL)
    THEN
        select SEQ_PERSON_VEHICLE_ID.NEXTVAL
        INTO :new.PERSON_VEHICLE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_PERSON_VEHICLE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PERSON_VEHICLE
 BEFORE UPDATE OF 
        VEHICLE_LICENSE_PLATE,
        VEHICLE_LICENSE_STATE,
        DATA_INS_DATE,
        DATA_INS_USER,
        PERSON_VEHICLE_ID
 ON PERSON_VEHICLE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PERSON_VEHICLE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PHYSICAL_ADDRESS
 BEFORE INSERT OR UPDATE
 ON PHYSICAL_ADDRESS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PHYSICAL_ADDRESS
	ENABLE;


CREATE  TRIGGER TIB_PHYSICAL_ADDRESS
 BEFORE 
 ON PHYSICAL_ADDRESS
 
 
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    IF (:new.PHYSICAL_ADDRESS_ID IS NULL)
    THEN

        select SEQ_PHYSICAL_ADDRESS_ID.NEXTVAL
        INTO :new.PHYSICAL_ADDRESS_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/


CREATE  OR REPLACE  TRIGGER TUB_PHYSICAL_ADDRESS
 BEFORE UPDATE OF 
        PHYSICAL_ADDRESS_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON PHYSICAL_ADDRESS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PHYSICAL_ADDRESS
	ENABLE;


CREATE  TRIGGER C_TIUA_PHYSICAL_CONNECTION
  AFTER INSERT OR UPDATE OF 
        PHYSICAL_PORT_ID1,
        PHYSICAL_PORT_ID2
  ON PHYSICAL_CONNECTION
  
  
  
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    v_cnt            number;

begin
    select count(*) into v_cnt
    from physical_connection l1 join physical_connection l2
    on  l1.physical_port_id1 = l2.physical_port_id2
    and l1.physical_port_id2 = l2.physical_port_id1;

    if ( v_cnt > 0 ) then
        errno  := -20001;
        errmsg := 'Connection already exists in opposite direction';
        raise integrity_error;
    end if;

exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER C_TIUA_PHYSICAL_CONNECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PHYSICAL_CONNECTION
 BEFORE INSERT OR UPDATE
 ON PHYSICAL_CONNECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PHYSICAL_CONNECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_PHYSICAL_CONNECTION
 BEFORE INSERT
 ON PHYSICAL_CONNECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "PHYSICAL_CONNECTION_ID" uses sequence SYSDB.SEQ_PATCH_PANEL_CONNECTION_ID
    IF (:new.PHYSICAL_CONNECTION_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_PATCH_PANEL_CONNECTION_ID.NEXTVAL
        select SEQ_PATCH_PANEL_CONNECTION_ID.NEXTVAL
        INTO :new.PHYSICAL_CONNECTION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_PHYSICAL_CONNECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PHYSICAL_CONNECTION
 BEFORE UPDATE OF 
        CABLE_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER,
        PHYSICAL_CONNECTION_ID,
        PHYSICAL_PORT_ID1,
        PHYSICAL_PORT_ID2
 ON PHYSICAL_CONNECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PHYSICAL_CONNECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PHYSICAL_PORT
 BEFORE INSERT OR UPDATE
 ON PHYSICAL_PORT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PHYSICAL_PORT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_PHYSICAL_PORT
 BEFORE INSERT
 ON PHYSICAL_PORT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "PHYSICAL_PORT_ID" uses sequence SYSDB.SEQ_PHYSICAL_PORT_ID
    IF (:new.PHYSICAL_PORT_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_PHYSICAL_PORT_ID.NEXTVAL
        select SEQ_PHYSICAL_PORT_ID.NEXTVAL
        INTO :new.PHYSICAL_PORT_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_PHYSICAL_PORT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PHYSICAL_PORT
 BEFORE UPDATE OF 
        PORT_NAME,
        PHYSICAL_PORT_ID,
        PORT_PURPOSE,
        DATA_INS_DATE,
        DATA_INS_USER,
        PORT_TYPE,
        DEVICE_ID
 ON PHYSICAL_PORT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PHYSICAL_PORT
	ENABLE;


CREATE  TRIGGER C_TIBUR_PROPERTY
  BEFORE INSERT OR UPDATE
  ON PROPERTY
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
  
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER C_TIBUR_PROPERTY
	ENABLE;


CREATE  TRIGGER K_TAIU_NONROW_PROPERTY
  AFTER INSERT OR UPDATE
  ON PROPERTY
  
  
  
declare
        v_tally integer;
        v_counter       INTEGER:=0;
        v_prop_rec      global_types.property_rec_type;

BEGIN
        --The FIRST/NEXT method is better, in case there are gaps in numbering
        v_counter := property_verify.G_property_recs_type.FIRST;
        WHILE v_counter IS NOT NULL 
        LOOP
                v_prop_rec := 
                        property_verify.G_property_recs_type(v_counter);

                SELECT  count(*)
                 into   v_tally
                 FROM   property
                 WHERE  property_id <>  v_prop_rec.property_id
                  AND   property_type = v_prop_rec.property_type
                  AND   ((company_id IS NULL AND v_prop_rec.company_id IS NULL) OR
                                (company_id = v_prop_rec.company_id))
                  AND   ((device_collection_id IS NULL AND v_prop_rec.device_collection_id IS NULL) OR
                                (device_collection_id = v_prop_rec.device_collection_id))
                  AND   ((dns_domain_id IS NULL AND v_prop_rec.dns_domain_id IS NULL) OR
                                (dns_domain_id = v_prop_rec.dns_domain_id))
                  AND   ((operating_system_id IS NULL AND v_prop_rec.operating_system_id IS NULL) OR
                                (operating_system_id = v_prop_rec.operating_system_id))
                  AND   ((production_state IS NULL AND v_prop_rec.production_state IS NULL) OR
                                (production_state = v_prop_rec.production_state))
                  AND   ((site_code IS NULL AND v_prop_rec.site_code IS NULL) OR
                                (site_code = v_prop_rec.site_code))
                  AND   ((person_id IS NULL AND v_prop_rec.person_id IS NULL) OR
                                (person_id = v_prop_rec.person_id))
                  AND   ((netblock_collection_id IS NULL AND v_prop_rec.netblock_collection_id IS NULL) OR
                                (netblock_collection_id = v_prop_rec.netblock_collection_id));
                  AND   ((account_id IS NULL AND v_prop_rec.account_id IS NULL) OR
                                (account_id = v_prop_rec.account_id))                
                  AND   ((account_collection_id IS NULL AND v_prop_rec.account_collection_id IS NULL) OR
                                (account_collection_id = v_prop_rec.account_collection_id));
                
                IF ( v_tally > 0) THEN
                        RAISE_APPLICATION_ERROR(
                                global_errors.ERRNUM_MULTIVALUE_OVERRIDE,
                                global_errors.ERRMSG_MULTIVALUE_OVERRIDE
                        );
                END IF;

                v_counter := property_verify.G_property_recs_type.NEXT(v_counter);
        END LOOP;
        -- Remove all entries in the global list
        property_verify.G_property_recs_type.delete;

        --The FIRST/NEXT method is better, in case there are gaps in numbering
        v_counter := property_verify.G_property_recs_name.FIRST;
        WHILE v_counter IS NOT NULL 
        LOOP
                v_prop_rec :=
                        property_verify.G_property_recs_name(v_counter);

--              dbms_output.put_line('property_id:   ' || v_prop_rec.property_id);
--              dbms_output.put_line('property_name: ' || v_prop_rec.property_name);
--              dbms_output.put_line('property_type: ' || v_prop_rec.property_type);
--              dbms_output.put_line('netblock_collection_id:     ' || v_prop_rec.netblock_collection_id);
--              dbms_output.put_line('account_collection_id:     ' || v_prop_rec.account_collection_id);
--              dbms_output.put_line('company_id:    ' || v_prop_rec.company_id);
--              dbms_output.put_line(' ');
                
                SELECT  count(*)
                 into   v_tally
                 FROM   property
                 WHERE  property_id <>  v_prop_rec.property_id
                  AND   property_name = v_prop_rec.property_name
                  AND   property_type = v_prop_rec.property_type
                  AND   ((company_id IS NULL AND v_prop_rec.company_id IS NULL) OR
                                (company_id = v_prop_rec.company_id))
                  AND   ((device_collection_id IS NULL AND v_prop_rec.device_collection_id IS NULL) OR
                                (device_collection_id = v_prop_rec.device_collection_id))
                  AND   ((dns_domain_id IS NULL AND v_prop_rec.dns_domain_id IS NULL) OR
                                (dns_domain_id = v_prop_rec.dns_domain_id))
                  AND   ((operating_system_id IS NULL AND v_prop_rec.operating_system_id IS NULL) OR
                                (operating_system_id = v_prop_rec.operating_system_id))
                  AND   ((production_state IS NULL AND v_prop_rec.production_state IS NULL) OR
                                (production_state = v_prop_rec.production_state))
                  AND   ((site_code IS NULL AND v_prop_rec.site_code IS NULL) OR
                                (site_code = v_prop_rec.site_code))
                  AND   ((netblock_collection_id IS NULL AND v_prop_rec.netblock_collection_id IS NULL) OR
                                (netblock_collection_id = v_prop_rec.netblock_collection_id))
                  AND   ((account_id IS NULL AND v_prop_rec.account_id IS NULL) OR
                                (account_id = v_prop_rec.account_id))
                  AND   ((account_collection_id IS NULL AND v_prop_rec.account_collection_id IS NULL) OR
                                (account_collection_id = v_prop_rec.account_collection_id));
 
                IF ( v_tally > 0) THEN
                        RAISE_APPLICATION_ERROR(
                                global_errors.ERRNUM_MULTIVALUE_OVERRIDE,
                                global_errors.ERRMSG_MULTIVALUE_OVERRIDE
                        );
                END IF;
                v_counter := property_verify.G_property_recs_name.NEXT(v_counter);
        END LOOP;
        -- Remove all entries in the global list
        property_verify.G_property_recs_type.delete;
END;
/


CREATE  TRIGGER K_TBIU_NONROW_PROPERTY
  BEFORE INSERT OR UPDATE
  ON PROPERTY
  
  
  
begin
        -- Remove all entries in the global list
        -- This before statement trigger will fire before the before row triggers.
        property_verify.G_property_recs_type.delete;
        property_verify.G_property_recs_name.delete;
end;
/



ALTER TRIGGER K_TBIU_NONROW_PROPERTY
	ENABLE;


 CREATE  TRIGGER K_TBIU_PROPERTY
  BEFORE INSERT OR UPDATE
  ON PROPERTY
  
  for each row
  
declare
        v_prop_rec               global_types.property_rec_type;
        integrity_error  exception;
        errno                   integer;
        errmsg             char(200);
        tally                   integer;
        v_prop           VAL_PROPERTY%rowtype;
        v_account_collection                 account_collection%rowtype;
        v_proptype               val_property_type%ROWTYPE;
        v_num            integer;
        v_listvalue     property.property_value%TYPE;
BEGIN
        -- Find if the record is a multi value record, and if so,
        -- store the record in the list
        BEGIN
                select  *
                 into   v_prop
                 from   VAL_PROPERTY
                where   property_name = :new.property_name
                 AND    property_type = :new.property_type;

                select  *
                 into   v_proptype
                 from   VAL_PROPERTY_TYPE
                where   property_type = :new.property_type;
        EXCEPTION
                WHEN NO_DATA_FOUND THEN
                        errno := -20900;
                        errmsg := 'Property name or type does not exist (' || :new.property_name || ',' || :new.property_type || ')';
                        raise integrity_error;
        END;

        IF (:new.property_id IS NULL)
        THEN
                SELECT SEQ_Property_ID.nextval INTO :new.property_id from dual;
        END IF;

        v_prop_rec.property_id                  :=      :new.property_id;
        v_prop_rec.property_name                :=      :new.property_name;
        v_prop_rec.property_type                :=      :new.property_type;
        v_prop_rec.company_id                   :=      :new.company_id;
        v_prop_rec.device_collection_id :=      :new.device_collection_id;
        v_prop_rec.dns_domain_id                :=      :new.dns_domain_id;
        v_prop_rec.operating_system_id  :=      :new.operating_system_id;
        v_prop_rec.production_state             :=      :new.production_state;
        v_prop_rec.site_code                    :=      :new.site_code;
        v_prop_rec.account_id               :=      :new.account_id;
        v_prop_rec.netblock_collection_id                    :=      :new.netblock_collection_id;
        v_prop_rec.account_collection_id                    :=      :new.account_collection_id;
        v_prop_rec.person_id                    := :new.person_id;

        -- if it ends up matching either of these, stash it for future lookup

        -- Check to see if the property itself is multivalue.  That is, if only
        -- one value can be set for this property for a specific property LHS

        IF (v_prop.is_multivalue = 'N') THEN
                property_verify.G_property_recs_name(
                        nvl(property_verify.G_property_recs_name.last,0)+1)
                                := v_prop_rec;
        END IF;

        -- Check to see if the property type is multivalue.  That is, if only
        -- one property and value can be set for any properties with this type
        -- for a specific property LHS

        IF (v_proptype.is_multivalue = 'N') THEN
                property_verify.G_property_recs_type(
                        nvl(property_verify.G_property_recs_type.last,0)+1)
                                := v_prop_rec;
        END IF;

        -- now validate the property_value columns.
        tally := 0;

        BEGIN
                select *
                  into v_prop
                  from val_property
                where  property_name = :new.property_name
                 and   property_type = :new.property_type;
        EXCEPTION
                WHEN NO_DATA_FOUND THEN
                        errno := -20900;
                        errmsg := 'Property type does not exist';
                        raise integrity_error;
        END;

        --
        -- first determine if the property_value is set properly.
        --

        -- iterate over each of fk PROPERTY_VALUE columns and if a valid
        -- value is set, increment tally, otherwise raise an exception.
        IF :new.PROPERTY_VALUE_COMPANY_ID is not NULL THEN
           IF v_prop.PROPERTY_DATA_TYPE = 'company_id' THEN
                  tally := tally + 1;
           else
          errno := -20900;
          errmsg := 'Property value may not be company_id';
                  raise integrity_error;
           END IF;
        END IF;
        IF :new.PROPERTY_VALUE_PASSWORD_TYPE is not NULL THEN
           IF v_prop.PROPERTY_DATA_TYPE = 'password_type' THEN
                  tally := tally + 1;
           else
          errno := -20900;
          errmsg := 'Property value may not be password_type';
                  raise integrity_error;
           END IF;
        END IF;
        IF :new.PROPERTY_VALUE_TOKEN_COL_ID is not NULL THEN
           IF v_prop.PROPERTY_DATA_TYPE = 'token_collection_id' THEN
                  tally := tally + 1;
           else
          errno := -20900;
          errmsg := 'Property value may not be token_collection_id';
                  raise integrity_error;
           END IF;
        END IF;
        IF :new.PROPERTY_VALUE_SW_PACKAGE_ID is not NULL THEN
           IF v_prop.PROPERTY_DATA_TYPE = 'sw_package_id' THEN
                  tally := tally + 1;
           else
          errno := -20900;
          errmsg := 'Property value may not be sw_collection_id';
                  raise integrity_error;
           END IF;
        END IF;
        IF :new.property_value_netblock_coll_id is not NULL THEN
           IF v_prop.PROPERTY_DATA_TYPE = 'netblock_collection_id' THEN
                  tally := tally + 1;
           else
          errno := -20900;
          errmsg := 'Property value may not be netblock_collection_id';
                  raise integrity_error;
           END IF;
        END IF;

        IF :new.property_value_account_coll_id is not NULL THEN
           IF v_prop.PROPERTY_DATA_TYPE = 'account_collection_id' THEN
                  tally := tally + 1;
           else
          errno := -20900;
          errmsg := 'Property value may not be account_collection_id';
                  raise integrity_error;
           END IF;
        END IF;
        IF :new.PROPERTY_VALUE_TIMESTAMP is not NULL THEN
           IF v_prop.PROPERTY_DATA_TYPE = 'timestamp' THEN
                  tally := tally + 1;
           else
          errno := -20900;
          errmsg := 'Property value may not be timestamp';
                  raise integrity_error;
           END IF;
        END IF;
        IF :new.PROPERTY_VALUE_DNS_DOMAIN_ID is not NULL THEN
           IF v_prop.PROPERTY_DATA_TYPE = 'dns_domain_id' THEN
                  tally := tally + 1;
           else
          errno := -20900;
          errmsg := 'Property value may not be dns_domain_id';
                  raise integrity_error;
           END IF;
        END IF;
        IF :new.PROPERTY_VALUE_PERSON_ID is not NULL THEN
           IF v_prop.PROPERTY_DATA_TYPE = 'person_id' THEN
                  tally := tally + 1;
           else
          errno := -20900;
          errmsg := 'Property value may not be person_id';
                  raise integrity_error;
           END IF;
        END IF;

        -- at this point, tally will be set to 1 if one of the other property
        -- values is set to something valid.  Now, check the various options for
        -- PROPERTY_VALUE itself.  If a new type is added to the val table, this
        -- trigger needs to be updated or it will be considered invalid.  If a
        -- new PROPERTY_VALUE_* column is added, then it will pass through without
        -- trigger modification.  This should be considered bad.

        IF :new.PROPERTY_VALUE is not NULL THEN
                tally := tally + 1;
                IF v_prop.PROPERTY_DATA_TYPE = 'boolean' THEN
                        IF :new.property_value <> 'Y' AND :new.property_value <> 'N' THEN
                                errno  := -20900;
                                errmsg := 'Boolean PROPERTY_VALUE must be Y/N.';
                                raise integrity_error;
                END IF;
                ELSIF v_prop.PROPERTY_DATA_TYPE = 'number' THEN
                begin
                        v_num := to_number(:new.property_value);
                exception when OTHERS THEN
                                errno  := -20900;
                                errmsg := 'PROPERTY_VALUE must be a number.';
                                raise integrity_error;
                end;
                ELSIF v_prop.PROPERTY_DATA_TYPE = 'list' THEN
                begin
                        SELECT Valid_Property_Value INTO v_listvalue FROM 
                                VAL_Property_Value WHERE
                                Property_Name = :new.property_name AND
                                Property_Type = :new.property_type AND
                                Valid_Property_Value = :new.property_value;
                exception
                        WHEN NO_DATA_FOUND THEN
                                errno  := -20900;
                                errmsg := 'PROPERTY_VALUE must be set to a valid value';
                                raise integrity_error;
                end;
                ELSIF v_prop.PROPERTY_DATA_TYPE <> 'string' THEN
                        errno  := -20900;
                        errmsg := 'PROPERTY_DATA_TYPE is not a known type.';
                        raise integrity_error;
                END IF;
        END IF;

        IF v_prop.PROPERTY_DATA_TYPE <> 'none' AND tally = 0 THEN
           errno  := -20901;
           errmsg := 'One of the PROPERTY_VALUE fields must be set.';
           raise integrity_error;
        END IF;

        IF tally > 1 THEN
           errno  := -20902;
           errmsg := 'Only one of the PROPERTY_VALUE fields may be set.';
           raise integrity_error;  
        END IF;

        -- If the RHS contains a account_collection_ID, check to see if it must be a
        -- specific type (e.g. per-user), and verify that if so
        
        IF :new.property_value_user_coll_id is not NULL THEN
                IF v_prop.PROP_VAL_account_collection_TYPE_RSTRCT is not NULL THEN
                        begin
                                select *
                                  into v_account_collection
                                  from account_collection
                                 where account_collection_id = :new.property_value_user_coll_id;

                                 IF v_account_collection.account_collection_type <> v_prop.PROP_VAL_account_collection_TYPE_RSTRCT
                                 THEN
                                                errno := -20905;
                                                errmsg := 'account_collection property value must be of type ' ||
                                                                v_prop.PROP_VAL_account_collection_TYPE_RSTRCT;
                                                raise integrity_error;
                                 END IF;
                        exception when NO_DATA_FOUND THEN
                                -- let the database deal with the fk exception later
                                null;
                        end;
                END IF;
        END IF;

        -- If the RHS contains a netblock_collection_ID, check to see if it must be a
        -- specific type (e.g. per-network), and verify that if so
        
        IF :new.property_value_nblk_coll_id is not NULL THEN
                IF v_prop.PROP_VAL_nblk_coll_TYPE_RSTRCT is not NULL THEN
                        begin
                                select *
                                  into v_netblock_collection
                                  from netblock_collection
                                 where netblock_collection_id = :new.property_value_nblk_coll_id;

                                 IF v_nblk_coll,netblock_collection_type <> v_prop.PROP_VAL_netblock_collection_TYPE_RSTRCT
                                 THEN
                                                errno := -20905;
                                                errmsg := 'account_collection property value must be of type ' ||
                                                                v_prop.PROP_VAL_nblk_coll_TYPE_RSTRCT;
                                                raise integrity_error;
                                 END IF;
                        exception when NO_DATA_FOUND THEN
                                -- let the database deal with the fk exception later
                                null;
                        end;
                END IF;
        END IF;


        -- At this point, the RHS has been checked, other than the multivalue
        -- check, so now we verify data set on the LHS

        -- There needs to be a stanza here for every "lhs".  If a new column is
        -- added to the property table, a new stanza needs to be added here,
        -- otherwise it will not be validated.  This also should be considered
        -- bad.

        IF v_prop.PERMIT_COMPANY_ID = 'REQUIRED' THEN
                IF :new.COMPANY_ID is null THEN
                        errno := -20903;
                        errmsg := 'COMPANY_ID is required.';
                        raise integrity_error;
                END IF;
        ELSIF v_prop.PERMIT_COMPANY_ID = 'PROHIBITED' THEN
                IF :new.COMPANY_ID is not null THEN
                        errno := -20904;
                        errmsg := 'COMPANY_ID is prohibited.';
                        raise integrity_error;
                END IF;
        END IF;

        IF v_prop.PERMIT_DEVICE_COLLECTION_ID = 'REQUIRED' THEN
                IF :new.DEVICE_COLLECTION_ID is null THEN
                        errno := -20903;
                        errmsg := 'DEVICE_COLLECTION_ID is required.';
                        raise integrity_error;
                END IF;
        ELSIF v_prop.PERMIT_DEVICE_COLLECTION_ID = 'PROHIBITED' THEN
                IF :new.DEVICE_COLLECTION_ID is not null THEN
                        errno := -20904;
                        errmsg := 'DEVICE_COLLECTION_ID is prohibited.';
                        raise integrity_error;
                END IF;
        END IF;

        IF v_prop.PERMIT_DNS_DOMAIN_ID = 'REQUIRED' THEN
                IF :new.DNS_DOMAIN_ID is null THEN
                        errno := -20903;
                        errmsg := 'DNS_DOMAIN_ID is required.';
                        raise integrity_error;
                END IF;
        ELSIF v_prop.PERMIT_DNS_DOMAIN_ID = 'PROHIBITED' THEN
                IF :new.DNS_DOMAIN_ID is not null THEN
                        errno := -20904;
                        errmsg := 'DNS_DOMAIN_ID is prohibited.';
                        raise integrity_error;
                END IF;
        END IF;

        IF v_prop.PERMIT_PRODUCTION_STATE = 'REQUIRED' THEN
                IF :new.PRODUCTION_STATE is null THEN
                        errno := -20903;
                        errmsg := 'PRODUCTION_STATE is required.';
                        raise integrity_error;
                END IF;
        ELSIF v_prop.PERMIT_PRODUCTION_STATE = 'PROHIBITED' THEN
                IF :new.PRODUCTION_STATE is not null THEN
                        errno := -20904;
                        errmsg := 'PRODUCTION_STATE is prohibited.';
                        raise integrity_error;
                END IF;
        END IF;

        IF v_prop.PERMIT_OPERATING_SYSTEM_ID = 'REQUIRED' THEN
                IF :new.OPERATING_SYSTEM_ID is null THEN
                        errno := -20903;
                        errmsg := 'OPERATING_SYSTEM_ID is required.';
                        raise integrity_error;
                END IF;
        ELSIF v_prop.PERMIT_OPERATING_SYSTEM_ID = 'PROHIBITED' THEN
                IF :new.OPERATING_SYSTEM_ID is not null THEN
                        errno := -20904;
                        errmsg := 'OPERATING_SYSTEM_ID is prohibited.';
                        raise integrity_error;
                END IF;
        END IF;

        IF v_prop.PERMIT_SITE_CODE = 'REQUIRED' THEN
                IF :new.SITE_CODE is null THEN
                        errno := -20903;
                        errmsg := 'SITE_CODE is required.';
                        raise integrity_error;
                END IF;
        ELSIF v_prop.PERMIT_SITE_CODE = 'PROHIBITED' THEN
                IF :new.SITE_CODE is not null THEN
                        errno := -20904;
                        errmsg := 'SITE_CODE is prohibited.';
                        raise integrity_error;
                END IF;
        END IF;

        IF v_prop.PERMIT_PERSON_ID = 'REQUIRED' THEN
                IF :new.person_ID is null THEN
                        errno := -20903;
                        errmsg := 'PERSON_ID is required.';
                        raise integrity_error;
                END IF;
        ELSIF v_prop.PERMIT_PERSON_ID = 'PROHIBITED' THEN
                IF :new.PERSON_ID is not null THEN
                        errno := -20904;
                        errmsg := 'PERSON_ID is prohibited.';
                        raise integrity_error;
                END IF;
        END IF;

        IF v_prop.PERMIT_account_ID = 'REQUIRED' THEN
                IF :new.account_ID is null THEN
                        errno := -20903;
                        errmsg := 'account_ID is required.';
                        raise integrity_error;
                END IF;
        ELSIF v_prop.PERMIT_account_ID = 'PROHIBITED' THEN
                IF :new.account_ID is not null THEN
                        errno := -20904;
                        errmsg := 'account_ID is prohibited.';
                        raise integrity_error;
                END IF;
        END IF;

        IF v_prop.PERMIT_netblock_collection_ID = 'REQUIRED' THEN
                IF :new.netblock_collection_ID is null THEN
                        errno := -20903;
                        errmsg := 'netblock_collection_ID is required.';
                        raise integrity_error;
                END IF;
        ELSIF v_prop.PERMIT_netblock_collection_ID = 'PROHIBITED' THEN
                IF :new.netblock_collection_ID is not null THEN
                        errno := -20904;
                        errmsg := 'netblock_collection_ID is prohibited.';
                        raise integrity_error;
                END IF;
        END IF;

        IF v_prop.PERMIT_account_collection_ID = 'REQUIRED' THEN
                IF :new.account_collection_ID is null THEN
                        errno := -20903;
                        errmsg := 'account_collection_ID is required.';
                        raise integrity_error;
                END IF;
        ELSIF v_prop.PERMIT_account_collection_ID = 'PROHIBITED' THEN
                IF :new.account_collection_ID is not null THEN
                        errno := -20904;
                        errmsg := 'account_collection_ID is prohibited.';
                        raise integrity_error;
                END IF;
        END IF;

        -- At this point, everything is verified with the exception of the
        -- multivalueness, which must be done in the AFTER trigger due to
        -- the whole Oracle mutating table fun.

--  Errors handling  

exception
        when integrity_error THEN  
           raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER K_TBIU_PROPERTY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_PROPERTY
  BEFORE INSERT
  ON PROPERTY
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
  
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    IF (:new.PROPERTY_ID IS NULL)
    THEN
        select SEQ_PROPERTY_ID.NEXTVAL
        INTO :new.PROPERTY_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;



/



ALTER TRIGGER TIB_PROPERTY
	ENABLE;


CREATE  TRIGGER TUB_PROPERTY
  BEFORE UPDATE
  ON PROPERTY
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
  
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER TUB_PROPERTY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_PSEUDO_KLOGIN
 BEFORE INSERT OR UPDATE
 ON PSEUDO_KLOGIN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_PSEUDO_KLOGIN
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_PSEUDO_KLOGIN
 BEFORE INSERT
 ON PSEUDO_KLOGIN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "PSEUDO_KLOGIN_ID" uses sequence SYSDB.SEQ_PSEUDO_KLOGIN_ID
    IF (:new.PSEUDO_KLOGIN_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_PSEUDO_KLOGIN_ID.NEXTVAL
        select SEQ_PSEUDO_KLOGIN_ID.NEXTVAL
        INTO :new.PSEUDO_KLOGIN_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_PSEUDO_KLOGIN
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_PSEUDO_KLOGIN
 BEFORE UPDATE OF 
        PSEUDO_KLOGIN_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        DEST_ACCOUNT_ID
 ON PSEUDO_KLOGIN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_PSEUDO_KLOGIN
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_RACK
 BEFORE INSERT OR UPDATE
 ON RACK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_RACK
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_RACK
 BEFORE INSERT
 ON RACK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "RACK_ID" uses sequence SYSDB.SEQ_RACK_ID
    IF (:new.RACK_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_RACK_ID.NEXTVAL
        select SEQ_RACK_ID.NEXTVAL
        INTO :new.RACK_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_RACK
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_RACK
 BEFORE UPDATE OF 
        RACK_NAME,
        DATA_INS_DATE,
        RACK_ID,
        SITE_CODE,
        SUB_ROOM,
        DATA_INS_USER,
        ROOM,
        RACK_ROW
 ON RACK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_RACK
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SECONDARY_NETBLOCK
 BEFORE INSERT OR UPDATE
 ON SECONDARY_NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SECONDARY_NETBLOCK
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_SECONDARY_NETBLOCK
 BEFORE INSERT
 ON SECONDARY_NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "SECONDARY_NETBLOCK_ID" uses sequence SYSDB.SEQ_SECONDARY_NETBLOCK_ID
    IF (:new.SECONDARY_NETBLOCK_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_SECONDARY_NETBLOCK_ID.NEXTVAL
        select SEQ_SECONDARY_NETBLOCK_ID.NEXTVAL
        INTO :new.SECONDARY_NETBLOCK_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_SECONDARY_NETBLOCK
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SECONDARY_NETBLOCK
 BEFORE UPDATE OF 
        NETBLOCK_ID,
        NETWORK_INTERFACE_ID,
        SECONDARY_NETBLOCK_ID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON SECONDARY_NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SECONDARY_NETBLOCK
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SITE
 BEFORE INSERT OR UPDATE
 ON SITE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SITE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SITE
 BEFORE UPDATE OF 
        SITE_CODE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON SITE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SITE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SITE_NETBLOCK
 BEFORE INSERT OR UPDATE
 ON SITE_NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SITE_NETBLOCK
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SITE_NETBLOCK
 BEFORE UPDATE OF 
        NETBLOCK_ID,
        SITE_CODE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON SITE_NETBLOCK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SITE_NETBLOCK
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SNMP_COMMSTR
 BEFORE INSERT OR UPDATE
 ON SNMP_COMMSTR
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SNMP_COMMSTR
	ENABLE;


CREATE  OR REPLACE  TRIGGER K_TBIU_SNMP_COMMSTR
 BEFORE INSERT OR UPDATE
 ON SNMP_COMMSTR
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
begin
	if(:new.Snmp_CommStr_Id is NULL) then
		select SEQ_Snmp_CommStr_Id.nextval
		  into :new.Snmp_CommStr_Id
		  from dual;
	end if;

    -- Commenting this out in favor of Unique Key
	--if(snmpcommstr_dev_has_type(:new.network_device_id, :new.SNMP_COMMSTR_TYPE)) then
		--raise_application_error( ERRNUM_SNMP_COMMSTR, ERRMSG_SNMP_COMMSTR ||'Str ('|| :new.Snmp_CommStr_Type_Id || ') Device (' || :new.network_device_id)||')';
	--end if;
end;

/



ALTER TRIGGER K_TBIU_SNMP_COMMSTR
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_SNMP_COMMSTR
 BEFORE INSERT
 ON SNMP_COMMSTR
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "SNMP_COMMSTR_ID" uses sequence SYSDB.SEQ_SNMP_COMMSTR_ID
    IF (:new.SNMP_COMMSTR_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_SNMP_COMMSTR_ID.NEXTVAL
        select SEQ_SNMP_COMMSTR_ID.NEXTVAL
        INTO :new.SNMP_COMMSTR_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_SNMP_COMMSTR
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SNMP_COMMSTR
 BEFORE UPDATE OF 
        SNMP_COMMSTR_ID,
        SNMP_COMMSTR_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER,
        DEVICE_ID
 ON SNMP_COMMSTR
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SNMP_COMMSTR
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SSH_KEY
 BEFORE INSERT OR UPDATE
 ON SSH_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SSH_KEY
	ENABLE;


CREATE  TRIGGER TIB_SSH_KEY
 BEFORE INSERT
 ON SSH_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    IF (:new.SSH_KEY_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SEQ_SSH_KEY_ID.NEXTVAL
        select SEQ_SSH_KEY_ID.NEXTVAL
        INTO :new.SSH_KEY_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_SSH_KEY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SSH_KEY
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER
 ON SSH_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SSH_KEY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_STATIC_ROUTE
 BEFORE INSERT OR UPDATE
 ON STATIC_ROUTE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_STATIC_ROUTE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_STATIC_ROUTE
 BEFORE INSERT
 ON STATIC_ROUTE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "STATIC_ROUTE_ID" uses sequence SYSDB.SEQ_STATIC_ROUTE_ID
    IF (:new.STATIC_ROUTE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_STATIC_ROUTE_ID.NEXTVAL
        select SEQ_STATIC_ROUTE_ID.NEXTVAL
        INTO :new.STATIC_ROUTE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_STATIC_ROUTE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_STATIC_ROUTE
 BEFORE UPDATE OF 
        NETBLOCK_ID,
        DATA_INS_DATE,
        NETWORK_INTERFACE_DST_ID,
        DATA_INS_USER,
        STATIC_ROUTE_ID,
        DEVICE_SRC_ID
 ON STATIC_ROUTE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_STATIC_ROUTE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_STATIC_ROUTE_TEMPLATE
 BEFORE INSERT OR UPDATE
 ON STATIC_ROUTE_TEMPLATE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_STATIC_ROUTE_TEMPLATE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_STATIC_ROUTE_TEMPLATE
 BEFORE INSERT
 ON STATIC_ROUTE_TEMPLATE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "STATIC_ROUTE_TEMPLATE_ID" uses sequence SYSDB.SEQ_STATIC_ROUTE_ID
    IF (:new.STATIC_ROUTE_TEMPLATE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_STATIC_ROUTE_ID.NEXTVAL
        select SEQ_STATIC_ROUTE_ID.NEXTVAL
        INTO :new.STATIC_ROUTE_TEMPLATE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_STATIC_ROUTE_TEMPLATE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_STATIC_ROUTE_TEMPLATE
 BEFORE UPDATE OF 
        NETBLOCK_ID,
        DATA_INS_DATE,
        NETWORK_INTERFACE_DST_ID,
        DATA_INS_USER,
        NETBLOCK_SRC_ID,
        STATIC_ROUTE_TEMPLATE_ID
 ON STATIC_ROUTE_TEMPLATE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_STATIC_ROUTE_TEMPLATE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SUDO_USERCOL_DEVCOL
 BEFORE INSERT OR UPDATE
 ON SUDO_ACCT_COL_DEVICE_COLLECTIO
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SUDO_USERCOL_DEVCOL
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SUDO_USERCOL_DEVCOL
 BEFORE UPDATE OF 
        DEVICE_COLLECTION_ID,
        RUN_AS_ACCOUNT_COLLECTION_ID,
        SUDO_ALIAS_NAME,
        DATA_INS_DATE,
        DATA_INS_USER,
        ACCOUNT_COLLECTION_ID
 ON SUDO_ACCT_COL_DEVICE_COLLECTIO
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SUDO_USERCOL_DEVCOL
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SUDO_ALIAS
 BEFORE INSERT OR UPDATE
 ON SUDO_ALIAS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SUDO_ALIAS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SUDO_ALIAS
 BEFORE UPDATE OF 
        SUDO_ALIAS_NAME,
        DATA_INS_DATE,
        DATA_INS_USER
 ON SUDO_ALIAS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SUDO_ALIAS
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SW_PACKAGE
 BEFORE INSERT OR UPDATE
 ON SW_PACKAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SW_PACKAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_SW_PACKAGE
 BEFORE INSERT
 ON SW_PACKAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "SW_PACKAGE_ID" uses sequence SYSDB.SEQ_SW_PACKAGE_ID
    IF (:new.SW_PACKAGE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_SW_PACKAGE_ID.NEXTVAL
        select SEQ_SW_PACKAGE_ID.NEXTVAL
        INTO :new.SW_PACKAGE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_SW_PACKAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SW_PACKAGE
 BEFORE UPDATE OF 
        SW_PACKAGE_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER,
        PRODUCTION_STATE_RESTRICTION,
        SW_PACKAGE_ID
 ON SW_PACKAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SW_PACKAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SW_PACKAGE_RELATION
 BEFORE INSERT OR UPDATE
 ON SW_PACKAGE_RELATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SW_PACKAGE_RELATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_SW_PACKAGE_RELATION
 BEFORE INSERT
 ON SW_PACKAGE_RELATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "SW_PACKAGE_RELATION_ID" uses sequence SYSDB.SEQ_SW_PACKAGE_RELATION_ID
    IF (:new.SW_PACKAGE_RELATION_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_SW_PACKAGE_RELATION_ID.NEXTVAL
        select SEQ_SW_PACKAGE_RELATION_ID.NEXTVAL
        INTO :new.SW_PACKAGE_RELATION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_SW_PACKAGE_RELATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SW_PACKAGE_RELATION
 BEFORE UPDATE OF 
        SW_PACKAGE_RELEASE_ID,
        RELATED_SW_PACKAGE_ID,
        DATA_INS_DATE,
        SW_PACKAGE_RELATION_ID,
        DATA_INS_USER,
        PACKAGE_RELATION_TYPE
 ON SW_PACKAGE_RELATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SW_PACKAGE_RELATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SW_PACKAGE_RELEASE
 BEFORE INSERT OR UPDATE
 ON SW_PACKAGE_RELEASE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SW_PACKAGE_RELEASE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_SW_PACKAGE_RELEASE
 BEFORE INSERT
 ON SW_PACKAGE_RELEASE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "SW_PACKAGE_RELEASE_ID" uses sequence SYSDB.SEQ_SW_PACKAGE_RELEASE_ID
    IF (:new.SW_PACKAGE_RELEASE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_SW_PACKAGE_RELEASE_ID.NEXTVAL
        select SEQ_SW_PACKAGE_RELEASE_ID.NEXTVAL
        INTO :new.SW_PACKAGE_RELEASE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_SW_PACKAGE_RELEASE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SW_PACKAGE_RELEASE
 BEFORE UPDATE
 ON SW_PACKAGE_RELEASE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SW_PACKAGE_RELEASE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_SW_PACKAGE_REPOSITORY
 BEFORE INSERT OR UPDATE
 ON SW_PACKAGE_REPOSITORY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_SW_PACKAGE_REPOSITORY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_SW_PACKAGE_REPOSITORY
 BEFORE INSERT
 ON SW_PACKAGE_REPOSITORY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "SW_PACKAGE_REPOSITORY_ID" uses sequence SYSDB.SEQ_SW_PACKAGE_REPOSITORY_ID
    IF (:new.SW_PACKAGE_REPOSITORY_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_SW_PACKAGE_REPOSITORY_ID.NEXTVAL
        select SEQ_SW_PACKAGE_REPOSITORY_ID.NEXTVAL
        INTO :new.SW_PACKAGE_REPOSITORY_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_SW_PACKAGE_REPOSITORY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_SW_PACKAGE_REPOSITORY
 BEFORE UPDATE OF 
        APT_REPOSITORY,
        DATA_INS_DATE,
        SW_REPOSITORY_NAME,
        DATA_INS_USER,
        SW_PACKAGE_REPOSITORY_ID
 ON SW_PACKAGE_REPOSITORY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_SW_PACKAGE_REPOSITORY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_TOKEN
 BEFORE INSERT OR UPDATE
 ON TOKEN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_TOKEN
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_TOKEN
 BEFORE INSERT
 ON TOKEN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "TOKEN_ID" uses sequence SYSDB.SEQ_TOKEN_ID
    IF (:new.TOKEN_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_TOKEN_ID.NEXTVAL
        select SEQ_TOKEN_ID.NEXTVAL
        INTO :new.TOKEN_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_TOKEN
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_TOKEN
 BEFORE UPDATE OF 
        TOKEN_TYPE,
        DATA_INS_DATE,
        TOKEN_ID,
        TOKEN_STATUS,
        DATA_INS_USER
 ON TOKEN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_TOKEN
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_TOKEN_COLLECTION
 BEFORE INSERT OR UPDATE
 ON TOKEN_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
	integrity_error  exception;
	errno			integer;
	errmsg		   char(200);
	dummy			integer;
	found			boolean;
	V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
	-- Context should be used by apps to list the end-user id.
	-- if it is filled, then concatenate it on.
	V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
	V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

	IF INSERTING
	THEN
		-- Override whatever is passed with context user
		:new.data_ins_user:=V_CONTEXT_USER;

		-- Force date to be sysdate
		:new.data_ins_date:=sysdate;
	END IF;

	IF UPDATING
	THEN
		-- Preventing changes to insert user and date columns happens in
		-- another trigger

		-- Override whatever is passed with context user
		:new.data_upd_user:=V_CONTEXT_USER;

		-- Force date to be sysdate
		:new.data_upd_date:=sysdate;
	END IF;



--  Errors handling
exception
	when integrity_error then
	   raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_TOKEN_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_TOKEN_COLLECTION
 BEFORE INSERT
 ON TOKEN_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
	integrity_error  exception;
	errno			integer;
	errmsg		   char(200);
	dummy			integer;
	found			boolean;

begin
	-- For sequences, only update column if null
	--  Column "TOKEN_COLLECTION_ID" uses sequence SYSDB.SEQ_TOKEN_COLLECTION_ID
	IF (:new.TOKEN_COLLECTION_ID IS NULL)
	THEN
		-- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
		--select SYSDB.SEQ_TOKEN_COLLECTION_ID.NEXTVAL
		select SEQ_TOKEN_COLLECTION_ID.NEXTVAL
		INTO :new.TOKEN_COLLECTION_ID
		from dual;
	END IF;

--  Errors handling
exception
	when integrity_error then
	   raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_TOKEN_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_TOKEN_COLLECTION
 BEFORE UPDATE
 ON TOKEN_COLLECTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
	integrity_error  exception;
	errno			integer;
	errmsg		   char(200);
	dummy			integer;
	found			boolean;

begin
	--  Non modifiable column "DATA_INS_USER" cannot be modified
	if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
	   errno  := -20001;
	   errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
	   raise integrity_error;
	end if;

	--  Non modifiable column "DATA_INS_DATE" cannot be modified
	if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
	   errno  := -20001;
	   errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
	   raise integrity_error;
	end if;


--  Errors handling
exception
	when integrity_error then
	   raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_TOKEN_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_COL_MEMBR
 BEFORE INSERT OR UPDATE
 ON TOKEN_COLLECTION_TOKEN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
	integrity_error  exception;
	errno			integer;
	errmsg		   char(200);
	dummy			integer;
	found			boolean;
	V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
	-- Context should be used by apps to list the end-user id.
	-- if it is filled, then concatenate it on.
	V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
	V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

	IF INSERTING
	THEN
		-- Override whatever is passed with context user
		:new.data_ins_user:=V_CONTEXT_USER;

		-- Force date to be sysdate
		:new.data_ins_date:=sysdate;
	END IF;

	IF UPDATING
	THEN
		-- Preventing changes to insert user and date columns happens in
		-- another trigger

		-- Override whatever is passed with context user
		:new.data_upd_user:=V_CONTEXT_USER;

		-- Force date to be sysdate
		:new.data_upd_date:=sysdate;
	END IF;



--  Errors handling
exception
	when integrity_error then
	   raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_COL_MEMBR
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_TOKEN_COL_MEMBR
 BEFORE UPDATE
 ON TOKEN_COLLECTION_TOKEN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
	integrity_error  exception;
	errno			integer;
	errmsg		   char(200);
	dummy			integer;
	found			boolean;

begin
	--  Non modifiable column "DATA_INS_USER" cannot be modified
	if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
	   errno  := -20001;
	   errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
	   raise integrity_error;
	end if;

	--  Non modifiable column "DATA_INS_DATE" cannot be modified
	if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
	   errno  := -20001;
	   errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
	   raise integrity_error;
	end if;


--  Errors handling
exception
	when integrity_error then
	   raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_TOKEN_COL_MEMBR
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_UNIX_GROUP
 BEFORE INSERT OR UPDATE
 ON UNIX_GROUP
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_UNIX_GROUP
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_UNIX_GROUP
 BEFORE UPDATE OF 
        UNIX_GID,
        DATA_INS_DATE,
        DATA_INS_USER
 ON UNIX_GROUP
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_UNIX_GROUP
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_ACCT_COL_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_ACCOUNT_COLLECTION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_ACCT_COL_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_ACCT_COL_TYPE
 BEFORE UPDATE OF 
        ACCOUNT_COLLECTION_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_ACCOUNT_COLLECTION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_ACCT_COL_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_ACCOUNT_ROLE
 BEFORE INSERT OR UPDATE
 ON VAL_ACCOUNT_ROLE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_ACCOUNT_ROLE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_ACCOUNT_ROLE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        ACCOUNT_ROLE,
        DATA_INS_USER
 ON VAL_ACCOUNT_ROLE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_ACCOUNT_ROLE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_ACCOUNT_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_ACCOUNT_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_ACCOUNT_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_ACCOUNT_TYPE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        ACCOUNT_TYPE,
        DATA_INS_USER
 ON VAL_ACCOUNT_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_ACCOUNT_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_APP_KEY
 BEFORE INSERT OR UPDATE
 ON VAL_APP_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_APP_KEY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_APP_KEY
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        APP_KEY
 ON VAL_APP_KEY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_APP_KEY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_APP_KEY_VALUES
 BEFORE INSERT OR UPDATE
 ON VAL_APP_KEY_VALUES
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_APP_KEY_VALUES
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_APP_KEY_VALUES
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        APP_VALUE,
        APP_KEY
 ON VAL_APP_KEY_VALUES
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_APP_KEY_VALUES
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_AUTH_QUESTION
 BEFORE INSERT OR UPDATE
 ON VAL_AUTH_QUESTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_AUTH_QUESTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_VAL_AUTH_QUESTION
 BEFORE INSERT
 ON VAL_AUTH_QUESTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "AUTH_QUESTION_ID" uses sequence SYSDB.SEQ_AUTH_QUESTION_ID
    IF (:new.AUTH_QUESTION_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_AUTH_QUESTION_ID.NEXTVAL
        select SEQ_AUTH_QUESTION_ID.NEXTVAL
        INTO :new.AUTH_QUESTION_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_VAL_AUTH_QUESTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_AUTH_QUESTION
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        AUTH_QUESTION_ID
 ON VAL_AUTH_QUESTION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_AUTH_QUESTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_AUTH_RESOURCE
 BEFORE INSERT OR UPDATE
 ON VAL_AUTH_RESOURCE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_AUTH_RESOURCE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_AUTH_RESOURCE
 BEFORE UPDATE
 ON VAL_AUTH_RESOURCE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_AUTH_RESOURCE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_BADGE_STATUS
 BEFORE INSERT OR UPDATE
 ON VAL_BADGE_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_BADGE_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_BADGE_STATUS
 BEFORE UPDATE OF 
        BADGE_STATUS,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_BADGE_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_BADGE_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_BAUD
 BEFORE INSERT OR UPDATE
 ON VAL_BAUD
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_BAUD
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_BAUD
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        BAUD
 ON VAL_BAUD
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_BAUD
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_CABLE_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_CABLE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_CABLE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_CABLE_TYPE
 BEFORE UPDATE OF 
        CABLE_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_CABLE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_CABLE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER Trigger_13051
 BEFORE INSERT OR UPDATE
 ON VAL_COMPANY_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER Trigger_13051
	ENABLE;


CREATE  OR REPLACE  TRIGGER Trigger_13052
 BEFORE UPDATE OF 
        COMPANY_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_COMPANY_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER Trigger_13052
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_COUNTRY_CODE
 BEFORE INSERT OR UPDATE
 ON VAL_COUNTRY_CODE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_COUNTRY_CODE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_COUNTRY_CODE
 BEFORE UPDATE OF 
        ISO_COUNTRY_CODE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_COUNTRY_CODE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_COUNTRY_CODE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_DATA_BITS
 BEFORE INSERT OR UPDATE
 ON VAL_DATA_BITS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_DATA_BITS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_DATA_BITS
 BEFORE UPDATE OF 
        DATA_BITS,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_DATA_BITS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_DATA_BITS
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_DEVICE_AUTO_MGMT_P
 BEFORE INSERT OR UPDATE
 ON VAL_DEVICE_AUTO_MGMT_PROTOCOL
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_DEVICE_AUTO_MGMT_P
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_DEVICE_AUTO_MGMT_PROTO
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        AUTO_MGMT_PROTOCOL
 ON VAL_DEVICE_AUTO_MGMT_PROTOCOL
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_DEVICE_AUTO_MGMT_PROTO
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_DEVICE_COLLECTION_
 BEFORE INSERT OR UPDATE
 ON VAL_DEVICE_COLLECTION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_DEVICE_COLLECTION_
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_DEVICE_COLLECTION_TYPE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        DEVICE_COLLECTION_TYPE
 ON VAL_DEVICE_COLLECTION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_DEVICE_COLLECTION_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_STATUS
 BEFORE INSERT OR UPDATE
 ON VAL_DEVICE_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_STATUS
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DEVICE_STATUS,
        DATA_INS_USER
 ON VAL_DEVICE_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_DIET
 BEFORE INSERT OR UPDATE
 ON VAL_DIET
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_DIET
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_DIET
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        DIET
 ON VAL_DIET
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_DIET
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_DNS_CLASS
 BEFORE INSERT OR UPDATE
 ON VAL_DNS_CLASS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_DNS_CLASS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_DNS_CLASS
 BEFORE UPDATE OF 
        DNS_CLASS,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_DNS_CLASS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_DNS_CLASS
	ENABLE;


CREATE  TRIGGER C_TIUBR_VAL_DNS_DOMAIN_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_DNS_DOMAIN_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER C_TIUBR_VAL_DNS_DOMAIN_TYPE
	ENABLE;


CREATE  TRIGGER TUB_VAL_DNS_DOMAIN_TYPE
 BEFORE UPDATE
 ON VAL_DNS_DOMAIN_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER TUB_VAL_DNS_DOMAIN_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_DNS_RECORD_RELATIO
 BEFORE INSERT OR UPDATE
 ON VAL_DNS_RECORD_RELATION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_DNS_RECORD_RELATIO
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_DNS_RECORD_RELATION_TY
 BEFORE UPDATE OF 
        DNS_RECORD_RELATION_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_DNS_RECORD_RELATION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_DNS_RECORD_RELATION_TY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_DNS_SRV_SERVICE
 BEFORE INSERT OR UPDATE
 ON VAL_DNS_SRV_SERVICE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_DNS_SRV_SERVICE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_DNS_SRV_SERVICE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DNS_SRV_SERVICE,
        DATA_INS_USER
 ON VAL_DNS_SRV_SERVICE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_DNS_SRV_SERVICE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_DNS_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_DNS_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_DNS_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_DNS_TYPE
 BEFORE UPDATE OF 
        DNS_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_DNS_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_DNS_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_ENCAPSULATION_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_ENCAPSULATION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_ENCAPSULATION_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_ENCAPSULATION_TYPE
 BEFORE UPDATE OF 
        ENCAPSULATION_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_ENCAPSULATION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_ENCAPSULATION_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_ENCRYPT_KEY_PURP
 BEFORE INSERT OR UPDATE
 ON VAL_ENCRYPTION_KEY_PURPOSE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_ENCRYPT_KEY_PURP
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_ENCRYPT_KEY_PURPOSE
 BEFORE UPDATE
 ON VAL_ENCRYPTION_KEY_PURPOSE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_ENCRYPT_KEY_PURPOSE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_ENCRYPT_METHOD
 BEFORE INSERT OR UPDATE
 ON VAL_ENCRYPTION_METHOD
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_ENCRYPT_METHOD
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TUB_VAL_ENCRYPT_METHOD
 BEFORE UPDATE
 ON VAL_ENCRYPTION_METHOD
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TUB_VAL_ENCRYPT_METHOD
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_FLOW_CONTROL
 BEFORE INSERT OR UPDATE
 ON VAL_FLOW_CONTROL
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_FLOW_CONTROL
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_FLOW_CONTROL
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        FLOW_CONTROL
 ON VAL_FLOW_CONTROL
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_FLOW_CONTROL
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_IMAGE_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_IMAGE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_IMAGE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_IMAGE_TYPE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        IMAGE_TYPE
 ON VAL_IMAGE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_IMAGE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_REASON_FOR_ASSIGN
 BEFORE INSERT OR UPDATE
 ON VAL_KEY_USG_REASON_FOR_ASSGN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_REASON_FOR_ASSIGN
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_REASON_FOR_ASSIGN
 BEFORE UPDATE
 ON VAL_KEY_USG_REASON_FOR_ASSGN
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_REASON_FOR_ASSIGN
	ENABLE;


CREATE  OR REPLACE  TRIGGER CTIUBR_VAL_NETBLOCK_COLLECTION
 BEFORE INSERT OR UPDATE
 ON VAL_NETBLOCK_COLLECTION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER CTIUBR_VAL_NETBLOCK_COLLECTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_NETBLOCK_COLLECTION_TY
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        NETBLOCK_COLLECTION_TYPE
 ON VAL_NETBLOCK_COLLECTION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_NETBLOCK_COLLECTION_TY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_NETBLOCK_STATUS
 BEFORE INSERT OR UPDATE
 ON VAL_NETBLOCK_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_NETBLOCK_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_NETBLOCK_STATUS
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        NETBLOCK_STATUS
 ON VAL_NETBLOCK_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_NETBLOCK_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_NETBLOCK_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_NETBLOCK_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_NETBLOCK_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_NETBLOCK_TYPE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        NETBLOCK_TYPE
 ON VAL_NETBLOCK_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_NETBLOCK_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER R_TIUBR_VAL_NETWORK_INT_PURP
 BEFORE INSERT OR UPDATE
 ON VAL_NETWORK_INTERFACE_PURPOSE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER R_TIUBR_VAL_NETWORK_INT_PURP
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_NETWORK_INTERFACE_PURP
 BEFORE UPDATE OF 
        NETWORK_INTERFACE_PURPOSE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_NETWORK_INTERFACE_PURPOSE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_NETWORK_INTERFACE_PURP
	ENABLE;


CREATE  OR REPLACE  TRIGGER R_TIUBR_VAL_NETWORK_INT_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_NETWORK_INTERFACE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER R_TIUBR_VAL_NETWORK_INT_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_NETWORK_INTERFACE_TYPE
 BEFORE UPDATE OF 
        NETWORK_INTERFACE_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_NETWORK_INTERFACE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_NETWORK_INTERFACE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_NETWORK_SERVICE_TY
 BEFORE INSERT OR UPDATE
 ON VAL_NETWORK_SERVICE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_NETWORK_SERVICE_TY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_NETWORK_SERVICE_TYPE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        NETWORK_SERVICE_TYPE
 ON VAL_NETWORK_SERVICE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_NETWORK_SERVICE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_OWNERSHIP_STATUS
 BEFORE INSERT OR UPDATE
 ON VAL_OWNERSHIP_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_OWNERSHIP_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_OWNERSHIP_STATUS
 BEFORE UPDATE OF 
        OWNERSHIP_STATUS,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_OWNERSHIP_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_OWNERSHIP_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PACKAGE_RELATION_T
 BEFORE INSERT OR UPDATE
 ON VAL_PACKAGE_RELATION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PACKAGE_RELATION_T
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PACKAGE_RELATION_TYPE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        PACKAGE_RELATION_TYPE
 ON VAL_PACKAGE_RELATION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PACKAGE_RELATION_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PARITY
 BEFORE INSERT OR UPDATE
 ON VAL_PARITY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PARITY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PARITY
 BEFORE UPDATE OF 
        PARITY,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_PARITY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PARITY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PASSWORD_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_PASSWORD_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PASSWORD_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PASSWORD_TYPE
 BEFORE UPDATE OF 
        PASSWORD_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_PASSWORD_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PASSWORD_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PERSON_COMPANY_REL
 BEFORE INSERT OR UPDATE
 ON VAL_PERSON_COMPANY_RELATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PERSON_COMPANY_REL
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PRESON_COMPANY_RELATIO
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        PERSON_COMPANY_RELATION
 ON VAL_PERSON_COMPANY_RELATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PRESON_COMPANY_RELATIO
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PERSON_LOC_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_PERSON_CONTACT_LOC_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PERSON_LOC_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PERSON_CONTACT_LOC_TYP
 BEFORE UPDATE OF 
        PERSON_CONTACT_LOCATION_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_PERSON_CONTACT_LOC_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PERSON_CONTACT_LOC_TYP
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PERSON_CONTACT_TEC
 BEFORE INSERT OR UPDATE
 ON VAL_PERSON_CONTACT_TECHNOLOGY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PERSON_CONTACT_TEC
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PERSON_CONTACT_TECH
 BEFORE UPDATE OF 
        PERSON_CONTACT_TECHNOLOGY,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_PERSON_CONTACT_TECHNOLOGY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PERSON_CONTACT_TECH
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PERSON_CONTACT_TYP
 BEFORE INSERT OR UPDATE
 ON VAL_PERSON_CONTACT_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PERSON_CONTACT_TYP
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PERSON_CONTACT_TYPE
 BEFORE UPDATE OF 
        PERSON_CONTACT_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_PERSON_CONTACT_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PERSON_CONTACT_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PERSON_IMAGE_USAGE
 BEFORE INSERT OR UPDATE
 ON VAL_PERSON_IMAGE_USAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PERSON_IMAGE_USAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PERSON_IMAGE_USAGE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_PERSON_IMAGE_USAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PERSON_IMAGE_USAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_USER_LOCATION_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_PERSON_LOCATION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_USER_LOCATION_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_USER_LOCATION_TYPE
 BEFORE UPDATE OF 
        PERSON_LOCATION_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_PERSON_LOCATION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_USER_LOCATION_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PERSON_STATUS
 BEFORE INSERT OR UPDATE
 ON VAL_PERSON_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PERSON_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PERSON_STATUS
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        PERSON_STATUS
 ON VAL_PERSON_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PERSON_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PLUG_STYLE
 BEFORE INSERT OR UPDATE
 ON VAL_PLUG_STYLE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PLUG_STYLE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PLUG_STYLE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        PLUG_STYLE,
        DATA_INS_USER
 ON VAL_PLUG_STYLE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PLUG_STYLE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PORT_PURPOSE
 BEFORE INSERT OR UPDATE
 ON VAL_PORT_PURPOSE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PORT_PURPOSE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PORT_PURPOSE
 BEFORE UPDATE OF 
        PORT_PURPOSE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_PORT_PURPOSE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PORT_PURPOSE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PORT_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_PORT_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PORT_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PORT_TYPE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        PORT_TYPE
 ON VAL_PORT_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PORT_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_PROCESSOR_ARCHITEC
 BEFORE INSERT OR UPDATE
 ON VAL_PROCESSOR_ARCHITECTURE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_PROCESSOR_ARCHITEC
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PROCESSOR_ARCHITECTURE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        PROCESSOR_ARCHITECTURE,
        DATA_INS_USER
 ON VAL_PROCESSOR_ARCHITECTURE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PROCESSOR_ARCHITECTURE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PRODUCTION_STATE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        PRODUCTION_STATE
 ON VAL_PRODUCTION_STATE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_PRODUCTION_STATE
	ENABLE;


CREATE  OR REPLACE  TRIGGER T_CIUBR_VAL_PRODUCTION_STATE
 BEFORE INSERT OR UPDATE
 ON VAL_PRODUCTION_STATE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER T_CIUBR_VAL_PRODUCTION_STATE
	ENABLE;


CREATE  TRIGGER C_TIBUR_VAL_PROPERTY
  BEFORE INSERT OR UPDATE
  ON VAL_PROPERTY
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
  
declare
 integrity_error exception;
 errno integer;
 errmsg char(200);
 dummy integer;
 found boolean;
 V_CONTEXT_USER VARCHAR2(256):=NULL;

begin
 -- Context should be used by apps to list the end-user id.
 -- if it is filled, then concatenate it on.
 V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
 V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

 IF INSERTING
 THEN
 -- Override whatever is passed with context user
 :new.data_ins_user:=V_CONTEXT_USER;

 -- Force date to be sysdate
 :new.data_ins_date:=sysdate;
 END IF;

 IF UPDATING
 THEN
 -- Preventing changes to insert user and date columns happens in
 -- another trigger

 -- Override whatever is passed with context user
 :new.data_upd_user:=V_CONTEXT_USER;

 -- Force date to be sysdate
 :new.data_upd_date:=sysdate;
 END IF;

-- Errors handling
exception
 when integrity_error then
 raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER C_TIBUR_VAL_PROPERTY
	ENABLE;


CREATE  TRIGGER TUB_VAL_PROPERTY
  BEFORE UPDATE
  ON VAL_PROPERTY
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
  
declare
 integrity_error exception;
 errno integer;
 errmsg char(200);
 dummy integer;
 found boolean;

begin
 -- Non modifiable column "DATA_INS_USER" cannot be modified
 if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
 errno := -20001;
 errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
 raise integrity_error;
 end if;

 -- Non modifiable column "DATA_INS_DATE" cannot be modified
 if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
 errno := -20001;
 errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
 raise integrity_error;
 end if;

 --  Non modifiable column "IS_MULTIVALUE" cannot be modified
 if updating('IS_MULTIVALUE') and :old.IS_MULTIVALUE != :new.IS_MULTIVALUE then
    errno  := -20001;
    errmsg := 'Non modifiable column "IS_MULTIVALUE" cannot be modified.';
    raise integrity_error;
 end if;

-- Errors handling
exception
 when integrity_error then
 raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER TUB_VAL_PROPERTY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIBUR_VAL_PROPERTY_DATA_TYPE
  BEFORE INSERT OR UPDATE
  ON VAL_PROPERTY_DATA_TYPE
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
  
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;
begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;

--  Errors handling
exception
    when integrity_error then       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER C_TIBUR_VAL_PROPERTY_DATA_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_PROPERTY_DATA_TYPE
  BEFORE UPDATE
  ON VAL_PROPERTY_DATA_TYPE
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
  
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER TUB_VAL_PROPERTY_DATA_TYPE
	ENABLE;


CREATE  TRIGGER C_TIBUR_VAL_PROPERTY_TYPE
  BEFORE INSERT OR UPDATE
  ON VAL_PROPERTY_TYPE
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
  
declare
 integrity_error exception;
 errno integer;
 errmsg char(200);
 dummy integer;
 found boolean;
 V_CONTEXT_USER VARCHAR2(256):=NULL;

begin
 -- Context should be used by apps to list the end-user id.
 -- if it is filled, then concatenate it on.
 V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
 V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

 IF INSERTING
 THEN
 -- Override whatever is passed with context user
 :new.data_ins_user:=V_CONTEXT_USER;

 -- Force date to be sysdate
 :new.data_ins_date:=sysdate;
 END IF;

 IF UPDATING
 THEN
 -- Preventing changes to insert user and date columns happens in
 -- another trigger

 -- Override whatever is passed with context user
 :new.data_upd_user:=V_CONTEXT_USER;

 -- Force date to be sysdate
 :new.data_upd_date:=sysdate;
 END IF;

-- Errors handling
exception
 when integrity_error then
 raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER C_TIBUR_VAL_PROPERTY_TYPE
	ENABLE;


CREATE  TRIGGER TUB_VAL_PROPERTY_TYPE
  BEFORE UPDATE
  ON VAL_PROPERTY_TYPE
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
  
declare
 integrity_error exception;
 errno integer;
 errmsg char(200);
 dummy integer;
 found boolean;

begin
 -- Non modifiable column "DATA_INS_USER" cannot be modified
 if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
 errno := -20001;
 errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
 raise integrity_error;
 end if;

 -- Non modifiable column "DATA_INS_DATE" cannot be modified
 if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
 errno := -20001;
 errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
 raise integrity_error;
 end if;

 --  Non modifiable column "IS_MULTIVALUE" cannot be modified
 if updating('IS_MULTIVALUE') and :old.IS_MULTIVALUE != :new.IS_MULTIVALUE then
    errno  := -20001;      
    errmsg := 'Non modifiable column "IS_MULTIVALUE" cannot be modified.';
    raise integrity_error; 
 end if;


-- Errors handling
exception
 when integrity_error then
 raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER TUB_VAL_PROPERTY_TYPE
	ENABLE;


CREATE  TRIGGER C_TIBUR_VAL_PROPERTY_VALUE
  BEFORE INSERT OR UPDATE
  ON VAL_PROPERTY_VALUE
  
  for each row
  
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;
begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;

--  Errors handling
exception
    when integrity_error then       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER C_TIBUR_VAL_PROPERTY_VALUE
	ENABLE;


CREATE  TRIGGER TUB_VAL_PROPERTY_VALUE
  BEFORE UPDATE
  ON VAL_PROPERTY_VALUE
  
  for each row
  
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;
/



ALTER TRIGGER TUB_VAL_PROPERTY_VALUE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_SERVICE_ENVIRONMEN
 BEFORE INSERT OR UPDATE
 ON VAL_SERVICE_ENVIRONMENT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_SERVICE_ENVIRONMEN
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_SERVICE_ENVIRONMENT
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER,
        SERVICE_ENVIRONMENT
 ON VAL_SERVICE_ENVIRONMENT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_SERVICE_ENVIRONMENT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_SNMP_COMMSTR_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_SNMP_COMMSTR_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_SNMP_COMMSTR_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_SNMP_COMMSTR_TYPE
 BEFORE UPDATE OF 
        SNMP_COMMSTR_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_SNMP_COMMSTR_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_SNMP_COMMSTR_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER Trigger_14950
 BEFORE INSERT OR UPDATE
 ON VAL_SSH_KEY_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER Trigger_14950
	ENABLE;


CREATE  OR REPLACE  TRIGGER Trigger_14951
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_SSH_KEY_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER Trigger_14951
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_STOP_BITS
 BEFORE INSERT OR UPDATE
 ON VAL_STOP_BITS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_STOP_BITS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_STOP_BITS
 BEFORE UPDATE OF 
        STOP_BITS,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_STOP_BITS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_STOP_BITS
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_SW_PACKAGE_FORMAT
 BEFORE INSERT OR UPDATE
 ON VAL_SW_PACKAGE_FORMAT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_SW_PACKAGE_FORMAT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_SW_PACKAGE_FORMAT
 BEFORE UPDATE OF 
        SW_PACKAGE_FORMAT,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_SW_PACKAGE_FORMAT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_SW_PACKAGE_FORMAT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_SW_PACKAGE_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_SW_PACKAGE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_SW_PACKAGE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_SW_PACKAGE_TYPE
 BEFORE UPDATE OF 
        SW_PACKAGE_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_SW_PACKAGE_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_SW_PACKAGE_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_SYMBOLIC_TRACK_NAM
 BEFORE INSERT OR UPDATE
 ON VAL_SYMBOLIC_TRACK_NAME
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_SYMBOLIC_TRACK_NAM
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_SYMBOLIC_TRACK_NAME
 BEFORE UPDATE OF 
        SYMBOLIC_TRACK_NAME,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_SYMBOLIC_TRACK_NAME
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_SYMBOLIC_TRACK_NAME
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_TOKEN_COL_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_TOKEN_COLLECTION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
	integrity_error  exception;
	errno			integer;
	errmsg		   char(200);
	dummy			integer;
	found			boolean;
	V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
	-- Context should be used by apps to list the end-user id.
	-- if it is filled, then concatenate it on.
	V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
	V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

	IF INSERTING
	THEN
		-- Override whatever is passed with context user
		:new.data_ins_user:=V_CONTEXT_USER;

		-- Force date to be sysdate
		:new.data_ins_date:=sysdate;
	END IF;

	IF UPDATING
	THEN
		-- Preventing changes to insert user and date columns happens in
		-- another trigger

		-- Override whatever is passed with context user
		:new.data_upd_user:=V_CONTEXT_USER;

		-- Force date to be sysdate
		:new.data_upd_date:=sysdate;
	END IF;



--  Errors handling
exception
	when integrity_error then
	   raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_TOKEN_COL_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_TOKEN_COL_TYPE
 BEFORE UPDATE
 ON VAL_TOKEN_COLLECTION_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
	integrity_error  exception;
	errno			integer;
	errmsg		   char(200);
	dummy			integer;
	found			boolean;

begin
	--  Non modifiable column "DATA_INS_USER" cannot be modified
	if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
	   errno  := -20001;
	   errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
	   raise integrity_error;
	end if;

	--  Non modifiable column "DATA_INS_DATE" cannot be modified
	if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
	   errno  := -20001;
	   errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
	   raise integrity_error;
	end if;


--  Errors handling
exception
	when integrity_error then
	   raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_TOKEN_COL_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_TOKEN_STATUS
 BEFORE INSERT OR UPDATE
 ON VAL_TOKEN_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_TOKEN_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_TOKEN_STATUS
 BEFORE UPDATE OF 
        TOKEN_STATUS,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_TOKEN_STATUS
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_TOKEN_STATUS
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_TOKEN_TYPE
 BEFORE INSERT OR UPDATE
 ON VAL_TOKEN_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_TOKEN_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_TOKEN_TYPE
 BEFORE UPDATE OF 
        TOKEN_TYPE,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_TOKEN_TYPE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_TOKEN_TYPE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_UPGRADE_SEVERITY
 BEFORE INSERT OR UPDATE
 ON VAL_UPGRADE_SEVERITY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_UPGRADE_SEVERITY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_UPGRADE_SEVERITY
 BEFORE UPDATE OF 
        UPGRADE_SEVERITY,
        DATA_INS_DATE,
        DATA_INS_USER
 ON VAL_UPGRADE_SEVERITY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_UPGRADE_SEVERITY
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VAL_VOE_STATE
 BEFORE INSERT OR UPDATE
 ON VAL_VOE_STATE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VAL_VOE_STATE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VAL_VOE_STATE
 BEFORE UPDATE OF 
        DATA_INS_DATE,
        VOE_STATE,
        DATA_INS_USER
 ON VAL_VOE_STATE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VAL_VOE_STATE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_CERT_FILE_FMT
 BEFORE INSERT OR UPDATE
 ON VAL_X509_CERTIFICATE_FILE_FMT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_CERT_FILE_FMT
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_CERT_FILE_FMT
 BEFORE UPDATE
 ON VAL_X509_CERTIFICATE_FILE_FMT
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_CERT_FILE_FMT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIBUR_X509_KEY_USAGE
 BEFORE INSERT OR UPDATE
 ON VAL_X509_KEY_USAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIBUR_X509_KEY_USAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_X509_KEY_USAGE
 BEFORE UPDATE
 ON VAL_X509_KEY_USAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_X509_KEY_USAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIBUR_KEY_USAGE_CATEGORY
 BEFORE INSERT OR UPDATE
 ON VAL_X509_KEY_USAGE_CATEGORY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIBUR_KEY_USAGE_CATEGORY
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_X509_KEY_USAGE_CAT
 BEFORE UPDATE
 ON VAL_X509_KEY_USAGE_CATEGORY
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_X509_KEY_USAGE_CAT
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VLAN_RANGE
 BEFORE INSERT OR UPDATE
 ON VLAN_RANGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VLAN_RANGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_VLAN_RANGE
 BEFORE INSERT
 ON VLAN_RANGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "VLAN_RANGE_ID" uses sequence SYSDB.SEQ_VLAN_RANGE_ID
    IF (:new.VLAN_RANGE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_VLAN_RANGE_ID.NEXTVAL
        select SEQ_VLAN_RANGE_ID.NEXTVAL
        INTO :new.VLAN_RANGE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_VLAN_RANGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VLAN_RANGE
 BEFORE UPDATE OF 
        PARENT_VLAN_RANGE_ID,
        VLAN_RANGE_ID,
        DATA_INS_DATE,
        SITE_CODE,
        DATA_INS_USER
 ON VLAN_RANGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VLAN_RANGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VOE
 BEFORE INSERT OR UPDATE
 ON VOE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VOE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_VOE
 BEFORE INSERT
 ON VOE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "VOE_ID" uses sequence SYSDB.SEQ_VOE_ID
    IF (:new.VOE_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_VOE_ID.NEXTVAL
        select SEQ_VOE_ID.NEXTVAL
        INTO :new.VOE_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_VOE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VOE
 BEFORE UPDATE OF 
        VOE_STATE,
        DATA_INS_DATE,
        DATA_INS_USER,
        VOE_ID,
        SW_PACKAGE_REPOSITORY_ID,
        VOE_NAME,
        SERVICE_ENVIRONMENT
 ON VOE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VOE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VOE_RELATION
 BEFORE INSERT OR UPDATE
 ON VOE_RELATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VOE_RELATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VOE_RELATION
 BEFORE UPDATE OF 
        UPGRADE_SEVERITY,
        DATA_INS_DATE,
        DATA_INS_USER,
        VOE_ID,
        RELATED_VOE_ID
 ON VOE_RELATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VOE_RELATION
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VOE_SW_PACKAGE
 BEFORE INSERT OR UPDATE
 ON VOE_SW_PACKAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VOE_SW_PACKAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VOE_SW_PACKAGE
 BEFORE UPDATE OF 
        SW_PACKAGE_RELEASE_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        VOE_ID
 ON VOE_SW_PACKAGE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VOE_SW_PACKAGE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_VOE_SYMBOLIC_TRACK
 BEFORE INSERT OR UPDATE
 ON VOE_SYMBOLIC_TRACK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_VOE_SYMBOLIC_TRACK
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_VOE_SYMBOLIC_TRACK
 BEFORE INSERT
 ON VOE_SYMBOLIC_TRACK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "VOE_SYMBOLIC_TRACK_ID" uses sequence SYSDB.SEQ_VOE_SYMBOLIC_TRACK_ID
    IF (:new.VOE_SYMBOLIC_TRACK_ID IS NULL)
    THEN
        -- Was the following.  Removed owner because quest doesn't handle it properly (for non owner builds)
        --select SYSDB.SEQ_VOE_SYMBOLIC_TRACK_ID.NEXTVAL
        select SEQ_VOE_SYMBOLIC_TRACK_ID.NEXTVAL
        INTO :new.VOE_SYMBOLIC_TRACK_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_VOE_SYMBOLIC_TRACK
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_VOE_SYMBOLIC_TRACK
 BEFORE UPDATE OF 
        SYMBOLIC_TRACK_NAME,
        ACTIVE_VOE_ID,
        VOE_SYMBOLIC_TRACK_ID,
        PENDING_VOE_ID,
        DATA_INS_DATE,
        DATA_INS_USER,
        UPGRADE_SEVERITY_THRESHOLD,
        SW_PACKAGE_REPOSITORY_ID
 ON VOE_SYMBOLIC_TRACK
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_VOE_SYMBOLIC_TRACK
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_X509_CERTIFICATE
 BEFORE INSERT OR UPDATE
 ON X509_CERTIFICATE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_X509_CERTIFICATE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TIB_X509_CERTIFICATE
 BEFORE INSERT
 ON X509_CERTIFICATE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    -- For sequences, only update column if null
    --  Column "X509_CERT_ID" uses sequence SEQ_X509_CERT_ID
    IF (:new.X509_CERT_ID IS NULL)
    THEN
        select SEQ_X509_CERT_ID.NEXTVAL
        INTO :new.X509_CERT_ID
        from dual;
    END IF;

--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TIB_X509_CERTIFICATE
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_X509_CERTIFICATE
 BEFORE UPDATE
 ON X509_CERTIFICATE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_X509_CERTIFICATE
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIUBR_KEY_USAGE_ATTRB
 BEFORE INSERT OR UPDATE
 ON X509_KEY_USAGE_ATTRIBUTE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIUBR_KEY_USAGE_ATTRB
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_KEY_USAGE_ATTRB
 BEFORE UPDATE
 ON X509_KEY_USAGE_ATTRIBUTE
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_KEY_USAGE_ATTRB
	ENABLE;


CREATE  OR REPLACE  TRIGGER C_TIBUR_KEY_USAGE_CTGRZTION
 BEFORE INSERT OR UPDATE
 ON X509_KEY_USAGE_CATEGORIZATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;
    V_CONTEXT_USER  VARCHAR2(256):=NULL;

begin
    -- Context should be used by apps to list the end-user id.
    -- if it is filled, then concatenate it on.
    V_CONTEXT_USER:=SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER');
    V_CONTEXT_USER:=UPPER(SUBSTR((USER||'/'||V_CONTEXT_USER),1,30));

    IF INSERTING
    THEN
        -- Override whatever is passed with context user
        :new.data_ins_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_ins_date:=sysdate;
    END IF;

    IF UPDATING
    THEN
        -- Preventing changes to insert user and date columns happens in
        -- another trigger

        -- Override whatever is passed with context user
        :new.data_upd_user:=V_CONTEXT_USER;

        -- Force date to be sysdate
        :new.data_upd_date:=sysdate;
    END IF;



--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER C_TIBUR_KEY_USAGE_CTGRZTION
	ENABLE;


CREATE  OR REPLACE  TRIGGER TUB_KEY_USAGE_CATEGRZTN
 BEFORE UPDATE
 ON X509_KEY_USAGE_CATEGORIZATION
 REFERENCING OLD AS OLD NEW AS NEW
 for each row
 
declare
    integrity_error  exception;
    errno            integer;
    errmsg           char(200);
    dummy            integer;
    found            boolean;

begin
    --  Non modifiable column "DATA_INS_USER" cannot be modified
    if updating('DATA_INS_USER') and :old.DATA_INS_USER != :new.DATA_INS_USER then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_USER" cannot be modified.';
       raise integrity_error;
    end if;

    --  Non modifiable column "DATA_INS_DATE" cannot be modified
    if updating('DATA_INS_DATE') and :old.DATA_INS_DATE != :new.DATA_INS_DATE then
       errno  := -20001;
       errmsg := 'Non modifiable column "DATA_INS_DATE" cannot be modified.';
       raise integrity_error;
    end if;


--  Errors handling
exception
    when integrity_error then
       raise_application_error(errno, errmsg);
end;

/



ALTER TRIGGER TUB_KEY_USAGE_CATEGRZTN
	ENABLE;
