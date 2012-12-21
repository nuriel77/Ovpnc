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
        cookie_data : {
            cookie_name: "Ovpnc_addClient_Form_Settings",
            path_name: $.addClient.pathname,
            modified: $.addClient.form_modified,
            expires: 14
        },
        set_click_bind: function(){
        //    if(typeof(events) !== "function"){
        //        $('#generate_password').click(function(){
        //                $.Ovpnc().check_changes();
        //        });
        //    }
            $.addClient().check_changes();
        },
        //
        // Confirm leaving page
        // save state to cookie
        // [data, cookie_name, path_name, modified, expires]
        confirm_exit: function(){
            var p = $.addClient().cookie_data;
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
            console.log("Cookie data: %o",Settings);
            $.cookie( p.cookie_name, Settings, {
                expires: p.expires ? p.expires : 30,
                path: p.path_name ? p.path_name : ''
            });
            console.log('Cookie saved');

            // Warn user about changes [for debug only]
            return "Unsaved modifications";
        },
        //
        // Set check changes and modified
        // form variable for confirm_exit
        //
        check_changes: function(){
            $('input').bind('keyup',function(){
                console.log('input detected');
                $.addClient.form_modified = $.Ovpnc().set_confirm_exit( $.addClient.form_modified, $.addClient().confirm_exit );
            });
            $('select').change(function(){
                console.log('change detected');
                $.addClient.form_modified = $.Ovpnc().set_confirm_exit( $.addClient.form_modified, $.addClient().confirm_exit );    
            });
        },
        //
        // Reset form fields
        //
        reset_form: function(form){
            $('input[type="text"]').each(function(k,v){ $(v).attr('value',''); });
            $('input[type="password"]').each(function(k,v){ $(v).attr('value',''); });
            $('.generated_password').remove()
            $('.error').remove()
            $('.error_message').remove();
            $('label').each(function(){ $(this).css('color','#000000'); });
        },
        set_form_events: function(){

            // Set validation rules
            $.addClient().set_form_validation_rules();

            // Set keyup for all inputs
            $('input').bind('keyup',function(e){
                // Prevent submit by pressing enter
                if (e.which == 13) return false;
                // Remove previous warnings if any
                $(this).parent('div').find('span').remove();
                $(this).parent('div').find('label').css('color','#000000');
            });
            // On form submission
            $('#submit_add_client_form').click(function(e){
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
                $.Ovpnc().check_username();
                $.Ovpnc().check_passwords();
                $.Ovpnc().check_email();
                $("#add_client_form").valid();
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
                // (data, cookie_name, path_name, modified, expires)
                $.addClient().confirm_exit();

                // Add client - submit to controller
                $.Ovpnc().ajax_call(
                    '/clients/add',
                     $("form#add_client_form").serialize(),
                    'POST',
                    $.addClient().return_client_add,
                    $.addClient().error_client_add,
                    1,
                    15000
                );

            });
            $('input#username').bind('keyup',function(){
                //$.addClient.form_modified = 1;
                $.Ovpnc().check_username();
            });
            $('input#email').bind('keyup',function(){
                //$.addClient.form_modified = 1;
                $.Ovpnc().check_email();
            });
            $('input#password2').bind('keyup',function(){
                //$.addClient.form_modified = 1;
                $.Ovpnc().check_passwords();
            });
            $('#generate_password').bind('mousedown',function(){
                $('#generate_password').css('border','1px solid #999999').css('color','#555555');
            }).bind('mouseup',function(){
                $('#generate_password').css('border','').css('color','#000000');
            });

        },
        // Form validation rules
        set_form_validation_rules: function(){
            $("#add_client_form").validate(
                $.addClient().validation_rules()
            );
        },
        // Set the input fields
        // from the cookie
        set_form_from_cookie: function(data){
            console.log("Setting fields from cookie");
            if ( data !== undefined ){
                if ( data.username !== '' ){
                    $('#username').attr('value', data.name);
                }
                if ( data.email !== '' ){
                    $('#email').attr('value', data.email);
                }
            }
        },
        //
        // Successful return from adding client
        //
        return_client_add: function(msg){
            if ( msg.error ){
                if ( Object.prototype.toString.call( msg.error ) === '[object Array]'
                    && msg.error.length > 0 
                ){
                    for ( var e in msg.error ){
                        alert($.Ovpnc().alert_err + ' ' + msg.error[e] + '</div><div class="clear"></div>');
                    }
                }
                else {
                    alert($.Ovpnc().alert_err + ' ' + msg.error + '</div><div class="clear"></div>');
                }
            }
            // Success
            if ( msg.status ){
                // Confirm
                var cnf = confirm( msg.status + '. Would you like to add one more?' );
                if ( cnf != true ){
                    alert( $.Ovpnc().alert_ok + ' ' + msg.status + ', redirecting...' + '</div><div class="clear"></div>' );
                    var _wait =  setInterval(function() {
                        window.clearInterval(_wait);
                        window.location = '/clients';
                    },
                    1000 );
                }
                else {
                    window.onbeforeunload = undefined;
                    console.log('removing Ovpnc_addClient_Form_Settings cookie');
                    $.removeCookie('Ovpnc_addClient_Form_Settings');
                    $.cookie('Ovpnc_addClient_Form_Settings', null);
                    $.addClient().reset_form();
                }
            }
            $.Ovpnc().remove_ajax_loading();
        },
        //
        // Returned error from add client
        //
        error_client_add: function(r){
            if ( r.responseText ){
                var msg = jQuery.parseJSON(r.responseText);

                if ( msg.fields_error !== undefined
                    && Object.prototype.toString.call( msg.fields_error ) === '[object Array]'
                ){
                    console.log("%o",msg.fields_error);
                    $("#add_client_form").valid();
                    for ( var i in msg.fields_error ){
                        $('label[for="' + msg.fields_error[i] + '"]').css('color','#8B0000');
                    }
                }
                if ( msg.error ){
                    if ( Object.prototype.toString.call( msg.error ) === '[object Array]'
                        && msg.error.length > 0 
                    ){
                        for ( var e in msg.error ){
                            alert($.Ovpnc().alert_err + ' ' + msg.error[e] + '</div><div class="clear"></div>');
                        }
                    }
                    else {
                        alert($.Ovpnc().alert_err + ' ' + msg.error + '</div><div class="clear"></div>');
                    }
                }
                else {
                    alert($.Ovpnc().alert_err + ' Error adding client: unknown error</div><div class="clear"></div>');
                }
            }
            else if ( r.statusText !== undefined ){ 
                alert($.Ovpnc().alert_err + ' Error adding client: ' + r.statusText + '</div><div class="clear"></div>');
            }
            else { 
                console.log( "%o", r );
                alert($.Ovpnc().alert_err + ' Error adding client: unknown error</div><div class="clear"></div>');
            }
            $.Ovpnc().remove_ajax_loading();
        }
    };
})(jQuery);

$(document).ready( function() {

    $("#password").passStrength({
        shortPass:      "top_shortPass",
        badPass:        "top_badPass",
        goodPass:       "top_goodPass",
        strongPass:     "top_strongPass",
        baseStyle:      "top_testresult",
        userid:         "#username",
        messageloc:     1
    });

    var cookie_data = new Object();

    // Preload cookie
    if ( $.cookie( $.addClient().cookie_data.cookie_name ) !== null ){
        cookie_data = jQuery.parseJSON( $.cookie( $.addClient().cookie_data.cookie_name ) );
        $.addClient().set_form_from_cookie( cookie_data );
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

    if ( $('input#username').attr('value') != '' && !$('.error_message').is(':visible') )
        $.Ovpnc().check_username();
    if ( $('input#password').attr('value') != '' && !$('.error_message').is(':visible') )
        $.Ovpnc().check_passwords();
    if ( $('input#email').attr('value') != '' && !$('.error_message').is(':visible') )
        $.Ovpnc().check_email();


    // Handler for exit
    $.addClient().set_click_bind();

});

// Handle returned error
function error_ajax_return(e){
    console.log("error: %o",e);
}

// Handle client returned data
function return_client_data(r){
    // Expect one field
    if ( r.rest !== undefined ){
        var keys = [];
        for (var k in r.rest){
            keys.push(k);
        }
        if ( r.rest[keys[0]] !== null  ){
            $('input#' + keys[0]).parent('div').prepend('<span class="error_message error_constraint_required">' + keys[0] + ' already exists</span>');
            $('input#' + keys[0]).parent('div').find('label').css('color','#8B0000');
        }
    }
}


