#!/usr/bin/env perl
#
# Copyright (c) 2014, Todd M. Kover
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

exit do_netblock_collection_update();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

sub do_netblock_collection_update {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	# print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;

	my (@errs);

	my $numchanges = 0;

	my $ncid = $stab->cgi_parse_param('NETBLOCK_COLLECTION_ID');

	#
	# deal with netblock removals
	#
	foreach my $id ( $stab->cgi_get_ids('rm_NETBLOCK_ID') ) {
		my $x;
		if ( !(
			$x = ( $stab->DBDelete(
				table  => 'netblock_collection_netblock',
				dbkey  => [ 'netblock_collection_id', 'netblock_id' ],
				keyval => [ $ncid,                    $id ],
				errors => \@errs,
			) )
		) )
		{
			$stab->error_return( join( " ", @errs ) );
		}
		$numchanges += $x;
	}

	#
	# deal with netblock collection removals
	#
	foreach my $id ( $stab->cgi_get_ids('rm_NETBLOCK_COLLECTION_ID') ) {
		my $x;
		if ( !(
			$x = ( $stab->DBDelete(
				table => 'netblock_collection_hier',
				dbkey =>
				  [ 'netblock_collection_id', 'child_netblock_collection_id' ],
				keyval => [ $ncid, $id ],
				errors => \@errs,
			) )
		) )
		{
			$stab->error_return( join( " ", @errs ) );
		}
		$numchanges += $x;
	}

	#
	# deal with rank updates for existing netblocks
	#
	foreach my $p ( $cgi->param ) {
		if ( $p !~ /^rank_NETBLOCK_ID_([0-9]+)$/i ) { next; }
		my $id = $1;

		my $new_rank = $stab->cgi_parse_param($p);

		# Get current value from database
		my $sth = $stab->prepare(
			qq{
			SELECT netblock_id_rank
			FROM netblock_collection_netblock
			WHERE netblock_collection_id = ?
			AND netblock_id = ?
		}
		) || return $stab->return_db_err;

		$sth->execute( $ncid, $id ) || return $stab->return_db_err;
		my ($old_rank) = $sth->fetchrow_array;
		$sth->finish;

		# Convert empty string to NULL for comparison
		my $old_val = defined($old_rank)                    ? $old_rank : '';
		my $new_val = defined($new_rank) && $new_rank ne '' ? $new_rank : undef;

		# Only update if changed
		if ( $old_val ne ( $new_val // '' ) ) {
			my $hash = { netblock_id_rank => $new_val };

			if ( !(
				$numchanges += $stab->DBUpdate(
					table  => 'netblock_collection_netblock',
					dbkey  => [ 'netblock_collection_id', 'netblock_id' ],
					keyval => [ $ncid,                    $id ],
					hash   => $hash,
					errors => \@errs
				)
			) )
			{
				$stab->error_return( join( " ", @errs ) );
			}
		}
	}

	#
	# deal with netblock additions
	#
	foreach my $p ( $cgi->param ) {
		if ( $p !~ /^add_NETBLOCK[0-9]+$/i ) { next; }

		# Get the next new netblock to add
		my $add_nb = $stab->cgi_parse_param($p);

		# Ignore the parameter if it has no value
		if ( !$add_nb ) { next; }

		my $nb = $stab->get_netblock_from_ip( ip_address => $add_nb );
		if ( !$nb ) {
			return $stab->error_return("Unable to find netblock $add_nb");
		}

		# Check if this netblock is already in the collection
		my $check_sth = $stab->prepare(
			qq{
			SELECT COUNT(*) FROM netblock_collection_netblock
			WHERE netblock_collection_id = ? AND netblock_id = ?
		}
		) || return $stab->return_db_err;

		$check_sth->execute( $ncid, $nb->{'netblock_id'} )
		  || return $stab->return_db_err;
		my ($exists) = $check_sth->fetchrow_array;
		$check_sth->finish;

		# Skip if already exists
		if ($exists) {
			next;
		}

		# Get the corresponding rank field if it exists
		my $rank_param = $p;
		$rank_param =~ s/^add_/rank_add_/;
		my $rank = $stab->cgi_parse_param($rank_param);

		my $new = {
			netblock_collection_id => $ncid,
			netblock_id            => $nb->{'netblock_id'},
		};

		# Only add rank if it has a value
		if ( defined($rank) && $rank ne '' ) {
			$new->{netblock_id_rank} = $rank;
		}

		my $x = $stab->DBInsert(
			table  => 'netblock_collection_netblock',
			hash   => $new,
			errors => \@errs
		);

		if ( !defined($x) ) {
			my $errmsg = @errs ? join( " ", @errs ) : $stab->errstr;
			$stab->error_return($errmsg);
		}
		$numchanges += $x;
	}

	#
	# deal with child netblock collection additions
	#
	foreach my $p ( $cgi->param ) {
		if ( $p !~ /^pick_NETBLOCK_COLLECTION_ID[0-9]+$/i ) { next; }

		my $newncid = $stab->cgi_parse_param($p);

		# Ignore the parameter if it has no value
		if ( !$newncid ) { next; }

		# Check if this child collection is already in the hierarchy
		my $check_sth = $stab->prepare(
			qq{
			SELECT COUNT(*) FROM netblock_collection_hier
			WHERE netblock_collection_id = ? AND child_netblock_collection_id = ?
		}
		) || return $stab->return_db_err;

		$check_sth->execute( $ncid, $newncid )
		  || return $stab->return_db_err;
		my ($exists) = $check_sth->fetchrow_array;
		$check_sth->finish;

		# Skip if already exists
		if ($exists) {
			next;
		}

		my $new = {
			netblock_collection_id       => $ncid,
			child_netblock_collection_id => $newncid
		};

		my $x = $stab->DBInsert(
			table  => 'netblock_collection_hier',
			hash   => $new,
			errors => \@errs
		);

		if ( !defined($x) ) {
			my $errmsg = @errs ? join( " ", @errs ) : $stab->errstr;
			$stab->error_return($errmsg);
		}
		$numchanges += $x;
	}

	if ($numchanges) {
		my $url = "./?NETBLOCK_COLLECTION_ID=$ncid";
		$stab->commit;
		return $stab->msg_return( "Collection Updated", $url, 1 );
	}
	$stab->rollback;
	$stab->msg_return("Nothing changed.  No changes submittted.");
	0;
}
