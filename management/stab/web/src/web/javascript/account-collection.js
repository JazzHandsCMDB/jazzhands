/*
 * Copyright (c) 2017, Todd M. Kover
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

//
// process ajax response and populates div with a list of accounts,
// expanded.
//
function build_expandlist_box(resp, div) {
	var ul = $("<ul/>", {class: 'collectionbox'});

	var tally = 0;
	for(var i in resp['ACCOUNTS']) {
		if(i) {
			var r = resp['ACCOUNTS'][i];
			var o = $("<li/>").append(r['print']);
			$(ul).append(o)
			tally++;
		}
	}

	$(div).empty();
	if(tally) {
		$(div).append(ul);
	}
	$(div).append(
		$("<a/>", {
			href: '#',
			class: 'expandcollection'
		}).append("(collapse)")
	);
}

//
// shows a popup with a list of people in the collection, expanding through
// account collections
//
function expand_collection(button)  {
	var pop = $(button).closest('div.collectionname').find('div.collectionexpandview').first();
	var dance = $(button).closest('div.collectionname').find('div.dance.spinner');

	var id = $(pop).attr('id');

	if( $(pop).hasClass('irrelevant')) {
		swaparrows_jq( dance,  'dance');
		$.getJSON('acctcol-ajax.pl',
			'what=ExpandMembers;id='+id,
			function(resp) {
				build_expandlist_box(resp, pop);
				$(pop).removeClass('irrelevant');
				swaparrows_jq( dance, 'hide');
			}
		);
	} else {
		$(pop).addClass('irrelevant');
	}

}

function build_collection_drop_from_type(resp, div) {
	var sel = $("<select/>", {
		name: "ACCOUNT_COLLECTION_ID",
		class: "netcoldrop",
	});
	var tally = 0;
	for(var id in resp['ACCOUNT_COLLECTIONS']) {
		if(id) {
			var r = resp['ACCOUNT_COLLECTIONS'][id];
			var o = $("<option/>", {
				value: id,
				text: r
			});
			$(sel).append(o)
			tally++;
		}
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
	var box = $(obj).closest('.acmanip').find('div#collec_detail');
	var coldiv = $(obj).closest('.acmanip').find('div#colbox');
	var typedrop = $(obj).closest('.acmanip').find('select.coltypepicker');

	var coltype = $(typedrop).val();

	if(coltype != '__unknown__') {
		var dance = $(obj).closest('div.collectionbox').find('div.dance.spinner');
		swaparrows_jq( dance,  'dance');
		$(coldiv).empty();
		$(box).addClass('irrelevant');
		$.getJSON('acctcol-ajax.pl',
			'what=Collections;type='+coltype,
			function(resp) {
				build_collection_drop_from_type(resp, coldiv);
				$(box).removeClass('irrelevant');
				swaparrows_jq( dance,  'hide');
			}
		);
	} else {
		$(box).addClass('irrelevant');
		$(coldiv).empty();
	}

	
}

//
// This is a separate function so it can be re-called when new rows are
// created.
//
function configure_account_collection_autocomplete(selector) {
	if(selector == null) {
		selector = 'input.acautocomplete';
	}

	//
	// Its done this way so that the URL can have the type in it.
	//
	$('html').find(selector).each(function(idx, elem) {
		var url = 'acctcol-ajax.pl?what=autocomplete;type=account';
		$(elem).devbridgeAutocomplete({
			noCache: false,
			deferRequestBy: 200,
			showNoSuggestionNotice: true,
			noSuggestionNotice: 'No suggested matches.',
			serviceUrl: url,
			triggerSelectOnValidInput: true,
			autoSelectFirst: true,
			onSelect: function (suggestion) {
				var x = $(this).closest('li').find('.acaccountid');
				$(x).val(suggestion.data);
			},
			onSearchStart: function(container, suggestion) {
				$(this).closest('li').find('.acaccountid').val(null);
			}
		});
	});
}

function add_account(plus) {
	var offset = 0;
	while ( $("input#ACCOUNT_ID_new_"+offset).length ) {
		offset += 1;
	}
	var recpart = "ACCOUNT_ID_new_"+offset;
	var recname = "LOGIN_new"+offset;

	$(plus).closest('li').before(
		$("<li/>").append(
			$("<a/>", { class: 'rmrow pendingadd'}),
			$("<input/>", {
				type: 'checkbox',
				class: 'irrelevant rmcollrow',
				name: 'Del_' + recpart,
			}),
			$("<input/>", {
				type: 'hidden',
				class: 'acaccountid',
				name: recpart,
				id: recpart
			}),
			$("<input/>", {
				class: 'acautocomplete',
				name: recname
			})
		)
	);
	configure_account_collection_autocomplete("input.acautocomplete");
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
	$('.acmanip').find('div#colbox').empty();

	// implements the add button on the dns value cell.
	$("ul.collectionbox").on('click', 'a.addacct', function(event) {
			return add_account(this);
	});

	$("ul.collectionbox").on('click', 'a.rmrow', function(event) {
		if( $(this).hasClass('pendingadd') ) {
			$(this).closest('li').remove();
		} else {
			$(this).closest('li').toggleClass('rmrow');
			$(this).closest('li').find('input.rmrow').prop(
				"checked", function (i, val) { return !val });
		}
	});


	$("div.collectionname").on('click', 'a.expandcollection', function(event) {
		expand_collection(event.target);
	});

	if( $('.coltypepicker').length == 0 ) {
		change_collection_select('div#collec_detail');
	}


});
