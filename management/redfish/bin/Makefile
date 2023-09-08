SOURCES= \
	redfish_bmc_reset.pl

all:
	@echo Nothing to build

install:
	mkdir -p $(DESTDIR)/$(PREFIX)
	for f in $(SOURCES); do \
		install -m 0755 -d $(DESTDIR)/$(PREFIX)/sbin/`dirname $$f` ; \
		install -m 0755 -c $$f $(DESTDIR)/$(PREFIX)/sbin/`basename $$f .pl` ; \
	done

clean:
	rm -rf $(DESTDIR)

distclean: clean
