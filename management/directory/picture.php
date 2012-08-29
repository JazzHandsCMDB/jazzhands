<?php 
include "jazzhands/dbauth.php";

/* Sort out the cache dir. */ 

$_CACHEDIR = ini_get("jazzhands_directory_picture_cache");
if(! strlen($_CACHEDIR)) {
	$_CACHEDIR="/var/tmp/jazzhands_directory_picture_cache";
}

if(!is_dir($_CACHEDIR)) {
	mkdir($_CACHEDIR);
}


/**************************** SUBROUTINES ************************************/

/*
 * copies the specific oid to the given file descriptor
 */
function copy_db_image($dbconn, $row, $wfd, $header = null) {
	$oid = $row['image_blob'];
	$type = $row['image_type'];

	if(isset($header)) {
		header("Content-type: image/".$row['image_type']);
	}
	$fd = pg_lo_open($dbconn, $oid, 'r');
	if($fd) {
		$str = pg_lo_read($fd, 8192);
		do {
			fwrite($wfd, $str, strlen($str));
		} while( $str = pg_lo_read($fd, 8192) );
		pg_lo_close($fd);
	} else {
		error_log("Unable to open oid $oid in db: ". pg_last_error() );
	}
}

/*
 * attempts to spit out an image given the hint.  It will attempt to cache
 * the image in a cache directory if it is writable so the db does not need
 * to be hit for every image.  It will also print the header.
 *
 * It *always* caches the full size image for future manipulations, and may
 * also cache the thumbnail or wahtever.
 *
 * [XXX] - even if there is no cache directory, this shold be changed to
 * spit out the reduced snapshot. 
 *
 * returns 0 if it failed to printed an image
 * returns non-zero if it printed an image
 */
function send_cached_image($dbconn, $row, $in_hint) {
	global $_CACHEDIR;

	$hint = $in_hint;
	if($hint == null) {
		$hint = "fullsize";
	}

	if(!is_writeable($_CACHEDIR)) {
		return(0);
	}

	# cache the full size version in any case because that gets converted.
	$fullfn = "$_CACHEDIR/cache_".$row['person_id']."_".$row['person_image_id']."_fullsize.".$row['image_type'];
	if(!is_readable($fullfn)) {
		if( $wfd = fopen($fullfn, "w") ) {
			copy_db_image($dbconn, $row, $wfd);
			fclose($wfd);
		}
		if(is_readable( $fullfn )) {
			if(! filesize($fullfn)) {
				unlink($fullfn);
				return(0);
			}
		} else {
			return(0);
		}
	}

	if($hint == 'fullsize') {
		header('Content-Type: image/'.$row['image_type']);
		header('Content-length: ' .filesize($fullfn));
		ob_clean();
		flush();
		readfile($fullfn);
		return(1);	
	}

	# Check to see if the destination file is there, and if not, geneate it.
	$fn = "$_CACHEDIR/cache_".$row['person_id']."_".$row['person_image_id']."_$hint.".$row['image_type'];
	if(is_readable($fn)) {
		header('Content-Type: image/'.$row['image_type']);
		header('Content-length: ' .filesize($fn));

		ob_clean();
		flush();
		readfile($fn);
		return(1);	
	}

	/*
	 * NOTE:  THese must be on the path.  We should probably try a little
 	 * harder to find the right one.
	 */
	if($row['image_type'] == 'jpeg') {
		$uqsrcprog = "djpeg";
		$uqdstprog = "cjpeg";
	} elseif($row['image_type'] == 'png') {
		$uqsrcprog = "pngtopnm";
		$uqdstprog = "pnmtopng";
	} elseif($row['image_type'] == 'tiff') {
		$uqsrcprog = "tifftopnm";
		$uqdstprog = "tifftopnm";
	}

	/*
	 * Now try to find it based on some sensible pathisms
	 */
	$path = split(":", getenv('PATH'));
	array_push($path, "/usr/pkg/bin");
	array_push($path, "/usr/local/bin");
	array_push($path, "/usr/sfw/bin");

	$srcprog = $uqsrcprog;
	$dstprog = $uqdstprog;
	$uqcvt = "pamscale";
	$cvt = $uqcvt;

	foreach (array_reverse($path) as $p) {
		if(is_executable("$p/$uqsrcprog")) {
			$srcprog = "$p/$uqsrcprog";
		}
		if(is_executable("$p/$uqdstprog")) {
			$dstprog = "$p/$uqdstprog";
		}
		if(is_executable("$p/$uqcvt")) {
			$cvt = "$p/$uqcvt";
		}
	}


	if($hint == 'thumb') {
		$width= "50";
	} elseif ($hint == 'contact') {
		$width= "200";
	} elseif ($hint == 'yearbook') {
		$width= "300";
	}

	$cmd =  "cat $fullfn | $srcprog | $cvt -xsize=$width | $dstprog | tee $fn";
	$str = `$cmd`;
	if(strlen($str)) {
		header('Content-Type: image/'.$row['image_type']);
		header('Content-length: ' .filesize($fn));
		echo $str;
		return(1);
	}
	if(is_readable($fn)) {
		if(! filesize($fn)) {
			unlink($fn);
			return(0);
		}
	}
	return(0);
}

/**************************** WORK STARTS HERE ********************************/

$dbconn = dbauth::connect('directory', null, $_SERVER['REMOTE_USER']) or die("Could not connect: " . pg_last_error() );
pg_query($dbconn, "begin");

$show_anything = 1;

$person_id = (isset($_GET['person_id']))? $_GET['person_id']:null;
$person_image_id = (isset($_GET['person_image_id']))? $_GET['person_image_id']:null;
$hint = (isset($_GET['type'])? $_GET['type']:null);

# Attempt to sanitize input a bit.  At the very least, make attempts
# to turn something into a filename bit work.
if(isset($person_image_id)) {
	$person_image_id = basename($person_image_id);
}
if(isset($hint)) {
	$hint = basename($hint);
}

$showpic = 0;
if($person_id && $person_image_id) {
	$query = "
		select person_id, person_image_id, image_blob, image_type,
			coalesce(data_upd_date, data_ins_date) as last_updated
		  from	person_image
		 where	person_id =  $1
		  and	person_image_id =  $2
			or ($1 = $2)
	";

	$result = pg_query_params($query, array($person_id, $person_image_id))
		or die("Bad Query");

	if( $row = pg_fetch_array($result, null, PGSQL_ASSOC) ) {
		if(! send_cached_image( $dbconn, $row, $hint ) ) {
			$stdout= fopen("php://stdout", "w");
			if(!copy_db_image($dbconn, $row, $stdout, 1)) {
				die("failed to display image #". $row['image_blob']);
			}
			fclose($stdout);
		} else {
			$showpic = 1;
		}
	}
	pg_query($dbconn, "rollback");
	pg_close($dbconn);
}

if(!$showpic && $show_anything = 1) {
	header("Content-type: image/png");
	echo file_get_contents("images/600px-Smiley.svg.png");
}

?>
