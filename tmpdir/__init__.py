#
# $Header: tmpdir/__init__.py                                 Exp $
# $Author: (c) 2016 tokiclover <tokiclover@gmail.com>         Exp $
# $License: MIT (or 2-clause/new/simplified BSD)              Exp $
# $Version: 1.2 2016/03/08                                    Exp $
#

"""Temporary (hierarchy) directory with ZRAM support

Setup zram/devices with single step without calling zram_init()

    tmpdir.zram_setup(device="4G ext4 /var/tmp 1777 user_xattr",
               compressor="lzo", num_dev=8, boot_setup=1)

Main tmpdir temporary directory setup function. This would save '/var/log'
to disk (tarball archive); and mount bind mount '/var/log' and '/var/run'
to '/var/tmp' for a temporary setup (tmpfs).

     tmpdir.tmpdir_setup(saved=["/var/log"], unsaved=["/var/run"],
                  prefix="/var/tmp") # Setup a temporary directory hierarchy

This package manage temporary directory (hierarchy) build on top of a collection
of helpers and utilities divided in several files.

Temporary directory can be pretty plain by using only 'prefix' key/value pair
to get a plain tmpfs mounted directory. And then, building a hierarchy of
'saved' and 'unsaved' directories can be easily done. This can be handy to
regroup a few writable directories for read only systems, or more generarly,
reduce disk seeks for whatever reason (e.g. system responsiveness.) 

'unsaved' can be seen as make a directory writable in the filesystem and then
discard everything afterwards with system reboot/shutdown. 'saved' can be used,
for example, to make '/var/log' a temporary storage on quick access filesystem,
and then, maybe save before system reboot/shutdown to disk.

This usage can be extended to other directories to get a responsive system.
Extra space efficiency can be atained by using zram which can be stacked with
this type of usage.
"""

from .functions import pr_begin, pr_die, pr_end, pr_info, pr_warn, mount_info, yesno
import os, os.path, sys

__author__ = "tokiclover <tokiclover@gmail.com>"
__date__ = "2016/03/20"
__version__ = "1.2"

TMPDIR = dict(compressor='lz4 -1', size='10%')
ZRAM   = dict(compressor='lz4', streams=2, num_dev=4, boot_setup=0)

def read_or_write(file, mode='r', *PARGS):
    """Tiny helper to read/write to file (echo and single file cat clone)"""
    if not mode in ['r', 'w']:
        pr_error("Unsupported mode")
        return 1
    if not os.path.isfile(file):
        pr_error("File not found")
        return 2
    FILE = open(file, mode)
    if not FILE:
        pr_error("Failed to open %s" % file)
        return 3

    if mode == 'w':
        for arg in PARGS: FILE.write("%s\n" % arg)
        FILE.close()
        return 0
    else:
        PARGS = FILE.read().rstrip()
        FILE.close()
        return PARGS

#------------------------------------------------------ TMPDIR FUNCTIONS
def tmpdir_init(prefix, compressor=TMPDIR['compressor'], size=TMPDIR['size'],
        saved=None, **KARGS):
    """Intialize a temporary directory hierarchy by mounting the prefix directory.

    tmpdir_init(prefix="/var/tmp", compressor="lz4 -1", saved=["/var/log"])"""

    extension = compressor.split()[0]
    for dir in saved:
        if os.path.isfile("%s.%s" % (dir, extension)):
            continue
        if os.path.isdir(dir):
            tmpdir_save(dir, compressor=compressor)
        else:
            os.mkdir(dir, mode=755)
    if os.path.ismount(prefix): return 0
    os.system("mount -o rw,nodev,mode=0755,size={0} -t tmpfs tmpdir {1}".format(
               size, prefix))

def tmpdir_setup(prefix, compressor=TMPDIR['compressor'], size=TMPDIR['size'],
        saved=None, unsaved=None):
    """Setup a temporary directory hierarchy with optional tarball archives for entries
    requiring state retention.

    tmpdir_setup(prefix="/var/test", compressor="lzop -1")"""

    if tmpdir_init(prefix=prefix, compressor=compressor, size=size, saved=saved,
                   unsaved=unsaved):
        return 1
    if not saved or not unsaved: return 0

    for dir in (saved, unsaved):
        DIR = "%s/%s".format(prefix, dir)
        if os.path.ismount(DIR):
            continue
        if not os.path.isdir(DIR):
            os.mkdir(DIR, mode=755)
        pr_begin("Mounting %s" % DIR)
        ret = os.system("mount --bind {0} {1}".format(DIR, dir))
        pr_end(ret)

    if saved:
        tmpdir_restore(saved, compressor=compressor)

def tmpdir_restore(compressor=TMPDIR['compressor'], *PARGS):
    """Restore temporary directory hierarchy from tarball archives."""
    extension='.tar.'+compressor.split()[0]
    for dir in PARGS:
        os.chdir(os.path.dirname(dir))
        tail = os.path.basename(dir)
        if   os.path.isfile(tail+extension       ): tarball = tail+extension
        elif os.path.isfile(tail+'.old'+extension): tarball = tail+'.old'+extension
        else:
            pr_warn("No tarball found.");
            return 3
        pr_begin("Restoring %s" % dir)
        ret = os.system("tar -xpf {0} -I {1}".format(tarball, compressor))
        pr_end(ret)

def tmpdir_save(compressor=TMPDIR['compressor'], *PARGS):
    """Save temporary directory hierarchy to disk."""
    extension='.tar.'+compressor.split()[0]
    for dir in PARGS:
        os.chdir(os.path.dirname(dir))
        tail = os.path.basename(dir)
        if   os.path.isfile(tail+extension):
            os.path.rename(tail+extension, tail+'.old'+extension)
        pr_begin("Saving %s" % dir)
        ret = os.system("tar -cpf {0} -I {1} {2}".format(tail+extension,
                         compressor, tail))
        pr_end(ret)

#------------------------------------------------------ ZRAM FUNCTIONS
def zram_reset(*PARGS):
    """Initialize zram devices passed arguments or glob everything found in /dev/zram*"""
    ret = 0
    if not PARGS:
        PARGS, num = [], 0
        while True:
            dev = "/dev/zram{0}".format(num)
            if not os.path.exists(dev): break
            PARGS.append(dev)
            num +=1

    for dev in PARGS:
        if mount_info(dev) or mount_info(dev, mode='s'):
            pr_warn("%s is busy" % dev)
            ret += 1; continue
        dev = dev.split('/')[-1]
        if read_or_write("/sys/block/{0}/reset".format(dev), "w", 1):
            ret += 1
    return ret

def zram_init(boot_setup=ZRAM['boot_setup'], num_dev=ZRAM['num_dev'], **KARGS):
    """Setup low level details and initialize kernel module if boot_setup key is
    passed. See zram_setup() for the hash keys/values. The following example
    setup zram kernel module.

    zram_init(num_dev=8, boot_setup=1)"""

    if os.path.exists('/dev/zram0'):
        if not boot_setup: return 0
    if mount_info('zram', mode='m'):
        if os.system('rmmod zram'):
            ret = zram_reset() or os.system('rmmod zram')
            if ret: return 1
    return os.system("modprobe num_devices={0} zram".format(num_dev))

def zram_setup(device, **KARGS):
    """Setup zram device with the following format:
    Size FileSystem Mount-Point Mode Mount-Options
    (mode is an octal mode to be passed to chmod, mount-option to mount)."""

    if not device:
        return 1
    if zram_init(**KARGS):
        return 2
    for key in ZRAM:
        KARGS[key] = KARGS.get(key, ZRAM[key])
    if not KARGS['compressor'] == 'lz4' or not KARGS['compressor'] == 'lzo':
        KARGS['compressor'] = ZRAM['compressor']

    OPTS = dict(zip(['size', 'fs', 'dir', 'mode', 'opt'], device.split()))
    num, DEV, dev = 0, '', ''
    # Find the first free device
    while True:
        dev = "/dev/zram{0}".format(num)
        if not os.path.exists(dev):
            pr_error("No zram free device found.")
            return 3
        DEV = "/sys/block/zram{0}".format(num)
        size = read_or_write(file=DEV+'/size', mode='r')
        if int(size[0]) != 0:
            num += 1
            continue
        else: break

    # Initialize device if requested
    if not OPTS.get('size', ''):
        return 0
    if os.access(DEV+'/comp_algorithm', os.W_OK):
        read_or_write(DEV+'/comp_algorithm', 'w', KARGS['compressor'])
    if os.access(DEV+'/max_comp_streams', os.W_OK):
        read_or_write(DEV+'/max_comp_streams','w', KARGS['streams'])
    if read_or_write(DEV+'/disksize', 'w', OPTS['size']):
        return 4

    # Setup device if requested
    if not OPTS.get('fs', ''):
        return 0
    if OPTS['fs'] == 'swap':
        pr_begin("Setting up {0} swap device\n".format(dev))
        ret = os.system("mkswap %s" % dev) or os.system("swapon %s" % dev)
        pr_end(ret)
    else:
        pr_begin("Setting up {0}/{1} device\n".format(dev, OPTS['fs']))
        ret = os.system("mkfs -t {0} {1}".format(OPTS['fs'], dev))
        pr_end(ret)

        if not ret and os.path.isdir(OPTS['dir']):
            os.mkdir(dir, mode=755)
            mount_opts = "-t {0}".format(OPTS['fs'])

            if OPTS.get('opt', ''):
                mount_opts += " -o {0}".format(OPTS['opt'])
            pr_begin("Mounting {0}".format(dev))
            ret = os.system("mount {0} {1} {2}".format(mount_opts, dev, OPTS['dir']))
            pr_end(ret)

            if not ret and OPTS.get('mode', ''):
                os.chmod(OPTS['dir'], OPTS['mode'])
    return ret


class Tmpdir():
    """Class methods build on top of {tmpdir,zram}_<FUNCTIONS> instead of functions
    calls.

    swp = Tmpdir(device="1G swap")  # To create a 1GB swap device object (ZRAM)
    swp.setup()

    tmp = Tmpdir(prefix="/var/tmp") # To create temporary directory hierarchy object (tmpfs)
    tmp.setup(size="2G")
    """

    def __init__(self, **KARGS):
        for attr in KARGS.keys():
            self.setattr(attr, KARGS[attr])

    def __contains__(self, attr):
        if getattr(self, attr): return True
        else: return False

    def delattr(self, attr):
        if attr in list(self.__dict__.keys()):
            del self.__dict__[attr]

    def __eq__(self, other):
        sa = set(list(self.__dict__.keys()))
        sb = set(list(other.__dict__.keys()))
        if sa != sb: return False
        for key in sa:
            if self.__dict__[key] != other.__dict__[key]: return False
        return True

    def getattr(self, attr):
        if attr in list(self.__dict__.keys()):
            return self.__dict__[attr]
        else: return None

    def __iter__(self):
        return ((attr, self.__dict__[attr]) for attr in self.__dict__)

    def __len__(self):
        return len(self.__dict__)

    def __repr__(self):
        string = self.__class__.__name__ + ': '
        for key in self.__dict__.keys():
            string += "{0}={1}, ".format(key, self.__dict__[key])
        return string

    def setattr(self, attr, value):
        KEYS = ['prefix', 'device']+list(TMPDIR.keys())+list(ZRAM.keys())
        if attr in set(KEYS):
            self.__dict__[attr] = value

    def setup(self, **KARGS):
        """Setup method build on top of tmpdir_setup() and zram_setup() functions,
        so, passing extra arguments is totally permissible when setting up the device."""
        for attr in KARGS.keys():
            self.__setattr__(attr, KARGS[attr])
        if getattr(self, 'device', ''):   zram_setup(**self.__dict__)
        if getattr(self, 'prefix', ''): tmpdir_setup(**self.__dict__)

#
# vim:fenc=utf-8:ci:pi:sts=4:sw=4:ts=4:expandtab
#
