#!/bin/sh

[ -d JazzHands ] && rm -rf JazzHands 
mkdir -p JazzHands

for i in \
	../aaa/acct-mgmt/src/lib/lib \
	../aaa/authtoken/src/perl/lib \
	../management/mgmt/perl/lib \
	../management/util/perl/lib \
	../management/util/perl-Krb5/lib \
	../poll/lib \
	../management/stab/perl/src/lib \
	../management/appauthal/perl/*/lib \
	../management/hotpants/src/perl/lib \
	../management/netdev-mgmt/perl/lib \
	../management/util/perl-tickets/lib \
	../management/approval/lib/lib \
; do
    echo process $i
    (cd $i; find JazzHands -type d -print) | xargs mkdir -p
    (cd $i; find JazzHands -name \*.pm -print) | perl -e 'my $path = shift || exit 1; while (<STDIN>) { chomp; $fn = $_; s%$path/?%%; $x = "../" x (scalar(split m%/%) - 1); symlink $x . $path . "/" . $fn, $fn; }' $i
done
