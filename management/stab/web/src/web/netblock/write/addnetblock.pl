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
use Data::Dumper;

do_add_child_netblock_prompt();

###########################################################################3
#
# does the actual work.
#
###########################################################################3

sub do_add_child_netblock_prompt {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";
	my $dbh  = $stab->dbh          || die "Could not create dbh";

	my $netblkid = $cgi->param('id') || undef;

	my @errors;
	my $blk;

	if ( defined($netblkid) ) {

		$blk = $stab->GetNetblock(
			netblock_id => $netblkid,
			errors      => \@errors
		);

		if ( !defined($blk) ) {
			if (@errors) {
				$stab->error_return( join ",", @errors );
			} else {
				$stab->error_return("Unknown Parent Netblock");
			}
		}
	}
	print $cgi->header(      { -type  => 'text/html' } ),            "\n";
	print $stab->start_html( { -title => 'STAB: Add a netblock' } ), "\n";
	if ( defined($blk) ) {
		print $cgi->h2( "Add a child to ",
			$blk->IPAddress, ( $blk->hash()->{'DESCRIPTION'} || "" ) );
	} else {
		print $cgi->h2("Add a netblock");
	}

	print $cgi->start_form( { -action => "doadd.pl" } ), "\n";
	print "IP/Bits: "
	  . $cgi->textfield( { -size => 15, -name => 'ip' } ) . "/"
	  . $cgi->textfield( { -size => 2,  -name => 'bits' } ) . "\n";
	print $cgi->br,        "\n";
	print "Description: ", $cgi->textfield('description') . "\n";
	print $cgi->submit( { -label => 'Submit' } ), "\n";
	if ( defined($netblkid) ) {
		print $cgi->hidden( 'parentnblkid', $netblkid );
	}
	print $cgi->end_form, "\n";
	print $cgi->end_html, "\n";

	$stab->commit;
	undef $stab;
}
