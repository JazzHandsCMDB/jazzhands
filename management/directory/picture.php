<?php 
include "dbauth.php";

$dbconn = dbauth::connect('directory') or die("Could not connect: " . pg_last_error() );

pg_query($dbconn, "begin");

#    $pic = "picture.php?person_id=".$line[person_id]."&person_image_id=".$line[person_image_id];

$show_anything = 1;

$person_id = (isset($_GET['person_id']))? $_GET['person_id']:null;
$person_image_id = (isset($_GET['person_image_id']))? $_GET['person_image_id']:null;

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
		# XXX - cache images
		if($fd = pg_lo_open($dbconn, $row['image_blob'], 'r')) {
			header("Content-type: image/".$row['image_type']);
			$str = pg_lo_read($fd, 8192);
			do {
				echo $str;
				$showpic = 1;
			} while( $str = pg_lo_read($fd, 8192) );
			pg_lo_close($fd);
		} else {
			die("fail: ". $row['image_blob']);
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
