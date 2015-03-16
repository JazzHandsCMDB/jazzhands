#!/usr/bin/env perl

#
# Copyright (c) 2010-2014 Todd Kover
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
# Copyright (c) 2013 Matthew Ragan
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

# Copyright (c) 2005-2010, Vonage Holdings Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#	 * Redistributions of source code must retain the above copyright
#	   notice, this list of conditions and the following disclaimer.
#	 * Redistributions in binary form must reproduce the above copyright
#	   notice, this list of conditions and the following disclaimer in the
#	   documentation and/or other materials provided with the distribution.
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
use JazzHands::STAB;

do_style_dump();

sub do_style_dump {
	my $stab = new JazzHands::STAB || die "Could not create STAB";

	my $cgi = $stab->cgi || die "Could not create cgi";

	print $cgi->header( { -type => 'text/css' } ), "\n";

	my $root = $stab->guess_stab_root;

	# this could be smarter.  It also apperas in STAB.pm for
	# the title bar
	if ( $root !~ m,://stab.[^/]+/?$, && $root !~ /dev/ ) {
		print <<END;

BODY { 
	background: url($root/images/development-background.png ); 
}
a { color: blue }
a:visited { color: purple }

END
	}

	print <<END;

BODY {
	Font-Family: Verdana, Arial, Helvetica, MS Sans Serif;
}

div.introblurb {
	margin-left: auto;
	margin-right: auto;
	text-align: center;
	width: 60%;
}

/* device box pretty */

TABLE.dev_checkboxes { background-color: lightyellow; border: 1px solid;}
TABLE.rack_summary { background-color: lightyellow; border: 1px solid;}

/* physical port popup box */

TABLE.primaryinterface { background-color: lightyellow; }
TD.header { background-color: orange; }
div.searchPopup {
	background: white;
	border: 1px solid black;
	border-top: none;
	font-size: 50%;
}
div.physPortPopup {
	background: lightblue;
	border: 1px solid black;
	font-size: 50%;
}
table.physPortTitle {
	background: lightgreen;
	border: 1px solid black;
	font-size: 100%;
	width: 600px;
}


/* Tabs */

div.tabgroup_pending {
	padding-top: 10px;
}

div#verifybox {
	border: 2px solid black;
	padding: 5px;
	background: red;
	text-align: center;
	width: 60%;
	margin-left: 20%;
}

div.maindiv {
	border: 2px solid black;
	padding: 3px;
}

div#tabthis {
	border: 1px solid black;
	padding-top: 10px;
	margin-top: 3px;
	background: #DDE;
}

tabgroup_pending {
	color: lightgrey
}

tabgrouptab { padding: 5px 0; }

div.tabthis {
	background: #DDE;
}

a.tabgroupactive {
	margin-top: 10px;
	padding: 3px 0.5em;
	padding-bottom: 4px;
	margin-left: 3px;
	border: 1px solid black;
	border-bottom-width: 0px;
	background: #DDE;
	text-decoration: none;
}

a.tabgrouptab {
	margin-top: 10px;
	padding: 3px 0.5em;
	margin-left: 3px;
	border: 1px solid black;
	border-bottom-width: 1px;
	background: #AAB;
	text-decoration: none;
}

a:hover.tabgrouptab {
	background: lightblue;
	color: black;
	border-bottom: 5px;
}

input#submitdevice { font-size: 60%;}


/* 	Rack display */

table.rackit {
	border: 1px solid black;
	background: #B0B0FF;
}

td.rackit_even {
	border: 1px solid black;
	background: #FFAA33;
}
td.rackit_odd {
	border: 1px solid black;
	background: \#FFFF33;
}
td.rackit_infrastructure {
	border: 1px solid black;
	background: grey;
}
td.rackit_vertical {
	width: 10px;
	text-align: center;
	border: 1px solid black;
	background: lightgrey;
}

/* SOA display */

table.soatable {
	background: lightgrey;
	border: 2px solid;
}

/* App display */

div.approle_inside {
	text-align: center;
	border: 1px solid;
}
div.approle {
	background: #DDE;
	border: 1px solid;
}
div.approle_leaf {
	color: green;
}
div.approle_undecided {
	/* color: yellow; */
	color: green;
}
a.approle_addchild {
	font-size: 50%;
	color: red; 
}

/* Ports */

span.port_label {
	color: green;
}

table.center_table, form.center_form {
	text-align: center;
}

table.center_table tbody {
	text-align: left;
}

div.approles {
	margin-left: auto;
	margin-right: auto;
	background: orange;
	text-align: center;
	border: 1px solid;
}
div.approles > div {
	text-align: left;
}

label {
	font-weight: bold;
}

/* Editable descriptions */

.hinttext, .hint {
	color: #a9a9a9;
	font-size: 75%;
	font-style: italic;
}

input.editabletext {
	width: 200px;
}

input.srvnum {
	width: 5em;
}

.irrelevant {
	display: none;
	visibility: hidden;
}

ul.collection {
	list-style-type: lower-roman;		/* should be none */
}

span.netblocksite {
	width: 8ex;
	float: left;
}

span.netblocklink {
	min-width: 30ex;
	float: left;
}

#SOA_MNAME, #SOA_RNAME {
	width: 35ex; 
}

tr.dnsadd {
	background: lightgrey;
}

tr.intadd {
	background: grey;
}

/* netblock management (pre rewrite */
table.nblk_ipallocation tr, table.nblk_ipallocation td {
	outline: 1px solid;
}

img.subnet {
	width: 1em;
}

table.intmoretable {
	background: lightyellow;
}

.intableheader {
	text-align: center;
	font-weight: bold;
	background: orange;
}

table.interfacetable {
	display: inline;
	margin: auto;
	text-align: center;
}

table.interfacetable tr {
	outline: 1px solid;
}

#verifybox li {
	list-style-type: none;
}

div.ncmanip {
	text-align: center;
	width: 100%;
	display: inline-block;
}

END
	undef $stab;
}
