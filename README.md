This utility manage web-browser home profile directory along with the associated
cache directory. It will put those direcories, if any, to a temporary directory
(usualy in a tmpfs or zram backed device directory) to minimize disk seeks and 
improve performance and responsiveness to said web-browser.

Many web-broser are supported out of the box. Namely, aurora, firefox, icecat,
seamonkey (mozilla family), conkeror, chrom{e,ium}, epiphany, midory, opera, otter,
qupzilla, netsurf, vivaldi. Specifying a particular web-broser on the command
line is supported along with discovering one in the user home directory (first
found would be used.)

Tarballs archive are used to save user data between session or computer
shutdown/power-on. However, the shell script will setup archive tarballs
on the first run (no-sourcing). And the python and perl script require
a `-s' command line argument to do so; otherwise, only temporary directories
are set up for the profile and cache directories if any.

**Note:** A Gentoo [ebuild](1) is available on this overlay.

**Note:** This utility is similar to the [profile-sync-daemon](https://github.com/graysky2/profile-sync-daemon)
bash script; but does not rely on the Bourn Shell Again, support others features,
and more importantly, keep a working cache and profile directory no matter what
happen unlike psd.

USAGE
-----

Many browser are supported out of the box, see the script for an extensive list;
or else appending a (supported) browser name on the command line to select a
particular browser. Otherwise, first supported web-browser found would be used.

Specific temporary directory can be specified on the command line with `-t`
command line switch when using a particular set up (e.g. a ZRAM backed filesystem,
see [zram.initd](2) init service for a set up example.)

Using a fast compressor like lz4 would make saving/restoring tarballs lighting
fast (e.g. ~230ms-54% average compression ratio-84.5MB total size for firefox
(profile/cache) compression phase.)

And may be using my [fork](3) of [prezto](4) may be of interest for users
interested in the shell script and sourcing usage instead of a standalone
lone script.

*Warning:* Sourcing capabilities are only relevant for the shell script.

ENVIRONMENT
-----------

**BROWSER**
Set up a default broser to pick when running.

**TMPDIR** (default to `/tmp/$USER`)

Set up tmpfs directory to use using something like the following in
fstab(5) to set up a tmpfs `/tmp`:

	tmp /tmp tmpfs nodev,exec,mode=1777,size=512M 0 0

REQUIREMENTS
------------

`bhp.sh` requires a POSIX Shell, tar, sed and a compressor e.g. lzop (default to lz4.)
`bhp.pl` requires Perl and the previous archive utilities.
`bhp.py` requires Python 2.7.x or 3.x and the previous archive utilities.

INSTALLATION
------------

`make DESTDIR=/tmp PREFIX=/usr/local install` would suffice, or, replace
`install` by `install-perl` or `install-python` for personal convenience.

LICENSE
-------

Distributed under the 2-clause/new/simplifed BSD License

[1]: https://github.com/tokiclover/bar-overlay
[2]: https://github.com/tokiclover/mkinitramfs-ll/tree/master/svc
[3]: https://github.com/tokiclover/prezto
[4]: https://github.com/sorin-ionescu/prezto

