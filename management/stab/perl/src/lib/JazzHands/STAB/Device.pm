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

sub setup_device_power {
	my($self, $devid) = @_;

	# XXX ORACLE/pgsql
	# oracle requires this to be wrapped in a begin/end, pgsql needs the
	# select

	my $dbh = $self->dbh || die "Could not create dbh";

	my $q = qq{
			SELECT port_utils.setup_device_power(?);
	};
	my $sth = $dbh->prepare($q) || $self->return_db_err($dbh);
	$sth->execute($devid) || $self->return_db_err($sth);
	$sth->finish;
}


sub setup_device_physical_ports {
	my($self, $devid, $type) = @_;

	# XXX ORACLE/pgsql
	# oracle requires this to be wrapped in a begin/end, pgsql needs the
	# select

	my $dbh = $self->dbh || die "Could not create dbh";

	my $q = qq{
			SELECT port_utils.setup_device_physical_ports(?, ?);
	};
	my $sth = $dbh->prepare($q) || $self->return_db_err($q, $dbh);
	$sth->execute($devid, $type) || $self->return_db_err($sth);
	$sth->finish;
}


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
			$cgi->td(
				{ -width => '85%' }, $cgi->escapeHTML($text)
			),
			$cgi->td(
				{ -width => '15%' }, $cgi->br($user),
				$cgi->br($date)
			)
		);
	}
	$sth->finish;

	$contents .= $cgi->Tr(
		$cgi->td(
			{ -colspan => 2, -style => 'text-align: center;' },
			$cgi->h4(
				{ -style => 'text-align: center' },
				'Add a note'
			),
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
		return $cgi->div(
			{ -style => 'text-align: center; padding: 50px' },
			$cgi->em("no notes.") );
	} else {
		return $cgi->table( { -width => '100%', -border => 1 },
			$contents );
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
	my $limit =
	  "p.device_id = ?  and	ni.PARENT_NETWORK_INTERFACE_ID is NULL";
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
		my $id = "circit_ni" . $hr->{_dbx('NETWORK_INTERFACE_ID')};

		my $nitype = $hr->{_dbx('NETWORK_INTERFACE_TYPE')};
		$nitype =~ tr/A-Z/a-z/;

		my $Xsth = $self->prepare(
"select count(*) from network_interface where parent_network_interface_id = ?"
		);
		$Xsth->execute( $hr->{_dbx('NETWORK_INTERFACE_ID')} )
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
						-id => "cirExpand_$id",
						-src =>
						  "$root/stabcons/expand.jpg"
					}
				),
				$hr->{_dbx('NETWORK_INTERFACE_NAME')}
			);
		} else {
			$iname = $hr->{_dbx('NETWORK_INTERFACE_NAME')};
		}
		my $circstr = "";
		if ( $hr->{_dbx('CIRCUIT_ID')} ) {
			my $name = $hr->{_dbx('VENDOR_CIRCUIT_ID_STR')} || 'unnamed';
			$circstr = $cgi->a(
				{
					-href => "$root/circuit/?CIRCUIT_ID="
					  . $hr->{_dbx('CIRCUIT_ID')}
				},
				$name
			);
		}

		my $trunk = "";
		my $cic   = "";
		if ( $hr->{_dbx('TRUNK_GROUP_NAME')} ) {
			$trunk = $cgi->a(
				{
					-href =>
"$root/circuit/trunkgroup/?TRUNK_GROUP_ID="
					  . $hr->{_dbx('TRUNK_GROUP_ID')}
				},
				$hr->{_dbx('TRUNK_GROUP_NAME')}
			);
			if ( $hr->{_dbx('TRUNK_TCIC_START')} ) {
				$cic =
				    $hr->{_dbx('TRUNK_TCIC_START')} . "-"
				  . $hr->{_dbx('TRUNK_TCIC_END')};
			}
		}

		$tt .= $cgi->Tr(
			{
				-class => "circuit_$nitype",
				-id    => "${id}_tr"
			},
			$cgi->td(
				[
					$iname,
					$hr->{_dbx('COMPANY_NAME')},
					$circstr,
					$hr->{_dbx('NETWORK_INTERFACE_TYPE')},
					$trunk,
					$cic,
				]
			)
		);
	}

	$cgi->table(
		{ -align => 'center', -border => 1 },
		$cgi->th(
			[
				"Name",       "Company",
				"Circuit ID", "Type",
				"Trunk",      "CIC Range"
			]
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

	$self->setup_device_physical_ports($devid, 'network');

	my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	#
	# if we have > 55 ports, then need to break down by card.
	#
	if (      !$parent
		&& $self->get_physical_port_tally( $devid, 'network', '/' ) >
		55 )
	{
		my $root = $self->guess_stab_root;
		# XXX ORACLE/PGSQL
		my $sth  = $self->prepare(
			q{
			select  distinct regexp_replace(port_name, '/.*$', '') as port_name
			 from   physical_port
			 where   device_id = ?
			   and   port_type = ?
	     -- order by NETWORK_STRINGS.NUMERIC_INTERFACE(port_name)
		}
		);
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
					-style =>
					  'width: 90%; border: 1px solid;'
				},
				$cgi->caption('Card'),
				$cgi->th( [ 'Port', '' ] ),
				$x
			);
		} else {
			"";
		}

	} else {
		my $q = build_physical_port_query( 'network', $parent );
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
				$cgi->caption('Switchport Connections'),
				$cgi->th( [ 'Port/Label', 'Other End', 'Port' ] ),
				$x
			);
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
	my $id    = "pport_agg_" . $hr->{_dbx('PORT_NAME')};
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
		$hr->{_dbx('PORT_NAME')}
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
	if($hr->{ _dbx('P1_PHYSICAL_LABEL') }) {
		$pname .= "/".$cgi->span({-class=>'port_label'},
			$hr->{ _dbx('P1_PHYSICAL_LABEL') });
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
				{ -deviceID => $devid, -pportKey => $pportid },
				$hr,
				'network',
				$divwrapid
			)
		),
		$cgi->td(
			$self->b_dropdown(
				{
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

	$self->setup_device_power($devid);

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
	     -- order by NETWORK_STRINGS.NUMERIC_INTERFACE(p1_power_interface_port)

	};
	my $sth = $self->prepare($q) || $self->return_db_err($self);

	$sth->bind_param(':devid', $devid) || $self->return_db_err($self);
	$sth->execute || $self->return_db_err($self);

	my $x = "";
	while ( my $hr = $sth->fetchrow_hashref ) {

		my $powerid   = $hr->{_dbx('P1_POWER_INTERFACE_PORT')};
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
					$hr->{_dbx('P1_POWER_INTERFACE_PORT')}
				)
			),
			$cgi->td(
				$self->powerport_device_magic(
					$hr, $divwrapid
				)
			),
			$cgi->td(
				$self->b_dropdown(
					{
						-divWrap => $divwrapid,
						-deviceid =>
						  $hr->{_dbx('P2_POWER_DEVICE_ID')}
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
			$cgi->th( [ 'Local Port', 'Other End', 'Port' ] ),
			$x
		);
	} else {
		print $cgi->div(
			{ -style => 'text-align: center; padding: 50px', },
			$cgi->em(
"This device type does not have a power configuration"
			)
		);
	}
}

sub powerport_device_magic {
	my ( $self, $hr, $portdivwrapid ) = @_;

	my $cgi = $self->cgi;

	my $id	= $hr->{_dbx('P1_POWER_INTERFACE_PORT')};
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
			-target => 'TOP',
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


	$self->setup_device_physical_ports($devid, 'serial');

	my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	my $q = build_physical_port_query('serial');
	my $sth = $dbh->prepare($q) || $self->return_db_err($dbh);
	$sth->execute( $devid, 'serial' ) || $self->return_db_err($sth);

	my $x = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		if (       defined( $hr->{_dbx('DATA_BITS')} )
			&& defined( $hr->{_dbx('STOP_BITS')} )
			&& defined( $hr->{_dbx('PARITY')} ) )
		{
			my $p = substr( $hr->{_dbx('PARITY')}, 0, 1 );
			$p =~ tr/a-z/A-Z/;
			$hr->{_dbx('SERIAL_PARAMS')} =
			  $hr->{_dbx('DATA_BITS')} . "-$p-" . $hr->{_dbx('STOP_BITS')};
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
					'Port',       'Baud',
					'Params',     'Flow Control'
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

	my $pportid   = $hr->{_dbx('P1_PHYSICAL_PORT_ID')};
	my $divwrapid = "div_p2_physical_port_id_$pportid";

	my $htmlid = "P1_PHYSICAL_PORT_ID_$pportid";

	my $pname = $hr->{_dbx('P1_PORT_NAME')};
	if($hr->{_dbx('P1_PHYSICAL_LABEL')}) {
		$pname .= "/".$cgi->span({-class=>'port_label'},
			$hr->{_dbx('P1_PHYSICAL_LABEL')});
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
				{ -deviceID => $devid, -pportKey => $pportid },
				$hr,
				'serial',
				$divwrapid
			)
		),
		$cgi->td(
			$self->b_dropdown(
				{
					-portLimit => 'serial',
					-divWrap   => $divwrapid,
					-deviceid  => $hr->{_dbx('P2_DEVICE_ID')}
				},
				$hr,
				'P2_PHYSICAL_PORT_ID',
				'P1_PHYSICAL_PORT_ID'
			)
		),
		$cgi->td(
			$self->b_dropdown( $hr, 'BAUD', 'P1_PHYSICAL_PORT_ID' )
		),
		$cgi->td(
			$self->b_nondbdropdown(
				$hr, 'SERIAL_PARAMS', 'P1_PHYSICAL_PORT_ID'
			)
		),
		$cgi->td(
			$self->b_dropdown(
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
		$l1c->{_dbx('LAYER1_CONNECTION_ID')} );

	if ( !$devid ) {
		my $pp = $self->get_physical_port($pportkey);
		$devid = $pp->{_dbx('DEVICE_ID')};
	}

	my $tableid = "table_pc_ppkey_" . $pportkey;

	my $backwards = 0;

	#
	# this happens when there's no physical path.  As such,
	#
	if ( ( !$path || ( !scalar @$path ) ) ) {
		my $startp =
		  $self->get_physical_port( $l1c->{_dbx('PHYSICAL_PORT1_ID')} );
		my $endp =
		  $self->get_physical_port( $l1c->{_dbx('PHYSICAL_PORT2_ID')} );

		if ( $startp->{_dbx('PHYSICAL_PORT_ID')} != $pportkey ) {
			$backwards = 1;
		}

		my $connpk = "PC_path_" . $startp->{_dbx('PHYSICAL_PORT_ID')};
		if ( !defined($row) ) {
			if ( $startp->{_dbx('PHYSICAL_PORT_ID')} != $pportkey ) {
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
							-backwards =>
							  $backwards,
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
							-backwards =>
							  $backwards,
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
		  "PC_path_" . $path->[0]->{_dbx('PC_P1_PHYSICAL_PORT_ID')};

		if ( $path && $path->[0]->{_dbx('PC_P1_DEVICE_ID')} != $devid ) {
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
						-deviceID => $devid,
						-pportKey => $pportkey,
						-choosable =>
						  ( $iter != $count ),
						-showAdd =>
						  ( $iter != $count ),
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
			  )

		}
	}

	# return value falls through
}

sub device_patch_ports {
	my ( $self, $devid ) = @_;

	my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	my $q = build_physical_port_conn_query('patchpanel');
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
			$cgi->th(
				[
					'Device',    'Port',
					'PatchPort', 'Device',
					'Port'
				]
			),
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
	if ( $hr->{_dbx('D1_DEVICE_NAME')} ) {
		$lhs = $cgi->a(
			{
				-href => "$root/device/device.pl?devid="
				  . $hr->{_dbx('D1_DEVICE_ID')},
				-target => 'TOP'
			},
			$hr->{_dbx('D1_DEVICE_NAME')}
		);
	}
	if ( $hr->{_dbx('D2_DEVICE_NAME')} ) {
		$rhs = $cgi->a(
			{
				-href => "$root/device/device.pl?devid="
				  . $hr->{_dbx('D2_DEVICE_ID')},
				-target => 'TOP'
			},
			$hr->{_dbx('D2_DEVICE_NAME')}
		);
	}

	$cgi->Tr(
		$cgi->td($lhs),
		$cgi->td( $hr->{_dbx('D1_PORT_NAME')} 
			? $hr->{_dbx('D1_PORT_NAME')} : "" ),
		$cgi->td( $cgi->b( $hr->{_dbx('PATCH_NAME')} ) ),
		$cgi->td($rhs),
		$cgi->td( $hr->{_dbx('D2_PORT_NAME')} 
			? $hr->{_dbx('D2_PORT_NAME')} : "" ),
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
			$pport = $hr->{_dbx("PC_P${side}_PHYSICAL_PORT_NAME")};
			$dev   = $hr->{_dbx("PC_P${side}_DEVICE_NAME")};
		} else {
			$pport = $hr->{_dbx("PORT_NAME")};
			my $d = $self->get_dev_from_devid( $hr->{_dbx('DEVICE_ID')} );
			$dev = $d->{_dbx('DEVICE_NAME')};
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
		if ( !$hr || !defined( $hr->{_dbx('PC_P1_PHYSICAL_PORT_ID')} ) ) {
			if ($backwards) {
				$pportside = 1;
			} else {
				$pportside = 2;
			}
		}

		my $dropp = {};
		$dropp->{-divWrap} = $divwrapid;
		if ( !$hr ) {
			my $cgiid = "PC_P${pportside}_PHYSICAL_PORT_ID_"
			  . $oep->{'-uniqID'};
			$dropp->{-id}   = $cgiid;
			$dropp->{-name} = $cgiid;
		} else {
			$dropp->{-deviceid} =
			  $hr->{_dbx("PC_P${pportside}_DEVICE_ID")};
		}

		$pport =
		  $self->b_dropdown( $dropp, $hr,
			"PC_P${pportside}_PHYSICAL_PORT_ID",
			'PC_P1_PHYSICAL_PORT_ID' );

	}

	my $hiddenid = "PhysPath_${pportkey}_row$row";

	my $myrowid =
	  ( defined($hr) ) ? $hr->{_dbx("PC_P1_PHYSICAL_PORT_ID")} : $uniqid;

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
		# $parentq .= qq{and regexp_matches(l1.port_name, ?)};
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
		  where	l1.device_id = ?
			and l1.port_type = ?
			$parentq
	     -- XXX order by NETWORK_STRINGS.NUMERIC_INTERFACE(l1.p1_port_name)
	};

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
		if ( exists( $params->{-backwards} ) && $params->{-backwards} )
		{
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
		$pdevid  = $hr->{_dbx("${prefix}P${side}_DEVICE_ID")};
		$pname   = $hr->{_dbx("${prefix}P${side}_DEVICE_NAME")};
		$pportid = $hr->{_dbx("${prefix}P1_PHYSICAL_PORT_ID")};
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
			-name => $pdnam,
			-id   => $pdnam,
			-size => 40,
			-onInput =>
"inputEvent_Search(this, $pdid, event, \"deviceForm\", function(){showPhysical_ports($pdid, $pdnam, \"$pportid\", \"$divwrapid\", \"$what\"$sidestuff)});",
			-onKeydown =>
"keyprocess_Search(this, $pdid, event, \"deviceForm\", function(){showPhysical_ports($pdid, $pdnam, \"$pportid\", \"$divwrapid\", \"$what\"$sidestuff)});",
			-onChange =>
"showPhysical_ports($pdid, $pdnam, \"$pportid\", \"$divwrapid\", \"$what\"$sidestuff);",
			-onBlur  => "hidePopup_Search($pdnam)",
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
			-target => 'TOP',
			id      => $what . "_devlink_$pportid",
			-href   => $devlink
		},
		">>"
	);
	if ( defined($hr) && defined( $hr->{_dbx('LAYER1_CONNECTION_ID')} ) ) {
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
				-label =>
				  'Add missing power ports from Device Type',
			)
		),
		$cgi->li(
			$cgi->checkbox(
				-name    => $addserid,
				-id      => $addserid,
				-checked => undef,
				-value   => 'off',
				-label => 'Add missing serial from Device Type',
			)
		),
		$cgi->li($cgi->checkbox(
				-name=> $addnetid,
				-id=> $addnetid,
				-checked => undef,
				-value => 'off',
				-label => 'Add missing switchports from Device Type',
		)),
	);

	my $dev;
	if ($devid) {
		$dev = $self->get_dev_from_devid($devid);
	}

	if ($dev) {
		my $tt = "";
		if ( $dev->{_dbx('DATA_INS_USER')} ) {
			$tt .= $cgi->Tr(
				$cgi->td("Inserted"),
				$cgi->td( $dev->{_dbx('DATA_INS_DATE')} ),
				$cgi->td( $dev->{_dbx('DATA_INS_USER')} )
			);
		}
		if ( $dev->{_dbx('DATA_UPD_USER')} ) {
			$tt .= $cgi->Tr(
				$cgi->td("Updated"),
				$cgi->td( $dev->{_dbx('DATA_UPD_DATE')} ),
				$cgi->td( $dev->{_dbx('DATA_UPD_USER')} )
			);
		}

		$rv .= $cgi->table($tt);
		undef $tt;
	}
	$rv;
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
				snb.netmask_bits as route_src_netmask_bits,
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
				inner join device ddev
					on ddev.device_id = dni.device_id
				left join netblock dnb
					on dni.netblock_id = dnb.netblock_id
		 where	sr.device_src_id = ?
	}
	);

	$sth->execute($devid) || $self->return_db_err($sth);

	my (%seen);

	my $tt = $cgi->th(
		[
			'Delete',  'Source address',
			"/",       "Bits",
			'Dest IP', 'Destination Device',
		]
	);
	while ( my $hr = $sth->fetchrow_hashref ) {
		$seen{      $hr->{_dbx('ROUTE_SRC_IP')} . "/"
			  . $hr->{_dbx('ROUTE_SRC_NETMASK_BITS')} } =
		  $hr->{_dbx('NETWORK_INTERFACE_ID')};
		$tt .= $self->build_existing_route_box($hr);
	}

	$tt .= $self->build_existing_route_box();    # add box

	my $oc = get_device_netblock_routes( $self, $devid, \%seen );
	if ( length($oc) ) {
		$oc = $cgi->h3( { -align => 'center' },
			"Routes for this Host's Netblocks" )
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

	my $del     = $cgi->b("ADD");
	my $intname = "";
	if ($hr) {
		my $id = $hr->{_dbx('STATIC_ROUTE_ID')};
		$del = $cgi->hidden(
			-name    => "STATIC_ROUTE_ID_$id",
			-default => $id
		  )
		  . $self->build_checkbox( $hr, "", 'rm_STATIC_ROUTE_ID',
			'STATIC_ROUTE_ID' );

		$intname = $cgi->td(
			{ -name => 'DEST_INT_' . $hr->{_dbx('STATIC_ROUTE_ID')} },
			$hr->{_dbx('DEST_DEVICE_NAME')} . ":"
			  . $hr->{_dbx('DEST_INTERFACE_NAME')}
		);
	}

	$cgi->Tr(
		$cgi->td(
			[
				$del,
				$self->b_textfield(
					{ -allow_ip0 => 1 },
					$hr,
					"ROUTE_SRC_IP",
					'STATIC_ROUTE_ID'
				),
				"/",
				$self->b_textfield(
					$hr,
					"ROUTE_SRC_NETMASK_BITS",
					'STATIC_ROUTE_ID'
				),
			]
		),
		$cgi->td(
			$self->b_textfield(
				$hr, "ROUTE_DEST_IP", 'STATIC_ROUTE_ID'
			),
		),
		$intname,
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
			snb.netmask_bits as source_block_bits,
			ni.netblock_id as destination_netblock_id,
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
				on net_manip.inet_base(rnb.ip_address, rnb.netmask_bits) =
					tnb.ip_address
			inner join network_interface ni
				on rnb.netblock_id = ni.netblock_id
			inner join network_interface dni
				on dni.network_interface_id = srt.network_interface_dst_id
			inner join netblock dnb
				on dni.netblock_id = dnb.netblock_id
			inner join device ddev
				on dni.device_id = ddev.device_Id
		where
			tnb.netmask_bits = rnb.netmask_bits
		  and   ni.device_id = ?
	}
	);

	my $tally = 0;
	$sth->execute($devid) || $self->return_db_err($sth);
	my $tt = $cgi->th( [ "Add", "Route", "Dest IP", "Dest Interface", ] );
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $x =
		  $hr->{_dbx('SOURCE_BLOCK_IP')} . "/" . $hr->{-dbx('SOURCE_BLOCK_BITS')};
		if (
			!(
				defined( $seen->{$x} )
				&& $seen->{$x} == $hr->{_dbx('NETWORK_INTERFACE_ID')}
			)
		  )
		{
			$tally++;
			$tt .= $cgi->Tr(
				$cgi->td(
					$self->build_checkbox(
						$hr,
						"",
						'add_STATIC_ROUTE_TEMPLATE_ID',
						'STATIC_ROUTE_TEMPLATE_ID'
					)
				),
				$cgi->td($x),
				$cgi->td( $hr->{_dbx('DESTINATION_IP')} ),
				$cgi->td(
					$hr->{_dbx('DEVICE_NAME')}, ":",
					$hr->{_dbx('NETWORK_INTERFACE_NAME')}
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

	my $img;

	my $collapse = $cgi->param('collapse') || 'no';
	if ( $collapse eq 'yes' ) {
		my $n = new CGI($cgi);
		$n->param( 'collapse', 'no' );
		$img = $cgi->a( { -href => $n->self_url },
			$cgi->img( { -src => "../stabcons/collapse.jpg" } ) );
	} else {
		my $n = new CGI($cgi);
		$n->param( 'collapse', 'yes' );
		$img = $cgi->a( { -href => $n->self_url },
			$cgi->img( { -src => "../stabcons/expand.jpg" } ) );
	}

	$collapse = 'yes';    # [XXX] need to figure out how to do the
	$img      = '';      # [XXX] collapsing better w/ the tabs!

	my $rv =
	  $cgi->h3( { -align => 'center' }, $img, "Layer 3 Interfaces", $img );

	my $lastid;
	my $q = qq{
		select	ni.network_interface_id,
			ni.network_interface_name,
			ni.network_interface_type,
			ni.is_interface_up,
			ni.mac_addr,
			ni.provides_nat,
			ni.should_manage,
			ni.should_monitor,
			ni.provides_dhcp,
			ni.description,
			net_manip.inet_dbtop(nb.ip_address) as IP,
			dns.dns_record_id,
			dns.dns_name,
			dns.dns_domain_id,
			dom.soa_name,
			net_manip.inet_dbtop(pnb.ip_address) as parent_IP,
			nb.parent_netblock_id
		  from	network_interface ni
			left join netblock nb using (netblock_id)
			left join dns_record dns using (netblock_id)
			left join dns_domain dom using (dns_domain_id)
			left join netblock pnb on
				nb.parent_netblock_id = pnb.netblock_id
		where ni.device_id = ?
		order by ni.network_interface_name, ni.network_interface_id,
			dns.should_generate_ptr desc
	};

	my $sth = $self->prepare($q) || $self->return_db_err($dbh);
	$sth->execute($devid) || $self->return_db_err($sth);


	while ( my ($values) = $sth->fetchrow_hashref ) {
		last if ( !defined($values) );

		# XXX: These need to be handled!
		next
		  if (     $lastid
			&& $lastid == $values->{_dbx('NETWORK_INTERFACE_ID')} );
		if ( $collapse eq 'yes' ) {
			$rv .= $self->build_collapsed_if_box( $values, $devid );
			# XXX need to kill secondary interfaces everywhere!
			#$rv .=
			#  $self->build_secondary_collapsed( $values, $devid );
		} else {
			$rv .= $self->build_interface_box( $values, $devid );
		}
		$lastid = $values->{_dbx('NETWORK_INTERFACE_ID')};
	}

	if ( $collapse eq 'yes' ) {
		my $collist = [ 'Del', 'Name', 'IP', 'DNS', 'Type', 'More'];
		$rv =
		  $cgi->table({-class => 'interfacetable'},
			$cgi->th( $collist ), $rv,
				$cgi->Tr({-class => 'intableheader'},
					$cgi->td({-colspan=> $#{$collist} + 1}, 
					"Add Interface")),
				$self->build_collapsed_if_box( undef, $devid ));
	} else {
		$rv .= $self->build_interface_box( undef, $devid );
	}

	$sth->finish;
	$rv .= "\n";
	$rv;
}

sub build_secondary_collapsed {
	my ( $self, $netint, $devid ) = @_;

	my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	my $rv = "";
	if ( defined($netint) ) {
		my $q = qq{
			select
					secondary_netblock_id,
					network_interface_id,
					net_manip.inet_dbtop(nb.ip_address) as IP,
					snb.mac_addr,
					-- XXX to_char(snb.mac_addr, 'XXXXXXXXXXXX') as mac_addr,
					dns.dns_record_id,
					dns.dns_name,
					dns.dns_domain_id
			 from	secondary_netblock snb
					inner join netblock nb on snb.netblock_id = nb.netblock_id
					left join dns_record dns
						on dns.netblock_id = snb.netblock_id
					left join dns_domain dom
						on dom.dns_domain_id = dns.dns_domain_id
			where	snb.network_interface_id = ?
		};
		my $sth = $self->prepare($q) || $self->return_db_err($dbh);
		$sth->execute( $netint->{_dbx('NETWORK_INTERFACE_ID')} )
		  || $self->return_db_err($sth);
		while ( my $hr = $sth->fetchrow_hashref ) {
			$hr->{_dbx('MAC_ADDR')} =
			  mac_int_to_text( $hr->{_dbx('MAC_ADDR')} );
			$rv .= $self->build_collapsed_if_box( $hr, $devid );
		}
		$sth->finish;
	}

	$rv;
}

sub build_collapsed_if_box {
	my ( $self, $values, $devid ) = @_;

	my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	my $defchecked = undef;

	my $action_url = "write/update_interface.pl";
	my $hidden     = "";
	my $showxtraclass = "irrelevant";

	my $rowitems = {};

	my $delbox = "";

	if ( !defined($values) ) {
		$rowitems->{'class'} = "intadd";
		$defchecked = 'on';
		$action_url = "write/add_interface.pl";
		$hidden     = $cgi->hidden(
			-name    => 'DEVICE_ID',
			-default => $devid
		);
	} else {
		$hidden = $cgi->hidden(
			-class => 'recordid',
			-name => 'NETWORK_INTERFACE_ID_'
			  . $values->{_dbx('NETWORK_INTERFACE_ID')},
			-id => 'NETWORK_INTERFACE_ID_'
			  . $values->{_dbx('NETWORK_INTERFACE_ID')},
			-default => $values->{_dbx('NETWORK_INTERFACE_ID')}
		);
		$delbox = $self->build_checkbox($values, "", 
			"rm_NETWORK_INTERFACE", 'NETWORK_INTERFACE_ID');
	}

	$self->textfield_sizing(undef);


	my $pk = "NETWORK_INTERFACE_ID";
	my $intname =
		$self->b_textfield( $values, 'NETWORK_INTERFACE_NAME', $pk);

	if ( defined( $values->{_dbx('SECONDARY_NETBLOCK_ID')} ) ) {
		my @pk = ( 'NETWORK_INTERFACE_ID', 'SECONDARY_NETBLOCK_ID' );
		$pk = \@pk;
	}

	my $dns = "";
	if($values && $values->{ _dbx('DNS_RECORD_ID') } ) {
		my $dot = "";
		if($values->{ _dbx('DNS_NAME')} ) {
			$dot = ".";
		} 
		$dns = $cgi->a({ -class => 'intdns',
			-target => "dns_domain_id". $values->{ _dbx('DNS_DOMAIN_ID') },
			-href => '../dns/?dnsdomainid='.$values->{ _dbx('DNS_DOMAIN_ID') },
			}, 
				$values->{ _dbx('DNS_NAME') }.$dot.$values->{ _dbx('SOA_NAME') },
			).
			$cgi->img({-src=> "../stabcons/e.gif", 
				-alt=>"Edit", 
				-title=>'Edit',
				-class=>'intdnsedit',
			}),
	} else {
		$dns =
			$self->b_textfield( $values, "DNS_NAME", $pk ).
			$self->b_dropdown( $values, "DNS_DOMAIN_ID", $pk );
	}

	# Build a table for Extras
	my $xbox = 
		$cgi->table({-class=> "intmoretable $showxtraclass"}, 
		  	$self->build_tr( {}, $values, "b_textfield", "Description",
				'DESCRIPTION', 'NETWORK_INTERFACE_ID' ),
			$cgi->Tr($cgi->td($self->build_checkbox( $values, "Up", 
				'IS_INTERFACE_UP', 'NETWORK_INTERFACE_ID', $defchecked))),
			$cgi->Tr($cgi->td($self->build_checkbox( $values, "Should Manage",
				'SHOULD_MANAGE', 'NETWORK_INTERFACE_ID', $defchecked ))),
			$cgi->Tr($cgi->td($self->build_checkbox( $values, "Should Monitor",
				'SHOULD_MONITOR', 'NETWORK_INTERFACE_ID', $defchecked ))),
			$cgi->Tr($cgi->td($self->build_checkbox( $values, "NATing", 
				'PROVIDES_NAT', 'NETWORK_INTERFACE_ID' ))),
			$cgi->Tr($cgi->td($self->build_checkbox( $values, "DHCP",
				'PROVIDES_DHCP', 'NETWORK_INTERFACE_ID'))),
			(length($delbox))?
				$cgi->Tr($cgi->td($self->build_checkbox( $values, 
					"Do Not Free IPs on Removal",
					'rm_NET_INT_preserveips', 'NETWORK_INTERFACE_ID')))
				:"",
		);

	# Make the extras something that can be clicked on and expanded
	$xbox = $cgi->a({-href=>'#', -class => 'showmore'}, "More"). $xbox;

	my $rv = $cgi->Tr( $rowitems,
		$cgi->td( $hidden, $delbox),
		$cgi->td( $intname ),
		$cgi->td( $self->b_textfield( $values, "IP",       $pk ) ),
		$cgi->td( $dns),
		$cgi->td( $self->b_dropdown($values, 'NETWORK_INTERFACE_TYPE', $pk) ),
		$cgi->td( $xbox ),
	);
	$self->textfield_sizing(1);
	$rv;
}

sub build_interface_box {
	my ( $self, $values, $devid ) = @_;

	my $dbh = $self->dbh || die "Could not create dbh";
	my $cgi = $self->cgi || die "Could not create cgi";

	my $defchecked = 'on';

	my $xbox = $self->build_checkbox( $values, "Up", 'IS_INTERFACE_UP',
		'NETWORK_INTERFACE_ID', $defchecked );
	$xbox .= $self->build_checkbox( $values, "NATing", 'PROVIDES_NAT',
		'NETWORK_INTERFACE_ID' );
	$xbox .= $self->build_checkbox( $values, "Should Manage",
		'SHOULD_MANAGE', 'NETWORK_INTERFACE_ID', $defchecked );
	$xbox .= $self->build_checkbox( $values, "Should Monitor",
		'SHOULD_MONITOR', 'NETWORK_INTERFACE_ID', $defchecked );

	$xbox .= $cgi->hr . "\n";

	my $pnk = "";
	if ( defined($values) ) {
		$pnk = "_" . $values->{_dbx('NETWORK_INTERFACE_ID')};
	}
	my $delem = "";
	if ( defined($values) ) {

    #	$delem .= $cgi->div($cgi->submit({-align => 'center', -valign => 'bottom',
    #			-name=>'del_free_ip'.$pnk,
    #			-label=>'Delete/Free All IPs'}));
    #	$delem .= $cgi->div($cgi->submit({-align => 'center', -valign => 'bottom',
    #			-name=>'del_reserve_ip'.$pnk,
    #			-label=>'Delete/Rsv All IPs'}));
		$delem .= $cgi->span( { -align => 'center' },
			$cgi->b( { -align => 'center' }, "Delete Interface" ) );

				# [XXX ] - need to make the class name in both -class and
				# uncheck()
				my $classname =
				  'delete_int_class_INT_' . $values->{_dbx('NETWORK_INTERFACE_ID')};
				$delem .= $cgi->div(
					$cgi->checkbox(
						-class => $classname,
						-id    => "rm_free_INTERFACE_"
						  . $values->{_dbx('NETWORK_INTERFACE_ID')},
						,
						-name => "rm_free_INTERFACE_"
						  . $values->{_dbx('NETWORK_INTERFACE_ID')},
						,
						-label => 'Delete/Free IPs',
						-onClick =>
		"uncheck(\"rm_free_INTERFACE_$values->{_dbx('NETWORK_INTERFACE_ID')}\",\"$classname\");"
					)
				);
				$delem .= $cgi->div(
					$cgi->checkbox(
						-class => $classname,
						-id    => "rm_rsv_INTERFACE_"
						  . $values->{_dbx('NETWORK_INTERFACE_ID')},
						,
						-name => "rm_rsv_INTERFACE_"
						  . $values->{_dbx('NETWORK_INTERFACE_ID')},
				,
				-label => 'Delete/Reserve IPs',
				-onClick =>
"uncheck(\"rm_rsv_INTERFACE_$values->{_dbx('NETWORK_INTERFACE_ID')}\", \"$classname\");"
			)
		);
	}

	$xbox .= $delem;

	my $ltd;
	$ltd = $cgi->start_table . "\n";

       #
       # The ability to change the interface name is not in the front end, but
       # the backend supports it.  Changing this to just be the else case allows
       # it to be edited in all cases.  Need to contemplate if it should be
       # changable
       #
	if ( defined($values) ) {
		$ltd .=
		  $self->build_tr( {}, $values, "b_textfield", "Iface",
			'NETWORK_INTERFACE_NAME', 'NETWORK_INTERFACE_ID' );

# $ltd .= $cgi->hidden('NETWORK_INTERFACE_NAME_'.$values->{_dbx('NETWORK_INTERFACE_ID')}, $values->{_dbx('NETWORK_INTERFACE_NAME')});
	} else {
		$ltd .=
		  $self->build_tr( {}, $values, "b_textfield", "Iface",
			'NETWORK_INTERFACE_NAME', 'NETWORK_INTERFACE_ID' );
	}
	$ltd .= $self->build_tr( $values, "b_textfield", "MAC", 'MAC_ADDR',
		'NETWORK_INTERFACE_ID' );
	$self->textfield_sizing(0);
	$ltd .= $self->build_tr( $values, "b_textfield", "IP", 'IP',
		'NETWORK_INTERFACE_ID' );
	$ltd .= $cgi->Tr(
		$cgi->td( { -align => 'right' }, $cgi->b("DNS:") ),
		$cgi->td(
			$self->b_textfield(
				$values, 'DNS_NAME', 'NETWORK_INTERFACE_ID'
			),
			$self->b_dropdown(
				$values, 'DNS_DOMAIN_ID',
				'NETWORK_INTERFACE_ID'
			)
		)
	);
	$self->textfield_sizing(1);
	$ltd .= $self->build_tr( $values, "b_dropdown", "Type",
		'NETWORK_INTERFACE_TYPE', 'NETWORK_INTERFACE_ID' );

	if ( defined($values) ) {
		my $dns = build_dns_rr_table( $self, $values );
		if ($dns) {
			$ltd .= $cgi->Tr(
				{
					-style => 'background: lightblue',
					-align => 'center'
				},
				$cgi->td( { -colspan => 2 }, $dns )
			);
			undef $dns;
		}
		$ltd .= $cgi->Tr(
			$cgi->td(
				{ -colspan => 2 },
				$self->build_secondary_netblocks_table($values)
			)
		);
	}
	$ltd .= $cgi->end_table . "\n";

	my $rv = "";

	my $action_url = "write/update_interface.pl";
	my $hidden     = "";
	if ( !defined($values) ) {
		$rv .=
		  $cgi->h4( { -align => 'center' }, 'Add interface' ) . "\n";
		$action_url = "write/add_interface.pl";
		$hidden     = $cgi->hidden(
			-name    => 'DEVICE_ID',
			-default => $devid
		);
	} else {
		$hidden = $cgi->hidden(
			-name => 'NETWORK_INTERFACE_ID_'
			  . $values->{_dbx('NETWORK_INTERFACE_ID')},
			-default => $values->{_dbx('NETWORK_INTERFACE_ID')}
		);
	}

	my %args = (
		-border => 1,
		-width  => '100%',
	);

	if ( defined($values) && $values->{_dbx('IS_PRIMARY')} eq 'Y' ) {
		$args{-class} = 'primaryinterface';
	}

	$rv .= $cgi->table(
		\%args,
		$cgi->Tr(
			$hidden,
			$cgi->td( { -width => '85%' }, $ltd ),
			$cgi->td(
				{
					-width  => '15%',
					-align  => 'left',
					-valign => 'top'
				},
				$xbox
			),
		)
	);
	undef $xbox;
	undef $ltd;
	$rv;
}

sub build_secondary_netblock_Tr {
	my ( $self, $values, $keys ) = @_;
	my $cgi = $self->cgi || die "Could not create cgi";
	my $dbh = $self->dbh || die "Could not create dbh";

	my $buttonbox = "";
	my $hidden    = "";

	my $attribhash = {};

	my $nint = $values->{_dbx('NETWORK_INTERFACE_ID')};
	my $pnk  = $values->{_dbx('SECONDARY_NETBLOCK_ID')};

	if ( defined($pnk) ) {
		$buttonbox .= $cgi->submit(
			{
				-align  => 'center',
				-valign => 'bottom',
				-name   => "del_free_snb_ip_${nint}_$pnk",
				-label  => 'Delete/Free IP'
			}
		  )
		  . $cgi->submit(
			{
				-align  => 'center',
				-valign => 'bottom',
				-name   => "del_reserve_snb_ip_${nint}_$pnk",
				-label  => 'Delete/Rsv IP'
			}
		  ),
		  $hidden = $cgi->hidden(
			-name => 'SECONDARY_NETBLOCK_ID_'
			  . $values->{_dbx('NETWORK_INTERFACE_ID')} . "_"
			  . $pnk,
			-default => $pnk
		  );
	} else {
		$attribhash->{-style} = 'background: lightgrey';
	}

	my $rv = $cgi->Tr(
		$attribhash,
		$cgi->td(
			$hidden,
			$cgi->span(
				$cgi->b("IP:"),
				$self->b_textfield( $values, 'IP', $keys )
			),
			$cgi->span(
				$cgi->b("MAC:"),
				$self->b_textfield(
					$values, 'MAC_ADDR', $keys
				)
			),
			$cgi->span(
				$cgi->b("DESC:"),
				$self->b_textfield(
					$values, 'DESCRIPTION', $keys
				)
			),
			$cgi->span(
				$cgi->b("DNS:"),
				$self->b_textfield(
					$values, 'DNS_NAME', $keys
				),
				$self->b_dropdown(
					$values, 'DNS_DOMAIN_ID', $keys
				),
			),
			$buttonbox
		)
	);
	undef $buttonbox;
	$rv;
}

sub build_dns_rr_table {
	my ( $self, $values ) = @_;

	return undef if ( !$values );

	my $cgi = $self->cgi || die "Could not create cgi";
	my $dbh = $self->dbh || die "Could not create dbh";

	my $q = qq{
		select	dns.dns_record_id, dns.dns_name,
				dns.dns_domain_id, dom.soa_name
		  from	dns_record dns
				inner join dns_domain dom
					on dom.dns_domain_id = dns.dns_domain_id
				inner join network_interface ni
					on dns.netblock_id = ni.netblock_id
		 where	ni.network_interface_id = ?
		  and	dns.dns_record_id != ?
	};
	my $sth = $self->prepare($q) || $self->return_db_err($dbh);

	my $rrt = "";

	$sth->execute( $values->{_dbx('NETWORK_INTERFACE_ID')},
		$values->{_dbx('DNS_RECORD_ID')} );
	while ( my $hr = $sth->fetchrow_hashref ) {
		$rrt .= $cgi->Tr(
			$cgi->td( $hr->{_dbx('DNS_NAME')} ),
			$cgi->td( $hr->{_dbx('SOA_NAME')} ),
		);
	}
	$sth->finish;

	if ( length($rrt) ) {
		return $cgi->div( { -align => 'center' },
			$cgi->b('DNS Round Robin Records') )
		  . $cgi->table($rrt);
	}
	undef;
}

sub build_secondary_netblocks_table {
	my ( $self, $values ) = @_;
	my $cgi = $self->cgi || die "Could not create cgi";
	my $dbh = $self->dbh || die "Could not create dbh";

	my $rv = "";

	my @keyfields = ( 'NETWORK_INTERFACE_ID', 'SECONDARY_NETBLOCK_ID' );

	my %novals;
	if ( defined($values) ) {
		my $q = qq{
			select	snb.SECONDARY_NETBLOCK_ID, snb.NETWORK_INTERFACE_ID,
					-- XXX to_char(snb.mac_addr, 'XXXXXXXXXXXX') as mac_addr,
					mac_addr,
					snb.DESCRIPTION,
					net_manip.inet_dbtop(nb.ip_address) as IP,
					dns.dns_name,
					dns.dns_domain_id
			  from	secondary_netblock snb
					left join netblock nb on nb.netblock_id = snb.netblock_id
					left join dns_record dns
						on dns.netblock_id = snb.netblock_id
			where
					snb.network_interface_id = ?
			order by description
		};
		my $sth = $self->prepare($q) || $self->return_db_err($dbh);
		$sth->execute( $values->{_dbx('NETWORK_INTERFACE_ID')} )
		  || $self->return_db_err($sth);
		while ( my $hr = $sth->fetchrow_hashref ) {
			$hr->{_dbx('MAC_ADDR')} =
			  mac_int_to_text( $hr->{_dbx('MAC_ADDR')} );
			$rv .= $self->build_secondary_netblock_Tr( $hr,
				\@keyfields );
		}
		$sth->finish;
		$novals{'NETWORK_INTERFACE_ID'} =
		  $values->{_dbx('NETWORK_INTERFACE_ID')};
	}

	$rv = $cgi->table( { -border => 1 }, $rv );

	undef %novals;
	$rv;
}

sub mac_int_to_text {
	my ($in) = @_;

	my $mac;
	if ( defined($in) ) {
		$mac = "000000000000";
		$in =~ s/\s+//g;
		$mac = substr( $mac, 0, length($mac) - length($in) );
		$mac .= $in;
		$mac =~ s/(\S\S)/$1:/g;
		$mac =~ s/:$//;
	}
	$mac;
}

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
		my $locid = "LOCATION_ID_" . $hr->{_dbx('LOCATION_ID')};
		$hidden = $cgi->hidden(
			-name  => $locid,
			-id    => $locid,
			-value => $hr->{_dbx('LOCATION_ID')}
		);
	}

	my $root = $self->guess_stab_root;

	my ( $rackdivid, $racksiteid );
	my $racklink = "";
	if ( $hr && exists( $hr->{_dbx('LOCATION_RACK_ID')} ) ) {
		my $rack =
		  $self->get_rack_from_rackid( $hr->{_dbx('LOCATION_RACK_ID')} );
		$racklink .= $cgi->Tr(
			$cgi->td(
				{ -colspan => 2, -align => 'center' },
				$cgi->a(
					{
						-align  => 'center',
						-target => 'TOP',
						-href   => $root
						  . "/sites/racks/?RACK_ID="
						  . $hr->{_dbx('LOCATION_RACK_ID')}
					},
qq{Rack $rack->{_dbx('ROOM')} : $rack->{_dbx('RACK_ROW')} - $rack->{_dbx('RACK_NAME')}}
				)
			)
		);
		$rackdivid  = "rack_div_" . $hr->{_dbx('LOCATION_ID')};
		$racksiteid = "RACK_SITE_CODE_" . $hr->{_dbx('LOCATION_ID')};
	} else {
		$rackdivid  = "rack_div";
		$racksiteid = "RACK_SITE_CODE";
	}

	my $locid = ( $hr && $hr->{_dbx('LOCATION_ID')} ) ? $hr->{_dbx('LOCATION_ID')} : undef;

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
			'LOCATION_ID'
		),
		$self->build_tr(
			{ -divWrap => $rackdivid, -dolinkUpdate => 'rack' },
			$hr,
			"b_dropdown",
			"Rack",
			'LOCATION_RACK_ID',
			'LOCATION_ID'
		),
		$self->build_tr(
			$hr,		    "b_textfield",
			"U Offset of Top Left", 'LOCATION_RU_OFFSET',
			'LOCATION_ID'
		),
		$self->build_tr(
			$hr,	 "b_nondbdropdown",
			"Rack Side", 'LOCATION_RACK_SIDE',
			'LOCATION_ID'
		),
		$self->build_tr(
			{ -mark => 'optional' }, $hr,
			"b_textfield",	       "Horizontal Offset",
			'LOCATION_INTER_DEV_OFFSET', 'LOCATION_ID'
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
	my($self, $devid) = @_;

	my $cgi = $self->cgi;

	my $rv = "";

	my $sth = $self->prepare(qq{
		select	dc.device_collection_id, dc.device_collection_name
 		  from	device_collection dc
				inner join device_collection_device dcm
					on dc.device_collection_id = dcm.device_collection_id
		 where	dc.device_collection_type = 'applicense'
		   and	dcm.device_id = ?
	}) || $self->return_db_err;

	$sth->execute($devid) || $self->return_db_err;

	my $tt = "";
	while(my $hr = $sth->fetchrow_hashref) {
		my $delid = "rm_Lic_DEVICE_COLLECTION_". 
			$hr->{_dbx('DEVICE_COLLECTION_ID')};
		my $rm .= $cgi->checkbox(
			-name=> $delid,
			-id=> $delid,
			-checked => undef,
			-value => 'on',
			-label => 'Delete',
		);
		$tt .= $cgi->Tr($cgi->td( [
			$rm,
			$hr->{_dbx('NAME')},
		]));
	}

	my $addid = "tr_lic_devid_". $devid;
	$rv = $cgi->table({-align => 'center', border=>1},
		$cgi->th(['Remove', 'License Type']),
		$tt,
		$cgi->Tr({-id => $addid},
			$cgi->td({-colspan => 2, style=>'text-align: center;'},
				$cgi->a({-onClick => "add_License(this, \"$addid\", $devid)",
						-href=>"javascript:void(null)"},
					"Add a License"),
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
	});

	$sth->execute($devid) || $self->return_db_err($sth);

	my ( @options, @set, %labels );

	my $name = "appgroup";

	my $resetlink = "";
	my $warnmsg = "";
	my $indicatetab = "";
	if($devid) {
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
		$resetlink = $cgi->div({-style => 'text-align: center;'},
			$cgi->a({
				-href=>"javascript:void(null)",
				-onClick => qq{ShowDevTab("AppGroup", "$devid", "force")},
			},
		"(reset tab)"));
		$indicatetab = $cgi->hidden("has_appgroup_tab_$devid", $devid);
		$name = 'appgroup_'.$devid;
	}


	my $tt = "";
	while ( my $hr = $sth->fetchrow_hashref ) {
		next if ( $hr->{_dbx('ROLE_IS_LEAF')} eq 'N' );
		my $printable = $hr->{_dbx('ROLE_PATH')} . '/' . $hr->{_dbx('ROLE_NAME')};
		$printable =~ s,^/,,;
		push( @options, $hr->{_dbx('ROLE_ID')} );
		push( @set,     $hr->{_dbx('ROLE_ID')} )
			if ( $hr->{_dbx('DEVICE_ID')} );
		$labels{ $hr->{_dbx('ROLE_ID')} } = $printable;
	}
	my $x = $cgi->h3({-align=>'center'}, 'Application Groupings').
		$cgi->div({-style => 'text-align: center'},
			$warnmsg).
		$indicatetab.
		$cgi->div({-style => 'text-align: center'},
			$cgi->scrolling_list(
				-name => $name,
				-values=> \@options,
				-default => \@set,
				-labels => \%labels,
				-size => 10,
				-multiple => 'true'
			)
		).
			$cgi->div({-style => 'text-align: center;'},
				$cgi->a({ -href=>"apps/", -target => 'TOP', },
					"(explore apps)").
			$resetlink
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
