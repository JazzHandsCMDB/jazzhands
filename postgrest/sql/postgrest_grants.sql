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

-- Grant various user roles to the authenticator so it can assume them. should be one per user
-- We'll need to solve this with some sort of automation - feed extension

-- UNCOMMENT AND FILL ME IN
-- GRANT <COMMA_SEP_LIST_USERS> TO postgrest_api_authenticator;

-- support schema grants
GRANT USAGE ON SCHEMA postgrest_support TO postgrest_support_schema;
GRANT postgrest_support_schema TO postgrest_support_ro;
GRANT postgrest_support_schema TO postgrest_users;
GRANT postgrest_support_ro TO postgrest_support_token_gen;
GRANT SELECT ON ALL TABLES IN SCHEMA postgrest_support TO postgrest_support_ro;
GRANT EXECUTE ON FUNCTION postgrest_support.authenticate_user(), postgrest_support.pre_request() TO postgrest_users;
GRANT EXECUTE ON FUNCTION postgrest_support.mint_token(VARCHAR, VARCHAR) TO postgrest_support_token_gen; 

-- Grant token gen role to folks, this should be a feed
-- UNCOMMENT AND FILL ME IN
-- GRANT postgrest_support_token_gen TO <COMMA_SEP_LIST_USERS>;

-- Grant api usage to some users, this should be a feed
-- UNCOMMENT AND FILL ME IN
-- GRANT postgrest_users TO <COMMA_SEP_LIST_USERS>;
