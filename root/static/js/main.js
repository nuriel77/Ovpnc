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
    $.Ovpnc._serverInterval = '';
    $.Ovpnc.ajaxLock = 0;
    $.Ovpnc.userData = new Object();

    //
    // Ovpnc static items
    //
    mem = {
        ajaxLoaderFloating: '<div id="ajaxLoaderFloating" onClick="$.Ovpnc().removeAjaxLoading()">&nbsp;</div>',
        ajaxLoader: '<img class="ajaxLoader" src="/static/images/ajax-loader.gif" />',
        okayIcon:   '<img class="ok_icon" width=16 height=16 src="/static/images/okay_icon.png" />',
        errorIcon:  '<img class="err_icon" width=16 height=16 src="/static/images/error_icon.png" />',
        alertIcon:  '<div class="err_text" style="margin:0 1.5px 0 1.5px"><img width=16 height=16 src="/static/images/alert_icon.png" /></div><div class="err_text">',
        alertOk:    '<div class="err_text" style="margin:0 1.5px 0 1.5px"><img width=16 height=16 style="margin-top:-2px" src="/static/images/okay_icon.png" /></div><div class="err_text">',
        alertErr:  '<div class="err_text" style="margin:0 1.5px 0 1.5px"><img width=16 height=16 style="margin-top:-2px" src="/static/images/error_icon.png" /></div><div class="err_text">',
        alertInfo: '<div class="err_text" style="margin:0 1.5px 0 1.5px"><img width=16 height=16 style="margin-top:-2px" src="/static/images/info_icon.png" /></div><div class="err_text">'
    };
    //
    // Ovnpc config items
    //
    config = {
        pollFreq: 10000,
        // Get server status from api every n milliseconds
        opacityEffectDuration: 3000,
        // Sets the timing of the opacity fadein/out effect
        pathname: window.location.pathname,
        geoUsername: function() {
            return $('#geoUsername').attr('name');
        },
    };
    //
    // Ovpnc's js actions
    //
    actions = {
        //
        // Get server status loop
        //
        pollStatus: function() {
            // run first query to status
            // before starting the setInterval
            $.Ovpnc().getServerStatus();

            // Then loop every n miliseconds
            $.Ovpnc._serverInterval = setInterval(function() {
                $.Ovpnc().getServerStatus();
            },
            $.Ovpnc().pollFreq );
        },
        //
        // Data return from client action
        //
        returnedClientData: function(r){
            // Expect one field
            if ( r.rest !== undefined ){
                var keys = [];
                for (var k in r.rest){ keys.push(k); }
                if ( r.rest[keys[0]] !== null  ){
                    $('input#' + keys[0]).parent('div').prepend('<span class="error_message error_constraint_required">' + keys[0] + ' already exists</span>');
                    $('input#' + keys[0]).parent('div').find('label').css('color','#8B0000');
                }
            }
        },
        //
        // Confirm leaving page
        //
        setConfirmExit: function(modified, action){
            if ( modified === undefined || modified === 0 ) {
                // On window unload
                console.log('Form modified, setting provided action.');
                window.onbeforeunload = action;
            }
            return 1;
        },
        //
        // Handle returned error
        //
        errorAjaxReturn: function(e){
            console.log("error: %o",e);
        },
        //
        // Check the username from database
        //
        checkUsername: function(){
            var _name = $('input#username').attr('value');
            if ( _name === undefined || _name == '' ) return;
            //( url, data, method, success_func, error_func, loader, timeout, retries, cache )
            $.Ovpnc().ajaxCall({
                url: '/api/clients',
                data: { username: _name },
                method: 'GET',
                success_func: $.Ovpnc().returnedClientData,
                error_func: $.Ovpnc().errorAjaxReturn
            });
        },
        //
        // Check if the passwords match
        //
        checkPasswords: function(){
            var current = $('input#password2').attr('value');
            var first = $('input#password').attr('value');
            $.Ovpnc().verifyPasswordsMatch( first, current, 'password2' );
        },
        //
        // Check if this email is in use
        //
        checkEmail: function(){
            var _name = $('input#email').attr('value');
            if ( _name === undefined || _name == '' ) return;
            $.Ovpnc().ajaxCall({
                url: '/api/clients',
                data: { email: _name },
                method: 'GET',
                success_func: $.Ovpnc().returnedClientData,
                error_func: $.Ovpnc().errorAjaxReturn
            });
        },
        //
        // Server status returns error
        //
        errorServerStatus: function(e){
            console.log("Server status error: %o", e);
            if ( e.responseText !== undefined
                && e.responseText !== null
                && e.responseText != ''
            ){
                var _msg = jQuery.parseJSON(e.responseText);
                if ( _msg !== undefined && _msg.error !== undefined ){
                    // Redirec to logout if session expired
                    if ( _msg.error === 'Session expired' ) {
                        alert($.Ovpnc().alertIcon + ' ' + _msg.error + ', redirecting to logout...</div><div class="clear"></div>');
                        var _wait_logout = setInterval(function() {
                                window.clearInterval(_wait_logout);
                                window.location = '/login';
                            }, 3000 );
                    }
                    alert($.Ovpnc().alertIcon + ' ' + _msg.error + '.</div><div class="clear"></div>');
                } else if ( _msg.rest !== undefined && _msg.rest.error !== undefined ){
                    alert($.Ovpnc().alertErr + ' ' + _msg.rest.error + '.</div><div class="clear"></div>');
                } else {
                    alert($.Ovpnc().alertErr + ' Unknown result from server! Ovpnc server might be down.</div><div class="clear"></div>');
                }
            }
            //else {
            //    alert($.Ovpnc().alertErr + ' Unknown result from backend! Ovpnc server might be down.</div><div class="clear"></div>');
            //}
        },
        //
        // Get server status
        //
        getServerStatus: function() {
            $.Ovpnc().ajaxCall({
                url: "/api/server/status",
                data: {},
                method: 'GET',
                success_func: $.Ovpnc().updateServerStatus,
                error_func: $.Ovpnc().errorServerStatus
            });
        },
        //
        // Server control call
        //
        serverAjaxControl: function(cmd) {
            $.Ovpnc().ajaxCall({
                url: "/api/server/",
                data: { command: cmd },
                method: 'POST',
                success_func: function successAjaxServerControl(r,cmd){ return $.Ovpnc().successAjaxServerControl( r, cmd ) },
                error_func: function errorAjaxServerControl(r,cmd){ return $.Ovpnc().errorAjaxServerControl( r, cmd ) },
                loader: 1
            });
        },
        //
        // Server control success
        //
        successAjaxServerControl: function(r,cmd){
            if (r !== undefined && r.rest !== undefined) {
                r.status = new Object();
                r.status = r.rest.status;
                // Check returned /started/
                if (r.status.match(/started/)) {
                    alert($.Ovpnc().alertOk + ' ' + r.status + '.</div><div class="clear"></div>');
                    $('#on_icon').animate({
                        opacity: 1
                    },
                    $.Ovpnc().opacityEffectDuration);
                }
                // Check returned /stopped/
                else if (r.status.match(/stopped/)) {
                    alert($.Ovpnc().alertOk + ' Server stopped.</div><div class="clear"></div>');
                    $('#on_icon').animate({
                            opacity: 0
                        },
                        $.Ovpnc().opacityEffectDuration);

                    if ($('#client_status_container').is(':visible'))
                        $('#client_status_container').hide(300).empty();
                } else {
                    alert($.Ovpnc().alertErr + ' Server did not stop? ' + r.status + '</div><div class="clear"></div>');
                    return
                }
                $.Ovpnc().getServerStatus();
            }
            else {
                alert( $.Ovpnc().alertErr + ' Server control did not reply to action ' + cmd + '</div><div class="clear"></div>' );
                return false;
            }
        },
        //
        // Server control error
        //
        errorAjaxServerControl : function(r) {
            console.log( "errorAjaxServerControl: %o", r);
            r = r.responseText !== undefined ? jQuery.parseJSON(r.responseText) : r;
            r = r.rest.error !== undefined ? r.rest.error : r;
            alert( $.Ovpnc().alertErr + ' Error executing command: ' + r + '</div><div class="clear"></div>' );
            return false;
        },
        //
        // Verify password inputs match
        //
        verifyPasswordsMatch: function(first, current, f_input){
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
        setAjaxLoading: function(no_overlay){
            $('body').prepend( $.Ovpnc().ajaxLoaderFloating );
            if ( no_overlay !== undefined )
                $.Ovpnc().applyOverlay();
        },
        //
        // Remove overlay div and ajax loader
        //
        removeAjaxLoading: function(){
            $('#oDiv').fadeOut('slow').remove();
            $('#ajaxLoaderFloating').remove();
        },
        //
        // Apply div overlay
        //
        applyOverlay: function(){
            var oDiv = document.createElement('div');
            $( oDiv ).css({
                zIndex:         '9002',
                display:        'none',
                position:       'fixed',
                top:            '120px',
                opacity:        '0.4',
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
        generatePasswordClick: function(){
            var _token = $('#token').attr('value');
            var _pass = $.Ovpnc().generatePassword(_token);
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
        generatePassword: function(a){
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
        clickBinds: function() {
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
                    $.Ovpnc().serverOnOff();
                });
            }
        },
        //
        // Get json data generic function
        //  ( url, data, method, success_func, error_func, loader, timeout, retries, cache, async )
        //
        ajaxCall: function(p){
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
                    $.Ovpnc.ajaxLock = 1;
                    if ( p.loader !== undefined )
                        $.Ovpnc().setAjaxLoading();
                },
                complete: function() {
                    $.Ovpnc.ajaxLock = 0;
                    if ( p.loader !== undefined )
                        $.Ovpnc().removeAjaxLoading();
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
            // In order for updateServerStatus to accept
            // the data structure and display the status
            // becaue this returned not as status 200
            // we are handling an error.
            var obj = new Object();
            obj.rest = new Object();
            if (msg.rest !== undefined) {
                $.each(msg.rest, function(k, v) {
                    if (k == "error" && v == "Server offline") {
                        obj.rest.status = v;
                        $.Ovpnc().updateServerStatus( obj );
						return;
                    }
                    else {
                        console.log( k + " -> " + v );
                        alert($.Ovpnc().alertOk + ' Error: ' + k + ' -> ' + v +'</div><div class="clear"></div>');
                    }
                });
            }
        },
        //
        // The version title of the server status div
        //
        populateVersion : function (version) {
            $('#server_status_content').attr('title', version ? version : '');
        },
        //
        // Update server status data
        //
        updateServerStatus: function(r) {
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
                    $('#serverOnOff').attr('ref', r.status.match(/online/i) ? 'on' : 'off');
                    // Show or dont show the green on icon
                    $('#on_icon').css('opacity', (r.status.match(/online/i) ? '1' : '0'));
                } else {
                    console.log("Server status got %o",r);
                }
    
                // Show number of connected clients if any
                $('#online_clients_number').text(r.rest.clients !== undefined ? r.rest.clients.length : 0);
        
                // In the title of the server status
                if (r.rest.title !== undefined) $.Ovpnc().populateVersion(r.rest.title);
        
                // Update the table with any online clients data
                // This applies only to path /clients
        
                if (r.rest.clients !== undefined
                    && $.Ovpnc().pathname === '/clients'
                    && $('#flexme').is(':visible')
                ) {
                    $.Client().updateFlexgrid(r);
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
                $.Ovpnc.userData = {
                    already_animated: 1
                };
                $.cookie("Ovpnc_User_Settings", JSON.stringify($.Ovpnc.userData), {
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
            $.Ovpnc().setSelectTab(li_elem);
        },
        //
        // Control server on/off
        //
        serverOnOff: function() {
            // Turn off:
            if ( $('#serverOnOff').attr('ref') == 'on' ) {
                var _online = $('#online_clients_number').text();
                var _cond   = "There " + (_online == 1 ? 'is ' : 'are ' ) + _online + ' client' +  ( _online > 1 ? 's ' : ' ' )
                            + 'online';
                // Ask confirmation
                var cr = confirm(
                    ( _online > 0 ? _cond + "\r\n" : '' ) + "Are you sure you want to turn the server off?");

                // Cancelled?
                if (cr == false) return;

                // Stop
                $.Ovpnc().serverAjaxControl('stop');

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
                $.Ovpnc().serverAjaxControl('start');
                return;            
            }
        },
        //
        // Set the selected tab
        //
        setSelectTab: function(l) {
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
        setMiddleFrameWidth: function(){
            var w = $(window).width();
            var f = w < 1300 ? ( 0.5 * w ) : ( 0.6 * w );
            var o;
            o = w < 1200 ? 7.5 : 10;
            o = w < 1100 ? 3 : 7.5;
            o = w < 1000 ? 0.5 : 3;
            var m = 3;
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
    $.Ovpnc().setMiddleFrameWidth();
    $(window).resize(function() {
        $.Ovpnc().setMiddleFrameWidth();
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
    $.Ovpnc().clickBinds();

    // display welcome message
    // Only on main screen
    // Or if never displayed before
    if ($.cookie('Ovpnc_User_Settings') === null || $.Ovpnc().pathname === '/') {
        $.Ovpnc.username = ucfirst($('#username').attr('name'));
        alert($.Ovpnc().alertOk + 'Hello ' + $.Ovpnc.username
        + ', welcome to OpenVPN Controller!');
    }

    // Get status (loop)
    $.Ovpnc().pollStatus();

});

// Add a custom dynamic regex checker to jquery.validate
jQuery.validator.addMethod("test_regex", function(value, element, param) {
    return value.match(new RegExp("^." + param + "$"));
});


function test_edit(){
    $.Ovpnc().setAjaxLoading();
}
