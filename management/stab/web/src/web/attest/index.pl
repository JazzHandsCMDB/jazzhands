#!/usr/bin/env perl
#
# Copyright (c) 2015, Todd M. Kover
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


#
# $Id$
#

use strict;
use warnings;
use POSIX;
use Data::Dumper;
use Carp;
use JazzHands::STAB;
use JazzHands::Common qw(_dbx);
use Net::IP;

# causes stack traces on warnings
# local $SIG{__WARN__} = \&Carp::cluck;
do_attest_toplevel();

sub do_attest_toplevel {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi	  || die "Could not create cgi";

	my $actas = $stab->cgi_parse_param('actas');

	do_my_attest($stab, $actas);

	undef $stab;
}

sub do_my_attest {
	my ($stab, $actas) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{ -title => "Attesting", -javascript => 'attest' } ), "\n";

	print $cgi->h4( { -align => 'center' }, "Outstanding Attestations" );

	my $acctid = $stab->get_account_id($actas);

	# XXX - need to make it so you can only act as people who work for you!

	my $sth = $stab->prepare(qq{
		SELECT approver_account_id, aisi.*, aii.*
		FROM	approval_instance ai
				INNER JOIN approval_instance_step ais
					USING (approval_instance_id)
				INNER JOIN approval_instance_step_item aisi
					USING (approval_instance_step_id)
				INNER JOIN approval_instance_item aii 
					USING (approval_instance_item_id)
				INNER JOIN approval_instance_link ail 
					USING (approval_instance_link_id)
		WHERE	approver_account_id = ?
	}) || return $stab->return_db_err;

	$sth->execute($acctid) || return $stab->return_db_err($sth);

	print $cgi->start_form( { -action => "attest.pl" } );
	print $cgi->start_table( { -class => 'attest' } );

    my $checky = $cgi->checkbox({
        -class => 'approveall',
        -name => 'selectall',
        -label => 'Y'
	});

    my $checkn = $cgi->checkbox({
        -class => 'disproveall',
        -name => 'selectall',
        -label => 'N'
	});
	$checkn = 'N';

	print $cgi->th([
		$checky, $checkn, 'What', "Who", "Value",
	]);

	my $lastlhs;
	my $classnote = 0;
	while(my $hr = $sth->fetchrow_hashref) {

		if($lastlhs) {
			if($lastlhs ne $hr->{_dbx('approved_lhs')}) {
				$lastlhs = $hr->{_dbx('approved_lhs')};
				$classnote = 1 - $classnote;
			}
		} else {
			$lastlhs = $hr->{_dbx('approved_lhs')};
		}

		my $myclass;
		if($classnote % 2) {
			$myclass = 'even';
		} else {
			$myclass = 'odd';
		}

		print $cgi->Tr(
			{ -align => 'center', -class => $myclass },
			$cgi->td(
				[
					$cgi->checkbox({
						-class => 'attesttoggle approve', 
						-name => 'app_'.$hr->{_dbx('approval_instance_item_id')},
						-label => ''}),
					$cgi->checkbox({
						-class => 'attesttoggle disapprove', 
						-name => 'dis'.$hr->{_dbx('approval_instance_item_id')},
						-label => ''}),
					$hr->{approved_label} || '',
					$hr->{approved_lhs} || '',
					$hr->{approved_rhs} || ''
				]
			)
		);
	}
	print $cgi->end_html, "\n";
}
