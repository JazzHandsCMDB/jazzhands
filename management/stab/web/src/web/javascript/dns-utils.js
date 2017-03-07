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
 *
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
// converts the query string to a
function QsToObj() {
    var vars = window.location.search.substring(1).split(';');
	var rv = new Array();
    for (var i = 0; i < vars.length; i++) {
	var pair = vars[i].split('=');
		if(pair.length == 2) {
			rv[ pair[0] ] = decodeURIComponent(pair[1]);
		}
    }
    return rv;
}

//
// makes an object visible
//
function show_soa(switchid, tableid)
{
	var s, t
	s = document.getElementById(switchid);
	t  = document.getElementById(tableid);

	if(s != null && t != null) {
		s.style.visibility = 'hidden';
		s.style.display = 'none';

		t.style.visibility = 'visible';
		t.style.display = '';
	}
}

function dns_show_approles(button)
{
	var div;
	div = document.getElementById("approle_div");
	if(!div) {
		return;
	}

	if(div.style.display == 'none') {
		button.innerHTML = "Hide AppRoles";
		div.style.display = '';
	} else {
		button.innerHTML = "Show AppRoles";
		div.style.display = 'none';
	}
}

function dns_debug_addns(button)
{
	var ns, br;

	ns = document.createElement('input');
	ns.name = 'extra_ns';
	ns.type = 'text';
	button.parentNode.appendChild(ns);

	br = document.createElement('br');
	button.parentNode.appendChild(br);
}


//
//  builds a drop down based on what was fetched from an ajax server.
// Optionally takes a hash at the end that contains possible defaults
//
function build_dns_drop(in_sel, detail, queryparams, id, prefix) {
	var sel = in_sel;
	if(in_sel == null) {
		sel = $('<select/>');
	}
	for(var field in detail) {
		var f = field;
		if(id) {
			f += "_" + id;
		}
		if(prefix) {
			f = prefix + "_" + f;
		}
		$(sel).attr('name', f);
		$(sel).attr('id', f);
		$(sel).addClass('srvnum');
		$(sel).addClass('hint');
		for(var key in detail[field]) {
			var val = (detail[field][key] == null)?key:detail[field][key];
			var o = $('<option/>', {
				text: key,
				value: val
			});
			if(queryparams != null && field in queryparams) {
				if(queryparams[field] == val) {
					$(o).attr('selected', true);
				}
			}
			$(sel).append(o);
		}
	}
	return(sel);
}

//
//  builds a drop down based on what was fetched from an ajax server.
// Optionally takes a hash at the end that contains possible defaults
//
function wtf_build_dns_drop(sel, detail, queryparams) {
	if(sel == null) {
		sel = document.createElement("select");
	}
	$(detail).each(function(index, in_elem) {
		for(var field in in_elem) {
			$(sel).addClass('srvnum');
			$(sel).addClass('hint');
			for(var in_key in detail[field]) {
				var key = $(in_key).get();
				var val = (detail[field][key] == null)?key:detail[field][key];
				var o = new Option(key, val);
				if(queryparams != null && field in queryparams) {
					if(queryparams[field] == val) {
						$(o).attr('selected', true);
					}
				}
				sel.add(o);
			}
		}
	});
	return(sel);
}

//
// This deals with showing extra fields for SRV and MX records, and making
// them go away the class changes.  There is a lot of repetition, so
// it should probably be broken out into some supporting functions...
//
function change_dns_record(obj) {
	var prms = QsToObj();
	var nametr = $(obj).closest('tr').first();
	var nametd = $(obj).closest('tr').find('td.DNS_NAME');

	// deal with showing/hiding the PTR box for A records
	if(obj.value == 'A' || obj.value == 'AAAA') {
		var x = $(obj).closest('tr').find('.ptrbox').first();
		if(! x.length ) {
			var newname = 'chk_SHOULD_GENERATE_PTR';
			if($(nametr).hasClass('dnsadd')) {
				newname = "new_" + newname + "_" + $(nametr).attr('id');
			} else {
				newname += "_" + $(nametr).attr('id');
			}
			var ck = document.createElement('input');
			$(ck).attr('class', 'ptrbox');
			$(ck).attr('type', 'checkbox');
			$(ck).attr('name', newname);
			$(ck).attr('id', newname);
			$(ck).addClass('srvnum');
			$(obj).closest('tr').find('.ptrtd').first().append(ck);
		} else {
			$(x).removeClass('irrelevant');
		}
	} else {
		$(obj).closest('tr').find('.ptrbox').addClass('irrelevant');
	}

	if($(nametr).hasClass('dnsadd')) {
		prefix = 'new';
		plusprefix = 'new_';
	} else {
		prefix = '';
		plusprefix = '';
	}

	var value = $(obj).closest('tr').find('input[name*="DNS_VALUE"]');
	if(obj.value == 'SRV' || obj.value == 'MX') {
		if(priority && $(priority).is("input") )  {
			$(priority).removeClass('irrelevant');
		} else {
			// need to fetch from server...
			var box = $("<input />", {
				name: plusprefix + 'DNS_PRIORITY' + "_" + $(nametr).attr('id'),
				id: plusprefix + 'DNS_PRIORITY' + "_" + $(nametr).attr('id'),
				"class": 'srvnum'
			});
			if( 'DNS_PRIORITY' in prms) {
				box.value = prms['DNS_PRIORITY'];
			} else {
				$(box).addClass('hint');
				$(box).val('pri');
			}
			$(box).insertBefore(value);
		}
	}

	if(obj.value == 'SRV') {
		var name = $(obj).closest('tr').find('input[name*="DNS_NAME"]');
		var priority = $(obj).closest('tr').find('input[name*="DNS_PRIORITY"]');
		var protocol = $(obj).closest('tr').find('select[name*="DNS_SRV_PROTOCOL"]');
		var weight = $(obj).closest('tr').find('input[name*="DNS_SRV_WEIGHT"]');
		var port = $(obj).closest('tr').find('input[name*="DNS_SRV_PORT"]');
		var svc = $(obj).closest('tr').find('select[name*="DNS_SRV_SERVICE"]');
		var ttl = $(obj).closest('tr').find('input[name*="DNS_TTL"]');

		if(svc && $(svc).is("input") )  {
			$(priority).removeClass('irrelevant');
			$(protocol).removeClass('irrelevant');
			$(weight).removeClass('irrelevant');
			$(port).removeClass('irrelevant');
			$(svc).removeClass('irrelevant');
		} else {
			var protos = $('<select/>');
			var services = $('<select/>');

			$.getJSON('dns-ajax.pl',
				'what=Protocols',
				function(resp) {
					build_dns_drop(protos, resp, prms, $(nametr).attr('id'), prefix);
					$(protos).prependTo(nametd);
			});

			$.getJSON('dns-ajax.pl',
				'what=Services',
				function(resp) {
					build_dns_drop(services, resp, prms, $(nametr).attr('id'), prefix);
					$(services).insertBefore(protos);
			});

			// need to fetch from server...
			var box = $("<input />", {
				name: plusprefix + 'DNS_SRV_WEIGHT' + "_" + $(nametr).attr('id'),
				id: plusprefix + 'DNS_SRV_WEIGHT' + "_" + $(nametr).attr('id'),
				"class": 'srvnum'
			});
			if( 'DNS_SRV_WEIGHT' in prms) {
				box.value = prms['DNS_SRV_WEIGHT'];
			} else {
				$(box).addClass('hint');
				box.value = 'weight';
			}
			$(box).insertBefore(value);
			var box = $("<input />", {
				name: plusprefix + 'DNS_SRV_PORT' + "_" + $(nametr).attr('id'),
				id: plusprefix + 'DNS_SRV_PORT' + "_" + $(nametr).attr('id'),
				"class": 'srvnum'
			});
			if( 'DNS_SRV_PORT' in prms) {
				box.value = prms['DNS_SRV_PORT'];
			} else {
				$(box).addClass('hint');
				box.value = 'port';
			}
			$(box).insertBefore(value);

		}
	} else if(obj.value == 'MX') {
		protocol = $(obj).closest('tr').find('select[name*="DNS_SRV_PROTOCOL"]').addClass("irrelevant");
		weight = $(obj).closest('tr').find('input[name*="DNS_SRV_WEIGHT"]').addClass("irrelevant");
		port = $(obj).closest('tr').find('input[name*="DNS_SRV_PORT"]').addClass("irrelevant");
		service = $(obj).closest('tr').find('select[name*="DNS_SRV_SERVICE"]').addClass("irrelevant");
	} else {
		priority = $(obj).closest('tr').find('input[name*="DNS_PRIORITY"]').addClass("irrelevant");;
		protocol = $(obj).closest('tr').find('select[name*="DNS_SRV_PROTOCOL"]').addClass("irrelevant");;
		weight = $(obj).closest('tr').find('input[name*="DNS_SRV_WEIGHT"]').addClass("irrelevant");;
		service = $(obj).closest('tr').find('select[name*="DNS_SRV_SERVICE"]').addClass("irrelevant");;
		port = $(obj).closest('tr').find('input[name*="DNS_SRV_PORT"]').addClass("irrelevant");;
	}
}


function add_new_dns_row(button, resp) {
	var offset = 1;
	while ( $("input#new_DNS_NAME_"+offset).length ) {
		offset += 1;
	}

	var types = $("<select />", {
		name: 'new_DNS_TYPE_'+offset,
		id: 'new_DNS_TYPE_'+offset,
		class: 'dnstype',
	});
	for(var field in resp['types']) {
		var o = $("<option/>",resp['types'][field]);
		$(types).append(o);
	}

	var classes = $("<select />", {
		name: 'new_DNS_CLASS_'+offset,
		id: 'new_DNS_CLASS_'+offset,
		class: 'dnsclass',
	});
	for(var field in resp['classes']) {
		var o = $("<option/>",resp['classes'][field]);
		$(classes).append(o);
	}

	var myclass ='dnsrecord dnsadd';
	if(offset % 2) {
		myclass += ' even';
	} else {
		myclass += ' odd';
	}

	$(button).closest('tr').after(
		$("<tr/>", {class: myclass}).append(
			$("<td>").append(
				$("<a/>", { class: 'purgerow'}).
					append( $("<img/>", {
						class: 'rmdnsrow button',
						src: '../stabcons/redx.jpg',
					})),
				$("<input/>", {
					type: 'checkbox',
					name: 'new_IS_ENABLED_'+offset,
					checked: true,
				})
			),
			$("<td>", { class: 'DNS_NAME' } ).append(
				$("<input/>", {
					type: 'text',
					name: 'new_DNS_NAME_'+offset,
					id: 'new_DNS_NAME_'+offset,
					class: 'dnsname',
				})
			),
			$("<td>").append(
				$("<input/>", {
					type: 'text',
					name: 'new_DNS_TTL'+offset,
					id: 'new_DNS_TTL'+offset,
					class: 'dnsttl off',
				}),
				$("<a/>", {
					href: '#',
					class: 'stabeditbutton'
				}).append(
					$("<img/>", {
						// class: 'stabeditbutton',
						src: '../stabcons/e.png',
						title: 'Edit'
					})
			)),
			$("<td>").append(classes),
			$("<td>").append(types),
			$("<td>").append(
				$("<input/>", {
					type: 'text',
					name: 'new_DNS_VALUE_'+offset,
					id: 'new_DNS_VALUE_'+offset,
				})
			),
			$("<td>").append(
				$("<input/>", {
					type: 'checkbox',
					name: 'new_SHOULD_GENERATE_PTR_'+offset,
					class: 'ptrbox irrelevant'
				})
			)
		)
	);

}

$(document).ready(function(){
	$("table.dnstable").on('change', "select.dnstype", function(event) {
		change_dns_record(event.target);
	});
	// If this was a reload, its possible for this object to be set to
	// SRV or MX, in which case, those fields should be expanded.
	var s = document.getElementById("DNS_TYPE");
	if($(s).val() == 'SRV' || $(s).val() == 'MX') {
		change_dns_record(s);
	}

	// this causes the grey'd out hint to go away
	$("table").on('focus', ".hint", function(event) {
		$(event.target).removeClass('hint');
		event.target.preservedHint = $(event.target).val();
		$(event.target).val('');
	});
	// this causes the grey'd out hint to come backw ith an empty field
	$("table").on('blur', ".srvnum", function(event) {
		if( $(event.target).val() == '' && event.target.preservedHint ) {
			$(event.target).addClass('hint');
			$(event.target).val( event.target.preservedHint );
		}
	});

	// this causes the EDIT button to show up where needed
	$("table.dnstable").on('click', "a.stabeditbutton", function(event) {
		toggleon_text(event.target);
	});

	// this causes a new dns record button to show up where needed.
	$("table.dnstable").on('click', 'a.adddnsrec', function(event) {
		url = 'json=yes;what=dnsaddrow';
		$.getJSON('dns-ajax.pl', url, function (resp) {
			add_new_dns_row(event.target, resp);
		});
		return(0);
	});

	// This handles making cnames destinations auto complete to othe		// records, if appropriate
	$('input.dnscname').autocomplete({
		noCache: false,
		deferRequestBy: 250,
		serviceUrl: 'dns-ajax.pl?what=cname-complete;',
		onSelect: function (suggestion) {
			alert('You selected: ' + suggestion.value + ', ' + suggestion.data);
		},
		beforeRender: function(container, suggestions) {
			// just used to clear the dns value record.
		}
	});


	create_dns_reference_jquery("table.dnstable");

});
