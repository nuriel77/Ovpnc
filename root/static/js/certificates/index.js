jQuery.validator.setDefaults({
	debug: true,
	success: "valid"
});

/*

ovpnc definitions

*/
var ovpnc = new Object();
ovpnc.ajax_lock = 0;
ovpnc.ajax_loader = '<img src="/static/images/ajax-loader.gif"></img>';
ovpnc.edit_country = 0;
ovpnc.elems = new Array ('country', 'state', 'city');
ovpnc.html_mem = new Array();
ovpnc.form_modified = 0;

/* jQuery begin document */
$(document).ready(function()
{
	
	$.ajaxSetup({
		async: true, cache: true
	});

	ovpnc.geo_username = $('#geo_username').attr('value');

	// Preload cookie
	if ( $.cookie('Ovpnc_Form_Settings') !== null ){
		//console.log('Found user settings cookie');
		ovpnc.cookie = jQuery.parseJSON( $.cookie('Ovpnc_Form_Settings') );
	}

	set_form_from_cookie();
	set_select_bind();
	set_click_bind();

	// If we saved the previous fields in a 
	// cookie, load from the cookie.
	if ( ( ovpnc.cookie !== undefined ) ){
		//console.log("Found country in saved cookie: ",ovpnc.cookie.country);
		// If these are numbers, it is a geonameId
		if ( ! isNaN(ovpnc.cookie.country) ){
			get_country_name_from_id( ovpnc.cookie.country );
		}
		else {
			// We got letters, this means that user
			// inputed manually, therefore set to 
			// manual editing and fill in values from cookie
			$('#edit_country').click();
			$('#country').attr('value', ovpnc.cookie.country);
			$('#state').attr('value', ovpnc.cookie.state);
			$('#city').attr('value', ovpnc.cookie.city);
		}
	}				
	else {
		// Check user's location
		// and set it as default
		get_user_geolocation();
	}

	// Set form validation rules
	set_form_validation();

});

function set_confirm_exit(){

	if (  ovpnc.form_modified === 0 ) {
		//console.log('Set check saved config');
		ovpnc.form_modified = 1;

		// On window unload
		window.onbeforeunload = confirmExit;
	}
}

// Set the input fields
// from the cookie
function set_form_from_cookie(){
	if ( typeof(ovpnc.cookie) !== "undefined" ){
		var data = ovpnc.cookie;
		if ( data.name !== '' ){
			$('#name').attr('value', data.name);
		}
		if ( data.email !== '' ){
			$('#data').attr('value', data.email);
		}
	}
}

// Sets rules for form validation
function set_form_validation(){

	// Form validation rules
	$("#main_form").validate({
	 	rules: {
		    email: {
		    	required: true,
				maxlength: 42,
	      		email: true
			},
			name: {
				required: true,
				maxlength: 42
			},
			country : { required: true },
			state : { required: true },
			city : { required: true }
	    }
	});

}

function update_select_rules(){

	// Must run this to be
	// able to use 'add'
	$('#main_form').validate();

	for (var i in ovpnc.elems){
		//console.log(ovpnc.elems[i]);
		$("#"+ovpnc.elems[i]).rules("add",{
			maxlength: 48
		});
	}

	if (ovpnc.edit_country === 0){
		for (var i in ovpnc.elems){
			$("#"+ovpnc.elems[i]).rules("remove", "required rangelength");
		}
	}

}

function confirmExit(){

	if ( ovpnc.form_modified === 0 ) return true;

	var data = new Object();

	data = {
		name : $('#name').attr('value'),
		email : $('#email').attr('value'),
		country : ( ovpnc.edit_country ? $('#country').attr('value') : $("select#country option:selected").attr('value') ),
		state :  ( ovpnc.edit_country ? $('#state').attr('value') : $("select#state option:selected").attr('value') ),
		city :   ( ovpnc.edit_country ? $('#city').attr('value') : $("select#city option:selected").attr('value') )
	}

	if ( $.cookie( "Ovpnc_Form_Settings" ) !== null ){
		console.log('removed old cookie');
		$.removeCookie("Ovpnc_Form_Settings");
	}
	var Settings = JSON.stringify( data );
	$.cookie( "Ovpnc_Form_Settings", Settings, { expires: 30, path: '/' } );

    return "Unsaved modifications";
}

function set_click_bind(){

	if(typeof(events) !== "function"){
		$('#edit_country').click(function(){
			if ( ovpnc.edit_country === 0 ){
				ovpnc.edit_country = 1;
	
				$('.r_auto').each(function(f,g){
					ovpnc.html_mem.push(g);
				});
				build_location_inputs();
				update_select_rules();
				check_changes();
				return;
			}
	 		else {
				ovpnc.edit_country = 0;
				build_location_selects();
				update_select_rules();
				check_changes();
				return;
			}
		});
	}
	check_changes();
}

function NASort(a, b) {    
    if (a.innerHTML == 'NA') {
        return 1;   
    }
    else if (b.innerHTML == 'NA') {
        return -1;   
    }       
    return (a.innerHTML > b.innerHTML) ? 1 : -1;
};

function check_changes(){
	$('input').bind('keyup',function(){
		console.log('input detected');
		set_confirm_exit();
	});
	$('select').change(function(){
		console.log('change detected');
		set_confirm_exit();
	});
}

function build_location_selects(){
	var inn = ovpnc.elems;
	for ( var i in ovpnc.html_mem ){
		$('#s_' + inn[i]).html( ovpnc.html_mem[i] );
	}
	set_select_bind();
}

function build_location_inputs(){
	var inn = ovpnc.elems;
	for (var i in inn){
		$('#s_' + inn[i]).html(
			'<input name="'+inn[i]+'" id="'+inn[i]+'" placeholder="'+inn[i]+' name" />'
		);
	}
}

function set_select_bind(){

	$('select#country').change(function(){	
		// Ajax loader
		$('#t_state').html( ovpnc.ajax_loader );	
		var geonameId = $("select#country option:selected").attr('value');
		get_state_list( geonameId );
		set_confirm_exit();
	});

	$('select#state').change(function(){
		// Ajax loader
		$('#t_city').html( ovpnc.ajax_loader );
		var geonameId = $("select#state option:selected").attr('value');
		get_city_list( geonameId );
		set_confirm_exit();
	});

}

function get_state_list(geonameId){

	$.getJSON('http://api.geonames.org/childrenJSON', {
			geonameId : geonameId,
			username : ovpnc.geo_username
		}, function(o){
		var states = o.geonames;
		
		// If list return empty, put a default option and return
		if ( states === undefined || states.length === 0 ){
			$('select#state').html('<option value="">-</option>');
			// Remove ajax-loader
			$('#t_state').empty();	
			return false;
		}

		// Empty previous list
		$('select#state').empty();

		// Append the options list
		populate_states(states);

		// Remove ajax-loader
		$('#t_state').empty();	

		if ( ovpnc.cookie !== undefined && ovpnc.cookie.state !== undefined && ovpnc.cookie.state !== ''){
			$("select#state option[value='" + ovpnc.cookie.state + "']").prop('selected',true);
		}

		var geoId = $("select#state option:selected").attr('value');
		// Update city list	
		$('#t_city').html( ovpnc.ajax_loader );
		get_city_list( geoId );

	}).error(function(xhr, ajaxOptions, thrownError) {
		console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
		// Remove ajax loader
		$('#t_state').empty();	
		return false;
	}).complete(function(){
		// Select state if it is found in cookie
		if ( ovpnc.cookie !== undefined && ovpnc.cookie.state !== undefined && ovpnc.cookie.state !== ''){
			$("select#state option[value='" + ovpnc.cookie.state + "']").prop('selected',true);
		}

	});
}


function get_city_list( geonameId ){

	$.getJSON('http://api.geonames.org/childrenJSON', {
			geonameId : geonameId,
			username : ovpnc.geo_username		
		}, function(o){
		var cities = o.geonames;
		
		// If list return empty, put a default option and return
		if ( cities === undefined || cities.length === 0 ){
			$('select#city').html('<option value="">-</option>');
			// Remove ajax-loader
			$('#t_city').empty();		
			return false;
		}

		// Empty previous list
		$('select#city').empty();

		// Append the options list
		populate_cities(cities);

		// Remove ajax-loader
		$('#t_city').empty();		

		// Select city if it is found in cookie
		if ( ovpnc.cookie !== undefined && ovpnc.cookie.city !== undefined && ovpnc.cookie.city !== ''){
			//console.log( 'City is now '+$("select#city option:selected").attr('value') );
			$("select#city option[value='" + ovpnc.cookie.city + "']").prop('selected',true);
			//console.log( 'City is now '+$("select#city option:selected").attr('value') );
		}



	}).error(function(xhr, ajaxOptions, thrownError) {
		console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
		// Remove ajax loader
		$('#t_city').empty();	
		return false;
	}).complete(function(){

		// Select city if it is found in cookie
		if ( ovpnc.cookie !== undefined && ovpnc.cookie.city !== undefined && ovpnc.cookie.city !== ''){
			$("select#city option[value='" + ovpnc.cookie.city + "']").prop('selected',true);
		}

	});
}

function populate_cities(cities){
	for (var i=0;i<cities.length;i++){
		$('select#city').append(
			'<option value="' + cities[i].geonameId + '">'
		  + cities[i].name
		  + '</option>'
		);		
	}
	ovpnc.city_full = 1;
}

function populate_states(states){
	for (var i=0;i<states.length;i++){
		$('select#state').append(
			'<option value="' + states[i].geonameId + '">'
		  + states[i].name
		  + '</option>'
		);		
	}
}

function get_user_geolocation(){

	if ( navigator.geolocation ) {
	    navigator.geolocation.getCurrentPosition(function(position) {
			$('#t_country').html( ovpnc.ajax_loader );	
	        $.getJSON('http://ws.geonames.org/countryCode', {
	            lat: position.coords.latitude,
	            lng: position.coords.longitude,
	            type: 'JSON'
	        }, function( result ) {

				$('#t_country').empty();
				set_select_country_geonameId( result.countryName )		

	        }).error(function(xhr, ajaxOptions, thrownError) {
				console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
				$('#t_country').empty();
				return false;
		    })
		})
	}
	else {
		console.log( "Failed to get the navigator geolocation, cannot set default country" );
		return false;
	}
}

// Provide a name and get a geonameId
// will set the select option automatically
function set_select_country_geonameId( country ){
	$.getJSON('http://api.geonames.org/searchJSON', {
		name: country,
		maxRows : 1,
		username : ovpnc.geo_username
	}, function( result ) {		

		if ( result === undefined || result.geonames === undefined || result.geonames.length === 0){
			$('select#country').html('<option value="">Please edit manually</option>');
			return false;
		}

		$('#t_state').html( ovpnc.ajax_loader );
		$('select#country option').sort(NASort).appendTo('select#country');
		$("select#country option[value='" + result.geonames[0].geonameId + "']").prop('selected',true);
		get_state_list( result.geonames[0].geonameId );
		
	}).error(function(xhr, ajaxOptions, thrownError) {
    	console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString());
        return false;
    });	
}

function get_country_name_from_id( geonameId ){

	 $.getJSON('http://api.geonames.org/childrenJSON', {
        geonameId: geonameId,
        maxRows : 1,
        username : ovpnc.geo_username
    }, function( result ) {
		if ( result.geonames !== undefined && result.geonames.length > 0 ) {
			set_select_country_geonameId(result.geonames[0].countryName);
		}
		else {
			console.debug('Error getting country name');
		}
    }).error(function(xhr, ajaxOptions, thrownError) {
        console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString());
        return false;
    });
}
