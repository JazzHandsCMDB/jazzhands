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
# Copyright (c) 2010-2017 Todd M. Kover
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

# $Id$
#
# most of the code for implementing the device tabs are here.
#
# Much of the JazzHands generic routines (even device-specific) can be found in
# JazzHandsAccess.pm.
#

#
# NOTE:  The entire port display/dropdown/etc needs to totally be overhauled
# to not have the P1_ / P2_ stuff.
#

package JazzHands::STAB::Device;

use 5.008007;
use strict;
use warnings;

use JazzHands::DBI;
use JazzHands::Common::Util qw(_dbx);
use Data::Dumper;
use URI;

our @ISA = qw( );

our $VERSION = '1.0.0';

##############################################################################
#
# Device Notes
#
##############################################################################
sub device_notes_print {
	my ( $self, $devid ) = @_;

	my $dbh = $self->dbh;
	my $cgi = $self->cgi;

	$self->error_return("No device specified") if ( !defined($devid) );

	my $q = qq{
		select	note_id, lower(note_user), note_date, note_text
		  from	device_note
		 where	device_id = ?
		order by note_date desc
	};
	my $sth = $dbh->prepare($q) || die $self->return_db_err($dbh);
	$sth->execute($devid) || $self->return_db_err($sth);

	my $contents = "";
	while ( my ( $id, $user, $date, $text ) = $sth->fetchrow_array ) {
		$contents .= $cgi->Tr(
			{ -width => '100%' },
			$cgi->td( { -width => '85%' }, $cgi->escapeHTML($text) ),
			$cgi->td( { -width => '15%' }, $cgi->br($user), $cgi->br($date) )
		);
	}
	$sth->finish;

	$contents .= $cgi->Tr(
		$cgi->td(
			{ -colspan => 2, -style => 'text-align: center;' },
			$cgi->h4( { -style => 'text-align: center' }, 'Add a note' ),
			$cgi->textarea(
				{
					-name    => "DEVICE_NOTE_TEXT_$devid",
					-rows    => 10,
					-columns => 80
				}
			)
		)
	);

	if ( !length($contents) ) {
		return $cgi->div( { -style => 'text-align: center; padding: 50px' },
			$cgi->em("no notes.") );
	} else {
		return $cgi->table( { -width => '100%', -border => 1 }, $contents );
	}
}

##############################################################################
#
# Circuit
#
##############################################################################
sub device_circuit_tab {
	my ( $self, $devid, $parent ) = @_;

	my $cgi = $self->cgi;

	#
	# [XXX] want to switch to named bind variables, methinks.
	#
	my $limit = "p.device_id = ?  and	ni.PARENT_NETWORK_INTERFACE_ID is NULL";
	if ($parent) {
		$limit = "ni.PARENT_NETWORK_INTERFACE_ID = ?";
	}

	# XXX ORACLE/PGSQL issue
	my $q = qq{
		select	ni.network_interface_id,
			ni.network_interface_name,
			p.physical_port_id,
			p.port_name,
			p.port_type,
			comp.company_name,
			c.circuit_id,
			c.vendor_circuit_id_str,
			ni.network_interface_type,
			tg.trunk_group_id,
			tg.trunk_group_name,
			c.trunk_tcic_start,
			c.trunk_tcic_end
		  from	physical_port p
			left join network_interface ni on
				ni.physical_port_id = p.physical_port_id
			left join layer1_connection l1c on
				(p.physical_port_id = l1c.physical_port1_id OR
				 p.physical_port_id = l1c.physical_port2_id)
			left join circuit c on
				c.circuit_id = l1c.circuit_id
			left join company comp on
				comp.company_id = c.VENDOR_COMPANY_ID
			left join trunk_group tg
				on tg.trunk_group_id = c.trunk_group_id
		 where	 $limit
	     -- order by NETWORK_STRINGS.NUMERIC_INTERFACE(ni.network_interface_name)
	};
	my $sth = $self->prepare($q) || $self->return_db_err;

	if ($parent) {
		$sth->execute($parent) || $self->return_db_err;
	} else {
		$sth->execute($devid) || $self->return_db_err;
	}

	my $root = $self->guess_stab_root;

	my $tt = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $id = "circit_ni" . $hr->{ _dbx('NETWORK_INTERFACE_ID') };

		my $nitype = $hr->{ _dbx('NETWORK_INTERFACE_TYPE') };
		$nitype =~ tr/A-Z/a-z/;

		my $Xsth = $self->prepare(
			"select count(*) from network_interface where parent_network_interface_id = ?"
		);
		$Xsth->execute( $hr->{ _dbx('NETWORK_INTERFACE_ID') } )
		  || $self->return_db_err($Xsth);
		my ($kidtally) = $Xsth->fetchrow_array;
		$Xsth->finish;

		my $iname;
		if ($kidtally) {
			$iname = $cgi->a(
				{
					-href => 'javascript:void(null)',
					-onClick =>
					  "showCircuitKids(this, \"$id\", \"${id}_tr\", $hr->{_dbx('NETWORK_INTERFACE_ID')})",
				},
				$cgi->img(
					{
						-id  => "cirExpand_$id",
						-src => "$root/stabcons/expand.jpg"
					}
				),
				$hr->{ _dbx('NETWORK_INTERFACE_NAME') }
			);
		} else {
			$iname = $hr->{ _dbx('NETWORK_INTERFACE_NAME') };
		}
		my $circstr = "";
		if ( $hr->{ _dbx('CIRCUIT_ID') } ) {
			my $name = $hr->{ _dbx('VENDOR_CIRCUIT_ID_STR') } || 'unnamed';
			$circstr = $cgi->a(
				{
					-href => "$root/circuit/?CIRCUIT_ID="
					  . $hr->{ _dbx('CIRCUIT_ID') }
				},
				$name
			);
		}

		my $trunk = "";
		my $cic   = "";
		if ( $hr->{ _dbx('TRUNK_GROUP_NAME') } ) {
			$trunk = $cgi->a(
				{
					-href => "$root/circuit/trunkgroup/?TRUNK_GROUP_ID="
					  . $hr->{ _dbx('TRUNK_GROUP_ID') }
				},
				$hr->{ _dbx('TRUNK_GROUP_NAME') }
			);
			if ( $hr->{ _dbx('TRUNK_TCIC_START') } ) {
				$cic =
					$hr->{ _dbx('TRUNK_TCIC_START') } . "-"
				  . $hr->{ _dbx('TRUNK_TCIC_END') };
			}
		}

		$tt .= $cgi->Tr(
			{
				-class => "circuit_$nitype",
				-id    => "${id}_tr"
			},
			$cgi->td(
				[
					$iname,   $hr->{ _dbx('COMPANY_NAME') },
					$circstr, $hr->{ _dbx('NETWORK_INTERFACE_TYPE') },
					$trunk,   $cic,
				]
			)
		);
	}

	$cgi->table(
		{ -align => 'center', -border => 1 },
		$cgi->th(
			[ "Name", "Company", "Circuit ID", "Type", "Trunk", "CIC Range" ]
		),
		$tt
	);
}

##############################################################################
#
# Switch Portage
#
##############################################################################
sub device_switch_port {
	my ( $self, $devid, $parent ) = @_;

	my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	#
	# if we have > 55 ports, then need to break down by card.
	#
	if (  !$parent
		&& $self->get_physical_port_tally( $devid, 'network', '/' ) > 55 )
	{
		my $root = $self->guess_stab_root;

		# XXX ORACLE/PGSQL
		my $sth = $self->prepare(
			q{
			select  distinct regexp_replace(port_name, '/.*$', '') as port_name
			 from   physical_port
			 where   device_id = ?
			   and   port_type = ?
	     -- order by NETWORK_STRINGS.NUMERIC_INTERFACE(port_name)
		}
		);

		# TODO - Stab is not allowed to access NETWORK_STRINGS.NUMERIC_INTERFACE
		$sth->execute( $devid, 'network' )
		  || $self->return_db_err($sth);

		my $x = "";
		while ( my $hr = $sth->fetchrow_hashref ) {
			$x .= $self->build_switch_droppable_tr( $devid, $hr );
		}
		if ( length($x) ) {
			$cgi->table(
				{
					-align  => 'center',
					-border => 0,
					-style  => 'width: 90%; border: 1px solid;'
				},
				$cgi->caption('Card'),
				$cgi->th( [ 'Port', '' ] ),
				$x
			);
		} else {
			"";
		}

	} else {
		my $q   = build_physical_port_query( 'network', $parent );
		my $sth = $dbh->prepare($q) || $self->return_db_err($dbh);
		if ($parent) {
			$sth->execute( $devid, 'network', "^$parent/" )
			  || $self->return_db_err($sth);
		} else {
			$sth->execute( $devid, 'network' )
			  || $self->return_db_err($sth);
		}

		my $x = "";
		while ( my $hr = $sth->fetchrow_hashref ) {
			$x .= $self->build_switch_drop_tr( $devid, $hr );
		}
		$sth->finish;

		if ( length($x) ) {
			my $t = $cgi->table(
				{
					-align  => 'center',
					-border => 0,
					-style  => 'border: 1px solid;'
				},
				$cgi->h3(
					{ -style => 'text-align: center' },
					'Switchport Connections'
				),
				$cgi->th( [ 'Port/Label', 'Other End', 'Port' ] ),
				$x
			) . '<br/>';
		} else {
			"";
		}
	}
}

#
# consider combining into build_switch_drop_tr
#
sub build_switch_droppable_tr {
	my ( $self, $devid, $hr ) = @_;
	my $cgi = $self->cgi || die "Could not create cgi";

	my $root  = $self->guess_stab_root;
	my $id    = "pport_agg_" . $hr->{ _dbx('PORT_NAME') };
	my $iname = $cgi->a(
		{
			-href => 'javascript:void(null)',
			-onClick =>
			  "showPhysPortKid_Groups($devid, \"$id\", \"${id}_tr\", \"$hr->{_dbx('PORT_NAME')}\")",
		},
		$cgi->img(
			{
				-id  => "kidXpand_$id",
				-src => "$root/stabcons/expand.jpg"
			}
		),
		$hr->{ _dbx('PORT_NAME') }
	);

	$cgi->Tr(
		{
			-class => "physport_agg",
			-id    => "${id}_tr"
		},
		$cgi->td($iname)
	);
}

sub build_switch_drop_tr {
	my ( $self, $devid, $hr ) = @_;

	my $cgi = $self->cgi || die "Could not create cgi";

	my $pportid   = $hr->{ _dbx('P1_PHYSICAL_PORT_ID') };
	my $divwrapid = "div_p2_physical_port_id_$pportid";

	my $htmlid = "P1_PHYSICAL_PORT_ID_$pportid";

	my $pname = $hr->{ _dbx('P1_PORT_NAME') };
	if ( $hr->{ _dbx('P1_PHYSICAL_LABEL') } ) {
		$pname .= "/"
		  . $cgi->span( { -class => 'port_label' },
			$hr->{ _dbx('P1_PHYSICAL_LABEL') } );
	}

	$cgi->Tr(
		$cgi->td(
			$cgi->b(
				$cgi->hidden(
					-name  => $htmlid,
					-id    => $htmlid,
					-value => $pportid
				),
				$pname,
			)
		),
		$cgi->td(
			$self->physicalport_otherend_device_magic(
				{ -deviceID => $devid, -pportKey => $pportid }, $hr,
				'network', $divwrapid
			)
		),
		$cgi->td(
			$self->b_dropdown(
				{
					-class    => 'tracked',
					-original => defined( $hr->{'p2_physical_port_id'} )
					? $hr->{ _dbx('p2_physical_port_id') }
					: '__unknown__',
					-portLimit => 'network',
					-divWrap   => $divwrapid,
					-deviceid  => $hr->{ _dbx('P2_DEVICE_ID') }
				},
				$hr,
				'P2_PHYSICAL_PORT_ID',
				'P1_PHYSICAL_PORT_ID'
			)
		),
	);
}

##############################################################################
#
# Power Portage
#
##############################################################################
sub device_power_ports {
	my ( $self, $devid ) = @_;

	my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	# ORACLE/PGSQL
	my $q = qq{
		select * from (
			select
				c.DEVICE_POWER_CONNECTION_ID,
				c.device_id as p1_power_device_id,
				c.power_interface_port as p1_power_interface_port,
				c.rpc_device_id as p2_power_device_id,
				c.rpc_power_interface_port as p2_power_interface_port,
				d2.device_name as p2_power_device_name
			  from	device_power_connection c
					inner join device_power_interface i
						on i.device_id = c.device_id
							and i.power_interface_port = c.power_interface_port
					inner join device d2
						on d2.device_id = c.rpc_device_id
			 where	i.device_id = :devid
		UNION
			select
				c.DEVICE_POWER_CONNECTION_ID,
				c.rpc_device_id as p1_power_device_id,
				c.rpc_power_interface_port as p1_power_interface_port,
				c.device_id as p2_power_device_id,
				c.power_interface_port as p2_power_interface_port,
				d2.device_name as p2_power_device_name
			  from	device_power_connection c
					inner join device_power_interface i
						on i.device_id = c.rpc_device_id
							and i.power_interface_port
								= c.rpc_power_interface_port
					inner join device d2
						on d2.device_id = c.device_id
			 where	i.device_id = :devid
		UNION
			select
				c.DEVICE_POWER_CONNECTION_ID,
				i.device_id as p1_power_device_id,
				i.power_interface_port as p1_power_interface_port,
				c.rpc_device_id as p2_power_device_id,
				c.rpc_power_interface_port as p2_power_interface_port,
				NULL
			  from	device_power_interface i
					left join device_power_connection c
						on (i.device_id = c.rpc_device_id
							and i.power_interface_port
								= c.rpc_power_interface_port)
						OR (i.device_id = c.device_id
							and i.power_interface_port
								= c.power_interface_port)
				where
					c.DEVICE_POWER_CONNECTION_ID is NULL
			 	and	i.device_id = :devid
		) xx
		order by p1_power_interface_port

	};

	# -- order by NETWORK_STRINGS.NUMERIC_INTERFACE(p1_power_interface_port)
	my $sth = $self->prepare($q) || $self->return_db_err($self);

	$sth->bind_param( ':devid', $devid ) || $self->return_db_err($self);
	$sth->execute || $self->return_db_err($self);

	my $x = "";
	while ( my $hr = $sth->fetchrow_hashref ) {

		my $powerid   = $hr->{ _dbx('P1_POWER_INTERFACE_PORT') };
		my $divwrapid = "div_p2_power_port_id_$powerid";
		my $htmlid    = "P1_POWER_INTERFACE_PORT_$powerid";

		$x .= $cgi->Tr(
			$cgi->td(
				$cgi->b(
					$cgi->hidden(
						-name  => $htmlid,
						-id    => $htmlid,
						-value => $powerid
					),
					$hr->{ _dbx('P1_POWER_INTERFACE_PORT') }
				)
			),
			$cgi->td( $self->powerport_device_magic( $hr, $divwrapid ) ),
			$cgi->td(
				$self->b_dropdown(
					{
						-divWrap  => $divwrapid,
						-deviceid => $hr->{ _dbx('P2_POWER_DEVICE_ID') }
					},
					$hr,
					'P2_POWER_INTERFACE_PORT',
					'P1_POWER_INTERFACE_PORT'
				)
			)
		);
	}
	$sth->finish;

	if ( length($x) ) {
		$cgi->table(
			{ -align => 'center' },
			$cgi->caption('Power Connections'),
			$cgi->th( [ 'Local Port', 'Other End', 'Port' ] ), $x
		);
	} else {
		print $cgi->div(
			{ -style => 'text-align: center; padding: 50px', },
			$cgi->em("This device type does not have a power configuration")
		);
	}
}

sub powerport_device_magic {
	my ( $self, $hr, $portdivwrapid ) = @_;

	my $cgi = $self->cgi;

	my $id        = $hr->{ _dbx('P1_POWER_INTERFACE_PORT') };
	my $devlinkid = "power_devlink_$id";
	my $args;

	my $devdrop = "P2_POWER_DEVICE_ID_$id";
	my $devname = "P2_POWER_DEVICE_NAME_$id";
	my $pdevid  = $hr->{ _dbx('P2_POWER_DEVICE_ID') };
	my $pname   = $hr->{ _dbx('P2_POWER_DEVICE_NAME') };

	my $pdnam = "P2_POWER_DEVICE_NAME_" . $id;
	my $dostuffjavascript =
	  "showPowerPorts(\"$devdrop\", \"$devname\", \"$portdivwrapid\", \"$id\", \"$devlinkid\");";
	my $rv = $cgi->hidden(
		{
			-name    => $devdrop,
			-id      => $devdrop,
			-default => $pdevid
		}
	);

	$rv .= $cgi->textfield(
		{
			-name => $pdnam,
			-id   => $pdnam,
			-size => 40,
			-onInput =>
			  "inputEvent_Search(this, $devdrop, event, \"deviceForm\", function(){$dostuffjavascript});",
			-onKeydown =>
			  "keyprocess_Search(this, $devdrop, event, \"deviceForm\", function(){$dostuffjavascript});",
			-onChange => "$dostuffjavascript",
			-onBlur   => "hidePopup_Search($pdnam)",
			-default  => $pname,
		}
	);

	my $devlink = "javascript:void(null);";
	if ($pdevid) {
		$devlink = "./device.pl?devid=$pdevid;__default_tab__=Power";
	}

	$rv .= $cgi->a(
		{
			-style  => 'font-size: 30%;',
			-target => "stab_device_$pdevid",
			id      => $devlinkid,
			-href   => $devlink
		},
		">>"
	);
	$rv;
}

##############################################################################
#
# Serial Portage
#
##############################################################################
sub device_serial_ports {
	my ( $self, $devid ) = @_;

	my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	my $q   = build_physical_port_query('serial');
	my $sth = $dbh->prepare($q) || $self->return_db_err($dbh);
	$sth->execute( $devid, 'serial' ) || $self->return_db_err($sth);

	my $x = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		if (   defined( $hr->{ _dbx('DATA_BITS') } )
			&& defined( $hr->{ _dbx('STOP_BITS') } )
			&& defined( $hr->{ _dbx('PARITY') } ) )
		{
			my $p = substr( $hr->{ _dbx('PARITY') }, 0, 1 );
			$p =~ tr/a-z/A-Z/;
			$hr->{ _dbx('SERIAL_PARAMS') } =
			  $hr->{ _dbx('DATA_BITS') } . "-$p-" . $hr->{ _dbx('STOP_BITS') };
		}
		$x .= $self->build_serial_drop_tr( $devid, $hr );
	}
	$sth->finish;

	if ( length($x) ) {
		$cgi->table(
			{ -align => 'center' },
			$cgi->caption('Serial Connections'),
			$cgi->th(
				[
					'Local Port/Label', 'Other End',
					'Port',             'Baud',
					'Params',           'Flow Control'
				]
			),
			$x
		);
	} else {
		"";
	}
}

sub build_serial_drop_tr {
	my ( $self, $devid, $hr ) = @_;

	my $cgi = $self->cgi || die "Could not create cgi";

	my $pportid   = $hr->{ _dbx('P1_PHYSICAL_PORT_ID') };
	my $divwrapid = "div_p2_physical_port_id_$pportid";

	my $htmlid = "P1_PHYSICAL_PORT_ID_$pportid";

	my $pname = $hr->{ _dbx('P1_PORT_NAME') };
	if ( $hr->{ _dbx('P1_PHYSICAL_LABEL') } ) {
		$pname .= "/"
		  . $cgi->span( { -class => 'port_label' },
			$hr->{ _dbx('P1_PHYSICAL_LABEL') } );
	}

	$cgi->Tr(
		$cgi->td(
			$cgi->b(
				$cgi->hidden(
					-name  => $htmlid,
					-id    => $htmlid,
					-value => $pportid
				),
				$pname,
			)
		),
		$cgi->td(
			$self->physicalport_otherend_device_magic(
				{ -deviceID => $devid, -pportKey => $pportid }, $hr,
				'serial', $divwrapid
			)
		),
		$cgi->td(
			$self->b_dropdown(
				{
					-portLimit => 'serial',
					-divWrap   => $divwrapid,
					-deviceid  => $hr->{ _dbx('P2_DEVICE_ID') }
				},
				$hr,
				'P2_PHYSICAL_PORT_ID',
				'P1_PHYSICAL_PORT_ID'
			)
		),
		$cgi->td(
			$self->b_nondbdropdown( $hr, 'BAUD', 'P1_PHYSICAL_PORT_ID' )
		),
		$cgi->td(
			$self->b_nondbdropdown(
				$hr, 'SERIAL_PARAMS', 'P1_PHYSICAL_PORT_ID'
			)
		),
		$cgi->td(
			$self->b_nondbdropdown(
				$hr, 'FLOW_CONTROL', 'P1_PHYSICAL_PORT_ID'
			)
		),
	);
}

##############################################################################
#
# Physical Connections / Patch Panel
#
##############################################################################
sub device_physical_connection {
	my ( $self, $devid, $pportkey, $row, $refside ) = @_;

	$refside = 2 if ( !defined($refside) );

	my $cgi = $self->cgi || die "Could not create cgi";

	my $l1c = $self->get_layer1_connection_from_port($pportkey);
	my $path =
	  $self->get_physical_path_from_l1conn(
		$l1c->{ _dbx('LAYER1_CONNECTION_ID') } );

	if ( !$devid ) {
		my $pp = $self->get_physical_port($pportkey);
		$devid = $pp->{ _dbx('DEVICE_ID') };
	}

	my $tableid = "table_pc_ppkey_" . $pportkey;

	my $backwards = 0;

	#
	# this happens when there's no physical path.  As such,
	#
	if ( ( !$path || ( !scalar @$path ) ) ) {
		my $startp =
		  $self->get_physical_port( $l1c->{ _dbx('PHYSICAL_PORT1_ID') } );
		my $endp =
		  $self->get_physical_port( $l1c->{ _dbx('PHYSICAL_PORT2_ID') } );

		if ( $startp->{ _dbx('PHYSICAL_PORT_ID') } != $pportkey ) {
			$backwards = 1;
		}

		my $connpk = "PC_path_" . $startp->{ _dbx('PHYSICAL_PORT_ID') };
		if ( !defined($row) ) {
			if ( $startp->{ _dbx('PHYSICAL_PORT_ID') } != $pportkey ) {
				my $x = $endp;
				$endp   = $startp;
				$startp = $x;
			}
			return (
				$cgi->table(
					{ -border => 1, -id => $tableid },
					$self->physical_connection_row(
						{
							-deviceID  => $devid,
							-pportKey  => $pportkey,
							-choosable => 0,
							-showAdd   => 1,
							-tableId   => $tableid,
							-backwards => $backwards,
						},
						0, undef, $startp
					  )
					  . $self->physical_connection_row(
						{
							-deviceID  => $devid,
							-pportKey  => $pportkey,
							-choosable => 0,
							-showAdd   => 0,
							-showCable => 1,
							-tableId   => $tableid,
							-backwards => $backwards,
						},
						1, undef, $endp
					  )
				)
			);
		} else {
			my $x = $self->physical_connection_row(
				{
					-deviceID  => $devid,
					-noTr      => 1,
					-pportKey  => $pportkey,
					-choosable => 1,
					-showAdd   => 1,
					-showCable => 1,
					-tableId   => $tableid,
					-backwards => $backwards,
				},
				$row, $refside, undef
			);
		}
	} else {
		my $connpk =
		  "PC_path_" . $path->[0]->{ _dbx('PC_P1_PHYSICAL_PORT_ID') };

		if (   $path
			&& $path->[0]->{ _dbx('PC_P1_DEVICE_ID') } != $devid )
		{
			$backwards = 1;
		}

		if ( !defined($row) ) {
			my $tt = "";

			my $count = $#{$path};
			my $side  = 1;
			if ($backwards) {
				$side = 2;
			}

			if ( scalar @$path ) {
				my $x = ($backwards) ? $count : 0;
				$tt = $self->physical_connection_row(
					{
						-deviceID  => $devid,
						-pportKey  => $pportkey,
						-choosable => 0,
						-showAdd   => 1,
						-tableId   => $tableid,
						-backwards => $backwards,
					},
					0, $side,
					$path->[ ($backwards) ? $count : 0 ]
				);
			}

			for ( my $iter = 0 ; $iter <= $count ; $iter++ ) {
				my $i = $iter;
				if ($backwards) {
					$i = $count - $iter;
				}
				my $hr = $path->[$i];

				$side = 2;
				if ($backwards) {
					$side = 1;
				}

				$tt .= $self->physical_connection_row(
					{
						-deviceID  => $devid,
						-pportKey  => $pportkey,
						-choosable => ( $iter != $count ),
						-showAdd   => ( $iter != $count ),
						-showCable => 1,
						-tableId   => $tableid,
						-backwards => $backwards,
					},
					$iter + 1,
					$side, $hr
				);
			}
			$cgi->table( { -id => $tableid, -border => 1 }, $tt );
		} else {
			my $hr = undef;
			$self->physical_connection_row(
				{
					-deviceID  => $devid,
					-noTr      => 1,
					-pportKey  => $pportkey,
					-choosable => 1,
					-showAdd   => 1,
					-showCable => 1,
					-tableId   => $tableid,
					-backwards => $backwards,
				},
				$row, $refside, $hr
			);

		}
	}

	# return value falls through
}

sub device_patch_ports {
	my ( $self, $devid ) = @_;

	my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	my $q   = build_physical_port_conn_query('patchpanel');
	my $sth = $dbh->prepare($q) || $self->return_db_err($dbh);
	$sth->execute( $devid, 'patchpanel' ) || $self->return_db_err($sth);

	my $x = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		$x .= $self->build_patchpanel_drop_tr( $devid, $hr );
	}
	$sth->finish;

	if ( length($x) ) {
		$cgi->table(
			{ -align => 'center', -border => 1 },
			$cgi->caption('Patch Panel Connections'),
			$cgi->th( [ 'Device', 'Port', 'PatchPort', 'Device', 'Port' ] ),
			$x
		);
	} else {
		"";
	}
}

#
# [XXX] This needs to be completely overhauled to deal with physical ports
# being properly displayed and editable but that requires the whole port
# manipulation code being overhauled.  yay.
#
sub build_patchpanel_drop_tr {
	my ( $self, $devid, $hr ) = @_;

	my $cgi = $self->cgi || die "Could not create cgi";

	my $lhs = "";
	my $rhs = "";

	my $root = $self->guess_stab_root;
	if ( $hr->{ _dbx('D1_DEVICE_NAME') } ) {
		my $rdevid = $hr->{ _dbx('D1_DEVICE_ID') };
		$lhs = $cgi->a(
			{
				-href   => "$root/device/device.pl?devid=" . $rdevid,
				-target => "stab_device_$rdevid",
			},
			$hr->{ _dbx('D1_DEVICE_NAME') }
		);
	}
	if ( $hr->{ _dbx('D2_DEVICE_NAME') } ) {
		my $rdevid = $hr->{ _dbx('D2_DEVICE_ID') };
		$rhs = $cgi->a(
			{
				-href   => "$root/device/device.pl?devid=" . $rdevid,
				-target => "stab_device_$rdevid",
			},
			$hr->{ _dbx('D2_DEVICE_NAME') }
		);
	}

	$cgi->Tr(
		$cgi->td($lhs),
		$cgi->td(
			$hr->{ _dbx('D1_PORT_NAME') } ? $hr->{ _dbx('D1_PORT_NAME') }
			: ""
		),
		$cgi->td( $cgi->b( $hr->{ _dbx('PATCH_NAME') } ) ),
		$cgi->td($rhs),
		$cgi->td(
			$hr->{ _dbx('D2_PORT_NAME') } ? $hr->{ _dbx('D2_PORT_NAME') }
			: ""
		),
	);
}

#
# This is all just really effin gross.  The ids and names acutally matter
# in most places, so extra care if any of those are going to change.
#
# When the row is specified, it means that a row is being dynamically
# requested rather than being constructed as part of the initial table.
# this means that some sort of id not used inside the existing web page
# needs to be assigned.
#
# The name of the tr and a hidden element inside the table named
# PC_[layer1_connection_id]_row# gets adjusted so that they can be queried
# in order.  the layer1_connection_id is always guaranteed to be there.
# Using the layer1_connection_id instead of the originaing physical_port_Id
# as an identifier is one of the reasons the connection must be inserted
# into the db first, then the patch panel setup done on a second step.  This
# should probably be reconciled in a future version of stab.
#
sub physical_connection_row {
	my ( $self, $params, $row, $side, $hr ) = @_;

	my $devid     = ($params) ? $params->{'-deviceID'}  : undef;
	my $tableid   = ($params) ? $params->{'-tableId'}   : undef;
	my $sel       = ($params) ? $params->{'-choosable'} : undef;
	my $showAdd   = ($params) ? $params->{'-showAdd'}   : undef;
	my $showCable = ($params) ? $params->{'-showCable'} : undef;
	my $pportkey  = ($params) ? $params->{'-pportKey'}  : undef;
	my $backwards = ($params) ? $params->{'-backwards'} : undef;

	my $cgi = $self->cgi || die "Could not create cgi";

	#
	# this is supposed to be some unique identifier that is unique within
	# the web page and used to describe the row.  A hidden element is used
	# by the code that handles the insert to map the row number to this
	# uniqueid in some cases.  In other cases, the physical_connection id
	# is used as a unique id.
	#
	my $uniqid = "r_" . int( rand(10000000) );
	$uniqid .= "_r" . $row if ($row);

	my ( $dev, $pport, $cable );
	my $divwrapid = "pc_r_dwrap_$uniqid";
	if ( !$sel ) {
		if ( defined($side) ) {
			$pport = $hr->{ _dbx("PC_P${side}_PHYSICAL_PORT_NAME") };
			$dev   = $hr->{ _dbx("PC_P${side}_DEVICE_NAME") };
		} else {
			$pport = $hr->{ _dbx("PORT_NAME") };
			my $d = $self->get_dev_from_devid( $hr->{ _dbx('DEVICE_ID') } );
			$dev = $d->{ _dbx('DEVICE_NAME') };
		}
	} else {

		#
		# this grossness allows for dynamically added entries to show up.
		#
		my $oep = {};
		$oep->{'-uniqID'}    = $uniqid;
		$oep->{'-deviceID'}  = $devid;
		$oep->{'-side'}      = $side;
		$oep->{'-pportKey'}  = $pportkey;
		$oep->{'-backwards'} = $backwards;

		$dev = $self->physicalport_otherend_device_magic( $oep, $hr,
			'physconn', $divwrapid );

		# when side is not set, its because an empty row is being added.  In
		# that case, the side depends on if the connection is backwards or not.
		# Yes, this is totally confusing.  Welcome to layer1 connections.
		my $pportside = $side;
		if (   !$hr
			|| !defined( $hr->{ _dbx('PC_P1_PHYSICAL_PORT_ID') } ) )
		{
			if ($backwards) {
				$pportside = 1;
			} else {
				$pportside = 2;
			}
		}

		my $dropp = {};
		$dropp->{-divWrap} = $divwrapid;
		if ( !$hr ) {
			my $cgiid =
			  "PC_P${pportside}_PHYSICAL_PORT_ID_" . $oep->{'-uniqID'};
			$dropp->{-id}   = $cgiid;
			$dropp->{-name} = $cgiid;
		} else {
			$dropp->{-deviceid} =
			  $hr->{ _dbx("PC_P${pportside}_DEVICE_ID") };
		}

		$pport =
		  $self->b_dropdown( $dropp, $hr, "PC_P${pportside}_PHYSICAL_PORT_ID",
			'PC_P1_PHYSICAL_PORT_ID' );

	}

	my $hiddenid = "PhysPath_${pportkey}_row$row";

	my $myrowid =
	  ( defined($hr) ) ? $hr->{ _dbx("PC_P1_PHYSICAL_PORT_ID") } : $uniqid;

	#
	# this is used to map the row to some unique id for finding the other
	# associated fields.
	#
	my $hidden = '';
	if ( $showCable || $sel ) {
		$hidden = $cgi->hidden(
			-name    => $hiddenid,
			-id      => $hiddenid,
			-default => $myrowid
		);
	}

	#
	# note that the javascript looks for an element with an id of this
	# without the tr_ and renames both this and the hidden element when a
	# row is added, so they /must/ be kept the same.
	#
	my $trid = "tr_" . $hiddenid;

	my $addrow = "";
	if ($showAdd) {
		my $addid       = "add_link_$uniqid";
		my $newlineside = 2;
		if ($backwards) {
			$newlineside = 1;
		}
		$addrow = $cgi->a(
			{
				-id => $addid,
				-href =>
				  "javascript:AppendPatchPanelRow(\"$addid\", \"$pportkey\", \"$tableid\", $newlineside)",
				-style => 'border: 1px solid; font-size: 50%'
			},
			"ADD"
		);
		if ($showCable) {
			my $delid = "rm_PC_$myrowid";
			$addrow .= $cgi->checkbox(
				-name    => $delid,
				-id      => $delid,
				-checked => undef,
				-value   => 'on',
				-label   => 'Delete',
			);
		}
	}

	if ($showCable) {
		my $args = {};
		if ( !$hr ) {
			$args->{-name} = "CABLE_TYPE_$uniqid";
		}
		$cable = $self->b_dropdown( $args, $hr, "CABLE_TYPE",
			'PC_P1_PHYSICAL_PORT_ID' );
	} else {
		$cable = "";
	}

	my $innerHtml =
		$cgi->td( $hidden, $cable )
	  . $cgi->td($dev)
	  . $cgi->td($pport)
	  . $cgi->td($addrow);

	if ( exists( $params->{-noTr} ) && defined( $params->{-noTr} ) ) {
		"<trid>$trid</trid> <contents>"
		  . $cgi->escapeHTML($innerHtml)
		  . "</contents>";
	} else {
		$cgi->Tr( { -id => "$trid" }, $innerHtml );
	}
}

##############################################################################
#
# Physical Port Generic Code
#
##############################################################################

sub build_physical_port_query {
	my ( $what, $parent ) = @_;

	# ORACLE/PGSQL -- regexp_like (o)  vs regexp_matches (p)
	my $parentq = "";
	if ($parent) {
		$parentq .= qq{and l1.port_name ~ ?};
	}

	# XXX - this needs to be made to just not suck.  The whole P1/P2 stuff
	# is disgusting in the way it was dealt with
	my $q = qq{
		select
			l1.layer1_connection_Id,
			l1.physical_port_id		as p1_physical_port_id,
			l1.device_id				as p1_device_id,
			l1.port_name				as p1_port_name,
			l1.port_type				as p1_port_type,
			l1.port_purpose				as p1_port_purpose,
			l1.other_physical_port_id	as p2_physical_port_id,
			l1.other_device_id			as p2_device_id,
			coalesce(d.device_name, d.physical_label) as p2_device_name,
			l1.other_port_name			as p2_port_name,
			l1.other_port_purpose		as p2_port_purpose,
			l1.baud,
			l1.data_bits,
			l1.stop_bits,
			l1.parity,
			l1.flow_control
		  from v_l1_all_physical_ports l1
			left join device d
				on l1.other_device_id = d.device_id
			join slot s on (l1.physical_port_id = s.slot_id)
		  where	l1.device_id = ?
			and l1.port_type = ?
			$parentq
	     order by s.component_id, s.slot_index
	};

	# order by NETWORK_STRINGS.NUMERIC_INTERFACE(l1.port_name),s.component_id, s.slot_index;
	# TODO - allow stab to use that function?

	$q;
}

sub build_physical_port_conn_query {
	my ($what) = @_;

	# [XXX] - need to tweak to actually deal with physical connections

	my $q = qq{
			select
				pcore.port_name	as	patch_name,
				d1.device_id 	as d1_device_id,
				d1.device_name	as d1_device_name,
				p1.port_name	as d1_port_name,
				d2.device_id	as d2_device_id,
				d2.device_name	as d2_device_name,
				p2.port_name	as d2_port_name
			  from  physical_port pcore
				left join physical_connection pc1
					on pc1.physical_port1_id = pcore.physical_port_id
				left join physical_port p1
					on p1.physical_port_id = pc1.physical_port2_id
				left join device d1
					on p1.device_id = d1.device_id
				left join physical_connection pc2
					on pc2.physical_port2_id = pcore.physical_port_id
				left join physical_port p2
					ON p2.physical_port_id = pc2.physical_port1_id
				left join device d2
					on p2.device_id = d2.device_id
			where
				pcore.device_id = ?
			AND
				pcore.port_type = ?
			order by NETWORK_STRINGS.NUMERIC_INTERFACE(patch_name)
	};

	$q;
}

sub physicalport_otherend_device_magic {
	my ( $self, $params, $hr, $what, $divwrapid ) = @_;

	my $cgi = $self->cgi;

	my $prefix = '';
	if ( $what eq 'physconn' ) {
		$what   = '';
		$prefix = 'PC_';
	}

	my $devid = $params->{'-deviceID'};
	my $side  = $params->{-side};

	#
	# when side is not set, its because an empty row is being added.  In
	# that case, the side depends on if the connection is backwards or not.
	# Yes, this is totally confusing.  Welcome to layer1 connections.
	#
	if ( !defined($side) ) {
		if ( exists( $params->{-backwards} ) && $params->{-backwards} ) {
			$side = 1;
		} else {
			$side = 2;
		}
	}

	#
	# this is what was there as a drop down.  his will require some
	# serious whacking to get working.
	#
	#$self->b_dropdown({
	#	-onChange=>"showSerialPorts(this, $pportid, \"$divwrapid\");",
	#	-devfuncrestrict=>'consolesrv'},
	#$hr, "P2_DEVICE_ID", 'P1_PHYSICAL_PORT_ID')

	my ( $pdevid, $pname, $pportid );

	if ($hr) {
		$pdevid  = $hr->{ _dbx("${prefix}P${side}_DEVICE_ID") };
		$pname   = $hr->{ _dbx("${prefix}P${side}_DEVICE_NAME") };
		$pportid = $hr->{ _dbx("${prefix}P1_PHYSICAL_PORT_ID") };
	} elsif ( $params && exists( $params->{'-uniqID'} ) ) {
		$pdevid  = '';
		$pname   = '';
		$pportid = $params->{'-uniqID'};
	} else {
		return '';
	}

	#
	# XXX need to effing clean this up.
	#
	my $sidestuff = '';
	if ( $what eq '' ) {
		$sidestuff = ", $side";
	}

	my $pdid  = "${prefix}P${side}_DEVICE_ID_" . $pportid;
	my $pdnam = "${prefix}P${side}_DEVICE_NAME_" . $pportid;
	my $rv    = $cgi->hidden(
		{
			-name    => $pdid,
			-id      => $pdid,
			-default => $pdevid
		}
	);
	$rv .= $cgi->textfield(
		{
			-name     => $pdnam,
			-id       => $pdnam,
			-size     => 40,
			-class    => 'tracked',
			-original => $pname,

			#-readonly => 1,
			-title => 'Click to select another device',
			-onClick =>
			  "showOtherEndDeviceSearchPopup( this, \"$pdid\", \"$pportid\", \"$divwrapid\", \"$what\"$sidestuff );",

			# Show the popup if a key is pressed, except Tab
			-onKeyDown =>
			  "if( event.keyCode !== 9 ) { showOtherEndDeviceSearchPopup( this, \"$pdid\", \"$pportid\", \"$divwrapid\", \"$what\"$sidestuff ); }",
			-onInput =>
			  "showOtherEndDeviceSearchPopup( this, \"$pdid\", \"$pportid\", \"$divwrapid\", \"$what\"$sidestuff ); delayedGetMatchingDevices( this );",

			#-onContextMenu => "if( this.value === '' ) { return( true ); }; event.preventDefault(); navigator.clipboard.writeText( this.value ); blink_message( 'Value copied!', event.pageX, event.pageY, 500 ); ",
			-default => $pname,
		}
	);

	# XXX
	# a matching change needs to happen in javascript/device-utils.js,
	# almost certainly want to rethink to make this editing not necessary
	# XXX

	my $deftab = '';

	if ( length($what) ) {
		$deftab = "Serial";
		$deftab = "Switchport" if ( $what eq 'network' );
		$deftab = ";__default_tab__=$deftab";
	}

	my $devlink = "javascript:void(null);";
	if ($pdevid) {
		$devlink = "./device.pl?devid=$pdevid$deftab";
	}

	$rv .= $cgi->a(
		{
			-style  => 'font-size: 30%;',
			-target => "stab_device_pp_$pportid",
			id      => $what . "_devlink_$pportid",
			-href   => $devlink
		},
		">>"
	);
	if ( defined($hr) && defined( $hr->{ _dbx('LAYER1_CONNECTION_ID') } ) ) {
		my $pportkey = $params->{-pportKey};
		my $myid     = "pplink_a_$pportkey";
		my $pplink =
		  "javascript:PatchPanelDrop($devid, $pportkey, \"$pdnam\");";
		$rv .= $cgi->a(
			{
				-style => 'font-size: 50%;',
				-href  => $pplink,
				-id    => $myid
			},
			"(pp)"
		);
	}
	$rv;
}

##############################################################################
#
# Advanced Tab
#
##############################################################################
sub dump_advanced_tab {
	my ( $self, $devid ) = @_;

	my $cgi = $self->cgi || die "Could not create cgi";

	my $addpwrid = "power_port_resync_$devid";
	my $addserid = "serial_port_resync_$devid";
	my $addnetid = "switch_port_resync_$devid";

	my $rv =
	  $cgi->h3( { -style => 'text-align: center' }, "Advanced Operations" );
	$rv .= $cgi->p(
		{ -style => 'font-size: 60%; text-align: center' },
		"Only check these if you know what they do"
	);
	$rv .= $cgi->ul(
		$cgi->li(
			$cgi->checkbox(
				-name  => 'chk_dev_port_reset',
				-id    => 'chk_dev_port_reset',
				-value => 'off',
				-label =>
				  'Reset serial port connections to default (This will erase existing connections)'
			)
		),
		$cgi->li(
			$cgi->checkbox(
				-name  => 'chk_dev_retire',
				-id    => 'chk_dev_retire',
				-value => 'off',
				-label =>
				  'RETIRE THIS DEVICE: Delete all ports, erase name, and if no serial number or device notes, remove device from JazzHands'
			)
		),
		$cgi->li(
			$cgi->checkbox(
				-name    => $addpwrid,
				-id      => $addpwrid,
				-checked => undef,
				-value   => 'off',
				-label   => 'Add missing power ports from Device Type',
			)
		),
		$cgi->li(
			$cgi->checkbox(
				-name    => $addserid,
				-id      => $addserid,
				-checked => undef,
				-value   => 'off',
				-label   => 'Add missing serial from Device Type',
			)
		),
		$cgi->li(
			$cgi->checkbox(
				-name    => $addnetid,
				-id      => $addnetid,
				-checked => undef,
				-value   => 'off',
				-label   => 'Add missing switchports from Device Type',
			)
		),
	);

	my $dev;
	if ($devid) {
		$dev = $self->get_dev_from_devid($devid);
	}

	if ($dev) {
		my $tt = "";
		if ( $dev->{ _dbx('DATA_INS_USER') } ) {
			$tt .= $cgi->Tr(
				$cgi->td("Inserted"),
				$cgi->td( $dev->{ _dbx('DATA_INS_DATE') } ),
				$cgi->td( $dev->{ _dbx('DATA_INS_USER') } )
			);
		}
		if ( $dev->{ _dbx('DATA_UPD_USER') } ) {
			$tt .= $cgi->Tr(
				$cgi->td("Updated"),
				$cgi->td( $dev->{ _dbx('DATA_UPD_DATE') } ),
				$cgi->td( $dev->{ _dbx('DATA_UPD_USER') } )
			);
		}

		$rv .= $cgi->table($tt);
		undef $tt;
	}
	$rv;
}

##############################################################################
#
# Components Tab
#
##############################################################################
sub dump_components_tab {
	my ( $self, $devid ) = @_;

	my $cgi = $self->cgi || die "Could not create cgi";

	# Get the components from the database
	my $sth = $self->prepare(
		q{
			select
				array_to_string(functions,'/') as component,
				vendor,
				model,
				serial_number,
				slot_name,
				concat_ws(' ',pg_size_pretty(memory_size*1024*1024),concat_ws(' Mhz',memory_speed,''),pg_size_pretty(disk_size),media_type) as specifications
			from
				jazzhands_legacy.v_device_components_expanded
			where
				device_id=?
			order by
				case when functions='{device}' then 0 else 1 end,
				functions,
				vendor,
				slot_name,
				model
		}
	);

	$sth->execute($devid) || $self->return_db_err($sth);

	# Display the tab content
	my $tab = $cgi->h3( { -style => 'text-align: center' }, "Components" );

	my $rows;
	my $opts = { -class => 'components' };
	while ( my $hr = $sth->fetchrow_hashref ) {
		$rows .= $cgi->Tr(
			$opts,
			$cgi->td( $opts, $hr->{ _dbx('component') } ),
			$cgi->td( $opts, $hr->{ _dbx('vendor') } ),
			$cgi->td( $opts, $hr->{ _dbx('model') } ),
			$cgi->td( $opts, $hr->{ _dbx('serial_number') } ),
			$cgi->td( $opts, $hr->{ _dbx('slot_name') } ),
			$cgi->td( $opts, $hr->{ _dbx('specifications') } ),
		);
	}

	$tab .= $cgi->table(
		{
			-style => 'border 1px solid',
			align  => 'center',
			-class => 'networkrange'
		},
		$cgi->Tr(
			$opts,
			$cgi->th(
				$opts,
				[
					'Component', 'Vendor',
					"Model",     "Serial",
					'Slot',      'Specifications',
				]
			)
		),
		$rows
	) . '<br/>';

	$tab;
}

##############################################################################
#
# Functions Tab
#
##############################################################################
sub dump_functions_tab {
	my ( $self, $devid ) = @_;

	my $cgi = $self->cgi || die "Could not create cgi";

	# Get functions from the database, along with an extra column with
	# 0 or 1, with 1 when function is assigned to the device
	my %functions = %{ $self->get_device_functions($devid) };

	# Build options for multi select box
	my ( @options, @set, %labels );
	foreach my $function_id ( sort keys %functions ) {
		my %function = %{ $functions{$function_id} };
		push( @options, $function{'device_collection_id'} );
		push( @set,     $function{'device_collection_id'} )
		  if ( $function{'selected'} );
		$labels{ $function{'device_collection_id'} } =
			 $function{'device_collection_name'}
		  || $function{'device_collection_id'};
	}

	# Build multi select box
	my $multi_select = $cgi->scrolling_list(
		-name    => 'DEVICE_FUNCTIONS',
		-values  => \@options,
		-default => \@set,
		-labels  => \%labels,

		#-size => scalar keys %labels,
		-size     => 10,
		-multiple => 'true',
		-class    => 'tracked',
		-original => join( ',', @set ),
	);

	# Display the tab content
	my $tab = $cgi->h3( { -style => 'text-align: center' }, "Functions" );
	$tab .= $cgi->table(
		{ -align => 'center' },
		$cgi->Tr( {}, $cgi->td( {}, $multi_select ) ),
	) . '<br/>';

	$tab;
}

##############################################################################
#
# Routing info
#
##############################################################################
sub dump_device_route {
	my ( $self, $devid ) = @_;

	my $cgi = $self->cgi || die "Could not create cgi";

	my $sth = $self->prepare(
		q{
		select	sr.static_route_id,
				net_manip.inet_dbtop(snb.ip_address) as route_src_ip,
				ddev.device_name as dest_device_name,
				dni.network_interface_name as dest_interface_name,
				dni.network_interface_id,
				net_manip.inet_dbtop(dnb.ip_address) as route_dest_ip
		   from	static_route sr
				inner join netblock snb
					on snb.netblock_id = sr.netblock_id
				inner join network_interface dni
					on dni.network_interface_id =
						sr.NETWORK_INTERFACE_DST_ID
				inner join network_interface_netblock dnin
					using( network_interface_id )
				inner join device ddev
					on ddev.device_id = dni.device_id
				left join netblock dnb
					on dnin.netblock_id = dnb.netblock_id
		 where	sr.device_src_id = ?
	}
	);

	$sth->execute($devid) || $self->return_db_err($sth);

	my (%seen);

	my $tt = $cgi->th(
		[
			'Delete',  'Source address', "/", "Bits",
			'Dest IP', 'Destination Device',
		]
	);
	while ( my $hr = $sth->fetchrow_hashref ) {
		$seen{ $hr->{ _dbx('ROUTE_SRC_IP') } } =
		  $hr->{ _dbx('NETWORK_INTERFACE_ID') };
		$tt .= $self->build_existing_route_box($hr);
	}

	$tt .= $self->build_existing_route_box();    # add box

	my $oc = get_device_netblock_routes( $self, $devid, \%seen );
	if ( length($oc) ) {
		$oc =
		  $cgi->h3( { -align => 'center' }, "Routes for this Host's Netblocks" )
		  . $oc;
	}

	undef(%seen);

	$cgi->h3( { -align => 'center' }, "Static Routing" )
	  . $cgi->h3( { -align => 'center' }, "Existing Routes" )
	  . $cgi->table( { -align => 'center', -border => 1 }, $tt )
	  . $oc;
}

sub build_existing_route_box {
	my ( $self, $hr ) = @_;

	my $cgi = $self->cgi || die "Could not create cgi";

	my $del      = $cgi->b("ADD");
	my $int_name = "";
	if ($hr) {
		my $id = $hr->{ _dbx('STATIC_ROUTE_ID') };
		$del = $cgi->hidden(
			-name    => "STATIC_ROUTE_ID_$id",
			-default => $id
		  )
		  . $self->build_checkbox( $hr, "", 'rm_STATIC_ROUTE_ID',
			'STATIC_ROUTE_ID' );

		$int_name = $cgi->td(
			{
				-name => 'DEST_INT_' . $hr->{ _dbx('STATIC_ROUTE_ID') }
			},
			$hr->{ _dbx('DEST_DEVICE_NAME') } . ":"
			  . $hr->{ _dbx('DEST_INTERFACE_NAME') }
		);
	}

	$cgi->Tr(
		$cgi->td(
			[
				$del,
				$self->b_textfield(
					{ -allow_ip0 => 1 }, $hr,
					"ROUTE_SRC_IP", 'STATIC_ROUTE_ID'
				),
			]
		),
		$cgi->td(
			$self->b_textfield( $hr, "ROUTE_DEST_IP", 'STATIC_ROUTE_ID' ),
		),
		$int_name,
	);
}

sub get_device_netblock_routes {
	my ( $self, $devid, $seen ) = @_;

	my $cgi = $self->cgi || die "Could not create cgi";

	my $sth = $self->prepare(
		q{
		select
			srt.STATIC_ROUTE_TEMPLATE_ID,
			net_manip.inet_dbtop(rnb.ip_address) as device_ip,
			srt.NETWORK_INTERFACE_DST_ID,
			srt.NETBLOCK_SRC_ID,
			net_manip.inet_dbtop(snb.ip_address) as source_block_ip,
			nin.netblock_id as destination_netblock_id,
			net_manip.inet_dbtop(dnb.ip_address) as destination_ip,
			dni.network_interface_name,
			dni.network_interface_id,
			ddev.device_name,
			srt.DESCRIPTION
		from   STATIC_ROUTE_TEMPLATE srt
			inner join netblock snb
				on snb.netblock_id = srt.netblock_src_id
			inner join netblock tnb
				on tnb.netblock_id = srt.netblock_id
			inner join netblock rnb
				on net_manip.inet_base(rnb.ip_address, masklen(rnb.ip_address)) =
				tnb.ip_address
			inner join network_interface_netblock nin
				on rnb.netblock_id = nin.netblock_id
			inner join network_interface dni
				on dni.network_interface_id = srt.network_interface_dst_id
			inner join network_interface_netblock dnin
				on dni.network_interface_id = dnin.network_interface_id
			inner join netblock dnb
				on dnin.netblock_id = dnb.netblock_id
			inner join device ddev
				on dni.device_id = ddev.device_Id
		where
			masklen(tnb.ip_address) = masklen(rnb.ip_address)
		and   ni.device_id = ?
	}
	);

	my $tally = 0;
	$sth->execute($devid) || $self->return_db_err($sth);
	my $tt = $cgi->th( [ "Add", "Route", "Dest IP", "Dest Interface", ] );
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $x =
			$hr->{ _dbx('SOURCE_BLOCK_IP') } . "/"
		  . $hr->{ -dbx('SOURCE_BLOCK_BITS') };
		if (
			!(
				defined( $seen->{$x} )
				&& $seen->{$x} == $hr->{ _dbx('NETWORK_INTERFACE_ID') }
			)
		  )
		{
			$tally++;
			$tt .= $cgi->Tr(
				$cgi->td(
					$self->build_checkbox(
						$hr, "", 'add_STATIC_ROUTE_TEMPLATE_ID',
						'STATIC_ROUTE_TEMPLATE_ID'
					)
				),
				$cgi->td($x),
				$cgi->td( $hr->{ _dbx('DESTINATION_IP') } ),
				$cgi->td(
					$hr->{ _dbx('DEVICE_NAME') },
					":",
					$hr->{ _dbx('NETWORK_INTERFACE_NAME') }
				)
			);
		}
	}

	my $rv = $cgi->table( { -align => 'center', -border => 1 }, $tt );

	($tally) ? $rv : "";
}

##############################################################################
#
# Network Interfaces
#
##############################################################################
sub dump_interfaces {
	my ( $self, $devid ) = @_;

	my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	my $rv = $cgi->h3( { -align => 'center' }, "Layer 3 Interfaces" );

	my $q = qq{
		select	ni.network_interface_id,
			ni.network_interface_name,
			ni.network_interface_type,
			ni.is_interface_up,
			ni.mac_addr,
			ni.should_manage,
			ni.should_monitor,
			ni.description,
			nb.netblock_id,
			net_manip.inet_dbtop(nb.ip_address) as IP,
			dns.dns_record_id,
			dns.dns_name,
			dns.dns_domain_id,
			dom.soa_name,
			dns.should_generate_ptr,
			net_manip.inet_dbtop(pnb.ip_address) as parent_IP,
			nb.parent_netblock_id
		from  network_interface ni
			left join network_interface_netblock nin using( network_interface_id )
			left join netblock nb using (netblock_id)
			left join dns_record dns using (netblock_id)
			left join dns_domain dom using (dns_domain_id)
			left join netblock pnb on
				nb.parent_netblock_id = pnb.netblock_id
		where ni.device_id = ?
		order by ni.network_interface_name, ni.network_interface_id, IP,
			dns.should_generate_ptr desc, dns.dns_name
	};

	my $sth = $self->prepare($q) || $self->return_db_err($dbh);
	$sth->execute($devid) || $self->return_db_err($sth);

	# Process each record and aggregate ip addresses and dns record

	my @aInterfaces;    # Array to store interfaces as hashes
	my %hInterface;     # Interface hash
	my %hIpAddress;     # IP address hash

	my $last_interface_id =
	  -1;    # Id of the interface processed in the last loop iteration
	my $last_ip_address =
	  'xxx';    # Value of the ip address processed in the last loop iteration
	my %dns;    # DNS info hash
	my $first = 1;

	while ( my ($values) = $sth->fetchrow_hashref ) {
		last if ( !defined($values) );

		# Build a hash of the dns properties
		if ( $values->{'dns_record_id'} ) {
			%dns = (
				'dns_record_id'       => $values->{'dns_record_id'},
				'dns_name'            => $values->{'dns_name'},
				'dns_domain_id'       => $values->{'dns_domain_id'},
				'soa_name'            => $values->{'soa_name'},
				'should_generate_ptr' => $values->{'should_generate_ptr'},
			);
		} else {
			%dns = ();
		}

		# If it's the first interface, just populate it from the record
		if ( $first == 1 ) {
			$first = 0;
			foreach ( keys( %{$values} ) ) {
				$hInterface{$_} = $values->{$_};
			}

			# If we have an ip address (it can be null), remember it
			if ( $values->{ _dbx('IP') } ) {
				$hIpAddress{'network_interface_id'} =
				  $values->{ _dbx('network_interface_id') };
				$hIpAddress{'netblock_id'} = $values->{ _dbx('netblock_id') };
				$hIpAddress{'ip'}          = $values->{ _dbx('IP') };
			}

			# This is not the first iteration
		} else {

			# If the interface has changed or if the ip address has changed
			if (
				(
					$last_interface_id !=
					$values->{ _dbx('NETWORK_INTERFACE_ID') }
				)
				or ( $last_ip_address ne $values->{ _dbx('IP') } )
			  )
			{
				if (%hIpAddress) {
					push( @{ $hInterface{'ip_addresses'} }, {%hIpAddress} );
				}

				# Empty and populate the current ip address with the new record data
				%hIpAddress = ();
				if ( $values->{ _dbx('IP') } ) {
					$hIpAddress{'network_interface_id'} =
					  $values->{ _dbx('network_interface_id') };
					$hIpAddress{'netblock_id'} =
					  $values->{ _dbx('netblock_id') };
					$hIpAddress{'ip'} = $values->{ _dbx('IP') };
				}
			}

			# If the interface has changed, save it for later processing
			if ( $last_interface_id !=
				$values->{ _dbx('NETWORK_INTERFACE_ID') } )
			{
				push( @aInterfaces, {%hInterface} );

				# Empty and populate the current interface with the new record data
				%hInterface = ();
				foreach ( keys( %{$values} ) ) {
					$hInterface{$_} = $values->{$_};
				}
			}
		}

		# Add the dns record hash to the current ip
		if ( $values->{'dns_record_id'} ) {
			push( @{ $hIpAddress{'dns_records'} }, {%dns} );
		}

		$last_interface_id = $values->{ _dbx('NETWORK_INTERFACE_ID') };
		$last_ip_address   = $values->{ _dbx('IP') };
	}

	# Save the last interface
	if (%hIpAddress) {
		push( @{ $hInterface{'ip_addresses'} }, {%hIpAddress} );
	}
	push( @aInterfaces, {%hInterface} );

	# Loop on preprocessed interfaces
	foreach my $hrInterface (@aInterfaces) {
		$rv .= $self->build_network_interface_box( $hrInterface, $devid );
	}

	# Define the table column headers
	my $collist = [
		'', 'Name', 'Type', 'MAC Address', 'IP Addresses',
		'DNS Records<span style="float:right">PTR</span>', ''
	];
	$rv = $cgi->table(
		{ -class => 'interfacetable' },
		$cgi->th($collist),
		$rv,
		$cgi->Tr(
			{ -class => 'header_add_item' },
			$cgi->td( { -colspan => $#{$collist} + 1 }, "Add Interface" )
		),
		$self->build_network_interface_box( undef, $devid ),
	);

	$sth->finish;

	# Add some notes at the bottom of the page
	$rv .=
	  "<br/><div align=center><u>Notes</u><div align=left style='margin: auto; width: 80%;'><ul>\n";
	$rv .=
	  "<li>Unlinking IP addresses will disassociate them from their network interface but leave them in the database with their DNS records.</li>\n";
	$rv .=
	  "<li>Locking DNS records will keep them associated to the original IP Address when it's updated</li>\n";
	$rv .= "</ul></div></div>\n";
	$rv;
}

#
# passed a $values (network_interface row ++) and a deviceid , print the
# purposes for that network interface (probably does not need device id)
#
# likely needs to become b_list or some such.
#
sub build_network_interface_purpose_table($$) {
	my ( $self, $values, $devid ) = @_;

	my $name = 'NETWORK_INTERFACE_PURPOSE';

	if ( defined( $values->{ _dbx('network_interface_id') } ) ) {
		$name .= "_" . $values->{ _dbx('network_interface_id') };
	} else {
		$name .= '_new';
	}

	my $cgi = $self->cgi || die "Could not create cgi";

	my $sth = $self->prepare(
		qq{
		WITH x AS (
			SELECT  network_interface_purpose, network_interface_id
			FROM    network_interface_purpose nip
			WHERE   network_interface_id = ?
		) SELECT network_interface_purpose, description, network_interface_id
			FROM val_network_interface_purpose
			LEFT JOIN x USING (network_interface_purpose)
			ORDER BY    network_interface_purpose
	}
	) || return $self->return_db_err();

	$sth->execute( $values->{ _dbx('network_interface_id') } )
	  || return $self->return_db_err($sth);

	my ( @options, @set, %labels );
	while ( my ( $val, $desc, $set ) = $sth->fetchrow_array ) {
		push( @options, $val );
		push( @set,     $val ) if ($set);
		$labels{$val} = $desc || $val;
	}

	my $thing = $cgi->scrolling_list(
		-name    => $name,
		-values  => \@options,
		-default => \@set,
		-labels  => \%labels,
		-size => scalar keys %labels,  # We have only 4 different values for now
		-multiple => 'true',
		-class    => 'tracked',
		-original => join( ',', @set ),
	);
}

# This function displays one interface and all its dependencies (netblocks, dns records, ...)
sub build_network_interface_box {
	my ( $self, $values, $devid ) = @_;

	#my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	# Default state of the more table checkboxes (unchecked)
	my $defchecked = undef;

	# Default network interface
	my $iNetworkInterfaceId = 'new';

	# Is this a new interface?
	if ( !defined( $values->{'network_interface_id'} ) ) {

		# More table heckboxes are selected by default for new interfaces
		$defchecked = 'on';

		# No, we have a valid network interface passed as parameter
	} else {
		$iNetworkInterfaceId = $values->{'network_interface_id'};
	}

	# Define a CSS class for all elements related to the network interface
	# This is used to mark them red for deletion
	my $strClassNetworkInterfaceId =
	  'id_network_interface_' . $iNetworkInterfaceId;

	my $strHiddenNetworkInterface = $cgi->input(
		{
			-type  => 'hidden',
			-id    => 'NETWORK_INTERFACE_ID_' . $iNetworkInterfaceId,
			-name  => 'NETWORK_INTERFACE_ID_' . $iNetworkInterfaceId,
			-value => 'NETWORK_INTERFACE_ID_' . $iNetworkInterfaceId,
		}
	);

	my $strNetIntButtonState = $self->cgi_parse_param(
		'NETWORK_INTERFACE_TOGGLE_' . $iNetworkInterfaceId );
	$strNetIntButtonState =
	  $strNetIntButtonState eq '' ? 'update' : $strNetIntButtonState;
	my $strNetIntButton = $cgi->button(
		{
			-type => 'button',
			-class =>
			  "button_switch parent_level_none level_network_interface $strClassNetworkInterfaceId",
			-id   => 'NETWORK_INTERFACE_TOGGLE_' . $iNetworkInterfaceId,
			-name => 'NETWORK_INTERFACE_TOGGLE_' . $iNetworkInterfaceId,
			-title =>
			  'Switch between update and delete modes for this Network Interface',
			-state   => $strNetIntButtonState,
			-label   => $strNetIntButtonState,
			-onclick => "updateNetworkInterfaceUI( this );",
		},
		$strNetIntButtonState
	);
	my $strNewNetIntButtonState = $self->cgi_parse_param(
		'NETWORK_INTERFACE_TOGGLE_' . $iNetworkInterfaceId );
	$strNewNetIntButtonState =
	  $strNewNetIntButtonState eq '' ? 'update' : $strNewNetIntButtonState;
	my $strNewNetIntButton = $cgi->button(
		{
			-type => 'button',
			-class =>
			  "button_switch parent_level_none level_network_interface $strClassNetworkInterfaceId",
			-id    => 'NETWORK_INTERFACE_TOGGLE_new',
			-name  => 'NETWORK_INTERFACE_TOGGLE_new',
			-title => '',
			-state => $strNewNetIntButtonState,
			-label => 'new',
		},
		'new'
	);

	my $pk                      = "NETWORK_INTERFACE_ID";
	my $strNetworkInterfaceName = $self->b_textfield(
		{
			-class =>
			  "tracked parent_level_none level_network_interface $strClassNetworkInterfaceId",
			-textfield_width => 10,
			-original        => (
				$iNetworkInterfaceId eq 'new'
				  or !defined( $values->{ _dbx('NETWORK_INTERFACE_NAME') } )
			) ? '' : $values->{ _dbx('NETWORK_INTERFACE_NAME') },
		},
		$values,
		'NETWORK_INTERFACE_NAME',
		$pk
	);

	my $strNetworkInterfaceType = $self->b_dropdown(
		{
			-class =>
			  "tracked parent_level_none level_network_interface $strClassNetworkInterfaceId",
			-original => (
				$iNetworkInterfaceId eq 'new'
				  or !defined( $values->{ _dbx('NETWORK_INTERFACE_TYPE') } )
			) ? '__unknown__' : $values->{ _dbx('NETWORK_INTERFACE_TYPE') },
		},
		$values,
		'NETWORK_INTERFACE_TYPE',
		$pk
	);

	my $strNetworkInterfaceMAC = $self->b_textfield(
		{
			-class =>
			  "tracked parent_level_none level_network_interface $strClassNetworkInterfaceId",
			-original => (
				$iNetworkInterfaceId eq 'new'
				  or !defined( $values->{ _dbx('MAC_ADDR') } )
			) ? '' : $values->{ _dbx('MAC_ADDR') },
		},
		$values,
		'MAC_ADDR',
		$pk
	);

	# The More table for the network interface
	my $strTableMore = $cgi->Tr(
		{
			-name  => 'more_expand_content_' . $iNetworkInterfaceId,
			-class => 'irrelevant',
			-style => 'border-top: 1px solid gray',
		},
		$cgi->th(),
		$cgi->th(
			'<br/><b>Up</b><br/>',
			$self->build_checkbox(
				{
					-class    => "tracked $strClassNetworkInterfaceId",
					-original => (
							 $iNetworkInterfaceId eq 'new'
						  or $values->{ _dbx('IS_INTERFACE_UP') } eq 'Y'
					) ? 'checked' : '',
				},
				$values, "",
				'IS_INTERFACE_UP',
				'NETWORK_INTERFACE_ID',
				$defchecked
			)
		),
		$cgi->th(
			'<b>Should<br/>Manage</b><br/>',
			$self->build_checkbox(
				{
					-class    => 'tracked',
					-original => (
							 $iNetworkInterfaceId eq 'new'
						  or $values->{ _dbx('SHOULD_MANAGE') } eq 'Y'
					) ? 'checked' : '',
				},
				$values, "",
				'SHOULD_MANAGE',
				'NETWORK_INTERFACE_ID',
				$defchecked
			)
		),
		$cgi->th(
			'<b>Should<br/>Monitor</b><br/>',
			$self->build_checkbox(
				{
					-class    => 'tracked',
					-original => (
							 $iNetworkInterfaceId eq 'new'
						  or $values->{ _dbx('SHOULD_MONITOR') } eq 'Y'
					) ? 'checked' : '',
				},
				$values, "",
				'SHOULD_MONITOR',
				'NETWORK_INTERFACE_ID',
				$defchecked
			)
		),
		$cgi->th(
			'<b>Select Purpose</b><br/>',
			$self->build_network_interface_purpose_table( $values, $devid )
		),
		$cgi->th(
			'<b>Description</b><br/>',
			$cgi->textarea(
				{
					-id => "NETWORK_INTERFACE_DESCRIPTION_$iNetworkInterfaceId",
					-name =>
					  "NETWORK_INTERFACE_DESCRIPTION_$iNetworkInterfaceId",
					-class    => "tracked $strClassNetworkInterfaceId",
					-rows     => 4,
					-columns  => 60,
					-original => $values->{ _dbx('DESCRIPTION') },
					-default  => $values->{ _dbx('DESCRIPTION') },
				},
				$values->{ _dbx('DESCRIPTION') },
			)
		),
		$cgi->th()
	);

	# Count the netblocks passed as parameters for this network interface
	my $iNumNetblocks =
	  exists( $values->{'ip_addresses'} )
	  ? scalar( @{ $values->{'ip_addresses'} } )
	  : 0;

	# The number of lines in the tables is the number of netblocks + one line for the new ip template
	my $iRowSpan = $iNumNetblocks + 1;

	# Make the extras something that can be clicked on and expanded
	my $strTdMoreExpand = $cgi->td(
		{
			-rowspan => $iRowSpan,
			-class   => 'more_expand_td_' . $iNetworkInterfaceId
		},
		'<span title="Show/hide more options" id="more_expand_control_'
		  . $iNetworkInterfaceId
		  . '" class=toggle_container onclick="showhide( this );"><span class=toggle_switch></span></span>',
	);

	# Loop on netblocks (ip addresses)
	# And iterate once more at the end for the new ip template
	my $strNetworkInterface;

	foreach my $i ( 0 .. ($iNumNetblocks) ) {

		# Get the supplied ip address for the current netblock
		my $hIPAddress = {};
		my $iNetblockId;

		# For all existing netblocks...
		if ( $i < $iNumNetblocks ) {
			$hIPAddress  = @{ $values->{'ip_addresses'} }[$i];
			$iNetblockId = $hIPAddress->{'netblock_id'};

			# ... and for the last iteration of the loop applying to the new ip addition template
		} else {
			$hIPAddress->{'network_interface_id'} = $iNetworkInterfaceId;
			$hIPAddress->{'netblock_id'}          = 'new';
			$hIPAddress->{'ip'}                   = '';
			$iNetblockId                          = 'new';
		}

		my $strClassNetblockId = 'id_netblock_' . $iNetblockId;

		# Prepare netblock related elements - delete button, ip and dns fields
		my $strNetblockButtonState = $self->cgi_parse_param(
			'NETBLOCK_TOGGLE_' . $iNetworkInterfaceId . '_' . $iNetblockId );
		$strNetblockButtonState =
		  $strNetblockButtonState eq '' ? 'update' : $strNetblockButtonState;
		my $strNetblockButton = $cgi->button(
			{
				-type => 'button',
				-class =>
				  "button_switch parent_level_network_interface level_netblock $strClassNetworkInterfaceId $strClassNetblockId",
				-id => 'NETBLOCK_TOGGLE_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId,
				-name => 'NETBLOCK_TOGGLE_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId,
				-title =>
				  'Switch between update, unlink (disassociate IP address from network interface without deleting it) and delete modes for this IP address',
				-state   => $strNetblockButtonState,
				-label   => $strNetblockButtonState,
				-onclick => "updateNetworkInterfaceUI( this );",
			},
			$strNetblockButtonState
		);
		my $strNewNetblockButtonState = $self->cgi_parse_param(
			'NETBLOCK_TOGGLE_' . $iNetworkInterfaceId . '_' . $iNetblockId );
		$strNewNetblockButtonState =
		  $strNewNetblockButtonState eq ''
		  ? 'update'
		  : $strNewNetblockButtonState;
		my $strNewNetblockButton = $cgi->button(
			{
				-type => 'button',
				-class =>
				  "button_switch parent_level_network_interface level_netblock $strClassNetworkInterfaceId $strClassNetblockId",
				-id => 'NETBLOCK_TOGGLE_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId,
				-name => 'NETBLOCK_TOGGLE_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId,
				-title => '',
				-state => $strNewNetblockButtonState,
				-label => 'new',
			},
			'new'
		);
		my $strIP = $self->b_textfield(
			{
				-type => 'text',
				-class =>
				  "tracked parent_level_network_interface level_netblock $strClassNetworkInterfaceId $strClassNetblockId",
				-placeholder => ( $iNetblockId eq 'new' )
				? 'Enter new IP address'
				: 'Use button to delete IP',
				-textfield_width => 25,
				-original        => $hIPAddress->{'ip'},
			},
			$hIPAddress,
			'ip',
			[ 'network_interface_id', 'netblock_id' ]
		);
		my $strDNS = $self->build_dns_box( $hIPAddress->{'dns_records'},
			$devid, $iNetworkInterfaceId, $iNetblockId, $hIPAddress->{'ip'} );

		# This is the first netblock line in the table, and we do have at least one associated netblock to display
		if ( $i == 0 && $iNumNetblocks > 0 ) {
			$strNetworkInterface .= $cgi->Tr(
				{
					-class => $strClassNetworkInterfaceId
					  . ' network_interface_first_line',
				},
				$cgi->td(
					{ -rowspan => $iRowSpan },
					$strHiddenNetworkInterface . $strNetIntButton
				),
				$cgi->td( { -rowspan => $iRowSpan }, $strNetworkInterfaceName ),
				$cgi->td( { -rowspan => $iRowSpan }, $strNetworkInterfaceType ),
				$cgi->td( { -rowspan => $iRowSpan }, $strNetworkInterfaceMAC ),
				$cgi->td(
					{ -class => $strClassNetblockId },
					$strNetblockButton . $strIP
				),
				$cgi->td( { -class => $strClassNetblockId }, $strDNS ),
				$strTdMoreExpand
			);

			# This is the first netblock line in the table, but we have no associated netblock to display, so that's the template to add a new ip address
		} elsif ( $i == 0 && $iNumNetblocks == 0 ) {

			# Set intadd class if it's the template to add a new network interface
			my $tr_int_class = 'network_interface_first_line';
			$strNetworkInterface .= $cgi->Tr(
				{
					-class => $strClassNetworkInterfaceId . ' ' . $tr_int_class,
				},

				# Note: delete button is not added for new interfaces
				$cgi->td(
					{
						-rowspan => $iRowSpan,
						title    => 'Add new interface',
						alt      => 'Add new interface'
					},
					$strHiddenNetworkInterface
					  . (
						( $iNetworkInterfaceId ne 'new' )
						? $strNetIntButton
						: $strNewNetIntButton
					  )
				),
				$cgi->td( { -rowspan => $iRowSpan }, $strNetworkInterfaceName ),
				$cgi->td( { -rowspan => $iRowSpan }, $strNetworkInterfaceType ),
				$cgi->td( { -rowspan => $iRowSpan }, $strNetworkInterfaceMAC ),
				$cgi->td(
					{ -class => $strClassNetblockId },
					$strNewNetblockButton . $strIP
				),
				$cgi->td( { -class => $strClassNetblockId }, $strDNS ),
				$strTdMoreExpand
			);

			# This is the first line coming just after the last associated netblock has been displayed, so that's the template to add an up address
		} elsif ( $i == $iNumNetblocks ) {
			$strNetworkInterface .= $cgi->Tr(
				{ -class => $strClassNetworkInterfaceId },
				$cgi->td(
					{ -class => $strClassNetblockId },
					$strNewNetblockButton . $strIP
				),
				$cgi->td( { -class => $strClassNetblockId }, $strDNS ),
			);

			# This is any line of the table with an associated netblock except the first one handled above
		} elsif ( $i < $iNumNetblocks ) {
			$strNetworkInterface .= $cgi->Tr(
				{ -class => $strClassNetworkInterfaceId },
				$cgi->td(
					{ -class => $strClassNetblockId },
					$strNetblockButton . $strIP
				),
				$cgi->td( { -class => $strClassNetblockId }, $strDNS ),
			);

		}
	}

	# Add the More table below its interface as a new table line
	$strNetworkInterface .= $strTableMore;

	# And add a separator
	$strNetworkInterface .= $cgi->Tr(
		$cgi->td( { -class => 'horizontal_separator', -colspan => 7 }, '' ) );

	$strNetworkInterface;
}

# This procedure builds what's needed to display the dns part of an ip address row
sub build_dns_box {
	my ( $self, $dns_records, $devid, $iNetworkInterfaceId, $iNetblockId,
		$strIP )
	  = @_;

	my $cgi = $self->cgi || die "Could not create cgi";

	my $dnsbox  = '';
	my $dnsline = '';
	my $strClassNetworkInterfaceId =
	  'id_network_interface_' . $iNetworkInterfaceId;
	my $strClassNetblockId  = 'id_netblock_' . $iNetblockId;
	my $strClassDnsRecordId = '';

	my $strNewDnsButton = '';

	# Do we have at least one DNS record for the netblock?
	if ( $dns_records && scalar @{$dns_records} > 0 ) {

		# Loop on dns records
		foreach my $dns_record ( @{$dns_records} ) {

			my $dns_record_id = $dns_record->{'dns_record_id'};
			$strClassDnsRecordId = 'id_dns_record_' . $dns_record_id;

			my $dot = "";
			if ( $dns_record->{'dns_name'} ) {
				$dot = ".";
			}

			# Populate the dns domain dropdown with the previous value after a failed update
			my @dns_domain_id_values = ( $dns_record->{'dns_domain_id'}, '-1' );
			my %dns_domain_id_labels = (
				$dns_record->{'dns_domain_id'} => $dns_record->{'soa_name'},
				'-1'                           => '--Unset--'
			);
			my $dns_domain_id_new =
			  $self->cgi_parse_param( 'DNS_DOMAIN_ID_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId . '_'
				  . $dns_record_id );

			# Do we have a previous value?
			if (    defined($dns_domain_id_new)
				and $dns_domain_id_new ne ''
				and $dns_domain_id_new ne '-1'
				and $dns_domain_id_new ne $dns_record->{'dns_domain_id'} )
			{
				# Get the domain name corresponding to the id from the database
				my $sth = $self->prepare(
					qq{ select soa_name from dns_domain where dns_domain_id = ? }
				) || $self->return_db_err;
				$sth->execute($dns_domain_id_new) || $self->return_db_err;
				my ($dns_domain_name_new) = $sth->fetchrow_array;

				# Do we have a valid and non empty result?
				if ( defined($dns_domain_name_new)
					and $dns_domain_name_new ne '' )
				{
					# Add the domain id to the values
					push @dns_domain_id_values, $dns_domain_id_new;

					# And add the domain (id,name) keypair to the labels
					$dns_domain_id_labels{$dns_domain_id_new} =
					  $dns_domain_name_new;
				}
			}

			my $dns_text_name = $cgi->textfield(
				{
					-type => 'text',
					-class =>
					  "tracked dnsname parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId $strClassDnsRecordId",
					-name => 'DNS_NAME_'
					  . $iNetworkInterfaceId . '_'
					  . $iNetblockId . '_'
					  . $dns_record_id,
					-value       => $dns_record->{'dns_name'},
					-original    => $dns_record->{'dns_name'},
					-placeholder => "DNS name can't be empty",
				}
			);

			my $dns_dropdown_domainid = $cgi->popup_menu(
				{
					-name => 'DNS_DOMAIN_ID_'
					  . $iNetworkInterfaceId . '_'
					  . $iNetblockId . '_'
					  . $dns_record_id,
					-class =>
					  "tracked dnsdomain parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId $strClassDnsRecordId",
					-values   => \@dns_domain_id_values,
					-labels   => \%dns_domain_id_labels,
					-default  => $dns_record->{'dns_domain_id'},
					-original => $dns_record->{'dns_domain_id'},
				}
			);

			my $dns_hidden_domainid = $cgi->hidden(
				{
					-class    => 'dnsdomainid',
					-name     => '',
					-value    => $dns_record->{'dns_domain_id'},
					-disabled => 1
				}
			);

			my $dns_img_bluearrow = $cgi->img(
				{
					-src   => "../stabcons/arrow.png",
					-alt   => "DNS Names",
					-title => 'DNS Names',
					-class => 'devdnsref',
				}
			);

			my $dns_hidden_recordid = $cgi->hidden(
				{
					-class    => 'dnsrecordid',
					-name     => '',
					-value    => $dns_record_id,
					-disabled => 1
				}
			);

			my $dns_link_bluearrow = $cgi->a(
				{
					-class => 'dnsref',
					-href  => 'javascript:void(null)',
					-style => 'display: inline-flex; width: 30px;'
				},
				$dns_img_bluearrow . $dns_hidden_recordid
			);

			$dnsline = $cgi->td(
				{
					-style => 'text-align: left'
				},
				$cgi->span(
					{ -class => 'dnsroot' },
					$dns_text_name
					  . $dns_dropdown_domainid
					  . $dns_hidden_domainid
				  )
				  . $dns_link_bluearrow
			);

			my $strDnsButtonState =
			  $self->cgi_parse_param( 'DNS_TOGGLE_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId . '_'
				  . $dns_record_id );
			$strDnsButtonState =
			  $strDnsButtonState eq '' ? 'update' : $strDnsButtonState;
			my $strDnsButton = $cgi->button(
				{
					-type => 'button',
					-class =>
					  "button_switch parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId $strClassDnsRecordId",
					-id => 'DNS_TOGGLE_'
					  . $iNetworkInterfaceId . '_'
					  . $iNetblockId . '_'
					  . $dns_record_id,
					-name => 'DNS_TOGGLE_'
					  . $iNetworkInterfaceId . '_'
					  . $iNetblockId . '_'
					  . $dns_record_id,
					-title =>
					  "Switch between update, lock (to original IP address $strIP, if it's updated) and delete modes for this DNS record",
					-state   => $strDnsButtonState,
					-label   => $strDnsButtonState,
					-onclick => "updateNetworkInterfaceUI( this );",
				},
				$strDnsButtonState
			);

			# Prepare a hidden line for the additional DNS records
			my $dns_tr_refrecords = $cgi->Tr(
				$cgi->td(
					{
						-colspan => 2,
					},
					$cgi->div(
						{
							-class => 'irrelevant dnsrefcontent_'
							  . $dns_record_id
						}
					)
				)
			);

			# Prepare the attributes for the DNS PTR radio element
			my $hPTRRadioAttributes = {
				-type  => 'radio',
				-title => 'Set PTR for this DNS record',
				-name => 'DNS_PTR_' . $iNetworkInterfaceId . '_' . $iNetblockId,
				-id   => 'DNS_PTR_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId . '_'
				  . $dns_record_id,
				-class =>
				  "tracked dnsptr parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId $strClassDnsRecordId",
				-value => 'DNS_PTR_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId . '_'
				  . $dns_record_id,
				-label => '',
			};

			# Set the radio for PTR
			# Check the value from the previous update, if any
			# If the value matches this radio id, it was selected
			if (
				$self->cgi_parse_param(
					'DNS_PTR_' . $iNetworkInterfaceId . '_' . $iNetblockId
				) ne ''
			  )
			{
				if (
					$self->cgi_parse_param(
						'DNS_PTR_' . $iNetworkInterfaceId . '_' . $iNetblockId
					) eq 'DNS_PTR_'
					. $iNetworkInterfaceId . '_'
					. $iNetblockId . '_'
					. $dns_record_id
				  )
				{
					$hPTRRadioAttributes->{'-checked'} = 'on';
				}

				# We have no previous value, let's apply the status from the database
			} elsif ( $dns_record->{'should_generate_ptr'} eq 'Y' ) {
				$hPTRRadioAttributes->{'-checked'} = 'on';
			}

			# The 'original' custom attribute always defautls to the database value
			if ( $dns_record->{'should_generate_ptr'} eq 'Y' ) {
				$hPTRRadioAttributes->{'-original'} = 'checked';
			} else {
				$hPTRRadioAttributes->{'-original'} = '';
			}

			$dnsbox .= $cgi->Tr(
				{ -class => "id_network_interface_$dns_record_id" },
				$cgi->td($strDnsButton)
				  . $dnsline
				  . $cgi->td( $cgi->input($hPTRRadioAttributes) )
			) . $dns_tr_refrecords;

		}    # end of loop on dns records

		# We're now adding a template to create a new DNS record for the existing netblock
		my $strNewDnsButtonState =
		  $self->cgi_parse_param( 'DNS_TOGGLE_'
			  . $iNetworkInterfaceId . '_'
			  . $iNetblockId
			  . '_new' );
		$strNewDnsButtonState =
		  $strNewDnsButtonState eq '' ? 'update' : $strNewDnsButtonState;
		$strNewDnsButton = $cgi->button(
			{
				-type => 'button',
				-class =>
				  "button_switch parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId id_dns_record_new",
				-id => 'DNS_TOGGLE_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId . '_new',
				-name => 'DNS_TOGGLE_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId . '_new',
				-title => '',
				-state => $strNewDnsButtonState,
				-label => 'new',
			},
			'new'
		);

		# Prepare the attributes for the DNS PTR radio element (for new DNS record)
		my $hPTRNewRadioAttributes = {
			-type  => 'radio',
			-title => 'Set PTR for this new DNS record',
			-name  => 'DNS_PTR_' . $iNetworkInterfaceId . '_' . $iNetblockId,
			-id    => 'DNS_PTR_'
			  . $iNetworkInterfaceId . '_'
			  . $iNetblockId . '_new',
			-class =>
			  "tracked dnsptr parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId id_dns_record_new",
			-value => 'DNS_PTR_'
			  . $iNetworkInterfaceId . '_'
			  . $iNetblockId . '_new',
			-label => '',
		};

		# Check the value from the previous update, if any
		# If the value matches this radio id, it was selected
		if (
			$self->cgi_parse_param(
				'DNS_PTR_' . $iNetworkInterfaceId . '_' . $iNetblockId
			) ne ''
		  )
		{
			if (
				$self->cgi_parse_param(
					'DNS_PTR_' . $iNetworkInterfaceId . '_' . $iNetblockId
				) eq 'DNS_PTR_'
				. $iNetworkInterfaceId . '_'
				. $iNetblockId . '_new'
			  )
			{
				$hPTRNewRadioAttributes->{'-checked'} = 'on';
			}
		}

		# The 'original' custom attribute always defautls to unchecked for new records
		$hPTRNewRadioAttributes->{'-original'} = '';

		# Populate the dns domain dropdown with the previous value after a failed update
		my @dns_domain_id_values = ('-1');
		my %dns_domain_id_labels = ( '-1' => '--Unset--' );
		my $dns_domain_id_new =
		  $self->cgi_parse_param( 'DNS_DOMAIN_ID_'
			  . $iNetworkInterfaceId . '_'
			  . $iNetblockId
			  . '_new' );

		# Do we have a previous value?
		if (    defined($dns_domain_id_new)
			and $dns_domain_id_new ne ''
			and $dns_domain_id_new ne '-1' )
		{
			# Get the domain name corresponding to the id from the database
			my $sth = $self->prepare(
				qq{ select soa_name from dns_domain where dns_domain_id = ? })
			  || $self->return_db_err;
			$sth->execute($dns_domain_id_new) || $self->return_db_err;
			my ($dns_domain_name_new) = $sth->fetchrow_array;

			# Do we have a valid and non empty result?
			if ( defined($dns_domain_name_new) and $dns_domain_name_new ne '' )
			{
				# Add the domain id to the values
				push @dns_domain_id_values, $dns_domain_id_new;

				# And add the domain (id,name) keypair to the labels
				$dns_domain_id_labels{$dns_domain_id_new} =
				  $dns_domain_name_new;
			}
		}

		$dnsbox .= $cgi->Tr(
			$cgi->td(
				{ title => 'Add new DNS record', alt => 'Add new DNS record' },
				$strNewDnsButton
			  )
			  . $cgi->td(
				$cgi->textfield(
					{
						-type => 'text',
						-class =>
						  "tracked dnsname parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId id_dns_record_new",
						-textfield_width => 20,
						-id              => 'DNS_NAME_'
						  . $iNetworkInterfaceId . '_'
						  . $iNetblockId . '_new',
						-name => 'DNS_NAME_'
						  . $iNetworkInterfaceId . '_'
						  . $iNetblockId . '_new',
						-original    => '',
						-value       => '',
						-placeholder => 'Create new DNS record',
					}
				  )

				  #	$dns_records, "DNS_NAME", [ 'network_interface_id', 'netblock_id', 'dns_record_id' ] )
				  . $cgi->popup_menu(
					{
						-class =>
						  "tracked dnsdomain parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId id_dns_record_new",
						-id => 'DNS_DOMAIN_ID_'
						  . $iNetworkInterfaceId . '_'
						  . $iNetblockId . '_new',
						-name => 'DNS_DOMAIN_ID_'
						  . $iNetworkInterfaceId . '_'
						  . $iNetblockId . '_new',
						-values   => \@dns_domain_id_values,
						-original => '-1',
						-labels   => \%dns_domain_id_labels,
						-default  => '-1',
					}
				  )
			  )
			  . $cgi->td( $cgi->input($hPTRNewRadioAttributes) )
		);

		# wrap all DNS lines in a table
		$dnsbox = $cgi->table(
			{
				-width       => '100%',
				-border      => 0,
				-cellspacing => 0,
				-cellpadding => 0,
				-class       => 'interfacednstable',
				-width       => '100%',
			},
			$dnsbox
		);

		# There is no DNS record associated to this interface ip, display input fields
	} else {

		# Populate the empty dns_records array with just the keys needed to build the input fields
		$dns_records->{'network_interface_id'} = $iNetworkInterfaceId;
		$dns_records->{'netblock_id'}          = $iNetblockId;
		$dns_records->{'dns_record_id'}        = 'new';
		$strClassDnsRecordId                   = 'id_dns_record_new';

		my $strNewDnsButtonState =
		  $self->cgi_parse_param( 'DNS_TOGGLE_'
			  . $iNetworkInterfaceId . '_'
			  . $iNetblockId
			  . '_new' );
		$strNewDnsButtonState =
		  $strNewDnsButtonState eq '' ? 'update' : $strNewDnsButtonState;
		$strNewDnsButton = $cgi->button(
			{
				-type => 'button',
				-class =>
				  "button_switch parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId $strClassDnsRecordId",
				-id => 'DNS_TOGGLE_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId . '_new',
				-name => 'DNS_TOGGLE_'
				  . $iNetworkInterfaceId . '_'
				  . $iNetblockId . '_new',
				-title => '',
				-state => $strNewDnsButtonState,
				-label => 'new',
			},
			'new'
		);

		# Prepare the attributes for the DNS PTR checkbox element (for new DNS record of new netblock)
		my $hPTRNewCheckboxAttributes = {
			-name => 'DNS_PTR_'
			  . $dns_records->{'network_interface_id'} . '_'
			  . $dns_records->{'netblock_id'},
			-id => 'DNS_PTR_'
			  . $dns_records->{'network_interface_id'} . '_'
			  . $dns_records->{'netblock_id'} . '_new',
			-class =>
			  "tracked dnsptr parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId $strClassDnsRecordId",
			-title => 'Set PTR for this new DNS record',
			-value => 'DNS_PTR_'
			  . $dns_records->{'network_interface_id'} . '_'
			  . $dns_records->{'netblock_id'} . '_new',
			-label => '',
		};

		# Check the value from the previous failed update, if any
		# Checkboxes are tricky because a value is present only if checked before submit
		# So we have 3 cases:
		# 1.- The form is not displayed after a failed update, default state is checked
		# 2.- The form is displayed after a failed update and there is no value, state is unchecked
		# 3.- The form is displayed after a failed update and there is a value, state is checked
		# We can detect an update vs first display of the form by checking
		# for the presence of __notemsg__ in the param array

		# So, is that a failed update?
		if (    $self->cgi_parse_param('__notemsg__') ne ''
			and $self->cgi_parse_param('__notemsg__') ne '' )
		{
			# Do we have a value for the checkbox?
			if (
				$self->cgi_parse_param(
					'DNS_PTR_' . $iNetworkInterfaceId . '_' . $iNetblockId
				) ne 'Update successful.'
			  )
			{
				$hPTRNewCheckboxAttributes->{'-checked'} = 'on';
			}

			# This is not an update but the first display of the form
		} else {
			$hPTRNewCheckboxAttributes->{'-checked'} = 'on';
		}

		# The 'original' custom attribute always defautls to checked for the (first, obviously) new record of a new netblock
		$hPTRNewCheckboxAttributes->{'-original'} = 'checked';

		# Populate the dns domain dropdown with the previous value after a failed update
		my @dns_domain_id_values = ('-1');
		my %dns_domain_id_labels = ( '-1' => '--Unset--' );
		my $dns_domain_id_new =
		  $self->cgi_parse_param( 'DNS_DOMAIN_ID_'
			  . $dns_records->{'network_interface_id'} . '_'
			  . $dns_records->{'netblock_id'}
			  . '_new' );

		# Do we have a previous value?
		if (    defined($dns_domain_id_new)
			and $dns_domain_id_new ne ''
			and $dns_domain_id_new ne '-1' )
		{
			# Get the domain name corresponding to the id from the database
			my $sth = $self->prepare(
				qq{ select soa_name from dns_domain where dns_domain_id = ? })
			  || $self->return_db_err;
			$sth->execute($dns_domain_id_new) || $self->return_db_err;
			my ($dns_domain_name_new) = $sth->fetchrow_array;

			# Do we have a valid and non empty result?
			if ( defined($dns_domain_name_new) and $dns_domain_name_new ne '' )
			{
				# Add the domain id to the values
				push @dns_domain_id_values, $dns_domain_id_new;

				# And add the domain (id,name) keypair to the labels
				$dns_domain_id_labels{$dns_domain_id_new} =
				  $dns_domain_name_new;
			}
		}

		$dnsbox = $cgi->table(
			{
				-border      => 0,
				-cellspacing => 0,
				-cellpadding => 0,
				-class       => 'interfacednstable empty',
				-width       => '100%',
			},
			$cgi->Tr(
				$cgi->td(
					{
						title => 'Add new DNS record',
						alt   => 'Add new DNS record'
					},
					$strNewDnsButton
				  )
				  . $cgi->td(
					$self->b_textfield(
						{
							-class =>
							  "tracked dnsname parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId $strClassDnsRecordId",
							-textfield_width => 20,
							-placeholder     => 'Create new DNS record',
							-original        => '',
						},
						$dns_records,
						"DNS_NAME",
						[
							'network_interface_id', 'netblock_id',
							'dns_record_id'
						]
					  )

					  # The DNS domain dropdown menu will be generated by asychronous ajax calls for performance reasons
					  . $cgi->popup_menu(
						{
							-class =>
							  "tracked dnsdomain parent_level_netblock level_dns_record $strClassNetworkInterfaceId $strClassNetblockId $strClassDnsRecordId",
							-id => 'DNS_DOMAIN_ID_'
							  . $dns_records->{'network_interface_id'} . '_'
							  . $dns_records->{'netblock_id'} . '_new',
							-name => 'DNS_DOMAIN_ID_'
							  . $dns_records->{'network_interface_id'} . '_'
							  . $dns_records->{'netblock_id'} . '_new',
							-values   => \@dns_domain_id_values,
							-labels   => \%dns_domain_id_labels,
							-default  => '-1',
							-original => '-1',
						}
					  )
					  . $cgi->span(
						{ -style => 'display: inline-flex; width: 30px' }
					  )    # Spacer needed to replace blue arrow
				  )
				  . $cgi->td( $cgi->checkbox($hPTRNewCheckboxAttributes) )
			)
		);
	}
	$dnsbox;
}

#sub build_dns_rr_table {
#	my ( $self, $values ) = @_;
#
#	return undef if ( !$values );
#
#	my $cgi = $self->cgi || die "Could not create cgi";
#	my $dbh = $self->dbh || die "Could not create dbh";
#
#	my $q = qq{
#		select	dns.dns_record_id, dns.dns_name,
#				dns.dns_domain_id, dom.soa_name
#		  from	dns_record dns
#				inner join dns_domain dom
#					on dom.dns_domain_id = dns.dns_domain_id
#				inner join network_interface_netblock ni
#					on dns.netblock_id = ni.netblock_id
#		 where	ni.network_interface_id = ?
#		  and	dns.dns_record_id != ?
#	};
#	my $sth = $self->prepare($q) || $self->return_db_err($dbh);
#
#	my $rrt = "";
#
#	$sth->execute(
#		$values->{ _dbx('NETWORK_INTERFACE_ID') },
#		$values->{ _dbx('DNS_RECORD_ID') }
#	);
#	while ( my $hr = $sth->fetchrow_hashref ) {
#		$rrt .= $cgi->Tr(
#			$cgi->td( $hr->{ _dbx('DNS_NAME') } ),
#			$cgi->td( $hr->{ _dbx('SOA_NAME') } ),
#		);
#	}
#	$sth->finish;
#
#	if ( length($rrt) ) {
#		return $cgi->div( { -align => 'center' },
#			$cgi->b('DNS Round Robin Records') )
#		  . $cgi->table($rrt);
#	}
#	undef;
#}

#sub mac_int_to_text {
#	my ($in) = @_;
#
#	my $mac;
#	if ( defined($in) ) {
#		$mac = "000000000000";
#		$in =~ s/\s+//g;
#		$mac = substr( $mac, 0, length($mac) - length($in) );
#		$mac .= $in;
#		$mac =~ s/(\S\S)/$1:/g;
#		$mac =~ s/:$//;
#	}
#	$mac;
#}

##############################################################################
#
# Location
#
##############################################################################
sub device_location_print {
	my ( $self, $devid ) = @_;

	my $cgi = $self->cgi;

	my $hr = $self->get_location_from_devid($devid);

	my $hidden = '';
	if ($hr) {
		my $locid = "RACK_LOCATION_ID_" . $hr->{ _dbx('RACK_LOCATION_ID') };
		$hidden = $cgi->hidden(
			-name  => $locid,
			-id    => $locid,
			-value => $hr->{ _dbx('RACK_LOCATION_ID') }
		);
	} else {

		# This is to avoid an undefined hr value to cause issues in the
		# response generation with a wrong rack selected if no location exists
		my %emptyhr;
		$hr = \%emptyhr;
	}

	my $root = $self->guess_stab_root;

	my ( $rackdivid, $racksiteid );
	my $racklink = "";
	if (   $hr
		&& exists( $hr->{ _dbx('LOCATION_RACK_ID') } )
		&& $hr->{ _dbx('LOCATION_RACK_ID') } )
	{
		my $rack =
		  $self->get_rack_from_rackid( $hr->{ _dbx('LOCATION_RACK_ID') } );

		my $rackname = "";
		foreach my $c ( 'ROOM', 'SUB_ROOM', 'RACK_ROW', 'RACK_NAME' ) {
			if ( defined( $rack->{ _dbx($c) } ) ) {
				$rackname .= "-" if ( length($rackname) );
				$rackname .= $rack->{ _dbx($c) };
			}
		}
		my $rackid = $hr->{ _dbx('LOCATION_RACK_ID') };
		$racklink .= $cgi->Tr(
			$cgi->td(
				{ -colspan => 2, -align => 'center' },
				$cgi->a(
					{
						-align  => 'center',
						-target => "stab_location_$rackid",
						-href   => $root
						  . "/sites/rack/?RACK_ID="
						  . $hr->{ _dbx('LOCATION_RACK_ID') }
					},
					$rackname,
				)
			)
		);
		$rackdivid  = "rack_div_" . $hr->{ _dbx('RACK_LOCATION_ID') };
		$racksiteid = "RACK_SITE_CODE_" . $hr->{ _dbx('RACK_LOCATION_ID') };
	} else {
		$rackdivid  = "rack_div";
		$racksiteid = "RACK_SITE_CODE";
	}

	my $locid =
	  ( $hr && $hr->{ _dbx('RACK_LOCATION_ID') } )
	  ? $hr->{ _dbx('RACK_LOCATION_ID') }
	  : undef;

	my $rv = $cgi->table(
		{ -align => 'center' },
		$hidden,
		$self->build_tr(
			{
				-onChange =>
				  "site_to_rack(\"$racksiteid\", \"$rackdivid\", \"dev\", $locid);"
			},
			$hr,
			"b_dropdown",
			"Site",
			'RACK_SITE_CODE',
			'RACK_LOCATION_ID'
		),
		$self->build_tr(
			{ -divWrap => $rackdivid, -dolinkUpdate => 'rack' },
			$hr, "b_dropdown", "Rack", 'LOCATION_RACK_ID', 'RACK_LOCATION_ID'
		),
		$self->build_tr(
			$hr,                    "b_textfield",
			"U Offset of Top Left", 'LOCATION_RU_OFFSET',
			'RACK_LOCATION_ID'
		),
		$self->build_tr(
			$hr,         "b_nondbdropdown",
			"Rack Side", 'LOCATION_RACK_SIDE',
			'RACK_LOCATION_ID'
		),
		$racklink
	);

	$rv;
}
##############################################################################
#
# License Tracking
#
##############################################################################
sub device_license_tab {
	my ( $self, $devid ) = @_;

	my $cgi = $self->cgi;

	my $rv = "";

	my $sth = $self->prepare(
		qq{
		select	dc.device_collection_id, dc.device_collection_name
 		  from	device_collection dc
				inner join device_collection_device dcm
					on dc.device_collection_id = dcm.device_collection_id
		 where	dc.device_collection_type = 'applicense'
		   and	dcm.device_id = ?
	}
	) || $self->return_db_err;

	$sth->execute($devid) || $self->return_db_err;

	my $tt = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $delid =
		  "rm_Lic_DEVICE_COLLECTION_" . $hr->{ _dbx('DEVICE_COLLECTION_ID') };
		my $rm .= $cgi->checkbox(
			-name    => $delid,
			-id      => $delid,
			-checked => undef,
			-value   => 'on',
			-label   => 'Delete',
		);
		$tt .= $cgi->Tr( $cgi->td( [ $rm, $hr->{ _dbx('NAME') }, ] ) );
	}

	my $addid = "tr_lic_devid_" . $devid;
	$rv = $cgi->table(
		{ -align => 'center', border => 1 },
		$cgi->th( [ 'Remove', 'License Type' ] ),
		$tt,
		$cgi->Tr(
			{ -id => $addid },
			$cgi->td(
				{
					-colspan => 2,
					style    => 'text-align: center;'
				},
				$cgi->a(
					{
						-onClick => "add_License(this, \"$addid\", $devid)",
						-href    => "javascript:void(null)"
					},
					"Add a License"
				),
			),
		)
	);

	#	$rv = $cgi->table({-align => 'center'},
	#		$cgi->th(['Remove', 'License Type']),
	#		$cgi->Tr($cgi->td( [
	#			"r",
	#			$self->b_dropdown({ -deviceCollectionType => 'applicense'},
	#				undef, 'DEVICE_COLLECTION_ID'),
	#		])),
	#	);

	$rv;
}

##############################################################################
#
# Application Groups / Roles
#
##############################################################################
# note that this is shared between the tab generation code and the add a device
# code.  This should probably be overhauled so the "add a device code"
# actually can use tabs..
sub device_appgroup_tab {
	my ( $self, $devid ) = @_;

	my $cgi = $self->cgi;

	my $sth = $self->prepare(
		qq{
		select	r.role_level,
			r.role_id,
			root_role_id,
			root_role_name,
			role_path,
			role_name,
			role_is_leaf,
			rm.device_Id
		  FROM	v_application_role r
			LEFT JOIN v_application_role_member rm
				on rm.role_id = r.role_id
		WHERE	rm.device_id = ? or rm.device_id is NULL
		order by role_path, role_name
	}
	);

	$sth->execute($devid) || $self->return_db_err($sth);

	my ( @options, @set, %labels );

	my $name = "appgroup";

	my $resetlink   = "";
	my $warnmsg     = "";
	my $indicatetab = "";
	if ($devid) {

		# this only shows if we're updating an existing device.  If we're
		# adding new, then this is somewhat superfluous.
		$warnmsg = qq{
			Please select all that apply.  Please note that if you
			are adding additional items, you need to use a key
			modifier with the mouse (typically ctrl or shift,
			depending on the browser and operating system).  If you
			inadvertently remove functions, the "reset tab" link wil
l
			reset the list to be in sync with the database, as thoug
h
			no changes were made.
		};
		$resetlink = $cgi->div(
			{ -style => 'text-align: center;' },
			$cgi->a(
				{
					-href    => "javascript:void(null)",
					-onClick => qq{ShowDevTab("AppGroup", "$devid", "force")},
				},
				"(reset tab)"
			)
		);
		$indicatetab = $cgi->hidden( "has_appgroup_tab_$devid", $devid );
		$name        = 'appgroup_' . $devid;
	}

	my $tt = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		next if ( $hr->{ _dbx('ROLE_IS_LEAF') } eq 'N' );
		my $printable =
		  $hr->{ _dbx('ROLE_PATH') } . '/' . $hr->{ _dbx('ROLE_NAME') };
		$printable =~ s,^/,,;
		push( @options, $hr->{ _dbx('ROLE_ID') } );
		push( @set,     $hr->{ _dbx('ROLE_ID') } )
		  if ( $hr->{ _dbx('DEVICE_ID') } );
		$labels{ $hr->{ _dbx('ROLE_ID') } } = $printable;
	}
	my $x =
		$cgi->h3( { -align => 'center' }, 'Application Groupings' )
	  . $cgi->div( { -style => 'text-align: center' }, $warnmsg )
	  . $indicatetab
	  . $cgi->div(
		{ -style => 'text-align: center' },
		$cgi->scrolling_list(
			-name     => $name,
			-values   => \@options,
			-default  => \@set,
			-labels   => \%labels,
			-size     => 10,
			-multiple => 'true'
		)
	  )
	  . $cgi->div(
		{ -style => 'text-align: center;' },
		$cgi->a(
			{
				-href   => "apps/",
				-target => 'stab_apps',
			},
			"(explore apps)"
		  )
		  . $resetlink
	  );
	$x;
}

1;
__END__

=head1 NAME

JazzHands::STAB::Device - Device page manipulation routines

=head1 SYNOPSIS

	don't use this directly; use JazzHands::STAB instead

=head1 DESCRIPTION

Device page routines are moved here to collect them in one place.  They
should be better documented...

=head1 SEE ALSO

=head1 AUTHOR

Todd Kover

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
