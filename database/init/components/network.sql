--
-- Copyright (c) 2015 Matthew Ragan
-- All rights reserved.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

DO $$
BEGIN
	PERFORM * FROM val_component_function WHERE component_function =
		'network_adapter';
	
	IF NOT FOUND THEN
		--
		-- Component functions are somewhat arbitrary and exist mainly for
		-- associating valid component_properties
		--
		INSERT INTO val_component_function (component_function, description)
			VALUES ('network_adapter', 'Network Adapter');

		INSERT INTO val_component_property_type (
			component_property_type, description, is_multivalue
		) VALUES 
			('network_adapter', 'network adapter properties', 'Y');

		--
		-- Slot functions are also somewhat arbitrary, and exist for associating
		-- valid component_properties, for displaying UI components, and for
		-- validating inter_component_connection links
		--
		INSERT INTO val_slot_function (slot_function, description) VALUES
			('network', 'Network port');

		--
		-- Slot types are not arbitrary.  In order for a component to attach to
		-- a slot, a specific linkage must exist in either
		-- slot_type_permitted_component_type for internal connections (i.e. the
		-- component becomes a logical sub-component of the parent) or in
		-- slot_type_prmt_rem_slot_type for an external connection (i.e.
		-- a connection to a separate component entirely, such as a network or
		-- power connection)
		--

		--
		-- Network slot types
		--
		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		SELECT
			unnest(ARRAY[
				'SFP',
				'SFP+',
				'QSFP+',
				'SFP28',
				'QSFP28',
				'OSFP',
				'QSFP-DD',
				'GBIC',
				'XENPAK',
				'RJ45',
				'MPO',
				'LC',
				'SC',
				'10GSFP+Cu',
				'MXP'
			]),
			'network'
		;

		INSERT INTO slot_type 
			(slot_type, slot_physical_interface_type, slot_function,
			 description, remote_slot_permitted)
		VALUES
			-- Direct attach types
			('100BaseTEthernet', 'RJ45', 'network', '100BaseT Ethernet', 'Y'),
			('1000BaseTEthernet', 'RJ45', 'network', '1000BaseT Ethernet', 'Y'),
			('10GBaseTEthernet', 'RJ45', 'network', '10GBaseT Ethernet', 'Y'),
			('1GLCEthernet', 'LC', 'network', '1Gbps LC Fiber Ethernet', 'Y'),
			('10GLCEthernet', 'LC', 'network', '10Gbps LC Ethernet', 'Y'),
			('10GMPOEthernet', 'MPO', 'network', '10Gbps split-MPO Ethernet', 'Y'),
			('10GSFPCuEthernet', '10GSFP+Cu', 'network', '10Gbps SFP+Cu (TwinAx) Ethernet', 'Y'),
			('40GMPOEthernet', 'MPO', 'network', '40Gbps MPO/MTP Ethernet', 'Y'),
			-- Module-requiring types
			('1GSFPEthernet', 'SFP', 'network', '1Gbps SFP Ethernet', 'N'),
			('10GSFP+Ethernet', 'SFP+', 'network', '10Gbps SFP+ Ethernet', 'N'),
			('10GQSFP+Ethernet', 'QSFP+', 'network', '10Gbps split QSFP Ethernet', 'N'),
			('40GQSFP+Ethernet', 'QSFP+', 'network', '40Gbps QSFP Ethernet', 'N'),
			('100GMXPEthernet', 'MXP', 'network', '100Gbps MXP Ethernet', 'N'),
			('100GQSFP28Ethernet', 'QSFP28', 'network', '100Gbps QSFP28 Ethernet', 'N'),
			('400GQSFP-DDEthernet', 'QSFP-DD', 'network', '400Gbps QSFP-DD Ethernet', 'N'),
			('400GOSFPEthernet', 'OSFP', 'network', '400Gbps OSFP Ethernet', 'N'),
			('25GSFP28Ethernet', 'QSFP28', 'network', '25Gbps SFP28 Ethernet', 'N');


		--
		-- Insert the permitted module connections.  SFP and QSFP can only take
		-- themselves.  SFP+ can take SFP or SFP+.
		-- 

		INSERT INTO slot_type_prmt_comp_slot_type (
			slot_type_id,
			component_slot_type_id
		) SELECT
			st.slot_type_id,
			cst.slot_type_id
		FROM
			slot_type st,
			slot_type cst
		WHERE
			st.slot_function = 'network' AND cst.slot_function = 'network' AND
			(
				(st.slot_physical_interface_type = 'SFP' AND
					cst.slot_physical_interface_type = 'SFP') OR
				(st.slot_physical_interface_type = 'QSFP+' AND
					cst.slot_physical_interface_type = 'QSFP+') OR
				(st.slot_physical_interface_type = 'SFP+' AND
					cst.slot_physical_interface_type IN ('SFP', 'SFP+',
					'SFP28')) OR
				(st.slot_physical_interface_type = 'QSFP28' AND
					cst.slot_physical_interface_type IN ('QSFP+', 'QSFP28',
					'SFP28')) AND
				(st.slot_physical_interface_type = 'SFP28' AND
					cst.slot_physical_interface_type IN ('SFP+', 'QSFP+',
					'QSFP28', 'SFP28')) 
			);

		--
		-- Insert the permitted network connections.  Generically, the fiber
		-- types all interconnect, except for non-split MPO, which can only
		-- connect to itself, the RJ45 types all interconnect, and the
		-- 10GSFP+Cu only connects to itself
		-- 
		INSERT INTO slot_type_prmt_rem_slot_type (
			slot_type_id,
			remote_slot_type_id
		) SELECT
			st.slot_type_id,
			rst.slot_type_id
		FROM
			slot_type st,
			slot_type rst
		WHERE
			st.slot_function = 'network' AND rst.slot_function = 'network' AND (
			(st.slot_type = '40GMPOEthernet' AND
				rst.slot_type = '40GMPOEthernet') OR
			(st.slot_type = '10GSFPCuEthernet' AND
				rst.slot_type = '10GSFPCuEthernet') OR
			(st.slot_type IN ('10GMPOEthernet','10GLCEthernet','1GLCEthernet') AND
				rst.slot_type IN ('10GMPOEthernet','10GLCEthernet','1GLCEthernet')) OR
			(st.slot_physical_interface_type = 'RJ45' AND
				st.slot_physical_interface_type = 'RJ45')
			);
	END IF;
END; $$ language plpgsql;
