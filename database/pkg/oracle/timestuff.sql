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
Functions needed:

NOW() - returns SYSTIMESTAMP

EPOCH( TIMESTAMP ) - returns seconds since the epoch

select extract(SECOND FROM (systimestamp - to_timestamp_tz('01-JAN-1969 00:00:00 GMT', 'DD-MON-RRRR HH24:MI:SS TZR'))) from dual; 

EpochInterval = SELECT (systimestamp - to_timestamp_tz('01-JAN-1969 00:00:00
 GMT', 'DD-MON-RRRR HH24:MI:SS TZR')) FROM DUAL;

EpochSeconds = (EXTRACT(DAY FROM EpochInterval) * 86400) +
	(EXTRACT(HOUR FROM EpochInterval) * 3600) +
	(EXTRACT(MINUTE FROM EpochInterval) * 60) +
	EXTRACT(SECOND FROM EpochInterval)


CREATE FUNCTION NOW 
	RETURN TIMESTAMP WITH LOCAL TIME ZONE
	IS
	ts TIMESTAMP WITH LOCAL TIME ZONE;
	BEGIN
		SELECT SYSTIMESTAMP INTO ts FROM DUAL;
		RETURN(ts);
	END;
/

CREATE FUNCTION EPOCH (DateTime TIMESTAMP WITH LOCAL TIME ZONE)
	RETURN NUMBER
	IS
	EpochTimeStamp TIMESTAMP WITH LOCAL TIME ZONE;
	EpochInterval INTERVAL DAY (9) TO SECOND (0);
	EpochSeconds INTEGER;
	BEGIN
		EpochTimeStamp := TO_TIMESTAMP_TZ('01-JAN-1970 00:00:00 GMT', 
			'DD-MON-RRRR HH24:MI:SS TZR');
		EpochInterval := DateTime - EpochTimeStamp;
		EpochSeconds := (EXTRACT(DAY FROM EpochInterval) * 86400) +
			(EXTRACT(HOUR FROM EpochInterval) * 3600) + 
			(EXTRACT(MINUTE FROM EpochInterval) * 60) +  
			EXTRACT(SECOND FROM EpochInterval);
		RETURN (EpochSeconds);
	END;
/
