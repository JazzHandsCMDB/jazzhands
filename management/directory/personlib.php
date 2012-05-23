<?php 
include "dbauth.php";

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

	return("<a href=\"$raw\"><img alt=\"person\" src=\"$src\" class=\"$class\" /></a>");
}

function personlink($personid, $text) {
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
		$heading = "Phone Directory";
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

?>
