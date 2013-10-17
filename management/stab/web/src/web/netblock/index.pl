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

#
# probably want to tweak to not double-pass all data (orig_{desc,ticket})
#

use strict;
use warnings;
use Net::Netmask;
use Net::IP;
use FileHandle;
use JazzHands::STAB;
use JazzHands::Common qw(:all);
use Data::Dumper;
use Carp;
use Math::BigInt;

do_dump_netblock();

############################################################################3
#
# everything else is a subroutine
#
############################################################################3


sub get_netblock_id {
	my ( $stab, $block ) = @_;

	my $dbh = $stab->dbh;

	my $base = $block->base;
	my $bits = $block->bits;

	my $q = qq{
		select	netblock_id
		  from	netblock
		 where	ip_address = net_manip.inet_ptodb(?, 1)
		   and	netmask_bits = ?
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
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
	$sth->execute($start_id) || $stab->return_db_err($sth);
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
		  . $cgi->a( { -href => "write/addnetblock.pl" },
			"[Add a Netblock]" );

	my $q = qq{
		SELECT
			net_manip.inet_dbtop(nb.ip_address) as ip,
			nb.netblock_id,
			nb.netmask_bits, 
			nb.netblock_status, 
			nb.is_ipv4_address,
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
	$sth->execute || $stab->return_db_err($sth);

	print "<ul>\n";
	while ( my ( $ip, $id, $bits, $stat, $v4, $desc, $site ) =
		$sth->fetchrow_array )
	{
		next if ( defined($site) && !defined($showsite) );
		my $blk = "$ip/$bits";
		my $url = make_url( $stab, $id );
		if ( defined($site) ) {
			$site = "[$site] ";
		} else {
			$site = "";
		}

		print "\t"
		  . $cgi->li(
			$cgi->span({-class => 'netblocklink'}, $cgi->a( { -href => $url }, "$site$blk" ) )
			  # . " [$id] - " 
			  . " - " 
			  . $cgi->span( { -class => 'netblockdesc'}, ( ($desc) ? $desc : "" )),
			"\n"
		  );
	}
	print "</ul>\n";
	$sth->finish;

	print $cgi->end_html, "\n";
	$dbh->rollback;
	$dbh->disconnect;
}

sub dump_nodes {
	my($stab, $p_nblkid, $nblk) = @_;
	my $v4 = $nblk->{_dbx('IS_IPV4_ADDRESS')};
	my $org = 'N';

	my $cgi = $stab->cgi;

	print $cgi->start_form(-method=>'POST',
		-action=>'ipalloc/allocate_ip.pl'
	), "\n";

	my $nb;
	if($v4 eq 'Y') {
		$nb = new Net::Netmask($nblk->{_dbx('IP')}."/".$nblk->{_dbx('NETMASK_BITS')}) || return;
		print print_netblock_allocation($stab, $p_nblkid, $nb, $org);
	}

	print $cgi->hidden(-name => 'NETBLOCK_ID', -default => $p_nblkid);
	print $cgi->submit(-align=>'center', -name=>'Submit Updates');
	print $cgi->start_table({-class=>'nblk_ipallocation'});

	print $cgi->th(['IP', 'Status', 'DNS', 'Description', 'Ticket']);


	my $q = qq{
		select	nb.netblock_id, 
			nb.netmask_bits,
			ni.device_id,
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
			left join network_interface ni
				on ni.netblock_id = nb.netblock_id
		 where	nb.parent_netblock_id = ?
		order by nb.ip_address
			-- XXX ,decode(dns.should_generate_ptr, 'Y', 1, 0)
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err;
	$sth->execute($p_nblkid) || $stab->return_db_err($sth);

	if(!$v4 || $v4 eq 'Y') {
		my $hashref = $sth->fetchall_hashref(_dbx('IP'));
		$sth->finish;

		foreach my $ip ($nb->enumerate) {
			my $desc;
			if( ($org eq 'N' && $ip eq $nb->base) ) {
				$desc = "reserved for network address\n";
			} elsif( ($org eq 'N' && $ip eq $nb->broadcast) ) {
				$desc = "reserved for broadcast address\n";
			}
			print $stab->build_netblock_ip_row(undef,
				$nblk, $hashref->{$ip}, $ip, $desc
			);
		}
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
		while(my $hr = $sth->fetchrow_hashref) {
			#
			# deal with any gaps at the beginning
			#
			if($first) {
				$first = 0;
				my $bst = new Math::BigInt($nblk->{_dbx('IP_ADDRESS')});
				my $thegap = $hr->{_dbx('IP_ADDRESS')} - $bst;
				if($thegap > 0) {
					print $stab->build_netblock_ip_row(
						{ -trgap=> $trgap++, -gap => $thegap,
							-gapno => $gapno++ }
					);
					
				}
			}

			#
			# deal with any gaps
			#
			my $ip = $hr->{_dbx('IP')};
			if(defined($lastip)) {
				# pgsql - XXX
				# frickin' 64 bit support
				my $new = new Math::BigInt("$hr->{_dbx('IP_ADDRESS')}");
				my $thegap = $new - $lastip;
				if($thegap > 1) {
					print $stab->build_netblock_ip_row(
						{ -trgap=> $trgap++, -gap => $thegap,
							-gapno => $gapno++ }
					);
				}
			}
			$lastip = new Math::BigInt("$hr->{_dbx('IP_ADDRESS')}");
			print $stab->build_netblock_ip_row(undef,
				$nblk, $hr, $ip
			);
		}

		# deal with empty block
		if(!$lastip) {
			$lastip = new Math::BigInt($nblk->{_dbx('IP_ADDRESS')});
		}

		#
		# check the block to see how many nodes are left at the end and
		# print as much
		#
		my $thing = $nblk->{_dbx('IP')}."/".$nblk->{_dbx('NETMASK_BITS')};
		if(my $b = new Net::IP( $thing ) ) {
			my $x = new Net::IP($thing);
			my $bst = new Math::BigInt($nblk->{_dbx('IP_ADDRESS')});
			my $bsz = new Math::BigInt($x->size);
			my $size = new Math::BigInt($bst + $bsz);

			my $thegap = $size - $lastip;
			if($thegap > 1) {
				print $stab->build_netblock_ip_row(
					{ -trgap=> $trgap++, -gap => $thegap,
						-gapno => $gapno++ }
				);
			}
		} 
	}
	
	print $cgi->end_table;
	# XXX - need to reconsider when/how to do this.
	if(0) {
		print dump_netblock_routes($stab, $p_nblkid, $nb);
	}
	print $cgi->submit(-align=>'center', -name=>'Submit Updates');
	print $cgi->end_form, "\n";
}


sub get_netblock_link_header {
	my ( $stab, $nblkid, $blk, $bits, $startnblkid, $descr, $pnbid, $site ) = @_;

	my $cgi = $stab->cgi;
	my $dbh = $stab->dbh;

	my $showsite = $stab->cgi_parse_param('showsite');
	my $allowdescedit = $stab->cgi_parse_param('allowdescedit') || 'no';

	my $displaysite = "";
	if ( defined($showsite) ) {
		$displaysite = ( "[" . ( defined($site) ? $site : "" ) . "] " );
	}

	my $pnb = $stab->get_netblock_from_id( $pnbid, 1, 1 );
	my $parent = "";
	if ($pnb && $nblkid == $startnblkid) {
		my $purl = make_url( $stab, $pnbid );
		$parent = " - "
		  . $cgi->a( { -href => $purl, },
			"Parent: ", $pnb->{_dbx('IP')}. "/". 
				$pnb->{_dbx('NETMASK_BITS')} );
	}

	my $ops = "";
	if ( num_kids( $stab, $nblkid, 'Y' ) == 0 ) {
		$ops = " - "
		  . $cgi->a( { -href => "write/addnetblock.pl?id=$nblkid" },
			$cgi->img({
				-class=>'subnet',
				-src=>"../stabcons/Axe_001.svg",
				-alt=> "[Subnet]",
				-title=> "Subnet Network"
			}))
		  . $cgi->a( { -href => "write/rmnetblock.pl?id=$nblkid" },
			$cgi->img({
				-class=>'subnet',
				-src=>"../stabcons/Octagon_delete.svg",
				-alt=> "[Remove]",
				-title=> "Remove Network",
			})) 
		;
	}

	if ( 1 || $allowdescedit eq 'yes' ) {
		my $name = "NETBLOCK_DESCRIPTION_$nblkid";
		#$descr = $cgi->hidden(
		#	-name    => "orig_$name",
		#	-default => $descr
		#  )
		#  . $cgi->textfield(
		#	{
		#		-size  => 80,
		#		-name  => $name,
		#		-value => $descr
		#	}
		#  );
		$descr = $cgi->span({-class => 'editabletext',
			-id=> $name
			},($descr || ""));
			
	}

	my $url = make_url( $stab, $nblkid );
	return $cgi->li(
		$cgi->span({-class=>'netblocklink'},
			$cgi->a( { -href => $url }, $blk ))
		  . "-" 
		  . $displaysite
		  . $cgi->span({-class=>'netblockdesc'}, ( $descr || "" ))
		  . $ops,
		$parent, "\n"
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
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
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

	my $start_id      = $stab->cgi_parse_param('nblkid');
	my $block         = $stab->cgi_parse_param('block');
	my $expand        = $stab->cgi_parse_param('forceexpansion');
	my $allowdescedit = $stab->cgi_parse_param('allowdescedit') || 'no';

	print $cgi->header( { -type => 'text/html' } ), "\n";

	my $nb;
	if ( !defined($start_id) ) {
		if ( defined($block) ) {
			$nb = new Net::Netmask($block);
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
			$stab->error_return(
				"Invalid netblock id ($start_id) specified");
		}

		my $netblock =
		  $stab->get_netblock_from_id( $start_id, 1, 'N', 'N' );
		if ( !defined($netblock) ) {
			$stab->error_return(
				"Invalid netblock id ($start_id) specified");
		}
		my $base = $netblock->{_dbx('IP')};
		my $bits = $netblock->{_dbx('NETMASK_BITS')};
		if ($netblock->{_dbx('IS_IPV4_ADDRESS')} eq 'Y' && defined($base) && defined($bits) ) {
			$nb = new Net::Netmask("$base/$bits");
		}
	}

	my ($nblk);

	#
	# if a bogus block was specified, it will still be undef.
	#
	if ( !defined($start_id) ) {
		dump_toplevel( $stab, $dbh, $cgi );
		exit;
	} else {
		$nblk = $stab->get_netblock_from_id( $start_id, 1, 'N', 'N' );
		if ( !defined($nblk) ) {
			$stab->error_return(
				"Unable to find Netblock ($start_id)",
				undef, 1 );
		}
	}

	if($nblk->{_dbx('IS_IPV4_ADDRESS')} eq 'Y' && !defined($nb)) {
		$stab->error_return("You must specify a valid netblock!\n");
	}

	my $q = qq{
		select  netblock_level,
			netblock_id,
			ip,
			netmask_bits,
			netblock_status,
			is_single_address,
			is_ipv4_address,
			description,
			parent_netblock_id,
			site_code
		  from  v_netblock_hier
		where	root_netblock_id = ?
		order by array_ip_path
		-- XXX probably need to rethink the order by here.
	};

	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($start_id) || $stab->return_db_err($sth);

	my $ipstr = $nblk->{_dbx('IP')} . "/" . $nblk->{_dbx('NETMASK_BITS')};

	print $stab->start_html(
		{
			-title      => "Netblock $ipstr",
			-javascript => 'netblock',
		}
	);
	print netblock_search_box($stab);

	print $cgi->p(
		qq{
		This application is used to manage net block allocations as well as
		the assignment (largely reservation) of IP addresses.  Use the
		"Subnet this block" and "Remove this netblock" links to furthur
		subdivide the network into smaller networks.  You may only add
		subnets or remove netblocks that don't have host IP allocations.
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

	# neeed to see if we even need Net::Netmask.  I don't think we do
	# anymore.
	my $root;
	if($nblk->{_dbx('IS_IPV4_ADDRESS')} eq 'Y') {
		$root = $nb->base."/".$nb->bits;
	} else {
		$root = join('/', $nblk->{_dbx('IP')}, $nblk->{_dbx('NETMASK_BITS')});
	}

	my ( @hier, %kids );
	my $lastl = -1;
	push( @hier, $root );

	print $cgi->p;

	print $cgi->start_form(
		-method => 'POST',
		-action => 'write/edit_netblock.pl'
	);

	if ( $allowdescedit eq 'yes' || $nblk->{_dbx('CAN_SUBNET')} eq 'Y') {
		warn Dumper($nblk);
		print $cgi->submit("Submit Updates");
	}

	# This is required for oracle, I *THINK*.  Under postgresql, this results
	# in double printing  a given block.  All this needs to be rewritten.

	#print get_netblock_link_header(
	#	$stab, $start_id, $root, $nblk->{_dbx('NETMASK_BITS')},
	#	$start_id,
	#	$nblk->{_dbx('DESCRIPTION')},
	#	$nblk->{_dbx('PARENT_NETBLOCK_ID')}
	#);

	while (
		my (
			$level,  $nblkid, $ip,    $bits, $status,
			$single, $v4,     $descr,  $pnbid, $site
		)
		= $sth->fetchrow_array
	  )
	{
		if ( $lastl < $level ) {
			for ( my $i = $lastl ; $i < $level ; $i++ ) {
				print "<ul>";
			}
		}
		if ( $lastl > $level ) {
			print "</ul><ul>\n";
			for ( my $i = $lastl ; $i > $level ; $i-- ) {
				print "</ul>";
			}
		}
		my $blk = "$ip/$bits";

		print get_netblock_link_header(
			$stab,     $nblkid, $blk,   $bits,
			$start_id, $descr,  $pnbid, $site
		);
		$lastl = $level;
	}
	$sth->finish;
	for ( my $i = $lastl ; $i ; $i-- ) {
		print "</ul>";
	}
	print "\n";

	print $cgi->end_form, "\n";
	if (       ( defined($expand) && $expand eq 'yes' )
		|| ( !defined($expand) && !num_kids( $stab, $start_id ) ) )
	{
		dump_nodes( $stab, $start_id, $nblk);
	}

	print $cgi->end_html, "\n";

	$sth->finish;
	$dbh->rollback;
	$dbh->disconnect;
	$dbh = undef;
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
					$cgi->b(
"Description/Reservation Search: "
					),
					$cgi->textfield( -name => 'bydesc' )
				),
				$cgi->submit('Search'),
				$cgi->end_form
			)
		)
	);
}

sub print_netblock_allocation {
	my ( $stab, $nblkid, $nb, $org ) = @_;

	my $dbh  = $stab->dbh;
	my $cgi  = $stab->cgi;
	my $size = $nb->size;

	my $q = qq{
		select	netblock_status, count(*) as tally
		  from	netblock
		 where	parent_netblock_id = ? 
		group by netblock_status
	};
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($nblkid) || $stab->return_db_err($sth);

	my (%breakdown);
	my $total = 0;
	while ( my ( $what, $tally ) = $sth->fetchrow_array ) {
		$breakdown{$what} = $tally;
		$total += $tally;
	}

	#
	# non-organizational netblocks  end up with their network and
	# broadcast being consumed. consumed. consumed. consumed.
	#
	if ( $org eq 'N' ) {
		$breakdown{'Allocated'} += 2;
		$total += 2;
	}

	$total = 256 if ( $total > 256 );

	my $x = "";
	foreach my $what ( sort( keys(%breakdown) ) ) {
		my $tally = $breakdown{$what};
		my $pct = sprintf( "%2.2f%%", ( $tally / $size ) * 100 );
		$x .= $cgi->div("$what: $tally ($pct)");
	}

	{
		my $free = $size - $total;
		my $pct = sprintf( "%2.2f%%", ( $free / $size ) * 100 );
		$x .= $cgi->div("Unallocated: $free ($pct)");
	}

	{
		my $pct = sprintf( "%2.2f%%", ( $total / $size ) * 100 );
		$x .= $cgi->div("Total: $total of $size ($pct)");
	}

	$cgi->div( { -align => 'center', -style => 'color: orange' }, $x );
}

sub dump_netblock_routes {
	my ( $stab, $nblkid, $nb ) = @_;
	my $cgi = $stab->cgi;

	my $sth = $stab->prepare(
		qq{
		select	srt.STATIC_ROUTE_TEMPLATE_ID,
				srt.description as ROUTE_DESCRIPTION,
				snb.netblock_Id as source_netblock_id,
				net_manip.inet_dbtop(snb.ip_address),
				snb.netmask_bits as SOURCE_NETMASK_BITS,
				ni.network_interface_id,
				ni.network_interface_name as interface_name,
				d.device_name,
				dnb.netblock_Id as dest_netblock_id,
				net_manip.inet_dbtop(dnb.ip_address) as ROUTE_DESTINATION_IP
		 from	static_route_template srt
				inner join netblock snb
					on srt.netblock_src_id = snb.netblock_id
				inner join network_interface ni
					on srt.network_interface_dst_id = ni.network_interface_id 
				inner join netblock dnb
					on dnb.netblock_id = ni.netblock_id
				inner join device d
					on d.device_id = ni.device_id
		where	srt.netblock_id = ?
	}
	);

	$sth->execute($nblkid) || die $sth->errstr;

	my $tt = $cgi->td(
		[
			"Del",         "Source IP",
			"/",           "Bits",
			"Dest Device", "Dest IP",
			"Description"
		]
	);
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
		my $id = $hr->{_dbx('STATIC_ROUTE_TEMPLATE_ID')};
		$dev   = $hr->{_dbx('DEVICE_NAME')} . ":" . $hr->{_dbx('INTERFACE_NAME')},
		  $del = $cgi->hidden(
			-name    => "STATIC_ROUTE_TEMPLATE_ID_$id",
			-default => $id
		  )
		  . $stab->build_checkbox( $hr, "",
			'rm_STATIC_ROUTE_TEMPLATE_ID',
			'STATIC_ROUTE_TEMPLATE_ID' );

	}

	$cgi->Tr(
		$cgi->td(
			[
				$del,
				$stab->b_textfield(
					{ -allow_ip0 => 1 },
					$hr,
					'SOURCE_BLOCK_IP',
					'STATIC_ROUTE_TEMPLATE_ID'
				),
				"/",
				$stab->b_textfield(
					$hr,
					'SOURCE_NETMASK_BITS',
					'STATIC_ROUTE_TEMPLATE_ID'
				),
				$dev,
				$stab->b_textfield(
					{ -allow_ip0 => 1 },
					$hr,
					'ROUTE_DESTINATION_IP',
					'STATIC_ROUTE_TEMPLATE_ID'
				),
				$stab->b_textfield(
					$hr,
					'ROUTE_DESCRIPTION',
					'STATIC_ROUTE_TEMPLATE_ID'
				),
			]
		)
	);
}
