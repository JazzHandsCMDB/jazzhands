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



// This function builds the paging header in the specified container
// The container must contains the following data attributes:
// data-count: the total number of records
// data-limit: the number of records per page
// data-page: the current page number
// There is a catch howver: the paging offset has to be overriden by the value of the global variable pagingOffset if it exists
// This value is set when the "Go to Record" function is used
// In that case, the sql query automatically calculates the correct offset to use to land on the page containing the record
// On the client side, we have to reuse this value if defined

function buildPagingContainer( pagingDivId ) {

  // Get the paging container div with id pagingDivId
  var $pagingContainer = $('#' + pagingDivId);
  // Return if it doesn't exist
  if ($pagingContainer.length == 0) {
    return;
  }

  // Get the data-count attribute value
  var $count = $('#' + pagingDivId).data('count');
  // Get the data-limit attribute value
  var $limit = $('#' + pagingDivId).data('limit');

  // If the pagingOffset global variable is defined for this specific paging container, use it as the offset
  var $offset;
  var $page;
  var pagingOffsetVar = window['pagingOffset_' + pagingDivId];
  if (typeof pagingOffsetVar !== 'undefined') {
    $offset = pagingOffsetVar;
    $page = Math.ceil($offset / $limit);
    // Set the data-page attribute value to the calculated page number
    $('#' + pagingDivId).data('page', $page);
  } else {
    // Get the data-page attribute value
    $page = $('#' + pagingDivId).data('page');
    // Calculate the offset
    $offset = ($page - 1) * $limit;
  }
  // Calculate the number of pages
  var $pages = Math.ceil($count / $limit);
  // Calculate the maximum possible offset
  //var $maxoffset = ( $pages - 1 ) * $limit;

  // Calculate the first and last record being displayed
  var $first = $offset;
  var $last = $offset + $limit - 1;
  if ($last > $count) {
    $last = $count;
  }
  // Get the current window location url
  var $link = window.location.href;
  // Remove the pagingDivId+'_PAGE' and pagingDivId+'_LIMIT' parameters from the url, if any
  //$link = $link.replac

  // Create a paging control div and a paging info div
  var $pagingControls = $('<div class="paging-controls"></div>');
  var $pagingInfo = $('<div class="paging-info"></div>');

  // Create a first button
  var $firstButton = $('<button type="button" class="paging' + (($page == 1)?' off':'') + '" name="First" title="First page">First</button>');
  // Create a previous button
  var $previousButton = $('<button type="button" class="paging' + (($page == 1)?' off':'') + '" name="Previous" title="Previous page">Previous</button>');
  // Create a page input box with the current page number
  var $pageInput = $('<input type="text" id="' + pagingDivId + '-page" name="' + pagingDivId + '-page" value="' + $page + '" size="3">');
  // Create a hidden limit input box with the current limit value
  var $limitInput = $('<input type="hidden" id="' + pagingDivId + '-limit" name="' + pagingDivId + '-limit" value="' + $limit + '">');
  // Create a next button
  var $nextButton = $('<button type="button" class="paging' + (($page == $pages)?' off':'') + '" name="Next" title="Next page">Next</button>');
  // Create a last button
  var $lastButton = $('<button type="button" class="paging' + (($page == $pages)?' off':'') + '" name="Last" title="Last page">Last</button>');

  // Check if there are cross-universe records for this paging container
  var hasCrossUniverseVar = window['hasCrossUniverse_' + pagingDivId];
  var $toggleButton = null;

  // Only create toggle button if cross-universe records exist
  if (typeof hasCrossUniverseVar !== 'undefined' && hasCrossUniverseVar) {
    $toggleButton = $('<button type="button" class="paging universe-toggle" name="ToggleCrossUniverse" title="Hide records from other universes">Hide Others</button>');
  }

  // Add the first, previous, next and last buttons to the paging control div
  $pagingControls.append($firstButton, $previousButton, ' - Page ', $pageInput, ' of ' + $pages + ' - ', $nextButton, $lastButton);

  // Add toggle button if it exists
  if ($toggleButton) {
    $pagingControls.append(' | ', $toggleButton);
  }

  // Add the records info to the paging info div
  $pagingInfo.append('Records ' + $first + ' to ' + $last + ' of ' + $count);

  // Add the paging control and paging info divs to the paging container
  $pagingContainer.append($pagingControls, $pagingInfo);

  // Add a click event to the first button
  $firstButton.click(function(event) { changePage( pagingDivId, event, 1 ); });
  // Add a click event to the previous button
  $previousButton.click(function(event) { changePage( pagingDivId, event, ($page - 1 < 1) ? 1 : $page - 1 ); });
  // Add a click event to the next button
  $nextButton.click(function(event) { changePage( pagingDivId, event, ($page + 1 > $pages) ? $pages : $page + 1 ); });
  // Add a click event to the last button
  $lastButton.click(function(event) { changePage( pagingDivId, event, $pages ); });
  // Add an event to the page input box reacting to a keypress, if the keypress is the enter key
  // then call the changePage function
  $pageInput.keypress(function(event) {
    if (event.which == 13) {
      changePage( pagingDivId, event, $pageInput.val() );
    }
  });

  // Add click event to toggle cross-universe records visibility (only if button exists)
  if ($toggleButton) {
    $toggleButton.click(function(event) {
      event.preventDefault();
      var $form = $pagingContainer.closest('form');
      var $table = $form.find('table.dnstable');
      var $mismatchRows = $table.find('tr.universe-mismatch');

      console.log('Toggle clicked. Form:', $form.length, 'Table:', $table.length, 'Mismatch rows:', $mismatchRows.length);

      if ($mismatchRows.length > 0 && $mismatchRows.first().is(':visible')) {
        // Hide them
        $mismatchRows.hide();
        $toggleButton.text('Show All');
        $toggleButton.attr('title', 'Show records from other universes');
      } else if ($mismatchRows.length > 0) {
        // Show them
        $mismatchRows.show();
        $toggleButton.text('Hide Others');
        $toggleButton.attr('title', 'Hide records from other universes');
      }
    });
  }

}

function hasPendingChanges() {

  // Get all elements having the tracked and changed classes
  var trackedElements = $('form .tracked.changed');
  // If there are any elements, return true
  if( trackedElements.length > 0 ) {
    return true;
  }

  // Get any tr element with the rowrm class
  var rmrows = $('tr.rowrm');
  // Get any tr element with the dnsadd class
  var dnsadd = $('tr.dnsadd');
  // Get any tr element with the dnsrefadd class
  var dnsrefadd = $('tr.dnsrefadd');
  // If there are any elements, return true
  if( rmrows.length > 0 || dnsadd.length > 0 || dnsrefadd.length > 0 ) {
    return true;
  }

  return false;
}



// This function changes the page number in the url and redirects to the new url
function changePage( pagingDivId, event, page ) {
	// Don't allow form submission
	event.preventDefault();
  // Check if we have changed tracked element in any form on the page
  if( hasPendingChanges() ) {
    alert( 'There are pending changes, which have not been saved. They must be submitted or cancelled before moving to a different page.' );
    return;
  }
  // Get current page
  console.log( 'current page: ' + $('#' + pagingDivId).data('page') );
  console.log( 'new page: ' + page );
  var current_page = $('#' + pagingDivId).data('page');
  // If the page is the same as the current page, do nothing
  if( page == current_page ) {
    return;
  }

  // Get the data-limit attribute value
  var limit = $('#' + pagingDivId).data('limit');

	// Get the current window location url
	var link = window.location.href;
	// Remove the pagingDivId-page and pagingDivId-limit parameters from the url, if any
	link = link.replace( new RegExp( ';' + pagingDivId + '-page=\\d+' ), '' );
  link = link.replace( new RegExp( ';' + pagingDivId + '-limit=\\d+' ), '' );
  // Remove the dnssearch parameter from the url, if any
  link = link.replace( new RegExp( ';dnssearch=\\d+' ), '' );

	// Extract ip_universe_id from pagingDivId if it exists (e.g., paging-dns-0 -> 0)
	// and add it to the URL to preserve the active tab
	var universeMatch = pagingDivId.match(/paging-dns-(\d+)$/);
	if (universeMatch) {
		var universeId = universeMatch[1];
		// Remove existing ip_universe_id parameter if present
		link = link.replace( new RegExp( ';ip_universe_id=\\d+' ), '' );
		// Add the ip_universe_id parameter
		link = link + ';ip_universe_id=' + universeId;
	}

	// Redirect to the new url with the new pageingDivID+_PAGE and pagingDivId+'_LIMIT' parameters
	window.location = link + ';' + pagingDivId + '-page=' + page + ';' + pagingDivId + '-limit=' + limit;
}



$(document).ready(function(){
  // Get all div element with class paging_container and call the buildPagingContainer function
  $('div.paging-container').each(function() {
    buildPagingContainer( this.id );
  });
});
