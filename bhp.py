#!/usr/bin/python
#
# $Header: bhp.py                                             Exp $
# $Author: (c) 2016 tokiclover <tokiclover@gmail.com>         Exp $
# $License: MIT (or 2-clause/new/simplified BSD)              Exp $
# $Version: 1.1 2016/02/26                                    Exp $
#

"""This utility manage web-browser home profile directory along with the associated
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

Some reusable helpers to format print output for the adventurous ones which can
be copy/pasted to any project or personal script.
"""

from __future__ import print_function
import os, os.path, signal, sys, tempfile

BHP, color, bg, fg = dict({}), dict({}), list([]), list([])
PR_COL, PR_LEN, PR_EOL = 0, 0, ''
BHP['color'], BHP['zero'] = 1, os.path.basename(sys.argv[0])

HELP_MESSAGE = 'Usage: %s [OPTIONS] [BROWSER]' % BHP['zero']
HELP_MESSAGE += """
    -c, --compressor 'lzop -1'   Use lzop compressor (default to lz4)
    -t, --tmpdir DIR             Set up a particular TMPDIR
    -p, --profiel PROFILE        Select a particular profile
    -s, --set                    Set up tarball archives
    -h, --help                   Print help message
    -v, --version                Print version message                    
"""

VERSION_STRING = "1.0"
VERSION_MESSAGE = '%s version %s' % (BHP['zero'], VERSION_STRING)

def tput(cap, conv=0):
    """Simple helper to querry terminfo(5) capabilities"""
    TPUT = os.popen('tput %s' % cap)
    tput = TPUT.read()
    TPUT.close()
    if yesno(conv): return int(tput)
    else: return tput

#
# Handle window resize signal
#
def sigwinch_handler():
    global PR_COL
    if sys.version[0] == 3:
        PR_COL = os.get_terminal_size()[0]
    else:
        PR_COL = tput('cols', 1)

signal.signal(signal.SIGWINCH, sigwinch_handler)

#
# @FUNCTION: Print error message to stderr
#
def pr_error(msg):
    """Print error message to stderr"""
    global PR_LEN
    PR_LEN = len(msg)+len(name)+2

    if name:
        pfx = ' %s%s:%s' % (color['fg-magenta'], name, color['reset'])
    else:
        pfx = ''
    print('%s%s*%s %s %s' % (PR_EOL, color['fg-red'], color['reset'], pfx, msg),
                file=sys.stderr)

#
# @FUNCTION: Print error message to stderr & exit
#
def pr_die(ret, msg):
    """Print error message to stderr and exit program"""
    pr_error(msg)
    exit(ret)

#
# @FUNCTION: Print info message to stdout
#
def pr_info(msg):
    """Print info message to stdout"""
    global PR_LEN
    PR_LEN = len(msg)+len(name)+2

    if name:
        pfx = ' %s%s:%s' % (color['fg-yellow'], name, color['reset'])
    else:
        pfx = ''
    print('%s%s*%s %s %s' % (PR_EOL, color['fg-blue'], color['reset'], pfx, msg),
                file=sys.stdout)

#
# @FUNCTION: Print warn message to stdout
#
def pr_warn(msg):
    """Print warning message to stdout"""
    global PR_LEN
    PR_LEN = len(msg)+len(name)+2

    if name:
        pfx = ' %s%s:%s' % (color['fg-red'], name, color['reset'])
    else:
        pfx = ''
    print('%s%s*%s %s %s' % (PR_EOL, color['fg-yellow'], color['reset'], pfx, msg),
                file=sys.stdout)

#
# @FUNCTION: Print begin message to stdout
#
def pr_begin(msg):
    """Print the beginning of a formated message to stdout"""
    global PR_EOL, PR_LEN
    if PR_EOL == '\n': print(PR_EOL)
    PR_EOL = '\n'
    PR_LEN = len(msg)+len(name)+2

    if name:
        pfx = '%s[%s%s%s]%s' % (color['fg-magenta'], color['fg-blue'], name,
                color['fg-magenta'], color['reset'])
    else:
        pfx = ''
    print('%s %s' % (pfx, msg), end=' ')

#
# @FUNCTION: Print end message to stdout
#
def pr_end(val, msg=''):
    """Print the end of a formated message to stdout"""
    global PR_EOL, PR_LEN
    len = PR_COL - PR_LEN

    if val == 0:
        sfx = '%(fg-blue)s[%(fg-green)sOk%(fg-blue)s]%(reset)s' % color
    else:
        sfx = '%(fg-yellow)s[%(fg-red)sNo%(fg-yellow)s]%(reset)s' % color
    
    s = '%s %s' % (msg, sfx)
    print('%*s' % (len, s))
    PR_EOL, PR_LEN = '', 0

#
# @FUNCTION: YES or NO helper
#
def yesno(val=0):
    """A tiny helper to simplify case incensitive yes/no configuration"""
    if str(val).lower() in ['0', 'disable', 'off', 'false', 'no']:
        return 0
    elif str(val).lower() in ['1', 'enable', 'on', 'true', 'yes']:
        return 1
    else:
        return None

#
# @FUNCTION: Colors handler
#
def eval_colors():
    """Set up colors for output for the print helper family"""
    global color, bg, fg
    bc = ['none', 'bold', 'faint', 'italic', 'underline', 'blink',
        'rapid-blink', 'inverse', 'conceal', 'no-italic', 'no-underline',
        'no-blink', 'reveal', 'default'
    ]
    val = list(range(8))+list(range(23, 25))+[28, '39;49']
    ESC = '\033['
    color = { bc[i]: '%s%sm' % (ESC, c) for (i, c) in enumerate(val) }
    color['reset'] = '%s0m' % ESC

    if tput('colors', 1) >= 256:
        BG, FG, NUM = '48;5;', '38;5;', 256
    else:
        BG, FG, NUM = 4, 3, 8

    bg = [ '%s%s%dm' % (ESC, BG, c) for c in range(NUM) ]
    fg = [ '%s%s%dm' % (ESC, FG, c) for c in range(NUM) ]
    bc = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white']
    for (i, c) in enumerate(bc):
        color['bg-{0}'.format(c)] = '%s%s%sm' % (ESC, BG, i)
        color['fg-{0}'.format(c)] = '%s%s%sm' % (ESC, FG, i)

#
# Set up colors
#
if sys.stdout.isatty() and yesno(BHP['color']):
    eval_colors()
if sys.version[0] == 3:
    PR_COL = os.get_terminal_size()[0]
else:
    PR_COL = tput('cols', 1)


def mount_info(dir):
    """A tiny helper to simplify probing mounted points"""
    if not dir: return None
    MFH = open("/proc/mounts", "r") #pr_die("Failed to open /proc/mounts");
    for line in MFH:
        if dir in line: ret = 1; break
        else: ret = 0
    MFH.close()
    return ret

def find_browser(browser=''):
    browsers = {
        'mozilla': [ 'aurora', 'firefox', 'icecat', 'seamonkey' ],
        'config':  [ 'conkeror', 'chrome', 'chromium', 'epiphany', 'midory',
            'opera', 'otter', 'qupzilla', 'netsurf', 'vivaldi' ]
    }

    if browser:
        if browser in browsers['mozilla']:
            BHP['browser'], BHP['profile'] = browser, 'mozilla/%s' % browser
            return 0
        elif browser in browsers['config']:
            BHP['browser'], BHP['profile'] = browser, 'config/%s' % browser
            return 0

    for key in browsers:
        for browser in browsers[key]:
            if os.path.isdir('{0}/.${1}/${2}'.format(os.environ['HOME'], key, browser)):
                BHP['browser'], BHP['profile'] = browser, '%s/%s' % (key, browser)
                return 0
    return 1

def mozilla_profile(browser, profile=''):
    if profile and os.path.isdir('%s/.mozilla/%s/%s' % (os.environ['HOME'], browser, profile)):
        BHP['profile'] = 'mozilla/%s/%s' % (browser, profile)
        return 0

    PFH = open('%s/.mozilla/%s/profiles.ini' % (os.environ['HOME'], browser))
    if not PFH: pr_die(1, "No mozilla profile found")
    for line in PFH:
        if line[:5].lower() == 'path=':
            BHP['profile'] = 'mozilla/%s/%s' % (browser, line.split('=')[1])
            if not os.path.isdir('%s/.%s' % (os.environ['HOME'], BHP['profile'])):
                pr_die(2, "No mozilla profile directory found")
            break
    PFH.close()

#
# Use a private initializer function
#
def bhp(profile, setup=False):
    global TMPDIR, bhp
    ext = '.tar.%s' % BHP['compressor'].split(' ')[0]

    #
    # Set up browser and/or profile directory
    #
    if find_browser(BHP['browser']):
        pr_error("No browser found.");
        return 1
    if 'mozilla' in profile:
        mozilla_profile(BHP['profile'], profile)
    profile = BHP['profile'].split('/')[-1]

    #
    # Set up directories for futur use
    #
    BHP['dirs'] = [ '{0}/.{1}'.format(os.environ['HOME'], BHP['profile']) ]
    cachedir = os.environ['HOME']+'/.cache/'+BHP['profile'].replace('config/', '')
    if os.path.isdir(cachedir):
        BHP['dirs'].append(cachedir)
    if not os.path.isdir(TMPDIR):
        try:
            os.mkdir(TMPDIR, mode=700)
        except OSError:
            pr_error("No suitable temporary directory found")
            return 2

    #
    # Finaly, set up temporary bind-mount directories
    #
    for dir in BHP['dirs']:
        os.chdir(os.path.dirname(dir))

        if not os.path.isfile(profile+ext) or not os.path.isfile(profile+'.old'+ext):
            if os.system("tar -cpf {0} -I '{1}' {2}".format(profile+ext, BHP['compressor'], profile)):
                pr_end(1, "Tarball")
                continue

        if os.path.ismount(dir):
            if setup: bhp_archive(ext, profile)
            continue
        pr_begin("Setting up directory... ")

        if 'cache' in dir: char = 'c'
        else: char = 'b'
        tmpdir = tempfile.mkdtemp(prefix='%{0}hp'.format(char), dir=TMPDIR)
        if os.system('sudo  mount --bind %s %s' % (tmpdir, dir)):
            pr_end(2, "Mounting")
            continue
        pr_end(0)
    
        if setup: bhp_archive(ext, profile)

#
# Set up or (un)compress archive tarballs accordingly
#
def bhp_archive(ext, profile):
    pr_begin("Setting up tarball... ")
    if os.path.isfile(profile+'/.unpacked'):
        if os.path.isfile(profile+ext):
            try:
                os.rename(profile+ext, profile+'.old'+ext)
            except OSError:
                pr_end(1, "Moving")
                return 1
        if os.system("tar -X {0}/.unpacked -cpf {1} -I '{2}' {3}".format(
            profile, profile+ext, BHP['compressor'], profile)):
            pr_end(1, "Packing")
            return 2
    else:
        if   os.path.isfile(profile+ext       ): tarball = profile+ext
        elif os.path.isfile(profile+'.old'+ext): tarball = profile+'.old'+ext
        else:
            pr_warn("No tarball found.");
            return 3
        if os.system("tar -xpf {0} -I '{1}'".format(tarball, BHP['compressor'])):
            pr_end(1, "Unpacking")
            return 4
        else:
            fh = open('{0}/.unpacked'.format(profile), "w")
            fh.close()

    pr_end(0)

if __name__ == '__main__':
    BHP['browser'], BHP['compressor'] = '', 'lz4 -1'
    profile, setup, name = '', False, BHP['zero']
    if 'TMPDIR' in os.environ:
        TMPDIR = os.environ['TMPDIR']
    elif 'USER' in os.environ:
        TMPDIR = '/tmp/%s' % os.environ['USER']
    else:
        TMPDIR = '/tmp'
    #
    # Set up options according to command line options
    #
    import getopt, re
    shortopts = 'c:hp:st:v'
    longopts  = ['compressor=', 'help', 'profile=', 'set', 'tmpdir=', 'version']
    try:
        opts, args = getopt.getopt(sys.argv[1:], shortopts, longopts)
    except getopt.GetoptError:
        print(HELP_MESSAGE)
        sys.exit(1)

    for (opt, arg) in opts:
        if opt in ['-h', '-help']:
            print(HELP_MESSAGE)
            sys.exit(0)
        if opt in ['-v', '-version']:
            print(VERSION_MESSAGE)
            sys.exit(0)
        if opt in ['-c', '-compressor']:
            BHP['compressor'] = arg
        if opt in ['-p', '-profile']:
            profile = arg
        if opt in ['-s', '-set']:
            setup = True
        if opt in ['-t', '-tmpdir']:
            TMPDIR = arg

    if len(args):
        BHP['browser'] = args[0]
    elif 'BROWSER' in os.environ:
        BHP['browser'] = os.environ['BROWSER']

    #
    # Finally, launch the setup helper
    #
    bhp(profile=profile,setup=setup)

#
# vim:fenc=utf-8:ci:pi:sts=4:sw=4:ts=4:expandtab
#
