/*
 * from http://stuff.mit.edu/afs/athena/astaff/project/ldap/AD/ksetpw/
 */
#include <stdio.h>
#include <sys/types.h>
#include <strings.h>
#ifdef HAVE_PWD_H
#include <pwd.h>
#endif
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifdef HAVE_GETOPT_H
#include <getopt.h>
#endif

#include <krb5.h>

static const char rcsid[] = "$Id$";

#define P1 "Enter new password: "
#define P2 "Enter it again: "

static char *progname;

int
main(int argc, char *argv[])
{
	krb5_error_code ret;
	krb5_context context;
	char *pname = NULL;
	char *targpname = NULL;
	krb5_ccache ccache;
	krb5_principal targprinc;
	char pw[1024];
	unsigned int pwlen;
	int result_code;
	krb5_data result_code_string, result_string;
	int ch;
	int infd = -1;
	FILE *f;
	extern char *optarg;
	extern int optind;

	static struct option longopts[] = {
		{"password-fd", required_argument, NULL, 'f'},
		{NULL, 0, NULL, 0}
	};


	progname = argv[0];

	while ((ch = getopt_long(argc, argv, "f:", longopts, NULL)) != -1) {
		switch (ch) {
		case 'f':
			infd = atoi(optarg);
			break;

		default:
			break;
		}
	}
	argc -= optind;
	argv += optind;

	if (argc != 1) {
		fprintf(stderr, "usage: %s [-password-fd #] <principal>\n", progname);
		exit(-1);
	}
	targpname = argv[optind];

	if (ret = krb5_init_context(&context)) {
		com_err(argv[0], ret, "initializing kerberos library");
		exit(ret);
	}
	if (ret = krb5_cc_default(context, &ccache)) {
		if (ret == KRB5_CC_NOTFOUND)
			printf("No Kerberos credentials; kinit then try again.\n");
		else
			com_err(argv[0], ret, "opening default ccache");
		exit(ret);
	}
	if (ret = krb5_parse_name(context, targpname, &targprinc)) {
		com_err(argv[0], ret, "while parsing target principal");
		exit(ret);
	}
	if (ret = krb5_unparse_name(context, targprinc, &targpname)) {
		com_err(argv[0], ret, "while parsing target principal");
		exit(ret);
	}
	pwlen = sizeof(pw);
	if (infd == -1) {
		printf("Changing password for %s\n", targpname);
	}
	if (infd >= 0) {
		if (!(f = fdopen(infd, "r"))) {
			fprintf(stderr, "could not reopen fd %d\n", infd);
			exit(-1);
		}
		if (fgets(pw, sizeof(pw), f) == NULL) {
			fprintf(stderr, "Error reading password from fd%d\n", infd);
			exit(-1);
		}
		if (!strlen(pw)) {
			fprintf(stderr, "Password must be given\n");
			exit(-1);
		}
		pw[strlen(pw) - 1] = '\0';
	} else if (ret = krb5_read_password(context, P1, P2, pw, &pwlen)) {
		com_err(argv[0], ret, "while reading password");
		exit(ret);
	}
	if (ret = krb5_set_password_using_ccache(context, ccache, pw, targprinc,
		&result_code, &result_code_string,
		&result_string)) {
		com_err(argv[0], ret, "changing password");
		exit(ret);
	}
	if (result_code) {
		printf("%.*s%s%.*s\n",
		    result_code_string.length, result_code_string.data,
		    result_string.length ? ": " : "",
		    result_string.length,
		    result_string.length ? result_string.data : "");
		exit(2);
	}
	free(result_string.data);
	free(result_code_string.data);

	printf("Password changed.\n");
	exit(0);
}
