package JazzHands::NetDev::Mgmt::ACL;

use strict;
use warnings;
use Data::Dumper;
use Socket;
use JazzHands::Common::Util qw(_options);
use JazzHands::Common::Error qw(:all);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt = &_options(@_);

	my $self = {};
	bless $self, $class;

	if ($opt->{acl_text}) {
		
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

sub ParseACLLine {
	my $opt = &_options(@_);

	my $error = $opt->{errors};
	my $line = $opt->{entry};

	if (!$line || $line =~ /^\s*$/) {
		return {};
	}

	#
	# Get rid of any leading whitespace
	#
	$line =~ s/^\s+//;

	my $rule =  {};

	if ($line =~ /^!\s*(\N*)/) {
		$rule->{action} = 'remark';
		$rule->{data} = $1;
		return $rule;
	}

	my @tokens = split /\s+/, $line;
	$rule->{action} = shift @tokens;


	# Any comments we just return
	# If we don't otherwise start with 'permit' or 'deny', also bail
	
	if ($rule->{action} eq 'remark') {
		$rule->{data} = join (' ', @tokens);;
		return $rule;
	} elsif ($rule->{action} ne 'permit' && $rule->{action} ne 'deny') { 
		SetError($error, sprintf("Unknown action : %s", $rule->{action}));
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
	$rule->{protocol} = $proto;

	$rule->{source} = {};
	$rule->{dest} = {};

	foreach my $target ($rule->{source}, $rule->{dest}) {
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
			##
			## This should be converted to use NetAddr::IP, but this works
			##
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
		if (exists($target->{addrlist})) {
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
						$port = [ $startport, $endport ];
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
				push @{$target->{port}}, [ $portstring, $endport];
			}
		}
	}
	my $icmptype = [];;
	my $tcpestablished;
	while (@tokens) {
		my $keyword = shift @tokens;
		if ($proto eq 'tcp') {
			if ($keyword eq 'established') {
				$rule->{tcp_established} = 1;
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
				if (!exists($rule->{icmptypes})) {
					$rule->{icmptypes} = [];
				}
				push @{$rule->{icmptypes}}, $itype;
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
	return $rule;
}

sub Validate {
	my $opt = &_options(@_);

	my $acl;
	if (!($acl = $opt->{acl})) {
		return 1;
	}
	my $dbh = $opt->{dbh};
	my $sth;
	if ($dbh) {
		my $q = q {
			SELECT
				netblock_collection_id
			FROM
				jazzhands.netblock_collection
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
	}

	my $aclok = 1;
	my @entries = split /\n/, $acl;
	foreach my $count (0..$#entries) {
		my $errstr = undef;
		my $term = ParseACLLine(
			entry => $entries[$count],
			errors => \$errstr
			);
		if ($errstr) {
			$aclok = 0;
			SetError($opt->{errors}, sprintf("Error on line %d: %s",
				$count + 1,
				$errstr || "unknown"
			));
		}
		if ($dbh) {
			foreach my $target ('source', 'dest') {
				if (
					exists($term->{$target}) && 
					exists($term->{$target}->{group})) 
				{
					foreach my $pl (@{$term->{$target}->{group}}) {
						if (!($sth->execute($pl))) {
							SetError($opt->{errors}, 
								sprintf("%s::Validate: Unable to execute netblock collection query: %s",
									scalar(caller()),
									$sth->errstr
								)
							);
							return undef;
						}
						if (!$sth->fetchrow_hashref) {
							SetError($opt->{errors}, 
								sprintf("%s::Validate: prefix-list %s referenced on line %d, but it does not exist in the database",
									scalar(caller()),
									$pl,
									$count
								)
							);
							$sth->finish;
							return undef;
						}
						$sth->finish;
					}
				}
			}
		}
	}
	return $aclok;
}

1;
