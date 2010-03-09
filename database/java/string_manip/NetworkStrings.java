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
 * $Id$$
 */

/*
 * This module implements some string manipulation functions
 */

import java.lang.*;
import java.text.*;

public class NetworkStrings {
	public static String NumericInterface(String in_iface) {
		int i;
		String elems[], rv, string, iface;

		iface = in_iface;
		rv = "";
		// leaving these off so they are sorted by slot numbers
		// rv = iface.replaceAll("([^\\d]+)\\d.*$", "$1");
		// rv += ".";
		iface = iface.replaceAll("^[^\\d]+", "");
		iface = iface.replaceAll("[^\\d]+$", "");
		if(! iface.matches("^[\\d\\./]+$")) {
			return in_iface;
		}

		elems = iface.split("[\\./]");
		for(i = 0; i< elems.length; i++) {
			DecimalFormat nft = new DecimalFormat("00000");
			String x = nft.format( Integer.parseInt(elems[i]) );
			rv += x + ".";
		}

		return rv;
	}
}
