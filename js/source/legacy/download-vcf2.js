
function select_chrom() {
    var gexp = document.getElementById("trial").value;
    var chrom = document.getElementById("chrom").value;
    var start = document.getElementById("start").value;
    var stop = document.getElementById("stop").value;
    var url = "/downloads/download-vcf.pl?function=query&trial=" + gexp + "&chrom=" + chrom + "&start=" + start + "&stop=" + stop;
    jQuery.ajax( {
        type: "GET",
        url: "/downloads/download-vcf.pl",
        data: "function=query&trial=" + gexp + "&chrom=" + chrom + "&start=" + start + "&stop=" + stop,
        success: function( data, textStatus) {
          jQuery("#step2").html( data );
        },
        error: function() {
          alert("Error selecting chromosome");
        }
    });
}

