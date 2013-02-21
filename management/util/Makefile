INSTBASE=/usr/lib/perl5/vendor_perl

all:
	(cd perl && perl Makefile.PL INSTALLDIRS=vendor LIB=$(INSTBASE) && $(MAKE) pure_all)


install:
	(cd perl && $(MAKE) DESTDIR=`pwd`/../fakeroot pure_vendor_install)

buildpkg:
	rm -rf `pwd`/haterpm
	mkdir -p `pwd`/haterpm/RPMS
	rpmbuild -ba --define "_topdir ./haterpm" --buildroot `pwd`/fakeroot -bb --short-circuit jazzhands-perl-common.spec

clean:
	rm -rf fakeroot haterpm
	(cd perl && ([ ! -f Makefile ] || make clean) && rm -f Makefile.old)
