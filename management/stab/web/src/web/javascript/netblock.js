//
// $Id$
//

function AddIpSpace(thing, parent_tr_id, gapid)
{
	var tbl, ptr, gap, uniq;

	for(tbl = thing; tbl.parentNode != null;        tbl = tbl.parentNode) {
		if(tbl.tagName == 'TABLE') {
			break;
		}
	}

	ptr = document.getElementById(parent_tr_id);
	if(tbl) {

		uniq = 0;
		for(uniq = 0; ; uniq++) {
			var idname = ""; 
			idname = "newiptr_" + uniq;
			dropname = document.getElementById(idname);
			if(dropname == null) {
						break;
			}
		}

		newtr = tbl.insertRow(ptr.rowIndex);
		newtr.style.display = 'none';
		newtr.id = "newiptr_" + uniq;
		newtr.style.visibility = 'hidden';

		url = "../device/device-ajax.pl?what=IpRow;uniqid=" + uniq;
		ajaxrequest = createRequest();
		ajaxrequest.open("GET", url, true);
		ajaxrequest.onreadystatechange = function () {
			if(ajaxrequest.readyState == 4) {
				var htmlgoo = ajaxrequest.responseText;
				// swaparrows("cirExpand_" + circid, 'down');
				newtr.innerHTML = htmlgoo;
				newtr.style.display = '';
				newtr.style.visibility = 'visible';

				gap = document.getElementById(gapid);
				if(gap) {
					var x = gap.innerHTML;
					x--;
					if(x > 0) {
						gap.innerHTML = x;
					} else {
						ptr.style.visibility = 'hidden';
						ptr.style.display = 'none';
					}
				}
			}
		}
		ajaxrequest.send(null);

	}
}
