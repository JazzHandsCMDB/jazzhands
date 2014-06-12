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

function site_to_rack(siteid, rackdivid, where, locid) {
	var sitebox, rackdiv;
	var url, ajaxrequest;

	sitebox = document.getElementById(siteid);
	if(!sitebox) {
		return;
	}
	rackdiv = document.getElementById(rackdivid);
	if(!rackdiv) {
		return;
	}

	if(where == 'dev') {
		url = "device-ajax.pl?what=SiteRacks";
		url += ";type=" + where;
	} else {
		url = "../../device/device-ajax.pl?what=SiteRacks";
	}
	url += ";SITE_CODE=" + sitebox.value;
	if(locid != null) {
		url += ";RACK_LOCATION_ID=" + locid;
	}
	ajaxrequest = createRequest();
	ajaxrequest.open("GET", url, true);
	ajaxrequest.onreadystatechange = function () {
		if(ajaxrequest.readyState == 4) {
			var x = rackdiv;
			var htmlgoo = ajaxrequest.responseText;
			rackdiv.innerHTML = htmlgoo;
		}
	}
	ajaxrequest.send(null);
}

function setRackLinkRedir(dropfieldid, redirlinkid, root) {
	var dropfield, redirlink;
	if(dropfieldid == null) {
		return null;
	}
	dropfield = document.getElementById(dropfieldid);
	if(dropfield == null) {
		return null;
	}
	redirlink = document.getElementById(redirlinkid);
	if(redirlink == null) {
		return null;
	}

	if(root == null) {
		root = "./";
	}

	if(dropfield.value != null) {
		redirlink.href = root+"?RACK_ID=" + dropfield.value;
	} else {
		redirlink.href = "javascript:void(null);";
	}
}

