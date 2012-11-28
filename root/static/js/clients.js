// Global clients counter
$.Ovpnc().count = 0;

$(document).ready(function(){

	// Declare flexigrid
	// Will run a query
	// to get clients
    $.Ovpnc().set_clients_table();

	// Show the clients table
	$('.flexigrid').slideDown(300);

	// This will force to update
	// online_data and not wait
	// until the next update_Server loop
	// This way user can see immediately
	// who is online when he opens this page
	var is_felxgrid_ready =
		setInterval(function(){
			if ( $('#flexme').is(':visible') ){
				$.Ovpnc().get_data( "/api/server/status", { }, 'GET', update_server_status );
				window.clearInterval(is_felxgrid_ready);
			}
		}, 100);

});

// Format the data from
// server status, processing
// only the clients array
function format_client_results(obj){

	// Check when the table is 
	// ready and remove all 'undefined' values
	// TODO: check how to avoid 'undefined' via
	// flexigrid...
	var clearer = setInterval(function(){
		if ( $('#flexme').is(':hidden') ) return;
		$('#flexme').find('tr').children('td').children('div').each(function(k,v){
		   	if ( v.innerHTML === 'undefined' ) v.innerHTML = '';
		});
		window.clearInterval(clearer);
	}, 1);

	if ( obj.rest !== undefined && obj.rest.length !== undefined ){
		var __rows = new Array();
		var __count = 0;
		for ( var index in obj.rest ){
			$.Ovpnc().count++;
			__count++;
			__rows.push({
				id: $.Ovpnc().count,
				cell: prepare_client_col_data(obj.rest[index])
			});
		}
		return {
			total: __count,
			page: 1,
			rows: __rows
		}
	}
}

function prepare_client_col_data(c){
	return [
		c.id,
		c.username,
		c.fullname,
		c.email,
		c.phone,
		c.address,
		c.enabled,
		c.revoked,
		c.created,
		c.modified
	]
}

