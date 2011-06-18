import java.math.BigInteger;

public class Test2 {
	private static void dump(IPv6Manip in) {
		System.out.println("In: " +in);
		System.out.println("\tstring: "+ in.toString());
	}

	private static void dump_i(IPv6Manip in) {
		System.out.println("In: " +in);
		System.out.println("\tstring: "+ in.toBigInteger());
	}

	public static void main(String[] args) {
		IPv6Manip x;

/*
		// random blocks
		dump(new IPv6Manip(new BigInteger("334965454937798799971759379190646833152"), 128));
		System.out.println("");
		dump(new IPv6Manip(new BigInteger("334969971398294010747267358593998913536"), 128));
		System.out.println("");
		dump(new IPv6Manip(new BigInteger("334969971398294010747267358593998913536"), 128));
		dump(new IPv6Manip(new BigInteger("334969971398294010931734799331094429696"), 128));
		System.out.println("");
		dump(new IPv6Manip(new BigInteger("334969971398294010931734799331094429697"), 128));
		dump(new IPv6Manip(new BigInteger("334969971398294010931734799331094429698"), 128));
		dump(new IPv6Manip(new BigInteger("334969971398294010931734799331094429705"), 128));
		dump(new IPv6Manip(new BigInteger("334969971398294010931734799331094429999"), 128));
		dump(new IPv6Manip(new BigInteger("334969971398294010931734799331094500000"), 128));
 */

		dump_i(new IPv6Manip("fc00:dead:beef:a::"));
		dump_i(new IPv6Manip("fc00:dead:beef:a::1"));
		dump_i(new IPv6Manip("fc00:dead:beef:a::2"));

		System.out.println(IPv6Manip.v6_int_from_string("fc00:dead:beef:a::", 1) + "\n");
		System.out.println(IPv6Manip.v6_int_from_string("fc00:dead:beef:a::1", 1) + "\n");
		System.out.println(IPv6Manip.v6_int_from_string("fc00:dead:beef:a::2", 1) + "\n");
	}
}
