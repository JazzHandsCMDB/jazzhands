<?php
include "personlib.php" ;

// XXX - need to move to a library
function check_admin($dbconn, $login) {
	$aq = <<<EOQ
		select	count(*) as tally
		 from	property p
			inner join account_collection ac
				on ac.account_collection_id =
					p.property_value_account_coll_id
			inner join v_acct_coll_account_expanded ae
				on ae.account_collection_id =
					ac.account_collection_id
			inner join account a
				on ae.account_id = a.account_id
		 where	p.property_name = 'PhoneDirectoryAdmin'
		  and	p.property_type = 'PhoneDirectoryAttributes'
		  and	a.login = $1
EOQ;
	$args = array($login);
	$r = pg_query_params($dbconn, $aq, $args) 
		or die("Admin Check Query failed: ".pg_last_error());

	$row = pg_fetch_array($r, null, PGSQL_ASSOC);
	if($row['tally'] > 0) {
		$rv = 1;
	} else {
		$rv = 0;
	}
	pg_free_result($r);
	return $rv;
}

function pretty_phone_row($row) {
	$str =	'+'.
		$row['dial_country_code']." ".
		$row['phone_number'];

	// this should be visible to some people but not others, but that's
	// for v1.5
	if($row['person_contact_privacy'] == 'HIDDEN') {
		return $str;
	}

	if($row['person_contact_privacy'] != 'PUBLIC') {
		$str .= " (" .$row['person_contact_privacy'] .")";
	}
	return $str;
}

/* This is no longer used and can be deleted */
function get_phone($db, $pid, $tech, $locale) {
	$args = array($pid);

	$argc = 1;
	if(isset($tech)) {
		if(isset($whereclause)) {
			$whereclause .=" and ";
		} else { $whereclause = ""; }
		$whereclause .= 'person_contact_technology = $' . ++$argc;
		array_push($args, $tech);
	}
	if(isset($locale)) {
		if(isset($whereclause)) {
			$whereclause .=" and ";
		} else { $whereclause = ""; }
		$whereclause .= 'person_contact_location_type = $' . ++$argc;
		array_push($args, $locale);
	}

	if(isset($whereclause)) {
		$whereclause = "and ( $whereclause ) ";
	}

	$q = "
		select	pc.person_contact_id,
			vcc.dial_country_code,
			pc.phone_number,
			pc.phone_extension,
			person_contact_privacy
		  from	person_contact pc
		  	inner join val_country_code vcc
				using(iso_country_code)
		where	person_id = $1
		  and	person_contact_type = 'phone'
		  	$whereclause 
		order by person_contact_order
	";
	$r = pg_query_params($db, $q, $args) 
		or die('Query failed: ' . pg_last_error());

	$row = pg_fetch_array($r, null, PGSQL_ASSOC);
	pg_free_result($r);
	return $row;
}

function build_tr($lhs, $rhs, $remove = null, $id = null, $isadmin = null) {
	// if remove is set then that indicates that the lhs should have a
	// remove button inside a form that javascript will take care of
	// allowing someone to remove.
	$removes = "";
	$removee = "";
	if(isset($remove) && isset($id) && $isadmin == 1) {
		$removes = <<<EOREMOVES
			<form class="phonerowform">
				<input type=hidden name="person_contact_id" value="$id">
				<a href="#" class="remove_phone" >
				<img alt="X" class="removex" src="images/Octagon_delete.svg" />
				</a>
EOREMOVES;
		$removee = "</form>";
	}
        return "<tr><td>$removes$lhs:$removee</td> <td>$rhs</td></tr>";
}

$dbconn = dbauth::connect('directory', null, $_SERVER['REMOTE_USER']) or die("Could not connect: " . pg_last_error() );


pg_query($dbconn, "begin");

$personid = (isset($_GET['person_id']))? $_GET['person_id']:null;

$query = "
	select  p.person_id,
		coalesce(p.preferred_first_name, p.first_name) as first_name,
		coalesce(p.preferred_last_name, p.last_name) as last_name,
		coalesce(pc.nickname, p.nickname) as nickname,
		pc.position_title,
		c.company_name,
		c.company_id,
		pi.person_image_id,
		pc.manager_person_id,
		coalesce(mgrp.preferred_first_name, mgrp.first_name) as mgr_first_name,
		coalesce(mgrp.preferred_last_name, mgrp.last_name) as mgr_last_name,
		u.account_collection_id,
		u.account_collection_name,
		a.login,
		numreports.tally as num_reports
	   from person p
	   	inner join person_company pc
			using (person_id)
	   	inner join company c
			using (company_id)
		inner join account a
			on p.person_id = a.person_id
			and pc.company_id = a.company_id
			and a.account_role = 'primary'
		left join account_collection_account uc
			on uc.account_id = a.account_id
		left join account_collection u
			on u.account_collection_id = uc.account_collection_id
			and u.account_collection_type = 'department'
		left join (     
        	select  pi.*, piu.person_image_usage
       		  from	person_image pi
        			inner join person_image_usage piu
        				on pi.person_image_id = piu.person_image_id
        				and piu.person_image_usage = 'corpdirectory'
        	) pi on p.person_id = pi.person_id
		left join person mgrp
			on pc.manager_person_id = mgrp.person_id
		left join ( -- this probably needs to be smarter
			   select manager_person_id as person_id, count(*)  as tally
			     from person_company
			     where person_company_status = 'enabled'
			     group by manager_person_id
		) numreports on p.person_id = numreports.person_id
	where p.person_id = $1
";

$result = pg_query_params($dbconn, $query, array($personid)) 
	or die('Query failed: ' . pg_last_error());

$row = pg_fetch_array($result, null, PGSQL_ASSOC) or die("no person");

if($row['login'] == $_SERVER['REMOTE_USER'] || check_admin($dbconn, $_SERVER['REMOTE_USER']) ) {
	$isadmin = 1;
} else {
	$isadmin = 0;
}

$name = $row['first_name']. " " . $row['last_name'];

$title = $row['position_title'] ;
$deptc = " (" . $row['company_name']. ")" ;
if(isset($row['mgr_last_name'])) {
	$manager = $row['mgr_first_name']. " " . $row['mgr_last_name'];
}

echo build_header($name);

echo "<div class=directorypic>" . img($row['person_id'], $row['person_image_id'], 'fullsize').
	"</div>";

echo "<div class=\"description\">";

echo "<h1> $name </h1>";
if(isset($row['nickname']) && strtolower($row['nickname']) != strtolower($row['first_name'])) {
	echo "AKA ", $row['nickname'], " </br>\n";
}
echo "<table id=\"contact\">\n";
if(isset($row['num_reports']) && $row['num_reports'] > 0) {
	$title = "$title (". hierlink('reports', $row['person_id'], "reports") .")";
}
echo build_tr("Title", $title);
/* Was $deptc at the end, which includes the company */
echo build_tr("Dept", hierlink('department', $row['account_collection_id'],
                $row['account_collection_name']));

if(isset($manager)) {
	echo build_tr("Manager", 
		personlink($row['manager_person_id'], $manager));
}
echo "<p>\n";

$q = "
	select	pc.person_contact_id,
		vcc.dial_country_code,
		pc.phone_number,
		pc.phone_extension,
		pc.person_contact_type,
		coalesce(vpct.description, pc.person_contact_technology)
			as person_contact_technology,
		coalesce(vpclt.description, pc.person_contact_location_type)
			as person_contact_location_type,
		pc.person_contact_privacy
	  from	person_contact pc
	  	inner join val_country_code vcc
			using(iso_country_code)
		inner join val_person_contact_loc_type vpclt
			using (person_contact_location_type)
		inner join val_person_contact_technology vpct
			using (person_contact_technology)
	where	person_id = $1
	  and	pc.person_contact_type = 'phone'
	order by person_contact_order
";
$args = array($personid);
$r = pg_query_params($dbconn, $q, $args) 
	or die('Query failed: ' . pg_last_error());

while($pc = pg_fetch_array($r, null, PGSQL_ASSOC)) {
	echo build_tr(
		$pc['person_contact_technology']."(".
		$pc['person_contact_location_type'].")",
		pretty_phone_row($pc),
		'remove',
		$pc['person_contact_id'], $isadmin);
}
		// should probably use jquery for picmanipbutton...

if($isadmin) {
?>

<tr id=add_phones> 
	<td colspan=2>
		<a class="addphonebutton" href="#">ADD </a>
		<a class="picmanipbutton" href="#" onClick="pic_manip(<?php echo $personid ?>);">PICS </a>
	</td>
</tr>
<?php
}

echo "</ul>\n";

echo build_footer();

// Free resultset
pg_free_result($result);

// Closing connection
pg_query($dbconn, "rollback");
pg_close($dbconn);

?>
</body>
</html>
