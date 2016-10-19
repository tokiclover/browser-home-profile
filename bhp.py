#!/usr/bin/python
#
# $Header: bhp.py                                             Exp $
# $Author: (c) 2016 tokiclover <tokiclover@gmail.com>         Exp $
# $License: MIT (or 2-clause/new/simplified BSD)              Exp $
# $Version: 1.4 2016/03/18                                    Exp $
#

"""This utility manage web-browser home profile directory along with the associated
cache directory. It will put those direcories, if any, to a temporary directory
(usualy in a tmpfs or zram backed device directory) to minimize disk seeks and 
improve performance and responsiveness to said web-browser.

Many web-browser are supported out of the box. Namely, aurora, firefox, icecat,
seamonkey (mozilla family), conkeror, chrom, epiphany, midory, opera, otter,
qupzilla, netsurf, vivaldi. Specifying a particular web-browser on the command
line is supported along with discovering one in the user home directory (first
found would be used.)

Tarballs archive are used to save user data between session or computer
shutdown/power-on. Speficy -s command line switch to set up the tarball archives
instead of the empty profile.

Some reusable helpers to format print output for the adventurous ones which can
be copy/pasted to any project or personal script.
"""

from __future__ import print_function
from tmpdir.functions import pr_begin, pr_end, pr_info, pr_warn, pr_error
from tmpdir.functions import pr_die, eval_colors, mount_info, sigwinch_handler
import os, os.path, signal, sys, tempfile, tmpdir

bhp_info = dict({})
bhp_info['zero'] = os.path.basename(sys.argv[0])

HELP_MESSAGE = 'Usage: %s [OPTIONS] [BROWSER]' % bhp_info['zero']
HELP_MESSAGE += """
    -c, --compressor 'lzop -1'   Use lzop compressor (default to lz4)
    -d, --daemon 300             Sync time (in sec) when daemonized
    -t, --tmpdir DIR             Set up a particular TMPDIR
    -p, --profiel PROFILE        Select a particular profile
    -s, --set                    Set up tarball archives
    -h, --help                   Print help message
    -v, --version                Print version message                    
"""

__author__ = "tokiclover <tokiclover@gmail.com>"
__date__ = "2016/03/08"
__version__ = "1.3"
VERSION_MESSAGE = '%s version %s' % (bhp_info['zero'], __version__)

signal.signal(signal.SIGWINCH, sigwinch_handler)

def find_browser(browser=''):
    """Find a browser to setup"""
    browsers = {
        'mozilla': [ 'aurora', 'firefox', 'icecat', 'seamonkey' ],
        'config':  [ 'conkeror', 'chrome', 'chromium', 'epiphany', 'midory',
            'opera', 'otter', 'qupzilla', 'netsurf', 'vivaldi' ]
    }

    if browser:
        for key in browsers:
            if browser in browsers[key]:
                bhp_info['browser'], bhp_info['profile'] = browser, key+'/'+browser
                return 0
    for key in browsers:
        for browser in browsers[key]:
            if os.path.isdir('{0}/.${1}/${2}'.format(os.environ['HOME'], key, browser)):
                bhp_info['browser'], bhp_info['profile'] = browser, '%s/%s' % (key, browser)
                return 0
    return 1

def mozilla_profile(browser, profile=''):
    """Find a Mozilla family browser profile"""
    if profile and os.path.isdir('%s/.mozilla/%s/%s' % (os.environ['HOME'], browser, profile)):
        bhp_info['profile'] = 'mozilla/%s/%s' % (browser, profile)
        return 0

    PFH = open('%s/.mozilla/%s/profiles.ini' % (os.environ['HOME'], browser))
    if not PFH: pr_die(1, "No mozilla profile found")
    for line in PFH:
        if line[:5].lower() == 'path=':
            bhp_info['profile'] = 'mozilla/%s/%s' % (browser, line.split('=')[1])
            if not os.path.isdir('%s/.%s' % (os.environ['HOME'], bhp_info['profile'])):
                pr_die(2, "No mozilla profile directory found")
            break
    PFH.close()

def bhp(profile, setup=False):
    """Profile initializer function and temporary directories setup"""
    global TMPDIR, bhp
    ext = '.tar.%s' % bhp_info['compressor'].split(' ')[0]

    #
    # Set up browser and/or profile directory
    #
    if find_browser(bhp_info['browser']):
        pr_error("No browser found.");
        return 1
    if 'mozilla' in profile:
        mozilla_profile(bhp_info['profile'], profile)
    profile = bhp_info['profile'].split('/')[-1]

    #
    # Set up directories for futur use
    #
    bhp_info['dirs'] = [ '{0}/.{1}'.format(os.environ['HOME'], bhp_info['profile']) ]
    cachedir = os.environ['HOME']+'/.cache/'+bhp_info['profile'].replace('config/', '')
    if os.path.isdir(cachedir):
        bhp_info['dirs'].append(cachedir)
    if not os.path.isdir(TMPDIR):
        try:
            os.mkdir(TMPDIR, mode=700)
        except OSError:
            pr_error("No suitable temporary directory found")
            return 2

    #
    # Finaly, set up temporary bind-mount directories
    #
    for dir in bhp_info['dirs']:
        os.chdir(os.path.dirname(dir))

        if not os.path.isfile(profile+ext) or not os.path.isfile(profile+'.old'+ext):
            if os.system("tar -cpf {0} -I '{1}' {2}".format(profile+ext, bhp_info['compressor'], profile)):
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

def bhp_archive(ext, profile):
    """Set up or (un)compress archive tarballs accordingly"""
    pr_begin("Setting up tarball... ")
    if os.path.isfile(profile+'/.unpacked'):
        if os.path.isfile(profile+ext):
            try:
                os.rename(profile+ext, profile+'.old'+ext)
            except OSError:
                pr_end(1, "Moving")
                return 1
        if os.system("tar -X {0}/.unpacked -cpf {1} -I '{2}' {3}".format(
            profile, profile+ext, bhp_info['compressor'], profile)):
            pr_end(1, "Packing")
            return 2
    else:
        if   os.path.isfile(profile+ext       ): tarball = profile+ext
        elif os.path.isfile(profile+'.old'+ext): tarball = profile+'.old'+ext
        else:
            pr_warn("No tarball found.");
            return 3
        if os.system("tar -xpf {0} -I '{1}'".format(tarball, bhp_info['compressor'])):
            pr_end(1, "Unpacking")
            return 4
        else:
            fh = open('{0}/.unpacked'.format(profile), "w")
            fh.close()

    pr_end(0)

def bhp_daemon(time=(60*5)):
    """Simple function to handle syncing the tarball archive to disk"""
    while True:
        signal.alarm(int(time))
        signal.pause()

def sigalrm_handler(sig=signal.SIGALRM, frame=None):
    for dir in bhp_info['dirs']:
        os.chdir(os.path.dirname(dir))
        bhp_archive('.tar.%s' % bhp_info['compressor'].split(' ')[0],
                bhp_info['profile'].split('/')[-1])
signal.signal(signal.SIGALRM, sigalrm_handler)

if __name__ == '__main__':
    bhp_info['browser'], bhp_info['compressor'] = '', 'lz4 -1'
    profile, setup, bhp_info['daemon'] = '', False, 0
    TMPDIR = os.environ.get('TMPDIR', '/tmp/' + os.environ['USER'])
    tmpdir.functions.NAME = bhp_info['zero']

    #
    # Set up options according to command line options
    #
    import getopt, re
    shortopts = 'c:d:hp:st:v'
    longopts  = ['compressor=', 'daemon=', 'help', 'profile=', 'set',
            'tmpdir=', 'version']
    try:
        opts, args = getopt.getopt(sys.argv[1:], shortopts, longopts)
    except getopt.GetoptError:
        print(HELP_MESSAGE)
        sys.exit(1)

    for (opt, arg) in opts:
        if opt in ['-h', '--help']:
            print(HELP_MESSAGE)
            sys.exit(0)
        if opt in ['-v', '--version']:
            print(VERSION_MESSAGE)
            sys.exit(0)
        if opt in ['-c', '--compressor']:
            bhp_info['compressor'] = arg
        if opt in ['-p', '--profile']:
            profile = arg
        if opt in ['-s', '--set']:
            setup = True
        if opt in ['-t', '--tmpdir']:
            TMPDIR = arg
        if opt in ['-d', '--daemon=']:
            bhp_info['daemon'] = arg

    #
    # Finally, launch the setup helper
    #
    bhp_info['browser'] = args[0] or os.environ.get('BROWSER', '')
    bhp(profile=profile,setup=setup)
    if bhp_info['daemon']: bhp_daemon(bhp_info['daemon'])

#
# vim:fenc=utf-8:ci:pi:sts=4:sw=4:ts=4:expandtab
#
