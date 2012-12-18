// Global clients counter
$.Ovpnc().count = 0;
var total_count = 0;
(function($) {

    $.Client = function(options) {
        var obj = $.extend({},
        mem, actions);
        return obj;
    };

    var mem = {
        processed: 0,
        loop:  0,
        total_count: 0
    };
    
    var actions = {
        set_clients_table: function() {
            $.ajaxSetup({
                cache: false,
                async: true
            });
            $('#flexme').flexigrid({
                url: '/api/clients',
                dataType: 'json',
                method: "GET",
                preProcess: format_client_results,
                colModel: [
                // TODO: Save table proportions in cookie
                    { display: 'ID', name : 'id', width: 15, sortable : true, align: 'right', hide: true },
                    { display: 'Username', name : 'username', width : 100, sortable : true, align: 'left'},
                    { display: 'Virtual IP', name : 'virtual_ip', width : 85, sortable : true, align: 'left'},
                    { display: 'Remote IP', name : 'remote_ip', width : 85, sortable : true, align: 'left'},
                    { display: 'Remote Port', name : 'remote_port', width : 40, sortable : true, align: 'left', hide: true },
                    { display: 'Bytes in', name : 'bytes_recv', width : 60, sortable : true, align: 'center'},
                    { display: 'Bytes out', name : 'bytes_sent', width : 60, sortable : true, align: 'center'},
                    { display: 'Connected Since', name : 'conn_since', width : 150, sortable : true, align: 'left' },
                    { display: 'Fullname', name : 'fullname', width : 100, sortable : true, align: 'left' },
                    { display: 'Email', name : 'email', width : 80, sortable : true, align: 'left', hide: true },
                    { display: 'Phone', name : 'phone', width: 80, sortable : true, align: 'right', hide: true },
                    { display: 'Address', name : 'address', width: 100, sortable : true, align: 'right', hide: true },
                    { display: 'Enabled', name : 'enabled', width: 40, sortable : true, align: 'right', hide: false },
                    { display: 'Blocked', name : 'revoked', width: 40, sortable : true, align: 'right', hide: false },
                    { display: 'Created', name : 'created', width: 100, sortable : true, align: 'right', hide: false },
                    { display: 'Modified', name : 'modified', width: 100, sortable : true, align: 'right', hide: false }
                ],
                buttons : [
                    { name: 'Add', bclass: 'add', onpress : add_client },
                    { name: 'Delete', bclass: 'delete', onpress : delete_client },
                    { name: 'Block', bclass: 'block', onpress : block_clients },
                    { name: 'Unblock', bclass: 'unblock', onpress : unblock_clients },
                    { name: 'Edit', bclass: 'edit', onpress : test_edit },
                    { separator: true}
                ],
                searchitems : [
                    { display: 'Virtual IP', name : 'virtual_ip'},
                    { display: 'Remote IP', name : 'remote_ip'},
                    { display: 'Remote Port', name : 'remote_port'},
                    { display: 'Created', name : 'created'},
                    { display: 'Modified', name : 'modified'},
                    { display: 'Fullname', name : 'fullname'},
                    { display: 'Email', name : 'email'},
                    { display: 'Since', name : 'conn_since'},
                    { display: 'Username', name : 'username', isdefault: true}
                ],
                sortname: "username",
                sortorder: "asc",
                usepager: true,
                title: 'Clients',
                useRp: true,
                rp: 15,
                showTableToggleBtn: false,
                width: $('#middle_frame').width() - 40,
                height: 300
            });
        },
        update_flexgrid : function(r){
            // Color unknown client in red
            $('#flexme').find('tr').children('td[abbr="id"]')
                        .children('div').each(function(k, v){
                var inner_text = v.innerHTML.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                if ( inner_text === 'unknown' ){
                    $(this).parent().parent('tr').children('td[abbr="username"]')
                        .children('div').css('color','red');
                    if ( $(this).parent().parent('tr').children('td[abbr="id"]').text() === 'unknown' ){
                        $(this).parent().parent('tr').remove();
                    }                    
                }
            });
            // Set the right color - on/off notice according
            // to client's status
            var _checker = 0;
            $('#flexme').find('tr').children('td[abbr="username"]')
                        .children('div').each(function(k, v){
                // we match the username from online_data
                // to the current tr.td[abbr=username].div.text in the loop
                // inner_text is in order to get only the username and not
                // any span we might have appended previous loop
                var inner_text = v.innerHTML.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                var online_data = $.Client().check_clients_match(r.rest.clients, inner_text);
                if (online_data !== false) {
                    _checker++;
                    // loop each td find the corresponding 'abbr'
                    // fill in the text from online_data
                    var mem_ip;
                    for (var i in online_data) {
                         if (i !== 'name') {
                            if ( i.match(/^bytes_.*$/) )
                                online_data[i] = ( online_data[i] / 1024 ).toFixed(2) + 'KB';
                                $(this).parent().parent('tr')
                                       .children('td[abbr="' + i + '"]')
                                       .children('div')
                                       .text( online_data[i] ).css('color','black');
                            }
                        }
                        // mark the row which has been found to be online
                        if ( ! $(this).children('span.inner_flexi_text').is(':visible') ){
                            $(this).append('<span class="inner_flexi_text">on</span>');
                        }
                    }
                else {
                    // Clean up td's with online data
                    // for client which is not online
                    $(this).children('span.inner_flexi_text').hide(300).remove();
                    if ( $(this).parent().parent('tr')
                                .children('td').children('div')
                                .text() !== '-'
                    ) {
                        var removable =
                            [ "remote_ip", "virtual_ip", "conn_since", "remote_port", "bytes_recv", "bytes_sent" ];
                        for (var z in removable) {
                            $(this).parent().parent('tr')
                            .children('td[abbr="' + removable[z] + '"]')
                                   .children('div').css('color','lightgray');
                        }
                    }
                }
            });
            if ( _checker === 0 && r.rest.clients.length > 0 ){
                $('.pReload').click();
            }
        },
        //
        // Check if client names match
        //
        check_clients_match: function(clients, current_client) {
            for (var i in clients) {
                if (clients[i].name === current_client) return clients[i];
            }
            return false;
        },
        check_complete_block: function(loop, processed, total_count, action){
            if ( processed === total_count ){
                alert($.Ovpnc().alert_ok
                        + ' Total ' + processed
                        + ' client' + ( processed === 1 ? ' ' : 's ' )
                        + action + 'd</div><div class="clear"></div>' );
                $('.pReload').click();
                return;
            }
            if ( loop === total_count ){
                $('.pReload').click();
                if ( processed === 0 ){
                    if ( total_count > 1 )
                        alert( $.Ovpnc().alert_icon + ' No clients ' + action + 'd!</div><div class="clear"></div>' );
                }
                else {
                    alert( $.Ovpnc().alert_icon + ' Only ' + processed + ' out of ' + total_count + ' clients ' + action + 'd</div><div class="clear"></div>' );
                }
            }
        }
    };

})(jQuery);

$(document).ready(function(){
	// Declare flexigrid
	// Will run a query
	// to get clients
    $.Client().set_clients_table();

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
    $.Ovpnc().ajax_call("/api/clients/", { client: _clients },
    'REMOVE', client_delete_return, client_delete_error, 1, 15000 );
}

function client_delete_return(r){
    console.log("%o",r.rest);    
    if ( r.rest.deleted !== undefined  ){
        if ( r.rest.deleted.length > 0 ){
            alert($.Ovpnc().alert_ok
                    + ' Total ' + r.rest.deleted.length
                    + ' client' + ( r.rest.deleted.length === 1 ? ' ' : 's ' )
                    + ' deleted</div><div class="clear"></div>' );
        }
        else {
            alert( $.Ovpnc().alert_err + 'No clients deleted!</div><div class="clear"></div>' );
            return;
        }
    }
    if ( r.rest.failed !== undefined && r.rest.failed.length > 0 ){
        alert( $.Ovpnc().alert_icon + r.rest.failed.length + ' out of ' + total_count + ' clients failed delete</div><div class="clear"></div>' );
    }
    $('.pReload').click();
}

function client_delete_error(e){
    console.log("Delete error: %o",e);
    if ( e.responseText !== undefined ){
        var msg = jQuery.parseJSON( e.responseText );
        alert( $.Ovpnc().alert_err + 'Clients failed delete: ' + msg + '</div><div class="clear"></div>' );
    }
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
				$.Ovpnc().ajax_call( "/api/server/status", { }, 'GET', $.Ovpnc().update_server_status );
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
        var _tr = this;
        // Get rid of any html
        client = client.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
        // Revoke client/disconnect
        $.Ovpnc().set_ajax_loading();
        $.ajax({
            url: '/api/clients/' + client,
            type: action,
            timeout: 5000,
            data: {},
            dataType: 'json',
            success: function( msg ) {
                if ( msg === undefined ) return;
                if ( msg.error !== undefined
                  && typeof msg.error.length !== undefined 
                  && Object.prototype.toString.call( msg.error ) === '[object Array]'
                  && msg.error.length > 0
                ){
                    alert( $.Ovpnc().alert_err + " " + msg.error.join() + '</div><div class="clear"></div>');
                }
                if ( msg.error === undefined && typeof msg.rest !== "undefined" ){
                    if ( msg.rest.match( /revoked ok/g )
                      || msg.rest.match( /Un-revocation success/g )
                    ){
                        // Remove select class from tr
                        // and append to processed
                        $(_tr).removeClass('trSelected');
                        // Update the revoked column
/*
                        $('#flexme').find('tr').children('td[abbr="username"]')
                            .children('div').each(function(k, v){
                            var inner_text = v.innerHTML.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                            if ( inner_text === client ){
                                $(this).parent().parent('tr').children('td[abbr="revoked"]')
                                       .children('div').text( ( action === 'revoke' ? '1' : '0' ) );
                            }
                        });
*/
                        processed++;
                    }
                    else {
                        alert( $.Ovpnc().alert_err + " " + msg.rest.replace(';','') + '</div><div class="clear"></div>');
                    }
                }
            },
            error: function(xhr, ajaxOptions, thrownError){
                var err = xhr.responseText;
                alert( $.Ovpnc().alert_err + " Failed command " + action + " for '" + client + "': " + xhr.responseText + '</div><div class="clear"></div>');
            },
            complete : function(){
                loop++;
                $.Ovpnc().remove_ajax_loading();
                $.Client().check_complete_block(loop, processed, total_count, action);
            }
        });
    });
}
