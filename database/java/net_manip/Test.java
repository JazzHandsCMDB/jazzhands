import java.math.BigInteger;

public class Test {
	private static void dump(IPv6Manip in) {
		System.out.println("In: " +in);
		System.out.println("\tsize:  " + in.size());
		System.out.println("\tstring: "+ in.toString());
		System.out.println("\tbigint: "+ in.toBigInteger());
		System.out.println("\thex:    " + in.toHexString());
		System.out.println("\tfull:  " + in.toLongString());
		System.out.println("\tbase:  " + in.baseShortString());
		System.out.println("\tlast:  " + in.last());
		System.out.println("\tcontains:  " + in.contains("2620:0:1800::5"));
		System.out.println("\tbinary:  " + in.toBitString());
	}

	public static void main(String[] args) {
		IPv6Manip x;

		// random blocks
		dump(new IPv6Manip("::1/128"));
		dump(new IPv6Manip("2001:4860::/32")); // comcast
		dump(new IPv6Manip("2001:558::", 31)); // google
		dump(new IPv6Manip("2620:0:1800::", 48)); // vg
		dump(new IPv6Manip("2620:0:1800::4/128")); // playing
		dump(new IPv6Manip("2620:0:1800::ffff", 48));  // playing
		dump(new IPv6Manip("fc00::/7"));
		dump(new IPv6Manip("fc00::ffff/7"));
		dump(new IPv6Manip("fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff/128"));
	}
}
