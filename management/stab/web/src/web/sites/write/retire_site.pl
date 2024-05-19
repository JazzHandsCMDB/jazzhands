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

#
# This does everything to move a site to inactive status.
#

use strict;
use warnings;
use JazzHands::STAB;
use URI;

retire_site();

sub retire_site {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $site = $stab->cgi_parse_param('SITE_CODE');

	if ( !$site ) {
		$stab->error_return("No Site Specified");
	}

	if ( ( my $status = check_site_validity( $stab, $site ) ) ) {
		if ( $status eq 'INACTIVE' ) {
			$stab->error_return("$site is already marked as inactive.");
		}
	} else {
		$stab->error_return("$site is not a valid site.");
	}

	if ( check_for_devices( $stab, $site ) ) {
		$stab->error_return("There are still devices in site $site");
	}

	my (@domids) = get_site_dns_domains( $stab, $site );
	my $numchanges = 0;
	$numchanges += purge_site_dns_domains( $stab, @domids );
	$numchanges += remove_site_netblocks( $stab, $site );
	$numchanges += purge_netblocks_from_site( $stab, $site );
	$numchanges += change_site_status( $stab, $site, 'INACTIVE' );

	if ($numchanges) {
		$stab->commit;
		$stab->msg_return( "Changed $site state to INACTIVE", undef, 1 );
	} else {
		$stab->rollback;
		$stab->msg_return("Nothing to change");
	}
	undef $stab;
}

sub check_site_validity {
	my ( $stab, $site ) = @_;

	my $sth = $stab->prepare( qq{
		select	site_status
		 from	site
		where	site_code = :1
	}
	);
	$sth->execute($site) || $stab->return_db_err($sth);
	my ($rv) = $sth->fetchrow_array;
	$sth->finish;
	$rv;
}

sub check_for_devices {
	my ( $stab, $site ) = @_;

	my $sth = $stab->prepare( qq{
		select	count(*)
		  from	device d
				left join rack_location l
					using (rack_location_id)
		 where
			(l.site_code = :1
		   	or regexp_like(lower(d.device_name), :2)
			)
		  or	d.device_id in (
				select distinct device_Id
				  from network_interface_netblock
				 where netblock_id in
					(
					select netblock_id from
						(select level, netblock_id
						   from  netblock
						connect by prior netblock_Id = parent_netblock_Id
						start with netblock_id in (
						select netblock_id from site_netblock where site_code = :1)
						order by level desc
					)
				   )
				)
	}
	);

	my $lsite = $site;
	$lsite =~ tr/A-Z/a-z/;
	$sth->execute( $site, "^.*$site\.example.com" )
	  || $stab->return_db_err($sth);
	my ($rv) = $sth->fetchrow_array;
	$sth->finish;
	$rv;
}

sub get_site_dns_domains {
	my ( $stab, $site ) = @_;

	$site =~ tr/A-Z/a-z/;
	my $sth = $stab->prepare( qq{
		select	dns_domain_id
		 from	dns_domain
		where	regexp_like(lower(soa_name), :1)
	}
	);
	$sth->execute("^.*\.$site\.\.example\.com")
	  || $stab->return_db_err($sth);
	my (@rv);
	while ( my ($id) = $sth->fetchrow_array ) {
		push( @rv, $id );
	}
	@rv;
}

sub purge_site_dns_domains {
	my ($stab) = shift @_;

	my $sth = $stab->prepare( qq{
		begin
			delete from dns_record where dns_domain_id = :1;
			delete from dns_domain where dns_domain_id= :1;
		end;
	}
	);

	my $numchanges = 0;
	while ( my $id = shift(@_) ) {
		$numchanges += $sth->execute($id);
	}
	$numchanges;
}

sub purge_netblocks_from_site {
	my ( $stab, $site ) = @_;

	my $sth = $stab->prepare( qq{
		begin
		delete from dns_record where netblock_id in (
			select netblock_id from
			(select	level, netblock_id
			  from	netblock
			connect by prior netblock_Id = parent_netblock_Id
			start with netblock_id in (
				select netblock_id from site_netblock where site_code = :1)
			order by level desc
			)
		);

		delete from netblock where netblock_id in (
			select netblock_id from
			(select	level, netblock_id
			  from	netblock
			connect by prior netblock_Id = parent_netblock_Id
			start with netblock_id in (
				select netblock_id from site_netblock where site_code = :1)
			order by level desc
			)
		);
		end;
	}
	);
	my $numchanges = $sth->execute($site) || $stab->return_db_err($sth);
	$numchanges;
}

sub remove_site_netblocks {
	my ( $stab, $site ) = @_;

	my $sth = $stab->prepare( qq{
		delete from site_netblock where site_code = :1
	}
	);
	my $numchanges = $sth->execute($site) || $stab->return_db_err($sth);
	$numchanges;
}

sub change_site_status {
	my ( $stab, $site, $code ) = @_;

	$code = 'INACTIVE' if ( !$code );

	my $sth = $stab->prepare( qq{
		update site set site_status = :2 where site_code = :1 and
			site_status <> :2
	}
	);
	my $numchanges += $sth->execute( $site, $code )
	  || $stab->return_db_err($sth);
	$numchanges;
}
