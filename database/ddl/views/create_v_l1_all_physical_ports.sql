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

-- This view is used to show all physical ports on a device and the ports
-- they are linked to, since this can go either way.

create or replace view v_l1_all_physical_ports as
select * from
(
select   
		l1.layer1_connection_Id,
		p1.physical_port_id 	as physical_port_id,
		p1.device_id		as device_id,
		p1.port_name		as port_name,
		p1.port_type		as port_type,
		p1.port_purpose		as port_purpose,
		p2.physical_port_id 	as other_physical_port_id,
		p2.device_id		as other_device_id,
		p2.port_name		as other_port_name,
		p2.port_purpose		as other_port_purpose,
		l1.baud,
		l1.data_bits,
		l1.stop_bits,
		l1.parity,
		l1.flow_control
	  from  physical_port p1
	    inner join layer1_connection l1
			on l1.physical_port1_id = p1.physical_port_id
	    inner join physical_port p2
			on l1.physical_port2_id = p2.physical_port_id
	 where  p1.port_type = p2.port_type
UNION
	 select
		l1.layer1_connection_Id,
		p1.physical_port_id 	as physical_port_id,
		p1.device_id		as device_id,
		p1.port_name		as port_name,
		p1.port_type		as port_type,
		p1.port_purpose		as port_purpose,
		p2.physical_port_id 	as other_physical_port_id,
		p2.device_id		as other_device_id,
		p2.port_name		as other_port_name,
		p2.port_purpose		as other_port_purpose,
		l1.baud,
		l1.data_bits,
		l1.stop_bits,
		l1.parity,
		l1.flow_control
	  from  physical_port p1
	    inner join layer1_connection l1
			on l1.physical_port2_id = p1.physical_port_id
	    inner join physical_port p2
			on l1.physical_port1_id = p2.physical_port_id
	 where  p1.port_type = p2.port_type
UNION
	 select
		NULL,
		p1.physical_port_id 	as physical_port_id,
		p1.device_id		as device_id,
		p1.port_name		as port_name,
		p1.port_type		as port_type,
		p1.port_purpose		as port_purpose,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL
	  from  physical_port p1
	left join layer1_connection l1
		on l1.physical_port1_id = P1.physical_port_id
		or l1.physical_port2_id = P1.physical_port_id
	     where  l1.layer1_connection_id is NULL
) order by NETWORK_STRINGS.NUMERIC_INTERFACE(port_name)
/
