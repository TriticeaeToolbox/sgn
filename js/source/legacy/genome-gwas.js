var self = document.location.href;

function getChrom()
{
    var gexp = document.getElementById("protocol").value;
    var url = self + "?function=getChrom&prot=" + gexp;
    document.getElementById("step3").innerHTML = "";
}

function select_markers()
{
    var gexp = document.getElementById("protocol").value;
    var method = document.querySelector('input[name="method"]:checked').value;
    document.getElementById("step3").innerHTML = "";
    var url = self + "?function=query&prot=" + gexp + "&method=" + method;
    jQuery.get(url, function( data ) {
        jQuery("#step3").html( data );
    })
}
