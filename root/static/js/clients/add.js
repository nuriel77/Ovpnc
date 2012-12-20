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
    groups: {},
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
                $.addClient.form_modified = 1;
            });
            // On form submission
            //$('form#add_client_form').submit( function(e){
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
                $.addClient().check_username();
                $.addClient().check_passwords();
                $.addClient().check_email();
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
                $.addClient().confirm_exit();

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
                $.addClient.form_modified = 1;
                $.addClient().check_username();
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

        },
        check_username: function(){
            var _name = $('input#username').attr('value');
            if ( _name === undefined || _name == '' ) return;
            $.Ovpnc().ajax_call('/api/clients', { username: _name }, 'GET', return_client_data, error_ajax_return );
        },
        check_passwords: function(){
            var current = $('input#password2').attr('value');
            var first = $('input#password').attr('value');
            $.Ovpnc().verify_passwords_match( first, current, 'password2' );
        },
        check_email: function(){
            var _name = $('input#email').attr('value');
            if ( _name === undefined || _name == '' ) return;
            $.Ovpnc().ajax_call('/api/clients', { email: _name }, 'GET', return_client_data, error_ajax_return );
        },
        // Form validation rules
        set_form_validation_rules: function(){
            // Form validation rules
            $("#add_client_form").validate(
                $.addClient().validation_rules()
            );
        },
        // Confirm unsaved modifications
        // on user leave page
        confirm_exit: function(){
            if ( $.addClient.form_modified === 0 ) return;
            var data = new Object();
            data = {
                username : $('#username').attr('value'),
                email : $('#email').attr('value'),
                address: $('#address').attr('value'),
                phone: $('#phone').attr('value'),
                fullname: $('#fullname').attr('value')
            };
            if ( $.cookie( "Ovpnc_addClient_Form_Settings" ) !== null ){
                $.removeCookie("Ovpnc_addClient_Form_Settings");
            }
            var Settings = JSON.stringify( data );
            $.cookie( "Ovpnc_addClient_Form_Settings", Settings, { expires: 30, path: '/' } );
            return "Unsaved modifications";
        },
        // Confirm leave page
        set_confirm_exit: function(){
            if (  $.addClient.form_modified === 0 ) {
                // On window unload
                window.onbeforeunload = $.addClient().confirm_exit;
            }
        },
        // Set the input fields
        // from the cookie
        set_form_from_cookie: function(data){
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
                alert( $.Ovpnc().alert_ok + ' ' + msg.status + ', redirecting...' + '</div><div class="clear"></div>' );
                var _wait =  setInterval(function() {
                    window.clearInterval(_wait);
                    window.location = '/clients';
                },
                2000 );
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
    if ( $.cookie('Ovpnc_addClient_Form_Settings') !== null ){
        cookie_data = jQuery.parseJSON( $.cookie('Ovpnc_addClient_Form_Settings') );
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
        $.addClient().check_username();
    if ( $('input#password').attr('value') != '' && !$('.error_message').is(':visible') )
        $.addClient().check_passwords();
    if ( $('input#email').attr('value') != '' && !$('.error_message').is(':visible') )
        $.addClient().check_email();

    // Handler for exit
    $.addClient().set_confirm_exit();

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

function generate_password_click(){
    var _token = $('#token').attr('value');
    var _pass = $.Ovpnc().generate_password(_token);
    $('#password2').parent('div').find('span').remove();
    $('#password2').parent('div').find('label').css('color','#000000');
    $('#password2').parent('div').prepend('<span class="generated_password" style="color:#000000">'
        + '<div id="generated_password_text" class="generated_password" onClick="fnSelect(this.id);" style="width:100%;border:0"'
        + '>'+ _pass + '</div>'
        + '</span>'
    );
    $('#password').attr('value', _pass ).keyup();
    $('#password2').attr('value', _pass );
    return;
}


