
insert into val_netblock_collection_type (netblock_collection_type, description) values ('prefix list', 'test case');

select set_config('jazzhands.appuser', 'test', false);

insert into netblock_collection (description, netblock_collection_type, netblock_collection_name) values ('test case', 'prefix list', 'test1');
insert into netblock_collection (description, netblock_collection_type, netblock_collection_name) values ('test case2', 'prefix list', 'test2');
insert into netblock_collection (description, netblock_collection_type, netblock_collection_name) values ('test case3', 'prefix list', 'test3');
insert into netblock_collection (description, netblock_collection_type, netblock_collection_name) values ('test case4', 'prefix list', 'test4');
insert into netblock_collection (description, netblock_collection_type, netblock_collection_name) values ('test case5', 'prefix list', 'test5');
insert into netblock_collection (description, netblock_collection_type, netblock_collection_name) values ('test case6', 'prefix list', 'test6');
insert into netblock_collection (description, netblock_collection_type, netblock_collection_name) values ('test case7', 'prefix list', 'test7');

insert into netblock_collection_hier (netblock_collection_id, child_netblock_collection_id) values (
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test1'),
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test2')
);

insert into netblock_collection_hier (netblock_collection_id, child_netblock_collection_id) values (
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test1'),
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test3')

);

insert into netblock_collection_hier (netblock_collection_id, child_netblock_collection_id) values (
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test3'),
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test4')
);

insert into netblock_collection_hier (netblock_collection_id, child_netblock_collection_id) values (
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test3'),
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test5')
);

insert into netblock_collection_hier (netblock_collection_id, child_netblock_collection_id) values (
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test1'),
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test6')
);

insert into netblock_collection_netblock (netblock_collection_id, netblock_id)
values (
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test5'),
	(select netblock_id from netblock where ip_address = net_manip.inet_ptodb('198.18.9.0', 25))
);

insert into netblock_collection_netblock (netblock_collection_id, netblock_id)
values (
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test1'),
	(select netblock_id from netblock where ip_address = net_manip.inet_ptodb('198.18.9.5', 26))
);

insert into netblock_collection_netblock (netblock_collection_id, netblock_id)
values (
	(select netblock_collection_id from netblock_collection where netblock_collection_type = 'prefix list' and netblock_collection_name = 'test3'),
	(select netblock_id from netblock where ip_address = net_manip.inet_ptodb('172.25.64.0', 24))
);

select	nc.netblock_collection_name, nc.netblock_collection_type, n.ip_address
 from	v_nblk_coll_netblock_expanded v
	inner join netblock_collection nc
		using (netblock_collection_id)
	inner join netblock n
		using (netblock_id)
;

