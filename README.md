Browser-Home-Profile is a POSIX shell script maintaining temprary home profile
and the associated cache directory with an optional tarball back up. Note that,
the tarball can be optional when the script is sourced in a shell
(e.g `~/.{ba,z}shrc`); otherwise a tarball would be set up (saved or restored
from profile directory.) Sourcing usage can be used to set up a clean and temprary
profile instead of the usaual tarball set up.

(A Gentoo [ebuild](1) is avail on this overlay.)

USAGE
-----

Many browser are supported out of the box, see the script for an extensive list;
or else appending a (supported) browser name on the command line with or without
`-b|--browser` switch would rightly select a particular browser. Otherwise, first
supported web-browser match would be used.

Specific temporary directory can be specified on the command line with
`-t|--tmpdir` command line switch when using a particular set up (e.g. a ZRAM
backed filesystem, see [zram.initd](2) init service.)

Using a fast compressor like lz4 would make saving/restoring tarballs lighting
fast (e.g. ~230ms-54% average compression ratio-84.5MB total size for
firefox (profile/cache) compression phase.)

ENVIRONMENT
-----------

**BROWSER**
Set up a default broser to pick when running bhp without `-b|--browser`
command line switch.

**TMPDIR**`:=/tmp/.private/$USER`

Set up tmpfs directory to use using something like the following in
fstab(5) to set up a tmpfs `/tmp`:

	tmp /tmp tmpfs nodev,exec,mode=1777,size=512M 0 0

REQUIREMENTS
------------

BHP requires a POSIX shell, tar, sed and a compressor e.g. lzop (default to lz4.)

INSTALLATION
------------

`make DESTDIR=/tmp PREFIX=/usr/local` would suffice.

LICENSE
-------

Distributed under the 2-clause/new/simplifed BSD License

[1]:https://github.com/tokiclover/bar-overlay
[2]:https://github.com/tokiclover/mkinitramfs-ll/tree/master/svc

