<?php 
include "jazzhands/dbauth.php";

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

function personlink($personid, $text) {
	# note the img() function also returns a conteact link.
	return "<a href=\"contact.php?person_id=$personid\">$text</a>";
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
	<html>
	<head>
        	<title> $title </title>
        	<style type="text/css">
                	@import url("$style");
                	@import url("local-style.css");
        	</style>
		<script src="js/jquery-1.7.1.js" type="text/javascript"></script>
		<script src="drops.js" type="text/javascript"></script>
		<link rel="shortcut icon" href="favicon.ico" type="image/x-icon">
	</head>
	<body>
	<div class="popup" id="picsdisplay"> <div> </div> </div>
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

function build_url($params) {
	return $_SERVER['PHP_SELF']."?".http_build_query($params);
}

?>
