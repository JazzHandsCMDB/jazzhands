
PREFIX	?= /var/www/account/directory

all:
	@echo Nothing to build

install:
	mkdir -p $(DESTDIR)/$(PREFIX)
	for f in `sed < debian/jazzhands-account-directory.files -e 's,^$(PREFIX)/,,'` ; do \
		install -m 0755 -d $(DESTDIR)/$(PREFIX)/`dirname $$f` ; \
		install -m 0755 -c $$f $(DESTDIR)/$(PREFIX)/`dirname $$f` ; \
	done

clean:
	rm -rf $(DESTDIR)

distclean: clean
