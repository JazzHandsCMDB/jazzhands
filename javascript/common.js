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

	// make all divs with a class of 'editabletext' be able to click to
	// edit the text

	$("span.editabletext").each( function ( index, el) {
		// Get the text value of the div as initial value, then clear
		// it

		var text = $(el).html();
		var id = $(el).attr('id');
		$(el).text('');

		// Create a new hidden box with the original value of the text
		// element

		var textbox = $("<input/>", {
			name: "orig_" + id,
			type: "hidden",
			value: text
		});
		$(el).append(textbox);

		// Create a new hidden input box with the value of the text
		// element

		textbox = $("<input/>", {
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
});

