//
// Copyright (c) 2013 Matthew Ragan
// All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//


// NOTE: this stuff requires jQuery having been included first

// Set up handlers for things

$(function() {
	jazzhands_common_init();
});

function jazzhands_common_init() {

	// make all divs with a class of 'editabletext' be able to click to
	// edit the text

	// NOTE:  This should probably just dynamically create the record on
	// click!

	$("span.editabletext").each( function ( index, el) {
		// Get the text value of the div as initial value, then clear
		// it

		var id = $(el).attr('id');
		//
		// see if it has already been done for this element
		var inid = "ED_"+id;
		// ... ipv6
		inid = inid.replace(/:/g, "_C_");
		var x = $(this).find("input#"+inid);
		var ll = $(x).length;
		if ( $(x).length ) {
			return;
		}

		// save the original value of the element
		// el.orig_value = textbox;
		var text = $(el).html();
		text = text.trim();
		$(el).text('');

		// Create a new hidden input box with the value of the text
		// element

		textbox = $("<input/>", {
			id: inid,
			name: id,
			type: "text",
			"class": "editabletext",
			value: text
		});

		textbox.hide();
		$(el).append(textbox);

		// Create a span with the text, or "Set Description" if no text
		// Set the class to "editabletext" or "hinttext" depending on
		// how we want it displayed



		$(el).append( $("<span/>", {
			html: text || "Set Description",
			"class": text ? "editabletext" : "hinttext"
		}));

		// Set up a handler for the element to show the input box and
		// hide the span when we're clicked

		$(el).click(
			function() {
				$(this).children('span').hide();
				$(this).children('input').show().focus();
			}
		);

		// Set up a second handler to hide the input box and show the
		// span when focus is removed, copying any text back over

		$(textbox).blur(
			function() {
				var value = $(this).val();
				if (!value) {
					$(this).siblings("span")
						.text("Set Description")
						.removeClass("editabletext")
						.addClass("hinttext")
						.show();
				} else {
					$(this).siblings("span")
						.text(value)
						.removeClass("hinttext")
						.addClass("editabletext")
						.show();
				}
				$(this).hide();
			}
		);

	});
}

