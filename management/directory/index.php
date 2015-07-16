<?php 
include "personlib.php" ;

$dbconn = dbauth::connect('directory', null, $_SERVER['REMOTE_USER']) or die("Could not connect: " . pg_last_error() );

$index = isset($_GET['index']) ? $_GET['index'] : 'random';

$select_fields = "
		distinct p.person_id,
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
		numreports.tally as num_reports,
		ofc.display_label as office_location,
		ofc.physical_address_id
";

$query_tables = "
	   FROM person p
	   	inner join (
			select * from person_company
			where hire_date is null or hire_date <= now()
		) pc
			using (person_id)
	   	inner join company c
			using (company_id)
		inner join v_corp_family_account a
			on p.person_id = a.person_id
			and pc.company_id = a.company_id
			and a.account_role = 'primary'
		inner join (
			select ac.*, account_id
			FROM account_collection ac
				INNER JOIN account_collection_account a
					USING (account_collection_id)
			WHERE account_collection_type = 'department'
		) u USING (account_id)
		inner join val_person_status vps
			on ( vps.person_status = pc.person_company_status
			 and	vps.is_disabled = 'N'
			)
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
		left join (
			select pl.person_id, pa.physical_address_id,
				pa.display_label
			 from	person_location pl
			 	inner join physical_address pa
					on pl.physical_address_id = 
						pa.physical_address_id
			where	pl.person_location_type = 'office'
			order by site_rank
			) ofc on ofc.person_id = p.person_id
";

$query_firstpart = "
	SELECT $select_fields
		$query_tables";

$orderby = "
	order by
		coalesce(p.preferred_last_name, p.last_name),
		coalesce(p.preferred_first_name, p.first_name),
		p.person_id
";

$limit = "";

$address = (isset ($_GET['physical_address_id']) )?$_GET['physical_address_id']:null;

$showarrow = 0;

$style = 'peoplelist';
switch($index) {
	case 'random':
		$query = "
			select p.person_id $query_tables order by random() limit 1
		";
		$result = pg_query($query)
			or die('Query failed: ' . pg_last_error());
		
		$row = pg_fetch_array($result, null, PGSQL_ASSOC);
		if($row && $row['person_id']) {
			Header('Location: '.personlinkurl($row['person_id'], 'random=yes'));
		}
		pg_free_result($result);
		pg_close($dbconn);
		exit(0);
		break;

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

	case 'team':
		$team = $_GET['team_id'];
		$query = "
		  $query_firstpart
		  where (
				a.account_id in (select account_id
				from v_acct_coll_acct_expanded
				where account_collection_id = $1 )
			)
		    and pc.person_company_status = 'enabled'
		  $orderby
		";
		$result = pg_query_params($query, array($team)) 
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

	case 'byname':
	case 'byoffice':
		$params = array();
		$numshow = 10;
		$offset = (isset($_GET['offset']))?$_GET['offset']:0;
		if( ($offset * 1) != $offset) {
			$offset = 0;
		}
		$dboffset = $offset * $numshow;
		$orderby = "ORDER BY
			coalesce(p.preferred_last_name, p.last_name),
			coalesce(p.preferred_first_name, p.first_name),
			p.person_id
		";
		$addrq = "";
		if(isset($address)) {
			// XXXX BIND VARIABLES
			$num = array_push($params, $address);
			$addrq = "and ofc.physical_address_id = $$num";
		}
		$query = "
			$query_firstpart
		    	where pc.person_company_status = 'enabled'
			$addrq
			$orderby
			LIMIT $numshow  OFFSET $dboffset
		";
		$result = pg_query_params($query, $params) or die("Query failed\n$query\n:" .pg_last_error());

		//
		// Need to figure out how many pages would need to be shown
		//
		$q = "SELECT count(*) as tally $query_tables 
		    	where pc.person_company_status = 'enabled'
			$addrq
		";
		$r = pg_query_params($dbconn, $q, $params) or die("Query failed: $q :".pg_last_error());
		$row = pg_fetch_array($r, null, PGSQL_ASSOC);
		if(isset($row['tally'])) {
			$numrows = $row['tally'];
		}

		$numpages = 0;
		$numpages = ceil($numrows / $numshow) - 1;

		$showarrow = 1;
		break;

	case 'bydept':
	case 'byteam':
		$style = 'teamlist';
		$query = "
			select	distinct
					account_collection_name,
					account_collection_id
			 from	account_collection
			 		inner join account_collection_account
							using(account_collection_id)
					inner join v_corp_family_account
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
	echo browsingMenu($dbconn, $index, (preg_match('/^by(office|name)$/', $index))?'both':'default');
	echo "<table id=\"peoplelist\">\n";
	?>


	<tr>
	<td> </td>
	<td> Employee Name </td> 
	<td> Title </td> 
	<td> Company </td> 
	<td> Manager </td> 
	<td> Functional Team </td> 
	<td> Location </td> 
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
			echo "<br>(" .hierlink('reports', $row['person_id'], "team").")";
		}
		echo "</td>";

		echo "<td> ". $row['position_title'] . "</td>\n";
		echo "<td> ". $row['company_name'] . "</td>\n";

		# Show Manager Links
		if(isset($row['manager_person_id'])) {
			$mgrname = $row['mgr_first_name']. " ". $row['mgr_last_name'];
			echo "<td>". personlink($row['manager_person_id'], $mgrname);

			echo "<br>(" .hierlink('reports', $row['manager_person_id'], "team").")";
			echo "</td>\n";

		} else {
			echo "<td></td>";
		}

		echo "<td>" . hierlink('team', $row['account_collection_id'],
			$row['account_collection_name']). "</td>\n";
		echo "<td> ". $row['office_location'] . "</td>\n";
	    echo "\t</tr>\n";
	}
	echo "</table>\n";

	if($showarrow) {
		echo "<div class=navbar>\n";
		if($offset >= 1) {
			$qs = build_url(build_qs(null, 'offset', 0));
			?> <a href="<?php echo $qs; ?> "> FIRST </a> // <?php

			$qs = build_url(build_qs(null, 'offset', $offset-1));
			?> <a href="<?php echo $qs; ?> "> PREV </a> // <?php
		} 

		if($numpages) {
			$qs = build_url(build_qs(null, 'offset', $offset+1));
			?> <a href="<?php echo $qs; ?> "> NEXT </a> <?php
			$qs = build_url(build_qs(null, 'offset', $numpages));
			?> // <a href="<?php echo $qs; ?> "> LAST </a> <?php
		}

		echo "</div>\n";
	}
} else {
	echo browsingMenu($dbconn, $index);
	echo "<h3> Browse by Functional Team </h3>\n";
	echo "<div class=teamlist><ul>\n";
	while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
		echo "<li>" . hierlink('team', $row['account_collection_id'],
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
