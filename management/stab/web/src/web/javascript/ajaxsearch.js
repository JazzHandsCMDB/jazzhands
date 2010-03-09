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


