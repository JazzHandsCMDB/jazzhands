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

use strict;
use warnings;
use CGI;
use vars qw($cgi);

$cgi = new CGI;

print $cgi->header( { -type => 'text/html' } ), "\n";

print $cgi->start_html(
	{
		-head => $cgi->Link(
			{
				-rel  => 'icon',
				-href => "/stab.png",
				-type => 'image/png'
			}
		  )
		  . $cgi->Link(
			{
				-rel  => 'shortcut icon',
				-href => "/stab.png",
				-type => 'image/png'
			}
		  ),

		-title => 'STAB Statistics',

	}
  ),
  "\n";

print $cgi->h2( { -align => 'center' }, "Device Statistics" );

print $cgi->ul(
	$cgi->li(
		$cgi->a( { -href => "baseline_summary.html" },
			"Baseline Statistics" )
		  . " - breakdown of machines and if they have been installed with UWO\n"
	  )
	  . $cgi->li(
		$cgi->a( { -href => "devices_total.html" }, "Devices Tracked" )
		  . " - breakdown of network elements tracked in JazzHands over time\n"
	  )
	  . $cgi->li(
		$cgi->a( { -href => "by_mclass/" }, "Mclass Statistics" )
		  . " - breakdown of machines in the central account management system\n"
	  )
);

print $cgi->hr;
print $cgi->i("nobody\@EXAMPLE.COM");

print $cgi->end_html, "\n";

exit;
