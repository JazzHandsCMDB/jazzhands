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
# $Id$
#

use strict;
use warnings;
use POSIX;
use JazzHands::STAB;
use JazzHands::GenericDB qw(_dbx);
use Net::DNS;

do_soacheck();

sub lower {
	my $ x = shift(@_);

	$x =~ tr/A-Z/a-z/;
	$x;
}

sub do_soacheck {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	dump_soacheck_all($stab);
}

sub dump_soacheck_all {
	my ($stab) = @_;
	my $cgi    = $stab->cgi;
	my $dbh    = $stab->dbh;

	my $showall   = $stab->cgi_parse_param('showall')   || 'no';
	my $nogenshow = $stab->cgi_parse_param('nogenshow') || 'all';

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html( { -title => "Nameservers: NIC vs DB" } ), "\n";

	{
		my $n = new CGI($cgi);
		my $verbage;
		if ( $showall eq 'no' ) {
			$n->param( 'showall', 'yes' );
			$verbage = 'Show All Zones';
		} else {
			$n->delete('showall');
			$verbage = 'Show Only Problem Zones';
		}
		print $cgi->p( { -align => 'center' },
			$cgi->a( { -href => $n->self_url }, $verbage ) );
	}

	my $q = qq{
		select 	dom.dns_domain_id,
			dom.soa_name,
			dom.soa_class,
			dom.soa_ttl,
			dom.soa_serial,
			dom.soa_refresh,
			dom.soa_retry,
			dom.soa_expire,
			dom.soa_minimum,
			dom.soa_mname,
			dom.soa_rname,
			dom.should_generate,
			dom.last_generated
		  from	dns_domain dom
			left join dns_record dns
				on dns.dns_domain_id = dom.dns_domain_id
				and dns.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
			left join netblock nb
				on dns.netblock_id = nb.netblock_id
		where	dom.parent_dns_domain_id is NULL
		  and	dom.soa_name not like '%10.in-addr.arpa'
		  and	dom.soa_name not like '%168.192.in-addr.arpa'
		  and	dom.soa_name not like '%16.172.in-addr.arpa'
		  and	dom.soa_name not like '%17.172.in-addr.arpa'
		  and	dom.soa_name not like '%18.172.in-addr.arpa'
		  and	dom.soa_name not like '%19.172.in-addr.arpa'
		  and	dom.soa_name not like '%2_.172.in-addr.arpa'
		  and	dom.soa_name not like '%30.172.in-addr.arpa'
		  and	dom.soa_name not like '%31.172.in-addr.arpa'
		order by nb.ip_address, dom.soa_name
	};
	my $sth = $stab->prepare($q) || return $stab->return_db_err($dbh);
	$sth->execute || return $stab->return_db_err($sth);

	my $maxperrow = 3;

	print $cgi->start_table( { -border => 1, -align => 'center' } ), "\n";

	my $curperrow = 0;
	my $rowtxt    = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		if ( $curperrow == $maxperrow ) {
			$curperrow = 0;
			print $cgi->Tr($rowtxt), "\n";
			$rowtxt = "";
		}

		my $zone_name = $hr->{_dbx('SOA_NAME')};
		my $domid     = $hr->{_dbx('DNS_DOMAIN_ID')};
		my $gen       = $hr->{_dbx('SHOULD_GENERATE')};

		if ( $nogenshow eq 'no' && $hr->{_dbx('SHOULD_GENERATE')} eq 'N' ) {
			next;
		}

		if ( $nogenshow eq 'yes' && $hr->{_dbx('SHOULD_GENERATE')} eq 'Y' ) {
			next;
		}

		my @nic = get_nic_ns($zone_name);
		my @jazzhands = get_jazzhands_namservers( $stab, $zone_name );

		my $problems = 0;
		my $numauth  = 0;
		my $numnic   = 0;

		my $nslist = $cgi->Tr(
			$cgi->td(
				{ -background => 'green', -align => 'center' },
				"NIC"
			)
		);
		if ( $#nic > -1 ) {
			foreach my $ns ( sort @nic ) {
				if ( $#jazzhands > -1
					&& grep( lower($_) eq lower($ns), @jazzhands ) )
				{
					$nslist .= $cgi->Tr( $cgi->td($ns) );
				} else {
					$nslist .= $cgi->Tr(
						$cgi->td(
							{
								-style =>
								  'color: red'
							},
							$ns
						)
					);
					$problems++;
				}
			}
			$numnic++;
		} else {
			$nslist .= $cgi->Tr(
				$cgi->td(
					{
						-style => 'color: blue',
						-align => 'center'
					},
					'none registered'
				)
			);
		}
		$nslist .= $cgi->Tr(
			$cgi->td(
				{ -background => 'green', -align => 'center' },
				"DB"
			)
		);
		if ( $#jazzhands > -1 ) {
			foreach my $ns ( sort @jazzhands ) {
				if ( $#nic > -1 && grep( lower($_) eq lower($ns), @nic ) ) {
					$nslist .= $cgi->Tr( $cgi->td($ns) );
				} else {
					$nslist .= $cgi->Tr(
						$cgi->td(
							{
								-style =>
								  'color: red'
							},
							$ns
						)
					);
					$problems++;
				}
			}
			$numauth++;
		} else {
			$nslist .= $cgi->Tr(
				$cgi->td(
					{
						-style => 'color: blue',
						-align => 'center'
					},
					'none set'
				)
			);
		}
		if ( !$numauth || !$numnic || ( $numnic != $numauth ) ) {
			$problems++;
		}

		if ($problems) {
			$rowtxt .= $cgi->td(
				{ -valign => 'top' },
				$cgi->table(
					{ -width => '100%', -valign => 'top' },
					$cgi->Tr(
						{
							-style =>
							  'background: orange',
							-align => 'center'
						},
						$cgi->td(
							{ -align => 'center' },
							$cgi->a(
								{
									-href =>
"./?dnsdomainid=$domid"
								},
								$zone_name
							),
							(
								( $gen eq 'Y' )
								? "(gen)"
								: ""
							)
						)
					),
					$nslist
				)
			);
			$curperrow++;
		}
	}
	print $cgi->Tr($rowtxt), "\n";
	print $cgi->end_table;
	print $cgi->end_html, "\n";

	$dbh->rollback;
	$dbh->disconnect;
	$dbh = undef;
}

sub get_jazzhands_namservers {
	my ( $stab, $zone ) = @_;
	my $cgi = $stab->cgi;
	my $dbh = $stab->dbh;

	$zone =~ s/\.+$//;

	my $q = qq{
		select  dns.dns_record_id,
				dns.dns_name,
				dns.dns_domain_id,
				dns.dns_ttl,    
				dns.dns_class,
				dns.DNS_TYPE,
				dns.dns_value,
				dns.netblock_id,
				dns.should_generate_ptr,
				nb.netblock_id,
				net_manip.inet_dbtop(nb.ip_address)
		 from   dns_domain dom
				inner join dns_record dns
					on dns.dns_domain_id = dom.dns_domain_id
				inner join val_dns_type vdt on
					dns.dns_type = vdt.dns_type
				left join netblock nb
					on nb.netblock_id = dns.netblock_id
		where   vdt.id_type in ('ID', 'NON-ID')
		  and	dns.dns_type = 'NS'
		  and   dns.dns_name is NULL
		  and   dns.reference_dns_record_id is null
		  and   dom.soa_name = ?
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($zone) || $stab->return_db_err($sth);

	my (@ns);
	while ( my $hr = $sth->fetchrow_hashref ) {
		if ( $hr->{_dbx('DNS_TYPE')} eq 'NS' ) {
			push( @ns, $hr->{_dbx('DNS_VALUE')} );
		}
	}
	$sth->finish;
	@ns;
}

sub find_ip_in_dns_packet {
	my ( $packet, $what ) = @_;

	$what =~ tr/A-Z/a-z/;
	$what =~ s/\.+$//;

	foreach my $thing ( $packet->additional ) {
		my $a = $thing->name;
		$a =~ tr/A-Z/a-z/;
		$a =~ s/\.+$//;
		if ( $a eq $what && $thing->type eq 'A' ) {
			return $thing->rdatastr;
		}
	}

	#
	# if we got here, then the authority packet had no appropriate
	# answers, so ask whomever we normally resolve to, and cross
	# fingers
	#
	my $res = Net::DNS::Resolver->new;
	my $answer = $res->query( $what, 'A' );
	foreach my $rr ( $answer->answer ) {
		if ( $rr->type eq 'A' ) {
			return $rr->rdatastr;
		}
	}
	undef;
}

sub build_dns_ask_list {
	my ($packet) = @_;

	my (@ips);

	foreach my $thing ( $packet->authority ) {
		if ( $thing->type eq 'NS' ) {
			my $ip =
			  find_ip_in_dns_packet( $packet, $thing->rdatastr );
			if ($ip) {
				push( @ips, $ip );
			}
		}
	}
	@ips;
}

sub get_nic_ns {
	my ( $zone, @ips ) = @_;

 	# should probably cache this somewhere, rather than hit it for
 	# every zone, but since its stored locally, or cached, its not
 	# that big of a deal, really...
  	if($#ips == -1) {
 		my $res = Net::DNS::Resolver->new;
 
 		my $packet = $res->send(".", "NS") || die;
 		foreach my $ans ($packet->answer) {
         		next if($ans->type ne 'NS');
         		my $i = Net::DNS::Resolver->new;
         		my $ipp = $i->send($ans->rdatastr, "A") || die;
         		foreach my $a ($ipp->answer) {
                 		if($a->type eq 'A') {
                         		push(@ips, $a->address);
                 		}
         		}
 		}
	}


	my $iterations = 0;

	my (@ns);
	do {
		my $res = Net::DNS::Resolver->new(
			nameservers => \@ips,
			recurse     => 0
		);

		my $packet = $res->send( $zone, 'NS' ) || die "no answer";

		my @authority = $packet->authority;

		$zone =~ s/\.+$//;
		$zone =~ tr/A-Z/a-z/;
		foreach my $ans ( $packet->authority ) {
			next if ( !defined($ans) );
			my $name = $ans->name;
			$name =~ s/\.+$//;
			$name =~ tr/A-Z/a-z/;
			if ( $zone eq $name && $ans->type eq 'NS' ) {
				my $x = $ans->rdatastr;
				push( @ns, $x ) if ( defined($x) );
			}
		}
		foreach my $ans ( $packet->answer ) {
			my $name = $ans->name;
			$name =~ s/\.+$//;
			$name =~ tr/A-Z/a-z/;
			if ( $zone eq $name && $ans->type eq 'NS' ) {
				my $x = $ans->rdatastr;
				push( @ns, $x ) if ( defined($x) );
			}
		}

		if ( $#ns == -1 ) {

			# go ask someone else
			my @whotoask = build_dns_ask_list($packet);
			if ( $#whotoask == -1 ) {
				return @ns;
			}
			@ips = @whotoask;
		} else {
			return (@ns);
		}
	} while ( $iterations++ < 10 );
	return @ns;
}
