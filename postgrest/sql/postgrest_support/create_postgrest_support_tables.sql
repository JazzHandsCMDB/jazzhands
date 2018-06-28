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

CREATE TABLE IF NOT EXISTS postgrest_support.jwt_user_tokens (
    jwt_id          SERIAL PRIMARY KEY,
    account_id      INTEGER REFERENCES jazzhands.account,
    audience        VARCHAR(255),
    tvn             INTEGER NOT NULL,
    token_enabled   BOOLEAN NOT NULL DEFAULT TRUE,
    created_date    TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE (account_id, audience)
);

CREATE OR REPLACE VIEW postgrest_support.v_jwt_user_tokens AS
    SELECT
        a.login AS role,
        CASE WHEN a.is_enabled = 'Y' THEN true
            ELSE false
        END AS user_enabled,
        j.audience,
        j.tvn,
        j.token_enabled
    FROM
        jazzhands.v_corp_family_account a
    INNER JOIN
        postgrest_support.jwt_user_tokens j
        USING(account_id)
;
