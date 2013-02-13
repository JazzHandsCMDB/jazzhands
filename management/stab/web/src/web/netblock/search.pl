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

use strict;
use warnings;
use Net::Netmask;
use FileHandle;
use JazzHands::STAB;
use JazzHands::Common qw(:all);

do_netblock_search();

sub numerically { $a <=> $b; }

sub do_netblock_search {
	my $stab = new JazzHands::STAB;
	my $cgi  = $stab->cgi;
	my $dbh  = $stab->dbh;

	my $bycidr = $stab->cgi_parse_param('bycidr');
	my $bydesc = $stab->cgi_parse_param('bydesc');

	# print $cgi->header, $cgi->start_html, $cgi->Dump, $cgi->end_html;
	# exit;

	if ( !defined($bycidr) && !defined($bydesc) ) {
		$cgi->delete('orig_return');
		$stab->error_return("No search criteria specified");
	}

	if ( defined($bycidr) ) {
		my $blk = $stab->parse_netblock_search($bycidr);

		if ( !defined($blk) ) {
			$cgi->delete('orig_return');
			$stab->error_return(
				"Could not locate a netblock $bycidr");
		}
		my $blkid = $blk->{_dbx('NETBLOCK_ID')};

		my $url = "index.pl?nblkid=$blkid";
		$cgi->redirect($url);
		$dbh->rollback;
		exit 1;
	} elsif ( defined($bydesc) ) {
		my $blks  = $stab->parse_netblock_description_search($bydesc);
		my $tally = scalar keys(%$blks);

		if ( $tally == 0 ) {
			return $stab->error_return("Sorry, no matches.");
		} elsif ( $tally > 50 ) {
			return $stab->error_return(
				"Sorry, too many matches. (>50)");
		} else {
			print $cgi->header;
			print $stab->start_html(
				{ -title => 'Search Matches' } );

			my $x = "";
			foreach my $id ( sort numerically keys(%$blks) ) {
				my $blk = $blks->{$id};
				my $mask =
				  $blk->{_dbx('IP')} . "/" . $blk->{_dbx('NETMASK_BITS')};
				my $desc = $blk->{_dbx('DESCRIPTION')};
				my $tix  = $blk->{_dbx('RESERVATION_TICKET_NUMBER')};
				my $pid  = $blk->{_dbx('PARENT_NETBLOCK_ID')};
				my $stat = $blk->{_dbx('NETBLOCK_STATUS')};

				$desc = ( defined($desc) ? $desc : "" );
				$tix  = ( defined($tix)  ? $tix  : "" );

				my $tixlink = "";
				if ( defined($tix) && length($tix) ) {
					$tixlink = $cgi->a(
						{
							-href => $stab
							  ->build_trouble_ticket_link
							  (
								$tix)
						},
						$tix
					);
				}

				$x .= $cgi->Tr(
					$cgi->td(
						$cgi->a(
							{
								-href =>
"index.pl?nblkid=$pid"
							},
							$mask
						)
					),
					$cgi->td($stat),
					$cgi->td(
						$cgi->a(
							{
								-href =>
"index.pl?nblkid=$pid"
							},
							$desc
						)
					),
					$cgi->td($tixlink)
				);
			}

			print $cgi->table(
				{ -border => 1, -align => 'center' },
				$cgi->th(
					[
						'Netblock',    'Status',
						'Description', 'Ticket'
					]
				),
				$x
			);
			print $cgi->end_html;
			$dbh->rollback;
			exit;
		}
	}

	return $stab->error_return("You have found a bug.  Please try again.");
}

