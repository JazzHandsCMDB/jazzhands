INSTBASE=/usr/lib/perl5/vendor_perl
DIRS=AppAuthAL LDAP DBI

all: $(addprefix all_,$(DIRS))

install: $(addprefix install_,$(DIRS))

buildpkg: $(addprefix buildpkg_,$(DIRS))

clean: $(addprefix clean_,$(DIRS))
	rm -rf haterpm

all_%:
	(cd $* && perl Makefile.PL LIB=$(INSTBASE) && $(MAKE) pure_all)

install_%:
	(cd $* && $(MAKE) DESTDIR=`pwd`/../fakeroot.$* pure_vendor_install)

buildpkg_%:
	rm -rf `pwd`/haterpm
	mkdir -p `pwd`/haterpm/RPMS
	rpmbuild --define "_topdir ./haterpm" --buildroot `pwd`/fakeroot.$* -bb --short-circuit perl-JazzHands-$*.spec

clean_%:
	rm -rf fakeroot.$*
	(cd $* && ([ ! -f Makefile ] || make clean) && rm -f Makefile.old)

