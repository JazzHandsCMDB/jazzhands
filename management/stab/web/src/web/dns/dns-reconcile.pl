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

use JazzHands::STAB;
use Net::DNS;
use warnings;
use strict;

do_dns_compare();

sub find_best_ns {
	my ( $stab, $zone ) = @_;

	my $lastns;
	if ( $zone =~ /(\d+)\.112.10.in-addr.arpa/ ) {
		$zone = '112.10.in-addr.arpa';
	}

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
			if ( $nsdname eq 'intauth0.EXAMPLE.COM' ) {
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
	if ( $zone =~ /(\d+)\.112.10.in-addr.arpa/ ) {
		$do_16    = $1;
		$xferzone = '112.10.in-addr.arpa';
	}

	my @zone = $res->axfr($xferzone);
	foreach my $rr ( sort by_name @zone ) {
		if ( $rr->type eq 'PTR' ) {
			$rr->name =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\./;
			next if ( defined($do_16) && $do_16 != $2 );
			my @addr = ( $1, $2, $3, $4 );
			my $addr = join( ".", reverse(@addr) );
			if (
				!check_addr(
					$stab, $rr->ptrdname,
					$addr, $rr->type
				)
			  )
			{
				print $cgi->li(
					"IP $addr PTR in DNS ",
					$cgi->b( $rr->ptrdname ),
					" does not exist in DB.\n"
				);
			}
		} elsif ( $rr->type eq 'A' ) {
			if (
				!check_addr(
					$stab,        $rr->name,
					$rr->address, $rr->type
				)
			  )
			{
				print $cgi->li(
					"A record for ",
					$cgi->b(
						device_link( $stab, $rr->name )
					),
					" (",
					$rr->address,
					") is not in DB.\n"
				);
			}
		} elsif ( $rr->type eq 'CNAME' ) {
			check_cname( $stab, $rr->name, $rr->cname, $zone );
		} elsif ( $rr->type eq 'NS' || $rr->type eq 'SOA' ) {
			next;
		} else {
			print $cgi->li(
				"NOTE: ",
				$rr->type,
				" record ",
				$rr->name,
" should be verified with jazzhands\@example.com"
			);
		}
	}
}

#
# This needs to go away once the version in the perl module
#
sub device_from_name {
	my ( $stab, $name ) = @_;
	my $dbh = $stab->dbh;

	my $q = qq{
		select  device_id, device_name,
			device_type_id, serial_number, 
			asset_tag, operating_system_id,
			status, production_state,
			ownership_status,
			is_monitored,
			is_locally_managed,
			identifying_dns_record_id,
			SHOULD_FETCH_CONFIG,
			PARENT_DEVICE_ID,
			IS_VIRTUAL_DEVICE,
			AUTO_MGMT_PROTOCOL
		  from  device
		 where  device_name = :1
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($name) || $stab->return_db_err($sth);

	$sth->fetchrow_hashref;
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
			 where	lower(dns.dns_name) = lower(:1)
			   and	dom.soa_name = :2
			   and	dns.dns_type = 'CNAME'
		};
		$cnameSth = $stab->prepare($q) || die $dbh->errstr;
	}

	$cname =~ s/\.$zone$//;

	$cnameSth->execute( $cname, $zone ) || die $dbh->errstr;
	my ($jazzhands) = ( $cnameSth->fetchrow_array )[0];
	$cnameSth->finish;

	my $devname = $pointsto;
	$pointsto .= ".";

	if ( !defined($jazzhands) ) {
		print $cgi->li(
			"CNAME ",
			$cgi->b("$cname.$zone"),
			" in DNS (",
			device_link( $stab, $devname, $pointsto ),
			") is not set in DB"
		);
	} elsif ( $jazzhands ne $pointsto ) {
		print $cgi->li(
			"CNAME mismatch",
			$cgi->b("$cname.$zone"),
			" is ",
			$cgi->b("$jazzhands"),
			" in DB and ",
			$cgi->b("$pointsto"),
			" in DNS "
		);
	}
}

sub check_addr {
	my ( $stab, $in_name, $addr, $rec ) = @_;
	my $dbh = $stab->dbh || die "no dbh!";
	my $cgi = $stab->cgi || die "no cgi!";

	my $casth;
	if ( !defined($casth) ) {
		my $q = qq{
			select	dns.dns_name,
					dom.soa_name
			 from	netblock nb
					inner join dns_record dns on 
						nb.netblock_id = dns.netblock_id
					inner join dns_domain dom on
						dom.dns_domain_id = dns.dns_domain_id
			where	nb.ip_address =
						ip_manip.v4_int_from_octet(:1)
			  and	dns.dns_type = 'A'
		};
		$casth = $stab->prepare($q) || die $dbh->errstr;
	}

	$casth->execute($addr) || die $casth->errstr;

	my $mismatch = 0;
	while ( my ( $name, $domain ) = $casth->fetchrow_array ) {
		my $full = ( $name ? $name . "." : "" ) . $domain;
		$full    =~ tr/A-Z/a-z/;
		$in_name =~ tr/A-Z/a-z/;
		if ( $full eq $in_name ) {
			$casth->finish;
			return 1;
		} else {
			if ( $rec eq 'PTR' ) {
				print $cgi->li(
					"IP ", $addr, "DB ",
					$cgi->b( device_link( $stab, $full ) ),
					" PTR does not match DNS",
					$cgi->b(
						device_link( $stab, $in_name )
					),
					"! [May overlap with next error ]\n"
				);
				$mismatch++;
			} elsif ( $rec eq 'A' ) {
				print $cgi->li(
					"A record for ",
					$cgi->b(
						device_link( $stab, $in_name )
					),
					"(", $addr, ")",
					" does not match DB (",
					$cgi->b( device_link( $stab, $full ) ),
					")"
				);
				$mismatch++;
			}
		}
	}

	return $mismatch;
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
					  . $dev->{'DEVICE_ID'}
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
	my $zone = $domain->{'SOA_NAME'};

	my $ns = $stab->cgi_parse_param('zone') || find_best_ns( $stab, $zone );

	print $cgi->header;
	print $stab->start_html(
		{ -title => "Reconcilation issues with $zone" } );
	print $cgi->center("Note:  DB == STAB");
	print $cgi->div( { -align => 'center' },
		$cgi->a( { -href => "../dns/?dnsdomainid=$domid" }, $zone ) );
	print "<ul>\n";
	process_zone( $stab, $ns, $zone );
	print "</ul>\n";
}
