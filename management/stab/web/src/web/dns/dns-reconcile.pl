#!/usr/bin/env perl
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
# This does a simple one way check to make sure whatever is in the ZONE is
# also in the database.  it does not go the other way and list things in the
# database that are not in the zone.
#

#
# $Id$
#

use warnings;
use strict;
use JazzHands::STAB;
use Net::DNS;
use Data::Dumper;
use JazzHands::Common qw(:all);
use Carp;

do_dns_compare();

sub find_best_ns {
	my ( $stab, $zone ) = @_;

	my $lastns;

	my $res = Net::DNS::Resolver->new;
	my $query = $res->query( $zone, "NS" );

	if ( !$query || !$query->answer ) {
		$stab->error_return(
			"Unable to find the registered nameserver for this host"
		);
	}
	foreach my $rr ( grep { $_->type eq 'NS' } $query->answer ) {
		if ( defined( $rr->nsdname ) ) {
			my $nsdname = $rr->nsdname;
			$nsdname =~ tr/A-Z/a-z/;
			if ( $nsdname eq 'intauth00.EXAMPLE.COM' ) {
				return ('intauth00.EXAMPLE.COM');
			} elsif ( $nsdname eq 'auth00.EXAMPLE.COM' ) {
				return ('auth00.EXAMPLE.COM');
			}
			$lastns = $rr->nsdname;
		}
	}
	$lastns;
}

sub by_name {
	if ( $a->name =~ /^\d+$/ && $b->name =~ /^\d+$/ ) {
		return ( $a->name <=> $b->name );
	} else {
		return ( $a->name cmp $b->name );
	}
}

sub process_zone {
	my ( $stab, $ns, $zone ) = @_;
	my $dbh = $stab->dbh || die "no dbh!";
	my $cgi = $stab->cgi || die "no cgi!";

	my $res = new Net::DNS::Resolver;
	$res->nameservers($ns);

	my $xferzone = $zone;
	my $do_16    = undef;
	if ( 0 && $zone =~ /(\d+)\.112.10.in-addr.arpa/ ) {
		$do_16    = $1;
		$xferzone = '112.10.in-addr.arpa';
	}

	my @zone = $res->axfr($xferzone);
	if ( $#zone == -1 ) {
		$stab->error_return(
			"Unable to AXFR zone from authoritative DNS server $ns"
		);
	}

	my $msg    = "";
	my $numrec = 0;
	foreach my $rr ( sort by_name @zone ) {
		$numrec++;
		if ( $rr->type eq 'PTR' ) {
			$rr->name =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\./;
			next if ( defined($do_16) && $do_16 != $2 );
			my @addr = ( $1, $2, $3, $4 );
			if ( !$addr[0] ) {
				$msg .=
				  "Weird, unverified PTR record: $rr->name";
			} else {
				my $addr = join( ".", reverse(@addr) );
				$msg .= check_addr(
					$stab, $rr->ptrdname,
					$addr, $rr->type
				);
			}
		} elsif ( $rr->type eq 'A' ) {
			$msg .= check_addr( $stab, $rr->name, $rr->address,
				$rr->type );
			$msg .= check_name( $stab, $rr->name, $rr->address,
				$rr->type, $zone );
		} elsif ( $rr->type eq 'MX' ) {
			$msg .= check_mx( $stab, $rr->name, $rr->preference,
				$rr->exchange, $zone );
		} elsif ( $rr->type eq 'CNAME' ) {
			$msg .=
			  check_cname( $stab, $rr->name, $rr->cname, $zone );
		} elsif ( $rr->type eq 'CNAME' ) {
			$msg .=
			  check_cname( $stab, $rr->name, $rr->cname, $zone );
		} elsif ( $rr->type eq 'SRV' ) {
			$msg .= check_srv( $stab, $rr, $zone );
		} elsif ( $rr->type eq 'TXT' ) {
			my @list = $rr->char_str_list;
			$msg .= check_txt( $stab, $rr->name, \@list, $zone );
		} elsif ( $rr->type eq 'NS' ) {
			$msg .=
			  check_ns( $stab, $rr->name, $rr->nsdname, $zone );
		} elsif ( $rr->type eq 'SOA' ) {
			$msg .= check_soa( $stab, $rr, $zone );
		} else {
			$msg .= $cgi->li(
				"NOTE: ",
				$rr->type,
				" record ",
				$rr->name,
" can not be checked and should be verified by hand."
			);
		}
	}

	$msg .= $cgi->li("Processed $numrec records.");
	$msg;
}

#
# This needs to go away once the version in the perl module
#
sub device_from_name {
	my ( $stab, $name ) = @_;
	my $dbh = $stab->dbh;

	my $q = qq{
		select  *
		  from  device
		 where  device_name = ?
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($name) || $stab->return_db_err($sth);

	$sth->fetchrow_hashref;
}

sub check_for_zone {
	my ( $stab, $zone ) = @_;

	my $sth = $stab->prepare(
		qq{
		select	dns_domain_id
		 from	dns_domain
		 where	soa_name = ?
	}
	) || $stab->return_db_err;

	$sth->execute($zone) || $stab->return_db_err;

	my ($domid) = $sth->fetchrow_array;
	$sth->finish;
	$domid;
}

sub check_soa {
	my ( $stab, $rr, $zone ) = @_;
	my $cgi = $stab->cgi;

	my $sth = $stab->prepare(
		qq{
		select	*
		 from	dns_domain
		where	soa_name = ?
	}
	) || $stab->return_db_err;

	$sth->execute($zone) || $stab->return_db_err;

	my $msg = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		if ( $hr->{ _dbx('SOA_SERIAL') } < $rr->serial ) {
			$msg .= $cgi->li(
				"SOA: Serial number in JazzHands (",
				$cgi->b( $hr->{ _dbx('SOA_SERIAL') } ),
				") is less than the one in zone (",
				$rr->serial,
				")"
			);
		}
		if ( $hr->{ _dbx('SOA_EXPIRE') } != $rr->expire ) {
			$msg .= $cgi->li(
				"SOA: Expire time in JazzHands (",
				$cgi->b( $hr->{ _dbx('SOA_EXPIRE') } ),
				") is different than the one in zone (",
				$rr->expire,
				")"
			);
		}
		if ( $hr->{ _dbx('SOA_MINIMUM') } != $rr->minimum ) {
			$msg .= $cgi->li(
				"SOA: minimum in JazzHands (",
				$cgi->b( $hr->{ _dbx('SOA_MINIMUM') } ),
				") is different than the one in zone (",
				$rr->minimum,
				")"
			);
		}

	}

	return $msg;
}

sub check_ns {
	my ( $stab, $name, $nsdname, $zone ) = @_;
	my $cgi = $stab->cgi;

	my $shortname = $name;
	$shortname =~ s/\.?$zone$//;

	my $zoneclause = "dns_name = :name";
	if ( $zone eq $name ) {
		$zoneclause = "dns_name is null";
	} else {
		if ( !defined( check_for_zone( $stab, $zone ) ) ) {
			return $cgi->li(
"$name is a dedicated zone; not checking NS record"
			);
		}
	}

	my $sth = $stab->prepare(
		qq{
		select	d.dns_value
		  from	dns_record	d
				inner join dns_domain dom
					on dom.dns_domain_id = d.dns_domain_id
		  where	$zoneclause
		  AND	d.dns_type = 'NS'
		  AND	d.dns_class = 'IN'
		  AND	dom.soa_name = :zone
	}
	) || $stab->return_db_err;

	if ( $zone ne $name ) {
		$sth->bind_param( ':name', $shortname )
		  || $stab->return_db_err($sth);
	}

	$sth->bind_param( ':zone', $zone ) || $stab->return_db_err($sth);
	$sth->execute || $stab->return_db_err($sth);

	my $msg   = "";
	my $found = 0;
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $dnsval = $hr->{ _dbx('DNS_VALUE') };
		my $altn   = $nsdname;
		if ( $nsdname ne $zone ) {
			$altn =~ s/\.$zone$//;
		}
		if ( $dnsval eq $nsdname . "." || $dnsval eq $altn ) {
			$found = 1;
		} else {
			$msg .= $cgi->li(
"NS: $name ($nsdname) does not match JazzHands for $shortname (",
				"$dnsval"
			);
		}
	}

	if ( !$found ) {
		if ( $msg && length($msg) ) {
			return $msg;
		} else {
			my $ps;
			if ( length($shortname) ) {
				$ps = "for $shortname";
			} else {
				$ps = "for domain";
			}
			return $cgi->li(
				"NS record $ps: $nsdname not in JazzHands");
		}
	}
}

sub check_txt {
	my ( $stab, $name, $txtlist, $zone ) = @_;
	my $cgi = $stab->cgi;

	my $sname = $name;
	$sname =~ s/.?$zone$//;

	my $nameq = "d.dns_name = :name";
	if ( $name eq $zone ) {
		$nameq = "d.dns_name is null";
	}

	my $sth = $stab->prepare(
		qq{
		select	d.dns_value
		 from	dns_record d
				inner join dns_domain dom
					on dom.dns_domain_id = d.dns_domain_id
		 where	dom.soa_name = :zone
		 and	$nameq
		 and	d.dns_class = 'IN'
		 and	d.dns_type = 'TXT'
	}
	) || return $stab->return_db_err;

	$sth->bind_param( ':zone', $zone ) || $stab->return_db_err($sth);

	if ( $name ne $zone ) {
		$sth->bind_param( ':name', $sname )
		  || $stab->return_db_err($sth);
	}

	$sth->execute || $stab->return_db_err($sth);

	my $found = 0;
	my $msg   = "";
	while ( my ($val) = $sth->fetchrow_array ) {

		# the zone generation software DTRT with quotes.
		$val =~ s/^"//;
		$val =~ s/"$//;
		foreach my $txt (@$txtlist) {
			if ( $txt eq $val ) {
				$found = 1;
			} else {
				$msg .= $cgi->li(
					"TXT record for ",
					$cgi->b($name),
					" ($val) does not match JazzHands ",
					"(",
					$cgi->b($val),
					")"
				);
			}
		}
	}

	if ( !$found ) {
		if ( $msg && length($msg) ) {
			return $msg;
		} else {
			return $cgi->li( "TXT record for ",
				$cgi->b($name), " not found in JazzHands" );
		}
	}
	return "";
}

sub check_srv {
	my ( $stab, $rr, $zone ) = @_;
	my $cgi = $stab->cgi || die "no cgi!";

	my $full = $rr->name;
	my ( $svc, $proto, $name ) = split( /\./, $full, 3 );

	if ( $name eq $zone ) {
		$full = undef;
		$name = undef;
	} else {
		$name =~ s/\.$zone$//;
	}

	my $aq = "";
	if ($name) {
		$aq = "d.dns_name = :fullname";
	} else {
		$aq = "d.dns_name is null";
	}
	my $pq = "";
	if ($proto) {
		$proto =~ s/^_//;
		$pq = q{ (
				d.dns_srv_protocol = :proto
			AND	d.dns_srv_service = :svc
			)
		};
	}

	if ( length($aq) ) {
		$aq = "( $aq AND $pq )";
	} else {
		$aq = $pq;
	}

	my $q = qq{
		select	d.dns_record_id,
			d.dns_name,
			d.dns_priority,
			d.dns_srv_service,
			d.dns_srv_protocol,
			d.dns_srv_weight,
			d.dns_srv_port,
			d.dns_value
		  from	dns_record d
				inner join dns_domain dom USING (dns_domain_id)
		 where	dom.soa_name = :zone
		  and	$aq
	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err;

	$sth->bind_param( ':zone', $zone ) || $stab->return_db_err($sth);
	if ($full) {
		$sth->bind_param( ':fullname', $name )
		  || $stab->return_db_err($sth);
	}

	my $msg = "";
	if ( $pq && length($pq) ) {
		$sth->bind_param( ':proto', $proto )
		  || $stab->return_db_err($sth);
		$sth->bind_param( ':svc', $svc ) || $stab->return_db_err($sth);
	}
	$sth->execute || $stab->return_db_err($sth);

	my $found = 0;
	while ( my $hr = $sth->fetchrow_hashref ) {

       # slap the zone back on some compares to what came from dns look right...
		$hr->{ _dbx('DNS_VALUE') } .= ".$zone"
		  if ( $hr->{ _dbx('DNS_VALUE') } !~ /\.$/ );
		$hr->{ _dbx('DNS_VALUE') } =~ s/\.$//;
		my $mesh = join( " ",
			$rr->priority, $rr->weight, $rr->port, $rr->target );
		$mesh =~ s/\s+/ /g;
		if ( defined( $hr->{ _dbx('DNS_SRV_PORT') } ) ) {
			if (
				$hr->{ _dbx('DNS_VALUE') } eq $rr->target
				&&

			       # $hr->{_dbx('DNS_SRV_SERVICE')} == $svc &&
			       # $hr->{_dbx('DNS_SRV_PROTOCOL')} eq "_$proto" &&
				$hr->{ _dbx('DNS_PRIORITY') } == $rr->priority
				&& $hr->{ _dbx('DNS_SRV_WEIGHT') } ==
				$rr->weight
				&& $hr->{ _dbx('DNS_SRV_PORT') } == $rr->port
			  )
			{
				$found = 1;
			} else {
				my $dbmesh = join( " ",
					$hr->{ _dbx('DNS_PRIORITY') },
					$hr->{ _dbx('DNS_SRV_WEIGHT') },
					$hr->{ _dbx('DNS_SRV_PORT') },
					$hr->{ _dbx('DNS_VALUE') } );
				$dbmesh =~ s/\s+/ /g;
				$msg .= $cgi->li(
					"SRV record in DNS ",
					$rr->name,
					" is '",
					$cgi->b($dbmesh),
					"' not '$mesh'"
				);
			}
		} elsif ( $hr->{ _dbx('DNS_VALUE') } eq $mesh ) {
			$found = 1;
		} else {
			my $dbmesh = $hr->{ _dbx('DNS_VALUE') };
			if ( $hr->{ _dbx('DNS_SRV_PORT') } ) {
				$dbmesh = join( " ",
					$hr->{ _dbx('DNS_PRIORITY') },
					$hr->{ _dbx('DNS_SRV_WEIGHT') },
					$hr->{ _dbx('DNS_SRV_PORT') },
					$hr->{ _dbx('DNS_VALUE') } );
				$dbmesh =~ s/\s+/ /g;
				$msg .= $cgi->li(
					"combined SRV record ",
					$rr->name,
					" is ",
					$cgi->b($dbmesh),
					" not '$mesh'"
				);
			}
		}
	}

	if ( !$found ) {
		if ( $msg && length($msg) ) {
			return $msg;
		} else {
			return $cgi->li(
				"SRV record for ",
				$rr->name,
				" was not found in JazzHands (",
				join( " ",
					$rr->priority, $rr->weight,
					$rr->port,     $rr->target ),
				")"
			);
		}
	}
}

sub check_mx {
	my ( $stab, $name, $pref, $mx, $zone ) = @_;
	my $cgi = $stab->cgi || die "no cgi!";

	my $shortname = $name;
	$shortname =~ s/\.$zone$//;

	my $nameblurb;
	if ( $zone eq $name ) {
		$nameblurb = "dns.dns_name is null";
		$name      = undef;
	} else {
		$nameblurb = "lower(dns.dns_name) = lower(:name)";
	}

	my $msg;
	my $sth = $stab->prepare(
		qq{
		select	lower(dns.dns_value), dns_priority
		  from	dns_record dns
				inner join dns_domain dom
					on dom.dns_domain_id = dns.dns_domain_id
		 where	$nameblurb
		   and	dom.soa_name = :zone
		   and	dns.dns_type = 'MX'
	}
	) || $stab->return_db_err;

	if ( defined($name) ) {
		$sth->bind_param( ":name", $shortname )
		  || $stab->return_db_err($sth);
	}
	$sth->bind_param( ":zone", $zone ) || $stab->return_db_err($sth);

	$sth->execute || $stab->return_db_err($sth);

	my $found = 0;
	while ( my ( $val, $pri ) = $sth->fetchrow_array ) {
		$found = 1;
		my $combo = "$pref $mx.";
		if ( $val !~ /\.$/ ) {
			$val .= ".$zone.";
		}
		if ( defined($pri) && $pref == $pri && $val eq "$mx." ) {
			$found = 1;
			$msg   = "";
			last;
		} elsif ( $val eq $combo ) {
			$found = 1;
			$msg   = "";
			last;
		} else {
			my $x = ($pri) ? "$pri $val" : $val;
			my $mname = $name || "";
			$msg .= $cgi->li(
"MX record $mname ($x) in JazzHands does not match ($combo)"
			);
		}
	}
	$sth->finish;

	if ( !$found ) {
		if ( !$msg || !length($msg) ) {
			$msg .= $cgi->li(
				"MX record $name $pref $mx not in JazzHands");
		}
	}
	$msg;

}

sub check_cname {
	my ( $stab, $cname, $pointsto, $zone ) = @_;
	my $dbh = $stab->dbh || die "no dbh!";
	my $cgi = $stab->cgi || die "no cgi!";

	my ($cnameSth);
	if ( !$cnameSth ) {
		my $q = qq{
			select	lower(dns.dns_value)
			  from	dns_record dns
					inner join dns_domain dom
						on dom.dns_domain_id = dns.dns_domain_id
			 where	lower(dns.dns_name) = lower(?)
			   and	dom.soa_name = ?
			   and	dns.dns_type = 'CNAME'
		};
		$cnameSth = $stab->prepare($q) || die $dbh->errstr;
	}

	$cname =~ s/\.$zone$//;

	$cnameSth->execute( $cname, $zone ) || die $dbh->errstr;
	my ($db) = ( $cnameSth->fetchrow_array )[0];
	$cnameSth->finish;

	my $devname = $pointsto;
	$pointsto .= ".";

	$pointsto =~ tr/A-Z/a-z/;

	my $rv = "";
	if ( !defined($db) ) {
		$rv .= $cgi->li(
			"CNAME ",
			$cgi->b("$cname.$zone"),
			" in DNS (",
			device_link( $stab, $devname, $pointsto ),
			") is not set in JazzHands"
		);
	} elsif ( $db !~ /\.$/ && $pointsto eq "$db.$zone." ) {
		return $rv;
	} elsif ( $db ne $pointsto ) {
		$rv .= $cgi->li(
			"CNAME mismatch",
			$cgi->b("$cname.$zone"),
			" is ",
			$cgi->b("$db"),
			" in JazzHands and ",
			$cgi->b("$pointsto"),
			" in DNS "
		);
	}
	return $rv;
}

sub check_name {
	my ( $stab, $in_name, $addr, $rec, $zone ) = @_;
	my $dbh = $stab->dbh || die "no dbh!";
	my $cgi = $stab->cgi || die "no cgi!";

	my $stripname = $in_name;
	$stripname =~ s/\.$zone$//;

	my $q = qq{
		select	net_manip.inet_dbtop(ip_address) as ip,
				dns.dns_name,
				dom.soa_name,
				dom.dns_domain_id
		 from	netblock nb
				inner join dns_record dns on 
					nb.netblock_id = dns.netblock_id
				inner join dns_domain dom on
					dom.dns_domain_id = dns.dns_domain_id
		where	dns.dns_name = ?
		  and	dns.dns_type = 'A'
		  and	dom.soa_name = ?

	};
	my $sth = $stab->prepare($q) || die $dbh->errstr;

	$sth->execute( $stripname, $zone ) || die $dbh->errstr;

	my $m = "";

	my $found = 0;
	while ( my ( $ip, $name, $dom, $id, $soa ) = $sth->fetchrow_array ) {
		$m .= $cgi->li( "** A record for ",
			$cgi->b($in_name), " is $ip (not $addr) in DB" );
		if ( $addr eq $ip ) {
			$sth->finish;
			return "";
		}
	}

	$m;
}

#
# This passes back its text as an reference to an input parameter, which is
# weird and different.  This is to faciliate combing PTR/A records, which
# probably needs to be rethought.
#
sub check_addr {
	my ( $stab, $in_name, $addr, $rec, $rv ) = @_;
	my $dbh = $stab->dbh || die "no dbh!";
	my $cgi = $stab->cgi || die "no cgi!";

	my $casth;
	if ( !defined($casth) ) {
		my $q = qq{
			select	dns.dns_domain_id, dns.dns_name,
					dom.soa_name
			 from	netblock nb
					inner join dns_record dns on 
						nb.netblock_id = dns.netblock_id
					inner join dns_domain dom on
						dom.dns_domain_id = dns.dns_domain_id
			where	nb.ip_address =
						net_manip.inet_ptodb(?, masklen(ip_address) )
			  and	dns.dns_type = 'A'
			  and	family(ip_address) = 4
		};
		$casth = $stab->prepare($q) || die $dbh->errstr;
	}

	$casth->execute($addr) || croak $casth->errstr;

	my $t = "";

	$in_name =~ tr/A-Z/a-z/;
	my $mismatch = 0;
	while ( my ( $id, $name, $domain ) = $casth->fetchrow_array ) {
		my $full = ( $name ? $name . "." : "" ) . $domain;
		$full =~ tr/A-Z/a-z/;
		if ( $full eq $in_name ) {
			$t .= $cgi->li("$full matches $in_name")
			  if ( $in_name =~ /ccadmin/ );
			$casth->finish;
			return "";
		} else {
			if ( $rec eq 'PTR' ) {
				$t .= $cgi->li(
					"IP ", $addr,
					"JazzHands ",
					$cgi->b( device_link( $stab, $full ) ),
					" PTR does not match DNS",
					$cgi->b(
						device_link( $stab, $in_name )
					),
					"! [May overlap with next error ]\n"
				);
				$mismatch++;
			} elsif ( $rec eq 'A' ) {
				$t .= $cgi->li(
					"A record for ",
					$cgi->b(
						device_link( $stab, $in_name )
					),
					"(", $addr, ")",
					" does not match JazzHands (",
					$cgi->b( device_link( $stab, $full ) ),
					")"
				);
				$mismatch++;
			} else {
				$t .= $cgi->li(
					$cgi->b(
"rec of type $rec not supported for $in_name/$addr.  This should not happen."
					)
				);
			}
		}
	}

	if ( !$mismatch ) {
		if ( $rec eq 'PTR' ) {
			$t .= $cgi->li( "IP $addr PTR in DNS ",
				$cgi->b($in_name),
				" does not exist in JazzHands.\n" );
		} elsif ( $rec eq 'A' ) {
			$t .= $cgi->li( "A record for ",
				$cgi->b($in_name), " (",
				$addr, ") is not in JazzHands.\n" );
		} else {
			$t .= $cgi->li(
				$cgi->b(
"rec of type $rec not supported for $in_name/$addr.  This should not happen. (no records in db)"
				)
			);
		}
	}

	return $t;
}

sub device_link {
	my ( $stab, $name, $altname ) = @_;

	$altname = $name if ( !$altname );

	my $cgi = $stab->cgi || die "no cgi!";

	my $dev = device_from_name( $stab, $name );

	if ( !$dev ) {
		return ($name);
	} else {
		return (
			$cgi->a(
				{
					-href => "../device/device.pl?devid="
					  . $dev->{ _dbx('DEVICE_ID') }
				},
				$altname
			)
		);
	}

}

#############################################################################

sub do_dns_compare {
	my $stab = new JazzHands::STAB || die "no stab!";
	my $cgi  = $stab->cgi          || die "no cgi!";
	my $dbh  = $stab->dbh          || die "no dbh!";

	my $domid = $stab->cgi_parse_param("DNS_DOMAIN_ID")
	  || $stab->error_return("you must specify a domain");

	my $domain = $stab->get_dns_domain_from_id($domid)
	  || $stab->error_return("unknown domain id $domid");
	my $zone = $domain->{ _dbx('SOA_NAME') };

	my $ns = $stab->cgi_parse_param('ns') || find_best_ns( $stab, $zone );

	my $msg = process_zone( $stab, $ns, $zone );
	print $cgi->header;
	print $stab->start_html(
		{ -title => "Reconcilation issues with $zone" } );
	print $cgi->center("Note:  JazzHands == STAB");
	print $cgi->div( { -align => 'center' },
		$cgi->a( { -href => "../dns/?dnsdomainid=$domid" }, $zone ) );
	print $cgi->ul($msg);
	$msg = undef;
	undef $stab;
}
