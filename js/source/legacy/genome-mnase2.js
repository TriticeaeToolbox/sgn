var self = document.location.href;

function getChrom()
{
    var gexp = document.getElementById("protocol").value;
    var url = self + "?function=getChrom&prot=" + gexp;
    jQuery.get(url, function( data ) {
        jQuery("#step1").html( data );
    });
    document.getElementById("step2").innerHTML = "";
    document.getElementById("step3").innerHTML = "";
}

function select_markers()
{
    var chrom = document.getElementById("chrom").value;
    var start = document.getElementById("start").value;
    var stop = document.getElementById("stop").value;
    var elem = document.getElementById("SearchButton");
    if (elem.value=="Search") {
	elem.value="Searching";
    }
    document.getElementById("step2").innerHTML = "";
    document.getElementById("step3").innerHTML = "";
    var url = "https://dev.triticeaetoolbox.org/ajax/sequence_metadata/query"  + "?feature_id=2639703" + "&start=" + start + "&end=" + stop + "&reference_genome=RefSeq_v1"; 
    jQuery.getJSON(url, function( data ) {
	var items = [];
	var attributes = "";
	var links = "";
	var count = 0;
	$.each(data, function( key1, val1) {
	  items.push("<table id=\"mnase\" class=\"display\"><thead><tr><th>marker<th>chromosome<th>position<th>score<th>Gene<th>consequence<th>impact<th>links</tr></thead>");
	  items.push("<tbody>");
	  $.each(val1, function( key2, val2) {
	    attributes = "";
	    links = "";
	    if (typeof val2 === 'object') {
              $.each(val2, function( key3, val3) {
	        if (key3 === "attributes") {
		   attributes = "";
		   marker_name = val3.Name;
		   gene_id = val3.gene;
		   feature_id = val3.feature;
		   consequence = val3.consequence;
		   impact = val3.impact;
	           $.each(val3, function( key4, val4) {    
	             attributes += key4 + "=" + val4 + "<br>";
		   }); 
		} else if (key3 == "links") {
		   $.each(val3, function( key4, val4) {
		     links += "<a href=" + val4 + ">" + key4 + "</a><br>";
                   });
	        } else {
		    feature_name = val2.feature_name;
		    type_name = val2.type_name;
		    protocol_name = val2.nd_protocol_name;
		    start = val2.start;
		    end = val2.end;
		}
	      });
	      if (val2.nd_protocol_name == "MNase Open Chromatin") {
		score = val2.score;
	      }
	      if (val2.nd_protocol_name == "Variant Effect Predictor") {
	        items.push("<tr><td>" + marker_name + "<td>" + feature_name + "<td>" + start + "<td>" + score + "<td>" + feature_id + "<td>" + consequence + "<td>" + impact + "<td>" + links + "</tr>");
	      } else if (val2.nd_protocol_name == "MNase Open Chromatin") {
		if (marker_name) {
	        items.push("<tr><td>" + marker_name + "<td>" + feature_name + "<td>" + start + "<td>" + score + "<td>" + protocol_name + "<td>" + links + "<td>" + attributes + "</tr>");
	        }
	      }
	    } else {
	      //items.push("<tr><td>" + key2 + " val2=" + val2);
	    }
          });
	});
	items.push("</tbody></table>");
        jQuery("#step3").html(items.join(''));
	jQuery("#mnase").DataTable( {
		"paging": false,
		"order": [2, "asc"]
	});
    })
    .done(function() {
	elem.value="Search";
    });
}
