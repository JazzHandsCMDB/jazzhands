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
	//
	// enable all appropriate tabs
	//
	enable_stab_tabs();

	// clear value on all hidden form entries.  This can be confusing on
	// page reloads.
	$('form#attest').find('input.approve_value').each(function(i, obj) {
		$(obj).val('');
	});

	// setup all the chosen boxes
    var config = {
      '.chosen-select'           : {},
      '.chosen-select-deselect'  : {allow_single_deselect:true},
      '.chosen-select-no-single' : {disable_search_threshold:10},
      '.chosen-select-no-results': {no_results_text:'Oops, nothing found!'},
      '.chosen-select-width'     : {width:"95%"}
    }
    for (var selector in config) {
      $(selector).chosen(config[selector]);
    }


	// on load (or reload), uncheck all the boxes
	$('input.attesttoggle,input.approveall').each(
		function(iter, obj) {
			$(obj).prop('checked', false);
		}
	);

	$("table").on('focus', ".hint", function(event) {
		$(event.target).removeClass('hint');
		$(event.target).closest('td').removeClass('error');
		event.target.preservedHint = $(event.target).val();
		$(event.target).val('');
	});
	// this causes the grey'd out hint to come backw ith an empty field
	$("table").on('blur', ".correction", function(event) {
		if( $(event.target).val() == '' && event.target.preservedHint ) {
			$(event.target).addClass('hint');
			$(event.target).val( event.target.preservedHint );
		}
	});

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
		$(event.target).closest('td').removeClass('error');

		if( ! approve ) {
			var dis = $(event.target).closest('tr').find('div.correction').first();
			var id = $(dis).attr('id');
			var newid = "fix_"+id;
			var iput = "#"+newid;

			var category = $(event.target).closest('tr').find('#approval_category').val();

			$(dis).find(iput).prop("disabled", false);
			$(dis).find(iput).closest('td').removeClass('hidecorrection');
		} else {
			$(event.target).closest('tr').find('input.correction').each(
				function(iter, obj) {
					$(obj).prop("disabled", true);
					$(obj).closest('td').addClass('hidecorrection');
					$(obj).closest('td').removeClass('error');
				}
			);
			$(event.target).closest('tr').find('select.correction').each(
				function(iter, obj) {
					$(obj).prop("disabled", true);
					$(obj).closest('td').addClass('hidecorrection');
					$(obj).closest('td').removeClass('error');
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
						$(obj).closest('td').removeClass('error');
						$(obj).closest('td').addClass('hidecorrection');
					}
				);
				$(obj).closest('td').removeClass('error');
			}
		);
	});

	$('#attest').submit( function(event) {
		var s = { dosubmit: true };

		// check for corrections that were not filled in
		$('form#attest').find('input.correction').each(function(i, obj) {
			if( !$(obj).closest('td').hasClass('hidecorrection') && 
					($(obj).hasClass('hint') || $(obj).val().length == 0 ) ) {
				s.dosubmit = false;
				$(obj).closest('td').addClass('error');
			} else {
				$(obj).closest('td').removeClass('error');
			}
		});

		// check for chosen selects that were not filled in
		$('form#attest').find('select.correction').each(function(i, obj) {
			if( !$(obj).closest('td').hasClass('hidecorrection') && 
					($(obj).hasClass('hint') || $(obj).val().length == 0 ) ) {
				s.dosubmit = false;
				$(obj).closest('td').addClass('error');
			} else {
				$(obj).closest('td').removeClass('error');
			}
		});

		// check for unchecked rows
		$('form#attest').find('input.approve_value').each(function(i, obj) {
			if( $(obj).val() == '' && !$(obj).closest('td').hasClass('hidecorrection')) {
				$(obj).closest('td').addClass('error');
				s.dosubmit = false;
			} else { 
				$(obj).closest('td').removeClass('error');
			}
		});

		if( s.dosubmit == false ) {
			alert("You must specify approve or request changes for each item.");
			event.preventDefault();
		}
		return s.dosubmit;
	});

});

function build_approve_correct(resp, newid) {
	var box = $("<input />", { 
		name: newid,
		id: newid,
		class: 'correction hint',
		value: 'enter correction',
	});
	return box;
}
