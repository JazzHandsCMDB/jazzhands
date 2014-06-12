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
# most of this presentation was written by chang.

package JazzHands::STAB::Rack;

use 5.008007;
use strict;
use warnings;
use JazzHands::Common::Util qw(_dbx);

our @ISA = qw( );

our $VERSION = '1.0.0';

# Preloaded methods go here.

# trick for vertical text
# <div style='width:10px;height:100px;text:align:center'>

# these input keys are set: site, row, rack, room
sub build_rack {
	my ( $self, $rackid ) = @_;

	my $root = $self->guess_stab_root;

	my $cgi = $self->cgi || die "Could not create cgi";
	my $rv = "";

	my $rack = $self->get_rack_from_rackid($rackid);
	if ( !$rack || !$rackid ) {
		$self->error_return("Unknown rack id $rackid");
	}

	#
	# this is per rack and indicates if we show up from the bottom or
	# down from the top
	#
	my $shouldcountup = 1;

	my ($q) = qq{
    		SELECT	
			d.device_id,
			d.device_name,
			pard.device_id,
			pard.device_name,
			d.physical_label,
			dt.model,
			dt.rack_units,
			l.rack_u_offset_of_device_top,
			l.rack_side,
			d.device_status,
			c.company_name
		FROM		device d
			inner join rack_location l
				using (rack_location_id)
			inner join device_type dt
				on d.device_type_id = dt.device_type_id
			left join company c
				on c.company_id = dt.company_id
			left join device pard
				on d.parent_device_id = pard.device_id
		WHERE 
			l.rack_id = ?
		ORDER BY l.rack_u_offset_of_device_top
	};
	my $sth = $self->prepare($q) || $self->return_db_err;

	$sth->execute($rackid) || $self->return_db_err($sth);

	# front?  back?  presume no overlap for now.
	my %thisrack   = ();    # key=offset, value=html table string
	my %offsets    = ();    # key=starting offset, value=length
	my ($flipflop) = 0;     # boolean, also index into @BGCOLORS;

	$rv .= $cgi->start_table(
		{ -class => 'rackit', -border => 2, -align => 'center' } );

	$rv .= $cgi->Tr(
		$cgi->th(
			[
				"u",
				join( " ",
					$rack->{ _dbx('SITE_CODE') },
					$rack->{ _dbx('ROOM') },
					$rack->{ _dbx('RACK_ROW') },
					$rack->{ _dbx('RACK_NAME') },
				)
			]
		)
	);

	my $MAX_RACKSIZE =
	  $rack->{ _dbx('RACK_HEIGHT_IN_U') } || 50;    # size of rack
	while (
		my (
			$did,   $name,   $pardid, $parname, $label,
			$model, $height, $offset, $side,    $site,
			$room,  $row,    $rack,   $status,  $vendor
		)
		= $sth->fetchrow_array
	  )
	{

		$offset = 0 if (!defined($offset));

		# print header
		# almost certainly need to mark this as a stub somehow; this is
		# for patchpanels
		if ( defined($name) && $name =~ /--otherside/ ) {
			$did  = $pardid;
			$name = $parname;
		}
		my $field;
		my $linkto = "";
		if ( !defined($name) || !length($name) ) {
			if ( defined($label) ) {
				$field = $label;
			}
		} else {
			$linkto = $name;
		}
		if ( !$field ) {

			# this is totally dumb; allows for vertical text
			if ( $offset < 0 ) {
				my $x = "";
				for ( my $i = 0 ; $i < length($linkto) ; $i++ )
				{
					my $l = substr( $linkto, $i, 1 );
					$x .= "$l<br>";
				}
				$linkto = $x;
			} else {    # need to make smarter...
				$linkto = $cgi->escapeHTML($linkto);
			}
			$field = $self->vendor_logo($vendor)
			  . $cgi->a(
				{
					-href =>
					  "$root/device/device.pl?devid=$did"
				},
				$linkto
			  );
		} else {
			$field = $cgi->escapeHTML($field);
		}

		# if height is not set or is 0, make it
		# default to 1, but flag it
		$height = 1 if ( !$height || $height < 0 );    # [XXX]

		if ( $thisrack{$offset} ) {

	      # if this field is already set,
	      # then we have an overlap.
	      # warn, error condition
	      # XXX not necessarily true, as 2 devices could be in one location,
	      # front and back
			$thisrack{$offset} =
			  $cgi->b("OVERLAP: $thisrack{$offset}, $field");

	    # this is ugly, screws up table formatting.  need to fix this later.

		} else {
			$thisrack{$offset} = $field;
		}

		# if $height is a fraction, round up.
		# this doesn't feel right but can't think
		# of anything cleaner at the moment
		if ( $height * 100 % 100 != 0 ) {

		      # warn "fractional height $height RU is being rounded up";
			$height = int($height) + 1;    # XXX OVERRIDE
		}
		for ( my $cnt = 0 ; $cnt < $height ; $cnt++ ) {
			my $ru = $offset - $cnt;
			next if ( $ru < 0 );

	   # print STDERR "\tsetting overlaper $ru $name\n" if($name =~ /s199/);
			$thisrack{$ru} = $field;
		}
		$offsets{$offset} = $height;
	}
	$sth->finish();

	my $lastdev = "";
	for ( my $iter = 0 ; $iter < $MAX_RACKSIZE ; $iter++ ) {
		my $ru = $MAX_RACKSIZE - $iter;
		my $presentu = ($shouldcountup) ? $ru : $iter + 1;

# my $offset_link= sprintf ("<A HREF=\"/cgi-bin/rackit.pl?site=%s&room=%s&row=%s&rack=%s&offset=%d\">%d</A>",
		my $offset_link = $presentu;

		if ( !defined( $thisrack{$ru} ) ) {
			$rv .= $cgi->Tr( $cgi->td( [ $offset_link, "" ] ) );
		} elsif ( $lastdev ne $thisrack{$ru} ) {
			if ( $thisrack{$ru} ) {
				$rv .= $cgi->Tr(
					$cgi->td($offset_link),
					$cgi->td(
						{
							-rowspan =>
							  $offsets{$ru},
							-class => 'rackit_'
							  . (
								(
									$flipflop
									  % 2
								)
								? 'even'
								: 'odd'
							  )
						},
						$thisrack{$ru}
					)
				);
				$flipflop = !$flipflop;
			}
		} else {
			if ( $thisrack{$ru} ) {
				$rv .= $cgi->Tr( $cgi->td($offset_link) );
			}
		}
		$lastdev = ( $thisrack{$ru} ) ? $thisrack{$ru} : "";
	}

	$rv .= $cgi->end_table;

	my ( $rhs, $lhs ) = ( "", "" );
	for ( my $i = -1 ; $i != 0 ; $i-- ) {
		last if ( !exists( $thisrack{$i} ) );

		# even #'s are on the lhs from the front
		# odd #'s are on the rhs from the front
		if ( $i % 2 ) {
			$lhs .= $cgi->td( { -class => 'rackit_vertical' },
				$thisrack{$i} );
		} else {
			$rhs .= $cgi->td( { -class => 'rackit_vertical' },
				$thisrack{$i} );
		}
	}

	$rv = $cgi->table( $cgi->Tr( $lhs, $cgi->td($rv), $rhs ) );

	$rv;
}

__END__;

# these input keys are set: site, row, room
sub show_row {
	local(*input)=@_;

	my (@RACKS)=();  # racks in this row
	my($rack);  # a temporry variable

	my ($sql)=qq{
		SELECT	DISTINCT rl.rack
		FROM	rack_location rl
		WHERE 	rl.site_code='$input{site}'
		AND	rl.rack_row='$input{row}'
		AND	rl.room='$input{room}'
		ORDER BY rl.rack
	};
	my($sth)=$dbh->prepare($sql);
	if ($dbh->errstr) {
		warn "DBI error: " . $dbh->errstr;
	} else {
		$sth->execute();
print "Query: <PRE>$sql</PRE>\n";
		if ($sth->errstr) {
			warn "DBI error: " . $sth->errstr;
		} else {
			while(($rack)=$sth->fetchrow_array()) {
				push(@RACKS, $rack);
			}
		}
	}


	###################################################################
	# display a header line
	print "<H2>$input{site} $input{room} row $input{row}</H2>\n";
	print "<TABLE BGCOLOR=\"\#B0B0FF\" BORDER=2>\n";
	print "<TR>\n";
	foreach $rack (@RACKS) {
			#printf ("<TH>%s-%s-%s</TH>",
			printf ("<TH><A HREF=\"/cgi-bin/rackit.pl?site=%s&room=%s&rack=%s&row=%s\">%s-%s-%s</A></TH>",
				$input{site},
				$input{room},
				$rack, 
				$input{row},
				#
				$input{room},
				$input{row},
				$rack); 
	}
	print "</TR>\n";
	
	print "<TR>\n";
	foreach $rack (@RACKS) {
		print "<TD>\n";
		$sql=qq{
			SELECT	device.device_name,
				device_type.model,
				device_type.rack_units,
				rl.rack_u_offset_of_device_top,
				rl.rack_side,
				device.device_id,
				company.company_name
			FROM	device,
				device_type,
				location rl,
				company
			WHERE 	device.device_type_id=device_type.device_type_id
			AND	device.rack_location_id=rl.rack_location_id
			AND	rl.site_code='$input{site}'
			AND	rl.rack='$rack'
			AND	rl.rack_row='$input{row}'
			AND	rl.room='$input{room}'
			AND	device.status != 'removed'
			AND	device_type.company_id=company.comany_id
			ORDER BY rl.rack_u_offset_of_device_top
		};
		$sth=$dbh->prepare($sql);
		if ($dbh->errstr) {
			warn "DBI error: " . $dbh->errstr;
		} else {
			my($name,$model,$height,$offset,$side,$did,$vendor);
			$sth->execute();
#print "Query: <PRE>$sql</PRE>\n";
			if ($sth->errstr) {
				warn "DBI error: " . $sth->errstr;
			} else {

				# front?  back?  presume no overlap for now.
				my %thisrack=();  # key=offset, value=html table string
				my %offsets=();   # key=starting offset, value=length
        			my($flipflop)=0;  # boolean, also index into @BGCOLORS;
				print "<TABLE BORDER=2>\n";   # can nested tables work???

				while(($name,$model,$height,$offset,$side,$did,$vendor)=$sth->fetchrow_array()) {
					#print "$name ($model of $height RU) found at $offset, $side<BR>\n";
					#my $field="$name ($model/$height RU/$side)";

					# shorten name here
					my $shortname = $name;
					$shortname =~ s/\.[ms]\.example\.com//;
					# NOTE: this only applies for servers, not routers/switches!
					#my $field="<A HREF=\"/cgi-bin/htmlrpt.pl\?hostname=$name\">$shortname</A>";
					#my $field="$shortname";
					#my $field="<A HREF=\"/cgi-bin/rackit.pl\?device_id=$did\">$shortname</A>";
					#my $field="<A HREF=\"/cgi-bin/rackit.pl\?device_id=$did\">$shortname</A>".
					#	&vendor_logo($vendor);
					my $field= &vendor_logo($vendor).
						"<A HREF=\"/cgi-bin/rackit.pl\?device_id=$did\">$shortname</A>";
					# add link of model->page describing
					# each kind of device?
	
					# if height is not set or is 0, make it
					# default to 1, but flag it
					if (!$height) {
						$field .= "<I>device_type.rack_units (height) is not set, presuming 1u</I>";
						$height=1;   # XXX OVERRIDE
					}
	
					if ($thisrack{$offset}) {
						# if this field is already set,
						# then we have an overlap.
						# warn, error condition
						$thisrack{$offset} = 
						"<B>OVERLAP: $thisrack{$offset}, $field</B>";
						
					} else {
						$thisrack{$offset}=$field;
					}
	
					# if $height is a fraction, round up.
					# this doesn't feel right but can't think
					# of anything cleaner at the moment
					if ($height*100%100 != 0) {
						warn "fractional height $height RU is being rounded up";
						$height=int($height)+1; # XXX OVERRIDE
					}
					for (my $cnt=$offset+1;$cnt<($offset+$height-1);$cnt++) {
						$thisrack{$cnt}=$field;
					}
					# warn "height of $name is $height?\n";
					$offsets{$offset}=$height;
					
				}
	
				my $cnt;
				my $MAX_RACKSIZE=66;  # size of rack  this is ballpark for now
				my $lastdev="";
				#foreach $cnt (sort by_numeric keys %thisrack) {
				for ($cnt=0;$cnt<$MAX_RACKSIZE;$cnt++) {
					my $offset_link= sprintf ("<A HREF=\"/cgi-bin/rackit.pl?site=%s&room=%s&row=%s&rack=%s&offset=%d\">%d</A>",
						$input{site}, $input{room}, $input{row}, $rack, $cnt, $cnt);
					if ($lastdev ne $thisrack{$cnt}) {
	
						if ($thisrack{$cnt}) {
						#	print "<TR><TD>$cnt</TD><TD ROWSPAN=\"$offsets{$cnt}\"".  $BGCOLORS[$flipflop] . ">$thisrack{$cnt}</TD></TR>\n";
							print "<TR><TD>$offset_link</TD><TD ROWSPAN=\"$offsets{$cnt}\"".  $BGCOLORS[$flipflop] . ">$thisrack{$cnt}</TD></TR>\n";
							$flipflop = !$flipflop;
						} else {
							print "<TR><TD>$offset_link</TD><TD><!--empty1--></TD></TR>\n";
						}
					} else {
						if ($thisrack{$cnt}) {
							# continuance
							print "<TR><TD>$offset_link</TD></TR>\n";
						} else {
							print "<TR><TD>$offset_link</TD><TD><!--empty1--></TD></TR>\n";
						}
					}
					$lastdev=$thisrack{$cnt};
				}
				print "</TABLE>\n"
			}
		}
		print "</TD>\n";
	}
	print "</TR>\n";
	print "</TABLE>\n";

			
	$sth->finish();
	return;
}

# given nothing
sub pick_site {
	# pull rows from JazzHands.site

	my $pop;

	print "<H2>Select a Site</H2>\n";
	print "<UL>\n";

	my ($sql)=qq{
		SELECT	site_code,
			description
		FROM	site
		WHERE	site_status = 'ACTIVE'
		ORDER BY site_code
	};
	my($sth)=$dbh->prepare($sql);
	if ($dbh->errstr) {
		warn "DBI error: " . $dbh->errstr;
	} else {
		$sth->execute();
print "Query: <PRE>$sql</PRE>\n";
		if ($sth->errstr) {
			warn "DBI error: " . $sth->errstr;
		} else {
			while(($pop,$desc)=$sth->fetchrow_array()) {
				print "<LI><A HREF=\"/cgi-bin/rackit.pl?site=$pop\">$pop</A> <I>($desc)</I>\n";
			}
		}
	}


	print "</UL>\n";
	

	$sth->finish();
	return;

}


# given input{site}, select a room/row 
sub show_site {
	local(*input)=@_;

	my (@ROWS)=();  
	my (@ROOMS)=();  
	my($row);  # a temporry variable
	my($room);  # a temporry variable
	print "<H2>Select a Row at $input{site}</H2>\n";
	print "It would be nice to get a map of the pop and put an IMAGEMAP here\n";
	print "<UL>\n";

	my ($sql)=qq{
		SELECT	DISTINCT rack_row, room
		FROM	rack_location rl
		WHERE 	rl.site_code='$input{site}'
		ORDER BY room, rack_row
	};
	my($sth)=$dbh->prepare($sql);
	if ($dbh->errstr) {
		warn "DBI error: " . $dbh->errstr;
	} else {
		$sth->execute();
print "Query: <PRE>$sql</PRE>\n";
		if ($sth->errstr) {
			warn "DBI error: " . $sth->errstr;
		} else {
			while(($row,$room)=$sth->fetchrow_array()) {
				printf ("<LI><A HREF=\"/cgi-bin/rackit.pl?site=%s&room=%s&row=%s\">%s row %s</A></TH>",
				$input{site},
				$room,
				$row,
				#
				$room,
				$row);
			}
		}
	}
	print "</UL>\n";

	return;
}


#
# given a device_id, display information about it in a web page
#
sub disp_device {
	my($did)=@_;

	my ($sql)=qq{
		SELECT	device.device_name,
			device.status,
			device.production_state,
			device_type.model,
			company.company_name,
			device_type.rack_units,
			device_type.processor_architecture,
			device.serial_number,
			rl.site_code,
			rl.room,
			rl.rack_row,
			rl.rack,
			rl.rack_u_offset_of_device_top
		FROM	device,
			device_type,
			company,
			rack_location rl
		WHERE	device.device_type_id=device_type.device_type_id
		AND	company.company_id = device_type.company_id
		AND	device.device_id=$did
		AND	device.rack_location_id=location.rack_location_id
	};
	my $sth=$dbh->prepare($sql);
	if ($sth) {
		my ($name,$status,$prodstat,$model,$vendor,$height,$arch,$serial,$site,$room,$row,$rack,$offset);
		$sth->execute();


		print "<UL BGCOLOR=\"\#B0B0FF\">\n";
		print "<LI>Information from JazzHands\n";
		print "<LI> add data from zamfir/rancid to highlight discrepancies?\n";
		print "<LI> add link to wiki for each device type/vendor?\n";
		print "</UL><P>\n";
		print "<TABLE BORDER=1>\n";
		print "<TR><TH></TH><TH>Device Info</TH></TR>\n";
		while(($name,$status,$prodstat,$model,$vendor,$height,$arch,$serial,$site,$room,$row,$rack,$offset)=$sth->fetchrow_array()) {
			my $rused;  my $r;
			print "<TR><TD>Name</TD><TD>$name</TD></TR>\n";
			print "<TR><TD>Status</TD><TD>$status</TD></TR>\n";
			print "<TR><TD>Production State</TD><TD>$prodstat</TD></TR>\n";
			print "<TR><TD>Device Model</TD><TD>$model</TD></TR>\n";
			print "<TR><TD>Device Manufacturer</TD><TD>" . &vendor_logo($vendor) . "$vendor</TD></TR>\n";
			print "<TR><TD>Device Serial Number</TD><TD>$serial</TD></TR>\n";
			if ($arch) {
				print "<TR><TD>Device Architecture</TD><TD>$arch</TD></TR>\n";
			}
			print "<TR><TD>Device Height</TD><TD>$height RUs</TD></TR>\n";
			
			for ($r=0;$r<$height;$r++) {
				#$rused.= sprintf("%d ", $offset+$r);
				$rused.= sprintf("%s %s-%s-%s-%d<BR>\n", $site, $room,
					$row,$rack, $offset+$r);
			}
			print "<TR><TD>RUs occupied </TD><TD>$rused</TD></TR>\n";
			print "<TR><TD>RPC Port Info:</TD><TD>?</TD></TR>\n";
			printf "<TR><TD>NIC Port Info:</TD><TD>%s</TD></TR>\n",
				&get_switchport($dbh, $did);
			printf "<TR><TD>Console Port Info:</TD><TD> %s</TD></TR>\n", &get_console($dbh, $did);
			print "<TR><TD>Related Data:</TD><TD>\n";
			print "<A HREF=\"/cgi-bin/htmlrpt.pl?hostname=$name\">Zamfir Report (servers)</A><BR>\n";
			print "<A HREF=\"/cgi-bin/rancidlist.pl?$name\">Rancid Config (router/switch)</A><BR>\n";
			print "</TR>\n";
		}
		print "</TABLE>\n";
		$sth->finish();
	} else {
		warn "$0: " . $dbh->errstr;
	}

	return;
}

sub lookup_spot {
	local(*input)=@_;
	# find rack_location_id for location row that maps to the above
	# slot.  what if there are multiple hits???
	# how to deal with multiple-u devices?  search for device_type
	# and then rack-u ?
	# when searching for a device, do not map to devices with type=removed
	#
	# what if box is 2u, there is an entry for offset but not offset+1
	#
	#
	my ($sql)=qq{
		SELECT	device.device_id,
			rl.rack_side
		FROM	device,
			device_type,
			rack_location rl
		WHERE	device.rack_location_id=rack_location.location_id
		AND     device.device_type_id=device_type.device_type_id
		AND	rl.site_code='$input{site}'
		AND	rl.rack='$input{rack}'
		AND	rl.rack_row='$input{row}'
		AND	rl.room='$input{room}'
        	AND     rl.rack_u_offset_of_device_top +device_type.rack_units-1>=$input{offset}
                AND     rl.rack_u_offset_of_device_top <=$input{offset}
		AND	device.status != 'removed'
	};
# instead of exact match, look for other devices that may occupy this spot but are
# defined at another rack_location_id
#		AND	location.rack_u_offset_of_device_top=$input{offset}
	my $sth=$dbh->prepare($sql);
print "Query: <PRE>$sql</PRE>\n";
	if ($sth) {
		my ($did,$side);
		$sth->execute();
		print "todo: add checking for overlapping entries, front/back JazzHands.location.rack_side issues\n";
		while (($did,$side)=$sth->fetchrow_array()) {
			# if more than one device shows up here, list it; no problem.
			# we just append to the html fragment.
			
			printf ("<H4>%s Rack %s-%s-%s Offset %d, %s</H4>",
				$input{site},
				$input{room},
				$input{row},
				$input{rack},
				$input{offset},
				$side);
			&disp_device($did);
		}
		$sth->finish();
	}
	return;
}


# given dbh to JazzHands and device_id,
# return html fragment with serial console info for that device
# (you could get 0, 1, or more console hits)
sub get_console {
	my ($dbh,$did)=@_;
	my $retbuf="";

	return "?";
	my($sql)=qq{
		SELECT	d1.device_name,
         		p1.port_name,
        		d2.device_name,
         		p2.port_name
		FROM	physical_port p1,
     			physical_port p2,
     			device d1,
     			device d2,
        		layer1_connection,
        		device_function
		WHERE 	p1.device_id=d1.device_id
		AND	p2.device_id=d2.device_id
		AND	d1.device_id=$did
		AND	p1.port_type='serial'
		AND	p2.port_type='serial'
		AND	device_function.device_id=d2.device_id
		AND	device_function.device_function_type='consolesrv'
		AND	((p1.physical_port_id=
				layer1_connection.physical_port1_id
        		AND	p2.physical_port_id=
				layer1_connection.physical_port2_id)
        		OR
        		(p2.physical_port_id=
				layer1_connection.physical_port1_id
        		AND	p1.physical_port_id=
				layer1_connection.physical_port2_id))
	};
	my $sth=$dbh->prepare($sql);
	$sth->execute();
	# have to accomodate the case of some devices that
	# have two console lines
	while(($d1,$p1,$d2,$p2)=$sth->fetchrow_array()) {
		## $p2 =~ s/ttyS/20/;
		$retbuf .= "$d2 $p2<BR>";
	}

	$sth->finish();
	return ($retbuf);
}

# given dbh to JazzHands and device_id,
# return html fragment with nic and switch port info
# for that device
# (you could get 0, 1, or more hits)
sub get_switchport {
	my ($dbh,$did)=@_;
	my $retbuf="";

	return("?");
#		AND	d1.device_name='nameserver.example.com'
	my($sql)=qq{
		SELECT	d1.device_name,
         		p1.port_name,
        		d2.device_name,
         		p2.port_name
		FROM	physical_port p1,
     			physical_port p2,
     			device d1,
     			device d2,
        		layer1_connection,
        		device_function
		WHERE 	p1.device_id=d1.device_id
		AND	p2.device_id=d2.device_id
		AND	d1.device_id=$did
		AND	p1.port_type='network'
		AND	p2.port_type='network'
		AND	device_function.device_id=d2.device_id
		AND	((p1.physical_port_id=
				layer1_connection.physical_port1_id
        		AND	p2.physical_port_id=
				layer1_connection.physical_port2_id)
        		OR
        		(p2.physical_port_id=
				layer1_connection.physical_port1_id
        		AND	p1.physical_port_id=
				layer1_connection.physical_port2_id))
	};
	my $sth=$dbh->prepare($sql);
	$sth->execute();
	# have to accomodate the case of some devices that
	# have two console lines
	while(($d1,$p1,$d2,$p2)=$sth->fetchrow_array()) {
		$retbuf .= "$d1:$p2 to $d2:$p2<BR>";
	}

	$sth->finish();
	return ($retbuf);
}
