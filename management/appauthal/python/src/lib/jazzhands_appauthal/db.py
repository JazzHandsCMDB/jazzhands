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

"""Implements the JazzHands AppAuthAL style database connectors

Classes:
    DatabaseConnection: the meat. Generates DB handles to requested applications

Exceptions:
    DatabaseConnectionException: General module exceptions
    DatabaseConnectionOperationalError: Database operational exceptions

Todo:
    Support additional drivers. MySQL and OBDC
"""


import sys, getpass, logging, psycopg2
try:
    import psycopg2
except ImportError:
    pass
try:
    import mysql.connector
except ImportError:
    pass

from .appauthal import AppAuthAL
from .cache import VaultCache, VaultCacheError


LOG = logging.getLogger(__name__)
LOG.addHandler(logging.NullHandler())


class DatabaseConnection(object):
    """DatabaseConnection provides database handles for requested applications"""

    def __init__(self, app=None, instance=None):
        """Initializes the DatabaseConnection object.

        If you do not supply an app name during initialization you must provide one to the
        connect function.

        Args:
            app (str, optional): app name
            instance (str, optional): the specific instance of the app to load
        """
        self._app = app
        self._instance = instance
        self._appauthal = AppAuthAL()
        self._app_config = self._get_app_config(app, instance)

    def _get_app_config(self, app, instance=None):
        if app:
            return self._appauthal.find_and_parse_auth(app, instance)

    def connect(self, app=None, instance=None, session_user=None, **kwargs):
        """Returns a database connection the requested application.

        Uses AppAuthAL to find the applications configuration file for connection details
        Options for that connection can be specified in the options stanza of the AppAuthAL file
        or supplied via keyword arguments.
        App name must either be provided when init'ing the DatabaseConnection object or supplied
        when calling this function

        Args:
            app (str, optional): app name, optional only if already supplied during obj init
            instance (str, optional): the specific instance of the app to load
            session_user (str, optional): the user to set as the jazzhands session user. defaults
                to the user running this script
            **kwargs: database connection options you wish to enable.  additive to any declared in
                the AppAuthAL file.
                Examples:
                    use_unicode_strings (yes|no): instruct psycopg2 to convert utf-8 strings
                        to python unicode objects
                    psycopg2_cursor_factory (str): [DictCursor|RealDictCursor]

        Returns:
            obj: database connection handle

        Raises:
            DatabaseConnectionException: if required arguments aren't supplied or unsupported
                config params are provided.
        """
        if app:
            config = self._get_app_config(app, instance)
        elif self._app_config:
            config = self._app_config
        else:
            raise DatabaseConnectionException('You must supply an app name at init or on connect')
        if not session_user:
            session_user = getpass.getuser()
        try:
            db_configs = self._app_config['database']
        except KeyError:
            raise DatabaseConnectionException(
                'AppAuthAL file does not have database section: {}'.format(
                    self._appauthal.find_auth_file(app, instance)))
        for config in db_configs:
            db_config = {
                'connection': config, 'options': self._app_config.get('options', dict()),
                'session_user': session_user}
            #adding in user specified options
            db_config['options'].update({key: val for key, val in kwargs.items()})
            try:
                if (config.get('DBType', '') == 'postgresql'
                or ('import' in config and config['import'].get('DBType', '') == 'postgresql')):
                    driver = PostgreSQL(db_config)
                    return driver.connect_db()
                if (config.get('DBType', '') == 'mysql'
                or ('import' in config and config['import'].get('DBType', '') == 'mysql')):
                    driver = MySQL(db_config)
                    return driver.connect_db()
                raise DatabaseConnectionException('Requested DBType not currently supported')
            except DatabaseConnectionOperationalError as exc:
                LOG.exception(exc)
        raise DatabaseConnectionException('Could not connect to any specified database')


class PostgreSQL(object):
    """PostgreSQL driver abstraction layer"""

    def __init__(self, db_config):
        """Initializes the PostgreSQL driver abstraction object.

        Args:
            db_config (dict): AppAuthAL database configuration dictionary

        Raises:
            DatabaseConnectionException: if any of the supplied configuration params are bogus
        """
        if 'psycopg2' not in sys.modules:
            raise DatabaseConnectionException('psycopg2 module not imported')
        if not db_config:
            raise DatabaseConnectionException('A db_config dictionary is required')
        self._db_config = db_config
        self._con_conf = db_config['connection']
        self._session_user = db_config.get('session_user')
        self._options = db_config.get('options', dict())
        if not isinstance(self._options, dict):
            raise DatabaseConnectionException('options arg must be dictionary')

    def _set_username(self, dbh):
        dbh.cursor().execute('set jazzhands.appuser to %s', (self._session_user,))

    def _translate_connect(authn):
        par_map = {
            'Username': 'user',
            'Password': 'password',
            'DBName': 'dbname',
            'DBHost': 'host',
            'DBPort': 'port',
            'Options': 'options',
            'Service': 'service',
            'SSLMode': 'sslmode'
        }
        common_keys = list(set(par_map.keys()) & set(authn.keys()))
        try:
            return psycopg2.connect(**{par_map[x]: authn[x] for x in common_keys})
        except psycopg2.Error as exc:
            raise ConnectionError(exc)

    def connect_db(self):
        """Returns a database connection based on the config provided at __init__

        Returns:
            obj: database connection object

        Raises:
            DatabaseConnectionException: if any of the supplied configuration params are bogus
            DatabaseConnectionOperationalError: if any database errors occur during connection
        """
        if self._con_conf.get('Method', '').lower() == 'password':
            if 'Username' not in self._con_conf or 'Password' not in self._con_conf:
                raise DatabaseConnectionException('password Method requires Username and Password')
            try:
                dbh = PostgreSQL._translate_connect(self._con_conf)
            except ConnectionError as exc:
                raise DatabaseConnectionOperationalError(exc)
        elif self._con_conf.get('Method', '').lower() == 'krb5':
            # clear Username and Password fields if provided. Force psycopg2 to use krb5
            self._con_conf.pop('Username', None)
            self._con_conf.pop('Password', None)
            try:
                dbh = PostgreSQL._translate_connect(self._con_conf)
            except ConnectionError as exc:
                raise DatabaseConnectionOperationalError(exc)
        elif self._con_conf.get('Method', '').lower() == 'vault':
            vc = VaultCache(self._options, self._con_conf)
            try:
                dbh = vc.connect(PostgreSQL._translate_connect)
            except VaultCacheError as exc:
                raise DatabaseConnectionOperationalError(exc)
        else:
            raise DatabaseConnectionException('Only password or krb5 method supported')
        if str(self._options.get('use_session_variables', 'no')).lower() != 'no':
            self._set_username(dbh)
        if str(self._options.get('use_unicode_strings', 'no')).lower() != 'no':
            import psycopg2.extensions
            psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
            psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)
        custom_cursor = self._options.get('psycopg2_cursor_factory')
        if custom_cursor:
            import psycopg2.extras
            try:
                dbh.cursor_factory = getattr(psycopg2.extras, custom_cursor)
            except AttributeError as exc:
                raise DatabaseConnectionException(
                    'psycopg2 doesnt have the requested cursor factory: {}'.format(custom_cursor))
        return dbh

class MySQL(object):
    """MySQL driver abstraction layer"""

    def __init__(self, db_config):
        """Initializes the Mysql driver abstraction object.

        Args:
            db_config (dict): AppAuthAL database configuration dictionary

        Raises:
            DatabaseConnectionException: if any of the supplied configuration params are bogus
        """
        if 'mysql.connector' not in sys.modules:
            raise DatabaseConnectionException('mysql.connector module not imported')
        if not db_config:
            raise DatabaseConnectionException('A db_config dictionary is required')
        self._db_config = db_config
        self._con_conf = db_config['connection']
        self._options = db_config.get('options', dict())
        if not isinstance(self._options, dict):
            raise DatabaseConnectionException('options arg must be dictionary')

    def _translate_connect(authn):
        par_map = {
            'Username': 'user',
            'Password': 'password',
            'DBName': 'database',
            'DBHost': 'host',
            'DBPort': 'port',
            'Compress': 'mysql_compression',
            'ConnectTimeout': 'mysql_connect_timeout',
            'SSLMode': 'mysql_ssl'
        }
        common_keys = list(set(par_map.keys()) & set(authn.keys()))
        try:
            return mysql.connector.connect(**{par_map[x]: authn[x] for x in common_keys})
        except mysql.connector.Error as exc:
            raise ConnectionError(exc)

    def connect_db(self):
        """Returns a database connection based on the config provided at __init__

        Returns:
            obj: database connection object

        Raises:
            DatabaseConnectionException: if any of the supplied configuration params are bogus
            DatabaseConnectionOperationalError: if any database errors occur during connection
        """
        if self._con_conf.get('Method', '').lower() == 'password':
            if 'Username' not in self._con_conf or 'Password' not in self._con_conf:
                raise DatabaseConnectionException('password Method requires Username and Password')
            try:
                dbh = MySQL._translate_connect(self._con_conf)
            except ConnectionError as exc:
                raise DatabaseConnectionOperationalError(exc)
        elif self._con_conf.get('Method', '').lower() == 'vault':
            vc = VaultCache(self._options, self._con_conf)
            try:
                dbh = vc.connect(MySQL._translate_connect)
            except VaultCacheError as exc:
                raise DatabaseConnectionOperationalError(exc)
        else:
            raise DatabaseConnectionException('Only password or krb5 method supported')
        return dbh

class DatabaseConnectionException(Exception):
    """General DatabaseConnection exceptions"""
    pass


class DatabaseConnectionOperationalError(Exception):
    """Database operation exceptions"""
    pass
