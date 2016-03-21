#!/usr/bin/perl
#
# $Header: tmpdirs.pl                                     Exp $
# $Author: (c) 2016 tokiclover <tokiclover@gmail.com>     Exp $
# $License: MIT (or 2-clause/new/simplified BSD)          Exp $
# $Version: 1.2 2016/03/18                                Exp $
#

use v5.14.0;
use strict;
use warnings;
use File::Basename;
use File::Tmpdir qw(:zram :tmpdir);
use File::Tmpdir::Functions qw(:misc);
use Getopt::Std;
my $zero = basename($0);
our $VERSION = "1.0";
$Getopt::Std::STANDARD_HELP_VERSION = 1;
$File::Tmpdir::Functions::NAME = $zero;
$SIG{WINCH} = \&sigwinch_handler;

sub HELP_MESSAGE {
	print <<"EOH"
Usage: $zero [OPTIONS] [--boot] [--tmpdir-prefix=DIRECTORY] [ZRAM_DEVICES]
  -z 8             Setup ZRAM devices number (default to 4)
  -c lzo           Setup ZRAM compressor (default to lz4)
  -s 4             Setup ZRAM stream number per device (deafault to 2)
  -p /var/tmp      Setup temporary directory hierarchy
  -C 'lzop -1'     Setup tmpdir compressor (default to lz4)
  -t /var/log      Setup archived temporary directory
  -T /var/run      Setup unarchived temporary directory
  -b               Run subsystem initialization (kernel module)
  -h, --help       Print help message
  -v, --version    Print version message

Example:
* \`$zero "512m swap" "8G ext4 /var/tmp 0755 user_xattr"' to create two devices
* \`$zero -p /var/tmp -t /var/log' to create a new (tmpfs) temporary-directory
     and have /var/log bind mounted to /var/tmp/log plus /var/log.tar.lz4 archive
* \`$zero -b -p /var/tmp -t /var/log "8G ext4 /var/tmp 1777"'
     to chain a temporary directory hierarchy on top of zram
EOH
}
sub VERSION_MESSAGE {
	print "$zero version $VERSION\n"
}

unless (@ARGV) { HELP_MESSAGE(); exit(0); }
my (%tmpdir_ARGS, %zram_ARGS, %OPTS);
getopts('bC:c:hs:T:t:p:vz:', \%OPTS) or die "Failed to process arguments";
if ($OPTS{h}) { HELP_MESSAGE()   ; exit(0); }
if ($OPTS{v}) { VERSION_MESSAGE(); exit(0); }

$tmpdir_ARGS{saved}      = [split /[\s,]/, $OPTS{t}] if defined($OPTS{t});
$tmpdir_ARGS{unsaved}    = [split /[\s,]/, $OPTS{T}] if defined($OPTS{T});
$tmpdir_ARGS{prefix}     = $OPTS{p} if defined($OPTS{p});
$tmpdir_ARGS{compressor} = $OPTS{C} if defined($OPTS{C});
$zram_ARGS{boot_setup}   = $OPTS{b} if defined($OPTS{b});
$zram_ARGS{compressor}   = $OPTS{c} if defined($OPTS{c});
$zram_ARGS{num_dev}      = $OPTS{z} if defined($OPTS{z});
$zram_ARGS{streams}      = $OPTS{s} if defined($OPTS{s});

for my $dev (@ARGV) {
	zram_setup(%zram_ARGS, device => $dev);
}
if (defined($tmpdir_ARGS{prefix})) {
	tmpdir_setup(%tmpdir_ARGS);
}
elsif (defined($tmpdir_ARGS{saved})) {
	tmpdir_save($tmpdir_ARGS{saved});
}

__END__
#
# vim:fenc=utf-8:ci:pi:sts=2:sw=2:ts=2:
#
