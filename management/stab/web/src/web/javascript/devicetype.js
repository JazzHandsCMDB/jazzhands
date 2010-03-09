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
//
// $Id$
//

function tweak_plug_style(picobj, dropobj)
{
	var plugstyle, newname, i;
	if(!picobj || ! dropobj) {
		return;
	}

	// dropobj.value contains "NEMA 5-20P".  need to tweak
	plugstyle = dropobj.value;

	if(plugstyle == "__unknown__") {
		plugstyle = "unknown";
	} else {
		i = plugstyle.lastIndexOf(" ");
		if(i >=0) {
			plugstyle = plugstyle.substring(i+1);
		}
		i = plugstyle.lastIndexOf("/");
		if(i >=0) {
			plugstyle = plugstyle.substring(0, i);
		}
	}

	newname = picobj.src;
	i = newname.lastIndexOf("/");
	newname = newname.substring(0, i);
	newname = newname + "/" + plugstyle.toLowerCase() + ".png";

	picobj.src = newname;

	return;

}
