// Global clients counter
$.Ovpnc().count = 0;
$(document).ready(function(){

	// Declare flexigrid
	// Will run a query
	// to get clients
    $.Ovpnc().set_clients_table();

	// Show the clients table
	$('.flexigrid').slideDown(300);

    function block_clients(button, grid) {}
});

// Format the data from
// server status, processing
// only the clients array
function format_client_results(obj){

	// This will force to update
	// online_data and not wait

	var is_felxgrid_ready =
		setInterval(function(){
			if ( $('#flexme').is(':visible') ){
				$.Ovpnc().get_data( "/api/server/status", { }, 'GET', update_server_status );
				window.clearInterval(is_felxgrid_ready);
			}
		}, 100);

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

    // Some fields have to contain
    // placeholders '-' because they
    // only get updated when server
    // status request returns
    // this keeps flexgrid from
    // messing up the order
	return [
        c.id ? c.id : 'unknown',
        c.username ? c.username : 'unknown',
        c.virtual_ip ? c.virtual_ip : '-',
        c.remote_ip ? c.remote_ip : '-',
        c.remote_port ? c.remote_port : '-',
        c.bytes_recv ? ( c.bytes_recv / 1024 ).toFixed(2) + 'KB' : '-',
        c.bytes_sent ? ( c.bytes_sent / 1024 ).toFixed(2) + 'KB' : '-',
        c.conn_since ? c.conn_since : '-',
        c.fullname ? c.fullname : 'unknown',
        c.email ? c.email : 'unknown',
        c.phone ? c.phone : 'unknown',
        c.address ? c.address : 'unknown',
        c.enabled ? c.enabled : 0,
        c.revoked ? c.revoked : 0,
        c.created ? c.created : '0000-00-00 00:00',
        c.modified ? c.modified : '0000-00-00 00:00'
    ]
}

function block_clients(button,grid){
    // Get total selected clients
    var total_count = $('.trSelected', grid).length;
    var blocked = 0;
    var loop = 0;

    $.each($('.trSelected', grid), function() {
        // Get the client's name of this grid
        var client = $('td:nth-child(2) div', this).html();
        // Get rid of any html
        client = client.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
        // Revoke client/disconnect
        $.ajax({
            url: '/api/clients/' + client,
            type: 'REVOKE',
            data: {},
            dataType: 'json',
            success: function(msg) {
                if ( msg && msg.rest !== undefined ){
                    if ( msg.rest.match( /revoked ok.*SUCCESS/g ) ){
                        blocked++;
                    }
                    else {
                        alert( "'" + client + "' revoke failed: " + msg.rest );
                    }
                }
                else {
                    alert( "'" + client + "' revoke failed: " + msg.rest );
                }
            },
            error: function(xhr, ajaxOptions, thrownError){
                var err = xhr.responseText;
                alert( "Error revoking '" + client + "': " + xhr.responseText );
            },
            complete : function(){
                loop++;
                check_complete_block(loop, blocked, total_count);
            }
        });
    });
}

function check_complete_block(loop,blocked,total_count){
    if ( blocked === total_count ){
        alert( 'Total ' + blocked + ' clients blocked' );
        return;
    }
    if ( loop === total_count ){
        if ( blocked === 0 ){
            alert( 'No clients blocked!' );
        }
        else {
            alert( 'Only ' + blocked + ' out of ' + total_count + ' clients blocked' );
        }
    }
}
