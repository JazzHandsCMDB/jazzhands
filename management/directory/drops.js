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
					if(resp['type'] == 'person') {
						var t = document.createElement('table');
						if(resp['people']) {
							for(var i = 0; i < resp['people'].length; i++) {
								var tr = document.createElement("tr");
								var td = document.createElement("tr");
								var a = document.createElement("a");
								a.href = resp['people'][i]['link'];
								$(a).text(resp['people'][i]['name']);
								td.appendChild(a);
								tr.appendChild(td);
								t.appendChild(tr);
							}
							$(results).append(t);
						}
					}
				}
			);
		}, 350);
	}
}

function build_option(newid, in_list) {
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
		} else {
			o = new Option(in_list[i], in_list[i]);
		}
		s.add(o);
	}
	return s;
}

function remove_phone(remove_button) {
	var form = $(remove_button).closest('form');

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
		});
	}
}

function add_phone(add_button) {
	var tbl = $(add_button).closest('TABLE');
	$.getJSON('ajax/contact.pl',
		"type=phone",
		function(resp) {
			var tr = document.createElement("tr");
			var td = document.createElement("td");
			td.colSpan = 2;

			var form = document.createElement("form");
			form.setAttribute("class", "addphone");

			var lhs = document.createElement("div");
			lhs.setAttribute("class", "phoneremove");

			var pic = document.createElement("img");
			pic.setAttribute("class", "removex");
			pic.src = "images/round_red_x_sign_4229.jpg";
			pic.setAttribute("alt", "X");
			var a = document.createElement("a");
			a.href = "#"
			a.setAttribute("class", "remove_phone");
			a.appendChild(pic);
			lhs.appendChild(a);
			form.appendChild(lhs);

			// this is acutally the middle now that there is a remove button */
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

			var s = build_option("locations", resp['locations']);
			lhs.appendChild(s);

			s = build_option('technology', resp['technologies']);
			lhs.appendChild(s);

			s = build_option('privacy', resp['privacy']);
			lhs.appendChild(s);

			form.appendChild(lhs);

			var rhs = document.createElement("div");
			rhs.setAttribute("class", "phonedigits");

			s = build_option('country', resp['countries']);
			rhs.appendChild(s);

			input = document.createElement("input");
			input.setAttribute("class", "inputhint");
			input.setAttribute("id", "phone");
			input.setAttribute("name", "phone");
			input.setAttribute("value", "phone");
			input.setAttribute("size", "15");
			rhs.appendChild(input);

			input = document.createElement("input");
			input.setAttribute("class", "inputhint");
			input.setAttribute("id", "pin");
			input.setAttribute("name", "pin");
			input.setAttribute("value", "pin");
			input.setAttribute("size", "5");
			rhs.appendChild(input);

			var msg = document.createElement("div");
			msg.setAttribute("class", "msg");
			rhs.appendChild(msg);

			var submit = document.createElement("a");
			submit.href = "#";
			submit.innerHTML = "SUBMIT";
			submit.setAttribute("class", "sbmtphone");
			rhs.appendChild(submit);

			form.appendChild(rhs);

			td.appendChild(form);
			tr.appendChild(td);
			$('tr#add_phones').before(tr);


		}
	);
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
			var close = document.createElement("a");
			close.setAttribute("class", "closebutton");
			$(close).click(function() {
				$('#picsdisplay').toggle(0);
				$('#picsdisplay').empty();
			});
			close.href = "#";
			$(close).text("[XXXX]");
			$('#picsdisplay').append(close);

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

			for(var i = 0; i < resp['pics'].length; i++) {
				var imgid = resp['pics'][i]['person_image_id'];
				var tr = document.createElement("tr");
				var td = document.createElement("td");
				var img = document.createElement("img");
				img.setAttribute("class", "fullsize");
				img.src = "picture.php?person_id="+person_id+"&person_image_id="+ imgid;
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
			$(input).attr('type','submit');
			$(input).val('Submit');
			$(td).append(input);
			$(tr).append(td);
			$(t).append(tr);

			// set onclick function on

			$(form).append(t);
			$('#picsdisplay').append(form);

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
	// binding to click does not work on dynamic elements 
	$("input#searchfor").keyup( 
	 		function(event){
				process_search($(this))
			}
	);

	$("a.sbmtphone").live('click', function(event){
		var form = $(this).closest('form');
		if(form) {
			s = $(form).serialize();

			// post results, and in the results, we'll remove
			// and replace with a proper row
			$.post('ajax/add_number.pl', s, function(resp) {
				if(resp['error']) {
					x = $(form).find('div.msg').text(resp['error']);
				} else {
					var tr = $(form).closest('tr');
					$(tr).empty();

					var td = document.createElement("td");
					var newform = document.createElement("form");

					var hidden = document.createElement("input");
					hidden.setAttribute("type", "hidden");
					hidden.setAttribute("name", "person_contact_id");
					hidden.setAttribute("value", resp['record']['person_contact_id']);
					newform.appendChild(hidden);

					var pic = document.createElement("img");
					pic.setAttribute("class", "removex");
					pic.src = "images/round_red_x_sign_4229.jpg";
					pic.setAttribute("alt", "X");
					var a = document.createElement("a");
					a.href = "#"
					a.setAttribute("class", "remove_phone");
					a.appendChild(pic);
					$(newform).append(a);
					$(newform).append( resp['record']['print_title'] );

					$(td).append(newform);
					$(tr).append(td);

					td = document.createElement("td");
					$(td).text( resp['record']['print_number'] );
					$(tr).append(td);
				}
			});
		}
	});

	$("a.remove_phone").live('click',function(event){
		remove_phone($(this));});

	$("a.addphonebutton").live('click',function(event){
		add_phone($(this));});

	// remove the greyed out hint that was there
	$("input.inputhint").live('focus',function(event){
		$(this).removeClass("inputhint");
		$(this).val("");
	});


	// This is here in case the search box is populated when the page
	// is reloaded.  Consistency is swell.
	process_search( $('#searchfor') );
})
