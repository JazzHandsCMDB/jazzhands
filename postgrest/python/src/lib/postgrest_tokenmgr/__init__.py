'''The meat of the postgrest-tokenmgr'''


import sys
import json
import logging
import datetime


import jwt
from jazzhands_appauthal.db import DatabaseConnection
from psycopg2 import InternalError


DEFAULT_EXPIRE_HOURS = 365 * 24
DEFAULT_APPAUTHAL_NAME = 'postgrest-tokenmgr'
DEFAULT_SIGNING_KEY_FILE = '/etc/postgrest-utils/postgrest_signing_key.pem'


LOG = logging.getLogger('postgrest-tokenmgr')


def init_logging(debug=False, verbose=False):
    """Initializes logging"""
    if debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
    elif verbose:
        logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    else:
        logging.basicConfig(stream=sys.stdout, level=logging.ERROR)


class TokenMgr(object):
    """TokenMgr generates tokens and interacts with JazzHands"""

    def __init__(self, conf_file):
        self._conf = self._load_conf(conf_file)
        self._expire = self._conf.get('token_expire_hours', DEFAULT_EXPIRE_HOURS)
        self._appauth = self._conf.get('appauthal_name', DEFAULT_APPAUTHAL_NAME)
        self._sign_file = self._conf.get('signing_key_file', DEFAULT_SIGNING_KEY_FILE)
        self._dry_run = self._conf.get('dry_run', False)
        self._dbh = self._connect_db()
        with open(self._sign_file, 'r') as _fh:
            self._sign_key = _fh.read()

    @staticmethod
    def _load_conf(conf_file):
        LOG.debug('config_file: %s', conf_file)
        with open(conf_file, 'r') as _fh:
            conf = json.load(_fh)
            LOG.debug('parsed conf: %s', conf)
            return conf

    def _connect_db(self):
        dbh = DatabaseConnection(self._appauth).connect(psycopg2_cursor_factory='DictCursor')
        LOG.debug('Connected to: %s', dbh.dsn)
        return dbh

    def _run_qry(self, qry, args):
        dbc = self._dbh.cursor()
        try:
            dbc.execute(qry, args)
        except InternalError as exc:
            LOG.exception(exc)
            self._dbh.rollback()
            raise Exception('JazzHands error: {}'.format(exc))
        LOG.debug('Ran query: %s', dbc.query)
        return dbc.fetchall()

    def _commit(self):
        if not self._dry_run:
            self._dbh.commit()

    def _incr_user_tvn(self, login, aud):
        """Update the provided logins tvn number and create initial if the login doesn't
        yet exist. Returns the current TVN to use"""
        qry = 'SELECT postgrest_support.mint_token(%s, %s)'
        args = (login, aud)
        tvn = self._run_qry(qry, args)[0][0]
        self._commit()
        LOG.info('Token incremented for %s to %s', login, tvn)
        return tvn

    def generate_token(self, login, aud, expire=None):
        """Generates a JWT for the supplied user

        Args:
            - login (str): username of jwt requester. must have a db role
            - aud (str): value to supply to aud claim. normally the service you are granting
                access to. ex api.jazzhands.com
            - expire (int) opt: number of hours before expiring the ticket

        Returns
            str - signed jwt for the user
        """
        if not expire:
            expire = self._expire
        LOG.info('generate_token login: %s aud: %s expire: %s', login, aud, expire)
        LOG.debug('Using key in: %s', self._conf.get('signing_key_file'))
        tvn = self._incr_user_tvn(login, aud)
        token_payload = {
            'tvn': tvn, 'role': login, 'aud': aud,
            'exp': datetime.datetime.now() + datetime.timedelta(expire)}
        return jwt.encode(token_payload, self._sign_key, algorithm='RS256')

    def set_token_state(self, login, aud, enabled):
        """Takes role, audience and enabled and sets the corresponding token to the required
        state.

        Args:
            - login (str): username of jwt requester. must have a db role
            - aud (str): value to supply to aud claim. normally the service you are granting
                access to. ex api.jazzhands.com
            - enabled (bool): true if token should be enabled, false if disabled

        Return:
            bool - new state of the token (should match what you asked for)
        """
        LOG.info('set_token_state login: %s aud: %s enabled: %s', login, aud, enabled)
        qry = '''
            UPDATE
                postgrest_support.jwt_user_tokens
            SET
                token_enabled = %s
            WHERE
                account_id = (SELECT account_id FROM jazzhands.v_corp_family_account WHERE login = %s)
                AND
                audience = %s
            RETURNING
                *'''
        args = (enabled, login, aud)
        try:
            res = self._run_qry(qry, args)[0]['token_enabled']
        except IndexError:
            raise TokenMgrException('Nothing returned from JH. Check your role and audience')
        self._commit()
        return res

    def get_tokens(self, role=None, aud=None):
        """Returns a list of user tokens. Can filter on role or audience"""
        LOG.debug('list_tokens role: %s aud: %s', role, aud)
        vals = {}
        qry = '''
            SELECT
                role,
                audience,
                tvn,
                token_enabled::VARCHAR
            FROM
                postgrest_support.v_jwt_user_tokens'''
        if role:
            qry += ' WHERE role = %(role)s '
            vals['role'] = role
        if aud and role:
            qry += ' AND audience = %(aud)s '
            vals['aud'] = aud
        elif aud:
            qry += ' WHERE audience = %(aud)s'
            vals['aud'] = aud
        LOG.debug('db query: %s', qry)
        dbc = self._dbh.cursor()
        dbc.execute(qry, vals)
        return dbc.fetchall()


class TokenMgrException(Exception):
    """For when things go wrong..."""
    pass