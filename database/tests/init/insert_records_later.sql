--- test device data
insert into device_type_phys_port_templt
	(port_name, device_type_id, port_type)
select 'bge0', device_type_id, 'network'
  	from device_type
	where model = 'DL360';

insert into device_type_phys_port_templt
	(port_name, device_type_id, port_type)
select 'bge1', device_type_id, 'network'
  	from device_type
	where model = 'DL360';

insert into device_type_phys_port_templt
	(port_name, device_type_id, port_type)
select 'ttya', device_type_id, 'serial'
  	from device_type
	where model = 'DL360';

insert into device_type_phys_port_templt
	(port_name, device_type_id, port_type)
select 'ttyb', device_type_id, 'serial'
  	from device_type
	where model = 'DL360';

insert into device_type_power_port_Templt
	(power_interface_port, device_type_id, power_plug_style, voltage, max_amperage, provides_power)
select 'power0', device_type_id, 'IEC-60320-C13', 120, 20, 'N'
  	from device_type
	where model = 'DL360';

insert into device_type_power_port_Templt
	(power_interface_port, device_type_id, power_plug_style, voltage, max_amperage, provides_power)
select 'power1', device_type_id, 'IEC-60320-C13', 120, 20, 'N'
  	from device_type
	where model = 'DL360';

-- needs device type but needs to be associated with a device which does not
-- happen...
-- insert into location 
-- 	(rack_id, rack_u_offset_of_device_top)
-- select rack_id, 15
--  from rack where site_code = 'CORP0' and rack_name = '2';
