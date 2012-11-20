/* index js lib */
"use strict";

/* Declare Ovpnc namespace */
;(function($) {

    // declare var in global scope
    window.Ovpnc = {};

    Ovpnc = {
		geo_username : function(){ 
			return $('#geo_username').attr('name');
		},
		actions : {
			poll_status : function() { return init_loop_get_status(); },
			hover_binds : function() { return init_hover_binds(); },
			click_binds : function() { return init_click_binds(); }
		},
		ajax_lock : 0
	}; 
})(jQuery);



/* jQuery begin document */
$(document).ready(function()
{

	// Set custom alert functionality
	window.alert = function (message) {
			// Check if message is already visible,
			// If yes, save current content and append
			if ( $('#message').is(':visible') ){
				// Remove first welcome message.
				if ( $('#msg_content').text().match(/Welcome/g) ){
					$('#msg_content').empty();
				}
				message += "<br/>" + $('#msg_content').html();
			}
			// Write
			$('#message').html(
					    '<div id="msg_content">'
					  + message
					  + '</div>'
					  + '<img id="message_close"'
					  + ' src="/static/images/close-gray.png"'
					  + ' class="hand_pointer"></img>')
				.slideDown(300);
			$('#message_close').click(function(){ $('#message').hide(300).empty(); });
			return false;
	};


	// Set up the navigation class
	slide("#sliding-navigation", 25, 15, 150, .8);

	// Set actions for clicks
	Ovpnc.actions.click_binds();	

	// display welcome message
	alert('Welcome!');

	$.getDATA = function(url) {
        	return jQuery.ajax({
        		headers: { 'Accept': 'application/json' },
		        async : false,
		        timeout: 3000,
		        tryCount : 0,
		        retryLimit : 3,
		        cache: false,
			    url: url,
				beforeSend : function(){ Ovpnc.ajax_lock = 1; },
				complete : function() { Ovpnc.ajax_lock = 0; },
		        success : function(r){
					$('#server_status').text('online').css('color','green');
					$('#server_on_off').attr('title', 'Shutdown OpenVPN server')
									   .attr('ref', 'on');
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
						$(".client_div").hide(250);
					}
					$('#client_status_container').html("<div id='no_data'>No data recieved, possible error: " + thrownError.toString() + "</div>").show(250);
					return false;
				}
			})
	};

	// Get status (loop)
	Ovpnc.actions.poll_status();
	
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
				$(".client_div").hide(300);
			}
			$('#client_status_container').html( '<div class="right_div client_div" id="no_clients">No clients connected</div>' );
			$('#no_clients').show(250);
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

function functionDelay(f,t)
{
	Ovpnc.timer = setTimeout(f, t);
}

function extend_client_data(n){
	
	// Before expending make sure ajax call is finished updating the div

/*	if ( checkPendingRequest() ){
		console.log( "sleep for 1 sec");
		functionDelay( extend_client_data(n), 1000 );
		return;
	}
	// If we got here, remove any active timers
	if ( typeof(Ovpnc.timer) !== "undefined") {
		clearInterval(Ovpnc.timer);
	}
*/
	if ( Ovpnc.ajax_lock === 1 ){
		console.log( "sleep for 1 sec");
        functionDelay( extend_client_data(n), 500 );
        return;
	}
	else {
		clearInterval(Ovpnc.timer);
	}

	if ( $('#' + n + '_hidden_data').is(':visible') ){
		$('#' + n + '_hidden_data').hide(250);
		$('#' + n + '_ext_status').html("<img src='/static/images/Alarm-Plus-icon.png'></img>");
	}
	else {
		$('#' + n + '_hidden_data').show(250);
		$('#' + n + '_ext_status').html("<img src='/static/images/Alarm-Minus-icon.png'></img>");
	}

}

function populate_version(s)
{
	$('#server_version').text( s ? s : '' );
}

function init_click_binds(){
	$('#server_on_off').click(function(){
		if ( $(this).attr('ref') === 'on' ){
			alert("This would shut the server down, still not implemented");
		}
		else {
			alert("This would power the server up, still not implemented");
		}
	});
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
		if ( ! $('#killed_clients').text().match(/\w+/) ) $('#killed_clients_container').hide(250);
		alert("Client '" + c + "' unkilled successfully");
		return true;		
	}).error(function(xhr, ajaxOptions, thrownError) {
		console.log("Error unkilling client '" + c + "': " + thrownError.toString());
		alert("Error unkilling client '" + c + "': " + thrownError.toString());
		return false;
	});

}

function append_dead_client(c){

	var now = get_date();
	var output = '<div class="unkill_me" id="unkill_' + c +'">'
				+ ' <b>' + c + '</b> killed ' + now
				+ ' <hr />'
                + ' <img style="float:right;margin-top:-2px"'
				+ '  class="client_action_link"'
				+ '  title="Click to unkill"'
				+ '  onClick="unkill_client(\'' + c +'\');"'
				+ '  src="/static/images/approve.png">' 
				+ ' </img>'
				+ '</div>';

	$('#killed_clients').append(output);

	if ( ! $('#killed_clients_container').is(":visible") ){
		$('#killed_clients_container').show(250);
		//Ovpnc.actions.hover_binds();
	}

}

// Check for pending ajax calls
function checkPendingRequest() {

	//console.log('Checking for pending ajax calls');

    if ( $.active > 0 ) {
        //console.log( $.active + " ajax call(s) still active");
        //window.setTimeout(checkPendingRequest, 1000); // run again
		return true;
    }
    else {
        //console.log("No pending ajax calls");
        return false;
    }

}

function get_date() { 
	var now = new Date(); 
	var then = now.getDay() + '-' + ( now.getMonth() + 1 ) + '-' + now.getFullYear()
			   + ' ' + now.getHours() + ':' +now.getMinutes() + ':' +now.getSeconds(); 
	return then;
} 
