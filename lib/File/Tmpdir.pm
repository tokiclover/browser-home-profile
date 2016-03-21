#
# $Header: File::Tmpdir                                   Exp $
# $Author: (c) 2016 tokiclover <tokiclover@gmail.com>     Exp $
# $License: MIT (or 2-clause/new/simplified BSD)          Exp $
# $Version: 1.3 2016/03/18                                Exp $
#

package File::Tmpdir;
use v5.14.0;
use strict;
use warnings;
use File::Path qw(mkpath rmtree);
use File::Tmpdir::Functions qw(:print :misc);
use Exporter;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
our (%COLOR, @BG, @FG, %PRINT_INFO, $NAME);
$VERSION = "1.3";
($PRINT_INFO{cols}, $PRINT_INFO{len}, $PRINT_INFO{eol}) = (tput('cols', 1), 0, "");
eval_colors(tput('colors', 1));

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(
	tmpdir_save tmpdir_setup zram_init zram_reset zram_setup
);
%EXPORT_TAGS = (
	zram   => [qw(zram_reset zram_init zram_setup)],
	tmpdir => [qw(tmpdir_save tmpdir_setup)],
);

my %tmpdir = (
	size       => '10%',
	compressor => 'lz4 -1',
);

my %zram = (
	num_dev    => 4,
	compressor => "lz4",
	streams    => 2,
	boot_setup => 0,
);

=head1 NAME

File::Tmpdir - Temporary (hierarchy) directory with ZRAM support

=cut

=head1 SYNOPSIS

Setup zram/devices with single step without calling C<zram_init()>

    use File::Tmpdir qw(:zram);
    zram_setup(device => "4G ext4 /var/tmp 1777 user_xattr",
               compressor => "lzo", num_dev => 8, boot_setup => 1);

Main tmpdir temporary directory setup function. This would save C</var/log>
to disk (tarball archive); and mount bind mount C</var/log> and C</var/run>
to C</var/tmp> for a temporary setup (tmpfs).

     use File::Tmpdir qw(:tmpdir);
     tmpdir_setup(saved => ["/var/log"], unsaved => ["/var/run"],
                  prefix => "/var/tmp"); # Setup a temporary directory hierarchy

=cut

=head1 DESCRIPTION

This package manage temporary directory (hierarchy) build on top of a collection
of helpers and utilities divided in several export tags.

    use File::Tmpdir qw(:color :print :tmpdir :zram: :misc);

Temporary directory can be pretty plain by using only I<prefix> key/value pair
to get a plain tmpfs mounted directory. And then, building a hierarchy of
I<saved> and I<unsaved> directories can be easily done. This can be handy to
regroup a few writable directories for read only systems, or more generarly,
reduce disk seeks for whatever reason (e.g. system responsiveness.) 

I<unsaved> can be seen as make a directory writable in the filesystem and then
discard everything afterwards with system reboot/shutdown. I<saved> can be used,
for example, to make I</var/log> a temporary storage on quick access filesystem,
and then, maybe save before system reboot/shutdown to disk.

This usage can be extended to other directories to get a responsive system.
Extra space efficiency can be atained by using zram which can be stacked with
this type of usage.

=cut

=head1 FUNCTIONS

=cut

=head2 tmpdir_init(OPTIONS)

Intialize a temporary directory hierarchy by mounting the prefix directory.

    tmpdir_init(compressor => "lz4 -1", saved => ["/var/log"]);

=cut

sub tmpdir_init {
	my %ARGS = @_;
	return 1 unless defined($ARGS{prefix});

	$ARGS{extension} = ".tar." . (split /\s/, $ARGS{compressor})[0];

	if (exists $ARGS{saved}) {
		for my $dir (@{$ARGS{saved}}) {
			next if (-f "$dir$ARGS{exntension}");
			if (-d $dir) {
				tmpdir_save(compressor => $ARGS{compressor}, $dir); 
			}
			else { mkpath($dir, 0, 0755) }
		}
	}

	return 0 if mount_info($ARGS{prefix});
	mkpath($ARGS{prefix}, 0, 0755) unless (-d $ARGS{prefix});
	system('mount', '-o', "rw,nodev,mode=0755,size=$ARGS{size}",
	       '-t', 'tmpfs', 'tmpdir', $ARGS{prefix});
	return $?;
}

=head2 tmpdir_setup(OPTIONS)

Setup a temporary directory hierarchy with optional tarball archives for entries
requiring state retention.

    tmpdir_setup(prefix => "/var/test", compressor => "lzop -1");

=cut

sub tmpdir_setup {
	my %ARGS = @_;
	for my $key (keys %tmpdir) {
		$ARGS{$key} = $ARGS{$key} // $tmpdir{$key};
	}
	return 1 if (tmpdir_init(%ARGS, @_));
	return 0 unless (exists $ARGS{saved} or exists $ARGS{unsaved});

	my @DIRS = @{$ARGS{saved}} if exists $ARGS{saved};
	push @DIRS, @{$ARGS{unsaved}} if exists $ARGS{unsaved};

	for my $dir (@DIRS) {
		my $DIR = "$ARGS{prefix}/$dir";
		next if (mount_info($DIR));
		mkdir $DIR unless (-d $DIR);
		pr_begin("Mounting $DIR");
		system('mount', '--bind', $DIR, $dir);
		pr_end($?);
	}
	tmpdir_restore(compressor => $ARGS{compressor}, @{$ARGS{saved}})
		if exists $ARGS{saved};
	return 0;
}

=head2 tmpdir_restore([compressor => 'lz4 -1',] DIRS)

Restore temporary directory hierarchy from tarball archives.

=cut

sub tmpdir_restore {
	my ($compressor, $extension);
	if ($_[0] eq 'compressor') {
		shift; $compressor = shift;
	}
	else { $compressor = $tmpdir{compressor} }
	$extension = '.tar.' . (split /\s/, $compressor)[0];

	my ($tail, $tarball);
	for my $dir (@_) {
		next unless (chdir(dirname($dir)));
		$tail = basename($dir);
		if    (-f "$tail$extension"    ) { $tarball = "$tail$extension"     }
		elsif (-f "$tail.old$extension") { $tarball = "$tail.old$extension" }
		else {
			pr_warn("No tarball found."); next;
		}
		pr_begin("Restoring $dir");
		system('tar', '-xpf', "$tail$extension", '-I', $compressor, $tail);
		pr_end($?);
	}
}

=head2 tmpdir_save([compressor => 'lz4 -1',] DIRS)

Save temporary directory hierarchy to disk.

=cut

sub tmpdir_save {
	my ($compressor, $extension);
	if ($_[0] eq 'compressor') {
		shift; $compressor = shift;
	}
	else { $compressor = $tmpdir{compressor} }
	$extension = '.tar.' . (split /\s/, $compressor)[0];

	my ($tail, $tarball);
	for my $dir (@_) {
		next unless chdir(dirname($dir));
		$tail = basename($dir);
		rename ("$tail$extension", "$tail.old$extension") if (-f "$tail$extension");
		pr_begin("Saving $dir");
		system('tar', '-cpf', "$tail$extension", '-I', $compressor, $tail);
		pr_end($?);
	}
}

=head2 zram_reset(DEVICES)

Initialize zram devices passed arguments or glob everything found in /dev/zram*.

=cut

sub zram_reset {
	my (@ARGS, $ret) = @_;
	@ARGS = glob '/dev/zram*' unless @ARGS;
	for my $dev (@ARGS) {
		if (mount_info($dev) or mount_info('-s', $dev)) {
			pr_warn("$dev is busy");
			$ret += 1; next;
		}
		$dev = (split /\//, $dev)[-1];
		if (read_or_write(">", "/sys/block/$dev/reset", 1)) {
			$ret += 1;
		}
	}
	return $ret;
}

=head2 zram_init(OPTIONS)

Setup low level details and initialize kernel module if boot_setup key is
passed. See C<zram_setup()> for the hash keys/values. The following example
setup zram kernel module.

    zram_init(num_dev => 8, streams => 4, boot_setup => 1); 

=cut

sub zram_init {
	my %ARGS = @_;
	for my $key (('boot_setup', 'num_dev')) {
		$ARGS{$key} = $ARGS{$key} // $zram{$key};
	}

	if (-b "/dev/zram0") {
		return 0 unless yesno($ARGS{boot_setup});
	}
	if (mount_info('-m', 'zram')) {
		unless (system('rmmod', 'zram')) {
			zram_reset() and system('rmmod', 'zram') or return 1;
		}
	}
	system('modprobe', "num_devices=$ARGS{num_dev}", 'zram');
	return $?;
}

=head2 zram_setup(DEVICE)

Setup zram device with the following format:
Size FileSystem Mount-Point Mode Mount-Options
(mode is an octal mode to be passed to chmod, mount-option to mount).

=cut

sub zram_setup {
	my %ARGS = @_;
	return 1 if (zram_init(@_));
	return 0 unless defined($ARGS{device});

	for my $key (('compressor', 'streams')) {
		$ARGS{$key} = $ARGS{$key} // $zram{$key};
	}
	$ARGS{compressor} = $zram{compressor} unless ($ARGS{compressor} eq "lz4" or
		$ARGS{compressor} eq "lzo");

	my ($size, $fs, $dir, $mode, $opt) = split /\s/, $ARGS{device};
	my ($num, $DEV, $dev, $ret) = (0);

	# Find the first free device
	while (1) {
		$dev = "/dev/zram$num";
		unless (-b $dev) {
			pr_error("No zram free device found.");
			return 2;
		}
		$DEV = "/sys/block/zram$num";
		if ((read_or_write("<", "$DEV/size"))[0] != 0) {
			$num += 1; next;
		}
		else { last }
	}

	# Initialize device if defined
	return 3 unless defined($size);
	read_or_write(">", "$DEV/comp_algorithm", $ARGS{compressor})
		if (-w "$DEV/comp_algorithm");
	read_or_write(">", "$DEV/max_comp_streams", $ARGS{streams})
		if (-w "$DEV/max_comp_streams");
	return 4 if (read_or_write(">", "$DEV/disksize", $size));

	# Setup device if requested
	return 0 unless defined($fs);
	if ($fs eq 'swap') {
		pr_begin("Setting up $dev swap device\n");
		system('mkswap', $dev) or system('swapon', $dev);
		pr_end($?);
	}
	elsif ($fs =~ m/[a-z]+/) {
		pr_begin("Setting up $dev/$fs device\n");
		system("mkfs", "-t", $fs, $dev);
		pr_end($?);

		if ($? == 0 and defined($dir)) {
			mkdir $dir unless(-d $dir);
			my @mount_ARGS = ("-t", $fs);
			push @mount_ARGS, ("-o", $opt) if defined($opt);
			pr_begin("Mounting $dev");
			system("mount", @mount_ARGS, $dev, $dir);
			pr_end($?);
			chmod($mode, $dir) if (defined($mode) and $? == 0);
		}
	}
	return 0;
}

sub read_or_write {
	my ($mode, $file, @ARGS, $FILE) = @_;
	unless ($mode eq '<' or $mode eq '>') {
		pr_error("Unsupported mode");
		return 1;
	}
	unless (-e $file) {
		pr_error("File not found");
		return 2;
	}
	unless (open($FILE, $mode, $file)) {
		pr_error("Failed to open $file: $!");
		return 3;
	}

	if ($mode eq '>') {
		for my $arg (@ARGS) {
			print $FILE "$arg\n";
		}
		close($FILE);
		return 0;
	}
	else {
		chomp(@ARGS = <$FILE>);
		close($FILE);
		return @ARGS;
	}
}

=head1 METHODS

To create a 1GB swap device on top of zram using methods (instead of function
calls.)

    my $swp = File::Tmpdir->new(device => "1G swap");
    $swp->setup();

To create tmpfs temporary directory hierarchy object.

    my $tmp = File::Tmpdir->new(prefix => "/var/tmp");
    $tmp->setup(size => "2G");

=cut

=head2 new(OPTIONS)

Constructor method; note that, using C<compressor> key setting will confuse
the object and try to set up either zram or tmpfs with a tiny cost.

=cut

sub new {
	my $invocant = shift;
	my %ARGS = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	bless ($self, $class);

	if (@_) {
		while (my ($key, $value) = each %ARGS) {
			$self->setattr($key, $value);
		}
	}
	return $self;
}

=head2 setup(OPTIONS)

Setup method build on top of C<tmpdir_setup()> and C<zram_setup()> subroutines,
so, passing extra arguments is totally permissible when setting up the device.

=cut

sub setup {
	my $self = shift;
	my %ARGS = @_;
	if (@_) {
		while (my ($key, $value) = each %ARGS) {
			$self->setattr($key, $value);
		}
	}
	  zram_setup(%$self) if exists $self->{device};
	tmpdir_setup(%$self) if exists $self->{prefix};
}

=head2 delattr('attr')

Delete an attribute of an object.

=cut

sub delattr {
	my ($self, $attr) = @_;
	if (exists $self->{$attr}) {
		delete $self->{$attr};
	}
}

=head2 getattr(attr)

Retrieve the setted attributes of the objest.

    $obj->getattr('compressor');

=cut

sub getattr {
	my ($self, $attr) = (shift);
	if (exists $self->{$attr}) {
		return $self->{$attr};
	}
	else { pr_warn("No valid attribute '$attr' in object") }
}

=head2 setattr(attr => 'value')

Set an attribute of an object.

=cut

sub setattr {
	my ($self, $attr, $value) = @_;
	if ($attr eq 'prefix' or $attr eq 'device'
			or defined $zram{$attr} or defined $tmpdir{$attr}) {
		$self->{$attr} = $value;
	}
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
