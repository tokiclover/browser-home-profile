PACKAGE     = browser-home-profile
VERSION     = $(shell sed -nre '3s/(.*):/\1/p' ChangeLog)

PREFIX      = /usr/local
EXEC_PREFIX = $(PREFIX)
BINDIR      = $(PREFIX)/bin
SBINDIR     = $(EXEC_PREFIX)/sbin
LIBDIR      = $(EXEC_PREFIX)/lib
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
	$(SBINDIR) $(BINDIR) $(DOCDIR)/$(PACKAGE)-$(VERSION) $(LIBDIR)/tmpdir/sh
DISTDIRS    = $(dist_DIRS)

FORCE:

.PHONY: FORCE all install install-doc install-dist

all:

install: install-dir install-dist
	$(install_SCRIPT) bhp.sh     $(DESTDIR)$(BINDIR)/
	$(install_SCRIPT) tmpdirs.sh $(DESTDIR)$(SBINDIR)/
	$(install_DATA) sh/functions.sh $(DESTDIR)$(LIBDIR)/tmpdir/sh
	sed -e 's:"\$${0%/\*}":"$(LIBDIR)":g' -i \
		$(DESTDIR)$(SBINDIR)/tmpdirs.sh \
		$(DESTDIR)$(BINDIR)/bhp.sh
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

