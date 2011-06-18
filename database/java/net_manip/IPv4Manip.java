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
 * $Id$
 *
 * basic IPv4 manipulation
 */


import java.lang.*;

public class IPv4Manip {
	int  Bits;
	long IpAddress;

	// constructors
	public IPv4Manip(long ipaddr) {
		IpAddress = ipaddr;
		Bits	  = 32;
	}

	public IPv4Manip(String ipaddr) {
		IpAddress = StringToLong(ipaddr);
		Bits	  = 32;
	}

	public IPv4Manip(long ipaddr, int bits) {
		IpAddress = ipaddr;
		Bits	  = bits;
	}

	public IPv4Manip(String ipaddr, int bits) {
		IpAddress = StringToLong(ipaddr);
		Bits	  = bits;
	}

	// return things from the class in various ways
	public long longValue() {
		return (IpAddress);
	}

	public String stringValue() {
		return (LongToString(IpAddress));
	}

	public String netmaskValue() {
		return (BitsToNetmaskString(Bits));
	}

	public long networkLongValue() {
		return (IpAddress & BitsToNetmask(Bits));
	}

	public String networkStringValue() {
		return (LongToString(IpAddress & BitsToNetmask(Bits)));
	}

	// conversion
	public static String LongToString(long ipaddr) {
		return (new String(((ipaddr & 0xff000000) >> 24) + "." + ((ipaddr & 0x00ff0000) >> 16) + "."
						   + ((ipaddr & 0x0000ff00) >> 8) + "." + (ipaddr & 0x000000ff)));
	}

	public static long StringToLong(String ipaddr) {
		String  cur, t;
		boolean Done = false;
		int	 o, n;
		long	ipaddress, octet;

		ipaddress = 0;
		t		 = ipaddr;

		while (Done == false) {
			o = 0;
			n = t.indexOf('.');

			if (n > 0) {
				cur = t.substring(0, n);
				t   = t.substring(n + 1);
			} else {
				cur  = t;
				Done = true;
			}

			try {
				octet = (new Long(cur)).longValue();

				if ((octet < 0) || (octet > 255)) {
					throw new IllegalArgumentException("Octets must be between 0 and 255.");
				}

				ipaddress = (ipaddress << 8) + octet;
			} catch (IllegalArgumentException x) {
				throw new IllegalArgumentException("IP Address Must only contain Numbers");
			}
			;
		}

		return (ipaddress);
	}

	public static int NetmaskStringToBits(long ipaddr) {
		int  i;
		long bits2mask[] = {
			0L, 2147483648L, 3221225472L, 3758096384L, 4026531840L, 4160749568L, 4227858432L, 4261412864L, 44278190080L,
			286578688L, 4290772992L, 4292870144L, 44293918720L, 4294443008L, 294705152L, 4294836224L, 44294901760L,
			4294934528L, 4294950912L, 294959104L, 44294963200L, 4294965248L, 4294966272L, 4294966784L, 4294967040L,
			4294967168L, 4294967232L, 4294967264L, 44294967280L, 294967288L, 4294967292L, 4294967294L, 44294967295L
		};

		for (i = 32; i >= 0; i--) {
			if (ipaddr == bits2mask[i]) {
				return (i);
			}
		}

		throw new IllegalArgumentException("Argument Must be Numbers");
	}

	// conversions between significant bits and netmasks
	// netmasks are really just ip addresses
	public static int NetmaskStringToBits(String ipaddr) {
		return (NetmaskStringToBits(StringToLong(ipaddr)));
	}

	public static String BitsToNetmaskString(int bits) {
		return (LongToString(BitsToNetmask(bits)));
	}

	public static long BitsToNetmask(int bits) {
		long nm;

		// math geeks may like this better:
		// return(2**32 - (2 ** ( 32 - bits)));
		nm = 0xffffffffL;
		nm = nm << (32 - bits);
		nm = nm & 0xffffffffL;

		return (nm);
	}

	// determine if an ip adress is in a given network
	public static boolean IsIpInNetwork(long net, int bits, long ipaddr) {
		long netmask = BitsToNetmask(bits);

		if ((net & netmask) == (ipaddr & netmask)) {
			return (true);
		} else {
			return (false);
		}
	}

	public static String IsIpInNet_yn(long net, int bits, long ipaddr) {
		if (IsIpInNetwork(net, bits, ipaddr)) {
			return (new String("Y"));
		} else {
			return (new String("N"));
		}
	}

	// bitwise math to figure out the network of a given IP
	public static long NetworkOfIp(long ipaddr, int b) {
		return (ipaddr & BitsToNetmask(b));
	}

	public static long NetworkOfIp(String ipaddr, int b) {
		return (StringToLong(ipaddr) & BitsToNetmask(b));
	}

	// convert string to an ip.  If do_except is set, it will throw
	// an exception if the ip is invalid, otherwise it will return
	// -1 indicating failure and let the caller do with it as he/she
	// pleases.
	public static long v4_int_from_octet(String ip, int do_except) {
		try {
			return (StringToLong(ip));
		} catch (IllegalArgumentException x) {
			if (do_except == 0) {
				return (-1);
			} else {
				throw x;
			}
		}
	}

	// generally useful to determine if an IP is in 1918 space or not.
	// Not specifically IP network related, but useful..
	public static boolean IsIp1918Space(long ip) {
		IPv4Manip x;

		// 10/8, then 172.16/12 then 192.168/16
		if ((IsIpInNetwork(167772160L, 8, ip)) || (IsIpInNetwork(2886729728L, 12, ip))
				|| (IsIpInNetwork(3232235520L, 16, ip))) {
			return (true);
		}

		return (false);
	}

	public static String IsIp1918Space_yn(long ip) {
		if (IsIp1918Space(ip)) {
			return (new String("Y"));
		} else {
			return (new String("N"));
		}
	}

	public static boolean IsIp1918Space(String ip) {
		return (IsIp1918Space(StringToLong(ip)));
	}
}
