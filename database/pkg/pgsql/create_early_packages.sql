--
-- Copyright (c) 2011-2021 Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
--
-- This will create all packages in the proper order
--
-- $Id$
--

--
-- NOTE:  make sure that ../ddl/dropJazzHandsdev.sql has any packages you
-- add here!
--


-- its not clear that any of the types need to survive and the oracle
-- types should be rethought, so this is nonexistant until needed.
--
-- \ir global_types.sql
--
-- This includes all the error types, however it looks like pgsql does not
-- support defining constants in a similar fashion (did not research
-- extensively) so they are just being hardcoded where used.  Note that
-- unlike the oracle errors, these are positive (can't be negative under
-- pgsql).  This also contains error stack traces which we didn't really
-- use under oracle, so they haven't been ported to postgresql.  That should
-- be reconciled.
--
-- \ir global_errors.sql
--
-- This has some handy utilities that were never really used in oracle
-- space, so not porting them to postgresql.  Like the global_errors
-- package, this may need to be rethought.
-- 
-- \ir global_util.sql
-- 

\ir net_manip.sql
\ir network_strings.sql
\ir time_util.sql
-- One or both of these may no longer need to be here.
\ir dns_utils.sql
\ir dns_manip.sql
\ir service_utils.sql
