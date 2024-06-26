/*
 * Copyright (c) 2013-2017, Todd M. Kover
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

function swaparrows(id, state) {
	img = document.getElementById( id );
	if(img == null) {
		return;
	}

	if(state == 'dance') {
		return;
	}

	if(state == 'down') {
		img.src = img.src.replace(/stabcons\/.*$/gi, "stabcons/collapse.jpg");
	} else if(state == 'up') {
		img.src = img.src.replace(/stabcons\/.*$/gi, "stabcons/expand.jpg");
	}
}

//
// jqeuery version of the above.  They should be consolidated.
// Should also be tweaked to be a jquery function $(foo).progress('dance') or whatever.
//
// also become a general purpose progress thing, which could be used to swap
// arrows or to just show progress
//
function swaparrows_jq(obj, state) {
	if(obj == null) {
		return;
	}
	if(!$(obj).length ) {
		return;
	}

	if(state == 'hide') {
		$(obj).addClass('irrelevant');
		return;
	} else {
		$(obj).removeClass('irrelevant');
	}

	if(state == 'dance') {
		return;
	}

	var thing = $(obj).attr('src');
	if(state == 'down') {
		thing = thing.replace(/stabcons\/.*$/gi, "stabcons/collapse.jpg");
	} else if(state == 'up') {
		thing = thing.replace(/stabcons\/.*$/gi, "stabcons/expand.jpg");
	}

	$(obj).attr('src', thing);
}

function toggleon_text(but) {
	$(but).prev(":input").toggleClass('off');
	$(but).addClass('irrelevant');
}

//
// called in a ready() function to enable tabs on a given page
//
function enable_stab_tabs() {
	$('div.stabtabbar').on('click', 'a.stabtab', function(event) {
		// clicking the open tab (stabtab_on) is off.
		if($(event.target).hasClass('stabtab_off')) {
			$(event.target).closest('.stabtabset').find('.stabtab_on').each(
				function(iter, obj) {
					$(obj).removeClass('stabtab_on');
					$(obj).addClass('stabtab_off');
				}
			);
			$(event.target).removeClass('stabtab_off');
			$(event.target).addClass('stabtab_on');

			var id = $(event.target).attr('id');
			$(event.target).closest('.stabtabset').find('div.stabtabcontent').find('div.stabtab#'+id).each(
				function(iter, obj) {
					$(obj).removeClass('stabtab_off');
					$(obj).addClass('stabtab_on');
				}
			);
		}
	});
}



// This function is used to process deferred scripts stored in script elements
// with class 'deferred' and data attribute 'data-code' containing the script code.
// Those script elements are added to the DOM by the server side code as part of
// ajax requesuts and are not executed by the browser, mostly because they are
// not returned as a text/javascript content type.
function processDeferredScripts() {
	$('script.deferred').each(function() {
		var newScript = document.createElement("script");
		var inlineScript = document.createTextNode($(this).attr('data-code'));
		newScript.appendChild(inlineScript);
		document.body.appendChild(newScript);
		// Remove class deferred from script
		$(this).removeClass('deferred');
	});
}
