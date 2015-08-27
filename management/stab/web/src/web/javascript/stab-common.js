/*
 * Copyright (c) 2013-2015, Todd M. Kover
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


function toggleon_text(but) {
	// var p = $(but).prev(":input").removeAttr('disabled');
	// var d = $(but).previousSibling;
	// $(but).filter(":parent").filter("input:disabled").removeAttr('disabled');

	$(but).prev(":input").removeAttr('disabled');
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
					// this is only necessary in the tab bar
					$(obj).addClass('stabtab_off');
				}
			);
			$(event.target).removeClass('stabtab_off');
			$(event.target).addClass('stabtab_on');

			var id = $(event.target).attr('id');
			$(event.target).closest('.stabtabset').find('div.stabtabcontent').find('div.stabtab#'+id).each(
				function(iter, obj) {
					$(obj).addClass('stabtab_on');
				}
			);
		}
	});
}
