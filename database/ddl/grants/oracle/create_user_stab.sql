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
-- $Id$
--

Prompt 'Enter new password for ap_stab:' 

create user ap_stab identified by &1;

create role stab_role;

grant create session to stab_role;

grant execute 				on jazzhands.ip_manip to stab_role;
grant execute 				on jazzhands.dns_gen_utils to stab_role;
grant execute 				on jazzhands.network_strings to stab_role;
grant select,update,insert,delete	on jazzhands.netblock to stab_role;
grant select,update,insert,delete	on jazzhands.secondary_netblock to stab_role;
grant select,update,insert,delete	on jazzhands.dns_record to stab_role;
grant select,update,insert		on jazzhands.dns_domain to stab_role;
grant select				on jazzhands.partner to stab_role;
grant select				on jazzhands.site to stab_role;

grant select,update,insert,delete	on jazzhands.physical_port to stab_role;
grant select,update,insert,delete	on jazzhands.network_interface to stab_role;
grant select,update,insert,delete	on jazzhands.device to stab_role;
grant select,update,insert		on jazzhands.val_status to stab_role;
grant select,update,insert		on jazzhands.site_netblock to stab_role;
grant select,update,insert		on jazzhands.device_function to stab_role;
grant select				on jazzhands.device_type to stab_role;
grant select				on jazzhands.operating_system to stab_role;
grant select				on jazzhands.composite_os_version to stab_role;
grant select				on jazzhands.val_ownership_status to stab_role;
grant select				on jazzhands.val_production_state to stab_role;
grant select				on jazzhands.val_device_function_type to stab_role;
grant select				on jazzhands.val_network_interface_purpose to stab_role;
grant select				on jazzhands.val_network_interface_type to stab_role;
grant select				on jazzhands.val_dns_type to stab_role;
grant select				on jazzhands.val_dns_class to stab_role;
grant select,insert			on jazzhands.snmp_commstr to stab_role;
grant select				on jazzhands.val_device_auto_mgmt_protocol to stab_role;

grant execute			 	on jazzhands.port_utils to stab_role;
grant execute			 	on jazzhands.device_utils to stab_role;
grant select,update,delete	   	on jazzhands.layer1_connection to stab_role;
grant select,update,insert	    	on jazzhands.device_type to stab_role;
grant select,update,insert	    	on jazzhands.operating_system to stab_role;
grant select,insert,update	    	on jazzhands.snmp_commstr to stab_role;
grant select			  	on jazzhands.val_snmp_commstr_type to stab_role;
grant select,insert,update,delete    	on jazzhands.device_type_power_port_templt to stab_role;
grant select,insert,update,delete    	on jazzhands.device_type_serial_port_templt to stab_role;
grant select			  	on jazzhands.val_plug_style to stab_role;
grant select,insert		  	on jazzhands.device_note to stab_role;
grant select,insert,update,delete  	on jazzhands.location to stab_role;
grant select,insert,update,delete  	on jazzhands.device_power_interface to stab_role;
grant select,insert,update,delete  	on jazzhands.device_power_connection to stab_role;
grant select,insert,update,delete  	on jazzhands.physical_connection to stab_role;


grant select,update,insert		on jazzhands.voe to stab_role;
grant select				on jazzhands.val_processor_architecture to stab_role;
grant select				on jazzhands.sw_package_repository to stab_role;

grant select				on jazzhands.SW_PACKAGE to stab_role;
grant select				on jazzhands.SW_PACKAGE_RELATION to stab_role;
grant select				on jazzhands.SW_PACKAGE_RELEASE to stab_role;
grant select				on jazzhands.SW_PACKAGE_REPOSITORY to stab_role;
grant select				on jazzhands.VAL_PACKAGE_RELATION_TYPE to stab_role;
grant select				on jazzhands.VAL_SW_PACKAGE_FORMAT to stab_role;
grant select				on jazzhands.VAL_VOE_STATE to stab_role;
grant select				on jazzhands.VOE_RELATION to stab_role;
grant select				on jazzhands.VOE_SW_PACKAGE to stab_role;
grant select				on jazzhands.VOE_SW_PACKAGE to stab_role;
grant select				on jazzhands.VOE_SYMBOLIC_TRACK to stab_role;
grant select				on jazzhands.VAL_UPGRADE_SEVERITY to stab_role;

grant select				on jazzhands.val_stop_bits to stab_role;
grant select				on jazzhands.val_data_bits to stab_role;
grant select				on jazzhands.val_baud to stab_role;
grant select				on jazzhands.val_flow_control to stab_role;
grant select				on jazzhands.val_parity to stab_role;
grant select				on jazzhands.val_cable_type to stab_role;
grant select				on jazzhands.val_system_user_type to stab_role;
grant select,insert,update,delete  	on jazzhands.dhcp_range to stab_role;
grant select				on jazzhands.device_collection to stab_role;
grant select				on jazzhands.device_collection_hier to stab_role;
grant select				on jazzhands.device_collection_device to stab_role;

-- 
-- for stuff that probably does not belong in stab
-- 
grant select on jazzhands.system_user to stab_role;
grant select on jazzhands.uclass to stab_role;
grant select on jazzhands.uclass_user to stab_role;
grant select on jazzhands.V_JOINED_UCLASS_USER_DETAIL to stab_role;
grant select on jazzhands.DEPT to stab_role;
grant select on jazzhands.dept_member to stab_role;
grant select on jazzhands.company to stab_role;
grant select,insert,update on jazzhands.UCLASS_PROPERTY_OVERRIDE to stab_role;
create synonym ap_stab.system_user for jazzhands.system_user;
create synonym ap_stab.uclass for jazzhands.uclass;
create synonym ap_stab.uclass_user for jazzhands.uclass_user;
create synonym ap_stab.V_JOINED_UCLASS_USER_DETAIL for jazzhands.V_JOINED_UCLASS_USER_DETAIL;
create synonym ap_stab.UCLASS_PROPERTY_OVERRIDE for jazzhands.UCLASS_PROPERTY_OVERRIDE;
create synonym ap_stab.DEPT for jazzhands.DEPT;
create synonym ap_stab.dept_member for jazzhands.dept_member;
create synonym ap_stab.company for jazzhands.company;

grant stab_role to ap_stab;

DECLARE
	dude    VARCHAR2(32) := 'ap_stab';
	obj	     VARCHAR2(32);
	stmt    VARCHAR2(1024);
	CURSOR  objcurs IS
		SELECT UNIQUE
			Table_Name
		FROM
			DBA_Role_Privs RP JOIN
			DBA_Tab_Privs TP ON RP.Granted_Role = TP.Grantee
		WHERE
			RP.Grantee IN (
				SELECT 
					UPPER(dude) AS Granted_Role 
				FROM
					DUAL
				UNION SELECT
					Granted_Role
				FROM
					DBA_Role_Privs
				START WITH
					Grantee=UPPER(dude)
				CONNECT BY PRIOR
					Granted_Role = Grantee
			) AND
			TP.Owner = 'JazzHands';

BEGIN
	OPEN objcurs;
	LOOP
		FETCH objcurs INTO obj;
		EXIT WHEN objcurs%NOTFOUND;
		BEGIN
			stmt := 'CREATE OR REPLACE SYNONYM ' || dude || '."' || obj ||
				'" FOR JazzHands."' || obj || '"';
			DBMS_OUTPUT.PUT_LINE(stmt);
			EXECUTE IMMEDIATE stmt;
		END;
	END LOOP;
	CLOSE objcurs;
END;

