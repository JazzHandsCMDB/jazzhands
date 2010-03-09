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
*/
/*
 * Originally taken from http://www.omniscent.com/; with permission
 */
var debugWindow;

var poppedup = null;
var popupon;

function changeNotify(obj)
{
	var thing;

	thing = findObj(obj);
	if(!thing) {
		return;
	}
	thing.value = 'Changed';
}

function findObj(what, d)
{
        var i, x;
        if(document.getElementById) {
                return document.getElementById(what);
        } else if(document.all) {
                for(i=0;i<document.all.length;i++) {
                        if(document.all[i].name == what) {
                                return(document.images[i]);
                        }
                }
        } else if(document.images) {
                for(i = 0 ; i < document.images.length; i++) {
                        if(document.images[i].name == what) {
                                return(document.images[i]);
                        }
                }
        }
        return null;
}

//
// when popping up over 'thing', open
// 'popmeup' so it's aligned with thing over
// popovertd.
// Switch the image at imgid to one with a _hover before the .jpg
//
function onlink(thing, popovertd, event, popmeup, imgid)
{
	var obj, outermost, o, popover, top, wid, img;

	// here change to the other "hover" image.
	if(imgid) {
		var img = findObj(imgid);
		var x = img.src.replace(".jpg", "_hover.jpg");
		img.src = x;
	}

	// alternately, we could have set the color to white.
	// thing.style.color = "white";

	// the rest of this deals with bringing up a table, if there is
	// one defined.

	// find the outermost object and calculate
	// where the top of it is for placing the popup.
	top = 0;
	for(o = thing; o; o = o.offsetParent) {
		top += o.offsetTop;
		outermost = o;
	}
	o = findObj(popovertd);

	//
	// If there is a windows still popped up, then close it.
	//
	if(poppedup != null) {
		poppedup.style.visibility = 'hidden';
		poppedup = null;
	}

	// find the table, and show it.
	obj = findObj(popmeup);
	if(o && obj) {
		obj.style.visibility = 'visible';
		poppedup = obj;

/*
		var wid = o.offsetLeft + 	// object to pop over
			thing.offsetParent.offsetParent.offsetParent.offsetParent.offsetLeft +  // Outer Table
			outermost.offsetLeft; // outermost object (border in browser)
*/
		var wid = img.width;

		obj.style.top = top + "px";
		obj.style.left = wid + "px";
	}
}

function offlink(thing, popovertd, event, popmeup, imgid)
{
	var left = 0, top = 0;
	var s = "";
	var img;

	// change to non-hover image.
	if(imgid) {
		var img = findObj(imgid);
		var x = img.src.replace("_hover.jpg", ".jpg");
		img.src = x;
		s += "img: " + img.offsetLeft+","+img.offsetTop + " x " + img.offsetWidth+","+img.offsetHeight + "<br>";
	}

	//
	// this magic is used to determine if the button will be exited in
	// order to go into the popup in which case the popup isn't closed.
	// 
	for(var o = thing; o; o = o.offsetParent) {
		left += o.offsetLeft;
		top += o.offsetTop;
		s += o.offsetLeft+","+o.offsetTop+" x "+o.offsetWidth+","+o.offsetHeight + "("+o.id+","+o.className+")<br>";
	}

	left = img.width;

	var bottom = top + thing.offsetHeight;
	s += "left == " + left + ", top == " + top + ", bottom == " + bottom  +"<br>";
	if(event.clientX <= left || event.clientY <= top || event.clientY >= bottom) {
		obj = findObj(popmeup);
		if(obj) {
			obj.style.visibility = 'hidden';
		}
		poppedup = null;
	}

}

function hidetable(thing, tblid, event)
{
	// find the borders of the table
	var o, top, bottom, left, right;
	top = 0;
	left = 0;

	// var popupon = findObj('tblid');
	popupon = thing;

	tbl = findObj(tblid) 
	if(!tbl) {
		return;
	}

	var s = "";
	for(o = tbl; o; o=o.offsetParent) {
		left += o.offsetLeft;
		top += o.offsetTop;
		s += o.offsetLeft+","+o.offsetTop+" x "+o.offsetWidth+","+o.offsetHeight + "("+o.id+","+o.className+")<br>";
	}
	bottom = top + tbl.offsetHeight;
	right = left + tbl.offsetWidth;

	left +=2; right -=2; top +=2 ; bottom -= 2;

	// The weird math is for IE's benefit.
	if(event.clientX <= left || event.clientY <= top || event.clientX >= right || event.clientY >= bottom) {
		popupon.style.visibility = 'hidden';
		poppedup = null;
	} else {
	}

}

function toggletable(thing, objid)
{
	var obj;

	obj = findObj(objid)
	if(!obj) {
		return;
	}

	if(obj.style.display == '') {
		obj.style.display = 'none'
	} else {
		obj.style.display = ''
	}
}
