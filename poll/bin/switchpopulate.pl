#!/usr/local/bin/perl
# Copyright (c) 2005-2010, Vonage Holdings Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# $Id$

use strict;
use warnings;
use JazzHands::Switches;
use Net::Netmask;
use JazzHands::DBI;
use Data::Dumper;
use FileHandle;
use Socket;
use Carp;
use Getopt::Long;

# Structure of a minimal ICMP packet
use constant ICMP_ECHOREPLY => 0; # ICMP packet types
use constant ICMP_ECHO      => 8;
use constant ICMP_STRUCT    => "C2 n3 A";  # Structure of a minimal ICMP packet
use constant SUBCODE	=> 0; # No ICMP subcode for ECHO and ECHOREPLY
use constant ICMP_FLAGS     => 0; # No special flags for send or recv
use constant ICMP_PORT      => 0; # No port with ICMP


do_work();

############################################################################
## deal withs ending icmp; stolen from Net::Ping

use constant ICMP_ECHOREPLY => 0; # ICMP packet types
use constant ICMP_ECHO      => 8;
use constant ICMP_STRUCT    => "C2 n3 A";  # Structure of a minimal ICMP packet
use constant SUBCODE	=> 0; # No ICMP subcode for ECHO and ECHOREPLY
use constant ICMP_FLAGS     => 0; # No special flags for send or recv
use constant ICMP_PORT      => 0; # No port with ICMP

sub checksum
{
  my (
      $msg	    # The message to checksum
      ) = @_;
  my ($len_msg,       # Length of the message
      $num_short,     # The number of short words in the message
      $short,	 # One short word
      $chk	    # The checksum
      );

  $len_msg = length($msg);
  $num_short = int($len_msg / 2);
  $chk = 0;
  foreach $short (unpack("n$num_short", $msg))
  {
    $chk += $short;
  }					   # Add the odd byte in
  $chk += (unpack("C", substr($msg, $len_msg - 1, 1)) << 8) if $len_msg % 2;
  $chk = ($chk >> 16) + ($chk & 0xffff);      # Fold high into low
  return(~(($chk >> 16) + $chk) & 0xffff);    # Again and complement
}

sub mk_icmp_socket {
	my $protonum =  (getprotobyname('icmp'))[2] || 1;
	my $fh = FileHandle->new() || die "icmp fh: $!";
	socket($fh, PF_INET, SOCK_RAW, $protonum) || die "socket: $!";;
	$fh;
}

sub icmp_send {
	my ($fh, $host, $seq) = @_;

	$seq = 1 if(!defined($seq));
	my $checksum = 0;
	my $pid = $$ & 0xffff;
	my $msg = pack(ICMP_STRUCT."0", ICMP_ECHO, SUBCODE, $checksum, $pid,
		$seq, "");
	$checksum = checksum($msg);
	$msg = pack(ICMP_STRUCT, ICMP_ECHO, SUBCODE, $checksum, $pid,
		$seq, "");

	my $ip = inet_aton($host);
	my $saddr = sockaddr_in(ICMP_PORT, $ip);
	send($fh, $msg, ICMP_FLAGS, $saddr);
}

############################################################################

sub dblogin {
	my $dbh = JazzHands::DBI->connect('switcher', {AutoCommit=>0}) || die;

	{
		my $dude = (getpwuid($<))[0] || 'unknown';
		my $q = qq{ 
			begin
				dbms_session.set_identifier ('$dude');
			end;
		};
		if(my $sth = $dbh->prepare($q)) {
			$sth->execute;
		}
	}
	$dbh;
}

#
# totally stolen from STAB.
#
sub int_mac_from_text {
	my($dbh, $vc_mac) = @_;

	return(undef) if(!defined($vc_mac));

	$vc_mac =~ tr/a-z/A-Z/;
	if($vc_mac =~ /^([\dA-F]{4}\.){2}[\dA-F]{4}$/) {
		$vc_mac =~ s/\.//g;
	} elsif($vc_mac =~ /^([\dA-F]{1,2}:){5}[\dA-F]{1,2}$/ ) {
		my $newmac = "";
		foreach my $o (split(/:/, $vc_mac)) {
			$newmac .= sprintf("%02X", hex($o));
		}
		$vc_mac = $newmac;
	} elsif($vc_mac =~ /^[\dA-F]{12}$/) {
		#
	} else {
		return undef;
	}


	my $q = qq{
		select TO_NUMBER(:1,'XXXXXXXXXXXX') from dual
	};
	my $sth = $dbh->prepare($q) || die $dbh->errstr;
	$sth->execute($vc_mac) || die $sth->errstr;
	($sth->fetchrow_array)[0];
}


sub build_session {
	my($dbh, $switch, $comm) = @_;

	my $rv = new JazzHands::Switches(
		hostname => $switch,
		community => $comm
	);
	$rv;
}

sub ping_all {
	my($icmp_sock, $vlanlist, $vlanmap, $seq) = @_;

	foreach my $vlan (keys %$vlanlist) {
		if(!exists($vlanmap->{$vlan})) {
			print "not pinging vlan #$vlan, no interface data\n";
			next;
		}
		foreach my $cidr (@{$vlanmap->{$vlan}}) {
			my $blk = new Net::Netmask($cidr);
			if(!$blk) {
				print "could not decode $cidr, skipping\n";
			}
			print "\tProcessing blk ", $blk->base(), "/", $blk->bits, "\n";
			for my $ip ($blk->enumerate) {
				icmp_send($icmp_sock, $ip, $seq);
			}
		}
	}
}

my($__FindDevByNameSth);
sub find_device_by_name {
	my($dbh, $name) = @_;

	if(!$__FindDevByNameSth) {
		my $q =qq{
			select	*
			  from	device
			 where	lower(device_name) = lower(:1)
				
		};
		$__FindDevByNameSth = $dbh->prepare($q) || die $dbh->errstr;
	}

	$__FindDevByNameSth->execute($name) || die $__FindDevByNameSth->errstr;
	my $ni = $__FindDevByNameSth->fetchrow_hashref;
	$__FindDevByNameSth->finish;
	$ni;
}

sub guess_device_by_name {
	my($dbh, $name) = @_;
	
	my $sth = $dbh->prepare_cached(qq{
		select	*
		  from	device
		 where	lower(device_name) like lower(:1) || '%'
	}) || die $dbh->errstr;

	$sth->execute($name) || die $sth->errstr;
	my $ni = $sth->fetchrow_hashref;
	$sth->finish;

	$ni;
}


my($__getPPortBySth);
sub get_pport_from_name {
	my($dbh, $devid, $name, $nick) = @_;

	if(!$__getPPortBySth) {
		my $q =qq{
			select	*
			  from	physical_port
			 where	device_id = :1 and port_name = :2
			   and	port_type = 'network'
		};
		$__getPPortBySth = $dbh->prepare($q) || die $dbh->errstr;
	}

	$__getPPortBySth->execute($devid, $name) || die $__getPPortBySth->errstr;
	my $ni = $__getPPortBySth->fetchrow_hashref;
	$__getPPortBySth->finish;
	if(!$ni && $nick) {
		$__getPPortBySth->execute($devid, $nick) || die $__getPPortBySth->errstr;
		$ni = $__getPPortBySth->fetchrow_hashref;
		$__getPPortBySth->finish;
	}
	$ni;
}

my($__FindIntByMacSth);
sub find_int_by_mac {
	my($dbh, $mac) = @_;

	if(!$__FindIntByMacSth) {
		my $q =qq{
			select	distinct ni.*, d.device_name
			  from	device d
				inner join network_interface ni
					on d.device_id = ni.device_id
			 where	
				ni.mac_addr = :1
			ORDER BY
					CASE 	WHEN regexp_like(ni.name, '.*:') THEN 1
							WHEN regexp_like(ni.name, '.*\\.') THEN 2
							ELSE 0
					 END
						 
		};
		$__FindIntByMacSth = $dbh->prepare($q) || die $dbh->errstr;
	}

	$__FindIntByMacSth->execute($mac) || die $__FindIntByMacSth->errstr;
	my $dev = $__FindIntByMacSth->fetchrow_hashref;
	$__FindIntByMacSth->finish;
	$dev;
}

my($__checkIntSth);
sub get_port_id {
	my($dbh, $devid, $port) = @_;

	if(!$__checkIntSth) {
		my $q = qq{
			select	physical_port_id
			  from	physical_port
			 where	device_id = :1
			   and	port_name = :2
		};
		$__checkIntSth = $dbh->prepare($q) || die $dbh->errstr;
	}
	$__checkIntSth->execute($devid, $port) || die $__checkIntSth->errstr;
	my $hr = $__checkIntSth->fetchrow_hashref;
	$__checkIntSth->finish;
	($hr)?$hr->{'PHYSICAL_PORT_ID'}:undef;
}

my ($__addIntSth);
sub add_port_Id {
	my($dbh, $devid, $port, $type) = @_;

	$type = 'network' if(!defined($type));

	if(!$__addIntSth) {
		my $q = qq{
			insert into physical_port
				(device_id, port_name, port_type)
			values
				(:devid, :pn, :pt)
			returning physical_port_id into :ppid
		};
		$__addIntSth = $dbh->prepare($q) || die $dbh->errstr;
	};

	my $ppid = undef;
	$__addIntSth->bind_param(':devid', $devid) || die $__addIntSth->errstr;
	$__addIntSth->bind_param(':pn', $port) || die $__addIntSth->errstr;
	$__addIntSth->bind_param(':pt', $type) || die $__addIntSth->errstr;
	$__addIntSth->bind_param_inout(':ppid', 
		\$ppid, 50) || die $__addIntSth->errstr;

	$__addIntSth->execute || confess $__addIntSth->errstr;
	$__addIntSth->finish;
	$ppid;
}


sub populate_all_switchports {
	my($dbh, $switch, $swrec) = @_;

	my $iflist = $switch->iflist();
	my $ifs = $switch->physicalifs();

	foreach my $if (sort keys %$ifs) {
		my $ifname = $iflist->{$if};
		print "dealing with $ifname\n";
		my $id = get_port_id($dbh, $swrec->{'DEVICE_ID'}, $ifname);
		if(!$id) {
			$id = add_port_Id($dbh, $swrec->{'DEVICE_ID'}, $ifname);
		}
		if($id) {
			# warn "added port $ifname on ", $swrec->{'DEVICE_NAME'}, ": $id\n";
		} else {
			warn "Could not add id for $ifname on ", $swrec->{'DEVICE_NAME'}, "\n";
		}
	}
}

my($__getIntSth);
sub get_interface {
	my($dbh, $id) = @_;

	if(!$__getIntSth) {
		my $q = qq{
			select	ni.*,
					ip_manip.v4_octet_from_int(nb.ip_address) as ip
			  from	network_interface ni
					inner join netblock nb
						on nb.netblock_id = ni.netblock_id
			 where	ni.network_interface_id = :1
		};
		$__getIntSth = $dbh->prepare($q) || die $dbh->errstr;
	}
	$__getIntSth->execute($id) || die $__getIntSth->errstr;
	my $hr = $__getIntSth->fetchrow_hashref;
	$__getIntSth->finish;
	$hr;
}


sub virtualify_pport {
	my($dbh, $id, $name) = @_;

	my $q = qq{
		update	network_interface
		   set	name = :2,
				physical_port_id = NULL
		  where	network_interface_id = :1
	};
	my $sth = $dbh->prepare($q) || die $dbh->errstr;
	$sth->execute($id, $name) || die $sth->errstr;
	$sth->finish;
}

sub delete_pport {
	my($dbh, $id) = @_;

	my $q = qq{
		delete	from physical_port
		  where	physical_port_id = :1
	};
	my $sth = $dbh->prepare($q) || die $dbh->errstr;
	$sth->execute($id) || die $sth->errstr;
	$sth->finish;
}

sub fix_goofy_ips {
	my($dbh, $switch, $swrec) = @_;

	my $iftoIdx = $switch->walk_oid('IF-MIB', 'ifName',undef,undef,undef,1);
	my $goofIp = $switch->walk_oid("FOUNDRY-SN-AGENT-MIB", "snAgGblIfIpAddr");
	my $goofMsk = $switch->walk_oid("FOUNDRY-SN-AGENT-MIB", "snAgGblIfIpAddr");

	my $q = qq{
		select	ni.*,
				ip_manip.v4_octet_from_int(nb.ip_address) as ip
		  from	network_interface ni
				inner join netblock nb
					on nb.netblock_id = ni.primary_netblock_id
		 where	device_id = :1
	};
	my $sth = $dbh->prepare($q) || die $dbh->errstr;

	foreach my $offset (keys(%$goofIp)) {
		my $ip = $goofIp->{$offset};
		my $mask = $goofMsk->{$offset};
		$sth->execute($swrec->{'DEVICE_ID'}) || die $sth->errstr;
		while(my $hr = $sth->fetchrow_hashref) {
			my $newname = "management";
			if(defined($iftoIdx->{ $hr->{'NAME'} })) {
				warn "need to change ", $hr->{'NAME'}, " to management\n";
				# virtualify_pport($dbh, $hr->{'NETWORK_INTERFACE_ID'}, $newname);
				# delete_pport($dbh, $hr->{'PHYSICAL_PORT_ID'});
			}
		}
		$sth->finish;
	}
}

my $__connectPPortSth;
sub connect_pports {
	my($dbh, $port1, $port2) = @_;

	if(!$__connectPPortSth) {
		my $q =qq{
			begin
				:numchange := port_utils.configure_layer1_connect(
					:physport1,
					:physport2
				);
			end;
		};
		$__connectPPortSth = $dbh->prepare($q) || die $__connectPPortSth->errstr;
	}

	$__connectPPortSth->bind_param(':physport1', $port1) || die $__connectPPortSth->errstr;
	$__connectPPortSth->bind_param(':physport2', $port2) || die $__connectPPortSth->errstr;
	my $rv;
	$__connectPPortSth->bind_param_inout(':numchange', \$rv, 50) || die $__connectPPortSth->errstr;
	$__connectPPortSth->execute || die $__connectPPortSth->errstr;
	$rv;
}

sub do_work {
	system("date");
	my $dbh = dblogin();

	my $icmp_sock = mk_icmp_socket();

	my($site,$routername);

	my $r = GetOptions(
		"site=s"	=> \$site,
		"router=s"	=> \$routername,
	) || die;

	if(defined($site)) {
		$site =~ tr/A-Z/a-z/;
	} else {
		die "must specify --site argument\n";
	}

	my $router;
	if($routername) {
		$router = build_session($dbh, $routername, 'commstr');	# need to hit db
		confess "router setup failure for $routername" if(!$router);
	}

	# specify an optional 'like' pattern .
	my $pattern = shift(@ARGV);

	my $devrest = "";
	if($pattern) {
		$devrest = "d.device_name like '$pattern' AND";
	}

	my $q = qq{
		select	d.*, snmp.rd_string, dns.dns_name, dom.soa_name
		  from	device d
			left join network_interface ni
				on ni.device_id = d.device_id
				and is_management_interface = 'Y'
			left join dns_record dns
				on dns.netblock_id = ni.primary_netblock_id
			left join dns_domain dom
				on dns.dns_domain_id = dom.dns_domain_id
			left join snmp_commstr snmp
				on snmp.device_id = d.device_Id
				and snmp_commstr_type = 'legacy'
		 where	 
		 $devrest
			d.status in ('up', 'unknown')
		order by d.device_name
	};
	print $q;
	my $sth = $dbh->prepare($q) || die $dbh->errstr;

	$sth->execute || die $sth->errstr;
	while(my $swrec = $sth->fetchrow_hashref) {
		if(!$swrec->{'RD_STRING'}) {
			warn $swrec->{'DEVICE_NAME'}, "( ",
				$swrec->{'DEVICE_ID'}, "): ", 'no comm str\n';
			next;
		};
		my $dns;
		if($swrec->{DNS_NAME}) {
			$dns = join(".", $swrec->{DNS_NAME}, $swrec->{SOA_NAME});
		}
		my $pollname = (defined($dns))?$dns:$swrec->{DEVICE_NAME};
		print "++ Processing ", $swrec->{'DEVICE_NAME'}, "( ",
			$swrec->{'DEVICE_ID'}, "): ", $swrec->{'RD_STRING'}, "\n";
		my $switch = build_session($dbh, $pollname,
			$swrec->{'RD_STRING'});
		if(!$switch) {
			warn "skipping ", $swrec->{'DEVICE_NAME'}, " could not establish session\n";
			next;
		} 
		process_switch($dbh, $icmp_sock, $switch, $swrec, $router);
	}
	$sth->finish;
	$dbh->commit;
	$dbh->disconnect;
	system("date");
}

sub process_switch {
	my($dbh, $icmp_sock, $switch, $swrec, $router) = @_;

	my $intIp;
	if($router) {
		$intIp = $router->intaddrs($intIp);
	}

	my $goofIp = $switch->walk_oid("FOUNDRY-SN-AGENT-MIB", "snAgGblIfIpAddr");

	if($goofIp) {
		warn "need to fix goofy ips\n";
		fix_goofy_ips($dbh, $switch, $swrec);
	} else {
		$intIp = $switch->intaddrs;
		#print Dumper($intIp);
		#exit;
	}

	# NOTE: THIS SCREWS UP WHEN PORT AGGREGATION IS INVOLVED!
	#	CAREFUL!
	# if router is not set, do interface only
	my $interfaceonly = ($router)?0:1;
	
	# if just doing interfaces, comment out from here to below
	if(! $interfaceonly) {
		my %vlanmap;
		for my $if (keys %$intIp) {
			if($intIp->{$if}->{vlan} && $intIp->{$if}->{ip}) {
				$vlanmap{ $intIp->{$if}->{vlan} } = $intIp->{$if}->{ip};
			}
		}
	
		# print Dumper(\%vlanmap);
	
		my $vlanlist = $switch->fetch_vlan_list;
		# print Dumper($vlanlist);
	
		#
		# ping everything a few times to make things responsive
		#
		print "pinging things...\n";
		ping_all($icmp_sock, $vlanlist, \%vlanmap, 1);
		ping_all($icmp_sock, $vlanlist, \%vlanmap, 2);
		ping_all($icmp_sock, $vlanlist, \%vlanmap, 3);
	
	} 
	# move before the fetch_vlan_list if just port population is desired
	print "populating all switchports...\n";
	populate_all_switchports($dbh, $switch, $swrec);
	return if($interfaceonly);
	# $dbh->commit;
	# exit;
	# if just doing interfaces, comment out to here, excepting the return
	# on the line above.

	my $list = $switch->mac_to_port;
	my $nicks = $switch->ifnicks;
	foreach my $if (sort keys(%$list)) {
		if(scalar @{$list->{$if}} >1) {
			warn "skipping $if because it has >1 mac\n";
			next;
		}

		my $firstmac = pop( @{$list->{$if}} );
		my $intmac = int_mac_from_text($dbh, $firstmac);
		my $peerint = find_int_by_mac($dbh, $intmac);
		if($peerint) {
			my $nickint = ($nicks && ref $nicks eq 'HASH')?$nicks->{$if}:undef;
			my $myint = get_pport_from_name($dbh, $swrec->{'DEVICE_ID'}, $if, $nickint);
			if(!$myint) {
				print "\t-- could not find interface for my $if\n";
			} else {
				print "connect ", $myint->{'PHYSICAL_PORT_ID'}, " to ",
					$peerint->{'PHYSICAL_PORT_ID'}, "\n";
				connect_pports($dbh, $myint->{'PHYSICAL_PORT_ID'},
					$peerint->{'PHYSICAL_PORT_ID'});
			}
		} else {
			warn $swrec->{'DEVICE_NAME'}.":$if -> $firstmac :: NOT FOUND\n";
		}
	}

	my $peers = $switch->neighbors;
	process_peers($dbh, $switch, $swrec, $peers);

}

sub process_peers {
	my($dbh, $switch, $rec, $peers) = @_;

	print Dumper($peers);

	for my $if (sort keys(%$peers)) {
		my $peername = $peers->{$if}->{'peer'};
		my $peerdns = (gethostbyname($peername))[0];
		if(!$peerdns) {
			$peerdns = (gethostbyname($peername.".m"))[0];
		}
		my $peerrec;
		if($peerdns) {
			$peerrec = find_device_by_name($dbh, $peerdns);
		}

		if(!$peerrec) {
			$peerrec = guess_device_by_name($dbh, $peername);
			if(!$peerrec) {
				warn $rec->{'DEVICE_NAME'}.":UNKNOWN PEER:", $peername, "\n";
				next;
			}
		}

		# XXX - probably need to look at network interfaces here, maybe?

		my $peerifname = $peers->{$if}->{'peerif'};
		my $peerpportid = get_port_id($dbh, $peerrec->{'DEVICE_ID'}, $peerifname);
		if(!$peerpportid) {
			$peerpportid = add_port_Id($dbh, $peerrec->{'DEVICE_ID'}, $peerifname);
		}

		my $myport = get_port_id($dbh, $rec->{'DEVICE_ID'}, $if);
		if(!$myport) {
			print "\t-- could not find $if on myself\n";
		} else {
			print "$if: connecting $myport to $peerpportid on dev ", $peerrec->{'DEVICE_ID'}, "\n";
			connect_pports($dbh, $myport, $peerpportid);
		}
	}
}
