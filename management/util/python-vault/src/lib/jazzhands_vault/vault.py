#!/usr/bin/env python

"""
Xandr front-end for Hasicorp Vault
"""

from __future__ import print_function
import json
import logging
import os
import pprint
import subprocess
import sys

import requests

class Vault(object):
    """ Xandr front-end for Hashicorp Vault """

    def __init__(self, vault_uri="https://vault.appnexus.net:8200",
                 vault_role_id_file=None,
                 vault_secret_id_file=None,
                 vault_token_file=None,
                 timeout=None):

        self._vault_uri = vault_uri
        self._vault_role_id_file = vault_role_id_file
        self._vault_secret_id_file = vault_secret_id_file
        self._vault_token_file = vault_token_file
        self._timeout = timeout

        self._token = None
        self._role_id_data = None
        self._secret_id_data = None
        self._api = requests.Session()

    @property
    def _role_id(self):
        """ Get the role_id """

        if self._role_id_data:
            return self._role_id_data

        try:
            with open(self._vault_role_id_file, "r") as filep:
                self._role_id_data = filep.read().strip()
        except OSError as error:
            sys.exit(error)

        return self._role_id_data

    @property
    def _secret_id(self):
        """ Get the secret_id """

        if self._secret_id_data:
            return self._secret_id_data

        try:
            with open(self._vault_secret_id_file, "r") as filep:
                self._secret_id_data = filep.read().strip()
        except OSError as error:
            sys.exit(error)

        return self._secret_id_data

    def _token_header(self):
        """ Return the headers with the token """

        if not self._token:
            return {}

        return {
            "X-Vault-Token": self._token
            }

    def _get(self, path, timeout=None):
        """ Issue a get requests """

        try:
            response = self._api.get(os.path.join(self._vault_uri, "v1", path),
                                     headers=self._token_header(),
                                     timeout=timeout if timeout is not None else self._timeout)
            logging.debug("GET %s: %s", path, pprint.pformat(response.json()))
        except IOError as error:
            sys.exit(error)

        return response.json()['data']

    def _list(self, path, timeout=None):
        """ Issue a LIST request """

        try:
            response = self._api.request("LIST",
                                         os.path.join(self._vault_uri, "v1", path),
                                         headers=self._token_header(),
                                         timeout=timeout if timeout is not None else self._timeout)
            logging.debug("LIST %s: %s", path, pprint.pformat(response.json()))
        except IOError as error:
            sys.exit(error)

        return response.json()['data']

    def _post(self, path, data, timeout=None):
        """ Issue a POST request """

        try:
            response = self._api.post(os.path.join(self._vault_uri, "v1", path),
                                      headers=self._token_header(),
                                      data=data,
                                      timeout=timeout if timeout is not None else self._timeout)
        except IOError as error:
            sys.exit(error)

        return response.json()

    def get_token(self, ttl_refresh_seconds=300, timeout=None):
        """
        Ensure we have a token valid for the specified TTL

        Runs /usr/libexec/jazzhands/creds-mgmt-client if we don't have our secrets yet.
        """

        self._token = None

        # If we have a token with adequate TTL, return
        try:
            with open(self._vault_token_file, "r") as filep:
                self._token = filep.read().strip()

            data = self._get("auth/token/lookup-self", timeout=timeout)
            ttl = int(data['ttl'])
            if ttl > ttl_refresh_seconds:
                return True
        except (IOError, KeyError, ValueError):
            logging.debug("Token in %s not available or insufficient TTL", self._vault_token_file)

        if not os.path.exists(self._vault_secret_id_file):
            try:
                subprocess.check_output([
                    "/usr/libexec/jazzhands/creds-mgmt-client",
                    "--purge-cache"
                ], stderr=subprocess.STDOUT)
            except (OSError, subprocess.CalledProcessError) as error:
                logging.warning("creds-mgmt-client: %s", error.output)
                sys.exit(1)

        post = {
            "role_id": self._role_id,
            "secret_id": self._secret_id,
        }

        data = self._post("auth/approle/login", data=json.dumps(post))
        try:
            token = data['auth']['client_token']
        except KeyError as error:
            if 'errors' in data:
                sys.exit(data['errors'][0])
            else:
                sys.exit(error)

        if not token or token == "":
            return False

        self._token = token

        try:
            with open(self._vault_token_file, "w") as filep:
                filep.write(self._token)
            logging.debug("Wrote new token to %s", self._vault_token_file)
        except IOError as error:
            logging.warning("Unable to write %s: %s",
                            self._vault_token_file,
                            error)

        return True

    def list(self, path, timeout=None):
        """
        Returns a listing of the kv at path.

        Returns the data or None.

        Errors are logged.

        HTTPS errors are fatal
        """

        try:
            data = self._list(path.replace("/data/", "/metadata/", 1), timeout=timeout)
            return data['keys']
        except KeyError:
            if 'errors' in data:
                logging.warning("Reading kv %s: %s", path, "; ".join(data['errors']))
            return []
        except IOError as error:
            logging.error("Getting listing of %s: %s", path, error)
            sys.exit(1)

    def read(self, path, timeout=None):
        """
        Returns the kv at path.

        Returns the data or None.

        Errors are logged.

        HTTPS errors are fatal
        """

        try:
            data = self._get(path, timeout=timeout)
            return data['data']
        except KeyError:
            if 'errors' in data:
                logging.warning("Reading kv %s: %s", path, "; ".join(data['errors']))
            return None
        except IOError as error:
            logging.error("Reading kv %s: %s", path, error)
            sys.exit(1)

    def write(self, path, data, timeout=None):
        """
        Write the kv at path.

        Returns True on success.

        Logs error and returns False on failure.
        """

        try:
            data = self._post(path, data, timeout=timeout)
            if 'errors' in data:
                logging.warning("Reading kv %s: %s", path, "; ".join(data['errors']))
            return False
        except IOError as error:
            logging.error("Writing kv %s: %s", path, error)
            sys.exit(1)

        return True

    def get_health(self, standby_ok, perf_standby_ok, timeout=None, verify=True):
        """ Check the health of the Vault server """

        params = {}
        if standby_ok:
            params['sendbyok'] = standby_ok
        if perf_standby_ok:
            params['perfstandbyok'] = perf_standby_ok

        path = os.path.join(self._vault_uri, "v1/sys/health")
        try:
            response = self._api.get(path,
                                     params=params,
                                     timeout=timeout if timeout is not None else self._timeout,
                                     verify=verify)
            logging.debug("GET %s: %s", path, response.status_code)
        except IOError as error:
            logging.warning(error)
            return False

        return response.status_code == 200
