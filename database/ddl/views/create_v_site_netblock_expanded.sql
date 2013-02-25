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
-- $Id$
--

-- This view maps users to device collections and lists properties
-- assigned to the users in order of their priorities.

CREATE OR REPLACE VIEW v_site_netblock_expanded AS
WITH RECURSIVE parent_netblock AS (
  SELECT n.netblock_id, n.parent_netblock_id, n.ip_address, sn.site_code
  FROM netblock n LEFT JOIN site_netblock sn on n.netblock_id = sn.netblock_id
  WHERE n.parent_netblock_id IS NULL
  UNION
  SELECT n.netblock_id, n.parent_netblock_id, n.ip_address,
    coalesce(sn.site_code, p.site_code)
  FROM netblock n JOIN parent_netblock p ON n.parent_netblock_id = p.netblock_id
  LEFT JOIN site_netblock sn ON n.netblock_id = sn.netblock_id
)
SELECT site_code, netblock_id FROM parent_netblock;
