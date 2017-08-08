#!/usr/bin/env perl

# TODO:
# - deal with ordering, TXT records on zone were coming later sometimes
# - pulling up child zones with ip universe bits
# - trigger enforcement of various data across ip universes keeping in mind
#	ip_universe_visibility
# - zonegen deals with per-server in a sane fashion
# - dns domain collection association for "put these zones anyway" on per-server

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
# Automatically generate zones from JazzHands, including hierarchies
# appropriate for disting to nameservers.  It's totally awesome.
#

use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case bundling);
use JazzHands::Common::Util qw(_dbx);
use Pod::Usage;
use Data::Dumper;

### XXX: SIGALRM that kills after one zone hasn't been processed for 20 mins?

# local $SIG{__WARN__} = \&Carp::cluck;

# This is required and the db is assumed to be returning UTC dates.
$ENV{'TZ'}   = 'UTC';
$ENV{'PATH'} = $ENV{'PATH'} . ":/usr/local/sbin:/usr/sbin";

umask(022);

##############################################################################

package JazzHands::ZoneGeneration;

use strict;
use warnings;
use FileHandle;
use File::Compare;
use JazzHands::DBI;
use JazzHands::Common qw(:all);
use Data::Dumper;
use POSIX;
use Carp;
use utf8;
use parent 'JazzHands::Common';

our $errstr;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	my $self = $class->SUPER::new(@_);
	return undef if ( !$self );

	$self->{_dbuser} = $opt->{dbuser} || 'zonegen';

	$self->{_debug} = defined( $opt->{debug} ) ? $opt->{debug} : 0;

	if ( !$opt->{output_root} ) {
		$errstr = "Must specify output root";
		return undef;
	}

	$self->{_output_root} = $opt->{output_root};
	$self->{_hostanddate} = $opt->{hostanddate};

	$self->{_zoneroot}  = $self->{_output_root} . "/zones";
	$self->{_cfgroot}   = $self->{_output_root} . "/etc";
	$self->{_perserver} = $self->{_output_root} . "/perserver";

	my $dbh = JazzHands::DBI->connect( $self->{_dbuser},
		{ AutoCommit => 0, RaiseError => 1 } );
	if ( !$dbh ) {
		$errstr =
		  "Unable to connect to $self->{_dbuser}: " . $JazzHands::DBI::errstr;
		return undef;
	}

	$self->DBHandle($dbh);
	$self;
}

sub make_directories() {
	my $self = shift @_;

	#
	# other directories are made elsewhere, this can probably just go away.
	#
	my @list = ( $self->{_output_root}, );

	foreach my $dir (@list) {
		$self->mkdir_p($dir) if ( !-d $dir );
	}
}

sub get_my_site_code($$) {
	my ( $self, $hn ) = @_;
	my $dbh = $self->DBHandle();

	my $sth = $dbh->prepare_cached(
		qq{
		select	site_code
		  from	device
		 where	device_name = ?
	}
	) || die $dbh->errstr;
	$sth->execute($hn) || die $sth->errstr;
	my ($site) = $sth->fetchrow_array;
	$sth->finish;
	$site;
}

sub get_my_hosts($$) {
	my ( $self, $insite ) = @_;
	my $dbh = $self->DBHandle();

	$insite =~ tr/a-z/A-Z/ if ($insite);

	my $sth = $dbh->prepare_cached(
		qq{
		SELECT distinct device_name from (
		SELECT	coalesce(p.site_code, d.site_code) as site_code,
			d.device_name
 		FROM	device d
			INNER JOIN device_collection_device dcd  USING
				(device_id)
			INNER JOIN v_device_coll_hier_detail h  USING
				(device_collection_id)
			INNER JOIN v_property p ON
				p.device_collection_id =
				h.parent_device_collection_id
		WHERE	p.property_name = 'DNSDistHosts'
		AND	p.property_type = 'DNSZonegen'
		) x
		WHERE	( site_code = ?::text or ?::text is NULL)
	}
	) || die $dbh->errstr;
	$sth->execute( $insite, $insite ) || die $sth->errstr;

	my (@rv);
	while ( my ($dn) = $sth->fetchrow_array ) {
		push( @rv, $dn );
	}
	$sth->finish;
	\@rv;
}

sub get_now {
	my ($self) = @_;
	my $dbh = $self->DBHandle();

	my $sth = $dbh->prepare_cached(
		qq{
		select now();
	}
	) || die $dbh->errstr;
	$sth->execute || die $dbh->errstr;
	my ($now) = $sth->fetchrow_array;
	$sth->finish;
	$now;
}

sub get_db_default {
	my ( $self, $prop, $default ) = @_;
	my $dbh = $self->DBHandle();

	my $q = qq {
		select	property_value
		  from	v_property
		 where	property_type = 'Defaults'
		   and	property_name = ?
	};

	my $sth = $dbh->prepare_cached($q) || die "$q: ", $dbh->errstr;
	$sth->execute($prop) || die $dbh->errstr;

	my ($pv) = $sth->fetchrow_array;
	$sth->finish;
	if ($pv) {
		$pv;
	} else {
		$default;
	}
}

#
# lock all the dns_change_record columns and return the max one
# found.  This assumes they are assigned in order, which is fine...
#
sub lock_db_changes($;$$) {
	my $self = shift;
	my $wait = shift;
	my $agg  = shift;

	my $dbh = $self->DBHandle();

	my $old = $dbh->{PrintError};
	$dbh->{PrintError} = 0;

	my $nowait = "NOWAIT";
	if ($wait) {
		$nowait = '';

		if ( $agg && $dbh->{Driver}->{Name} eq 'Pg' ) {

			# Use transaction-level advisory lock to allow the SELECT FOR
			# UPDATE to clear backlogs more efficiently
			my $sth = $dbh->prepare_cached(
				qq{
					select	pg_advisory_xact_lock(54321)
				}
			) || die $dbh->errstr;
			if ( !( $sth->execute ) ) {
				die $sth->errstr;
			}
			$sth->finish;
		}
	} else {
		if ( $agg && $dbh->{Driver}->{Name} eq 'Pg' ) {

			# Use transaction-level advisory lock to allow the SELECT FOR
			# UPDATE to clear backlogs more efficiently
			my $sth = $dbh->prepare_cached(
				qq{
					select	pg_try_advisory_xact_lock(54321)
				}
			) || die $dbh->errstr;
			if ( !( $sth->execute ) ) {
				if ( $sth->state eq '55P03' ) {
					return undef;
				}
				die $sth->errstr;
			}
			$sth->finish;
		}
	}

	my $sth = $dbh->prepare_cached(
		qq{
		select	dns_change_record_id
		  from	dns_change_record
		order by dns_change_record_id
		FOR UPDATE  $nowait
	}
	) || die $dbh->errstr;
	if ( !( $sth->execute ) ) {
		if ( $sth->state eq '55P03' ) {
			return undef;
		}
		die $sth->errstr;
	}

	my @list;

	while ( my ($id) = $sth->fetchrow_array ) {
		push( @list, $id );
	}
	$sth->finish;
	$dbh->{PrintError} = 1;
	\@list;
}

sub get_change_tally($) {
	my $self = shift;

	my $dbh = $self->DBHandle();

	my $sth = $dbh->prepare_cached(
		qq{
		select	count(*)
		  from	dns_change_record
	}
	) || die $dbh->errstr;
	$sth->execute || die $sth->errstr;

	my $high;
	while ( my ($id) = $sth->fetchrow_array ) {
		$high = $id;
	}
	$sth->finish;
	$high;
}

#
# return true if a zone is in the db, false otherwise
#
sub get_dns_domid($$) {
	my $self   = shift;
	my $domain = shift;

	my $dbh = $self->DBHandle();

	my $sth = $dbh->prepare_cached(
		qq{
		select	dns_domain_id
		 from	dns_domain
		where	soa_name = ?
	}
	) || die $dbh->errstr;
	$sth->execute($domain) || die $sth->errstr;
	my $domid = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$domid;
}

#
# print comments to a FileHandle object to indicate that the file is
# auto-generated and likely not hand maintained.
#
sub print_comments {
	my ( $self, $fn, $commchr ) = @_;

	my $output_root = $self->{_output_root};

	my $dbh = $self->DBHandle();
	$commchr = '#' if ( !defined($commchr) );

	my $where  = `hostname`;
	my $whence = ctime(time);

	$where =~ s/\s*$//s;
	$whence =~ s/\s*$//s;

	my $idtag = '$Id$';

	my $email =
	  $self->get_db_default( '_supportemail', 'jazzhands@example.com' );

	my $wherestr  = "";
	my $whencestr = "";
	if ( $self->{_hostanddate} ) {
		$wherestr  = "It was generated on machine $where";
		$whencestr = "It was generated at $whence";
	}

	$fn->print(
		qq{
$commchr
$commchr DO NOT EDIT THIS FILE BY HAND.  YOUR CHANGES WILL BE LOST.
$commchr This file was auto-generated from JazzHands.
$commchr $wherestr
$commchr It was generated by the DNS zone generation system.
$commchr (look under $output_root )
$commchr
$commchr $whencestr
$commchr It was generated by:
$commchr $idtag
$commchr
$commchr Please contact $email if you require more info.
}
	);

}

#
# record that a zone has been generated and bump the soa.
#
sub record_newgen($$$) {
	my ( $self, $domid, $uid ) = @_;
	my $dbh = $self->DBHandle();

	# This is for postgresql, oracle is to_date XXX
	my $func = 'to_timestamp';

	my $sth = $dbh->prepare_cached(
		qq{
		update	dns_domain_ip_universe
		  set	soa_serial = soa_serial + 1, last_generated = now()
		where	dns_domain_id = :domid
		  and	ip_universe_id = :uid
	}
	) || die dbhsth->errst;
	$sth->bind_param( ':domid', $domid ) || die $sth->errstr;
	$sth->bind_param( ':uid', $uid ) || die $sth->errstr;
	$sth->execute || die $sth->errstr;
}

#
#  generate an acl file for inclusion by named based on site_codes
#
sub generate_named_acl_file($$$) {
	my ( $self, $fn ) = @_;
	my $dbh = $self->DBHandle();

	my $zoneroot = $self->{_cfgroot};

	$fn = "$zoneroot/$fn";

	if ( !-d $zoneroot ) {
		$self->mkdir_p($zoneroot);
	}

	my $tmpfn = "$fn.$$.zonetmp";
	my $out = new FileHandle(">$tmpfn") || die "$tmpfn: $!";

	# XXX probably not the best choice...
	$out->binmode('encoding(utf8)');
	$self->print_comments( $out, '//' );

	$out->print("\n\n");

	# generate explicitly defined acls
	{
		my $sth = $dbh->prepare_cached(
			qq{
		SELECT	p.property_value AS acl_name, nb.ip_address, nb.description
		FROM 	v_nblk_coll_netblock_expanded nbe
				INNER JOIN property p USING (netblock_collection_id)
				INNER JOIN netblock nb USING (netblock_id)
		WHERE property_name = 'DNSACLs' and property_type = 'DNSZonegen'
		ORDER BY 1,2;
	}
		) || die $dbh->errstr;

		$sth->execute || die $sth->errstr;
		my $lastacl = undef;
		while ( my ( $acl, $ip, $desc ) = $sth->fetchrow_array ) {
			if ( defined($lastacl) && $acl ne $lastacl ) {
				$out->print("};\n\n");
				$lastacl = undef;
			}
			if ( !defined($lastacl) ) {
				$out->print("acl $acl\n{\n");
			}
			$lastacl = $acl;
			$out->printf( "\t%-35s\t// %s\n", "$ip;", ($desc) ? $desc : "" );
		}
		if ( defined($lastacl) ) {
			$out->print("};\n\n");
		}
	}

	# generate per site blocks
	{
		my $sth = $dbh->prepare_cached(
			qq{
			SELECT * FROM (
				SELECT '!' AS inclusion, psnb.site_code, nb.ip_address,
					snb.site_code AS child_site_code,
					pnb.ip_address AS parent_ip,
					nb.description
				  FROM  site_netblock snb
						JOIN netblock nb using (netblock_id),
					site_netblock psnb
						JOIN netblock pnb using (netblock_id)
				WHERE   psnb.site_code != snb.site_code
				AND     pnb.ip_address >>= nb.ip_address
			UNION
				SELECT  NULL AS inclusion, site_code, ip_address,
						NULL AS child_site_code ,NULL AS parent_ip,
						description
				  FROM  site_netblock
					JOIN netblock USING (netblock_id)
			) subq
			ORDER BY site_code,
				coalesce(parent_ip, ip_address), inclusion,
				masklen(ip_address) DESC

	}
		) || die $dbh->errstr;

		$sth->execute || die $sth->errstr;
		my $lastsite = undef;
		while ( my ( $inc, $sc, $ip, $ksc, $pip, $desc ) =
			$sth->fetchrow_array )
		{
			$sc =~ tr/A-Z/a-z/;
			if ( defined($lastsite) && $sc ne $lastsite ) {
				$out->print("};\n\n");
				$lastsite = undef;
			}
			if ( !defined($lastsite) ) {
				$out->print("acl $sc\n{\n");
			}
			$lastsite = $sc;
			if ($inc) {
				$desc = "[$ksc vs $pip] " . ( ($desc) ? $desc : "" );
			} else {
				$inc = "";
			}
			$out->printf( "\t%-35s\t// %s\n",
				"$inc$ip;", ($desc) ? $desc : "" );
		}
		if ( defined($lastsite) ) {
			$out->print("};\n\n");
		}
	}

	$out->close;

	$self->safe_mv_if_changed( $tmpfn, $fn );
}

sub generate_rsync_list($$$$) {
	my ( $self, $fn, $site ) = @_;
	my $dbh = $self->DBHandle();

	my $root     = $self->{_output_root};
	my $zoneroot = $self->{_zoneroot};

	my $nameservers = $self->get_my_hosts($site);

	my $fullfn = "$root/$fn";
	my $tmpfn  = "$fullfn.$$.zonetmp";
	my $fh     = new FileHandle(">$tmpfn") || die "$tmpfn: $!";

	foreach my $ns ( @{$nameservers} ) {
		$fh->print("$ns\n") || die "writing $ns to $tmpfn: $!";
	}
	$fh->close || die "close($tmpfn): $!";

	# may be possible if a site is beingr retired
	$self->safe_mv_if_changed( $tmpfn, $fullfn, 1 );
}

sub process_all_dns_records {
	my ( $self, $out, $domid, $domain, $universe ) = @_;
	my $dbh = $self->DBHandle();

	my $uclause = "";
	if ( defined($universe) ) {
		$uclause = "AND ( ip_universe_id = :universe )";
	}

	#
	# sort_order is arranged such that records for the domain itself
	# end up first.  The processing of the query inserts a newline when
	# going between the two, so that value is also used later.
	#
	# NOTE:  It is possible to have an in database "cname" that causes
	# another records ip address or name to be put in.  This only works
	# for NS, A, AAAA, MX and CNAMEs.  It almost certainly needs to be
	# broken out better in the db.
	#
	my $sth = $dbh->prepare_cached(
		qq {
		WITH dns AS (
		select  dns_record_id,
			network_range_id,
			dns_name,
			dns_ttl,
			dns_class,
			dns_type,
			dns_value,
			dns_priority,
			host(ip) as ip,
			ref_record_id,
			dns_srv_service,
			dns_srv_protocol,
			dns_srv_weight,
			dns_srv_port,
			is_enabled,
			CASE WHEN DNS_TYPE IN ('NS') THEN 3
				WHEN DNS_TYPE IN ('A','AAAA') THEN 4
				ELSE 10 END as sortorder,
			dns_domain_id
		  from	v_dns
		 where	dns_domain_id = :domid $uclause
		) SELECT *, row_number()
			OVER (partition by dns_name,dns_domain_id ORDER BY sortorder) as rn
		FROM dns
		order by
			dns_domain_id,
			CASE WHEN dns_name IS NULL THEN 0 ELSE 1 END,
			CASE WHEN DNS_TYPE IN ('A','AAAA') THEN NULL
			     WHEN DNS_TYPE = 'PTR' THEN lpad(dns_name, 10, '0')
				ELSE  dns_name
			END,
			sortorder,
			ip,
			dns_type,
			dns_value
	}
	);

	# order by sort_order, net_manip.inet_dbtop(ni.ip_address),dns_type

	$sth->bind_param( ':domid', $domid ) || die $sth->errstr;
	if ( defined($universe) ) {
		$sth->bind_param( ':universe', $universe ) || die $sth->errstr;
	}

	$sth->execute || die $sth->errstr;

	while (
		my (
			$id,   $rangeid,  $name,      $ttl,     $class,
			$type, $val,      $pri,       $ip,      $rid,
			$srv,  $srvproto, $srvweight, $srvport, $enable
		)
		= $sth->fetchrow_array
	  )
	{
		my $com = ( $enable eq 'N' ) ? ";" : "";
		my $value = $val;

		$name = "" if ( !defined($name) );

		if ( $type eq 'A' || $type eq 'AAAA' ) {
			$value = $ip;
		} elsif ( $type eq 'MX' ) {

			# at the moment, STAB nudges people towards putting
			# the mx value in the "value field", overloading it.
			# while this needs to be fixed, this causes bum
			# records to not be generated.
			if ( !defined($pri) ) {
				if ( $value !~ /^\s*\d+\s+\S/ ) {
					$pri = 0;
				} else {
					$pri = "";
				}
			}
			$pri .= " " if ( defined($pri) );
			$value = "$pri$value";
		} elsif ( $type eq 'TXT' || $type eq 'SPF') {
			$value =~ s/^"//;
			$value =~ s/"$//;
			$value = "\"$value\"";
		} elsif ( $type eq 'SRV' ) {
			if ( $srvproto && $srvproto !~ /^_/ ) {
				$srvproto = "_$srvproto";
			}
			$name = ".$name"         if ( $srvproto && length($name) );
			$name = "$srvproto$name" if ($srvproto);
			$name = ".$name"         if ( $srv && length($name) );
			$name = "$srv$name"      if ($srv);

			$value = "$pri $srvweight $srvport $value";
		}

		#
		# so == 0 means it's a record or the zone, so this gets
		# indented less
		#
		my $width = 25;
		$width = 0 if ( !$name );    # zone records get indented less

		$ttl = "" if ( !defined($ttl) );
		$out->printf( "%s%-*s\t%s %s\t%s\t%s\n",
			$com, $width, $name, $ttl, $class, $type, $value );
	}
	$out->print("\n");
}

sub process_soa {
	my ( $self, $out, $domid, $bumpsoa, $uid ) = @_;
	my $dbh = $self->DBHandle();

	my $sth = $dbh->prepare_cached(
		qq{
		SELECT	soa_name, soa_class, soa_ttl,
				soa_serial, soa_refresh, soa_retry,
				soa_expire, soa_minimum,
				soa_mname, soa_rname
		  FROM	dns_domain
				inner join dns_domain_ip_universe USING (dns_domain_id)
		 WHERE	dns_domain_id = ?
		   AND	ip_universe_id = ?
	}
	);

	$sth->execute( $domid, $uid ) || die $sth->errstr;

	my ( $dom, $class, $ttl, $serial, $ref, $ret, $exp, $min, $mname, $rname )
	  = $sth->fetchrow_array;
	$sth->finish;

	$class  = 'IN'    if ( !defined($class) );
	$ttl    = 72000   if ( !defined($ttl) );
	$serial = 0       if ( !defined($serial) );
	$ref    = 3600    if ( !defined($ref) );
	$ret    = 1800    if ( !defined($ret) );
	$exp    = 2419200 if ( !defined($exp) );
	$min    = 3600    if ( !defined($min) );

	#
	# This happens in order to allow updates to the dns_domain rows to happen
	# all at once, right before commit, to minimize the amount of time a row
	# is locked due to an update.  Both the "last_generated" and "soa_serial"
	# columns are updated to match this.
	#
	$serial += 1 if ($bumpsoa);

	$rname = $self->get_db_default( '_dnsrname', 'hostmaster.example.com' )
	  if ( !defined($rname) );
	$mname = $self->get_db_default( '_dnsmname', 'auth00.example.com' )
	  if ( !defined($mname) );

	# should do this - escaping of .'s in email addresses..
	# $rname =~ s/[^\\]{0,1}\./\\./;
	$rname =~ s/\@/./g;

	$mname .= "." if ( $mname =~ /\./ );
	$rname .= "." if ( $rname =~ /\./ );

	$self->print_comments( $out, ';' );

	$out->print( '$TTL', "\t$ttl\n" );
	$out->print("@\t$ttl\t$class\tSOA $mname $rname (\n");
	$out->print("\t\t\t\t$serial\t; serial number\n");
	$out->print("\t\t\t\t$ref\t; refresh\n");
	$out->print("\t\t\t\t$ret\t; retry\n");
	$out->print("\t\t\t\t$exp\t; expire\n");
	$out->print("\t\t\t\t$min )\t; minimum\n\n");

}

#
# if zoneroot is undef, then dump the zone to stdout.
#
sub process_domain {
	my ( $self, $domid, $domain, $uid, $uname, $errcheck, $last, $bumpsoa ) =
	  @_;
	my $dbh = $self->DBHandle();

	my $zoneroot = $self->{_zoneroot};

	my $inaddr = "";
	if ( $domain =~ /in-addr.arpa$/ ) {
		$inaddr = "inaddr/";
	} elsif ( $domain =~ /ip6.arpa$/ ) {
		$inaddr = "ip6/";
	}

	#
	# This generally happens only on dumping a zone to stdout...
	if ( !$domid ) {
		$domid = $self->get_dns_domid($domain);
		return 0 if ( !$domid );

	}

	$self->_Debug( 1, "processing universe %s (%s)...", $uname, $uid );

	my ( $fn, $tmpfn );

	if ($zoneroot) {

		my $dir = "$zoneroot/$uname/$inaddr";
		$self->mkdir_p($dir) if ( !-d $dir );
		$fn    = "$dir$domain";
		$tmpfn = "$fn.tmp.$$";
	} else {
		$tmpfn = "/dev/stdout";
	}

	my $out = new FileHandle(">$tmpfn") || die "$tmpfn: $!";

	$self->_Debug( 1, "process SOA to %s", $tmpfn );

	$self->process_soa( $out, $domid, $bumpsoa, $uid );

	$self->_Debug( 1, "process DNS Records to %s", $tmpfn );
	$self->process_all_dns_records( $out, $domid, $domain, $uid );
	$self->_Debug( 1, "process_domain complete" );
	$out->close;

	if ($last) {
		$last =~ s/\..*$//;
		my ( $y, $m, $d, $h, $min, $s ) =
		  ( $last =~ /^(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)/ );
		if ($y) {
			my $whence = mktime( $s, $min, $h, $d, $m - 1, $y - 1900 );
			utime( $whence, $whence, $tmpfn );    # If it does not work, then Vv
		} else {
			warn "difficulting breaking apart $last";
		}
	}

	if ( !$zoneroot ) {
		return 0;
	}

	#
	# run named-checkzone to see if its a valid or bump zone, and if it
	# failed the test, then spit out an error message and return something
	# indicating as such.
	#
	my $prog = "named-checkzone $domain $tmpfn";
	$self->_Debug( 1, "running '%s'", $prog );
	my $output = `$prog`;
	if ( ( $? >> 8 ) ) {
		my $errmsg = "[not pushing out]";
		if ($errcheck) {
			$errmsg = "[WARNING: PUSHING OUT!]";
		}
		$output = "" if ( !$output );
		warn "$domain ($uname) was generated with errors $errmsg ($output)\n";
		if ( !$errcheck ) {
			return 0;
		}
	}

	unlink($fn);
	rename( $tmpfn, $fn );
	return 1;
}

sub generate_complete_files {
	my ( $self, $zonesgend ) = @_;
	my $dbh = $self->DBHandle();

	my $zoneroot = $self->{_zoneroot};

	my $cfgdir = "$zoneroot/../etc";

	$self->mkdir_p("$cfgdir");
	my $cfgfn    = "$cfgdir/named.conf.auto-gen";
	my $tmpcfgfn = "$cfgfn.tmp.$$";
	my $cfgf     = new FileHandle(">$tmpcfgfn") || die "$tmpcfgfn\n";

	$self->print_comments( $cfgf, '#' );

	my $sth = $dbh->prepare_cached(
		qq{
		select	soa_name
		  from	dns_domain
		 where	should_generate = 'Y'
		order by soa_name
	}
	);
	$sth->execute || die $sth->errstr;

	while ( my ($zone) = $sth->fetchrow_array ) {
		my $fn = $zone;
		if ( $fn =~ /.in-addr.arpa/ ) {
			$fn = "inaddr/$zone";
		} elsif ( $fn =~ /.ip6.arpa/ ) {
			$fn = "ip6/$zone";
		}
		$cfgf->print(
			"zone \"$zone\" {\n\ttype master;\n\tfile \"/auto-gen/zones/$fn\";\n};\n\n"
		);
	}
	$cfgf->close;
	$self->safe_mv_if_changed( $tmpcfgfn, $cfgfn, 1 );

	my $zcfn    = "$cfgdir/zones-changed";
	my $tmpzcfn = "$zcfn.tmp.$$";
	my $zcf     = new FileHandle(">$tmpzcfn") || die "$zcfn\n";
	chmod( 0755, $tmpzcfn );

	$self->print_comments( $zcf, '#' );

	#
	# XXX this really wants to be a variable set in the db to determine
	# if views are in use or not, or better, views in the db.
	my $tally = 0;
	foreach my $zone ( sort keys(%$zonesgend) ) {
		if ( defined($zonesgend) && defined( $zonesgend->{$zone} ) ) {

			# oh, this is a hack!
			$zcf->print("$zone\n");
			$tally++;
		}
	}

	$zcf->close;
	$self->safe_mv_if_changed( $tmpzcfn, $zcfn, 1 );

}

#
# zoneroot is passwd in so symlinks work.  Not fully qualified symlinks
# for debugging purposes (since much of that is done in `pwd`).  This is
# probably worth rethinking.
#
# The underlying rsync follows symlinks.
#
sub process_perserver {
	my ( $self, $zoneroot, $zonesgend ) = @_;
	my $dbh = $self->DBHandle();

	my $persvrroot = $self->{_perserver};

	#
	# we only create symlinks for zones that should be generated
	#
	# This does NOT use v_dns because its super slow for just these records
	# of interest.
	#
	my $sth = $dbh->prepare_cached(
		q{
		SELECT	DISTINCT
			dom.dns_domain_id,
			CASE WHEN dns.dns_value ~ '\.$'
				THEN regexp_replace(dns.dns_value, '\.$', '')
				ELSE concat(dns.dns_value,'.',dom.soa_name)
			END AS dns_value,
			dom.soa_name
		 FROM   dns_domain dom
			INNER JOIN dns_domain_ip_universe di
				USING (dns_domain_id)
			INNER JOIN dns_record dns
				USING (dns_domain_id)
		 WHERE  dns.dns_name is NULL
		   AND  dns_type = 'NS'
		   AND	should_generate = 'Y'
		ORDER BY dns_value
	}
	);

	$sth->execute || die $sth->errstr;

	my %servers;
	while ( my ( $id, $ns, $zone ) = $sth->fetchrow_array ) {
		next if ( !$ns );    # this should not happen
		$ns =~ s/\.*$//;
		push( @${ $servers{$ns} }, $zone );
	}

	#
	# now process each server
	#
	my $tally = 0;
	foreach my $server ( keys(%servers) ) {
		my $svrdir  = "$persvrroot/$server";
		my $zonedir = "$svrdir/zones";
		my $cfgdir  = "$svrdir/etc";
		my $zones   = $servers{$server};

		if ( -d $zonedir ) {
			#
			# go through and remove zones that don't belong.
			# This may leave excess in-addrs.  oh well.
			#
			opendir( DIR, $zonedir ) || die "$zonedir: $!";
			foreach my $entry ( readdir(DIR) ) {
				my $fqn = "$zonedir/$entry";
				next if ( !-l $fqn );
				next if ( grep( $_ eq $entry, @$$zones ) );
				unlink($fqn);
			}
			closedir(DIR);
		} else {
			$self->mkdir_p($zonedir);
		}

		foreach my $dir ( "$zonedir/inaddr", "$zonedir/ip6" ) {
			if ( -d $dir ) {
				#
				# go through and remove zones that don't belong,
				# which may leave some non-inaddrs.
				#
				opendir( DIR, $dir ) || die "$dir: $!";
				foreach my $entry ( readdir(DIR) ) {
					my $fqn = "$dir/$entry";
					next if ( !-l $fqn );
					next
					  if ( grep( $_ eq $entry, @$$zones ) );
					unlink($fqn);
				}
				closedir(DIR);
			} else {
				$self->mkdir_p($dir);
			}
		}

		#
		# create a symlink in the "perserver" directory for zones
		# the server servers as well as creating a named.conf
		# file to be included.  A file that lists all the zones that
		# are auto-generated that were changed on this run is also saved.
		#
		$self->mkdir_p("$cfgdir");
		my $cfgfn    = "$cfgdir/named.conf.auto-gen";
		my $tmpcfgfn = "$cfgfn.tmp.$$";
		my $cfgf     = new FileHandle(">$tmpcfgfn") || die "$tmpcfgfn\n";

		$self->print_comments( $cfgf, '#' );

		my $zcfn    = "$cfgdir/zones-changed";
		my $tmpzcfn = "$zcfn.tmp.$$";
		my $zcf     = new FileHandle(">$tmpzcfn") || die "$zcfn\n";
		chmod( 0755, $tmpzcfn );
		$self->print_comments( $zcf, '#' );

		foreach my $zone ( sort @$$zones ) {
			my $fqn = "$zonedir/$zone";
			my $zr  = $zoneroot;
			if ( $zr =~ /^\.\./ ) {
				$zr = "../../$zr";
			}

			if ( $zone =~ /in-addr.arpa$/ ) {
				if ( $zr =~ /^\.\./ ) {
					$zr = "../$zr";
				}
				$fqn = "$zonedir/inaddr/$zone";
				$zr .= "/inaddr/$zone";
			} elsif ( $zone =~ /ip6.arpa$/ ) {
				if ( $zr =~ /^\.\./ ) {
					$zr = "../$zr";
				}
				$fqn = "$zonedir/ip6/$zone";
				$zr .= "/ip6/$zone";

			} else {
				$zr .= "/$zone";
			}

			#
			# now actually create the link, and if the link
			# is pointing to the wrong place, move it
			#
			if ( !-l $fqn ) {
				unlink($zr);
				symlink( $zr, $fqn );
			} else {
				my $ov = readlink($fqn);
				if ( $ov ne $zr ) {
					unlink($fqn);
					symlink( $zr, $fqn );
				}
			}
			if ( !-r $fqn ) {
				warn
				  "$zone does not exist for $server (see $fqn); possibly needs to be forced before a regular run\n";
			}

			if ( $zone =~ /in-addr.arpa$/ ) {
				$cfgf->print(
					"zone \"$zone\" {\n\ttype master;\n\tfile \"auto-gen/zones/inaddr/$zone\";\n};\n\n"
				);
			} elsif ( $zone =~ /ip6.arpa$/ ) {
				$cfgf->print(
					"zone \"$zone\" {\n\ttype master;\n\tfile \"auto-gen/zones/ip6/$zone\";\n};\n\n"
				);
			} else {
				$cfgf->print(
					"zone \"$zone\" {\n\ttype master;\n\tfile \"auto-gen/zones/$zone\";\n};\n\n"
				);
			}

			if (   defined($zonesgend)
				&& defined( $zonesgend->{$zone} ) )
			{
				$zcf->print("$zone\n");
				$tally++;
			}
		}

		$cfgf->close;
		$self->safe_mv_if_changed( $tmpcfgfn, $cfgfn, 1 );

		$zcf->close;
		unlink($zcfn);
		$self->safe_mv_if_changed( $tmpzcfn, $zcfn, 1 );

		#
		# create a symlink to the acl file so it gets sync'd out right"
		#
		if ( -r "$persvrroot/$zoneroot/../etc/sitecodeacl.conf" ) {
			unlink("$svrdir/etc/sitecodeacl.conf");
			symlink( "$zoneroot/../../../etc/sitecodeacl.conf",
				"$svrdir/etc/sitecodeacl.conf" )
			  || die "not create symlink in $svrdir...";
		}
	}
}

#
# implement mkdir -p in perl
#
sub mkdir_p {
	my $self = shift @_;

	my ($dir) = @_;
	my $mode = 0755;

	my (@d) = split( m-/-, $dir );
	my $ne = $#d + 1;
	for ( my $i = 1 ; $i <= $ne ; $i++ ) {
		my (@dir) = split( m-/-, $dir );
		splice( @dir, $i );
		my $thing = join( "/", @dir );
		mkdir( $thing, $mode );
	}
}

#
# mv's a file in place if it has changed.
#
sub safe_mv_if_changed($$;$) {
	my ( $self, $new, $final, $allowzero ) = @_;

	# if the old file is there, diff, if not, just move into place
	# if diff matches, delete the new file
	if ( !-f $final ) {
		rename( $new, $final );
	} elsif ( -r $final && ( $allowzero || -s $new ) ) {
		my $cmd = qq{diff -w -i -I '^\\s*//' "$new" "$final"};
		system("$cmd > /dev/null");
		if ( $? >> 8 ) {
			my $oldfn = "$final.old";
			unlink($oldfn);
			if ( rename( $final, $oldfn ) ) {
				if ( !rename( $new, $final ) ) {
					rename( $oldfn, $final )
					  || die
					  "Unable to put $final back from $oldfn after fail to rename\n";
				}
				unlink($oldfn);
			} else {
				die "$final: Unable to rename to $final\n";
			}
		} else {
			unlink($new);
		}
	} else {
		die "$final: $! (can not open for compare)\n";
	}
}

DESTROY {
	my $self = shift;

	$self->DBHandle()->disconnect;
	$self->DBHandle(undef);
	undef;
}

package main;

#############################################################################
#
# main stuff starts here
#
#############################################################################

my $output_root = "/var/lib/zonegen/auto-gen";
my $hostanddate = 0;
my $verbose     = 0;
my $debug       = 0;

my $genall      = 0;
my $dumpzone    = 0;
my $forcegen    = 0;
my $forcesoa    = 0;
my $forceall    = 0;
my $nosoa       = 0;
my $help        = 0;
my $norsynclist = 0;
my $nogen       = 0;
my $sleep       = 0;
my $wait        = 1;
my $agg         = 0;

my $mysite;

my $script_start = time();

GetOptions(
	'aggressive-lock' => \$agg,            # aggressively lock db
	'debug'           => \$debug,          # even more verbosity.
	'dumpzone'        => \$dumpzone,       # dump a zone to stdout
	'forcegen|f'      => \$forcegen,       # force generation of zones
	'forcesoa|s'      => \$forcesoa,       # force bump of SOA record
	'force|f'         => \$forceall,       # force everything
	'genall|a'        => \$genall,         # generate all, not just new
	'hostanddate!'    => \$hostanddate,    # include in comments
	'help'            => \$help,           # duh.
	'no-rsync-list'   => \$norsynclist,    # generate rsync list
	'nogen'           => \$nogen,          # do not generate any zones
	'nosoa'           => \$nosoa,          # never bump soa record
	'outdir|o=s'      => \$output_root,    # output directory
	'random-sleep=i'  => \$sleep,          # how long to sleep up unto;
	'site=s'          => \$mysite,         # indicate what local machines site
	'verbose|v'       => \$verbose,        # duh.
	'wait!'           => \$wait            # wait on lock in db
) || die pod2usage( -verbose => 1 );

$verbose = 1 if ($debug);

if ($nogen) {
	warn "--nogen specified; exiting\n" if ($verbose);
	exit 0;
}

if ($dumpzone) {
	if ( $#ARGV > 0 ) {
		die "can only dump one zone to stdout.\n";
	} elsif ( $#ARGV == -1 ) {
		die "must specify a zone to dump\n";
	}
}

if ($help) {
	pod2usage( -verbose => 1 );
}

if ($forceall) {
	$forcegen = $forcesoa = 1;
}

if ( $nosoa && $forcesoa ) {
	die "Can't both force an SOA serial bump and deny it.\n";
}

if ($sleep) {
	my $delay = int( rand($sleep) );
	warn "Sleeping $delay seconds\n" if ($debug);
	sleep($delay);
}

my $zg = new JazzHands::ZoneGeneration(
	output_root => $output_root,
	hotanddate  => $hostanddate,
) || die $JazzHands::ZoneGeneration::errstr;

#
# This should probably move into script_hooks.zonegen_pre().
#
if ( $agg && $zg->DBHandle()->{Driver}->{Name} eq 'Pg' ) {
	$zg->DBHandle()->do("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ")
	  || die $zg->DBHandle()->errstr;
}

$zg->DBHandle()->do("SELECT script_hooks.zonegen_pre()");

if ($dumpzone) {
	my $domain = shift @ARGV;
	$zg->process_domain( undef, $domain, undef, undef, undef );
	exit(0);
}

my $me = `hostname`;
chomp($me);

if ( $mysite && $mysite eq 'none' ) {
	$mysite = undef;
}

if ( !$mysite ) {
	$mysite = $zg->get_my_site_code($me);
} elsif ( $mysite eq 'none' ) {
	$mysite = undef;
}

$zg->make_directories();

# Do not manipulate the change records if the SOA is not to be manipulated.
# This is just used to make sure everything on disk is right.
my @changeids;
if ($nosoa) {
	#
	# don't manipulate any changeids.
	#
	my @foo;
	@changeids = @foo;
} else {
	#
	# if this returns  an empty list, then exit 1
	# This signals to the caller that it should cease.
	#
	my $changeids = $zg->lock_db_changes( $wait, $agg );

	if ( !defined($changeids) ) {
		exit 1;
	}

	@changeids = @{$changeids};
}

if ($debug) {
	warn "Got ", scalar @changeids, " change ids to deal with";
	warn "Number of change records, ", $zg->get_change_tally(), "\n";
}

# $generate contains all of the objects that are to be regenerated
my $generate = {};
if ( scalar @changeids ) {
	#
	# Now get all zones eligible for regeneration and save them.
	#
	my $dbh = $zg->DBHandle();
	my $sth = $dbh->prepare_cached(
		qq{
			SELECT v.*, u.ip_universe_name
			FROM v_dns_changes_pending v
			JOIN ip_universe u USING (ip_universe_id)
	}
	) || die $dbh->errstr;

	$sth->execute || die $sth->errstr;

	#
	# build up generate to be a ahsh of zones to regenerate with a hash of the
	# change ids that need to later be zapped.
	#
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $dom = $hr->{ _dbx('SOA_NAME') };
		my $uname = $hr->{ _dbx('IP_UNIVERSE_NAME') };
		if ( $#ARGV >= 0 ) {
			next if ( !$dom || !grep( $_ eq $dom, @ARGV ) );
		}
		if ( !$dom ) {
			if ( defined( $hr->{ _dbx('IP_ADDRESS') } ) ) {
				if ( $#ARGV < 0 ) {
					warn "Unable to find zone for ",
					  $hr->{ _dbx('IP_ADDRESS') }, "\n"
					  if ($verbose);
				}
			} else {
				warn
				  "Odd but not a crisis -- this code shuld not be reached for ",
				  Dumper($hr);
			}
		}

		if ( !$dom ) {
			$dom = '__unknown__';
		}

		if ( !defined( $generate->{$dom} ) ) {
			$generate->{$dom} = {};
		}

		if ( !defined( $generate->{$dom}->{$uname} ) ) {
			$generate->{$dom}->{$uname} = {};
		}

		# There was a change and thus we bump the soa
		$generate->{$dom}->{$uname}->{bumpsoa} = 1;
		push( @{ $generate->{$dom}->{$uname}->{rec} }, $hr );
	}
}

#
# at this point, generate has a list of all zones that should be generated
# and the __unknown__ zone which contains in-addr records which did not have
# a matching record.
#

#
# look at all existing zones and, based on command line options, see if they
# should be generated or not.  This may remove some zones from above, it may
# add some.
#
if (1) {
	my $dbh = $zg->DBHandle();
	my $sth = $dbh->prepare_cached(
		qq{
		WITH uv AS (
			SELECT ip_universe_Id,visible_ip_universe_id
				FROM ip_universe_visibility WHERE propagate_dns = 'Y'
			UNION
			SELECT ip_universe_id, ip_universe_id FROM ip_universe
		) SELECT  dns_domain_id, u.ip_universe_id, ip_universe_name,
				should_generate, last_generated, soa_name,
				extract(epoch from last_generated) as epoch_gen
		FROM ip_universe u
			JOIN uv USING (ip_universe_id)
			JOIN dns_domain_ip_universe du ON
				du.ip_universe_id = uv.visible_ip_universe_id
			JOIN dns_domain d USING (dns_domain_id)
		WHERE u.should_generate_dns = 'Y'
		ORDER BY soa_name, ip_universe_id
	}
	) || die $dbh->errstr;
	$sth->execute || die $sth->errstr;

	while ( my $hr = $sth->fetchrow_hashref ) {
		my $dom = $hr->{ _dbx('SOA_NAME') };

		#
		# --genall overrides SHOULD_GENERATE in the db
		#
		if ( !$genall && $hr->{ _dbx('SHOULD_GENERATE') } eq 'N' ) {
			die "need to deal with universes in this case";
			delete $generate->{$dom};
			next;
		}

		my $genit = 0;
		if ( $#ARGV >= 0 ) {
			if ( !grep( $_ eq $dom, @ARGV ) ) {
				delete $generate->{$dom};
				next;
			} elsif ($forcegen) {
				$genit = 1;
			}
		} elsif ($forcegen) {
			$genit = 1;
		}

		my $univ = $hr->{ _dbx('IP_UNIVERSE_NAME') };

		if ($genall) {
			$genit = 1;
		} else {

			# look for the existing file

			my $zoneroot = $zg->{_zoneroot}."/$univ";

			my $fn = "$zoneroot/$dom";
			if ( $dom =~ /\.in-addr\.arpa$/ ) {
				$fn = "$zoneroot/${univ}inaddr/$dom";
			} elsif ( $dom =~ /\.ip6\.arpa$/ ) {
				$fn = "$zoneroot/${univ}ip6/$dom";
			}

			if ( !-f $fn ) {
				$genit = 1;
			} else {
				# if the file on disk was generated before
				# the last generation date, regenerate it.
				# Its possible it was generated on another
				# host
				my ($mtime) = ( stat($fn) )[9];
				my $epoch = $hr->{ _dbx('EPOCH_GEN') } || 0;
				$epoch = int ($epoch);
				if ( $mtime != $epoch ) {
					$genit = 1;
				}

			}
		}


		if ($genit) {
			if ( !$generate->{$dom} ) {
				$generate->{$dom} = {};
			} elsif ( exists( $generate->{$dom}->{$univ} ) ) {
				next;
			}

			if ( !$generate->{$dom}->{$univ} ) {
				$generate->{$dom}->{$univ} = {};
			}

			push( @{ $generate->{$dom}->{$univ}->{rec} }, $hr );
		}
	}
	$sth->finish;
}

#
# Go through the command line and make  sure they are all there.
#
# XXX - need to deal with iprgment.
foreach my $dom (@ARGV) {
	if ( !exists( $generate->{$dom} ) ) {
		if ( !$zg->get_dns_domid($dom) ) {
			die "$dom is not a valid zone\n";
		}
	}
}

#
# NOTE, the setting of $generate->{$dom}->{bumpsoa} is set here and the db
# update to set the zone checks it later.
#
#
foreach my $dom ( sort keys( %{$generate} ) ) {
	next if $dom eq '__unknown__';
	foreach my $univ ( sort keys( %{ $generate->{$dom} } ) ) {
		my $bumpsoa = 0;
		if ($nosoa) {
			$generate->{$dom}->{$univ}->{bumpsoa} = 0;
		} else {
			if ($forcesoa) {
				$bumpsoa = 1;
				$generate->{$dom}->{$univ}->{bumpsoa} = 1;
			} else {
				$bumpsoa = $generate->{$dom}->{$univ}->{bumpsoa} || 0;
			}
		}
		my $domid =
		  $generate->{$dom}->{$univ}->{rec}->[0]->{ _dbx('DNS_DOMAIN_ID') };
		print "$dom $univ\n";
		my $last = $generate->{$dom}->{$univ}->{rec}->[0]->{last_generated};
		if ($bumpsoa) {
			$last = $zg->get_now();
		}
		my $uid = $generate->{$dom}->{$univ}->{rec}->[0]->{ip_universe_id};
		$zg->process_domain( $domid, $dom, $uid, $univ, undef, $last,
			$bumpsoa );
	}

}
warn "Done Generating Zones\n" if ($verbose);

my $docommit = 0;

#
# update the db's "last generated" date now.  This is saved to the end so
# that all the updates happen quickly, and right before commit so the time
# that a modification is lingering is minimized.
#
foreach my $dom ( sort keys( %{$generate} ) ) {
	next if ( $dom eq '__unknown__' );
	foreach my $universe ( sort keys( %{ $generate->{$dom} } ) ) {
		my $t = $generate->{$dom}->{$universe};
		if ( $t->{bumpsoa} ) {
			my $rec = $t->{rec}->[0];
			my $domid = $rec->{ _dbx('DNS_DOMAIN_ID') };
			my $uid   = $rec->{ _dbx('IP_UNIVERSE_ID') };
			warn "bumping soa for $domid, $dom\n" if ($debug);
			$zg->record_newgen( $domid, $uid );
			$docommit++;
		}
	}
}
warn "Done bumping SOAs\n" if ($debug);

warn "Purging processed DNS_CHANGE_RECORD records\n" if ($verbose);
#
# purge dns change records that were processed
#
# $nosoa basically means no changes, so thus do not note things as done
#
if ( !$nosoa ) {
	if ( scalar keys(%$generate) ) {
		my $seen = {};
		my $dbh  = $zg->DBHandle();
		my $sth  = $dbh->prepare_cached(
			qq{
			delete from dns_change_record where dns_change_record_id = ?
		}
		) || die $dbh->errstr;
		foreach my $dom ( sort keys( %{$generate} ) ) {
			foreach my $u ( sort keys %{ $generate->{$dom} } ) {
				next if ( !defined( $generate->{$dom}->{$u}->{rec} ) );
				my $b = $generate->{$dom}->{$u};
				foreach my $hr ( @{ $b->{rec} } ) {
					my $id = $hr->{ _dbx('DNS_CHANGE_RECORD_ID') };

					# for if something was forced from the command line but did not
					# have recorded changes
					next if ( !$id );

					#
					# only remove ids that were found before processing started.
					# This allows for transactions commited during the run to get
					# a chance to regenerate
					#
					if ( !grep( $_ == $id, @changeids ) ) {
						warn "skipping change record $id, not in initial set\n"
						  if ($debug);
						next;
					}
					if ( !exists( $seen->{$id} ) ) {
						warn "deleting change record $id\n"
						  if ($debug);
						$sth->execute($id) || die $sth->errstr;
						$docommit++;
					}
					$seen->{$id}++;
				}

			}
		}
	}
}

warn "Generating acl file\n" if ($verbose);
$zg->generate_named_acl_file("sitecodeacl.conf");

if ( !$norsynclist ) {
	warn "Generating rsync list\n" if ($verbose);
	$zg->generate_rsync_list( "rsynchostlist.txt", $mysite );
}

#
# Final cleanup
#
warn "Generating configuration files and whatnot..." if ($debug);

die "need to port per-server bits";

#$zg->process_perserver( "../zones", $generate );
#$zg->generate_complete_files($generate);

$zg->DBHandle()->do("SELECT script_hooks.zonegen_post()");

warn "Done file generation, about to commit\n" if ($verbose);
if ($docommit) {
	$zg->commit;
} else {

	# no changes should have been made
	$zg->rollback;
}

exit 0;

__END__;

=head1 generate-zones

generate-zones -- generate DNS zone files from JazzHands

=head1 SYNOPSIS

generate-zones [ options ] [ zone1 zone2 zone3 ... ]

=head1 OPTIONS

=over

=item B<--genall, -a> generate all zones

=item B<--forcegen> force generation of zones

=item B<--forcesoa> force update of SOA

=item B<--force, -f> force generation and bumping of SOA record

=item B<--nosoa> never update the SOA

=item B<--outdir, -o> change putput

=item B<--dumpzone> dump a zone to stdout.

=item B<--site arg> specify a site for generating a node list

=item B<--no-rsynclist> do not generate a node list

=item B<--nogen> exit without doing anything

=item B<--nowait> do not block on database lock on startup

=item B<--random-sleep #> on startup, sleep random seconds up to #

=back

=head1 DESCRIPTION

The generate-zones command is used to generate zone files, as well
as configuration files and zone file hierarchies that can be copied to
dns servers for inclusion in their DNS configuration files.  This script
is generally invoked by the generate-and-sync script which takes care of
distribution.  An end-user may invoke zonegen-force to invoke the entire
process for a given zone.

A DNS table (dns_change_record) is checked to determine which zones have
been changed. generate-zones will SELECT records in dns_change_record
for update in all cases, which will result in other zonegen invocations
blocking until the other script is finished. generate-zones will
typically delete all processed records in dns_change_record unless the
B<--nosoa> option was specified, in which case they will persist until a
future run.  In the case that zones are specified on the command line,
generate-zones will lock all records for update but only delete the
zones it processed.

By default only those zones and ones without files in the output
directory will be generated.  If a zone has changed, its SOA serial
number will be bumped by one and zone files generation.  A configuration
file and a shell script that invokes rndc for each changed zone is also
generated with a hierarchy of symlinks for distribution to name servers.
These are used by a wrapper script to copy to machines.

Anytime the SOA record changes, change records are removed from the
dns_change_record changes so subsequent runs will not retrigger generation
of the zone.  The --nosoa option will ensure this does not happen.

If invoked from the generate-and-sync wrapper script that also
takes care of syncing (the normal invocation), the lock file
/var/lib/zonegen/run/zonegen.lock will also prevent a run from happening
if the lock file is newer than three hours.

It is possible to specify zone names on the command line.  In that case,
only those zones will be operated on rather than all zones that are in
the database.  Note that you may need to use other options to trigger
the behavior you want, since this option just restricts the zones that
the command operates on, rather than forcing generation of zones.

Unlike what might be expected, this script generates zone files that
make a zone file a 'master' server' rather than one that slaves zones
from another server.

The command has two subdirectories that it creates under the output
directory, 'zones' and 'perserver'.  The zones directory contains forward
zones, and a subdirectory 'inaddr' with the inverse zones.

The perserver directory contains a directory per nameserver.  The
nameservers are those that generate-zones found to be listed as
authoritative for zones with the should_generate flag set to Y.  Each
of these directories contains two directories, "etc", and "zones".  The
etc directory contains part of a named.conf file that can be included on
a name server to make it a master server for auto generated zones.  The
"zones" file contains symlinks back to the master zones directory in
the output_root area.  This entire tree can be copied via rsync or rdist
(by not replicating symlinks) to a nameserver's auto-gen directory under
it's named root.

generate-zones normally does it's work under the /var/lib/zonegen/auto-gen/
directory.  The B<--outdir> option can be used to change the root of
this work.

The B<--genall> option is used to tell generate-zones that it should
generate zones regardless of if it is marked as such in JazzHands.  Zones
will never be setup to be pushed to DNS servers if they are not
configured for auto-generation.  This option exists to see what a zone
may end up looking like it if it were auto generated.

The B<--forcegen> option skips the check to see if a zone has changed,
and generates a zone anyway.  Other options can influence if a zone
generation will happen, as well.  The SOA serial number will only be
incremented if the zone has changed, however, unless the B<--forcesoa>
option is used.

Note that forcegen implies an SOA increase if the zone file did not exist
locally already.  Normally, the zone would just be generated on disk in that
case.

The B<--forcesoa> option causes the SOA serial number to be incremented
for any generated zones, even if there were no changes to the zone.
This option cannot be combined with the --nosoa option

The B<--force> option causes the zone to be forcibly regenerated and the
SOA serial number to be bumped.  This basically is a shorthand for the
B<--forcegen> and B<--forcesoa> options.

The B<--nosoa> prevents the serial number from ever being updated on a
Zone.  This option cannot be combined with the --forcesoa optoin.

The B<--dumpzone> takes one zone as an argument and will dump the zone
to stdout.  Note that it does NOT change the serial number if it's due
for updating, so it will match the last generation of the record.  This
is meant as an error checking aide.

generate-zones uses the rows of the network_range, dns_domain,
dns_record, netblock, and network_interface tables in JazzHands to create
zone files.

The dns_domain table contains the typical information about a zone, from
the SOA data, including serial number, to hierarchical relationships
among zones.  It also contains a Y/N flag column, SHOULD_GENERATE and a
value, LAST_GENERATED, to indicate if a zone should be auto-generated by
this script, and the last time it was auto-generated.

The dns_record table contains all records for a given dns_domain.  It
contains typical values for a DNS entry, such as Type and Class, but
also contains a Netblock_id for resolving A/AAA records.  If the DNS_NAME
value is set to NULL, the record is assumed to share a name of another
record via the REFERENCE_DNS_RECORD_ID.  If this value is NULL, the record
is assumed to be for the zone.  This is, for example, how NS records are
populated.

Under normal circumstances, PTR records are not explicitly stored in
the db, but instead there is a dns_domain record for each inverse zone.
It has a dns_record of REVERSE_ZONE_BLOCK_PTR that indicates that the
netblock_id for the record, contains the base record for a netblock
that should be used to generate a reverse zone.  All A/AAA records matching
this base record will be used to generate a PTR record, unless the
should_generate_ptr flag is set to 'N' for a given A/AAA record.

Other records are set via the dns_value flag in the dns_record table.

The network_range simply causes dns entries of the form pool-<ip>, with
the dots translated to dashes in the appropriate zone (as ascertained
from the dns name of the network_interface record), unless dns_prefix is set,
in which case, it will use that.  If a name is set
elsewhere in the db for an IP, that name will be favored over the
generated name in a network range entry.

When a zone is generated, the mtime of the zone file will be changed to
match the last_generated value of the dns_domain row for that zone.  In the
event that the zone is updated by a run (that is, some operation bumped the
SOA), the date, and dns_domain.last_updated are both set to the start time of
the transaction.

The script will also create sitecodeacl.conf in the main etc directory with
a symlink in the per-server directory with a named acl for each site code
based on the site_netblock and netblock tables

The script also creates a rsynclist.txt file in the zone root.  generate-zones
can be prevented from creating this file with the B<--no-rsync-list> option.
If the file exists, it will not be removed.  If the site of the host
running zonegen can be discerned from the device table or overriden via
the B<--site> option, generate-zones will look for devices that are
recursively members of device collections with the DNSZonegen:DNSDistHosts
property set that are also in the datacenter (either via the site_code on the
property or the site_code on the device, the former taking precedence).
The argument "none" can be provided to the B<--site> argument to not find a
site, in which case, all devices with that property set, regardless of site
will have the zones generated.   It should generally be alright if this
happens because every host that generates zones should have the same zone
files with the same dates.

The B<--nogen> option is used to cause the script to exit. This is useful
for wrapper scripts that will rsync if there is a bug in this such that
generation hangs and zones needs to be pushed out anyway.

The B<--nowait> option is used to cause the script to immediately return if
another zonegen instance is running and has the dns_change_record table locked.
This will cause the script to exit non-zero.

=head1 ENVIRONMENT

The APPAUTHAL_CONF environment variable is used by JazzHands::DBI to determine
what database credentials to use.

=head1 AUTHORS

Todd Kover

=head1 SEE ALSO

named(9), L<JazzHands::DBI>, L<JazzHands::Common::Util>

=head1 BUGS

If an rsync fails to run, the next run may not notify the far end server
that a zone has changed and an 'rndc' never executed. rsync should
probably be replaced with 'rdist' or some other mechanism that causes the
command to be run when the new file is placed.  An alternative would be to
just run 'rndc reload', without zones, on the clients, which will cause it
to reload all zones.  This may have unintended side effects as well.

It may be desirable to push zones to nameservers that are not listed in the
zone as authoritative.  This does not generate files that make this
straightforward.
