<?php
include "personlib.php" ;

/* code in here is shared with contact.php.  They should be merged. */

//
// this probably wants to move to the main query and fetched along with
// phone numbers
function get_email( $dbconn, $personid ) {
	$qq = <<<EOQ
		select	person_contact_account_name as email_address
		  from	person_contact
		 where	person_id = $1
		  and	person_contact_type = 'email'
		  and	person_contact_technology = 'email'
		  and	person_contact_location_type = 'office'
		  and	person_contact_privacy != 'HIDDEN'
		 order by person_contact_order
		 LIMIT 1
EOQ;
	$args = array($personid);
	$r = pg_query_params($dbconn, $qq, $args) 
		or die("Admin Check Query failed: ".pg_last_error());

	$row = pg_fetch_array($r, null, PGSQL_ASSOC);
	pg_free_result($r);
	if($row == null) {
		return null;
	}
	return $row{'email_address'};
}

$dbconn = dbauth::connect('directory', null, $_SERVER['REMOTE_USER']) or die("Could not connect: " . pg_last_error() );

pg_query($dbconn, "begin");

$personid = (isset($_GET['person_id']))? $_GET['person_id']:null;

// the order by is used to get the non-NULL ones pushed to the top , tho now
// there should be only one row
$query = "
	select  p.person_id,
		coalesce(p.preferred_first_name, p.first_name) as first_name,
		coalesce(p.preferred_last_name, p.last_name) as last_name,
		coalesce(pc.nickname, p.nickname) as nickname,
		pc.position_title,
		pc.person_company_relation,
		date_part('month', p.birth_date) as birth_date_month,
		date_part('day', p.birth_date) as birth_date_day,
		date_part('epoch', p.birth_date) as birth_date_epoch,
		pc.hire_date,
		c.company_name,
		c.company_id,
		pi.person_image_id,
		pc.manager_person_id,
		coalesce(mgrp.preferred_first_name, mgrp.first_name) as mgr_first_name,
		coalesce(mgrp.preferred_last_name, mgrp.last_name) as mgr_last_name,
		ac.account_collection_id,
		ac.account_collection_name,
		a.login,
		numreports.tally as num_reports,
		ofc.display_label,
		ofc.building,
		ofc.floor,
		ofc.section,
		ofc.seat_number
	   from person p
	   	inner join (
			select * from person_company
			where hire_date is null or hire_date <= now()
		) pc using (person_id)
		inner join company c using (company_id)
		inner join v_corp_family_account a
			on p.person_id = a.person_id
			and pc.company_id = a.company_id
			and a.account_role = 'primary'
		left join ( select ac.*, account_id
					FROM account_collection ac
						INNER JOIN account_collection_account
						USING (account_collection_id)
					WHERE account_collection_type = 'department'
		) ac USING (account_id)
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
		left join (
			select	pl.person_id, 
				pa.display_label,
				pl.building,
				pl.floor,
				pl.section,
				pl.seat_number
			from   person_location pl
				inner join physical_address pa
					USING (physical_address_id)
			where   pl.person_location_type = 'office'
			order by site_rank
		) ofc on ofc.person_id = p.person_id
	where p.person_id = $1
	order by ac.account_collection_name
";

$result = pg_query_params($dbconn, $query, array($personid)) 
	or die('Query failed: ' . pg_last_error());

$row = pg_fetch_array($result, null, PGSQL_ASSOC) or die("no person");

$name = $row['first_name']. " " . $row['last_name'];

header('Content-Type: text/vcard');
header("Content-disposition: inline; filename=\"vcard-$name.vcf\"");

$email = get_email( $dbconn, $row{'person_id'} );
if(isset($email) || isset($row['login'])) {
        if( $email == null) {
                $email = $row['login']."@". get_default_domain($dbconn);
        }
}

$fn = $row['first_name'];
$sn = $row['last_name'];

$title = $row['position_title'];

echo "BEGIN:VCARD\n";
echo "VERSION:3.0\n";
echo "N:$sn;$fn;\n";
echo "FN:$name\n";
echo "TITLE:$title\n";
// echo "PHOTO;VALUE=URL;TYPE=GIF:http://www.example.com/dir_photos/my_photo.gif\n";
$q = "
	select	pc.person_contact_id,
			vcc.dial_country_code,
			pc.phone_number,
			pc.phone_extension,
			pc.person_contact_type,
			pc.person_contact_technology,
			pc.person_contact_location_type,
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
	and	person_contact_privacy != 'HIDDEN'
	and person_contact_technology in ('phone', 'mobile', 'fax')
	order by person_contact_order
";

$args = array($personid);
$r = pg_query_params($dbconn, $q, $args) 
	or die('Query failed: ' . pg_last_error());

while($pc = pg_fetch_array($r, null, PGSQL_ASSOC)) {
	$pn =	'+'.
		$pc['dial_country_code']." ".
		$pc['phone_number'];

	$tech = $pc['person_contact_technology'];
	$type = $pc['person_contact_location_type'];

	if($type == 'home') {
		$type = 'HOME';
	} else {
		$type = 'WORK';
	}

	$tech = strtoupper($tech);
	if($tech == 'PHONE') {
		$tech = 'VOICE';
	} else if($tech == 'MOBILE') {
		$tech = 'CELL,MOBILE,VOICE';
	}

	echo "TEL;TYPE=$type,$tech:$pn\n";
}

if(isset($email) || $email != null) {
	echo "EMAIL;TYPE=PREF,INTERNET:$email\n";
}
#- echo "ORG:".$row['account_collection_name']."\n";
echo "ADR;TYPE=WORK:;;".$row['display_label']."\n";
$now = time();
echo "REV:".date("Y-m-d", $now)."T".date("h:i:s", $now)."Z\n";
echo "END:VCARD\n";

// Free resultset
// pg_free_result($result);

// Closing connection
pg_query($dbconn, "rollback");
pg_close($dbconn);
?>
