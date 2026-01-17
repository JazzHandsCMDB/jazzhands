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
# Copyright (c) 2013-2020 Todd Kover, Matthew Ragan
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

package JazzHands::STAB::DBAccess;

use 5.008007;
use strict;
use warnings;

use Data::Dumper;
use JazzHands::DBI;
use JazzHands::Common::Util qw(:all);
use JazzHands::Mgmt;
use URI;
use Carp;
use Math::BigInt;
use Net::IP;

use Apache2::Log;
use Apache2::Const -compile => qw(OK :log);
use APR::Const -compile => qw(:error SUCCESS);

our @ISA = qw( JazzHands::Common );

our $VERSION = '1.0.0';

# Preloaded methods go here.

#sub rollback {
#	my ($self) = @_;
#	my $dbh = $self->dbh;
#	$dbh->rollback;
#}
#
#sub commit {
#	my ($self) = @_;
#	my $dbh = $self->dbh;
#	$dbh->commit;
#}

sub prepare {
	my ( $self, $q ) = @_;

	my $dbh = $self->dbh;

	if ( !$self->{_jhSth} ) {
		$self->{_jhSth} = {};
	}

	if ( !defined( $self->{_jhSth}->{$q} ) ) {
		$self->{_jhSth}->{$q} = $dbh->prepare_cached($q)
		  || return undef;
	}
	$self->{_jhSth}->{$q}->finish;
	$self->{_jhSth}->{$q};
}

sub prepare_cached {
	my $self = shift @_;
	$self->prepare(@_);
}

#
# different from other implementations
#
# This really wants to have some more quality time spent on it.
#
#
sub guess_parent_netblock_id {
	my ( $self, $in_ip, $in_bits, $sing ) = @_;

	#
	# parse_netblock_search wants this to be Y
	#
	$sing = 'Y' if ( !$sing );

	if ( $in_bits && $in_ip !~ m,/, ) {
		$in_ip   = "$in_ip/$in_bits";
		$in_bits = undef;
	}

	# select is needed for postgres 9.1 to optimize right.
	my $q1 = qq {
		select  Netblock_Id,
			host(ip_address) as IP,
			ip_address, masklen(ip_address) as netmask_bits,
			family(ip_address) as ip_family
		  from  netblock
		  where	netblock_id in (
			SELECT netblock_utils.find_best_parent_id(
				in_IpAddress := :ip,
				in_ip_universe_id := 0,
				in_netblock_type := 'default',
				in_is_single_address := :sing)
			)
	};
	my $q2 = qq {
		select  Netblock_Id,
			host(ip_address) as IP,
			ip_address, masklen(ip_address) as netmask_bits,
			family(ip_address) as ip_family
		  from  netblock
		  where	netblock_id in (
			SELECT netblock_utils.find_best_parent_id(
				in_IpAddress := :ip,
				in_ip_universe_id := 0,
				in_netblock_type := 'default',
				in_is_single_address := :sing,
				in_fuzzy_can_subnet := true )
			)
	};
	my $q3 = qq {
		select  Netblock_Id,
			host(ip_address) as IP,
			ip_address, masklen(ip_address) as netmask_bits,
			family(ip_address) as ip_family
		  from  netblock
		  where	netblock_id in (
			SELECT netblock_utils.find_best_parent_id(
				in_IpAddress := :ip,
				in_ip_universe_id := 0,
				in_netblock_type := 'default',
				in_is_single_address := :sing,
				in_fuzzy_can_subnet := true,
				can_fix_can_subnet := true)
			)
	};

	# Logic is - check for a parent..   if found, return.
	# If not found, check for a parent and do not care about
	# can_subnet.  If found, and its an ipv6 block >= /64 or its an
	# ipv4 block >= /24, then it the routine is called again, switching
	# the network to not be subnetable.  note I'm using the > literally
	# not in terms of "bigger" or "smaller" block.  ugh.

	my $sth = $self->prepare($q1)      || $self->return_db_err($self);
	$sth->bind_param( ':ip', $in_ip )  || die $sth->errstr;
	$sth->bind_param( ':sing', $sing ) || die $sth->errstr;
	$sth->execute                      || $self->return_db_err($sth);
	my $rv = $sth->fetchrow_hashref;
	$sth->finish;

	if ( !$rv ) {
		$sth = $self->prepare($q2)         || $self->return_db_err($self);
		$sth->bind_param( ':ip', $in_ip )  || die $sth->errstr;
		$sth->bind_param( ':sing', $sing ) || die $sth->errstr;
		$sth->execute                      || $self->return_db_err($sth);
		$rv = $sth->fetchrow_hashref;
		$sth->finish;
		my $bits = $rv->{'NETMASK_BITS'};
		if ( $rv->{'IP_FAMILY'} eq '6' ) {

			if ( $bits < 64 ) {
				return undef;
			}
		} elsif ( $rv->{'IP_FAMILY'} eq '4' ) {
			if ( $bits < 24 ) {
				return undef;
			}
		}
		if ($rv) {
			$sth = $self->prepare($q3)         || $self->return_db_err($self);
			$sth->bind_param( ':ip', $in_ip )  || die $sth->errstr;
			$sth->bind_param( ':sing', $sing ) || die $sth->errstr;
			$sth->execute                      || $self->return_db_err($sth);
			$rv = $sth->fetchrow_hashref;
			$sth->finish;
		}
	}

	$rv;
}

sub get_network_int_purpose {
	my ( $self, $netintid ) = @_;

	my $sth = $self->prepare(
		qq{
		select	network_interface_purpose
		  from	network_interface_purpose
		 where	network_interface_id = ?
	}
	);
	$sth->execute($netintid) || $self->return_db_err($sth);
	my (@rv);
	while ( my $id = $sth->fetchrow_array ) {
		push( @rv, $id );
	}
	\@rv;
}

sub get_device_functions {
	my ( $self, $devid ) = @_;

	# Note: while the device_collection_device table has a rank column,
	# it's not used by the device-function collection type, only by the
	# lb-cluster one, so we simply ignore it here
	my $sth = $self->prepare(
		q{
			SELECT device_collection_id, device_collection_name,
					coalesce(selected, 0) as selected
			FROM device_collection
				LEFT JOIN (select device_collection_id, 1 as selected
					FROM  device_collection_device
					WHERE device_id = ?
				) dc USING (device_collection_id)
			WHERE device_collection_type='device-function'
			ORDER BY device_collection_name
		}
	);
	$sth->execute($devid) || $self->return_db_err($sth);
	my $x = $sth->fetchall_hashref('DEVICE_COLLECTION_NAME');
	return $x;
}

sub get_interface_from_ip {
	my ( $self, $ip ) = @_;

	my $sth = $self->prepare(
		qq{
		select  ni.*,nin.netblock_id
		from network_interface ni
		inner join network_interface_netblock nin
			on ni.network_interface_id = nin.network_interface_id
		inner join netblock nb
			on nb.netblock_id = nin.netblock_id
		where	net_manip.inet_ptodb(?) = nb.ip_address
	}
	);
	$sth->execute($ip) || $self->return_db_err($sth);
	my $rv = $sth->fetchrow_hashref;
	$sth->finish;
	$rv;

}

sub get_interface_from_netblock_id {
	my ( $self, $ip ) = @_;

	my $sth = $self->prepare(
		qq{
		select  ni.*,nin.netblock_id
		  from  network_interface ni inner join network_interface_netblock nin using( network_interface_id )
		 where	netblock_id = ?
	}
	);
	$sth->execute($ip) || $self->return_db_err($sth);
	my $rv = $sth->fetchrow_hashref;
	$sth->finish;
	$rv;

}

#
# returns non-zero if a given IP address is on an interface for a device or
# not.  Primarily used for setting up static routes on hosts
#
sub check_ip_on_local_nets {
	my ( $self, $devid, $ip ) = @_;

	my $sth = $self->prepare(
		qq{
		select count(*)
		from network_interface ni
		inner join network_interface_netblock nin using(network_interface_id)
		inner join netblock nb using (netblock_id)
		where
			ni.device_id = ?
		 and
			net_manip.inet_base(net_manip.inet_ptodb(?),
					family(nb.ip_address)) =
				net_manip.inet_base(nb.ip_address, family(nb.ip_address))
	}
	);

	$sth->execute( $devid, $ip ) || $self->return_db_err($sth);
	my ($count) = $sth->fetchrow_array;
	$sth->errstr;
	$count;
}

sub get_netblock_from_id {
	my ( $self, $nblkid, $opts ) = @_;

	return undef if ( !$nblkid );

	my $morewhere = "";

	#
	# This allows restriction of types of netblock if necessary.
	#
	if ($opts) {
		foreach my $flag ( keys %$opts ) {
			$morewhere .= "AND $flag = :$flag\n";
		}
	}

	my $q = qq{
		select  netblock.*,
			net_manip.inet_dbtop(ip_address) as ip,
			family(ip_address) as family,
			masklen(ip_address) as masklen
		 from   netblock
		where   netblock_id = :nblkid
			$morewhere
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	foreach my $flag ( keys %$opts ) {
		$sth->bind_param( ":$flag", $opts->{$flag} );
	}
	$sth->bind_param( ':nblkid', $nblkid )
	  || die $self->return_db_err($sth);
	$sth->execute || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	return $hr;
}

sub add_netblock {
	my $self = shift @_;
	my $opts = _options(@_);

	# XXX need to deal with more smartly  -- $isorg!!
	#my $type = 'default';
	#if ( $isorg eq 'Y' ) {
	#	return undef;
	#}

	# these are defaults...
	my $new = {
		ip_address      => $opts->{ip_address},
		netblock_type   => 'default',
		ip_universe_id  => 0,
		netblock_status => 'Allocated',
	};

	for my $f (
		'is_single_address', 'netblock_type',
		'can_subnet',        'parent_netblock_id',
		'netblock_status',   'ip_universe_id',
		'description',
	  )
	{
		if ( exists( $opts->{$f} ) ) {
			$new->{$f} = $opts->{$f};
		}
	}

	if ( !defined( $new->{can_subnet} ) ) {
		if ( $new->{is_single_address} eq 'Y' ) {
			$new->{can_subnet} = 'N';
		} else {
			$new->{can_subnet} = 'Y';
		}
	}

	my @errs;
	my $numchanges;
	if ( !(
		$numchanges = $self->DBInsert(
			table  => 'netblock',
			hash   => $new,
			errors => \@errs
		)
	) )
	{
		$self->error_return( join( " ", @errs ) );
	}

	return ( $new->{'NETBLOCK_ID'} );
}

sub get_network_range_from_id {
	my ( $self, $nrid, $opts ) = @_;

	return undef if ( !$nrid );

	my $morewhere = "";

	#
	# This allows restriction of types of network range if necessary.
	#
	if ($opts) {
		foreach my $flag ( keys %$opts ) {
			$morewhere .= "AND $flag = :$flag\n";
		}
	}

	my $q = qq{
		select  network_range.*
		 from   network_range
		where   network_range_id = :nrid
			$morewhere
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	foreach my $flag ( keys %$opts ) {
		$sth->bind_param( ":$flag", $opts->{$flag} );
	}
	$sth->bind_param( ':nrid', $nrid )
	  || die $self->return_db_err($sth);
	$sth->execute || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;

	return $hr;
}

#############################################################################
# begin weird location stuff - XXX
#############################################################################

# cooked is to make it easier for having multiple things named things things.
# I almost certainly need to provide a generic translation routine and return
# something passed to that rather then the uncooked weirdness.  This was just
# a quick hack...  aren't they all?
#
sub get_rackid_from_params {
	my ( $self, $site, $room, $row, $rack ) = @_;

	my $q = qq{
		select 	rack_id
		  from  rack
		 where  site_code = ?
		  AND	room = ?
		  AND	rack_row = ?
		  AND	rack_name = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute( $site, $room, $row, $rack )
	  || $self->return_db_err($sth);
	my ($id) = $sth->fetchrow_array;
	$sth->finish;
	$id;
}

sub get_rack_from_rackid {
	my ( $self, $rackid, $uncooked ) = @_;

	return undef if ( !$rackid );

	my $q = qq{
		select  *
		  from  rack
		 where  rack_id = ?
	};
	if ($uncooked) {
		$q =~ s/\s+as\s+[^,\s]+(,?\s*\n)/$1/gim;
	}
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($rackid)       || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_location_from_devid {
	my ( $self, $devid, $uncooked ) = @_;

	my $q = qq{
		select
			l.RACK_LOCATION_ID,
			l.RACK_ID as LOCATION_RACK_ID,
			l.RACK_U_OFFSET_OF_DEVICE_TOP as LOCATION_RU_OFFSET,
			l.RACK_SIDE as LOCATION_RACK_SIDE,
			r.SITE_CODE as RACK_SITE_CODE,
			r.RACK_TYPE as RACK_TYPE,
			r.DESCRIPTION as RACK_DESCRIPTION
		  from  rack_location l
			inner join device d
				using (rack_location_id)
			inner join rack r on
				r.rack_id = l.rack_id
		 where  d.device_id = ?
	};
	if ($uncooked) {
		$q =~ s/\s+as\s+[^,\s]+(,?\s*\n)/$1/gim;
	}
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($devid)        || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_all_rack_id_and_types {
	my ($self) = @_;

	my $q = qq{
		select  rack_id, rack_type
		  from  rack
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute                || $self->return_db_err($sth);

	my $hr = $sth->fetchall_hashref('RACK_ID');
	$sth->finish;
	$hr;
}

#############################################################################
# end of weird location stuff
#############################################################################

sub guess_dns_domain_from_devid {
	my ( $self, $device ) = @_;

	my $q = qq{
		select  dns_domain_id
		  from  dns_domain
		 where  soa_name = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);

	my $name = $device->{'DEVICE_NAME'};
	while ( $name =~ s/^[^\.]+\.// ) {
		$sth->execute($name) || $self->return_db_err($sth);
		my ($domid) = $sth->fetchrow_array;
		$sth->finish;
		if ( defined($domid) ) {
			return $domid;
		}
	}
	undef;
}

sub get_dns_record_from_id {
	my ( $self, $id ) = @_;

	my $q = qq{
		select  *
		 from   dns_record
		where   dns_record_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id)           || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_dns_record_from_name {
	my ( $self, $shortname, $domid ) = @_;

	my $q;

	if ($domid) {
		$q = qq{
			select  *
			from   dns_record
			where   dns_name = ?
			and	dns_domain_id = ?
		};
	} else {
		$q = qq{
			select  *
			from   dns_record
			left join dns_domain using(dns_domain_id)
			where concat(dns_name,'.',soa_name) = ?
		};
	}
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	if ($domid) {
		$sth->execute( $shortname, $domid ) || $self->return_db_err($sth);
	} else {
		$sth->execute($shortname) || $self->return_db_err($sth);
	}
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_dns_domain_from_id {
	my ( $self, $id ) = @_;

	my $q = qq{
		select  dns_domain_id,
			soa_name,
			soa_class,
			soa_ttl,
			soa_serial,
			soa_refresh,
			soa_retry,
			soa_expire,
			soa_minimum,
			soa_mname,
			soa_rname,
			parent_dns_domain_id,
			should_generate
		 from   v_dns_domain_nouniverse
		where   dns_domain_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id)           || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_dns_domain_from_name {
	my ( $self, $name ) = @_;

	my $q = qq{
		select  dns_domain_id,
			soa_name,
			soa_class,
			soa_ttl,
			soa_serial,
			soa_refresh,
			soa_retry,
			soa_expire,
			soa_minimum,
			soa_mname,
			soa_rname,
			parent_dns_domain_id,
			should_generate
		 from   v_dns_domain_nouniverse
		where   soa_name = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($name)         || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_netblock_from_ip {
	my $self = shift(@_);
	my $opts = _options(@_);

	my @errors;
	my $args = { netblock_type => 'default', };

	# The ip address has no netmask
	if ( $opts->{ip_address} !~ m,/, ) {
		$args->{'host(ip_address)'} = $opts->{ip_address};

		# Remove the implicit /32 netmask suffix if present
	} elsif ( $opts->{ip_address} =~ m,/32 *$, ) {
		$args->{'host(ip_address)'} = $opts->{'ip_address'} =~ s,/32 *$,,r;

		# The ip address has a netmask suffix, but not a /32
	} else {
		$args->{ip_address} = $opts->{ip_address};
	}

	if ( $opts->{'is_single_address'} ) {
		$args->{'is_single_address'} = 'Y';
	}

	if ( $opts->{'netblock_type'} ) {
		$args->{'netblock_type'} = $opts->{'netblock_type'};
	}

	my $netblock = $self->DBFetch(
		table           => 'netblock',
		result_set_size => 'first',
		errors          => \@errors,
		match           => $args,
		order           => 'masklen(ip_address) desc'
	);

	if ( !$netblock ) {
		if (@errors) {
			$self->error_return( "Netblock issue: "
				  . join( ';', @errors ) . "for "
				  . $opts->{ip_address} );
		}
		return undef;
	}

	# XXX - This code doesn't seem to be reachable - to be removed? - smesserli - 2023-05-03
	if ( !$netblock ) {
		if (@errors) {
			$self->error_return(
				"Netblock has hash issue: " . join( ';', @errors ) );
		}
		return undef;
	}
	$netblock;
}

sub get_dev_from_devid {
	my ( $self, $devid ) = @_;

	my $q = qq{
		select  d.*
		  from  device d
		 where  d.device_id = :devid
	};
	my $sth = $self->prepare($q)         || $self->return_db_err($self);
	$sth->bind_param( ':devid', $devid ) || $self->return_db_err($sth);
	$sth->execute                        || $self->return_db_err($sth);

	# when putting this in, make sure that updates to devices don't touch these
	# fields.  I think it's smart, but make sure. -kovert [XXX]
	#			DATA_INS_USER, DATA_INS_DATE,
	#			DATA_UPD_USER, DATA_UPD_DATE

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$self->fill_asset_details_with_device($hr);
}

sub get_asset_from_component_id {
	my ( $self, $compid ) = @_;

	my $q = qq{
		select  *
		  from  asset
		 where  component_id = :compid
	};
	my $sth = $self->prepare($q)           || $self->return_db_err($self);
	$sth->bind_param( ':compid', $compid ) || $self->return_db_err($sth);
	$sth->execute                          || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub fill_asset_details_with_device($$) {
	my ( $self, $dev ) = @_;

	return undef if ( !$dev );

	if ( $dev->{'COMPONENT_ID'} ) {
		my $ass = $self->get_asset_from_component_id( $dev->{'COMPONENT_ID'} );

		foreach my $c (
			qw(ASSET_ID SERIAL_NUMBER PART_NUMBER ASSET_TAG OWNERSHIP_STATUS LEASE_EXPIRATION_DATE)
		  )
		{
			$dev->{$c} = $ass->{$c};
		}
	}
	$dev;
}

sub add_location_to_dev {
	my ( $self, $devid, $loc ) = @_;

	my $new = {
		rack_id                     => $loc->{'RACK_ID'},
		rack_u_offset_of_device_top => $loc->{'RACK_U_OFFSET_OF_DEVICE_TOP'},
		rack_side                   => $loc->{'RACK_SIDE'},
	};

	my $numchanges = 0;
	my @errs;
	if ( !(
		$numchanges += $self->DBInsert(
			table  => 'rack_location',
			hash   => $new,
			errors => \@errs
		)
	) )
	{
		$self->error_return( join( " ", @errs ) );
	}

	my $locid = $new->{'RACK_LOCATION_ID'};

	my ($dq) = qq{
		update	device
		   set	rack_location_id = :locid
		  where	device_id = :devid
	};
	my $dsth = $self->prepare($dq) || $self->return_db_err();
	$dsth->bind_param( ':locid', $locid ) || $self->return_db_err();
	$dsth->bind_param( ':devid', $devid ) || $self->return_db_err();

	$numchanges += $dsth->execute() || $self->return_db_err();

	$numchanges;
}

sub get_dev_from_name {
	my ( $self, $name ) = @_;

	my $q = qq{
		select  *
		  from  device d
		 where  d.device_name = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($name)         || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$self->fill_asset_details_with_device($hr);
}

sub get_dev_from_serial {
	my ( $self, $serno ) = @_;

	my $q = qq{
		SELECT  *
		  FROM  device d
				LEFT JOIN component c USING (component_id)
				LEFT JOIN asset a using  (component_id)
		 WHERE  lower(a.serial_number) = lower(:serno)
		LIMIT 1
	};

	my $sth = $self->prepare($q)         || $self->return_db_err($self);
	$sth->bind_param( ':serno', $serno ) || $self->return_db_err();
	$sth->execute                        || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$self->fill_asset_details_with_device($hr);
}

sub get_snmpcommstr_from_id {
	my ( $self, $snmpid ) = @_;

	my $q = qq{
		select  *
		  from  snmp_commstr
		 where  snmp_commstr_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($snmpid)       || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_snmpstr_count {
	my ( $self, $deviceid ) = @_;

	my $q = qq{
		select  count(*)
		  from  snmp_commstr
		 where  device_id = :devid
	};

	my $sth = $self->prepare($q)            || $self->return_db_err($self);
	$sth->bind_param( ':devid', $deviceid ) || $self->return_db_err($sth);
	$sth->execute()                         || $self->return_db_err($sth);
	my $rv = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$rv;
}

sub ptr_exists {
	my ( $self, $id ) = @_;

	my $q = qq{
		select	count(*)
		  from	dns_record
		 where	netblock_id = ?
		   and	should_generate_ptr = 'Y'
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id)           || $self->return_db_err($sth);
	my $tally = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$tally;
}

#
# Adds a dns record, basically a database hash passed in with some extra
# processing done to make it so not everywhere needs to think about it.
#
sub add_dns_record {
	my $self = shift @_;
	my $opts = shift @_;

	if ( $opts->{DNS_VALUE_RECORD_ID} ) {
		delete( $opts->{DNS_VALUE} );
	} elsif ( $opts->{DNS_TYPE} =~ /^A(AAA)?/ ) {
		delete( $opts->{DNS_VALUE} );
		if ( !$opts->{SHOULD_GENERATE_PTR} ) {
			if ( $self->ptr_exists( $opts->{NETBLOCK_ID} ) ) {
				$opts->{SHOULD_GENERATE_PTR} = 'N';
			} else {
				$opts->{SHOULD_GENERATE_PTR} = 'Y';
			}
		}
	} elsif ( $opts->{DNS_TYPE} eq 'REVERSE_ZONE_BLOCK_PTR' ) {
		$opts->{NETBLOCK_ID} = $opts->{DNS_VALUE};
		delete( $opts->{DNS_VALUE} );
	}

	if ( !$opts->{SHOULD_GENERATE_PTR} ) {
		$opts->{SHOULD_GENERATE_PTR} = 'N';
	}

	my @errs;
	my $x;
	if ( !(
		$x = $self->DBInsert(
			table  => 'dns_record',
			hash   => $opts,
			errors => \@errs
		)
	) )
	{
		$self->error_return( join( " ", @errs ) );
	}
	return ( $opts->{'DNS_RECORD_ID'} );
}

sub fetch_property {
	my ( $self, $type, $name ) = @_;

	my @errs;
	my $match = [ {
			key   => 'property_name',
			value => $name,
		},
		{
			key   => 'property_type',
			value => $type,
		},
	];
	my $rows = $self->DBFetch(
		table  => 'property',
		match  => $match,
		errors => \@errs
	) || die $self->return_db_err();
	my $hr = $rows->[0];
	if ( $hr && defined( $hr->{property_value} ) ) {
		return $hr->{property_value};
	}
	return undef;
}

sub configure_allocated_netblock {
	my ( $self, $ip, $nblk ) = @_;

	my $parnb;
	if ( !defined($nblk) ) {
		$parnb = $self->guess_parent_netblock_id( $ip, undef, 'Y' );

		# if the ip addres is 0/0 (or 0/anything), then it should
		# be considered unset
		if ( !defined($parnb) || ( !$parnb->{'IP_ADDRESS'} ) ) {
			$self->error_return("Unable to find network for $ip");
		}
	} elsif ( $nblk->{'NETBLOCK_STATUS'} eq 'Allocated' ) {
		my $nbid = $nblk->{'NETBLOCK_ID'};
		if ( $self->get_interface_from_netblock_id($nbid) ) {
			return $self->error_return("$ip is in use on a device");
		} else {

			# nothing to change about the block; returning.
			return $nblk;
		}

	}

	# if netblock is reserved, switch it to allocated
	if (
		defined($nblk)
		&& (   $nblk->{'NETBLOCK_STATUS'} eq 'Legacy'
			|| $nblk->{'NETBLOCK_STATUS'} eq 'Reserved' )
	  )
	{
		my $q = qq{
			update	netblock
		       set	netblock_status = 'Allocated'
		 	 where	netblock_id = ?
		};
		my $sth = $self->prepare($q) || $self->return_db_err($self);
		$sth->execute( $nblk->{'NETBLOCK_ID'} )
		  || $self->return_db_err($sth);
	} else {
		my $h = {
			ip_address        => $ip,
			is_single_address => 'Y',
			netblock_type     => 'default',
			can_subnet        => 'N',
			netblock_status   => 'Allocated',
		};
		my $nblkid = $self->add_netblock($h);
		$nblk = $self->get_netblock_from_id($nblkid);
	}
	$nblk;
}

sub get_operating_system_from_id {
	my ( $self, $id ) = @_;

	my $q = qq{
		select  os.operating_system_id,
			c.company_name,
			os.company_id,
			os.operating_system_name,
			os.version
		  from  operating_system os
			inner join company c on
				c.company_id = os.company_id
		 where  os.operating_system_id = ?
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id)           || $self->return_db_err($sth);
	my $os = $sth->fetchrow_hashref;
	$sth->finish;
	$os;
}

sub get_device_from_id {
	my ( $self, $id ) = @_;

	# This can go back to just * when the asset columns are dropped
	# from device
	my $q = qq{
		select  *
		  from device d
		where device_id = ?
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id)           || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$self->fill_asset_details_with_device($hr);
}

sub get_device_type_from_id {
	my ( $self, $id ) = @_;

	my $q = qq{
		select  dt.DEVICE_TYPE_ID, c.company_name,
			-- p.address as partner_address, XXX
			c.company_id, dt.model,
			dt.config_fetch_type, dt.rack_units,
			dt.description,
			dt.has_802_3_interface,
			dt.has_802_11_interface,
			dt.processor_architecture,
			dt.snmp_capable
		  from  device_type dt
			inner join company c
				on dt.company_id = c.company_id
		where   dt.device_type_id = ?
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($id)           || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$self->fill_asset_details_with_device($hr);
}

sub get_device_type_from_name {
	my ( $self, $companyid, $model ) = @_;

	my $q = qq{
		select  dt.DEVICE_TYPE_ID, c.company_name,
			-- p.address as partner_address, XXX
			dt.company_id, dt.model,
			dt.config_fetch_type, dt.rack_units,
			dt.description,
			dt.has_802_3_interface,
			dt.has_802_11_interface,
			dt.snmp_capable
		  from  device_type dt
			inner join company c
				on dt.company_id = c.company_id
		where   c.company_id = ?
		 AND	dt.model = ?
	};

	my $sth = $self->prepare($q)        || $self->return_db_err($self);
	$sth->execute( $companyid, $model ) || $self->return_db_err($sth);

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$self->fill_asset_details_with_device($hr);
}

sub get_physical_path_from_l1conn {
	my ( $self, $l1conn ) = @_;

	my $q = qq{
		select	pc.PHYSICAL_CONNECTION_ID,
			pc.cable_type,
			p1.physical_port_id as pc_p1_physical_port_id,
			p1.port_name as pc_p1_physical_port_name,
			d1.device_id as pc_p1_device_id,
			d1.device_name as pc_p1_device_name,
			p2.physical_port_id as pc_p2_physical_port_id,
			p2.port_name as pc_p2_physical_port_name,
			d2.device_id as pc_p2_device_id,
			d2.device_name as pc_p2_device_name
		  from	v_physical_connection vpc
			inner join physical_connection pc
				using (physical_connection_id)
			inner join physical_port p1
				on p1.physical_port_id = pc.physical_port1_id
			inner join device d1
				on d1.device_id = p1.device_id
			inner join physical_port p2
				on p2.physical_port_id = pc.physical_port2_id
			inner join device d2
				on d2.device_id = p2.device_id
		where	vpc.layer1_connection_id = ?
		order by level
	};

	my $sth = $self->prepare($q) || $self->return_db_err($self);

	$sth->execute($l1conn) || die $self->return_db_err($sth);

	my (@rv);
	while ( my $hr = $sth->fetchrow_hashref ) {
		push( @rv, $hr );
	}
	if ( $#rv == -1 ) {
		undef;
	} else {
		\@rv;
	}
}

sub get_layer1_connection_from_port {
	my ( $self, $port ) = @_;

	my $q = qq{
		select	layer1_connection_id,
			PHYSICAL_PORT1_ID,
			PHYSICAL_PORT2_ID,
			CIRCUIT_ID,
			BAUD,
			DATA_BITS,
			STOP_BITS,
			PARITY,
			FLOW_CONTROL
		  from	layer1_connection
		 where	physical_port1_id = :pportid or
			physical_port2_id = :pportid
	};
	my $sth = $self->prepare($q)          || $self->return_db_err($self);
	$sth->bind_param( ':pportid', $port ) || $self->return_db_err;
	$sth->execute                         || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_layer1_connection {
	my ( $self, $l1cid ) = @_;

	my $q = qq{
		select	layer1_connection_id,
			PHYSICAL_PORT1_ID,
			PHYSICAL_PORT2_ID,
			CIRCUIT_ID,
			BAUD,
			DATA_BITS,
			STOP_BITS,
			PARITY,
			FLOW_CONTROL
		  from	layer1_connection
		 where	layer1_connection_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($l1cid)        || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_physical_port {
	my ( $self, $pportid ) = @_;

	my $q = qq{
		select	PHYSICAL_PORT_ID,
			DEVICE_ID,
			PORT_NAME,
			PORT_TYPE,
			DESCRIPTION,
			PHYSICAL_LABEL,
			PORT_PURPOSE,
			TCP_PORT
		  from	physical_port
		 where	physical_port_id = ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);
	$sth->execute($pportid)      || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_physical_port_byport {
	my ( $self, $devid, $port, $type ) = @_;

	my $q = qq{
		select	PHYSICAL_PORT_ID,
			DEVICE_ID,
			PORT_NAME,
			PORT_TYPE,
			DESCRIPTION,
			PHYSICAL_LABEL,
			PORT_PURPOSE,
			TCP_PORT
		  from	physical_port
		 where	device_id = ?
		   and	port_name = ?
		   and	port_type = ?
	};
	my $sth = $self->prepare($q)          || $self->return_db_err($self);
	$sth->execute( $devid, $port, $type ) || $self->return_db_err($sth);
	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_physical_port_tally {
	my ( $self, $devid, $type, $limit ) = @_;

	my $limitq = "";
	if ($limit) {

		# ORACLE/PGSQL
		#$limitq = "and	regexp_matches(port_name, ?)";
		$limitq = "and	port_name ~ ?";
	}

	my $sth = $self->prepare(
		qq{
		select	count(*)
		  from	physical_port
		 where	device_id = ?
		   and	port_type = ?
		   $limitq
	}
	);
	if ( defined($limit) ) {
		$sth->execute( $devid, $type, $limit )
		  || $self->return_db_err($sth);
	} else {
		$sth->execute( $devid, $type ) || $self->return_db_err($sth);
	}
	my ($tally) = $sth->fetchrow_array;
	$sth->finish;
	$tally;
}

sub get_physical_ports_for_dev {
	my ( $self, $devid, $type ) = @_;

	my (@rv);

	my $sth;
	if ($type) {
		my $q = qq{
			select	physical_port_id
			  from	physical_port
			 where	device_id = ?
			   and	port_type = ?
		};
		$sth = $self->prepare($q)      || $self->return_db_err($self);
		$sth->execute( $devid, $type ) || $self->return_db_err($sth);
	} else {
		my $q = qq{
			select	physical_port_id
			  from	physical_port
			 where	device_id = ?
		};
		$sth = $self->prepare($q) || $self->return_db_err($self);
		$sth->execute($devid)     || $self->return_db_err($sth);
	}
	while ( my ($id) = $sth->fetchrow_array ) {
		push( @rv, $id );
	}
	$sth->finish;
	\@rv;
}

sub get_num_dev_notes {
	my ( $self, $devid ) = @_;

	my $q = qq{
		select	count(*)
		  from	device_note
		 where	device_id = :devid
	};
	my $sth = $self->prepare($q)         || $self->return_db_err($self);
	$sth->bind_param( ':devid', $devid ) || $self->return_db_err($sth);
	$sth->execute()                      || $self->return_db_err($sth);

	my $tally = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$tally;
}

sub add_to_device_collection {
	my ( $self, $devid, $dcid ) = @_;

	my $sth = $self->prepare(
		qq{
		insert into device_collection_device (
			device_collection_id,
			device_id
		) values (
			?,
			?
		)
	}
	) || $self->return_db_err;

	my $numchanges = 0;
	$numchanges += $sth->execute( $dcid, $devid )
	  || $self->return_db_err($sth);
	$numchanges;
}

sub remove_from_device_collection {
	my ( $self, $devid, $dcid, $type ) = @_;

	my $q = qq{
		delete from device_collection_device
		 where	device_collection_id = :dc
		  and	device_id = :devid
	};

	if ($type) {
		$q .= qq{and device_collection_id in
			(select device_collection_id
			   from device_collection
			  where	device_collection_type = :type
			)
		};
	}

	my $sth = $self->prepare($q) || $self->return_db_err;

	my $numchanges = 0;
	$sth->bind_param( ':dc',    $dcid )  || $self->return_db_err($sth);
	$sth->bind_param( ':devid', $devid ) || $self->return_db_err($sth);
	if ($type) {
		$sth->bind_param( ':type', $type )
		  || $self->return_db_err($sth);
	}
	$numchanges += $sth->execute || $self->return_db_err($sth);
	$numchanges;
}

sub get_device_collection {
	my ( $self, $dcid ) = @_;

	my $sth = $self->prepare(
		qq{
		select	*
		  from	device_collection
		 where	device_collection_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($dcid) || $self->return_db_err($sth);
	my $dc = $sth->fetchrow_hashref;
	$sth->finish;
	$dc;
}

sub get_device_collections_for_device {
	my ( $self, $devid, $type ) = @_;

	my @dcids;
	my $q = qq{
		select	device_collection_id
		  from	device_collection_device
		 where	device_id = :devid
		  and
				device_collection_id not in
					(select parent_device_collection_id
					  from	v_device_collection_hier_trans
					)
	};
	if ($type) {
		$q .= qq{and device_collection_id in
			(select device_collection_id
			  from device_collection
			  where device_collection_type = :type
			)
		};
	}

	my $sth = $self->prepare($q) || $self->return_db_err;

	$sth->bind_param( ':devid', $devid ) || $self->return_db_err($sth);
	if ($type) {
		$sth->bind_param( ':type', $type )
		  || $self->return_db_err($sth);
	}

	$sth->execute || $self->return_db_err($sth);

	my (@rv);
	while ( my ($dcid) = $sth->fetchrow_array ) {
		push( @rv, $dcid );
	}
	@rv;
}

#
# given an id, return the netblock_collection record
#
sub get_netblock_collection($$) {
	my ( $self, $id ) = @_;

	my $sth = $self->prepare(
		qq{
		select	*
		  from	netblock_collection
		 where	netblock_collection_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($id) || $self->return_db_err($sth);
	my $nc = $sth->fetchrow_hashref;
	$sth->finish;
	$nc;
}

#
# given an id, return the account_collection record
#
sub get_account_collection($$) {
	my ( $self, $id ) = @_;

	my $sth = $self->prepare(
		qq{
		select	*
		  from	account_collection
		 where	account_collection_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($id) || $self->return_db_err($sth);
	my $nc = $sth->fetchrow_hashref;
	$sth->finish;
	$nc;
}

sub get_system_user {
	my ( $self, $suid ) = @_;

	my $sth = $self->prepare(
		qq{
		select  *
		  from  system_user
		 where  system_user_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($suid) || $self->return_db_err;

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub is_static_route_on_device {
	my ( $self, $devid, $niid, $nbid ) = @_;

	my $sth = $self->prepare(
		qq{
		select	count(*)
		  from	static_route
		 where	device_src_id = ?
		   and	network_interface_dst_id = ?
		   and	netblock_id = ?
	}
	);
	$sth->execute( $devid, $niid, $nbid ) || $self->return_db_err;

	my ($tally) = $sth->fetchrow_array;
	$sth->finish;
	$tally;
}

sub add_static_route_from_template {
	my ( $self, $devid, $tmpltid ) = @_;

	my $sth = $self->prepare(
		qq{
		insert into static_route
			(device_src_id, network_interface_dst_id, netblock_id)
		select
			?, NETWORK_INTERFACE_DST_ID, NETBLOCK_SRC_ID
		from
			static_route_template
		where
			STATIC_ROUTE_TEMPLATE_ID = ?
	}
	);

	my $tally += $sth->execute( $devid, $tmpltid )
	  || $self->return_db_err($sth);
	$tally;
}

sub rm_static_route_from_device {
	my ( $self, $srid ) = @_;

	my $sth = $self->prepare(
		qq{
		delete from static_route where static_route_id = ?
	}
	);
	my $tally += $sth->execute($srid) || $self->return_db_err($sth);
	$tally;
}

sub rm_static_route_from_netblock {
	my ( $self, $srid ) = @_;

	my $sth = $self->prepare(
		qq{
		delete from static_route_template where static_route_template_id = ?
	}
	);
	my $tally += $sth->execute($srid) || $self->return_db_err($sth);
	$tally;
}

sub validate_route_entry {
	my ( $self, $srcip, $srcbits, $destip ) = @_;

	if (
		( defined($srcip) || defined($srcbits) || defined($destip) )
		&& (   !defined($srcip)
			|| !defined($srcbits)
			|| !defined($destip) )
	  )
	{
		$self->error_return(
			"Must specify all of ip, bits and dest IP for static route route");
	}

	if ($srcip) {
		if ( !$self->validate_ip($srcip) ) {
			$self->error_return(
				"$srcip for static route is an invalid IP address");
		}
		if ( !$self->validate_ip($destip) ) {
			$self->error_return(
				"$destip for static route is an invalid IP address");
		}

		if ( $srcbits !~ /^\d+$/ || $srcbits > 32 ) {
			$self->error_return(
				"$srcbits for static route is not a valid number of bits.");
		}

		# check valid ip, bits, dest ip
		my $ni = $self->get_interface_from_ip($destip);

		if ( !$ni ) {
			$self->error_return(
				"$destip does not correspond to any network interfaces on this device in the database."
			);
		}

		my $nb = $self->get_netblock_from_ip( $srcip, $srcbits, 'N', 'N' );

		if ( !$nb ) {
			my $parnb = $self->guess_parent_netblock_id( $srcip, $srcbits );
			$nb = $self->add_netblock(
				ip_address         => $srcip,
				parent_netblock_id => $parnb->{'NETBLOCK_ID'},
				netblock_type      => 'default',    # XXX -- need to reconsider!
			);
		}

		if ( !$nb ) {
			confess
			  "WEIRD: could not create route on $destip for $srcip/$srcbits to $destip "
			  . $ni->{'NETWORK_INTERFACE_ID'};
			$self->error_return(
				"There was a temporary error creating the static route.  Please report this. "
			);
		}

		return ( $ni, $nb );
	}

}

sub resync_device_power {
	my ( $self, $dev ) = @_;

	my $sth = $self->prepare(
		qq{
		insert into device_power_interface
			(device_id, power_interface_port)
		select	:devid, power_interface_port
		  from	DEVICE_TYPE_POWER_PORT_TEMPLT
		 where	device_type_id = :dtid
		   and	power_interface_port not in
			(select power_interface_port from device_power_interface
				where device_id = :devid
			)
	}
	);
	$sth->bind_param( ':devid', $dev->{'DEVICE_ID'} )
	  || $self->return_db_err;
	$sth->bind_param( ':dtid', $dev->{'DEVICE_TYPE_ID'} )
	  || $self->return_db_err;

	my $tally = $sth->execute() || $self->return_db_err($sth);
	$tally;
}

sub resync_physical_ports {
	my ( $self, $dev, $type ) = @_;

	my $typeadd = "";
	if ($type) {
		$typeadd = "and port_type = :ptype";
	}

	my $sth = $self->prepare(
		qq{
		insert into physical_port
			(device_id, port_name, port_type)
		select	:devid, port_name, port_type
		  from	device_type_phys_port_templt
		 where	device_type_id = :dtid
		   $typeadd
		   and	(port_name,port_type) not in
				(select port_name,port_type
					 from physical_port
					where device_id = :devid
				)
	}
	);
	$sth->bind_param( ':devid', $dev->{'DEVICE_ID'} )
	  || $self->return_db_err($sth);
	$sth->bind_param( ':dtid', $dev->{'DEVICE_TYPE_ID'} )
	  || $self->return_db_err($sth);
	if ($type) {
		$sth->bind_param( ':ptype', $type )
		  || $self->return_db_err($sth);
	}
	my $tally += $sth->execute || $self->return_db_err($sth);
	$tally;
}

sub get_power_port_count {
	my ( $self, $devid ) = @_;

	my $sth = $self->prepare(
		qq{
			select	count(*)
			  from	device_power_interface
			 where	device_id = ?
		}
	) || die $self->return_db_err;

	$sth->execute($devid) || $self->return_db_err;
	my $count = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$count;
}

sub get_physical_port_count {
	my ( $self, $devid, $type ) = @_;

	my $sth = $self->prepare(
		qq{
			select	count(*)
			  from	physical_port
			 where	device_id = ?
			   and	port_type = ?
		}
	) || die $self->return_db_err;

	$sth->execute( $devid, $type ) || $self->return_db_err;
	my $count = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$count;
}

sub get_circuit {
	my ( $self, $cid ) = @_;

	my $sth = $self->prepare(
		qq{
		select  *
		  from  circuit
		 where  circuit_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($cid) || $self->return_db_err;

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_trunk_group {
	my ( $self, $cid ) = @_;

	my $sth = $self->prepare(
		qq{
		select  *
		  from  trunk_group
		 where  trunk_group_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($cid) || $self->return_db_err;

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

sub get_x509_cert_by_id {
	my ( $self, $certid ) = @_;

	my $sth = $self->prepare(
		qq{
		select	*
		  from	x509_certificate
		 where	x509_cert_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($certid) || $self->return_db_err;

	my $hr = $sth->fetchrow_hashref;
	$sth->finish;
	$hr;
}

#
# NOTE:  This is called via an ajax call in device-ajax.pl +
# netblock/index.pl
#
sub build_netblock_ip_row {
	my ( $self, $params, $blk, $hr, $ip ) = @_;

	my $cgi = $self->cgi;

	#
	# This is used to present a gap that a user can expand to add more
	# IP addresses;  used mostly with IPv6 where there is potential for
	# huge spaces between assignments
	if ( $params && $params->{-gap} ) {
		my $trgap   = $params->{-trgap};
		my $gapsize = $params->{-gap};
		my $gapno   = $params->{-gapno};

		my $gapnoid = 'nbgap' . $gapno;
		my $rowid   = "trgap_" . $trgap++;
		return $cgi->Tr( {
				-style => 'text-align: center',
				-id    => $rowid,
			},
			$cgi->td( $cgi->a( {
					-href    => 'javascript:void(null);',
					-onClick => qq{AddIpSpace(this, "$rowid", "$gapnoid");},
				},
				"ADD",
			) ),
			$cgi->td(
				{ -colspan => 5 },
				$cgi->em(
					$cgi->span( { -id => $gapnoid }, $gapsize ),
					"address gap"
				),
			),
		);
	}

	my $showtr = 1;

	my ( $id, $devid, $name, $dom, $status, $desc, );

	$status = "";
	$name   = "";
	$dom    = "";

	my $editabledesc = 1;

	my $uniqid = $ip;
	$uniqid =~ s,/\d+$,, if ($uniqid);
	if ( defined( $params->{-uniqid} ) ) {
		$uniqid = "new_" . $params->{-uniqid};
	} elsif ( !defined($uniqid) ) {
		$uniqid = "__R" . rand();
	}

	my $printip;
	if ( !defined($ip) ) {

		# [XXX] probably should not asssume this will be there.
		$showtr  = 0;
		$printip = $cgi->textfield(
			-name => "ip_$uniqid",
			-size => '30',
		);
	} else {
		$printip = $ip;
		$ip =~ s,/\d+$,,;
	}

	my $fqhn = "";
	if ( defined($hr) ) {
		$id     = $hr->{'NETBLOCK_ID'};
		$devid  = $hr->{'DEVICE_ID'};
		$name   = $hr->{'DNS_NAME'};
		$dom    = $hr->{'SOA_NAME'};
		$status = $hr->{'NETBLOCK_STATUS'};
		$desc   = $hr->{'DESCRIPTION'} || "";

		my $recid = $hr->{'DNS_RECORD_ID'};

		if ( $status ne 'Reserved' && $status ne 'Legacy' ) {
			$editabledesc = 0;
		}

		# $printip = $ip;
		# $ip =~ s,/\d+$,,;

		if ( defined($name) ) {
			$fqhn = $name . ( defined($dom) ? ".$dom" : "" );
		}

		if ( $status eq 'Reserved' || $status eq 'Legacy' ) {
			$editabledesc = 1;

			# allow descriptions to not match DNS
			#if ( !defined($devid) && $fqhn ) {
			#	$desc = $fqhn;
			#}
		}

		if ( defined($devid) ) {
			$printip =
			  $cgi->a( { -href => "../device/device.pl?devid=$devid" },
				$printip );
		}

		if ( defined($recid) ) {
			$fqhn =
			  $cgi->a( { -href => "../dns/?DNS_RECORD_ID=$recid" }, $fqhn );
		}
	} else {
		$editabledesc = 1;
	}

	#
	# When device ids are not set, then allow the dns name to be changed
	# or set from here
	#
	if ( !$devid ) {
		$fqhn = $cgi->span( { -class => 'editdns' }, $fqhn );
	}

	if ($editabledesc) {
		my $h = $cgi->hidden(
			-name    => "rowblk_$uniqid",
			-default => $id
		);

		#$desc = ( ($id) ? $h : "" )
		#  . $cgi->textfield(
		#	-name    => "desc_$uniqid",
		#	-default => ( ($desc) ? $desc : "" ),
		#	-size    => 50
		#  );
		$desc = $h
		  . $cgi->span( { -class => 'editabletext', -id => "desc_$uniqid" },
			( $desc || "" ) );
	}

	my $url;

	my $trid = $uniqid;

	my $tds = $cgi->td( [ $printip, $status, $fqhn, $desc ] );

	my $rv;
	if ($showtr) {
		$rv = $cgi->Tr( { -id => $trid }, $tds );
	} else {
		$rv = $tds;
	}
	return $rv;
}

#
# given an IP, returns the forward record that defines that
# PTR record
#
sub get_dns_a_record_for_ptr {
	my ( $self, $ip ) = @_;

	# NOTE: need to reconsider ip universes
	my (@errs);
	my $rows = $self->DBFetch(
		table => 'netblock',
		match => {
			'host(ip_address)'  => $ip,
			'is_single_address' => 'Y',
			'ip_universe_id'    => 0,
			'host(ip_address)'  => $ip
		},
		errors => \@errs
	);
	my $nblk = undef;
	foreach my $n (@$rows) {
		next if ( $n->{netblock_type} !~ /^(dns|default)$/ );
		$nblk = $n;
		last;
	}
	return undef if !$nblk;

	my $dns = $self->DBFetch(
		table => 'dns_record',
		match => {
			netblock_id         => $nblk->{netblock_id},
			should_generate_ptr => 'Y',
		},
		errors => \@errs
	);
	return undef if !$dns;

	return $dns->[0]->{dns_record_id};
}

sub process_and_insert_dns_record {
	my $self = shift @_;
	my $opts = shift @_;

	if ( $opts->{DNS_TYPE} =~ /^A(AAA)?/ && !$opts->{DNS_VALUE_RECORD_ID} ) {
		my $i = new Net::IP( $opts->{DNS_VALUE} )
		  || $self->error_return( $opts->{DNS_VALUE}
			  . " is not a valid IP address ("
			  . Net::IP::Error()
			  . ")" );

		my $block = $self->get_netblock_from_ip(
			ip_address        => $opts->{DNS_VALUE},
			is_single_address => 'Y'
		);
		if ( !$block ) {
			$block = $self->get_netblock_from_ip(
				ip_address        => $opts->{DNS_VALUE},
				netblock_type     => 'dns',
				is_single_address => 'Y',
			);
		}

		# now figure out what to do if ptr is set.  If it is set,
		# then we unconditionally make other records not have the PTR.
		# If it is not set, we set it for the user if the IP address
		# is showing up for the first time

		if (   exists( $opts->{'SHOULD_GENERATE_PTR'} )
			&& defined( $opts->{'SHOULD_GENERATE_PTR'} )
			&& $opts->{'SHOULD_GENERATE_PTR'} eq 'Y' )
		{
			# set all other dns_records but this one to have
			# ptr = 'N'. More than one should never happen, but
			# this is a while loop just in case.
			while ( my $recid =
				$self->get_dns_a_record_for_ptr( $opts->{DNS_VALUE} ) )
			{
				$self->run_update_from_hash( "DNS_RECORD",
					"DNS_RECORD_ID", $recid, { SHOULD_GENERATE_PTR => 'N' } );
			}
		} else {
			if (   !$self->get_dns_a_record_for_ptr( $opts->{DNS_VALUE} )
				&& !$opts->{DNS_VALUE_RECORD_ID} )
			{
				$opts->{'SHOULD_GENERATE_PTR'} = 'Y';
			} else {
				$opts->{'SHOULD_GENERATE_PTR'} = 'N';
			}
		}

		# Wildcard dns records must not have the PTR set
		if ( $opts->{DNS_NAME} =~ /\*/ ) {
			$opts->{'SHOULD_GENERATE_PTR'} = 'N';
		}

		my $id;
		if ( !defined($block) ) {
			my $h = {
				ip_address        => $opts->{DNS_VALUE},
				is_single_address => 'Y'
			};
			if ( !(
				my $par = $self->guess_parent_netblock_id( $opts->{DNS_VALUE} )
			) )
			{
				# XXX This is outside our IP universe, which we should probably
				# print a warning on, but lacking that, it gets created as a
				# type dns
				$h->{netblock_type} = 'dns';
			}
			$id = $self->add_netblock($h)
			  || die $self->return_db_err();
		} else {
			$id = $block->{'NETBLOCK_ID'};
		}

		$opts->{NETBLOCK_ID} = $id;
	}
	$self->add_dns_record($opts);

	return 1;
}

sub delete_netblock {
	my ( $self, $nblkid, $fkok ) = @_;

	# XXX - note, using bind variables gives an error
	# presumably because things are nested.  This probably
	# wants to move to a stored procedure.  yay.
	my $q = qq{
		delete from netblock where netblock_id = $nblkid;
	};

	my $sth;
	if ($fkok) {
		$q = q{
			DO $$
			BEGIN
		} . $q . q{
			EXCEPTION WHEN foreign_key_violation THEN
				NULL;
			END
			$$
		};
		$sth = $self->prepare($q) || die $self->return_db_err();

		#- $sth->bind_param(':id', $nblkid) || die $self->return_db_err();
	} else {
		$sth = $self->prepare(
			qq{
			delete from netblock where netblock_id = :id
		}
		) || die $self->return_db_err();
		$sth->bind_param( ':id', $nblkid );
	}

	$sth->execute || die $self->return_db_err($sth);
}

#
# Builds a list of dns domains
#
sub build_dns_drop {
	my $self = shift @_;
	my $onid = shift @_;
	my $type = shift @_;

	my $where = "";
	if ($type) {
		$where = "WHERE dns_domain_type = :dnsdomaintype";
	}
	my $sth = $self->prepare(
		qq{
		SELECT  DNS_DOMAIN_ID, SOA_NAME
		  FROM  DNS_DOMAIN
		  $where
		  ORDER BY CASE WHEN dns_domain_type = 'reverse' THEN 1
			ELSE 0 END, soa_name
	}
	) || die;
	if ($type) {
		$sth->bind_param( ':dnsdomaintype', $type );
	}
	$sth->execute;
	my $r = {};
	if ( !$onid ) {
		$r->{options}->{'__unknown__'} = {
			value    => '__unknown__',
			text     => 'Please Choose',
			selected => 'true',
		};
	}
	while ( my ( $id, $name ) = $sth->fetchrow_array ) {
		$r->{options}->{$id} = {
			'value' => $id,
			'text'  => $name,
		};
		if ( $onid && $id == $onid ) {
			$r->{'options'}->{$id}->{'selected'} = 'true';
		}
	}
	$sth->finish;
	$r;
}

#
# Builds a list of dns dns types for pushing into jquery
#
sub build_dns_type_drop {
	my $self = shift @_;
	my $type = shift @_;

	my $sth = $self->prepare(
		qq{
		select  dns_type, description
		  from  val_dns_type
		WHERE	id_type IN ('ID','NON-ID')
	}
	) || die;
	$sth->execute;

	my @rv;
	push(
		@rv,
		{
			value    => '__unknown__',
			text     => 'Please Choose',
			selected => 'true',
		}
	);
	while ( my ( $id, $desc ) = $sth->fetchrow_array ) {
		my $r = {};
		$r->{$id}->{'value'} = $id;
		$r->{'text'} = $desc || $id;
		push( @rv, $r );
	}
	$sth->finish;
	\@rv;
}

sub build_dns_classes_drop {
	my $self = shift @_;

	my $sth = $self->prepare(
		qq{
		select  dns_class, description
		  from  val_dns_class
	}
	) || die;
	$sth->execute;
	my @rv;
	while ( my ( $id, $desc ) = $sth->fetchrow_array ) {
		my $r = {};
		$r->{'value'} = $id;
		$r->{'text'}  = $desc || $id;
		if ( $id eq 'IN' ) {
			$r->{selected} = 'true';
		}
		push( @rv, $r );
	}
	$sth->finish;
	\@rv;
}

#
# check to see if account is in another's managment chain
#
sub check_management_chain($$;$) {
	my $self          = shift @_;
	my $acctid        = shift @_;
	my $possiblemgrid = shift @_ || $self->get_account_id();

	return 1 if ( $acctid == $possiblemgrid );

	my $sth = $self->prepare(
		q{
		SELECT	manager_account_id
		FROM	v_account_manager_hier
		WHERE	account_id = ?
	}
	) || die $self->return_db_err;

	$sth->execute($acctid) || $self->return_db_err($sth);

	while ( my ($mid) = $sth->fetchrow_array ) {
		if ( $mid && $mid == $possiblemgrid ) {
			$sth->finish;
			return 1;
		}
	}

	0;
}

#
# this really needs to get rethunk to handle optional recursion on both sides
# and what not.  This is just kind of gross.
#
# returns undef on no permissions or error.
#
# Needs to have a global admin permission shortcut.
#
sub get_account_collection_permissions($$;$) {
	my $self = shift @_;
	my $type = shift @_;

	my $clause;
	if ($type) {
		if ( $type eq 'RO' ) {
			$clause =
			  q{property_name IN ('AccountCollectionRO','AccountCollectionRW')};
		} elsif ( $type eq 'RW' ) {
			$clause = q{property_name ='AccountCollectionRW'};
		}
	}

	return undef if ( !$clause );

	my $cachename = "_cache_account_collection_perms.$type";

	if ( exists( $self->{$cachename} ) ) {
		return $self->{$cachename};
	}

	my $sth = $self->prepare(
		qq{
		SELECT	child_account_collection_id as account_collection_id,
				h.account_collection_name,
				h.account_collection_type
		FROM	property p
		JOIN	account_collection ac USING (account_collection_id)
		JOIN	(
				SELECT	h.account_collection_id AS
							property_value_account_coll_id,
						child_account_collection_id,
						account_collection_name,
						account_collection_type
				FROM account_collection_hier h
					JOIN account_collection ac ON
						h.child_account_collection_id =
							ac.account_collection_id
				) h USING (property_value_account_coll_id)
		JOIN	v_acct_coll_acct_expanded ace USING (account_collection_id)
		JOIN	v_corp_family_account a ON a.account_id =  ace.account_id
		WHERE	property_type = 'StabRole'
		AND		$clause
		AND		login = ?
	}
	) || die $self->return_db_err;

	my $rv = { type => [], collections => [] };
	$sth->execute( $self->{_username} )
	  || return $self->return_db_err();
	while ( my $hr = $sth->fetchrow_hashref ) {
		if (   !exists( $rv->{types} )
			|| !grep( $_ eq $hr->{'ACCOUNT_COLLECTION_TYPE'}, $rv->{types} ) )
		{
			push( @{ $rv->{types} }, $hr->{'ACCOUNT_COLLECTION_TYPE'} );
		}
		push( @{ $rv->{collections} }, $hr );
	}

	#
	# no permissions or error return undef
	#
	if ( scalar( @{ $rv->{collections} } ) ) {
		$self->{$cachename} = $rv;
	} else {
		$self->{$cachename} = undef;
	}
}

#
# calls the above and is used to lookup if a user has permission on a given
# account collection
#
sub check_account_collection_permissions($$$) {
	my $self = shift @_;
	my $acid = shift @_;
	my $type = shift @_ || 'RO';

	my $perms = $self->get_account_collection_permissions($type);

	if (
		grep( $_->{'ACCOUNT_COLLECTION_ID'} == $acid,
			@{ $perms->{collections} } )
	  )
	{
		1;
	} else {
		0;
	}
}

1;
__END__

=head1 NAME

JazzHands::STAB::DBAccess - DB interface routines that belong elsewhere

=head1 SYNOPSIS

	don't use this directly; use JazzHands::STAB instead

=head1 DESCRIPTION

DB routines isolated here that need to be foled into a more generic
system

=head1 SEE ALSO

=head1 AUTHOR

Todd Kover

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
