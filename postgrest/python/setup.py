#!/usr/bin/env python3

import subprocess
from distutils.core import setup

version = '0.1.0'

classifiers = [
    "Topic :: Utilities",
    "Programming Language :: Python",
]

setup(
    name = 'postgrest-tokenmgr',
    version = version,
    url = 'http://jazzhands.net',
    author = 'Ryan D Williams',
    author_email = 'rdw@drws-office.com',
    license = 'ALv2',
    package_dir = {'': 'src/lib'},
    packages = ['postgrest_tokenmgr'],
    scripts = ['src/bin/postgrest-tokenmgr'],
    description = 'JWT Token Mgmt Foo',
    classifiers = classifiers,
)
