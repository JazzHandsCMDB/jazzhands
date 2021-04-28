# Copyright 2021 Bernard Jech
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

"""Implements cached DB authentication with credentials obtained from Vault

Classes:
    VaultCache: The main Vault DB authentication caching class

Exceptions:
    DatabaseConnectionException: General module exceptions
    DatabaseConnectionOperationalError: Database operational exceptions
"""


import logging, os, time, stat, json, psycopg2
from jazzhands_vault.vault import Vault, VaultError
from .db import DatabaseConnectionException, DatabaseConnectionOperationalError


LOG = logging.getLogger(__name__)
LOG.addHandler(logging.NullHandler())


class VaultCache(object):
    """Caches DB credentials retreived from Vault and connects to the DB"""

    def __init__(self, options, db_authn):
        """Initializes the VaultCache object.

        Args:
            options (dictionary): options from the AppAuthAL file
            db_authn (dictionary): array item from the database section
                                   of the AppAuthAL file
        """
        self._options = options
        self._db_authn = db_authn
        self._opt_merged = options['vault'].copy()
        self._opt_merged.update(db_authn)

    def _get_cache_dir(self):
        """Returns cache directory for caching DB credentials."""
        
        cachedir = '/run/user/{}'.format(os.getuid())
        if os.path.exists(cachedir) and os.path.isdir(cachedir):
            cachedir = os.path.join(cachedir, 'jazzhands-dbi-cache')
        else:
            cachedir = '/tmp/__jazzhands-appauthal-cache__-{}'.format(os.getuid())
        if not os.path.exists(cachedir):
            try:
                os.mkdir(cachedir, mode=0o700)
            except IOError:
                return None
        if os.path.islink(cachedir):
            return None
        try:
            info = os.lstat(cachedir)
        except IOError:
            return None
        if info.st_uid != os.getuid():
            return None
        if info.st_mode & stat.S_IRWXO:
            return None
        return cachedir

    def _get_cache_filename(self):
        """Returns the cache base filename for caching DB credentials."""

        mrg = self._opt_merged
        if all(k in mrg for k in ('VaultRoleId', 'VaultServer', 'VaultPath')):
            key = "%s@%s/%s" % (mrg['VaultServer'], mrg['VaultRoleId'], mrg['VaultPath'])
            return key.replace('/', '_').replace(':', '_')
        return None

    def _get_cache_pathname(self):
        """Returns the pathname for caching DB credentials."""
        
        cache_dir = self._get_cache_dir()
        cache_filename = self._get_cache_filename()
        if not cache_dir or not cache_filename:
            return None
        return os.path.join(cache_dir, cache_filename)

    def _write_cache(self, cache):
        """Saves DB authn credentials to cache."""

        cache_pathname = self._get_cache_pathname()
        if not cache_pathname:
            return
        if os.path.exists(cache_pathname):
            try:
                os.remove(cache_pathname)
            except IOError:
                pass
        expire = int(time.time()) + self._options.get('DefaultCacheExpiration', 86400)
        if '__Expiration' in cache:
            divisor = self._options.get('DefaultCacheDivisor', 2)
            expire = time.time() + cache['__Expiration'] / divisor
            cache.pop('__Expiration')
        cache = { 'expired_whence': expire, 'auth': cache }
        try:
            with open(cache_pathname, 'w') as f:
                json.dump(cache, f)
                os.chmod(cache_pathname, 0o500)
        except IOError:
            pass

    def _read_cache(self):
        """Reads cached DB credentials."""

        cache_pathname = self._get_cache_pathname()
        if not cache_pathname:
            return None
        try:
            with open(cache_pathname, 'r') as f:
                cache = json.load(f)
            expire = int(cache['expired_whence'])
        except (IOError, KeyError, ValueError, json.JSONDecodeError):
            return None
        cache['auth']['expired'] = expire > time.time()
        return cache['auth']

    def _is_caching_enabled(self):
        caching = self._options.get('Caching', 'yes')
        if caching.lower() in ('no', 'n', '0'):
            return False
        elif caching.lower() in ('yes', 'y', '1'):
            return True
        return True

    def _translate_connect(self, authn):
        par_map = {
            'Username': 'user',
            'Password': 'password',
            'DBName':   'dbname',
            'DBHost':   'host',
            'DBPort':   'port',
            'Options':  'options',
            'Service':  'service',
            'SSLMode':  'sslmode'
        }
        common_keys = list(set(par_map.keys()) & set(authn.keys()))
        return psycopg2.connect(**{par_map[x]: authn[x] for x in common_keys})

    def _get_vault_params(self):
        """Parse Vault parameters from _opt_merged and return them."""

        params = {}
        if 'VaultSecretIdPath' in self._opt_merged:
            params['secret_id_file'] = self._opt_merged['VaultSecretIdPath']
        elif 'VaultSecretId' in self._opt_merged:
            params['secret_id'] = self._opt_merged['VaultSecretId']
        else:
            raise DatabaseConnectionException('Neither VaultSecretIdPath nor VaultSecretId defined')
        if all(x in self._opt_merged for x in ('VaultRoleIdPath', 'VaultRoleId')):
            raise DatabaseConnectionException('Both VaultRoleIdPath and VaultRoleId are defined')
        if 'VaultRoleIdPath' in self._opt_merged:
            params['role_id_file'] = self._opt_merged['VaultRoleIdPath']
        elif 'VaultRoleId' in self._opt_merged:
            params['role_id'] = self._opt_merged['VaultRoleId']
        else:
            raise DatabaseConnectionException('Neither VaultRoleIdPath nor VaultRoleId defined')
        if 'VaultServer' in self._opt_merged:
            params['uri'] = self._opt_merged['VaultServer']
        else:
            raise DatabaseConnectionException('VaultServer not defined')
        return params

    def _merge_vault_secrets(self, secrets):
        """Merge Vault secrets with _opt_merged and return DB authn credentials."""

        par_map = self._opt_merged['map']
        authn = self._opt_merged['import'].copy()
        try:
            authn.update({x: secrets[par_map[x]] for x in par_map.keys()})
            return authn
        except KeyError as err:
            return None
 
    def connect(self):
        """Returns a connected psycopg2 database handle using cached credentials 'Vault'.

        The logic of this function is taken from the Perl module JazzHands::AppAuthAL:

            1. fetch catched creds
            2. if success unexpired, try those
            3. if sucesssful conn, return
            4. if no cached creds, or expired, get new ones
            5. if new ones, try them
            6. if cached ones success, save in cache, return
            7. if new ones fail and cached exist, try
            8. if cached ones suceeded, return
            9. if cached ones failed, return failure            

        Returns:
            obj: database connection object

        Raises:
            DatabaseConnectionException: if any of the supplied configuration params are bogus
            DatabaseConnectionOperationalError: if any database errors occur during connection
        """

        ## [XXX] Modify Vault module to return ttl / expiration
        ## [XXX] Add CA path to the Vault module
        ## [XXX] Method is written to cache

        cache = None
        if self._is_caching_enabled():
            cache = self._read_cache()
            if cache and not cache['expired']:
                try:
                    return self._translate_connect(cache)
                except psycopg2.Error:
                    pass
        if not cache or cache['expired']:
            vault_params = self._get_vault_params()
            vault = Vault(**vault_params)
            try:
                vault.get_token()
                secrets = vault.read(self._opt_merged['VaultPath'])
                vault.revoke_token()
            except VaultError as err:
                raise DatabaseConnectionException(err)
            new_db_authn = self._merge_vault_secrets(secrets)
        if new_db_authn:
            try:
                dbh = self._translate_connect(new_db_authn)
            except psycopg2.Error:
                dbh = None
            if dbh:
                if not cache or cache['expired']:
                    if self._is_caching_enabled():
                        self._write_cache(new_db_authn)
                return dbh
        if cache:
            try:
                dbh = self._translate_connect(cache)
            except psycopg2.Error:
                raise DatabaseConnectionOperationalError(
                    'Cannot connect to the database using Vault/cached credentials') 
