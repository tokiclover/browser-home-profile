#!/usr/bin/python
#
# $Header: tmpdirs.py                                         Exp $
# $Author: (c) 2016 tokiclover <tokiclover@gmail.com>         Exp $
# $License: MIT (or 2-clause/new/simplified BSD)              Exp $
# $Version: 1.3 2016/03/18                                    Exp $
#

from tmpdir.functions import sigwinch_handler
import os.path, signal, sys, tmpdir, getopt

zero = os.path.basename(sys.argv[0])
tmpdir.functions.NAME = zero
HELP_MESSAGE = 'Usage: %s [OPTIONS] [--boot] [--tmpdir-prefix=DIRECTORY] [ZRAM_DEVICES]' % zero
HELP_MESSAGE += """
  -z, --zram-num-dev=8                Setup ZRAM devices number (default to 4)
  -c, --zram-compressor=lzo           Setup ZRAM compressor (default to lz4)
  -s, --zram-stream=4                 Setup ZRAM stream number per device (deafault to 2)
  -p, --tmpdir-prefix=/var/tmp        Setup temporary directory hierarchy
  -C, --tmpdir-compressor='lzop -1'   Setup tmpdir compressor (default to lz4)
  -t, --tmpdir-saved=/var/log         Setup archived temporary directory
  -T, --tmpdir-unsaved=/var/run       Setup unarchived temporary directory
  -b, --boot                          Run subsystem initialization (kernel module)
  -h, --help                          Print help message
  -v, --version                       Print version message

Examples:
"""
HELP_MESSAGE += '* `%s "512m swap" "8G ext4 /var/db 0755 user_xattr"\' to create two devices\n'    % zero
HELP_MESSAGE += '* `%s  --tmpdir-prefix=/var/test\' to create a new (tmpfs) temporary-directory\n' % zero
HELP_MESSAGE += '* `%s  --boot -p /var/tmp --tmpdir-saved=/var/log "8G ext4 /var/tmp 1777"\'\n'    % zero
HELP_MESSAGE += '     to chain a temporary directory hierarchy on top of zram\n'

version = "1.3"
VERSION_MESSAGE = '%s version %s' % (zero, version)

signal.signal(signal.SIGWINCH, sigwinch_handler)

if not len(sys.argv) > 1:
    print(HELP_MESSAGE)
    sys.exit(0)

shortopts = 'bC:c:hs:T:t:p:vz:'
longopts  = ['--boot', '--tmpdir-compressor=', '--zram-compressor=', '--zram-stream=',
        '--tmpdir-prefix=', '--tmpdir-saved=', '--tmpdir-unsaved=', '--help',
        '--version', '--zram-num-dev=']

try:
    OPTS, ARGS = getopt.getopt(sys.argv[1:], shortopts, longopts)
except getopt.GetoptError:
    print(HELP_MESSAGE)
    sys.exit(1)

tmpdir_ARGS, zram_ARGS = dict({}), dict({})
for (opt, arg) in OPTS:
    if opt in ['-h', '--help']:
        print(HELP_MESSAGE)
        sys.exit(0)
    if opt in ['-v', '--version']:
        print(VERSION_MESSAGE)
        sys.exit(0)
    if opt in ['-b', '--boot']:
        zram_ARGS['boot_setup'] = 1
    if opt in ['-C', '--tmpdir-compressor']:
        tmpdir_ARGS['compressor'] = arg
    if opt in ['-c', '--zram-compressor']:
        zram_ARGS['compressor'] = arg
    if opt in ['-s', '--zram-stream']:
        zram_ARGS['streams'] = arg
    if opt in ['-z', '--zram-num-dev']:
        zram_ARGS['num_dev'] = arg
    if opt in ['-p', '--tmpdir-prefix']:
        tmpdir_ARGS['prefix'] = arg
    if opt in ['-t', '--tmpdir-saved']:
        tmpdir_ARGS['saved'] = arg.split(',')
    if opt in ['-T', '--tmpdir-unsaved']:
        tmpdir_ARGS['unsaved'] = arg.split(',')

for arg in ARGS:
    tmpdir.zram_setup(device=arg, **zram_ARGS)
if 'prefix' in list(tmpdir_ARGS.keys()):
    tmpdir.tmpdir_setup(**tmpdir_ARGS)
elif 'saved' in list(tmpdir_ARGS):
    tmpdir.tmpdir_save(**tmpdir_ARGS)

#
# vim:fenc=utf-8:ci:pi:sts=4:sw=4:ts=4:expandtab
#
