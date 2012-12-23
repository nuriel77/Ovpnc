/*
 *
 * Functions for forms
 *
 */

(function($) {

    //
    // Create name space $.Forms
    //
    $.Forms = function(options) {
        var obj = $.extend({},
        namespace);
        return obj;
    };

    var namespace = {
        //
        // Reset form fields
        //
        resetForm: function(id){
            $('#'+id).each(function(){
                this.reset();
            });
            $('input[type="text"]').each(function(k,v){ $(v).attr('value',''); });
            $('input[type="password"]').each(function(k,v){ $(v).attr('value',''); });
            $('.generated_password').remove()
            $('.error').remove()
            $('.error_message').remove();
            $('label').each(function(){ $(this).css('color','#000000'); });
        },
        //
        // Enable handler for inputs
        // 
        setInputBinds: function(){
            // Set bind for focusout and key up to prevent
            // submitting the form with 'enter'
            $('input').bind('keyup', function(e){
                // Prevent submit by pressing enter
                if (e.which == 13) return false;
                $(this).parent('div').find('label').css('color','#000000');
                $(this).parent('div').find('span').remove();
            });
        },
        //
        // Enable form input binds - for user forms
        //
        setUserFormInputBinds: function(){
            $('input#username').bind('focusout',function(){
                $.Ovpnc().checkUsername();
            });
            $('input#email').bind('focusout',function(){
                $.Ovpnc().checkEmail();
            });
            $('input#password').bind('keyup',function(){
                if ( $('input#focusout').attr('value') != '' )
                    $('#password2').attr('value','');
                $('#generated_password_text').empty();
                $.Ovpnc().checkPasswords();
            });
            $('input#password2').bind('focusout',function(){
                $('#generated_password_text').empty();
                $.Ovpnc().checkPasswords();
            });
            $('#generatePassword').bind('mousedown',function(){
                $('#generatePassword').css('border','1px solid #999999').css('color','#555555');
                $('#password').parent('div').find('span.error_message').remove();
                $('#password').parent('div').find('label').css('color','#333333');
            }).bind('mouseup',function(){
                    var _wait_keyup =  setInterval(function() {
                        window.clearInterval(_wait_keyup);
                        $('#password').keyup();
                        $('#password2').attr('value', $('#password').attr('value') );
                        $('#generated_password_text').text($('#password').attr('value'));
                    },
                    50 );
                $('#generatePassword').css('border','').css('color','#000000');
            });
        },
        //
        // Set the input fields from the cookie
        //
        setFormFromCookie: function(data, ignore_list){
            if ( window.DEBUG ) console.log("Going to set form fields with %o", data);
            if ( data !== undefined ){
                for ( var d in data ){
                    if ( ignore_list !== undefined
                      && jQuery.inArray( d, ignore_list ) > -1
                    ){
                        if ( window.DEBUG ) console.log( 'Found field element to be ignored: ' + d);
                    }
                    else {
                        $('#' + d).attr('value', data[d]);
                    }
                }
            }
            else {
                if ( window.DEBUG ) console.log('No data from cookie with which I can set form fields');
            }
        }
    };

})(jQuery);
