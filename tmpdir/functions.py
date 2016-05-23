#
# $Header: tmpdir/functions.py                                Exp $
# $Author: (c) 2016 tokiclover <tokiclover@gmail.com>         Exp $
# $License: MIT (or 2-clause/new/simplified BSD)              Exp $
# $Version: 1.2 2016/03/18                                    Exp $
#

"""Print and miscellaneous functions

Some reusable helpers to format print output prepended with '* name:' or '[name]'
(name refer to global tmpdir.functions.NAME) with ANSI color (escapes)  support.

COLOR hold the usual color attributes e.g. COLOR['bold'], COLOR['reset'],
COLOR['underline'] etc; and the common 8 ['back,fore}ground named colors prefixed
with {bg,fg} e.g. COLOR['fg-blue'], COLOR['bg-yellow'] etc.
FG and BG hold the numeral colors, meaning that, FG[0:255] and BG[0:255] are
usable after a eval_colors(256) initialization call.
BG[0:7] and FG[0:7] being the named colors included in COLOR.
"""

from __future__ import print_function
import os, os.path, sys, signal

__author__ = "tokiclover <tokiclover@gmail.com>"
__date__ = "2016/03/18"
__version__ = "1.2"

COLOR, BG, FG = dict({}), list([]), list([])
PRINT_INFO, NAME = dict(col=0, len=0, eol=''), ''

#------------------------------------------------------ PRINT FUNCTIONS
def pr_error(msg):
    """Print error message to stderr e.g.: pr_error("Failed to do this")"""
    global PRINT_INFO
    PRINT_INFO['len'] = len(msg)+len(NAME)+2

    if NAME:
        pfx = ' %s%s:%s' % (COLOR['fg-magenta'], NAME, COLOR['reset'])
    else:
        pfx = ''
    print('%s%sERROR:%s %s %s' % (PRINT_INFO['eol'], COLOR['fg-red'], COLOR['reset'],
          pfx, msg), file=sys.stderr)

def pr_die(ret, msg):
    """Print error message to stderr and exit program e.g.
    pr_die(ret, "Failed to launch %s:!" % command)"""
    pr_error(msg)
    exit(ret)

def pr_info(msg):
    """Print info message to stdout e.g.: pr_info("Running version %s" % __version__)"""
    global PRINT_INFO
    PRINT_INFO['len'] = len(msg)+len(NAME)+2

    if NAME:
        pfx = ' %s%s:%s' % (COLOR['fg-yellow'], NAME, COLOR['reset'])
    else:
        pfx = ''
    print('%s%sINFO:%s %s %s' % (PRINT_INFO['eol'], COLOR['fg-blue'], COLOR['reset'],
          pfx, msg), file=sys.stdout)

def pr_warn(msg):
    """Print warning message to stdout e.g.: pr_warn("Configuration file not found.")"""
    global PRINT_INFO
    PRINT_INFO['len'] = len(msg)+len(NAME)+2

    if NAME:
        pfx = ' %s%s:%s' % (COLOR['fg-red'], NAME, COLOR['reset'])
    else:
        pfx = ''
    print('%s%sWARN:%s %s %s' % (PRINT_INFO['eol'], COLOR['fg-yellow'], COLOR['reset'], pfx, msg),
                file=sys.stdout)

def pr_begin(msg):
    """Print the beginning of a formated message to stdout e.g.:
    pr_begin("Mounting device")"""
    global PRINT_INFO
    if PRINT_INFO['eol'] == '\n': print(PRINT_INFO['eol'])
    PRINT_INFO['eol'] = '\n'
    PRINT_INFO['len'] = len(msg)+len(NAME)+2

    if NAME:
        pfx = '%s[%s%s%s]%s' % (COLOR['fg-magenta'], COLOR['fg-blue'], NAME,
                COLOR['fg-magenta'], COLOR['reset'])
    else:
        pfx = ''
    print('%s %s' % (pfx, msg), end=' ')

def pr_end(val, msg=''):
    """Print the end of a formated message to stdout e.g.: pr_end(ret)"""
    global PRINT_INFO
    len = PRINT_INFO['cols'] - PRINT_INFO['len']

    if val == 0:
        sfx = '%(fg-blue)s[%(fg-green)sOk%(fg-blue)s]%(reset)s' % COLOR
    else:
        sfx = '%(fg-yellow)s[%(fg-red)sNo%(fg-yellow)s]%(reset)s' % COLOR
    
    s = '%s %s' % (msg, sfx)
    print('%*s' % (len, s))
    PRINT_INFO['eol'], PRINT_INFO['len'] = '', 0

#------------------------------------------------------ MISCELLANEOUS FUNCTIONS
def yesno(val=0):
    """A tiny helper to simplify case incensitive yes/no configuration"""
    if str(val).lower() in ['0', 'disable', 'off', 'false', 'no']:
        return 0
    elif str(val).lower() in ['1', 'enable', 'on', 'true', 'yes']:
        return 1
    else:
        return None

def eval_colors(num=8):
    """Set up colors (used for output for the print helper family.) Default to 8 colors,
    if no argument passed. Else, valid argument would be 8 or 256."""

    global COLOR, BG, FG
    num -= 1
    bc = ['none', 'bold', 'faint', 'italic', 'underline', 'blink',
        'rapid-blink', 'inverse', 'conceal', 'no-italic', 'no-underline',
        'no-blink', 'reveal', 'default'
    ]
    val = list(range(8))+list(range(23, 25))+[28, '39;49']
    esc = '\033['
    COLOR = { bc[i]: '%s%sm' % (esc, c) for (i, c) in enumerate(val) }
    COLOR['reset'] = '%s0m' % esc

    if num >= 255:
        bg, fg = '48;5;', '38;5;'
    else:
        bg, fg = 4, 3

    BG = [ '%s%s%dm' % (esc, bg, c) for c in range(num) ]
    FG = [ '%s%s%dm' % (esc, fg, c) for c in range(num) ]
    bc = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white']
    for (i, c) in enumerate(bc):
        COLOR['bg-{0}'.format(c)] = '%s%s%sm' % (esc, bg, i)
        COLOR['fg-{0}'.format(c)] = '%s%s%sm' % (esc, fg, i)

def mount_info(node, file='/proc/mounts', mode=None):
    """A tiny helper to simplify probing usage of mounted points or device, swap
    device and kernel module.

    mount_info('/dev/zram0', mode='s') # whether the specified device is swap
    mount_info('zram', mode='m')       # whether the kernel module is loaded
    mount_info('/dev/zram1')           # whether the specified device is mounted"""

    if   mode == 's': file='/proc/swaps'
    elif mode == 'm': file='/proc/modules'
    FILE = open(file, "r")
    if not FILE:
        pr_die("Failed to open %s" % file)
        return
    for line in FILE:
        if node in line: ret = 1; break
        else: ret = 0
    FILE.close()
    return ret

def tput(cap, conv=0):
    """Simple helper to querry C<terminfo(5)> capabilities without a shell.
    Second argument enable integer conversion.

    tput('cols', 1) # to get the actual terminal colon length"""
    TPUT = os.popen('tput %s' % cap)
    tput = TPUT.read()
    TPUT.close()
    if yesno(conv): return int(tput)
    else: return tput

def sigwinch_handler(sig=signal.SIGWINCH, frame=None):
    """Handle window resize signal"""
    global PRINT_INFO
    if sys.version[0] == 3:
        PRINT_INFO['cols'] = os.get_terminal_size()[0]
    else:
        PRINT_INFO['cols'] = tput('cols', 1)
#signal.signal(signal.SIGWINCH, sigwinch_handler)

if sys.version[0] == 3:
    PRINT_INFO['cols'] = os.get_terminal_size()[0]
else:
    PRINT_INFO['cols'] = tput('cols', 1)
eval_colors(tput('colors', 1))

#
# vim:fenc=utf-8:ci:pi:sts=4:sw=4:ts=4:expandtab
#
