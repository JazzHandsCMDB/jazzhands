//
// $Id$
//

function AddIpSpace(thing, parent_tr_id, gapid)
{
	var tbl, ptr, gap, uniq;

	for(tbl = thing; tbl.parentNode != null;        tbl = tbl.parentNode) {
		if(tbl.tagName == 'TABLE') {
			break;
		}
	}

	ptr = document.getElementById(parent_tr_id);
	if(tbl) {

		uniq = 0;
		for(uniq = 0; ; uniq++) {
			var idname = "";
			idname = "newiptr_" + uniq;
			dropname = document.getElementById(idname);
			if(dropname == null) {
						break;
			}
		}

		newtr = tbl.insertRow(ptr.rowIndex);
		newtr.style.display = 'none';
		newtr.id = "newiptr_" + uniq;
		newtr.style.visibility = 'hidden';

		url = "../device/device-ajax.pl?what=IpRow;uniqid=" + uniq;
		ajaxrequest = createRequest();
		ajaxrequest.open("GET", url, true);
		ajaxrequest.onreadystatechange = function () {
			if(ajaxrequest.readyState == 4) {
				var htmlgoo = ajaxrequest.responseText;
				// swaparrows("cirExpand_" + circid, 'down');
				newtr.innerHTML = htmlgoo;
				newtr.style.display = '';
				newtr.style.visibility = 'visible';

				gap = document.getElementById(gapid);
				if(gap) {
					var x = gap.innerHTML;
					x--;
					if(x > 0) {
						gap.innerHTML = x;
					} else {
						ptr.style.visibility = 'hidden';
						ptr.style.display = 'none';
					}
				}
				jazzhands_common_init();
				configure_setupdns();
			}
		}
		ajaxrequest.send(null);
	}
}

function configure_setupdns() {
	// Put "set DNS" on reserved records without DNS set
	$("span.editdns").each( function ( index, el) {
		var text = $(el).html().trim();
		if(! text.length) {
			$(el).html("Setup DNS");
			$(el).addClass('hint');
		}
	});
}

//
// much of this probably wants to be shared
//
$(document).ready(function() {

	configure_setupdns();

	$("table.nblk_ipallocation").on('click', 'span.editdns', function(event) {

		var el = this;
		if( $(el).hasClass('hint')) {
			$(el).removeClass('hint');
			$(el).html('');
			// This case happens when it says 'set dns'.  In this case, user
			// has clicked on an empty field, and the span gets cleared and
			// replaced with a dns_value input box and a dns domain drop down
			var trid = $(el).parents("tr").first().attr('id');
			$.getJSON('../dns/dns-ajax.pl',
				'MIME_TYPE=json;what=domains;type=service',
				function (resp) {
					var name = $("<input/>", {
						name: 'DNS_RECORD_ID_' + trid,
						id: 'DNS_RECORD_ID_' + trid,
						type: 'text'
 					});
					var s = $("<select/>", {
						name: 'DNS_DOMAIN_ID_' + trid,
						type: "input",
						id: "DNS_DOMAIN_ID_" + trid
					});

					for(var field in resp['options']) {
						var o = $("<option/>", resp['options'][field]);
						$(s).append(o);
					}
					$(el).append(name);
					$(el).append(s);
					$(name).focus();
			});
		}
	});

	$('ul').on('click', 'a.netblkexpand', function(event) {
		event.stopImmediatePropagation();
		event.stopPropagation();
		event.preventDefault();
		var img = $(this).find('img');
		var src = $(img).attr('src');

		$(this).closest('ul').children('li').toggleClass('irrelevant');
		// $(this).closest('ul').children('li').toggleClass('irrelevant');
		// $(this).closest('ul').children('ul').first().toggleClass('irrelevant');
		if(src.match(/collapse/)) {
			swaparrows_jq(img, 'up');
		} else {
			swaparrows_jq(img, 'down');
		}
		return(0);
	});

	$('form').on('click', 'a.collapseall', function(event) {
		event.stopImmediatePropagation();
		event.stopPropagation();
		event.preventDefault();
		$(this).closest('form').find('ul.nbhier').children('li,ul').addClass('irrelevant');

		$(this).closest('form').find('img.netblkexpand').each(
			function(i, v) {
				swaparrows_jq(v, 'up');
			});
		return(0);
	});

	$('form').on('click', 'a.expandall', function(event) {
		event.stopImmediatePropagation();
		event.stopPropagation();
		event.preventDefault();
		$(this).closest('form').find('ul.nbhier').children('li,ul').removeClass('irrelevant');
		$(this).closest('form').find('img.netblkexpand').each(
			function(i, v) {
				swaparrows_jq(v, 'down');
			});
		return(0);
	});

});
