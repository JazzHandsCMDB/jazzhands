/*
* Copyright (c) 2005-2010, Vonage Holdings Corp.
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*
* THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/*
 * $Id$
 *
 * System configuration routines for HOTPants
 *
 */

#include <hotpants_internals.h>

unsigned int hp_auth_debug = HOTPANTS_DEBUG;

/*
 * config_normal_seq_skew() - Get normal sequence skew configuration parameter.
 */

int
config_normal_seq_skew(HOTPants_DB * hpd, u_int32_t * skew)
{
	HPData data;
	int ret;

	if (!hpd || !hpd->get_config_param) {
		return EINVAL;
	}
	ret = hpd->get_config_param(hpd, "normal_seq_skew", &data);
	if (ret && ret != DB_KEYEMPTY && ret != DB_NOTFOUND) {
		return ret;
	} else if (ret == DB_KEYEMPTY || ret == DB_NOTFOUND) {
		*skew = HPCF_DEFAULT_NORMAL_SEQ_SKEW;
		return 0;
	}
	if (data.size != sizeof(u_int32_t)) {
		return HP_CONFIG_ERROR;
	}
	*skew = *(int *) (data.data);
	free(data.data);
	return 0;
}

/*
 * config_verify_seq_skew() - Get verified sequence skew config parameter.
 */

int
config_verify_seq_skew(HOTPants_DB * hpd, u_int32_t * skew)
{
	HPData data;
	int ret;

	if (!hpd || !hpd->get_config_param) {
		return EINVAL;
	}
	ret = hpd->get_config_param(hpd, "verify_seq_skew", &data);
	if (ret && ret != DB_KEYEMPTY && ret != DB_NOTFOUND) {
		return ret;
	} else if (ret == DB_KEYEMPTY || ret == DB_NOTFOUND) {
		*skew = HPCF_DEFAULT_VERIFY_SEQ_SKEW;
		return 0;
	}
	if (data.size != sizeof(u_int32_t)) {
		return HP_CONFIG_ERROR;
	}
	*skew = *(int *) (data.data);
	free(data.data);
	return 0;
}

/*
 * config_max_bad_logins() - Get maximum sequential bad logins config parameter.
 */

int
config_max_bad_logins(HOTPants_DB * hpd, u_int32_t * bad_logins)
{
	HPData data;
	int ret;

	if (!hpd || !hpd->get_config_param) {
		return EINVAL;
	}
	ret = hpd->get_config_param(hpd, "max_bad_logins", &data);
	if (ret && ret != DB_KEYEMPTY && ret != DB_NOTFOUND) {
		return ret;
	} else if (ret == DB_KEYEMPTY || ret == DB_NOTFOUND) {
		*bad_logins = HPCF_DEFAULT_MAX_BAD_LOGINS;
		return 0;
	}
	if (data.size != sizeof(u_int32_t)) {
		return HP_CONFIG_ERROR;
	}
	*bad_logins = *(int *) (data.data);
	free(data.data);
	return 0;
}

/*
 * config_lockout_time() - Get bad login lockout time config parameter
 */

int
config_lockout_time(HOTPants_DB * hpd, time_t * lockout_time)
{
	HPData data;
	int ret;

	if (!hpd || !hpd->get_config_param) {
		return EINVAL;
	}
	ret = hpd->get_config_param(hpd, "lockout_time", &data);
	if (ret && ret != DB_KEYEMPTY && ret != DB_NOTFOUND) {
		return ret;
	} else if (ret == DB_KEYEMPTY || ret == DB_NOTFOUND) {
		*lockout_time = HPCF_DEFAULT_LOCKOUT_TIME;
		return 0;
	}
	if (data.size != sizeof(u_int32_t)) {
		return HP_CONFIG_ERROR;
	}
	*lockout_time = *(time_t *) (data.data);
	free(data.data);
	return 0;
}
