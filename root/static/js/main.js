/*
 *
 * OpenVPN Controller JS lib
 *
 */
"use strict";

/* Declare Ovpnc namespace */
(function($) {

    var mem, config, actions = {};

    //
    // Create name space $.Ovpnc
    //
    $.Ovpnc = function(options) {
        var obj = $.extend({},
        mem, actions, config, options);
        return obj;
    };

    //
    // Global items
    //
    $.Ovpnc._server_interval = '';
    $.Ovpnc.ajax_lock = 0;
    $.Ovpnc.user_data = new Object();

    //
    // Ovpnc static items
    //
    mem = {
        ajax_loader_floating: '<div id="ajax_loader_floating" onClick="$.Ovpnc().remove_ajax_loading()">&nbsp;</div>',
        ajax_loader: '<img class="ajax_loader" src="/static/images/ajax-loader.gif" />',
        okay_icon: '<img class="ok_icon" width=16 height=16 src="/static/images/okay_icon.png" />',
        error_icon: '<img class="err_icon" width=16 height=16 src="/static/images/error_icon.png" />',
        alert_icon: '<div class="err_text" style="margin:0 1.5px 0 1.5px"><img width=16 height=16 src="/static/images/alert_icon.png" /></div><div class="err_text">',
        alert_ok: '<div class="err_text" style="margin:0 1.5px 0 1.5px"><img width=16 height=16 style="margin-top:-2px" src="/static/images/okay_icon.png" /></div><div class="err_text">',
        alert_err: '<div class="err_text" style="margin:0 1.5px 0 1.5px"><img width=16 height=16 style="margin-top:-2px" src="/static/images/error_icon.png" /></div><div class="err_text">',
        alert_info: '<div class="err_text" style="margin:0 1.5px 0 1.5px"><img width=16 height=16 style="margin-top:-2px" src="/static/images/info_icon.png" /></div><div class="err_text">'
    };
    //
    // Ovnpc config items
    //
    config = {
        poll_freq: 10000,
        // Get server status from api every n milliseconds
        opacity_effect: 3000,
        // Sets the timing of the opacity fadein/out effect
        pathname: window.location.pathname,
        geo_username: function() {
            return $('#geo_username').attr('name');
        },
    };
    //
    // Ovpnc's js actions
    //
    actions = {
        //
        // Get server status loop
        //
        poll_status: function() {
            // run first query to status
            // before starting the setInterval
            $.Ovpnc().get_server_status();

            // Then loop every n miliseconds
            $.Ovpnc._server_interval = setInterval(function() {
                $.Ovpnc().get_server_status();
            },
            $.Ovpnc().poll_freq );
        },
        //
        // Init hover events
        //
        hover_binds: function() {
            // Client action links hover
            $('.unkill_me').hover(function() {
                $(this).css('text-shadow', '#999999 1px -1px 1px');
            },
            function() {
                $(this).css('text-shadow', 'none');
            });

        },
        //
        // Confirm leaving page
        //
        set_confirm_exit: function(modified, action){
            if ( modified === undefined || modified === 0 ) {
                // On window unload
                //console.log('Form modified, setting confirm_on_exit');
                window.onbeforeunload = action;
            }
            else {
                //console.log('Already modified');
            }
            return 1;
        },
        check_username: function(){
            var _name = $('input#username').attr('value');
            if ( _name === undefined || _name == '' ) return;
            //( url, data, method, success_func, error_func, loader, timeout, retries, cache )
            $.Ovpnc().ajax_call({
                url: '/api/clients',
                data: { username: _name },
                method: 'GET',
                success_func: return_client_data,
                error_func: error_ajax_return
            });
        },
        check_passwords: function(){
            var current = $('input#password2').attr('value');
            var first = $('input#password').attr('value');
            $.Ovpnc().verify_passwords_match( first, current, 'password2' );
        },
        check_email: function(){
            var _name = $('input#email').attr('value');
            if ( _name === undefined || _name == '' ) return;
            $.Ovpnc().ajax_call({
                url: '/api/clients',
                data: { email: _name },
                method: 'GET',
                success_func: return_client_data,
                error_func: error_ajax_return
            });
        },
        //
        // Reset form fields
        //
        reset_form: function(id){
            $('#'+id).each(function(){
                this.reset();
            });
        },
        //
        // Server status returns error
        //
        error_server_status: function(e){
            console.log("Server status error: %o", e);
            if ( e.responseText !== undefined
                && e.responseText !== null
                && e.responseText != ''
            ){
                var _msg = jQuery.parseJSON(e.responseText);
                if ( _msg !== undefined && _msg.error !== undefined ){
                    // Redirec to logout if session expired
                    if ( _msg.error === 'Session expired' ) {
                        alert($.Ovpnc().alert_icon + ' ' + _msg.error + ', redirecting to logout...</div><div class="clear"></div>');
                        var _wait_logout = setInterval(function() {
                                window.clearInterval(_wait_logout);
                                window.location = '/login';
                            }, 3000 );
                    }
                    alert($.Ovpnc().alert_icon + ' ' + _msg.error + '.</div><div class="clear"></div>');
                } else if ( _msg.rest !== undefined && _msg.rest.error !== undefined ){
                    alert($.Ovpnc().alert_err + ' ' + _msg.rest.error + '.</div><div class="clear"></div>');
                } else {
                    alert($.Ovpnc().alert_err + ' Unknown result from server! Ovpnc server might be down.</div><div class="clear"></div>');
                }
            }
            //else {
            //    alert($.Ovpnc().alert_err + ' Unknown result from backend! Ovpnc server might be down.</div><div class="clear"></div>');
            //}
        },
        //
        // Get server status
        //
        get_server_status: function() {
            $.Ovpnc().ajax_call({
                url: "/api/server/status",
                data: {},
                method: 'GET',
                success_func: $.Ovpnc().update_server_status,
                error_func: $.Ovpnc().error_server_status
            });
        },
        //
        // Server control call
        //
        server_ajax_control: function(cmd) {
            $.Ovpnc().ajax_call({
                url: "/api/server/",
                data: { command: cmd },
                method: 'POST',
                success_func: function success_ajax_server_control(r,cmd){ return $.Ovpnc().success_ajax_server_control( r, cmd ) },
                error_func: function error_ajax_server_control(r,cmd){ return $.Ovpnc().error_ajax_server_control( r, cmd ) },
                loader: 1
            });
        },
        //
        // Server control success
        //
        success_ajax_server_control: function(r,cmd){
            if (r !== undefined && r.rest !== undefined) {
                r.status = new Object();
                r.status = r.rest.status;
                // Check returned /started/
                if (r.status.match(/started/)) {
                    alert($.Ovpnc().alert_ok + ' ' + r.status + '.</div><div class="clear"></div>');
                    $('#on_icon').animate({
                        opacity: 1
                    },
                    $.Ovpnc().opacity_effect);
                }
                // Check returned /stopped/
                else if (r.status.match(/stopped/)) {
                    alert($.Ovpnc().alert_ok + ' Server stopped.</div><div class="clear"></div>');
                    $('#on_icon').animate({
                            opacity: 0
                        },
                        $.Ovpnc().opacity_effect);

                    if ($('#client_status_container').is(':visible'))
                        $('#client_status_container').hide(300).empty();
                } else {
                    alert($.Ovpnc().alert_err + ' Server did not stop? ' + r.status + '</div><div class="clear"></div>');
                    return
                }
                $.Ovpnc().get_server_status();
            }
            else {
                alert( $.Ovpnc().alert_err + ' Server control did not reply to action ' + cmd + '</div><div class="clear"></div>' );
                return false;
            }
        },
        //
        // Server control error
        //
        error_ajax_server_control : function(r) {
            console.log( "error_ajax_server_control: %o", r);
            r = r.responseText !== undefined ? jQuery.parseJSON(r.responseText) : r;
            r = r.rest.error !== undefined ? r.rest.error : r;
            alert( $.Ovpnc().alert_err + ' Error executing command: ' + r + '</div><div class="clear"></div>' );
            return false;
        },
        //
        // Verify password inputs match
        //
        verify_passwords_match: function(first, current, f_input){
            if ( current === undefined || current == '' || first == '' ) return true;
            if ( current !== first ){
                $('#'+f_input).parent('div').prepend('<span class="error_message error_constraint_required">Passwords do not match</span>');
                $('#'+f_input).parent('div').find('label').css('color','#8B0000');
                return false;
            }
            return true;
        },
        //
        // Set processing overlay div and ajax loader
        //
        set_ajax_loading: function(no_overlay){
            $('body').prepend( $.Ovpnc().ajax_loader_floating );
            if ( no_overlay !== undefined )
                $.Ovpnc().apply_overlay();
        },
        //
        // Remove overlay div and ajax loader
        //
        remove_ajax_loading: function(){
            $('#oDiv').fadeOut('slow').remove();
            $('#ajax_loader_floating').remove();
        },
        //
        // Apply div overlay
        //
        apply_overlay: function(){
            var oDiv = document.createElement('div');
            $( oDiv ).css({
                zIndex:         '9002',
                display:        'none',
                position:       'fixed',
                top:            '120px',
                opacity:        '0.6',
                'min-width':    '99%',
                'height':       '100%',
                'background-color': '#ffffff'
            }).attr('id', 'oDiv');
            $('#outer').prepend( oDiv );
            $( oDiv ).fadeIn(500);
        },
        //
        // Generate password click event handler
        //
        generate_password_click: function(){
            var _token = $('#token').attr('value');
            var _pass = $.Ovpnc().generate_password(_token);
            // Clean any previous messages
            $('#password2').parent('div').find('span.error_message').empty();
            // Color the elements black, if it was
            // red because of previous error..
            $('#password2').parent('div').find('label').css('color','#000000');
            $('#generated_password_text').text(_pass);
            $('#password').attr('value', _pass );
            $('#password2').attr('value', _pass );
            return;
        },
        //
        // Generate random password
        //
        generate_password: function(a){
            var m = new MersenneTwister();
            var randomNumber = m.random();
            var chars = randomNumber + "abcdefhjmnpqrstuvwxyz23456789ABCDEFGHJKLMNPQRSTUVWYXZ" + a;
            var _str = '';
            for (var i=0 ; i<16 ; i++ ){
                var _rn = Math.floor( Math.random() * chars.length );
                _str += chars.substring(_rn, _rn + 1);
            }
            return _str;
        },
        //
        // Init click events
        //
        click_binds: function() {
            $('#message').dblclick(function(){
                $(this).hide(300);
            });
            /*
             * Only if hand_pointer was assigned
             * via template, this user has
             * rights to control. In any case
             * user cannot call api functions
             * to which he doesnt have rights for.
             */
            if ($('#on_off_click_area').hasClass('hand_pointer')) {
                $('#on_off_click_area').click(function() {
                    $.Ovpnc().server_on_off();
                });
            }
        },
        //
        // Get json data generic function
        //  ( url, data, method, success_func, error_func, loader, timeout, retries, cache, async )
        //
        ajax_call: function(p){
            return jQuery.ajax({
                headers: { 'Accept' : 'application/json' },
                async: p.async ? p.async : true,
                timeout: p.timeout ? p.timeout : 5000,
                data: p.data ? p.data : {},
                type: p.method ? p.method : 'GET',
                tryCount: 0,
                retryLimit: p.retries ? p.retries : 3,
                cache: p.cache ? p.cache : false,
                url: p.url,
                beforeSend: function() {
                    $.Ovpnc.ajax_lock = 1;
                    if ( p.loader !== undefined )
                        $.Ovpnc().set_ajax_loading();
                },
                complete: function() {
                    $.Ovpnc.ajax_lock = 0;
                    if ( p.loader !== undefined )
                        $.Ovpnc().remove_ajax_loading();
                },
                success: p.success_func ? function(rest){ return p.success_func(rest); } : function(rest) {
                    console.log("Ajax got back: %o", rest);
                },
                error: p.error_func ? function(rest,xhr,throwError){ return p.error_func(rest,xhr,throwError); } : function(xhr, ajaxOptions, thrownError) {
                    this.tryCount++;
                    if (this.tryCount <= this.retryLimit) {
                        //try again
                        $.ajax(this);
                        return;
                    }
                    if ($(".client_div").is(":visible")) $(".client_div").hide(250);
                    $('#client_status_container').html("<div id='no_data'>" + "No data recieved, possible error: " + thrownError.toString() + "</div>").show(250);
                    return false;
                }
            });
        },
        //
        // process error message
        //
        process_err: function(e, m) {
            if (m === undefined) return false;
            var msg = jQuery.parseJSON(m);
            // In order for update_server_status to accept
            // the data structure and display the status
            // becaue this returned not as status 200
            // we are handling an error.
            var obj = new Object();
            obj.rest = new Object();
            if (msg.rest !== undefined) {
                $.each(msg.rest, function(k, v) {
                    if (k == "error" && v == "Server offline") {
                        obj.rest.status = v;
                        $.Ovpnc().update_server_status( obj );
						return;
                    }
                    else {
                        console.log( k + " -> " + v );
                        alert($.Ovpnc().alert_ok + ' Error: ' + k + ' -> ' + v +'</div><div class="clear"></div>');
                    }
                });
            }
        },
        //
        // The version title of the server status div
        //
        populate_version : function (version) {
            $('#server_status_content').attr('title', version ? version : '');
        },
        //
        // Update server status data
        //
        update_server_status: function(r) {
            //console.log("%o",r);
            if (r !== undefined ) {
                // If we get status back, display
                if ( r.rest !== undefined && r.rest.status !== undefined) {
                    r.status = new Object();
                    r.status = r.rest.status; // Make "more" accessible
                    $('#server_status').text(r.status).css('color', r.status.match(/online/i) ? 'green' : 'gray');
                    // hand_pointer is only applied when this user
                    // has ACL to control the server. (in the tt2 template)
                    if ( $('#on_off_click_area').hasClass('hand_pointer') )
                        $('#on_off_click_area').attr('title', (r.status.match(/online/i) ? 'Shutdown' : 'Poweron') + ' OpenVPN server');
                    // reference used to determine status on click events
                    $('#server_on_off').attr('ref', r.status.match(/online/i) ? 'on' : 'off');
                    // Show or dont show the green on icon
                    $('#on_icon').css('opacity', (r.status.match(/online/i) ? '1' : '0'));
                } else {
                    console.log("Server status got %o",r);
                }
    
                // Show number of connected clients if any
                $('#online_clients_number').text(r.rest.clients !== undefined ? r.rest.clients.length : 0);
        
                // In the title of the server status
                if (r.rest.title !== undefined) $.Ovpnc().populate_version(r.rest.title);
        
                // Update the table with any online clients data
                // This applies only to path /clients
        
                if (r.rest.clients !== undefined
                    && $.Ovpnc().pathname === '/clients'
                    && $('#flexme').is(':visible')
                ) {
                    $.Client().update_flexgrid(r);
                }
            }
            return false;
        },
        //
        // The navigation menu
        //
        slide: function(nav_id, pad_out, pad_in, time, multiplier) {
            var li_elem = nav_id + " li.sliding-element";
            var links = li_elem + " a";
            // initiates the timer used
            // for the sliding animation
            var timer = 0;
            // Prevent animating more than once on entry
            if ($.cookie('Ovpnc_User_Settings') === null) {
                $.Ovpnc.user_data = {
                    already_animated: 1
                };
                $.cookie("Ovpnc_User_Settings", JSON.stringify($.Ovpnc.user_data), {
                    expires: 30,
                    path: '/'
                });
                // creates the slide animation for all list elements
                $(li_elem).each(function(i) {
                    // Remove earlier tab selections
                    $(this).css('font-weight', 'normal');
                    // margin left = - ([width of element] + [total vertical padding of element])
                    $(this).css("margin-left", "-180px");
                    // updates timer
                    timer = (timer * multiplier + time);
                    $(this).animate({
                        marginLeft: "0"
                    },
                    timer);
                    $(this).animate({
                        marginLeft: "15px"
                    },
                    timer);
                    $(this).animate({
                        marginLeft: "0"
                    },
                    timer);
                });
            }
            // creates the hover-slide
            // effect for all link elements
            $(links).each(function(i) {
                $(this).hover(
                function() {
                    $(this).animate({
                        paddingLeft: pad_out
                    },
                    150);
                },
                function() {
                    $(this).animate({
                        paddingLeft: pad_in
                    },
                    150);
                });
            });
            $.Ovpnc().set_select_tab(li_elem);
        },
        server_on_off: function() {
            // Turn off:
            if ( $('#server_on_off').attr('ref') == 'on' ) {
                var _online = $('#online_clients_number').text();
                var _cond   = "There " + (_online == 1 ? 'is ' : 'are ' ) + _online + ' client' +  ( _online > 1 ? 's ' : ' ' )
                            + 'online';
                // Ask confirmation
                var cr = confirm(
                    ( _online > 0 ? _cond + "\r\n" : '' ) + "Are you sure you want to turn the server off?");

                // Cancelled?
                if (cr == false) return;

                // Stop
                $.Ovpnc().server_ajax_control('stop');

                // Wait 5 seconds to refresh the table
                // Only on clients table page
                if ( $('.flexigrid').is(':visible') ){
                    var _wait_refresh = setInterval(function() {
                        $('.pReload').click();
                        window.clearInterval(_wait_refresh);
                    }, 5000 );
                }

                return;
            } else {
                // Turn on:
                $.Ovpnc().server_ajax_control('start');
                return;            
            }
        },
        //
        // Set the selected tab
        //
        set_select_tab: function(l) {
            // Check which page this is
            // then set text bolder on the selected
            var pathname = window.location.pathname;
            pathname = pathname.replace('/', '');
            if (pathname == '') {
                // This is main page
                $('a:contains("Main")').css('font-weight', 'bold');
            }
            else {
                $(l).each(function(i) {
                    var _curret_link = $(this).text().toLowerCase();
                    if (pathname.match(_curret_link)) {
                        $(this).css('font-weight', 'bold');
                        return;
                    }
                });
            }
        },
        //
        // Set the width of the middle frame
        //
        set_middle_frame_w: function(){
            var w = $(window).width();
            var f = w < 1300 ? ( 0.5 * w ) : ( 0.6 * w );
            var o;
            o = w < 1200 ? 7.5 : 10;
            o = w < 1100 ? 3 : 7.5;
            o = w < 1000 ? 0.5 : 3;
            var m = 3;
//            m = w < 1200 ? 2 : 3;
//            m = w < 1100 ? 0.5 : 3;
            
//            $('#outer_centered').css('margin-right', ( w < 1100 ? 0.5 : 4.5 ) + '%');
            $('#outer_centered').css('margin-left', o + '%');
            if ( f > 601 )
                $('#middle_frame').css('min-width', f + 'px');
            if ( $('.flexigrid').is(':visible') ){
                $('.flexigrid').css('max-width', ( $('#middle_frame').width() - 40 ) + 'px' );
            }
        }
    };

})(jQuery);

/*
 * Document Ready
 */
$(document).ready(function() {
    // Set width of middle frame
    $.Ovpnc().set_middle_frame_w();
    $(window).resize(function() {
        $.Ovpnc().set_middle_frame_w();
    });
    // Exit on login page
    if ($.Ovpnc().pathname === '/login')
        return false;

    /*
    if ( $.cookie('Ovpnc_User_Settings') !== null ) {
        var _cookie_data = jQuery.parseJSON( $.cookie('Ovpnc_User_Settings') );
        if ( _cookie_data.last_page !== undefined ){
            var _last_location = _cookie_data.last_page;
            if ( pathname !== _last_location )
                window.location = _last_location;
        }
    }
    */

    // Set up the navigation
    $.Ovpnc().slide("#sliding-navigation", 25, 15, 150, .8);

    // Set actions for clicks
    $.Ovpnc().click_binds();

    // display welcome message
    // Only on main screen
    // Or if never displayed before
    if ($.cookie('Ovpnc_User_Settings') === null || $.Ovpnc().pathname === '/') {
        $.Ovpnc.username = ucfirst($('#username').attr('name'));
        alert($.Ovpnc().alert_ok + 'Hello ' + $.Ovpnc.username
        + ', welcome to OpenVPN Controller!');
    }

    // Get status (loop)
    $.Ovpnc().poll_status();

});

// Add a custom dynamic regex checker to jquery.validate
jQuery.validator.addMethod("test_regex", function(value, element, param) {
    return value.match(new RegExp("^." + param + "$"));
});


function test_edit(){
    $.Ovpnc().set_ajax_loading();
}
