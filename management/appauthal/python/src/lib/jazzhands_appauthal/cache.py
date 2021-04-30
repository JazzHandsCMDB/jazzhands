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

import logging, os, tempfile, time, stat, json, psycopg2
from jazzhands_vault.vault import Vault, VaultError
from .db import DatabaseConnectionException, DatabaseConnectionOperationalError

LOG = logging.getLogger(__name__)
LOG.addHandler(logging.NullHandler())


def _is_cache_expired(cache):
    return int(cache['expired_whence']) < time.time()


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
        self._opt_merged = options['vault'].copy()
        self._opt_merged.update(db_authn)

    def _get_cache_dir(self):
        """Returns cache directory for caching DB credentials."""

        cachedir = '/run/user/{}'.format(os.getuid())
        if os.path.exists(cachedir) and os.path.isdir(cachedir):
            cachedir = os.path.join(cachedir, 'jazzhands-dbi-cache')
        else:
            cachedir = '/tmp/__jazzhands-appauthal-cache__-{}'.format(
                os.getuid())
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
            key = "%s@%s/%s" % (mrg['VaultServer'], mrg['VaultRoleId'],
                                mrg['VaultPath'])
            return key.replace('/', '_').replace(':', '_')
        return None

    def _assemble_cache(self, metadata, authn):
        """Returns cache dictionary to be written to cache file."""

        expire = int(time.time() +
                     self._options.get('DefaultCacheExpiration', 86400))
        if 'lease_duration' in metadata:
            divisor = self._options.get('DefaultCacheDivisor', 2)
            expire = int(time.time() + metadata['lease_duration'] / divisor)
        return {'expired_whence': expire, 'auth': authn}

    def _write_cache(self, cache):
        """Saves cache dictionary to cache file."""

        cache_dir = self._get_cache_dir()
        cache_filename = self._get_cache_filename()
        if not cache_dir or not cache_filename:
            return
        cache_pathname = os.path.join(cache_dir, cache_filename)
        try:
            tmp = tempfile.NamedTemporaryFile(mode='w',
                                              dir=cache_dir,
                                              delete=False)
            json.dump(cache, tmp)
            tmp.close()
            os.rename(tmp.name, cache_pathname)
            os.chmod(cache_pathname, 0o500)
        except IOError:
            pass

    def _read_cache(self):
        """Reads cached DB credentials."""

        cache_dir = self._get_cache_dir()
        cache_filename = self._get_cache_filename()
        if not cache_dir or not cache_filename:
            return None
        cache_pathname = os.path.join(cache_dir, cache_filename)
        try:
            with open(cache_pathname, 'r') as f:
                cache = json.load(f)
        except (IOError, KeyError, ValueError, json.JSONDecodeError):
            return None
        return cache

    def _is_caching_enabled(self):
        caching = self._options.get('Caching', 'yes')
        if caching.lower() in ('no', 'n', '0'):
            return False
        elif caching.lower() in ('yes', 'y', '1'):
            return True
        return True

    def _translate_authn(self, authn):
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
        return {par_map[x]: authn[x] for x in common_keys}

    def _get_vault_params(self):
        """Parse Vault parameters from _opt_merged and return them."""

        params = {}
        if all(x in self._opt_merged
               for x in ('VaultSecretIdPath', 'VaultSecretId')):
            raise DatabaseConnectionException(
                'Both VaultSecretIdPath and VaultSecretId are defined')
        if 'VaultSecretIdPath' in self._opt_merged:
            params['secret_id_file'] = self._opt_merged['VaultSecretIdPath']
        elif 'VaultSecretId' in self._opt_merged:
            params['secret_id'] = self._opt_merged['VaultSecretId']
        else:
            raise DatabaseConnectionException(
                'Neither VaultSecretIdPath nor VaultSecretId defined')
        if all(x in self._opt_merged
               for x in ('VaultRoleIdPath', 'VaultRoleId')):
            raise DatabaseConnectionException(
                'Both VaultRoleIdPath and VaultRoleId are defined')
        if 'VaultRoleIdPath' in self._opt_merged:
            params['role_id_file'] = self._opt_merged['VaultRoleIdPath']
        elif 'VaultRoleId' in self._opt_merged:
            params['role_id'] = self._opt_merged['VaultRoleId']
        else:
            raise DatabaseConnectionException(
                'Neither VaultRoleIdPath nor VaultRoleId defined')
        if 'VaultServer' in self._opt_merged:
            params['uri'] = self._opt_merged['VaultServer']
        else:
            raise DatabaseConnectionException('VaultServer not defined')
        if 'VaultPath' not in self._opt_merged:
            raise DatabaseConnectionException('VaultPath not defined')
        return params

    def _merge_vault_secrets(self, secrets):
        """Merge Vault secrets with _opt_merged and return DB authn credentials."""

        par_map = self._opt_merged['map']
        authn = self._opt_merged['import'].copy()
        try:
            authn.update(
                {x: secrets['data'][par_map[x]]
                 for x in par_map.keys()})
            return authn
        except KeyError as err:
            return None

    def connect(self):
        """Returns a connected psycopg2 database handle using Vault/cached credentials."""

        ## [XXX] Add CA path to the Vault module

        cache = None
        if self._is_caching_enabled():
            cache = self._read_cache()
            if cache:
                t_cache = self._translate_authn(cache['auth'])
                if not _is_cache_expired(cache):
                    try:
                        return psycopg2.connect(**t_cache)
                    except psycopg2.Error:
                        pass
        vault_params = self._get_vault_params()
        vault = Vault(**vault_params)
        try:
            vault.get_token()
            secrets = vault.read(self._opt_merged['VaultPath'], metadata=True)
            vault.revoke_token()
        except VaultError as err:
            raise DatabaseConnectionException('{}: {}'.format(
                type(err).__name__, err))
        new_db_authn = self._merge_vault_secrets(secrets)
        if new_db_authn:
            t_new_db_authn = self._translate_authn(new_db_authn)
            try:
                dbh = psycopg2.connect(**t_new_db_authn)
            except psycopg2.Error:
                dbh = None
            if dbh:
                new_cache = self._assemble_cache(secrets['metadata'],
                                                 new_db_authn)
                if not cache or cache != new_cache:
                    self._write_cache(new_cache)
                return dbh
        if cache:
            try:
                return psycopg2.connect(**t_cache)
            except psycopg2.Error:
                raise DatabaseConnectionOperationalError(
                    'Cannot connect to the database using Vault/cached credentials'
                )
