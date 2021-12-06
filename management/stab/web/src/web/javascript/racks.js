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

// Let's save the form data just after the page has finished loading
// to be able to see what's changed later on
var formOriginalData = new Array();

$( document ).ready(function() {
    formOriginalData = $("#RACK_FORM").serializeArray();
});



function verify_rack_submission(form) {
	var nogo = new Array();
	var values = new Array();

	// Get the submitted form data
	var formSubmittedData = new Array();
	formSubmittedData = $("#RACK_FORM").serializeArray();

	// Get the original and submitted site data
	var dataPoints = [ 'SITE_CODE', 'ROOM', 'SUB_ROOM', 'RACK_ROW', 'RACK_NAME' ];
	for( var i in dataPoints ) {
		values = $.grep( formOriginalData.concat( formSubmittedData ), function( n, index ) {
			regex = new RegExp( '^' + dataPoints[i] + '_[0-9]' );
			return ( 'name' in n && regex.test( n.name ) );
		});
		if( values.length == 2 && values[0].value != values[1].value ) {
			nogo.push( 'You have changed the rack ' + dataPoints[i].toLowerCase().replace( '_', ' ' ) + ' from ' + values[0].value + ' to ' + values[1].value + '.' );
		}
	}

	$("input.scaryrm:checked").each(function() {
		if( $(this).hasClass('rmrack') ) {
			nogo.push("You have selected to retire the rack.  This will remove all devices in the rack and the rack from the database.  This should only be done if the rack and devices are behing physically removed.");
		}
		if( $(this).hasClass('demonitor') ) {
			nogo.push("You have chosen to take all the devices in this rack out of monitoring");
		}

	});

	if(!nogo.length) {
		return true;
	}

	nogo[nogo.length] = '<p>';
	nogo[nogo.length] = "<b>Are you sure you want to do this?</b>"

	verifybox = $('#verifybox');
	$(verifybox).css('visibility', 'visible');
	$(verifybox).show();

	for(var i =0; i < nogo.length; i++) {
		var li = $("<li/>");
		$(li).append( nogo[i]);
		$(verifybox).append(li);
	}

	var span = $("</p>");
	$(verifybox).append(span);

	var yes = $("<input/>", {
		type: 'button',
		value: 'Yes',
	}).click( function() { form.submit(); });
	$(span).append(yes);

	var no = $("<input/>", {
		type: 'button',
		value: 'No',
	}).click(
		function() {
			$(verifybox).hide();
			$(verifybox).empty();
		}
	);
	$(span).append(no);
	form.dontSubmit = false;
	return false;
}

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
	console.log( url );
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

