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
        $.Ovpnc().get_data('/api/clients', { client: _name }, 'GET', return_client_data, return_ajax_error );
    });
    $('input#fullname').bind('keyup',function(){
        var _name = this.value;
        if ( _name === undefined || _name == '' ) return;
        $.Ovpnc().get_data('/api/clients', { fullname: _name }, 'GET', return_client_data, return_ajax_error );
    });
}

function return_client_data(r){
    if ( r.rest !== undefined && r.rest.length > 0 ){
        $('input#username').parent('div').prepend('<span class="error_message error_constraint_required">Name already exists</span>');
        $('input#username').parent('div').find('label').css('color','#ff0000');
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
