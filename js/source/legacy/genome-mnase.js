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
    var gexp = document.getElementById("protocol").value;
    var chrom = document.getElementById("chrom").value;
    var start = document.getElementById("start").value;
    var stop = document.getElementById("stop").value;
    var elem = document.getElementById("SearchButton");
    if (elem.value=="Search") {
	elem.value="Searching";
    }
    document.getElementById("step2").innerHTML = "";
    document.getElementById("step3").innerHTML = "";
    var url = self + "?function=getVEP&prot=" + gexp;
    jQuery.get(url, function( data ) {
        jQuery("#step2").html( data );
    });
    var url = self + "?function=query&prot=" + gexp + "&chrom=" + chrom + "&start=" + start + "&stop=" + stop;
    jQuery.get(url, function( data ) {
        jQuery("#step3").html( data );
    })
    .done(function() {
	elem.value="Search";
    });
}
