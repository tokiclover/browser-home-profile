use v5.14.0;
use strict;
use warnings;
use ExtUtils::MakeMaker 6.56;

WriteMakefile(
	NAME               => 'File::Tmpdir',
	LICENSE            => 'MIT',
	AUTHOR             => 'tokiclover <tokiclover@gmail.com',
	VERSION_FROM       => 'lib/File/Tmpdir.pm',
	ABSTRACT_FROM      => 'lib/File/Tmpdir.pm',
	BUILD_REQUIRES     => {
		'perl' => 5.014,
	},
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker' => 6.56,
	},
	EXE_FILES          => [ qw(bhp.pl tmpdirs.pl) ],
	MAN1PODS           => {},
	PM                 => {
		'lib/File/Tmpdir.pm'           => '$(INST_LIB)/File/Tmpdir.pm',
		'lib/File/Tmpdir/Functions.pm' => '$(INST_LIB)/File/Tmpdir/Functions.pm',
		'bhp.pl'                       => '$(INST_BIN)/bhp.pl',
		'tmpdirs.pl'                   => '$(INST_BIN)/tmpdirs.pl',
	},
	dist               => { COMPRESS => 'gzip -9', SUFFIX => 'gz' },
);
