$.Ovpnc.count = 0;

// Document ready
$(document).ready(function(){

	// Declare flexigrid
    set_clients_table();

	// Show the clients tab;e
	$('.flexigrid').slideDown(300);

    // Then loop every n miliseconds
//    setInterval(function() {
//		$('#flexme').flexReload();
//   }, $.Ovpnc().poll_freq );

//	$('#flexme').flexigrid({dataType : "json"});
var update = setInterval(function() {
	$('#flexme').flexAddData({
		clients: [ 
			 {
		        "virtual_ip" : "5.5.5.5",
		        "remote_ip" : "1.2.7.92",
		        "epoc_since" : "91074",
		        "name" : "test",
		        "conn_since" : "Fri Nov 22 18:17:54 2012",
		        "bytes_sent" : "10111",
		        "bytes_recv" : "111115",
		        "remote_port" : "56561111119"
		  	}
		]
	});
	window.clearInterval(update);
 }, 1000);

});

function set_clients_table(){

	$('#flexme').flexigrid({
	    url: '/api/server/status',
	    dataType: 'json',
		preProcess: format_results,
		// TODO: Save table proportions in cookie
	    colModel : [
	        { display: 'Name', name : 'name', width : 100, sortable : true, align: 'left'},
	        { display: 'Virtual IP', name : 'virtual_ip', width : 60, sortable : true, align: 'center'},
	        { display: 'Remote IP', name : 'remote_ip', width : 100, sortable : true, align: 'left'},
	        { display: 'Connected Since', name : 'conn_since', width : 120, sortable : true, align: 'left', hide: false},
	        { display: 'Bytes in', name : 'bytes_recv', width : 60, sortable : true, align: 'right'},
	        { display: 'Bytes out', name : 'bytes_sent', width : 60, sortable : true, align: 'right'}
	    ],
	    buttons : [
	        { name: 'Add', bclass: 'add', onpress : console.log('add') },
	        { name: 'Delete', bclass: 'delete', onpress : console.log('delete') },
	        { name: 'Block', bclass: 'block', onpress : console.log('block') },
	        { separator: true}
	    ],
	    searchitems : [
	        { display: 'vIP', name : 'virtual_ip'},
	        { display: 'rIP', name : 'remote_ip'},
	        { display: 'since', name : 'conn_since'},
	        { display: 'Name', name : 'name', isdefault: true}
	    ],
	    sortname: "name",
	    sortorder: "asc",
	    usepager: true,
	    title: 'Clients',
	    useRp: true,
	    rp: 15,
	    showTableToggleBtn: false,
	    width: 530,
	    height: 300
	});

}

// Format the data from
// server status, processing
// only the clients array
function format_results(d){

	update_server_status(d); // Make sure to update server status div info

	if ( d.clients !== undefined && d.clients.length !== undefined ){
		var __rows = new Array();
		var __count = 0;
		for ( var index in d.clients ){
			$.Ovpnc.count++;
			__count++;
			__rows.push({
				id: $.Ovpnc.count,
				cell: get_client_col_data(d.clients[index])
			});
		}
		return {
//			total: __count,
			total: $.Ovpnc.count,
			page: 1,
			rows: __rows
		}
	}
}

function get_client_col_data(c){
	// Array order must be
	// the same as the colModel
	return [
		c.name,
		c.virtual_ip,
		c.remote_ip + ':' + c.remote_port, // Attach remote port to remote ip
		c.conn_since,
		c.bytes_recv,
		c.bytes_sent
	]
}
