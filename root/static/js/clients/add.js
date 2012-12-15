function set_form_events(){
    $('input#username').bind('keyup',function(){
        var _name = this.value;
        console.log('input detected with val: ' + _name);
        $.Ovpnc().get_data('/api/clients', { client: _name }, 'GET', return_client_data, return_ajax_error );
    });
}

function return_client_data(r){
    console.log("%o", r);
    if ( r.rest !== undefined && r.rest.length > 0 ){
        console.log('Warning - duplicate name');
    }
}

function return_ajax_error(e){
    console.log("error: %o",e);
}
