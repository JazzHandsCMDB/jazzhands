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

 * Copyright (c) 2014-2017, Todd M. Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
//
// $Id$
//

var request = null;

function forcedevtabload(tabname, devid) {
	if(devid == null) {
		return;
	}
	var gotoTab = document.getElementById(tabname);

	if(gotoTab == null || gotoTab.value == null || gotoTab.value == "") {
		return;
	}

	ShowDevTab(gotoTab.value, devid, true);
}

// This functions loads and displays a tab of the device page
function ShowDevTab( what, devid, bForceReload ) {

	// If the device id is null, we shouldn't be here
	if( devid === null ) return;

	// Get all the tab divs - they only exist if they have been loaded previously
	let tabDivs = document.getElementsByClassName( 'tabcontent' );

	// Create the div for the current content if it doesn't exist
	let divName = what + '_content';
	let divElement = document.getElementById( divName );
	let bNeedsLoading = false;
	if( ! divElement ) {
		bNeedsLoading = true;
		divElement = document.createElement( 'div' );
		divElement.id = divName;
		divElement.className = 'tabcontent active';
		divElement.style.textAlign = 'center';
		divElement.style.padding = '50px';
		divElement.innerHTML = '<div class="spinner align-middle"></div> <em>Loading ' + what + ' Tab, Please Wait...</em>';
		// Get the tabgroup div, and bail out if it doesn't exist
		let tabgroupDiv = document.getElementById( 'tabgroup' );
		if( ! tabgroupDiv ) return;
		tabgroupDiv.appendChild( divElement );

	// The div has already been loaded, just make it active
	} else {
		if( bForceReload ) {
			divElement.style.textAlign = 'center';
			divElement.style.padding = '50px';
			divElement.innerHTML = '<div class="spinner align-middle"></div> <em>Loading ' + what + ' Tab, Please Wait...</em>';
		}
		divElement.classList.add( 'active' );
	}

	// Make all tab divs inactive, except the current one
	for( let i = 0; i < tabDivs.length; i++ ) {
		if( tabDivs[i].id === divName ) continue;
		tabDivs[i].classList.remove( 'active' );
	}

	// Now loop on the tabs (<a> elements) and set the styles based on selection
	let tabElements = document.getElementsByClassName( 'tabgrouptab' );
	for( let i = 0; i < tabElements.length; i++ ) {
		if( tabElements[i].id === what ) {
			tabElements[i].classList.add( 'active' );
		} else {
			tabElements[i].classList.remove( 'active' );
		}
	}

	// If the selected tab was already loaded
	// and if we aren't forced to reload, we're done
	if( bNeedsLoading === false && bForceReload === false ) return;

	// Prepare the ajax call url
	let qstr = document.location + "";
	qstr = encodeURIComponent(qstr);
	if(qstr) {
		re = /^.*\?/;
		qstr.replace(re,  '');
		qstr.replace(/devid=\d+./, '');
		qstr.replace(/__notemsg__=[^&;]+/, '');
		qstr.replace(/__errormsg__=[^&;]+/, '');
	}

	let url = 'device-ajax.pl?what='+ what;
	url += ";passedin=" + qstr;
	url += ";DEVICE_ID=" + devid;

	// Execute the ajax query
	let ajaxrequest = createRequest();
	ajaxrequest.open("GET", url, true);
	ajaxrequest.onreadystatechange = function() {
		if(ajaxrequest.readyState == 4) {
			var htmlgoo = ajaxrequest.responseText;
			divElement.style.textAlign = '';
			divElement.style.padding = '';
			divElement.innerHTML = htmlgoo;
		}
		// Update the change tracking status of elements once the document is loaded
		$('.tracked').each( function() { updateChangeTrackingStatus( $(this)[0] ); } );
		// Update colors based on toggle swtich statuses
		$('.button_switch').each( function() {
			updateNetworkInterfaceUI( $(this)[0], $(this)[0].getAttribute('state'), false );
		} );
	}
	ajaxrequest.send(null);
}

// this is the legal way to do innerHTML, but this appears to be
// unnecessary.
function dynamiccontentNS6(elementid,content){
	if (document.getElementById && !document.all){
		rng = document.createRange();
		el = document.getElementById(elementid);
		rng.setStartBefore(el);
		htmlFrag = rng.createContextualFragment(content);
	while (el.hasChildNodes())
		el.removeChild(el.lastChild);
		el.appendChild(htmlFrag);
	}
}

function uncheck (id, restoclass) {
	var ochx, i;
	var me = document.getElementById(id);
	var dizclass, htmlgoo;

	if(me) {
		if(me.value = 'on') {
			ochx = document.getElementsByTagName("input");
			for(i = 0; i < ochx.length; i++) {
				dizclass = ochx[i].className;
				htmlgoo = ochx[i].name;
				if (ochx[i].className == restoclass) {
					if(ochx[i] != me) {
						ochx[i].checked = false;
					}
				}
			}
		}
	}
}

// //////////////////////////////////////////////////////////////////////////
//
// Parent Device smartness
//
// //////////////////////////////////////////////////////////////////////////
function updateDeviceParentLink(devid, paridfld) {
	var devlink;
	var txtfld;

	// if the name field is empty, but the id field is not, we also need
	// to sync that up.  This happens when the box is completely emptied.
	// XXX I think this needs to be reconciled with the hostname
	// selection code in switch/console/etc ports to make sure they make
	// things blank consistently.  (tho maybe not?)
	txtfld = document.getElementById("PARENT_DEVICE_NAME_"+devid);
	if(txtfld) {
		if(!txtfld.value || !txtfld.value.length) {
			paridfld.value = "";
		}
	}


	devlink = document.getElementById("parent_link_" + devid);
	if(devlink) {
		if(paridfld && paridfld.value) {
			devlink.href = "device.pl?devid=" + paridfld.value;
		} else {
			devlink.href = "javascript:void(null);";
		}
	}

}

function setDevLinkRedir(dropfield, redirlink, root) {
    if(! dropfield) {
	return null;
    }

    if(root == null) {
	root = "./";
    }

    if(dropfield && dropfield.value) {
	redirlink.href = root+"type/?DEVICE_TYPE_ID=" + dropfield.value;
    } else {
	redirlink.href = "javascript:void(null);";
    }
}


// //////////////////////////////////////////////////////////////////////////
//
// Physical Portage
//
// //////////////////////////////////////////////////////////////////////////
//
// does an ajax request and replaces the select option
// side is a hack.  I need to redo the ports are working everywhere so it
// doesn't care about the side.  It will make any port related stuff
// more clear and eliminate much of the hacking.  No time now, though.  *sigh*
//
function showPhysical_ports(devidfld, devnamfld, physportid, portboxname, type, side) {
	var url, devlink;

	if(portboxname == null) {
		return;
	}

	//
	// catches the empty field.
	//
	if(!devnamfld || devnamfld.value.length == 0) {
		devidfld.value = null;
		devidfld = null;
	}

	//
	// reset the link for the device to match the new other end
	//
	devlink = document.getElementById(type+"_devlink_" + physportid);
	if(devlink) {
		if(devidfld && devidfld.value) {
			devlink.href = "device.pl?devid=" + devidfld.value +";__default_tab__=Switchport";
			devlink.onclick = '';
		} else {
			//devlink.href = "javascript:void(null);";
			devlink.href = "#";
			devlink.onclick = function() { alert( "Can't open Other End device page as it's not set." ); return( false ); };
		}
	}

	request = createRequest();
	url = 'device-ajax.pl?what=Ports';
	if(type != null && type.length > 0) {
		url += ";type=" + type;
	}
	if( side !== 'undefined' ) {
		url += ";side=" + side;
	}
	if( devidfld != null ) {
		url += ";DEVICE_ID=" + devidfld.value;
	}
	url += ";PHYSICAL_PORT_ID=" + physportid;

	// Replace the Port dropdown by an ajax loaded while it's being updated
	let obj = document.getElementById( portboxname );
	let elementSpan = document.createElement( 'span' );
	elementSpan.innerHTML = '<div class="spinner align-middle"></div> Updating...';
	elementSpan.style.display = 'inline-flex';
	obj.parentElement.appendChild( elementSpan );
	obj.style.display= 'none';

	// Update the Port field
	request.open("GET", url, true);
	request.onreadystatechange = function () {
		if(request.readyState == 4) {
			var htmlgoo = request.responseText;
			var n = portboxname;
			obj.innerHTML = htmlgoo;
			obj.style.display = '';
			obj.parentElement.removeChild( elementSpan );
			portboxname = null;
		}
	}
	request.send(null);

	//
	// when these are changed, the patch panel link should go away,
	// as well as the traces of the popup window that holds any values
	// that need to be updated.  This will cause the physical connection
	// path to go away when the submission happens.
	//
	cleanup_patchpanel_links(physportid);
}

function showPhysPortKid_Groups(devid, id, trid, portname) {
	// XXX - NEED TO SHARE WITH NON-SUBINTERFACE GROUPED
	// SHOULD ALSO SHARE CODE WITH NETWORK_INTERFACE HIERARCIES
	var kid_trid, kid_tr;
	var ajaxrequest;
	var ptr, rowindex;
	var tr, td, tbl;
	var url;

	kid_trid = "kid_tr"+portname;
	kid_tr = document.getElementById(kid_trid);

	if(kid_tr) {
		// totally need to toggle tr visibility and maybe change the  pic
		if(kid_tr.style.visibility == 'hidden') {
			kid_tr.style.display = '';
			kid_tr.style.visibility = 'visible';
			swaparrows("kidXpand_" + id, 'down');
		} else {
			kid_tr.style.visibility = 'hidden';
			kid_tr.style.display = 'none';
			swaparrows("kidXpand_" + id, 'up');
		}
		return;
	}

	// find the table, to generate a new row.

	ptr = document.getElementById(trid);
	if(ptr == null) {
		return;
	}

	for(tbl = ptr; tbl.parentNode != null ; tbl = tbl.parentNode) {
		if(tbl.tagName == 'TABLE') {
			break;
		}
	}

	if(tbl == null) {
		return;
	}
	tr = tbl.insertRow(ptr.rowIndex + 1);
	tr.id = kid_trid;
	tr.style.display = 'none';

	td = document.createElement("td");
	tr.appendChild(td);

	td = document.createElement("td");
	td.inner_html = " I am a total td";
	td.colSpan = 5;
	tr.appendChild(td);

	url = "device-ajax.pl?what=SwitchportKids;parent=" + portname;
	url += ";DEVICE_ID=" + devid;
	swaparrows("kidXpand_" + id, 'dance');
	ajaxrequest = createRequest();
	ajaxrequest.open("GET", url, true);
	ajaxrequest.onreadystatechange = function () {
		if(ajaxrequest.readyState == 4) {
			var htmlgoo = ajaxrequest.responseText;
			swaparrows("kidXpand_" + id, 'down');

			td.innerHTML = htmlgoo;
			tr.style.display = '';
		}
	}
	ajaxrequest.send(null);
}

function showPhysPortKid_Groups(devid, id, trid, portname) {
	// XXX - NEED TO SHARE WITH NON-SUBINTERFACE GROUPED
	// SHOULD ALSO SHARE CODE WITH NETWORK_INTERFACE HIERARCIES
	var kid_trid, kid_tr;
	var ajaxrequest;
	var ptr, rowindex;
	var tr, td, tbl;
	var url;

	kid_trid = "kid_tr"+portname;
	kid_tr = document.getElementById(kid_trid);

	if(kid_tr) {
		// totally need to toggle tr visibility and maybe change the  pic
		if(kid_tr.style.visibility == 'hidden') {
			kid_tr.style.display = '';
			kid_tr.style.visibility = 'visible';
			swaparrows("kidXpand_" + id, 'down');
		} else {
			kid_tr.style.visibility = 'hidden';
			kid_tr.style.display = 'none';
			swaparrows("kidXpand_" + id, 'up');
		}
		return;
	}

	// find the table, to generate a new row.

	ptr = document.getElementById(trid);
	if(ptr == null) {
		return;
	}

	for(tbl = ptr; tbl.parentNode != null ; tbl = tbl.parentNode) {
		if(tbl.tagName == 'TABLE') {
			break;
		}
	}

	if(tbl == null) {
		return;
	}
	tr = tbl.insertRow(ptr.rowIndex + 1);
	tr.id = kid_trid;
	tr.style.display = 'none';

	td = document.createElement("td");
	tr.appendChild(td);

	td = document.createElement("td");
	td.inner_html = " I am a total td";
	td.colSpan = 5;
	tr.appendChild(td);

	url = "device-ajax.pl?what=SwitchportKids;parent=" + portname;
	url += ";DEVICE_ID=" + devid;
	swaparrows("kidXpand_" + id, 'dance');
	ajaxrequest = createRequest();
	ajaxrequest.open("GET", url, true);
	ajaxrequest.onreadystatechange = function () {
		if(ajaxrequest.readyState == 4) {
			var htmlgoo = ajaxrequest.responseText;
			swaparrows("kidXpand_" + id, 'down');

			td.innerHTML = htmlgoo;
			tr.style.display = '';
		}
	}
	ajaxrequest.send(null);
}

function cleanup_patchpanel_links(pportid) {
	var pcthing;

	if(!pportid) {
		return;
	}

	pcthing = document.getElementById('pplink_a_'+pportid);
	if(pcthing) {
		pcthing.parentNode.removeChild(pcthing);
	}

	pcthing = document.getElementById('PC_popup_'+pportid);
	if(pcthing) {
		pcthing.parentNode.removeChild(pcthing);
	}
}

/////////////////////////////////////////////////////////////////////////////
//
// POWER
//
/////////////////////////////////////////////////////////////////////////////

var power_portboxname;
function showPowerPorts(devdropid, devnameid, portboxid,piport,devlinkid) {
	var devlink = document.getElementById(devlinkid);
	var devdrop = document.getElementById(devdropid);
	var devname = document.getElementById(devnameid);

	if(devlink != null) {
		if(devdrop.value && devlink) {
			devlink.href = "./device.pl?devid="+devdrop.value+";__default_tab__=Power";
		} else {
			devlink.href = "javascript:void(null);";
		}
	}

	//
	// catches the empty field.
	//
	if(!devname || devname.value.length == 0) {
		devdrop.value = null;
		devdrop = null;
	}

	power_portboxname = portboxid;
	request = createRequest();
	url = 'device-ajax.pl?what=PowerPorts';
	if(devdrop != null && devdrop.value != null ) {
		url += ";DEVICE_ID=" + devdrop.value;
	}
	url += ";POWER_INTERFACE_PORT="+piport;
	request.open("GET", url, true);
	request.onreadystatechange = updatePowerPort;
	request.send(null);
}

function updatePowerPort() {
	if(request.readyState == 4) {
		var htmlgoo = request.responseText;
		var obj = document.getElementById(power_portboxname);
		obj.innerHTML = htmlgoo;
		power_portboxname = null;
	}
}

////////////////////////////////////////////////////////////////////////////
//
// Device Sanity checking
//
////////////////////////////////////////////////////////////////////////////
function verify_device_submission(form) {
	var msgtally, msg, result, name, verifybox, ser_reset, retire;
	var nogotally, nogo;

	// if this is set, something didn't want the user to be able to
	// submit the form via enter (may cause a user to need to do something
	// twice to submit if not all browsers work the same...
	if(form.dontSubmit == true) {
		form.dontSubmit = false;
		return false;
	}

	// Add IP/Netowrk tab toggle switches to form
	// Needed because buttons that aren't clicked aren't submitted
	for( const oToggle of document.querySelectorAll( '.button_switch' ) ) {
		var oHidden = document.createElement( 'input' );
		oHidden.type = 'hidden';
		oHidden.name = oToggle.name;
		oHidden.value = oToggle.getAttribute( 'state' );
		form.appendChild( oHidden );
	}

	verifybox = document.getElementById("verifybox");
	verifybox.innerHTML = null;

	msgtally = 0;
	msg = new Array();

	nogotally = 0;
	nogo = new Array();

	if(form.elements) {
		nampat = "rm_([a-zA-Z]+)_INTERFACE_(\\d+)";
		for(var i = 0; i < form.elements.length; i ++) {
			if (form.elements[i].type == 'checkbox') {
				if( (result = form.elements[i].name.match(nampat)) != null &&
						form.elements[i].checked == true) {
					var tmpthing;
					name = "INTERFACE_NAME_"+result[2];
					name = document.getElementById(name);
					if(name) {
						tmpthing = document.createElement("br");
						if(result[1] == "free") {
							tmpthing = "Remove and Free IPs for interface " + name.value + "?";
						} else {
							tmpthing = "Remove and Reserve IPs for interface " + name.value + "?";
						}
					} else {
						tmpthing = "Remove and Reserve IP for interface?";
					}
					msg[msgtally] = tmpthing;
					msgtally++;
				}
			}
		}
	}

	ser_reset = document.getElementById("chk_dev_port_reset");
	if(ser_reset != null && ser_reset.checked == true) {
		msg[msgtally++] = "You have selected to resync all serial ports on this device.  This will remove all existing serial connections.  Only click YES if you know what you're doing.";
	}

	retire = document.getElementById("chk_dev_retire");
	if(retire != null && retire.checked == true) {
		if(ser_reset != null && ser_reset.checked == true) {
			nogo[nogotally++] = "You may not both retire a box and rest serial ports to default.";
		} else {
			msg[msgtally++] = "You have selected to RETIRE the box.  Only click yes if you want to remove the device characteristics from the database";
		}
	}


	if(nogotally >0 || msgtally >0) {
		var but, span, w, ul, li;

		verifybox.style.visibility = 'visible';

		ul = document.createElement("ul");

		if(nogotally >0) {
			for(var i = 0; i < nogo.length; i++) {
				li = document.createElement("li");
				li.textContent = nogo[i];
				ul.appendChild(li);
			}
			verifybox.appendChild(ul);
		} else if(msgtally >0) {
			for(var i = 0; i < msg.length; i++) {
				li = document.createElement("li");
				li.textContent = msg[i];
				ul.appendChild(li);
			}
			verifybox.appendChild(ul);
		}

		span = document.createElement("P");

		if(nogotally >0) {
			but = document.createElement("input");
			but.type = 'button';
			but.value = 'Close';
			but.onclick = function() { verifybox.innerHTML = ""; verifybox.style.visibility = 'hidden' };
			span.appendChild(but);
		} else if(msgtally >0) {
			var txt;

			txt = document.createElement("text");
			txt.text = "Do you want to continue?"
			span.appendChild(txt);

			but = document.createElement("input");
			but.type = 'button';
			but.value = 'Yes';
			but.onclick = function() { form.submit(); };
			span.appendChild(but);

			but = document.createElement("input");
			but.type = 'button';
			but.value = 'No';
			but.onclick = function() { verifybox.innerHTML = ""; verifybox.style.visibility = 'hidden' };
			span.appendChild(but);
		}

		verifybox.appendChild(span);
		this.scrollTo(0,0);
		return false;
	}
	return true;
}

// jquery version - needs to merge in
function toggleon_text(but) {
	// var p = $(but).prev(":input").removeAttr('disabled');
	// var d = $(but).previousSibling;
	// $(but).filter(":parent").filter("input:disabled").removeAttr('disabled');

	$(but).closest("td").find(".off").removeClass('off');
	$(but).addClass('irrelevant');

}

////////////////////////////////////////////////////////////////////////////
//
// patch panels
//
////////////////////////////////////////////////////////////////////////////
function close_patchpanel(killid) {
	var node = document.getElementById(killid);
	if(node) {
		// makes debugging easier.
		// node.parentNode.removeChild(node);
		if(node.style.visibility == 'visible') {
			node.style.visibility = 'hidden';
		} else {
			node.style.visibility = 'visible';
		}
	}
}

function PatchPanelDrop(devid, ppkeyid, devtxtid) {
	var popup, tbl, tblid, url, devtxt, popupid, innerdiv;
	var close, titletab, tr, td, form;
	var dyn;
	var patchpanel_request;

	devtxt = document.getElementById(devtxtid);

	// note this is used elsewhere in this javascript.
	popupid = "PC_popup_"+ppkeyid;
	popup = document.getElementById(popupid);

	if(popup == null) {
		popup = document.createElement("div");
		popup.id = popupid;

		titletab = document.createElement("table");
		popup.appendChild(titletab);

		titletab.innerHTML;
		titletab.className = 'physPortTitle';

		tr = document.createElement("tr");
		td = document.createElement("td");
		td.textAlign = 'right';

		dyn = document.createElement("div");
		dyn.innerHTML = "Physical Patch Panel Connectivity";
		dyn.style.fontWeight = 'bold';
		dyn.style.textAlign = 'center';
		dyn.style.fontSize = '150%';
		td.appendChild(dyn);

		tr.appendChild(td);

		td = document.createElement("td");
		td.style.width = '10%';
		td.style.textAlign = 'right';
		td.style.marginRight = '0px';
		td.style.marginLeft = 'auto';

		close = document.createElement("a");
		close.innerHTML = "CLOSE";
		close.style.fontSize = '150%';
		close.style.textAlign = 'right';
		close.style.marginRight = '0px';
		close.style.marginLeft = 'auto';
		close.style.border = '2px solid';
		close.href = "javascript:close_patchpanel(\""+popupid+"\")";
		td.appendChild(close);

		tr.appendChild(td);
		titletab.appendChild(tr);

		tblid = popupid + "_table";
		tbl = document.createElement("div");
		tbl.id = tblid;
		popup.appendChild(tbl);

		innerdiv = document.createElement("div");
		popup.appendChild(innerdiv);

		popup.style.position = 'absolute';
		popup.style.visibility = 'hidden';
		popup.className = "physPortPopup";

		var x = findPosX(devtxt);
		var y = findPosY(devtxt);
		y += devtxt.offsetHeight;
		popup.style.left = x + "px";
		popup.style.top = y + "px";

		url = "device-ajax.pl?what=PhysicalConnection;" + "PHYSICAL_PORT_ID="+ppkeyid;
		url += ";DEVICE_ID="+devid;

		patchpanel_request = createRequest();
		patchpanel_request.open("GET", url, true);
		patchpanel_request.onreadystatechange = function () {
			if(patchpanel_request.readyState == 4) {
				var htmlgoo = patchpanel_request.responseText;
				innerdiv.innerHTML = htmlgoo;
				popup.style.visibility = 'visible';
			}
		};
		patchpanel_request.send(null);

		patch_popup = popup;
		table_go = innerdiv;
		form = document.getElementById('deviceForm');
		form.appendChild(popup);
	} else {
		// makes debugging easier.
		// popup.parentNode.removeChild(popup);
		if(popup.style.visibility == 'visible') {
			popup.style.visibility = 'hidden';
		} else {
			popup.style.visibility = 'visible';
		}
	}
}

function AppendPatchPanelRow(myid, ppkeyid, tblid, side) {
	var newrow;
	var tbl, after, mything;
	var url;
	var ajaxrequest;
	var newindex;

	//
	// the row to go after needs to be deduced dynamically.
	//
	mything = document.getElementById(myid);
	if(!mything) {
		return;
	}
	after = mything;
	while(after = after.parentNode) {
		if(after.tagName == 'TR') {
			break;
		}
	}
	if(!after) {
		// should be buried inside a row.  This is, umm, bad.
		return;
	}
	tbl = document.getElementById(tblid);
	if(!tbl) {
		return;
	}

	newindex = after.rowIndex + 1;
	newrow = tbl.insertRow(newindex);

	url = "device-ajax.pl?xml=yes;what=PhysicalConnection;" + "PHYSICAL_PORT_ID="+ppkeyid;
	url += ";row=" + newindex;
	url += ";side="+side;
	ajaxrequest = createRequest();
	ajaxrequest.open("GET", url, true);
	ajaxrequest.onreadystatechange = function () {
		if(ajaxrequest.readyState == 4) {
			// I tried to do the entire response in xml, but that ended up
			// being a complete mess because each element needed to be
			// recreated, so I'm doing this hybrid.  It may be possible to
			// write a dtd that does things smarter.  That's like, work and
			// stuff.

			//
			// first redo all the exsting ids.
			//
			for(var i = tbl.rows.length - 1; i > newindex; i--) {
				var refid, refelem, nidx;
				var r = tbl.rows[i];
				var oldid = tbl.rows[i].id;
				var newid = oldid;

				refid = oldid.replace(/^tr_/, '');
				refelem = document.getElementById(refid);
				// XXX - need to check if we can't find the element
				// in which case, back everything out and throw an error.

				//
				// increment the row number in the ids so they get fetched
				// in the right order.
				//
				nidx = parseInt(oldid.replace(/^.*_row(\d+)\s*$/, '$1'));
				nidx += 1;
				newid = oldid.replace(/_row(\d+)\s*$/, '_row'+nidx);
				r.id = newid;

				newid = refid.replace(/_row(\d+)\s*$/, '_row'+nidx);
				refelem.id = newid;
				var refname = refelem.getAttribute('name');
				refelem.setAttribute('name', newid);
			}

			//
			// now deal with setting up the new row.  This needs to happen
			// second because the new row's name would have existed if done
			// before.
			//
			var resp = ajaxrequest.responseXML;
			var id = resp.getElementsByTagName('trid')[0];
			var htmlgoo = resp.getElementsByTagName('contents')[0];
			newrow.id = id.textContent;
			var y = htmlgoo.textContent;
			newrow.innerHTML = y;
		};
	};
	ajaxrequest.send(null);
}

/////////////////////////////////////////////////////////////////////////////
//
// Circuit
//
/////////////////////////////////////////////////////////////////////////////
function showCircuitKids(link, circid, parent_tr_id, interface_id)
{
	var kid_trid, kid_tr;
	var ajaxrequest;
	var ptr, rowindex;
	var tr, td, tbl;
	var url;

	kid_trid = "kid_tr"+interface_id;
	kid_tr = document.getElementById(kid_trid);

	if(kid_tr) {
		// totally need to toggle tr visibility and maybe change the  pic
		if(kid_tr.style.visibility == 'hidden') {
			kid_tr.style.display = '';
			kid_tr.style.visibility = 'visible';
			swaparrows("cirExpand_" + circid, 'down');
		} else {
			kid_tr.style.visibility = 'hidden';
			kid_tr.style.display = 'none';
			swaparrows("cirExpand_" + circid, 'up');
		}
		return;
	}

	// find the table, to generate a new row.

	ptr = document.getElementById(parent_tr_id);
	if(ptr == null) {
		return;
	}

	for(tbl = ptr; tbl.parentNode != null ; tbl = tbl.parentNode) {
		if(tbl.tagName == 'TABLE') {
			break;
		}
	}

	if(tbl == null) {
		return;
	}
	tr = tbl.insertRow(ptr.rowIndex + 1);
	tr.id = kid_trid;
	tr.style.display = 'none';

	td = document.createElement("td");
	tr.appendChild(td);

	td = document.createElement("td");
	td.innerHTML = " I am a total td";
	td.colSpan = 5;
	tr.appendChild(td);

	url = "device-ajax.pl?what=Circuit;parent=" + interface_id;
	swaparrows("cirExpand_" + circid, 'dance');
	ajaxrequest = createRequest();
	ajaxrequest.open("GET", url, true);
	ajaxrequest.onreadystatechange = function () {
		if(ajaxrequest.readyState == 4) {
			var htmlgoo = ajaxrequest.responseText;
			swaparrows("cirExpand_" + circid, 'down');

			td.innerHTML = htmlgoo;
			tr.style.display = '';
		}
	}
	ajaxrequest.send(null);
}

/////////////////////////////////////////////////////////////////////////////
//
// License
//
/////////////////////////////////////////////////////////////////////////////
function add_License(thing, parent_tr_id, devid)
{
	var tbl, newtd, newtr, ptr, url, dropname;
	var ajaxrequest;

	for(tbl = thing; tbl.parentNode != null; 	tbl = tbl.parentNode) {
		if(tbl.tagName == 'TABLE') {
			break;
		}
	}

	ptr = document.getElementById(parent_tr_id);
	if(ptr == null) {
		return;
	}

	if(tbl) {
		var trid, rmclick;
		for(var i = 0; ; i++) {
			var idname = "";
			idname = "add_license_" + devid + "_" + i;
			trid = "addlictr_" + devid + "_" + i;
			dropname = document.getElementById(idname);
			if(dropname == null) {
				break;
			}
		}

		// insert before the "add a license" button"
		newtr = tbl.insertRow(ptr.rowIndex);
		newtr.style.display = 'none';
		newtr.id = trid;
		newtr.style.visibility = 'hidden';


		newtd = document.createElement("td");
		rmclick = document.createElement("a");
		rmclick.innerHTML = "REMOVE";
		rmclick.onclick = function() { newtr.parentNode.removeChild(newtr); };
		newtd.appendChild(rmclick);
		newtr.appendChild(newtd);

		newtd = document.createElement("td");
		// note that newtd is used later!
		newtr.appendChild(newtd);

		url = "device-ajax.pl?what=LicenseDrop;dropid=" + idname;
		ajaxrequest = createRequest();
		ajaxrequest.open("GET", url, true);
		ajaxrequest.onreadystatechange = function () {
			if(ajaxrequest.readyState == 4) {
				var htmlgoo = ajaxrequest.responseText;
				// swaparrows("cirExpand_" + circid, 'down');
				newtd.innerHTML = htmlgoo;
				newtr.style.display = '';
				newtr.style.visibility = 'visible';
			}
		}
	    ajaxrequest.send(null);

	}
}


//
// replaces the name.domain link with a textbox and drop down for dns
// suitable for changing.  Name and domain will match the link so submits
// will not change anything; this is just to not make devices with many
// interfaces not have giant pages.
//
function replace_int_dns_drop (obj, resp)
{
	$(obj).empty();
	var name = $("<input />", resp['DNS_NAME']);
	var s = $("<select />", resp['DNS_DOMAIN']);

	for(var field in resp['domains']['options']) {
		var o = $("<option/>",resp['domains']['options'][field]);
		$(s).append(o);
	}
	$(obj).append(name);
	$(obj).append(s);
	$(name).focus();
}

/* Function to show / hide elements when a control element is clicked
   The control and content element ids must match these formats:
    - control element: xxx_control_nnn
    - content element: xxx_content_nnn
   Where xxx is the group identifier and nnn the control/content pair identifier.
   There can be multiple pairs in a group.
*/
function showhide( element ) {
	// Find the associated (hidden) element with matchging id
	var strContentName = element.id.replace( 'control', 'content' );
	//targetContentElement = $( '#' + strContentName );
	var targetContentElements = document.getElementsByName( strContentName );
	// Exit if the related content can't be found
	if( targetContentElements.length == 0 ) return;

	// Build the group id for control and content elements
	var strGroupControlId = element.id.replace( /_[^_]*$/, '' );
	var strGroupContentName = strContentName.replace( /_[^_]*$/, '' );

	// Find all control elements belonging to the group, except the targeted one
	var eOtherControlsInGroup = $( '[id^="' + strGroupControlId + '"]' ).not( '[id="' + element.id + '"]' );
	// Find all content elements belonging to the group, except the targeted one
	var eOtherContentsInGroup = $( '[name^="' + strGroupContentName + '"]' ).not( '[name="' + strContentName + '"]' );

	// Loop on target elements
	for( let i = 0; i < targetContentElements.length; i++ ) {

		var targetContentElement = targetContentElements[i];

		// Is the targeted content element hidden?
		if( targetContentElement.classList.contains( 'irrelevant' ) ) {
			// Update the show/hide icon
			element.classList.add( 'toggled' );
			//element.classList.remove( 'control_collapsed' );
			//element.classList.add( 'control_expanded' );
			// Update the show/hide icon for those other elements
			if( eOtherControlsInGroup ) {
				eOtherControlsInGroup.removeClass( 'toggled' );
				//eOtherControlsInGroup.removeClass( 'control_expanded' );
				//eOtherControlsInGroup.addClass( 'control_collapsed' );
			}
			// Show it
			targetContentElement.classList.remove('irrelevant');
			// And hide all content elements of the group, except the targeted one
			if( eOtherContentsInGroup ) { eOtherContentsInGroup.addClass( 'irrelevant' ); }
		// The targetet element is visible
		} else {
			// Update the show/hide icon
			element.classList.remove( 'toggled' );
			//element.classList.remove( 'control_expanded' );
			//element.classList.add( 'control_collapsed' );
			// Hide it
			targetContentElement.classList.add( 'irrelevant' );
		}
	}
}



// This function is used to update the device IP Network tab when toggle buttons are clicked
// It's also called by parent toggles to propagate their state to their child toggles (if applicable)
// Finally, it's called when the web page is loaded to set the previous states (with propagate set to false in this case)
function updateNetworkInterfaceUI( element, stateOverride = '', propagate = true ) {
	// Define the various possible states
	const states = {
		'level_network_interface' : {
			'update': 'delete',
			'delete': 'update',
		},
		'level_netblock' : {
			'update': 'unlink',
			'unlink': 'delete',
			'delete': 'update',
		},
  		'level_dns_record' : {
			'update': 'lock',
			'lock':   'delete',
			'delete': 'update',
		}
	};

	// Get the parent level
	const strParentLevelClass = [ ...element.classList].filter( strClass => strClass.match( /^parent_level_/) )[0];
	// Get the level
	const strLevelClass = [ ...element.classList].filter( strClass => strClass.match( /^level_/) )[0];
    // Get the network interface, netblock and dns record classes - if defined -  as an array
    const aIdClasses = [ ...element.classList].filter( strClass => strClass.match( /^id_/) );
	// Get the parent toggle state
	var aParentElements;
	var strParentState;
	// Do we have a parent toggle?
	if( strParentLevelClass !== 'parent_level_none' ) {
		// The parent id classes are the same, except for the current id class
		const strExcludeClass = '^id_' + strLevelClass.replace( /^level_/, '' );
		aParentIdClasses = aIdClasses.filter( strClass => ! strClass.match( strExcludeClass ) );
		var oParentToggle = document.getElementsByClassName( aParentIdClasses.concat( [ strParentLevelClass.replace( /^parent_/, '' ) ] ).concat( 'button_switch' ).join(' ') )[0];
		aParentElements = document.getElementsByClassName( aParentIdClasses.concat( [ strParentLevelClass.replace( /^parent_/, '' ) ] ).concat( 'tracked' ).join(' ') );
		strParentState = oParentToggle.getAttribute( 'state' );
	}
	// Get the current state of the toggle button
	const strCurrentState = element.getAttribute( 'state' );
	// Get the new state, either from the override or from the states json object
	var newState;
	// Do we have a state override and not a simple toggle click?
	if( stateOverride ) {
		for( const state of Object.keys( states[strLevelClass] ) ) {
			if( states[strLevelClass][state] == stateOverride ) {
				newState = states[strLevelClass][state];
				break;
			}
		}
	} else {
		newState = states[strLevelClass][strCurrentState];
	}

	// Let's check if the new state is compatible with the parent state
	var bOk = false;
	while( ! bOk ) {
		bOk = true;
		// Check for invalid states
		if(      strParentState === 'delete' && newState === 'update' ) bOk = false;
		else if( strParentState === 'delete' && newState === 'lock'   ) bOk = false;
		else if( strParentState === 'unlink' && newState === 'lock'   ) bOk = false;
		// A lock state is not allowed without at least one parent element updated
		if( newState === 'lock' ) {
			var bParentElementChanged = false;
		  	for( const oParentElement of aParentElements ) {
				if( oParentElement.classList.contains( 'changed' ) ) {
					bParentElementChanged = true;
					break;
				}
			}
			if( ! bParentElementChanged ) {
				bOk = false;
			}
		}
		// Did we find an invalid state? If yes, try the next possible state
		if( ! bOk ) newState = states[strLevelClass][newState];
	}

	// Get same level and child level elements
	const aLevelElements = document.getElementsByClassName( aIdClasses.concat( [strLevelClass] ).join(' ') );
	const aChildToggles = document.getElementsByClassName( aIdClasses.concat( [ 'parent_' + strLevelClass ] ).concat( 'button_switch' ).join(' ') );

	// Change the button value (displayed text) to the new state except for 'new' toggles
	if( element.value !== 'new' ) element.value = newState;
	// And change it's state (custom) attribute to the new value as well
	element.setAttribute( 'state', newState );

	// Loop on elements on the same level as the current toggle button being processed
	for( const oLevelElement of aLevelElements ) {
		// Update their class
		oLevelElement.classList.remove( 'marked_for_' + strCurrentState );
		oLevelElement.classList.add( 'marked_for_' + newState );
		// Is that the button that was clicked?
		if( oLevelElement.classList.contains( 'button_switch' ) ) {
			// Actually... nothing to do
		// That's an input/select field of some sort
		} else {
			// If the requested state is 'delete', the related input fields must be disabled
			if( newState === 'delete' ) {
				oLevelElement.setAttribute( 'disabled', 'disabled' );
			} else {
				oLevelElement.removeAttribute( 'disabled' );
			}
		}
	}

	// If we don't have to propagate the change to the child element, stop here
	// This is required to correctly set the states when the browser loads the page
	if( ! propagate ) return;

	// Loop on child toggles to notify the change
	for( const oChildElement of aChildToggles ) {
		// Get the toggle level class
		var strChildState = oChildElement.getAttribute( 'state' );
		// State is propagated to child toggles, unless the state is unlink
		// If the state we wan't to pass is unlink and the child is not (lock or delete) state, we enforce update instead
		if( newState === 'unlink' ) {
			updateNetworkInterfaceUI( oChildElement, 'update' );
		// In all other cases, we just pass the new state
		} else {
			updateNetworkInterfaceUI( oChildElement, newState );
		}
	}
}



// jQuery magic!
$(document).ready(function(){
	// this causes the EDIT button to show up where needed
	$("body").on('click', ".stabeditbutton", function(event) {
		toggleon_text(event.target);
	});


	// When the more button is clicked on, find the table underneath
	// and toggle if its shown or not
	$("div.maindiv").on('click', 'a.showmore', function(event) {
		var t = $(this).closest("td").find("table.intmoretable");
		if(t) {
			if ($(t).hasClass('irrelevant') ){
				$(t).removeClass('irrelevant');
			} else {
				$(t).addClass('irrelevant');
			}
		} else {
			alert('Can not find "More" table');
		}
	});

	// When a component id checkbox is set to something meanintful,
	// toggle the component related fields if they matter.
	$("div.maindiv").on('change', 'select.componenttype', function(event) {
		var x = $(this).find('option:selected').val();
		if(x == '__unknown__') {
			$(this).closest('table').find('.componentfields').addClass('off');
		} else {
			$(this).closest('table').find('.componentfields').removeClass('off');
		}
	});

	// Get dns domains from the database and populate a json object
	get_dns_domains();

	create_dns_reference_jquery("div.maindiv");

});
