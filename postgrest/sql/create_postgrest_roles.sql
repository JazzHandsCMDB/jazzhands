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

-- Main PostgREST roles
CREATE ROLE postgrest_api_authenticator WITH NOINHERIT LOGIN;

-- Actual token generator user
CREATE ROLE app_postgrest_token_generator WITH LOGIN;

-- Support schema roles
CREATE ROLE postgrest_support_schema;
CREATE ROLE postgrest_support_ro;

-- Token generator user role
CREATE ROLE postgrest_support_token_gen;

-- Role for all API users
CREATE ROLE postgrest_users;
