#!/usr/bin/env perl
#
# Copyright (c) 2010-2018 Todd M. Kover
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

#
# probably want to tweak to not double-pass all data (orig_{desc,ticket})
#

use strict;
use warnings;
use Net::IP;
use FileHandle;
use JazzHands::STAB;
use JazzHands::Common qw(:all);
use Data::Dumper;
use Carp;
use Math::BigFloat;

do_dump_netblock();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3

sub get_netblock_id {
	my ( $stab, $block ) = @_;

	my $dbh = $stab->dbh;

	my $base = $block->ip();
	my $bits = $block->prefixlen();

	my $q = qq{
		select	netblock_id
		  from	netblock
		 where	ip_address = net_manip.inet_ptodb(?, 1)
		   and	family(ip_address) = ?
	};
	my $sth = $stab->prepare($q)  || $stab->return_db_err($dbh);
	$sth->execute( $base, $bits ) || $stab->return_db_err($sth);

	my $x = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$x;
}

sub get_max_level {
	my ( $stab, $start_id ) = @_;

	my $dbh = $stab->dbh;

	my $q = qq{
		select  max(netblock_level)
		  from  v_netblock_hier
		 where	root_netblock_id = ?
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($start_id)     || $stab->return_db_err($sth);
	my $x = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$x;
}

sub make_url {
	my ( $stab, $nblkid ) = @_;

	my $cgi = $stab->cgi;

	my $c = new CGI($cgi);
	$c->delete('block');
	$c->param( 'nblkid', $nblkid );
	$c->self_url;
}

sub dump_toplevel {
	my ( $stab, $dbh, $cgi ) = @_;

	my $showsite = $cgi->param('showsite') || 'yes';

	print $stab->start_html(
		-title      => 'STAB: Top Level Netblocks',
		-javascript => 'netblock',
	);
	print netblock_search_box($stab);

	print "Please select a block to drill down into, or "
	  . $cgi->a( { -href => "write/addnetblock.pl" }, "[Add a Netblock]" );

	my $q = qq{
		SELECT
			nb.ip_address,
			nb.netblock_id,
			nb.netblock_status,
			nb.description,
			snb.site_code
		  from  netblock nb
				left join site_netblock snb
					on snb.netblock_id = nb.netblock_id
		 where	nb.parent_netblock_id is NULL
		   and	nb.netblock_type = 'default'
		 order by nb.ip_address
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute                || $stab->return_db_err($sth);

	print "<ul>\n";
	while ( my ( $ip, $id, $stat, $desc, $site ) = $sth->fetchrow_array ) {
		next if ( defined($site) && !defined($showsite) );
		my $url = make_url( $stab, $id );
		if ( !defined($site) ) {
			$site = "-";
		}

		print "\t"
		  . $cgi->li( join(
			" ",
			$cgi->span( { -class => 'netblocksite' }, $site ),
			$cgi->span(
				{ -class => 'netblocklink' },
				"- ",
				$cgi->a( { -href => $url }, "$ip" )
			),
			$cgi->span(
				{ -class => 'netblockdesc' },
				"- " . ( ($desc) ? $desc : "" )
			),
			"\n"
		  ) );
	}
	print "</ul>\n";
	$sth->finish;

	print $cgi->end_html, "\n";
	$dbh->rollback;
	$dbh->disconnect;
}

sub dump_nodes {
	my ( $stab, $p_nblkid, $nblk ) = @_;

	my $nb       = new Net::IP( $nblk->{ _dbx('IP_ADDRESS') } );
	my $fam      = $nblk->{ _dbx('FAMILY') } || -1;
	my $showgaps = 1;
	if ( $fam == 6 ) {
		$showgaps = 0;
	} elsif ( $nb->prefixlen() <= 22 ) {
		$showgaps = 0;
	}

	my $cgi = $stab->cgi;

	print $cgi->start_form(
		-method => 'POST',
		-action => 'ipalloc/allocate_ip.pl'
	  ),
	  "\n";

	my $isbcst;
	if ( $nblk->{ _dbx('MASKLEN') } <= 30 ) {
		$isbcst = 1;
	}

	print print_netblock_allocation( $stab, $p_nblkid, $nb, $isbcst );

	print $cgi->hidden( -name => 'NETBLOCK_ID', -default => $p_nblkid );
	print $cgi->submit( -align => 'center', -name => 'Submit IP/DNS Updates' );
	print $cgi->start_table( { -class => 'nblk_ipallocation' } );

	print $cgi->th( [ 'IP', 'Status', 'DNS', 'Description', ] );

	my $q = qq{
		select	nb.netblock_id,
			ni.device_id,
			dns.dns_record_id,
			dns.dns_name,
			dom.soa_name,
			net_manip.inet_dbtop(nb.ip_address) as ip,
			nb.ip_address,
			nb.netblock_status,
			nb.description
		  from	netblock nb
			left join dns_record dns
				on dns.netblock_id = nb.netblock_id
				and dns.dns_type in ('AAAA', 'A', 'A6')
			left join dns_domain dom
				on dns.dns_domain_id = dom.dns_domain_id
			left join network_interface_netblock ni
				on ni.netblock_id = nb.netblock_id
		 where	nb.parent_netblock_id = ?
		order by nb.ip_address
			-- XXX ,decode(dns.should_generate_ptr, 'Y', 1, 0)
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err;
	$sth->execute($p_nblkid)     || $stab->return_db_err($sth);

	if ($showgaps) {
		my $hashref = $sth->fetchall_hashref( _dbx('IP') );
		$sth->finish;

		my $newnb = new Net::IP( $nb->print );
		do {
			my $ip = $newnb->ip();
			my $desc;
			if ( ( $isbcst && $ip eq $nb->ip() ) ) {
				$desc = "reserved for network address\n";
			} elsif ( ( $isbcst && $ip eq $nb->last_ip ) ) {
				$desc = "reserved for broadcast address\n";
			}
			print $stab->build_netblock_ip_row( undef,
				$nblk, $hashref->{$ip}, $ip, $desc );
		} while ( ++$newnb );
	} else {

		# ipv6 is different because dumping out a /64 is going to be an
		# effing huge web page.  ipv4 could probably be folded into that,
		# but being able to visualize the spaces is useful, so maybe only
		# for blocks after a certain size
		my $lastip;
		my $trgap = 0;
		my $gapno = 0;
		my $first = 1;

		# XXX - need to deal with ipv6 in the db, not translate address
		# here.
		while ( my $hr = $sth->fetchrow_hashref ) {
			my $printable = $hr->{ _dbx('IP_ADDRESS') };
			$printable =~ s,/\d+$,,;
			my $myip = new Net::IP($printable)
			  || die( Net::IP::Error() );
			#
			# deal with any gaps at the beginning
			#
			if ($first) {
				$first = 0;
				my $thegap = $myip->intip() - $nb->intip();
				if ( $thegap > 0 ) {
					print $stab->build_netblock_ip_row( {
						-trgap => $trgap++,
						-gap   => $thegap,
						-gapno => $gapno++
					} );

				}
			}

			#
			# deal with any gaps
			#
			my $ip = $hr->{ _dbx('IP_ADDRESS') };
			if ( defined($lastip) ) {
				my $thegap = $myip->intip() - $lastip->intip() - 1;
				if ( $thegap > 0 ) {
					print $stab->build_netblock_ip_row( {
						-trgap => $trgap++,
						-gap   => $thegap,
						-gapno => $gapno++
					} );
				}
			}
			$lastip = $myip;
			print $stab->build_netblock_ip_row( undef, $nblk, $hr, $ip );
		}

		# deal with empty block
		if ( !$lastip ) {
			$lastip = $nb;
		}

		#
		# check the block to see how many nodes are left at the end and
		# print as much
		#
		my $l         = $nb->last_ip();
		my $endoblock = new Net::IP($l) || die Net::IP::Error();
		if ( $endoblock->ip() ne $lastip->ip() ) {
			my $thegap = $endoblock->intip() - $lastip->intip();
			if ( $thegap > 1 ) {
				print $stab->build_netblock_ip_row( {
					-trgap => $trgap++,
					-gap   => $thegap,
					-gapno => $gapno++
				} );
			}
		}
	}

	print $cgi->end_table;

	# XXX - need to reconsider when/how to do this.
	if (0) {
		print dump_netblock_routes( $stab, $p_nblkid, $nb );
	}
	print $cgi->submit( -align => 'center', -name => 'Submit IP/DNS Updates' );
	print $cgi->end_form, "\n";
}

sub get_netblock_link_header {
	my ( $stab, $nblkid, $blk, $startnblkid, $descr, $pnbid, $site, $numkids )
	  = @_;

	my $cgi = $stab->cgi;
	my $dbh = $stab->dbh;

	my $showsite = $stab->cgi_parse_param('showsite');

	my $displaysite = "";
	if ( defined($showsite) ) {
		$displaysite = ( "[" . ( defined($site) ? $site : "" ) . "] " );
	}

	my $parent = "";

	my $ops = "";
	#
	# Something of a hack.  If it has no "single address" children, then
	# allow it to be subnetable.
	#
	if ( ( my $hassingles = num_kids( $stab, $nblkid, 'Y' ) ) == 0 ) {
		$ops = " - "
		  . $cgi->a(
			{ -href => "write/addnetblock.pl?id=$nblkid" },
			$cgi->img( {
				-class => 'subnet',
				-src   => "../stabcons/Axe_001.svg",
				-alt   => "[Subnet]",
				-title => "Subnet Network"
			} )
		  )
		  . $cgi->a( {
				-href  => "write/rmnetblock.pl?id=$nblkid",
				-class => 'rmnetblock'
			},
			''
		  );
	}

	my $name = "NETBLOCK_DESCRIPTION_$nblkid";

	# We need to escape any html code here, otherwise
	# html / javascript code would be interpreted (code injection).
	# This is typically if the field contains <script>...</script>.
	# It means that we'll have to unescape it later in the javascript
	# processing, which creates the editable field.
	$descr = CGI::escapeHTML($descr);

	$descr = $cgi->span( {
			-class => 'editabletext',
			-id    => $name
		},
		( $descr || "" )
	);

	my $expand = "";
	#
	# If there are any networks that are children of this one, print an
	# expansion arrow for javaacripty goodness.
	#
	if ($numkids) {
		$expand = $cgi->a(
			{ -class => 'netblkexpand' },
			$cgi->img( {
				-class => 'netblkexpand',
				-src   => '../stabcons/collapse.jpg'
			} )
		);
	}

	my $url = make_url( $stab, $nblkid );

	return join(
		" ",
		$cgi->span(
			{ -class => 'netblocklink' },
			$expand,
			$cgi->a( { -href => $url }, $blk )
		  )
		  . "-"
		  . $displaysite
		  . $cgi->span( { -class => 'netblockdesc' }, ( $descr || "" ) )
		  . $ops
	);
}

sub num_kids {
	my ( $stab, $nblkid, $issingle ) = @_;

	my $dbh = $stab->dbh;

	$issingle = 'N' if ( !defined($issingle) );

	my $q = qq{
		select	count(*)
		  from	netblock
		 where	parent_netblock_id = ?
		   and	is_single_address = ?
	};
	my $sth = $stab->prepare($q)        || $stab->return_db_err($dbh);
	$sth->execute( $nblkid, $issingle ) || $stab->return_db_err($sth);
	my $x = ( $sth->fetchrow_array )[0];
	$sth->finish;
	$x;
}

sub do_dump_netblock {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $dbh = $stab->dbh || die "Could not create dbh";
	my $cgi = $stab->cgi || die "Could not create cgi";

	#
	# expand is largely deprecated and can almost certainly go away.
	#

	my $start_id = $stab->cgi_parse_param('nblkid');
	my $block    = $stab->cgi_parse_param('block');
	my $expand   = $stab->cgi_parse_param('forceexpansion');

	print $cgi->header( { -type => 'text/html' } ), "\n";

	my $nb;
	if ( !defined($start_id) ) {
		if ( defined($block) ) {
			$nb       = new Net::IP($block);
			$start_id = get_netblock_id( $stab, $nb );

			if ( !defined($start_id) ) {
				$stab->error_return("Netblock not found");
			} else {
				my $url = make_url( $stab, $start_id );
				print $cgi->redirect($url);
				exit 1;
			}
		}
	} else {
		if ( $start_id !~ /^\d+$/ ) {
			$stab->error_return("Invalid netblock id ($start_id) specified");
		}

		my $netblock =
		  $stab->get_netblock_from_id( $start_id,
			{ is_single_address => 'N' } );
		if ( !defined($netblock) ) {
			$stab->error_return("Invalid netblock id ($start_id) specified");
		}
		my $base = $netblock->{ _dbx('IP_ADDRESS') };
		$nb = new Net::IP($base);
	}

	my ($nblk);

	#
	# if a bogus block was specified, it will still be undef.
	#
	if ( !defined($start_id) ) {
		dump_toplevel( $stab, $dbh, $cgi );
		exit;
	} else {
		$nblk = $stab->get_netblock_from_id( $start_id,
			{ is_single_address => 'N' } );
		if ( !defined($nblk) ) {
			$stab->error_return( "Unable to find Netblock ($start_id)",
				undef, 1 );
		}
	}

	my $q = qq{
		select  h.netblock_level,
			h.netblock_id,
			h.ip_address,
			h.netblock_status,
			h.is_single_address,
			family(h.ip_address) as family,
			masklen(h.ip_address) as masklen,
			h.description,
			h.parent_netblock_id,
			h.site_code,
			coalesce (haskids.tally, 0) as haskids
		  from  v_netblock_hier h
				LEFT JOIN (
					SELECT	parent_netblock_id AS netblock_id,
							count(*) AS tally
					FROM	netblock
					WHERE	is_single_address = 'N'
					GROUP BY parent_netblock_id
				) haskids USING (netblock_id)
		where	h.root_netblock_id = ?
		order by h.array_ip_path
		-- XXX probably need to rethink the order by here.
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($start_id)     || $stab->return_db_err($sth);

	my $ipstr = $nblk->{ _dbx('IP_ADDRESS') };

	print $stab->start_html( {
		-title      => "Netblock $ipstr",
		-javascript => 'netblock',
	} );
	print netblock_search_box($stab);

	print $cgi->p( qq{
		This application is used to manage net block allocations as well as
		the assignment (largely reservation) of IP addresses. To manage the
		subdvision/chopping up of networks, use the "subnet this block'
		(<img class=subnet src="../stabcons/Axe_001.svg">) and  "remove this
		block" (<a class=rmnetblock></a>)
		icons. You may only add subnets or remove netblocks that don't have
		host IP allocations.
		It's possible to edit a netblock description by clicking on the text
		and confirming the change with the Enter key or the "Submit Netblock
		Updates" button.
	}
	);
	print $cgi->p(
		qq{
		For the allocation of individual IP addresses to hosts,
		you do this by changing the description field to be whatever the
		address is being allocated to.  In that case, the device will be
		marked as 'Reserved'.  Devices marked as 'Legacy' may or may not
		be in use (they're allocation was imported from legacy IP
		tracking systems that used to be authoritative for this data).
		Devices marked as 'Allocated' have been assigned to devices
		and can not be changed from within this part of STAB.
		(They should be changed from within the
	}, $cgi->a( { -href => "../device/" }, "device manager" ), ")."
	);

	my $root = $nblk->{'IP_ADDRESS'};

	my ( @hier, %kids );
	push( @hier, $root );

	print $cgi->p;

	if ( $nblk->{ _dbx('PARENT_NETBLOCK_ID') } ) {
		my $p =
		  $stab->get_netblock_from_id( $nblk->{ _dbx('PARENT_NETBLOCK_ID') } );
		print $cgi->a(
			{ -href => "./?nblkid=" . $p->{ _dbx('NETBLOCK_ID') } },
			"Parent: " . $p->{ _dbx('IP_ADDRESS') },
			(
				( $p->{ _dbx('DESCRIPTION') } )
				? $p->{ _dbx('DESCRIPTION') }
				: ""
			)
		);
	}

	print $cgi->start_form(
		-method => 'POST',
		-action => 'write/edit_netblock.pl'
	);

	# This does not work with individual expansion
	print $cgi->div(
		{ -class => 'centered' },
		$cgi->a( { -class => 'expandall' }, "Expand All" ),
		' // ',
		$cgi->a( { -class => 'collapseall' }, "Collapse All" ),
	);

	print $cgi->submit("Submit Netblock Updates");

	print $cgi->p();

	# This is required for oracle, I *THINK*.  Under postgresql, this results
	# in double printing  a given block.  All this needs to be rewritten.
	# ... and netmask bits is gone.

	my $lastl = -1;
	my @tiers;

	# push( @tiers, { first => '', ul => '' } );

	# indicates that we're in the process of descending into a hierarchy.
	my $isdescending = 0;
	while (
		my (
			$level,   $nblkid, $ip,    $status, $single, $family,
			$masklen, $descr,  $pnbid, $site,   $numkids
		)
		= $sth->fetchrow_array
	  )
	{
		#
		# build the printable row for this db row.
		# How it is used is decided later...
		#
		my $thing = get_netblock_link_header( $stab, $nblkid, $ip,
			$start_id, $descr, $pnbid, $site, $numkids );

		my $mknewtier = 0;
		my $addpeer   = 1;
		my $bumpup    = 0;

		#
		# this is for subnets that do not further subnet (kind of a hack
		# but as much time as I have spent on this, I'm going to let that go.
		if ( $#tiers == -1 ) {
			$mknewtier = 1;
		}

		#
		# When going up a level, need to close out the existing level and
		# roll it into the one above.  This may happen multiple times.
		#
		if ( $lastl > $level ) {
			for ( my $i = $lastl ; $i > $level ; $i-- ) {
				my $x = pop(@tiers);
				my $me =
				  $cgi->ul( { -class => 'nbhier' }, $x->{label}, $x->{kids} );
				$tiers[$#tiers]->{kids} .=
				  $cgi->li( { -class => 'nbkids' }, $me );
				$bumpup++;
			}

			# If this one has kids, then we're immediately going to create
			# a new level based on this one, because the next row will be
			# descendents.
			if ($numkids) {
				$mknewtier    = 1;
				$isdescending = 1;
			} else {
				$isdescending = 0;
			}
		} elsif ( $lastl == $level ) {
			#
			# In this case, we're about to drop into children of this row,
			# so make it so
			#
			if ($numkids) {
				$mknewtier    = 1;
				$isdescending = 1;
			} else {
				$isdescending = 0;
			}
		} else {    # lastl < $level
			if ($numkids) {
				$mknewtier    = 1;
				$isdescending = 1;
			} else {
				$isdescending = 0;
			}
		}

		#warn "$ip -- is:$isdescending mk:$mknewtier add:$addpeer last:$lastl/cur:$level kids:$numkids// tiers:", $#tiers, (($lastl != $#tiers + 1)?" -- WTF":""), "\n";

		if ($mknewtier) {
			push( @tiers, { label => $thing, kids => '', level => $level } );
		} elsif ($addpeer) {
			$tiers[$#tiers]->{kids} .=
			  $cgi->li( { -class => 'nbnokids' }, $thing );
		}
		$lastl = $level;
	}
	$sth->finish;
	for ( my $i = $lastl ; $i && $#tiers > 0 ; $i-- ) {
		my $x = pop @tiers;
		my $k =
		  ( length( $x->{kids} ) )
		  ? $cgi->li( { -class => 'nbnokids' }, $x->{kids} )
		  : "";
		$tiers[$#tiers]->{kids} .= $cgi->li( { -class => 'nbkids' },
			$cgi->ul( { -class => 'nbhier' }, $x->{label}, $k ) );
	}
	my $x = pop @tiers;
	print $cgi->ul( { -class => 'nbhier' }, $x->{label}, $x->{kids} );
	print "\n";
	print $cgi->submit("Submit Netblock Updates");
	print $cgi->end_form, "\n";
	if (   ( defined($expand) && $expand eq 'yes' )
		|| ( !defined($expand) && !num_kids( $stab, $start_id ) ) )
	{
		dump_nodes( $stab, $start_id, $nblk );
	}

	print $cgi->end_html, "\n";

	$sth->finish;
	undef $stab;
	exit 0;
}

sub netblock_search_box {
	my ($stab) = @_;

	my $cgi = $stab->cgi;

	$cgi->table(
		{ -align => 'center' },
		$cgi->Tr(
			{ -align => 'center' },
			$cgi->td(
				$cgi->start_form(
					-method => 'POST',
					-action => 'search.pl'
				),
				$cgi->div(
					$cgi->b("CIDR Search: "),
					$cgi->textfield( -name => 'bycidr' )
				),
				$cgi->div(
					$cgi->b("Description/Reservation Search: "),
					$cgi->textfield( -name => 'bydesc' )
				),
				$cgi->submit('Search'),
				$cgi->end_form
			)
		)
	);
}

sub print_netblock_allocation {
	my ( $stab, $nblkid, $nb, $isbroadcast ) = @_;

	my $dbh  = $stab->dbh;
	my $cgi  = $stab->cgi;
	my $size = new Math::BigFloat( $nb->size() );

	my $q = qq{
		select	netblock_status, count(*) as tally
		  from	netblock
		 where	parent_netblock_id = ?
		group by netblock_status
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($nblkid)       || $stab->return_db_err($sth);

	my (%breakdown);
	my $total = 0;
	while ( my ( $what, $tally ) = $sth->fetchrow_array ) {
		$breakdown{$what} = $tally;
		$total += $tally;
	}

	my $x       = "";
	my $tdclass = { -class => 'netblock_summary' };
	$x .= $cgi->Tr(
		$cgi->th( { -class => 'netblock_summary', -rowspan => 2 }, 'IPs' ),
		$cgi->th( { -class => 'netblock_summary', -rowspan => 2 }, 'Count' ),
		$cgi->th( { -class => 'netblock_summary', -colspan => 2 }, '%' )
	);
	$x .= $cgi->Tr(
		$cgi->th( $tdclass, 'of allocatable' ),
		$cgi->th( $tdclass, 'of netblock' )
	);

	#
	# non-organizational netblocks  end up with their network and
	# broadcast being consumed. consumed. consumed. consumed.
	#
	my $broadcast_network_count = 0;
	my $remark                  = '';
	if ($isbroadcast) {
		$remark = 'Note: first and last IPs are assigned to network/broadcast';
		$broadcast_network_count = 2;
	}

	$x .= $cgi->Tr(
		$cgi->td( $tdclass, 'In netblock' ),
		$cgi->td( $tdclass, $size ),
		$cgi->td( $tdclass, '' ),
		$cgi->td( $tdclass, '100.00%' )
	);

	my $allocatable = $size - $broadcast_network_count;
	$x .= $cgi->Tr(
		$cgi->td( $tdclass, 'Allocatable' ),
		$cgi->td( $tdclass, $allocatable ),
		$cgi->td( $tdclass, '100.00%' ),
		$cgi->td(
			$tdclass, sprintf( "%2.2f%%", ( $allocatable / $size ) * 100 )
		)
	);

	{
		my $free = $size - $total - $broadcast_network_count;
		my $pct  = sprintf( "%2.2f%%", ( $free / $size ) * 100 );
		my $pct2 = sprintf( "%2.2f%%", ( $free / $allocatable ) * 100 );
		$x .= $cgi->Tr(
			$cgi->td( $tdclass, 'Unallocated ("free")' ),
			$cgi->td( $tdclass, $free ),
			$cgi->td( $tdclass, $pct2 ),
			$cgi->td( $tdclass, $pct )
		);
	}

	foreach my $what ( sort( keys(%breakdown) ) ) {
		my $tally = $breakdown{$what};
		my $pct   = sprintf( "%2.2f%%", ( $tally / $size ) * 100 );
		my $pct2  = sprintf( "%2.2f%%", ( $tally / $allocatable ) * 100 );
		$x .= $cgi->Tr(
			$cgi->td( $tdclass, "$what" ),
			$cgi->td( $tdclass, $tally ),
			$cgi->td( $tdclass, $pct2 ),
			$cgi->td( $tdclass, $pct )
		);
	}

	#{
	#	my $pct = sprintf( "%2.2f%%", ( $total / $size ) * 100 );
	#	my $pct2 = sprintf( "%2.2f%%", ( $total / $allocatable ) * 100 );
	#	my $plural = ( $allocatable > 1 ) ? 's':'';
	#	$x .= $cgi->Tr(
	#		$cgi->td( $tdclass, "Allocated + Reserved" ),
	#		$cgi->td( $tdclass, $total ),
	#		$cgi->td( $tdclass, $pct2 ),
	#		$cgi->td( $tdclass, $pct )
	#	);
	#}
	if ($remark) {
		$x .= $cgi->Tr( $cgi->td(
			{ -class => 'netblock_summary', -colspan => 4 }, $remark
		) );
	}

	$cgi->div( { -align => 'center' },
		$cgi->table( { -class => 'netblock_summary' }, $x ) );
}

sub dump_netblock_routes {
	my ( $stab, $nblkid, $nb ) = @_;
	my $cgi = $stab->cgi;

	my $sth = $stab->prepare( qq{
		select	srt.STATIC_ROUTE_TEMPLATE_ID,
				srt.description as ROUTE_DESCRIPTION,
				snb.netblock_Id as source_netblock_id,
				snb.ip_address,
				ni.network_interface_id,
				ni.network_interface_name as interface_name,
				d.device_name,
				dnb.netblock_Id as dest_netblock_id,
				net_manip.inet_dbtop(dnb.ip_address) as ROUTE_DESTINATION_IP
		 from	static_route_template srt
				inner join netblock snb
					on srt.netblock_src_id = snb.netblock_id
				inner join network_interface_netblock ni
					on srt.network_interface_dst_id = ni.network_interface_id
				inner join netblock dnb
					on dnb.netblock_id = ni.netblock_id
				inner join device d
					on d.device_id = ni.device_id
		where	srt.netblock_id = ?
	}
	);

	$sth->execute($nblkid) || die $sth->errstr;

	my $tt = $cgi->td( [
		"Del", "Source IP", "/", "Bits",
		"Dest Device", "Dest IP", "Description"
	] );
	while ( my $hr = $sth->fetchrow_hashref ) {
		$tt .= build_route_Tr( $stab, $hr );

	}
	$tt .= build_route_Tr($stab);

	# $cgi->div({-align=>'center', -style=>'border: 1px solid;'},
	$cgi->h3( { -align => 'center' }, 'Static Routes' )
	  . $cgi->table( { -align => 'center', -border => 1 }, $tt )

	  #)
	  ;
}

sub build_route_Tr {
	my ( $stab, $hr ) = @_;
	my $cgi = $stab->cgi;

	my $dev = "";
	my $del = "ADD";
	if ($hr) {
		my $id = $hr->{ _dbx('STATIC_ROUTE_TEMPLATE_ID') };
		$dev =
		  $hr->{ _dbx('DEVICE_NAME') } . ":" . $hr->{ _dbx('INTERFACE_NAME') },
		  $del = $cgi->hidden(
			-name    => "STATIC_ROUTE_TEMPLATE_ID_$id",
			-default => $id
		  )
		  . $stab->build_checkbox( $hr, "", 'rm_STATIC_ROUTE_TEMPLATE_ID',
			'STATIC_ROUTE_TEMPLATE_ID' );

	}

	$cgi->Tr( $cgi->td( [
		$del,
		$stab->b_textfield(
			{ -allow_ip0 => 1 }, $hr,
			'SOURCE_BLOCK_IP',   'STATIC_ROUTE_TEMPLATE_ID'
		),
		"/",
		$stab->b_textfield( $hr, 'SOURCE_MASKLEN', 'STATIC_ROUTE_TEMPLATE_ID' ),
		$dev,
		$stab->b_textfield(
			{ -allow_ip0 => 1 },    $hr,
			'ROUTE_DESTINATION_IP', 'STATIC_ROUTE_TEMPLATE_ID'
		),
		$stab->b_textfield(
			$hr, 'ROUTE_DESCRIPTION', 'STATIC_ROUTE_TEMPLATE_ID'
		),
	] ) );
}
