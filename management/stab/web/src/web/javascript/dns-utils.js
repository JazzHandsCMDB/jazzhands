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
 * Copyright (c) 2013, Todd M. Kover					     
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
function build_dns_drop(sel, detail, queryparams) {
	if(sel == null) {
		sel = document.createElement("select");
	}
	for(var field in detail) {
		$(sel).attr('name', field);
		$(sel).attr('id', field);
		$(sel).addClass('srvnum');
		$(sel).addClass('hint');
		for(var key in detail[field]) {
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
	return(sel);
}

//
// This deals with showing extra fields for SRV and MX records, and making
// them go away the class changes.  There is a lot of repetition, so
// it should probably be broken out into some supporting functions...
//
function change_dns_record(obj) {
	var prms = QsToObj();
	if(obj.value == 'SRV') {
		var name = document.getElementById('DNS_NAME');
		var value = document.getElementById('DNS_VALUE');
		var priority = document.getElementById('DNS_PRIORITY');
		var protocol = document.getElementById('DNS_SRV_PROTOCOL');
		var weight = document.getElementById('DNS_SRV_WEIGHT');
		var port = document.getElementById('DNS_SRV_PORT');

		if(weight) {
			$(priority).removeClass('irrelevant');
			$(protocol).removeClass('irrelevant');
			$(weight).removeClass('irrelevant');
			$(port).removeClass('irrelevant');
		} else {
			var protos = document.createElement("select");
			var services = document.createElement("select");
			$.getJSON('dns-ajax.pl',
				'what=Protocols',
				function(resp) {
					build_dns_drop(protos, resp, prms);
					$(protos).insertBefore(name);
			});

			$.getJSON('dns-ajax.pl',
				'what=Services',
				function(resp) {
					build_dns_drop(services, resp, prms);
					$(services).insertBefore(protos);
			});

			if(priority) {
				priority.style.visibility = 'visible';
			} else {
				// need to fetch from server...
				var box = document.createElement("input");
				$(box).attr('name', 'DNS_PRIORITY');
				$(box).attr('id', 'DNS_PRIORITY');
				$(box).addClass('srvnum');
				if( 'DNS_PRIORITY' in prms) {
					box.value = prms['DNS_PRIORITY'];
				} else {
					$(box).addClass('hint');
					box.value = 'pri';
				}
				$(box).insertBefore(value);
			}

			// need to fetch from server...
			var box = document.createElement("input");
			$(box).attr('name', 'DNS_SRV_WEIGHT');
			$(box).attr('id', 'DNS_SRV_WEIGHT');
			$(box).addClass('srvnum');
			if( 'DNS_SRV_WEIGHT' in prms) {
				box.value = prms['DNS_SRV_WEIGHT'];
			} else {
				$(box).addClass('hint');
				box.value = 'weight';
			}
			$(box).insertBefore(value);

			// need to fetch from server...
			var box = document.createElement("input");
			$(box).attr('name', 'DNS_SRV_PORT');
			$(box).attr('id', 'DNS_SRV_PORT');
			$(box).addClass('srvnum');
			if( 'DNS_SRV_PORT' in prms) {
				box.value = prms['DNS_SRV_PORT'];
			} else {
				$(box).addClass('hint');
				box.value = 'port';
			}
			$(box).insertBefore(value);

		}
	} else if(obj.value == 'MX') {
		var priority = document.getElementById('DNS_PRIORITY');
		if(priority)  {
			$(priority).removeClass('irrelevant');
		} else {
			var value = document.getElementById('DNS_VALUE');
			// need to fetch from server...
			var box = document.createElement("input");
			$(box).attr('name', 'DNS_PRIORITY');
			$(box).attr('id', 'DNS_PRIORITY');
			$(box).addClass('srvnum');
			if( 'DNS_PRIORITY' in prms) {
				box.value = prms['DNS_PRIORITY'];
			} else {
				$(box).addClass('hint');
				box.value = 'priority';
			}
			$(box).insertBefore(value);
		}
		var protocol = document.getElementById('DNS_SRV_PROTOCOL');
		var weight = document.getElementById('DNS_SRV_WEIGHT');
		var port = document.getElementById('DNS_SRV_PORT');
		var service = document.getElementById('DNS_SRV_SERVICE');
		if(weight) {
			$(protocol).addClass('irrelevant');
			$(weight).addClass('irrelevant');
			$(port).addClass('irrelevant');
			$(service).addClass('irrelevant');
		}
	} else {
		var priority = document.getElementById('DNS_PRIORITY');
		var protocol = document.getElementById('DNS_SRV_PROTOCOL');
		var weight = document.getElementById('DNS_SRV_WEIGHT');
		var service = document.getElementById('DNS_SRV_SERVICE');
		var port = document.getElementById('DNS_SRV_PORT');
		if(weight) {
			$(protocol).addClass('irrelevant');
			$(weight).addClass('irrelevant');
			$(port).addClass('irrelevant');
			$(service).addClass('irrelevant');
		}
		if(priority) {
			$(priority).addClass('irrelevant');
		}
	}
}

$(document).ready(function(){
	$("select.dnstype").change(
		function(event) {
			change_dns_record(event.target);
		}
	);
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
});
