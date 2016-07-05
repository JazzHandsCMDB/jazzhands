package JazzHands::NetDev::Mgmt::__devtype::juniper;

use strict;
use warnings;
use Data::Dumper;
use Socket;
use	XML::DOM;
use JazzHands::Common::Util qw(_options);
use JazzHands::Common::Error qw(:all);
use NetAddr::IP qw(:lower);

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

	my $jnx = new JUNOS::Device(
		access => 'ssl',
		login => $opt->{credentials}->{username},
		password => $opt->{credentials}->{password},
		hostname => $hostname
	);
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

	if (!$self->{handle}) {
		return;
	}

	my $hostname = $self->{device}->{hostname};

	my $rc = 1;
	my $jnx = $self->{handle};
	my $res = $jnx->commit_configuration();
	my $jerr = $res->getFirstError();
	if ($jerr) {
		SetError($err,
			sprintf("%s: commit error: %s", $hostname, $jerr->{message}));
		SetError($opt->{errbyhost}->{$hostname},
			sprintf("commit error: %s", $jerr->{message}));
		$rc = 0;
	} else {
		$self->{connection_cache}->{$hostname}->{state} = STATE_LOCKED;
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

	my $hostname = $self->{device}->{hostname};

	my $jnx = $self->{handle};

	my $state = $self->{state};
	if ($state >= STATE_CONFIG_LOADED) {
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
	undef %$self;
	1;
}

sub SetPortVLAN {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};
	if (!$opt->{ports}) {
		SetError($err, "ports parameter must be passed to SetJuniperPortVLAN");
		return undef;
	}
	if (!$opt->{vlan}) {
		SetError($err, "vlan parameter must be passed to SetJuniperPortVLAN");
		return undef;
	}
	if ($opt->{vlan} ne 'trunk' && $opt->{vlan} !~ /^\d+$/) {
		SetError($err, "vlan parameter must be a vlan number or 'trunk'");
		return undef;
	}
	my $device = $self->{device};

	my $native_vlan = $opt->{native_vlan} || 100;

	my $debug = 0;
	if ($opt->{debug}) {
		$debug = 1;
	}

	my ($trunk, $vlan);
	if ($opt->{vlan} eq 'trunk') {
		$trunk = 1;
	} else {
		$vlan = $opt->{vlan}
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
	
	$res = $jnx->get_vlan_information(
		brief => 1
	);
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
		$Vlans{byname}->{$vlstatus->{name}} = $vlstatus;
		$Vlans{byid}->{$vlstatus->{id}} = $vlstatus;
	}

	foreach my $port (@$ports) {

		$res = $jnx->get_ethernet_switching_interface_information(
			interface_name => $port . ".0",
			detail => 1
		);
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
			}
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
							<native-vlan-id>%d</native-vlan-id>
							<vlan replace="replace">
				}, $port, $native_vlan);

			foreach my $vl (sort {$a <=> $b } keys %{$Vlans{byid}}) {
				if ($vl > 100) {
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
			my $parser = new XML::DOM::Parser;
			my $doc = $parser->parsestring($xml);
			if (!$doc) {
				SetError($err,
					"Bad XML string setting VLAN trunking.  This should not happen");
				return undef;
			}
			eval {
				$res = $jnx->load_configuration(
					format => 'xml',
					action => 'replace',
					configuration => $doc
				);
			};
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
			my $parser = new XML::DOM::Parser;
			my $doc = $parser->parsestring($xml);
			if (!$doc) {
				SetError($err,
					"Bad XML string setting VLAN.  This should not happen");
				return undef;
			}
			eval {
				$res = $jnx->load_configuration(
					format => 'xml',
					action => 'replace',
					configuration => $doc
				);
			};
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
		$res = $jnx->get_lacp_interface_information(
			interface_name => $port
		);

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
		$res = $jnx->get_configuration(configuration => $confdoc);

#		$res = $jnx->get_lacp_interface_information(
#			interface_name => $port,
#		);
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
#	$res = $jnx->get_lacp_interface_information(
#		interface_name => $aeinterface
#	);
#
#	if (!ref($res)) {
#		SetError($err, sprintf("Error retrieving LACP status for port %s",
#			$port));
#		return undef;
#	}
#	my $aeports;
#	foreach my $interface ($res->getElementsByTagName('lag-lacp-protocol')) {
#		$aeports->{$interface->getElementsByTagName('name')->[0]->getFirstChild->getNodeValue} = 1;
#	}

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

	$res = $jnx->get_configuration(configuration => $confdoc);
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
		$res = $jnx->load_configuration(
			format => 'xml',
			action => 'replace',
			configuration => $confdoc
		);
	};
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
		$res = $jnx->get_configuration(configuration => $confdoc);
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
			$res = $jnx->get_configuration(configuration => $confdoc);
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
		$res = $jnx->load_configuration(
			format => 'xml',
			action => 'replace',
			configuration => $confdoc
		);
	};
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
		$res = $jnx->load_configuration(
			format => 'xml',
			action => 'replace',
			configuration => $confdoc
		);
	};
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
		$res = $jnx->get_mstp_bridge_configuration_information();
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
	$res = $jnx->get_route_information(
		destination => $opt->{route},
		exact => 1);
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
		$res = $jnx->load_configuration(
			format => 'xml',
			action => 'replace',
			configuration => $doc
		);
	};
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

	my $err;

	my $macport = {};
	my $portmac = {};

	my $timeout = time() + ($opt->{timeout} || 0);

	my $device = $self->{device};
	my $jnx = $self->{handle};
	while(1) {
		my $macdata = $jnx->get_ethernet_switching_table_information(brief=>1);
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

    my $res = $jnx->get_ethernet_switching_interface_information(
            interface_name => $port . ".0",
            detail => 1
        );

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
	my $credentials = $opt->{credentials};
	my $action = $opt->{action} || 'replace';

	my $res;
	my $state;
	$state = STATE_CONNECTED;

	eval {
		$res = $jnx->load_configuration(
			format => ($opt->{format} || 'text'),
			action => 'replace',
			($opt->{format} && $opt->{format} eq 'xml') ?
				(configuration => $opt->{config}) :
				("configuration-text" => $opt->{config})
		);
	};
	$state = STATE_CONFIG_LOADED;
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
		$res = $jnx->commit_configuration();
		$error = $res->getFirstError();
		if ($error) {
			SetError($err, sprintf(
				"Error committing configuration change: %s",
				$error->{message}));
			return undef;
		}
	}
	return 1;
}

sub SetBGPPeerStatus {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{bgp_peer}) {
		SetError($err,
			"bgp_peer parameter must be passed to SetBGPPeer");
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
	$res = $jnx->get_bgp_group_information(
		group_name => 'ADNEXUS-HOST'
	);

	if (!ref($res)) {
		SetError($err, "Error retrieving BGP information");
		return undef;
	}
	my $bgpstanza = $res->getElementsByTagName('bgp-group');
	if (!$bgpstanza) {
		SetError($err, "BGP group is not configured for this switch");
		return undef;
	}
	my $bgppeers = $res->getElementsByTagName('peer-address');
	my $peerfound;
	foreach my $peercrap (@$bgppeers) {
		my $peer = (split '\+', $peercrap->getFirstChild->getNodeValue)[0];
		if ($peer && $peer eq $bgp_peer) {
			$peerfound = 1;
			last;
		}
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
		<routing-instances>
			<instance>
				<name>PROD</name>
				<protocols>
					<bgp>
						<group>
							<name>ADNEXUS-HOST</name>
							<neighbor delete="delete">
								<name>%s</name>
							</neighbor>
						</group>
					</bgp>
				</protocols>
			</instance>
		</routing-instances>
	</configuration>
			}, $bgp_peer);
		my $parser = new XML::DOM::Parser;
		my $doc = $parser->parsestring($xml);
		if (!$doc) {
			SetError($err,
				"Bad XML string removing BGP peer.  This should not happen");
			return undef;
		}
		eval {
			$res = $jnx->load_configuration(
				format => 'xml',
				action => 'replace',
				configuration => $doc
			);
		};
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

		$res = $jnx->get_route_information(
			protocol => 'direct'
		);

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
				$nexthop->[0]->getFirstChild->getNodeValue !~ /^vlan/);

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
		<routing-instances>
			<instance>
				<name>PROD</name>
				<protocols>
					<bgp>
						<group>
							<name>ADNEXUS-HOST</name>
							<neighbor>
								<name>%s</name>
							</neighbor>
						</group>
					</bgp>
				</protocols>
			</instance>
		</routing-instances>
	</configuration>
			}, $bgp_peer);
		my $parser = new XML::DOM::Parser;
		my $doc = $parser->parsestring($xml);
		if (!$doc) {
			SetError($err,
				"Bad XML string removing BGP peer.  This should not happen");
			return undef;
		}
		eval {
			$res = $jnx->load_configuration(
				format => 'xml',
				action => 'merge',
				configuration => $doc
			);
		};
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

sub GetInterfaceConfig {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

	if (!$opt->{interface_name}) {
		GetError($err,
			"interface_name parameter must be passed to GetJuniperInterfaceConfig");
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
	$res = $jnx->get_configuration(configuration => $confdoc);

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
			my $filtername = $f->getElementsByTagName('filter-name')->[0]->
				getFirstChild->getNodeValue;
			$iface_info->{filter}->{$filtertype} = $filtername;
		}
	}
	return $iface_info;
}

sub GetVLANs {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

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

	#
	# <get-vlan-information> doesn't show irb interface mappings on the
	# 9200s, because Juniper sucks
	#
	#my $res = $jnx->get_vlan_information();

	my $xml = qq {
	<configuration>
		<vlans/>
	</configuration>};
	my $parser = new XML::DOM::Parser;
	my$confdoc = $parser->parsestring($xml);

	my $res = $jnx->get_configuration(configuration => $confdoc);

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

	my $ifacexml = $jnx->get_interface_information;
	if (!ref($ifacexml)) {
		SetError($err, "Error retrieving interface config");
		return undef;
	}

	my $vrrpxml;
	my $vrrp_info = {};
	
	eval { $vrrpxml = $jnx->get_vrrp_information(brief=>1) };

	if (ref($vrrpxml)) {
		foreach my $iface ($vrrpxml->getElementsByTagName('vrrp-interface')) {
			my $ifacename = $iface->getElementsByTagName('interface')->[0]->
				getFirstChild->getNodeValue;
			if (!exists($vrrp_info->{$ifacename})) {
				$vrrp_info->{$ifacename} = [];
			}
			push @{$vrrp_info->{$ifacename}},
				$iface->getElementsByTagName('virtual-ip-address')->[0]->
				getFirstChild->getNodeValue;
		}
	}

	my $iface_info;
	foreach my $iface ($ifacexml->getElementsByTagName('logical-interface')) {
		my $self = {};

		my $ifacename = $iface->getElementsByTagName('name')->[0]->
			getFirstChild->getNodeValue;

		foreach my $afxml ($iface->getElementsByTagName('address-family')) {
			my $af = $afxml->getElementsByTagName('address-family-name')->[0]->
				getFirstChild->getNodeValue;
			next if !$af;
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
						if (!(grep { $addr->addr() eq $_ }
							@{$vrrp_info->{$ifacename}})) {
							$addr
						} else {
							();
						}
					} $afxml->getElementsByTagName('interface-address')
				];
				$self->{ipv4} = $ipv4 if @$ipv4;
			}
			my $linklocal = NetAddr::IP->new('fe80::/64');
			if ($af eq 'inet6') {
				my $ipv6 = [];
				foreach my $addrxml
						($afxml->getElementsByTagName('interface-address')) {
					my $netxml =
						$addrxml->getElementsByTagName('ifa-destination');
					next if !@$netxml;
					my $net;
					if (@$netxml)  {
						$net = NetAddr::IP->new(
							$netxml->[0]->getFirstChild->getNodeValue);
						next if $net eq $linklocal;
					} else {
						$net = NetAddr::IP->new('::/128');
					}
					my $addr = NetAddr::IP->new(
						$addrxml->getElementsByTagName('ifa-local')->[0]
							->getFirstChild->getNodeValue, $net->masklen);
					# Skip anything that's a VRRP service address or
					# link local address
					if (!($net eq $linklocal || (grep
							{ $addr->addr() eq $addrxml }
							@{$vrrp_info->{$ifacename}}))) {
						push @$ipv6, $addr;
					}
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

sub GetChassisInfo {
	my $self = shift;
	my $opt = &_options(@_);

	my $err = $opt->{errors};

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
	$chassisxml = $jnx->get_chassis_inventory();
	if (!ref($chassisxml)) {
		SetError($err, "Error retrieving chassis inventory");
		return undef;
	}

	my $members = {};
	foreach my $member ($chassisxml->getElementsByTagName('chassis-module')) {
		my $modname = $member->getElementsByTagName('name', 0)->[0]->
			getFirstChild->getNodeValue;
		my $slot;
		($slot) = $modname =~ /^FPC (\d+)/;
		next if (!defined($slot));

		my $serial = $member->getElementsByTagName('serial-number', 0)->
			[0]->getFirstChild->getNodeValue;
		my $model = $member->getElementsByTagName('model-number', 0)->
			[0]->getFirstChild->getNodeValue;
		$members->{$slot} = {
			serial => $serial,
			model => uc($model)
		}
	}

	my $chassis = $chassisxml->getElementsByTagName('chassis')->[0];
	my $inventory = {
		model => $chassis->getElementsByTagName('description', 0)->[0]->
			getFirstChild->getNodeValue,
		serial => $chassis->getElementsByTagName('serial-number', 0)->[0]->
			getFirstChild->getNodeValue,
		members => $members
	};

	return $inventory;
}

1;
