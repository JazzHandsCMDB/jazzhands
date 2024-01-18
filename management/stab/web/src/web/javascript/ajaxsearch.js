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

function findPosX(obj)
{
	var curleft = 0;
	if (obj.offsetParent)
	{
		while (obj.offsetParent)
		{
			curleft += obj.offsetLeft
			obj = obj.offsetParent;
		}
	}
	else if (obj.x)
		curleft += obj.x;
	return curleft;
}

function findPosY(obj)
{
	var curtop = 0;
	if (obj.offsetParent)
	{
		while (obj.offsetParent)
		{
			curtop += obj.offsetTop
			obj = obj.offsetParent;
		}
	}
	else if (obj.y)
		curtop += obj.y;
	return curtop;
}

//
// this is called when the popup div gets focus.  This is so when focus
// goes from the text box to the dropdown, it continues to stay around.
function keepVisible_Search(obj) {
	if(this.leaveUp = true) {
		this.leaveUp = false;
		this.style.visibility = 'visible';
	}
}

//
// onblur handle for the search div
//
function hideonBlur_Search(action) {

	processSearchBox_Breakdown(this);
}

//
// takes an object of the dropdown div.
//
function processSearchBox_Breakdown(dropdown_div, dropdownsel) {

	if(dropdownsel = null) {
		if(dropdown_div.childNodes != null) {
			for(var i = 0; i < dropdown_div.childNodes.length; i ++) {
				if (dropdown_div.childNodes[i].className == 'select') {
					dropdownsel = dropdown_div.childNodes[i];
				}
			}
		}
	}
	closeAndFillIn_Search(dropdownsel, dropdown_div);
}

function checkSelectKeypress_Search(ddselect, event) {
	var keycode, form;
	if(window.event) { // IE
		keycode = event.keyCode
	} else if(event.keyCode) { // Netscape/Firefox/Opera
		keycode = event.which 
	}
	if(keycode == 13) { // enter
		// this is so enter doesn't cause the form to submit, if that was
		// configured.
		if(ddselect.parentNode.noSubmitForm) {
			form = document.getElementById(ddselect.parentNode.noSubmitForm);
			form.dontSubmit = true;
		}
		closeAndFillIn_Search(ddselect, ddselect.parentNode);
	} else if(keycode == 27) { // escape || tab
		// in this case, revert back to what it was.
		if(ddselect.parentNode.txtid && ddselect.parentNode.txtid.orig_value) {
			ddselect.parentNode.txtid.value = ddselect.parentNode.txtid.orig_value
		}
		ddselect.parentNode.user_abort = true;
		closeAndFillIn_Search(ddselect, ddselect.parentNode);
		return;
	}
}

//
//
// dropdown is the select box, whose parent is the popup div that hides
// relevant values.  popupdiv is the parent div.  
//
// either of dropdown or popupdiv may not be set.  If dropdown is set, the
// div can probably be infered if not set. [XXX]
//
//this takes the value in the text field and:
//
// - resets it to what's selected in the drop down
// - if 1he textfield is typed something that matches something in the
//	dropdown, use that
// - revert back to what was there before.
//
function closeAndFillIn_Search(dropdown, popupdiv) {
	var typedval;
	var reset = false;
	var user_abort = false;
	var savetxt;

	if(popupdiv.user_abort == true) {
		user_abort = true;
	}


	if(popupdiv.txtid != null && user_abort == false) {
		typedval = popupdiv.txtid.value;

		if(dropdown != null && dropdown.childNodes != null) {
			for(var i = 0; i < dropdown.childNodes.length; i ++) {
				var debugme =  dropdown.childNodes[i].value;
				if(dropdown.childNodes[i].selected == true) {
					popupdiv.idsave.value = dropdown.childNodes[i].value;
					popupdiv.txtid.value = dropdown.childNodes[i].text;
					reset = true;
					break;
				} else if(dropdown.childNodes[i].text == typedval) {
					popupdiv.idsave.value = dropdown.childNodes[i].value;
					popupdiv.txtid.value = dropdown.childNodes[i].text;
					reset = true;
					break;
				}
			}
		}

		if(popupdiv.txtid.value.length == 0) {
			popupdiv.idsave.value = null;
		}
	}

	if(popupdiv.txtid) {
		savetxt = popupdiv.txtid;
	}


	if(reset == true) {
		popupdiv.txtid.oldval = null;
		popupdiv.txtid.pending = null;
	} else {
		//
		// otherwise reset it to what it was.
		//
		if(popupdiv.txtid) {
			if(popupdiv.txtid.pending == true) {
				popupdiv.txtid.value = popupdiv.txtid.oldval;
			} else {
				popupdiv.txtid.value = '';
				popupdiv.idsave.value = null;
			}
			popupdiv.txtid.pending = null;
			popupdiv.txtid.oldval = null;
		}
	}

	// make it so this doesn't reappear
	popupdiv.leaveUp = true;
	popupdiv.style.visibility = 'hidden';
	popupdiv.innerHTML = '';
	if(user_abort != true) {
		if(popupdiv.oncompletion ) {
			var tid = popupdiv.txtid;
			if(!tid.orig_value  || tid.orig_value != tid.value) {
				popupdiv.oncompletion();
				tid.orig_value = null;
			}
		}
	}
	popupdiv.parentNode.removeChild(popupdiv);
	if(savetxt) {
		savetxt.focus();
	}
	return reset;
}

function mouseover_Search() {
	this.leaveUp = true;
}

function mouseout_Search() {
	this.leaveUp = false;
}

//
// A function to display a temporary message at the pointer location
//
function blink_message( strMessage, x, y, duration ) {
	let elementMsg = document.createElement( 'div' );
	elementMsg.innerHTML = strMessage;
	elementMsg.style.position = 'absolute';
	elementMsg.style.backgroundColor = 'black';
	elementMsg.style.color = 'white';
	elementMsg.style.border = '1px';
	document.body.appendChild( elementMsg );
	// Position the message just above the mouse cursor
	elementMsg.style.top = ( y - elementMsg.offsetHeight * 2 )  + 'px';
	elementMsg.style.left = ( x - elementMsg.offsetWidth / 2 ) + 'px';
	setTimeout( function() { elementMsg.remove(); }, duration );
}

//
// Show the device search popup for an Other End input field, creating it if necessary
//
//var listener;
function showOtherEndDeviceSearchPopup( elementDeviceName, strElementDeviceId, portId, strElementPortsId, type, side ) {
	if( ! elementDeviceName ) return;

	// Build the popup id and check if it already exists for this Other End field
	const strPopupId = elementDeviceName.id + '_popup';
	let elementPopup = document.getElementById(strPopupId);

	// Hide all similar popups, we don't want more than one open
	Array.from( document.querySelectorAll( '.searchPopup' ) ).forEach(( otherPopup ) => {
		if( otherPopup.id === strPopupId ) return;
		otherPopup.style.visibility = 'hidden';
		// We also want to make it clear that the entry has not been validated
		// Get the input element for this popup
		let oInputElement = document.getElementById( otherPopup.id.replace( '_popup', '' ) );
		// Revert the displayed value to the last selected and validated value, or to the original value if nothing was selected
		if( oInputElement.hasAttribute( 'lastselected' ) ) {
		  oInputElement.value = oInputElement.getAttribute( 'lastselected' );
		} else {
		  oInputElement.value = oInputElement.getAttribute( 'original' );
		}
		updateChangeTrackingStatus( oInputElement );
	});

	// First build ids for the related fields
	//const strPopupSearchId = elementDeviceName.id + '_popup_search';
	const strPopupSelectId = elementDeviceName.id + '_popup_select';
	const strPopupSelectButtonId = elementDeviceName.id + '_popup_button';
	const strPopupDisconnectButtonId = elementDeviceName.id + '_popup_disconnect_button';
	const strPopupAjaxId = elementDeviceName.id + '_popup_ajax';

	// Popup exists already, make it visible and set focus to search field again
	if( elementPopup ) {
		elementPopup.style.visibility = 'visible';
		//document.getElementById( strPopupSearchId ).focus();
		return;
	}

	// Popup doesn't exist yet, let's create it
	elementPopup = document.createElement('div');

	elementPopup.id = strPopupId;
	elementPopup.style.position = 'absolute';
	elementPopup.className = 'searchPopup';

	elementDeviceName.setAttribute('lastsearch', '' );
	elementDeviceName.setAttribute('myselect', strPopupSelectId );
	elementDeviceName.setAttribute('myajax', strPopupAjaxId );
	elementDeviceName.setAttribute('mybutton', strPopupSelectButtonId );
	//elementDeviceName.addEventListener( 'blur', function() { hidePopup( strPopupId ); } );
	elementDeviceName.onkeydown = function( event ) { if( event.keyCode === 27 ) { hidePopup( strPopupId ); } };

	// We could hide the popup when the mouse leaves, but it doesn't feel nice
	//elementPopup.onmouseleave = function() { hidePopup( strPopupId ); }
	// Escape key closes the popup
	elementPopup.onkeydown = function( event ) { if( event.keyCode === 27 ) { hidePopup( strPopupId ); } };

	// Popup title
	//let strPopupHTML = '<div>Other End Device Selection</div>';
	// Search field
	//strPopupHTML += '<div><input id=' + strPopupSearchId + ' type=text value="" original=\'' + elementDeviceName.getAttribute('original') + '\' placeholder="Search for device name..." onInput="delayedGetMatchingDevices( this );" lastsearch="" myselect="' + strPopupSelectId + '" mybutton="' + strPopupSelectButtonId + '" myajax="' + strPopupAjaxId + '"/></div>';

	// Selection list
	strPopupHTML = '<div><select id=' + strPopupSelectId + ' size=10 style="width:100%" onDblclick="updateOtherEnd( document.getElementById(\'' + strPopupSelectButtonId + '\') );" onKeyDown="if( event.keyCode === 13 ) { event.preventDefault(); updateOtherEnd( document.getElementById(\'' + strPopupSelectButtonId + '\') ); }" onChange="document.getElementById(\''+strPopupSelectButtonId+'\').removeAttribute(\'disabled\');">';
	//strPopupHTML += '<option value=\'delete\'>Disconnect ' + elementDeviceName.getAttribute( 'original' ) + '</option>';
	strPopupHTML += '</select></div>';

	// Bottom rows of buttons
	strPopupHTML += '<div align=right>';
	// Ajax spinning wheel
	strPopupHTML += '<span id=' + strPopupAjaxId + ' style=\'float:left\'></span></span>';
	// Cancel button
	strPopupHTML += '<input type=button value="Cancel" onclick="hidePopup(\'' + strPopupId + '\' );"/>';
	// Disconnect button
	//strPopupHTML += '<input type=button value="Disconnect" onclick="hidePopup(\'' + strPopupId + '\' );"/>';
	let strDisconnectDisable = elementDeviceName.value === '' ? 'disabled=disabled' : '';
	strPopupHTML += '<input id=' + strPopupDisconnectButtonId + ' type=button value="Disconnect" onClick="updateOtherEnd( this, true );" ' + strDisconnectDisable + ' mydeviceid="' + strElementDeviceId + '" mypopup="' + strPopupId + '" myselect="' + strPopupSelectId + '" myotherend="' + elementDeviceName.id + '" myportid="' + portId + '" myports="' + strElementPortsId + '" mytype="' + type + '" myside="' + side + '"/>';
	// Select button
	strPopupHTML += '<input id=' + strPopupSelectButtonId + ' type=button value="Select" onClick="updateOtherEnd( this );" disabled=disabled mydeviceid="' + strElementDeviceId + '" mypopup="' + strPopupId + '" myselect="' + strPopupSelectId + '" myotherend="' + elementDeviceName.id + '" myportid="' + portId + '" myports="' + strElementPortsId + '" mytype="' + type + '" myside="' + side + '" mydisconnectbutton="' + strPopupDisconnectButtonId + '"/>';
	strPopupHTML += '</div>';

	elementPopup.innerHTML = strPopupHTML;

	// Position the top left corner of the popup at the bottom left corner of the parent field
	// And sets its width to match the width of the parent Other End field
	const inputRect = elementDeviceName.getBoundingClientRect();
	elementPopup.style.top = inputRect.bottom + window.scrollY;
	elementPopup.style.left = inputRect.left + window.scrollX;
	elementPopup.style.minWidth = inputRect.width - 30;
	elementPopup.style.boxShadow = '2px 2px 3px 2px gray';

	// Show the popup and trigger a first device search from the orgiinal device name
	document.body.appendChild( elementPopup );
	//document.getElementById( strPopupSearchId ).focus();
	elementDeviceName.setAttribute( 'lastsearch', elementDeviceName.value );
	delayedGetMatchingDevices( elementDeviceName );
}

//
// Hide the popup and set focus back to the Other End field
//
function hidePopup( strPopupId ) {
	const elementDeviceName =  document.getElementById( strPopupId.replace( /_popup$/, '' ) );
	const elementPopup = document.getElementById( strPopupId );
	document.getElementById( elementDeviceName.getAttribute( 'myajax' ) ).innerHTML = '';
	//elementDeviceName.value = elementPopup.getAttribute( 'lastselected' );
	if( elementDeviceName.hasAttribute( 'lastselected' ) ) {
		elementDeviceName.value = elementDeviceName.getAttribute( 'lastselected' );
	} else {
		elementDeviceName.value = elementDeviceName.getAttribute( 'original' );
	}
	delayedGetMatchingDevices( elementDeviceName );
	updateChangeTrackingStatus( elementDeviceName );
	elementPopup.style.visibility='hidden';
	elementDeviceName.focus();
}

//
// Schedule a fetch of the matching devices
//
var timeoutGetMatchingDevices;
function delayedGetMatchingDevices( elementSearch ) {
	// If we already have a running timeout, clear it
        if( timeoutGetMatchingDevices ) {
	  //console.log( 'Clearing timeout' );
	  clearTimeout( timeoutGetMatchingDevices );
	}
        // Set a new timeout
	timeoutGetMatchingDevices = setTimeout( function() { getMatchingDevices( elementSearch ); }, 500 );
}

//
// Gets a list of devices matching the Other End search pattern
//
function getMatchingDevices( elementSearch ) {
	//console.log( 'Searching for: ' + elementSearch.value );
	// If the search pattern matches the last one used, ignore the new request
	if( elementSearch.getAttribute( 'lastrequestedsearch' ) === elementSearch.value ) {
		//console.log( 'Search pattern equals last search pattern' );
		return;
	}

	// If the search pattern is empty, just empty the options list
        if( elementSearch.value === '' ) {
		//console.log( 'Empty search value' );
		document.getElementById( elementSearch.getAttribute( 'myselect' ) ).innerHTML = '';
		document.getElementById( elementSearch.getAttribute( 'myajax' ) ).innerHTML = '';
		elementSearch.setAttribute( 'lastsearch', '' );
		return;
	}

	elementSearch.setAttribute( 'lastrequestedsearch', elementSearch.value );
	const url = 'ajax-devsearch.pl?pattern=' + elementSearch.value;
        const requestDevicesSearch = createRequest();
        requestDevicesSearch.open("GET", url, true);
        requestDevicesSearch.onreadystatechange = function() { updateOtherEndDeviceSearchPopup( requestDevicesSearch, elementSearch ); }
        requestDevicesSearch.send(null);
	document.getElementById( elementSearch.getAttribute( 'myajax' ) ).innerHTML = ' <img src=\'../../stabcons/progress.gif\'> Getting devices... ';
}

//
// Update the Other End device search popup based on the received devices list
//
function updateOtherEndDeviceSearchPopup( requestDevicesSearch, elementSearch ) {
	if( requestDevicesSearch.readyState !== 4 ) return;

        // Since concurrent ajax requests are possible, ignore results not matching the current search pattern
	let strSearchPattern = requestDevicesSearch.responseURL.replace(/^.*pattern=/,'');
	if( strSearchPattern !== elementSearch.getAttribute( 'lastrequestedsearch' ) ) {
		//console.log( 'Result for old pattern, ignoring' );
		return;
	}

	// Get the devices array from the ajax request
	const data = JSON.parse( requestDevicesSearch.responseText );
	requestDevicesSearch = '';
	//console.log( data );

	// Empty the options list and disable the Select button
	const elementSelect = document.getElementById( elementSearch.getAttribute('myselect') );
	const elementButton = document.getElementById( elementSearch.getAttribute('mybutton') );
	elementSelect.innerHTML = '';
	elementButton.setAttribute('disabled','disabled');

	// Add a first option to disconnect the current Other End device
	//let elementOption = document.createElement( 'option' );
	//elementOption.text = 'Disconnect ' + elementSearch.getAttribute( 'original' );
	//elementOption.value = 'delete'
	//elementSelect.add( elementOption );

	// Build the new list of options from the array of devices
	for( let i=0; i<data.length; i++) {
		elementOption = document.createElement( 'option' );
		//console.log( data[i][0], data[i][1] );
		elementOption.text = data[i][1];
		elementOption.value = data[i][0];
		elementSelect.add( elementOption );
	}

	// Remember this search pattern
	elementSearch.setAttribute( 'lastsearch', strSearchPattern );

	// Remove the loading message
	document.getElementById( elementSearch.getAttribute( 'myajax' ) ).innerHTML = '';
}

//
// Function triggered by a the Other End popup Select button
//
function updateOtherEnd( buttonSelect, bDisconnect ) {
	const strElementDeviceId = buttonSelect.getAttribute( 'mydeviceid' );
	const elementSelect      = document.getElementById( buttonSelect.getAttribute( 'myselect' ) );
	const elementOtherEnd    = document.getElementById( buttonSelect.getAttribute( 'myotherend' ) );
	const elementPopup       = document.getElementById( buttonSelect.getAttribute( 'mypopup' ) );
	const iPortId            = buttonSelect.getAttribute( 'myportid' );
	const strElementPortsId  = buttonSelect.getAttribute( 'myports' );
	const strType            = buttonSelect.getAttribute( 'mytype' );
	const strSide            = buttonSelect.getAttribute( 'myside' );

	// Update the device id value in the hidden field
	const elementDeviceId = document.getElementById( strElementDeviceId );

	// Check if the user clicked the Disconnect button
	// And update the device id in the device id field, and the device name in the readonly field
	if( bDisconnect === true ) {
		// If the Other End is already empty, nothing to do
		if( elementOtherEnd.value === '' ) { return; }
		elementDeviceId.value = '';
		elementOtherEnd.value = '';
		buttonSelect.setAttribute( 'disabled', 'disabled' );
		elementOtherEnd.setAttribute( 'lastselected', '' );
		elementOtherEnd.setAttribute( 'lastsearch', '' );
	} else {
                let selectedOption = elementSelect.options[elementSelect.selectedIndex];
		if( ! selectedOption ) return;
		elementDeviceId.value = selectedOption.value;
		elementOtherEnd.value = selectedOption.text;
		elementOtherEnd.setAttribute( 'lastselected', elementOtherEnd.value );
		let strSelectButtonId = buttonSelect.getAttribute( 'mydisconnectbutton' );
		document.getElementById( strSelectButtonId ).removeAttribute( 'disabled' );
	}
	updateChangeTrackingStatus( elementOtherEnd );

	// Get the device link, patch panel link and ports list updated
	// function showPhysical_ports(devidfld, devnamfld, physportid, portboxname, type, side) {
	showPhysical_ports( elementDeviceId, elementOtherEnd, iPortId, strElementPortsId, strType, strSide );
	elementPopup.style.visibility = 'hidden';
	elementOtherEnd.focus();
}

//
// create the div that handles the auto complete search
//
function create_search_popup(txtsource, idsave, event, noSubmitForm, ondone) {
	var popupName = txtsource.id + "_popUp";
	var popup = document.getElementById(popupName);

	if(!txtsource) {
		return;
	}

	if(popup) {
		return popup;
	}

	txtsource.setAttribute("autocomplete", "off");

	if(txtsource.orig_value = null) {
		txtsource.orig_value = txtsource.value;
	}

	popup = document.createElement("div");
	popup.id = popupName
	popup.className = 'searchPopup';
	popup.style.position = 'absolute';
	popup.style.visibility = 'hidden';
	var x = findPosX(txtsource);
	var y = findPosY(txtsource);
	y += txtsource.offsetHeight;
	popup.style.left = x + "px";
	popup.style.top = y + "px"; 
	if(noSubmitForm) {
		popup.noSubmitForm = noSubmitForm;
	}
	if(ondone) {
		popup.oncompletion = ondone;
	}
	popup.onfocus = keepVisible_Search;
	popup.onmouseover = mouseover_Search;
	popup.onmouseout = mouseout_Search;
	popup.onblur = hideonBlur_Search;
	popup.txtid = txtsource;
	popup.idsave = idsave;
	document.body.appendChild(popup);

	return popup;
}

function inputEvent_Search(txtsource, idsave, event, noSubmitForm, ondone) {
	var popupName = txtsource.id + "_popUp";
	var popup = document.getElementById(popupName);

	// if keyprocess_Search has set a timer, then this has already been
	// processed,
	// so don't do anything.
	if(timer != null) {
		return;
	}

	if(popup == null) {
		txtsource.orig_value = "";
		popup = create_search_popup(txtsource, idsave, event, noSubmitForm, ondone);
	}
	changePopup_Search(txtsource, popup);
}

//
// called when the textfield has a key released in it.
//
var searchrequest;
var searchpopup;
var timer = null;
function keyprocess_Search(txtsource, idsave, event, noSubmitForm, ondone) {
	var popupName = txtsource.id + "_popUp";
	var popup = document.getElementById(popupName);

	window.clearTimeout(timer);
	timer = null;

	//
	// this is used to restore the value to something if a valid
	// option is not picked.
	if(txtsource.pending == null) {
		txtsource.oldval = txtsource.value;
		txtsource.pending = true;
	}

	// only do something if printable keys were pressed
	// num lock(144), scroll lock(145), pause(19), capslock(20), 
	// shift/ctrl/alt (16-18), open apple (244)
	// page up/down/end/home/arrows (33-45)
	var keycode;
	if(window.event) { // IE
		keycode = event.keyCode
	} else if(event.keyCode) { // Netscape/Firefox/Opera
		keycode = event.which 
	}
	if(keycode == 9) {
		return;
	}
	if(keycode != 40) {
		if(keycode == 144 || keycode == 145 || keycode == 19 || 
				keycode == 20 ||  // keycode == 224 ||
				(keycode >=16 && keycode <= 18) || (keycode >=33 && keycode <=45)) {
			return;
		}

		// 40, 27, 9 all pass through
		if(keycode != 27 && keycode != 0 && event.charCode == 0) {
			return;
		}
	}


	//
	// XXX TODO - safari, ie6 and ie7 support
	// XXX TODO - deal with if an invalid value is left in the
	//		textfield.  reset to original value
	// XXX TODO - fill in a parent device id properly
	//
	if(popup == null) {
		if(keycode == 27) {
			return;
		}
		popup = create_search_popup(txtsource, idsave, event, noSubmitForm, ondone);
	} else {
		if(keycode == 40) { // down arrow
			popup.leaveUp = true;
			for(var i = 0; i < popup.childNodes.length; i++) {
				if (popup.childNodes[i].className == 'select') {
					popup.childNodes[i].focus();
				}
			}
			return;
		} else if(keycode == 27 || keycode == 9) { // esc && tab
			popup.leaveUp = false;
			processSearchBox_Breakdown(popup);
			return;
		}

		// up == 38, esc == 28, tab == 9
	}

	if(popup.txtid.oldvalue) {
		if(popup.txtid.oldvalue.length == 0 & popup.txtid.value.length > 0) {
			popup.txtid.oldvalue = popup.txtid.value;
		} else {
			// return;
		}
	} else {
		popup.txtid.oldvalue = popup.txtid.value;
	}

	timer = window.setTimeout(function() { changePopup_Search(txtsource, popup); }, 350);
}

function changePopup_Search(tf, popup) {
	window.clearTimeout(timer);
	timer = null;

	if(tf.value.length > 0) {
		var url = "ajax-devsearch.pl?" +
			"lookfor=" + tf.value;
		;
		// var url = "insertit.pl";
		popup.style.visibility = 'visible';
		searchrequest = createRequest();
		searchrequest.open("GET", url, true);
		searchrequest.onreadystatechange = updatePopUpSearchPage;
		searchrequest.send(null);
		searchpopup = popup;
	} else {
		popup.style.visibility = 'hidden';
		popup.parentNode.removeChild(popup);
	}
}

function  updatePopUpSearchPage() {
	if(searchrequest.readyState == 4) {
		var htmlgoo = searchrequest.responseText;
		// var obj = document.getElementById(searchrequest.popupName);
		// searchrequest.popupName = null;
		if(searchpopup) {
			searchpopup.innerHTML = htmlgoo;
			searchpopup.style.visibility = 'visible';
		}
	}
}

//
// This is called when the textfield looses focus.
// 
// need to be careful not to close the dropdown when that's where the
// focus is going, however.
//
function hidePopup_Search(txtsource) {
	var popupName = txtsource.id + "_popUp";
	var popup = document.getElementById(popupName);

	if(!popup) {
		return;
	}

	if(popup.leaveUp && popup.leaveUp == true) {
		popup.leaveUp = false;
		return;
	}

	//
	// if something is typed into the field and it is in the dropdown
	// (ie, valid), then reset to that, otherwise revert back to what
	// was there before.
	if(popup.style.visibility != 'hidden') {
		var dropdown;
		for(var i = 0; i < popup.childNodes.length; i ++) {
			if (popup.childNodes[i].className == 'select') {
				dropdown = popup.childNodes[i];
				break;
			}
		}
		closeAndFillIn_Search(dropdown, popup);
	}


	// consider folding it into the above?
	//if(popup.txtid && popup.txtid.value.length == 0) {
	//	popup.idsave.value = null;
	//	if(popup.oncompletion) {
	//		popup.oncompletion();
	//	}
	//}
}


