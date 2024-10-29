-- Copyright (c) 2024, Matthew Ragan
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


DO $$
DECLARE
	switch	RECORD;
	ports	jsonb;
	ct		RECORD;
BEGIN
	FOR switch IN SELECT * FROM (VALUES

	--
	-- 7010T(X)
	--

	(
		'7010T-48', 'Arista 7010T, 48x1000BaseT & 4xSFP+ switch', 1,
		'[
			{ "slot_type": "1000BaseTEthernet", "count": 48 },
			{ "slot_type": "10GSFP+Ethernet", "count": 4 }
		]'::jsonb
	),

	(
		'7010TX-48', 'Arista 7010T, 48x1000BaseT & 4xSFP+ switch', 1,
		'[
			{ "slot_type": "1000BaseTEthernet", "count": 48 },
			{ "slot_type": "10GSFP+Ethernet", "count": 4 }
		]'::jsonb
	),


	--
	-- 7048
	--

	(
		'7048T-A', 'Arista 7048-A switch 48xRJ45(100/1000), 4xSFP+', 1,
		'[
			{ "slot_type": "1000BaseTEthernet", "count": 48 },
			{ "slot_type": "10GSFP+Ethernet", "count": 4 }
		]'::jsonb
	),

	--
	-- 7150
	--

	(
		'7150S-64-CL', 'Arista 7150, 48xSFP+ 4xQSFP+ switch, high precision clock', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 4 }
		]'::jsonb
	),

	(
		'7150S-64-CLD', 'Arista 7150, 48xSFP+ 4xQSFP+ switch, high precision clock, SSD', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 4 }
		]'::jsonb
	),


	(
		'7150SC-64-CLD', 'Arista 7150SC, 48xSFP+ 4xQSFP+ switch, high precision clock, SSD', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 4 }
		]'::jsonb
	),

	(
		'7150S-52-CL', 'Arista 7150, 48xSFP+ 4xQSFP+ switch, high precision clock', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 52 }
		]'::jsonb
	),

	(
		'7150S-52-CLD', 'Arista 7150, 48xSFP+ 4xQSFP+ switch, high precision clock, SSD', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 52 }
		]'::jsonb
	),

	(
		'7150S-24', 'Arista 7150, 24xSFP+ switch', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 24 }
		]'::jsonb
	),

	(
		'7150S-24-CL', 'Arista 7150, 48xSFP+ 4xQSFP+ switch, high precision clock', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 24 }
		]'::jsonb
	),

	(
		'7150S-24-CLD', 'Arista 7150, 48xSFP+ 4xQSFP+ switch, high precision clock, SSD', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 24 }
		]'::jsonb
	),

	--
	-- 7050
	--
	
	(
		'7050S-64', 'Arista 7050, 48xSFP+ & 4xQSFP+ switch', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 4 }
		]'::jsonb
	),

	(
		'7050S-52', 'Arista 7050, 48xSFP+ & 4xQSFP+ switch', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 52 }
		]'::jsonb
	),

	(
		'7050T-64', 'Arista 7050, 48xRJ45(1/10GBASE-T) & 4xQSFP+ switch', 1,
		'[
			{ "slot_type": "10GBaseTEthernet", "count": 48 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 4 }
		]'::jsonb
	),

	(
		'7050T-52', 'Arista 7050, 48xRJ45(1/10GBASE-T) & 4xSFP+ switch', 1,
		'[
			{ "slot_type": "10GBaseTEthernet", "count": 48 },
			{ "slot_type": "10GSFP+Ethernet", "count": 4 }
		]'::jsonb
	),

	(
		'7050T-36', 'Arista 7050, 32(1/10GBASE-T) & 4xSFP+ switch', 1,
		'[
			{ "slot_type": "10GBaseTEthernet", "count": 32 },
			{ "slot_type": "10GSFP+Ethernet", "count": 4 }
		]'::jsonb
	),

	(
		'7050Q-16', 'Arista 7050, 16xQSFP+ & 8xSFP+ switch', 1,
		'[
			{ "slot_type": "40GQSFP+Ethernet", "count": 16 },
			{ "slot_type": "10GSFP+Ethernet", "count": 8 }
		]'::jsonb
	),

	--
	-- 7050X/X2
	--

	(
		'7050SX2-128', 'Arista 7050X2, 96xSFP+ & 8xQSFP+ switch', 2,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 96 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 16 }
		]'::jsonb
	),

	(
		'7050SX-128', 'Arista 7050, 96xSFP+ & 8xQSFP+ switch', 2,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 96 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 16 }
		]'::jsonb
	),

	(
		'7050SX2-128-D', 'Arista 7050X2, 96xSFP+ & 8xQSFP+ switch, SSD', 2,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 96 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 16 }
		]'::jsonb
	),

	(
		'7050SX2-72Q', 'Arista 7050X2, 48xSFP+ & 6x40GbE QSFP+ switch', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 6 }
		]'::jsonb
	),

	(
		'7050SX-72Q', 'Arista 7050X, 48xSFP+ & 6x40GbE QSFP+ switch', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 6 }
		]'::jsonb
	),

	(
		'7050SX-64', 'Arista 7050X, 48xSFP+ & 6x40GbE QSFP+ switch', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 4 }
		]'::jsonb
	),

	(
		'7050SX-64-D', 'Arista 7050X, 48xSFP+ & 6x40GbE QSFP+, SSD switch', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 4 }
		]'::jsonb
	),

	--
	-- 7060/7260
	--

	(
		'7260CX-64', 'Arista 7260X, 64xQSFP28 & 2xSFP+ switch', 2,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 64 },
			{ "slot_type": "10GSFP+Ethernet", "count": 2 }
		]'::jsonb
	),

	(
		'7260QX-64', 'Arista 7260X, 64xQSFP+ & 2xSFP+ switch', 2,
		'[
			{ "slot_type": "40GQSFP+Ethernet", "count": 64 },
			{ "slot_type": "10GSFP+Ethernet", "count": 2 }
		]'::jsonb
	),

	(
		'7060CX-32S', 'Arista 7260X, 32xQSFP28 & 2xSFP+ switch', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "10GSFP+Ethernet", "count": 2 }
		]'::jsonb
	),

	(
		'7260CX2-32S', 'Arista 7260X2, 32xQSFP28 & 2xSFP+ switch', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "10GSFP+Ethernet", "count": 2 }
		]'::jsonb
	),

	(
		'7260SX2-48YC6', 'Arista 7260X2, 48xSFP28 & 6xQSFP28+ switch', 1,
		'[
			{ "slot_type": "25GSFP28Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 6 }
		]'::jsonb
	),

	--
	-- 7260X3
	--

	(
		'7260CX3-64', 'Arista 7260X, 64xQSFP28 & 2xSFP+ switch', 2,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 64 },
			{ "slot_type": "10GSFP+Ethernet", "count": 2 }
		]'::jsonb
	),

	(
		'7260CX3-64E', 'Arista 7260X, 64xQSFP28 & 2xSFP+ Enhanced switch', 2,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 64 },
			{ "slot_type": "10GSFP+Ethernet", "count": 2 }
		]'::jsonb
	),

	--
	-- 7160
	--

	(
		'7160-32CQ', 'Arista 7160, 32 x 100GbE QSFP28 switch', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 }
		]'::jsonb
	),

	(
		'7160-32CQ-M', 'Arista 7160, 32 x 100GbE QSFP28, SSD switch', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 }
		]'::jsonb
	),

	(
		'7160-48YC6', 'Arista 7160, 48xSFP28 6xQSFP28 switch', 1,
		'[
			{ "slot_type": "25GSFP28Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 6 }
		]'
	),

	(
		'7160-48TC6', 'Arista 7160, 48x10GBaseT 6xQSFP28 switch', 1,
		'[
			{ "slot_type": "10GBaseTEthernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 6 }
		]'
	),

	--
	-- 7280R
	--

	(
		'7280CR-48', 'Arista 7280R, 48x100GbE QSFP and 8x40GbE QSFP+ switch', 2,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 48 },
			{ "slot_type": "40GQSFP+Ethernet", "count": 8 }
		]'::jsonb
	),

	(
		'7280QR-C72', 'Arista 7280R, 56xQSFP+ and 16xQSFP28 switch', 2,
		'[
			{ "slot_type": "40GQSFP+Ethernet", "count": 56 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 16 }
		]'::jsonb
	),

	(
		'7280QR-C36', 'Arista 7280R, 24xQSFP+ and 12xQSFP28 switch', 1,
		'[
			{ "slot_type": "40GQSFP+Ethernet", "count": 24 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 12 }
		]'::jsonb
	),

	(
		'7280QR-C36', 'Arista 7280R, 48xSFP+ and 6xQSFP28 switch', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 6 }
		]'::jsonb
	),

	(
		'7280SR-48C6', 'Arista 7280R, 48xSFP+ and 6xQSFP28 switch', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 6 }
		]'::jsonb
	),

	(
		'7280TR-48C6', 'Arista 7280R, 48x10GBaseT and 6xQSFP28 switch', 1,
		'[
			{ "slot_type": "10GBaseTEthernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 6 }
		]'::jsonb
	),

	(
		'7280QRA-C36S', 'Arista 7280R, 24xQSFP+ and 12xQSFP28 switch', 1,
		'[
			{ "slot_type": "40GQSFP+Ethernet", "count": 24 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 12 }
		]'::jsonb
	),

	(
		'7280SR2-48YC6', 'Arista 7280R, 48xSFP28 and 6xQSFP28 switch', 1,
		'[
			{ "slot_type": "25GSFP+Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 6 }
		]'::jsonb
	),

	(
		'7280SR2A-48YC6', 'Arista 7280R, 48xSFP28 and 6xQSFP28 switch', 1,
		'[
			{ "slot_type": "25GSFP28Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 6 }
		]'::jsonb
	),

	(
		'7280SRA-48C6', 'Arista 7280R, 48xSFP28 and 6xQSFP28 switch', 1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 6 }
		]'::jsonb
	),

	(
		'7280TRA-48C6', 'Arista 7280R, 48x10GBaseT and 6xQSFP28 switch', 1,
		'[
			{ "slot_type": "10GBaseTEthernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 6 }
		]'::jsonb
	),

	(
		'7280CR2-60', 'Arista 7280R, 60xQSFP28 switch', 2,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 60 }
		]'::jsonb
	),

	(
		'7280CR2-60', 'Arista 7280R, 60xQSFP28 switch', 2,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 60 }
		]'::jsonb
	),

	(
		'7280CR2A-60', 'Arista 7280R, 60xQSFP28 switch', 2,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 60 }
		]'::jsonb
	),

	(
		'7280CR2K-60', 'Arista 7280R, 60xQSFP28 switch', 2,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 60 }
		]'::jsonb
	),

	(
		'7280CR2A-30', 'Arista 7280R, 30xQSFP28 switch', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 30 }
		]'::jsonb
	),

	(
		'7280CR2K-30', 'Arista 7280R, 30xQSFP28 switch', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 30 }
		]'::jsonb
	),

	(
		'7280SR2K-48C6', 'Arista 7280R, 24xSFP28, 24xSFP+ 6xQSFP28 switch', 1,
		'[
			{ "slot_type": "25GSFP28Ethernet", "count": 24 },
			{ "slot_type": "10GSFP+Ethernet", "count": 24 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 6 }
		]'::jsonb
	),


	--
	-- 7280R3
	--

	(
		'7280PR3-24', 'Arista 7280R3, 24x400GbE OSFP switch router', 1,
		'[
			{ "slot_type": "400GOSFPEthernet", "count": 24 }
		]'::jsonb
	),

	(
		'7280PR3-24-M', 'Arista 7280R3, 24x400GbE OSFP switch router, expn mem', 1,
		'[
			{ "slot_type": "400GOSFPEthernet", "count": 24 }
		]'::jsonb
	),

	(
		'7280PR3K-24', 'Arista 7280R3, 24x400GbE OSFP switch router, large routes', 1,
		'[
			{ "slot_type": "400GOSFPEthernet", "count": 24 }
		]'::jsonb
	),

	(
		'7280DR3-24', 'Arista 7280R3, 24x400GbE QSFP-DD switch router', 1,
		'[
			{ "slot_type": "400GQSFP-DDEthernet", "count": 24 }
		]'::jsonb
	),

	(
		'7280DR3-24-M', 'Arista 7280R3, 24x400GbE QSFP-DD switch router, expn mem', 1,
		'[
			{ "slot_type": "400GQSFP-DDEthernet", "count": 24 }
		]'::jsonb
	),

	(
		'7280DR3K-24', 'Arista 7280R3, 24x400GbE QSFP-DD switch router, large routes', 1,
		'[
			{ "slot_type": "400GQSFP-DDEthernet", "count": 24 }
		]'::jsonb
	),

	(
		'7280CR3-32P4', 'Arista 7280R3, 32x100GbE QSFP and 4x400GbE OSFP switch router', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "400GOSFPEthernet", "count": 4 }
		]'::jsonb
	),

	(
		'7280CR3-32P4-M', 'Arista 7280R3, 32x100GbE QSFP and 4x400GbE OSFP switch router, expn mem', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "400GOSFPEthernet", "count": 4 }
		]'::jsonb
	),

	(
		'7280CR3K-32P4', 'Arista 7280R3, 32x100GbE QSFP and 4x400GbE OSFP switch router, large routes', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "400GOSFPEthernet", "count": 4 }
		]'::jsonb
	),

	(
		'7280CR3K-32P4A', 'Arista 7280R3, 32x100GbE QSFP and 4x400GbE OSFP switch router, large routes', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "400GOSFPEthernet", "count": 4 }
		]'::jsonb
	),

	(
		'7280CR3-32D4', 'Arista 7280R3, 32x100GbE QSFP and 4x400GbE QSFP-DD switch router', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "400GQSFP-DDEthernet", "count": 4 }
		]'::jsonb
	),

	(
		'7280CR3-32D4-M', 'Arista 7280R3, 32x100GbE QSFP and 4x400GbE QSFP-DD switch router, expn mem', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "400GQSFP-DDEthernet", "count": 4 }
		]'::jsonb
	),

	(
		'7280CR3K-32D4', 'Arista 7280R3, 32x100GbE QSFP and 4x400GbE QSFP-DD switch router, large routes', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "400GQSFP-DDEthernet", "count": 4 }
		]'::jsonb
	),

	(
		'7280CR3K-32D4A', 'Arista 7280R3, 32x100GbE QSFP and 4x400GbE QSFP-DD switch router, large routes', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "400GQSFP-DDEthernet", "count": 4 }
		]'::jsonb
	),

	(
		'7280CR3-36S', 'Arista 7280R3, 36x100GbE QSFP/2x400G switch router', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 28 },
			{ "slot_type": "200GQSFP28-DDEthernet", "count": 6 },
			{ "slot_type": "400GQSFP-DDEthernet", "count": 2 }
		]'::jsonb
	),

	(
		'7280CR3K-36S', 'Arista 7280R3, 36x100GbE QSFP/2x400G switch router, large routes', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 28 },
			{ "slot_type": "200GQSFP28-DDEthernet", "count": 6 },
			{ "slot_type": "400GQSFP-DDEthernet", "count": 2 }
		]'::jsonb
	),

	(
		'7280CR3K-36SA', 'Arista 7280R3, 36x100GbE QSFP/2x400G switch router, large routes', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 28 },
			{ "slot_type": "200GQSFP28-DDEthernet", "count": 6 },
			{ "slot_type": "400GQSFP-DDEthernet", "count": 2 }
		]'::jsonb
	),


	(
		'7280CR3-96', 'Arista 7280R3, 96x100GbE QSFP switch router', 2,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 96 }
		]'::jsonb
	),

	(
		'7280CR3K-36S', 'Arista 7280R3, 96x100GbE QSFP switch router, large routes', 2,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 28 }
		]'::jsonb
	),

	--
	-- 7050X3
	--

	(
		'7050CX3-32S', 'Arista 7050X3, 32x100GbE QSFP100 & 2xSFP+ switch', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "10GSFP+Ethernet", "count": 2 }
		]'::jsonb
	),
	(
		'7050CX3-32C', 'Arista 7050X3, 32x100GbE QSFP100 & 2xSFP+ switch', 1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "10GSFP+Ethernet", "count": 2 }
		]'
	),
	(
		'7050CX3-32S-D',
		'Arista 7050X3, 32x100GbE QSFP100 & 2xSFP+ switch, expn memory, SSD',
		1,
		'[
			{ "slot_type": "100GQSFP28Ethernet", "count": 32 },
			{ "slot_type": "10GSFP+Ethernet", "count": 2 }
		]'
	),
	(
		'7050SX3-96YC8',
		'Arista 7050X3, 96x25GbE SFP & 8x100GbE QSFP100 switch',
		2,
		'[
			{ "slot_type": "25GSFP28Ethernet", "count": 96 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 8 }
		]'
	),
	(
		'7050SX3-48YC12',
		'Arista 7050X3, 48x25GbE SFP & 12x100GbE QSFP100 switch',
		1,
		'[
			{ "slot_type": "25GSFP28Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 12 }
		]'
	),
	(
		'7050SX3-48YC8',
		'Arista 7050X3, 48x25GbE SFP & 12x100GbE QSFP100 switch',
		1,
		'[
			{ "slot_type": "25GSFP28Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 8 }
		]'
	),
	(
		'7050SX3-48YC8',
		'Arista 7050X3, 48x25GbE SFP & 12x100GbE QSFP100 switch',
		1,
		'[
			{ "slot_type": "25GSFP28Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 8 }
		]'
	),
	(
		'7050SX3-48YC8C',
		'Arista 7050X3, 48x25GbE SFP & 12x100GbE QSFP100 switch',
		1,
		'[
			{ "slot_type": "25GSFP28Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 8 }
		]'
	),
	(
		'7050SX3-48C8',
		'Arista 7050X3, 48x10GbE SFP & 8x100GbE QSFP100 switch',
		1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 8 }
		]'
	),
	(
		'7050SX3-48C8C',
		'Arista 7050X3, 48x10GbE SFP & 8x100GbE QSFP100 switch',
		1,
		'[
			{ "slot_type": "10GSFP+Ethernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 8 }
		]'
	),
	(
		'7050TX3-48C8C',
		'Arista 7050X3, 48x10GbE 10GBaseT & 8x100GbE QSFP100 switch',
		1,
		'[
			{ "slot_type": "10GBaseTEthernet", "count": 48 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 8 }
		]'
	),
	(
		'7050SX3-24YC4C',
		'Arista 7050X3, 24x25GbE SFP & 4x100GbE QSFP100 switch',
		1,
		'[
			{ "slot_type": "25GSFP28Ethernet", "count": 24 },
			{ "slot_type": "100GQSFP28Ethernet", "count": 4 }
		]'
	)
	)
	AS s(model, description, size_units, ports) LOOP
		RAISE INFO 'Model is %', switch.model;
		BEGIN
			SELECT * INTO ct FROM component_manip.insert_arista_switch_type(
				model := switch.model,
				description := switch.description,
				size_units := switch.size_units,
				ports := switch.ports
			);
		EXCEPTION
			WHEN unique_violation THEN
				RAISE NOTICE 'switch model % already inserted',
					switch.model;
				CONTINUE;
		END;
		RAISE INFO '  component_type_id is %', ct.component_type_id;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

\ir Arista_720XP.sql
\ir Arista_7500.sql
\ir Arista_7800.sql
