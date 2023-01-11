#!/usr/bin/env perl
#
# Copyright (c) 2013-2023, Todd M. Kover
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

# TODO: reevaluate how $numchanges is set with DB*, particularly update.
#	Look at all the exception harcodings around pools and whatnot. (next/r if..

use warnings;
use strict;
use Getopt::Long;
use Carp;

package ZoneImportWorker;

use Net::DNS;
use Net::DNS::Zone::Parser;
use JazzHands::DBI;
use Net::IP;    # Just for reverse DNS-type operations
use NetAddr::IP qw(:lower);
use Data::Dumper;
use JazzHands::Common qw(:all);
use Carp qw(cluck);
use parent 'JazzHands::Common';
use DBD::Pg qw(:pg_types);

#local $SIG{__WARN__} = \&Carp::cluck;
#local $SIG{__DIE__} = \&Carp::cluck;

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

	$self->SetDebug( $opt->{debug} ) if ( $opt->{debug} );

	$self->make_loopbacks( $opt->{loopback} ) if ( $opt->{loopback} );

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

sub make_loopbacks {
	my $self = shift @_;
	my $lb   = shift @_ || return undef;

	foreach my $nw ( @{$lb} ) {
		my $i = new NetAddr::IP($nw) || die "$nw: $!";
		push( @{ $self->{_loopbacks} }, $i );
	}

	$self->{_loopbacks};
}

sub check_loopbacks {
	my $self = shift @_;
	my $ip   = shift @_;

	my $o = new NetAddr::IP($ip);
	foreach my $i ( @{ $self->{_loopbacks} } ) {
		return 1 if ( $o->within($i) );
	}
	0;
}

sub find_universe {
	my ( $self, $u ) = @_;

	return undef if ( !defined($u) );

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
	$self->dbh->err && die "Find_universe: ", join( " ", @errs );

	die "Unable to find universe $u\n";

	return undef;
}

#
# takes mismatched ip universes and adjusts the new record to point across
# universes and returns a new record to insert.
#
# This requires the record to exist in the other domain, otherwise just returns
# the old record, which will fail to insert.  This probably means that the
# command line argument to define how this works needs more granularity.
#
sub bleed_universes($$$) {
	my $self = shift @_;
	my $new  = shift @_;
	my $nb   = shift @_;

	my $dbh = $self->DBHandle();

	my $sth = $dbh->prepare_cached( qq {
		SELECT *
		FROM dns_record
			JOIN netblock USING (netblock_id)
		WHERE dns_name IS NOT DISTINCT FROM :name
		AND dns_domain_id = :domain
		AND dns_type = :type
		AND host(ip_address) = :ip
		ORDER BY dns_record_id, dns_domain_id, ip_address
		LIMIT 1;
	} ) || die $dbh->errstr;

	$sth->bind_param( ':name',   $new->{dns_name} )      || die $sth->errstr;
	$sth->bind_param( ':type',   $new->{dns_type} )      || die $sth->errstr;
	$sth->bind_param( ':ip',    $nb->{ip_address} ) || die $sth->errstr;
	$sth->bind_param( ':domain', $new->{dns_domain_id} ) || die $sth->errstr;

	$sth->execute() || die $sth->errstr;

	my $hr = $sth->fetchrow_hashref();

	$sth->finish;

	if ( !$hr ) {
		warn "nothing for bleeding given ",, Dumper( $new, $nb );
		return $new;
	}

	$new->{dns_value}               = undef;
	$new->{netblock_id}             = undef;
	$new->{reference_dns_record_id} = $hr->{dns_record_id};
	$new->{dns_value_record_id}     = $hr->{dns_record_id};
	$new->{should_generate_ptr}     = 'N';

	$new;
}

# picks the best universe for the IP.  If its in the internet universe (0),
# then favor that, otherwise rifle through the list fetched on creation and
# find the right one.
#
# return undef if there is no good choice.
#
sub get_universe($$) {
	my ( $self, $ip ) = @_;

	my $u = $self->{ip_universe};

	my $dbh = $self->DBHandle();

	my $sth = $dbh->prepare_cached(
		qq{
			select netblock_utils.find_best_visible_ip_universe(
				ip_address := :ip,
				ip_universe_id := :myuniverse,
				permitted_ip_universe_ids := :allowedus
			);
		}
	) || die $dbh->errstr;

	$sth->bind_param( ':ip',         $ip ) || die $sth->errstr;
	$sth->bind_param( ':myuniverse', $u )  || die $sth->errstr;
	$sth->bind_param( ':allowedus',  $self->{alloweduniverses} )
	  || die $sth->errstr;

	$sth->execute || die $sth->errstr;
	my ($id) = $sth->fetchrow_array;
	$sth->finish;

	$id;
}

#
# look through everything in the current namespace to find the best choice
# regardless of visibility or other considerations.
#
sub guess_universe($$) {
	my ( $self, $ip ) = @_;

	my $dbh = $self->DBHandle();

	my $sth = $dbh->prepare_cached(
		qq{
			select netblock_utils.find_best_ip_universe(
				ip_address := :ip,
				ip_namespace := :namespace
			);
		}
	) || die $dbh->errstr;

	$sth->bind_param( ':ip',        $ip )                 || die $sth->errstr;
	$sth->bind_param( ':namespace', $self->{_namespace} ) || die $sth->errstr;

	$sth->execute || die $sth->errstr;
	my ($id) = $sth->fetchrow_array;
	$sth->finish;

	$id;
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
	my $match = {
		dns_domain_id => $domid,
		dns_type      => 'REVERSE_ZONE_BLOCK_PTR',
	};
	$match->{ip_universe_id} = $universe if ( defined($universe) );
	if (

		my $dbrec = $self->DBFetch(
			table           => 'dns_record',
			match           => $match,
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
		errs  => \@errs,
	) || die join( " ", @errs );
	1;
}

#
# given an IP, returns the forward record that defines that
# PTR record, traversing CNAMEs and what not.
#
sub get_ptr {
	my ( $self, $ip ) = @_;

	$self->_Debug( 4, "looking for PTR for $ip" );

	my $universe = $self->get_universe($ip);
	if ( !defined($universe) ) {
		$universe = $self->{ip_universe};
	}
	$self->_Debug( 5, "Guessed Universe %d", $universe );

	my (@errs);
	my $match = {
		'is_single_address'      => 'Y',
		'netblock_type'          => 'default',
		'host(ip_address)::inet' => $ip
	};
	$match->{'ip_universe_id'} = $universe if ( defined($universe) );
	my $nblk = $self->DBFetch(
		table           => 'netblock',
		match           => $match,
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

	$self->_Debug( 7, "get_inaddr($ip)..." );

	my $ii     = new Net::IP($ip) || die "Parse($ip): " . Net::IP::Error();
	my $inaddr = $ii->reverse_ip();

	my $res = new Net::DNS::Resolver();
	#
	# There is no guarantee that the auth server that hosts a fwd zone also
	# hosts the in-addr zone, so this extra hoop jumping.
	#

	my $nameserver = $self->{nameserver};

	if ( $self->{force_inaddr} && ( my $i = new NetAddr::IP($ip) ) ) {
		foreach my $map ( @{ $self->{force_inaddr} } ) {
			my ( $blk, $ns ) = split( /:/, $map, 2 );
			if ( $i->within( new NetAddr::IP $blk) ) {
				if ($ns) {
					$nameserver = $ns;
				} else {
					$nameserver = undef;
				}
				last;
			}

		}
	}

	$res->nameserver($nameserver) if ($nameserver);
	my $a = $res->send( $ip, 'PTR' );

	if ( !$a || !scalar $a->answer ) {

		# reset with no nameserver
		$res = new Net::DNS::Resolver;
		$a   = $res->send( $inaddr, 'PTR' );
	}

	# deal with the case of there being a cname.
	if ( !$a || !scalar $a->answer || !grep { $_->type eq 'PTR' } $a->answer ) {

		# to reset the nameservers, which is potentially needed to traverse
		# CNAMEs, which the AUTH server may not actually  have.
		# XXX - this will almost certainly have issue where switching BACK
		# to the auth nameserver is required to deal with cases where its not
		# 'internet resolvable' from the main host.
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

#
# sort SOA, other, PTR
#
sub favor_soa_by_name {
	if ( $a->type eq 'SOA' ) {
		if ( $b->type eq 'SOA' ) {
			return ( $a->name <=> $b->name );
		} else {
			return -1;
		}
	} elsif ( $b->type eq 'SOA' ) {
		return 1;
	} elsif ( $a->type eq 'PTR' ) {
		if ( $b->type eq 'PTR' ) {
			my $lhs = $a->name;
			my $rhs = $b->name;
			$lhs =~ s/^(\d*)\D.*$/$1/;
			$rhs =~ s/^(\d*)\D.*$/$1/;
			my $x = $lhs <=> $rhs;
			if ( $x == 0 ) {
				return ( $a->name cmp $b->name );
			} else {
				return $x;
			}
		} else {
			return 1;
		}
	} elsif ( $a->name =~ /^\d+$/ && $b->name =~ /^\d+$/ ) {
		return ( $a->name <=> $b->name );
	} else {
		return ( $a->name cmp $b->name );
	}
}

#
# given a zone, makes sure its in the DB and returns a record accordingly.
#
sub freshen_zone {
	my ( $self, $zone, $dom ) = @_;

	my @errs;
	my $numchanges = 0;

	my $olddom = $self->DBFetch(
		table           => 'dns_domain',
		match           => { soa_name => $zone },
		result_set_size => 'exactlyone',
		errors          => \@errs
	);

	my $parent = get_parent_domain( $self, $zone );

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

		if ( $zone =~ /\.in-addr.arpa$/ ) {
			$new->{dns_domain_type} = 'reverse';
		}

		$numchanges += $self->DBInsert(
			table  => 'dns_domain',
			hash   => $new,
			errors => \@errs,
		) || die join( " ", @errs );
		$$dom = $new;
	} else {
		$$dom = $olddom;
	}

	my $lineage = $zone;
	$lineage =~ s/^[^\.]+\././;
	foreach my $z (
		@{
			$self->DBFetch(
				table => 'dns_domain',
				match => [ {
					key       => 'soa_name',
					value     => $lineage,
					matchtype => 'like',
				} ],
				errors => \@errs,
			)
		}
	  )
	{
		if ( !defined( $z->{parent_dns_domain_id} )
			|| $z->{parent_dns_domain_id} != $$dom->{dns_domain_id} )
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

	$numchanges;
}

#
# takes a nameserver and a zone, gets the SOA record for that zone and
# makes sure the database matches for all the SOA vaules
#
sub freshen_soa {
	my ( $self, $zone, $rr, $dom ) = @_;

	my $domid = $dom->{dns_domain_id};

	my $numchanges = 0;

	my $universe =
	  ( defined( $self->{soa_universe} ) )
	  ? $self->{soa_universe}
	  : $self->{ip_universe};

	if ( $rr->name ne $zone ) {
		die "freshen_soa name mismatch: ", $rr->name, " v ", $zone, "\n";

		# return undef;
	}
	my @errs;
	my $newzone = {
		dns_domain_id  => $domid,
		ip_universe_id => $universe,
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
			'ip_universe_id' => $universe,
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
				keyval => [ $domid,          $self->{ip_universe} ],
				hash   => $diff,
				errs   => \@errs,
			) || die join( " ", @errs );
		}

		# requires RETURNING * in DBUpdate()
		# $newzone = $diff;
	} else {
		$newzone->{should_generate} = $self->{shouldgenerate};
		$numchanges += $self->DBInsert(
			table  => 'dns_domain_ip_universe',
			hash   => $newzone,
			errors => \@errs,
		) || die join( " ", @errs );
	}

	# If this is an in-addr zone, then do reverse linkage
	# XXX -- this needs to properly handle ip universe!
	if ( $zone =~ /in-addr.arpa$/ ) {
		if ( $self->{linknetwork} ) {
			$numchanges +=
			  $self->link_inaddr( $dom->{dns_domain_id}, $self->{linknetwork} );
		} else {

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
				  $self->link_inaddr( $dom->{dns_domain_id}, $block );
			} else {
				warn "Unable to make in-addr dns linkage\n";
			}
		}
	}

	#
	#
	# Probably only meaningful for initial setup.  This needs to be on a
	# per-universe basis!
	#
	if ( $dom->{parent_dns_domain_id} ) {
		my $parent = get_parent_domain( $self, $zone );

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
				if ( !(
					$ret = $self->DBDelete(
						table  => 'dns_record',
						dbkey  => 'dns_record_id',
						keyval => $z->{dns_record_id},
						errors => \@errs,
					)
				) )
				{
					die "Error deleting record ", join( " ", @errs ), ": ",
					  Dumper($z);
				}
			}
			$numchanges += $ret;
		}
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
		#
		# Figure out the IP universe.  The netblock and the dns record need
		# to share the same universe (trigger enforced), so $universe is
		# set and that used for both.
		#
		# Things that can impact this:
		#
		# 1. For AAAA records and a set v6 namespace set. just use that for the
		# universe for both records, hands down.  This is generally for places
		# that use universes for v4 but v6 does not.
		#
		# 2. If a default namespace is set, then look in that universe for
		# the best choice, ignoring anything else.  If that fails, keep
		# going
		#
		# 3. Use the specified universe and any visible universe that are
		# allowed.  If there's no allowed list, use anything that's visible.
		#
		# 4. If universebleeding is specified and the sane name/network exists
		# in another universe then this the record will bleed over.  This is
		# meant for records exposed for convenience.  This check also happens
		# later on.
		#
		# 5. Follow the "insert netblock" guidelines for inserting, which may
		# result in an error.
		if ( $opt->{dns_type} eq 'AAAA' && defined( $self->{v6_universe} ) ) {
			$universe = $self->{v6_universe};
		} elsif ( $self->{_namespace}
			&& ( defined( my $x = $self->guess_universe($address) ) ) )
		{
			# XXX move to high debugging
			warn "... Redefining Universe to $x" if ( $x ne $universe );
			$universe = $x;
		} else {
			if(defined(my $x = $self->get_universe($address))) {
				$universe = $x;
			}
		}
		$self->_Debug( 3, "Attempting to find IP %s (universe %s)...",
			$address, $universe );
		my $match = {
			'is_single_address'      => 'Y',
			'netblock_type'          => 'default',
			'host(ip_address)::inet' => $address,
			ip_universe_id  => $universe,
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
				$self->_Debug( 5, "%s (%s) - Netblock not found.  Skipping",
					$errname, $address );
				return 0;
			} else {
				$self->_Debug( 5, "%s (%s) - Netblock not found.  Creating",
					$errname, $address );
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
				ip_universe_id		=> $universe,
			};

			$self->dbh->do("SAVEPOINT biteme");
			if ( $self->check_loopbacks($address) ) {

				# need to insert a /32 for this sucka'

				my $pnb = {
					ip_address        => $address,
					netblock_type     => 'default',
					is_single_address => 'N',
					can_subnet        => 'N',
					netblock_status   => 'Allocated',
					ip_universe_id		=> $universe,
				};
				$pnb->{ip_universe_id} = $universe if ( defined($universe) );
				my $x = $self->DBInsert(
					table => 'netblock',
					hash  => $pnb,
					errs  => \@errs,
				);

				if ( !$x ) {
					my $errmsg = $self->dbh->errstr;
					warn "loopback: $errmsg\n";
					$self->dbh->do("ROLLBACK TO SAVEPOINT biteme");
				}

			}
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
						$self->_Debug( 1,
							"Skipping IP %s creation due to failure: %s",
							$address, $e );
						# not returning to give universe bleeding a chance
						# in the next section.  If that does not work, then
						# it will result in an error.
						# return;
					} else {
						$nb->{netblock_type} = 'dns';
						my $x = $self->DBInsert(
							table  => 'netblock',
							hash   => $nb,
							errors => \@errs,
						  )
						  || die "$address: [", $self->dbh->err, "] ",
						  join( " ", @errs );
						warn "NOTE: Creating DNS netblock for $address\n"
						  if ( $self->{verbose} );
					}
				} else {
					die "$address: [", $self->dbh->err, "] ",
					  join( " ", @errs );
				}
			} else {
				$numchanges += $x;
			}
			$self->dbh->do("RELEASE SAVEPOINT biteme");
		}

	}

	my $match = {
		dns_name       => $name,
		dns_value      => $value,
		dns_type       => $opt->{dns_type},
		dns_domain_id  => $opt->{dns_domain_id},
		netblock_id    => ($nb) ? $nb->{netblock_id} : undef,
		ip_universe_id => $universe,
	};
	if ($srv_service) {
		$match->{dns_srv_service}  = $srv_service;
		$match->{dns_srv_protocol} = $srv_protocol;
	}

	my $rows = $self->DBFetch(
		table  => 'v_dns',
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

		# if the reference and value come from the same record, it's bleedover
		# from another universe and should just ignored.
		if (   $dnsrec->{ref_record_id}
			&& $dnsrec->{dns_value_record_id}
			&& $dnsrec->{ref_record_id} == $dnsrec->{dns_value_record_id} )
		{
			warn "Skipping universe bleedover record for ",
			  $dnsrec->{dns_name}, "\n";
		} else {

			# Find if there is a dns record associated with this record
			$dnsrecid = $dnsrec->{dns_record_id};
			my $diff = $self->hash_table_diff( $dnsrec, $new );
			if ( scalar %$diff ) {
				my $rv = $self->DBUpdate(
					table  => 'dns_record',
					dbkey  => 'dns_record_id',
					keyval => $dnsrec->{dns_record_id},
					hash   => $diff,
					errs   => \@errs,
				  )
				  || die "failed to update DNS Record: ",
				  Dumper( $dnsrec, $diff ), " :-- ", join( " ", @errs );
				$numchanges += $rv;
				$self->_Debug(
					15,
					" ++ refresh dns record %d\n",
					$dnsrec->{dns_record_id}
				) if ( $self->{verbose} );
			}
		}
	} else {
		#
		# This means the network was not found above given existing rules so
		# this is a last ditch effort to try universe bleeding.
		if ( !$nb->{netblock_id} && $self->{universebleed}) {
				my $x = $self->bleed_universes( $new, $nb );
				warn "... Universe bleeding....", Dumper($new, $x, $nb);
				$new = $x;
		}
		$numchanges += $self->DBInsert(
			table  => 'dns_record',
			hash   => $new,
			errors => \@errs,
		  )
		  || die "failed to insert: ",
		  join( " ",
			Dumper($new),   "failed to match",
			Dumper($match), ":", @errs );
		$dnsrecid = $new->{dns_record_id};
		$self->_Debug( 8, "Inserted new record: %d", $new->{dns_record_id} );
	}

	$numchanges;
}

sub process_zone($$$;$) {
	my ( $self, $ns, $xferzone, $file ) = @_;

	my $numchanges = 0;

	my $dom;
	#
	# This makes sure the zone exists and is in order.  SOA processing is
	# handled later.
	#
	# XXX dom is returned both from freshen_zone and freshen_soa.  This needs
	# to be better reconciled.
	#
	my $r = $self->freshen_zone( $xferzone, \$dom );
	if ( defined($r) ) {
		$numchanges += $r;
	}

	#return undef;

	my $domid = $dom->{dns_domain_id};

	my $zone;

	if ( !$file ) {
		my $res = new Net::DNS::Resolver;
		$res->nameservers($ns);
		my @zone = $res->axfr($xferzone);
		$zone = \@zone;

		if ( $#zone == -1 ) {
			warn "No records returned in AXFR --", $res->errorstring;
			return undef;
		}
	} else {
		my $r  = new Net::DNS::Zone::Parser();
		my $rv = $r->read(
			$file,
			{
				ORIGIN    => $xferzone,
				CREATE_RR => 1
			}
		);
		if ( !defined($rv) ) {
			die "$file: $! /$rv";
		}
		$zone = $r->get_array();
		if ( scalar( @{$zone} ) == 0 ) {
			warn "No records read from $file for $xferzone: $!";
			return undef;
		}
	}

	my $defttl = 3600;
	#
	# XXX - First go through the zone and find things that are not there that should be
	my $numrec = 0;
  RR:
	foreach my $rr ( sort favor_soa_by_name @{$zone} ) {
		my $x = $rr->string;

		#- next if($x !~ /auth01/);
		$x =~ s/\s+/ /mg;
		$self->_Debug( 3, ">> Processing record '%s'...", $x );

		foreach my $pre ( @{ $self->{ignoreprefix} } ) {
			if ( $x =~ /^$pre/ ) {
				$self->_Debug( 2, "... Skipping, matches $pre" );
				next RR;
			}
		}
		my $name = $rr->name;
		if ( $name eq $dom->{soa_name} ) {
			$name = undef;
		} else {
			$name =~ s/\.$dom->{soa_name}$//;
		}

		$numrec++;

		# This assumes there will be an SOA first basically because it fills
		# in the zone ttl.
		if ( $rr->type eq 'SOA' ) {
			$numchanges += $self->freshen_soa( $xferzone, $rr, $dom );
			$defttl = $rr->ttl;
			next;
		}
		my $new = {
			handle        => $self,
			domain        => $xferzone,
			name          => $name,
			dns_domain_id => $domid,
			dns_type      => $rr->type,
			dns_class     => $rr->class,
			dns_ttl       => ( $rr->ttl == $defttl ? undef : $rr->ttl ),
			genptr        => 'N',
		};
		if ( $rr->type eq 'PTR' ) {

			# If this is a legitimate PTR record, check the
			# forward record and see if it is there and genptr is
			# set, and if so, skip, otherwise print a warning and
			# insert as expected.  This  can be tricking if it's a ipv4
			# in-addr zone for a block that is not class aligned.
			my $isip;
			if ( $rr->name =~ /^(.+)\.(in-addr|ip6)\.arpa$/i ) {
				my ( $z, $t ) = ( $1, $2 );

				# figure out what kind of record this is for by breaking up
				# rr->name and figuring out if its v6, a normal class a, b or c
				# or redirect off to something (either in-addr or otherwise,
				# such as the btp colo stuff).
				#

				if ($t) {
					$isip = 1;
					my $ip;
					$self->_Debug( 10, "Record Type: %s - %s", $t, $z );
					if ( $t eq 'in-addr' ) {

						# ipv4
						my @digits = reverse split( /\./, $z );
						if ( $#digits == 3 ) {

							# "class c" zone, easy match
							$ip = join( ".", @digits );
							if ( my $net = $self->{linknetwork} ) {
								my $ni = new NetAddr::IP($net)
								  || die "$net: $!";
								my $h = $ni->network->addr;
								$h =~ s/\.(\d+)$/.$digits[$#digits]/;
								$ip = $h;
							} else {
								warn "-- Unable to figure out in-addr mapping";
							}
						}
					} elsif ( $t =~ /ip6/ ) {

						# There's no hoop jumping here because of how things
						# block, so just assume it's all correct.
						my @digits = reverse split( /./, $z );
						$ip = join( "", @digits );
						$ip =~ s/(....)/$1:/g;
						$ip =~ s/:$//;
					} else {
						die "This name should not happen.  Regexp Bug";
					}

					if ( $ip && ( my $dbrec = $self->get_ptr($ip) ) ) {
						if ( $dbrec ne $rr->ptrdname ) {
							warn
							  "PTR: $ip has a PTR record that does not match DB (",
							  $rr->ptrdname, "), skipping\n";
						}
						next;
					} else {
						$self->_Debug( 2,
							"PTR: DB has no FWD record for %s (%s), adding",
							$ip, $rr->ptrdname );
					}
				}
			}
			$new->{value} = $rr->ptrdname;

			# if the PTR is for an IP looking thing, then tack on a .
			$new->{value} .= ".";    # XXX - ugh if ( $isip );
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
			$new->{value} =
			  join( " ", $rr->algorithm, $rr->fptype, $rr->fingerprint, );
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
			die "Unable to process record for ", $rr->name, " -- ",
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
		$ns,               $verbose,      $addsvr,
		$nodelete,         $debug,        $dryrun,
		$universe,         $v6universe,   $shouldgenerate,
		@alloweduniverses, $file,         $universebleed,
		$soauniverse,      @ignoreprefix, $linknetwork,
		$namespace,        @forceinaddr,  @loopback,
	);

	my $r = GetOptions(
		"dry-run|n"           => \$dryrun,
		"debug+"              => \$debug,
		"verbose"             => \$verbose,
		"dbapp=s"             => \$app,
		"nameserver=s"        => \$ns,
		"forceinaddr=s"       => \@forceinaddr,
		"add-services"        => \$addsvr,
		"no-delete"           => \$nodelete,
		"file=s"              => \$file,
		"loopback=s"          => \@loopback,
		"v6-universe=s"       => \$v6universe,
		"ip-universe=s"       => \$universe,
		"soa-universe=s"      => \$soauniverse,
		"universebleed"       => \$universebleed,
		"ignore-prefix=s"     => \@ignoreprefix,
		"unknown-netblocks=s" => \$nbrule,
		"linknetwork=s"       => \$linknetwork,
		"should-generate"     => \$shouldgenerate,
		"allowed-universe=s"  => \@alloweduniverses,
		"ip-namespace=s"      => \$namespace,
	) || die "Issues";

	$verbose = 1 if ($debug);

	if ( defined($nbrule) ) {
		die "--unknown-netblocks can be skip, insert, iponly\n"
		  if ( $nbrule ne 'skip'
			&& $nbrule ne 'insert'
			&& $nbrule ne 'iponly' );
	}

	my $ziw = new ZoneImportWorker(
		dbuser    => 'zoneimport',
		debug     => $debug,
		loopback  => \@loopback,
		namespace => $namespace,
	) || die $ZoneImportWorker::errstr;

	if ($ns) {
		my $res  = new Net::DNS::Resolver;
		my $resp = $res->query($ns);
		if ($resp) {
			foreach my $rr ( grep { $_->type =~ /^(A|AAAA$)/ } $resp->answer ) {
				$ns = $rr->address;
				last;
			}
		} else {
			die "no nameserver $ns\n";
		}
	} else {
		die
		  "Must specify a nameserver for now to axfr from, at least to deal with files.  This probably needs some attention XXX";
	}

	if ( $file && scalar(@ARGV) != 1 ) {
		die "When specifying a filename, only one zone can be processed.\n";
	}

	$ziw->{ignoreprefix}  = \@ignoreprefix;
	$ziw->{nbrule}        = $nbrule;
	$ziw->{verbose}       = $verbose;
	$ziw->{addservice}    = $addsvr;
	$ziw->{nodelete}      = $nodelete;
	$ziw->{linknetwork}   = $linknetwork;
	$ziw->{universebleed} = $universebleed;
	$ziw->{_namespace}    = $namespace;
	$ziw->{force_inaddr}  = \@forceinaddr;

	if ( scalar @alloweduniverses ) {
		foreach my $u (@alloweduniverses) {
			my $id = $ziw->find_universe($u);
			die "Unknown universe $u\n" if ( !defined($id) );
			push( @{ $ziw->{alloweduniverses} }, $id );
		}
	}
	$ziw->{shouldgenerate} = ($shouldgenerate) ? 'Y' : 'N';
	$ziw->{nameserver}     = $ns if ($ns);

	# XXX need to error check
	$ziw->{ip_universe} = $ziw->find_universe($universe);
	$ziw->{v6_universe} = $ziw->find_universe($v6universe) if ($v6universe);

	$ziw->{soa_universe} = $ziw->find_universe($soauniverse) if ($soauniverse);

	foreach my $zone (@ARGV) {
		$ziw->_Debug( 1, "Processing zone %s (%s)", $zone, $universe );
		if ($file) {
			$ziw->process_zone( $ns, $zone, $file );
			$ziw->process_db( $zone, $file );
		} elsif ($ns) {
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
		$ziw->rollback || die "Unable to rollback ", $ziw->dbh->errstr;
	} else {
		$ziw->commit || die "Unable to commit ", $ziw->dbh->errstr;
	}
	0;
}
