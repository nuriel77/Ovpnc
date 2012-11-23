// Document ready
$(document).ready(function(){
    set_clients_table();
	$('.flexigrid').hide().slideDown(300);
});

function set_clients_table(){

	$('#flexme').flexigrid({
	    url: '/api/server/status',
	    dataType: 'json',
	    colModel : [
	        { display: 'ISO', name : 'iso', width : 40, sortable : true, align: 'center'},
	        { display: 'Name', name : 'name', width : 180, sortable : true, align: 'left'},
	        { display: 'Printable Name', name : 'printable_name', width : 120, sortable : true, align: 'left'},
	        { display: 'ISO3', name : 'iso3', width : 130, sortable : true, align: 'left', hide: true},
	        { display: 'Number Code', name : 'numcode', width : 80, sortable : true, align: 'right'}
	    ],
	    buttons : [
	        { name: 'Add', bclass: 'add', onpress : alert('add') },
	        { name: 'Delete', bclass: 'delete', onpress : alert('delete') },
	        { name: 'Block', bclass: 'block', onpress : console.log('block') },
	        { separator: true}
	    ],
	    searchitems : [
	        { display: 'ISO', name : 'iso'},
	        { display: 'Name', name : 'name', isdefault: true}
	    ],
	    sortname: "iso",
	    sortorder: "asc",
	    usepager: true,
	    title: 'Clients',
	    useRp: true,
	    rp: 15,
	    showTableToggleBtn: true,
	    width: 530,
	    height: 300
	});
}
