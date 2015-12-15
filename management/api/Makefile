SPECFILE=JazzHands-Apache-API.spec

INSTBASE=/usr/libexec/jazzhands/api
DESTDIR=$(shell pwd)/fakeroot
TOPDIR=$(shell pwd)/haterpm
NAME := $(shell perl -ne 'if (/^Name:/) { print ((split /\s+/)[1]), "\n"}' $(SPECFILE))
VERSION := $(shell perl -ne 'if (/^Version:/) { print ((split /\s+/)[1]), "\n"}' debian.control)
SOURCES= \
	lib/JazzHands/Apache/API/Common.pm \
	lib/JazzHands/Apache/API/Container.pm

all:
	@echo Nothing to build

install:
	mkdir -p $(DESTDIR)/$(INSTBASE)
	for f in $(SOURCES); do \
		install -m 0755 -d $(DESTDIR)/$(INSTBASE)/`dirname $$f` ; \
		install -m 0755 -c $$f $(DESTDIR)/$(INSTBASE)/`dirname $$f` ; \
	done

buildpkg:
	rm -rf haterpm
	mkdir -p $(TOPDIR) $(TOPDIR)/BUILD $(TOPDIR)/RPMS $(TOPDIR)/SOURCES \
		$(TOPDIR)/SPECS $(TOPDIR)/SRPMS $(DESTDIR)/$(NAME)-$(VERSION)
	rsync -avPR $(NAME).spec Makefile $(SOURCES) $(DESTDIR)/$(NAME)-$(VERSION)
	tar cvCfz $(DESTDIR) $(TOPDIR)/SOURCES/$(NAME)-$(VERSION).tar.gz \
		$(NAME)-$(VERSION)
	rpmbuild --define "_topdir $(TOPDIR)" -bb $(SPECFILE)

buildpkg-deb:
	rm -rf fakeroot
	mkdir -p $(DESTDIR)/$(NAME)-$(VERSION)
	rsync -avPR $(NAME).spec Makefile $(SOURCES) $(DESTDIR)/$(NAME)-$(VERSION)
	mkdir $(DESTDIR)/$(NAME)-$(VERSION)/debian
	rsync -avPR Makefile debian $(SOURCES) $(DESTDIR)/$(NAME)-$(VERSION)
	(cd $(DESTDIR)/$(NAME)-$(VERSION) && debuild -us -uc )

clean:
	rm -rf $(TOPDIR) $(DESTDIR)
