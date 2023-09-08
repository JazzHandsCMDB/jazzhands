PREFIX ?= /usr/libexec/jazzhands/sync-prefix-lists
SOURCES= \
	sync-prefix-lists.pl

all:
	@echo Nothing to build

install:
	mkdir -p $(DESTDIR)/$(PREFIX)
	for f in $(SOURCES); do \
		install -m 0755 -d $(DESTDIR)/$(PREFIX)/`dirname $$f` ; \
		install -m 0755 -c $$f $(DESTDIR)/$(PREFIX)/`basename $$f .pl` ; \
	done

clean:
	rm -rf $(DESTDIR)

distclean: clean
