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

	print $cgi->div( { -class => 'netblock-search-box' },
		$cgi->p('Select a collection type to view or manage collections') );

	print $cgi->div(
		{ -class => 'ncmanip' },
		$cgi->start_form( {
			-class  => 'picker',
			-method => 'GET',
			-action => './'
		} ),
		$cgi->div( {
				-class => 'netblock-wrapper',
				-style => 'margin: 2em auto; padding: 1.5em;'
			},
			$cgi->h3(
				{ -style => 'margin: 0 0 1em 0; text-align: center;' },
				'Select Collection Type'
			),
			$cgi->div(
				{ -style => 'text-align: center; margin: 1em 0;' },
				$stab->b_dropdown( {
						-class => 'coltypepicker',
						-style => 'width: 300px; padding: 0.5em;'
					},
					undef,
					'NETBLOCK_COLLECTION_TYPE',
					undef, 1
				),
			),
		),
		$cgi->div(
			{ -id => 'collec_detail', class => 'irrelevant' },
			$cgi->div( {
					-id    => 'container_colbox',
					-class => 'netblock-wrapper',
					-style => 'margin: 2em auto; padding: 1.5em;'
				},
				$cgi->h3(
					{ -style => 'margin: 0 0 1em 0; text-align: center;' },
					'Pick a Collection to Modify'
				),
				$cgi->div(
					{ -style => 'text-align: center; margin: 1em 0;' },
					$cgi->div( { -id => 'colbox' }, "" ),
				),
				$cgi->div(
					{ -style => 'text-align: center; margin: 1em 0;' },
					$cgi->submit( {
						-name  => 'submit',
						-value => 'Modify',
						-style => 'padding: 0.5em 2em;'
					} ),
				),
				$cgi->end_form(),
			),
			$cgi->div( {
					-class => 'netblock-wrapper',
					-style => 'margin: 2em auto; padding: 1.5em;'
				},
				$cgi->h3(
					{ -style => 'margin: 0 0 1em 0; text-align: center;' },
					"Add a New Collection of this Type"
				),
				$cgi->div(
					{ -style => 'text-align: center; margin: 1em 0;' },
					$cgi->textfield( {
						-name        => 'NETBLOCK_COLLECTION_NAME',
						-placeholder => 'Enter new collection name',
						-style       => 'width: 300px; padding: 0.5em;'
					} ),
				),
				$cgi->div(
					{ -style => 'text-align: center; margin: 1em 0;' },
					$cgi->submit( {
						-name  => 'submit',
						-value => 'Add',
						-style => 'padding: 0.5em 2em;'
					} ),
				),
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
# returns a grid row with proper linkage and a remove checkbox.
#
sub build_collection_row($$$;$$$$) {
	my ( $cgi, $link, $rmid, $label, $rmheader, $description, $rank ) = @_;

	my $rmbox;
	if ( !$rmheader ) {
		$rmbox =
		  ($rmid)
		  ? $cgi->checkbox( {
			-name     => $rmid,
			-id       => $rmid,
			-label    => '',
			-class    => 'remove-checkbox',
			-onchange => 'toggleRemoveHighlight(this);',
		  } )
		  : "";
	} else {
		$rmbox = $rmheader;
	}

	if ($link) {
		$label = $cgi->a( { -href => $link }, "$label" ),;
	}

	my $row = "";
	$row .= $cgi->span( { -class => 'netblocksite' }, $rmbox );
	$row .= $cgi->span( { -class => 'netblocklink' }, $label );
	$row .= $cgi->span( { -class => 'netblockdesc' }, $description || '' );

	my $rank_field = '';
	if ( defined($rmid) && $rmid =~ /^rm_NETBLOCK_ID_/ ) {

		# Extract the ID from the remove checkbox name
		my $field_id = $rmid;
		$field_id =~ s/^rm_/rank_/;
		$rank_field = $cgi->textfield( {
			-name        => $field_id,
			-id          => $field_id,
			-value       => $rank,
			-placeholder => '',
			-style       => 'width: 4em; text-align: center;',
		} );
	} elsif ( defined($rmheader) ) {
		$rank_field = $rank || '';
	} else {
		$rank_field = $rank || '';
	}
	$row .= $cgi->span( { -class => 'netblockrank' }, $rank_field );

	$cgi->div( { -class => 'netblock-row' }, $row );
}

#
# returns a grid header row
#
sub build_collection_row_header($$;$$$) {
	my ( $cgi, $col1, $col2, $col3, $col4 ) = @_;

	my $row = "";
	$row .= $cgi->span( { -class => 'netblocksite' }, $col1 );
	$row .= $cgi->span( { -class => 'netblocklink' }, $col2 );
	$row .= $cgi->span( { -class => 'netblockdesc' }, $col3 || 'Description' );
	$row .= $cgi->span( { -class => 'netblockrank' }, $col4 || 'Rank' );

	$cgi->div( { -class => 'netblock-header' }, $row );
}

# This function displays a row to add a new network
sub build_netblock_collection_add_row($) {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $row = "";
	$row .= $cgi->span(
		{ -class => 'netblocksite' },
		$cgi->checkbox( {
			-name     => 'rm_add_NETBLOCK1',
			-id       => 'rm_add_NETBLOCK1',
			-label    => '',
			-class    => 'remove-checkbox',
			-onchange => 'toggleRemoveHighlight(this);',
		} )
	);
	$row .= $cgi->span(
		{ -class => 'netblocklink' },
		$cgi->textfield( {
			-name         => 'add_NETBLOCK1',
			-id           => 'add_NETBLOCK1',
			-value        => '',
			-placeholder  => 'New Network',
			-style        => 'width: 95%;',
			-autocomplete => 'on',
		} )
	);
	$row .= $cgi->span( { -class => 'netblockdesc' }, '' );
	$row .= $cgi->span(
		{ -class => 'netblockrank' },
		$cgi->textfield( {
			-name        => 'rank_add_NETBLOCK1',
			-id          => 'rank_add_NETBLOCK1',
			-value       => '',
			-placeholder => '',
			-style       => 'width: 4em; text-align: center;',
		} )
	);

	my $buttonrow = "";
	$buttonrow .= $cgi->span( { -class => 'netblocksite' }, '' );
	$buttonrow .= $cgi->span( { -class => 'netblockdesc' }, '' );
	$buttonrow .= $cgi->span( { -class => 'netblockrank' }, '' );
	$buttonrow .= $cgi->span(
		{ -class => 'netblocklink' },
		$cgi->button( {
				-type    => 'button',
				-class   => "",
				-id      => 'insert_NETBLOCK',
				-name    => 'insert_NETBLOCK',
				-title   => 'Add one more network',
				-label   => "Add Network",
				-onclick => "insert_netblock_input_row( this );",
			},
			'Add Network'
		)
	);

	$cgi->div( { -class => 'netblock-row', -id => 'netblock-input-row1' },
		$row ) . $cgi->div( { -class => 'netblock-row' }, $buttonrow );
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
				ncn.netblock_id_rank,
				d.device_id,
				d.device_name
		FROM	netblock nb
				INNER JOIN netblock_collection_netblock ncn USING (netblock_id)
				LEFT JOIN network_interface_netblock USING (netblock_id)
				LEFT JOIN device d USING (device_id)
		WHERE	ncn.netblock_collection_id = ?
		ORDER BY nb.ip_address, nb.is_single_address, d.device_id
	}
	) || return $stab->return_db_err;

	$sth->execute($ncid) || die $stab->return_db_err();

	my $rv;
	while ( my ( $id, $ip, $sig, $desc, $rank, $devid, $dname ) =
		$sth->fetchrow_array )
	{
		my $nblink = "";
		my $label  = "$ip";
		if ( $sig eq 'Y' ) {
			$label =~ s,/\d+$,/32,;
			if ($devid) {
				$nblink = "../../device/device.pl?devid=$devid";
			}
		} else {
			$nblink = "../?nblkid=$id";
		}

		my $rmid = "rm_NETBLOCK_ID_$id";

		$rv .=
		  build_collection_row( $cgi, $nblink, $rmid, $label, undef, $desc,
			defined($rank) ? $rank : '' );
	}
	$rv;
}

# This function displays a row to add a new child collection
sub build_child_collection_add_row($) {
	my ($stab) = @_;
	my $cgi = $stab->cgi || die "Could not create cgi";

	my $row = "";
	$row .= $cgi->span( { -class => 'netblocksite' }, '' );
	$row .= $cgi->span(
		{ -class => 'netblocklink' },
		$cgi->button( {
				-type    => 'button',
				-class   => "",
				-id      => 'insert_CHILD_COLLECTION',
				-name    => 'insert_CHILD_COLLECTION',
				-title   => 'Add one more child collection',
				-label   => "Add Child Collection",
				-onclick => "insert_child_collection_input_row( this );",
			},
			'Add Child Collection'
		)
	);
	$row .= $cgi->span( { -class => 'netblockdesc' }, '' );
	$row .= $cgi->span( { -class => 'netblockrank' }, '' );

	$cgi->div( { -class => 'netblock-row' }, $row );
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
		$rv .=
		  build_collection_row( $cgi, $nblink, $rmid, $label, undef, $desc );
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
		$rv .= build_collection_row( $cgi, $nblink, $rmid, $label, ' ', $desc );
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

	print $cgi->hidden( 'NETBLOCK_COLLECTION_ID', $ncid );

	# Combined Members Section (netblocks and child collections)
	my $member_content   = build_collection_members( $stab, $ncid );
	my $children_content = build_collection_children( $stab, $ncid );

	print $cgi->div(
		{ -class => 'netblock-wrapper', -style => 'margin: 2em auto;' },
		$cgi->h3(
			{ -style => 'margin: 0.5em 1em; text-align: center;' },
			"Collection Members"
		),
		$cgi->div( {
				-class => 'netblock-list netblock-list-four-col',
				-id    => 'collection-members'
			},
			build_collection_row_header(
				$cgi, "Remove", "Member", "Description", "Rank"
			),
			$member_content,
			build_netblock_collection_add_row($stab),
			$cgi->div( { -class => 'netblock-separator' }, '' ),
			$children_content,
			build_child_collection_add_row($stab),
		),
	);

	# Submit button
	print $cgi->div(
		{ -style => 'text-align: center; margin: 2em;' },
		$cgi->submit( {
			-value => 'Submit Changes',
			-style => 'padding: 0.5em 2em; font-size: 1.1em;'
		} )
	);

	print $cgi->end_form;

	# Parent Collections Section (read-only)
	my $parents_content = build_collection_parents( $stab, $ncid );
	print $cgi->div(
		{ -class => 'netblock-wrapper', -style => 'margin: 2em auto;' },
		$cgi->h3(
			{ -style => 'margin: 0.5em 1em; text-align: center;' },
			"Parent Collection(s) of "
			  . join( ":",
				$nc->{'NETBLOCK_COLLECTION_TYPE'},
				$nc->{'NETBLOCK_COLLECTION_NAME'} )
		),
		$cgi->div(
			{ -class => 'netblock-list netblock-list-three-col' },
			build_collection_row_header(
				$cgi, " ", "Collection", "Description"
			),
			$parents_content || $cgi->div(
				{ -class => 'netblock-row' },
				$cgi->span( { -class => 'netblocksite' }, '' )
				  . $cgi->span( {
						-class => 'netblocklink',
						-style => 'font-style: italic; color: #888;'
					},
					'No parent collections'
				  )
			),
		)
	);

	print $cgi->end_html;

}
