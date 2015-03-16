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
use FileHandle;
use JazzHands::STAB;
use JazzHands::Common qw(:all);
use Data::Dumper;

exit do_apps();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

#
# The top level of the list has class approle_root, expandable subnodes
# have clas approle_depth, and leaves are approle_leaf.  The collapse/expand
# javascript relies on some of these classnames.
#
sub build_hier {
	my ( $stab, $tier, $depth ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $root = $stab->guess_stab_root;

	my $t;
	while ( my $item = shift( @{ $tier->{keys} } ) ) {
		my $x = $item;
		my $y = "";
		if ( exists( $tier->{kids}->{$item} ) ) {
			$y = build_hier( $stab, $tier->{kids}->{$item},
				$depth + 1 )
			  || "";

		}

		my $canadd = 0;
		if (
			$tier->{hr}->{$item}
			&& (      !$tier->{hr}->{$item}->{ _dbx('NUM_DEVICES') }
				|| $tier->{hr}->{$item}->{ _dbx('NUM_KIDS') } )
		  )
		{
			$canadd = 1;
		}

	   # FOR NOW - no add functionality written, so that needs to be written
	   # before this can be flipped on...
		$canadd = 0;

		my $style1 = "";
		my $style2 = "";
		$style1 .= "margin-left: " . ( $depth * 20 ) . "px;";

		my $id1   = $item . "_depth";
		my $class = "approle_depth";
		if ( !$y ) {
			if ($canadd) {
				$class = 'approle_undecided';
			} else {
				$class = 'approle_leaf';
			}
		} else {
			$class = 'approle_depth';
		}

		my $img = "collapse.jpg";
		if ( $depth == 0 ) {
			$class = "approle_root";
			$id1   = $item . "_root";

		     # 20 is hard coded in AddAppChild in app-utils.js, so would
		     # need to be changed there, too.
			$style2 .=
			  "margin-left: " . ( $depth * 20 + 5 ) . "px;";
			$style2 .= " display: none;";
			$img = "expand.jpg";
		}

		my $id    = $item;
		my $imgid = $item . "_arrow";
		my $a     = $cgi->a(
			{
				-href    => 'javascript:void(null)',
				-onClick => qq{AppTreeManip("$id", "$imgid");},
			},
			$cgi->img(
				{
					-id  => $imgid,
					-src => "$root/stabcons/$img"
				}
			  )

			  #"-+>"
		);

		$a = "" if ( !$y || !length($y) );

		my $addkids = "";
		if ($canadd) {
			$addkids = $cgi->a(
				{
					-href    => "javascript:void(null);",
					-class   => 'approle_addchild',
					-onClick => qq{AddAppChild("$id1");},
				},
				"(add)"
			);
		}

		if ($y) {
			$y = $cgi->div( { -style => $style2, -id => $id }, $y );
		}
		$t .= $cgi->div(
			{
				-style => $style1,
				-class => $class,
				-id    => $id1
			},
			$a, $x, $addkids, $y
		);

		$style1 = $style2 = $class = undef;
	}
	$t;
}

sub do_apps {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $cgi = $stab->cgi || die "Could not create cgi";

	# my $devtypid = $stab->cgi_parse_param('DEVICE_TYPE_ID');

	print $cgi->header('text/html');
	print $stab->start_html(
		{
			-title      => "Application Roles",
			-javascript => 'apps',
		}
	);

	my $cl = {};

	my $sth = $stab->prepare(
		qq{
		select	x.*,
				coalesce(devs.tally, 0) as num_devices,
				coalesce(kids.tally, 0) as num_kids
		  from (
				select kids.* from 
				(
					select *
					  from v_application_role
				)  kids
		  ) x
				-- figure out which have devices assigned already for
				-- purposes of adding
				left join (
					select role_id, count(*) as tally
					  from v_application_role_member 
					group by role_id
				) devs on devs.role_id = x.role_id
				left join (
					select parent_device_collection_id as
								device_collection_id, 
							count(*) as tally
					  from	device_collection_hier
					  group by parent_device_collection_id
				) kids on kids.device_collection_id = x.role_id
		order by x.root_role_id, length(role_path), role_level
	}
	);
	$sth->execute || $stab->return_db_err($sth);

	# setup appgroup styles named after each path, and muck with disable
	# enable to expand and contract?  may require chomping the path up into
	# components to enable/disable all styles, tho.

	# build $tier up into a hierarchy describing all of the elements
	# each element has elements 'keys', which is a list of valid chidren
	# that should be printed out, and 'kids' which is a hash with a set of
	# elements for each element that has sub elements.
	# There is also a hash "hr" that contains all the rows foom this query
	my $tier = {};
	$tier->{kids} = {};
	my $lastroot = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $cur = $tier->{kids};
		my $bo  = $tier;
		my $fullp =
		  $hr->{ _dbx('ROLE_PATH') } . "/" . $hr->{ _dbx('ROLE_NAME') };

	   # in oracle, ROLE_PATH was just /, did not include the curent one.
	   # This may make more sense, but the postgresql version does it so the
	   # path is fully qualified.  Need to rethink.  XXX
		my $splitem = $hr->{ _dbx('ROLE_PATH') };
		my $rn      = $hr->{ _dbx('ROLE_NAME') };
		$splitem =~ s,$rn$,,;
		foreach my $elem ( split( '/', $splitem ) ) {
			next if ( $elem eq '' );
			if ( !exists( $cur->{$elem} ) ) {
				$cur->{$elem} = {};
				$cur->{$elem}->{kids} = {};
			}
			$bo  = $cur->{$elem};
			$cur = $cur->{$elem}->{kids};
		}

		if ( !exists( $bo->{keys} ) ) {
			$bo->{keys} = [];
			$bo->{hr}   = {};
		}
		push( @{ $bo->{keys} }, $hr->{ _dbx('ROLE_NAME') } );

		$bo->{hr}->{ $hr->{ _dbx('ROLE_NAME') } } = $hr;
	}

	# print $cgi->pre(Dumper ( $tier ) );
	# return;

	my (@list);
	my (@hash);

	# recurision is icky, but I'm lazy.  My AP Computer Science Teacher
	# would be uber happy.
	my $x = build_hier( $stab, $tier, 0 );

	print $cgi->div(
		{
			-style => 'text-align: center;',
			-align => 'center',
			-class => 'approle'
		},
		qq{
				Note that those items in green can be
				assigned to devices, and they will automatically be
				assigned everything in the "tree" above them (the elements
				in black).  Device can be (and often are) assigned 
				multiple roles.
			},
		$cgi->div(
			{ -class => 'approle_inside' },
			$cgi->span(
				$cgi->a(
					{
						-href =>
						  "javascript:void(null);",
						-onClick =>
						  'BalanceTree("collapse")'
					},
					"collapse all"
				),
				'//',
				$cgi->a(
					{
						-href =>
						  "javascript:void(null);",
						-onClick =>
						  'BalanceTree("expand")'
					},
					"expand all"
				),
			),
			$cgi->div( { -style => 'text-align: left;' }, $x )
		)
	);

	print $cgi->end_html;

	$x    = undef;
	$tier = undef;
	undef $stab;
	1;
}
