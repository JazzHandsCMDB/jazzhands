DROP TABLE IF EXISTS maestro_jazz.application;
CREATE TABLE maestro_jazz.application (
	service_id		integer			NOT NULL,
	service_collection_id	integer			NOT NULL,
	short_name                    citext.citext,
	abbreviation                  citext.citext,
	can_build_rpm                 integer,
	default_nagios_service_set_id integer,
	use_release                   integer		default 0 NOT NULL,
	legacy_has_config             integer		default 1 NOT NULL,
	starting_port_number          integer,
	max_num_ports                 integer,
	build_type                    citext.citext,
	inherited_application_id      integer,
	PRIMARY KEY (service_id),
	UNIQUE (service_collection_id)
);


grant insert,update,delete on all tables in schema maestro_jazz to maestro_iud_role;
grant select on all tables in schema maestro_jazz to maestro_ro_role;
