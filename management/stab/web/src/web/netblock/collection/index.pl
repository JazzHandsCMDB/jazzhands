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

exit do_netblock_collections();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

sub do_netblock_collections {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $cgi = $stab->cgi || die "Could not create cgi";

	#
	# This is pick for adding children so the ajaxy stuff can use
	# NETBLOCK_COLLECTION_ID.  All needs to be rethought...
	#
	my $nbcid = $stab->cgi_parse_param('pick_NETBLOCK_COLLECTION_ID');
	if ( !$nbcid ) {
		$nbcid = $stab->cgi_parse_param('NETBLOCK_COLLECTION_ID');
	}

	my $submit = $stab->cgi_parse_param('submit');

	if ( defined($submit) && $submit || $nbcid ) {
		process_netblock_collection( $stab, $nbcid );
	} else {
		do_netblock_collection_chooser($stab);
	}

	$stab->rollback;
	undef $stab;
	0;
}

sub do_netblock_collection_chooser($) {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header('text/html');
	print $stab->start_html( {
		-title      => "Netblock Collection Management",
		-javascript => 'netblock_collection',
	} );

	print $cgi->div(
		{ -class => 'ncmanip' },
		$cgi->start_form( {
			-class  => 'picker',
			-method => 'GET',
			-action => './'
		} ),
		$cgi->div(
			$cgi->h3('Pick a type:'),
			$stab->b_dropdown(
				{ -class => 'coltypepicker', }, undef,
				'NETBLOCK_COLLECTION_TYPE',     undef,
				1
			),
		),
		$cgi->div(
			{ -id => 'collec_detail', class => 'irrelevant' },
			$cgi->h3("Add a new Collection of this Type"),
			$cgi->textfield( { -name => 'NETBLOCK_COLLECTION_NAME' } ),
			$cgi->submit( -name => 'submit', -value => 'Add' ),
			$cgi->div(
				{ -id => 'container_colbox' },
				$cgi->h3('Pick a collection:'),
				$cgi->start_form( { -method => 'GET', -action => './' } ),
				$cgi->div( { -id => 'colbox' }, "" ),
				$cgi->submit( -name => 'submit', -value => 'Modify' ),
				$cgi->end_form(),
			),
		),
	);
	print $cgi->end_html;

}

sub add_netblock_collection($$$) {
	my ( $stab, $name, $type ) = @_;

	my (@errs);

	my $hash = {
		'netblock_collection_name' => $name,
		'netblock_collection_type' => $type,
	};

	my $numchanges = 0;
	if ( !(
		$numchanges = $stab->DBInsert(
			table  => 'netblock_collection',
			hash   => $hash,
			errors => \@errs
		)
	) )
	{
		$stab->error_return( join( " ", @errs ) );
	}

	return $hash->{'NETBLOCK_COLLECTION_ID'};
}

#
# returns an li with proper linkage and a remove checkbox.
#
sub build_collection_row($$$$;$$) {
	my ( $cgi, $link, $rmid, $label, $desc, $rmheader ) = @_;

	my $rmbox;
	if ( !$rmheader ) {
		$rmbox =
		  ($rmid)
		  ? $cgi->checkbox( {
			-name  => $rmid,
			-id    => $rmid,
			-label => '',
		  } )
		  : "-";
	} else {
		$rmbox = $rmheader;
	}

	if ($link) {
		$label = $cgi->a( { -href => $link }, "$label" ),;
	}

	$cgi->li(
		$cgi->span( { -class => 'netblocksite' }, $rmbox ),
		$cgi->span( { -class => 'netblocklink' }, $label ),
		$cgi->span(
			{ -class => 'netblockdesc' },
			( ($desc) ? " - $desc " : "" )
		),
	);
}

# This function displays a button to add a new network input row
# It's added in a div and not a li element because it shouldn't be numbered
sub build_netblock_collection_add_more($) {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $strInsertNetblockButton = $cgi->button( {
			-type    => 'button',
			-class   => "",
			-id      => 'insert_NETBLOCK',
			-name    => 'insert_NETBLOCK',
			-title   => 'Add one more network',
			-state   => "Add Network",
			-label   => "Add Network",
			-onclick => "insert_netblock_input_row( this );",
		},
		'Add Network'
	);

	$cgi->div( {}, "-", $strInsertNetblockButton ),;
}

sub build_collection_members($$) {
	my ( $stab, $ncid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $sth = $stab->prepare(
		qq{
		SELECT	nb.netblock_id,
				nb.ip_address,
				nb.is_single_address,
				nb.description,
				d.device_id,
				d.device_name
		FROM	netblock nb
				INNER JOIN netblock_collection_netblock USING (netblock_id)
				LEFT JOIN network_interface_netblock USING (netblock_id)
				LEFT JOIN device d USING (device_id)
		WHERE	netblock_collection_id = ?
		ORDER BY nb.ip_address, nb.is_single_address, d.device_id
	}
	) || return $stab->return_db_err;

	$sth->execute($ncid) || die $stab->return_db_err();

	my $rv;
	while ( my ( $id, $ip, $sig, $desc, $devid, $dname ) =
		$sth->fetchrow_array )
	{
		my $nblink = "";
		my $label  = "$ip";
		if ( $sig eq 'Y' ) {
			$label =~ s,/\d+$,/32,;
			if ($devid) {
				$nblink = "../../device/device.pl?devid=$devid";

				# maybe do this if switching to tables
				# $label = "$label ($dname)";
			}
		} else {
			$nblink = "../?nblkid=$id";
		}

		my $rmid = "rm_NETBLOCK_ID_$id";

		$rv .= build_collection_row( $cgi, $nblink, $rmid, $label, $desc );
	}
	$rv;
}

# This function displays a button to add a new child colletion input row
# It's added in a div and not a li element because it shouldn't be numbered
sub build_child_collection_add_more($) {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $strInsertNetblockButton = $cgi->button( {
			-type    => 'button',
			-class   => "",
			-id      => 'insert_CHILD_COLLECTION',
			-name    => 'insert_CHILD_COLLECTION',
			-title   => 'Add one more child collection',
			-state   => "Add Child Collection",
			-label   => "Add Child Collection",
			-onclick => "insert_child_collection_input_row( this );",
		},
		'Add Network'
	);

	$cgi->div( {}, "-", $strInsertNetblockButton ),;
}

sub build_collection_children {
	my ( $stab, $ncid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $sth = $stab->prepare(
		qq{
		SELECT	nc.netblock_collection_id,
				nc.netblock_collection_name,
				nc.netblock_collection_type,
				nc.description
		FROM	netblock_collection nc
				INNER JOIN netblock_collection_hier h ON
					h.child_netblock_collection_id = nc.netblock_collection_id
		WHERE	h.netblock_collection_id = ?
		ORDER BY nc.netblock_collection_type,nc.netblock_collection_name,
				nc.netblock_collection_id
		}
	) || return $stab->return_db_err;

	$sth->execute($ncid) || die $stab->return_db_err();

	my $rv;
	while ( my ( $id, $name, $type, $desc ) = $sth->fetchrow_array ) {
		my $nblink = "./?NETBLOCK_COLLECTION_ID=$id";
		my $rmid   = "rm_NETBLOCK_COLLECTION_ID_$id";
		my $label  = "$type:$name";
		$rv .= build_collection_row( $cgi, $nblink, $rmid, $label, $desc );
	}
	$rv;
}

sub build_collection_parents {
	my ( $stab, $ncid ) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $sth = $stab->prepare(
		qq{
		SELECT	nc.netblock_collection_id,
				nc.netblock_collection_name,
				nc.netblock_collection_type,
				nc.description
		FROM	netblock_collection nc
				INNER JOIN netblock_collection_hier h ON
					h.netblock_collection_id = nc.netblock_collection_id
		WHERE	h.child_netblock_collection_id = ? AND
			nc.netblock_collection_type <> 'by-coll-type'
		ORDER BY nc.netblock_collection_type,nc.netblock_collection_name,
				nc.netblock_collection_id
		}
	) || return $stab->return_db_err;

	$sth->execute($ncid) || die $stab->return_db_err();

	my $rv;
	while ( my ( $id, $name, $type, $desc ) = $sth->fetchrow_array ) {
		my $nblink = "./?NETBLOCK_COLLECTION_ID=$id";
		my $rmid   = "rm_NETBLOCK_COLLECTION_ID_$id";
		my $label  = "$type:$name";
		$rv .= build_collection_row( $cgi, $nblink, $rmid, $label, $desc, ' ' );
	}
	$rv;
}

sub process_netblock_collection {
	my ( $stab, $ncid ) = @_;

	my $cgi    = $stab->cgi || die "Could not create cgi";
	my $submit = $stab->cgi_parse_param('submit');
	my $nctype = $stab->cgi_parse_param('NETBLOCK_COLLECTION_TYPE');

	if ( $submit && $submit eq 'Add' ) {
		my $ncname = $stab->cgi_parse_param('NETBLOCK_COLLECTION_NAME');
		my $id     = add_netblock_collection( $stab, $ncname, $nctype );
		my $url    = "./?NETBLOCK_COLLECTION_ID=$id";
		$stab->commit;
		return $stab->msg_return( "Netblock Added Successfully", $url, 1 );
	}

	# submit is Modify if it was a modify submission, otherwise it may have
	# been a direct open from the add page or elsewhere

	if ( !$ncid ) {
		return $stab->error_return("No Collection Specified");
	}

	my $nc = $stab->get_netblock_collection($ncid);

	if ( !$nc ) {
		return $stab->error_return("Unkown Collection Id $ncid");
	}

	# print $cgi->div({-align=>'center'}, $cgi->submit("Submit Changes"));
	print $cgi->header('text/html');
	print $stab->start_html( {
		-title => "Netblock Collection "
		  . join( ":",
			$nc->{'NETBLOCK_COLLECTION_TYPE'},
			$nc->{'NETBLOCK_COLLECTION_NAME'} ),
		-javascript => 'netblock_collection',
	} );

	print $cgi->start_form( {
		-method => 'GET',
		-action => 'update_nb.pl',
	} );

	print $cgi->ul(
		{ -class => 'collection' },
		$cgi->hidden( 'NETBLOCK_COLLECTION_ID', $ncid ),
		build_collection_row(
			$cgi, undef, undef, "Member", "Description", "RM"
		),
		build_collection_members( $stab, $ncid ),
		build_netblock_collection_add_more($stab),
		build_collection_children( $stab, $ncid ),
		build_child_collection_add_more($stab),
		'<br/>',
		$cgi->submit(),
	);

	print $cgi->ul(
		{ -class => 'collection' },
		'<br/><br/><h2>Parent Collection(s) of '
		  . join( ":",
			$nc->{'NETBLOCK_COLLECTION_TYPE'},
			$nc->{'NETBLOCK_COLLECTION_NAME'},
			'</h2>' ),
		build_collection_row(
			$cgi, undef, undef, "Collection", "Description", " "
		),
		build_collection_parents( $stab, $ncid ),
	);

	print $cgi->end_form;

	print $cgi->end_html;

}
