#!/usr/bin/env perl
#
# Copyright (c) 2013, Todd M. Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# $Id$
#

# does an axfr of a zone and the zone into jazzhands

use warnings;
use strict;
use Net::DNS;
use JazzHands::DBI;
use NetAddr::IP;
use Getopt::Long;
use Data::Dumper;
use JazzHands::Common qw(:all);
use Carp;

exit do_zone_load();

sub get_parent_domain {
	my ($c, $zone) = @_;

	print "processing zone is $zone\n";
	my (@errs);
	while($zone =~ s/^[^\.]+\.//) {
		my $old = $c->DBFetch(
			table           => 'dns_domain',
			match           => { soa_name => $zone },
			result_set_size => 'exactlyone',
			errors          => \@errs
		);
		if($old) {
			return $old;
		}
	}
	undef;
}

#
# Given an ipv4 or ipv6 address, returns what the PTR record
# says for it.
#
sub get_inaddr {
	my $ip = shift(@_);

	my $i = new NetAddr::IP($ip) || die "Unable to parse invalid ip $ip\n";

	my @ip;
	if ( $i->version() == 4 ) {
		@ip = reverse split( /\./, $ip );
	} elsif ( $i->version() == 6 ) {
		my $i = new NetAddr::IP($ip);
		my $x = $i->full();
		$x =~ s/://g;
		@ip = reverse split( //, $x );
	} else {
		die "Unknown IP version ", $i->version();
	}

	my $inaddr = join( ".", @ip ) . ".in-addr.arpa";
	my $res    = new Net::DNS::Resolver;
	my $a      = $res->query( $inaddr, 'PTR' );

	# return the first one.  If there is more than one,
	# we will consider that broken setup.  Perhaps
	# a warning is in order here.  XXX
	return undef if ( !$a );
	foreach my $rr ( grep { $_->type eq 'PTR' } $a->answer ) {
		return $rr->ptrdname;
	}
}

sub by_name {
	if ( $a->name =~ /^\d+$/ && $b->name =~ /^\d+$/ ) {
		return ( $a->name <=> $b->name );
	} else {
		return ( $a->name cmp $b->name );
	}
}

#
# takes a nameserver and a zone, gets the SOA record for that zone and
# makes sure the database matches for all the SOA vaules
#
sub freshen_zone {
	my ( $c, $ns, $zone, $dom ) = @_;

	my $numchanges = 0;

	my $res = new Net::DNS::Resolver;
	$res->nameservers($ns);

	my $answer = $res->query( $zone, 'SOA' ) || return undef;    # XXX

	foreach my $rr ( grep { $_->type eq 'SOA' } $answer->answer ) {
		next if ( $rr->name ne $zone );
		my @errs;
		my $old = $c->DBFetch(
			table           => 'dns_domain',
			match           => { soa_name => $zone },
			result_set_size => 'exactlyone',
			errors          => \@errs
		);

		if ( !$old ) {
			if ( $c->DBHandle->err ) {
				die "$zone: ", join( " ", @errs );
			}
		}

		my $domid = ($old) ? $old->{dns_domain_id} : undef;

		# should only be one SOA record, but just in case...
		my $new = {
			dns_domain_id => $domid,
			soa_name      => $zone,
			soa_class     => $rr->class,
			soa_ttl       => $rr->ttl,
			soa_serial    => $rr->serial,
			soa_refresh   => $rr->refresh,
			soa_retry     => $rr->retry,
			soa_expire    => $rr->expire,
			soa_minimum   => $rr->minimum,
			soa_mname     => $rr->mname,
			soa_rname     => $rr->rname,
		};

		my $parent;
		if($parent = get_parent_domain($c, $zone) ) {
			$new->{parent_dns_domain_id} = $parent->{dns_domain_id};
		}

		# XXX needs to be fixed!
		# This should be a bigint now, so this needs to be tested and this code can be removed.
		#if ( $new->{soa_serial} > 2147483647 ) {
		#	$new->{soa_serial} = 2147483646;
		#}
		if ($old) {
			my $diff = $c->hash_table_diff( $old, $new );
			if ( scalar %$diff ) {
				$numchanges += $c->DBUpdate(
					table  => 'dns_domain',
					dbkey  => 'dns_domain_id',
					keyval => $domid,
					hash   => $diff,
					errs   => \@errs,
				) || die join( " ", @errs );
			}
			$$dom = $new;
		} else {
			delete( $new->{dns_domain_id} );
			$new->{should_generate} = 'N';
			$new->{dns_domain_type} = 'service';    # XXX
			$numchanges += $c->DBInsert(
				table => 'dns_domain',
				hash  => $new,
				errrs => \@errs,
			) || die join( " ", @errs );
			$$dom = $new;
		}

		if($parent) {
			# In our parent, if there are any NS record for us, they
			# should be deleted, because Zone Generaion will DTRT with
			# delegation
			my $shortname = $zone;
			$shortname =~ s/.$parent->{soa_name}$//;
			foreach my $z (@{$c->DBFetch(
					table           => 'dns_record',
					match           => { 
										dns_domain_id => $parent->{dns_domain_id},
										dns_type => 'NS',
										dns_name => $shortname,
									},
					errors          => \@errs
			)}) {
				warn "deleting ns record ", $z->{dns_record_id};
				my $ret = 0;
				if(! ($ret = $c->DBDelete(
						table	=> 'dns_record',
						dbkey	=> 'dns_record_id',
						keyval	=> $z->{dns_record_id},
						errors	=> \@errs,
				))) {
					die "Error deleting record ", join(" ", @errs), ": ", Dumper($z);
				}
				$numchanges += $ret;
			}
		}

		my $lineage = $zone;
		$lineage =~ s/^[^\.]+\././;
		foreach my $z (@{$c->DBFetch(
					table => 'dns_domain',
					match => [
						{	key => 'soa_name',
							value => $lineage,
							matchtype => 'like',
						}
					],
					errors	=> \@errs,
				)}) {
				warn Dumper($z);
			if(!defined($z->{parent_dns_domain_id}) || $z->{parent_dns_domain_id} != $new->{dns_domain_id}) {
				if($c->{verbose}) {
					warn "updating ", $z->{soa_name}, " to have parent of ", $new->{soa_name}, "\n";
				}
				$numchanges += $c->DBUpdate(
					table  => 'dns_domain',
					dbkey  => 'dns_domain_id',
					keyval => $z->{dns_domain_id},
					hash   => {
							parent_dns_domain_id => $new->{dns_domain_id},
					},
					errs   => \@errs,
				) || die join( " ", @errs );
			}
		}

		# XXX rehome children appropriately

		# XXX need to deal with rehoming subzones and homing this zone to parent
	}

	$numchanges;
}

sub build_match_entry {
	my $in = shift @_;

	my $match;
	foreach my $k ( sort keys %$in ) {
		my $x = {
			'key'   => $k,
			'value' => $in->{$k},
		};
		push( @{$match}, $x );
	}
	$match;
}

sub refresh_dns_record {
	my $opt = _options(@_);

	my $numchanges = 0E0;

	my $c            = $opt->{handle};
	my $name         = $opt->{name};
	my $address      = $opt->{address};
	my $value        = $opt->{value};
	my $priority     = $opt->{priority};
	my $srv_service  = $opt->{srv_service};
	my $srv_protocol = $opt->{srv_protocol};
	my $srv_weight   = $opt->{srv_weight};
	my $srv_port     = $opt->{srv_port};
	my $genptr       = $opt->{genptr};

	my $nb;
	my @errs;
	if ( defined($address) ) {
		warn "Attempting to find $address... \n" if ( $c->{verbose} );
		my $match = {
			'is_single_address' => 'Y',
			'netblock_type'     => 'default',
			'ip_universe_id'    => 0,
			'host(ip_address)'  => $address
		};
		$nb = $c->DBFetch(
			table           => 'netblock',
			match           => $match,
			errors          => \@errs,
			result_set_size => 'first',
		);
		$c->dbh->err && die join( " ", @errs );

		# If there was not a type default, check for one
		# that is just there for DNS.
		if ( !$nb ) {
			$match->{netblock_type} = 'dns';
			$nb = $c->DBFetch(
				table           => 'netblock',
				match           => $match,
				errors          => \@errs,
				result_set_size => 'first',
			);
			$c->dbh->err && die join( " ", @errs );
		}

		if ( !$nb ) {
			if ( defined( $c->{nbrule} ) && $c->{nbrule} eq 'skip' )
			{
				warn
"$name ($address) - Netblock not found.  Skipping.\n";
				return 0;
			} else {
				warn
"$name ($address) - Netblock not found.  Creating.\n";
			}

			$nb = {
				ip_address        => $address,
				netblock_type     => 'default',
				is_single_address => 'Y',
				can_subnet        => 'N',
				netblock_status   => 'Allocated',
				ip_universe_id    => 0,
				is_ipv4_address   => ( $opt->{dns_type} eq 'A' )
				? 'Y'
				: 'N',
			};
			$c->dbh->do("SAVEPOINT biteme");
			my $x = $c->DBInsert(
				table => 'netblock',
				hash  => $nb,
				errs  => \@errs,
			);
			if ( !$x ) {
				if ( $c->dbh->err == 7 ) {
					$c->dbh->do(
						"ROLLBACK TO SAVEPOINT biteme");
					if ( defined( $c->{nbrule} )
						&& $c->{nbrule} eq 'iponly' )
					{
						warn "\tskipping ...",
						  join( " ", @errs );
						return;
					} else {
						$nb->{netblock_type} = 'dns';
						$nb->{netmask_bits}  = 32;
						my $x = $c->DBInsert(
							table => 'netblock',
							hash  => $nb,
							errrs => \@errs,
						  )
						  || die "$address: [",
						  $c->dbh->err, "] ",
						  join( " ", @errs );
					}
				} else {
					die "$address: [", $c->dbh->err, "] ",
					  join( " ", @errs );
				}
				$c->dbh->do("RELEASE SAVEPOINT biteme");
			} else {
				$numchanges += $x;
			}
		}

	}

	my $match = {
		dns_name    => $name,
		dns_value   => $value,
		dns_domain_id	=> $opt->{dns_domain_id},
		netblock_id => ($nb) ? $nb->{netblock_id} : undef,
	};
	my $rows = $c->DBFetch(
		table  => 'dns_record',
		match  => $match,
		errors => \@errs,
	) || die join( " ", @errs );

	my $dnsrec = $rows->[0];

	my $new = {
		'dns_name'                => $name,
		'dns_domain_id'           => $opt->{dns_domain_id},
		'dns_ttl'                 => $opt->{ttl},
		'dns_class'               => $opt->{dns_class},
		'dns_type'                => $opt->{dns_type},
		'dns_value'               => $value,
		'dns_priority'            => $priority,
		'dns_srv_service'         => $srv_service,
		'dns_srv_protocol'        => $srv_protocol,
		'dns_srv_weight'          => $srv_weight,
		'dns_srv_port'            => $srv_port,
		'netblock_id'             => ($nb) ? $nb->{netblock_id} : undef,
		'reference_dns_record_id' => $opt->{reference_dns_record_id},
		'dns_value_record_id'     => $opt->{dns_value_record_id},
		'should_generate_ptr'     => $genptr,
		'is_enabled'              => 'Y',
	};

	my $dnsrecid;
	if ($dnsrec) {
		# Find if there is a dns record associated with this record
		$dnsrecid = $dnsrec->{dns_record_id};
		my $diff = $c->hash_table_diff( $dnsrec, $new );
		if ( scalar %$diff ) {
			$numchanges += $c->DBUpdate(
				table  => 'dns_record',
				dbkey  => 'dns_record_id',
				keyval => $dnsrec->{dns_record_id},
				hash   => $diff,
				errs   => \@errs,
			) || die join( " ", @errs );
		}
	} else {
		$numchanges += $c->DBInsert(
			table => 'dns_record',
			hash  => $new,
			errrs => \@errs,
		) || die join( " ", @errs );
		$dnsrecid = $new->{dns_record_id};
	}

	$numchanges;
}

sub process_zone {
	my ( $c, $ns, $xferzone ) = @_;

	my $numchanges = 0;

	my $dom;
	my $r = freshen_zone( $c, $ns, $xferzone, \$dom );
	if(defined($r)) {
		$numchanges += $r;
	}

#return undef;

	my $domid = $dom->{dns_domain_id};

	my $res = new Net::DNS::Resolver;
	$res->nameservers($ns);

	my @zone = $res->axfr($xferzone);
	if ( $#zone == -1 ) {
		return undef;
	}

#
# XXX - First go through the zone and find things that are not there that should be
	my $numrec = 0;
	foreach my $rr ( sort by_name @zone ) {

		# warn "CONSIDER ", $rr->print;
		my $name = $rr->name;
		if ( $name eq $dom->{soa_name} ) {
			$name = undef;
		} else {
			$name =~ s/\.$dom->{soa_name}$//;
		}

		$numrec++;
		my $new = {
			handle        => $c,
			domain        => $xferzone,
			name          => $name,
			dns_domain_id => $domid,
			dns_type      => $rr->type,
			dns_class     => $rr->class,
			dns_ttl =>
			  ( $rr->ttl == $dom->{soa_ttl} ? undef : $rr->ttl ),
			genptr => 'N',
		};
		if ( $rr->type eq 'PTR' ) {
			$new->{value} = $rr->ptrdname;
		} elsif ( $rr->type eq 'A' || $rr->type eq 'AAAA' ) {
			my $ptr = get_inaddr( $rr->address );

			next if $rr->address eq '8.12.229.167';

			$new->{address} = $rr->address;
			$new->{genptr} =
			  ( defined($ptr) && $ptr eq $rr->name ) ? 'Y' : 'N';
		} elsif ( $rr->type eq 'MX' ) {
			$new->{priority} = $rr->preference;
			$new->{value}    = $rr->exchange;
		} elsif ( $rr->type eq 'CNAME' ) {
			$new->{value} = $rr->cname;
		} elsif ( $rr->type eq 'DNAME' ) {
			$new->{value} = $rr->dname;
		} elsif ( $rr->type eq 'SRV' ) {

			# $msg .= check_srv($c, $rr, $zone);
		} elsif ( $rr->type eq 'TXT' || $rr->type eq 'SPF' ) {
			$new->{value} = $rr->txtdata;
		} elsif ( $rr->type eq 'NS' ) {
			# XXX may want to consider this check to be optional.
			if(defined($name) && length($name)) {
				my @errs;
				my $count = $c->DBFetch(
					table           => 'dns_domain',
					match           => { soa_name => $rr->name },
					result_set_size => 'exactlyone',
					errors          => \@errs
				);
				if($count) {
					warn "Skipping subzone NS records for $name (", $rr->nsdname, ")\n";
					next;
				}
			}
			$new->{value} = $rr->nsdname;
		} elsif ( $rr->type =~ /^AFSDB$/ ) {
			$new->{value} = $rr->subtype;
		} elsif ( $rr->type eq 'SSHFP' ) {
			warn "record type ", $rr->type, " unsupported\n";
			next;
		} elsif ( $rr->type eq 'TLSA' ) {
			warn "record type ", $rr->type, " unsupported\n";
			next;
		} elsif ( $rr->type =~
			/^(APL|CAA|CERT|DHCID|HIP|IPSECKEY|LOC|NAPTR)/ )
		{
			warn "record type ", $rr->type, " unsupported\n";
			next;
		} elsif ( $rr->type =~
/^(CLV|DNAME|DNSKEY|DS|KEY|KX|NSEC|NSEC3.*|RRSIG|RP|SIG|TA|TKEY|TSIG)$/
		  )
		{
			warn "DNSSEC record type ", $rr->type, " unsupported\n";
			next;
		} elsif ( $rr->type eq 'SOA' ) {
			next;
		} else {
			warn "Unable to process record for ", $rr->name, " -- ",
			  $rr->type, "\n";
			next;
		}
		# for record that point elsewhere, make sure they are dot terminated
		# should that be necessary.  Some are probably missing.
		if($rr->type =~ /^(CNAME|SRV|NS|MX|DNAME)/) {
			if($new->{value} !~ s/\.$xferzone$//) {
				$new->{value} .= ".";
			}
		}
		if ( defined( my $nr = refresh_dns_record($new) ) ) {
			$numchanges += $nr;
		}
	}

#
# XXX - now go through the zone and find things that are there that should not be.
#
	return $numchanges;
}

sub process_db {
	my ( $c, $zone ) = @_;

	my @errs;
	my $rows = $c->DBFetch(
		table           => 'dns_domain',
		match           => { soa_name => $zone, },
		result_set_size => 'exactlyone',
		errors          => \@errs,
	) || die join( " ", @errs );
}

#############################################################################

sub do_zone_load {
	my $app    = 'zoneimport';
	my $nbrule = 'skip';
	my ( $ns, $verbose );

	my $r = GetOptions(
		"verbose"             => \$verbose,
		"dbapp=s"             => \$app,
		"nameserver=s"        => \$ns,
		"unknown-netblocks=s" => \$nbrule,
	) || die "Issues";

	if ( defined($nbrule) ) {
		die "--unknown-netblocks can be skip, insert, iponly\n"
		  if (     $nbrule ne 'skip'
			&& $nbrule ne 'insert'
			&& $nbrule ne 'iponly' );
	}

	my $dbh = JazzHands::DBI->connect( $app, { AutoCommit => 0 } )
	  || die $JazzHands::DBI::errstr;
	my $c = new JazzHands::Common;
	$c->DBHandle($dbh);

	$c->{nbrule}  = $nbrule;
	$c->{verbose} = $verbose;

	foreach my $zone (@ARGV) {
		warn "Processing zone $zone...\n";
		if ($ns) {
			process_zone( $c, $ns, $zone );
			process_db( $c, $zone );
		} else {
			my $res = new Net::DNS::Resolver;
			my $resp = $res->query( $zone, 'NS' );
			if ( !$resp ) {
				die
"Unable to find name servers for $zone.  Aborting.\n";
			}
			foreach
			  my $rr ( grep { $_->type eq 'NS' } $resp->answer )
			{
				my $ns = $rr->nsdname;
				warn "consdering $ns\n";
				my $numchanges = process_zone( $c, $ns, $zone );
				if ( !defined($numchanges) ) {
					next;
				}
				warn "updated $numchanges records\n";
				process_db( $c, $zone );
				last;
			}
		}
	}

	$dbh->commit;
	$dbh->disconnect;
}
