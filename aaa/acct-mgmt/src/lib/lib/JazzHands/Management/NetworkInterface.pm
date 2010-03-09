#
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

# $Id$
#

package JazzHands::Management::NetworkInterface;

use warnings;
use strict;
use JazzHands::Management;
use Net::Netmask;
use Data::Dumper;

use vars qw($VERSION @EXPORT @EXPORT_OK @ISA $AUTOLOAD);

$VERSION = '1.0.0';    # $Date$

@EXPORT_OK = qw(

);

sub new {
	my ( $class, @params ) = @_;

	my $me = {};
	bless $me;

	# probably need to intialize actual class if it's different, or
	# something? [XXX]

	while ( my $thing = shift(@params) ) {
		if ( $thing eq 'dbh' ) {
			$me->{'dbh'} = shift(@params);
		} elsif ( $thing eq 'device' ) {
			$me->{'deviceid'} = shift(@params);
		} elsif ( $thing eq 'network_interface_id' ) {
			$me->{'__db_interfaceid'} = shift(@params);
		} elsif ( $thing eq 'ip' ) {
			$me->{'ip'} = shift(@params);
		} elsif ( $thing eq 'bits' ) {
			$me->{'bits'} = shift(@params);
		} elsif ( $thing eq 'name' ) {
			$me->{'name'} = shift(@params);
		}
	}

	#
	# maybe need to allow these to be overridden in new?  maybe not.  [XXX]
	#
	$me->{'is_up'} = 'Y' if ( !defined( $me->{'is_up'} ) );
	$me->{'should_monitor'} = 'N'
	  if ( !defined( $me->{'should_monitor'} ) );
	$me->{'should_manage'} = 'Y' if ( !defined( $me->{'should_manage'} ) );

	$me->refresh_class_from_db;

	$me->seterr(undef);
	return $me;
}

sub isindb {
	my ($me) = @_;

	if ( defined( $me->{'__db_interfaceid'} ) ) {
		return 1;
	}
	return undef;
}

sub dbinsert {
	my ($me) = @_;

	if ( ( defined( $me->{'__db_interfaceid'} ) ) ) {
		return $me->seterr( 'data', undef, undef,
			'interface is already in db' );
	}

	if ( !( defined( $me->{'name'} ) ) ) {
		return $me->seterr( 'data', undef, undef,
			'no interface name defined' );
	}

	if ( !( defined( $me->{'deviceid'} ) ) ) {
		return $me->seterr( 'data', undef, undef,
			'no device id specified' );
	}

	if ( !( defined( $me->{'is_primary'} ) ) ) {
		return $me->seterr( 'data', undef, undef,
			'primary state not set' );
	}

	if ( !( defined( $me->{'is_management_interface'} ) ) ) {
		return $me->seterr( 'data', undef, undef,
			'management state not set' );
	}

	if (       ( $me->{'shortname'} && !defined( $me->{'domain'} ) )
		|| ( $me->{'domain'} && !defined( $me->{'shortname'} ) ) )
	{

		return $me->seterr( 'data', undef, undef,
			'dns info incomplete' );
	}

	my $ip   = $me->{'ip'};
	my $bits = $me->{'bits'};

	my $newnblkid;
	if ( defined($ip) ) {
		$newnblkid = $me->__get_or_create_netblock_id( $ip, $bits )
		  || return;
		if ( defined( $me->{'domain'} ) ) {

			#
			# error code passes back from create_physical_port
			#
			$me->add_dns_record( $me->{'domain'},
				$me->{'shortname'}, $newnblkid )
			  || return;
		}
	} else {
		$newnblkid = 'NULL';
	}

	#
	# error code passes back from create_physical_port
	#
	my $pport_id =
	  $me->create_physical_port( $me->{'deviceid'}, $me->{'name'},
		'network' )
	  || return undef;

	my $mac;
	if ( defined($mac) ) {
		$mac =~ s/://g;
		$mac = qq{ TO_NUMBER('$mac','XXXXXXXXXXXX') };
	} else {
		$mac = 'NULL';
	}

	my $q = qq{
		insert into network_interface	(
			device_id, name, physical_port_id,
			network_interface_type, is_interface_up,
			mac_addr, network_interface_purpose,
			is_primary, should_monitor,
			v4_netblock_id, should_manage,
			provides_dhcp, provides_nat, is_management_interface
		) values (
			:device_id, :name, $pport_id,
			'unknown', :is_interface_up,
			$mac, 'unknown',
			:is_primary,  :should_monitor,
			$newnblkid, :should_manage,
			'N', 'N', :is_management_interface
		) returning network_interface_id into :rv
	};

	my $netintid;

	my $sth = $me->{'dbh'}->prepare($q) || return $me->setdberr;

	$sth->bind_param( ":device_id", $me->{'deviceid'} )
	  || return $me->setdberr($sth);
	$sth->bind_param( ":name", $me->{'name'} )
	  || return $me->setdberr($sth);
	$sth->bind_param( ":is_interface_up", $me->{'is_up'} )
	  || return $me->setdberr($sth);
	$sth->bind_param( ":is_primary", $me->{'is_primary'} )
	  || return $me->setdberr($sth);
	$sth->bind_param( ":should_monitor", $me->{'should_monitor'} )
	  || return $me->setdberr($sth);
	$sth->bind_param( ":should_manage", $me->{'should_manage'} )
	  || return $me->setdberr($sth);
	$sth->bind_param( ":is_management_interface",
		$me->{'is_management_interface'} )
	  || return $me->setdberr($sth);

	$sth->bind_param_inout( ":rv", \$netintid, 500 )
	  || return $me->setdberr($sth);
	$sth->execute || return $me->setdberr($sth);

	$me->{'__db_interfaceid'} = $netintid;
	$me->{'__db_netblockid'}  = $newnblkid;

	$me->refresh_class_from_db || return undef;
	$me->setdberr($sth);
	1;
}

sub rename {
	my ( $me, $new_name ) = @_;

	$me->{'name'} = $new_name;

	if ( ( defined( $me->{'__db_interfaceid'} ) ) ) {
		my $q = qq{
			update	network_interface
			   set	name = :2
			  where	network_interface_id = :1
		};

		my $sth = $me->{'dbh'}->prepare($q) || return $me->setdberr;
		$sth->execute( $me->{'__db_interfaceid'}, $new_name )
		  || return $me->setdberr($sth);
	}

	$me->seterr(undef);
	1;
}

sub changeip {
	my ( $me, $ip, $bits ) = @_;

	my $oldip   = $me->{'ip'};
	my $oldbits = $me->{'bits'};

	if ( !defined($bits) ) {
		( $ip, $bits ) = split( m,/,, $ip );
	}

	if ( !( defined($bits) ) ) {
		$bits = $oldbits;
	}

	if ( !( defined( $me->{'__db_interfaceid'} ) ) ) {
		$me->{'ip'}   = $ip;
		$me->{'bits'} = $bits;
		$me->seterr(undef);
		return 1;
	}

	my $dbh = $me->{'dbh'};

	my $newnblkid = $me->__get_or_create_netblock_id( $ip, $bits );

	return undef if ( !$newnblkid );

	if ( defined( $me->{__db_netblockid} )
		&& $me->{__db_netblockid} != $newnblkid )
	{
		my ( $q, $sth );

		$q = qq {
			update network_interface
			   set	v4_netblock_id = :2
			 where	network_interface_id = :1
		};
		$sth = $dbh->prepare($q) || return $me->setdberr;
		$sth->execute( $me->{'__db_interfaceid'}, $newnblkid )
		  || return $me->setdberr;

		$q = qq {
			update	dns_record
			   set	netblock_id = :2
			 where	dns_record_id = :1
		};

		$sth = $dbh->prepare($q) || return $me->setdberr;
		$sth->execute( $me->{'__db_dnsrecordid'}, $newnblkid )
		  || return $me->setdberr($sth);

		$q = qq{
			delete from netblock
			  where	netblock_id = :1
		};
		$sth = $dbh->prepare($q) || return $me->setdberr($sth);
		$sth->execute( $me->{'__db_netblockid'} )
		  || return $me->setdberr($sth);

		$me->{'__db_netblockid'} = $newnblkid;
	}

	$me->seterr(undef);
	1;
}

sub delete {
	my ($me) = @_;

	return if ( !( defined($me) ) );
	if ( !defined( $me->{'dbh'} ) ) {
		return $me->seterr('must have a dbh set');
	}
	my $dbh = $me->{'dbh'};

	#
	# do we want this?
	#
	if ( !$me->refresh_class_from_db ) {
		return $me->seterr( 'data', undef, undef,
			"no matches for interface " );
	}

	if ( !defined( $me->{'__db_interfaceid'} ) ) {
		return $me->seterr( 'data', undef, undef,
			"no matches for interface" );
	}

	my @cmds = (
		'__db_interfaceid',
		'delete from network_interface where network_interface_id = :1',
		'__db_dnsrecordid',
		'delete from dns_record where dns_record_id = :1',
		'__db_netblockid',
		'delete from netblock where netblock_id = :1'
	);

	while ( my $key = shift(@cmds) ) {
		my $cmd = shift(@cmds);
		if ( defined( $me->{$key} ) ) {
			my $sth = $dbh->prepare($cmd) || return $me->setdberr;
			$sth->execute( $me->{$key} )
			  || return $me->setdberr($sth);
		}
	}

	$me->{'domainid'}         = undef;
	$me->{'__db_interfaceid'} = undef;
	$me->{'__db_netblockid'}  = undef;
	$me->{'__db_dnsrecordid'} = undef;
	$me->{'__db_dnsdomainid'} = undef;

	$me->seterr(undef);
	1;
}

sub dnsrename {
	my ( $me, $newshort, $newdomain ) = @_;

	return if ( !( defined($me) ) );
	if ( !defined( $me->{'dbh'} ) ) {
		return $me->seterr('must have a dbh set');
	}
	my $dbh = $me->{'dbh'};

	if ( !( defined( $me->{'__db_interfaceid'} ) ) ) {
		$me->{'shortname'} = $newshort  if ( defined($newshort) );
		$me->{'domain'}    = $newdomain if ( defined($newdomain) );
		$me->{'fqhn'} = $me->{'shortname'}
		  . (
			( defined( $me->{'domain'} ) )
			? "." . $me->{'domain'}
			: ""
		  );
		$me->seterr(undef);

		if ( defined($newdomain) ) {
			my $newdomid = $me->__get_dns_domain($newdomain);
			if ( !defined($newdomid) ) {
				return $me->seterr( 'db', undef, $newdomain,
"could not find domain.  it needs to be created."
				);
			}
		}

		return 1;
	}

	if ( !defined( $me->{'shortname'} ) ) {
		if ( !defined($newdomain) ) {
			return $me->seterr("must set a domain with new entry");
		} else {
			$me->{'shortname'} = $newshort;
			$me->{'domain'}    = $newdomain;
			$me->add_dns_record( $me->{'domain'},
				$me->{'shortname'}, $me->{'__db_netblockid'} );
			$me->refresh_class_from_db;
			return 1;
		}
	}

	my $oldshort  = $me->{'shortname'};
	my $olddomain = $me->{'domain'};
	my $oldfqhn   = $me->{'fqhn'};

	if ( !defined($newdomain) ) {
		$newshort =~ s/\.$me->{'domain'}$//;
		$newdomain = $me->{'domain'};
	}

	if ( defined($newdomain)
		&& ( !defined($olddomain) || ( $newdomain ne $olddomain ) ) )
	{
		my $newdomid = $me->__get_dns_domain($newdomain);

		if ( !( defined($newdomid) ) ) {
			return $me->seterr( 'db', undef, $newdomain,
				"could not find domain, it needs to be created"
			);
		}

		if ( defined($olddomain) ) {
			my $q = qq{
				update	dns_record
				   set	dns_domain_id = :2
				 where	dns_record_id = :1
			};
			my $sth = $dbh->prepare($q) || return $me->setdberr;
			$sth->execute( $me->{'__db_dnsrecordid'}, $newdomid )
			  || return $me->setdberr($sth);
		}
		$me->{'__db_dnsdomainid'} = $newdomid;
	}

	if ( defined($newshort)
		&& ( !defined($oldshort) || ( $newshort ne $oldshort ) ) )
	{
		if ( !defined($oldshort) ) {
			$me->add_dns_record( $newdomain, $newshort,
				$me->{'__db_netblockid'} )
			  || return undef;
		} else {
			my $q = qq{
				update	dns_record
				   set	dns_name = :2
				 where	dns_record_id = :1
			};
			my $sth = $dbh->prepare($q) || return $me->setdberr;
			$sth->execute( $me->{'__db_dnsrecordid'}, $newshort )
			  || return $me->setdberr($sth);
		}
	}

	$me->{'shortname'} = $newshort;
	$me->{'domain'} = $newdomain if ( defined($newdomain) );
	$me->{'fqhn'} =
	  $me->{'shortname'}
	  . ( ( defined( $me->{'domain'} ) ) ? "." . $me->{'domain'} : "" );

	$me->seterr(undef);
	1;
}

sub dump {
	my ( $me, $fh, $debug ) = @_;

	$fh = \*STDOUT if ( !defined($fh) );

	if ( defined($debug) ) {
		foreach my $key ( sort keys(%$me) ) {
			if ( scalar $me->{$key} ) {
				print $fh "\t$key == ", $me->{$key}, "\n";
			}
		}
		print $fh "\n";
	} else {
		my $bits = $me->{'bits'} || 32;

		my $ip;
		if ( defined( $me->{'ip'} ) ) {
			$ip = sprintf( "%s/%-2s", $me->{'ip'}, $bits );
		} else {
			$ip = "";
		}

		printf $fh (
			"%10s %17s %s\n%29s %s\n",
			$me->{'name'},
			$ip,
			( ( defined( $me->{'fqhn'} ) ) ? $me->{'fqhn'} : "" ),
			"",
			( ( defined( $me->{'mac'} ) ) ? $me->{'mac'} : "" )
		);
		printf $fh ( "%29s is_primary = %s\n", "",
			$me->{'is_primary'} );
		printf $fh ( "%29s is_up = %s\n", "", $me->{'is_up'} );
		printf $fh (
			"%29s is_management_interface = %s\n",
			"", $me->{'is_management_interface'}
		);
		printf $fh ( "%29s should_manage = %s\n", "",
			$me->{'should_manage'} );
		printf $fh ( "%29s should_monitor = %s\n", "",
			$me->{'should_monitor'} );
	}

	$me->seterr(undef);
	1;
}

sub device_iterate {
	my ($me) = @_;

	return if ( !( defined($me) ) );
	if ( !defined( $me->{'dbh'} ) ) {
		return $me->seterr('must have a dbh set');
	}
	my $dbh = $me->{'dbh'};

	my $q = qq{
		select	network_interface_id
		  from	network_interface
		 where	device_id = :1
		order by name
	};

	my $sth = $dbh->prepare_cached($q) || return $me->setdberr;
	$sth->execute( $me->{deviceid} ) || return $me->setdberr($sth);

	my (@rv);
	while ( my ($id) = $sth->fetchrow_array ) {
		my $x = new JazzHands::Management::NetworkInterface(
			dbh                  => $dbh,
			network_interface_id => $id
		);
		push( @rv, $x );
	}
	@rv;
}

sub int_mac_from_text {
	my ( $self, $vc_mac ) = @_;

	my $dbh = $self->{dbh};

	return (undef) if ( !defined($vc_mac) );

	$vc_mac =~ tr/a-z/A-Z/;
	if ( $vc_mac =~ /^([\dA-F]{4}\.){2}[\dA-F]{4}$/ ) {
		$vc_mac =~ s/\.//g;
	} elsif ( $vc_mac =~ /^([\dA-F]{1,2}:){5}[\dA-F]{1,2}$/ ) {
		my $newmac = "";
		foreach my $o ( split( /:/, $vc_mac ) ) {
			$newmac .= sprintf( "%02X", hex($o) );
		}
		$vc_mac = $newmac;
	} elsif ( $vc_mac =~ /^[\dA-F]{12}$/ ) {

		#
	} else {
		return undef;
	}

	my $q = qq{
                select TO_NUMBER(:1,'XXXXXXXXXXXX') from dual
        };
	my $sth = $dbh->prepare_cached($q) || return undef;
	$sth->execute($vc_mac) || return undef;
	my $rv = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$rv;
}

sub setmac {
	my ( $me, $mac ) = @_;

	return if ( !( defined($me) ) );
	if ( !defined( $me->{'dbh'} ) ) {
		return $me->seterr('must have a dbh set');
	}
	my $dbh = $me->{'dbh'};

	if ( defined($mac) ) {
		$mac = $me->int_mac_from_text($mac);
		if ( !defined($mac) ) {
			return $me->seterr( 'data', undef, $mac,
				"invalid mac address" );
		}
	}

	if ( !( defined( $me->{'__db_interfaceid'} ) ) ) {
		$me->seterr(undef);
		return 1;
	}

	my $q = qq{
		update	network_interface
			set mac_addr = $mac
		 where	network_interface_id = :1
	};

	my $sth = $dbh->prepare($q) || return $me->setdberr;
	$sth->execute( $me->{'__db_interfaceid'} )
	  || return $me->setdberr($sth);

	$me->seterr(undef);
	1;
}

sub DESTROY {
	my ($mod) = @_;
}

###############################################################################
#
# unpublished, support infrastructure that probably wants to be moved out
# elsewhere
#
###############################################################################

#
# set a database error
#
sub setdberr {
	my ( $me, $obj ) = @_;

	if ( !$obj ) {
		$obj = $me->{'dbh'};
	}

	return $me->seterr( 'db', undef, undef, $obj->errstr );
}

#
# set the internal error string (this probably wants to be pulled up to a
# master module that this one inherits properties from.
#
# pass it an undef to clear the error message
#
# always returns undef
#
sub seterr {
	my ( $ref, $what, $subwhat, $query, $msg ) = @_;

	if ( !defined($what) ) {
		$ref->{'errstr'}    = undef;
		$ref->{err_what}    = undef;
		$ref->{err_subwhat} = undef;
		$ref->{err_query}   = undef;
		$ref->{err_msg}     = undef;
	} else {
		$ref->{err_what}    = $what;
		$ref->{err_subwhat} = $subwhat;
		$ref->{err_query}   = $query;
		$ref->{err_msg}     = $msg;

		if ( defined($what) ) {
			if ( defined($subwhat) ) {
				$subwhat = "/$subwhat";
			} else {
				$subwhat = "";
			}
			$what = "[$what$subwhat] ";
		} elsif ( defined($subwhat) ) {
			$what = "[$subwhat] ";
		} else {
			$what = "";
		}

		$ref->{'errstr'} =
		    $what
		  . ( ( defined($query) ) ? $query . ": " : "" )
		  . ( ( defined($msg) )   ? $msg . ": "   : "" );
	}

	# [XXX] have a flag to set how this should be presented?
	# $ref->{'errstr'} =~ s/\n/ /g;
	return undef;
}

sub iserrstate {
	my ($me) = @_;

	if ( defined( $me->{'errstr'} ) ) {
		return 1;
	}
	undef;
}

sub refresh_class_from_db {
	my ($me) = @_;

	return if ( !( defined($me) ) );
	if ( !defined( $me->{'dbh'} ) ) {
		return $me->seterr('must have a dbh set');
	}
	my $dbh = $me->{'dbh'};

	my $netint_id = $me->{'__db_interfaceid'};
	my $deviceid  = $me->{'deviceid'};
	my $name      = $me->{'name'};

	my $sth;
	if ( defined($netint_id) ) {
		my $q = qq {
			select  ni.network_interface_id as network_interface_id,
				ip_manip.v4_octet_from_int(nb.ip_address) as ip,
				nb.netblock_id	  as netblock_id,
				nb.netmask_bits	 as bits,		
				ni.name		 as interface_name,	      
				ni.description	  as interface_description,
				ni.is_interface_up      as is_interface_up,     
				to_char(ni.mac_addr, 'XXXXXXXXXXXX')  as mac_addr,
				ni.is_primary	   as is_primary,
				ni.should_monitor       as should_monitor,
				ni.should_manage	as should_manage,
				ni.is_management_interface  as is_management_interface,
				dns.dns_record_id       as dns_record_id,       
				dns.dns_domain_id       as dns_domain_id,       
				dns.dns_name	    as dns_name,
				dom.soa_name	    as domain_name	  
			  from  network_interface ni
				left join netblock nb
				    on  ni.v4_netblock_id = nb.netblock_id
				left join   dns_record dns
				    on dns.netblock_id = ni.v4_netblock_id
				left join   dns_domain  dom
				    on dns.dns_domain_id  = dom.dns_domain_id
			 where  ni.network_interface_id = :1
		};

		$sth = $dbh->prepare_cached($q)
		  || return $me->seterr( 'db', 'dbh', $q, $dbh->errstr );
		$sth->execute($netint_id)
		  || return $me->seterr( 'db', 'sth', $q, $dbh->errstr );
	} elsif ( defined($name) && defined($deviceid) ) {
		my $q = qq {
			select  ni.network_interface_id as network_interface_id,
				ip_manip.v4_octet_from_int(nb.ip_address) as ip,
				nb.netblock_id	  as netblock_id,
				nb.netmask_bits	 as bits,		
				ni.name		 as interface_name,	      
				ni.description	  as interface_description,
				ni.is_interface_up      as is_interface_up,     
				to_char(ni.mac_addr, 'XXXXXXXXXXXX')  as mac_addr,
				ni.is_primary	   as is_primary,
				ni.should_monitor       as should_monitor,
				ni.should_manage	as should_manage,
				ni.is_management_interface  as is_management_interface,
				dns.dns_record_id       as dns_record_id,       
				dns.dns_domain_id       as dns_domain_id,       
				dns.dns_name	    as dns_name,
				dom.soa_name	    as domain_name	  
			  from  network_interface ni
				left join netblock nb
				    on  ni.v4_netblock_id = nb.netblock_id
				left join   dns_record dns
				    on dns.netblock_id = ni.v4_netblock_id
				left join   dns_domain  dom
				    on dns.dns_domain_id  = dom.dns_domain_id
			 where  ni.name = :2
		   	   and	ni.device_id = :1
		};

		$sth = $dbh->prepare_cached($q)
		  || return $me->seterr( 'db', 'dbh', $q, $dbh->errstr );
		$sth->execute( $deviceid, $name )
		  || return $me->seterr( 'db', 'sth', $q, $dbh->errstr );
	} else {
		return 1;
	}

	my $matches = $sth->fetchall_hashref('NETWORK_INTERFACE_ID');
	$sth->finish;

	my @stuff = keys %$matches;
	if ( $#stuff != -1 ) {
		my $tally = $#stuff;
		if ( $tally == -1 ) {
			return $me->errstr( 'data', undef, undef,
				"no interfaces match id $netint_id" );
		} elsif ( $tally > 0 ) {
			return $me->errstr( 'data', undef, undef,
				"too many match id $netint_id" );
		}
	} else {
		return $me->seterr( 'data', undef, undef,
			'no matches for interface' );
	}

	#
	# There can be only one.
	#
	my $thing = $matches->{ $stuff[0] };
	$me->_db_import_hash($thing);

	1;
}

sub _db_import_hash {
	my ( $me, $rowh ) = @_;

	$me->{'__db_interfaceid'}        = $rowh->{'NETWORK_INTERFACE_ID'};
	$me->{'__db_netblockid'}         = $rowh->{'NETBLOCK_ID'};
	$me->{'__db_dnsrecordid'}        = $rowh->{'DNS_RECORD_ID'};
	$me->{'__db_dnsdomainid'}        = $rowh->{'DNS_DOMAIN_ID'};
	$me->{'ip'}                      = $rowh->{'IP'};
	$me->{'bits'}                    = $rowh->{'BITS'};
	$me->{'name'}                    = $rowh->{'INTERFACE_NAME'};
	$me->{'description'}             = $rowh->{'INTERFACE_DESCRIPTION'};
	$me->{'is_up'}                   = $rowh->{'IS_INTERFACE_UP'};
	$me->{'is_primary'}              = $rowh->{'IS_PRIMARY'};
	$me->{'is_management_interface'} = $rowh->{'IS_MANAGEMENT_INTERFACE'};
	$me->{'should_monitor'}          = $rowh->{'SHOULD_MONITOR'};
	$me->{'should_manage'}           = $rowh->{'SHOULD_MANAGE'};
	$me->{'mac'}                     = $rowh->{'MAC_ADDR'};
	$me->{'shortname'}               = $rowh->{'DNS_NAME'};
	$me->{'domain'}                  = $rowh->{'DOMAIN_NAME'};
	if ( defined( $me->{'shortname'} ) ) {
		$me->{'fqhn'} = $me->{'shortname'}
		  . (
			( defined( $me->{'domain'} ) )
			? "." . $me->{'domain'}
			: ""
		  );
	}

	if ( defined( $me->{'mac'} ) ) {
		my $mac = "000000000000";
		$me->{'mac'} =~ s/\s+//g;
		$mac = substr( $mac, 0, length($mac) - length( $me->{'mac'} ) );
		$mac .= $me->{'mac'};

		# $mac = join(":", split(/\S\S/, $mac));
		$mac =~ s/(\S\S)/$1:/g;
		$mac =~ s/:$//;
		$me->{'mac'} = $mac;
	}

	$me->seterr(undef);
	1;
}

sub __get_netblock_by_id {
	my ( $me, $netblockid ) = @_;

	my $dbh = $me->{'dbh'};
	my $q   = qq{ 
		select  ip_manip.v4_octet_from_int(nb.ip_address) as ip,
				nb.*
		  from  netblock nb
		 where  nb.netblock_id = :1
	};

	my $sth = $dbh->prepare_cached($q)
	  || return $me->seterr( 'db', 'dbh', $q, $dbh->errstr );
	$sth->execute($netblockid)
	  || return $me->seterr( 'db', 'sth', $q, $sth->errstr );

	my $rv = $sth->fetchrow_hashref;
	$sth->finish;
	$rv;
}

sub __get_netblock_by_ip {
	my ( $me, $ip, $bits ) = @_;

	my $dbh = $me->{'dbh'};
	my $q   = qq{ 
		select  ip_manip.v4_octet_from_int(nb.ip_address) as ip,
				nb.*
		  from  netblock nb
		 where  nb.ip_address = ip_manip.v4_int_from_octet(:1)
		   and	nb.netmask_bits = :2
	};

	my $sth = $dbh->prepare_cached($q)
	  || return $me->seterr( 'db', 'dbh', $q, $dbh->errstr );
	$sth->execute( $ip, $bits )
	  || return $me->seterr( 'db', 'sth', $q, $sth->errstr );

	my $rv = $sth->fetchrow_hashref;
	$sth->finish;
	$rv;
}

sub __get_dns_domain {
	my ( $me, $domain ) = @_;

	my $dbh = $me->{'dbh'};
	my $q   = qq{ 
		select  dns_domain_id
		  from  dns_domain
		 where  soa_name = :1
	};

	my $sth = $dbh->prepare_cached($q)
	  || return $me->seterr( 'db', 'dbh', $q, $dbh->errstr );
	$sth->execute($domain)
	  || return $me->seterr( 'db', 'sth', $q, $sth->errstr );

	my $rv = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$rv || undef;
}

#
# look up the best parent.
#
sub __find_best_parent {
	my ( $me, $ip, $bits ) = @_;

	my $dbh = $me->{'dbh'};

	$bits = 32 if ( !defined($bits) );

	my $sth = $dbh->prepare_cached(
		qq{
		begin
			:pnb := netblock_utils.find_best_parent_id(
				ip_manip.v4_int_from_octet(:ip), :bits
			);
		end;
	}
	) || return $me->setdberr;
	$sth->bind_param( ':ip',   $ip )   || return $me->setdberr($sth);
	$sth->bind_param( ':bits', $bits ) || return $me->setdberr($sth);
	my $id;
	$sth->bind_param_inout( ':pnb', \$id, 50 )
	  || return $me->setdberr($sth);
	$sth->execute || return $me->setdberr($sth);
	$id;
}

sub __get_or_create_netblock_id {
	my ( $me, $ip, $bits ) = @_;

	my $dbh = $me->{'dbh'};

	#
	# unnecessary if the IP is already there.
	#
	my $parid = $me->__find_best_parent( $ip, $bits );
	if ($parid) {
		my $parnb = $me->__get_netblock_by_id($parid);
		if ( defined($bits) ) {
			if ( $parnb->{'NETMASK_BITS'} != $bits ) {
				return $me->seterr(
"Bits does not seem right.  Please check and use stab if it is."
				);
			}
		} else {
			$bits = $parnb->{'NETMASK_BITS'};
		}
	}

	if ( !$parid ) {
		return undef if ( $me->iserrstate );
		return $me->seterr(
"Could not find a netblock that $ip/$bits should be a part of."
		);
	}

	#
	# look for the block itself
	#
	my $nb = $me->__get_netblock_by_ip( $ip, $bits );
	if ($nb) {
		if ( $nb->{NETBLOCK_STATUS} eq 'Allocated' ) {
			if ( defined( $me->{__db_netblockid} )
				&& $me->{__db_netblockid} ==
				$nb->{NETBLOCK_ID} )
			{
				return $nb->{NETBLOCK_ID};
			} else {
				return $me->seterr(
"IP is already configured on a device.  Please use STAB."
				);
			}
		} elsif ( $nb->{NETBLOCK_STATUS} =~ /^(Reserved|Legacy)$/ ) {
			my $sth = $dbh->prepare_cached(
				qq{
				update netblock set netblock_status = 'Allocated'
				where netblock_id = :1
			}
			) || return $me->setdberr;
			$sth->execute( $nb->{'NETBLOCK_ID'} )
			  || $me->setdberr($sth);
			return $nb->{'NETBLOCK_ID'};
		}
	} else {
		return undef if ( $me->iserrstate );
	}

	my $sth = $dbh->prepare_cached(
		qq{
		insert into netblock (
			ip_address, netmask_bits, is_ipv4_address,
			is_single_address, netblock_status,
			is_organizational,
			parent_netblock_id
		) values (
			ip_manip.v4_int_from_octet(:ip, 1), :bits, 'Y',
			'Y', 'Allocated',
			'N',
			:parid
		) returning netblock_id into :rv
	}
	) || return $me->setdberr;

	$sth->bind_param( ':ip',    $ip )    || return $me->setdberr($sth);
	$sth->bind_param( ':bits',  $bits )  || return $me->setdberr($sth);
	$sth->bind_param( ':parid', $parid ) || return $me->setdberr($sth);
	my $nbid;
	$sth->bind_param_inout( ':rv', \$nbid, 50 )
	  || return $me->setdberr($sth);
	$sth->execute || return $me->setdberr($sth);
	$nbid;
}

sub create_physical_port {
	my ( $me, $devid, $name, $type, $desc ) = @_;

	my $dbh = $me->{'dbh'};

	$desc = 'NULL' if ( !defined($desc) );

	my $ppid;
	my $q = qq {    
		insert into physical_port (
			device_id, port_name, port_type, description  
		) values (
			$devid, '$name', '$type', $desc
		) returning physical_port_id into :rv
	};
	my $sth = $dbh->prepare($q) || return $me->setdberr;
	$sth->bind_param_inout( ":rv", \$ppid, 500 )
	  || return $me->setdberr($sth);
	$sth->execute || return $me->setdberr($sth);
	$ppid;
}

sub add_dns_record {
	my ( $me, $domain, $name, $value, $type ) = @_;

	my $dbh = $me->{'dbh'};

	$type = 'A' if ( !defined($type) );
	my $netblockid;

	if ( $type eq 'A' ) {
		$netblockid = int $value
		  || return $me->seterr( 'data', undef, undef,
			"attempt to set an a record to a non-netblock" );
		$value = 'NULL';
	} elsif ( !defined($value) ) {
		$value = 'NULL';
	} else {
		$value      = "'$value'";
		$netblockid = 'NULL';
	}

	my $domid = $me->__get_dns_domain($domain) || return;

	my $recordid;
	my $q = qq{
		insert into dns_record
		(
			dns_name, dns_domain_id, dns_class, dns_type,
			dns_value, netblock_id, SHOULD_GENERATE_PTR
		) values (
			'$name', $domid, 'IN', '$type',
			$value, $netblockid, 'Y'
		) returning dns_record_id into :rv
	};

	my $sth = $dbh->prepare($q) || return $me->setdberr;

	$sth->bind_param_inout( ":rv", \$recordid, 500 )
	  || return $me->setdberr($sth);

	$sth->execute || return $me->setdberr($sth);
	$recordid;
}

1;
__END__

=head1 NAME

JazzHands::Management::NetworkInterface - interface access abstraction

=head1 SYNOPSIS

	use JazzHands::Management::NetworkInterface;

	## create a network interface identifier.  dbh and device are the
	## minium required.

	$netint = new JazzHands::Management::NetworkInterface(
		dbh => DBI dbi handle,
		$device => jazzhands_device_id,
		ip => ip_addres_of_interface
		bits => netmask_bits_of_interface
		name => name_of_interface
	);

	## change the name of an interface
	$netint->rename($new_name);

	## change the name of an interface's dns entry
	$netint->dnsrename($shortname, $domain);

	## change the name of an interface
	$netint->changeip($ip, $bits);

	## delete an interface from the db
	$netint->delete;

	## dump out interface description to file handle
	$netint->dump(\*STDOUT, $debug);

	## commit a new interface to the db
	$netint->dbinsert;

	## refresh information in the record from the db
	$netint->refresh_class_from_db;

	## set the mac address for an interface
	$netint->setmac($mac)

	## iterate over interfaces on a device
	foreach $thing ($netint->device_iterate) {
		# do something
	}


=head1 DESCRIPTION

JazzHands::Management::NetworkInterface is an abstration for Network Interfaces
in the System DB.  Unlike other modules in JazzHands::Management, this module
is implemenated in an object-oriented fashion.  Eventually, the remainder
of the modules will be recoded to look like this.

The dbh passed to new is generally the one opened with
JazzHands::Management::OpenJHDBConnection().

When an initial interface is created (name and device id are set), the
remainder of relevent information is populated from the db if it's there.

In this case, and after a dbinsert, all changes are commited to the db
immediately.  In the case where the device_id/name pair doesn't already
exist, then no changes will be commited to the db until the dbinsert
routine is called.  This specifically applies to rename, dnsrename,
changeip, and delete

A delete call will both delete the record from the db and make it so that
future changse are back in the 'pending' state and require the dbinsert to
insert a new record.

It is generally not necessary to call refresh_class_from_db, this is
primarily used on intial new() to populate everything relevent about
the netblock, and on an insert to make sure that everyhting relevent is
populated after the record is created.

Passing undef to the setmac function will cause it to clear the mac
address.  Only ethernet macs are supported.

The following variables can be set and accessed via $netint->{'variable'}:

	ip - the ip address in dotted quad form
	bits - the netmask_bits of a given interface
	name - the name of the network_interface
	description - a free form description of the interface
	is_up - if the interface should be considered up
	is_primary - if the interface is the primary interface
	is_management_interface - if the interface is the management interface
	should_monitor - if the interface should be monitored
	should_manage - if the interface is managed by JazzHands
	mac - the mac address in colon seperated hex form
	shortname - the short name that would live in a dns domain
	domain - the domain that the interface is associated
	fqhn - the fully qualified name of the host (shortname.domainame)

is_primary and is_management_interface must be set before a device can be
inserted.

=head1 BUGS

In a shocking turn of events, this was written really fast.  It probably
needs to be redone with more thought.

=head1 AUTHORS

Todd Kover 
