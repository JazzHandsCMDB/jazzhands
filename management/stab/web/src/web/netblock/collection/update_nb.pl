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
use JazzHands::Common::Util qw(_dbx);
use Data::Dumper;

exit do_netblock_collection_update();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

sub do_netblock_collection_update {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi = $stab->cgi || die "Could not create cgi";

	# print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html; exit;

	my(@errs);

	my $numchanges = 0;

	my $ncid = $stab->cgi_parse_param('NETBLOCK_COLLECTION_ID');
	my $add_nb = $stab->cgi_parse_param('add_NETBLOCK');

	#
	# deal with netblock removals
	#
	foreach my $id ( $stab->cgi_get_ids('rm_NETBLOCK_ID')) {
		my $x;
		if(!($x = ($stab->DBDelete(
					table	=> 'netblock_collection_netblock',
					dbkey => ['netblock_collection_id', 'netblock_id'],
					keyval => [ $ncid, $id ],
					errors => \@errs,
				)))) {
			$stab->error_return(join(" ", @errs));
		}
		$numchanges += $x;
	}

	#
	# deal with netblock collection removals
	#
	foreach my $id ( $stab->cgi_get_ids('rm_NETBLOCK_COLLECTION_ID')) {
		my $x;
		if(!($x = ($stab->DBDelete(
					table	=> 'netblock_collection_hier',
					dbkey => ['netblock_collection_id', 
						'child_netblock_collection_id'
					],
					keyval => [ $ncid, $id ],
					errors => \@errs,
				)))) {
			$stab->error_return(join(" ", @errs));
		}
		$numchanges += $x;
	}

	#
	# deal with netblock additions
	#
	if($add_nb) {
		my $nb = $stab->get_netblock_from_ip(ip_address=>$add_nb);

		if(!$nb) {
			return $stab->error_return("Unable to find netblock $add_nb");
		}

		my $new = {
			netblock_collection_id => $ncid,
			netblock_id => $nb->{ _dbx('NETBLOCK_ID') },
		};

		if(!($numchanges += $stab->DBInsert(
				table => 'netblock_collection_netblock',
				hash => $new,
				errors => \@errs))) {
			$stab->error_return(join(" ", @errs));
		}
	}

	#
	# deal with child netblock additions
	#
	my $newncid = $stab->cgi_parse_param('pick_NETBLOCK_COLLECTION_ID');
	if($newncid) {
		my $new = {
			netblock_collection_id => $ncid,
			child_netblock_collection_id => $newncid
		};

		if(!($numchanges += $stab->DBInsert(
				table => 'netblock_collection_hier',
				hash => $new,
				errors => \@errs))) {
			$stab->error_return(join(" ", @errs));
		}
	}

	if($numchanges) {
		my $url = "./?NETBLOCK_COLLECTION_ID=$ncid";
		$stab->commit;
		return $stab->msg_return("Collection Updated", $url, 1);
	}
	$stab->rollback;
	$stab->msg_return("Nothing changed.  No changes submittted.");
	0;
};
