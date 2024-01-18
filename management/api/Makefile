PREFIX ?= /usr/libexec/jazzhands/api

SOURCES= \
	JazzHands/Apache/API/Device.pm \
	JazzHands/Apache/API/Common.pm \
	JazzHands/Apache/API/Container.pm

all:
	@echo Nothing to build

install:
	mkdir -p $(DESTDIR)/$(PREFIX)
	for f in $(SOURCES); do \
		install -m 0755 -d $(DESTDIR)/$(PREFIX)/`dirname $$f` ; \
		install -m 0755 -c lib/$$f $(DESTDIR)/$(PREFIX)/`dirname $$f` ; \
	done

clean:
	rm -rf $(DESTDIR)

distclean: clean
