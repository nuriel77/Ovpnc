/* jquery validator settings */
jQuery.validator.setDefaults({
    debug: true,
    success: "valid",
    messages: {
        username: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z0-9_]</div>",
        address: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z0-9\\-\\.\\(\\) ]</div>",
        fullname: "<div style='margin-left:40px;'>Invalid input, allowed regex: [a-zA-Z\\-\\.\\' ]</div>",
        phone: "<div style='margin-left:40px;'>Invalid input, allowed regex: [0-9\\-\\.\\(\\) ]</div>"
    },
    // Added custom check test_regex
    rules: {
        username: { test_regex: "([a-zA-Z0-9_]*)" },
        phone: { test_regex: "([0-9\-\.\(\) ]*)" },
        fullname: { test_regex: "[a-zA-Z\-\'\. ]*" },
        address: { test_regex: "([a-zA-Z0-9\-\.\'\(\) ]*)" }
    },
    errorClass: "client_error",
    validClass: "valid",
    errorElement: "span",
    focusInvalid: true,
    errorContainer: $( [] ),
    errorLabelContainer: $( [] ),
    onsubmit: false,
    ignore: ":hidden",
    ignoreTitle: false
});
jQuery.validator.addMethod("test_regex", function(value, element, param) {
    return value.match(new RegExp("^." + param + "$"));
});

/* addClient namespace */
(function($) {

    $.addClient = function(options) {
        var obj = $.extend({},
        actions );
        return obj;
    };

    $.addClient.form_modified = 0;
    $.addClient.pathname = window.location.pathname;

    //
    // addClient actions
    //
    actions = {
        validationRules: function() {
            return {
                rules: {
                    username: {
                        required: true,
                        minlength: 2,
                        maxlength: 42,
                    },
                    fullname: {
                        required: true,
                        minlength: 2,
                        maxlength: 42,
                    },
                    password: {
                        required: true,
                        maxlength: 72,
                        minlength: 8
                    },
                    email: {
                        required: true,
                        minlength: 3,
                        maxlength: 72,
                        email: true
                    },
                    phone: {
                        required: false,
                        maxlength: 32,
                        minlength: 3
                    },
                    address: {
                        required: false,
                        maxlength: 128,
                        minlength: 2
                    }
                }
            }
        },
        cookieData : {
            cookie_name: "Ovpnc_addClient_Form_Settings",
            path_name: $.addClient.pathname,
            modified: $.addClient.form_modified,
            expires: 14
        },
        setClickBind: function(){
            if(typeof(events) !== "function"){
                $('#generatePassword').click(function(){
                    $.addClient().checkChanges();
                });
            }
            $.addClient().checkChanges();
        },
        //
        // Confirm leaving page
        // save state to cookie
        // [data, cookie_name, path_name, modified, expires]
        confirmExit: function(){
            var p = $.addClient().cookieData;
            if ( p === undefined ) return true;
            if ( $.cookie( p.cookie_name ) !== null ){
                $.removeCookie( p.cookie_name );
            }

            // Set the cookie data
            var Settings = JSON.stringify({
                username: $('#username').attr('value'),
                email: $('#email').attr('value'),
                address: $('#address').attr('value'),
                phone: $('#phone').attr('value'),
                fullname: $('#fullname').attr('value')
            });

            if ( window.DEBUG ) log("Cookie data: %o",Settings);
            $.cookie( p.cookie_name, Settings, {
                expires: p.expires ? p.expires : 30,
                path: p.path_name ? p.path_name : ''
            });
            if ( window.DEBUG ) log('Cookie saved');

            // Warn user about changes [for debug only]
            //return "Unsaved modifications";
            return;
        },
        //
        // Set check changes and modified
        // form variable for confirmExit
        //
        checkChanges: function(){
            $('input').bind('focusout',function(){
                //$(this).parent('div').find('span:not(.passwd_err)').remove();
                $.addClient.form_modified = $.Ovpnc().setConfirmExit( $.addClient.form_modified, $.addClient().confirmExit );
            });
            $('select').change(function(){
                $.addClient.form_modified = $.Ovpnc().setConfirmExit( $.addClient.form_modified, $.addClient().confirmExit );    
            });
        },
        //
        // Set event handlers
        //
        setFormEvents: function(){
            /*
             *
             * Begin submit form override
             *
             */
            $('#submit_add_client_form').click(function(e){
            	// Set the ajax loader
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
                $("#add_client_form").valid();
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
                // Save the current values - [ debug ]
                // (data, cookie_name, path_name, modified, expires)
                $.addClient().confirmExit();
                
                $.Ovpnc.ajaxLock = 1;
                window.lock_checked = undefined;
                var doDiv = document.createElement('div');
                $(doDiv).attr('id','addClientOverlay')
                		.css({
                			'position': 'fixed',
                			'z-index': '9008',
                			'border': '1px solid lightgray',
                		    '-moz-border-radius': '5px',
                			'background': '#CCCCCC',
                			'opacity': '0.4',
                			'width': ( $('#addClient').width() ) - 3 + 'px',
                			'height': ( $('#addClient').height() - 3 ) + 'px',
                		});
                $('#addClient').prepend(doDiv);
                $.Ovpnc().ajaxCall({
                    url: "/clients/add",
                    data: $('#add_client_form').serialize(),
                    method: 'POST',
                    success_func: function (r){
                    	if ( window.DEBUG ) log("Got add client success: %o", r);
                    	if ( r.rest !== undefined ){
                    		              	    	
                    		if ( r.error !== undefined ){
                    			alert( $.Ovpnc().alertErr + ' ' + decodeURIComponent(r.error) + '</div><div class="clear"></div>' );
                    			return;
                    		}
                    		
                    		if ( r.rest.status !== undefined
                    	      && r.rest.status === 'ok'
                    	    ){
                    			$('#oDiv').fadeOut('slow').remove();
                    			$('#addClient').slideUp('slow').remove();
                    			$('.pReload').click();
                    	    	alert( $.Ovpnc().alertOk + ' ' + r.cert_name + ' added successfully</div><div class="clear"></div>' );
                    	    }
                    	
                    	}

                    },
                    error_func: function (e){
                    	if ( window.DEBUG ) log("Got add client error: %o", e);
                    	var err = jQuery.parseJSON(e.responseText);
                    	if ( err.error ){
                    		var field = err.error.replace(/^.*: (.*)$/, "$1");
                    		alert( $.Ovpnc().alertErr + ' ' + err.error + '</div><div class="clear"></div>' );
                    		$("#add_client_form").find('input[name="' + field + '"]')
                    								  .parent('div').effect("shake", { times:3, distance: 1 }, 500)
                    								  .append('<span class="error_message err_text">Field error</span>');
                    									
                    	}
                    	if ( err.errors ){
                    		for ( i in err.errors ){
	                    		var field = err.errors[i].replace(/^.*: (.*)$/, "$1");
	                    		alert( $.Ovpnc().alertErr + ' ' + err.errors[i] + '</div><div class="clear"></div>' );
	                    		$("#add_client_form").find('input[name="' + field + '"]')
	                    								  .parent('div').effect("shake", { times:3, distance: 1 }, 500)
	                    								  .append('<span class="error_message err_text">Field error</span>');
                    		}								
                    	}
                		$('#oDiv').fadeOut('slow').remove();
                    },
                    complete_func: function(r){
                    	$.Ovpnc().removeAjaxLoading();
                    	$.Ovpnc.ajaxLock = 0;
                    	$('#addClientOverlay').remove();
                    }
                });
                
                return false;
            });
            /* End submit form override */

        },
        // Form validation rules
        setFormValidationRules: function(){
            $("#add_client_form").validate(
                $.addClient().validationRules()
            );
        },
        //
        // Successful return from adding client
        //
        returnedClientAdd: function(msg){
            if ( window.DEBUG ) log("returnClientAdd has: %o",msg);
            if ( msg.error ){
                if ( Object.prototype.toString.call( msg.error ) === '[object Array]'
                    && msg.error.length > 0 
                ){
                    for ( var e in msg.error ){
                        alert($.Ovpnc().alertErr + ' ' + msg.error[e] + '</div><div class="clear"></div>');
                    }
                }
                else {
                    alert($.Ovpnc().alertErr + ' ' + msg.error + '</div><div class="clear"></div>');
                }
            }
            // Success
            if ( msg.status ){
                // Confirm
                var cnf = confirm( msg.status + '. Would you like to add one more?' );
                if ( cnf != true ){
                    alert( $.Ovpnc().alertOk + ' ' + msg.status + ', redirecting...' + '</div><div class="clear"></div>' );
                    // Wait a sec before redirecting    
                    var _wait =  setInterval(function() {
                        window.clearInterval(_wait);
                        window.location = '/clients';
                    },
                    1000 );
                }
                else {
                    // Free window.onbeforeunload
                    window.onbeforeunload = undefined;
                    // Clearn up the cookie
                    $.removeCookie('Ovpnc_addClient_Form_Settings');
                    $.cookie('Ovpnc_addClient_Form_Settings', null);
                    // Clean up old values
                    //$.addClient().resetForm();
                }
            }
            $.Ovpnc().removeAjaxLoading();
        },
        //
        // Returned error from add client
        //
        errorClientAdd: function(r){
            if ( r.responseText ){
                var msg = jQuery.parseJSON(r.responseText);

                if ( msg.fields_error !== undefined
                    && Object.prototype.toString.call( msg.fields_error ) === '[object Array]'
                ){
                    if ( window.DEBUG ) log("%o",msg.fields_error);
                    //$("#add_client_form").valid();
                    //for ( var i in msg.fields_error ){
                    //    $('label[for="' + msg.fields_error[i] + '"]').css('color','#8B0000');
                    //}
                }
                if ( msg.error ){
                    if ( Object.prototype.toString.call( msg.error ) === '[object Array]'
                        && msg.error.length > 0 
                    ){
                        for ( var e in msg.error ){
                            alert($.Ovpnc().alertErr + ' ' + msg.error[e] + '</div><div class="clear"></div>');
                        }
                    }
                    else {
                        alert($.Ovpnc().alertErr + ' ' + msg.error + '</div><div class="clear"></div>');
                    }
                }
                else {
                    alert($.Ovpnc().alertErr + ' Error adding client: unknown error</div><div class="clear"></div>');
                }
            }
            else if ( r.statusText !== undefined ){ 
                alert($.Ovpnc().alertErr + ' Error adding client: ' + r.statusText + '</div><div class="clear"></div>');
            }
            else { 
                if ( window.DEBUG ) log( "%o", r );
                alert($.Ovpnc().alertErr + ' Error adding client: unknown error</div><div class="clear"></div>');
            }
            $.Ovpnc().removeAjaxLoading();
        }
    };
})(jQuery);

