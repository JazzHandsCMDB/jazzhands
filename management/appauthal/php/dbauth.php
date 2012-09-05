<?php

//
// Copyright (c) 2011 Todd M. Kover
// All rights reserved.
//
// Copyright (c) 2011, Todd M. Kover
// All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
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
$__appauthcfg = "etc/jazzhands/appauth-config.json";
if(getenv('APPAUTHAL_CONFIG')) {
	if(! file_exists(getenv('APPAUTHAL_CONFIG'))) {
		die("Unable to find appauth config: ". getenv('APPAUTHAL_CONFIG'));
	} else {
		$__appauthcfg = getenv('APPAUTHAL_CONFIG');
	}
}
if(file_exists($__appauthcfg)) {
	$__json = json_decode(file_get_contents($__appauthcfg));
}

if(isset($__json->{'onload'}) && isset($__json->{'environment'})) {
	foreach ($__json->{'onload'}->{'environment'} as $rowcount => $row) {
		foreach ($row as $lhs => $rhs) {
			$_ENV[$lhs] = $rhs;
		}
	}
}


class dbauth {
	private function parse_json_auth($filename) {
		$thing = json_decode(file_get_contents($filename));
		if(isset($thing->{'database'})) {
			return $thing;
		}
	}

	private function find_and_parse_series($place) {
		global $__json, $__appauthcfg;
		$default_dir = "/var/lib/jazzhands/appauth-info";
		if(isset($__json) && isset($__json->{'search_dirs'})) {
			foreach ($__json->{'search_dirs'} as $dir) {
				if($dir == '.') {
					$dir = dirname($__appauthcfg);
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
		global $__appauthauthcfg;
		if(isset($instance)) {
			$x = dbauth::find_and_parse_series("$instance/$app");
			if(isset($x)) {
				return($x);
			}
		}

		if(!isset($instance) || !isset($__json->{'sloppy_instance_match'}) ||
				$__json->{'sloppy_instance_match'} != 'no') {
			$x = dbauth::find_and_parse_series("$app");
			if(isset($x)) {
				return($x);
			}
		}

	}

	// discern the underlying database and make the right call. This is kind
	// of lame, but Vv.
	private function optional_set_session_user($dbh, $login, $options) {
		global $__json;

		$doit = 0;
		if(isset($options) && isset($options->{'use_session_variables'})) {
			if($options->{'use_session_variables'} != 'no') {
				$doit = 1;
			}
		}

		if(!$doit) {
			if(!isset($__json->{'use_session_variables'})) {
				return null;
			}
			if($__json->{'use_session_variables'} == 'no') {
				return null;
			}
		}

		if(!isset($dbh)) {
			return null;
		}

		if(!isset($login) || $login == null) {
			if(! function_exists('posix_getpwuid') ) {
				return null;
			} else {
				//  assume  if posix_getpwuid exists, posix_getuid does
				$dude = posix_getpwuid( posix_getuid() );
				$login = $dude['name'];
			}
		}

		return dbauth::set_session_user($dbh, $login);
	}

	public function set_session_user($dbh, $login) { 
		if(gettype($dbh) == 'resource') {
			switch( get_resource_type( $dbh ) ) {
				case 'pgsql link':
					$result = pg_query("set jazzhands.appuser = '$login'"); // or die( pg_last_error() );
					pg_free_result($result);
					break;
			}
		}

		return 1;
	}

	public function connect($app, $instance = null, $login = null, $flags = null) {
		$record = dbauth::find_and_parse_auth($app, $instance);

		if(!isset($record)) {
			return null;
		}

		$dbspecs = $record->{'database'};

		if(!isset($dbspecs)) {
			return null;
		}

		foreach ($dbspecs as $dbspec) {
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

					$dbh = pg_connect($connstr);
					if(isset($dbh) && $dbh != null) {
						dbauth::optional_set_session_user($dbh, $login, (isset($record->{'options'}))?$record->{'options'}:null);
					}
					return $dbh;
					break;
			case 'mysql':
					$dbh = new mysqli( $dbspec->{'DBHost'}, $dbspec->{'Username'}, $dbspec->{'Password'}, $dbspec->{'DBName'} );
					// no support for session variables, so not doing anything.
					// need to deal with options
					return $dbh;
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
}

?>
