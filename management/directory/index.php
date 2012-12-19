<?php 
include "personlib.php" ;

$dbconn = dbauth::connect('directory', null, $_SERVER['REMOTE_USER']) or die("Could not connect: " . pg_last_error() );

$index = isset($_GET['index']) ? $_GET['index'] : 'default';

$query_firstpart = "
	select  distinct p.person_id,
		coalesce(p.preferred_first_name, p.first_name) as first_name,
		coalesce(p.preferred_last_name, p.last_name) as last_name,
		pc.position_title,
		c.company_name,
		c.company_id,
		pi.person_image_id,
		pc.manager_person_id,
		coalesce(mgrp.preferred_first_name, mgrp.first_name) as mgr_first_name,
		coalesce(mgrp.preferred_last_name, mgrp.last_name) as mgr_last_name,
		u.account_collection_id,
		u.account_collection_name,
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
		inner join account_collection_account uc
			on uc.account_id = a.account_id
		inner join account_collection u
			on u.account_collection_id = uc.account_collection_id
			and u.account_collection_type = 'department'
		left join (
			select	pi.*, piu.person_image_usage
			 from	person_image pi
					inner join person_image_usage piu
						on pi.person_image_id = piu.person_image_id
						and piu.person_image_usage = 'corpdirectory'
		) pi
			on pi.person_id = p.person_id
		left join person mgrp
			on pc.manager_person_id = mgrp.person_id
		left join ( -- this probably needs to be smarter
			select manager_person_id as person_id, count(*)  as tally
			  from person_company
			  where person_company_status = 'enabled'
			  group by manager_person_id
		) numreports on numreports.person_id = p.person_id 
";

$orderby = "order by
		coalesce(p.preferred_last_name, p.last_name),
		coalesce(p.preferred_first_name, p.first_name),
		p.person_id
";

$style = 'peoplelist';
switch($index) {
	case 'reports':
		$who = $_GET['person_id'];
		$query = "
		  $query_firstpart
		  where pc.manager_person_id = $1
		    and pc.person_company_status = 'enabled'
		  $orderby
		";
		$result = pg_query_params($query, array($who)) 
			or die('Query failed: ' . pg_last_error());
		break;

	case 'department':
		$dept = $_GET['department_id'];
		$query = "
		  $query_firstpart
		  where uc.account_collection_id = $1
		    and pc.person_company_status = 'enabled'
		  $orderby
		";
		$result = pg_query_params($query, array($dept)) 
			or die('Query failed: ' . pg_last_error());
		break;

  	case 'hier':
		$query = "
			$query_firstpart
		where pc.manager_person_id is NULL
	    	and pc.person_company_status = 'enabled'
		  $orderby
		";
		$result = pg_query($query) or die('Query failed: ' . pg_last_error());
		break;

	default:
		$style = 'departmentlist';
		$query = "
			select	distinct
					account_collection_name,
					account_collection_id
			 from	account_collection
			 		inner join account_collection_account
							using(account_collection_id)
					inner join account
							using(account_id)
					inner join val_person_status vps
							on vps.person_status = account_status
			where	account_collection_type = 'department'
			 and	vps.is_disabled = 'N'
				
			order by account_collection_name
		";
		$result = pg_query($query) or die('Query failed: ' . pg_last_error());
		break;
}

echo build_header("Directory");

if($style == 'peoplelist') {
	// Printing results in HTML
	echo "<table id=\"peoplelist\">\n";
	?>

	<tr>
	<td> </td>
	<td> Employee Name </td> 
	<td> Title </td> 
	<td> Company </td> 
	<td> Manager </td> 
	<td> Department </td> 
	</tr>

	<?php
	while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
		$name = $row['first_name']. " ". $row['last_name'];
		echo "\t<tr>\n";
		if(isset($row['person_image_id'])) {
			$pic = img($row['person_id'], $row['person_image_id'], 'thumb');
			echo "<td> $pic </td>";

		} else {
			echo "<td> </td>";
		}
		echo "<td>". personlink($row['person_id'], $name);

	   	if(isset($row['num_reports']) && $row['num_reports'] > 0) {
			echo "<br>(" .hierlink('reports', $row['person_id'], "reports").")";
		}
		echo "</td>";

		echo "<td> ". $row['position_title'] . "</td>\n";
		echo "<td> ". $row['company_name'] . "</td>\n";

		# Show Manager Links
		if(isset($row['manager_person_id'])) {
			$mgrname = $row['mgr_first_name']. " ". $row['mgr_last_name'];
			echo "<td>". personlink($row['manager_person_id'], $mgrname);

			echo "<br>(" .hierlink('reports', $row['manager_person_id'], "reports").")";
			echo "</td>\n";

		} else {
			echo "<td></td>";
		}

		echo "<td>" . hierlink('department', $row['account_collection_id'],
			$row['account_collection_name']). "</td>\n";
	    echo "\t</tr>\n";
	}
	echo "</table>\n";
} else {
	echo "<h3> Browse by Department </h3>\n";
	echo "<div class=deptlist><ul>\n";
	while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
		echo "<li>" . hierlink('department', $row['account_collection_id'],
			$row['account_collection_name']). "</li>\n";
		
	}
	echo "</ul>\n";
	echo "</div>\n";
}

echo build_footer();

// Free resultset
pg_free_result($result);

// Closing connection
pg_close($dbconn);

?>
</div>
</body>
</html>
