/* jquery validator settings */
/* jquery validator settings */
jQuery.validator.setDefaults({
    debug: true,
    success: "valid",
    messages: {
        username: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z0-9_]</div>",
        address: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z0-9\\-\\.\\(\\) ]</div>",
        certname: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z\\-\\.\\' ]</div>",
        phone: "<div style='margin-left:40px;'>Invalid input, allowed regex: [0-9\\-\\.\\(\\) ]</div>"
    },
    rules: {
        username: { test_regex: "([a-zA-Z0-9_]*)" },
        phone: { test_regex: "([0-9\-\.\(\) ]*)" },
        certname: { test_regex: "[a-zA-Z\-\'\. ]*" },
        address: { test_regex: "([a-zA-Z0-9\-\.\'\(\) ]*)" }
    },
    errorClass: "client_error",
    validClass: "valid",
    errorElement: "div",
    focusInvalid: true,
    errorContainer: $( [] ),
    errorLabelContainer: $( [] ),
    onsubmit: false,
    ignore: ":hidden",
    ignoreTitle: false
});

/* Ovpnc definitions */
(function($){

	items = new Object({
		elems : [ 'country', 'state', 'city' ],
	});


	// Append to main namespace
	var temp_ns = $.Ovpnc();
	$.addCertificate = function(options){
        var obj = $.extend( {}, actions, items);
        return obj;
    };

	// New global vars:
	$.addCertificate.edit_country = 0;
	$.addCertificate.form_modified = 0;
    $.addCertificate.pathname = window.location.pathname;
	$.addCertificate.html_mem = new Array();

    var actions = {
        //
        // Confirm leaving page
        //
        confirm_exit: function(){
        	if ( $.addCertificate.form_modified === 0 ) return true;

        	var data = {
        		name : $('#name').attr('value'),
        		email : $('#email').attr('value'),
        		country : ( $.addCertificate.edit_country ? $('#country').attr('value') : $("select#country option:selected").attr('value') ),
        		state :  ( $.addCertificate.edit_country ? $('#state').attr('value') : $("select#state option:selected").attr('value') ),
        		city :   ( $.addCertificate.edit_country ? $('#city').attr('value') : $("select#city option:selected").attr('value') )
        	}

        	if ( $.cookie( "Ovpnc_addCertificate_Form_Settings" ) !== null ){
        		$.removeCookie("Ovpnc_addCeritifcate_Form_Settings");
        	}
          	var Settings = JSON.stringify( data );
        	$.cookie( "Ovpnc_addCeritifcate_Form_Settings", Settings, { expires: 30, path: $.addCertificate.pathname } );
            return "Unsaved modifications";
        },
        //
        // Reset the form
        // 
        reset_form: function(form){
            $('input[type="text"]').each(function(k,v){ $(v).attr('value',''); });
            $('input[type="password"]').each(function(k,v){ $(v).attr('value',''); });
            $('.generated_password').remove()
            $('.error').remove()
            $('.error_message').remove();
            $('label').each(function(){ $(this).css('color','#000000'); });
        },
        //
        // Apply the validation rules onto the form
        //
        set_form_validation_rules: function(){
            $("#add_client_form").validate(
                $.addCertificate().validation_rules()
            );
        },
        //
        // The rules/constraints
        //
        validation_rules: function() {
            return {
                rules: {
                    username: {
                        required: true,
                        maxlength: 42,
                    },
                    password: {
                        required: true,
                        maxlength: 72
                    },
                    email: {
                        required: true,
                        maxlength: 72,
                        email: true
                    },
                    phone: {
                        required: true,
                        maxlength: 42
                    },
                    address: {
                        required: true,
                        maxlength: 128
                    }
                }
            }
        },
        //
        // Set event handlers for the form 
        //
        set_form_events: function(){

            // Set validation rules
            $.addCertificate().set_form_validation_rules();

            // Set keyup for all inputs
            $('input').bind('keyup',function(e){
                // Prevent submit by pressing enter
                if (e.which == 13) return false;
                // Remove previous warnings if any
                $(this).parent('div').find('span').remove();
                $(this).parent('div').find('label').css('color','#000000');
                $.addCertificate.form_modified = 1;
            });
            // On form submission
            $('#submit_add_certificate_form').click(function(e){
                e.preventDefault();
                $.Ovpnc().set_ajax_loading();
                // Check password length and strength
                var _pw_length = $('input#password').attr('value');
                if ( _pw_length.length < 8 ) {
                    $('input#password').parent('div').find('span').remove();
                    $('input#password').parent('div').prepend('<span class="error_message error_constraint_required">Minimum 8 characters</span>');
                    $('input#password').parent('div').find('label').css('color','#8B0000');
                    $.Ovpnc().remove_ajax_loading();
                    return false;
                }
                // Don't submit if passwords don't match or weak
                var current = $('input#password2').attr('value');
                var first = $('input#password').attr('value');
                if ( ! $.Ovpnc().verify_passwords_match(first, current, 'password2' ) ) return false;
                if ( $('.top_badPass').is(':visible') ) {
                    $('input#password').parent('div').find('span').remove();
                    $('input#password').parent('div').prepend('<span class="error_message error_constraint_required">Password is too weak!</span>');
                    $('input#password').parent('div').find('label').css('color','#8B0000');
                    $.Ovpnc().remove_ajax_loading();
                    return false;
                }
                $.addCertificate().check_username();
                $.addCertificate().check_passwords();
                $.addCertificate().check_email();
                $("#add_certificate_form").valid();
                var _wait =  setInterval(function() {
                    window.clearInterval(_wait);
                },
                1000 );
                if ( $('.error_message').is(':visible') || $('.client_error').is(':visible') ) {
                    $.Ovpnc().remove_ajax_loading();
                    return false;
                };

                // Remove the warnings message
                // when leaving this page
                window.onbeforeunload = undefined;

                // Save the current values
                $.addCertificate().confirm_exit();

                $.Ovpnc().ajax_call(
                    '/certificates/add',
                     $("form#add_client_form").serialize(),
                    'POST',
                    $.addCertificate().return_certificate_add,
                    $.addCertificate().error_certificate_add,
                    1,
                    15000
                );

            });
            $('input#username').bind('keyup',function(){
                $.addCertificate.form_modified = 1;
                $.addCertificate().check_username();
            });
            $('input#email').bind('keyup',function(){
                $.addClient.form_modified = 1;
                $.addClient().check_email();
            });
            $('input#password2').bind('keyup',function(){
                $.addClient.form_modified = 1;
                $.addClient().check_passwords();
            });
            $('#generate_password').bind('mousedown',function(){
                $('#generate_password').css('border','1px solid #999999').css('color','#555555');
            }).bind('mouseup',function(){
                $('#generate_password').css('border','').css('color','#000000');
            });

        }
    };	
})(jQuery);


// Document ready
$(document).ready(function(){
	$('#form_container').slideDown(600);
	cert_exec_actions();

});

// Main function
function cert_exec_actions(){

	$('#name').focus();

	var cookie_data = new Object();

	// Preload cookie
	if ( $.cookie("Ovpnc_addCeritifcate_Form_Settings") !== null ){
		cookie_data = jQuery.parseJSON( $.cookie("Ovpnc_addCeritifcate_Form_Settings") );
		set_form_from_cookie( cookie_data );
	}

	set_select_bind();
	set_click_bind();

    // First check if a country has already been set
    // by Catalyst FormFu, where 0 means not.
    if ( $("#country option:selected").attr('value').match(/\d+/)
      && $("#country option:selected").attr('value') > 0
    ) {
        // We can get the state list,
        // since the country was already
        // set by Catalyst FormFu
        console.log('We got a default: ' + $("#country option:selected").attr('value'));
        get_state_list( $("#country option:selected").attr('value') );
    }    
    // If no country has been set,
	// load from the cookie.
	else if ( cookie_data !== undefined && cookie_data.country !== undefined ){
		$.Ovpnc.cookie = cookie_data;
		//console.log("Found country in saved cookie: ", $.Ovpnc.cookie.country);
		// If these are numbers, it is a geonameId
		if ( ! isNaN(cookie_data.country) ){
			get_country_name_from_id( cookie_data.country );
		}
		else {
			// We got letters, this means that user
			// inputed manually, therefore set to 
			// manual editing and fill in values from cookie
			$('#edit_country').click();
			$('#country').attr('value', cookie_data.country);
			$('#state').attr('value', cookie_data.state);
			$('#city').attr('value', cookie_data.city);
		}
	}				
	else {
		// Check user's location
		// and set it as default
		//console.log( 'Setting default user location' );
		get_user_geolocation();
	}

	// Set form validation rules
	set_form_validation();

}

// Set the input fields
// from the cookie
function set_form_from_cookie(data){

    if ( data !== undefined ){
        if ( data.name !== '' ){
            $('#name').attr('value', data.name);
        }
        if ( data.email !== '' ){
            $('#data').attr('value', data.email);
        }
    }

}

function set_confirm_exit(){

	if (  $.addCertificate.form_modified === 0 ) {
		//console.log('Set check saved config');
		$.addCertificate.form_modified = 1;
		// On window unload
		window.onbeforeunload = $.addCertificate().confirm_exit;
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

	for (var i in $.Ovpnc().elems){
		//console.log(Ovpnc.elems[i]);
		$("#"+$.Ovpnc().elems[i]).rules("add",{
			maxlength: 48
		});
	}

	if ($.addCertificate.edit_country === 0){
		for (var i in $.Ovpnc().elems){
			$("#"+$.Ovpnc().elems[i]).rules("remove", "required rangelength");
		}
	}

}

function set_click_bind(){

	if(typeof(events) !== "function"){
		$('#edit_country').click(function(){
			if ( $.addCertificate.edit_country === 0 ){
				$.addCertificate.edit_country = 1;
	
				$('.r_auto').each(function(f,g){
					$.addCertificate.html_mem.push(g);
				});
				build_location_inputs();
				update_select_rules();
				check_changes();
				return;
			}
	 		else {
				$.addCertificate.edit_country = 0;
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
		//console.log('input detected');
		set_confirm_exit();
	});
	$('select').change(function(){
		//console.log('change detected');
		set_confirm_exit();
	});
}

function build_location_selects(){
	var inn = $.Ovpnc().elems;
	for ( var i in $.addCertificate.html_mem ){
		$('#s_' + inn[i]).html( $.addCertificate.html_mem[i] );
	}
	set_select_bind();
}

function build_location_inputs(){
	var inn = $.Ovpnc().elems;
	for (var i in inn){
		$('#s_' + inn[i]).html(
			'<input name="'+inn[i]+'" id="'+inn[i]+'" placeholder="'+inn[i]+' name" />'
		);
	}
}

function set_select_bind(){

	$('select#country').change(function(){	
		// Ajax loader
		$('#t_state').html( $.Ovpnc().ajax_loader );	
		var geonameId = $("select#country option:selected").attr('value');
		get_state_list( geonameId );
		set_confirm_exit();
	});

	$('select#state').change(function(){
		// Ajax loader
		$('#t_city').html( $.Ovpnc().ajax_loader );
		var geonameId = $("select#state option:selected").attr('value');
		get_city_list( geonameId );
		set_confirm_exit();
	});

}

function get_state_list( geonameId ){
	$.ajaxSetup({ async: true, cache: true  });
	$.getJSON('http://api.geonames.org/childrenJSON', {
			geonameId : geonameId,
			username : $.Ovpnc().geo_username()
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

		if ( $.Ovpnc.cookie !== undefined && $.Ovpnc.cookie.state !== undefined && $.Ovpnc.cookie.state !== ''){
			$("select#state option[value='" + $.Ovpnc.cookie.state + "']").prop('selected',true);
		}

		var geoId = $("select#state option:selected").attr('value');
		// Update city list	
		$('#t_city').html( $.Ovpnc().ajax_loader );
		get_city_list( geoId );

	}).error(function(xhr, ajaxOptions, thrownError) {
		console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
		// Remove ajax loader
		$('#t_state').empty();	
		return false;
	}).complete(function(){
		// Select state if it is found in cookie
		if ( $.Ovpnc.cookie !== undefined && $.Ovpnc.cookie.state !== undefined && $.Ovpnc.cookie.state !== ''){
			$("select#state option[value='" + $.Ovpnc.cookie.state + "']").prop('selected',true);
		}
		$.ajaxSetup({ async: true, cache: false  });
	});
}


function get_city_list( geonameId ){

	$.getJSON('http://api.geonames.org/childrenJSON', {
			geonameId : geonameId,
			username : $.Ovpnc().geo_username()
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
		if ( $.Ovpnc.cookie !== undefined && $.Ovpnc.cookie.city !== undefined && $.Ovpnc.cookie.city !== ''){
			//console.log( 'City is now '+$("select#city option:selected").attr('value') );
			$("select#city option[value='" + $.Ovpnc.cookie.city + "']").prop('selected',true);
			//console.log( 'City is now '+$("select#city option:selected").attr('value') );
		}



	}).error(function(xhr, ajaxOptions, thrownError) {
		console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
		// Remove ajax loader
		$('#t_city').empty();	
		return false;
	}).complete(function(){

		// Select city if it is found in cookie
		if ( $.Ovpnc.cookie !== undefined && $.Ovpnc.cookie.city !== undefined && $.Ovpnc.cookie.city !== ''){
			$("select#city option[value='" + $.Ovpnc.cookie.city + "']").prop('selected',true);
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
	$.Ovpnc().city_full = 1;
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
			$('#t_country').html( $.Ovpnc().ajax_loader );	
		 	$.ajaxSetup({ async: true, cache: true });
	        $.getJSON('http://ws.geonames.org/countryCode', {
	            lat: position.coords.latitude,
	            lng: position.coords.longitude,
	            type: 'JSON'
	        }, function( result ) {

				$('#t_country').empty();
				//console.log('CountryName: ' + result.countryName );
				set_select_country_geonameId( result.countryName )		

	        }).error(function(xhr, ajaxOptions, thrownError) {
				console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
				$('#t_country').empty();
				return false;
		    }).complete(function(){
		 		$.ajaxSetup({ async: true, cache: false });
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
	$.ajaxSetup({ async: true, cache: true });
	$.getJSON('http://api.geonames.org/searchJSON', {
		name: country,
		maxRows : 1,
		username : $.Ovpnc().geo_username()
	}, function( result ) {		

		if ( result === undefined || result.geonames === undefined || result.geonames.length === 0){
			$('select#country').html('<option value="">Please edit manually</option>');
			console.log( "No country? %o" + result );
			return false;
		}

		$('#t_state').html( $.Ovpnc().ajax_loader );
		$('select#country option').sort(NASort).appendTo('select#country');
		$("select#country option[value='" + result.geonames[0].geonameId + "']").prop('selected',true);
		get_state_list( result.geonames[0].geonameId );
		
	}).error(function(xhr, ajaxOptions, thrownError) {
    	console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString());
        return false;
    }).complete(function(){
		 $.ajaxSetup({ async: true, cache: false });
	});	
}

function get_country_name_from_id( geonameId ){

	 //console.log( 'get country id: ' + geonameId + ' with username ' + $.Ovpnc().geo_username() );

	 $.ajaxSetup({ async: true, cache: true });
	 $.getJSON('http://api.geonames.org/childrenJSON', {
        geonameId: geonameId,
        maxRows : 1,
        username : $.Ovpnc().geo_username()
     }, function( result ) {
		if ( result.geonames !== undefined && result.geonames.length > 0 ) {
			set_select_country_geonameId(result.geonames[0].countryName);
		}
		else {
			console.debug('Error getting country name '  + $.Ovpnc().geo_username() );
		}
     }).error(function(xhr, ajaxOptions, thrownError) {
        console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString());
        return false;
    }).complete(function(){
		 $.ajaxSetup({ async: true, cache: false });
	});
}
