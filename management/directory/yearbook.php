<?php 
include "personlib.php" ;

$dbconn = dbauth::connect('directory') or die("Could not connect: " . pg_last_error() );

$personid = isset($_GET['person_id']) ? $_GET['person_id'] : null;

$wherextra = "";
$args = null;
if(isset($personid)) {
	$wherextra = "and p.person_id = $1";
	$args = array($personid);
}

$query = "
	select  p.person_id,
		coalesce(p.preferred_first_name, p.first_name) as first_name,
		coalesce(p.preferred_last_name, p.last_name) as last_name,
		coalesce(pc.nickname, p.nickname) as nickname,
		pc.position_title,
		pi.person_image_id,
		pi.description
	   from person p
	   	inner join person_company pc
			using (person_id)
	   	inner join company c
			using (company_id)
		inner join account a
			on p.person_id = a.person_id
			and pc.company_id = a.company_id
			and a.account_role = 'primary'
		inner join account_collection_account uc
			on uc.account_id = a.account_id
		inner join account_collection u
			on u.account_collection_id = uc.account_collection_id
			and u.account_collection_type = 'department'
		inner join person_image pi
			on pi.person_id = p.person_id
		inner join person_image_usage piu
			on pi.person_image_id = piu.person_image_id
				and piu.person_image_usage = 'yearbook'
		where	pc.person_company_status = 'enabled'
		 and	pi.description is not null
			$wherextra
		order by pc.employee_id
";

if(strlen($wherextra) >  0) {
	$result = pg_query_params($query, $args) 
		or die("Query $query == $personid failed: " . pg_last_error());
} else {
	$result = pg_query($query) 
		or die("Query $query failed: " . pg_last_error());
}

echo build_header("Yearbook", null, "Yearbook");
if(! isset($personid)) {
	?>
	<table id=yearbook>
		<tr>
			<td> Name </td> 
			<td> Photo </td> 
			<td> Most Likely To... </td> 
		</tr>
	<?php
}

while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
	$pic = null;
	if(isset($row['person_image_id'])) {
		$pic = img($row['person_id'], $row['person_image_id'], 'yearbook');
	}
	if(isset($row['nickname'])) {
		$name = $row['nickname'];
	} else {
		$name = $row['first_name']." ".$row['last_name'];
	}
	if(isset($personid)) {
		echo "$name<br>$pic<br>";
		echo "Most Likely to ".$row['description'];
		echo "<p>";
	} else {
		$lname = yearbooklink($row['person_id'], $name);
		echo "<tr>";
		echo " <td> $lname </td>";
		if(isset($pic)) {
			echo "<td> $pic </td>";
		} else {
			echo "<td> </td>";
		}
		echo " <td>".$row['description']."</td>";
		echo "</tr>\n";
	}
}
	
if(! isset($personid)) {
	echo "</table>\n";
};

echo build_footer();

// Free resultset
pg_free_result($result);

// Closing connection
pg_close($dbconn);

?>
</div>
</body>
</html>
