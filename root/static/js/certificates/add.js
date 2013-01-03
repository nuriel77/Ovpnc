/* jquery validator settings */
jQuery.validator.setDefaults({
    debug: true,
    success: "valid",
    messages: {
        username: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z0-9_]</div>",
        address: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z0-9\\-\\.\\(\\) ]</div>",
        cert_name: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z\\-\\.\\' ]</div>",
    },
    rules: {
        username: { test_regex: "([a-zA-Z0-9_]*)" },
        cert_name: { test_regex: "[a-zA-Z\-\'\. ]*" },
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
    $.addCertificate.users = new Array();
	$.addCertificate.html_mem = new Array();
	$.addCertificate.html_mem_username = new Array();

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
        			username: {
        				required: true,
        				maxlength: 42
        			},
        			cert_name: {
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
            if ( window.DEBUG ) log('Edit manually clicked');
            if ( $.addCertificate.edit_manually === 0 ){
                $('#edit_manually').attr('title', 'Use select list');
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
                $('#edit_manually').attr('title', 'Edit manually');
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
            // Set click on label of radiobutton (choose)
            $.each( $('.radiogroup').find('input[name=cert_type],label'), function(){
                $(this).bind('click', function(){
                    $('.radiogroup').find('input').removeAttr('checked');
                    $('.simpletable').find('label').css('color','#000000');     
                    $(this).parent('span')
                           .find('input')
                           .attr('checked','checked');
                    // Once we get a click, check
                    // the certificate type so we
                    // display or hide certain fields
                    // and/or run backend checks
                    $.addCertificate().checkCertType(
                        $('input[name=cert_type]:checked', '#add_certificate_form').val()
                    );
                }).hover(function(){
                    $(this).css('text-shadow','1px 1px #dddddd');
                }, function(){
                    $(this).css('text-shadow','none');
                });
            });

            // Run a check on certificate name
            //( url, data, method, success_func, error_func, loader, timeout, retries, cache )
            $('#cert_name').bind('focusout',function(){
                // We require user name as well for the 
                // path of the user's certificates
                if ( $('#username').attr('value').match(/\w+/)
                  || $('#certtype').attr('value') === 'ca'
                  
                ){
                    if ( ! $('#cert_name').attr('value').match(/\w/) ) return false;
                    $.Ovpnc().ajaxCall({
                        url: "/api/certificates",
                        data: {
                            cert_name: $('#cert_name').attr('value'),
                            name: $('#username').attr('value'),
                            type: $('#certtype').attr('value'),
                            action: 'usage'
                        },
                        method: 'GET',
                        success_func: $.addCertificate().ajaxCheckCertSuccess,
                        error_func: $.addCertificate().ajaxCheckCertError
                    });
                }
            });

            $('#username').bind('focusout',function(){
                if ( $('#username').attr('value') != ''
                  && ! $('#certtype').attr('value').match(/server|ca/)
                ){
                    $.Ovpnc().ajaxCall({
                        url: "/api/clients",
                        data: {
                            search: $(this).attr('value'),
                            field: 'username',
                            rows: 12,
                            db: 'user'
                        },
                        method: 'GET',
                        success_func: $.addCertificate().ajaxCheckUsernameSuccess,
                        error_func: $.addCertificate().ajaxCheckUsernameError
                    });
                }
            });
        },
        //
        //
        //
        ajaxCheckUsernameSuccess: function (d){
            if ( window.DEBUG ) log ("Check username returns: %o", d );
            var _err = 0;
            // We make sure this client name
            // exists, user must choose an 
            // existing user from the list
            if ( d.rest.resultset !== undefined ){
                if ( Object.prototype.toString.call( d.rest.resultset ) === '[object Array]' ){
                    if ( d.rest.resultset.length > 1 ){
                        _err++;
                    }
                }
                else {
                    if ( d.rest.resultset !== $('input#username').attr('value') ){
                        _err++;
                    }
                }
                if ( _err != 0 ) {
                    var elem = document.createElement('span');
                    $( elem ).addClass('error_message error_constraint_required')
                             .text('Choose an existing user');
                    $('input#username').parent('div').find('span').remove();
                    $('input#username').parent('div').find('label').css('color','#8B0000');
                    $('#username').parent('div').prepend( elem );
                }

            }
        },
        //
        //
        //
        ajaxCheckUsernameError: function (e){
            if ( window.DEBUG ) log ("Check username error returns: %o", e );
            if ( e.responseText ){
                var _msg = jQuery.parseJSON(e.responseText);
                if ( window.DEBUG ) log ('Certificate name exists');
                $('#cert_name').parent('div').find('label')
                              .css('color','#8B0000');
                var elem   = document.createElement('span');
                $( elem ).addClass('passwd_err error_message error_constraint_required')
                         .css('margin','4px 0 0 305px')
                         .text('Certificate name exists!');
                $('#cert_name').parent('div').children('.passwd_err').remove();
                $('#cert_name').parent('div').append( elem );
            }
        },
        //
        // Success - no such cert name
        // returned from ajaxcall
        // 
        ajaxCheckCertSuccess: function (d){
            if ( window.DEBUG ) log("ajaxCheckCertSuccess: %o",d);
            if ( d.rest && d.rest.locked && d.rest.locked == 1 ){
                window.locked_ca = 1;
                return;
            }
            window.locked_ca = undefined;
        },
        //
        // Success - no such cert name
        // returned from ajaxcall
        // 
        ajaxCheckCertError: function (e){
            if ( e.responseText ){
                var _msg = jQuery.parseJSON(e.responseText);
                if ( _msg.rest && _msg.rest.status === 'Certificate exists' ){
                    if ( window.DEBUG ) log ("Certificate name exists: %o", _msg);
                    $('#cert_name').parent('div').find('label')
                                  .css('color','#8B0000');
                    var elem   = document.createElement('span');
                    $( elem ).addClass('passwd_err error_message error_constraint_required')
                             .css('margin','4px 0 0 305px')
                             .text('Certificate name exists!');
                    $('#cert_name').parent('div').children('.passwd_err').remove();
                    $('#cert_name').parent('div').append( elem );
                }
                if ( _msg.rest && _msg.rest.locked === 1 ){
                    if ( window.DEBUG ) log ('CA is locked');
                    window.locked_ca = 1;
                    return;
                }
                window.locked_ca = undefined;
            }
        },        
        //
        // Toggling from edit to select list
        // requires us to re-apply the rules
        //
        updateSelectRules: function(){
        	// Must run this to be
        	// able to use 'add'
            if ( window.DEBUG ) log( 'at updateSelectRules' );
        	$('#add_certificate_form').validate();
        	for (var i in $.addCertificate().elems){
        		if ( window.DEBUG ) log( $.addCertificate().elems[i] );
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
             if ( window.DEBUG ) log( 'get country id: ' + geonameId + ' with username ' + $.Ovpnc().geoUsername() );
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
                   log ('Error getting country name '  + $.Ovpnc().geoUsername() );
                }
             }).error(function(xhr, ajaxOptions, thrownError) {
                log ("Error getting JSON: " + xhr.status + ", " + thrownError.toString());
                return false;
            }).complete(function(){
                 $.ajaxSetup({ async: true, cache: false });
            });
        },
        //
        // Check the chosen certificat type, act accordingly
        //
        checkCertType: function (cType){
            if ( window.DEBUG ) log ( 'got cert_type: ' + cType );
            $('.error_message').remove();
            if ( $('#cert_name').attr('value') != '' ){
                $('#cert_name').focusout();
            }


            $('#certtype').attr('value', cType);
            if ( cType === 'server' ){
                $('#password2').parents('tr:first').slideUp(300);
                $('#password').parents('tr:first').slideUp(400);
                $('#generatePassword').parents('tr:first').hide(100);
                // Check if Root CA exists,
                // if not, display a warning
                $.Ovpnc().ajaxCall({
                    url: "/api/certificates",
                    data: {
                        cert_name: 'ca',
                        type: 'ca',
                        name: 'anyuser',
                        action: 'usage'
                    },
                    method: 'GET',
                    success_func: $.addCertificate().ajaxCheckCASuccess,
                    error_func: $.addCertificate().ajaxCheckCAError
                });
                // Set server type defaults
                $('#username').parent('div').find('label').text('Common Name');
                $('#cert_name').removeAttr('readonly')
                              .css({
                                color: '',
                                'background-color': ''
                              }).focusout();
            }
            else if ( cType === 'client' ){
                $('#cert_name').removeAttr('readonly')
                              .attr('value','')
                              .css({
                                color: '',
                                'background-color': ''
                              });

                // Check if Root CA exists,
                // if not, display a warning
                window._first_move = 1;
                $.Ovpnc().ajaxCall({
                    url: "/api/certificates",
                    data: {
                        cert_name: 'ca',
                        type: 'ca',
                        name: 'anyuser',
                        action: 'usage'
                    },
                    method: 'GET',
                    success_func: $.addCertificate().ajaxCheckCASuccess,
                    error_func: $.addCertificate().ajaxCheckCAError
                });

                if ( $('#password').is(':hidden') ){
                    $('#password').parents('tr:first').slideDown(400);
                    $('#password2').parents('tr:first').slideDown(300);
                    $('#generatePassword').parents('tr:first').show(100);
                }
                if ( $('#username').attr('value') != '' ) $('#username').focusout();
                $('#username').parent('div').find('label').text('Username');
            }
            else if ( cType === 'ca' ){
                if ( window.checkNoDupMessage !== undefined ){
                    window.checkNoDupMessage = undefined;
                    $.each( $('.err_text'), function(){
                        if ( $(this).text().match(/You must have a Root CA/) ){
                            $(this).parent('div').remove();
                            if ( $('#message').text() == '' ){
                                $('#message_container').hide();
                            }
                        }
                    });
                }
                if ( $('#password').is(':hidden') ){
                    $('#password').parents('tr:first').slideDown(300);
                    $('#password2').parents('tr:first').slideDown(200);
                    $('#generatePassword').parents('tr:first').show(350);
                }
                $('#cert_name').attr('value', 'ca')
                              .attr('readonly','readonly')
                              .css({
                                color: '#888888',
                                'background-color': '#CCCCCC'
                              }).focusout();
                $('#username').parent('div').find('label').text('Common Name').focus();
            }
            else {
            }
            // Set and / or hide certain fields
            $.addCertificate().applyNonClientCertType(cType);
        },
        //
        // Hide certain fields if certype is server or ca
        //
        applyNonClientCertType: function (type) {
            if ( type === 'ca' ){
            }
            else if ( type === 'server' ) {

            }
            else {

            }
        },
        //
        // Handle error return from checking Root CA
        //
        ajaxCheckCAError: function (e){

            if ( window._first_move !== undefined ){
                var _wait_remove =  setInterval(function() {
                    $('#cert_name').parent('div').find('label').css('color','#333333');
                    $('#cert_name').parent('div').find('.error_message').remove();
                    window.clearInterval(_wait_remove);
                }, 400 );
                window._first_move = undefined;
            }

            // Error actually means that
            // the Root CA already exists
            // This is okay if the user
            // is on certtype server or client
            // he can now create them because
            // he has a Root CA.
            if ( window.DEBUG ) log( "ajaxCheckCASuccess got back: %o", e);
            var action = jQuery.parseJSON(e.responseText);
            if (action.rest && action.rest.locked == 1 ){
                window.locked_ca = 1;
                return;
            }
            window.locked_ca = undefined;
            return;
        },
        //
        // Handle return from checking Root CA
        //
        ajaxCheckCASuccess: function (r){
            // Success actually means that
            // the Root CA doesn't exists
            // In this case we want to display
            // a warning to the user to create
            // one because he is now on the
            // certtype server or client.
            if ( window.DEBUG ) log( "ajaxCheckCASuccess got back: %o", r);
            if ( window.checkNoDupMessage === undefined ){
                window.checkNoDupMessage = 1;
                alert(
                    $.Ovpnc().alertIcon + ' You must have a Root CA, only then server and client certificates can be generated.</div><div class="clear"></div>'
                );
            }
        },
        //
        // Main function - init
        //
        certExecActions: function (){
        	$('#username').focus();
        	var cookie_data = new Object();
        	// Preload cookie
            if ( $.cookie( $.addCertificate().cookieData.cookie_name ) !== null ){
                cookie_data = jQuery.parseJSON( $.cookie( $.addCertificate().cookieData.cookie_name ) );
                if ( window.DEBUG ) log("Found cookie data: %o", cookie_data);
        	}
            else {
                log('No cookie data, fields to default state.');
            }
            $.Ovpnc.cookie = cookie_data;
            // Set fields from cookie (disabled -> implementing "save details as template")
            $.Forms().setFormFromCookie( cookie_data, $.addCertificate().elems);
            if ( cookie_data.certtype ){
                $('.radiogroup').find('input').removeAttr('checked');
                $('input[value=' + cookie_data.certtype +']', '#certtype').attr('checked','checked');
                $.addCertificate().checkCertType(cookie_data.certtype);
            }

        	$.addCertificate().setSelectBind();
        	$.addCertificate().setClickBind();
            $.Ovpnc().chooseUser({
                element: $('#username'),
                rows: 12,
                db: 'user',
                like: 1,
            });

            if ( $('#cert_name').attr('value') != '' ) $('#cert_name').focusout();
            if ( $('#username').attr('value') != '' ) $('#username').focusout();

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
                if ( window.DEBUG ) log('We got a default: ' + _default_country);
                $.addCertificate().getStateList( _default_country );
            }    
            // If no country has been set,
        	// load from the cookie.
        	else if ( cookie_data !== undefined && cookie_data.country !== undefined ){
        		$.Ovpnc.cookie = cookie_data;
        		if ( window.DEBUG ) log("Found country in saved cookie: ", $.Ovpnc.cookie.country);
        		// If these are numbers, it is a geonameId
                if ( cookie_data.country == 0 ) {
                    if ( window.DEBUG ) log( 'country is 0 from cookie, getting user location' );
            		$.addCertificate().getUserGeolocation();
                }
        		else if ( ! isNaN(cookie_data.country) ){
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
            if ( window.DEBUG ) log("confirmExit got: %o",p);
            if ( p === undefined ) return true;
            if ( $.cookie( p.cookie_name ) !== null ){
                $.removeCookie( p.cookie_name );
            }
            if ( $.cookie( p.cookie_name ) !== null ){
                $.removeCookie( p.cookie_name );
            }
            // Set the cookie data
            var Settings = JSON.stringify({
                certtype:       $('input[name=cert_type]:checked', '#certtype').attr('value'),
                username:       $('#username').attr('value'),
                cert_name:       $('#cert_name').attr('value'),
                email:          $('#email').attr('value'),
                organization:   $('#organization').attr('value'),
                org_unit:       $('#org_unit').attr('value'),
                key_size:       $('#key_size').attr('value'),
                country :       ( $.addCertificate.edit_manually ? $('#country').attr('value') : $("select#country option:selected").attr('value') ),
                state :         ( $.addCertificate.edit_manually ? $('#state').attr('value') : $("select#state option:selected").attr('value') ),
                city :          ( $.addCertificate.edit_manually ? $('#city').attr('value') : $("select#city option:selected").attr('value') ) 

            });

            $.cookie( p.cookie_name, Settings, {
                expires: p.expires ? p.expires : 30,
                path: p.path_name ? p.path_name : ''
            });

            if ( window.DEBUG ) log("Cookie data: %o", Settings );
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
            // Set select change bind
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
        // Ask user for passwd to unlock Root CA
        //
        processUnlockDialog: function (){
            var cDiv = document.createElement('div');
            $( cDiv ).css({
                'display':'none',
                'color'  :'#555555'
            });
            $( 'body' ).prepend( cDiv );
            $( cDiv ).attr('id','confirmDialog')
                    .dialog({
                 autoOpen: false,
                 title: 'Password required',
                 hide: "explode",
                 modal:true,
                 closeText: 'close',
                 closeOnEscape: true,
                 stack: true,
                 height: "auto",
                 width: "auto",
                 zIndex:9010,
                 position: [ 300, 200 ],
                 buttons: [
                    {
                         text: "cancel", click: function () { $(this).dialog("close").remove(); return false; }
                    },
                    {
                         id: "dialog_submit",
                         text: "ok",     click: function () {
                            $(this).dialog("close");
                            var iDiv = document.createElement('input');
                            $( iDiv ).attr({
                                type: 'password',
                                value: $("#ca_password").attr('value'),
                                name: 'ca_password'
                            }).css('display','none');
                            $('#add_certificate_form').prepend( iDiv );
                            window.locked_ca = undefined;
                            $('#submit_add_certificate_form').click();
                            return true;
                         }
                    }
                 ],
            });
    
            var aDiv = document.createElement('div'),
                bDiv = document.createElement('div'),
                cDiv = document.createElement('div'),
                fDiv = document.createElement('form'),
                lDiv = document.createElement('label'),
                iDiv = document.createElement('input');

            $( iDiv ).attr({
               id: "ca_password",
               type: "password",
               name: "ca_password",
               autofocus: "autofocus"
            });
            $( lDiv ).attr('for','ca_password').text('Password: ');
            $( fDiv ).append( lDiv ).append( iDiv ).attr({
                action: 'javascript:void(0)',
                onsubmit: "if ( $(this).attr('value') == '' ) return false; $('#dialog_submit').click();"
            });
            $( bDiv ).append( fDiv );
            $( aDiv ).html($.Ovpnc().alertInfo + ' A password is required in order to use the Root CA for signing').append('<div class="clear"></div>');
            $( cDiv ).append( aDiv ).append( bDiv );

            $('#confirmDialog').dialog('open')
                               .append( cDiv ).show(200);
            $( aDiv ).css('padding-bottom','8px'); //xxx
            return false;
        },
        //
        // Set event handlers for the form 
        //
        setFormEvents: function(){
            // On form submission
            $('#submit_add_certificate_form').click(function(e){


                $('#cert_name').focusout();
                $('#username').focusout();

                if ( window.locked_ca == 1 ){
                    $.addCertificate().processUnlockDialog();
                    return false;
                }


                if ( ! $('#username').attr('value').match(/\w+/) ) return false;

                // Check password length and strength
                if ( $('input#password').attr('value') != '' ) {
                    var _pw = $('input#password').attr('value');
                    if ( _pw.length < 8 ) {
                        $('input#password').parent('div').find('span').remove();
                        $('input#password').parent('div').prepend('<span class="error_message error_constraint_required">Minimum 8 characters</span>');
                        $('input#password').parent('div').find('label').css('color','#8B0000');
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
                        return false;
                    }
                }
                if ( $('#password').attr('value') != '' && $('#password2').attr('value') == '' ){
                    $('input#password2').parent('div').find('span').remove();
                    $('input#password2').parent('div').prepend('<span class="error_message error_constraint_required">Verification required</span>');
                    $('input#password2').parent('div').find('label').css('color','#8B0000');
                    return false;
                }

                $("#add_certificate_form").valid();

                var _wait =  setInterval(function() {
                    window.clearInterval(_wait);
                },
                1500 );

                $.Ovpnc().setAjaxLoading(
                    1,
                    ( $('#certtype').attr('value') === 'ca' ? 'This might take a while...' : '' )
                );
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
                    cookie_name: "Ovpnc_addCertificate_Form_Settings",
                    path_name: $.addCertificate.pathname,
                    modified: $.addCertificate.form_modified,
                    expires: 14
                });
    
                $.addCertificate().convertLocationIDs();
    
                return true;



            });
        },
        //
        // Convert id's to names for submission
        //
        convertLocationIDs: function () {
            // Get field names(country/state/city)
            var inn = $.addCertificate().elems;
            // For each field name
            for (var i in inn){
                var cVal = $('#' + inn[i] + ' option[value="' + $('#'+inn[i]).attr('value') + '"]').text();
                if ( inn[i] === 'country' ){
                    cVal = cVal.replace( /^([A-Z]{2}) \-.*$/ ,"$1" );
                }
                $('#KEY_'+ inn[i].toUpperCase() + '_TEXT').attr('value', cVal);
            }
        },
        //
        // Get user's location from browser
        //
        getUserGeolocation: function (){
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
        				if ( window.DEBUG ) log('CountryName: ' + result.countryName );
        				$.addCertificate().setSelectCountryGeonameId( result.countryName )		
        	        }).error(function(xhr, ajaxOptions, thrownError) {
        				if ( window.DEBUG ) log("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
        				$('#s_country').find('.ajaxLoader').remove();
        				return false;
        		    }).complete(function(){
        		 		$.ajaxSetup({ async: true, cache: false });
        			})	
        		})
        	}
        	else {
        		log( "Failed to get the navigator geolocation, cannot set default country" );
        		return false;
        	}
        },
        //
        // Build location select input
        //
        buildLocationSelects: function(){
        	var inn = $.addCertificate().elems;
            if ( window.DEBUG ) log("at buildLocationSelects: %o", $.addCertificate.html_mem );
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
            if ( window.DEBUG ) log( 'at buildLocationInputs' );
            // Get field names(country/state/city)
        	var inn = $.addCertificate().elems;
            // For each field name
        	for (var i in inn){
                // Set new class
                $('#s_'+inn[i]).children('.select.label')
                               .removeClass('select label')
                               .addClass('text label')
                               .addClass('oldSelect');
                // Remove select fields
                $('#s_'+inn[i]).children('div').find('select').remove();
                var iElem   = document.createElement('input');
                // Add input fields
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
            if ( window.DEBUG ) log( 'getStateList: ' + geonameId);
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
            		// Empty previous city list results
            		$('#s_city').find('.form_row_select').empty();
        			$('select#city').html('<option value="">-</option>');
        			return false;
        		}

        		// Empty previous list results
        		$('#s_state').find('.form_row_select').empty();

    	    	// Append the options list
        		$.addCertificate().populateStates(states);

        		// Remove previous (state) ajax-loader
        		$('#s_state').find('.ajaxLoader').remove();	
                if ( window.DEBUG ) log("looking up in cookie for state %o", $.Ovpnc.cookie );
        		if ( $.Ovpnc.cookie !== undefined && $.Ovpnc.cookie.state !== undefined && $.Ovpnc.cookie.state !== ''){
                    if ( window.DEBUG ) log('Found state in cookie '  + $.Ovpnc.cookie.state);
        			$("select#state option[value='" + $.Ovpnc.cookie.state + "']").prop('selected',true);
        		}
                var geoId = $("select#state option:selected").attr('value');
                // Add client ajax loader
                $.addCertificate().cityAjaxLoader();
        		// Update city list	
        		$.addCertificate().getCityList( geoId );
            }).error(function(xhr, ajaxOptions, thrownError) {
        		if ( window.DEBUG ) log("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
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
                margin: '2px 3px 0 0'
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
        			$('#s_city').find('.ajaxLoader').remove();		
        			return false;
        		}

                // Remove previous results
                $('#s_city').find('.form_row_select').empty();

        		// Append the options list
        		$.addCertificate().populateCities(cities);
		        // Remove ajax-loader
        		$('#s_city').find('.ajaxLoader').remove();		
        		// Select city if it is found in cookie
        		if ( $.Ovpnc.cookie !== undefined && $.Ovpnc.cookie.city !== undefined && $.Ovpnc.cookie.city !== ''){
        			$("select#city option[value='" + $.Ovpnc.cookie.city + "']").prop('selected',true);
        			if ( window.DEBUG ) log( 'City is now '+$("select#city option:selected").attr('value') );
        		}
        	}).error(function(xhr, ajaxOptions, thrownError) {
        		if ( window.DEBUG ) log("Error getting JSON: " + xhr.status + ", " + thrownError.toString())
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
        			if ( window.DEBUG ) log( "No country? %o" + result );
        			return false;
        		}
                // Append ajax loader for next select field (country)
                $.addCertificate().stateAjaxLoader();
        		$('select#country option').sort(NASort).appendTo('select#country');
        		$("select#country option[value='" + result.geonames[0].geonameId + "']").prop('selected',true);
        		$.addCertificate().getStateList( result.geonames[0].geonameId );
        		
        	}).error(function(xhr, ajaxOptions, thrownError) {
            	if ( window.DEBUG ) log("Error getting JSON: " + xhr.status + ", " + thrownError.toString());
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

