// Global clients counter
$.Ovpnc().count = 0;
var total_count = 0;
(function($) {

    $.Client = function(options) {
        var obj = $.extend({},
        mem );
        return obj;
    };

    var mem = {
        processed: 0,
        loop:  0,
        total_count: 0
    };

})(jQuery);

$(document).ready(function(){

	// Declare flexigrid
	// Will run a query
	// to get clients
    $.Ovpnc().set_clients_table();
	// Show the clients table
	$('.flexigrid').slideDown(300);
    
    function block_clients(button, grid) {}
    function unblock_clients(button, grid) {}
    function delete_client(button, grid) {}
    
});

function add_client() {
    window.location = '/clients/add';
}

function delete_client(button, grid){

    // Get total selected clients
    total_count = $('.trSelected', grid).length;
    var _clients = '';
    $.each($('.trSelected', grid), function() {
        // Get the client's name of this grid
        var client = $('td:nth-child(2) div', this).html();
        // Get rid of any html
        client = client.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
        _clients += client + ',';    
        $.Client().loop = $.Client().loop + 1;
    });
    $.Ovpnc().get_data("/api/clients/", { client: _clients },
    'REMOVE', client_delete_return, client_delete_error );
}

function client_delete_return(r){
    console.log("%o",r.rest);    
    if ( r.rest.deleted !== undefined  ){
        if ( r.rest.deleted.length > 0 ){
            alert( 'Total ' + r.rest.deleted.length
                    + ' client' + ( r.rest.deleted.length === 1 ? ' ' : 's ' )
                    + ' deleted' );
        }
        else {
            alert( 'No clients deleted!' );
            return;
        }
    }
    if ( r.rest.failed !== undefined && r.rest.failed.length > 0 ){
        alert( r.rest.failed.length + ' out of ' + total_count + ' clients failed delete' );
    }
    $('.pReload').click();
}

function client_delete_error(e){
    console.log("Delete error: %o",e);
}

function block_clients(button, grid){
    block_unblock_clients(button, grid, 'revoke');
}

function unblock_clients(button, grid){
    block_unblock_clients(button, grid, 'unrevoke');
}

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

function block_unblock_clients(button, grid, action){
    // Get total selected clients
    var total_count = $('.trSelected', grid).length;
    var processed = 0;
    var loop = 0;
    $.each($('.trSelected', grid), function() {
        // Get the client's name of this grid
        var client = $('td:nth-child(2) div', this).html();
        // Get rid of any html
        client = client.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
        // Revoke client/disconnect
        $.ajax({
            url: '/api/clients/' + client,
            type: action,
            data: {},
            dataType: 'json',
            success: function( msg ) {
                if ( msg && msg.rest !== undefined ){
                    if ( msg.rest.match( /revoked ok.*SUCCESS/g )
                      || msg.rest.match( /Un-revocation success/g )
                    ){
                        processed++;
                    }
                    else {
                        alert( "'" + client + "' " + action + " failed: " + msg.rest );
                    }
                }
                else {
                    alert( "'" + client + "' " + action + " failed: " + msg.rest );
                }
            },
            error: function(xhr, ajaxOptions, thrownError){
                var err = xhr.responseText;
                alert( "Failed command " + action + " for '" + client + "': " + xhr.responseText );
            },
            complete : function(){
                loop++;
                check_complete_block(loop, processed, total_count, action);
            }
        });
    });
}

function check_complete_block(loop, processed, total_count, action){
    if ( processed === total_count ){
        alert( 'Total ' + processed
                + ' client' + ( processed === 1 ? ' ' : 's ' )
                + action + 'd' );
        return;
    }
    if ( loop === total_count ){
        if ( processed === 0 ){
            alert( 'No clients ' + action + 'd!' );
        }
        else {
            alert( 'Only ' + processed + ' out of ' + total_count + ' clients ' + action + 'd' );
        }
    }
}

