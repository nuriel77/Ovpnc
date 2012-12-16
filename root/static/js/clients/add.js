/* jquery validator settings */
jQuery.validator.setDefaults({
    debug: true,
    success: "valid"
});

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

});

function set_form_events(){

    $('input').bind('keyup',function(e){
        // Prevent submit by pressing enter
        if (e.which == 13) return false;
        // Remove previous warnings if any
        $(this).parent('div').find('span').remove();
        $(this).parent('div').find('label').css('color','#000000');
    });

    $('form#add_client_form').submit(function(){
        // Check password length and strength
        var _pw_length = $('input#password').attr('value');
        if ( _pw_length.length < 8 ) {
            $('input#password').parent('div').find('span').remove();
            $('input#password').parent('div').prepend('<span class="error_message error_constraint_required">Minimum 8 characters</span>');
            $('input#password').parent('div').find('label').css('color','#ff0000');
            return false;
        }
        // Don't submit if passwords don't match or weak
        if ( ! verify_passwords_match() ) return false;
        // Don't submit if passwords are
        if ( $('.top_badPass').is(':visible') ) {
            $('input#password').parent('div').find('span').remove();
            $('input#password').parent('div').prepend('<span class="error_message error_constraint_required">Password is too weak!</span>');
            $('input#password').parent('div').find('label').css('color','#ff0000');
            return false;
        }
    });
    $('input#username').bind('keyup',function(){
        var _name = this.value;
        if ( _name === undefined || _name == '' ) return;
        $.Ovpnc().get_data('/api/clients', { username: _name }, 'GET', return_client_data, return_ajax_error );
    });
    $('input#email').bind('keyup',function(){
        var _name = this.value;
        if ( _name === undefined || _name == '' ) return;
        $.Ovpnc().get_data('/api/clients', { email: _name }, 'GET', return_client_data, return_ajax_error );
    });
    $('input#password2').bind('keyup',function(){
        verify_passwords_match();
    });
}

function verify_passwords_match(){
    var _current = $('input#password2').attr('value');
    var _first = $('input#password').attr('value');
    if ( _current === undefined || _current == '' || _first === '' ) return true;
    if ( _current !== _first ){
        $('input#password2').parent('div').prepend('<span class="error_message error_constraint_required">Passwords do not match</span>');
        $('input#password2').parent('div').find('label').css('color','#ff0000');
        return false;
    }
    return true;
}

function return_client_data(r){
    // Expect one field
    if ( r.rest !== undefined ){
        var keys = [];
        for (var k in r.rest){
            keys.push(k);
        }
        if ( r.rest[keys[0]] !== null  ){
            $('input#' + keys[0]).parent('div').prepend('<span class="error_message error_constraint_required">' + keys[0] + ' already exists</span>');
            $('input#' + keys[0]).parent('div').find('label').css('color','#ff0000');
        }
    }
}

function return_ajax_error(e){
    console.log("error: %o",e);
}

function set_form_validation_rules(){
    // Form validation rules
    $("#add_client_form").validate({
        rules: {
            username: {
                required: true,
                maxlength: 42
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
    });

}
