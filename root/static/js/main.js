/*
 *
 * OpenVPN Controller JS lib
 *
 */
"use strict";

/* Declare Ovpnc namespace */
(function($){

	var mem, config, actions = {};

	// Create name space $.Ovpnc
	$.Ovpnc = function(options){
		var obj = $.extend({}, mem, actions, config, options);
		return obj;
	};

	$.Ovpnc.ajax_lock = 0;

	mem = {
		alert_icon : '<img width=18 height=18 src="/static/images/alert_icon.png" />',
		alert_ok : '<div style="float:left;"><img width=17 height=17 style="margin-top:-2px" src="/static/images/okay_icon.png" /></div>' 
				 + '<div style="float:left;margin:5px 0 0 6px;"></div>',
		alert_err : '<div style="float:left;"><img width=18 height=18 style="margin-top:-2px" src="/static/images/alert_icon.png" /></div>'
			  + '<div style="float:left;margin:5px 0 0 6px;"></div>',
	};
	config = {
		poll_freq : 10000, 			// Get server status from api every n milliseconds
		opacity_effect : 3000, 		// Sets the timing of the opacity fadein/out effect
		pathname : window.location.pathname,
		geo_username : function(){ return $('#geo_username').attr('name'); },
	};
	actions = {
		poll_status : function() { return init_loop_get_status(); },
		hover_binds : function() { return init_hover_binds(); },
		click_binds : function() { return init_click_binds(); }
	};


	// Global json get function
	$.getDATA = function(url) {
        	return jQuery.ajax({
        		headers: { 'Accept': 'application/json' },
		        async : false,
		        timeout: 3000,
		        tryCount : 0,
		        retryLimit : 3,
		        cache: false,
			    url: url,
				beforeSend : function(){ $.Ovpnc.ajax_lock = 1; },
				complete : function() { $.Ovpnc.ajax_lock = 0; },
		        success : update_server_status,
				error : function(xhr, ajaxOptions, thrownError) {
			        //console.debug("Error getting status: " + xhr.status + ", " + thrownError)
					this.tryCount++;
			        if (this.tryCount <= this.retryLimit) {
			            //console.log( "Going to retry connection to host loop: " + this.tryCount);
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


})(jQuery);



/* jQuery begin document */
$(document).ready(function(){

	// Todo: Split this large js file
	// to match controllers like clients.js
	// and certificates.js ...
	// That way no need to do this check here
	if ($.Ovpnc().pathname === '/login') return;

	// Set custom alert functionality
	window.alert = function (message) {
			//console.log('Alert called with ' + message);
			// Check if message is already visible,
			// If yes, save current content and append
			if ( $('#message').is(':visible') ){
				// Remove first welcome message.
				var old_content = $('#msg_content').html();
				//console.log('old: ' + old_content);
				old_content = old_content.replace('<br>','');
				if ( old_content.match(/Hello/g)
			  		|| old_content === message
				){
					$('#msg_content').empty();
				} else {
					message += "<br/>" + $('#msg_content').html();
				}
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


	// Set up the navigation class (not on login)
	// TODO: Control via Root controller so this can
	// optionally be include into other js files

	if ($.Ovpnc().pathname !== '/login')
		slide("#sliding-navigation", 25, 15, 150, .8);

	// Set actions for clicks
	$.Ovpnc().click_binds();	

	// display welcome message
	// Only on main screen
	// Or if never displayed before
	if ( $.cookie( 'Ovpnc_User_Settings' ) === null || $.Ovpnc().pathname === '/'){
		$.Ovpnc.username = ucfirst( $('#username').attr('name') );
		alert( $.Ovpnc().alert_ok + 'Hello ' + $.Ovpnc.username + ', welcome to OpenVPN Controller!' );
	}

	// clients.js will load own status
	if ( $.Ovpnc().pathname !== '/clients' ) {
		// Get status (loop)
		$.Ovpnc().poll_status();
	}
	
});


/*
	- Functions -
*/

function update_server_status(r){
	//console.log("Status returns: %o",r);
	// If we get status back, display
	if ( r.status !== undefined ){
		$('#server_status').text(r.status).css('color', r.status.match(/online/i) ? 'green' : 'gray' );
		$('#on_off_click_area').attr('title', ( r.status.match(/online/i) ? 'Shutdown' : 'Poweron' )  + ' OpenVPN server')
		$('#server_on_off').attr('ref', r.status.match(/online/i) ? 'on' : 'off' );
		// Show or dont show the green on icon
		$('#on_icon').css('opacity', ( r.status.match(/online/i) ? '1' : '0' ) );
	}
				
	// Show number of connected clients
	$('#online_clients_number').text( r.clients !== undefined ? r.clients.length : 0 );

	if ( r.clients !== undefined ){
		if (typeof(r.title) !== "undefined")
			populate_version(r.title);
		//if ( Ovpnc.pathname === '/clients' )
		//	populate_clients(r.clients);
	}

	return false;
}

function init_loop_get_status()
{

	// run first one
	get_server_status();

	// Then loop every n miliseconds
	setInterval(function() {
		get_server_status();
	}, $.Ovpnc().poll_freq );
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
		return;
	}
	else {
		// Clean up the no_clients div if it exists
		if ( $("#no_clients").is(":visible") ) 				$("#no_clients").hide();
		if ( $("#no_data").is(":visible") ) 				$("#no_data").hide();
		if ( $('#client_status_container').is(':hidden') ) 	$('#client_status_container').show();
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

			$.Ovpnc().tfc.in = client_obj['bytes_recv'];
			$.Ovpnc().tfc.out = client_obj['bytes_sent'];

			// for each client's data
			for (var obj in client_obj){
				if ( obj !== 'name' && !obj.match(/epoc_since|virtual_ip/) ) {

					// If numbers, add commas
					if ( ! isNaN(client_obj[obj]) && obj !== 'remote_port' )
						client_obj[obj] = numberWithCommas(client_obj[obj]);

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
			  		+ ' <div class="client_actions">'
					+ '  <div class="client_action_link" title="Kill client" style="float:right" id="' + client_obj['name'] + '_kill" onClick="kill_client(\'' + client_obj['name'] +'\');" >' 
					+ '   <img style="margin-top:-2px;" src="/static/images/kill_client.png" style="margin-top:-3px"></img></div>'
					+ '  </div>'
					+ '  <div class="client_action_link" title="Extend status" id="' + client_obj['name'] + '_ext_status" onClick="extend_client_data(\'' + client_obj['name'] + '\');" >'
					+ '   <img style="margin-top:-2px;" src="/static/images/arrow_down.png"></img>' 
					+ '  </div>'
					+ ' <div class="client_tfc" title="Bandwidth usage" id="in_out_' + client_obj['name'] + '"></div>'
					+ ' </div><!-- client_actions -->'
					+ '</div><!-- client_div --><div class="clear"></div><br><br>'
				);

				$('#client_name_' + client_obj['name']).show(500);
			}
			else {
				$("#data_client_name_" + client_obj["name"] ).html(output);
			}

			get_client_network_usage( client_obj['name'] );
		}
	}
}

function functionDelay(f,t)
{
	$.Ovpnc().timer = setTimeout(f, t);
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
	if ( $.Ovpnc.ajax_lock === 1 ){
		console.log( "sleep for 1 sec");
        functionDelay( extend_client_data(n), 500 );
        return;
	}
	else {
		clearInterval($.Ovpnc().timer);
	}

	if ( $('#' + n + '_hidden_data').is(':visible') ){
		$('#' + n + '_hidden_data').hide(250);
		$('#' + n + '_ext_status').html("<img src='/static/images/arrow_down.png'></img>")
								  .attr('title','Extend status');
	}
	else {
		$('#' + n + '_hidden_data').show(250);
		$('#' + n + '_ext_status').html("<img style='margin-left:-10px;' src='/static/images/arrow_up.png'></img>")
								  .attr('title','Hide status');
	}

}

function populate_version(s)
{
	$('#server_status_content').attr( 'title', s ? s : '' );
}

function init_click_binds(){

	$('#on_off_click_area').click(function(){
		server_on_off();
	});

}

function server_ajax_control(command){

	$.getJSON('/api/server/' + command, function(r){
		if ( r !== undefined && r.status !== undefined){

			console.log( "reply: %o", r.status);

			// Check returned /started/
            if ( command == 'start' ) {
				if ( r.status.match(/started/) ){
    	            alert( $.Ovpnc().alert_ok + r.status + " at " + get_date() + ".</div>" 
						+ '<div class="clear">'
					);
					$('#on_icon').animate({ opacity: 1 }, $.Ovpnc().opacity_effect );
					return;
				} else {
                	alert( 'Server did not start? ' + r.status );
					return;
    	        }
			// Check returned /stopped/
			} else if ( command == 'stop' ){
				if ( r.status.match(/stopped/) ){
					alert( $.Ovpnc().alert_err + "Server stopped at " + get_date() + ".</div>"
						+ '<div class="clear">'
					);
					$('#on_icon').animate({ opacity: 0 }, $.Ovpnc().opacity_effect );
					if ( $('#client_status_container').is(':visible') )
						$('#client_status_container').hide(300).empty();
					return;
				} else {
					alert( 'Server did not stop? ' + r.status );
					return
				}
			}
		}
		else {
			alert("Server control did not reply to action '" + command + "'");
			console.log("Server control did not reply");
			return false;
		}
	}).error(function(xhr, ajaxOptions, thrownError) {
        console.log("Error executing command " + + " server '" + c + "': " + thrownError.toString());
        alert( $.Ovpnc().error_icon + " Error executing command " + + " server '" + c + "': " + thrownError.toString());
        return false;
    });

}

function server_on_off(){
	// Turn off:
	if ( $('#server_on_off').attr('ref') == 'on' ){

		// Ask confirmation
		var cr = confirm("Are you sure you want to turn the server off?");
		if ( cr != true ) return;

		// Stop
		server_ajax_control('stop');
		return;
	} else {
		// Turn on:
		server_ajax_control('start');
		return;
	}
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

$.Ovpnc().okay_icon = '<img class="ok_icon" width=16 height=16 src="/static/images/okay_icon.png" />';
$.Ovpnc().error_icon = '<img class="err_icon" width=16 height=16 src="/static/images/error_icon.png" />';
function kill_client(c){

	$.getJSON('/api/server/kill/' + c, function(r){
		append_dead_client(c);
		alert($.Ovpnc().okay_icon + " Client '" + c + "' killed successfully.");
		return true;		
	}).error(function(xhr, ajaxOptions, thrownError) {
		console.log("Error killing client '" + c + "': " + thrownError.toString());
		alert( $.Ovpnc().error_icon + " Error killing client '" + c + "': " + thrownError.toString());
		return false;
	});

}

function unkill_client(c){

	$.getJSON('/api/server/unkill/' + c, function(r){
		$('#unkill_' + c).remove();
		if ( ! $('#killed_clients').text().match(/\w+/) ) $('#killed_clients_container').hide(250);
		alert($.Ovpnc().okay_icon + " Client '" + c + "' unkilled successfully");
		return true;		
	}).error(function(xhr, ajaxOptions, thrownError) {
		console.log("Error unkilling client '" + c + "': " + thrownError.toString());
		alert($.Ovpnc().error_icon + " Error unkilling client '" + c + "': " + thrownError.toString());
		return false;
	});

}

function append_dead_client(c){

	var now = get_date();
	var output = '<div class="unkill_me" id="unkill_' + c +'">'
				+ ' <b>' + c + '</b> killed ' + now
				+ '<hr />' 
                + ' <img style="float:right;margin-top:-2px"'
				+ '  class="client_action_link"'
				+ '  title="Click to unkill"'
				+ '  onClick="unkill_client(\'' + c +'\');"'
				+ '  src="/static/images/okay_icon.png">' 
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

$.Ovpnc().tfc = new Object();
$.Ovpnc().tfc = {
	in	: 0,
	out : 0,
	old_in : 0,
	old_out : 0
};

function get_client_network_usage( name ){

	//console.debug('In: ' + Ovpnc.tfc.in + ', Out: ' + Ovpnc.tfc.out );

	// Build client's traffic div container if it never existed
	// Here we record the values for next loop to pick them up
	// and calculate the delta
	if ( ! $('#tfc_' + name).is(':visible') ){
		//console.log( 'Build client traffic div first record for '  + name);

		// build for this client a traffic div
		$('#traffic').append('<div class="client_tfc" id="tfc_' + name + '"></div>');

		// Record the in/out packets, use as a starting point for delta calculation
		$('#tfc_'+name).html(
			'<input style="opacity:0" id="rec_in_'+name+'" value="' + $.Ovpnc().tfc.in + '" />'
		  + '<input style="opacity:0" id="rec_out_'+name+'" value="' + $.Ovpnc().tfc.out + '" />'
		);
		// This is the first loop because we created the 
		// tfc_+name div, second loop will already
		// see this div is created.
		return;
	}
	else {
		// If the tfc_+name is already created, get
		// the values (these have been recorded from the previous cycle)
		$.Ovpnc().tfc.old_in = $('#rec_in_' + name ).val();
		$.Ovpnc().tfc.old_out = $('#rec_out_' + name ).val();
		$('#rec_in_' + name ).val($.Ovpnc().tfc.in);
		$('#rec_out_' + name ).val($.Ovpnc().tfc.out);
	}

	var fixDeltaOut; var fixDeltaIn;

	if ( $.Ovpnc().tfc.old_in !== '' || $.Ovpnc().tfc.old_in !== 0 ){
		var real_deltaIn = $.Ovpnc().tfc.in - $.Ovpnc().tfc.old_in;
		var real_deltaOut= $.Ovpnc().tfc.out - $.Ovpnc().tfc.old_out;

		var bytes_in_avg = real_deltaIn / ( $.Ovpnc().poll_freq / 1000 );
		var bytes_out_avg = real_deltaOut / ( $.Ovpnc().poll_freq / 1000 );

		var output = '';		
		var in_setter = 'KB/s';
		var out_setter = 'KB/s';
		if ( bytes_in_avg > 0 ){
			var flDIn = bytes_in_avg / 1024;
			if ( flDIn > 1000 ){ in_setter = 'MB/s'; flDIn = flDIn / 1024; }
			fixDeltaIn = flDIn.toFixed(2);
			output += '<div style="float:left" id="tfc_in_' + name + '">' 
					+ '<img src="/static/images/red_down.png" />'
					+ '<span style="margin-left:3px;" id="inner_in_' + name + '">'
					+ fixDeltaIn 
					+ '</span>'
					+ '<span id="din_setter_'+name+'">' + in_setter + '</span>'
					+ '</div>';
		}
		if ( bytes_out_avg > 0){
			var flDOut = bytes_out_avg / 1024;
			if ( flDOut > 1000 ){ out_setter = 'MB/s'; flDOut = flDOut / 1024; }
			fixDeltaOut = flDOut.toFixed(2);
			output += '<div style="float:left;margin-left:5px;" id="tfc_out_' + name + '">'
					+ '<img src="/static/images/green_up.png" />'
					+ '<span style="margin-left:3px;" id="inner_out_' + name + '">'
					+ fixDeltaOut
					+ '</span>'
					+ '<span id="dout_setter_'+name+'">' + out_setter + '</span>'
					+ '</div>';
		}

		$.Ovpnc().tfc.old_in = $.Ovpnc().tfc.in;
		$.Ovpnc().tfc.old_out = $.Ovpnc().tfc.out;
		if ( $('#inner_in_'+name).is(':visible') && $('#inner_out_'+name).is(':visible') ){
			$('#inner_in_'+name).text(fixDeltaIn);
			$('#inner_out_'+name).text(fixDeltaOut);
			$('#din_setter_'+name).text(in_setter);
			$('#dout_setter_'+name).text(out_setter);
		}
		else {
			$('#in_out_' + name ).html( output );
		}
	}

}

function ucfirst(str) {
	var f = str.charAt(0).toUpperCase();
	return f + str.substr(1);
}       
