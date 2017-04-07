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

	ShowDevTab(gotoTab.value, devid);
}

function ShowDevTab(what,devid) {
	var url;
	var i, o, onext, otabs, goawayTab;
	var holdingDiv, holdingDiv_Name, deviceForm;
	var forcedloadElem;

	var ajaxrequest = createRequest();

	var gotoTab = document.getElementById(what);
	//
	// reset tabbage
	//
	otabs = document.getElementsByTagName("a");
	for(i = 0; i < otabs.length; i++) {
		if (otabs[i].className == 'tabgroupactive') {
			otabs[i].className = 'tabgrouptab';
			goawayTab = otabs[i];
		}
	}

	if(goawayTab && gotoTab ) {
		if(goawayTab.id == gotoTab.id) {
			if(goawayTab.className == gotoTab.className) {
				return;
			}
		}
	}

	var divObj = document.getElementById("tabthis");

	deviceForm = document.getElementById('deviceForm');
	if(deviceForm == null) {
		alert("Can't find form on the document");
		return;
	}

	if(goawayTab) {
		holdingDiv_Name = "STAB__TabHold_"+goawayTab.id;
		holdingDiv = document.getElementById(holdingDiv_Name);

		if(holdingDiv == null) {
			holdingDiv = document.createElement("div");
			holdingDiv.id = holdingDiv_Name;
			holdingDiv.style.visibility = 'hidden';
			deviceForm.appendChild(holdingDiv);
		}

		for(o = divObj.firstChild; o; o = onext) {
			onext = o.nextSibling;
			divObj.removeChild(o);
			holdingDiv.appendChild(o);
		}
	}

	holdingDiv_Name = "STAB__TabHold_"+what;
	holdingDiv = document.getElementById(holdingDiv_Name);

	if(holdingDiv != null) {
		for(o = holdingDiv.firstChild; o; o = onext) {
			onext = o.nextSibling;
			holdingDiv.removeChild(o);
			divObj.appendChild(o);
		}
	} else {
		var qstr;
		url = 'device-ajax.pl?what='+ what;

		qstr = document.location + "";
		qstr = encodeURIComponent(qstr);
		if(qstr) {
			re = /^.*\?/;
			qstr.replace(re,  '');
			qstr.replace(/devid=\d+./, '');
			qstr.replace(/__notemsg__=[^&;]+/, '');
			qstr.replace(/__errormsg__=[^&;]+/, '');
		}
		url += ";passedin=" + qstr;

		divObj.style.textAlign = 'center';
		divObj.style.padding = '50px';
		divObj.innerHTML = "<img src=\"../stabcons/progress.gif\"> <em>Loading, Please Wait...</em>"

		url += ";DEVICE_ID=" + devid;
		ajaxrequest.open("GET", url, true);
		ajaxrequest.onreadystatechange = function() {
			if(ajaxrequest.readyState == 4) {
				var htmlgoo = ajaxrequest.responseText;
				var obj = document.getElementById("tabthis");
				//dynamiccontentNS6("tabthis", htmlgoo);
				obj.style.textAlign = '';
				obj.style.padding = '';
				obj.innerHTML = htmlgoo;
			}
		}
		ajaxrequest.send(null);
	}

	forcedloadElem = document.getElementById('__default_tab__');
	if(forcedloadElem) {
		forcedloadElem.value = what;
	}

	if(gotoTab) {
		gotoTab.className = 'tabgroupactive';
	}

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
	var url, devlink, tabtype;

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
			devlink.href = "device.pl?devid=" + devidfld.value +";__default_tab__=" + tabtype;
		} else {
			devlink.href = "javascript:void(null);";
		}
	}

	request = createRequest();
	url = 'device-ajax.pl?what=Ports';
	if(type != null && type.length > 0) {
		url += ";type=" + type;
	}
	if(side != null) {
		url += ";side=" + side;
	}
	if(devidfld != null) {
		url += ";DEVICE_ID=" + devidfld.value;
	}
	url += ";PHYSICAL_PORT_ID=" + physportid;
	request.open("GET", url, true);
	request.onreadystatechange = function () {
		if(request.readyState == 4) {
			var htmlgoo = request.responseText;
			var obj = document.getElementById(portboxname);
			var n = portboxname;
			obj.innerHTML = htmlgoo;
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
// OS / VOE Mappings
//
/////////////////////////////////////////////////////////////////////////////
// when devid is null its' for an add device.
function update_voe_options(devid, divid)
{
	var os, voetrax, mydiv;
	var newosval, oldoption, i, to;
	var url;

	var pdevid;
	if(devid == null) {
		pdevid = "";
	} else {
		pdevid = "_" + devid;
	}

	mydiv = document.getElementById(divid);
	os = document.getElementById('OPERATING_SYSTEM_ID' + pdevid);
	voetrax = document.getElementById('VOE_SYMBOLIC_TRACK_ID' + pdevid);

	// figure out what the new OS is for passing to ajax bacony goodness.
	for(i = 0; i < os.options.length; i++) {
		to = os.options[i];
		if(to.selected == true) {
			newosval = to.value;
			break;
		}
	}

	// figure out what the new OS is for picking a new default
	for(i = 0; i < voetrax.options.length; i++) {
		to = voetrax.options[i];
		if(to.selected == true) {
			if(to.value != '__unknown__') {
				oldoption = to.text;
			}
			break;
		}
	}

	// disable drop downs while the ajax magic is working.
	os.disabled = true;
	voetrax.disabled = true;

	// go and actually get the new drop down
	url = "device-ajax.pl?what=VOESymTrax";
	if(devid != null) {
		url += ";DEVICE_ID=" + devid;
	}
	url += ";OPERATING_SYSTEM_ID=" + newosval;
	ajaxrequest = createRequest();
	ajaxrequest.open("GET", url, true);
	ajaxrequest.onreadystatechange = function () {
		if(ajaxrequest.readyState == 4) {
			var oldo = oldoption;
			var htmlgoo = ajaxrequest.responseText;
			var v;
			mydiv.innerHTML = htmlgoo;

			v = document.getElementById('VOE_SYMBOLIC_TRACK_ID' + pdevid);
			for(i = 0; i < v.options.length; i++) {
				var x = v.options[i].text;
				if(v.options[i].text == oldo) {
					v.options[i].selected = true;
					break;
				}
			}

			// reenable drop downs
			os.disabled = null;
			voetrax.disabled = null;

		}
	}
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

	create_dns_reference_jquery("div.maindiv");

});
