/* jquery validator settings */
jQuery.validator.setDefaults({
    debug: true,
    success: "valid",
    messages: {
        username: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z0-9_]</div>",
        address: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z0-9\\-\\.\\(\\) ]</div>",
        certname: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z\\-\\.\\' ]</div>",
    },
    rules: {
        username: { test_regex: "([a-zA-Z0-9_]*)" },
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

	// Append to main namespace
	var temp_ns = $.Ovpnc();
	$.addCertificate = function(options){
        var obj = $.extend( {}, actions, items);
        return obj;
    };

	// New global vars:
	$.addCertificate.edit_manually = 0;
	$.addCertificate.form_modified = 0;
    $.addCertificate.pathname = window.location.pathname;
	$.addCertificate.html_mem = new Array();

	var items = new Object({
		elems : [ 'country', 'state', 'city' ],
        cookieData : {
            cookie_name: "Ovpnc_addCertificate_Form_Settings",
            path_name: $.addCertificate.pathname,
            modified: $.addCertificate.form_modified,
            expires: 14
        }
	});

    var actions = {
        //
        // Sets rules for form validation
        //
        setFormValidation: function(){
            $("#add_certificate_form").validate({
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
        },
        //
        // Edit manually (not via select land/state/city)
        //
        editManually: function (){
            if ( window.DEBUG ) console.log('Edit manually clicked');
            if ( $.addCertificate.edit_manually === 0 ){
                $.addCertificate.edit_manually = 1;
                // Save current select elements
                $('.r_auto').each(function(f,g){
                    $.addCertificate.html_mem.push(g);
                });
                $.addCertificate().buildLocationInputs();
                $.addCertificate().updateSelectRules();
                $.addCertificate().checkChanges();
                return;
            }
            else {
                $.addCertificate.edit_manually = 0;
                $.addCertificate().buildLocationSelects();
                $.addCertificate().updateSelectRules();
                $.addCertificate().checkChanges();
                return;
            }
        },        
        //
        // Sets bindings for click events
        // 
        setClickBind: function (){
            $.addCertificate().checkChanges();
        },
        //
        // Toggling from edit to select list
        // requires us to re-apply the rules
        //
        updateSelectRules: function(){
        	// Must run this to be
        	// able to use 'add'
            if ( window.DEBUG ) console.log( 'at updateSelectRules' );
        	$('#add_certificate_form').validate();
        	for (var i in $.addCertificate().elems){
        		//console.log(addCertificate.elems[i]);
        		$("#"+$.addCertificate().elems[i]).rules("add",{
        			maxlength: 48
        		});
        	}
        	if ($.addCertificate.edit_manually === 0){
        		for (var i in $.addCertificate().elems){
        			$("#"+$.addCertificate().elems[i]).rules("remove", "required rangelength");
        		}
        	}
        },
        //
        // Get the country name from a geoname id
        //
        getCountryNameFromId: function(geonameId){
             //console.log( 'get country id: ' + geonameId + ' with username ' + $.Ovpnc().geoUsername() );
             $.ajaxSetup({ async: true, cache: true });
             $.getJSON('http://api.geonames.org/childrenJSON', {
                geonameId: geonameId,
                maxRows : 1,
                username : $.Ovpnc().geoUsername()
             }, function( result ) {
                if ( result.geonames !== undefined && result.geonames.length > 0 ) {
                    $.addCertificate().setSelectCountryGeonameId(result.geonames[0].countryName);
                }
                else {
                    console.debug('Error getting country name '  + $.Ovpnc().geoUsername() );
                }
             }).error(function(xhr, ajaxOptions, thrownError) {
                console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString());
                return false;
            }).complete(function(){
                 $.ajaxSetup({ async: true, cache: false });
            });
        },
        //
        // Main function - init
        //
        certExecActions: function (){
        	$('#name').focus();
        	var cookie_data = new Object();
        	// Preload cookie
            if ( $.cookie( $.addCertificate().cookieData.cookie_name ) !== null ){
                cookie_data = jQuery.parseJSON( $.cookie( $.addCertificate().cookieData.cookie_name ) );
                if ( window.DEBUG ) console.log("Found cookie data: %o", cookie_data);
        		$.Forms().setFormFromCookie( cookie_data );
        	}
            else {
                console.log('No cookie data, fields to default state.');
            }
        	$.addCertificate().setSelectBind();
        	$.addCertificate().setClickBind();
            // First check if a country has already been set
            // by Catalyst FormFu, where 0 means not.
            // Also ignore if they have been set by the cookie
            var _selected = $("#country option:selected").attr('value');
            if ( _selected !== undefined
              && _selected != 0
            ){
                // We can get the state list,
                // since the country was already
                // set by Catalyst FormFu
                var _default_country = $("#country option:selected").attr('value');
                console.log('We got a default: ' + _default_country);
                $.addCertificate().getStateList( _default_country );
            }    
            // If no country has been set,
        	// load from the cookie.
        	else if ( cookie_data !== undefined && cookie_data.country !== undefined ){
        		$.Ovpnc.cookie = cookie_data;
        		//console.log("Found country in saved cookie: ", $.Ovpnc.cookie.country);
        		// If these are numbers, it is a geonameId
        		if ( ! isNaN(cookie_data.country) ){
        			$.addCertificate().getCountryNameFromId( cookie_data.country );
        		}
        		else {
        			// We got letters, this means that user
        			// inputed manually, therefore set to 
        			// manual editing and fill in values from cookie
        			$('#edit_manually').click();
        			$('#country').attr('value', cookie_data.country);
        			$('#state').attr('value', cookie_data.state);
        			$('#city').attr('value', cookie_data.city);
        		}
        	}				
        	else {
        		// Check user's location
        		// and set it as default
        		console.log( 'Setting default user location' );
                if ( $("#country option:selected").attr('value') == 0 ){
                    $("#country option:selected").remove();
                }
        		$.addCertificate().getUserGeolocation();
        	}

        	// Set form validation rules
        	$.addCertificate().setFormValidation();
        
        },
        //
        // Confirm leaving page
        // save state to cookie
        // [data, cookie_name, path_name, modified, expires]
        //
        confirmExit: function(){
            var p = $.addCertificate().cookieData;
            console.log("confirmExit got: %o",p);
            if ( p === undefined ) return true;
            if ( $.cookie( p.cookie_name ) !== null ){
                $.removeCookie( p.cookie_name );
            }
            if ( $.cookie( p.cookie_name ) !== null ){
                $.removeCookie( p.cookie_name );
            }
            // Set the cookie data
            var Settings = JSON.stringify({
                username: $('#username').attr('value'),
                certname: $('#certname').attr('value'),
                email: $('#email').attr('value'),
                country: $('#country').attr('value'),
                state: $('#state').attr('value'),
                city: $('#city').attr('value')
            });
/*
            $.cookie( p.cookie_name, Settings, {
                expires: p.expires ? p.expires : 30,
                path: p.path_name ? p.path_name : ''
            });
*/
            console.log('Cookie saved');

            // Warn user about changes [for debug only]
            //return "Unsaved modifications";
        },
        //
        // Set check changes on form fields
        // 
        checkChanges: function(){
            // Set focusout bind for all inputs 
            $('input').bind('focusout',function(e){
                $.addCertificate.form_modified = $.Ovpnc().setConfirmExit( $.addCertificate.form_modified, $.addCertificate().confirmExit );
            });
            $('select').change(function(){
                $.addCertificate.form_modified = $.Ovpnc().setConfirmExit( $.addCertificate.form_modified, $.addCertificate().confirmExit );
            });
        },
        //
        // Sets events for select changes
        //
        setSelectBind: function(){
        	$('select#country').change(function(){	
        		// Ajax loader
                $.addCertificate().stateAjaxLoader();
        		var geonameId = $("select#country option:selected").attr('value');
        		$.addCertificate().getStateList(geonameId);
        		$.addCertificate.form_modified = $.Ovpnc().setConfirmExit( $.addCertificate.form_modified, $.addCertificate().confirmExit );
        	});
        	$('select#state').change(function(){
        		// Ajax loader
                $.addCertificate().cityAjaxLoader();
        		var geonameId = $("select#state option:selected").attr('value');
        		$.addCertificate().getCityList( geonameId );
        		$.addCertificate.form_modified = $.Ovpnc().setConfirmExit( $.addCertificate.form_modified, $.addCertificate().confirmExit );
        	});
        },
        //
        // Set event handlers for the form 
        //
        setFormEvents: function(){
            // On form submission
            $('#submit_add_certificate_form').click(function(e){
                $.Ovpnc().setAjaxLoading(1);
                // Check password length and strength
                var _pw_length = $('input#password').attr('value');
                if ( _pw_length.length < 8 ) {
                    $('input#password').parent('div').find('span').remove();
                    $('input#password').parent('div').prepend('<span class="error_message error_constraint_required">Minimum 8 characters</span>');
                    $('input#password').parent('div').find('label').css('color','#8B0000');
                    $.Ovpnc().removeAjaxLoading();
                    return false;
                }
                // Don't submit if passwords don't match or weak
                var current = $('input#password2').attr('value');
                var first = $('input#password').attr('value');
                if ( ! $.Ovpnc().verifyPasswordsMatch(first, current, 'password2' ) ) return false;
                if ( $('.top_badPass').is(':visible') ) {
                    $('input#password').parent('div').find('span').remove();
                    $('input#password').parent('div').prepend('<span class="error_message error_constraint_required">Password is too weak!</span>');
                    $('input#password').parent('div').find('label').css('color','#8B0000');
                    $.Ovpnc().removeAjaxLoading();
                    return false;
                }
                $.Ovpnc().checkUsername();
                $.Ovpnc().checkPasswords();
                $.Ovpnc().checkEmail();
                $("#add_certificate_form").valid();
                var _wait =  setInterval(function() {
                    window.clearInterval(_wait);
                },
                1000 );
                if ( $('.error_message').is(':visible') || $('.client_error').is(':visible') ) {
                    $.Ovpnc().removeAjaxLoading();
                    return false;
                };

                // Remove the warnings message
                // when leaving this page
                window.onbeforeunload = undefined;

                // Save the current values
                // (data, cookie_name, path_name, modified, expires)
                $.addCertificate().confirmExit({
                    data: {
                        name : $('#name').attr('value'),
                        email : $('#email').attr('value'),
                        country : ( $.addCertificate.edit_manually ? $('#country').attr('value') : $("select#country option:selected").attr('value') ),
                        state :  ( $.addCertificate.edit_manually ? $('#state').attr('value') : $("select#state option:selected").attr('value') ),
                        city :   ( $.addCertificate.edit_manually ? $('#city').attr('value') : $("select#city option:selected").attr('value') ) 
                    },
                    cookie_name: "Ovpnc_addCertificate_Form_Settings",
                    path_name: $.addCertificate.pathname,
                    modified: $.addCertificate.form_modified,
                    expires: 14
                });
    
                /*
                $.Ovpnc().ajaxCall({
                    url: '/certificates/add',
                    data: $("form#add_client_form").serialize(),
                    method: 'POST',
                    success_func: $.addCertificate().return_certificate_add,
                    error_func: $.addCertificate().error_certificate_add,
                    loader: 1,
                    timeout: 15000
                });
                */
                //xxx
                return true;
            });
        },
        //
        // Get user's location from browser
        //
        getUserGeolocation: function(){
        	if ( navigator.geolocation ) {
        	    navigator.geolocation.getCurrentPosition(function(position) {
                    // Apply ajax loader
                    $.addCertificate().countryAjaxLoader();
                    // Exec ajax call
        		 	$.ajaxSetup({ async: true, cache: true });
        	        $.getJSON('http://ws.geonames.org/countryCode', {
        	            lat: position.coords.latitude,
        	            lng: position.coords.longitude,
        	            type: 'JSON'
        	        }, function( result ) {
        				$('#s_country').find('.ajaxLoader').remove();
        				console.log('CountryName: ' + result.countryName );
        				$.addCertificate().setSelectCountryGeonameId( result.countryName )		
        	        }).error(function(xhr, ajaxOptions, thrownError) {
        				if ( window.DEBUG ) console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
        				$('#s_country').find('.ajaxLoader').remove();
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
        },
        //
        // Build location select input
        //
        buildLocationSelects: function(){
        	var inn = $.addCertificate().elems;
            if ( window.DEBUG ) console.log("at buildLocationSelects: %o", $.addCertificate.html_mem );
            // Remove text inputs
            $.each( $('.oldSelect'), function(){
                $(this).removeClass('oldSelect')
                       .removeClass('text label')
                       .addClass('select label');
                $(this).children('input')
                       .remove();
            });
            // Replace with cached select lists
        	for ( var i in $.addCertificate.html_mem ){
        		$('#s_'+inn[i]).children('div').append( $.addCertificate.html_mem[i] );
        	}
        	$.addCertificate().setSelectBind();
        },
        //
        // Build location inputs
        //
        buildLocationInputs: function(){
            if ( window.DEBUG ) console.log( 'at buildLocationInputs' );
            // Get field names(country/state/city)
        	var inn = $.addCertificate().elems;
            // Remove the select fields
            $.each( $('.select'), function(){
                $(this).first('div')
                       .removeClass('select label')
                       .addClass('text label')
                       .addClass('oldSelect');
                $(this).children('select')
                       .remove();
            });
            // Replace with text inputs
        	for (var i in inn){
                var iDiv    = document.createElement('div'),
                    iElem   = document.createElement('input');
                $( iElem ).attr({
                    name: inn[i],
                    id: inn[i],
                    class: 'form_row',
                    placeholder: inn[i] + ' name'
                });
                $('#s_'+inn[i]).children('div').append( iElem );
            }
        },
        //
        // Populate the state select list
        //
        populateStates: function(states){
            for (var i=0;i<states.length;i++){
        		$('select#state').append('<option value="' + states[i].geonameId + '">' + states[i].name + '</option>' );		
        	}
        },
        //
        // Get list of the states
        //
        getStateList: function (geonameId){
            if ( window.DEBUG ) console.log( 'getStateList: ' + geonameId);
        	$.ajaxSetup({ async: true, cache: true  });
        	$.getJSON('http://api.geonames.org/childrenJSON', {
        			geonameId : geonameId,
        			username : $.Ovpnc().geoUsername()
        		}, function(o){
        		var states = o.geonames;		
        		// If list return empty, put a default option and return
        		if ( states === undefined || states.length === 0 ){
        			$('select#state').html('<option value="">-</option>');
        			// Remove ajax-loader
        			$('#s_state').find('.ajaxLoader').remove();	
        			return false;
        		}
        		// Empty previous list
        		$('select#state').empty();
    	    	// Append the options list
        		$.addCertificate().populateStates(states);
        		// Remove previous (state) ajax-loader
        		$('#s_state').find('.ajaxLoader').remove();	
        		if ( $.Ovpnc.cookie !== undefined && $.Ovpnc.cookie.state !== undefined && $.Ovpnc.cookie.state !== ''){
        			$("select#state option[value='" + $.Ovpnc.cookie.state + "']").prop('selected',true);
        		}
                var geoId = $("select#state option:selected").attr('value');
                // Add client ajax loader
                $.addCertificate().cityAjaxLoader();
        		// Update city list	
        		$.addCertificate().getCityList( geoId );
            }).error(function(xhr, ajaxOptions, thrownError) {
        		if ( window.DEBUG ) console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
        		// Remove ajax loader
        		$('#s_state').find('.ajaxLoader').remove();	
        		$('#s_city').find('.ajaxLoader').remove();	
        		return false;
        	}).complete(function(){
    	    	// Select state if it is found in cookie
        		if ( $.Ovpnc.cookie !== undefined && $.Ovpnc.cookie.state !== undefined && $.Ovpnc.cookie.state !== ''){
    	    		$("select#state option[value='" + $.Ovpnc.cookie.state + "']").prop('selected',true);
        		}
    	    	$.ajaxSetup({ async: true, cache: false  });
        	});
        },
        //
        // Add ajax loader near country select
        //
        countryAjaxLoader: function (){
            var tCountry = document.createElement('div');
            $(tCountry).css({
                float: 'right',
                margin: '-9px 3px 0 0'
            }).addClass('ajaxLoader');
            $('#s_country').find('.select.label').append( tCountry );
        },
        //
        // Add ajax loader near state select
        //
        stateAjaxLoader: function (){
            var tState = document.createElement('div');
            $(tState).css({
                float: 'right',
                margin: '3px 3px 0 0'
            }).addClass('ajaxLoader');
            $('#s_state').find('.select.label').append( tState );
        },
        //
        // Add ajax loader near city select
        //
        cityAjaxLoader: function (){
            var tCity = document.createElement('div');
            $(tCity).css({
                float: 'right',
                margin: '-9px 3px 0 0'
            }).addClass('ajaxLoader');
            $('#s_city').find('.select.label').append( tCity );
        },
        //
        // Get list of cities for this land
        //
        getCityList: function (geonameId){
        	$.getJSON('http://api.geonames.org/childrenJSON', {
                geonameId : geonameId,
                username : $.Ovpnc().geoUsername()
    		}, function(o){
	        	var cities = o.geonames;
		
        		// If list return empty, put a default option and return
		        if ( cities === undefined || cities.length === 0 ){
        			$('select#city').html('<option value="">-</option>');
        			// Remove ajax-loader
        			$('#s_city').find('.ajaxLoder').remove();		
        			return false;
        		}

        		// Empty previous list
        		$('select#city').empty();

        		// Append the options list
        		$.addCertificate().populateCities(cities);
		        // Remove ajax-loader
        		$('#s_city').find('.ajaxLoader').remove();		
        		// Select city if it is found in cookie
        		if ( $.Ovpnc.cookie !== undefined && $.Ovpnc.cookie.city !== undefined && $.Ovpnc.cookie.city !== ''){
        			//console.log( 'City is now '+$("select#city option:selected").attr('value') );
        			$("select#city option[value='" + $.Ovpnc.cookie.city + "']").prop('selected',true);
        			//console.log( 'City is now '+$("select#city option:selected").attr('value') );
        		}
        	}).error(function(xhr, ajaxOptions, thrownError) {
        		if ( window.DEBUG ) console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
        		// Remove ajax loader
        		$('#s_city').find('.ajaxLoader').remove();
        		return false;
        	}).complete(function(){
        		// Select city if it is found in cookie
        		if ( $.Ovpnc.cookie !== undefined && $.Ovpnc.cookie.city !== undefined && $.Ovpnc.cookie.city !== ''){
    	    		$("select#city option[value='" + $.Ovpnc.cookie.city + "']").prop('selected',true);
        		}
        	});
        },
        //
        // Populdate city select list
        //
        populateCities: function (cities){
        	for (var i=0;i<cities.length;i++){
        		$('select#city').append('<option value="' + cities[i].geonameId + '">' + cities[i].name + '</option>');		
        	}
        	$.Ovpnc().city_full = 1;
        },
        //
        // Provide a name and get a geonameId
        // will set the select option automatically
        //
        setSelectCountryGeonameId: function(country){
        	$.ajaxSetup({ async: true, cache: true });
        	$.getJSON('http://api.geonames.org/searchJSON', {
        		name: country,
        		maxRows : 1,
        		username : $.Ovpnc().geoUsername()
        	}, function( result ) {		
        		if ( result === undefined || result.geonames === undefined || result.geonames.length === 0){
        			$('select#country').html('<option value="">Please edit manually</option>');
        			console.log( "No country? %o" + result );
        			return false;
        		}
                // Append ajax loader for next select field (country)
                $.addCertificate().stateAjaxLoader();
        		$('select#country option').sort(NASort).appendTo('select#country');
        		$("select#country option[value='" + result.geonames[0].geonameId + "']").prop('selected',true);
        		$.addCertificate().getStateList( result.geonames[0].geonameId );
        		
        	}).error(function(xhr, ajaxOptions, thrownError) {
            	if ( window.DEBUG ) console.debug("Error getting JSON: " + xhr.status + ", " + thrownError.toString());
                return false;
            }).complete(function(){
        		 $.ajaxSetup({ async: true, cache: false });
        	});	
        }
    };	

})(jQuery);


// Document ready
$(document).ready(function(){
	$('#form_container').slideDown(600);
	$.addCertificate().certExecActions();
});

