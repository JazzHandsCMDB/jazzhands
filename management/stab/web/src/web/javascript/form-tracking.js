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



// Update chnage tracking status of specified element
function updateChangeTrackingStatus( element ) {

	// Do we have the 'original' custom attribute - which is needed to track original values from DB
	if( element.hasAttribute( 'original' ) ) {
		// Does the element have an options parameter (it's a select)?
		if( element.options ) {
			// Are the currently selected values identical to the original ones?
			// Lopp on options
			let bDefaultSelected = true;
			// Let's consider the original string as a comma separated listed
			var originalSelectedValues = element.getAttribute( 'original' ).split( ',' );
			for( let option of element.options ) {
				// Is the option selected now but not in the original setup?
				// Or the other way round?
				if( ( originalSelectedValues.includes( option.value ) && ! option.selected ) || ( ! originalSelectedValues.includes( option.value ) && option.selected ) ) {
					bDefaultSelected = false;
					break;
				}
			}
			// Do we have default values selected?
			if( bDefaultSelected ) {
				element.classList.remove( 'changed' );
			} else {
				element.classList.add( 'changed' );
			}
		// Is it a radio control?
		} else if( element.type === 'radio' ) {
			// We need to update all radio buttons of the group, because the onchange event only targets the clicked one
			$( 'input[type="radio"][name="' + element.name + '"]' ).each( function() {
				// The 'original' custom attribute is the id of the selected radio group member selected by default
				( this.checked && this.getAttribute( 'original' ) === 'checked' ) || ( ! this.checked && this.getAttribute( 'original' ) === '' ) ? this.classList.remove( 'changed' ):this.classList.add( 'changed' );
			});
		// Is it a checkbox?
		} else if( element.type === 'checkbox' ) {
			( element.getAttribute( 'original' ) === 'checked' && element.checked ) || ( element.getAttribute( 'original' ) === '' && ! element.checked ) ? element.classList.remove( 'changed' ):element.classList.add( 'changed' );
		// It's not a select, not a radio and not a checkbox
		} else {
			element.getAttribute( 'original' ) === element.value ? element.classList.remove( 'changed' ):element.classList.add( 'changed' );
		}
		// We stop the processing here
		return;
	}

	// At this point, the element has no 'original' custom attribute
	// Let's use what html has to offer as a fallback
	// That won't work after failed updates with modified fields, but it will work for display before the first submit

	// Does the element have an options parameter (it's a select)?
	if( element.options ) {
		// Lopp on options
		let bDefaultSelected = true;
		for( let option of element.options ) {
			if( option.defaultSelected !== option.selected ) {
				bDefaultSelected = false;
				break;
			}
		}
		// Do we have default values selected?
		if( bDefaultSelected ) {
			element.classList.remove( 'changed' );
		} else {
			element.classList.add( 'changed' );
		}
	// Is it a radio control?
	} else if( element.type === 'radio' ) {
		// We need to update all radio buttons of the group, because the onchange event only targets the clicked one
		$( 'input[type="radio"][name="' + element.name + '"]' ).each( function() {
			this.defaultChecked === this.checked ? this.classList.remove( 'changed' ):this.classList.add( 'changed' );
		});
		//element.defaultChecked === element.checked ? element.classList.remove( 'changed' ):element.classList.add( 'changed' );
	} else if( element.type === 'checkbox' ) {
		element.defaultChecked === element.checked ? element.classList.remove( 'changed' ):element.classList.add( 'changed' );
	// No, it's another input field
	} else {
		element.defaultValue === element.value ? element.classList.remove( 'changed' ):element.classList.add( 'changed' );
	}
}



// Function used to add a list of changed items in the form as hidden elements
// There is one list of changed element names and one list with Stab-defined Ids.
// Those Ids are whatever follows the last _ in tracked element names.
// For example NETWORK_RANGE_TYPE_
function preSubmitTrackedElements( submitButton ) {
	// Cleanup any previous hidden element tracking the changed elements
	document.querySelectorAll( 'input.changedElements' ).forEach( (element) => { element.remove(); });

	// Create one hidden element with tracked and changed elements
	let changedElements = [];
	let changedElementsIds = [];
	document.querySelectorAll(".tracked.changed").forEach( ( trackedUpdatedElement ) => {
		// Extract the id
		let strId = trackedUpdatedElement.name.split('_').pop();
		if( ! changedElementsIds.includes( strId ) ) {
			changedElementsIds.push( strId );
		}
		if( ! changedElements.includes( trackedUpdatedElement.name ) ) {
			changedElements.push( trackedUpdatedElement.name );
		}
	});

	var hiddenElement = document.createElement( 'input' );
	hiddenElement.setAttribute( 'type', 'hidden' );
	hiddenElement.name = 'CHANGED_ELEMENTS';
	hiddenElement.className = 'changedElements';
	hiddenElement.value = changedElements.join(',');
	submitButton.form.appendChild( hiddenElement );

	hiddenElement = document.createElement( 'input' );
	hiddenElement.setAttribute( 'type', 'hidden' );
	hiddenElement.name = 'CHANGED_ELEMENTS_IDS';
	hiddenElement.className = 'changedElements';
	hiddenElement.value = changedElementsIds.join(',');
	submitButton.form.appendChild( hiddenElement );

	//console.log( document.querySelectorAll( 'input.changedElements' ) );
	//console.log( document.querySelectorAll( 'input.changedElementsIds' ) );
}



// Enable change tracking when the document is loaded
$(document).ready(function(){

	// The browser may populate fields after a page refresh, so set the tracked status accordingly
	document.querySelectorAll( '.tracked' ).forEach( ( element ) => {
		updateChangeTrackingStatus( element )
	});

	// Add change tracking to relevant elements (those having the 'tracked' class)
	$('body').on( 'change keyup input', '.tracked', function( event ) {
		// Get the element that triggered the event
		let element = $(this)[0];
		updateChangeTrackingStatus( element );
	});

	// Make the submit button(s) supply a list of changed items in the form
	document.querySelectorAll( 'input[type="submit"]' ).forEach( ( submitButton ) => {
		submitButton.addEventListener( 'click', function( event ) { preSubmitTrackedElements( event.target ); } );
	});

});

