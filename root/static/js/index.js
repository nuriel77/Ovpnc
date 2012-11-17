/* index js lib */
$(document).ready(function()
{
	init_loop_get_status();

});

function init_loop_get_status()
{
	// run first one
	get_status();
	// Then loop even n miliseconds
	setInterval(function() {
		get_status();
	}, 5000);
}

function get_status()
{
	$.ajaxSetup({
		cache: false,
		async: true,
		timeout: 3000	
	});
	
	$.getJSON("/api/server/status", function(r){
		if (typeof(r.title) !== "undefined")
			populate_title(r.title);
		populate_clients(r.clients);
	}).error(function(xhr, ajaxOptions, thrownError) {
        console.debug("Error getting status: " + xhr.status + ", " + thrownError)
		$('#clients').html("<p>No data recieved, possible error: " + thrownError + "</p>");
		return false;
	});
}

function populate_clients(c)
{
	if (c.length === 0){
		$('#clients').html("No clients connected");
		return;
	}
	var output = '';
	for (var i=0;i<c.length;i++){
		var client_obj = c[i];
		for (var obj in client_obj){
			output +=  obj + ' - ' + client_obj[obj] + '<br/>';
		}
	}
	$('#clients').html(output);
}

function populate_title(s)
{
	$('#status').text(s);
}
