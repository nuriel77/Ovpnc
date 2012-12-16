/* jquery validator settings */
jQuery.validator.setDefaults({
    debug: true,
    success: "valid"
});

function set_form_events(){
    $('form#add_client_form').submit(function(){
        var _pw_length = $('input#password').attr('value');
        if ( _pw_length.length < 8 ) {
             $('input#password').parent('div').find('span').remove();
            $('input#password').parent('div').prepend('<span class="error_message error_constraint_required">Minimum 8 characters</span>');
            $('input#password').parent('div').find('label').css('color','#ff0000');
            return false;
        }

     });
    $('input').bind('keyup',function(e){
        // Prevent submit by pressing enter
        if (e.which == 13) return false;
        // Remove previous warnings if any
        $(this).parent('div').find('span').remove()
        $(this).parent('div').find('label').css('color','#000000');
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
