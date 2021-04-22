#!/usr/bin/env python
"""
JazzHands front-end for Hasicorp Vault
"""

import json
import logging
import os
import pprint
import requests

logger = logging.getLogger(__name__)


class Vault(object):
    """JazzHands front-end for Hashicorp Vault."""
    def __init__(
        self,
        uri=None,
        role_id=None,
        role_id_file=None,
        secret_id=None,
        secret_id_file=None,
        token=None,
        token_file=None,
        timeout=None,
    ):
        self.uri = uri or os.getenv('VAULT_ADDR')
        self._role_id = role_id
        self._role_id_file = role_id_file
        self._secret_id = secret_id
        self._secret_id_file = secret_id_file
        self._token = token
        self._token_file = token_file
        self.timeout = timeout
        self._api = requests.Session()

    @property
    def role_id(self):
        """Get the role_id from _role_id or _role_id_file."""

        if self._role_id:
            return self._role_id
        elif self._role_id_file:
            try:
                with open(self._role_id_file, 'r') as filep:
                    self._role_id = filep.read().strip()
            except IOError as e:
                raise VaultIOError('Cannot read role_id file: {}'.format(e))
            return self._role_id
        else:
            return None

    @role_id.setter
    def role_id(self, role_id):
        self._role_id = role_id

    @property
    def role_id_file(self):
        return self._role_id_file

    @role_id_file.setter
    def role_id_file(self, role_id_file):
        self._role_id_file = role_id_file

    @property
    def secret_id(self):
        """Get the secret_id from _secret_id or _secret_id_file."""

        if self._secret_id:
            return self._secret_id
        elif self._secret_id_file:
            try:
                with open(self._secret_id_file, 'r') as filep:
                    self._secret_id = filep.read().strip()
            except IOError as e:
                raise VaultIOError('Cannot read secret_id file: {}'.format(e))
            return self._secret_id
        else:
            return None

    @secret_id.setter
    def secret_id(self, secret_id):
        self._secret_id = secret_id

    @property
    def secret_id_file(self):
        return self._secret_id_file

    @secret_id_file.setter
    def secret_id_file(self, secret_id_file):
        self._secret_id_file = secret_id_file

    @property
    def token(self):
        """Get the token from _token or from _token_file."""

        if self._token:
            return self._token
        elif self._token_file:
            try:
                with open(self._token_file, 'r') as filep:
                    self._token = filep.read().strip()
                return self._token
            except IOError:
                return None
        else:
            return None

    @token.setter
    def token(self, token):
        self._token = token

    @property
    def token_file(self):
        return self._token_file

    @token_file.setter
    def token_file(self, token_file):
        self._token_file = token_file

    def _token_header(self):
        """Return the HTTP headers with the Vault token included."""

        return {'X-Vault-Token': self.token} if self.token else {}

    def _get(self, path, timeout=None):
        """Issue a GET request for path."""

        try:
            response = self._api.get(
                os.path.join(self.uri, 'v1', path),
                headers=self._token_header(),
                timeout=timeout if timeout is not None else self.timeout,
            )
        except IOError as e:
            raise VaultIOError(e)
        parsed = response.json()
        logger.debug('GET %s: %s', path, pprint.pformat(parsed))
        if 'errors' in parsed:
            if parsed['errors']:
                raise VaultResponseError(', '.join(parsed['errors']))
            else:
                raise VaultResponseError('Unspecified error')
        return parsed

    def _list(self, path, timeout=None):
        """Issue a LIST request for path."""

        try:
            response = self._api.request(
                'LIST',
                os.path.join(self.uri, 'v1', path),
                headers=self._token_header(),
                timeout=timeout if timeout is not None else self.timeout,
            )
        except IOError as e:
            raise VaultIOError(e)
        parsed = response.json()
        logger.debug('LIST %s: %s', path, pprint.pformat(parsed))
        if 'errors' in parsed:
            if parsed['errors']:
                raise VaultResponseError(', '.join(parsed['errors']))
            else:
                raise VaultResponseError('Unspecified error')
        return parsed

    def _post(self, path, data, timeout=None):
        """Issue a POST request for path."""

        try:
            response = self._api.post(
                os.path.join(self.uri, 'v1', path),
                headers=self._token_header(),
                data=data,
                timeout=timeout if timeout is not None else self.timeout,
            )
        except IOError as e:
            raise VaultIOError(e)
        if response.status_code == 204:
            return None
        else:
            parsed = response.json()
            logger.debug('POST %s: %s', path, pprint.pformat(parsed))
        if 'errors' in parsed:
            if parsed['errors']:
                raise VaultResponseError(', '.join(parsed['errors']))
            else:
                raise VaultResponseError('Unspecified error')
        return parsed

    def get_token(self, ttl_refresh_seconds=300, timeout=None):
        """Ensure we have a token valid for the specified TTL

        If we already have a token, the function verifies whether
        the token is still valid and whether the token TTL is at least
        ttl_refresh_seconds. In case the token is unavailable, invalid,
        or the TTL is too short, the function uses the role_id and secret_id
        to authenticate and obtain a new token. If token_file is defined,
        the function attempts to write the token to token_file but failure
        to write to the file is only logged as a warning.
        """

        try:
            data = self._get('auth/token/lookup-self', timeout=timeout)
            ttl = int(data['data']['ttl'])
            if ttl > ttl_refresh_seconds:
                return
        except (VaultError, KeyError, ValueError):
            logger.debug('Token not available or insufficient TTL')
        if not self.role_id:
            raise VaultParameterError(
                'Neither role_id nor role_id_file defined')
        if not self.secret_id:
            raise VaultParameterError(
                'Neither secret_id nor secret_id_file defined')
        post = {
            'role_id': self.role_id,
            'secret_id': self.secret_id,
        }
        data = self._post('auth/approle/login',
                          data=json.dumps(post),
                          timeout=timeout)
        try:
            token = data['auth']['client_token']
        except (KeyError, TypeError):
            raise VaultValueError(
                "Vault server response does not contain 'client_token'")
        self._token = token
        if self._token_file:
            try:
                with open(self._token_file, 'w') as filep:
                    filep.write(self._token)
                logger.debug('Wrote new token to %s', self._token_file)
            except IOError as e:
                logger.warning('Unable to write %s: %s', self._token_file, e)

    def revoke_token(self, timeout=None):
        """Revoke the current token"""

        if self.token:
            self._post('auth/token/revoke-self', data='', timeout=timeout)

    def list(self, path, timeout=None):
        """Returns a list of KV secrets at the specified location."""

        data = self._list(path.replace('/data/', '/metadata/', 1),
                          timeout=timeout)
        try:
            return data['data']['keys']
        except (KeyError, TypeError):
            raise VaultValueError(
                "Vault server response does not contain 'keys'")

    def read(self, path, timeout=None):
        """Returns the KV secrets at the specified location."""

        data = self._get(path, timeout=timeout)
        try:
            return data['data']['data']
        except (KeyError, TypeError):
            raise VaultValueError(
                "Vault server response does not contain 'data'")

    def write(self, path, data, timeout=None):
        """Writes the KV secrets to the specified location."""

        data = self._post(path, data, timeout=timeout)


class VaultError(Exception):
    """Base class for Vault exceptions."""

    pass


class VaultParameterError(VaultError):
    pass


class VaultIOError(VaultError):
    pass


class VaultResponseError(VaultError):
    pass


class VaultValueError(VaultError):
    pass
