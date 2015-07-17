/*
 * Copyright (c) 2015, Todd M. Kover					     
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

$(document).ready(function(){
	// if the y button is checked, uncheck the button
	$("table.attest").on('click', ".attesttoggle", function(event) {
		var other;
		var dodis = false;
		if( $(event.target).hasClass('approve') ) {
			other = $(event.target).closest('tr').find('.disapprove');
		} else {
			other = $(event.target).closest('tr').find('.approve');
			if( $(event.target).is(':checked') ) {
				dodis = true;
			}
		}
		if( $(event.target).is(':checked') ) {
			$(other).attr('checked', false);
		}

		if(dodis) {
			alert('dis');
		}


	});

	$("table.attest").on('click', "input.approveall", function(event) {
		var makeem = $(event.target).is(':checked');

		$(event.target).closest('table.attest').find('input.approve').each( function(iter, obj) {
			$(obj).prop('checked', makeem);
		});

	});

});
