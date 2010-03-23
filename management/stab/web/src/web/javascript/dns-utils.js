/*
* Copyright (c) 2005-2010, Vonage Holdings Corp.
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*
* THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
//
// $Id$
//

//
// makes an object visible
//
function show_soa(switchid, tableid)
{
	var s, t
	s = document.getElementById(switchid);
	t  = document.getElementById(tableid);

	if(s != null && t != null) {
		s.style.visibility = 'hidden';
		s.style.display = 'none';

		t.style.visibility = 'visible';
		t.style.display = '';
	}
}

function dns_show_approles(button)
{
	var div;
	div = document.getElementById("approle_div");
	if(!div) {
		return;
	}

	if(div.style.display == 'none') {
		button.innerHTML = "Hide AppRoles";
		div.style.display = '';
	} else {
		button.innerHTML = "Show AppRoles";
		div.style.display = 'none';
	}
}

function dns_debug_addns(button)
{
	var ns, br;

	ns = document.createElement('input');
	ns.name = 'extra_ns';
	ns.type = 'text';
	button.parentNode.appendChild(ns);

	br = document.createElement('br');
	button.parentNode.appendChild(br);
}
