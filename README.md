**Note:** A Gentoo [ebuild](1) is available in this overlay for this package.
**Note:** *EXTENSION* is either {sh,py,pl} for POSIX compliant shell script,
Python (2.7.x or 3.x) or Perl in the following sections.

Using the Perl or Python variant would install, rightly, a reusable module:
`File::Tmpdir{,::Functions}` for Perl and `tmpdir/{__init__,functions}.py` for Python.
Read the following section for more on the description and usage of the utilities.

DESCRIPTION
-----------

# bhp.EXTENSION (browser-home-profile)

This utility manage web-browser home profile directory along with the associated
cache directory. It will put those direcories, if any, to a temporary directory
(usualy in a tmpfs or zram backed device directory) to minimize disk seeks and 
improve performance and responsiveness to said web-browser.

Many web-browser are supported out of the box. Namely, aurora, firefox, icecat,
seamonkey (mozilla family), conkeror, chrom{e,ium}, epiphany, midory, opera, otter,
qupzilla, netsurf, vivaldi. Specifying a particular web-browser on the command
line is supported along with discovering one in the user home directory (first
found would be used.)

Tarballs archive are used to save user data between session or computer
shutdown/power-on. Add a `-s' command line argument to do so; otherwise,
only temporary directories are set up for the profile and cache if any.

**Note:** This utility is similar to the [profile-sync-daemon](https://github.com/graysky2/profile-sync-daemon)
bash script; but does not rely on the Bourn Shell Again, support others features,
and more importantly, keep a working cache and profile directory no matter what
happen unlike psd.

**Note:** `bhp.sh` can be sourced to a login shell; just run `bhp_init_profile -s`
with some arguments or none for atomatic setup; and the subsequent `bhp` command
would keep updating the tarball.

# tmpdirs.EXTENSION

This utility is used to setup temporary directory stack upon the usual tmpfs
or on top of ZRAM, if supported, for efficient RAM space usage.

Typicaly, this utility can be used to setup some temporary directories, like
`/var/tmp` or more widely used `/tmp` to tmpfs or ZRAM backed device for space
usage efficiency. This would make heavy temporary usage more efficient and keep
the system responsiveness at check. See, the previous sub-section for a use case.

If the boot-up is strict and access to `/usr` is not availabe... using the shell
variant is more a propos too this kind of usage.

DOCUMENTATION
-------------

This file for the shell scripts; or use `perldoc` or `pydoc` on the script/module
files for the Perl and/or Python variant.

USAGE
-----

# bhp.EXTENSION (browser-home-profile)

Many browser are supported out of the box, see the script for an extensive list;
or else appending a (supported) browser name on the command line to select a
particular browser. Otherwise, first supported web-browser found would be used.

Specific temporary directory can be specified on the command line with `-t`
command line switch when using a particular set up (e.g. a ZRAM backed filesystem,
see [zram.initd](2) init service for a setup example or the tmpdirs.EXTENSION
sub-section for another one shot solution.)

Using a fast compressor like lz4 would make saving/restoring tarballs lighting
fast (e.g. ~230ms-54% average compression ratio-84.5MB total size for firefox
(profile/cache) compression phase.)

And may be using my [fork](3) of [prezto](4) may be of interest for users
interested in the shell script and sourcing usage instead of a standalone
lone script.

*Warning:* Sourcing capabilities are only relevant for the shell script.

# tmpdirs.EXTENSION

    `tmpdirs.EXTENSION '1G swap' '4G ext4 /var/tmp 1777 user_xattr'` to setup two devices.
	`tmpdirs.EXTENSION --tmpdir-prefix=/var/tmp --tmpdir-saved=/var/log` to setup
	a temporary directory hierarchy in `/var/tmp`, plus bind-mounting `/var/log`
	to `/var/tmp/var/log` for temporary storage.

ENVIRONMENT
-----------

# bhp.EXTENSION (browser-home-profile)

**BROWSER**
Set up a default browser to pick when running.

**TMPDIR** (default to `/tmp/$USER`)

Set up tmpfs directory to use using something like the following in
fstab(5) to set up a tmpfs `/tmp`:

	tmp /tmp tmpfs nodev,exec,mode=1777,size=512M 0 0

# tmpdirs.EXTENSION

None

REQUIREMENTS
------------

# bhp.EXTENSION (browser-home-profile)

`bhp.sh` requires a POSIX Shell, tar, sed and a compressor e.g. lzop (default to lz4.)
`bhp.pl` requires Perl and the previous archive utilities.
`bhp.py` requires Python 2.7.x or 3.x and the previous archive utilities.

# tmpdirs.EXTENSION

Same as above for `tmpdirs.p{l,y}` scripts.

INSTALLATION
------------

# Shell scripts

`make DESTDIR=/tmp PREFIX=/usr/local install` would suffice.

# Perl scripts

`perl Makefile.PL; make -f Makefile_PL install DESTDIR=/tmp INSTALLDIRS=vendor`
would suffice.

# Python scripts

`python setup.py install --root /tmp --compile` would suffice.

LICENSE
-------

Distributed under MOIT or the 2-clause/new/simplifed BSD License

[1]: https://github.com/tokiclover/bar-overlay
[2]: https://github.com/tokiclover/mkinitramfs-ll/tree/master/svc
[3]: https://github.com/tokiclover/prezto
[4]: https://github.com/sorin-ionescu/prezto

