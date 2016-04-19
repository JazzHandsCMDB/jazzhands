<?php 
include "jazzhands/dbauth.php";

date_default_timezone_set('UTC');

//
// print various ways to browse at the top
//
function browsingMenu($dbconn, $current, $content = 'default') {
	$params = build_qs(array(), 'offset', null);
	$rv = "";

	if($content == 'both' || $content == 'default' || $content == 'locations') {
		if($content == 'locations') {
			$arr = array(
				'byname' => "Global",
			);
		 } else {
			$arr = array(
				'byname' => "By Name",
				'bydept' => "By Team",
				'byoffice' => "By Office",
				'hier' => "By Org",
				'random' => "Random"
			);
		};

		foreach ($arr as $k => $v) {
			if($content == 'default') {
				$url = build_url(build_qs($params, 'index', $k), "./");
			} else {
				$url = build_url(build_qs($params, 'index', $k));
			}
			$lab = $arr[$k];
			if(strlen($rv)) {
				$rv = "$rv ";
			}
			if($current == $k) {
				$class = 'activefilter';
			} else {
				$class = 'inactivefilter';
			}
			$rv = "$rv | <a class=\"$class filteroption\" href=\"$url\"> $lab </a> ";
		}
		$rv .= " |";
	} 

	$sitelimit = "";
	if($content == 'both' || $content == 'locations') {
		$query = "
			WITH occupied_offices AS (
			    SELECT DISTINCT
			        physical_address_id
			    FROM
			        person_location
			    INNER JOIN
			        v_corp_family_account
			    USING
			        (person_id)
			    WHERE
			        is_enabled = 'Y'
			)
			SELECT
			    physical_address_id,
			    display_label
			FROM
			    physical_address
			INNER JOIN
			    occupied_offices
			USING
			    (physical_address_id)
			WHERE
			    physical_address_type = 'location'
			ORDER BY 
			    display_label
		";
		$result = pg_query($dbconn, $query) or die('Query failed: ' . pg_last_error());
	
		$params = build_qs(null, 'offset', null);

		# used to have the site limiter in the menubar
		$label = "";
	
		while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
			if(isset($_GET['physical_address_id']) && $_GET['physical_address_id'] == $row['physical_address_id']) {
				$class = 'activefilter';
				$label = $row['display_label'];
			} else {
				$class = 'inactivefilter';
			}
			$url = build_url(build_qs($params, 'physical_address_id', $row['physical_address_id']));
			$lab = $row['display_label'];
			$sitelimit = "$sitelimit | <a class=\"$class limitsiterow\" href=\"$url\"> $lab </a>";
		}
		$sitelimit .= "|";
		if(isset($_GET['physical_address_id'])) {
			$url = build_url(build_qs($params, 'physical_address_id', null));
			$lab = '| Clear';
			$return = "$return <a class=\"inactivefilter limitsiterow\" href=\"$url\"> $lab </a> ";
		}
		$rv = "$rv <a class=\"$class filteroption locationfilter\"> </a>";
	}
	return "<div class=filterbar>$rv</div> <div class=\"sitelimit \">$sitelimit</div>";
}

function get_default_domain($dbconn = null) {
	$query = "
		select	property_value
		  from	property
		 where	property_name = '_defaultdomain'
		   and	property_type = 'Defaults'
	";
	$result = pg_query($dbconn, $query) or die ("Query Failed: " . pg_last_error());

	if($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
		return( $row['property_value'] );
	}
	return "";
}


//
// general routines for dislpaying people.
//

function img($personid, $personimageid, $thumb) {

	if(isset($thumb)) {
		$class = $thumb;
		$thumb="&type=$thumb";
	} else {
		$class = $thumb;
		$thumb = "";
	}

	$raw = "picture.php?person_id=$personid&person_image_id=$personimageid";
	$src = "$raw$thumb";

	return("<a href=\"contact.php?person_id=$personid\"><img alt=\"person\" src=\"$src\" class=\"$class\" /></a>");
}

function personlinkurl($personid, $extra = null) {
	if(isset($extra)) {
		$extra = "&$extra";
	} else {
		$extra = "";
	}
	return "contact.php?person_id=$personid$extra";
}

function personlink($personid, $text) {
	# note the img() function also returns a contact link.
	return "<a href=\"". personlinkurl($personid) ."\">$text</a>";
}

function yearbooklink($personid, $text) {
	return "<a href=\"yearbook.php?person_id=$personid\">$text</a>";
}

function hierlink($index, $id, $text) {
	if($index == 'reports') {
		$link = "./?index=$index&person_id=".$id;
	} elseif($index == 'team') {
		$link = "./?index=$index&team_id=".$id;
	} else {
		$link = $_SERVER['PHP_SELF'];
	}

	return("<a href=\"$link\">$text</a>");
}

function build_header($title, $style = null, $heading = null) {
	if(!isset($heading)) {
		$heading = "Directory";
	}
	if($style == null) {
		$style = "style.css";
	}
	return (<<<ENDHDR
	<!DOCTYPE HTML>
	<html>
	<head>
		<meta http-equiv="X-UA-Compatible" content="IE=edge" >
        	<title> $title </title>
		<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        	<style type="text/css">
                	@import url("$style");
                	@import url("local-style.css");
        	</style>
		<script src="../javascript-common/external/jQuery/jquery-1.9.0.js" type="text/javascript"></script>
		<script src="drops.js" type="text/javascript"></script>
		<link rel="shortcut icon" href="favicon.ico" type="image/x-icon">
	</head>
	<body>
	<div class="popup" id="picsdisplay"> <div> </div> </div>
	<div class="popup" id="locationmanip"> <div> </div> </div>
	<div id="page">
		<div id="head">
                	<a id="mast" href="./"
 			title="Link to Homepage">$heading</a>
		</div>

		<div id="main">
		<div class="searchbox">
			<form name="search">
				Search: <input type="text" id="searchfor"  action="#"
					name="searchfor">
			</form>
			<div id="resultsparents">
				<div id="resultsbox"> 
					<div> </div>
				</div>
		</div>
		</div>
ENDHDR
	);

}

function build_footer() {
	return( "</div></div></div>");
}

function build_qs($params = null, $key, $value = null) {
	if($params == null && !is_array($params)) {
		$params = $_GET;
	}
	$params[$key] = $value;
	return $params;
}

function build_url($params, $root = null) {
	if($root == null) {
		$root = $_SERVER['PHP_SELF'];
	}
	return "$root?".http_build_query($params);
}

?>
