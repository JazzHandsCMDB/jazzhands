/*
* Copyright (c) 2010-2011, Todd M. Kover
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
 * $Id$
 *
 * basic IPv6 manipulation, does more than InetAddress does
 *
 * This really wants to be merged into IPv4Manip...
 */


import java.lang.*;
import java.math.BigInteger;
import java.util.regex.*;

public class IPv6Manip {
	int  Bits = -1;
	Integer IP[];

	String stash;

	/**********************************************************************
	 *
	 * Constructors 
	 *
	 **********************************************************************/
	public IPv6Manip(BigInteger in_ipaddr) {
		IP = BigIntToIntArray(in_ipaddr);
	}

	public IPv6Manip(String in_ipaddr) {
		String[] parsed = in_ipaddr.split("/");
		IP = StringToInts(parsed[0]);
		if(parsed.length == 2) {
			Bits = Integer.parseInt(parsed[1]);
			Integer[] x = BitsToMask(Bits);
		}
	}

	public IPv6Manip(BigInteger in_ipaddr, int bits) {
		IP = BigIntToIntArray(in_ipaddr);
		Bits	  = bits;
	}

	public IPv6Manip(String in_ipaddr, int bits) {
		IP = StringToInts(in_ipaddr);
		Bits	  = bits;
	}

	/**********************************************************************
	 *
	 * Data manipulation code
	 *
	 **********************************************************************/

	// XXX throw an error if we have bum input (not [0-9a-z:])
	private static Integer[] StringToInts(String in_ipaddr) {
		// This deals with things starting with a :.
		String xlate = in_ipaddr.replaceAll("^::", "0::");
		String[] in =  xlate.split(":");
		Integer[] rt = new Integer[8];
		int olen = 0;

		for(int i = 0; i < in.length; i++) {
			if(in[i].equals("")) {
				for(int j = 0; j <= 8 - in.length; j++) {
					rt[olen++] = 0;
				}
			} else {
					rt[olen++] = Integer.parseInt(in[i], 16);
			}
		}
		// fill in any gaps (for the end)
		for(int i = olen; i < rt.length; i++) {
			rt[olen++] = 0;
		}
		return(rt);
	}

	// print the IPv6 address with all double octets (no ::)
	private static String IntsToFullString(Integer[] hex) {
		String r = "";
		for(int i = 0; i < hex.length; i++) {
			if(i > 0) {
				r += ':';
			}
			// r += Integer.toHexString(hex[i]).toUpperCase();
			r += String.format("%04x", hex[i]);
		}
		return r;
	}

	// print the IPv6 address with all double octets (no ::)
	private String IntsToShortString(Integer[] hex) {
		String r = "";
		for(int i = 0; i < hex.length; i++) {
			if(i > 0) {
				r += ':';
			}
			// r += Integer.toHexString(hex[i]).toUpperCase();
			r += String.format("%x", hex[i]);
		}
		return r;
	}

	// return one long hex string (no colons);
	private static String IntsToHexString(Integer[] hex) {
		String r = "";
		for(int i = 0; i < hex.length; i++) {
			r += String.format("%04x", hex[i]);
		}
		return r;
	}

	// return one long hex string (no colons);
	private String IntsToBitsString(Integer[] hex) {
		String r = "";
		System.out.println("hex length is " + hex.length);
		for(int i = 0; i < hex.length; i++) {
			r += String.format("%16s", Integer.toBinaryString(hex[i]));
		}
		r = r.replace(" ", "0");
		return r;
	}

	// bits to binary
	// take the length, stuff in a bunch of ones, zeros for the rest
	// convert that to a full string.
	private Integer[] BitsToMask(int bits) {
		Integer rv[] = { 0,0,0,0,0,0,0,0};
		int full;

		// XXX make sure bits <= 128
		full = bits/16;
		for(int i = 0; i< full; i++) {
			rv[i] = 0xffff;
		}
		if(full < rv.length ) {
			rv[full] = ( 0xFFFF << (16 - bits%16)) & 0xFFFF;
		}
		return rv;
	}

	// given a mask array, returns the number of bits
	private Integer MaskArrayToBits(Integer[] in) {
		String x = IntsToBitsString(in);
		return x.indexOf("0");
	}

	// given a string mask, returns the number of bits
	private Integer MaskToBits(String in) {
		Integer[] mask = StringToInts(in);
		String bits = IntsToBitsString(mask);
		return bits.indexOf("0");
	}

	//
	// XXX: need to test:
	//	strings with no matches
	//  strings with multiple equal matches
	private String IntegerToShortString(Integer[] in_ip) {
		String x = IntsToShortString(in_ip);
		Pattern p = Pattern.compile("(:0)+");
		Matcher m;
		int start = 0, end = 0;

		String longest;
		// need to strip out the longest set of :0
		m = p.matcher(x);
		boolean result = m.find();
		while(result) {
			if(m.end() - m.start() >=  end - start) {
				start = m.start();
				end = m.end();
			}
			String z = x.substring(m.start(), m.end());
			result = m.find();
		}
		if(start > 0) {
			String z = "";
			if(end != x.length() ) {
				z= x.substring(end+1,x.length() );
			}
			x= x.substring(0,start) + "::" + z;
		}
		return x.replaceAll("^0::", "::");
	}

	private static Integer[] BigIntToIntArray(BigInteger in) {
		Integer[] rv = { 0,0,0,0,0,0,0,0 };

		// ** need to figure out the right way to break this up!
		for(int i=0; i < rv.length; i++) {
			rv[7-i] = in.shiftRight(16*i).intValue() & 0xFFFF;
		}
		return rv;
	}

	/**********************************************************************
	 *
	 * Public interface functions for giving different interpretations of
	 * this object.
	 *
	 **********************************************************************/

	public String toLongString() {
		String rv;
		rv = IntsToFullString(IP);
		if(Bits >= 0) {
			rv += "/" + String.valueOf(Bits);
		}
		return rv;
	}

	public String toBitString() {
		String rv;
		return IntsToBitsString(IP);
	}

	public String toString() {
		return IntegerToShortString(IP);
	}

	public BigInteger BitsToBigInt() {
		if(Bits < 0) {
			throw new IllegalArgumentException("Netblock size not set");
		}
		Integer[] mask = BitsToMask(Bits);
		String x = IntsToHexString(mask);
		return new BigInteger(x, 16);
	}

	public BigInteger toBigInteger() {
		String x = IntsToHexString(IP);
		return new BigInteger(x, 16);
	}

	public String toHexString() {
		return IntsToHexString(IP);
	}

	public BigInteger baseLong() {
		BigInteger me = toBigInteger();
		BigInteger mask = BitsToBigInt();
		BigInteger base = me.and(mask);
		return base;
	}

	public String base() {
		return baseShortString();
	}

	public String baseShortString() {
		BigInteger me = toBigInteger();
		BigInteger mask = BitsToBigInt();
		BigInteger base = me.and(mask);

		Integer[] basea = BigIntToIntArray(base);
		return IntegerToShortString(basea);
	}

	public String baseString() {
		BigInteger me = toBigInteger();
		BigInteger mask = BitsToBigInt();
		BigInteger base = me.and(mask);

		Integer[] basea = BigIntToIntArray(base);
		return IntsToBitsString(basea);
	}

	public BigInteger size() {
		if(Bits < 0) {
			throw new IllegalArgumentException("Netblock size not set");
		}
		BigInteger x = new BigInteger("2");
		return x.pow(128 - Bits);
	} 

	public BigInteger lastLong() {
		if(Bits < 0) {
			throw new IllegalArgumentException("Netblock size not set");
		}
		BigInteger x = new BigInteger("2");
		BigInteger size = x.pow(128 - Bits);
		BigInteger base = baseLong();
		return base.add(size).subtract(new BigInteger("1"));
	} 

	public String last() {
		if(Bits < 0) {
			throw new IllegalArgumentException("Netblock size not set");
		}
		BigInteger x = new BigInteger("2");
		BigInteger size = x.pow(128 - Bits);
		BigInteger base = baseLong();
		Integer[] end = BigIntToIntArray( base.add(size).subtract(new BigInteger("1")) );
		return IntsToShortString(end);
	} 

	public Boolean contains(String in) {
		Integer[] checkme = StringToInts(in);
		String x = IntsToHexString(checkme);
		BigInteger inbig = new BigInteger(x, 16);

		BigInteger base = baseLong();
		if(inbig.compareTo(base) < 0) {
			return false;
		}
		BigInteger last = lastLong();
		if(inbig.compareTo(last) > 0) {
			return false;
		}
		return true;
	}

	// return the type??
	// return the in-addr record
	// is address X in this block? -- for other types (Ip, bigint?)

	/**********************************************************************
	 *
	 * Public interface for manipulating IPv6 addresses
	 *
	 * NONE OF THESE ARE IMPLEMENTED YET...  Well, maybe the first one
	 *
	 **********************************************************************/

        // convert string to an ip.  If do_except is set, it will throw
        // an exception if the ip is invalid, otherwise it will return
        // -1 indicating failure and let the caller do with it as he/she
        // pleases.
        public static BigInteger v6_int_from_string(String ip, int do_except) {
		Integer v6split[];
		String tstr;
		BigInteger bi;
                try {
			v6split = StringToInts(ip);
			tstr = IntsToHexString(v6split);
			bi = new BigInteger(tstr, 16);
			System.out.println("result is " + bi);
			return bi;
                } catch (IllegalArgumentException x) {
                        if (do_except == 0) {
				return null;
                        } else {
                                throw x;
                        }
                }
        }

	// convert an ip  to a string
	public static String ora_v6_string_from_int(BigInteger in_ip)  {
		Integer v6split[];

		v6split = BigIntToIntArray(in_ip);
		return IntsToFullString(v6split);
	}
		

	// is this block in that block
	// address && mask == address
	// base address of a block
	// is private space? rfc4xxx?

}
