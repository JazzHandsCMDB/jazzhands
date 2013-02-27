var search_timer = null;
function process_search(searchbox) {
	var find = $(searchbox).val();
	// XXX - need to process errors, do a full search for that too
	// need to actually process

	// in any case, clear the timer
	if(search_timer) {
		window.clearTimeout( search_timer );
		search_timer = null;
	}

	// if nothing is in there, clear the underlying box immediately
	if(!find || find == "") {
		var results = $('#resultsbox');
		$(results).empty();
	} else {
		// wait a bit for more characters, then go for box completion.
		search_timer = window.setTimeout( function() {
			var results = $('#resultsbox');
			$(results).empty();
			$.getJSON('ajax/search.pl', "find="+find,
				function(resp) {
					var t = document.createElement('table');
					if(resp['type'] == 'person') {
						if(resp['people']) {
							for(var i = 0; i < resp['people'].length; i++) {
								var dude = resp['people'][i];
								var tr = document.createElement("tr");
								// show their picture if we have it
								var td = document.createElement("td");
								if(dude['img']) {
									var pic = document.createElement('img');
									pic.src = dude['img'];
									pic.setAttribute("class", "thumb");
									pic.setAttribute("alt", "pic");
									td.appendChild(pic);
								}
								tr.appendChild(td);
								// link to the person
								td = document.createElement("td");
								var a = document.createElement("a");
								a.href = dude['link'];
								$(a).text(dude['name']);
								td.appendChild(a);
								tr.appendChild(td);

								// show the person's office location 
								td = document.createElement("td");
								if(dude['location'] != null) {
									td.innerHTML = dude['location'];
								} else {
									td.innerHTML = "";
								}
								tr.appendChild(td);

								t.appendChild(tr);
							}
						} else {
							// not found
							var tr = document.createElement("tr");
							var td = document.createElement("td");
							td.innerHTML = "No Matches Found";
							tr.appendChild(td);
							t.appendChild(tr);
						}
						$(results).append(t);
					}
				}
			).error(function() {
				alert("There was an issue completing the search.  Try reloading the directory.");
			});
		}, 200);
	}
}

function build_option(newid, in_list, val) {
	var s, o;

	s = document.createElement("select");
	// s.setAttribute("id", newid);
	$(s).attr("name", newid);

	for(var i = 0; i < in_list.length; i++) {
		// test with IE and perhaps older IE before removing.
		// o = document.createElement("option");
		// o.text = in_list[i];
		// o.value = in_list[i];
		if($.isArray(in_list[i])) {
			o = new Option(in_list[i][1], in_list[i][0]);
			if (in_list[i][0] == val) {
				$(o).attr('selected', true);
			}
		} else {
			o = new Option(in_list[i], in_list[i]);
			if (in_list[i] == val) {
				$(o).attr('selected', true);
			}
		}
		s.add(o);
	}
	return s;
}

function remove_phone(remove_button) {
	var form = $(remove_button).closest('form');

	// only necessary on new phones
	$("#addphonehint").addClass("hintoff");

	if(confirm("Are you sure you want to remove this phone?")) {
		// post results, and in the results, we'll remove
		// and replace with a proper row
		var s = $(form).serialize();
		$.post('ajax/remove_number.pl', s, function(resp) {
			if(resp['error']) {
				x = $(form).find('div.msg').text(resp['error']);
			} else {
				$(form).closest('tr').remove();
			}
		}).error(function() {
			alert("There was an issue submitting your request.  Please try again later");
		});;
	}
}

function update_location(button) {
	var tbl = $(button).closest('TABLE');

	// get person_id from the uri args to pass through as a hidden
	// element
	var r = new RegExp('[\\?&;]person_id=([^&#;]*)');
	var rr = r.exec(window.location.href); 
	var personid;
	if(rr) {
		personid = decodeURIComponent(rr[1]);
	}
	$.getJSON('ajax/location.pl','person_id='+personid,
		function(resp) {
			$('#locationmanip').toggle(1);
			$('#locationmanip').empty();

			var form = document.createElement("FORM");
			form.action = 'ajax/location.pl';
			$(form).attr('method', 'POST');
			$(form).attr('enctype','multipart/form-data');
			var tbl = document.createElement("TABLE");
			tbl.setAttribute('class', "locationmanip"); 

			var input = document.createElement("input");
			$(input).attr('type', 'hidden');
			$(input).attr('name', 'person_id');
			$(input).attr('value', resp['record']['person_id']);
			$(form).append(input);

			input = document.createElement("input");
			$(input).attr('type', 'hidden');
			$(input).attr('name', 'person_location_id');
			$(input).attr('value', resp['record']['person_location_id']);
			$(form).append(input);
		
			var tr = document.createElement("tr");
			var td = document.createElement("td");
			td.innerHTML = "Location";
			$(tr).append(td);
			td = document.createElement("td");
			td.innerHTML = resp['record']['display_label'];
			$(tr).append(td);
			$(tbl).append(tr);


			var a = [ 'building', 'floor', 'section', 'seat_number'];
			for ( var idx in a) {
				var col = a[idx];
				tr = document.createElement("tr");
				td = document.createElement("td");
				td.innerHTML = col;
				$(tr).append(td);

				td = document.createElement("td");
				input = document.createElement("input");
				$(input).attr('name', col + '_' + resp['record']['person_location_id']);
				$(input).val( resp['record'][col] );
				$(td).append(input);
				$(tr).append(td);
				$(tbl).append(tr);
			}

			// submit button
			tr = document.createElement("tr");
			td = document.createElement("td");
			td.colSpan = 2;

			input = document.createElement("input");
			$(input).attr('type','submit');
			$(input).addClass('abutton');
			$(input).val('Submit');
			$(td).append(input);

			var close = document.createElement("input");
			$(close).attr('type', 'submit');
			$(close).addClass('abutton');
			$(close).click(function() {
				$('#locationmanip').toggle(0);
				$('#locationmanip').empty();
			});
			close.href = "#";
			$(close).val("Cancel");
			$(td).append(close);

			$(tr).append(td);
			$(tbl).append(tr);

			// set onclick to submit and make popup go away
			$(form).submit(
				function() {
					s = $(form).serialize();
					$.post('ajax/location.pl', s, function(resp) {
						$('#locationmanip').toggle(1);
						$('#locationmanip').empty();
					}).error(function() {
						alert("There was an issue submitting your request.  Please try again later");
					});;
					return(false);
				}
			);

			$(form).append(tbl);
			$('#locationmanip').append(form);
		}
	).error(function() {
		alert("There was an issue downloading location information.    Please reload the page or try later.");
	});
	return 0;
}

function manip_phone(add_button) {
	var tbl = $(add_button).closest('TABLE');
	var id = $(add_button).attr('id');
	var swaptr;

	if(id) {
		swaptr = $(add_button).closest('TR');
		// $(tr).empty();
		id = "&"+id;
	} else {
		id="";
	}
	$.getJSON('ajax/contact.pl',
		"type=phone"+id,
		function(resp) {
			var contact = (resp['contact'])?resp['contact']:null;
			var tr = document.createElement("tr");
			var td = document.createElement("td");
			td.colSpan = 2;

			var form = document.createElement("form");
			form.setAttribute("class", "addphone");

			lhs = document.createElement("div");
			lhs.setAttribute("class", "phoneattribs");

			// get person_id from the uri args to pass through as a hidden
			// element
			var r = new RegExp('[\\?&;]person_id=([^&#;]*)');
			var rr = r.exec(window.location.href); 
			var personid;
			if(rr) {
				personid = decodeURIComponent(rr[1]);
			}

			var input = document.createElement("input");
			input.setAttribute('type', "hidden");
			input.setAttribute('name', "person_id");
			input.setAttribute('value', personid);
			lhs.appendChild(input);

			if(contact) {
				input = document.createElement("input");
				input.setAttribute('type', "hidden");
				input.setAttribute('name', "person_contact_id");
				input.setAttribute('value', contact['person_contact_id']);
				lhs.appendChild(input);
			}

			var s = build_option("locations", resp['locations'], (contact)?contact['person_contact_location_type']:null);
			lhs.appendChild(s);

			s = build_option('technology', resp['technologies'], (contact)?contact['person_contact_technology']:null);
			lhs.appendChild(s);

			s = build_option('privacy', resp['privacy'], (contact)?contact['person_contact_privacy']:null );
			lhs.appendChild(s);

			form.appendChild(lhs);

			var rhs = document.createElement("div");
			rhs.setAttribute("class", "phonedigits");

			s = build_option('country', resp['countries'], (contact)?contact['iso_country_code']:null);
			rhs.appendChild(s);

			input = document.createElement("input");
			$(input).addClass("hinted");
			input.setAttribute("id", "phone");
			input.setAttribute("name", "phone");
			input.setAttribute("size", "15");
			if(contact) {
				$(input).val( contact['phone_number'] );
			}
			if( $(input).val() == '') {
				$(input).addClass("inputhint");
				input.setAttribute("value", "phone");
			}
			rhs.appendChild(input);

			input = document.createElement("input");
			$(input).addClass("hinted");
			input.setAttribute("id", "phone_extension");
			input.setAttribute("name", "phone_extension");
			input.setAttribute("size", "5");
			if(contact && contact['phone_extension']) {
				$(input).val( contact['phone_extension'] );
			}
			if( $(input).val() == '') {
				$(input).addClass("inputhint");
				input.setAttribute("value", "ext");
			}
			rhs.appendChild(input);

			input = document.createElement("input");
			$(input).addClass("hinted");
			input.setAttribute("id", "pin");
			input.setAttribute("name", "pin");
			input.setAttribute("size", "5");
			if(contact && contact['phone_pin']) {
				$(input).val( contact['phone_pin'] );
			}
			if( $(input).val() == '') {
				$(input).addClass("inputhint");
				input.setAttribute("value", "pin");
			}
			rhs.appendChild(input);

			var msg = document.createElement("div");
			msg.setAttribute("class", "msg");
			rhs.appendChild(msg);

			var submit = document.createElement("a");
			submit.href = "#";
			submit.innerHTML = "SUBMIT";
			submit.setAttribute("class", "sbmtphone");
			rhs.appendChild(submit);

			var cancel = document.createElement("a");
			cancel.href = "#";
			cancel.innerHTML = "CANCEL";
			cancel.setAttribute("class", "cancelphone");
			rhs.appendChild(cancel);

			form.appendChild(rhs);

			td.appendChild(form);
			tr.appendChild(td);
			if(swaptr) {
				$(swaptr).after(tr);
				$(swaptr).addClass('hide');
			} else {
				$('tr#add_phones').before(tr);
			}
	

			var position = $(tr).offset();
			position.left += $(tr).width();
			$("#addphonehint").removeClass("hintoff");
			$("#addphonehint").offset({left: 0, top: 0});
			$("#addphonehint").offset( position);

		}
	).error(function() {
		alert("There was an issue downloading contact information.    Please reload the page or try later.");
	});
	return 0;
}

function enforce_select_is_multivalue(in_class, my_item, valid) {
	in_class = '.'+in_class;

	// iterate over all the items selected and check all the other selects
	// to see if they are set.  If the person_usage type has 
	// is_multivalue set
	// to 'N', then clear all the others out.
	$(in_class).filter("[name="+my_item+']').children().filter('option:selected').each(function() {
		// checkit == select that is being checked.
		// myusg == selected option that is being checked.
		var checkit = $(this).closest('select').attr('name');
		var myusg = $(this).text();
		for(i = 0; i < valid.length; i++) {
			if(valid[i]['person_image_usage'] == myusg) {
				if(valid[i]['is_multivalue'] == 'N') {
					$('.person_image_usage').not('[name='+checkit+']').children().filter("option:selected").each(function() {
						if($(this).text() == myusg) {
							$(this).removeAttr("selected");
						}
						
					});
				}

			}
		}
	});
}

var pic_offset = 0;
function pic_manip(person_id) {
	$.getJSON('ajax/ajax-pics.pl',
		"person_id=" + person_id,
		function(resp) {
			$('#picsdisplay').toggle(1);
			$('#picsdisplay').empty();

			var addtr;

			var form = document.createElement("FORM");
			form.action = 'ajax/pic-manip.pl';
			$(form).attr('method', 'POST');
			$(form).attr('enctype','multipart/form-data');
			var t = document.createElement("TABLE");
			t.setAttribute('class', "picmanip");

			var input = document.createElement("input");
			$(input).attr('type', 'hidden');
			$(input).attr('name', 'person_id');
			$(input).attr('value', person_id);
			$(form).append(input);

			for(var i = 0; 
					typeof(resp['pics']) != 'undefined' && 
					 i < resp['pics'].length; i++) {
				var imgid = resp['pics'][i]['person_image_id'];
				var tr = document.createElement("tr");
				var td = document.createElement("td");
				var img = document.createElement("img");
				img.setAttribute("class", "fullsize");
				img.src = "picture.php?person_id="+person_id+"&person_image_id="+ imgid + "&type=contact";
				$(td).append(img);
				$(tr).append(td);

				input = document.createElement("input");
				$(input).attr('type', "textarea");
				$(input).attr('name', "description_" + imgid);
				$(input).val( resp['pics'][i]['description'] );
				// wtf?
				input.rows = 10;
				// $(input).attr('rows', 10);

				td = document.createElement("td");
				$(td).append(input);
				$(tr).append(td);

				td = document.createElement("td");
				s = document.createElement("select");
				// build_options does not work due to the way that
				// person_image_usage works
				$(s).attr('multiple', 'multiple');
				var selid = 'person_image_usage_' + imgid;
				$(s).attr('name', selid);
				$(s).attr('class', "person_image_usage");
				$(s).change(function() { 
					enforce_select_is_multivalue('person_image_usage', $(this).attr('name'), resp['valid_usage']); 
				});
				for(var j = 0; j < resp['valid_usage'].length; j++) {
					var x = resp['valid_usage'][j]['person_image_usage'];
					var o = new Option(x, x);
					if( jQuery.inArray(x, 
							resp['pics'][i]['person_image_usage']) >= 0) {
						o.selected = true;
					}
					s.add(o);
				}
				$(td).append(s);
				$(tr).append(td);

				$(t).append(tr);
			}

			tr = document.createElement("tr");
			td = document.createElement("td");
			td.colSpan = 3;
			var a = document.createElement("a");
			a.href = '#';
			$(a).text('ADD');

			addtr = tr;	// insert before in the click function
			$(a).click(function() {
				var tr = document.createElement("tr");
				// global variable offset feels wrong, but...
				var td = document.createElement("td");
				var input = document.createElement("input");
				$(input).attr('type', 'file');
				$(input).attr('name', 'newpic_file_'+pic_offset);
				$(td).append(input);
				$(tr).append(td);

				td = document.createElement("td");
				input = document.createElement("input");
				$(input).attr('type', "textarea");
				$(input).attr('name', 'new_description_'+pic_offset);
				$(td).append(input);
				$(tr).append(td);

				td = document.createElement("td");
				s = document.createElement("select");
				$(s).attr('multiple', 'multiple');
				var selid = 'new_person_image_usage_' + pic_offset;
				$(s).attr('name', selid);
				$(s).attr('class', "person_image_usage");
				$(s).change(function() { 
					enforce_select_is_multivalue('person_image_usage', $(this).attr('name'), resp['valid_usage']); 
				});
				for(var j = 0; j < resp['valid_usage'].length; j++) {
					var x = resp['valid_usage'][j]['person_image_usage'];
					var o = new Option(x, x);
					s.add(o);
				}
				$(td).append(s);
				$(tr).append(td);

				pic_offset++;
				$(addtr).before(tr);
			});

			$(td).append(a);
			$(tr).append(td);
			$(t).append(tr);

			// submit button
			tr = document.createElement("tr");
			td = document.createElement("td");
			td.colSpan = 3;
			input = document.createElement("input");
			$(input).addClass('abutton');
			$(input).attr('type','submit');
			$(input).val('Submit');
			$(td).append(input);

			var close = document.createElement("input");
			$(close).click(function() {
				$('#picsdisplay').toggle(0);
				$('#picsdisplay').empty();
			});
			close.href = "#";
			$(close).addClass('abutton');
			$(close).val('Cancel');
			$(td).append(close);

			$(tr).append(td);
			$(t).append(tr);

			$(form).append(t);
			$('#picsdisplay').append(form);

			var d = document.createElement("div");
			d.innerHTML = "The caption is used in yearbook photos and is otherwise unused.  The type marked as corpdirectory is used by this directory.  Headshots are professional photographs that are not, at present, in use.  ";
			$('#picsdisplay').append(d);

		}).error(function() {
			alert("There was an issue downloading picture information.    Please reload the page or try later.");
		});
}

/*
        $r->{record}->{person_contact_id} = $pimgid;
        $r->{record}->{technology} = $tech;
        $r->{record}->{country} = $cc;
        $r->{record}->{phone} = $phone;
        $r->{record}->{pin} = $pin;
        $r->{record}->{privacy} = $privacy;
 */

$(document).ready(function(){
	// do not let the search for actually submit.
	$("#search").submit( function(event) { return false; } );

	// binding to click does not work on dynamic elements 
	$("input#searchfor").keyup( 
	 		function(event){
				process_search($(this))
			}
	);

	// prevent submit button from working
	$("input#searchfor").keydown( 
	 		function(event){
				if(event.which == 13)
					return false;
			}
	);

	$("a.cancelphone").live('click', function(event) {
		$("#addphonehint").addClass("hintoff");
		$(this).closest('tr').prev().removeClass('hide');
		$(this).closest('tr').remove();
	});

	$("a.sbmtphone").live('click', function(event){
		$("#addphonehint").addClass("hintoff");
		var form = $(this).closest('form');
		if(form) {

			s = $(form).serialize();

			// post results, and in the results, we'll remove
			// and replace with a proper row
			$.post('ajax/manip_number.pl', s, function(resp, textStatus, jqXHR) {
				if(resp['error']) {
					x = $(form).find('div.msg').text(resp['error']);
				} else {
					// if there is already a row for this contactid,
					// that means this was an edit, so the old row should
					// go away.
					var trid = 'contact'+resp['record']['person_contact_id'];
					$('tr#'+trid).remove();
					var tr = $(form).closest('tr');
					$(tr).empty();
					$(tr).attr('id', trid);

					var td = document.createElement("td");
					var newform = document.createElement("form");

					$(newform).addClass('phonerowform');

					var hidden = document.createElement("input");
					hidden.setAttribute("type", "hidden");
					hidden.setAttribute("name", "person_contact_id");
					hidden.setAttribute("value", resp['record']['person_contact_id']);
					newform.appendChild(hidden);

					var pic = document.createElement("img");
					pic.setAttribute("class", "removex");
					pic.src = "images/Octagon_delete.svg";
					pic.setAttribute("alt", "X");
					var a = document.createElement("a");
					a.href = "#"
					a.setAttribute("class", "remove_phone");
					a.appendChild(pic);
					$(newform).append(a);
					$(newform).append( resp['record']['print_title']+':' );

					$(td).append(newform);
					$(tr).append(td);

					td = document.createElement("td");
					var span = document.createElement("span");
					$(span).addClass('phoneno');
					$(span).attr('id', 'PHONE_CONTACT_ID='+resp['record']['person_contact_id']);
					$(span).text( resp['record']['print_number'] );
					$(td).append(span);
					$(tr).append(td);
				}
			}).error(function() {
				alert("There was an issue submitting your request.  Please try again later");
			});;
		}
	});

	$("a.remove_phone").live('click',function(event){
		remove_phone($(this));});

	$("a.addphonebutton").live('click',function(event){
		manip_phone($(this));});

	$("a.locationmanipbutton").live('click',function(event){
		update_location($(this));});

	// remove the greyed out hint that was there
	$("input.inputhint").live('focus',function(event){
		$(this).removeClass("inputhint");
		this.preservedHint = $(this).val();
		$(this).val("");
	});

	// remove the greyed out hint that was there
	$("input.hinted").live('blur',function(event){
		if( $(this).val() == '' && this.preservedHint ) {
			$(this).addClass('inputhint');
			$(this).val( event.target.preservedHint );
		}
	});

	$('.editbuttons').mouseenter(function(event) {
		var position = $('tr.editbuttons').offset();
		var height=  $('tr.editbuttons').height();
		position.top += $('tr.editbuttons').height();
		$("#usermaniphint").removeClass("hintoff");
		$("#usermaniphint").offset({left: 0, top: 0});
		$("#usermaniphint").offset( position);
	});
	$('.editbuttons').mouseleave(function(event) {
		$("#usermaniphint").addClass("hintoff");
	});

	$('.phoneno').live('click', function(event) {
		manip_phone(event.target);
	});


	// This is here in case the search box is populated when the page
	// is reloaded.  Consistency is swell.
	process_search( $('#searchfor') );
})
