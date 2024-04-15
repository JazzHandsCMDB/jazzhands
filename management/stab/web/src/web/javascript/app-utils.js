// Copyright (c) 2005-2010, Vonage Holdings Corp.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

//
// $Id$
//

function AppTreeManip(nodeid, imgid) {
	var node;

	node = document.getElementById(nodeid);
	if(node == null) {
		return;
	}
	if(node.style.display == 'none') {
		node.style.display = '';
		swaparrows(imgid, 'down');
	} else {
		node.style.display = 'none';
		swaparrows(imgid, 'up');
	}
}

//
// collapse or expand the trees
//
function BalanceTree(what) {
	var state, disp, divs, imgid;
	var divid, div;

	if(what == 'collapse') {
		disp = 'none'
		arrows = 'up';
	} else if(what == 'expand') {
		disp = ''
		arrows = 'down';
	} else {
		return;
	}

	divs = document.getElementsByTagName("div");
	for(var i = 0; i < divs.length; i++) {
		if(divs[i].className == 'approle_root') {
			divid = divs[i].id.replace(/_root$/, "");
			div = document.getElementById(divid);
			div.style.display = disp;

			imgid = divid + "_arrow";
			swaparrows(imgid, arrows);
		} else if(divs[i].className == 'approle_depth') {
			divid = divs[i].id.replace(/_depth$/, "");
			div = document.getElementById(divid);
			div.style.display = disp;

			imgid = divid + "_arrow";
			swaparrows(imgid, arrows);
		}

	}

}

//
// add a child application, and adjust the current one
//
function AddAppChild(id) {
	var parent, newkid, newdiv;
	var imgid, divid, div;
	var offset, add;

	parent = document.getElementById(id);
	if(!parent) {
		return
	}
	if(parent.className == 'approle_undecided') {
		parent.className = 'approle_depth';

		div = document.createElement('div');
		div.className = 'approle_depth';
		parent.appendChild(div);
	} else if(parent.className != 'approle_depth' && parent.className != 'approle_root') {
		// the only things we're actually allowed to change
		return;
	} else {
		divid = id.replace(/_.*$/, "");
		div = document.getElementById(divid);

		if(div.style.display == 'none') {
			imgid = id.replace(/_.*$/, "_arrow");
			div.style.display = '';
			swaparrows(imgid, 'down');
		}
	}

	//
	// at this point, div is the wrapper around the collapsable element
	// that contains all the "children" of a given element.
	//
	// newdiv will be the wrapper around the actual element itself, where
	// the user enters items.

	newdiv = document.createElement('div');
	newdiv.className = 'approle_undecided';
	newdiv.id = "newchild_" + div.id;

	// place it.  For "undecideds", it needs to probably just be the
	// same as offset. XXX
	offset = Number(div.parentNode.style.marginLeft.replace(/px$/, ""));
	offset += 20;	// this is also in device/apps/index.pl ; must sync.
	newdiv.style.marginLeft = offset + "px";


	newkid = document.createElement('input');
	newkid.id = div.id;
	newdiv.appendChild(newkid);

	add = document.createElement('a');
	add.href = "javascript:void(null);";
	add.className = 'approle_addchild';
	add.onclick = function() { AddAppChild(newdiv.id); };
	add.innerHTML = "(add)";
	newdiv.appendChild(add);

	//
	// in this case, we're adding a child to a new child, so it needs
	// arrows.
	if(parent.id.match(/^newchild/)) {
		var arrowimgid, arrowimgid;
		arrowimg = document.createElement('img');

		// this only needs to happen if the arrow doesn't exist (check by id)
		// create the image, make it point to the right place, assign all the
		// right onclicks and whatnot, default to open

		alert("wtfbbq?!");
	}

	// make the new box show up
	div.appendChild(newdiv);
}
