#!/usr/bin/env perl
#
# Copyright (c) 2016-2017 Todd Kover
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
# $Id$
#

use strict;
use warnings;
use FileHandle;
use Carp;
use JazzHands::STAB;
use JazzHands::Common qw(:all);
use Data::Dumper;

# causes stack traces on warnings
# local $SIG{__WARN__} = \&Carp::cluck;

do_device_page();

############################################################################

sub do_device_page {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $cgi   = $stab->cgi           || die "Could not create cgi";
	my $dbh   = $stab->dbh           || die "Could not create dbh";
	my $devid = $cgi->param('devid') || undef;

	my $title    = "";
	my $page     = "";
	my $subtitle = "";
	if ( !defined($devid) ) {
		$title = "Add a new Device";
		$page .= build_page( $stab, undef, "write/add_device.pl" );
	} else {
		$title = "Update Device";

		$subtitle = $cgi->p( { -align => 'center', -style => 'font-size: 8pt' },
			"[ ", $cgi->a( { -href => "device.pl" }, "Add A Device" ), " ]" );

		my $values = $stab->get_dev_from_devid($devid);
		if ( defined($values) ) {
			if ( defined( ( $values->{ _dbx('DEVICE_ID') } ) ) ) {
				my $n = ( $values->{ _dbx('DEVICE_NAME') } );
				if ($n) {

					# ok to remove this
					$n =~ s/\.example\.com\.?$//;
					$title .= " ( $n )";
				}
			}
			$page .= build_page( $stab, $values, "write/update_device.pl" );
		}
		undef $values;

	}
	my $printdevid = ($devid) ? $devid : "null";
	print $cgi->header( { -type => 'text/html' } ), "\n";
	print $stab->start_html(
		{
			-title      => $title,
			-onLoad     => "forcedevtabload(\"__default_tab__\", $printdevid);",
			-javascript => 'device',
		}
	  ),
	  "\n";
	print $subtitle;
	print $page;
	print "\n";
	print $cgi->end_html, "\n";

	undef $page;
	$dbh->rollback;
	$dbh->disconnect;
	undef $subtitle;
	undef $cgi;
	undef $dbh;
	undef $stab;
}

##############################################################################
#
# subroutines start here
#
##############################################################################

sub build_device_checkboxes {
	my ( $stab, $device ) = @_;

	my $cgi = $stab->cgi;

	my $checked = undef;
	$checked = "on" if ( !defined($device) );

	my $checkbox1 =
	  $stab->build_checkbox( $device, "Is monitored", 'IS_MONITORED',
		'DEVICE_ID', $checked )
	  . "\n";
	$checkbox1 .= $stab->build_checkbox( $device, "Is Locally Managed",
		'IS_LOCALLY_MANAGED', 'DEVICE_ID', $checked )
	  . "\n";
	$checkbox1 .= $stab->build_checkbox( $device, "Should Configfetch",
		'SHOULD_FETCH_CONFIG', 'DEVICE_ID', $checked )
	  . "\n";
	$checkbox1 .= $stab->build_checkbox( $device, "Virtual Device",
		'IS_VIRTUAL_DEVICE', 'DEVICE_ID', undef )
	  . "\n";

	#	$checkbox1 .=
	#	  $stab->build_checkbox( $device, "Baselined", 'IS_BASELINED',
	#		'DEVICE_ID', undef )
	#	  . "\n";

	my $rv = $cgi->td($checkbox1);
	undef $checkbox1;
	$rv;
}

sub build_device_box {
	my ( $stab, $values ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $checkboxes = build_device_checkboxes( $stab, $values );
	$checkboxes = "\n" . $cgi->table(
		{ -align => 'center', -class => 'dev_checkboxes' },
		$cgi->Tr( $checkboxes, )    # returns as tds
	) . "\n";

	my $top_table;
	if ( !defined($values) ) {
		$top_table = $stab->build_tr(
			$values, "b_textfield", "Device Name", "DEVICE_NAME",
			'DEVICE_ID'
		);
	} else {
		$top_table = $cgi->hidden(
			-name    => 'DEVICE_ID_' . $values->{ _dbx('DEVICE_ID') },
			-default => $values->{ _dbx('DEVICE_ID') },
		);
		$top_table .=
		  $stab->build_tr( $values, "b_offtextfield", "Device Name",
			"DEVICE_NAME", 'DEVICE_ID' );
	}
	$top_table .= $stab->build_tr(
		$values,          "b_offtextfield",
		"Physical Label", "PHYSICAL_LABEL",
		'DEVICE_ID'
	);
	$top_table .=
	  $stab->build_tr( $values, "b_dropdown", "Site Code", "SITE_CODE",
		'DEVICE_ID' );
	$top_table .= $stab->build_tr( { -dolinkUpdate => 'device_type' },
		$values, "b_dropdown", "Model", "DEVICE_TYPE_ID", 'DEVICE_ID' );

	# only show this on new things to setup components
	if ( !$values ) {
		$top_table .= $stab->build_tr(
			{ -class => 'componenttype' },
			$values, "b_dropdown", "Hardware Type (if applicable)",
			"COMPONENT_TYPE_ID", 'DEVICE_ID'
		);
	}

	if ( !$values || $values->{ _dbx('COMPONENT_ID') } ) {
		my $args = {};
		if ( !$values ) {
			$args->{'-class'} = 'off componentfields';
		}
		$top_table .=
		  $stab->build_tr( $args,
			$values, "b_textfield", "Serial #", "SERIAL_NUMBER", 'DEVICE_ID' );
		$top_table .=
		  $stab->build_tr( $args,
			$values, "b_textfield", "Asset Tag", "ASSET_TAG", 'DEVICE_ID' );
		$top_table .=
		  $stab->build_tr( $args,
			$values, "b_textfield", "Part #", "PART_NUMBER", 'DEVICE_ID' );

		$top_table .=
		  $stab->build_tr( $args, $values, "b_dropdown", "Ownership",
			"OWNERSHIP_STATUS", 'DEVICE_ID' );
		if (
			!$values
			|| ( exists( $values->{ _dbx('OWNERSHIP_STATUS') } )
				&& $values->{ _dbx('OWNERSHIP_STATUS') } eq 'leased' )
		  )
		{
			$top_table .=
			  $stab->build_tr( $args, $values, "b_textfield", "Lease Expires",
				"LEASE_EXPIRATION_DATE", 'DEVICE_ID' );
		}
	}

	#$top_table .= $stab->build_tr($values, "b_textfield",
	#	"Asset #", "ASSET_TAG", 'DEVICE_ID');
	$top_table = $cgi->table($top_table);

	my $osargs       = {};

	my ( $left_table, $right_table ) = ( "", "" );

	$right_table .=
	  $stab->build_tr( $values, "b_dropdown", "Service Environment",
		"SERVICE_ENVIRONMENT_ID", 'DEVICE_ID' );

	if ($values) {
		$left_table .= $cgi->Tr(
			$cgi->td( { -align => 'right' }, $cgi->b("Parent Device") ),
			$cgi->td(
				build_parent_device_box(
					$stab,
					$values->{ _dbx('PARENT_DEVICE_ID') },
					$values->{ _dbx('DEVICE_ID') },
					$values->{ _dbx('IS_VIRTUAL_DEVICE') },
				)
			)
		);

		if ( $values->{ _dbx('IS_VIRTUAL_DEVICE') } eq 'N' ) {
			$left_table .= $cgi->Tr(
				$cgi->td( { -align => 'right' }, $cgi->b("Children Devices") ),
				$cgi->td(
					build_children_device_list(
						$stab, $values->{ _dbx('DEVICE_ID') },
					)
				)
			);
			$left_table .= $cgi->Tr(
				$cgi->td(
					{ -align => 'right' },
					$cgi->b("Managed By")
				),
				$cgi->td(
					build_managed_by_device_list(
						$stab,
						$values->{ _dbx('DEVICE_ID') },
					)
				)
			);

			$left_table .= $cgi->Tr(
				$cgi->td(
					{ -align => 'right' },
					$cgi->b("Manages")
				),
				$cgi->td(
					build_manages_device_list(
						$stab,
						$values->{ _dbx('DEVICE_ID') },
					       $stab, $values->{ _dbx('DEVICE_ID') },
					)
				)
			);
		}
	}

	if ( defined($values) ) {
		if ( $values->{ _dbx('HOST_ID') } ) {
			$right_table .=
			  $cgi->Tr( $cgi->td( { -align => 'right' }, $cgi->b("Host ID") ),
				$cgi->td( $values->{ _dbx('HOST_ID') } ) );
		} else {
			$right_table .=
			  $cgi->Tr( $cgi->td( { -align => 'right' }, $cgi->b("Host ID") ),
				$cgi->td('not set') );
		}

		my $cnt =
		  $stab->get_snmpstr_count( $values->{ _dbx('DEVICE_ID') } );
		$right_table .= $cgi->Tr(
			$cgi->td(
				{ -colspan => 2 },
				$cgi->a(
					{
						-href => "snmp/?DEVICE_ID="
						  . $values->{ _dbx('DEVICE_ID') }
					},
					"$cnt SNMP string" . ( ( $cnt == 1 ) ? '' : "s" )
				)
			)
		);
	} else {
		$right_table .=
		  $stab->build_tr( $values, "b_textfield", "SNMP Rd", "SNMP_COMMSTR" );
	}

	$left_table  = $cgi->table($left_table);
	$right_table = $cgi->table($right_table);

	my $rv = $cgi->table(
		$cgi->Tr( $cgi->td( [ $top_table,  $checkboxes ] ) ),
		$cgi->Tr( $cgi->td( [ $left_table, $right_table ] ) )
	);

	undef $left_table;
	undef $right_table;
	undef $top_table;
	$rv;
}

sub build_page {
	my ( $stab, $device, $devurl ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $devinfo = build_device_box( $stab, $device );

	my $pnk = "";
	if ( defined($device) ) {
		$pnk = "_" . $device->{ _dbx('DEVICE_ID') };
	}

	my $bottomTr = "";
	if ( !defined($device) ) {

		#my $approleboxes = $cgi->div({-class => 'approle'},
		#	$stab->device_appgroup_tab());
		my $approleboxes = "";
		$bottomTr =
		  $cgi->Tr( { -align => 'center;' }, $cgi->td($approleboxes) ),
		  undef $approleboxes;
	}

	my $maindiv = $cgi->table( { -border => 1, width => '100%' },
		$cgi->Tr( $cgi->td($devinfo), ), $bottomTr, );

	undef $bottomTr;

	if ( defined($device) ) {
		my $devid = $device->{ _dbx('DEVICE_ID') };

		my $opentabid = "__default_tab__";
		my $otabval   = $stab->cgi_parse_param('default_tab');

		my $numnotes = $stab->get_num_dev_notes($devid);
		if ( $numnotes == 0 ) {
			$numnotes = "";
		} else {
			$numnotes = " ($numnotes)";
		}

		#
		# comment things out here and the tabs just won't show up at all.
		# This maps the inside name (used by the javascript and ajax
		# scripts) to what its presented as in the tabs, as well as defines
		# which tabes are valid.  This is used in dev so tabs can get built
		# out but not made visible.  Note that someone clever could bring
		# up the tabs using web queries in this case, tho.
		#

		my $tablist = {
			"PatchPanel" => "Patch Panel",
			"IP"         => "IP Network",

			#	"IPRoute" => "IP Routing",
			#	"Circuit" => "Voice",
			"Serial" => "Serial",

			#"AppGroup"     => "AppGroup",
			"Power"      => "Power",
			"Switchport" => "Switch Port",

			#	"AppGroup" => "AppGroup",
			"Location" => "Location",

			#"Licenses"     => "Licenses",
			"Advanced" => "Advanced",
			"Notes"    => "Notes$numnotes",
		};

		if ( !$stab->get_power_port_count($devid) ) {
			delete( $tablist->{Power} );
		}

		if ( !$stab->get_physical_port_count( $devid, 'network' ) ) {
			delete( $tablist->{Switchport} );
		}

		if ( !$stab->get_physical_port_count( $devid, 'serial' ) ) {
			delete( $tablist->{Serial} );
		}
		if ( !$stab->get_physical_port_count( $devid, 'patchpanel' ) ) {
			delete( $tablist->{PatchPanel} );
		}

		if ( $device->{ _dbx('IS_VIRTUAL_DEVICE') } eq 'Y' ) {
			delete( $tablist->{Location} );
		}

		my (@tablist);
		push( @tablist, "Notes", "DevFunctions", "AppGroup" );

		# XXX - used to run check_func, needs to move to application
		# roles!
		# } elsif ( !$stab->check_func( $devid, 'cablemanagement' ) ) {
		if ( exists( $tablist->{PatchPanel} ) ) {
			push( @tablist, "PatchPanel" );
		} else {
			push( @tablist, qw{IP IPRoute Circuit Serial Power Switchport } );
		}

		push( @tablist, qw{Location Licenses Advanced} );

		my $intertab = "";
		foreach my $tab (@tablist) {
			if ( exists( $tablist->{$tab} ) ) {
				my $tabp = $tablist->{$tab};
				$intertab .= $cgi->a(
					{
						-class   => 'tabgrouptab',
						-id      => $tab,
						-href    => 'javascript:void(null);',
						-onClick => "ShowDevTab('$tab', $devid);"
					},
					$tabp
				) . "\n\n";
			}
		}

		$maindiv .= "\n\n"
		  . $cgi->div(
			$cgi->div( { -class => 'tabgroup_pending' } ),
			$cgi->hidden(
				-name    => $opentabid,
				-id      => $opentabid,
				-default => $otabval
			),
			$intertab,
			$cgi->div(
				{ -id => 'tabthis' },
				$cgi->div(
					{ -align => 'center' },
					$cgi->em("please select a tab.")
				)
			)
		  ) . "\n\n";
	}

	$maindiv .= $cgi->div(
		{ -width => '100%', -style => 'text-align: center;' },
		$cgi->submit(
			{
				-id     => 'submitdevice',
				-valign => 'bottom',
				-name   => 'update' . $pnk,
				-label  => 'Submit Device Changes'
			}
		)
	);

	my $page .= $cgi->start_form(
		{
			-id       => 'deviceForm',
			-onSubmit => "return(verify_device_submission(this));",
			-action   => $devurl
		}
	);
	$page .=
	  $cgi->div( { -id => 'verifybox', -style => 'visibility: hidden' }, "" );
	$page .= $cgi->div( { -class => 'maindiv' }, $maindiv );
	$page .= $cgi->end_form();

	undef $maindiv;
	undef $devinfo;
	$page;
}

sub build_children_device_list {
	my ( $stab, $devid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $q = qq{
		select	device_id, device_name
		  from	device
		 where	parent_device_id = ?
	} || $stab->return_db_err();

	my $sth = $stab->prepare($q) || $stab->return_db_err();
	$sth->execute($devid) || $stab->return_db_err();

	my $list = "";
	while ( my ( $id, $name ) = $sth->fetchrow_array ) {
		$list .= $cgi->li(
			$cgi->a(
				{
					-target => "stab_device_$id",
					-href   => "./device.pl?devid=$id",
				},
				$name
			)
		);
	}
	$sth->finish;

	if ( length($list) ) {
		$cgi->ul($list);
	} else {
		"none";
	}
}
sub build_manages_device_list {
	my ( $stab, $devid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $q = qq{
		select  dmc.device_id, device_name
		  from  device d JOIN
				device_management_controller dmc ON
					(d.device_id = dmc.device_id)
		 where  manager_device_id = ?
	} || $stab->return_db_err();

	my $sth = $stab->prepare($q) || $stab->return_db_err();
	$sth->execute($devid) || $stab->return_db_err();

	my $list = "";
	while ( my ( $id, $name ) = $sth->fetchrow_array ) {
		$list .= $cgi->li(
			$cgi->a(
				{
					-target => "stab_device_$id",
					-href   => "./device.pl?devid=$id",
				},
				$name
			)
		);
	}
	$sth->finish;

	if ( length($list) ) {
		$cgi->ul($list);
	} else {
		"";
	}
}

sub build_managed_by_device_list {
	my ( $stab, $devid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $q = qq{
		select  dmc.manager_device_id, device_name
		  from  device d JOIN
				device_management_controller dmc ON
					(d.device_id = dmc.manager_device_id)
		 where  dmc.device_id = ?
	} || $stab->return_db_err();

	my $sth = $stab->prepare($q) || $stab->return_db_err();
	$sth->execute($devid) || $stab->return_db_err();

	my $list = "";
	while ( my ( $id, $name ) = $sth->fetchrow_array ) {
		$list .= $cgi->li(
			$cgi->a(
				{
					-target => "stab_device_$id",
					-href   => "./device.pl?devid=$id",
				},
				$name
			)
		);
	}
	$sth->finish;

	if ( length($list) ) {
		$cgi->ul($list);
	} else {
		"";
	}
}

sub build_parent_device_box {
	my ( $stab, $parid, $devid, $isvirt ) = @_;

	my $cgi = $stab->cgi;

	my ( $dev, $pname, $pdevid );
	if ($parid) {
		$dev = $stab->get_dev_from_devid($parid);
		if ($dev) {
			$pdevid = $dev->{ _dbx('DEVICE_ID') };
			$pname  = $dev->{ _dbx('DEVICE_NAME') };
			if ($pname) {
				$pname =~ s/.example.com$//;
			} else {
				$pname = "--unnamed--";
			}
		}
	}

	my $devlink = "javascript:void(null);";
	if ($pdevid) {
		$devlink = "./device.pl?devid=$pdevid";
	}

	my $pdid  = "PARENT_DEVICE_ID_" . $devid;
	my $pdnam = "PARENT_DEVICE_NAME_" . $devid;

	my $style    = "";
	my $rv       = "";
	my $linktext = ">>";
	if ( $isvirt eq 'N' ) {
		$style = 'font-size: 30%;',
		  $rv  = $cgi->hidden(
			{
				-name    => $pdid,
				-id      => $pdid,
				-default => $pdevid
			}
		  )
		  . $cgi->textfield(
			{
				-name => $pdnam,
				-id   => $pdnam,
				-size => 50,
				-onInput =>
				  "inputEvent_Search(this, $pdid, event, \"deviceForm\", function(){updateDeviceParentLink($devid, $pdid);})",
				-onKeydown =>
				  "keyprocess_Search(this, $pdid, event, \"deviceForm\", function(){updateDeviceParentLink($devid, $pdid);})",
				-onBlur   => "hidePopup_Search($pdnam)",
				-onChange => "updateDeviceParentLink($devid, $pdid
)",
				-default => $pname,
			}
		  );
	} else {
		$linktext = $pname;
	}

	$rv .= $cgi->a(
		{
			-style  => $style,
			-target => "stab_device_$devid",
			id      => "parent_link_$devid",
			-href   => $devlink
		},
		$linktext
	);
	$rv;
}
