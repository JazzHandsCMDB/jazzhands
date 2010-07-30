import java.math.BigInteger;

public class Test {
	private static void dump(IPv6Manip in) {
		System.out.println("In: " +in);
		System.out.println("\tstring: "+ in.toString());
		System.out.println("\tbigint: "+ in.toBigInteger());
		System.out.println("\thex:    " + in.toHexString());
		System.out.println("\tshort:  " + in.toShortString());
		System.out.println("\tbinary:  " + in.toBitString());
		System.out.println("\tbase:  " + in.baseShortString());
	}

	public static void main(String[] args) {
		IPv6Manip x;

		// random blocks
		dump(new IPv6Manip("::1"));
		dump(new IPv6Manip("2001:4860::/32")); // comcast
		dump(new IPv6Manip("2001:558::", 31)); // google
		dump(new IPv6Manip("2620:0:1800::4")); // vonage
		dump(new IPv6Manip("2620:0:1800::ffff", 48));  // playing
		dump(new IPv6Manip("fc00::/7"));
		dump(new IPv6Manip("fc00::ffff/7"));
		dump(new IPv6Manip("fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff/128"));

/*
		BigInteger zz = new BigInteger("50676817346727557890169925822582882304");
		byte[] b = zz.toByteArray();
		for(int i = 0; i < b.length; i++) {
			System.out.println(">"+i+" -- " + 
				String.format("%x", b[i]));
		}
 */
	}
}
