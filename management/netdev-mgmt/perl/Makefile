SOURCES= \
	JazzHands/NetDev/Mgmt.pm \
	JazzHands/NetDev/Mgmt/ACL.pm \
	JazzHands/NetDev/Mgmt/__devtype/arista.pm \
	JazzHands/NetDev/Mgmt/__devtype/juniper.pm

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
