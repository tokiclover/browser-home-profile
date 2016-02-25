PACKAGE     = browser-home-profile
VERSION     = $(shell sed -nre '3s/(.*):/\1/p' ChangeLog)

PREFIX      = /usr/local
BINDIR      = $(PREFIX)/bin
DATADIR     = $(PREFIX)/share
DOCDIR      = $(DATADIR)/doc
MANDIR      = $(DATADIR)/man

INSTALL     = install
install_SCRIPT = $(INSTALL) -m 755
install_DATA   = $(INSTALL) -m 644
MKDIR_P     = mkdir -p

dist_EXTRA  = \
	AUTHORS \
	COPYING \
	README.md \
	ChangeLog

DISTFILES   = $(dist_EXTRA)
dist_DIRS  += \
	$(BINDIR) $(DOCDIR)/$(PACKAGE)-$(VERSION)
DISTDIRS    = $(dist_DIRS)

FORCE:

.PHONY: FORCE all install install-doc install-dist

all:

install: install-dir install-dist
	$(install_SCRIPT) bhp.sh $(DESTDIR)$(BINDIR)/
install-dist: $(DISTFILES)
install-dir :
	$(MKDIR_P) $(dist_DIRS:%=$(DESTDIR)%)
install-doc : $(dist_EXTRA)

$(dist_EXTRA): FORCE
	$(install_DATA) $@ $(DESTDIR)$(DOCDIR)/$(PACKAGE)-$(VERSION)/$@

.PHONY: uninstall uninstall-doc uninstall-dist

uninstall: uninstall-doc
	rm -f $(dist_SCRIPTS:%=$(DESTDIR)$(BINDIR)/%)
uninstall-doc:
	rm -f $(dist_EXTRA:%=$(DESTDIR)$(DOCDIR)/$(PACKAGE)-$(VERSION)/%)

.PHONY: clean

clean:

