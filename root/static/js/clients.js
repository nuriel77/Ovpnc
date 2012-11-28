$.Ovpnc().count = 0;

// Document ready
$(document).ready(function(){

	// Declare flexigrid
	// Will run a query
	// to get clients
    set_clients_table();

	// Show the clients table
	$('.flexigrid').slideDown(300);

	// This will force to update
	// online_data and not wait
	// until the next update_Server loop
	// This way user can see immediately
	// who is online when he opens this page
	var is_felxi_ready =
		setInterval(function(){
			if ( $('#flexme').is(':visible') ){
				$.getDATA( "/api/server/status" );
				window.clearInterval(is_felxi_ready);
			}
		}, 100);

});

function set_clients_table(){
	$.ajaxSetup({ cache: false, async: true });
	$('#flexme').flexigrid({
	    url: '/api/clients',
	    dataType: 'json',
		method: "GET",
		preProcess: format_results,
		colModel : [
		// TODO: Save table proportions in cookie
			{ display: 'ID', name : 'id', width: 80, sortable : true, align: 'right', hide: true },
	        { display: 'Username', name : 'username', width : 100, sortable : true, align: 'left'},
	        { display: 'Fullname', name : 'fullname', width : 100, sortable : true, align: 'left', hide: true },
	        { display: 'Email', name : 'email', width : 80, sortable : true, align: 'left'},
			{ display: 'Phone', name : 'phone', width: 80, sortable : true, align: 'right', hide: true },
			{ display: 'Address', name : 'address', width: 100, sortable : true, align: 'right', hide: true },
			{ display: 'Enabled', name : 'enabled', width: 10, sortable : true, align: 'right', hide: false },
			{ display: 'Revoked', name : 'revoked', width: 10, sortable : true, align: 'right', hide: false },
			{ display: 'Created', name : 'created', width: 100, sortable : true, align: 'right', hide: true },
			{ display: 'Modified', name : 'modified', width: 100, sortable : true, align: 'right', hide: false },
	        { display: 'Remote IP', name : 'remote_ip', width : 120, sortable : true, align: 'left'},
	        { display: 'Virtual IP', name : 'virtual_ip', width : 120, sortable : true, align: 'left'},
	        { display: 'Connected Since', name : 'conn_since', width : 130, sortable : true, align: 'left', hide: false},
	        { display: 'Bytes in', name : 'bytes_recv', width : 60, sortable : true, align: 'right'},
	        { display: 'Bytes out', name : 'bytes_sent', width : 60, sortable : true, align: 'right'}
	    ],
	    buttons : [
	        { name: 'Add', bclass: 'add', onpress : console.log('add') },
	        { name: 'Delete', bclass: 'delete', onpress : console.log('delete') },
	        { name: 'Block', bclass: 'block', onpress : console.log('block') },
	        { name: 'Edit', bclass: 'edit', onpress : console.log('edit') },
	        { separator: true}
	    ],
	    searchitems : [
	        { display: 'vIP', name : 'virtual_ip'},
	        { display: 'rIP', name : 'remote_ip'},
	        { display: 'created', name : 'created'},
	        { display: 'modified', name : 'modified'},
	        { display: 'fullname', name : 'fullname'},
	        { display: 'email', name : 'email'},
	        { display: 'since', name : 'conn_since'},
	        { display: 'username', name : 'username', isdefault: true}
	    ],
	    sortname: "name",
	    sortorder: "asc",
	    usepager: true,
	    title: 'Clients',
	    useRp: true,
	    rp: 15,
	    showTableToggleBtn: false,
	    width: 600,
	    height: 300
	});

}

// Format the data from
// server status, processing
// only the clients array
function format_results(obj){

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

