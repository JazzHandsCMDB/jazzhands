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

//
// $Id$
//
//
// adds a row before the row that contains 'button' based on the domain list
// in resp.  The rest of resp can be ignored.
//
function add_dns_ref_record_row(button, dnsrecid, resp) 
{
	var offset = 0;
	while ( $("input#dnsref_DNS_NAME_dnsref_"+dnsrecid+"_new_"+offset).length ) {
		offset += 1;
	}
	var recpart = "dnsref_"+dnsrecid+"_new_"+offset;
	var s = $("<select />", {
		name: 'dnsref_DNS_DOMAIN_ID_'+recpart,
		id: 'dnsref_DNS_DOMAIN_ID_'+recpart,
	});
	for(var field in resp['domains']['options']) {
		var o = $("<option/>",resp['domains']['options'][field]);
		$(s).append(o);
	}

	// this should possibly be pulled from json. maybe.
	// its redundant with backend code.
	var drop = $("<select/>", {
		name: 'dnsref_DNS_TYPE_'+recpart,
		id: 'dnsref_DNS_TYPE_'+recpart
	}).append(
		$("<option/>", { value: 'A', text: 'A'}),
		$("<option/>", { value: 'AAAA', text:'AAAA'}),
		$("<option/>", { value: 'CNAME', text: 'CNAME'})
	);

	$(button).closest('tr').before(
		$("<tr/>").append(
			$("<td>").append(
				$("<a/>", { class: 'purgerow'}).
					append( $("<img/>", {
						class: 'rmdnsrow button',
						src: '../stabcons/redx.jpg',
					}))
			),
			$("<td>").append(drop),
			$("<td>").append(
				$("<input/>", {
					id: 'dnsref_DNS_NAME_'+recpart,
					name: 'dnsref_DNS_NAME_'+recpart,
				})).append(s)
		)
	);
}

//
// dynamically builds a table for dns records that refer to a given record.
// There's perl code in the interface section that probably wants to do this
// too, possibly with an edit button, possibly not. XXX
// 
//
function build_dns_ref_table(cell, dnsrecid, resp)
{
	var tbl = $("<table/>", { class: 'dnsrefroot'} );
	for(var i in resp['records']) {
		var rec = resp['records'][i];

		var suffix = "_dnsref_" + dnsrecid + "_" + rec['dns_record_id'];

		var s = $('<select/>', { 
			class: 'off', 
			name: 'dnsref_DNS_TYPE' + suffix
		} );
		for(var j in resp['types']) {
			var rtype = resp['types'][j];
			var o = $('<option/>', { text: rtype });
			if(rec['dns_type'] == rtype) {
				$(o).attr('selected', true);
			}
			$(s).append(o);
		}

		var r = $('<tr/>', { class: 'dnsroot'} ).append( 
			$("<td>").append(
				$("<a/>", { class: 'rmrow'}).
					append( $("<img/>", {
						class: 'rmdnsrow button',
						src: '../stabcons/redx.jpg',
					})),
				$("<input/>", { 
					type: 'checkbox',
					class: 'irrelevant rmrow',
					name: 'Del_' + rec['dns_record_id'],
				})
			),
			$("<td/>").append(
				$(s)
			),
			$("<td/>").append( 
				$('<input/>', {
					type: 'text',
					class: 'irrelevant dnsname',
					name: 'dnsref_DNS_NAME'+ suffix,
					value: rec['dns_name']
				}),
				$('<select/>', {
					class: 'irrelevant dnsdomain',
					name: 'dnsref_DNS_DOMAIN_ID'+ suffix,
				}),

				$('<input/>', {
					type: 'hidden',
					class: 'dnsdomainid',
					// name: 'dnsref_DNS_DOMAIN_ID'+ suffix,
					value: rec['dns_domain_id'],
					disabled: true,
				}),

				$("<a>", {
						class: 'intdns',
						target: 'dns_record_id'+rec['dns_domain_id'],
						href: '../dns/?DNS_RECORD_ID='+rec['dns_record_id'],
					}).append( rec['dns_name']+'.'+rec['soa_name'] ),
				$("<img/>", {
					src: '../stabcons/e.png',
					alt: 'Edit',
					title: 'Edit',
					class: 'intdnsedit'
				})
			)
		);
		$(tbl).append(r);
	}

	$(tbl).append(
		$('<tr/>').append( $('<td/>', { colspan: 4 }).append(
			$('<a/>', {
					href: '#',
					class: 'dnsaddref'
				}).append(
				$('<img/>', {
					src: '../stabcons/plus.png',
					alt: 'Add',
					title: 'Add',
					class: 'plusbutton'
				}),
				$('<input/>', {
					type: 'hidden',
					class: 'dnsrecordid',
					value: dnsrecid,
					disabled: true,
				})
			)
		))
	);

	$(cell).append( tbl );
}

//
// makes a dns record editable.  This largely prepopulates the drop down
// selector for dns domains
//
function make_dns_editable(dnsroot, resp) {
		var s = $(dnsroot).find('select.dnsdomain');

		$(s).empty();
		for(var field in resp['domains']['options']) {
				var o = $("<option/>",resp['domains']['options'][field]);
				$(s).append(o);
		}

		$(dnsroot).find('a').addClass('irrelevant');
		$(dnsroot).find(':input').removeClass('off');
		$(dnsroot).find(':input').removeClass('irrelevant');
		$(dnsroot).find('input.dnsname').prop('disabled', false);

};

function build_dnsref_table (obj) {
	var id = $(obj).find(".dnsrecordid").attr('value');
	var url = 'json=yes;what=dnsref;DNS_RECORD_ID='+id;

	if(id == undefined) {
		alert("Danger!  Danger!  Unable to find DNS_RECORD_ID");
		return(0);
	}

	//
	// removing/adding class there until it can be turned to a
	// spinning wheel.
	//
	blt = $(obj).closest('td').find('div#dnsvalue_'+id);
	if (blt.length) {
		$(blt).toggleClass('irrelevant');
	} else {
		$(obj).removeClass('dnsref');
		$.getJSON('../dns/dns-ajax.pl', url, function (resp) {
			var div = $("<div/>", {
					class: 'dnsvalueref',
					id: 'dnsvalue_'+id
				}).append(
					"DNS Records that refer to this one"
				);
			build_dns_ref_table(div, id, resp);
			$(obj).closest('td').append(div);
			$(obj).addClass('dnsref');
		});
	}
	return(0);
}

function make_dnslink_editable(event) {
	var dnsroot = $(event.target).closest('.dnsroot');
	if ( $(dnsroot).length == 0) {
		alert("Unable to find dnsroot, seek help.");
		return(0);
	}
	var x = $(dnsroot).find('input.dnsdomainid');
	var id = $(dnsroot).find('input.dnsdomainid').attr('value');
	if ( id == undefined ) {
		alert("Unable to find dns domain, seek help.");
		return(0);
	}
	var url = 'json=yes;what=dnsref';
	url += ';DNS_DOMAIN_ID='+id;
	$.getJSON('../dns/dns-ajax.pl', url, function (resp) {
		make_dns_editable(dnsroot, resp);
		$(event.target).addClass('irrelevant');
	});
	return(0);
}

function add_dns_references(obj) {
	var dr = $(obj).find("input.dnsrecordid").attr('value');

	if(dr == undefined) {
		alert("Danger!  Danger!  Unable to find DNS_RECORD_ID");
		return(0);
	}

	url = 'json=yes;type=service;what=dnsref;DNS_RECORD_ID='+ dr;
	$.getJSON('../dns/dns-ajax.pl', url, function (resp) {
		add_dns_ref_record_row(obj, dr, resp);
	});
	return(0);
}

//
// sets up events for adding dns references to records.
//
function create_dns_reference_jquery(baseobj) {
	// This shows the CNAME/A record reference table.
	$(baseobj).on('click', 'a.dnsref', function(event) {
		return build_dnsref_table(this);
	});

	// this allows editing of the dns record and is largely used to
	// populate the domain drop down, which is prohibitive to prepopulate.
	//
	$(baseobj).on('click', 'img.intdnsedit', function(event) {
		return make_dnslink_editable(event);
	});

	// implements the add button on the dns value cell.
	$(baseobj).on('click', 'a.dnsaddref', function(event) {
		return add_dns_references(this);
	});

	$(baseobj).on('click', 'a.rmrow', function(event) {
		$(this).closest('tr').toggleClass('rowrm');
		$(this).closest('td').nextAll('td').toggleClass('pendingrm');
		$(this).closest('td').find('input.rmrow').prop(
			"checked", function (i, val) { return !val });
	});
	$(baseobj).on('click', 'a.purgerow', function(event) {
		var t = $(this).closest('table');
		$(this).closest('tr').remove();
		// does nothing for dns refernces.
		$(t).find('tr.dnsadd').each(
			function(i, v) {
				$(v).removeClass('odd');
				$(v).removeClass('even');
				$(v).addClass( i%2?'even':'odd');
		});
	});

}
