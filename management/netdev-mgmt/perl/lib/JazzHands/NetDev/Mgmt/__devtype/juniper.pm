package JazzHands::NetDev::Mgmt::__devtype::juniper;

use strict;
use warnings;
use Data::Dumper;
use Socket;
use	XML::DOM;
use JazzHands::Common::Util qw(_options);
use JazzHands::Common::Error qw(:all);
use NetAddr::IP qw(:lower);
use Net::MAC qw(:lower);

#
# We need to get rid of using JUNOS::Device, because Juniper sucks and has
# basically abandoned it
#
use JUNOS::Device;

use constant STATE_CONNECTED => 1;
use constant STATE_LOCKED => 2;
use constant STATE_CONFIG_LOADED => 3;

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
	#
	# If we already have a connection to the device, just return
	#
	my $hostname = $device->{hostname};
	if (defined($self->{handle})) {
		return $self;
	}

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}
	my $jnx;
	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$jnx = new JUNOS::Device(
			access => 'ssl',
			login => $opt->{credentials}->{username},
			password => $opt->{credentials}->{password},
			hostname => $hostname
		);
	};
	alarm 0;

	if (!ref($jnx)) {
		SetError($opt->{errors}, sprintf("Unable to connect to %s",
			$hostname));
		return undef;
	}
	$self->{handle} = $jnx;
	$self->{state} = STATE_CONNECTED;
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

	if (!$opt->{timeout}) {
		$opt->{timeout} = 90;
	}
	if (!$self->{handle}) {
		return;
	}

	my $hostname = $self->{device}->{hostname};

	my $rc = 1;
	my $jnx = $self->{handle};
	my @args;
	if ($opt->{confirmed_timeout}) {
		push @args, 
			"confirmed" => 1,
			"confirm-timeout" => $opt->{confirmed_timeout};
	}

	my $res;
	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->commit_configuration( @args);
	};
	alarm 0;

	if ($0 && $@ eq 'alarm') {
		SetError(
			$err,
			sprintf("%s: timeout commit to host %s", $hostname)
		);
		SetError(
			$opt->{errbyhost}->{$hostname},
			sprintf("commit timeout")
		);
		return 0;
	}
	my $jerr = $res->getFirstError();
	if ($jerr) {
		SetError($err,
			sprintf("%s: commit error: %s", $hostname, $jerr->{message}));
		SetError($opt->{errbyhost}->{$hostname},
			sprintf("commit error: %s", $jerr->{message}));
		$rc = 0;
	} else {
		$self->{state} = STATE_LOCKED;
	}
	return $rc;
}

sub rollback {
	my $self = shift;
	if (!ref($self)) {
		return undef;
	}
	my $opt = &_options(@_);
	my $err = $opt->{errors};

	if (!$self->{handle}) {
		return;
	}

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $hostname = $self->{device}->{hostname};

	my $rc = 1;
	my $jnx = $self->{handle};
	if ($self->{state} >= STATE_CONFIG_LOADED) {
		my $res;
		eval { 
			local $SIG{ALRM} = sub { die "alarm\n"; };
			alarm $opt->{timeout};
			$res = $jnx->load_configuration(rollback => 0);
		};

		alarm 0;

		if ($0 && $@ eq 'alarm') {
			SetError(
				$err,
				sprintf("%s: timeout commit to host %s", $hostname)
			);
			SetError(
				$opt->{errbyhost}->{$hostname},
				sprintf("commit timeout")
			);
			return 0;
		}

		my $jerr = $res->getFirstError();
		if ($jerr) {
			SetError($err,
				sprintf("%s: rollback error: %s", $hostname, $jerr->{message}));
			SetError($opt->{errbyhost}->{$hostname},
				sprintf("rollback error: %s", $jerr->{message}));
			$rc = 0;
		} else {
			$self->{state} = STATE_LOCKED;
		}
	}
	return $rc;
}

sub disconnect {
	my $self = shift;
	if (!ref($self)) {
		return undef;
	}
	my $opt = &_options(@_);
	my $err = $opt->{errors};

	if (!$self->{handle}) {
		return;
	}

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $hostname = $self->{device}->{hostname};

	my $jnx = $self->{handle};

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		my $state = $self->{state};
		if ($state >= STATE_CONFIG_LOADED && !$opt->{norollback}) {
			eval { $jnx->load_configuration(rollback => 0); };
		}
		if ($state >= STATE_LOCKED) {
			eval { $jnx->unlock_configuration(); };
		}
		if ($state >= STATE_CONNECTED) {
			eval {
				$jnx->request_end_session();
				$jnx->disconnect();
			};
		}
	};
	alarm 0;
	undef %$self;
	1;
}

sub check_for_changes {
	my $self = shift;
	if (!ref($self)) {
		return undef;
	}
	my $opt = &_options(@_);
	my $err = $opt->{errors};

	if (!$self->{handle}) {
		return;
	}
	my $jnx = $self->{handle};
	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $res;
	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->get_configuration(
			compare => 'rollback',
			rollback => 0,
			format => 'text'
		);
	};
	alarm 0;
	my $changes;
	if (!$res) {
		SetError($err, "error retrieving configuration");
		return undef;
	}

	my $x = $res->getElementsByTagName('configuration-output');
	if (@$x) {
		$changes = $x->[0]->getFirstChild->getNodeValue;
	}

	if (!$changes || $changes =~ /^\s*$/) {
		return 0;
	} else {
		return $changes;
	}
}

sub UploadConfigText {
	my $self;
	if (ref($_[0])) {
		$self = shift;
	}
	my $opt = &_options(@_);
	my $err = $opt->{errors};


	my $jnx = $self->{handle};

	if (!$opt->{config}) {
		SetError($err, "config option must be passed");
		return undef;
	}

	my $device = $self->{device};
	my $action = $opt->{action} || 'replace';

	my $res;
	$self->{state} = STATE_CONNECTED;

	eval {
		$res = $jnx->load_configuration(
			format => ($opt->{format} || 'text'),
			action => 'replace',
			($opt->{format} && $opt->{format} eq 'xml') ?
				(configuration => $opt->{config}) :
				("configuration-text" => $opt->{config})
		);
	};
	$self->{state} = STATE_CONFIG_LOADED;
	if ($@) {
		SetError($err, sprintf("Error sending config: %s", $@));
		return undef;
	}
	if (!$res) {
		SetError($err, "Unknown error sending config");
		return undef;
	}
	my $error = $res->getFirstError();
	if ($error) {
		SetError($err, sprintf("Error sending config: %s", $error->{message}));
		return undef;
	};
	if ($opt->{commit}) {
		return $self->commit(errors => \$err);
	}
	return 1;
}

sub SetPortVLAN {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};
	if (!$opt->{ports}) {
		SetError($err, "ports parameter must be passed to SetJuniperPortVLAN");
		return undef;
	}

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $debug = $opt->{debug};

	#
	# For historical reasons; should be removed after the few clients that
	# use this are upgraded
	#
	if ($opt->{vlan} && $opt->{vlan} eq 'trunk') {
		$opt->{portmode} = 'trunk';
		$opt->{vlan_list} = undef;
	}
	if (!$opt->{portmode}) {
		$opt->{portmode} = 'access';
	}
	if ($opt->{portmode} eq 'access') {
		if (!$opt->{vlan}) {
			SetError($err, "vlan parameter must be passed to SetPortVLAN if portmode is access");
			return undef;
		}
		if ($opt->{vlan} !~ /^\d+$/ || 
			$opt->{vlan} < 1 || $opt->{vlan} > 4095
		) {
			SetError($err,
				"vlan parameter must be an integer between 1 and 4095");
			return undef;
		}
	} elsif ($opt->{portmode} eq 'trunk') {
		#
		# Validate vlan_list and native_vlan parameters if they're passed
		#
		if (defined($opt->{vlan_list})) {
			if (ref($opt->{vlan_list}) ne 'ARRAY') {
				SetError($err,
					"vlan_list parameter must be an array of integers between 1 and 4095 or not defined");
				return undef;
			}
			if (
				grep { $_ !~ /^\d+$/ || $_ < 1 || $_ > 4095 } 
					@{$opt->{vlan_list}}
			) {
				SetError($err,
					"vlan_list parameter must be an array of integers between 1 and 4095 or not defined");
				return undef;
			}
		}

		if (exists($opt->{native_vlan}) && defined($opt->{native_vlan}) &&
			($opt->{native_vlan} !~ /^\d+$/ || 
				$opt->{native_vlan} < 1 || $opt->{native_vlan} > 4095)
		) {
			SetError($err,
				"native_vlan parameter must be an integer between 1 and 4095 or not defined");
			return undef;
		}

		my $vltext;
		if (defined($opt->{vlan_list})) {
			if (!@{$opt->{vlan_list}}) {
				$vltext = "none";
			} else {
				$vltext = (join ',', @{$opt->{vlan_list}});
			}
		} else {
			$vltext = "all";
		};

		if ($debug) {
			my $nvdesc;
			if (exists($opt->{native_vlan})) {
				if (defined($opt->{native_vlan})) {
					$nvdesc = $opt->{native_vlan};
				} else {
					$nvdesc = "cleared";
				}
			} else {
				$nvdesc = "unchanged";
			}
			printf STDERR "Request to set port(s) %s to trunk mode, VLAN list %s, native vlan %s on switch %s\n",
				(join ',', @{$opt->{ports}}),
				$vltext,
				$nvdesc,
				$self->{device}->{hostname};
		}
	}

	my $device = $self->{device};

	my ($trunk, $vlan);
	if ($opt->{portmode} eq 'trunk') {
		$trunk = 1;
	} else {
		$vlan = $opt->{vlan};
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $res;

	my $lacpstatus;
	if (!($lacpstatus = $self->GetPortLACP(
			ports => $opt->{ports},
			errors => $opt->{errors}))) {
		return undef;
	};

	my $ports;
	if (ref($opt->{ports})) {
		my %portlist;
		foreach my $port (@{$opt->{ports}}) {
			$portlist{$lacpstatus->{$port}||$port} = 1;
		}
		$ports = [ keys %portlist ];
	} else {
		$ports = [ $lacpstatus->{$opt->{ports}} || $opt->{ports} ];
	}

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};
		$res = $jnx->get_vlan_information(
			brief => 1
		);
	};
	alarm 0;

	if (!ref($res)) {
		SetError($err, "unable to retrieve VLAN information");
		return undef;
	}

	my %Vlans = (
		byid => {},
		byname => {}
	);

	foreach my $vl ($res->getElementsByTagName('vlan')) {
		my $vlname = $vl->getElementsByTagName('vlan-name')->[0]->
			getFirstChild->getNodeValue;
		my $vlstatus;
		$vlstatus = {
			name => $vlname,
			id =>
				$vl->getElementsByTagName('vlan-tag')->[0]->
				getFirstChild->getNodeValue,
		};
		next if !$vlstatus->{id};
		$Vlans{byname}->{$vlstatus->{name}} = $vlstatus;
		$Vlans{byid}->{$vlstatus->{id}} = $vlstatus;
	}

	foreach my $port (@$ports) {
		eval {
			local $SIG{ALRM} = sub { die "alarm\n"; };
			alarm $opt->{timeout};
			$res = $jnx->get_ethernet_switching_interface_information(
				interface_name => $port . ".0",
				detail => 1
			);

		};
		alarm 0;

		if (!ref($res)) {
			SetError($err,
				sprintf("Error retrieving port status for port %s", $port));
			return undef;
		}

		my $interface = $res->getElementsByTagName('interface')->[0];
		if (!$interface) {
			SetError($err, sprintf("Port %s does not exist", $port));
			return undef;
		}
		my $ifname = $interface->getElementsByTagName('interface-name')->[0]->
			getFirstChild->getNodeValue;
		my $ifstatus;
		$ifstatus = {
			name => $ifname,
			id =>
				$interface->getElementsByTagName('interface-id')->[0]->
				getFirstChild->getNodeValue,
			portMode =>
				$interface->getElementsByTagName('interface-port-mode')->[0]->
				getFirstChild->getNodeValue,
		};
		if ($ifstatus->{portMode} eq 'Access') {
			my $vlanInfo =
				$interface->getElementsByTagName('interface-vlan-member-list')->
				[0]->getElementsByTagName('interface-vlan-member')->[0];
			if (!$vlanInfo) {
				#
				# Some older JunOS switches suck
				#.
				$ifstatus->{vlan} = { id => 0, name => '' };
			} else {
				$ifstatus->{vlan} = {
					name => $vlanInfo->getElementsByTagName('interface-vlan-name')->
						[0]->getFirstChild->getNodeValue,
				};
				my $child = $vlanInfo->
					getElementsByTagName('interface-vlan-member-tagid')->[0];
				if ($child) {
					$ifstatus->{vlan}->{id} = $child->getFirstChild->getNodeValue;
				}
				$child = $vlanInfo->
					getElementsByTagName('interface-vlan-member-tagness')->[0];
				if ($child) {
					my $tagstuff = $child->getFirstChild->getNodeValue;
					if ($tagstuff && $tagstuff eq 'untagged') {
						$ifstatus->{native_vlan} = $ifstatus->{vlan}->{id};
					}
				}
			}
		}

		#
		# If we're not passed an explicit native vlan, use whatever
		# may have been set before, if anything
		#
		if (!exists($opt->{native_vlan})) {
			$opt->{native_vlan} = $ifstatus->{native_vlan};
		}

		if ($debug) {
			printf "Port %s currently has trunking %s",
				$ifstatus->{name},
				$ifstatus->{portMode} eq 'Trunk' ? 'on' : 'off';
			if ($ifstatus->{portMode} eq 'Access') {
				printf ", access VLAN %s",
				$ifstatus->{vlan}->{id} || 'default';
			}
			print "\n";
		}
		my $xml;
		if ($trunk) {
			#
			# Put the port into trunk mode
			#
			$xml = sprintf(q{
	<configuration>
		<interfaces>
			<interface>
			<name>%s</name>
				<unit>
					<name>0</name>
					<family>
						<ethernet-switching>
							<port-mode>trunk</port-mode>
							}, $port);

			if ($opt->{native_vlan}) {
				$xml .= sprintf(q{<native-vlan-id replace="replace">%d</native-vlan-id>
							}, $opt->{native_vlan});
			} else {
				$xml .= qq{<native-vlan-id delete="delete"/>\n};
			}
			$xml .= qq{<vlan replace="replace">\n};

			if (!defined($opt->{vlan_list})) {
				# Fuck you, Juniper.  If the native vlan is listed as a
				# member, things don't work, so put all of the vlans that
				# are present on the switch except the native vlan
				if (!$opt->{native_vlan}) {
					$xml .= "\t\t\t\t\t\t\t\t<members>all</members>\n";
				} else {
					foreach my $vl (sort {$a <=> $b } keys %{$Vlans{byid}}) {
						next if $vl eq $opt->{native_vlan};
						$xml .= sprintf("\t\t\t\t\t\t\t\t<members>%d</members>\n",
							$vl);
					}
				}
			} else {
				foreach my $vl (sort {$a <=> $b } @{$opt->{vlan_list}}) {
					if ($opt->{native_vlan} && $vl eq $opt->{native_vlan}) {
						next;
					}
					$xml .= sprintf("\t\t\t\t\t\t\t\t<members>%d</members>\n",
						$vl);
				}
			}
			$xml .= q{
							</vlan>
						</ethernet-switching>
					</family>
				</unit>
			</interface>
		</interfaces>
	</configuration>
			};

			if ($debug) {
				printf STDERR "XML config is:\n%s\n", $xml;
			}
			my $parser = new XML::DOM::Parser;
			my $doc = $parser->parsestring($xml);
			if (!$doc) {
				SetError($err,
					"Bad XML string setting VLAN trunking.  This should not happen");
				return undef;
			}
			eval {
				local $SIG{ALRM} = sub { die "alarm\n"; };
				alarm $opt->{timeout};
				$res = $jnx->load_configuration(
					format => 'xml',
					action => 'replace',
					configuration => $doc
				);
			};
			alarm 0;
			$self->{state} = STATE_CONFIG_LOADED;
			if ($@) {
				SetError($err,
					sprintf("Error setting VLAN for port %s: %s", $port, $@));
				return undef;
			}
			if (!$res) {
				SetError($err,
					sprintf("Unknown error setting VLAN for port %s", $port));
				return undef;
			}
			$err = $res->getFirstError();
			if ($err) {
				SetError($err,
					sprintf("Error setting VLAN for port %s: %s", $port,
						$err->{message}));
				return undef;
			};
		}
		if ($vlan) {
			#
			# Verify that the VLAN exists on the switch.  Specifically use
			# index 1, since we don't want any private VLANs which should not
			# be configured anyways.
			#
			if (!defined($Vlans{byid}->{$vlan})) {
				SetError($err,
					sprintf("VLAN %d does not exist on the switch\n", $vlan));
				return undef;
			}

			#
			# Put the port into access mode
			#
			$xml = sprintf(q{
	<configuration>
		<interfaces>
			<interface>
			<name>%s</name>
				<unit>
					<name>0</name>
					<family>
						<ethernet-switching>
							<port-mode>access</port-mode>
							<native-vlan-id delete="delete"/>
							<vlan>
								<members replace="replace">%d</members>
							</vlan>
						</ethernet-switching>
					</family>
				</unit>
			</interface>
		</interfaces>
	</configuration>
			}, $port, $vlan);
			if ($debug) {
				printf STDERR "XML config is:\n%s\n", $xml;
			}
			my $parser = new XML::DOM::Parser;
			my $doc = $parser->parsestring($xml);
			if (!$doc) {
				SetError($err,
					"Bad XML string setting VLAN.  This should not happen");
				return undef;
			}
			eval {
				local $SIG{ALRM} = sub { die "alarm\n"; };
				alarm $opt->{timeout};
				$res = $jnx->load_configuration(
					format => 'xml',
					action => 'replace',
					configuration => $doc
				);
			};
			alarm 0;
			$self->{state} = STATE_CONFIG_LOADED;
			if ($@) {
				SetError($err,
					sprintf("Error setting VLAN for port %s: %s", $port, $@));
				return undef;
			}
			if (!$res) {
				SetError($err,
					sprintf("Unknown error setting VLAN for port %s", $port));
				return undef;
			}
			my $xmlerr = $res->getFirstError();
			if ($xmlerr) {
				SetError($err, sprintf("Error setting VLAN for port %s: %s",
					$port, $xmlerr->{message}));
				return undef;
			};
		}
	}
	return 1;
}

sub GetPortLACP {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	if (!$opt->{ports}) {
		GetError($err,
			"ports parameter must be passed to GetPortLACP");
		return undef;
	}

	#
	# Get LACP status for all specified ports on a switch
	# index number as the last index of the first port passed.
	#

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	my $device = $self->{device};
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $parser = new XML::DOM::Parser;
	my $confdoc;
	my $res;
	my $currentae;
	foreach my $port (@{$opt->{ports}}) {

		eval {
			local $SIG{ALRM} = sub { die "alarm\n"; };
			alarm $opt->{timeout};

			$res = $jnx->get_lacp_interface_information(
				interface_name => $port
			);

		};
		alarm 0;

		if (!ref($res)) {
			SetError($err, sprintf("Error retrieving LACP status for port %s",
				$port));
			return undef;
		}
		my $aestanza = $res->getElementsByTagName('aggregate-name');
		my $aggint;
		if (!$aestanza || !$aestanza->[0]) {
			$currentae->{$port} = undef;
		} else {
			$aggint = $aestanza->[0]->getFirstChild->getNodeValue;
			$currentae->{$port} = $aggint;
		}
	}
	return $currentae;
}

sub SetPortLACP {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	if (!$opt->{ports}) {
		SetError($err,
			"ports parameter must be passed to SetJuniperPortLACP");
		return undef;
	}
	if (!defined($opt->{lacp})) {
		SetError($err,
			"lacp parameter must be passed to SetJuniperPortLACP");
		return undef;
	}

	#
	# Set all specified ports on a switch to a given LACP interface.  If
	# the LACP interface name is not passed, it is assumed to be the same
	# index number as the last index of the first port passed.
	#

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $aeinterface;
	if ($opt->{trunk_interface}) {
		$aeinterface = $opt->{trunk_interface};
	} else {
		my $port;
		if (!defined($port = $opt->{ports}->[0])) {
			SetError($err, "Bad port passed to SetJuniperPortLACP");
			return undef;
		}

		my ($idx) = $port =~ m%.*/(\d+)%;
		if (!defined($idx)) {
			SetError($err, sprintf(
				"Bad port %s passed to SetJuniperPortLACP", $port));
			return undef;
		}
		$aeinterface="ae" . $idx;
	}

	my $xml = qq {
	<configuration>
		<interfaces>
			<interface>
				<name> </name>
			</interface>
		</interfaces>
	</configuration>};
	my $parser = new XML::DOM::Parser;
	my $confdoc;
	my $res;
	my $currentae;
	foreach my $port (@{$opt->{ports}}) {
		#
		# Check the current ae status of the passed interfaces.  If they are
		# part of a different ae, then bail.
		#
		# Note: it would be awesome to use get_lacp_interface_information
		# here, except that we may have previous configuration changes
		# that were already made but not committed, so we have to look
		# at the config
		#
		$confdoc = $parser->parsestring($xml);
		$confdoc->getElementsByTagName('name')->[0]->getFirstChild->
			setData($port);

		eval {
			local $SIG{ALRM} = sub { die "alarm\n"; };
			alarm $opt->{timeout};

			$res = $jnx->get_configuration(configuration => $confdoc);
		};
		alarm 0;

		if (!ref($res)) {
			SetError($err, sprintf("Error retrieving LACP status for port %s",
				$port));
			return undef;
		}
		my $aestanza = $res->getElementsByTagName('bundle');
		my $aggint;
		if (!$aestanza->[0]) {
			$currentae->{$port} = undef;
		} else {
			$aggint = $aestanza->[0]->getFirstChild->getNodeValue;
			$currentae->{$port} = $aggint;
		}
	}
	#
	# Get information about the ae interface itself, to make sure things
	# are sane
	#

	#
	# If port is already a part a different ae, then error
	#
	my $portsaggregated = 0;
	my $portsnotaggregated = 0;
	foreach my $port (@{$opt->{ports}}) {
		if ($currentae->{$port}) {
			$portsaggregated++;
		} else {
			$portsnotaggregated++;
		}

		if ($currentae->{$port} && $currentae->{$port} ne $aeinterface) {
			SetError($err, sprintf(
				"Port %s is part of aggregate %s.  Will not %s %s",
				$port,
				$currentae->{$port},
				$opt->{lacp} ? "assign to" : "unassign from",
				$aeinterface));
			return undef;
		}
	}

	#
	# Check to see if anything needs to be done
	#
	if ($opt->{lacp} && ! $portsnotaggregated) {
		#
		# All ports listed are already assigned to this ae, so return 2
		# to signify that nothing changed
		#
		return 2;
	}

	if (!$opt->{lacp} && !$portsaggregated) {
		#
		# All ports listed are already not aggregated, so return 2
		# to signify that nothing changed
		#
		return 2;
	}

	#
	# Go for it, I guess
	#

	$confdoc = $parser->parsestring($xml);
	#
	# If we're enabling LACP, get the information for the port from the
	# first interface passed, otherwise, get it from the ae
	#
	my $port = $opt->{lacp} ? $opt->{ports}->[0] : $aeinterface;
	$confdoc->getElementsByTagName('name')->[0]->getFirstChild->setData($port);


	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->get_configuration(configuration => $confdoc);
	};
	alarm 0;

	if (!ref($res)) {
		SetError($err, sprintf("Error retrieving configuration for port %s",
			$port));
		return undef;
	}

	my $unit = $res->getElementsByTagName('unit')->[0];
	#
	# For now, error.  In the future, we'll set the port configuration if
	# it is passed
	#
	if (!$unit) {
		SetError($err, sprintf("No switchport configuration for %s", $port));
		return undef;
	}
	#
	# People suck
	#
	my $unitdoc = $parser->parsestring($unit->toString);
	$unit = $unitdoc->getFirstChild;

	my $intelement = $confdoc->getElementsByTagName('interfaces')->[0];

	if ($opt->{lacp}) {
		foreach my $interface (@{$opt->{ports}}) {
			#
			# Create the interface stanza
			#
			my $ielement = $confdoc->createElement('interface');
			my $newelement = $confdoc->createElement('name');
			$newelement->appendChild($confdoc->createTextNode($interface));
			$ielement->appendChild($newelement);
			$newelement = $confdoc->createElement('unit');
			$newelement->setAttribute('delete', 'delete');
			$ielement->appendChild($newelement);
			my $element = $newelement;
			$newelement = $confdoc->createElement('name');
			$newelement->appendChild($confdoc->createTextNode("0"));
			$element->appendChild($newelement);

			#
			# Configure the LACP stuff
			#
			$newelement = $confdoc->createElement('ether-options');
			$ielement->appendChild($newelement);
			$element = $newelement;
			$newelement = $confdoc->createElement('ieee-802.3ad');
			$element->appendChild($newelement);
			$element = $newelement;
			$newelement = $confdoc->createElement('bundle');
			$newelement->appendChild($confdoc->createTextNode($aeinterface));
			$element->appendChild($newelement);
			#
			# Append the config to the interface
			#
			$intelement->appendChild($ielement);
		}
		#
		# Create the interface stanza
		#
		my $ielement = $confdoc->createElement('interface');
		my $newelement = $confdoc->createElement('name');
		$newelement->appendChild($confdoc->createTextNode($aeinterface));
		$ielement->appendChild($newelement);
		$newelement = $confdoc->createElement('unit');
		$newelement->setAttribute('delete', 'delete');
		$ielement->appendChild($newelement);
		my $element = $newelement;
		$newelement = $confdoc->createElement('name');
		$newelement->appendChild($confdoc->createTextNode("0"));
		$element->appendChild($newelement);
		#
		# Configure the LACP stuff
		#
		$newelement = $confdoc->createElement('aggregated-ether-options');
		$ielement->appendChild($newelement);
		$element = $newelement;
		$newelement = $confdoc->createElement('lacp');
		$element->appendChild($newelement);
		$element = $newelement;
		$newelement = $confdoc->createElement('active');
		$element->appendChild($newelement);
		$newelement = $confdoc->createElement('periodic');
		$newelement->appendChild($confdoc->createTextNode('fast'));
		$element->appendChild($newelement);
		#
		# copy the unit to the interface
		#
		my $intunit = $unit->cloneNode(1);
		$intunit->setOwnerDocument($ielement->getOwnerDocument);
		$ielement->appendChild($intunit);
		#
		# Append the config to the interface
		#
		$intelement->appendChild($ielement);
	} else {
		foreach my $interface (@{$opt->{ports}}) {
			#
			# Create the interface stanza
			#
			my $ielement = $confdoc->createElement('interface');
			my $newelement = $confdoc->createElement('name');
			$newelement->appendChild($confdoc->createTextNode($interface));
			$ielement->appendChild($newelement);
			$newelement = $confdoc->createElement('unit');
			$newelement->setAttribute('delete', 'delete');
			$ielement->appendChild($newelement);
			my $element = $newelement;
			$newelement = $confdoc->createElement('name');
			$newelement->appendChild($confdoc->createTextNode("0"));
			$element->appendChild($newelement);
			$newelement = $confdoc->createElement('ether-options');
			$newelement->setAttribute('delete', 'delete');
			$ielement->appendChild($newelement);
			#
			# copy the unit to the interface
			#
			my $intunit = $unit->cloneNode(1);
			$intunit->setOwnerDocument($ielement->getOwnerDocument);
			$ielement->appendChild($intunit);
			#
			# Append the config to the interface
			#
			$intelement->appendChild($ielement);
		}
		#
		# Create the interface stanza
		#
		my $ielement = $confdoc->createElement('interface');
		my $newelement = $confdoc->createElement('name');
		$newelement->appendChild($confdoc->createTextNode($aeinterface));
		$ielement->appendChild($newelement);
		$newelement = $confdoc->createElement('unit');
		$newelement->setAttribute('delete', 'delete');
		$ielement->appendChild($newelement);
		my $element = $newelement;
		$newelement = $confdoc->createElement('name');
		$newelement->appendChild($confdoc->createTextNode("0"));
		$element->appendChild($newelement);

		#
		# Configure the LACP stuff
		#
		$newelement = $confdoc->createElement('aggregated-ether-options');
		$ielement->appendChild($newelement);
		$element = $newelement;
		$newelement = $confdoc->createElement('lacp');
		$element->appendChild($newelement);
		$element = $newelement;
		$newelement = $confdoc->createElement('active');
		$element->appendChild($newelement);
		$newelement = $confdoc->createElement('periodic');
		$newelement->appendChild($confdoc->createTextNode('fast'));
		$element->appendChild($newelement);
		#
		# Append the config to the interface
		#
		$intelement->appendChild($ielement);
	}

	eval {

		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->load_configuration(
			format => 'xml',
			action => 'replace',
			configuration => $confdoc
		);
	};
	alarm 0;
	$self->{state} = STATE_CONFIG_LOADED;
	if ($@) {
		SetError(sprintf("Error setting LACP configuration for %s: %s",
			$aeinterface, $@));
		return undef;
	}
	if (!$res) {
		SetError(sprintf(
			"Unknown error setting LACP configuration for port %s", $port));
		return undef;
	}
	my $xmlerr = $res->getFirstError();
	if ($xmlerr) {
		SetError(sprintf("Error setting LACP configuration for port %s: %s",
			$port, $xmlerr->{message}));
		return undef;
	};
	return 1;
}

sub GetPrefixLists {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	if ($opt->{'prefix-list'} && !$opt->{'prefix-lists'}) {
		$opt->{'prefix-lists'} = [ $opt->{'prefix-list'} ];
	}
	$opt->{name} = $opt->{'prefix-lists'};
	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $xml = qq {
	<configuration>
		<policy-options>
			<prefix-list>
				<name> </name>
			</prefix-list>
		</policy-options>
	</configuration>};
	my $parser = new XML::DOM::Parser;
	my $confdoc;
	my $res;
	my $prefixlists = {};
	if (!$opt->{name}) {
		$confdoc = $parser->parsestring($xml);
		$confdoc->getElementsByTagName('prefix-list')->[0]->
			removeChild($confdoc->getElementsByTagName('name')->[0]);

		eval {
			local $SIG{ALRM} = sub { die "alarm\n"; };
			alarm $opt->{timeout};

			$res = $jnx->get_configuration(configuration => $confdoc);
		};
		alarm 0;

		if (!ref($res)) {
			SetError($err, "Error retrieving prefix-lists");
			return undef;
		}
		foreach my $prefixlist ($res->getElementsByTagName('prefix-list')) {
			my $name = $prefixlist->getElementsByTagName('name')->[0]->
				getFirstChild->getNodeValue;
			$prefixlists->{$name} = [];
			foreach my $element ($prefixlist->
					getElementsByTagName('prefix-list-item')) {
				push @{$prefixlists->{$name}},
					NetAddr::IP->new(
						$element->getElementsByTagName('name')->[0]->
						getFirstChild->getNodeValue);
			}
		}
	} else {
		if (!ref($opt->{name})) {
			$opt->{name} = [ $opt->{name} ];
		}
		foreach my $name (@{$opt->{name}}) {
			$confdoc = $parser->parsestring($xml);
			$confdoc->getElementsByTagName('name')->[0]->getFirstChild->
				setData($name);

			eval {
				local $SIG{ALRM} = sub { die "alarm\n"; };
				alarm $opt->{timeout};
				$res = $jnx->get_configuration(configuration => $confdoc);
			};
			alarm 0;

			if (!ref($res)) {
				SetError($err, sprintf("Error retrieving prefix-list %s",
					$name));
				return undef;
			}
			my $prefixlist = $res->getElementsByTagName('prefix-list')->[0];
			if ($prefixlist) {
				$prefixlists->{$name} = [];
				foreach my $element ($prefixlist->
						getElementsByTagName('prefix-list-item')) {
					push @{$prefixlists->{$name}},
						NetAddr::IP->new(
							$element->getElementsByTagName('name')->[0]->
							getFirstChild->getNodeValue);
				}
			}
		}
	}
	return $prefixlists;
}

sub SetPrefixLists {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	if (!ref($opt->{"prefix-lists"})) {
		GetError($err,
			"prefix-lists parameter must be passed to SetPrefixLists");
		return undef;
	}

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $xml = qq {
	<configuration>
		<policy-options>
		</policy-options>
	</configuration>};
	my $parser = new XML::DOM::Parser;
	my $confdoc = $parser->parsestring($xml);
	my $res;
	my $prefixlists = {};
	my $polelement = $confdoc->getElementsByTagName('policy-options')->[0];
	foreach my $prefixlist (keys %{$opt->{"prefix-lists"}}) {
		my $plelement = $confdoc->createElement('prefix-list');
		my $newelement = $confdoc->createElement('name');
		$newelement->appendChild($confdoc->createTextNode($prefixlist));
		$plelement->appendChild($newelement);
		$plelement->setAttribute('replace', 'replace');
		foreach my $netblock
			(@{$opt->{"prefix-lists"}->{$prefixlist}})
		{
			my $plielement = $confdoc->createElement('prefix-list-item');
			$newelement = $confdoc->createElement('name');
			$newelement->appendChild($confdoc->createTextNode($netblock));
			$plielement->appendChild($newelement);
			$plelement->appendChild($plielement);
		}
		$polelement->appendChild($plelement);
	}

	eval {

		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->load_configuration(
			format => 'xml',
			action => 'replace',
			configuration => $confdoc
		);
	};
	alarm 0;

	$self->{state} = STATE_CONFIG_LOADED;
	if ($@) {
		SetError($err,
			sprintf("Error setting prefix-list configurations: %s", $@));
		return undef;
	}
	if (!$res) {
		SetError($err, "Unknown error setting prefix-list configurations");
		return undef;
	}
	my $xmlerr = $res->getFirstError();
	if ($xmlerr) {
		SetError($err, sprintf("Error setting prefix-list configuration: %s",
			$xmlerr->{message}));
		return undef;
	};
	return 1;
}


sub DeletePrefixLists {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	if (!defined($opt->{"prefix-list"})) {
		GetError($err,
			"prefix-list parameter must be passed to DeleteJuniperPrefixLists");
		return undef;
	}

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $xml = qq {
	<configuration>
		<policy-options>
		</policy-options>
	</configuration>};
	my $parser = new XML::DOM::Parser;
	my $confdoc = $parser->parsestring($xml);
	my $res;
	my $prefixlists = {};
	my $polelement = $confdoc->getElementsByTagName('policy-options')->[0];
	if (!ref($opt->{"prefix-list"})) {
		$opt->{"prefix-list"} = [ $opt->{"prefix-list"} ];
	}
	foreach my $prefixlist (@{$opt->{"prefix-list"}}) {
		my $plelement = $confdoc->createElement('prefix-list');
		my $newelement = $confdoc->createElement('name');
		$newelement->appendChild($confdoc->createTextNode($prefixlist));
		$plelement->appendChild($newelement);
		$plelement->setAttribute('delete', 'delete');
		$polelement->appendChild($plelement);
	}

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->load_configuration(
			format => 'xml',
			action => 'replace',
			configuration => $confdoc
		);
	};
	alarm 0;

	$self->{state} = STATE_CONFIG_LOADED;
	if ($@) {
		SetError(sprintf("Error setting prefix-list configurations: %s", $@));
		return undef;
	}
	if (!$res) {
		SetError(sprintf(
			"Unknown error setting prefix-list configurations"));
		return undef;
	}
	my $xmlerr = $res->getFirstError();
	if ($xmlerr) {
		SetError(sprintf("Error setting prefix-list configuration: %s",
			$xmlerr->{message}));
		return undef;
	};
	return 1;
}

sub GetMSTPDigest {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $parser = new XML::DOM::Parser;
	my $confdoc;
	my $res;
	my $prefixlists = {};

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->get_mstp_bridge_configuration_information();
	};
	alarm 0;

	if (!ref($res)) {
		SetError($err, "Error retrieving mstp configuration");
		return undef;
	}
	my $digest = $res->getElementsByTagName('mstp-configuration-digest')->[0]->getFirstChild->getNodeValue;
	return $digest;
}

sub TestRouteExistence {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	if (!$opt->{route}) {
		SetError($err,
			"must pass desired route to TestRouteExistence");
		return undef;
	}

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $res;

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->get_route_information(
			destination => $opt->{route},
			exact => 1);
	};
	alarm 0;

	if (!ref($res)) {
		SetError($err, "Error retrieving route information");
		return undef;
	}
	my $table = $res->getElementsByTagName('route-table');
	if ($table) {
		return $table->getLength;
	} else {
		return 0;
	}
}

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

my $CiscoICMPMap = {
	"echo" => "echo-request",
	"echo-reply" => "echo-reply",
	"information-request" => "info-request",
	"information-reply" => "info-reply",
	"mask-request" => "mask-request",
	"mask-reply" => "mask-reply",
	"parameter-problem" => "parameter-problem",
	"redirect" => "redirect",
	"router-advertisement" => "router-advertisement",
	"router-solicitation" => "router-solicit",
	"source-quench" => "source-quench",
	"time-exceeded" => "time-exceeded",
	"timestamp-request" => "timestamp",
	"timestamp-reply" => "timestamp-reply",
	"unreachable" => "unreachable",
};

sub GetPortList {
	my %ports = %{$CiscoACLPortMap};
	return \%ports;
}

sub ConvertCiscoACLLineToJunOS {

	#
	# Note that this function does not return the outer <term>
	# wrapping unless the term_name option is passed
	#

	my $opt = &_options(@_);

	my $error = $opt->{errors};
	my $line = $opt->{line};
	my $valid_ranges = $opt->{valid_ranges};

	if (!$line || $line =~ /^\s*$/) {
		return undef;
	}

	## Validate the valid_ranges option

	if (defined $valid_ranges) {
	    unless (ref($valid_ranges) && ref($valid_ranges) eq 'ARRAY') {
		SetError($error, "valid_ranges must be an array reference");
		return undef;
	    }

	    foreach my $r (@$valid_ranges) {
		unless (ref($r) && ref($r) eq 'ARRAY') {
		    SetError($error, "valid_ranges must be a reference to an array of arrays");
		    return undef;
		}

		unless ($#$r == 1 && $r->[0] =~ /^\d+$/ && $r->[1] =~ /^\d+$/ ) {
		    SetError($error, "each item in valid_ranges must be an array of two numbers");
		    return undef;
		}
	    }
	}

	my ($document, $filter);
#	if ($opt->{filter}) {
#		$filter = $opt->{filter};
#		eval {
#			$document = $filter->getOwnerDocument;
#		}
#	} else {
		$document = new XML::DOM::Document;
#	}
	if (!$document) {
		SetError($error,
			"Unable to create or determine XML document for firewall rules");
		return undef;
	}

	my $element;

	#
	# Get rid of any leading whitespace
	#
	$line =~ s/^\s+//;

	if ($line =~ /^!/) {
		$element = $document->createElement('junos:comment');
		$element->appendChild($document->createTextNode(
			sprintf("/* %s */", $line)));
		return $element;
	}

	my @tokens = split /\s+/, $line;
	my $action = shift @tokens;


	# Any comments we just return
	# If we don't otherwise start with 'permit' or 'deny', also bail

	if ($action eq 'remark') {
		$element = $document->createElement('junos:comment');
		$element->appendChild($document->createTextNode(
			sprintf("/* %s */", join(' ', @tokens))));
		return $element;
	} elsif ($action eq 'permit') {
		$action = 'accept';
	} elsif ($action eq 'deny') {
		$action = 'discard';
	} else {
		SetError($error, sprintf("Unknown action : %s", $action));
		return undef;
	}

	my $proto = shift @tokens;
	if (
			$proto ne 'ip' &&
			$proto ne 'tcp' &&
			$proto ne 'udp' &&
			$proto ne 'esp' &&
			$proto ne 'ahp' &&
			$proto ne 'icmp' &&
			$proto ne 'gre') {
		SetError($error, sprintf("unsupported protocol: %s", $proto));

		return undef;
	}
	# JunOS and Cisco specify AH differently
	$proto = "ah" if $proto eq "ahp";

	my $source = {};
	my $dest = {};

	foreach my $target ($source, $dest) {
        my $addr = shift @tokens;
        if ($addr eq 'any') {
            $target->{addrlist} = undef;
        } elsif ($addr eq 'host') {
            $target->{addrlist} = [ shift @tokens ];
        } elsif ($addr eq 'addrgroup') {
            $target->{group} = [ split /,/, shift @tokens ];
        } elsif ($addr eq 'addrlist') {
            $target->{addrlist} = [ split /,/, shift @tokens ];
        } else {
            my $testaddr;
            eval {
				$testaddr = inet_aton($addr);
				if ($testaddr) {
					$testaddr = inet_ntoa($testaddr);
				}
			};
            if (!$testaddr || ($testaddr ne $addr)) {
                SetError($error,
                    sprintf("Bad address format: %s", $addr));
                return undef;
            }
            my $mask = shift @tokens;
			my $testmask;
            eval {
				$testmask = inet_aton($mask);
				if ($testmask) {
					$testmask = inet_ntoa($testmask) ;
				}
			};
            if (!$testmask || ($testmask ne $mask)) {
                SetError($error,
                    sprintf("Bad mask format: %s", $mask));
                return undef;
            }
            my $maskval = unpack('N', inet_aton($mask));
            $maskval = $maskval ^ 0xffffffff;
            my $bitmask;
            my $bits;
			if ($maskval) {
				foreach my $i (1..32) {
					$bitmask |= (0x1 << (32 - $i));
					if ($bitmask == $maskval) {
						$bits = $i;
						last;
					}
				}
			} else {
				$bits = 0;
			}
            if (!defined($bits)) {
                SetError($error,
                    sprintf("Bad mask format: %s", $mask));
                return undef;
            }
			$testaddr = unpack('N', inet_aton($addr));
            if (($testaddr & $bitmask) != $testaddr) {
                SetError($error,
                    sprintf("Mask %s is not valid for address %s",
						$mask, $addr));
                return undef;
            }
			#
			# If bits is 0, then it's really "any"
			#
			if ($bits) {
				$target->{addrlist} = [ $addr . "/" . $bits ];
			}
        }

		foreach $addr (@{$target->{addrlist}}) {
			my ($xaddr, $xmask) = split m%/%, $addr;

            my $testaddr;
            eval {
				$testaddr = inet_aton($xaddr);
				if ($testaddr) {
					$testaddr = inet_ntoa($testaddr);
				}
			};
            if (!$testaddr || ($testaddr ne $xaddr)) {
                SetError($error,
                    sprintf("Bad address format: %s", $xaddr));
                return undef;
            }
			if (defined($xmask)) {
				if ($xmask !~ /^\d+$/ || ($xmask < 0 || $xmask > 32)) {
					SetError($error,
						sprintf("Bad mask: /%s", $xmask));
					return undef;
				}
				my $bitmask = 0xffffffff << (32 - $xmask);
				$testaddr = unpack('N', inet_aton($xaddr));
				if (($testaddr & $bitmask) ne $testaddr) {
					SetError($error,
						sprintf("Mask /%s is not valid for address %s",
							$xmask, $addr));
					return undef;
				}
			}
		}
		next if ($proto eq 'icmp');
		if (
				@tokens && (
				$tokens[0] eq 'eq' ||
				$tokens[0] eq 'gt' ||
				$tokens[0] eq 'lt' ||
				$tokens[0] eq 'range' )) {
			if (
					$proto ne 'tcp' &&
					$proto ne 'udp') {
				SetError($error,
					sprintf("Port not valid for protocol %s", $proto));
				return undef;
			}
			$target->{portcmp} = shift @tokens;
			my $portstring = shift @tokens;
			if (!$portstring) {
				SetError($error,
					sprintf("Port not specified after comparison operator"));
				return undef;
			}
			$target->{port} = [];
			if ($target->{portcmp} eq 'eq') {
				foreach my $port (split /,/, $portstring) {
					if ($CiscoACLPortMap->{lc($port)}) {
						$port = $CiscoACLPortMap->{lc($port)};
					}
					my ($startport, $endport);
					if ( ($startport, $endport) = $port =~ /^(\w+)-(\w+)$/) {
						if ($CiscoACLPortMap->{lc($startport)}) {
							$startport = $CiscoACLPortMap->{lc($startport)};
						}
						if ($startport !~ /^\d+$/ ||
								$startport < 0 || $startport > 65535) {
							SetError($error, sprintf("Bad port: %s", $port));
							return undef;
						}
						if ($CiscoACLPortMap->{lc($endport)}) {
							$endport = $CiscoACLPortMap->{lc($endport)};
						}
						if ($endport !~ /^\d+$/ ||
								$endport < 0 || $endport > 65535) {
							SetError($error, sprintf("Bad port: %s", $port));
							return undef;
						}
						if ($startport >= $endport) {
							SetError($error,
								sprintf("Start port greater than end port in port range '%s'",
									 $port));
							return undef;
						}
						$port = $startport . '-' . $endport;
					} else {
						if ($port !~ /^\d+$/ ||
								$port < 0 || $port > 65535) {
							SetError($error, sprintf("Bad port: %s", $port));
						return undef;
						}
					}
					push @{$target->{port}}, $port;
				}
			}
			#
			# Convert 'lt' and 'gt' to ranges
			#

		        my $real_portcmp = $target->{portcmp};

			if ($target->{portcmp} eq 'lt') {
				$target->{portcmp} = 'range';
				unshift @tokens, 0;
			}
			if ($target->{portcmp} eq 'gt') {
				$target->{portcmp} = 'range';
				push @tokens, 65535;
			}
			if ($target->{portcmp} eq 'range') {
				my $endport = shift @tokens;
				if ($CiscoACLPortMap->{lc($portstring)}) {
					$portstring = $CiscoACLPortMap->{lc($portstring)};
				}
				if ($CiscoACLPortMap->{lc($endport)}) {
					$endport = $CiscoACLPortMap->{lc($endport)};
				}
				if (!$endport) {
					SetError($error, "Range must have two arguments");
					return undef;
				}
				if (($portstring !~ /^\d+$/) || ($endport !~ /^\d+$/)) {
					SetError($error, sprintf("Bad range: %s - %s", $portstring,
						$endport));
					return undef;
				}
				if (defined($valid_ranges) && $real_portcmp eq 'range') {
				        my $rangeok = 0;

				        foreach my $r (@$valid_ranges) {
					        $rangeok = 1 if ($r->[0] eq $portstring && $r->[1] eq $endport);
				        }

				        unless ($rangeok) {
					        SetError($error, sprintf("Not a valid range: %s - %s",
							 $portstring, $endport));
					        return undef;
				        }
				}
				push @{$target->{port}}, $portstring . "-" . $endport;
			}
		}
	}
	my $icmptype = [];;
	my $tcpestablished;
	while (@tokens) {
		my $keyword = shift @tokens;
		if ($proto eq 'tcp') {
			if ($keyword eq 'established') {
				$tcpestablished=1;
				next;
			}
		}
		if ($proto eq 'icmp') {
			foreach my $itype (split /,/, $keyword) {
				if (!exists($CiscoICMPMap->{$itype})) {
					SetError($error,
						sprintf("ICMP type %s not valid", $itype));
					return undef;
				}
				push @{$icmptype}, $CiscoICMPMap->{$itype};
			}
			next;
		}
		if ($keyword eq 'log') {
			next;
		}
		SetError($error,
			sprintf("%s is not a valid keyword", $keyword));
		return undef;
	}
	my $term = $document->createElement('term');
	$element = $document->createElement('name');
	$term->appendChild($document->createTextNode("\n" . "    "x6));
	$term->appendChild($element);
	$element->appendChild($document->createTextNode(
		$opt->{term_name} || 'NO-NAME'));

	my $fromdoc = $document->createDocumentFragment;
	my $from = $document->createElement('from');
	$fromdoc->appendChild($from);
	#
	# Protocol IP is not special for JunOS
	#
	if ($proto ne "ip") {
		$element = $document->createElement('protocol');
		$element->appendChild($document->createTextNode($proto));
		$from->appendChild($document->createTextNode("\n" . "    "x7));
		$from->appendChild($element);
	}
	if ($source->{addrlist}) {
		foreach my $addr (@{$source->{addrlist}}) {
			my ($xaddr, $xmask) = split m%/%, $addr;
			if (!defined($xmask)) {
				$addr .= "/32";
			}
			$element = $document->createElement('source-address');
			$element->appendChild($document->createTextNode($addr));
			$from->appendChild($document->createTextNode("\n" . "    "x7));
			$from->appendChild($element);
		}
	}
	if ($source->{group}) {
		foreach my $group (@{$source->{group}}) {
			$element = $document->createElement('source-prefix-list');
			$element->appendChild($document->createTextNode($group));
			$from->appendChild($document->createTextNode("\n" . "    "x7));
			$from->appendChild($element);
		}
	}
	if ($source->{port}) {
		foreach my $port (@{$source->{port}}) {
			$element = $document->createElement('source-port');
			$element->appendChild($document->createTextNode($port));
			$from->appendChild($document->createTextNode("\n" . "    "x7));
			$from->appendChild($element);
		}
	}
	if ($dest->{addrlist}) {
		foreach my $addr (@{$dest->{addrlist}}) {
			my ($xaddr, $xmask) = split m%/%, $addr;
			if (!defined($xmask)) {
				$addr .= "/32";
			}
			$element = $document->createElement('destination-address');
			$element->appendChild($document->createTextNode($addr));
			$from->appendChild($document->createTextNode("\n" . "    "x7));
			$from->appendChild($element);
		}
	}
	if ($dest->{group}) {
		foreach my $group (@{$dest->{group}}) {
			$element = $document->createElement('destination-prefix-list');
			$element->appendChild($document->createTextNode($group));
			$from->appendChild($document->createTextNode("\n" . "    "x7));
			$from->appendChild($element);
		}
	}
	if ($dest->{port}) {
		foreach my $port (@{$dest->{port}}) {
			$element = $document->createElement('destination-port');
			$element->appendChild($document->createTextNode($port));
			$from->appendChild($document->createTextNode("\n" . "    "x7));
			$from->appendChild($element);
		}
	}
	if ($tcpestablished) {
		$element = $document->createElement('tcp-established');
		$from->appendChild($document->createTextNode("\n" . "    "x7));
		$from->appendChild($element);
	}
	foreach my $itype (@{$icmptype}) {
		$element = $document->createElement('icmp-type');
		$element->appendChild($document->createTextNode($itype));
		$from->appendChild($document->createTextNode("\n" . "    "x7));
		$from->appendChild($element);
	}
	if ($from->hasChildNodes) {
		$term->appendChild($document->createTextNode("\n" . "    "x6));
		$term->appendChild($fromdoc);
		$from->appendChild($document->createTextNode("\n" . "    "x6));
	}
	$element = $document->createElement('then');
	$element->appendChild($document->createElement($action));
	$term->appendChild($document->createTextNode("\n" . "    "x6));
	$term->appendChild($element);
	$term->appendChild($document->createTextNode("\n" . "    "x5));

	return $term;
}

sub GenerateXMLforACL {
	my $opt = &_options(@_);
	my $filtername;
	if (!($filtername = $opt->{filtername})) {
		SetError($opt->{errors},
			"filtername parameter must be passed to GenerateXMLforACL");
		return undef;
	}

	my $xml = qq {
<configuration>
    <firewall>
        <family>
            <inet>
                <filter>
                    <name> </name>
                </filter>
            </inet>
        </family>
    </firewall>
</configuration> };
	my $parser = new XML::DOM::Parser;
	my $doc = $parser->parsestring($xml);

	my $filter = $doc->getElementsByTagName('filter')->[0];
	$filter->getElementsByTagName('name')->[0]->getFirstChild->setData(
		$filtername);
	$filter->setAttribute('replace', 'replace');
	if ($opt->{prefixxml}) {
		$parser = new XML::DOM::Parser;
		my $pfxdoc = $parser->parsestring($opt->{prefixxml});
		my $pfxfilter = $pfxdoc->getElementsByTagName('filter')->[0]->
			cloneNode(1);
		$pfxfilter->setOwnerDocument($doc);
		$pfxfilter->removeChild(
			$pfxfilter->getElementsByTagName('name', 0)->[0]);
		foreach my $kid ($pfxfilter->getChildNodes) {
			$filter->appendChild($kid);
		}
		$filter->appendChild($doc->createTextNode("\n" . "    "x4));
	}

	#
	# Loop through all of the access list entries and convert them from
	# Cisco ACL format to Juniper firewall terms
	#
	my @entries;
	if ($opt->{prefixtext}) {
		@entries = split /\n/, $opt->{prefixtext};
	}
	if ($opt->{entries}) {
		push @entries, (split /\n/, $opt->{entries});
	}
	if ($opt->{suffixtext}) {
		push @entries, (split /\n/, $opt->{suffixtext});
	}

	foreach my $i (0..$#entries) {
		my @errstr;
		my $term = ConvertCiscoACLLineToJunOS(
			line => $entries[$i],
			term_name => sprintf("%s-%03d", $filtername, $i),
			errors => \@errstr
		);
		if (@errstr) {
			SetError($opt->{errors},
				sprintf("Error processing filter %s", $filtername),
				sprintf("Error processing line: %s", $entries[$i]),
				@errstr);
		}
		next if (!$term);
		$term->setOwnerDocument($doc);
		$filter->appendChild($doc->createTextNode("\n" . "    "x5));
		$filter->appendChild($term);
	}

	#
	# Now append the suffix
	#

	if ($opt->{suffixxml}) {
		$parser = new XML::DOM::Parser;
		my $sfxdoc = $parser->parsestring($opt->{suffixxml});
		my $sfxfilter = $sfxdoc->getElementsByTagName('filter')->[0]->
			cloneNode(1);
		$sfxfilter->setOwnerDocument($doc);
		$sfxfilter->removeChild(
			$sfxfilter->getElementsByTagName('name', 0)->[0]);
		foreach my $kid ($sfxfilter->getChildNodes) {
			$filter->appendChild($kid);
		}
		$filter->appendChild($doc->createTextNode("\n" . "    "x4));
	}
	$filter->appendChild($doc->createTextNode("\n" . "    "x4));
	return $doc;
}

sub SetCiscoFormatACL {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

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

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $res;

	my $acl = $opt->{acl};
	my $filtername = $opt->{name};

	my $xml = qq {
<configuration>
	<firewall>
		<family>
			<inet>
				<filter>
					<name> </name>
				</filter>
			</inet>
		</family>
	</firewall>
</configuration> };
	my $parser = new XML::DOM::Parser;
	my $doc = $parser->parsestring($xml);

	my $filterlist;
	my $acl_text;
	if ($opt->{no_template}) {
		$acl_text = $acl->{aces};
	} else {
		$acl_text = $acl->{full_acl};
	}

	$doc = GenerateXMLforACL(
		errors => $err,
		filtername => $filtername,
		entries => $acl_text
	);

	if (!$doc) {
		return undef;
	}
	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->load_configuration(
			format => 'xml',
			action => 'replace',
			configuration => $doc
		);
	};
	alarm 0;

	if ($@) {
		SetError($err, sprintf("Error setting firewall settings: %s", $@));
		return undef;
	}
	if (!$res) {
		SetError($err, sprintf("Unknown error setting firewall settings"));
		return undef;
	}
	my $jnxerr = $res->getFirstError();
	if ($jnxerr) {
		SetError($err, sprintf("Error setting firewall: %s",
			$jnxerr->{message}));
		return undef;
	};
	$self->{state} = STATE_CONFIG_LOADED;

	return 1;
}

sub GetPortMACs {
	my $self = shift;
	my $opt = &_options(@_);

	my $errors = $opt->{errors};

	my $debug = 1;
	if ($opt->{debug}) {
		$debug = 1;
	}

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $err;

	my $macport = {};
	my $portmac = {};

	my $timeout = time() + ($opt->{timeout} || 0);

	my $device = $self->{device};
	my $jnx = $self->{handle};
	while(1) {
		my $macdata;
		eval {
			local $SIG{ALRM} = sub { die "alarm\n"; };
			alarm $opt->{timeout};

			$macdata = $jnx->get_ethernet_switching_table_information(brief=>1);
		};
		alarm 0;

		if (!ref $macdata) {
			SetError($errors,
				"Unknown error getting MAC table from switch");
			return undef;
		}
		$err = $macdata->getFirstError();
		if ($err) {
			SetError($errors,
				sprintf("Error getting MAC table from switch: %s\n",
				$err->{message}));
			return undef;
		}

		#
		# Pull all of the returned MAC addresses into an array that are in
		# the main switchports
		#

		foreach my $entry
				($macdata->getElementsByTagName('mac-table-entry')) {
			my $port =
				$entry->getElementsByTagName('mac-interfaces')->[0]->
				getFirstChild->getNodeValue;
			# Skip any of the uplink ports
			next if ($port !~ m%^ge-\d/0/%);
			my $addr = $entry->getElementsByTagName('mac-address')->[0]->
				getFirstChild->getNodeValue;
			if (defined($port) && defined($addr)) {
				$addr = mac_aton($addr);
				$portmac->{$port} = $addr;
				$macport->{$addr} = $port;
			}
		}
		last if (time() > $timeout);
		sleep 5;
	}

	return {
		byport => $portmac,
		bymac => $macport
	};
}

sub GetPortVlan {
	my $self = shift;
	my $opt = &_options(@_);
	my $err = $opt->{errors};

    my $port = $opt->{port};

	if (!defined($port)) {
		SetError($err,
			"port parameter must be passed to GetPortVlan");
		return undef;
	}

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $res;

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->get_ethernet_switching_interface_information(
				interface_name => $port . ".0",
				detail => 1
			);
	};
	alarm 0;


	if (!ref($res)) {
		SetError($err, sprintf("Error retrieving port status for port %s",
			$port));
		return undef;
	}

    my $interface = $res->getElementsByTagName('interface')->[0];
    if (!$interface) {
        SetError($err, sprintf("Port %s does not exist", $port));
        return undef;
    }
    my $ifname = $interface->getElementsByTagName('interface-name')->[0]->
        getFirstChild->getNodeValue;
    my $ifstatus;
    $ifstatus = {
        name => $ifname,
        id =>
            $interface->getElementsByTagName('interface-id')->[0]->
            getFirstChild->getNodeValue,
        portMode =>
            $interface->getElementsByTagName('interface-port-mode')->[0]->
            getFirstChild->getNodeValue,
    };
    my $vlan;
    if ($ifstatus->{portMode} eq 'Access') {
        my $vlanInfo =
            $interface->getElementsByTagName('interface-vlan-member-list')->
            [0]->getElementsByTagName('interface-vlan-member')->[0];
        $ifstatus->{vlan} = {
            name => $vlanInfo->getElementsByTagName('interface-vlan-name')->
                [0]->getFirstChild->getNodeValue,
        };
        my $child = $vlanInfo->
            getElementsByTagName('interface-vlan-member-tagid')->[0];
        if ($child) {
            $ifstatus->{vlan}->{id} = $child->getFirstChild->getNodeValue;
        }
        $vlan = $ifstatus->{vlan}->{id} || 'default';
    }
    my $trunking = $ifstatus->{portMode} eq 'Trunk' ? 'on' : 'off';
    return ($trunking, $vlan);
}

sub SetBGPPeerStatus {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	if (!$opt->{bgp_peer}) {
		SetError($err,
			"bgp_peer parameter must be passed to SetBGPPeer");
		return undef;
	}
	if (!$opt->{bgp_peer_group}) {
		SetError($err,
			"bgp_peer_group parameter must be passed to SetBGPPeer");
		return undef;
	}
	my ($peerobj, $bgp_peer);
	if (ref($opt->{bgp_peer})) {
		$peerobj = $opt->{bgp_peer};
		$bgp_peer = $peerobj->addr;
	} else {
		$bgp_peer = $opt->{bgp_peer};
		eval {
			$peerobj = NetAddr::IP->new($bgp_peer);
		};
		if (!$peerobj) {
			SetError($err,
				"invalid bgp_peer parameter to SetBGPPeer");
			return undef;
		}
	}

	if (!$opt->{state}) {
		SetError($err, "state parameter must be passed to SetBGPPeer");
		return undef;
	}
	my $state = $opt->{state};
	if ($state ne 'up' && $state ne 'down' && $state ne 'delete') {
		SetError($err, "state parameter must be either 'up', 'down', or 'delete'");
		return undef;
	}

	#
	# Get current BGP status for peer
	#
	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $parser = new XML::DOM::Parser;
	my $confdoc;
	my $res;

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->get_bgp_group_information(
			group_name => $opt->{bgp_peer_group}
		);
	};
	alarm 0;

	if (!ref($res)) {
		SetError($err, "Error retrieving BGP information");
		return undef;
	}

	my $bgpgroups = $res->getElementsByTagName('bgp-group');
    if (!$bgpgroups) {
        SetError($err, "BGP group is not configured for this switch");
        return undef;
    }

	# From Junos OS release 18.4 onwards, show bgp group group-name does an
	# exact match and displays groups with names matching exactly with that
	# of the specified group-name. For all Junos OS releases preceding 18.4,
	# the implemenation was performed using the prefix matches (example: if
	# there are two groups grp1, grp2 and the CLI command show bgp group grp
	# was issued, then both grp1, grp2 were displayed).
    my $num_bgp_groups = $bgpgroups->getLength;
    my $peerfound;
    for (my $i = 0; $i < $num_bgp_groups; $i++) {
        my $node = $bgpgroups->item($i);
        my $bgp_group_name = $node->getElementsByTagName('name')->item(0)->getFirstChild->getNodeValue;
        next if ($bgp_group_name ne $opt->{bgp_peer_group});
        my $bgppeers = $node->getElementsByTagName('peer-address');
        foreach my $peercrap (@$bgppeers) {
            my $peer = (split '\+', $peercrap->getFirstChild->getNodeValue)[0];
            if ($peer && $peer eq $bgp_peer) {
                $peerfound = 1;
                last;
            }
        }
        last if $peerfound;
    }

	# See if we need to do anything

	if ($peerfound && $state eq 'up') {
		return 1;
	}
	if (!$peerfound && ($state eq 'down' || $state eq 'delete')) {
		return 1;
	}

	if ($state eq 'down' || $state eq 'delete') {
		#
		# Remove the peer from the group
		#

		my $xml = sprintf(q{
	<configuration>
		<protocols>
			<bgp>
				<group>
					<name>%s</name>
					<neighbor delete="delete">
						<name>%s</name>
					</neighbor>
				</group>
			</bgp>
		</protocols>
	</configuration>
			}, $opt->{bgp_peer_group}, $bgp_peer);
		my $parser = new XML::DOM::Parser;
		my $doc = $parser->parsestring($xml);
		if (!$doc) {
			SetError($err,
				"Bad XML string removing BGP peer.  This should not happen");
			return undef;
		}
		eval {
			local $SIG{ALRM} = sub { die "alarm\n"; };
			alarm $opt->{timeout};

			$res = $jnx->load_configuration(
				format => 'xml',
				action => 'replace',
				configuration => $doc
			);
		};
		alarm 0;

		$self->{state} = STATE_CONFIG_LOADED;
		if ($@) {
			SetError($err,
				sprintf("Error removing BGP peer %s: %s", $bgp_peer, $@));
			return undef;
		}
		if (!$res) {
			SetError($err,
				sprintf("Unknown error removing BGP peer %s", $bgp_peer));
			return undef;
		}
		my $xmlerr = $res->getFirstError();
		if ($xmlerr) {
			SetError($err, sprintf("Error removing BGP peer %s: %s",
				$bgp_peer, $xmlerr->{message}));
			return undef;
		}
	} else {
		#
		# Validate that the peer belongs on this host
		#

		eval {
			local $SIG{ALRM} = sub { die "alarm\n"; };
			alarm $opt->{timeout};

			$res = $jnx->get_route_information(
				protocol => 'direct'
			);
		};
		alarm 0;

		if (!ref($res)) {
			SetError($err, "Error retrieving routing information");
			return undef;
		}
		my $routelist = $res->getElementsByTagName('rt');
		if (!$routelist) {
			SetError($err, "No direct routes for this switch.  This should never happen");
			return undef;
		}
		my $networkfound;
		ROUTELOOP: foreach my $route (@$routelist) {
			#
			# Skip this network if it isn't attached to a vlan interface.
			# We only want to allow peers on those networks to be managed
			#
			my $nexthop = $route->getElementsByTagName('via');
			next if (!$nexthop ||
				$nexthop->[0]->getFirstChild->getNodeValue !~ /^(vlan)|(irb)/);

			foreach my $netblock (
					$route->getElementsByTagName('rt-destination')) {
					$netblock->getFirstChild->getNodeValue;
				if (NetAddr::IP->new(
							$netblock->getFirstChild->getNodeValue
						)->contains($peerobj)) {
					$networkfound = 1;
					last ROUTELOOP;
				}
			}
		}
		if (!$networkfound) {
			SetError($err,
				sprintf("%s is not a valid address on switch %s",
					$bgp_peer,
					$device->{hostname}));
			return undef;
		}

		my $xml = sprintf(q{
	<configuration>
		<protocols>
			<bgp>
				<group>
					<name>%s</name>
					<neighbor>
						<name>%s</name>
					</neighbor>
				</group>
			</bgp>
		</protocols>
	</configuration>
			}, $opt->{bgp_peer_group}, $bgp_peer);
		my $parser = new XML::DOM::Parser;
		my $doc = $parser->parsestring($xml);
		if (!$doc) {
			SetError($err,
				"Bad XML string removing BGP peer.  This should not happen");
			return undef;
		}
		eval {
			local $SIG{ALRM} = sub { die "alarm\n"; };
			alarm $opt->{timeout};

			$res = $jnx->load_configuration(
				format => 'xml',
				action => 'merge',
				configuration => $doc
			);
		};
		alarm 0;

		$self->{state} = STATE_CONFIG_LOADED;
		if ($@) {
			SetError($err,
				sprintf("Error removing BGP peer %s: %s", $bgp_peer, $@));
			return undef;
		}
		if (!$res) {
			SetError($err,
				sprintf("Unknown error removing BGP peer %s", $bgp_peer));
			return undef;
		}
		my $xmlerr = $res->getFirstError();
		if ($xmlerr) {
			SetError($err, sprintf("Error removing BGP peer %s: %s",
				$bgp_peer, $xmlerr->{message}));
			return undef;
		}
	}
	return 1;
}

# This function will return the IP Version of a BGP group (4 or 6).
# This is done by looking at the IP Version of the first peer found in the group
# If it cannot be determined (no peer in group), we return 1.
# In case of error, returns undef.
sub GetBGPGroupIPFamily {
    my $self = shift;
    my $opt = &_options(@_);

    my $err = $opt->{err};

    if( !$opt->{timeout}) {
        $opt->{timeout} = 30;
    }

    if( !$opt->{bgp_peer_group}) {
        SetError($err,
            "bgp_peer_group parameter must be passed to GetBGPGroupIPFamily"
        );
        return undef;
    }

    my $device = $self->{device};
    my $debug = 0;
    if ($opt->{debug}) {
        $debug = 1;
    }

    my $jnx;
    if (!($jnx = $self->{handle})) {
        SetError($err,
            sprintf("No connection to device %s", $device->{hostname})
        );
        return undef;
    }

    my $res;

    eval {
        local $SIG{ALRM} = sub { die "alarm\n"; };
        alarm $opt->{timeout};

        $res = $jnx->get_bgp_group_information(
            group_name => $opt->{bgp_peer_group}
        );
    };
    alarm 0;
    if (!ref($res)) {
        SetError($err,
            sprintf("Error retrieving BGP information for BGP group %s on switch %s",
                $opt->{bgp_peer_group},
                $device->{hostname}
            )
        );
        return undef;
    }


    my $bgpgroups = $res->getElementsByTagName('bgp-group');
    if (!$bgpgroups) {
        SetError($err, "Unknown error in getElementsByTagName('bgp-group')");
        return undef;
    }
    my $num_bgp_groups = $bgpgroups->getLength;


	# There is an issue : if a BGP group has no peer, the `bgp show group`
	# command (which is the Junos command ran by get_bgp_group_information) returns
	# nothing, like if the BGP group was not existing !
	# --> This behavior is at least ran into when, on a existing BGP GROUP, you
	#     remove the last peer.
	# --> So, instead of returning undef, we will return 1.
    if ($num_bgp_groups == 0) {
		SetError($err,
            sprintf("Could not find BGP group %s on switch %s. Group might exist however. Returning 1",
                $opt->{bgp_peer_group},
                $device->{hostname}
            )
        );
        return 1;
    }

    my $bgpgroup_found;
    my $first_peer_ipaddr;
    # See remark about Junos OS < 18.4 in the function SetBGPPeerStatus above.
	# it explains why we have to use a loop here.
    for (my $i = 0 ; $i < $num_bgp_groups; $i++) {
        my $node = $bgpgroups->item($i);
        my $bgp_group_name = $node->getElementsByTagName('name')->item(0)->getFirstChild->getNodeValue;

        next if ($bgp_group_name ne $opt->{bgp_peer_group});
		$bgpgroup_found = 1;

        my $first_peer = $node->getElementsByTagName('peer-address')->item(0);
        if ($first_peer) {
            $first_peer_ipaddr = NetAddr::IP->new( (split '\+', $first_peer->getFirstChild->getNodeValue)[0]);
        }
    }

	# see comment above : we might not find the BGP group we are looking if it has no peer.
	# let's not return an error.
    if (!$bgpgroup_found) {
		SetError($err,
            sprintf("Could not find BGP group %s on switch %s. Group might exist however. Returning 1",
                $opt->{bgp_peer_group},
                $device->{hostname}
            )
        );
		return 1;
    }

	# Can we run into this case despite the bug descrive above ? not sure.
	# Anyway, it would mean we have foudn the BGP group but it has no peer, so we return 1.
    if (!$first_peer_ipaddr) {
        SetError($err,
            sprintf("Could not find a peer on BGP group %s on switch %s. Cannot determine version yet.",
                $opt->{bgp_peer_group},
                $device->{hostname}
            )
        );
        return 1;
    }

    return $first_peer_ipaddr->version();
}

sub RemoveVLAN {
    my $self = shift;
    my $opt = &_options(@_);

    my $err = $opt->{errors};

    if (!$opt->{encapsulation_tag}) {
        SetError($err,
            "encapsulation_tag parameter must be passed to RemoveVLAN");
        return undef;
    }
	my $encapsulation_tag = $opt->{encapsulation_tag};

    if (
        $encapsulation_tag !~ /^[0-9]+$/ ||
        $encapsulation_tag < 1 ||
        $encapsulation_tag > 4094
    ) {
        SetError($err,
            "encapsulation_tag parameter must be a valid VLAN number for RemoveVLAN");
        return undef;
    }

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $vlans = $self->GetVLANs(
		timeout => $opt->{timeout},
		errors => $err
	);

	if (!defined($vlans)) {
		return undef;
	}

	if (!exists($vlans->{ids}->{$encapsulation_tag})) {
		return undef;
	}
	my $vlan = $vlans->{ids}->{$encapsulation_tag};

	my $conf = "<configuration>\n";
	$conf .= sprintf(q {
			<vlans>
				<vlan delete="delete">
					<vlan-id>%s</vlan-id>
				</vlan>
			</vlans>
		},
			$vlan->{name}
	);

	if ($vlan->{l3_interface}) {
		my $iface = $self->GetInterfaceConfig(
			timeout => $opt->{timeout},
			interface_name => $vlan->{l3_interface}
		);
		if ($iface) {
			$conf .= sprintf(q{
				<interfaces>
					<interface>
						<name>irb</name>
						<unit delete="delete">
							<name>%s</name>
						</unit>
					</interface>
				</interfaces>
				},
					$vlan->{l3_interface}
			);
			if (%{$iface->{filter}}) {
				$conf .= q{
					<firewall>
						<family>
							<inet>
				};
				foreach my $filter (keys %{$iface->{filter}}) {
					$conf .= sprintf(q{
								<filter delete="delete">
									<name>%s</name>
								</filter>
					},
						$iface->{filter}->{$filter});
				}
				$conf .= q{
							</inet>
						</family>
					</firewall>
				};
			}
		}
	}
	$conf .= "</configuration>\n";
}

sub GetInterfaceConfig {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	if (!$opt->{interface_name}) {
		GetError($err,
			"interface_name parameter must be passed to GetInterfaceConfig");
		return undef;
	}

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my ($iface, $unit) = split /\./, $opt->{interface_name};
	my $xml = qq {
	<configuration>
		<interfaces>
			<interface>
				<name> </name>
			</interface>
		</interfaces>
	</configuration>};
	my $res;
	my $parser = new XML::DOM::Parser;
	my $confdoc = $parser->parsestring($xml);
	$confdoc = $parser->parsestring($xml);
	$confdoc->getElementsByTagName('name')->[0]->getFirstChild->
		setData($iface);

	if ($unit) {
		my $newelement = $confdoc->createElement('unit');
		my $nameelement = $confdoc->createElement('name');
		$nameelement->appendChild($confdoc->createTextNode($unit));
		$newelement->appendChild($nameelement);
		$confdoc->getElementsByTagName('interface')->[0]->
			appendChild($newelement);
	}

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->get_configuration(configuration => $confdoc);
	};
	alarm 0;

	if (!ref($res)) {
		SetError($err, sprintf("Error retrieving interface config for %s",
			$opt->{interface_name}));
		return undef;
	}

	my $iface_info = {};
	foreach my $ae ($res->getElementsByTagName('address')) {
		my $vrrp = undef;
		my $address =
			$ae->getElementsByTagName('name')->[0]
				->getFirstChild->getNodeValue;
		my $vrrp_element = $ae->getElementsByTagName('vrrp-group')->[0];
		if ($vrrp_element) {
			$vrrp = $vrrp_element->getElementsByTagName('name')->[0]
				->getFirstChild->getNodeValue;
		};
		$iface_info->{addresses}->{$address} = { "vrrp-group" => $vrrp };
		if (defined($vrrp)) {
			$iface_info->{"vrrp-groups"}->{$vrrp} = { "addresses" => $address };
		}
	}
	my $filter = $res->getElementsByTagName('filter');
	if (@$filter) {
		foreach my $f ($filter->[0]->getChildNodes) {
			my $nt = $f->getNodeType;
			next if ($nt == TEXT_NODE);
			my $filtertype = $f->getNodeName;
			my $filtername = $f->getElementsByTagName('filter-name')->[0];
			if (ref($filtername)) {
				$iface_info->{filter}->{$filtertype} =
					$filtername->getFirstChild->getNodeValue;
			}
		}
	}
	return $iface_info;
}

sub GetVLANs {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	my $device = $self->{device};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	#
	# <get-vlan-information> doesn't show irb interface mappings on the
	# 9200s, because Juniper sucks
	#

	my $xml = qq {
	<configuration>
		<vlans/>
	</configuration>};
	my $parser = new XML::DOM::Parser;
	my$confdoc = $parser->parsestring($xml);

	my $res;
	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$res = $jnx->get_configuration(configuration => $confdoc);
	};
	alarm 0;

	if (!ref($res)) {
		SetError($err, "Error retrieving VLAN config");
		return undef;
	}

	my $vlans = {
		names => {},
		ids => {},
		interfaces => {}
	};
	foreach my $vlan ($res->getElementsByTagName('vlan')) {
		my $name = $vlan->getElementsByTagName('name')->[0]
			->getFirstChild->getNodeValue;
		my $v = {
			name => $name
		};
		$vlans->{names}->{$name} = $v;
		my $id = $vlan->getElementsByTagName('vlan-id');
		if ($id && $id->[0]) {
			$v->{id} = $id->[0]->getFirstChild->getNodeValue;
			$vlans->{ids}->{$v->{id}} = $v;
		}
		my $iface = $vlan->getElementsByTagName('l3-interface');
		if ($iface && $iface->[0]) {
			$iface = $iface->[0]->getFirstChild->getNodeValue;
			$iface =~ s/ .*//;
			$v->{l3_interface} = $iface;
			$vlans->{interfaces}->{$iface} = $v;
		}
	}
	return $vlans;
}

sub GetIPAddressInformation {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	my $ifacexml;

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$ifacexml = $jnx->get_interface_information;

	};
	alarm 0;

	if (!ref($ifacexml)) {
		SetError($err, "Error retrieving interface config");
		return undef;
	}

	my $vrrpxml;
	my $vrrp_info = {};

	my $response;

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		($vrrpxml, $response) = $jnx->request('<rpc><get-vrrp-information/></rpc>');

	};
	alarm 0;

	if (ref($vrrpxml)) {
		foreach my $iface ($vrrpxml->getElementsByTagName('vrrp-interface')) {
			my $ifacename = $iface->getElementsByTagName('interface')->[0]->
				getFirstChild->getNodeValue;
			if (!exists($vrrp_info->{$ifacename})) {
				$vrrp_info->{$ifacename} = [];
			}
			push @{$vrrp_info->{$ifacename}},
				{
					group =>
						$iface->getElementsByTagName('group')->[0]->
						getFirstChild->getNodeValue,
					address =>
						NetAddr::IP->new($iface->
							getElementsByTagName('virtual-ip-address')->[0]->
							getFirstChild->getNodeValue)
				};
		}
	}

	my $linklocal = NetAddr::IP->new('fe80::/7');
	my $iface_info;
	foreach my $iface ($ifacexml->getElementsByTagName('logical-interface')) {
		my $self = {};

		my $ifacename = $iface->getElementsByTagName('name')->[0]->
			getFirstChild->getNodeValue;

		foreach my $afxml ($iface->getElementsByTagName('address-family')) {
			my $af = $afxml->getElementsByTagName('address-family-name')->[0]->
				getFirstChild->getNodeValue;
			next if !$af;
			if (exists($vrrp_info->{$ifacename})) {
				$self->{vrrp} = $vrrp_info->{$ifacename};
			}
			if ($af eq 'inet') {
				my $ipv4 = [
					map {
						my $netxml =
							$_->getElementsByTagName('ifa-destination');
						my $net;
						if (@$netxml) {
							$net = NetAddr::IP->new(
								$netxml->[0]->getFirstChild->getNodeValue)
						} else {
							$net = NetAddr::IP->new('0.0.0.0/32');
						}

						my $addr = NetAddr::IP->new(
							$_->getElementsByTagName('ifa-local')->[0]
								->getFirstChild->getNodeValue, $net->masklen);
						# Skip anything that's a VRRP service address
						if (
							$net->masklen > 8 &&
							!(grep { $addr->addr() eq $_->{address}->addr() }
								@{$vrrp_info->{$ifacename}})
						) {
							$addr
						} else {
							();
						}
					} $afxml->getElementsByTagName('interface-address')
				];
				$self->{ipv4} = $ipv4 if @$ipv4;
			}
			if ($af eq 'inet6') {
				my $ipv6 = [];
				foreach my $addrxml
						($afxml->getElementsByTagName('interface-address')) {

					my $netxml =
						$addrxml->getElementsByTagName('ifa-destination');
					next if !@$netxml;
					my $net;
					$net = NetAddr::IP->new(
						$netxml->[0]->getFirstChild->getNodeValue);
					next if $net->within($linklocal);

					my $addr = NetAddr::IP->new(
						$addrxml->getElementsByTagName('ifa-local')->[0]
							->getFirstChild->getNodeValue, $net->masklen);
					# Skip anything that's a VRRP service address or
					# link local address
					next if (
						grep { $_->{address} eq $addr->addr() }
							@{$vrrp_info->{$ifacename}}
					);

					push @$ipv6, $addr;
				}
				$self->{ipv6} = $ipv6 if @$ipv6;
			}

		}
		if (%$self) {
			$iface_info->{$ifacename} = $self;
		}
	}

	return $iface_info;
}


sub GetLLDPInformation {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}


	my $chassis_info = $self->GetChassisInfo;

	my $lldp_info = {};
	$lldp_info->{chassisId} = $chassis_info->{chassisId};
	my $lldpxml;

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$lldpxml = $jnx->get_lldp_neighbors_information;
	};
	alarm 0;

	if (!ref($lldpxml)) {
		SetError($err, "Error retrieving interface config");
		return undef;
	}

	if (ref($lldpxml)) {
		foreach my $iface (
			$lldpxml->getElementsByTagName('lldp-neighbor-information')
		) {
			#
			# We only care about things that have a remote system name set
			#
			my $rsys = $iface->getElementsByTagName('lldp-remote-system-name');
			next if (!@$rsys);
			#
			# Also skip anything that uses MAC address for the remote port ID
			#
			my ($idtype, $local_int_name, $rem_int_name, $rem_sys_name);
			eval {
				$idtype = $iface->
					getElementsByTagName('lldp-remote-port-id-subtype')->[0]->
					getFirstChild->getNodeValue;
			};

			eval {
				$local_int_name =
					$iface->getElementsByTagName('lldp-local-port-id')->[0]->
					getFirstChild->getNodeValue;
			};
			if (!defined($local_int_name)) {
				$local_int_name =
					$iface->getElementsByTagName('lldp-local-interface')->[0]->
					getFirstChild->getNodeValue;
			}

			eval {
				$rem_sys_name =
					$iface->getElementsByTagName('lldp-remote-system-name')->
					[0]->getFirstChild->getNodeValue;
			};

			if (!$idtype) {
				next;
				#
				# Fuck you, Juniper
				#
#				$rem_int_name = $iface->
#					getElementsByTagName('lldp-remote-port-description')->[0]->
#					getFirstChild->getNodeValue;
			} elsif ($idtype eq 'Interface name') {
				$rem_int_name =
					$iface->getElementsByTagName('lldp-remote-port-id')->[0]->
					getFirstChild->getNodeValue;

			}

			next if (!$rem_int_name);
			my $info = {
				interface_name => $local_int_name,
				remote_system_name => $rem_sys_name,
				remote_interface_name => $rem_int_name
			};

			if (exists($chassis_info->{ports}->{$local_int_name})) {
				$info->{media_type} =
					$chassis_info->{ports}->{$local_int_name}->{media_type};
				$info->{module_type} =
					$chassis_info->{ports}->{$local_int_name}->{module_type};
			}
			$lldp_info->{$local_int_name} = $info;
		}
	}

#
#	my $iface_info;
#	foreach my $iface ($ifacexml->getElementsByTagName('logical-interface')) {
#		my $self = {};
#
#		my $ifacename = $iface->getElementsByTagName('name')->[0]->
#			getFirstChild->getNodeValue;
#
#		foreach my $afxml ($iface->getElementsByTagName('address-family')) {
#			my $af = $afxml->getElementsByTagName('address-family-name')->[0]->
#				getFirstChild->getNodeValue;
#			next if !$af;
#			if (exists($vrrp_info->{$ifacename})) {
#				$self->{vrrp} = $vrrp_info->{$ifacename};
#			}
#			if ($af eq 'inet') {
#				my $ipv4 = [
#					map {
#						my $netxml =
#							$_->getElementsByTagName('ifa-destination');
#						my $net;
#						if (@$netxml) {
#							$net = NetAddr::IP->new(
#								$netxml->[0]->getFirstChild->getNodeValue)
#						} else {
#							$net = NetAddr::IP->new('0.0.0.0/32');
#						}
#						my $addr = NetAddr::IP->new(
#							$_->getElementsByTagName('ifa-local')->[0]
#								->getFirstChild->getNodeValue, $net->masklen);
#						# Skip anything that's a VRRP service address
#						if (!(grep { $addr->addr() eq $_->{address}->addr() }
#							@{$vrrp_info->{$ifacename}})) {
#							$addr
#						} else {
#							();
#						}
#					} $afxml->getElementsByTagName('interface-address')
#				];
#				$self->{ipv4} = $ipv4 if @$ipv4;
#			}
#			my $linklocal = NetAddr::IP->new('fe80::/64');
#			if ($af eq 'inet6') {
#				my $ipv6 = [];
#				foreach my $addrxml
#						($afxml->getElementsByTagName('interface-address')) {
#
#					my $netxml =
#						$addrxml->getElementsByTagName('ifa-destination');
#					next if !@$netxml;
#					my $net;
#					$net = NetAddr::IP->new(
#						$netxml->[0]->getFirstChild->getNodeValue);
#					next if $net eq $linklocal;
#
#					my $addr = NetAddr::IP->new(
#						$addrxml->getElementsByTagName('ifa-local')->[0]
#							->getFirstChild->getNodeValue, $net->masklen);
#					# Skip anything that's a VRRP service address or
#					# link local address
#					next if (
#						grep { $_->{address} eq $addr->addr() }
#							@{$vrrp_info->{$ifacename}}
#					);
#
#					push @$ipv6, $addr;
#				}
#				$self->{ipv6} = $ipv6 if @$ipv6;
#			}
#
#		}
#		if (%$self) {
#			$iface_info->{$ifacename} = $self;
#		}
#	}

	return $lldp_info;
}

my $iface_map = {
    '10/100/1000' => {
        module_type => '1000BaseTEthernet',
        media_type => '1000BaseTEthernet',
        slot_prefix => 'ge-',
    },
    'SFP-T' => {
        module_type => '1GSFPEthernet',
        media_type => '1000BaseTEthernet',
        slot_prefix => 'ge-',
    },
    'SFP-LX10' => {
        module_type => '1GSFPEthernet',
        media_type => '1GLCEthernet',
        slot_prefix => 'ge-',
    },
    'SFP+-10G-SR' => {
        module_type => '10GSFP+Ethernet',
        media_type => '10GLCEthernet',
        slot_prefix => 'xe-',
    },
    'SFP+-10G-LR' => {
        module_type => '10GSFP+Ethernet',
        media_type => '10GLCEthernet',
        slot_prefix => 'xe-',
    },
    'SFP+-10G-LR' => {
        module_type => '10GSFP+Ethernet',
        media_type => '10GLCEthernet',
        slot_prefix => 'xe-',
    },
	'SFP+-10G-CU1M' => {
        module_type => '10GSFP+Ethernet',
        media_type => '10GSFPCuEthernet',
        slot_prefix => 'xe-',
	},
	'QSFP28-100G-CDWM4-FEC' => {
        module_type => '100GQSFP28Ethernet',
        media_type => '100GCDWM4Ethernet',
        slot_prefix => 'et-',
	},
	'QSFP+-40G-SR4' => {
        module_type => '40GQSFP+Ethernet',
        media_type => '40GMPOEthernet',
        slot_prefix => 'xe-',
	},
	'QSFP+-4X10G-SR' => {
        module_type => '40GQSFP+Ethernet',
        media_type => '10GLCEthernet',
        slot_prefix => 'xe-',
	},
};

sub GetChassisInfo {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}
	my $chassisxml;

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$chassisxml = $jnx->get_chassis_inventory();

	};
	alarm 0;

	if (!ref($chassisxml)) {
		SetError($err, "Error retrieving chassis inventory");
		return undef;
	}

	my $port_inventory;

	my $members = {};
	my $h;

	foreach my $member ($chassisxml->getElementsByTagName('chassis-module')) {
		my $modname = $member->getElementsByTagName('name', 0)->[0]->
			getFirstChild->getNodeValue;
		my $modslot;
		($modslot) = $modname =~ /^FPC (\d+)/;
		next if (!defined($modslot));

		my $serial;
		$h = $member->getElementsByTagName('serial-number', 0);
		if (@$h) {
			$serial = $h->[0]->getFirstChild->getNodeValue;
		}
		my $model;
		$h = $member->getElementsByTagName('model-number', 0);
		if (@$h) {
			$model = $h->[0]->getFirstChild->getNodeValue;
		}
		my $description;
		$h = $member->getElementsByTagName('description', 0);
		if (@$h) {
			$description = $h->[0]->getFirstChild->getNodeValue;
		}

		my $modinfo = {
			slot => $modslot,
			serial => $serial,
			model => uc($model || $description),
			description => $description,
			modules => {}
		};
		$members->{$modslot} = $modinfo;

		foreach my $submod (
			$member->getElementsByTagName('chassis-sub-module')
		) {
			my $submodname = $submod->getElementsByTagName('name', 0)->[0]->
				getFirstChild->getNodeValue;
			my $submodslot;
			($submodslot) = $submodname =~ /^PIC (\d+)/;
			next if (!defined($submodslot));
			my $slot_template = $modslot . '/' . $submodslot . '/';

			$h = $submod->getElementsByTagName('serial-number', 0);
			my $serial;
			if (@$h) {
				$serial = $h->[0]->getFirstChild->getNodeValue;
			}
			my $model;
			$h = $submod->getElementsByTagName('model-number', 0);
			if (@$h) {
				$model = $h->[0]->getFirstChild->getNodeValue;
			}
			my $description;
			$h = $submod->getElementsByTagName('description', 0);
			if (@$h) {
				$description = $h->[0]->getFirstChild->getNodeValue;
			}
			my $submodinfo = {
				slot => $submodslot,
				name => $slot_template . $submodslot,
				serial => $serial,
				model => $model,
				description => $description,
				modules => {}
			};
			$modinfo->{modules}->{$submodslot} = $submodinfo;

			#
			# Handle some built-in types
			#
			my $portcount;

			if (($portcount) = $description =~ qr{(\d+)x 10/100/1000 Base-T}) {
				foreach my $p (0 .. $portcount ) {
					$port_inventory->{$slot_template . $p} = {
						name => 'ge-' . $slot_template . $p,
						module_type => '1000BaseTEthernet',
						media_type => '1000BaseTEthernet'
					};
				}
				next;
			}
			foreach my $ssmod (
				$submod->getElementsByTagName('chassis-sub-sub-module')
			) {
				my $ssmodname = $ssmod->getElementsByTagName('name', 0)->[0]->
					getFirstChild->getNodeValue;
				my $ssmodslot;
				($ssmodslot) = $ssmodname =~ /^Xcvr (\d+)/;
				next if (!defined($ssmodslot));

				$h = $ssmod->getElementsByTagName('serial-number', 0);
				my $serial;
				if (@$h) {
					$serial = $h->[0]->getFirstChild->getNodeValue;
				}
				my $model;
				$h = $ssmod->getElementsByTagName('part-number', 0);
				if (@$h) {
					$model = $h->[0]->getFirstChild->getNodeValue;
				}
				my $description;
				$h = $ssmod->getElementsByTagName('description', 0);
				if (@$h) {
					$description = $h->[0]->getFirstChild->getNodeValue;
				}

				my $ssmodinfo = {
					slot => $ssmodslot,
					serial => $serial,
					model => $model
				};

				if (defined($description) &&
					exists($iface_map->{$description}))
				{
					$ssmodinfo->{media_type} = $iface_map->{$description}->
						{media_type};
					$ssmodinfo->{module_type} = $iface_map->{$description}->
						{module_type};
					$ssmodinfo->{name} = $iface_map->{$description}->
						{slot_prefix} . $slot_template . $ssmodslot;
				} else {
					next if $description eq 'UNKNOWN';
					printf STDERR "No media interface mapping for %s\n",
						$description;
					exit 1;
				}

				$port_inventory->{$ssmodinfo->{name}} = $ssmodinfo;
				$submodinfo->{modules}->{$ssmodslot} = $ssmodinfo;
			}
		}
	}

	my $chassis = $chassisxml->getElementsByTagName('chassis')->[0];
	my $inventory = {
		manufacturer => 'Juniper Networks',
		model => $chassis->getElementsByTagName('description', 0)->[0]->
			getFirstChild->getNodeValue,
		serial => $chassis->getElementsByTagName('serial-number', 0)->[0]->
			getFirstChild->getNodeValue,
		modules => $members
	};

	if ($inventory->{model} =~ /\[.+\]/) {
		$inventory->{model} =~ s/.*\[([^\]]+)\].*/$1/;
	}

	if ($inventory->{model} eq 'Virtual Chassis') {
		$inventory->{model} = 'Juniper EX4xxx virtual chassis';
	}

	$inventory->{ports} = $port_inventory;

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$chassisxml = $jnx->get_lldp_local_info();
	};
	alarm 0;

	my $chassisid;
	eval { $chassisid =
		$chassisxml->getElementsByTagName('lldp-local-chassis-id')
		->[0]->getFirstChild->getNodeValue;
	};
	$chassisid = Net::MAC->new(mac => $chassisid,
		base => 16, bit_group => 8, delimiter => ':')->as_Sun();
	$inventory->{lldp_chassis_id} = $chassisid;
	return $inventory;
}


sub GetSimpleTrafficCounterInfo {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{timeout}) {
		$opt->{timeout} = 30;
	}

	my $device = $self->{device};

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my $jnx;
	if (!($jnx = $self->{handle})) {
		SetError($err,
			sprintf("No connection to device %s", $device->{hostname}));
		return undef;
	}

	##
	## Juniper traffic counters are completely stupid.  If a single filter is
	## applied to an interface, the counter shows up under the filter name.
	## If a filter list is applied, the counter shows up under a
	## constructed filter named 'iface_name-i' or 'iface_name-o' for
	## input and output filters, respectively, with a counter name that
	## also has the constructed filter name appended.
	##
	my $firewallxml;

	eval {
		local $SIG{ALRM} = sub { die "alarm\n"; };
		alarm $opt->{timeout};

		$firewallxml = $jnx->get_firewall_information();

	};
	alarm 0;

	if (!ref($firewallxml)) {
		SetError($err, "Error retrieving firewall counter information");
		return undef;
	}

	my $counters = {};

	##
	## Loop through all of the firewall filters and pull out the name.
	## Pull out all of the counts and aggregate them, removing any trailing
	## '-iface_name-o' or '-iface_name-i', where 'iface_name-{o,i{' is the name
	## of the firewall filter
	##
	my $members = {};
	my $h;

	foreach my $filter ($firewallxml->getElementsByTagName('filter-information')) {
		my $filtername = $filter->getElementsByTagName('filter-name', 0)->[0]
			->getFirstChild->getNodeValue;
		foreach my $counter ($filter->getElementsByTagName('counter')) {
#			print $counter->toString;
			my $counter_name = $counter->getElementsByTagName('counter-name', 0)
				->[0]->getFirstChild->getNodeValue;
			my $packet_count = $counter->getElementsByTagName('packet-count', 0)
				->[0]->getFirstChild->getNodeValue;
			my $byte_count = $counter->getElementsByTagName('byte-count', 0)
				->[0]->getFirstChild->getNodeValue;

			$counter_name =~ s/-${filtername}$//;

			if (!exists($counters->{$counter_name})) {
				$counters->{$counter_name} = {
					bytes => $byte_count,
					packets => $packet_count
				};
			} else {
				$counters->{$counter_name}->{bytes} += $byte_count;
				$counters->{$counter_name}->{packets} += $packet_count;
			}
		}
	}

	return $counters;
}

1;
