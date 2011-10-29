<?php

//
// Copyright (c) 2011 Todd M. Kover
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

//
// $Id$
//

// Based on the perl version.

//
// If the environment variable is not set, the config file is optional.
// If it is set, it must exist.  Read it into __json.
//
// This runs on script intialization in order to be able to do things like
// set environment variables set in the script.  __json is then taken apart
// (or not) as connections are made.
//
$__json = null;
$__dbauthcfg = "/Users/kovert/.auth-info/auth-config.json";
if(getenv('DBAUTH_CONFIG')) {
	if(! file_exists(getenv('DBAUTH_CONFIG'))) {
		die("Unable to find dbauth config: ". getenv('DBAUTH_CONFIG'));
	} else {
		$__dbauthcfg = getenv('DBAUTH_CONFIG');
	}
}
if(file_exists($__dbauthcfg)) {
	echo "loading $__dbauthcfg";
	$__json = json_decode(file_get_contents($__dbauthcfg));
}

foreach ($__json->{'onload'}->{'environment'} as $rowcount => $row) {
	foreach ($row as $lhs => $rhs) {
		$_ENV[$lhs] = $rhs;
	}
}


class dbauth {
	private function parse_json_auth($filename) {
		return json_decode(file_get_contents($filename));
	}

	private function find_and_parse_series($place) {
		$default_dir = "/var/lib/jazzhands/dbauth-info";
		if(isset($__json) && isset($__json->{'search_dirs'})) {
			foreach ($__json->{'search_dirs'} as $dir) {
				if($dir == '.') {
					$dir = dirname($__dbauthcfg);
				}
				if(file_exists("$dir/$place.json")) {
					return dbauth::parse_json_auth("$dir/$place.json");
				}
			}
		} else {
			if(file_exists("$default_dir/$place.json")) {
				return dbauth::parse_json_auth("$default_dir/$place.json");
			}
		}
	}

	private function find_and_parse_auth($app, $instance) {
		global $__json;
		global $__dbauthcfg;
		if(isset($instance)) {
			echo "instance is set\n";
			$x = dbauth::find_and_parse_series("$instance/$app");
			if(isset($x)) {
				return($x);
			}
		}

		if(!isset($instance) || !isset($__json->{'sloppy_instance_match'}) ||
				$__json->{'sloppy_instance_match'} != 'no') {
			echo "global \n";
			$x = dbauth::find_and_parse_series("$app");
			if(isset($x)) {
				return($x);
			}
		}

		echo "returning nothing\n";
	}
	public function connect($app, $instance = null, $flags = null) {
		$dbspec = dbauth::find_and_parse_auth($app, $instance);

		switch( $dbspec->{'DBType'} ) {
			case 'postgresql':
					$connstr = "";
					if(isset( $dbspec->{'DBHost'}) ) {
						$connstr .= " host=".$dbspec->{'DBHost'};
					}
					if(isset( $dbspec->{'DBPort'}) ) {
						$connstr .= " port=".$dbspec->{'DBPort'};
					}
					if(isset( $dbspec->{'DBName'}) ) {
						$connstr .= " dbname=".$dbspec->{'DBName'};
					}
					if(isset( $dbspec->{'Service'}) ) {
						$connstr .= " service=".$dbspec->{'Service'};
					}
					if(isset( $dbspec->{'SSLMode'}) ) {
						$connstr .= " sslmode=".$dbspec->{'sslmode'};
					}
					if(isset( $dbspec->{'Options'}) ) {
						$connstr .= " sslmode=".$dbspec->{'Options'};
					}
					if(isset( $dbspec->{'Username'}) ) {
						$connstr .= " user=".$dbspec->{'Username'};
					}
					if(isset( $dbspec->{'Password'}) ) {
						$connstr .= " password=".$dbspec->{'Password'};
					}

					return pg_connect($connstr);
					break;
			case 'mysql':
					break;
			default:
				if(!isset($dbspec->{'DBType'})) {
					die( "unset dbtype");	// XXX -- set an error and return null
				} else {
					die("Unknown database ". $dbspec->{'DBType'});
				}
		}

		
	}
}

?>
