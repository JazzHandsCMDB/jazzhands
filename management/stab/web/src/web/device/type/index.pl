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

exit do_device_type();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

sub do_device_type {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $devtypid = $stab->cgi_parse_param('DEVICE_TYPE_ID');

	# $devtypid = 47;
	if ( defined($devtypid) && $devtypid ) {
		do_device_type_power( $stab, $devtypid );
		return;
	}

	print $cgi->header('text/html');
	print $stab->start_html(
		{
			-title      => "Device Type",
			-javascript => 'devicetype',
		}
	);

	print $cgi->start_form(
		{ -method => 'POST', -action => 'dtsearch.pl' } );
	print $cgi->div(
		{ -align => 'center' },
		$cgi->h3( { -align => 'center' }, 'Pick a device type:' ),
		$stab->b_dropdown( undef, 'DEVICE_TYPE_ID', undef, 1 ),
		$cgi->submit
	);
	print $cgi->end_form;

	print $cgi->hr;
	print $cgi->h2( { -align => 'center' }, "Add a New Device Type" );
	device_type_power_form($stab);

	print $cgi->end_html;
	undef $stab;
	0;
}

sub do_device_type_power {
	my ( $stab, $devtypid ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my ( $dt, $model );
	my $q = qq{
		select	dt.DEVICE_TYPE_ID, c.company_name,
			-- p.address as partner_address, XXX
			dt.company_id, dt.model,
			dt.config_fetch_type, dt.rack_units,
			dt.description,
			dt.has_802_3_interface,
			dt.has_802_11_interface,
			dt.snmp_capable
		  from	device_type dt
			inner join company c
				on dt.company_id = c.company_id
		where	dt.device_type_id = ?
	};

	my $sth = $dbh->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($devtypid) || $stab->return_db_err($sth);

	$dt = $sth->fetchrow_hashref;

	if ( !$dt ) {
		return $stab->error_return("Unknown Device Type");
	}

	$model = $dt->{ _dbx('COMPANY_NAME') } . " " . $dt->{ _dbx('MODEL') };

	print $cgi->header('text/html');
	print $stab->start_html(
		{
			-title      => "Device Type $model",
			-javascript => 'devicetype',
		}
	  ),
	  "\n";

	device_type_power_form( $stab, $devtypid, $dt );

	print $cgi->end_html;
}

sub device_type_power_form {
	my ( $stab, $devtypid, $dt ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $leftbox = $cgi->table(
		$stab->build_tr(
			$dt,      "b_dropdown",
			"Vendor", 'COMPANY_ID',
			'DEVICE_TYPE_ID'
		),
		$stab->build_tr(
			$dt,           "b_dropdown",
			"Server Arch", 'PROCESSOR_ARCHITECTURE',
			'DEVICE_TYPE_ID'
		),
		$stab->build_tr(
			$dt,     "b_textfield",
			"Model", 'MODEL',
			'DEVICE_TYPE_ID'
		),
		$stab->build_tr(
			$dt,           "b_textfield",
			"Description", 'DESCRIPTION',
			'DEVICE_TYPE_ID'
		),
		$stab->build_tr(
			$dt,          "b_textfield",
			"RancidType", 'CONFIG_FETCH_TYPE',
			'DEVICE_TYPE_ID'
		),
	);

	my $rightbox = $cgi->table(
		$cgi->Tr(
			$cgi->td(
				{ -colspan => 2 },
				$stab->build_checkbox(
					$dt,            "CanSNMP",
					'SNMP_CAPABLE', 'DEVICE_TYPE_ID'
				),
				$stab->build_checkbox(
					$dt,
					"802.3",
					'HAS_802_3_INTERFACE',
					'DEVICE_TYPE_ID'
				),
				$stab->build_checkbox(
					$dt,
					"802.11",
					'HAS_802_11_INTERFACE',
					'DEVICE_TYPE_ID'
				),
			)
		),
		$cgi->Tr( $cgi->td( { -colspan => 2 }, $cgi->hr ) ),
		$stab->build_tr(
			$dt,          "b_textfield",
			"Rack Units", 'RACK_UNITS',
			'DEVICE_TYPE_ID'
		),
	);

	my $powerbox = build_power_box( $stab, $devtypid );
	my $serialbox  = build_physical_port_box( $stab, $devtypid, 'serial' );
	my $networkbox = build_physical_port_box( $stab, $devtypid, 'network' );

	my $poweraddbox = build_power_add_box( $stab, $devtypid );
	my $serialaddbox =
	  build_physical_port_add_box( $stab, $devtypid, 'serial' );
	my $networkaddbox =
	  build_physical_port_add_box( $stab, $devtypid, 'network' );

	my $offparams = { -align => 'center' };

	my $addparams = {
		-style => 'background: lightgrey',
		-align => 'center'
	};

	if ( !defined($powerbox) || !length($powerbox) ) {
		$powerbox = "no power configuration";
	}

	if ( !defined($serialbox) || !length($serialbox) ) {
		$serialbox = "no serial configuration";
	}

	if ( !defined($networkbox) || !length($networkbox) ) {
		$serialbox = "no switchport configuration";
	}

	my $hdrparam = {
		-align   => 'center',
		-colspan => 2,
		-style   => 'background: lightyellow'
	};

	if ($dt) {
		my $powerrow;
		if ( defined($powerbox) && length($powerbox) ) {
			$powerbox    = $cgi->td( $offparams, $powerbox );
			$poweraddbox = $cgi->td( $addparams, $poweraddbox );
			$powerrow = $cgi->Tr( $powerbox, $poweraddbox );
		} else {
			$poweraddbox =
			  $cgi->td( { -colspan => 2 }, $poweraddbox );
			$powerrow = $cgi->Tr( $addparams, $poweraddbox );
		}

		my $serialrow;
		if ( defined($serialbox) && length($serialbox) ) {
			$serialbox    = $cgi->td( $offparams, $serialbox );
			$serialaddbox = $cgi->td( $addparams, $serialaddbox );
			$serialrow = $cgi->Tr( $serialbox, $serialaddbox );
		} else {
			$serialaddbox =
			  $cgi->td( { -colspan => 2 }, $serialaddbox );
			$serialrow = $cgi->Tr( $addparams, $serialaddbox );
		}

		my $networkrow;
		if ( defined($networkbox) && length($networkbox) ) {
			$networkbox    = $cgi->td( $offparams, $networkbox );
			$networkaddbox = $cgi->td( $addparams, $networkaddbox );
			$networkrow = $cgi->Tr( $networkbox, $networkaddbox );
		} else {
			$networkaddbox =
			  $cgi->td( { -colspan => 2 }, $networkaddbox );
			$networkrow = $cgi->Tr( $addparams, $networkaddbox );
		}

		print $cgi->start_form(
			{ -method => 'POST', -action => 'write/updatedt.pl' } ),
		  $cgi->table(
			{ -align => 'center', -width => '100%', -border => 1 },
			$cgi->Tr( $cgi->td( $hdrparam, "General" ) ),
			$cgi->Tr( $cgi->td($leftbox), $cgi->td($rightbox) ),
			$cgi->Tr(
				$cgi->td( $hdrparam, "Power Port Template" )
			),
			$powerrow,
			$cgi->Tr(
				$cgi->td( $hdrparam, "Serial Port Template" )
			),
			$serialrow,
			$cgi->Tr(
				$cgi->td( $hdrparam, "Switch Port Template" )
			),
			$networkrow,
			$cgi->Tr(
				$cgi->td(
					$hdrparam,
					$cgi->hidden(
						'DEVICE_TYPE_ID', $devtypid
					),
					$cgi->submit('Submit Update'),
				)
			),
		  ),
		  $cgi->end_form;
	} else {
		print $cgi->start_form(
			{ -method => 'POST', -action => 'write/adddt.pl' } ),
		  $cgi->table(
			{ -align => 'center', -border => 1 },
			$cgi->Tr( $cgi->td( $hdrparam, "General" ) ),
			$cgi->Tr( $cgi->td($leftbox), $cgi->td($rightbox) ),
			$cgi->Tr(
				$cgi->td( $addparams, $poweraddbox ),
				$cgi->td(
					$addparams, $serialaddbox,
					$cgi->hr,   $networkaddbox,
				)
			),
			$cgi->Tr(
				$cgi->td(
					$hdrparam,
					$cgi->submit('Add'),
					$cgi->caption(
"Vendor, Model and Rack Units are Required.  To add vendors, contact ",
						$stab->support_email,
						"\n"
					)
				)
			),
		  ),
		  $cgi->end_form;
	}

}

sub build_physical_port_box {
	my ( $stab, $devtypid, $type ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $humantype = $type;
	$humantype = 'switch' if ( $humantype eq 'network' );
	my $captype = $humantype;
	substr( $captype, $[, 1 ) =~ tr/a-z/A-Z/;

	my $q = qq{
		select	port_name, device_type_id, port_type,
			description, port_plug_style, port_medium,
			port_protocol, port_speed, physical_label,
			port_purpose, tcp_port, is_optional
		  from	device_type_phys_port_templt
		 where	device_type_id = ?
		   and	port_type = ?
		order by port_name
	};

	# XXX ORACLE/pgsql
	#		order by to_number(
	#			regexp_replace(port_name, '[^\d]', '')),
	#				port_name
	#	};

	my $sth = $dbh->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute( $devtypid, $type ) || $stab->return_db_err($sth);

	my $numrows  = 0;
	my $existing = "";

	my (@keys) = ( 'DEVICE_TYPE_ID', 'PORT_TYPE', 'PORT_NAME' );
	while ( my $hr = $sth->fetchrow_hashref ) {
		$numrows++;

		my $idx = join( "_",
			$hr->{ _dbx('DEVICE_TYPE_ID') },
			$hr->{ _dbx('PORT_TYPE') },
			$hr->{ _dbx('PORT_NAME') },
		);

		my $serialxtra = "";
		if ( $type eq 'serial' ) {
			$serialxtra = $cgi->td(
				$stab->b_textfield(
					{ -textfield_width => 10 }, $hr,
					'TCP_PORT', \@keys
				)
			);

		}

		$existing .= $cgi->Tr(
			$cgi->td(
				{ -align => 'center' },
				$cgi->checkbox(
					-class => "dt_${type}rm",
					-name  => "rm_PORT_NAME_$idx",
					-label => ''
				),
				$cgi->td(
					$stab->b_textfield(
						{ -textfield_width => 10 },
						$hr, 'PORT_NAME', \@keys
					)
				),
				$cgi->td(
					$stab->b_textfield(
						{ -textfield_width => 10 },
						$hr, 'DESCRIPTION', \@keys
					)
				),
				$cgi->td(
					$stab->b_textfield(
						{ -textfield_width => 10 },
						$hr, 'PHYSICAL_LABEL', \@keys
					)
				),
				$cgi->td(
					$stab->b_dropdown(
						undef,        $hr,
						'PORT_SPEED', \@keys
					)
				),
				$cgi->td(
					$stab->b_dropdown(
						undef,           $hr,
						'PORT_PROTOCOL', \@keys
					)
				),
				$cgi->td(
					$stab->b_dropdown(
						undef,             $hr,
						'PORT_PLUG_STYLE', \@keys
					)
				),
				$cgi->td(
					$stab->b_dropdown(
						undef,         $hr,
						'PORT_MEDIUM', \@keys
					)
				),
				$cgi->td(
					$stab->b_dropdown(
						undef,          $hr,
						'PORT_PURPOSE', \@keys
					)
				),
				$serialxtra,
				$cgi->td(
					$stab->build_checkbox(
						undef, $hr,
						'',    'IS_OPTIONAL',
						\@keys
					)
				),

			),
		);
	}

	my $delall = $cgi->checkbox(
		{
			-class => "dt_${type}rm dtrmall",
			-label => '',
		}
	) . "Del";

	my $headers = [
		$delall, "Name",     'Descrip', 'Label',
		'Speed', 'Protocol', 'Plug',    'Medium',
		'Purpose',
	];

	if ( $type eq 'serial' ) {
		push( @{$headers}, 'TCP Port', );
	}

	push( @{$headers}, 'Optional', );

	my $rv = "";
	if ( !$numrows ) {
		my $offparams = {
			-style   => 'color: grey',
			-align   => 'center',
			-colspan => $#{$headers} + 1,
		};
		$existing =
		  $cgi->Tr(
			$cgi->td( $offparams, "no $humantype configuration" ) );

	}

	$rv = $cgi->table(
		{ -border => 1, -width => '100%' },
		$cgi->caption("Current $captype Port Template"),
		$cgi->th($headers), $existing
	);

	$rv;
}

sub build_physical_port_add_box {
	my ( $stab, $devtypid, $type ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $pfx = $type;
	$pfx =~ tr/a-z/A-Z/;

	my $humantype = $type;
	$humantype = 'switch' if ( $type eq 'network' );

	my $title;
	if ($devtypid) {
		$title = "Add to $humantype port template";
	} else {
		my $captype = $humantype;
		substr( $captype, $[, 1 ) =~ tr/a-z/A-Z/;
		$title = $cgi->b("$captype Template");

	}

	my $portxtra = "";
	if ( $type eq 'serial' ) {
		$portxtra = $stab->build_tr(
			{ -textfield_width => 10 }, undef,
			"b_textfield",           'Tcp Port Start',
			"${pfx}_TCP_PORT_START", 'DEVICE_TYPE_ID'
		);
	}

	$cgi->table(
		$cgi->caption($title),
		$stab->build_tr(
			{ -textfield_width => 10 }, undef,
			"b_textfield",        'NamePrefix',
			"${pfx}_PORT_PREFIX", 'DEVICE_TYPE_ID',
			$devtypid
		),
		$stab->build_tr(
			{ -textfield_width => 10 }, undef,
			"b_textfield",                 'StartPort',
			"${pfx}_INTERFACE_PORT_START", 'DEVICE_TYPE_ID',
			$devtypid
		),
		$stab->build_tr(
			{ -textfield_width => 10 }, undef,
			"b_textfield",                 'Count',
			"${pfx}_INTERFACE_PORT_COUNT", 'DEVICE_TYPE_ID',
			$devtypid
		),
		$portxtra,
		$stab->build_tr(
			{ -prefix => "${pfx}_", }, undef,
			"b_dropdown",   "Purpose",
			'PORT_PURPOSE', 'DEVICE_TYPE_ID'
		),
		$stab->build_tr(
			{ -prefix => "${pfx}_" }, undef,
			"b_dropdown", "Port Speed",
			'PORT_SPEED', 'DEVICE_TYPE_ID'
		),
		$stab->build_tr(
			{ -prefix => "${pfx}_" }, undef,
			"b_dropdown",    "Protocol",
			'PORT_PROTOCOL', 'DEVICE_TYPE_ID'
		),
		$stab->build_tr(
			{ -prefix => "${pfx}_" }, undef,
			"b_dropdown",  "Medium",
			'PORT_MEDIUM', 'DEVICE_TYPE_ID'
		),
		$stab->build_tr(
			{ -prefix => "${pfx}_" }, undef,
			"b_dropdown",      "Plug Style",
			'PORT_PLUG_STYLE', 'DEVICE_TYPE_ID'
		),
	);
}

sub build_power_box {
	my ( $stab, $devtypid ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $q = qq{
		select	*
		  from	DEVICE_TYPE_POWER_PORT_TEMPLT
		 where	device_type_id = ?
	};

	# XXX ORACLE/pgsql
	#		order by to_number(
	#					regexp_replace(POWER_INTERFACE_PORT, '[^[:digit:]]', '')),
	#				power_interface_port
	#	};

	my $sth = $dbh->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($devtypid) || $stab->return_db_err($sth);

	my $numrows  = 0;
	my $existing = "";

	my (@keys) = ( 'DEVICE_TYPE_ID', 'POWER_INTERFACE_PORT' );

	while ( my $hr = $sth->fetchrow_hashref ) {
		$numrows++;

		my $idx = "pwr_"
		  . $hr->{ _dbx('DEVICE_TYPE_ID') } . "_"
		  . $hr->{ _dbx('POWER_INTERFACE_PORT') };
		$idx = $cgi->escapeHTML($idx);

		my $pstyle = $hr->{ _dbx('POWER_PLUG_STYLE') };
		$pstyle =~ tr/A-Z/a-z/;
		$pstyle =~ s,/.*$,,;
		$pstyle =~ s,^.+\s+,,;
		my $plugimg = $cgi->img(
			{
				-id  => "power_plug_style_img_$idx",
				-src => "../../images/electric/$pstyle.png"
			}
		);

		$existing .= $cgi->Tr(
			{ -valign => 'bottom' },
			$cgi->td(
				{ -align => 'center' },
				$cgi->checkbox(
					-class => 'dt_powerrm',
					-name  => "power_port_rm_$idx",
					-label => ''
				)
			),
			$cgi->td(
				$stab->b_textfield(
					undef,                  $hr,
					'POWER_INTERFACE_PORT', \@keys
				)
			),
			$cgi->td(
				$stab->b_dropdown(
					{
						-postpend_html => $plugimg,
						-id => "plug_drop_$idx",
						-onChange =>
"tweak_plug_style(power_plug_style_img_$idx, plug_drop_$idx);",
					},
					$hr,
					'POWER_PLUG_STYLE',
					\@keys
				),
				$plugimg
			),
			$cgi->td(
				$stab->b_textfield(
					undef, $hr, 'VOLTAGE', \@keys
				)
			),
			$cgi->td(
				$stab->b_textfield(
					undef, $hr, 'MAX_AMPERAGE', \@keys
				)
			),
			$cgi->td(
				$stab->build_checkbox(
					undef, $hr,
					'',    'PROVIDES_POWER',
					\@keys
				)
			),
			$cgi->td(
				$stab->build_checkbox(
					undef, $hr,
					'',    'IS_OPTIONAL',
					\@keys
				)
			),
		);
	}

	my $rv = "";
	if ( !$numrows ) {
		my $offparams = {
			-style   => 'color: grey',
			-align   => 'center',
			-colspan => 7,
		};
		$existing =
		  $cgi->Tr( $cgi->td( $offparams, "no power configuration" ) );
	}

	my $delall = $cgi->checkbox(
		{
			-class => 'dt_powerrm dtrmall',
			-label => '',
		}
	) . "Del";

	$rv = $cgi->table(
		{ -border => 1, -width => '100%' },
		$cgi->caption("Current Power Port Template"),
		$cgi->th(
			[
				$delall,      'PortName',
				'Plug Style', 'Voltage',
				'Max Amp',    'Provides',
				'Optional',
			]
		),
		$existing
	);

	$rv;
}

sub build_power_add_box {
	my ( $stab, $devtypid ) = @_;

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $title;
	if ($devtypid) {
		$title = 'Add to Power Port Template';
	} else {
		$title = $cgi->b('Power Template');
	}

	my $plugimg = $cgi->img(
		{
			-id  => 'plug_style_img',
			-src => "../../images/electric/unknown.png"
		}
	);
	$cgi->table(
		$cgi->Tr(
			$cgi->td(
				{ -colspan => 2, -align => 'center' }, $title
			)
		),
		$stab->build_tr(
			{ -textfield_width => 10, -default => 'power' },
			undef,
			"b_textfield",
			'NamePrefix',
			'POWER_INTERFACE_PORT_PREFIX',
			'DEVICE_TYPE_ID',
			$devtypid
		),
		$stab->build_tr(
			{ -textfield_width => 10 }, undef,
			"b_textfield",                'StartPort',
			'POWER_INTERFACE_PORT_START', 'DEVICE_TYPE_ID',
			$devtypid
		),
		$stab->build_tr(
			{ -textfield_width => 10 }, undef,
			"b_textfield",                'Count',
			'POWER_INTERFACE_PORT_COUNT', 'DEVICE_TYPE_ID',
			$devtypid
		),
		$stab->build_tr(
			{
				-postpend_html => $plugimg,
				-id            => 'plug_drop',
				-onChange =>
'tweak_plug_style(plug_style_img, plug_drop);',
			},
			undef,
			"b_dropdown",
			'Plug Style',
			'POWER_PLUG_STYLE',
			'DEVICE_TYPE_ID',
			$devtypid
		),
		$stab->build_tr(
			{ -textfield_width => 10, -voltage => 120 },
			undef,
			"b_textfield",
			'Voltage',
			'VOLTAGE',
			'DEVICE_TYPE_ID',
			$devtypid
		),
		$stab->build_tr(
			{ -textfield_width => 10 }, undef,
			"b_textfield",  'Max Amp',
			'MAX_AMPERAGE', 'DEVICE_TYPE_ID',
			$devtypid
		),
		$stab->build_tr(
			{ -label => '' }, undef,
			"build_checkbox", "Provides Power",
			"PROVIDES_POWER", 'DEVICE_TYPE_ID'
		),
		$stab->build_tr(
			{ -label => '' }, undef,
			"build_checkbox", "Optional",
			"IS_OPTIONAL",    'DEVICE_TYPE_ID'
		),
	);
}
