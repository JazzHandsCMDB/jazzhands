<?php 
include "personlib.php" ;

$dbconn = dbauth::connect('directory', null, $_SERVER['REMOTE_USER']) or die("Could not connect: " . pg_last_error() );

echo build_header("Events");
echo browsingMenu($dbconn, null, 'locations');

$address = (isset ($_GET['physical_address_id']) )?$_GET['physical_address_id']:null;

$addrsubq = "";
if($address) {
	$addrsubq = "AND officemap.physical_address_id = $1";
}

$query ="
	WITH perlimit AS (	
		SELECT	person_id, account_collection_name as restrict
		FROM	v_corp_family_account
				INNER JOIN account_collection_account USING (account_id)
				INNER JOIN account_collection USING (account_collection_id)
		WHERE	account_collection_type = 'system'
		AND		account_collection_name IN 
				('noeventsbirthday', 'noeventsanniversary')
	), events AS ( 
		select	p.person_id,
			coalesce(p.preferred_first_name, p.first_name) as first_name,
			coalesce(p.preferred_last_name, p.last_name) as last_name,
			date_part('epoch', pc.hire_date) as whence,
			pc.hire_date as whence_human,
			'Hire Date' as event, 
            CASE WHEN pc.hire_date IS NOT NULL THEN
	    	round(extract('epoch' FROM (select
            		date_trunc('year',now()) - date_trunc('year',pc.hire_date) 
				))/86400/365) ELSE NULL END AS duration
	 	from	person p
		inner join (
			select * from person_company
			where hire_date is null or hire_date <= now()
		) pc using(person_id)
		WHERE	pc.hire_date is not null
		AND person_id NOT IN (
			SELECT person_id 
			FROM perlimit
			WHERE restrict = 'noeventsanniversary'
		) UNION
		select p.person_Id,
			coalesce(p.preferred_first_name, p.first_name) as first_name,
			coalesce(p.preferred_last_name, p.last_name) as last_name,
			date_part('epoch', p.birth_date) as whence,
			p.birth_date as whence_human,
			'Birthday' as event,
			NULL as duration
	 	from	person p
		WHERE	p.birth_date is not null
		AND person_id NOT IN (
			SELECT person_id 
			FROM perlimit
			WHERE restrict = 'noeventsbirthday'
		)
	), officemap AS (
	    select  pa.physical_address_id,
				pl.person_id,
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
	) SELECT events.*, officemap.display_label as office_location
		FROM events
		INNER JOIN (
			SELECT * from person_company
			WHERE hire_date is null or hire_date <= now()
		) pc USING (person_id)
		INNER JOIN v_person_company_expanded vpc USING(person_id)
		INNER JOIN val_person_status vps
			ON ( vps.person_status = 
					pc.person_company_status
			 AND    vps.is_disabled = 'N'
			)
		LEFT JOIN officemap USING (person_id)
	WHERE   vpc.company_id in (
			select  property_value_company_id
			  from  property
		 where  property_name = '_rootcompanyid'
			   and  property_type = 'Defaults'
		) 
	AND	pc.person_company_relation = 'employee'
    $addrsubq
	ORDER BY date_part('month', whence_human),
		date_part('day', whence_human),
		last_name,
		first_name,
		event
";

if($address) {
	$params = array($address);
} else {
	$params = array();
}

$result = pg_query_params($dbconn, $query, $params)
	or die('Query failed: ' . pg_last_error());

echo "<table class=events>\n";
$last_month = "";
while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
	$name = $row['first_name']. " ". $row['last_name'];
	$name = personlink($row['person_id'], $name);
	$mon = date("F", $row['whence']);

	$event = $row['event'];
	if($mon != $last_month) {
		$last_month = $mon;
		echo "<tr class=month> <td colspan=5> $mon </td> </tr>\n";
	}
	if($event != 'Birthday') {
		$printable = date("F j, Y", $row['whence']);
		$duration = ($row['duration'])? ($row['duration']." year".
			(($row['duration'] > 1)?'s':'') ) :'';
	} else {
		$printable = date("F j", $row['whence']);
		$duration = '';
	}
	$office = ($row['office_location'])?$row['office_location']:'';
	echo "<tr>
		<td> $name </td> 
		<td> $printable </td> 
		<td> $event </td>
		<td> $duration </td>
		<td> $office </td>
		</tr>\n";
}
echo "</table>\n";

echo build_footer();

// Free resultset
pg_free_result($result);

// Closing connection
pg_close($dbconn);

?>
</div>
</body>
</html>
