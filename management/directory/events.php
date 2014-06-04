<?php 
include "personlib.php" ;

$dbconn = dbauth::connect('directory', null, $_SERVER['REMOTE_USER']) or die("Could not connect: " . pg_last_error() );

echo build_header("Events");
// echo browsingMenu($dbconn, null);

$query ="
	select * from 
	( 
		select	p.person_id,
			coalesce(p.preferred_first_name, p.first_name) as first_name,
			coalesce(p.preferred_last_name, p.last_name) as last_name,
			date_part('epoch', pc.hire_date) as whence,
			pc.hire_date as whence_human,
			'Hire Date' as event
	 	from	person p
		inner join (
			select * from person_company
			where hire_date is null or hire_date <= now()
		) pc using(person_id)
		WHERE	pc.hire_date is not null
	UNION
		select p.person_Id,
			coalesce(p.preferred_first_name, p.first_name) as first_name,
			coalesce(p.preferred_last_name, p.last_name) as last_name,
			date_part('epoch', p.birth_date) as whence,
			p.birth_date as whence_human,
			'Birthday' as event
	 	from	person p
		WHERE	p.birth_date is not null
	) events
	       inner join (
			select * from person_company
			where hire_date is null or hire_date <= now()
		) pc
			using (person_id)
	       inner join v_person_company_expanded vpc
			using (person_id)
		       inner join val_person_status vps
				on ( vps.person_status = 
						pc.person_company_status
				 and    vps.is_disabled = 'N'
				)
	WHERE   vpc.company_id in (
			select  property_value_company_id
			  from  property
		 where  property_name = '_rootcompanyid'
			   and  property_type = 'Defaults'
		)
	AND	pc.person_company_relation = 'employee'
	ORDER BY date_part('month', whence_human),
		date_part('day', whence_human),
		last_name,
		first_name,
		event
";

$result = pg_query($query)
	or die('Query failed: ' . pg_last_error());

$last_month = "";
while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
	// XXX - preferred!
	$name = $row['first_name']. " ". $row['last_name'];
	$name = personlink($row['person_id'], $name);
	$mon = date("F", $row['whence']);

	$event = $row['event'];
	if($mon != $last_month) {
		$last_month = $mon;
		echo "<table class=events>\n";
		echo "<tr class=month> <td colspan=3> $mon </td> </tr>\n";
	}
	if($event != 'Birthday') {
		$printable = date("F j, Y", $row['whence']);
	} else {
		$printable = date("F j", $row['whence']);
	}
	echo "<tr> <td> $name </td> <td> $printable </td> <td> $event </td></td>\n";
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
