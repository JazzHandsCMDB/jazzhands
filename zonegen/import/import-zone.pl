#!/usr/bin/env perl
#
# Copyright (c) 2013-2017, Todd M. Kover
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
use Getopt::Long;

package ZoneImportWorker;

use Net::DNS;
use JazzHands::DBI;
use Net::IP;    # Just for reverse DNS-type operations
use NetAddr::IP qw(:lower);
use Data::Dumper;
use JazzHands::Common qw(:all);
use Carp;
use parent 'JazzHands::Common';

# local $SIG{__WARN__} = \&Carp::cluck;

our $errstr;

sub DESTROY {
	my $self = shift @_;
	my $ac   = $self->{_dbh}->{AutoCommit};

	$self->rollback if ( !$ac );
	$self->disconnect;
}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	my $self = $class->SUPER::new(@_);

	$self->{_dbuser} = $opt->{dbuser} || 'zoneimport';

	$self->{_debug} = defined( $opt->{debug} ) ? $opt->{debug} : 0;

	my $dbh = JazzHands::DBI->connect( $self->{_dbuser},
		{ AutoCommit => 0, RaiseError => 0 } );
	if ( !$dbh ) {
		$errstr =
		  "Unable to connect to $self->{_dbuser}: " . $JazzHands::DBI::errstr;
		return undef;
	}

	$self->DBHandle($dbh);
	$self;

}

sub find_universe {
	my ( $self, $u ) = @_;

	return 0 if ( !$u );

	return undef if ( $u eq 'none' );

	return $u if ( $u =~ /^\d+$/ );

	my (@errs);
	my $dbrec;
	if (
		$dbrec = $self->DBFetch(
			table => 'ip_universe',
			match => {
				ip_universe_name => $u,
			},
			result_set_size => 'first',
			errors          => \@errs
		)
	  )
	{
		return $dbrec->{ip_universe_id};
	}
	$self->dbh->err && die join( " ", @errs );

	die "Unable to find universe $u";
}

#
# should probably by looked into how to do DBFetch with >=
#
# NOTE: If multiple ip universes are specified, need to try really hard to
# not mess it up.  If one is specified in the class (essentially via the command
# line, and there's a dup, the one from the universe on the command line wins,
# otherwise its not well defined; generally assumes the invoker knows WTF they
# are doing.
#
sub pull_universes($) {
	my ($self) = @_;

	my $dbh = $self->DBHandle();

	my $sth = $dbh->prepare_cached(
		qq{
		SELECT	ip_address, masklen(ip_address), ip_universe_id
		FROM	netblock
		WHERE	ip_universe_id IS NOT NULL
		AND		netblock_type = 'default'
		AND		parent_netblock_id is NULL
	}
	) || die $dbh->errstr;

	$sth->execute || die $sth->errstr;

	$self->{_universemap} = {};
	while ( my ( $ip, $cidr, $u ) = $sth->fetchrow_array ) {
		if ( exists( $self->{alloweduniverses} ) ) {

			# skip unallowed universes
			next if !( grep { $u == $_ } @{ $self->{alloweduniverses} } );
		}
		if ( exists( $self->{_universemap}->{$ip} ) && $self->{ip_universe} ) {
			if ( $u != $self->{ip_universe} ) {
				next;
			}
		}
		$self->{_universemap}->{$ip}->{universeid} = $u;
		$self->{_universemap}->{$ip}->{cidr}       = $cidr;
	}
	$self->{_universemap};
}

#
# picks the best universe for the IP.  If its in the internet universe (0),
# then favor that, otherwise rifle through the list fetched on creation and
# find the right one.
#
sub get_universe($$) {
	my ( $self, $ip ) = @_;

	if ( !$self->{_universemap} ) {
		return $self->{ip_universe};
	}

	my $dbh = $self->DBHandle();

	{
		my $sth = $dbh->prepare_cached(
			qq{
			select netblock_utils.find_best_parent_id(
				in_ipaddress := ?,
				in_ip_universe_id := 0,
				in_is_single_address := 'Y'
			), family(?);
		}
		) || die $dbh->errstr;

		$sth->execute( $ip, $ip ) || die $sth->errstr;

		my ( $id, $fam ) = $sth->fetchrow_array;
		$sth->finish;

		if ( $fam == 6 && defined( $self->{v6_universe} ) ) {
			return $self->{v6_universe};
		}
		return 0 if ($id);
	}

	foreach my $blk (
		sort {
			$self->{_universemap}->{$b}->{cidr}
			  <=> $self->{_universemap}->{$a}->{cidr}
		} keys %{ $self->{_universemap} }
	  )
	{
		$self->_Debug( 10, "get_universe:  look in %s for %s", $blk, $ip );
		my $n = $self->{_universemap}->{$blk}->{naddr};
		if ( !$n ) {
			$n = $self->{_universemap}->{$blk}->{naddr} = new NetAddr::IP($blk)
			  || die;
		}
		my $nip = new NetAddr::IP($ip) || die;
		if ( $n->contains($nip) ) {
			return $self->{_universemap}->{$blk}->{universeid};
		}
	}

	$self->{ip_universe};
}

sub check_and_add_service {
	my ( $self, $service ) = @_;

	my (@errs);
	my $dbrec;
	if (
		$dbrec = $self->DBFetch(
			table => 'val_dns_srv_service',
			match => {
				dns_srv_service => $service,
			},
			result_set_size => 'first',
			errors          => \@errs
		)
	  )
	{
		return 0;
	}
	$self->dbh->err && die join( " ", @errs );

	if ($dbrec) {
		return;
	}
	if ( !$self->{addservice} ) {
		die "$service not in DB, can not add record\n";
	}
	$self->DBInsert(
		table => 'val_dns_srv_service',
		hash  => {
			dns_srv_service => $service
		},
		errs => \@errs,
	) || die join( " ", @errs );
}

sub link_inaddr {
	my ( $self, $domid, $block ) = @_;

	my $universe = $self->get_universe($block);
	if ( !defined($universe) ) {
		$universe = $self->{ip_universe};
	}

	my (@errs);
	if (
		my $dbrec = $self->DBFetch(
			table => 'dns_record',
			match => {
				dns_domain_id  => $domid,
				dns_type       => 'REVERSE_ZONE_BLOCK_PTR',
				ip_universe_id => $universe,
			},
			result_set_size => 'first',
			errors          => \@errs
		)
	  )
	{
		return 0;
	}

	my $nblk = $self->DBFetch(
		table           => 'netblock',
		match           => { ip_address => $block, netblock_type => 'dns' },
		errors          => \@errs,
		result_set_size => 'first',
	);
	$self->dbh->err && die join( " ", @errs );

	if ( !$nblk ) {
		$nblk = {
			ip_address        => $block,
			netblock_type     => 'dns',
			is_single_address => 'N',
			can_subnet        => 'N',
			netblock_status   => 'Allocated',
			ip_universe_id    => $universe,
		};
		$self->DBInsert(
			table => 'netblock',
			hash  => $nblk,
			errs  => \@errs,
		) || die join( " ", @errs );
	}

	my $dns = {
		dns_domain_id  => $domid,
		dns_class      => 'IN',
		dns_type       => 'REVERSE_ZONE_BLOCK_PTR',
		ip_universe_id => $universe,
		netblock_id    => $nblk->{netblock_id},
	};
	$self->DBInsert(
		table => 'dns_record',
		hash  => $dns,
		,,,
		errs => \@errs,
	) || die join( " ", @errs );
	1;
}

#
# given an IP, returns the forward record that defines that
# PTR record, traversing CNAMEs and what not.
#
sub get_ptr {
	my ( $self, $ip ) = @_;

	$self->_Debug( 2, "looking for PTR for $ip" );

	my $universe = $self->get_universe($ip);
	if ( !defined($universe) ) {
		$universe = $self->{ip_universe};
	}
	$self->_Debug( 3, "Guessed Universe %d", $universe );

	my (@errs);
	my $nblk = $self->DBFetch(
		table => 'netblock',
		match => {
			'is_single_address'      => 'Y',
			'netblock_type'          => 'default',
			'ip_universe_id'         => $universe,
			'host(ip_address)::inet' => $ip
		},
		result_set_size => 'first',
		errors          => \@errs
	);
	return undef if !$nblk;

	my $dns = $self->DBFetch(
		table => 'dns_record',
		match => {
			netblock_id         => $nblk->{netblock_id},
			should_generate_ptr => 'Y',
		},
		result_set_size => 'first',
		errors          => \@errs
	);
	return undef if !$dns;

	my $dom = $self->DBFetch(
		table => 'dns_domain',
		match => {
			dns_domain_id => $dns->{dns_domain_id},
		},
		result_set_size => 'exactlyone',
		errors          => \@errs
	) || die "$ip: ", join( ",", @errs );

	if ( defined( $dns->{dns_name} ) ) {
		return join( ".", $dns->{dns_name}, $dom->{soa_name} );
	} else {
		return $dom->{soa_name};
	}
	undef;
}

sub get_parent_domain {
	my ( $self, $zone ) = @_;

	# print "processing zone is $zone\n";
	my (@errs);
	while ( $zone =~ s/^[^\.]+\.// ) {
		my $old = $self->DBFetch(
			table           => 'dns_domain',
			match           => { soa_name => $zone },
			result_set_size => 'exactlyone',
			errors          => \@errs
		);
		if ($old) {
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
	my $self = shift(@_);
	my $ip   = shift(@_);

	$self->_Debug( 3, "get_inaddr($ip)..." );

	my $ii = new Net::IP($ip) || die "Parse($ip): " . Net::IP::Error();
	my $inaddr = $ii->reverse_ip();

	my $res = new Net::DNS::Resolver();
	#
	# There is no guarantee that the auth server that hosts a fwd zone also
	# hosts the in-addr zone, so this extra hoop jumping.
	#
	$res->nameserver( $self->{nameserver} ) if ( $self->{nameserver} );
	my $a = $res->send( $ip, 'PTR' );

	if ( !$a || !scalar $a->answer ) {

		# reset with no nameserver
		$res = new Net::DNS::Resolver;
		$a = $res->send( $inaddr, 'PTR' );
	}

	# deal with the case of there being a cname.
	if ( !$a || !scalar $a->answer || !grep { $_->type eq 'PTR' } $a->answer ) {

		# to reset the nameservers, which is potentially needed to traverse
		# CNAMEs, which the AUTH server may not actually  have.
		# XXX - this will almost certainly have issue where switching BACK
		# to the auth nameserver is required to deal with cases where its not
		# 'internet resolvable'f rom the main host.
		my $res = new Net::DNS::Resolver;
		my $qn  = $inaddr;
		do {
			$a = $res->send( $qn, 'CNAME' );
			$self->_Debug( 4, "consider [%s] %s ..  ", $qn, scalar $a->answer );
			if ($a) {
				foreach my $rr ( grep { $_->type eq 'CNAME' } $a->answer ) {
					$qn = $rr->cname;
					last;
				}
			}
		} while ( $a && scalar $a->answer );

		$a = $res->send( $qn, 'PTR' );
	}

	# return the first one.  If there is more than one,
	# we will consider that broken setup.  Perhaps
	# a warning is in order here.  XXX
	if ( !$a || !scalar $a->answer ) {
		$self->_Debug( 3, "no answer: %s", $res->errorstring );
		return undef;
	}
	foreach my $rr ( grep { $_->type eq 'PTR' } $a->answer ) {
		$self->_Debug( 3, "Returning: %s", $rr->ptrdname );
		return $rr->ptrdname;
	}
	$self->_Debug( 3, "Returning nothing" );
	undef;
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
	my ( $self, $ns, $zone, $dom ) = @_;

	my $numchanges = 0;

	my $res = new Net::DNS::Resolver;
	$res->nameservers($ns);

	my $answer = $res->query( $zone, 'SOA' ) || return undef;    # XXX

	foreach my $rr ( grep { $_->type eq 'SOA' } $answer->answer ) {
		next if ( $rr->name ne $zone );
		my @errs;
		my $olddom = $self->DBFetch(
			table           => 'dns_domain',
			match           => { soa_name => $zone },
			result_set_size => 'exactlyone',
			errors          => \@errs
		);

		my $parent;
		$parent = get_parent_domain( $self, $zone );

		if ( !$olddom ) {
			if ( $self->DBHandle->err ) {
				die "$zone: ", join( " ", @errs );
			}

			my $new = {
				soa_name        => $zone,
				dns_domain_type => 'service',    # XXX
			};
			if ($parent) {
				$new->{parent_dns_domain_id} = $parent->{dns_domain_id};
			}

			$numchanges += $self->DBInsert(
				table => 'dns_domain',
				hash  => $new,
				errrs => \@errs,
			) || die join( " ", @errs );
			$$dom = $new;
		} else {
			$$dom = $olddom;
		}

		my $domid = ${$dom}->{dns_domain_id};

		# should only be one SOA record, but just in case...
		my $newdom = {
			dns_domain_id => $domid,
			soa_name      => $zone,
		};

		my $newzone = {
			dns_domain_id  => $domid,
			ip_universe_id => $self->{ip_universe},
			soa_class      => $rr->class,
			soa_ttl        => $rr->ttl,
			soa_serial     => $rr->serial,
			soa_refresh    => $rr->refresh,
			soa_retry      => $rr->retry,
			soa_expire     => $rr->expire,
			soa_minimum    => $rr->minimum,
			soa_mname      => $rr->mname,
			soa_rname      => $rr->rname,
		};

		my $oldzone = $self->DBFetch(
			table => 'dns_domain_ip_universe',
			match => {
				'dns_domain_id'  => $domid,
				'ip_universe_id' => $self->{ip_universe},
			},
			result_set_size => 'exactlyone',
			errors          => \@errs
		);

		if ( !$oldzone ) {
			if ( $self->DBHandle->err ) {
				die "$zone: ", join( " ", @errs );
			}
		}

		# XXX needs to be fixed!
		# This should be a bigint now, so this needs to be tested and this code can be removed.
		#if ( $new->{soa_serial} > 2147483647 ) {
		#	$new->{soa_serial} = 2147483646;
		#}
		if ($oldzone) {
			my $diff = $self->hash_table_diff( $oldzone, $newzone );
			if ( scalar %$diff ) {
				$numchanges += $self->DBUpdate(
					table  => 'dns_domain_ip_universe',
					dbkey  => [ 'dns_domain_id', 'ip_universe_id' ],
					keyval => [ $domid, $self->{ip_universe} ],
					hash   => $diff,
					errs   => \@errs,
				) || die join( " ", @errs );
			}
			${$dom}->{soa_ttl} = $newzone->{soa_ttl};
		} else {
			$newzone->{should_generate} = $self->{shouldgenerate};
			$numchanges += $self->DBInsert(
				table => 'dns_domain_ip_universe',
				hash  => $newzone,
				errrs => \@errs,
			) || die join( " ", @errs );
			${$dom}->{soa_ttl} = $newzone->{soa_ttl};
		}

		# If this is an in-addr zone, then do reverse linkage
		if ( $zone =~ /in-addr.arpa$/ ) {

			# XXX needs to be combined with routine in gen_ptr
			$zone =~ /^([a-f\d\.]+)\.in-addr.arpa$/i;
			if ($1) {
				my $block;
				my @digits = reverse split( /\./, $1 );
				my ( $ip, $bit );
				if ( $#digits <= 3 ) {
					$ip = join( ".", @digits );

					# ipv4, most likely...
					if ( $#digits == 2 ) {
						$block = "$ip.0/24";
					}
				} else {
					die "need to sort out ipv6\n";
				}
				die "Unable to discern block for $zone", if ( !$block );
				$numchanges +=
				  link_inaddr( $self, $$dom->{dns_domain_id}, $block );
			} else {
				warn "Unable to make in-addr dns linkage\n";
			}
		}

		if ($parent) {

			# In our parent, if there are any NS record for us, they
			# should be deleted, because Zone Generaion will DTRT with
			# delegation
			my $shortname = $zone;
			$shortname =~ s/.$parent->{soa_name}$//;
			foreach my $z (
				@{
					$self->DBFetch(
						table => 'dns_record',
						match => {
							dns_domain_id => $parent->{dns_domain_id},
							dns_type      => 'NS',
							dns_name      => $shortname,
						},
						errors => \@errs
					)
				}
			  )
			{
				my $ret = 0;
				if ( $self->{nodelete} ) {
					warn "Skipping NS record cleanup on ", $z->{dns_record_id},
					  "\n";
				} else {
					warn "deleting ns record ", $z->{dns_record_id};
					if (
						!(
							$ret = $self->DBDelete(
								table  => 'dns_record',
								dbkey  => 'dns_record_id',
								keyval => $z->{dns_record_id},
								errors => \@errs,
							)
						)
					  )
					{
						die "Error deleting record ", join( " ", @errs ), ": ",
						  Dumper($z);
					}
				}
				$numchanges += $ret;
			}
		}

		my $lineage = $zone;
		$lineage =~ s/^[^\.]+\././;
		foreach my $z (
			@{
				$self->DBFetch(
					table => 'dns_domain',
					match => [
						{
							key       => 'soa_name',
							value     => $lineage,
							matchtype => 'like',
						}
					],
					errors => \@errs,
				)
			}
		  )
		{
			if ( !defined( $z->{parent_dns_domain_id} )
				|| $z->{parent_dns_domain_id} != $newzone->{dns_domain_id} )
			{
				if ( $self->{verbose} ) {
					warn "updating ", $z->{soa_name}, " to have parent of ",
					  $dom->{soa_name}, "\n";
				}
				$numchanges += $self->DBUpdate(
					table  => 'dns_domain',
					dbkey  => 'dns_domain_id',
					keyval => $z->{dns_domain_id},
					hash   => {
						parent_dns_domain_id => $dom->{dns_domain_id},
					},
					errs => \@errs,
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

	my $self         = $opt->{handle};
	my $name         = $opt->{name};
	my $address      = $opt->{address};
	my $value        = $opt->{value};
	my $priority     = $opt->{priority};
	my $srv_service  = $opt->{srv_service};
	my $srv_protocol = $opt->{srv_protocol};
	my $srv_weight   = $opt->{srv_weight};
	my $srv_port     = $opt->{srv_port};
	my $genptr       = $opt->{genptr};

	my $universe = $self->{ip_universe};

	my $nb;
	my @errs;
	if ( defined($address) ) {
		if ( $opt->{dns_type} eq 'AAAA' && defined( $self->{v6_universe} ) ) {
			$universe = $self->{v6_universe};
		} elsif ( defined( my $x = $self->get_universe($address) ) ) {
			$universe = $x;
		}
		$self->_Debug( 2, "Attempting to find %s (universe %s)...",
			$address, $universe );
		my $match = {
			'is_single_address'      => 'Y',
			'netblock_type'          => 'default',
			'ip_universe_id'         => $universe,
			'host(ip_address)::inet' => $address
		};
		$nb = $self->DBFetch(
			table           => 'netblock',
			match           => $match,
			errors          => \@errs,
			result_set_size => 'first',
		);
		$self->dbh->err && die join( " ", @errs );

		# If there was not a type default, check for one
		# that is just there for DNS.
		if ( !$nb ) {
			$match->{netblock_type} = 'dns';
			$nb = $self->DBFetch(
				table           => 'netblock',
				match           => $match,
				errors          => \@errs,
				result_set_size => 'first',
			);
			$self->dbh->err && die join( " ", @errs );
		}

		if ( !$nb ) {
			my $errname = $name || "";
			if ( defined( $self->{nbrule} ) && $self->{nbrule} eq 'skip' ) {
				print STDERR
				  "$errname ($address) - Netblock not found.  Skipping.\n";
				return 0;
			} else {
				print STDERR
				  "$errname ($address) - Netblock not found.  Creating.\n";
			}

			my $pr = $self->dbh->{PrintError};
			my $re = $self->dbh->{RaiseError};

			$self->dbh->{PrintError} = $self->dbh->{RaiseError} = 0;

			$nb = {
				ip_address        => $address,
				netblock_type     => 'default',
				is_single_address => 'Y',
				can_subnet        => 'N',
				netblock_status   => 'Allocated',
				ip_universe_id    => $universe,
			};
			$self->dbh->do("SAVEPOINT biteme");
			my $x = $self->DBInsert(
				table => 'netblock',
				hash  => $nb,
				errs  => \@errs,
			);
			$self->dbh->{PrintError} = $pr;
			$self->dbh->{RaiseError} = $re;

			if ( !$x ) {
				if ( $self->dbh->err == 7 ) {
					my $errmsg = $self->dbh->errstr;
					$self->dbh->do("ROLLBACK TO SAVEPOINT biteme");
					if ( defined( $self->{nbrule} )
						&& $self->{nbrule} eq 'iponly' )
					{
						my $e = ( scalar @errs ) ? join( " ", @errs ) : $errmsg;
						$e =~ s/\n/ /mg;
						$self->_Debug( 1, "Skipping %s creation", $address );
						$self->_Debug( 1, "... db said: %s",      $e );
						return;
					} else {
						$nb->{netblock_type} = 'dns';
						my $x = $self->DBInsert(
							table => 'netblock',
							hash  => $nb,
							errrs => \@errs,
						  )
						  || die "$address: [", $self->dbh->err, "] ",
						  join( " ", @errs );
					}
				} else {
					die "$address: [", $self->dbh->err, "] ",
					  join( " ", @errs );
				}
				$self->dbh->do("RELEASE SAVEPOINT biteme");
			} else {
				$numchanges += $x;
			}
		}

	}

	my $recuniverse = $universe;

	my $match = {
		dns_name       => $name,
		dns_value      => $value,
		dns_type       => $opt->{dns_type},
		dns_domain_id  => $opt->{dns_domain_id},
		netblock_id    => ($nb) ? $nb->{netblock_id} : undef,
		ip_universe_id => $recuniverse,
	};
	if ($srv_service) {
		$match->{dns_srv_service}  = $srv_service;
		$match->{dns_srv_protocol} = $srv_protocol;
	}

	my $rows = $self->DBFetch(
		table  => 'dns_record',
		match  => $match,
		errors => \@errs,
	) || die join( " ", @errs );

	my $dnsrec = $rows->[0];

	my $new = {
		'dns_name'                => $name,
		'dns_domain_id'           => $opt->{dns_domain_id},
		'dns_ttl'                 => $opt->{dns_ttl},
		'dns_class'               => $opt->{dns_class},
		'dns_type'                => $opt->{dns_type},
		'dns_value'               => $value,
		'dns_priority'            => $priority,
		'dns_srv_service'         => $srv_service,
		'dns_srv_protocol'        => $srv_protocol,
		'dns_srv_weight'          => $srv_weight,
		'dns_srv_port'            => $srv_port,
		'ip_universe_id'          => $universe,
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
		my $diff = $self->hash_table_diff( $dnsrec, $new );
		if ( scalar %$diff ) {
			$numchanges += $self->DBUpdate(
				table  => 'dns_record',
				dbkey  => 'dns_record_id',
				keyval => $dnsrec->{dns_record_id},
				hash   => $diff,
				errs   => \@errs,
			) || die join( " ", @errs );
			warn " ++ refresh dns record ", $dnsrec->{dns_record_id}, "\n"
			  if ( $self->{verbose} );
		}
	} else {
		$numchanges += $self->DBInsert(
			table => 'dns_record',
			hash  => $new,
			errrs => \@errs,
		) || die join( " ", Dumper($new), @errs );
		$dnsrecid = $new->{dns_record_id};
		$self->_Debug( 8, "Inserted new record: %d", $new->{dns_record_id} );
	}

	$numchanges;
}

sub process_zone {
	my ( $self, $ns, $xferzone ) = @_;

	my $numchanges = 0;

	my $dom;
	my $r = $self->freshen_zone( $ns, $xferzone, \$dom );
	if ( defined($r) ) {
		$numchanges += $r;
	}

	#return undef;

	my $domid = $dom->{dns_domain_id};

	my $res = new Net::DNS::Resolver;
	$res->nameservers($ns);

	my @zone = $res->axfr($xferzone);
	if ( $#zone == -1 ) {
		warn "No records returned in AXFR --", $res->errorstring;
		return undef;
	}

	#
	# XXX - First go through the zone and find things that are not there that should be
	my $numrec = 0;
	foreach my $rr ( sort by_name @zone ) {
		my $x = $rr->string;
		$x =~ s/\s+/ /mg;
		$self->_Debug( 1, ">> Processing record %s...", $x );
		my $name = $rr->name;
		if ( $name eq $dom->{soa_name} ) {
			$name = undef;
		} else {
			$name =~ s/\.$dom->{soa_name}$//;
		}

		$numrec++;
		my $new = {
			handle        => $self,
			domain        => $xferzone,
			name          => $name,
			dns_domain_id => $domid,
			dns_type      => $rr->type,
			dns_class     => $rr->class,
			dns_ttl       => ( $rr->ttl == $dom->{soa_ttl} ? undef : $rr->ttl ),
			genptr        => 'N',
		};
		if ( $rr->type eq 'PTR' ) {

			# If this is a legitimate PTR record, check the
			# forward record and see if it is there and genptr is
			# set, and if so, skip, otherwise print a warning and
			# insert as expected.
			$rr->name =~ /^([a-f\d\.]+)\.(in-addr|ip6).arpa$/i;

			#
			# figure out what kind of record this is for by breaking up
			# rr->name and figuring out if its v6, a normal class a, b or c
			# or redirect off to something (either in-addr or otherwise,
			# such as the btp colo stuff).
			#

			my $isip;
			my ( $z, $t ) = ( $1, $2 );
			$isip = 1;
			if ($t) {
				my $ip;
				warn "\t $t - $z\n";
				if ( $z =~ /\./ ) {
					my @digits = reverse split( /\./, $z );
					if ( $#digits == 3 ) {
						$ip = join( ".", @digits );
					} else {
						$ip = join( "", @digits );
						$ip =~ s/(....)/$1:/g;
						$ip =~ s/:$//;
					}

				} elsif ( $z =~ /:/ ) {
					my @digits = reverse split( /:/, $z );
					$ip = join( ":", @digits );
					$ip =~ s/:$//;
				}

				if ( my $dbrec = $self->get_ptr($ip) ) {
					if ( $dbrec ne $rr->ptrdname ) {
						warn
						  "PTR: $ip has a PTR record that does not match DB (",
						  $rr->ptrdname, "), skipping\n";
					}
					next;
				} else {
					warn "PTR: DB has no FWD record for $ip (", $rr->ptrdname,
					  "), adding\n";
				}
			}
			$new->{value} = $rr->ptrdname;
			$new->{value} .= "." if ($isip);
		} elsif ( $rr->type eq 'A' || $rr->type eq 'AAAA' ) {
			my $ptr = $self->get_inaddr( $rr->address );

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
			my ( $srv, $proto, $n ) = split( /\./, $rr->name, 3 );
			if ($n) {
				$new->{srv_service} = $srv;
				$proto =~ s/^_//;
				$new->{srv_protocol} = $proto;
				if ( $n eq $xferzone ) {
					$new->{name} = undef;
				} else {
					$n =~ s/\.$xferzone$//;
					$new->{name} = $n;
				}

				check_and_add_service( $self, $srv );
			}
			#
			$new->{priority}   = $rr->priority;
			$new->{srv_weight} = $rr->weight;
			$new->{srv_port}   = $rr->port;
			$new->{value}      = $rr->target;
		} elsif ( $rr->type eq 'TXT' || $rr->type eq 'SPF' ) {
			$new->{value} = $rr->txtdata;
		} elsif ( $rr->type eq 'NS' ) {

			# XXX may want to consider this check to be optional.
			if ( defined($name) && length($name) ) {
				my @errs;
				my $count = $self->DBFetch(
					table           => 'dns_domain',
					match           => { soa_name => $rr->name },
					result_set_size => 'exactlyone',
					errors          => \@errs
				);
				if ($count) {
					warn "Skipping subzone NS records for $name (",
					  $rr->nsdname, ")\n";
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
		} elsif ( $rr->type =~ /^(APL|CAA|CERT|DHCID|HIP|IPSECKEY|LOC|NAPTR)/ )
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
		if ( $rr->type =~ /^(CNAME|SRV|NS|MX|DNAME)/ ) {
			if ( $new->{value} !~ s/\.$xferzone$// ) {
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
	my ( $self, $zone ) = @_;

	return 0;

	my @errs;
	my $rows = $self->DBFetch(
		table           => 'dns_domain',
		match           => { soa_name => $zone, },
		result_set_size => 'first',
		errors          => \@errs,
	) || die join( " ", @errs );
}

1;

#############################################################################

package main;

exit do_zone_load();

sub do_zone_load {
	my $app    = 'zoneimport';
	my $nbrule = 'skip';
	my (
		$ns,             $verbose,       $addsvr,
		$nodelete,       $debug,         $dryrun,
		$universe,       $guessuniverse, $v6universe,
		$shouldgenerate, @alloweduniverses
	);

	my $r = GetOptions(
		"dry-run|n"           => \$dryrun,
		"debug+"              => \$debug,
		"verbose"             => \$verbose,
		"dbapp=s"             => \$app,
		"nameserver=s"        => \$ns,
		"add-services"        => \$addsvr,
		"no-delete"           => \$nodelete,
		"v6-universe=s"       => \$v6universe,
		"ip-universe=s"       => \$universe,
		"guess-universe"      => \$guessuniverse,
		"unknown-netblocks=s" => \$nbrule,
		"should-generate"     => \$shouldgenerate,
		"allowed-universe=s"  => \@alloweduniverses,
	) || die "Issues";

	$verbose = 1 if ($debug);

	if ( defined($nbrule) ) {
		die "--unknown-netblocks can be skip, insert, iponly\n"
		  if ( $nbrule ne 'skip'
			&& $nbrule ne 'insert'
			&& $nbrule ne 'iponly' );
	}

	my $ziw = new ZoneImportWorker(
		dbuser => 'zoneimport',
		debug  => $debug,
	) || die $ZoneImportWorker::errstr;

	if ($guessuniverse) {
		$ziw->pull_universes();
	}

	if ($ns) {
		my $res  = new Net::DNS::Resolver;
		my $resp = $res->query($ns);
		foreach my $rr ( grep { $_->type =~ /^(A|AAAA$)/ } $resp->answer ) {
			$ns = $rr->address;
			last;
		}
	}

	$ziw->{nbrule}     = $nbrule;
	$ziw->{verbose}    = $verbose;
	$ziw->{addservice} = $addsvr;
	$ziw->{nodelete}   = $nodelete;
	if ( scalar @alloweduniverses ) {
		foreach my $u (@alloweduniverses) {
			my $id = $ziw->find_universe($universe);
			die "Unknown universe $u\n" if ( !$id );
			push( @{ $ziw->{alloweduniverses} }, $id );
		}
	}
	$ziw->{shouldgenerate} = ($shouldgenerate) ? 'Y' : 'N';
	$ziw->{nameserver} = $ns if ($ns);

	# XXX need to error check
	$ziw->{ip_universe} = $ziw->find_universe($universe);
	$ziw->{v6_universe} = $ziw->find_universe($v6universe) if ($v6universe);

	foreach my $zone (@ARGV) {
		$ziw->_Debug( 1, "Processing zone %s", $zone );
		if ($ns) {
			$ziw->process_zone( $ns, $zone );
			$ziw->process_db($zone);
		} else {
			my $res = new Net::DNS::Resolver;
			$res->nameservers($ns) if ($ns);
			my $resp = $res->query( $zone, 'NS' );
			if ( !$resp ) {
				die "Unable to find name servers for $zone.  Aborting.\n";
			}
			foreach my $rr ( grep { $_->type eq 'NS' } $resp->answer ) {
				my $ns = $rr->nsdname;
				warn "consdering $ns\n";
				my $numchanges = $ziw->process_zone( $ns, $zone );
				if ( !defined($numchanges) ) {
					next;
				}
				warn "updated $numchanges records\n";
				$ziw->process_db($zone);
				last;
			}
		}
	}

	if ($dryrun) {
		$ziw->rollback;
	} else {
		$ziw->commit;
	}
	0;
}
