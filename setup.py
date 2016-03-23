from setuptools import setup, find_packages
setup(
    name = "tmpdir",
    version = "1.2",
    packages = ['tmpdir'],
    scripts = ['bhp.py', 'tmpdirs.py'],

    package_data = {
        '': ['AUTHORS', 'COPYING', 'README.md', 'ChangeLog'],
    },
    exclude_package_data = {
        'sh': [ '*.sh' ],
        'pl': [ '*.pl', '*.pm'],
    },

    author = "tokiclover",
    author_email = "tokiclover@gmail.com",
    description = "Temporary Directory Setup with ZRAM support",
    license = "MIT or 2-clause BSD",
    keywords = "tmpdir zram tmpfs directory temporary",
    url = "https://github.com/tokiclover/browser-home-profile",
    download_url = "https://github.com/tokiclover/browser-home-profile/releases",
    platform = "Unix (Linux for ZRAM support)"
)
