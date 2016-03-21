#!/usr/bin/perl
#
# $Header: bhp.pl                                         Exp $
# $Author: (c) 2016 tokiclover <tokiclover@gmail.com>     Exp $
# $License: MIT (or 2-clause/new/simplified BSD)          Exp $
# $Version: 1.4 2016/03/08                                Exp $
#

use v5.14.0;
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Basename;
use File::Tmpdir::Functions qw(:print :misc :color);
use Getopt::Std;
use POSIX qw(pause);
our $VERSION = "1.3";
my (%bhp_info, %opts);
$bhp_info{zero} = basename($0);
$Getopt::Std::STANDARD_HELP_VERSION = 1;
$File::Tmpdir::Functions::NAME = $bhp_info{zero};

sub HELP_MESSAGE {
	print <<"EOH"
Usage: $bhp_info{zero} [OPTIONS] [BROWSER]
  -c 'lzop -1'     Use lzop compressor (default to lz4)
  -d 300           Sync time (in sec) when daemonized
  -t DIR           Set up a particular TMPDIR
  -p PROFILE       Select a particular profile
  -s               Set up tarball archives
  -h, --help       Print help message
  -v, --version    Print version message          
EOH
}

sub VERSION_MESSAGE {
	print "$bhp_info{zero} version $VERSION\n";
}

#
# Handle window resize signal
#
$SIG{WINCH} = \&sigwinch_handler;

sub sigalrm_handler {
	for my $dir (@{$bhp_info{dirs}}) {
		unless(chdir dirname($dir)) {
			pr_end(1, "Directory");
			next;
		}
		bhp_archive('.tar.' . (split /\s/, $bhp_info{compressor})[0], basename($bhp_info{profile}));
	}
}
$SIG{ALRM} = \&sigalrm_handler;

=head1 SYNOPSIS

bhp.pl [OPTIONS] [BROWSER] (see bhp.pl --help for the optional switches)

% bhp.pl -t /var/tmp # to use a particualr temporary directory

% bhp.pl -p 1234abc.default firefox # to specify a particular profile to use

=cut

=head1 DESCRIPTION

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
shutdown/power-on. Speficy -s command line switch to set up the tarball archives
instead of the empty profile.

=head1 FUNCTIONS

=head2 find_browser()

Find a browser to setup

=cut

sub find_browser {
	my($browser, $profile) = @_;
	my %browser = (
		'mozilla', [ qw(aurora firefox icecat seamonkey) ],
		'config',  [ qw(conkeror chrome chromium epiphany midory opera otter qupzilla netsurf vivaldi) ],
	);

	if (defined($browser)) {
		for my $key (keys %browser) {
			if (grep { $_ eq $browser } @{$browser{$key}}) {
				($bhp_info{browser}, $bhp_info{profile}) = ($browser, $key . "/" . $browser);
				return 0;
			}
		}
	}

	for my $key (keys %browser) {
		for $browser (@{$browser{$key}}) {
			if (-d "$ENV{HOME}/.$key/$browser") {
				($bhp_info{browser}, $bhp_info{profile}) = ($browser, "$key/$browser");
				return 0;
			}
		}
	}
	return 1;
}

=head2 mozilla_profile([browser, profile])

Find a Mozilla family browser profile

=cut

sub mozilla_profile {
	my($browser, $profile) = @_;
	if ($profile and -d "$ENV{HOME}/.$browser/$profile" ) {
		$bhp_info{profile} = "$browser/$profile"; return 0;
	}

	my $PFH;
	open($PFH, q(<), "$ENV{HOME}/.$browser/profiles.ini")
		or pr_die(1, "No mozilla profile found");
	while (<$PFH>) {
		if (m/path=(.*$)/i) {
			$bhp_info{profile} = "$browser/$1";
			unless (-d "$ENV{HOME}/.$bhp_info{profile}") {
				pr_die(2, "No firefox profile dir found");
			}
			last;
		}
	}
	close($PFH);
}

=head2 bhp()

Profile initializer function and temporary directories setup

=cut

sub bhp {
	my($char, $dir, $ext, $head, $profile, $TMPDIR, $tmpdir);
	$ext = '.tar.' . (split /\s/, $bhp_info{compressor})[0];
	$TMPDIR = defined($opts{t}) ? $opts{t} : $ENV{TMPDIR} // "/tmp/$ENV{USER}";

	#
	# Set up browser and/or profile directory
	#
	find_browser($bhp_info{browser});
	unless ($bhp_info{browser}) {
		pr_error("No browser found.");
		return 1;
	}
	if ($bhp_info{profile} =~ /mozilla/) {
		mozilla_profile($bhp_info{profile}, $opts{p});
	}
	$profile = basename($bhp_info{profile});

	#
	# Set up directories for futur use
	#
	$bhp_info{dirs} = [ "$ENV{HOME}/.$bhp_info{profile}" ];
	my $cachedir = $bhp_info{profile} =~ s|config/||r;
	$cachedir = "$ENV{HOME}/.cache/$cachedir";
	push @{$bhp_info{dirs}}, $cachedir if (-d $cachedir);
	unless(-d $TMPDIR || mkdir($TMPDIR, 0700)) {
		pr_error("No suitable temporary directory found");
		return 2;
	}

	#
	# Finaly, set up temporary bind-mount directories
	#
	for $dir (@{$bhp_info{dirs}}) {
		unless(chdir dirname($dir)) {
			pr_end(1, "Directory");
			next;
		}
		unless (-f "$profile$ext" || -f "$profile.old$ext" ) {
			system('tar', '-X', "$profile/.unpacked", '-cpf', "$profile$ext",
			       '-I', $bhp_info{compressor}, $profile);
			if ($?) {
				pr_end(1, "Tarball");
				next;
			}
		} 

		if (mount_info($dir)) {
			bhp_archive($ext, $profile) if ($opts{s});
			next;
		}
		pr_begin("Setting up directory... ");

		if ($dir =~ /cache/) { $char = 'c' }
		else { $char = 'b' }
		$tmpdir = tempdir("${char}hpXXXXXX", DIR => $TMPDIR);
		if (system('sudo', 'mount', '--bind', $tmpdir, $dir)) {
			pr_end(1, "Mounting");
			next;
		}
		pr_end("$?");
	
		bhp_archive($ext, $profile) if ($opts{s});
	}
}

=head2 bhp_archive(ext, profile)

Set up or (un)compress archive tarballs accordingly

=cut

sub bhp_archive {
	my($ext, $profile, $tarball) = @_;

	pr_begin("Setting up tarball... ");
	if (-f "$profile/.unpacked") {
		if (-f "$profile$ext") {
			unless(rename("$profile$ext", "$profile.old$ext")) {
				pr_end(1, "Moving"); 
				return 1;
			}
		}
		system('tar', '-X', "$profile/.unpacked", '-cpf', "$profile$ext",
		       '-I', $bhp_info{compressor}, $profile);
		pr_end(1, "Packing") if ($?);
	}
	else {
		if    (-f "$profile$ext"    ) { $tarball = "$profile$ext"     }
		elsif (-f "$profile.old$ext") { $tarball = "$profile.old$ext" }
		else {
			pr_warn("No tarball found.");
			next;
		}
		system('tar', '-xpf', "$profile$ext", '-I', $bhp_info{compressor});
		if ($?) {
			pr_end(1, "Unpacking");
			return 4;
		}
		else {
			open(my $fh, '>', "$profile/.unpacked")
				or die "Failed to open $profile/.unpacked: $!";
			close($fh);
		}
	}
	pr_end(0);
}

=head2 bhp_daemon(duration)

Simple deamon to handle syncing the tarball archive to disk

=cut

sub bhp_daemon {
  my $arg = shift // 300;
	while (1) {
		alarm($arg);
		POSIX::pause();
	}
}

if (__PACKAGE__ eq "main") {
	#
	# Set up options according to command line options
	#
	getopts('c:d:hp:st:v', \%opts) or die "Failed to process options";
	if ($opts{h}) { HELP_MESSAGE()   ; exit(0); }
	if ($opts{v}) { VERSION_MESSAGE(); exit(0); }
	$bhp_info{daemon} = $opts{d} // 0;
	$bhp_info{browser} = $ARGV[0] // $ENV{BROWSER};
	$bhp_info{compressor} =  defined($opts{c}) ? $opts{c} : 'lz4 -1';
	$bhp_info{color} = $ENV{PRINT_COLOR} // 1;

	bhp();
	bhp_daemon() if $bhp_info{daemon};
}

__END__

=head1 AUTHOR

tokiclover <tokiclover@gmail.com>

=cut

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the MIT License or under the same terms as Perl itself.

=cut

#
# vim:fenc=utf-8:ci:pi:sts=2:sw=2:ts=2:
#
