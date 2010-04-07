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

#
# $Id$
#

#
# this script validates input for an addition, and in the event of problem,
# will send an error message and present the user with an opportunity to
# fix.
#

use strict;
use warnings;
use JazzHands::STAB;
use URI;

do_domain_add();

############################################################################3

#
# if the zone is a /24, link it to an appropriate reverse netblock.  If there
# isn't one, create it.
#
sub link_inaddr_zone($$$) {
	my ( $stab, $name, $dnsdomid ) = @_;

	$name =~ s/.in-addr.arpa//;
	my $ip =
	  join( ".", reverse( ( split( /\./, $name ) )[ 0, 1, 2 ] ) ) . ".0";

	my $nb = $stab->get_netblock_from_ip( $ip, 24, 'nocare', 'nocare' );
	if ( !$nb ) {
		my $parnb = $stab->guess_parent_netblock_id( $ip, 24 );
		if ($parnb) {
			$parnb = $parnb->{'NETBLOCK_ID'};
		}
		$nb = $stab->add_netblock( $ip, $parnb, 24, 'Y' );
	}

	my $nbid = $nb->{'NETBLOCK_ID'};
	$stab->add_dns_record( $dnsdomid, undef, undef, 'IN',
		'REVERSE_ZONE_BLOCK_PTR', $nbid );
	return 1;
}

sub add_default_ns_records($$) {
	my ( $stab, $dnsdomid ) = @_;

	# these really need to be set as properties in the database...

	$stab->add_dns_record( $dnsdomid, undef, undef, 'IN', 'NS',
		'auth00.ns.example.com.' );
	$stab->add_dns_record( $dnsdomid, undef, undef, 'IN', 'NS',
		'auth01.ns.example.com.' );
	$stab->add_dns_record( $dnsdomid, undef, undef, 'IN', 'NS',
		'auth02.ns.example.com.' );
	$stab->add_dns_record( $dnsdomid, undef, undef, 'IN', 'NS',
		'auth03.ns.example.com.' );
	$stab->add_dns_record( $dnsdomid, undef, undef, 'IN', 'NS',
		'auth04.ns.example.com.' );

}

#
# the meat of the script
#
sub do_domain_add {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $soaname = $stab->cgi_parse_param('SOA_NAME');
	my $serial  = $stab->cgi_parse_param('SOA_SERIAL') || 0;
	my $refresh = $stab->cgi_parse_param('SOA_REFRESH') || 21600;
	my $retry   = $stab->cgi_parse_param('SOA_RETRY') || 7200;
	my $expire  = $stab->cgi_parse_param('SOA_EXPIRE') || 2419200;
	my $min     = $stab->cgi_parse_param('SOA_MINIMUM') || 3600;
	my $ttl     = $stab->cgi_parse_param('SOA_TTL') || $min || 3600;
	my $mname   = $stab->cgi_parse_param('SOA_MNAME')
	  || 'auth00.ns.example.com';
	my $rname = $stab->cgi_parse_param('SOA_RNAME')
	  || 'hostmaster.example.com';
	my $gen   = $stab->cgi_parse_param('chk_SHOULD_GENERATE');
	my $addns = $stab->cgi_parse_param('chk_DEFAULT_NS_RECORDS');
	my $type = $stab->cgi_parse_param('DNS_DOMAIN_TYPE');
	my $class = 'IN';

	$gen   = $stab->mk_chk_yn($gen);
	$addns = $stab->mk_chk_yn($addns);

	# $soaname = '70.50.10.in-addr.arpa';
	# $gen = 'Y';

	if ( !defined($soaname) ) {
		$stab->error_return("You must specify a Domain Name");
	}

	if ( !defined($type) ) {
		$stab->error_return("You must specify a Domain Type");
	}

	if ( defined($soaname) ) {
		my $q = qq{
			 select	dns_domain_id
			   from	dns_domain
			  where soa_name = :1
		};
		my $sth = $stab->prepare($q) || $stab->return_db_err;
		$sth->execute($soaname) || $stab->return_db_err($sth);
		my $hr = $sth->fetchrow_hashref;
		if ( defined($hr) ) {
			$stab->error_return(
				"The zone $soaname already exists.");
		}
	}

	my $numchanges = 0;

	my $bestparent =
	  guess_best_parent_dns_domain_from_domain( $stab, $soaname );

	my $q = qq{
		insert into dns_domain (
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
			dns_domain_type,
			should_generate
		) values (
			:soaname,
			:class,
			:ttl,
			:serial,
			:refresh,
			:retry,
			:expire,
			:minimum,
			:mname,
			:rname,
			:parent,
			:type,
			:shouldgen
		) returning dns_domain_id into :dnsdomid
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err;

	my $dnsdomid;
	$sth->bind_param( ':soaname', $soaname ) || $stab->return_db_err($sth);
	$sth->bind_param( ':class',   $class )   || $stab->return_db_err($sth);
	$sth->bind_param( ':ttl',     $ttl )     || $stab->return_db_err($sth);
	$sth->bind_param( ':serial',  $serial )  || $stab->return_db_err($sth);
	$sth->bind_param( ':refresh', $refresh ) || $stab->return_db_err($sth);
	$sth->bind_param( ':retry',   $retry )   || $stab->return_db_err($sth);
	$sth->bind_param( ':expire',  $expire )  || $stab->return_db_err($sth);
	$sth->bind_param( ':minimum', $min )     || $stab->return_db_err($sth);
	$sth->bind_param( ':mname',   $mname )   || $stab->return_db_err($sth);
	$sth->bind_param( ':rname',   $rname )   || $stab->return_db_err($sth);
	$sth->bind_param( ':type',   $type )   || $stab->return_db_err($sth);
	$sth->bind_param( ':parent', $bestparent )
	  || $stab->return_db_err($sth);
	$sth->bind_param( ':shouldgen', $gen ) || $stab->return_db_err($sth);
	$sth->bind_param_inout( ':dnsdomid', \$dnsdomid, 500 )
	  || $stab->return_db_err($sth);

	$numchanges += $sth->execute || $stab->return_db_err($sth);

	if ( $soaname =~ /^((\d+)\.){3}in-addr.arpa$/ ) {
		$numchanges += link_inaddr_zone( $stab, $soaname, $dnsdomid );
	}

	if ($addns) {
		add_default_ns_records( $stab, $dnsdomid );
	}

	if ($numchanges) {
		my $url = "../?dnsdomainid=$dnsdomid";
		$stab->commit;
		$stab->msg_return( "Domain Added Successfully.", $url, 1 );
	}
	$stab->rollback;
	$stab->msg_return("Nothing to do.");
}

sub guess_best_parent_dns_domain_from_domain {
	my ( $stab, $name ) = @_;

	return undef if ( !defined($name) );

	my $q = qq{
		select	dns_domain_id
		  from	dns_domain
		 where	soa_name = :1
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err;

	while ( length($name) && $name =~ /\./ && $name ne '.' ) {
		$name =~ s/^[^\.]+\.//;
		$sth->execute($name);
		my $id = ( $sth->fetchrow_array )[0];
		if ( defined($id) ) {
			$sth->finish;
			return ($id);
		}
	}
	return (undef);
}
