#include <sys/cdefs.h>
#include "hotpants_crypt.h"

#include <sys/types.h>

#include "crypt.h"

static const unsigned char itoa64[] =		/* 0 ... 63 => ascii - 64 */
	"./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

void
__crypt_to64(char *s, u_int32_t v, int n)
{

	while (--n >= 0) {
		*s++ = itoa64[v & 0x3f];
		v >>= 6;
	}
}
