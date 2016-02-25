#!/usr/bin/perl
#
# $Header: bhp.pl                                         Exp $
# $Author: (c) 2016 tokiclover <tokiclover@gmail.com>     Exp $
# $License: MIT (or 2-clause/new/simplified BSD)          Exp $
# $Version: 1.0 2016/02/24                                Exp $
#

use v5.14.0;
use strict;
use warnings;
use File::Temp qw(tempdir);
use Getopt::Std;
$Getopt::Std::STANDARD_HELP_VERSION = 1;
our $VERSION = "1.0";

my(%color, @bg, @fg, %bhp);
my $PR_EOL = "";
$bhp{color} = 1;
($bhp{zero}) = $0 =~ m|(?:.*/)?(\w.+)$|g;
my $name = "bhp";

sub HELP_MESSAGE {
	print <<"EOH"
Usage: $bhp{zero} [OPTIONS] [BROWSER]
  -c 'lzop -1'     Use lzop compressor (default to lz4)
  -t DIR           Set up a particular TMPDIR
  -p PROFILE       Select a particular profile
  -s               Set up tarball archives
  -h, --help       Print help message
  -v, --version    Print version message          
EOH
}

sub VERSION_MESSAGE {
	print "$bhp{zero} version $VERSION\n";
}

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

Many web-broser are supported out of the box. Namely, aurora, firefox, icecat,
seamonkey (mozilla family), conkeror, chrom, epiphany, midory, opera, otter,
qupzilla, netsurf, vivaldi. Specifying a particular web-broser on the command
line is supported along with discovering one in the user home directory (first
found would be used.)

Tarballs archive are used to save user data between session or computer
shutdown/power-on. Speficy -s command line switch to set up the tarball archives
instead of the empty profile.

=head1 FUNCTIONS

Some reusable helpers to format print output for the adventurous ones which can
be copy/pasted to any project or personal script.

=cut

=head2 pr_error

Print error message to stderr

=cut

#
# @FUNCTION: Print error message to stderr
#
sub pr_error {
	my $pfx;
	$pfx = "$color{'fg-magenta'}${name}:$color{reset}" if defined($name);
	print STDERR $PR_EOL;
	print STDERR " $color{'fg-red'}*$color{reset} $pfx ", join ' ', @_;
}

=head2 pr_die

Print error message to stderr and exit program

=cut

#
# @FUNCTION: Print error message to stderr & exit
#
sub pr_die {
	my $ret = shift;
	pr_error(@_);
	exit($ret);
}

=head2 pr_info

Print info message to stdout

=cut

#
# @FUNCTION: Print info message to stdout
#
sub pr_info {
	my $pfx;
	$pfx = "$color{'fg-yellow'}${name}:$color{reset}" if defined($name);
	print $PR_EOL;
	print " $color{'fg-blue'}*$color{reset} $pfx ", join ' ', @_;
}

=head2 pr_warn

Print warning message to stdout

=cut

#
# @FUNCTION: Print warn message to stdout
#
sub pr_warn {
	my $pfx;
	$pfx = " $color{'fg-red'}${name}:$color{reset}" if defined($name);
	print STDOUT $PR_EOL;
	print STDOUT " $color{'fg-yellow'}*$color{reset} $pfx ", join ' ', @_;
}

=head2 pr_begin

Print the beginning of a formated message to stdout

=cut

#
# @FUNCTION: Print begin message to stdout
#
sub pr_begin {
	print "$PR_EOL";
	$PR_EOL = "\n";
	my $pfx;
	$pfx = "${color{'fg-magenta'}}[$color{reset} $color{'fg-blue'}${name}$color{reset} $color{'fg-magenta'}]${color{reset}}"
		 if defined($name);
	print " $pfx ", join ' ', @_;
}

=head2 pr_end

Print the end of a formated message to stdout

=cut

#
# @FUNCTION: Print end message to stdout
#
sub pr_end {
	my($val, $sfx) = (shift);
	if ($val == 0) {
		$sfx="${color{'fg-blue'}}[$color{reset} $color{'fg-green'}Ok$color{reset} $color{'fg-blue'}]$color{reset}";
	} else {
		$sfx="${color{'fg-yellow'}}[$color{reset} $color{'fg-red'}No$color{reset} $color{'fg-yellow'}]$color{reset}";
	}
	print join(' ', @_), " $sfx\n";
	$PR_EOL = "";
}

=head2 yesno

A tiny helper to simplify case incensitive yes/no configuration

=cut

#
# @FUNCTION: YES or NO helper
#
sub yesno {
	my $val = shift // 0;
	if ($val =~ m/0|disable|off|false|no/i) {
		return 0;
	} elsif ($val =~ m/1|enable|on|true|yes/i) {
		return 1;
	} else {
		return undef;
	}
}

=head2 eval_colors

Set up colors for output for the print helper family

=cut

#
# @FUNCTION: Colors handler
#
sub eval_colors {
	my @bc =	('none', 'bold', 'faint', 'italic', 'underline', 'blink',
		'rapid-blink', 'inverse', 'conceal', 'no-italic', 'no-underline',
		'no-blink', 'reveal', 'default'
	);
	my @val = (0..8, 23..25, 28, '39;49');
	my($esc, $bg, $fg, $num, $c) = ("\e[");
	%color = map { $bc[$_], "$esc${val[$_]}m" } 0..$#val;
	$color{'reset'} = "${esc}0m";

	my $tput = `tput colors`;
	if ($tput >= 256) {
		($bg, $fg, $num) = ('48;5;', '38;5;', 256);
	} else {
		($bg, $fg, $num) = (4, 3, 8);
	}

	for $c (0..$num) {
		$bg[$c] = "$esc$bg${c}m";
		$fg[$c] = "$esc$fg${c}m";
	}
	@bc = ('black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white');
	for $c (0..$#bc) {
		$color{"bg-$bc[$c]"} = "$esc$bg${c}m";
		$color{"fg-$bc[$c]"} = "$esc$fg${c}m";
	}
}
#
# Set up colors
#
if (-t STDIN && yesno($bhp{color})) {
	eval_colors();
}

=head2 mount_info

A tiny helper to simplify probing mounted points

=cut

sub mount_info {
	return undef unless defined($_[0]);
	my($MFH, $ret);
	open($MFH, q(<), "/proc/mounts") or pr_die "Failed to open /proc/mounts";
	while (<$MFH>) {
		if (m|$_[0]\b|) { $ret = 1; last; }
		else { $ret = 0 }
	}
	close($MFH);
	$ret;
}

sub find_browser {
	my %browser = (
		'mozilla', [ qw(aurora firefox icecat seamonkey) ],
		'config',  [ qw(conkeror chrom epiphany midory opera otter qupzilla netsurf vivaldi) ],
	);

	if (defined($_[0])) {
	if ($_[0] =~ /.*aurora|firefox.*|icecat|seamonkey/) {
		($bhp{browser}, $bhp{profile}) = ($_[0], "mozilla/$_[0]"); return 0; }
	elsif ($_[0] =~ /conkeror.*|.*chrom.*|epiphany|midory|opera.*|otter.*|qupzilla|netsurf.*|vivaldi.*/) {
		($bhp{browser}, $bhp{profile}) = ($_[0], "config/$_[0]" ); return 0; }
	}

	for my $key (keys %browser) {
		for my $brw (@{$browser{$key}}) {
			for my $dir (glob "$ENV{HOME}/.$key/*${brw}*") {
				if (-d $dir) {
					($bhp{browser}, $bhp{profile}) = ($brw, "$key/$brw"); return 0;
				}
			}
		}
	}
	return 1;
}

sub mozilla_profile {
	if ($_[1] && -d "$ENV{HOME}/.$_[0]/$_[1]" ) {
		$bhp{profile} = "$_[0]/$_[1]"; return 0;
	}

	my $PFH;
	open($PFH, q(<), "$ENV{HOME}/.$_[0]/profiles.ini")
		or pr_die(1, "No firefox profile found");
	while (<$PFH>) {
		if (m/path=(.*$)/i) {
			$bhp{profile} = "$_[0]/$1";
			unless (-d "$ENV{HOME}/.$bhp{profile}") {
				pr_die(2, "No firefox profile dir found");
			}
			last;
		}
	}
	close($PFH);
}

#
# Use a private initializer function
#
sub bhp {
	my($char, $dir, $ext, $head, $profile, $TMPDIR, $tmpdir, %opts);

	#
	# Set up options according to command line options
	#
	getopts('c:hp:st:v', \%opts) or die "Failed to process options";
	if ($opts{h}) { HELP_MESSAGE()   ; exit(0); }
	if ($opts{v}) { VERSION_MESSAGE(); exit(0); }

	$bhp{browser} = $ARGV[0] // $ENV{BROWSER};
	$bhp{compressor} =  defined($opts{c}) ? [split $opts{c} ] : [ qw(lz4 -1 -) ];
	$ext = ".tar.$bhp{compressor}->[0]";
	$TMPDIR = defined($opts{t}) ? $opts{t} : $ENV{TMPDIR} // "/tmp/$ENV{USER}";

	#
	# Set up browser and/or profile directory
	#
	find_browser($bhp{browser});
	unless ($bhp{browser}) {
		pr_error("No browser found.");
		return 1;
	}
	if ($bhp{profile} =~ /mozilla/) {
		mozilla_profile($bhp{profile}, $opts{p});
	}
	($profile) = $bhp{profile} =~ m|/(\w+)$|g;

	#
	# Set up directories for futur use
	#
	$bhp{dirs} = [ "$ENV{HOME}/.$bhp{profile}" ];
	my $cachedir = $bhp{profile} =~ s|config/||r;
	$cachedir = "$ENV{HOME}/.cache/$cachedir";
	push @{$bhp{dirs}}, $cachedir if (-d $cachedir);
	unless(-d $TMPDIR || mkdir($TMPDIR, 0700)) {
		pr_error("No suitable temporary directory found");
		return 2;
	}

	#
	# Finaly, set up temporary bind-mount directories
	#
	for $dir (@{$bhp{dirs}}) {
		unless(chdir "$dir/../") {
			pr_end(1, "Directory");
			next;
		}
		unless (-f "$profile$ext" || -f "$profile.old$ext" ) {
			if (system("tar -Ocp $profile | " . join(' ', @{$bhp{compressor}}) . " $profile$ext")) {
				pr_end(1, "Tarball");
				next;
			}
		} 

		if (mount_info($dir)) {
			bhp_archive($ext, $profile) if ($opts{s});
			next;
		}
		pr_begin("Setting up directory...\n");

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

#
# Set up or (un)compress archive tarballs accordingly
#
sub bhp_archive {
	my($ext, $profile, $tarball) = @_;

	pr_begin("Setting up tarball...\n");
	if (-f "$profile/.unpacked") {
		if (-f "$profile$ext") {
			unless(rename("$profile$ext", "$profile.old$ext")) {
				pr_end(1, "Moving"); 
				return 1;
			}
		}
		unless(system("tar -X $profile/.unpacked -ocp $profile | " . join(' ', @{$bhp{compressor}}) . " $profile$ext")) {
			pr_end(1, "Packing");
			return 2;
		}
	} else {
		if    (-f "$profile$ext"    ) { $tarball = "$profile$ext"     }
		elsif (-f "$profile.old$ext") { $tarball = "$profile.old$ext" }
		else {
			pr_warn("No tarball found.");
			return 3;
		}
		if (system("$bhp{compressor}->[0] -cd $tarball | tar -xp && touch ${profile}/.unpacked")) {
			pr_end(1, "Unpacking");
			return 4;
		}
	}
	pr_end(0);
}

bhp();

__END__
#
# vim:fenc=utf-8:ci:pi:sts=2:sw=2:ts=2:
#