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

sub print_error_screen {
	my $cgi = new CGI;

	print $cgi->header;
	print $cgi->start_html("STAB Error Page");

	print $cgi->h3(
"Congratulations, you have found a problem in the STAB application."
	);

	print qq{
		You have found an error in the stab error/message notification
		system.  You can report this to 
	}, $stab->support_email();

	my $notemsg = $cgi->param("__notemsg__");
	my $errmsg  = $cgi->param("__errmsg__");

	if ( defined($notemsg) ) {
		print $cgi->p(
			qq{
			The last action attempted to pass on the following
			note: $notemsg
		}
		);
	}

	if ( defined($errmsg) ) {
		print $cgi->p(
			qq{
			The last action attempted to pass on the following
			error: $errmsg
		}
		);
	}

	print $cgi->end_html;
}

print_error_screen();
