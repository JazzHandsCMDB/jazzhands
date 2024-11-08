#!/usr/bin/env python
# Copyright 2017-2019 Ryan D. Williams
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import subprocess
try:
    from setuptools import setup
except ImportError:
    from distutils.core import setup

# this should be pulled in automatically
version = '0.98.0'

classifiers = [
    "Topic :: Utilities",
    "Programming Language :: Python",
]

setup(
    name = 'jazzhands_appauthal',
    version = version,
    url = 'http://www.jazzhands.net/',
    author = 'Ryan D Williams',
    author_email = 'rdw@xandr.com',
    license = 'ALv2',
    package_dir = {'': 'src/lib'},
    packages = ['jazzhands_appauthal'],
    description = 'Provides generic authentication abstraction libraries.'
        ' Currently supports returning unified config interface for Postrgres and MySQL',
    classifiers = classifiers,
)
