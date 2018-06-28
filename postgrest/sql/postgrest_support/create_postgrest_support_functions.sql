-- Copyright 2018 Ryan D. Williams
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--     http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- authenticates the user, checks to make sure they are enabled and that their token is valid
CREATE OR REPLACE FUNCTION postgrest_support.authenticate_user() RETURNS VOID
AS $$
DECLARE
    _current_user VARCHAR;
    _user_tvn INTEGER;
    _claim_tvn INTEGER;
    _claim_aud VARCHAR;
    _key_enabled BOOLEAN;
    _user_enabled BOOLEAN;
BEGIN
    -- check for the required jwt claims
    IF current_setting('request.jwt.claim.tvn', true) IS NOT NULL THEN
        _claim_tvn := current_setting('request.jwt.claim.tvn');
    ELSE
        RAISE insufficient_privilege
        USING DETAIL = 'Claim does not contain tvn... it needs to';
    END IF;
    IF current_setting('request.jwt.claim.aud', true) IS NOT NULL THEN
        _claim_aud = current_setting('request.jwt.claim.aud');
    ELSE
        RAISE insufficient_privilege
        USING DETAIL = 'Claim does not contain tvn... it needs to';
    END IF;
    -- get the current user from the role setting
    _current_user = current_setting('role', true);
    -- verify the uniq role aud tvn combinition and check status of user and tokens
    SELECT
        tvn, token_enabled, user_enabled
    INTO
        _user_tvn, _key_enabled, _user_enabled
    FROM
        postgrest_support.v_jwt_user_tokens
    WHERE
        role = _current_user
        AND
        audience = _claim_aud;
    IF _user_tvn IS NULL THEN
        RAISE insufficient_privilege
        USING DETAIL = 'No tokens for this user registered in JH';
    ELSIF NOT _user_enabled THEN
        RAISE insufficient_privilege
        USING DETAIL = 'user: ' || current_user || ' is not enabled';
    ELSIF _user_tvn != _claim_tvn THEN
        RAISE insufficient_privilege
        USING DETAIL = 'Claim tvn: ' || _claim_tvn || ' does not match DB: ' || _user_tvn;
    ELSIF NOT _key_enabled THEN
        RAISE insufficient_privilege
        USING DETAIL = 'User token is disabled';
    END IF;
END;
$$
SET search_path = postgrest_support
LANGUAGE plpgsql SECURITY DEFINER;


-- Currently  only calls the auth SP but leaving here to future addtional pre_request foo
CREATE OR REPLACE FUNCTION postgrest_support.pre_request() RETURNS VOID
AS $$
BEGIN
    PERFORM postgrest_support.authenticate_user();
END;
$$ LANGUAGE plpgsql;


-- used by the token generation code to increment the TVN for a given user
CREATE OR REPLACE FUNCTION postgrest_support.mint_token(_role VARCHAR, _aud VARCHAR) RETURNS INTEGER
AS $$
DECLARE
    _new_tvn INTEGER;
    _account_id INTEGER;
BEGIN
    IF (SELECT 1 FROM pg_user WHERE usename = _role) IS NULL THEN
        RAISE EXCEPTION 'role % not found in DB. Role must exist before token minting', _role;
    END IF;

    SELECT
        account_id
    INTO
        _account_id
    FROM
        jazzhands.v_corp_family_account
    WHERE
        login = _role;

    INSERT INTO postgrest_support.jwt_user_tokens AS ujwt
        (account_id, tvn, token_enabled, audience)
    VALUES
        (_account_id, 1, true, _aud)
    ON CONFLICT (account_id, audience) DO UPDATE
        SET
            tvn = ujwt.tvn + 1
        WHERE
            ujwt.account_id = _account_id
            AND
            ujwt.audience = _aud
    RETURNING
        tvn
    INTO
        _new_tvn;
    RETURN _new_tvn;
END;
$$
SET search_path = postgrest_support
LANGUAGE plpgsql SECURITY DEFINER;

