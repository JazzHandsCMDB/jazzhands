/*
 * Copyright (c) 2014, Todd M. Kover					     
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

function build_collection_drop(resp, div) {
	var sel = $("<select/>", {
		name: "pick_NETBLOCK_COLLECTION_ID",
		class: "netcoldrop",
	});
	var tally = 0;
	for(var coll of  resp['NETBLOCK_COLLECTIONS']) {
		var id = coll['id'];
		var desc = coll['human'];
		var o = $("<option/>", {
			value: id,
			text: desc
		});
		$(sel).append(o)
		tally++;
	}

	$(div).empty();
	if(tally) {
		$(div).append(sel);
	}
}

//
// This populates a dropdown based on a netblock collection type, and will
// allow the creation of a new one of that type or manipulation of existing
// ones
//
function change_collection_select(obj) {
	var box = $(obj).closest('.ncmanip').find('div#collec_detail');
	var coldiv = $(obj).closest('.ncmanip').find('div#colbox');
	var typedrop = $(obj).closest('.ncmanip').find('select.coltypepicker');

	var coltype = $(typedrop).val();

	if(coltype != '__unknown__') {
		$.getJSON('netcol-ajax.pl',
			'what=Collections;type='+coltype,
			function(resp) {
				build_collection_drop(resp, coldiv);
			}
		);
		$(box).removeClass('irrelevant');
	} else {
		$(box).addClass('irrelevant');
		$(coldiv).empty();
	}

	
}

$(document).ready(function(){
	$("select.coltypepicker").change(
		function(event) {
			change_collection_select(event.target);
		}
	);

	// on page reload, clear out the type drop down and make the collection
	// box go away.  It may make more sense instead to re-run
	// chanage_collection_select() on the picker to get it to recreate the
	// name box, but I'm lazy.
	$(".coltypepicker").val("__unknown__");
	$('.ncmanip').find('div#colbox').empty();
});
