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
	if ( $root !~ m,://stab.[^/]+/?$, && $root !~ /dev[^e]/ ) {
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
	overflow: auto;
	overflow-y: scroll;
}

div.introblurb {
	margin-left: auto;
	margin-right: auto;
	text-align: center;
	width: 60%;
}

div.navbar {
	margin: auto;
	font-size: 75%;
	text-align: center;
}

div.errmsg {
	margin: auto;
	color: red;
	text-align: center;
}

div.notemsg {
	margin: auto;
	color: green;
	text-align: center;
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

div.dnsvalueref {
	margin-left: auto;
	margin-right: auto;
	background: lightblue;
	text-align: center;
	border: 1px solid;
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

/* Tabs */

div.tabgroup {
	padding-top: 10px;
}

tabgroup {
	color: lightgrey
}

tabgrouptab { padding: 5px 0; }

a.tabgrouptab {
	margin-top: 10px;
	padding: 3px 0.5em;
	margin-left: 3px;
	border: 1px solid black;
	border-bottom-width: 1px;
	background: #AAB;
	text-decoration: none;
	border-radius: 20px 20px 0px 0px;
}

a.tabgrouptab.active {
	padding-bottom: 4px;
	border-bottom-width: 0px;
	background: #DDE;
}

a:hover.tabgrouptab {
	background: lightblue;
	color: black;
	border-bottom: 5px;
}

div.tabcontent {
	display: none;
	border: 1px solid black;
	padding-top: 10px;
	margin-top: 3px;
	background: #DDE;
}

div.tabcontent.active {
	display: block;
}

input#submitdevice { font-size: 60%;}

/***************** START OF GENERIC JQUERY TABS ****************************/

/*
 * tabs default to 'off', but the tab bar item needs class stabbar_off set
 * because of the hover bits
 *
 * to to
 */
div.stabtabcontent {
	background: #DDE;
	border: 1px solid black;
	border-radius: 10px;
	width: 100%;
	margin:auto;
	min-width: 100ex;
}

div.stabtab {
	padding: 5px 0;
	display: none;
	visibility: hidden;
}

a.stabtab {
	margin-top: 10px;
	padding: 3px 0.5em;
	margin-left: 3px;
	border: 2px solid black;
	text-decoration: none;
	border-radius: 20px 20px 0px 0px;
	background: #AAB;
	border-bottom-width: 1px;
	color: white;
	padding-top: 10px;
}

a.stabtab_on {
	padding-bottom: 4px;
	background: #DDE;
	border-bottom-width: 0px;
	color: blue;
}

.stabtabbar a:hover.stabtab_off {
	background: lightblue;
	color: black;
	border-bottom: 5px;
}

div.stabtab_on {
	display: block;
	visibility: visible;
}

/******************************* END OF NEW TABS **************************/


/* 	Device search display */
table.devicesearch {
	border-collapse: collapse;
	margin: auto;
	border: 1px solid black;
}
tr.devicesearch:nth-child( even ) {
	border: 0px solid black;
	background: white;
}
tr.devicesearch:nth-child( odd ) {
	border: 0px solid black;
	background: #DDDDDD;
}
td.devicesearch {
	border: 0px solid black;
	padding-left: 5px;
	padding-right: 5px;
}

/* 	Network ranges display */
table.networkrange {
	border-collapse: collapse;
	margin: auto;
	border: 1px solid gray;
}
th.networkrange,td.networkrange {
	border: 1px solid gray;
	padding-left: 5px;
	padding-right: 5px;
}

/* 	Components display */
table.components {
	border-collapse: collapse;
	margin: auto;
	border: 1px solid gray;
}
th.components,td.components {
	border: 1px solid gray;
	padding-left: 5px;
	padding-right: 5px;
}
tr.components:nth-child( odd ) {
	background: #eee;
}
tr.components:nth-child( even ) {
	background: white;
}

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

/* DNS display */

form.dnspage, form.dnspage table {
	text-align: center;
	margin: auto;
}

table.dnsgentable {
	text-align: center;
	margin: auto;
	border: 2px solid;
}

table.soatable {
	text-align: center;
	margin: auto;
	background: lightgrey;
	border: 2px solid;
}

tr.even {
	background: lightgrey;
}

tr.odd {
	background: transparent;
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
	min-width: 200px;
}

input.srvnum {
	width: 5em;
}

/*
	 this exists for approval because display: none confuses the chosen
	jquery plugin
 */
.hidecorrection {
	visibility: hidden;
}

.irrelevant {
	display: none;
	visibility: hidden;
}

div.chosen-workaround {
	width: 100% !important;
}

div.ipdiv {
	width: 100%;
}

ul.collection {
	list-style-type: lower-roman;		/* should be none */
}

span.netblocksite {
	min-width: 8ex;
}

span.netblocklink {
	min-width: 30ex;
}

#SOA_MNAME, #SOA_RNAME {
	width: 35ex;
}

tr.intadd {
	background: grey;
}

td.intadd {
	background: grey;
}

table.dnstable {
	text-align: center;
	margin: auto;
	border: 1px solid;
}

table.dnstable tr.dnsrecord {
	text-align: left;
}

table.dnstable input.dnsttl {
	width: 6em;
}

table.dnstable input.dnsvalue {
	width: 29em;
}

table.dnstable input.dnsname {
	width: 10em;
}

select.dnsdomain {
	width: 25em;
}

.autocomplete-suggestions { border: 1px solid #999; background: lightyellow; overflow: auto; font-size: 80%;}
.autocomplete-suggestion { padding: 2px 5px; white-space: nowrap; overflow: hidden; }
.autocomplete-selected { background: #F0F0F0; }
.autocomplete-suggestions strong { font-weight: normal; color: #3399FF; }
.autocomplete-group { padding: 2px 5px; }
.autocomplete-group strong { display: block; border-bottom: 1px solid #000; }


.dnssubmit {
	display: block;
	margin: auto;
	text-align: center;
}

/* netblock management (pre rewrite */
table.nblk_ipallocation tr, table.nblk_ipallocation td {
	outline: 1px solid;
}

img.subnet {
	width: 1em;
}

/* This affects both the Add Network Interface and the Add IP Address
   headers */
.header_add_item {
	text-align: center;
	font-weight: bold;
	background: orange;
}

table.interfacetable {
	border-collapse: collapse;
	margin: auto;
	text-align: center;
	border: 1px solid;
}

table.interfacetable tr th:nth-child(2n), table.interfacetable tr td:nth-child(2n) {
	background: #EEEEEE;
}
table.interfacetable tr th:nth-child(2n+1), table.interfacetable tr td:nth-child(2n+1) {
	background: #CCCCCC;
}

table.interfacetable tr.network_interface_first_line {
	border-top: 1px solid;
}

/* This affects the Add Network Interface header */
table.interfacetable tr.header_add_item {
	border-top: 1px solid;
}

/* This affects the Add IP Address header */
table.interfacetable td.header_add_item {
	border-top: 1px solid;
}

table.interfacednstable tr th:nth-child(2n), table.interfacednstable tr td:nth-child(2n) {
	background: #EEEEFF;
}
table.interfacednstable tr th:nth-child(2n+1), table.interfacednstable tr td:nth-child(2n+1) {
	background: #CCCCDD;
}


table.interfacetable td {
	vertical-align: top;
	margin: auto;
	text-align: left;
	/*border-top: 1px solid;
	border-bottom: none;*/
}

/* This is required to remove all interferring browser styles */
table.interfacetable input, table.interfacetable select {
	/*-webkit-appearance: none;*/
	border: 1px solid lightgray;
	border-radius: 1px;
}

table.interfacednstable td {
	border: none;
}

table.interfacetable tr td.horizontal_separator {
    border: none;
	height: 10px;
	/*background-color: transparent;*/
}

table.dnsrefroot {
        width: 100%;
}

tr.dnsroot td {
	text-align: left;
}

table.intmoretable {
	background: lightyellow;
	border-collapse: collapse;
	border: none;
	width: 100%;
}

table.intmoretable td {
	border-collapse: collapse;
	border: none;
	text-align: left;
}

#verifybox li {
	list-style-type: none;
}

div.ncmanip {
	text-align: center;
	width: 100%;
	display: inline-block;
}

div.attestbox {
	min-width: 20ex;
	text-align: center;
}


table.attest {
	border: 2px solid;
	margin: auto;
	background: grey;
}

table.attest tbody tr.odd {
	background: lightgrey;
	border: 1px solid;
}

table.attest td {
	background: grey;
}

table.attest tbody th {
	background: lightgrey;
}

table.attest tbody tr.even {
	background: white;
}

table.attest tbody tr.even {
	background: white;
}

table.attest tbody tr.even td {
	background-color: white;
}
table.attest tbody tr.odd td {
	background-color: lightgrey;
}

.error {
	background-color: red;
	color: white;
}

.disabled  {
	/*pointer-events: none;*/
	opacity: .9;
	text-decoration: line-through;
}

.off  {
	pointer-events: none;
	opacity: .9;
	background-color: lightgrey;
}

.plusbutton {
	height: 1.2em;
	width: 1.2em;
	font-size: 1.0em;
	border: 1px solid;
	cursor: pointer;
	user-select: none;
	float: left;
	display: flex;
	align-items: center;
	justify-content: center;
}

.plusbutton:hover {
	transform: scale(1.2,1.2);
	color: blue;
}

img.button {
	height: 2ex;
	vertical-align: middle;
}

.toggle_container {
  display: inline-flex;
  height: 14px;
  background: lightgray;
  cursor: pointer;
  user-select: none;
  border-radius: 30%;
  box-shadow: inset 0 0 0 2px gray;
  color: darkgray;
  padding-top: 4px;
  padding-bottom: 0px;
  padding-left: 4px;
  padding-right: 16px;
}

.toggle_container.toggled {
  background: #bbbbff;
  padding-left: 16px;
  padding-right: 4px;
  color: #0000cc;
}

.toggle_container:hover {
  box-shadow: inset 0 0 0 2px #333333;
  color: black;
}

.toggle_switch {
  display: inline-flex;
  cursor: pointer;
  user-select: none;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background-color: black;
}

table.interfacetable input.button_switch, table.interfacetable input.button_switch[value='new'] {
  color: black;
  padding: 1px 10px;
  /*text-decoration: none;*/
  width: 6em;
}
table.interfacetable input.button_switch[value='new'] {
  background-color: #C0C0C0;
  border: 1px solid transparent;
  cursor: auto;
}
table.interfacetable input.button_switch {
  background-color: #AAAAAA;
  border: 1px solid #808080;
  cursor: pointer;
}
table.interfacetable input.button_switch:hover{
  border: 1px solid blue;
}

tr.marked_for_delete, td.marked_for_delete, input.marked_for_delete, select.marked_for_delete {
  box-shadow: inset 0 0 0 100px rgba(255, 128, 128, 0.2);
  mix-blend-mode: multiply;
}

tr.marked_for_unlink, td.marked_for_unlink, input.marked_for_unlink, select.marked_for_unlink {
  box-shadow: inset 0 0 0 100px rgba(255, 255, 128, 0.2);
  mix-blend-mode: multiply;
}

tr.marked_for_lock, td.marked_for_lock, input.marked_for_lock, select.marked_for_lock {
  box-shadow: inset 0 0 0 100px rgba(128, 128, 255, 0.2);
  mix-blend-mode: multiply;
}

/*.marked_for_update tr, .marked_for_update td, .marked_for_update input, .marked_for_update select {
  box-shadow: none;
}*/

table.interfacetable .dnsptr{
  width: 2em;
}

div.description {
	border: 3px solid;
	text-align: center;
	margin: auto;
	min-width: 75%;

}

div.directions {
	text-align: center;
	margin: auto;
	width: 60%;

}

div.process { background: orange; }
div.chain { background: lightgrey; }

div.attestsubmit {
	width: 100%;
	text-align: center;
}

td.correction {
	min-width: 30ex;
}

td.correction input {
	width: 100%;
}

/* Color for input fields with user-updated value */
input.tracked.changed, select.tracked.changed, textarea.tracked.changed {
	/*color: blue;*/
	/*border: 1px solid magenta;*/
	box-shadow: inset 0 0 0 1px rgb(255, 128, 255, 1.0), 0 0 0 2px rgb(255, 128, 255, 1.0);
}

/* Color for input fields with default initial value - not needed? */
/*input.tracked, select.tracked {
	color: black;
}*/

input.attestsubmit {
	background-color: green;
	color: white;
	border-radius: 20px;
	margin: auto;
	font-size: 130%;

}

.approveall {
	border: 1px solid;
	border-radius: 20px;
	margin: 2px;
	background: lightyellow;
}

.attesttoggle {
	border: 1px solid;
	border-radius: 20px;
	margin: 0px;
	margin: 0px;
	text-decoration: bold;
	background: lightyellow;
}

.approvaldue {
	margin: auto;
	text-align: center;
}

.collectionbox {
	margin: auto;
	text-align: center;
}

.duesoon {
	background: yellow;
}

.overdue {
	background: red;
	color: white;
}

tr.rowrm {
	background: red;
	text-decoration: line-through;
}

li.rmrow {
	background: red;
	text-decoration: line-through;
}

.mark_for_delete {
	background: red;
	text-decoration: line-through;
}

/*
	This is a CSS setup to make an image as the clickable element of an input
	checkbox
*/
input.mark_for_delete_control[type=checkbox] {
	display: none;
}
input.mark_for_delete_control[type=checkbox] + label {
	display:inline-block;
	background:url("/stabcons/redx.jpg") no-repeat;
	height: 18px;
	width: 18px;
	background-size: 100%;
}
input.mark_for_delete_control[type=checkbox]:hover + label {
	display:inline-block;
	background:url("/stabcons/Octagon_delete.svg") no-repeat;
	height: 18px;
	width: 18px;
	background-size: 100%;
}
input.mark_for_delete_control[type=checkbox]:checked + label {
	display:inline-block;
	background:url("/stabcons/Octagon_delete.svg") no-repeat;
	height: 18px;
	width: 18px;
	background-size: 100%;
}

td.pendingrm * {
	pointer-events: none;
	opacity: .5;
	text-decoration: line-through;
}

.buttonon {
	background: lightblue;
}

div.reporting {
	width: 100%;
	margin: auto;
}

table.reporting {
	border: 1px solid;
	margin: auto;
	text-align:center;
}

table.reporting >tbody{
	text-align:left;
}

table.reporting > tbody td {
	border: 1px solid;
	border-color: grey;
}


div.centeredlist {
	text-align: center;
	margin: auto;
}

ul.nbhier {
	padding-top: 0;
}

ul.nbhier > li.nbkids {
	list-style-type: none;
	margin-left: 0ex;
}

ul.nbhier > li.nbnokids {
	list-style-type: none;
	padding-left: 19px;
	margin-left: 5ex;
}

/* account (and eventually other) collection manipulation */

ul.collectionbox a.collpad {
	pointer-events: none;
	visibility: hidden;
}

ul.collectionbox li {
	width: 100%;
}

ul.collectionbox li.plus {
	list-style-type: none;
}

ul.collectionbox input {
	width: 50%;
	mid-width: 25ex;
}

form.picker ul {
	text-align: left;
	margin: auto;
}

h2.objectdetails {
	text-align: center;
	margin: auto;
}

div.collectionname {
	text-align: center;
	margin: auto;
}

div.collectionexpandview {
	position: absolute;
	border: 2px double;
	z-index: 2;
	left: 0;
	right: 0;
	margin: auto;
	text-align: center;
	vertical-align:center;
	min-width: 50ex;
	min-height: 20em;
	width: 50%;
	height: 50%;
	overflow-y: auto;
	background: lightgrey;
}
div.collectionexpandview ul {
	text-align: left;
}

END
	undef $stab;
}
