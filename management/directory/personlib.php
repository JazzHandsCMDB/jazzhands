<?php 
include "jazzhands/dbauth.php";

//
// prints a bar across the top of locations to limit things by and
//
function locations_limit($dbconn = null) {
	$query = "
		select physical_address_id, display_label
		from	physical_address
		where	company_id in (
			select company_id from v_company_hier
			where root_company_id IN
				(select property_value_company_id
                                   from property
                                  where property_name = '_rootcompanyid'
                                    and property_type = 'Defaults'
                                )
				
			) order by display_label
	";
	$result = pg_query($dbconn, $query) or die('Query failed: ' . pg_last_error());


	$params = build_qs(null, 'offset', null);

	$rv = "";
	while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
		if(isset($_GET['physical_address_id']) && $_GET['physical_address_id'] == $row['physical_address_id']) {
			$class = 'activefilter';
		} else {
			$class = 'inactivefilter';
		}
		$url = build_url(build_qs($params, 'physical_address_id', $row['physical_address_id']));
		$lab = $row['display_label'];
		if(strlen($rv)) {
			$rv = "$rv | ";
		}
		$rv = "$rv <a class=\"$class\" href=\"$url\"> $lab </a> ";
	}
	if(isset($_GET['physical_address_id'])) {
		$url = build_url(build_qs($params, 'physical_address_id', null));
		$lab = '| Clear';
		$rv = "$rv <a class=\"inactivefilter\" href=\"$url\"> $lab </a> ";
	}
	return "<div class=filterbar>[ $rv ]</div>";
}


//
// print various ways to browse at the top
//
function browse_limit($current) {
	$arr = array(
		'byname' => "By Name",
		'bydept' => "By Dept",
		'hier' => "By Org",
		'random' => "Random"
	);

	$params = build_qs(null, 'offset', null);
	$rv = "";
	foreach ($arr as $k => $v) {
		$url = build_url(build_qs($params, 'index', $k), "./");
		$lab = $arr[$k];
		if(strlen($rv)) {
			$rv = "$rv | ";
		}
		if($current == $k) {
			$class = 'activefilter';
		} else {
			$class = 'inactivefilter';
		}
		$rv = "$rv <a class=\"$class\" href=\"$url\"> $lab </a> ";
			
	}
	return "<div class=filterbar>[ Browse: $rv ]</div>";
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
	} elseif($index == 'department') {
		$link = "./?index=$index&department_id=".$id;
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
	if($params == null) {
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
