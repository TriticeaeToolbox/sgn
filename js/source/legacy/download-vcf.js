var php_self = document.location.href;

function update_side()
{
    var url = "side_menu.php";
    jQuery.get(url, function( data ) {
        jQuery("#quicklinks").html( data );
    });
}

function getChromFile() {
    var gexp = document.getElementById("trial").value;
    var start = document.getElementById("start").value;
    var stop = document.getElementById("stop").value;
    var url = php_self + "?function=readChrom&trial=" + gexp;
    $(document).ready(function(){
    jQuery.get(url, function( data ) {
        jQuery("#step1").html( data );
    });
    document.getElementById('step2').innerHTML = "";
});
}

function select_chrom() {
    var gexp = document.getElementById("trial").value;
    var chrom = document.getElementById("chrom").value;
    var start = document.getElementById("start").value;
    var stop = document.getElementById("stop").value;
    var url = php_self + "?function=query&trial=" + gexp + "&chrom=" + chrom + "&start=" + start + "&stop=" + stop;
    jQuery.get(url, function( data ) {
        jQuery("#step2").html( data );
    }).fail(function() {
	alert('Error: Please select chromosome');
    });
}

function output_file(filename, trial) {
    url = php_self + "?function=download&filename=" + filename + "&trial=" + trial;
    window.open(url)
}

function save() {
    var url = php_self + "?function=save";
    jQuery.get(url, function( data ) {
        jQuery("#step2").html( data );
        update_side();
    });
}