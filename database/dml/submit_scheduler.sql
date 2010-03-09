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
--
-- $Id$
--

-- (10/1440) is 10 minutes
-- 1 is per day


-- GRANT CREATE JOB TO jazzhands;
-- GRANT MANAGE SCHEDULER TO jazzhands;

--alter session set NLS_TIMESTAMP_TZ_FORMAT  = 'YYYY-MM-DD HH24:MI:SS.FF';
alter session set NLS_TIMESTAMP_TZ_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF TZH:TZM';

exec dbms_session.set_identifier('exp_sysusrs_job');


exec dbms_scheduler.drop_job('exp_sysusrs_job');
exec dbms_scheduler.drop_schedule('hourly_five_before_hour');
exec dbms_scheduler.drop_program('expire_system_users');


exec dbms_scheduler.drop_job('cleanup_sysusrauth_job');
exec dbms_scheduler.drop_schedule('daily_at_ten_past_midnight');
exec dbms_scheduler.drop_program('cleanup_system_user_auth_log');

begin
 -- ========= expire system users hourly.
 DBMS_SCHEDULER.CREATE_SCHEDULE(
		schedule_name	=>	'hourly_five_before_hour',
		start_date	=>	'2007-06-01 00:00:00.00 00:00',
		repeat_interval	=>	'FREQ=HOURLY;INTERVAL=1;BYMINUTE=55', -- Every hour at 5 of the hour 
		end_date	=>	NULL,
		comments	=>	'Used for expiring system users at 5 of the hour'
	);
		
 DBMS_SCHEDULER.CREATE_PROGRAM(
		program_name	=>	'expire_system_users',
		program_type	=>	'stored_procedure',
		program_action	=>	'jazzhands.dbms_job_util.terminate_expired_users',
		number_of_arguments	=>	0,
		enabled		=>	TRUE,
		comments	=>	'Program for expiring (changing system_user_status) of system_users whos termination date has passed'
	);

		
 DBMS_SCHEDULER.CREATE_JOB (
		job_name	=>	'exp_sysusrs_job',
		program_name	=>	'expire_system_users',
		schedule_name	=>	'hourly_five_before_hour',
		enabled		=>	TRUE
	);

	-- 
	--	dbms_scheduler.enable('EXP_SYSUSRS_JOB');

 -- ========= cleanup system_user_auth_log

 DBMS_SCHEDULER.CREATE_SCHEDULE(
		schedule_name	=>	'daily_at_ten_past_midnight',
		start_date	=>	'2009-09-16 00:10:00.00 00:00',
		repeat_interval	=>	'FREQ=DAILY',
		end_date	=>	NULL,
		comments	=>	'Used for cleaning out system_user_auth_log at 00:10'
	);
		
 DBMS_SCHEDULER.CREATE_PROGRAM(
		program_name	=>	'cleanup_system_user_auth_log',
		program_type	=>	'stored_procedure',
		program_action	=>	'jazzhands.dbms_job_util.cleanup_system_user_auth_log',
		number_of_arguments	=>	0,
		enabled		=>	TRUE,
		comments	=>	'Program for expiring (changing system_user_status) of system_users whos termination date has passed'
	);

		
 DBMS_SCHEDULER.CREATE_JOB (
		job_name	=>	'cleanup_sysusrauth_job',
		program_name	=>	'cleanup_system_user_auth_log',
		schedule_name	=>	'daily_at_ten_past_midnight',
		enabled		=>	TRUE
	);

end;
/


prompt 'Using the scheduler'
prompt 'http://download.oracle.com/docs/cd/B14117_01/server.101/b10739/scheduse.htm'


SELECT * FROM DBA_SCHEDULER_JOB_CLASSES;

SELECT * FROM DBA_SCHEDULER_SCHEDULES;

SELECT * FROM DBA_SCHEDULER_PROGRAMS;

--SELECT * FROM DBA_SCHEDULER_PROGRAM_ARGUMENTS;


SELECT JOB_NAME, STATE FROM DBA_SCHEDULER_JOBS
WHERE JOB_NAME = 'EXP_SYSUSRS_JOB';


SELECT JOB_NAME, OPERATION, OWNER FROM DBA_SCHEDULER_JOB_LOG;


SELECT JOB_NAME, STATUS FROM DBA_SCHEDULER_JOB_RUN_DETAILS
WHERE JOB_NAME ='EXP_SYSUSRS_JOB';

SELECT * FROM DBA_SCHEDULER_RUNNING_JOBS;

SELECT JOB_NAME, STATUS, ERROR#
FROM DBA_SCHEDULER_JOB_RUN_DETAILS WHERE JOB_NAME = 'EXP_SYSUSRS_JOB';


