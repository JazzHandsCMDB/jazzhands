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
// Read cgi parameters from url
// We need them to repopulate the fields after a failed update
//
var hCGIParams = {};
window.location.search.replace(/^\?/,'').split(';').forEach( (v) => {
	kv = v.split( '=' );
	hCGIParams[kv[0]] = kv[1];
});

//
// This functions updates a Collection picker dropdown
// when another Collection Type is chosen
// It's used when a netblock collection is displayed
// but not on the initial collection selection page
//
function update_collection_select( elementCollectionTypeSelect ) {
	const strSelectedCollectionType = elementCollectionTypeSelect.options[elementCollectionTypeSelect.selectedIndex].value;
	const strElementCollectionSelectId = elementCollectionTypeSelect.getAttribute( 'my_collection_dropdown' );
	let elementCollectionSelect = document.getElementById( strElementCollectionSelectId );

	// Do we have a collection type selected?
        if( strSelectedCollectionType === '__unknown__' ) {
		// No, so let's remove the Collection select element if it exists
		// along with the preceding br and span elements
		if( elementCollectionSelect ) {
			elementCollectionSelect.remove();
			elementCollectionTypeSelect.nextSibling.remove();
			elementCollectionTypeSelect.nextSibling.remove();
		}
		return;
	}

	// At this point we have a valid collection type selected
	// So let's create the collection picker dropdown if it doesn't exist
	if( ! elementCollectionSelect ) {
		elementCollectionTypeSelect.parentElement.appendChild( document.createElement( 'br' ) );
		let elementSpan = document.createElement( 'span' );
		elementSpan.className = 'netblocksite';
		elementSpan.innerHTML = '- ';
		elementCollectionTypeSelect.parentElement.appendChild( elementSpan );
		elementCollectionSelect = document.createElement( 'select' );
		elementCollectionSelect.id = strElementCollectionSelectId;
		elementCollectionSelect.name = strElementCollectionSelectId;
		elementCollectionSelect.className = 'netcoldrop';
		elementCollectionTypeSelect.parentElement.appendChild( elementCollectionSelect );
	} else {
		elementCollectionSelect.innerHTML = '';
	}
	// Populate the collection picker dropdown
	let elementOption = document.createElement( 'option' );
	elementOption.text = 'Loading...';
	elementCollectionSelect.add( elementOption );

	populate_collections_select( elementCollectionSelect, strSelectedCollectionType );
}

//
// This function populates a Collection Type dropdown
// Technically, it could reuse any previous ajax call data
// But for now it calls the database again, which is rather quick
// It's used when a netblock collection is displayed
// but not on the initial collection selection page
//
function populate_collection_types_select( elementSelect ) {
	$.getJSON('netcol-ajax.pl',
		'what=CollectionTypes',
		function( data ) {
			elementSelect.innerHTML = '';
			let elementOption = document.createElement( 'option' );
			elementOption.value = '__unknown__';
			elementOption.text = 'Please Select a Collection Type';
			elementSelect.add( elementOption );
			// Get the CGI value, if any
			const strValue = ( elementSelect.id in hCGIParams ) ? hCGIParams[ elementSelect.id ] : '';
			let bTriggerOnChange = false;
			for( let i = 0; i < data['NETBLOCK_COLLECTION_TYPES'].length; i++ ) {
				elementOption = document.createElement( 'option' );
		                elementOption.value = data['NETBLOCK_COLLECTION_TYPES'][i]['name'];
				if( strValue === elementOption.value ) {
					elementOption.selected = 'selected';
					bTriggerOnChange = true;
				}
		                elementOption.text = data['NETBLOCK_COLLECTION_TYPES'][i]['human'];
				elementSelect.add( elementOption );
			}
			if( bTriggerOnChange ) {
				update_collection_select( elementSelect );
			}
		}
	);
}

//
// This function inserts an additional netblock input row
//
var iNumNetblockInputs = 0;
function insert_netblock_input_row() {
	const elementAddButton = document.getElementById('insert_NETBLOCK');
	const elementRow = document.createElement('li');
	iNumNetblockInputs ++;
	const strId = 'add_NETBLOCK' + iNumNetblockInputs;
	const strValue = ( strId in hCGIParams ) ? hCGIParams[ strId ] : '';
	elementRow.innerHTML = '<span class="netblocksite">-</span> <span class="netblocklink"><input type="text" name=\'' + strId + '\' autocomplete="on" value=\''  +strValue + '\'/></span> <span class="netblockdesc"> - NEW NETWORK</span>';
	elementAddButton.parentElement.parentElement.insertBefore( elementRow, elementAddButton.parentElement );
}

//
// This function inserts an additional child collection input row
//
var iNumChildCollectionInputs = 0;
function insert_child_collection_input_row() {
	const elementAddButton = document.getElementById('insert_CHILD_COLLECTION');
	const elementRow = document.createElement('li');
	iNumChildCollectionInputs ++;
	const strId = 'add_CHILD_COLLECTION' + iNumChildCollectionInputs;
	elementRow.innerHTML = '<span class="netblocksite">-</span> <span class="netblocklink"><select id=\'' + strId + '\' name=\'' + strId + '\' class="collectiontypepicker" onchange=\'update_collection_select( this );\' my_collection_dropdown=\'pick_NETBLOCK_COLLECTION_ID' + iNumChildCollectionInputs + '\'><option>Loading...</option></select></span> <span class="netblockdesc"> - NEW CHILD COLLECTION</span>';
	elementAddButton.parentElement.parentElement.insertBefore( elementRow, elementAddButton.parentElement );
	populate_collection_types_select( document.getElementById( 'add_CHILD_COLLECTION' + iNumChildCollectionInputs ) );
}

//
// This function populates a Collection dropdown
// based on the selected Collection Type
// It's used on the initial collection selection page
// Not when an actual collection is displayed
//
function populate_collections_select( elementSelect, strCollectionType ) {
	$.getJSON('netcol-ajax.pl',
		'what=Collections;type=' + strCollectionType,
		function( data ) {
			elementSelect.innerHTML = '';
			// Get the CGI value, if any
			const strValue = ( elementSelect.id in hCGIParams ) ? hCGIParams[ elementSelect.id ] : '';
			if( ! ( 'NETBLOCK_COLLECTIONS' in data ) ) return;
			for( let i = 0; i < data['NETBLOCK_COLLECTIONS'].length; i++ ) {
				let elementOption = document.createElement( 'option' );
		                elementOption.value = data['NETBLOCK_COLLECTIONS'][i]['id'];
		                elementOption.text = data['NETBLOCK_COLLECTIONS'][i]['human'];
				if( strValue === elementOption.value ) {
					elementOption.selected = 'selected';
				}
				elementSelect.add( elementOption );
			}
		}
	);
}

//
// This function builds the collection picker dropdown
// It's used on the initial collection selection page
// Not when an actual collection is displayed
//
function build_collection_drop(resp, div) {
	var sel = $("<select/>", {
		name: "pick_NETBLOCK_COLLECTION_ID",
		class: "netcoldrop",
	});
	var tally = 0;
	// Loop on the netblock collections, but only if NETBLOCK_COLLECTIONS is defined in the response
	if( ! ( 'NETBLOCK_COLLECTIONS' in resp ) ) {
		$(div).empty();
		// Hide the entire collection picker container div, which id is container_colbox, if there are no collections
		$('#container_colbox').hide();
		return;
	}
	$('#container_colbox').show();
	for(var coll of resp['NETBLOCK_COLLECTIONS']) {
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

	// Repopulate netblock input fields after a failed updated, if any
	if( document.getElementById('insert_NETBLOCK') ) {
		// Check if we have add_NETBLOCK parameters, indicating a failed update
		const iNumAddNetblockParams = Object.keys( hCGIParams ).filter(key => key.match( /^add_NETBLOCK\d+$/ ) ).length;
		if( iNumAddNetblockParams > 0 ) {
			// Loop on all add_NETBLOCK parameters
			for( let i = 0; i < iNumAddNetblockParams; i++ ) {
				insert_netblock_input_row();
			}
		// This is not a failed update, we just add one empty input row
		} else {
			insert_netblock_input_row();
		}
	}

	// Repopulate child collection input fields after a failed updated, if any
	if( document.getElementById('insert_CHILD_COLLECTION') ) {
		// Check if we have add_CHILD_COLLECTION parameters, indicating a failed update
		const iNumAddCollectionParams = Object.keys( hCGIParams ).filter(key => key.match( /^add_CHILD_COLLECTION\d+$/ ) ).length
		if( iNumAddCollectionParams > 0 ) {
			// Loop on all add_CHILD_COLLECTION parameters
			for( let i = 0; i < iNumAddCollectionParams; i++ ) {
				insert_child_collection_input_row();
			}
		// This is not a failed update, we just add one empty input row
		} else {
			insert_child_collection_input_row();
		}
	}
});

