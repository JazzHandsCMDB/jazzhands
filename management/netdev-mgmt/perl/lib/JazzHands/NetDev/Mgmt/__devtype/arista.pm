package JazzHands::NetDev::Mgmt::__devtype::arista;

use strict;
use warnings;
use Data::Dumper;
use Socket;
use IO::Socket::SSL;
use JazzHands::Common::Util qw(_options);
use JazzHands::Common::Error qw(:all);
use JSON::XS;
use NetAddr::IP qw(:lower);
use LWP::UserAgent;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt = &_options(@_);

	my $self = {};

	if (!$opt->{credentials}) {
		SetError($opt->{errors}, 
			"credentials parameter must be passed to connect");
		return undef;
	}
	if (!$opt->{device}) {
		SetError($opt->{errors}, 
			"device parameter must be passed to connect");
		return undef;
	}   
	if (!ref($opt->{device})) {
		SetError($opt->{errors}, 
			"device parameter must be a device object");
		return undef;
	}   
	my $device = $opt->{device};
	
	if (!$device->{hostname}) {
		SetError($opt->{errors}, "device is missing hostname");
		return undef;
	}

	if (!$opt->{credentials}) {
		SetError($opt->{errors}, "must pass credentials");
		return undef;
	}

	$self->{credentials} = $opt->{credentials};
	$self->{device} = $device;
	bless $self, $class;
}

sub commit {
	my $self = shift;
	if (!ref($self)) {
		return undef;
	}
	my $opt = &_options(@_);
	my $err = $opt->{errors};

	return $self->SendCommand(
		commands => [ 
			'write memory'
		],
		errors => $err
	);
}

sub disconnect {
	return 1;
}


my $arista_cmd_serial = 1;

sub SendCommand {
	my $self;
	if (ref($_[0])) {
		$self = shift;
	}
	my $opt = &_options(@_);
	my $err = $opt->{errors};

	my $timeout = $opt->{timeout} || 30;
	my $credentials = $opt->{credentials} || $self->{credentials};
	if (!$credentials) {
		SetError($err, 
			"credentials parameter must be passed to SendCommand");
		return undef;
	}
	if (ref($opt->{commands}) ne 'ARRAY') {
		SetError($err,
			"commands parameter must be passed to SendCommand and be an array reference");
		return undef;
	}
	unshift @{$opt->{commands}}, 'enable';

	my $device = $self->{device};
	my $format = $opt->{format} || 'json';
	my $cmd = {
		jsonrpc => '2.0',
		method => 'runCmds',
		id => $arista_cmd_serial++,
		params => {
			version => 1,
			cmds => $opt->{commands},
			format => $format
		}
	};
	my $json_req;
	eval { $json_req = JSON::XS->new->pretty(1)->encode($cmd); };
	if (!$json_req) {
		SetError($opt->{errors}, 'unable to encode JSON');
		return undef;
	}

#	print Data::Dumper->Dump([$json_req], ["Request"]);
	my $ua = LWP::UserAgent->new(
		ssl_opts => {
			SSL_verify_mode   => SSL_VERIFY_NONE,
			verify_hostname => 0,
		}
	);
	$ua->agent("arista_mgr/1.0");
	$ua->timeout($timeout);
	my $header = HTTP::Headers->new;
	$header->authorization_basic(
		$credentials->{username},
		$credentials->{password});
	my $req = HTTP::Request->new(
		'POST',
		'https://' . ($device->{hostname} || $opt->{hostname}) . '/command-api',
		$header,
		$json_req);

	my $res;
	eval {
		local $SIG{ALRM} = sub { die "timeout"; };
		alarm($timeout);
#		print Dumper $ua;
#		print Dumper $req;
		$res = $ua->request($req);
		alarm(0);
	};
	if ($@ eq 'timeout') {
		SetError($err, "connection timed out");
		return undef;
	}
	if (!$res) {
		SetError($err, "Bad return");
		return undef;
	}
	if (!$res->is_success) {
		SetError($err, $res->status_line);
		return undef;
	}
	undef $ua;
#	print $res->content . "\n";
	my $result;
	eval { $result = JSON::XS->new->decode($res->content) };
#	print Data::Dumper->Dump([$result], ["Response"]);
	if ($result->{error}) {
		SetError($err, $result->{error}->{message});
		return undef;
	}
	shift @{$result->{result}};
	return $result->{result};
}

sub GetPortStatus {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	my $ports = $opt->{ports};
	if (!$ports) {
		SetError($err,
			"port parameter must be passed to GetPortStatus");
		return undef;
	}
	if (!ref($ports)) {
		$ports = [ $ports ];
	}

	#
	# Get all specified ports on a switch to a given LACP interface.  If
	# the LACP interface name is not passed, it is assumed to be the same
	# index number as the last index of the first port passed.
	#

	my $device = $self->{device};
	my $credentials = $self->{credentials};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $result = $self->SendCommand(
		credentials => $credentials,
		hostname => $device->{hostname},
		commands => [ 
			map { 'show interfaces ' . $_ } @$ports 
		],
		errors => $err
	);
	if (!$result) {
		return undef;
	}
	my $portstatus = {
		map { $_ =>
			{ lacp =>
				(shift @{$result})->{interfaces}->{$_}->
					{interfaceMembership} || undef
			}
		} @$ports
	};
	#
	# Get the switchport information for these ports, which requires getting
	# it for everything, and it's not even JSON
	#

	$result = $self->SendCommand(
		credentials => $credentials,
		hostname => $device->{hostname},
		commands => [ 'show interfaces switchport' ],
		format => 'text',
		errors => $err
	);
	if (!$result) {
		return undef;
	}
	my $porthash = {};
	my $portinfo;
	foreach my $line (split /\n/, $result->[0]->{output}) {
		next if $line =~ /^$/;
		my ($k, $val) = $line =~ /([^:]+): (.*)/;
		if ($k eq 'Name') {
			#
			# Change the names, because Arista sucks
			#
			$val =~ s/Et/Ethernet/;
			$val =~ s/Po/Port-Channel/;
			$portinfo = {};
			$porthash->{$val} = $portinfo;
			next;
		}
		if ($k eq 'Administrative Mode') {
			$portinfo->{mode} = ($val eq 'static access') ?
				'access' : 'trunk';
			next;
		}
		if ($k eq 'Access Mode VLAN') {
			($portinfo->{access_vlan}) = $val =~ /^(\S+)/;
			next;
		}
		if ($k eq 'Trunking Native Mode VLAN') {
			($portinfo->{native_vlan}) = $val =~ /^(\S+)/;
			next;
		}
		if ($k eq 'Trunking VLANs Enabled') {
			($portinfo->{trunk_vlans}) = $val;
			next;
		}
	}
	
	foreach my $port (@$ports) {
		my $status = $portstatus->{$port};
		if ($status->{lacp}) {
			$status->{lacp} =~ s/^Member of //;
			$portinfo = $porthash->{$status->{lacp}}
		} else {
			$portinfo = $porthash->{$port};
		}
		map {
			$status->{$_} = $portinfo->{$_};
		} keys %{$portinfo};
	}
	
	return $portstatus;
}

sub SetPortVLAN {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};
	my $debug = $opt->{debug} || '0';

	if (!$opt->{ports}) {
		SetError($err,
			"ports parameter must be passed to SetPortVLAN");
		return undef;
	}

	my @ports = (@{$opt->{ports}});
	if (!$opt->{vlan}) {
		SetError($err, "vlan parameter must be passed to SetPortVLAN");
		return undef;
	}
	if ($opt->{vlan} ne 'trunk' && $opt->{vlan} !~ /^\d+$/) {
		SetError($err, "vlan parameter must be a vlan number or 'trunk'");
		return undef;
	}
	my $vlan = $opt->{vlan};
	my $credentials = $self->{credentials};
	my $errors = $opt->{errors};
	my $device = $self->{device};

	if ($debug) {
		printf STDERR "Request to set ports %s to VLAN %d on switch %s\n",
			(join ',', @{$opt->{ports}}), $vlan, $device->{hostname};
	}
	my $result = $self->GetPortStatus(
		ports => [ @ports ],
		errors => $errors
	);
	return undef if (!defined($result));
	if ($debug) {
		printf STDERR "Current port status: %s", Data::Dumper->Dump(
			[ $result ], [ '$port_status']);
	}

	foreach my $p (keys(%$result)) {
		push @ports, $result->{$p}->{lacp} if defined($result->{$p}->{lacp});
	}


	my $commands;
	if ($vlan eq 'trunk') {
		$commands = [ 
			'configure',
			map { 
					'interface ' . $_,
					'spanning-tree portfast edge',
					'switchport mode trunk',
					'switchport trunk allowed vlan 100,150,151,2000-2999',
					'switchport trunk native vlan 100',
				} @ports
		];
	} else {
		$commands = [ 
			'configure',
			map {
					'interface ' . $_,
					'spanning-tree portfast edge',
					'switchport access vlan ' . $vlan,
					'switchport mode access'
				} @ports
		];
	}
	if ($commands) {
		my $result = $self->SendCommand(
			credentials => $credentials,
			hostname => $device->{hostname},
			commands => $commands,
			errors => $errors
		);
		return $result ? 1 : 0;
	}
	return 1;
}

sub SetPortLACP {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	my $ports = $opt->{ports};
	if (!$ports) {
		SetError($err,
			"ports parameter must be passed to SetPortLACP");
		return undef;
	}
	if (ref($ports) ne 'ARRAY') {
		SetError($err,
			"ports parameter must be an array reference");
		return undef;
	}
	
	if (!defined($opt->{lacp})) {
		SetError($err,
			"lacp parameter must be passed to SetPortLACP");
		return undef;
	}

	my $credentials = $self->{credentials};
	my $errors = $opt->{errors};
	#
	# Set all specified ports on a switch to a given LACP interface.  If
	# the LACP interface name is not passed, it is assumed to be the same
	# index number as the last index of the first port passed.
	#

	my $device = $self->{device};

	my $trunk_interface = $opt->{trunk_interface};
	my $idx;
	if (!$trunk_interface) {
		($idx) = $ports->[0] =~ /(\d+)$/;
		if (!$idx) {
			SetError(sprintf(
				"Unable to determine Port-channel interface for %s",
				$ports->[0]));
			return undef;
		}
		$trunk_interface = 'Port-Channel' . $idx;
	} else {
		($idx) = $trunk_interface =~ /port-channel(\d+)$/i;
		if (!$idx) {
			SetError(sprintf(
				"%s is not a valid Port-channel interface",
				$trunk_interface));
			return undef;
		}
		# Normalize the name
		$trunk_interface = 'Port-Channel' . $idx;
	}
	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	if ($debug) {
		printf STDERR "Request to set port LACP status to %s on for ports %s on LACP trunk interface %s on switch %s\n",
			$opt->{lacp} ? 'on' : 'off',
			(join ',', @{$opt->{ports}}),
			$trunk_interface,
			$device->{hostname};
	}
	#
	# Get current VLAN information
	#

	my $result = $self->GetPortStatus(
		ports => [ @$ports, $trunk_interface ],
		errors => $errors
	);
	return undef if (!defined($result));
	if ($debug) {
		print STDERR Data::Dumper->Dump( 
			[$result], ['$port_status']);
	}
	my $commands;
	if ($opt->{lacp}) {
		$commands = [ 
			'configure',
			'interface ' . $trunk_interface,
			'mlag ' . $idx,
			'port-channel lacp fallback',
			'port-channel lacp fallback timeout 15',
			'spanning-tree portfast edge',
			(map { 
					'interface ' . $_,
					'channel-group ' . $idx . ' mode active'
				} @$ports)
		];
		my $portinfo = $result->{$ports->[0]};
		if ($portinfo->{mode} eq 'access') {
			push @$commands, 
				'interface ' . $trunk_interface,
				'switchport mode access',
				sprintf("switchport access vlan %s",
					$portinfo->{access_vlan});
		} else {
			push @$commands, 
				'interface ' . $trunk_interface,
				'switchport mode trunk',
				sprintf("switchport trunk native vlan %s",
					$portinfo->{native_vlan});
		}
	} else {
		$commands = [ 
			'configure',
		];
		foreach my $port (@$ports) {
			next if (!defined($result->{$port}->{lacp}));
			push @$commands, 'interface ' . $port,
				'no channel-group',
				'spanning-tree portfast edge';
			my $trunkstanza;
			if ($result->{$trunk_interface}->{mode} eq 'access') {
				push @$commands, 
					'switchport mode access',
					sprintf("switchport access vlan %s",
						$result->{$trunk_interface}->{access_vlan});
			} else {
				push @$commands, 
					'switchport mode trunk',
					sprintf("switchport trunk native vlan %s",
						$result->{$trunk_interface}->{native_vlan});
			}
		}
	}
	if ($commands) {
		if ($debug) {
			printf STDERR "Commands:\n	%s\n", (join "\n", @$commands);
		}
		my $result = $self->SendCommand(
			credentials => $credentials,
			hostname => $device->{hostname},
			commands => $commands,
			errors => $errors
		);
		return $result;
	}
	return 1;
}

sub SetBGPPeerStatus {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{bgp_peer}) {
		SetError($err,
			"bgp_peer parameter must be passed to SetBGPPeerStatus");
		return undef;
	}

	if (!$opt->{state}) {
		SetError($err, "state parameter must be passed to SetBGPPeerStatus");
		return undef;
	}
	my $state = $opt->{state};
	if ($state ne 'up' && $state ne 'down' && $state ne 'delete') {
		SetError($err, "state parameter must be either 'up', 'down', or 'delete'");
		return undef;
	}
	my $credentials = $self->{credentials};
	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	#
	# Validate that this is a valid BGP peer for the device
	#
	# Figure out the BGP ASN that is being used (and that there is one)
	#
	my $commands = [
		'show ip bgp summary'
	];

	my $result = $self->SendCommand(
		credentials => $credentials,
		hostname => $device->{hostname},
		commands => $commands,
		format => 'text',
		errors => $err
	);

	if (!$result) {
		return undef;
	}
	my $output;
	if (!($output = $result->[0]->{output})) {
		SetError($err, "BGP does not appear to be configured on " .
			$device->{hostname});
		return undef;
	}
	
	my ($asn) = $output =~ /local AS number (\d+)/m;

	if (!$asn) {
		SetError($err, sprintf(
			"Unable to determine AS for %s.  This should not happen" .
			$device->{hostname}));
		return undef;
	}

	my @output = split /\n/, $output;

	my $peers = {
		map { (split /\s+/, $_)[0,8] } (grep /^\d+/, @output)
	};

	$commands = [
		'configure',
		'router bgp ' . $asn
	];

	if ($state eq 'down' || $state eq 'delete') {
		#
		# If we're supposed to down or delete the peer, and it doesn't
		# exist, wipe hands on pants
		#
		if (!exists($peers->{$opt->{bgp_peer}->addr})) {
			return 1;
		}
		if ($state eq 'down') {
			push @{$commands},
				'neighbor ' . $opt->{bgp_peer}->addr . ' shutdown';
		} else {
			push @{$commands},
				'no neighbor ' . $opt->{bgp_peer}->addr;
		}
	} else {
		#
		# If we're supposed to up the peer, and it does not exist,
		# determine if it's a valid peer
		#
		if (!exists($peers->{$opt->{bgp_peer}->addr})) {
			#
			# Get IP networks attached to the switch
			#
			my $result = $self->SendCommand(
				credentials => $credentials,
				hostname => $device->{hostname},
				commands => [ 'show ip interface'],
				errors => $err
			);

			if (!$result) {
				return undef;
			}
			#
			# Check all of the VLAN interfaces to ensure that this IP
			# network is on this switch
			#
			my $found = 0;
			foreach my $int (values %{$result->[0]->{interfaces}}) {
				next if $int->{name} !~ /^Vlan/;
				if (NetAddr::IP->new(
						$int->{interfaceAddress}->{primaryIp}->{address},
						$int->{interfaceAddress}->{primaryIp}->{maskLen})->
							network->contains($opt->{bgp_peer})) {
					$found = 1;
					last;
				}
			}
			if (!$found) {
				SetError($err, 
					sprintf("%s is not a valid address on switch %s",
					$opt->{bgp_peer},
					$device->{hostname}));
				return undef;
			}
			push @{$commands}, 'neighbor ' . $opt->{bgp_peer}->addr . 
				' peer-group ADNEXUS-HOST';
		}
		push @{$commands},
			'no neighbor ' . $opt->{bgp_peer}->addr . ' shutdown';
	}
	push @{$commands}, 'write memory';

	$result = $self->SendCommand(
		credentials => $credentials,
		hostname => $device->{hostname},
		commands => $commands,
		errors => $err
	);

	if (!$result) {
		return undef;
	}

	return 1;
}

sub GetInterfaceConfig {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{interface_name}) {
		SetError($err,
			"interface_name parameter must be passed to GetInterfaceConfig");
		return undef;
	}

	my $credentials = $self->{credentials};
	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my @errors;
	my $result = $self->SendCommand(
		credentials => $credentials,
		hostname => $device->{hostname},
		commands => [ 
			'show ip interface' . 
				($opt->{interface_name} ? ' ' . $opt->{interface_name} : '')
		],
		errors => \@errors
	);

	if (!$result) {
		return {};
	}

	my $addr = (values(%{$result->[0]->{interfaces}}))[0]
		->{interfaceAddress}->{primaryIp};

	my $iface = {
		addresses => {
			$addr->{address} . '/' . $addr->{maskLen} => { 
				"vrrp-group" => undef 
			}
		}
	};
	return $iface;
}

sub GetIPAddressInformation {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	my $credentials = $self->{credentials};
	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	#
	# These two commands have to be issued separately, because the API
	# sucks if one command returns an error
	#
	my $result = $self->SendCommand(
		credentials => $credentials,
		hostname => $device->{hostname},
		commands => [ 
			'show ip interface'
		],
		errors => $err
	);

	if (!$result) {
		return undef;
	}

	my $ipv4ifaces = $result->[0]->{interfaces};

	$result = $self->SendCommand(
		credentials => $credentials,
		hostname => $device->{hostname},
		commands => [ 
			'show ipv6 interface'
		],
		errors => $err
	);

	my $ipv6ifaces;
	if ($result) {
		$ipv6ifaces = $result->[0]->{interfaces};
	} else {
		$ipv6ifaces = {};
	}

	my $ifaceinfo;

	foreach my $iface (values %$ipv4ifaces) {
		next if (!$iface->{interfaceAddress}->{primaryIp}->{maskLen});
		$ifaceinfo->{$iface->{name}} = {
			ipv4 => [ 
				map {
					NetAddr::IP->new($_->{address}, $_->{maskLen})
				} ($iface->{interfaceAddress}->{primaryIp},
					@{$iface->{secondaryIpsOrderedList}})
			]
		};
	}

	foreach my $iface (values %$ipv6ifaces) {
		if (!exists($ifaceinfo->{$iface->{name}})) {
			$ifaceinfo->{$iface->{name}} = {};
		}
		$ifaceinfo->{$iface->{name}}->{ipv6} =
			[ map 
				{ 
					NetAddr::IP->new(
						$_->{address}, 
						NetAddr::IP->new($_->{subnet})->masklen
					)
				} @{$iface->{addresses}}
			];
	}

	return $ifaceinfo;
}

sub TestRouteExistence {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{route}) {
		SetError($err,
			"must pass desired route to TestRouteExistence");
		return undef;
	}

	my $credentials = $self->{credentials};
	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	#
	# These two commands have to be issued separately, because the API
	# sucks if one command returns an error
	#
	my $result = $self->SendCommand(
		credentials => $credentials,
		hostname => $device->{hostname},
		commands => [ 
			'show ip route ' . $opt->{route} . ' longer-prefixes',
		],
		errors => $err
	);

	if (!$result) {
		return undef;
	}

	if ($result->[0]->{vrfs}->{default}->{routes}) {
		return scalar(keys %{$result->[0]->{vrfs}->{default}->{routes}});
	} else {
		return 0;
	}
}

#
# Only support this list for historical purposs
#
my $CiscoACLPortMap = {
	bgp => 179,
	biff => 512,
	bootpc => 68,
	bootps => 67,
	chargen => 19,
	cmd => 514,
	daytime => 13,
	discard => 9,
	dnsix => 195,
	domain => 53,
	echo => 7,
	'exec' => 512,
	finger => 79,
	ftp => 21,
	'ftp-data' => 20,
	gopher => 70,
	hostname => 101,
	ident => 113,
	irc => 194,
	isakmp => 500,
	klogin => 543,
	kshell => 544,
	login => 513,
	lpd => 515,
	'mobile-ip' => 434,
	nameserver => 42,
	'netbios-dgm' => 138,
	'netbios-ns' => 137,
	'netbios-ss' => 139,
	nntp => 119,
	'non500-isakmp' => 4500,
	ntp => 123,
	'pim-auto-rp' => 496,
	pop2 => 109,
	pop3 => 110,
	rip => 520,
	smtp => 25,
	snmp => 161,
	snmptrap => 162,
	ssh => 22,
	sunrpc => 111,
	syslog => 514,
	tacacs => 49,
	talk => 517,
	telnet => 23,
	tftp => 69,
	'time' => 37,
	uucp => 540,
	who => 513,
	whois => 43,
	www => 80,
	xdmcp => 177,
};

sub GetPortList {
	my %ports = %{$CiscoACLPortMap};
	return \%ports;
}

sub SetCiscoFormatACL {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	if (!$opt->{acl}) {
		SetError($err,
			sprintf("%s: acl parameter must be passed to SetCiscoFormatACL",
				scalar(caller)));
		return undef;
	}
	if (!ref($opt->{acl})) {
		SetError($err, sprintf("%s: acl parameter must be an ACL object",
			scalar(caller)));
		return undef;
	}

	if (!$opt->{name}) {
		SetError($err, sprintf("%s: must pass ACL name", scalar(caller)));
		return undef;
	}

	my $acl = $opt->{acl};
	my $aclname = $opt->{name};

	my $acl_text;
	if ($opt->{no_template}) {
		$acl_text = $acl->{aces};
	} else {
		$acl_text = $acl->{full_acl};
	}

	my $converted_acl = GenerateTextForACL(
		errors => $err,
		entries => $acl_text,
		dbh => $opt->{dbh}
	);

	if (!defined($converted_acl)) {
		return undef;
	}

	unshift (@$converted_acl, sprintf("ip access-list %s", $aclname));

	return 1;
}

sub GenerateTextForACL {
	my $opt = &_options(@_);
	my $dbh = $opt->{dbh};

	if (!$opt->{entries}) { return ""; };


	my ($sth, $exist_sth);
	if ($dbh) {
		my $q = q {
			SELECT
				CASE 
					WHEN is_single_address = 'Y' THEN host(ip_address) || '/32'
					ELSE ip_address::text
				END
			FROM
				jazzhands.netblock_collection nc JOIN
				jazzhands.netblock_collection_netblock ncn USING 
					(netblock_collection_id) JOIN
				jazzhands.netblock USING (netblock_id)
			WHERE
				netblock_collection_type = 'prefix-list' AND
				netblock_collection_name = ?
		};

		if (!($sth = $dbh->prepare_cached($q))) {
			SetError($opt->{errors}, 
				sprintf("%s::Validate: Unable to prepare netblock collection query: %s",
					scalar(caller()),
					$dbh->errstr
				)
			);
			return undef;
		}

		$q = q {
			SELECT
				netblock_collection_id
			FROM
				jazzhands.netblock_collection
			WHERE
				netblock_collection_type = 'prefix-list' AND
				netblock_collection_name = ?
		};

		if (!($exist_sth = $dbh->prepare_cached($q))) {
			SetError($opt->{errors}, 
				sprintf("%s::Validate: Unable to prepare netblock collection query: %s",
					scalar(caller()),
					$dbh->errstr
				)
			);
			return undef;
		}
	}
	my @entries = (split /\n/, $opt->{entries});
	my $acl_entries = [];

	LINELOOP: foreach my $i (0..$#entries) {
		my $errstr;
		my $entry = JazzHands::NetDev::Mgmt::ACL::ParseACLLine(
			entry => $entries[$i],
			errors => \$errstr
		);
		if (!defined($entry)) {
			SetError($opt->{errors}, sprintf("Error on line %d: %s",
				$i + 1,
				$errstr || "unknown"
			));
			return undef;
		}
		next if (!$entry->{action});
		if ($entry->{action} eq 'remark') {
			push @$acl_entries, "remark " . $entry->{data};
			next;
		}
		foreach my $target (qw(source dest)) {
			my $x = $entry->{$target};
			if( exists($x->{group})) {
				if (!$dbh) {
					SetError($opt->{errors}, sprintf("%s: Error on line %d: prefix-list reference but no database connection",
						scalar(caller),
						$i
					));
					return undef;
				}
				my $addresses = [];
				foreach my $pl (@{$x->{group}}) {
					if (!($exist_sth->execute($pl))) {
						SetError($opt->{errors}, 
							sprintf("%s::Validate: Unable to execute netblock collection query: %s",
								scalar(caller()),
								$exist_sth->errstr
							)
						);
						return undef;
					}
					if (!$exist_sth->fetchrow_hashref) {
						SetError($opt->{errors}, 
							sprintf("%s::Validate: prefix-list %s referenced on line %d, but it does not exist in the database",
								scalar(caller()),
								$pl,
								$i
							)
						);
						$exist_sth->finish;
						return undef;
					}
					$exist_sth->finish;

					if (!($sth->execute($pl))) {
						SetError($opt->{errors}, 
							sprintf("%s::Validate: Unable to execute netblock collection member query: %s",
								scalar(caller()),
								$sth->errstr
							)
						);
						return undef;
					}
					my $row;
					while ($row = $sth->fetchrow_arrayref) {
						push @$addresses, $row->[0];
					}
					$sth->finish;
				}
				if (!@$addresses) {
					#
					# If all of the prefix-lists expand to no addresses,
					# skip this rule
					#
					next LINELOOP;
				}
				$x->{addrlist} = $addresses;
			}
			if (!exists($x->{addrlist}) || !@{$x->{addrlist}}) {
				$x->{addrlist} = [ "any" ];
			} else {
				my $crap = [ map {
						NetAddr::IP->new($_)
					} @{$x->{addrlist}}
				];
				$x->{addrlist} = $crap;
			}
			$x->{textlines} = [ @{$x->{addrlist}} ];
			if ($x->{portcmp}) {
				my $newtextlines = [];
				my @ranges = grep { (ref($_) eq 'ARRAY') } @{$x->{port}};
				my @nonranges = grep { !(ref($_) eq 'ARRAY') } @{$x->{port}};
				push @$newtextlines, map { 
						my $a = $_;
						map {
							$_ . " range " . join (' ', @$a)
						} @{$x->{textlines}}
					} @ranges; 
				#
				# Group ports into 10
				#
				while (@nonranges) {
					push @$newtextlines, 
						map {
							$_ . " eq " . join (' ', 
								@nonranges[0.. ($#nonranges > 9 ? 9 : $#nonranges)])
						} @{$x->{textlines}};
					@nonranges = @nonranges[10 .. $#nonranges];
				}
				$x->{textlines} = $newtextlines;
			}
		}
		map {
			my $a = $_;
			map {
				if ($entry->{protocol} ne "icmp") {
					push @$acl_entries, (sprintf("%s %s %s %s%s",
						$entry->{action},
						$entry->{protocol},
						$_,
						$a,
						$entry->{tcp_established} ? " established" : ""
					));
				} else {
					if (!($entry->{icmptypes})) {
						push @$acl_entries, 
							sprintf("%s %s %s %s",
								$entry->{action},
								$entry->{protocol},
								$_,
								$a
							);
					} else {
						my $b = $_;
						push @$acl_entries, map { sprintf("%s %s %s %s %s",
								$entry->{action},
								$entry->{protocol},
								$b,
								$a,
								$_
							) } @{$entry->{icmptypes}};
					}
				}
			} @{$entry->{source}->{textlines}};
		} @{$entry->{dest}->{textlines}};
	}
	return $acl_entries;
}
1;
