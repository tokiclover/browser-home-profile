#
# $Header: File::Tmpdir                                   Exp $
# $Author: (c) 2016 tokiclover <tokiclover@gmail.com>     Exp $
# $License: MIT (or 2-clause/new/simplified BSD)          Exp $
# $Version: 1.3 2016/03/18                                Exp $
#

package File::Tmpdir::Functions;
use v5.14.0;
use strict;
use warnings;
use Exporter;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
our (%COLOR, @BG, @FG, %PRINT_INFO, $NAME);
$VERSION = "1.3";
($PRINT_INFO{cols}, $PRINT_INFO{len}, $PRINT_INFO{eol}) = (tput('cols', 1), 0, "");
eval_colors(tput('colors', 1));

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(
	pr_info pr_warn pr_error pr_begin pr_end pr_die
	eval_colors mount_info sigwinch_handler tput yesno
	%COLOR @BG @FG $NAME
);
%EXPORT_TAGS = (
	print  => [qw(pr_info pr_warn pr_error pr_begin pr_end pr_die)],
	misc   => [qw(eval_colors tput mount_info yesno)],
	color  => [qw(%COLOR @BG @FG)],
);

=head1 NAME

File::Tmpdir::Functions - Print and miscellaneous functions

=cut

=head1 SYNOPSIS

    use File::Tmpdir qw(:color :print :misc);

=cut

=head1 DESCRIPTION

    use File::Tmpdir qw(:print);

Some reusable helpers to format print output prepended with C<name:> or C<[name]>
(name refer to global C<$File::Tmpdir::NAME>) with ANSI color (escapes)  support.

    use File::Tmpdir qw(:color);

C<%COLOR> hold the usual color attributes e.g. C<$COLOR{bold}>, C<$COLOR{reset}>,
C<$COLOR{underline}> etc; and the common 8 {back,fore}ground named colors prefixed
with C<{bg,fg}-> e.g. C<$COLOR{'fg-blue'}>, C<$COLOR{'bg-yellow'}> etc.
C<@FG> and C<@BG> hold the numeral colors, meaning that, C<@FG[0..255]> and
C<@BG[0..255]> are usable after a C<eval_colors(256)> initialization call.
C<@BG[0..7]> and C<@FG[0..7]> being the named colors included in C<%COLOR>.

=cut

=head1 FUNCTIONS

=cut

=head2 pr_error(str)

Print error message to stderr e.g.:

    pr_error("Failed to do this");

=cut

sub pr_error {
	my ($msg, $pfx) = (join ' ', @_);
	$PRINT_INFO{len} = length($msg)+length($NAME)+2;

	$pfx = "$COLOR{'fg-magenta'}${NAME}:$COLOR{reset}" if defined($NAME);
	print STDERR "$PRINT_INFO{eol}$COLOR{'fg-red'}:ERROR:$COLOR{reset} $pfx $msg\n";
}

=head2 pr_die(err, str)

Print error level message to stderr and exit program like C<die> would do.

    pr_die($?, "Failed to launch $command!");

=cut

sub pr_die {
	my $ret = shift;
	pr_error(@_);
	exit($ret);
}

=head2 pr_info(str)

Print info level message to stdout.

    pr_info("Running perl $] version.");

=cut

sub pr_info {
	my ($msg, $pfx) = (join ' ', @_);
	$PRINT_INFO{len} = length($msg)+length($NAME)+2;

	$pfx = "$COLOR{'fg-yellow'}${NAME}:$COLOR{reset}" if defined($NAME);
	print "$PRINT_INFO{eol}$COLOR{'fg-blue'}INFO:$COLOR{reset} $pfx $msg\n";
}

=head2 pr_warn(str)

Print warning level message to stdout.

    pr_warn("Configuration file not found.");

=cut

sub pr_warn {
	my ($msg, $pfx) = (join ' ', @_);
	$PRINT_INFO{len} = length($msg)+length($NAME)+2;

	$pfx = "$COLOR{'fg-red'}${NAME}:$COLOR{reset}" if defined($NAME);
	print STDOUT "$PRINT_INFO{eol}$COLOR{'fg-yellow'}WARN:$COLOR{reset} $pfx $msg\n";
}

=head2 pr_begin(str)

Print the beginning of a formated message to stdout.

    pr_begin("Mounting device");

=cut

sub pr_begin {
	my ($msg, $pfx) = (join ' ', @_);
	print $PRINT_INFO{eol} if defined($PRINT_INFO{eol});
	$PRINT_INFO{eol} = "\n";
	$PRINT_INFO{len} = length($msg)+length($NAME)+2;
	$pfx = "${COLOR{'fg-magenta'}}[$COLOR{'fg-blue'}${NAME}$COLOR{'fg-magenta'}]$COLOR{reset}"
		 if defined($NAME);
	printf "%s", "$pfx $msg";
}

=head2 pr_end(err[, str])

Print the end of a formated message to stdout which is just a colored C<[Ok]>
or C<[No]> (if no further arguments are found) after running a commmand.

    pr_end($?);

=cut

sub pr_end {
	my ($val, $sfx) = (shift);
	my $msg = join ' ', @_;
	my $len = $PRINT_INFO{cols} - $PRINT_INFO{len};

	if ($val == 0) {
		$sfx="${COLOR{'fg-blue'}}[$COLOR{'fg-green'}Ok$COLOR{'fg-blue'}]$COLOR{reset}";
	} else {
		$sfx="${COLOR{'fg-yellow'}}[$COLOR{'fg-red'}No$COLOR{'fg-yellow'}]$COLOR{reset}";
	}
	printf "%${len}s\n", "$msg $sfx";
	($PRINT_INFO{eol}, $PRINT_INFO{len}) = ('', 0);
}

=head2 yesno([01]|{true|false|etc})

A tiny helper to simplify case incensitive yes/no configuration querries.

=cut

sub yesno {
	my $val = shift // 0;
	if ($val =~ m/0|disable|off|false|no/i) {
		return 0;
	}
	elsif ($val =~ m/1|enable|on|true|yes/i) {
		return 1;
	}
	else { return }
}

=head2 eval_colors(NUMBER)

Set up colors (used for output for the print helper family.) Default to 8 colors,
if no argument passed. Else, valid argument would be 8 or 256.

=cut

sub eval_colors {
	my $NUM = shift // 0;
	my @bc = ('none', 'bold', 'faint', 'italic', 'underline', 'blink',
		'rapid-blink', 'inverse', 'conceal', 'no-italic', 'no-underline',
		'no-blink', 'reveal', 'default'
	);
	my @val = (0..8, 23..25, 28, '39;49');
	my ($esc, $bg, $fg, $num, $c) = ("\e[");
	%COLOR = map { $bc[$_], "$esc${val[$_]}m" } 0..$#val;
	$COLOR{'reset'} = "${esc}0m";

	if ($NUM >= 256) {
		($bg, $fg, $num) = ('48;5;', '38;5;', $NUM-1);
	}
	elsif ($NUM == 8) {
		($bg, $fg, $num) = (4, 3, $NUM-1);
	}

	for $c (0..$num) {
		$BG[$c] = "$esc$bg${c}m";
		$FG[$c] = "$esc$fg${c}m";
	}
	@bc = ('black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white');
	for $c (0..$#bc) {
		$COLOR{"bg-$bc[$c]"} = "$esc$bg${c}m";
		$COLOR{"fg-$bc[$c]"} = "$esc$fg${c}m";
	}
}

=head2 mount_info ([OPT,] DIR|DEV [,FILE])

A tiny helper to simplify probing usage of mounted points or device, swap
device and kernel module.

    mount_info('-s', '/dev/zram0'); # whether the specified device is swap
    mount_info('-m', 'zram)       ; # whether the kernel module is loaded
    mount_info('/dev/zram1')      ; # whether the specified device is mounted

=cut

sub mount_info {
	my ($opt, $file) = shift;
	return unless defined($opt);

	if ($opt eq "-s") {
		$file = "/proc/swaps";
		$opt = shift;
	}
	elsif ($opt eq "-m") {
		$file = "/proc/modules";
		$opt = shift;
	}
	else {
		$file = "/proc/mounts" unless defined($file);
	}

	my ($FILE, $ret);
	unless (open($FILE, q(<), $file)) {
		pr_error("Failed to open $file: $!");
		return;
	}
	while (<$FILE>) {
		if (m|$opt\b|) { $ret = 1; last; }
		else { $ret = 0 }
	}
	close($FILE);
	return $ret;
}

=head2 sigwinch_handler()

Handle window resize signal to update the colon length of the terminal.

=cut

sub sigwinch_handler {
	$PRINT_INFO{cols} = tput('cols', 1);
}
#$SIG{WINCH} = \&sigwinch_handler;

=head2 tput(cap[, 1])

Simple helper to querry C<terminfo(5)> capabilities without a shell (implied by
the `cmd` construct.) Second argument enable integer conversion.

    tput('cols', 1); # to get the actual terminal colon length

=cut

sub tput {
	my ($cap, $conv) = @_;
	return unless defined($cap);
	open(my $TPUT, '-|', 'tput', $cap) or die "Failed to launch tput: $!";
	chomp(my @val = <$TPUT>);
	close($TPUT);
	return int($val[0]) if yesno($conv);
	return @val;
}

1;
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
