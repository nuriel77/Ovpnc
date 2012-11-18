/* index js lib */
"use strict";

/* Declare namespace */
var ovpnc = new Object();
ovpnc.mem = new Object();
ovpnc.actions = new Object();

// Actions
ovpnc.actions = {
	poll_status : function() { return init_loop_get_status(); },
	hover_binds : function() { return init_hover_binds(); }
};

/* jQuery begin document */
$(document).ready(function()
{

		$.getDATA = function(url) {
        	return jQuery.ajax({
        		headers: { 'Accept': 'application/json' },
		        async : true,
		        timeout: 3000,
		        tryCount : 0,
		        retryLimit : 3,
		        cache: false,
			    url: url,
		        success : function(r){
					$('#server_status').text('online').css('color','green');
					if (typeof(r.title) !== "undefined") populate_version(r.title);
					populate_clients(r.clients);		
				},
				error : function(xhr, ajaxOptions, thrownError) {
			        console.debug("Error getting status: " + xhr.status + ", " + thrownError)
					this.tryCount++;
			        if (this.tryCount <= this.retryLimit) {
			            console.log( "Going to retry connection to host loop: " + this.tryCount);
			            //try again
			            $.ajax(this);
			            return;
			        }

					if ( $(".client_div").is(":visible") ){
						$(".client_div").hide(400);
					}
					$('#client_status_container').html("<div id='no_data'>No data recieved, possible error: " + thrownError.toString() + "</div>").show(400);
					return false;
				}
			})
		};

	// Get status (loop)
	ovpnc.actions.poll_status();

});


/*
	- Functions -
*/


function init_loop_get_status()
{

	// run first one
	get_server_status();

	// Then loop even n miliseconds
	setInterval(function() {
		get_server_status();
	}, 5000);
}

function get_server_status()
{

	$.getDATA( "/api/server/status" );

        //.beforeSend( function(){
        //  console.log( "At retry loop " + this.tryCount );
        //},	

}

function populate_clients(c)
{
	if (c.length === 0){

		if ( ! $("#no_clients").is(":visible") ){
			if ( $(".client_div").is(":visible") ){
				$(".client_div").hide(600);
			}
			$('#client_status_container').html( '<div class="client_div" id="no_clients">No clients connected</div>' );
			$('#no_clients').show(400);
		}

		return;
	}
	else {
		// Clean up the no_clients div if it exists
		if ( $("#no_clients").is(":visible") ) 		$("#no_clients").hide();
		if ( $("#no_data").is(":visible") ) 		$("#no_data").hide();
	}

	$('.client_div').each(function(){

		// Current open client divs
		var current_name = this.id;
		current_name = current_name.replace(/.*_(.*)$/, "$1");
		var checker = 0;
		// Comapre with names recieved from ajax
		for ( var i=0;i<c.length;i++ ){
			if ( c[i].name === current_name ){
				//console.log("Match: " +  current_name);
				checker++;
			}
		}
		// Remove this div if it is not found in recieved data
		if (checker === 0){
			//console.log( current_name + " has to go..." );
			$('#client_name_' + current_name).hide(200); 
		}

	});

	// For each client
	for (var i=0;i<c.length;i++){
		// Get client object
		var client_obj = c[i];
		var disp_client = 'none';

		if (client_obj['name'] !== 'UNDEF' ){
			
			if ( $('#' + client_obj['name'] + '_hidden_data').is(':visible') ){
				disp_client = 'block';
			}
			var output = '<div class="client_keys">' + client_obj['name'] + '</div>'
				    + '<div class="client_values">'
					+ ' <span style="float:right;margin-left:4px">'
					+ client_obj['virtual_ip']
					+ ' </span>'
					+ '</div><!-- client_name -->' 
					+ '<br/>'
					+ '<div style="display:' + disp_client + '" class="client_hidden_data" id="' + client_obj['name'] + '_hidden_data">';
	
			// for each client's data
			for (var obj in client_obj){
				if ( obj !== 'name' && !obj.match(/epoc_since|virtual_ip/) ) {
					if ( ! isNaN(client_obj[obj]) && obj !== 'remote_port' ){
						client_obj[obj] = numberWithCommas(client_obj[obj]);
					}
					output += '<div class="client_keys">'
							+ obj
							+ ':</div><!-- client_keys -->' 
							+ '<div class="client_values" >'
							+ client_obj[obj]
							+ '</div><!-- client_values -->';
				}
			}

			output += '</div><!-- client_hidden_data -->';

			if ( ! $("#client_name_" + client_obj["name"] ).is(':visible') ){

				$('#client_status_container').append(
					  '<div class="client_div" id="client_name_' + client_obj['name'] + '">'
					+ ' <div class="client_data" id="data_client_name_' + client_obj['name'] + '">'
					+ output
					+ ' </div><!-- client_data -->'
					+ ' <hr />' 
			  		+ ' <div class="client_actions">'
					+ '  <div class="client_action_link" title="Kill client" style="float:right" id="' + client_obj['name'] + '_kill" onClick="kill_client(\'' + client_obj['name'] +'\');" >' 
					+ '   <img src="/static/images/kill_client.png" style="margin-top:-3px"></img></div>'
					+ '  </div>'
					+ '  <div class="client_action_link" title="Extend status" id="' + client_obj['name'] + '_ext_status" onClick="extend_client_data(\'' + client_obj['name'] + '\');" >'
					+ '   <img src="/static/images/Alarm-Plus-icon.png"></img></div>'
					+ ' </div><!-- client_actions -->'
					+ '</div><!-- client_div -->'
				);

				$('#client_name_' + client_obj['name']).show(500);
			}
			else {
				$("#data_client_name_" + client_obj["name"] ).html(output);
			}
		}
	}
}

function extend_client_data(n){
	if ( $('#' + n + '_hidden_data').is(':visible') ){
		$('#' + n + '_hidden_data').hide(400);
		$('#' + n + '_ext_status').html("<img src='/static/images/Alarm-Plus-icon.png'></img>");
	}
	else {
		$('#' + n + '_hidden_data').show(400);
		$('#' + n + '_ext_status').html("<img src='/static/images/Alarm-Minus-icon.png'></img>");
	}
}

function populate_version(s)
{
	$('#server_version').text( s ? s : '' );
}

function init_hover_binds(){

	// Client action links hover
	$('.unkill_me').hover(function(){
		$(this).css('text-shadow','#999 1px -1px 1px');
		}, function(){
		$(this).css('text-shadow','none');
	});

}

function numberWithCommas(n) {
    var parts=n.toString().split(".");
    return parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",") + (parts[1] ? "." + parts[1] : "");
}

function kill_client(c){

	$.getJSON('/api/server/kill/' + c, function(r){
		append_dead_client(c);
		alert("Client '" + c + "' killed successfully");
		return true;		
	}).error(function(xhr, ajaxOptions, thrownError) {
		console.log("Error killing client '" + c + "': " + thrownError.toString());
		alert("Error killing client '" + c + "': " + thrownError.toString());
		return false;
	});

}

function unkill_client(c){

	$.getJSON('/api/server/unkill/' + c, function(r){
		$('#unkill_' + c).remove();
		if ( $('#killed_clients').text() === '' ) $('#killed_clients_container').hide(400);
		alert("Client '" + c + "' unkilled successfully");
		return true;		
	}).error(function(xhr, ajaxOptions, thrownError) {
		console.log("Error unkilling client '" + c + "': " + thrownError.toString());
		alert("Error unkilling client '" + c + "': " + thrownError.toString());
		return false;
	});

}

function append_dead_client(c){

	var output = '<div class="unkill_me" title="Click to unkill"'
				+ ' onClick="unkill_client(\'' + c +'\');" id="unkill_' + c +'">'
				+ c + ' - unkill'
				+ '</div>';

	$('#killed_clients').append(output);

	if ( ! $('#killed_clients_container').is(":visible") ){
		$('#killed_clients_container').show(400);
		ovpnc.actions.hover_binds();
	}

}
