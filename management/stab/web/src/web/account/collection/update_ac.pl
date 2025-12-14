#!/usr/bin/env perl
#
# Copyright (c) 2017, Todd M. Kover
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

use strict;
use warnings;
use FileHandle;
use JazzHands::STAB;
use Data::Dumper;

exit do_account_collection_update();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

sub do_account_collection_update {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	#- print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;

	my (@errs);

	my $numchanges = 0;

	my $acid = $stab->cgi_parse_param('ACCOUNT_COLLECTION_ID');

	my $admin = $stab->check_role('AccountCollectionAdmin');

	# Is this a development server?
	my $development_override = 0;
	if ( $ENV{'development'} =~ /true/ ) {

		# Authorize write access
		$development_override = 1;
	}

	if (   !$development_override
		&& !$admin
		&& !$stab->check_account_collection_permissions( $acid, 'RW' ) )
	{
		return $stab->error_return(
			"You do not have permission to edit that account collection ($acid)"
		);
	}

	#
	# deal with account removals
	#
	foreach my $id ( $stab->cgi_get_ids('Del_ACCOUNT_ID') ) {
		my $x;
		if ( !(
			$x = ( $stab->DBDelete(
				table  => 'account_collection_account',
				dbkey  => [ 'account_collection_id', 'account_id' ],
				keyval => [ $acid,                   $id ],
				errors => \@errs,
			) )
		) )
		{
			$stab->error_return( join( " ", @errs ) );
		}
		$numchanges += $x;
	}

	#
	# here, we'd deal with account collections
	#

	#
	# deal with account additions
	#
	foreach my $id ( $stab->cgi_get_ids('ACCOUNT_ID_new') ) {
		next if ( !defined($id) );
		my $acctid = $stab->cgi_parse_param( "ACCOUNT_ID_new", $id );

		# this happens if its left blank.
		next if ( !$acctid );
		my $new = {
			account_collection_id => $acid,
			account_id            => $acctid,
		};

		if ( !(
			$numchanges += $stab->DBInsert(
				table  => 'account_collection_account',
				hash   => $new,
				errors => \@errs
			)
		) )
		{
			$stab->error_return( join( " ", @errs ) );
		}
	}

	if ($numchanges) {
		my $url = "./?ACCOUNT_COLLECTION_ID=$acid";
		$stab->commit;
		return $stab->msg_return( "Collection Updated", $url, 1 );
	}
	$stab->rollback;
	$stab->msg_return("Nothing changed.  No changes submittted.");
	0;
}
