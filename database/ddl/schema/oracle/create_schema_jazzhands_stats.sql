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
-- $Id$

prompt "Enter name for spool file in /tmp/:"
spool /tmp/&&spoolfile..drops
 
set echo on
set termout on


create table dev_function_history
(
	whence			date 			not null,
	device_function_type	varchar(200)		not null,
	tally			number			not null
)
	pctfree 10
	pctused 40
	initrans 1
	maxtrans 255
	storage
(
	initial 64K
	minextents 1
	maxextents unlimited
	freelists 1
	freelist groups 1
)
tablespace RPT_DATA01
logging
monitoring
noparallel;

create index idx_dev_func_history_whce on dev_function_history(whence)
pctfree 10
initrans 2
maxtrans 255
storage
(
    initial 64K
    minextents 1
    maxextents unlimited
)  
tablespace RPT_INDEX01;  

create table dev_function_mclass_history
(
	whence			date 			not null,
	device_function_type	varchar(200)		not null,
	total_in_mclass		number			not null,
	total			number			not null
)
	pctfree 10
	pctused 40
	initrans 1
	maxtrans 255
	storage
(
	initial 64K
	minextents 1
	maxextents unlimited
	freelists 1
	freelist groups 1
)
tablespace RPT_DATA01
logging
monitoring
noparallel;

create index idx_dev_func_mcl_history_whce on dev_function_mclass_history(whence)
pctfree 10
initrans 2
maxtrans 255
storage
(
    initial 64K
    minextents 1
    maxextents unlimited
)  
tablespace RPT_INDEX01;  

create table dev_baseline_history
(
	whence			date 			not null,
	unknown_version		number			not null,
	baselined		number			not null,
	legacy			number			not null
)
	pctfree 10
	pctused 40
	initrans 1
	maxtrans 255
	storage
(
	initial 64K
	minextents 1
	maxextents unlimited
	freelists 1
	freelist groups 1
)
tablespace RPT_DATA01
logging
monitoring
noparallel;

create index idx_dev_bline_whence on dev_baseline_history(whence)
pctfree 10
initrans 2
maxtrans 255
storage
(
    initial 64K
    minextents 1
    maxextents unlimited
)  
tablespace RPT_INDEX01;  
