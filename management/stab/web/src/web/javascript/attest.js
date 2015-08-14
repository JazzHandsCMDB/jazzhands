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
	// on load (or reload), uncheck all the boxes
	$('input.attesttoggle,input.approveall').each(
		function(iter, obj) {
			$(obj).prop('checked', false);
		}
	);

	// if the y button is checked, uncheck the button
	$("table.attest").on('click', ".attesttoggle", function(event) {
		var other;
		var approve = false;

		var val = $(event.target).closest('td').find('.approve_value');

		if( $(event.target).hasClass('approve') ) {
			other = $(event.target).closest('tr').find('.disapprove');
			$(val).val('approve');
			approve = true;
		} else {
			other = $(event.target).closest('tr').find('.approve');
			$(val).val('reject');
			approve = false;
		}

		$(other).removeClass('buttonon');
		$(event.target).addClass('buttonon');

		if(! approve) {
			var dis = $(event.target).closest('tr').find('div.correction').first();
			var id = $(dis).attr('id');
			var newid = "fix_"+id;
			var iput = "input#"+newid;

			if( ! $(iput).length ) {
				var box = $("<input />", { 
					name: newid,
					id: newid,
					class: 'correction'
				});
				$(box).insertAfter(dis);
			} else {
				$(iput).prop("disabled", false);
				$(iput).removeClass('irrelevant');
			}
		} else {
			$(event.target).closest('tr').find('input.correction').each(
				function(iter, obj) {
					$(obj).prop("disabled", true);
					$(obj).addClass('irrelevant');
				}
			);
		}

	});

	$("table.attest").on('click', "input.approveall", function(event) {

		$(event.target).closest('table.attest').find('input.approve').each( 
			function(iter, obj) {
				$(obj).addClass('buttonon');
				$(obj).closest('td').find('.disapprove').removeClass('buttonon');
				$(obj).closest('td').find('.approve_value').val('approve');
				$(event.target).closest('table.attest').find('.correction').each(
					function(iter, obj) {
						$(obj).prop("disabled", true);
						$(obj).addClass('irrelevant');
					}
				);
			}
		);
	});

	$('#attest').submit( function(event) {
		var s = { dosubmit: true };

		return true;

		// check for unset values
		$('form#attest').find('input.correction').each(function(i, obj) {
			if($(obj).val().length == 0) {
				s.dosubmit = false;
				$(obj).closest('td').addClass('error');
			} else {
				$(obj).closest('td').removeClass('error');
			}
		});

		// check for unset values
		$('form#attest').find('input.approve').each(function(i, obj) {
			var other = $(obj).closest('tr').find('input.disapprove');
			if( (!$(obj).is(':checked') && !$(other).is(':checked')) ||
					( $(obj).is(':checked') && $(other).is(':checked')) ) {
				s.dosubmit = false;
				$(obj).closest("td").addClass('error');
				$(other).closest("td").addClass('error');
			} else {
				$(obj).closest("td").removeClass('error');
				$(other).closest("td").removeClass('error');
			}
		});

		if( s.dosubmit == false ) {
			alert("You must specify approve or disapprove and enter a corrected value for each disapproval.");
			event.preventDefault();
		}
		return s.dosubmit;
	});

});
