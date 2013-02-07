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
# most of this presentation was written by chang.

use strict;
use warnings;
use JazzHands::STAB;

do_rackit();

sub do_rackit {
	my $stab = new JazzHands::STAB || die "Could not create STAB";
	my $cgi  = $stab->cgi          || die "Could not create cgi";

	my $site   = $stab->cgi_parse_param('SITE');
	my $rackid = $stab->cgi_parse_param('RACK_ID');

	#XXX my $site = $stab->cgi_parse_param('SITE_CODE');
	my $room   = $stab->cgi_parse_param('ROOM');
	my $row    = $stab->cgi_parse_param('ROW');
	my $rack   = $stab->cgi_parse_param('RACK');
	my $offset = $stab->cgi_parse_param('OFFSET');
	my $devid  = $stab->cgi_parse_param('DEVICE_ID');

	if ( !$rackid && ( $site && $row && $rack && $room ) ) {
		$rackid =
		  $stab->get_rackid_from_params( $site, $row, $rack, $room );
	}

	if ( $site && $row && $rack && $offset && $room ) {
		$stab->error_return("Offset View Not implemented");
		lookup_spot();
	} elsif ($rackid) {

     #XXX print $cgi->header, $stab->start_html("Rack: $site $room $row-$rack");
		print $cgi->header, $stab->start_html("Rack");
		print $stab->build_rack($rackid);
		print $cgi->end_html;
	} elsif ( $site && $row && $room ) {
		$stab->error_return("Row View Not implemented");
		show_row();
	} elsif ($site) {
		$stab->error_return("Site View Not implemented");
		show_site();
	} elsif ($devid) {
		$stab->error_return("Device View Not implemented");
		disp_device();
	} else {
		$stab->error_return("Global View Not implemented");
		show_chooser();
	}
}

exit 0;
