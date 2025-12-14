#!/usr/bin/env perl
#
# Copyright (c) 2019 Todd Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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

#
# $Id$
#

use strict;
use warnings;
use POSIX;
use JazzHands::STAB;
use Net::DNS;
use Data::Dumper;

do_soacheck();

sub lower {
	my $x = shift(@_);

	$x =~ tr/A-Z/a-z/;
	$x;
}

sub do_soacheck {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	dump_soacheck_all($stab);
	undef $stab;
}

sub dump_soacheck_all {
	my ($stab) = @_;
	my $cgi    = $stab->cgi;
	my $dbh    = $stab->dbh;

	my $showall   = $stab->cgi_parse_param('showall')   || 'no';
	my $nogenshow = $stab->cgi_parse_param('nogenshow') || 'all';

	print $cgi->header(      { -type  => 'text/html' } ),              "\n";
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
		  from	v_dns_domain_nouniverse dom
			left join (
				SELECT * FROM dns_record
				WHERE dns_type = 'REVERSE_ZONE_BLOCK_PTR'
				) dns USING (dns_domain_id)
			left join netblock nb USING (netblock_id)
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
	$sth->execute                || return $stab->return_db_err($sth);

	my $maxperrow = 3;

	print $cgi->start_table( { -class => 'nic-database-container' } ), "\n";

	my $curperrow = 0;
	my $rowtxt    = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		if ( $curperrow == $maxperrow ) {
			$curperrow = 0;
			print $cgi->Tr($rowtxt), "\n";
			$rowtxt = "";
		}

		my $zone_name = $hr->{'SOA_NAME'};
		my $domid     = $hr->{'DNS_DOMAIN_ID'};
		my $gen       = $hr->{'SHOULD_GENERATE'};

		if (   $nogenshow eq 'no'
			&& $hr->{'SHOULD_GENERATE'} eq 'N' )
		{
			next;
		}

		if (   $nogenshow eq 'yes'
			&& $hr->{'SHOULD_GENERATE'} eq 'Y' )
		{
			next;
		}

		my @jazzhands = get_jazzhands_namservers( $stab, $zone_name );

		# Remove the trailing dot from all the result
		@jazzhands = map { s/\.$//; $_ } @jazzhands;
		my @nic = get_nic_ns($zone_name);

		my $problems = 0;
		my $numauth  = 0;
		my $numnic   = 0;

		my $nslist = $cgi->Tr( $cgi->td( { -align => 'center' }, "NIC" ) );

		if ( $#nic > -1 ) {
			foreach my $ns ( sort @nic ) {
				if ( $#jazzhands > -1
					&& grep( lower($_) eq lower($ns), @jazzhands ) )
				{
					$nslist .= $cgi->Tr( $cgi->td($ns) );
				} else {
					$nslist .=
					  $cgi->Tr( $cgi->td( { -class => 'mismatch' }, $ns ) );
					$problems++;
				}
			}
			$numnic++;

		} else {
			$nslist .= $cgi->Tr(
				$cgi->td( { -class => 'missing' }, 'none registered' ) );
		}

		$nslist .= $cgi->Tr( $cgi->td( { -align => 'center' }, "DB" ) );

		if ( $#jazzhands > -1 ) {
			foreach my $ns ( sort @jazzhands ) {
				if ( $#nic > -1
					&& grep( lower($_) eq lower($ns), @nic ) )
				{
					$nslist .= $cgi->Tr( $cgi->td($ns) );
				} else {
					$nslist .=
					  $cgi->Tr( $cgi->td( { -class => 'mismatch' }, $ns ) );
					$problems++;
				}
			}
			$numauth++;

		} else {
			$nslist .=
			  $cgi->Tr( $cgi->td( { -class => 'missing' }, 'none set' ) );
		}

		if ( !$numauth || !$numnic || ( $numnic != $numauth ) ) {
			$problems++;
		}

		if ( $problems || $showall eq 'yes' ) {
			$rowtxt .= $cgi->td( $cgi->table(
				{ -class => 'nic-database' },
				$cgi->Tr( $cgi->th(
					$cgi->a( {
							-href => "./?dnsdomainid=$domid"
						},
						$zone_name
					),
					( ( $gen eq 'Y' ) ? "(gen)" : "" )
				) ),
				$nslist
			) );
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
				CASE WHEN dns.dns_value LIKE '%.' THEN dns.dns_value
					ELSE concat(dns_value, '.', dns_domain_name, '.')
					END AS dns_value,
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
	$sth->execute($zone)         || $stab->return_db_err($sth);

	my (@ns);
	while ( my $hr = $sth->fetchrow_hashref ) {
		if ( $hr->{'DNS_TYPE'} eq 'NS' ) {
			push( @ns, $hr->{'DNS_VALUE'} );
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
	if ( my $answer = $res->query( $what, 'A' ) ) {
		foreach my $rr ( $answer->answer ) {
			if ( $rr->type eq 'A' ) {
				return $rr->rdatastr;
			}
		}
	}
	undef;
}

sub build_dns_ask_list {
	my ($packet) = @_;

	my (@ips);

	foreach my $thing ( $packet->authority ) {
		if ( $thing->type eq 'NS' ) {
			my $ip = find_ip_in_dns_packet( $packet, $thing->rdatastr );
			if ($ip) {
				push( @ips, $ip );
			}
		}
	}

	foreach my $thing ( $packet->answer ) {
		if ( $thing->type eq 'NS' ) {
			my $ip = find_ip_in_dns_packet( $packet, $thing->rdatastr );
			if ($ip) {
				push( @ips, $ip );
			}
		}
	}

	@ips;
}

#
# walks from the roots and keeps going until it gets to one of the ones ina
# jazzhands list.  This isn't truly "nic" since someone else may delegate to
# us but be the delegation from the root.
#
sub get_nic_ns {
	my ( $zone, @ips ) = @_;

	# should probably cache this somewhere, rather than hit it for
	# every zone, but since its stored locally, or cached, its not
	# that big of a deal, really...
	if ( $#ips == -1 ) {
		my $res = Net::DNS::Resolver->new();

		my $packet = $res->send( "$zone", "NS" ) || die;
		foreach my $ans ( $packet->answer ) {
			next if ( $ans->type ne 'NS' );
			push( @ips, $ans->nsdname );

			#my $i = Net::DNS::Resolver->new();
			#my $ipp = $i->send( $ans->rdatastr, "A" ) || die;
			#foreach my $a ( $ipp->answer ) {
			#	if ( $a->type eq 'A' ) {
			#		#push( @ips, $a->address );
			#	}
			#}
		}

		return @ips;
	}

	#
	# $niconly probably wants to become an option.  It controls if we keep
	# drilling down until we get to the end or stop when we get the first
	# answer.  This distinction is most useful for in-addr or if it's just
	# delegated off elsewhere.
	#
	my $niconly    = 0;
	my $iterations = 0;
	my @nsoflastresort;
	while ( $iterations++ <= 10 ) {
		my @ns;
		my $res = Net::DNS::Resolver->new(
			nameservers => \@ips,
			recurse     => 0
		);

		my $packet = $res->send( $zone, 'NS' );
		if ( !$packet ) {
			return @nsoflastresort;
		}

		# print "<pre>", join(", ", @ips), ": ", $packet->string, "</pre><hr>\n";
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

		#
		# at this point, @ns contains a list of nameservers that
		# came back in either ANSWER or AUTH that match the name of
		# the zone.  This may actually keep going (this is the nic
		# vs all the way down case).  In that case, check to see if
		# any of them match what we talked to.  If not, then check to
		# see if this is the same set as the last ones we got.  If
		# we did then there is probably some sort of name mismatch,
		# so stop.
		#

		#
		# based on this packet, figure out who to ask next.  This should be
		# the same set of people we asked.
		my @whotoask = build_dns_ask_list($packet);
		if ( !$niconly ) {
			#
			# case when we keep drilling down even after the first match
			#
			if ($#ns) {
				foreach my $ip (@whotoask) {

					# in this case, we were told to talk to one of the things
					# that were previous told, so we're done walking.
					if ( grep( $ip eq $_, @ips ) ) {
						return (@ns);
					}
				}
			}

			if ( $#whotoask == -1 ) {
				#
				# check to see if any of the things we were going to
				# return is one of the ones in the last.  If not, bail and
				# return the last one we saw.  I'm not sure if this
				# is correct.
				#
				my $ok = 0;
			  NSCHECK:
				foreach my $ns (@ns) {
					my $i   = Net::DNS::Resolver->new;
					my $ipp = $i->send( $ns, "A" ) || die;
					foreach my $a ( $ipp->answer ) {
						if ( $a->type eq 'A' ) {
							warn "compare $ns ", $a->address, " ",
							  $packet->answerfrom;
							if ( $a->address eq $packet->answerfrom ) {
								$ok = 1;
								last NSCHECK;
							}
						}
					}
				}
				if ($ok) {
					return (@ns);
				} else {
					return (@nsoflastresort);
				}
			}
			@ips            = @whotoask;
			@nsoflastresort = @ns;
		} else {
			#
			# case when we stop at the first match down from root
			#
			if ( $#ns == -1 ) {
				if ( $#whotoask == -1 ) {
					return @ns;
				}
				@ips = @whotoask;
			} else {
				return (@ns);
			}
		}
	}

	return @nsoflastresort;
}
