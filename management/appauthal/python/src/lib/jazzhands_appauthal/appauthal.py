# Copyright 2017 Ryan D. Williams
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

"""Implements the JazzHands AppAuthAL style configuration retrieval

Classes:
    AppAuthAL: the meat. Generates config directionary from app files.

Exceptions:
    AppAuthALException: General module exceptions

Configuration:
    JSON FILE = [os.getenv('APPAUTHAL_CONFIG') | '/etc/jazzhands/appauth-config.json']
    config =
        {
            'search_dirs': ['/var/lib/jazzhands/appauth-info'],
            'conf_file_format': 'json'
            'onload': {
                'environment': [
                    { 'ODBCINI':     '/etc/odbc.ini' },
                    { 'ORACLE_HOME': '/opt/oracle12' }
                ]
            }
        }

Todo:
    Support additional configuration file formats. only accepts json currently.
"""


import os
import json


DEFAULT_APPAUTHAL_CONFIG = '/etc/jazzhands/appauth-config.json'
DEFAULT_APPAUTHAL_FILE_DIR = '/var/lib/jazzhands/appauth-info'
DEFAULT_CONFIG_FILE_FORMAT = 'json'


class AppAuthAL(object):
    """AppAuthAL provides auth configuration dictionaries for the requested applications.

    Looks for main AppAuthAL config during init, defaults to dbaal.DEFAULT_APPAUTHAL_CONFIG
    overridden by setting the APPAUTHAL_CONFIG enviroment variable. When neither configuration
    file is found, DBAAL will only search dbaal. DEFAULT_APPAUTHAL_FILE_DIR for application config
    files.
    """

    def __init__(self):
        self._main_config = self._get_main_config()
        self._conf_format = self._main_config.get('conf_file_format', DEFAULT_CONFIG_FILE_FORMAT)

    def _get_main_config(self):
        main_config_fname = os.getenv('APPAUTHAL_CONFIG', default=DEFAULT_APPAUTHAL_CONFIG)
        if not os.path.isfile(main_config_fname):
            config = {'search_dirs' : [DEFAULT_APPAUTHAL_FILE_DIR]}
        else:
            config = self._load_json_conf(main_config_fname)
        if 'onload' in config:
            for envar, enval in config['onload'].get('environment', dict()).items():
                os.environ[envar] = enval
        return config

    @staticmethod
    def _load_json_conf(config_f):
        with open(config_f, 'r') as _fh:
            config = json.load(_fh)
        return config

    def find_auth_file(self, app, instance=None):
        """Take an app name and optionaly an instance name, and returns the auth file location.

        Args:
            app (str): name of the applications config to load
            instance (str, optional): the specific instance of the app to load

        Returns:
            str: path to auth file

        Raises:
            AppAuthALException: if no configuration file can be found
        """
        config_search_dirs = self._main_config['search_dirs']
        if instance:
            for config_search_dir in config_search_dirs:
                instance_dir = os.path.join(config_search_dir, app)
                instance_path = os.path.join(instance_dir, '{}.json'.format(instance))
                if instance_path:
                    return instance_path
        for config_search_dir in config_search_dirs:
            config_path = os.path.join(config_search_dir, '{}.json'.format(app))
            if os.path.isfile(config_path):
                return config_path
        raise AppAuthALException('Failed to find a config')

    def find_and_parse_auth(self, app, instance=None, config_format=None):
        """Take an app name and optionaly an instance name, and returns the auth dictionary.

        Args:
            app (str): name of the applications config to load
            instance (str, optional): the specific instance of the app to load
            config_format (str, optional): override the global config format default

        Returns:
            dict: AppAuthAL style dictionary
        """
        auth_file = self.find_auth_file(app, instance)
        if not config_format:
            config_format = self._conf_format
        return getattr(self, '_load_{}_conf'.format(config_format))(auth_file)


class AppAuthALException(Exception):
    """General AppAuthAL exceptions"""
    pass
