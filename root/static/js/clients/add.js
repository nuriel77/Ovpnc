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

            if ( window.DEBUG ) console.log("Cookie data: %o",Settings);
            $.cookie( p.cookie_name, Settings, {
                expires: p.expires ? p.expires : 30,
                path: p.path_name ? p.path_name : ''
            });
            if ( window.DEBUG ) console.log('Cookie saved');

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
                $(this).parent('div').find('span.error_message').remove();
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

            // Set validation rules
            $.addClient().setFormValidationRules();

            /*
             *
             * Begin submit form override
             *
             */
            $('#submit_add_client_form').click(function(e){
                // Prevent submit by pressing 'enter'
                if ( e.which == 13 ) return false;
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
                return true;
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
            if ( window.DEBUG ) console.log("returnClientAdd has: %o",msg);
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
                    if ( window.DEBUG ) console.log("%o",msg.fields_error);
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
                if ( window.DEBUG ) console.log( "%o", r );
                alert($.Ovpnc().alertErr + ' Error adding client: unknown error</div><div class="clear"></div>');
            }
            $.Ovpnc().removeAjaxLoading();
        }
    };
})(jQuery);

$(document).ready( function() {

    var cookie_data = new Object();

    // Preload cookie
    if ( $.cookie( $.addClient().cookieData.cookie_name ) !== null ){
        cookie_data = jQuery.parseJSON( $.cookie( $.addClient().cookieData.cookie_name ) );
        // Set the form fields
        $.Forms().setFormFromCookie( cookie_data );
    }
    // If we saved the previous fields in a
    // cookie, load from the cookie.
    if ( cookie_data !== undefined && cookie_data.username !== undefined ){
        $.Ovpnc.cookie = cookie_data;
        for ( var k in cookie_data ){
            if (cookie_data[k] !== '' )
                $('#'+k).attr('value',cookie_data[k]);
        }
    }

    /*
    if ( $('input#username').attr('value') != '' && !$('.error_message').is(':visible') )
        $.Ovpnc().checkUsername();
    if ( $('input#password').attr('value') != '' && !$('.error_message').is(':visible') )
        $.Ovpnc().checkPasswords();
    if ( $('input#email').attr('value') != '' && !$('.error_message').is(':visible') )
        $.Ovpnc().checkEmail();
    */
    // Handler for exit
    $.addClient().setClickBind();
    $.addClient().setFormEvents();
});
