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
    $.Ovpnc.ajax_lock = 0;
    $.Ovpnc.user_data = new Object();

    //
    // Ovpnc static items
    //
    mem = {
        ajax_loader: '<img class="ajax_loader" src="/static/images/ajax-loader.gif" />',
        okay_icon: '<img class="ok_icon" width=16 height=16 src="/static/images/okay_icon.png" />',
        error_icon: '<img class="err_icon" width=16 height=16 src="/static/images/error_icon.png" />',
        alert_icon: '<img width=18 height=18 src="/static/images/alert_icon.png" />',
        alert_ok: '<div style="float:left;"><img width=17 height=17 style="margin-top:-2px" src="/static/images/okay_icon.png" /></div>' + '<div style="float:left;margin:5px 0 0 6px;"></div>',
        alert_err: '<div style="float:left;"><img width=18 height=18 style="margin-top:-2px" src="/static/images/alert_icon.png" /></div>' + '<div style="float:left;margin:5px 0 0 6px;"></div>',
    };
    //
    // Ovnpc config items
    //
    config = {
        poll_freq: 5000,
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
        // Get server status
        poll_status: function() {
            // run first query to status
            // before starting the setInterval
            get_server_status();

            // Then loop every n miliseconds
            setInterval(function() {
                get_server_status();
            },
            $.Ovpnc().poll_freq );
        },
        // Init hover events
        hover_binds: function() {
            // Client action links hover
            $('.unkill_me').hover(function() {
                $(this).css('text-shadow', '#999 1px -1px 1px');
            },
            function() {
                $(this).css('text-shadow', 'none');
            });

        },
        verify_passwords_match: function(first, current, f_input){
            if ( current === undefined || current == '' || first == '' ) return true;
            if ( current !== first ){
                $('#'+f_input).parent('div').prepend('<span class="error_message error_constraint_required">Passwords do not match</span>');
                $('#'+f_input).parent('div').find('label').css('color','#8B0000');
                return false;
            }
            return true;
        },
        // Generate random password
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
        // Init click events
        click_binds: function() {
            // Only if hand_pointer was assigned
            // via template, this user has
            // rights to control. In any case
            // user cannot call api functions
            // to which he doesnt have rights for.
            if ($('#on_off_click_area').hasClass('hand_pointer')) {
                $('#on_off_click_area').click(function() {
                    server_on_off();
                });
            }
        },
        // Get json data
        get_data: function(url, data, method, success_func, error_func) {
            return jQuery.ajax({
                headers: {
                    'Accept': 'application/json'
                },
                async: true,
                timeout: 3000,
                data: data,
                type: method ? method : 'GET',
                tryCount: 0,
                retryLimit: 3,
                cache: false,
                url: url,
                beforeSend: function() {
                    $.Ovpnc.ajax_lock = 1;
                },
                complete: function() {
                    $.Ovpnc.ajax_lock = 0;
                },
                success: success_func ? success_func : function(rest) {
                    console.log("Ajax got back: %o", rest);
                },
                error: error_func ? error_func : function(xhr, ajaxOptions, thrownError) {
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
            })
        },
        // process error message
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
                        update_server_status( obj );
						return;
                    }
                    else {
                        console.log( k + " -> " + v );
                        alert( 'Error: ' + k + " -> " + v );
                    }
                });
            }
        },
        populate_version : function (version) {
            $('#server_status_content').attr('title', version ? version : '');
        },
        // On client page start the flexgrid plugin
        set_clients_table: function() {
            $.ajaxSetup({
                cache: false,
                async: true
            });
            $('#flexme').flexigrid({
                url: '/api/clients',
                dataType: 'json',
                method: "GET",
                preProcess: format_client_results,
                colModel: [
                // TODO: Save table proportions in cookie
                    { display: 'ID', name : 'id', width: 15, sortable : true, align: 'right', hide: true },
                    { display: 'Username', name : 'username', width : 100, sortable : true, align: 'left'},
                    { display: 'Virtual IP', name : 'virtual_ip', width : 85, sortable : true, align: 'left'},
                    { display: 'Remote IP', name : 'remote_ip', width : 85, sortable : true, align: 'left'},
                    { display: 'Remote Port', name : 'remote_port', width : 40, sortable : true, align: 'left', hide: true },
                    { display: 'Bytes in', name : 'bytes_recv', width : 60, sortable : true, align: 'center'},
                    { display: 'Bytes out', name : 'bytes_sent', width : 60, sortable : true, align: 'center'},
                    { display: 'Connected Since', name : 'conn_since', width : 150, sortable : true, align: 'left' },
                    { display: 'Fullname', name : 'fullname', width : 100, sortable : true, align: 'left' },
                    { display: 'Email', name : 'email', width : 80, sortable : true, align: 'left', hide: true },
                    { display: 'Phone', name : 'phone', width: 80, sortable : true, align: 'right', hide: true },
                    { display: 'Address', name : 'address', width: 100, sortable : true, align: 'right', hide: true },
                    { display: 'Enabled', name : 'enabled', width: 20, sortable : true, align: 'right', hide: false },
                    { display: 'Revoked', name : 'revoked', width: 20, sortable : true, align: 'right', hide: false },
                    { display: 'Created', name : 'created', width: 100, sortable : true, align: 'right', hide: false },
                    { display: 'Modified', name : 'modified', width: 100, sortable : true, align: 'right', hide: false }
                ],
                buttons : [
                    { name: 'Add', bclass: 'add', onpress : add_client },
                    { name: 'Delete', bclass: 'delete', onpress : delete_client },
                    { name: 'Block', bclass: 'block', onpress : block_clients },
                    { name: 'Unblock', bclass: 'unblock', onpress : unblock_clients },
                    { name: 'Edit', bclass: 'edit', onpress : console.log('edit') },
                    { separator: true}
                ],
                searchitems : [
                    { display: 'Virtual IP', name : 'virtual_ip'},
                    { display: 'Remote IP', name : 'remote_ip'},
                    { display: 'Remote Port', name : 'remote_port'},
                    { display: 'Created', name : 'created'},
                    { display: 'Modified', name : 'modified'},
                    { display: 'Fullname', name : 'fullname'},
                    { display: 'Email', name : 'email'},
                    { display: 'Since', name : 'conn_since'},
                    { display: 'Username', name : 'username', isdefault: true}
                ],
                sortname: "username",
                sortorder: "asc",
                usepager: true,
                title: 'Clients',
                useRp: true,
                rp: 15,
                showTableToggleBtn: false,
                width: 600,
                height: 300
            });
        },
        // Update the client's tables
        update_flexgrid : function(r){
            // Color unknown client in red
            $('#flexme').find('tr').children('td[abbr="id"]')
                        .children('div').each(function(k, v){
                if ( v.innerHTML === 'unknown' ){
                    $(this).parent().parent('tr').children('td[abbr="username"]')
                        .children('div').css('color','red');
                }
            });
            // Set the right color - on/off notice according
            // to client's status
            var _checker = 0;
            $('#flexme').find('tr').children('td[abbr="username"]')
                        .children('div').each(function(k, v){
                // we match the username from online_data
                // to the current tr.td[abbr=username].div.text in the loop
                // inner_text is in order to get only the username and not
                // any span we might have appended previous loop
                var inner_text = v.innerHTML.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                var online_data = $.Ovpnc().check_client_match(r.rest.clients, inner_text);
                if (online_data !== false) {
                    _checker++;
                    // loop each td find the corresponding 'abbr'
                    // fill in the text from online_data
                    var mem_ip;
                    for (var i in online_data) {
                        if (i !== 'name') {
                            if ( i.match(/^bytes_.*$/) )
                                online_data[i] = ( online_data[i] / 1024 ).toFixed(2) + 'KB';
                            $(this).parent().parent('tr')
                                   .children('td[abbr="' + i + '"]')
                                   .children('div')
                                   .text( online_data[i] ).css('color','black');
                        }
                    }
                    // mark the row which has been found to be online
                    if ( ! $(this).children('span.inner_flexi_text').is(':visible') ){
                        $(this).append('<span class="inner_flexi_text">On</span>');
                    }
                }
                else {
                    // Clean up td's with online data
                    // for client which is not online
                    $(this).children('span.inner_flexi_text').hide(300).remove();
                    if ( $(this).parent().parent('tr')
                                .children('td').children('div')
                                .text() !== '-'
                    ) {
                        var removable =
                            [ "remote_ip", "virtual_ip", "conn_since", "remote_port", "bytes_recv", "bytes_sent" ];
                        for (var z in removable) {
                            $(this).parent().parent('tr')
                                   .children('td[abbr="' + removable[z] + '"]')
                                   .children('div').css('color','lightgray');
                        }
                    }
                }
            });
            if ( _checker === 0 && r.rest.clients.length > 0 ){
                $('.pReload').click();
            }
        },
        // The navigation menu
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
        check_client_match: function(clients, current_client) {
            for (var i in clients) {
                if (clients[i].name === current_client) return clients[i];
            }
            return false;
        }

    };

})(jQuery);

$(document).ready(function() {

    if ($.Ovpnc().pathname === '/login') return;

    // Set custom alert functionality
    window.alert = function(message) {
        // Check if message is already visible,
        // If yes, save current content and append
        if ($('#message').is(':visible')) {
            // Remove first welcome message.
            var old_content = $('#msg_content').html();
            old_content = old_content.replace('<br>', '');
            if (old_content.match(/Hello/g) || old_content === message) {
                $('#msg_content').empty();
            } else {
                message += "<br/>" + $('#msg_content').html();
            }
        }
        // Write
        $('#message').html('<div id="msg_content">[' + get_time() + '] ' + message + '</div>' + '<img id="message_close"' + ' src="/static/images/close-gray.png"' + ' class="hand_pointer"></img>').slideDown(300);
        $('#message_close').click(function() {
            $('#message').hide(300).empty();
        });
        return false;
    };

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

/*
	- Functions -
*/
function canJSON(value) {
    try {
        JSON.stringify(value);
        return JSON.stringify(value);
    } catch(ex) {
        return false;
    }
}

function update_server_status(r) {
    if (r !== undefined && r.rest !== undefined) {
        // If we get status back, display
        if (r.rest.status !== undefined) {
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
            $.Ovpnc().update_flexgrid(r);
        }
    }
    return false;
}

function get_server_status() {
    $.Ovpnc().get_data("/api/server/status", {},
    'GET', update_server_status);
}


function server_ajax_control(cmd) {

    $.post('/api/server/', {
        command: cmd
    },
    function(r) {
        if (r !== undefined && r.rest !== undefined) {
            r.status = new Object();
            r.status = r.rest.status;
            // Check returned /started/
            if (cmd == 'start') {
                if (r.status.match(/started/)) {
                    alert($.Ovpnc().alert_ok + r.status + " at " + get_date() + ".</div>" + '<div class="clear">');
                    $('#on_icon').animate({
                        opacity: 1
                    },
                    $.Ovpnc().opacity_effect);
                    return;
                } else {
                    alert('Server did not start? ' + r.status);
                    return;
                }
                // Check returned /stopped/
            } else if (cmd == 'stop') {
                if (r.status.match(/stopped/)) {
                    alert($.Ovpnc().alert_err + "Server stopped at " + get_date() + ".</div>" + '<div class="clear">');
                    $('#on_icon').animate({
                        opacity: 0
                    },
                    $.Ovpnc().opacity_effect);
                    if ($('#client_status_container').is(':visible')) $('#client_status_container').hide(300).empty();
                    return;
                } else {
                    alert('Server did not stop? ' + r.status);
                    return
                }
            }
        }
        else {
            alert("Server control did not reply to action '" + cmd + "'");
            console.log("Server control did not reply");
            return false;
        }
    }).error(function(xhr, ajaxOptions, thrownError) {
        console.log("Error executing command " + cmd + " server: " + thrownError.toString());
        var msg = jQuery.parseJSON(xhr.responseText);
        alert($.Ovpnc().error_icon + " Error executing command " + cmd + " server: " + thrownError.toString() + (msg.rest.error !== undefined ? ": " + msg.rest.error : ''));
        return false;
    });

}

function server_on_off() {
    // Turn off:
    if ($('#server_on_off').attr('ref') == 'on') {

        // Ask confirmation
        var cr = confirm("Are you sure you want to turn the server off?");
        if (cr != true) return;

        // Stop
        server_ajax_control('stop');
        return;
    } else {
        // Turn on:
        server_ajax_control('start');
        return;
    }
}


function kill_client(c) {

    $.getJSON('/api/server/kill/' + c, function(r) {
        append_dead_client(c);
        alert($.Ovpnc().okay_icon + " Client '" + c + "' killed successfully.");
        return true;
    }).error(function(xhr, ajaxOptions, thrownError) {
        console.log("Error killing client '" + c + "': " + thrownError.toString());
        alert($.Ovpnc().error_icon + " Error killing client '" + c + "': " + thrownError.toString());
        return false;
    });

}

function unkill_client(c) {

    $.getJSON('/api/server/unkill/' + c, function(r) {
        $('#unkill_' + c).remove();
        if (!$('#killed_clients').text().match(/\w+/)) $('#killed_clients_container').hide(250);
        alert($.Ovpnc().okay_icon + " Client '" + c + "' unkilled successfully");
        return true;
    }).error(function(xhr, ajaxOptions, thrownError) {
        console.log("Error unkilling client '" + c + "': " + thrownError.toString());
        alert($.Ovpnc().error_icon + " Error unkilling client '" + c + "': " + thrownError.toString());
        return false;
    });

}

// Check for pending ajax calls
function checkPendingRequest() {

    //console.log('Checking for pending ajax calls');
    if ($.active > 0) {
        //console.log( $.active + " ajax call(s) still active");
        //window.setTimeout(checkPendingRequest, 1000); // run again
        return true;
    }
    else {
        //console.log("No pending ajax calls");
        return false;
    }

}

$.Ovpnc().tfc = new Object();
$.Ovpnc().tfc = { in :0,
    out: 0,
    old_in: 0,
    old_out: 0
};

function get_client_network_usage(name) {

    //console.debug('In: ' + Ovpnc.tfc.in + ', Out: ' + Ovpnc.tfc.out );
    // Build client's traffic div container if it never existed
    // Here we record the values for next loop to pick them up
    // and calculate the delta
    if (!$('#tfc_' + name).is(':visible')) {
        //console.log( 'Build client traffic div first record for '  + name);
        // build for this client a traffic div
        $('#traffic').append('<div class="client_tfc" id="tfc_' + name + '"></div>');

        // Record the in/out packets, use as a starting point for delta calculation
        $('#tfc_' + name).html('<input style="opacity:0" id="rec_in_' + name + '" value="' + $.Ovpnc().tfc. in +'" />' + '<input style="opacity:0" id="rec_out_' + name + '" value="' + $.Ovpnc().tfc.out + '" />');
        // This is the first loop because we created the
        // tfc_+name div, second loop will already
        // see this div is created.
        return;
    }
    else {
        // If the tfc_+name is already created, get
        // the values (these have been recorded from the previous cycle)
        $.Ovpnc().tfc.old_in = $('#rec_in_' + name).val();
        $.Ovpnc().tfc.old_out = $('#rec_out_' + name).val();
        $('#rec_in_' + name).val($.Ovpnc().tfc. in );
        $('#rec_out_' + name).val($.Ovpnc().tfc.out);
    }

    var fixDeltaOut;
    var fixDeltaIn;

    if ($.Ovpnc().tfc.old_in !== '' || $.Ovpnc().tfc.old_in !== 0) {
        var real_deltaIn = $.Ovpnc().tfc. in -$.Ovpnc().tfc.old_in;
        var real_deltaOut = $.Ovpnc().tfc.out - $.Ovpnc().tfc.old_out;

        var bytes_in_avg = real_deltaIn / ($.Ovpnc().poll_freq / 1000);
        var bytes_out_avg = real_deltaOut / ($.Ovpnc().poll_freq / 1000);

        var output = '';
        var in_setter = 'KB/s';
        var out_setter = 'KB/s';
        if (bytes_in_avg > 0) {
            var flDIn = bytes_in_avg / 1024;
            if (flDIn > 1000) {
                in_setter = 'MB/s';
                flDIn = flDIn / 1024;
            }
            fixDeltaIn = flDIn.toFixed(2);
            output += '<div style="float:left" id="tfc_in_' + name + '">' + '<img src="/static/images/red_down.png" />' + '<span style="margin-left:3px;" id="inner_in_' + name + '">' + fixDeltaIn + '</span>' + '<span id="din_setter_' + name + '">' + in_setter + '</span>' + '</div>';
        }
        if (bytes_out_avg > 0) {
            var flDOut = bytes_out_avg / 1024;
            if (flDOut > 1000) {
                out_setter = 'MB/s';
                flDOut = flDOut / 1024;
            }
            fixDeltaOut = flDOut.toFixed(2);
            output += '<div style="float:left;margin-left:5px;" id="tfc_out_' + name + '">' + '<img src="/static/images/green_up.png" />' + '<span style="margin-left:3px;" id="inner_out_' + name + '">' + fixDeltaOut + '</span>' + '<span id="dout_setter_' + name + '">' + out_setter + '</span>' + '</div>';
        }

        $.Ovpnc().tfc.old_in = $.Ovpnc().tfc. in ;
        $.Ovpnc().tfc.old_out = $.Ovpnc().tfc.out;
        if ($('#inner_in_' + name).is(':visible') && $('#inner_out_' + name).is(':visible')) {
            $('#inner_in_' + name).text(fixDeltaIn);
            $('#inner_out_' + name).text(fixDeltaOut);
            $('#din_setter_' + name).text(in_setter);
            $('#dout_setter_' + name).text(out_setter);
        }
        else {
            $('#in_out_' + name).html(output);
        }
    }

}

/* Helper functions */
function ucfirst(str) {
    var f = str.charAt(0).toUpperCase();
    return f + str.substr(1);
}

function get_date() {
    var now = new Date();
    var hrs = now.getHours();
    var min = now.getMinutes();
    var sec = now.getSeconds();
    var then = now.getDay() + '-'
             + (now.getMonth() + 1) + '-'
             + now.getFullYear() + ' '
             + ( hrs < 10 ? '0' + hrs : hrs ) + ':'
             + ( min < 10 ? '0' + min : min ) + ':'
             + ( sec < 10 ? '0' + sec : sec );

    return then;
}

function get_time() {
    var now = new Date();
    var hrs = now.getHours();
    var min = now.getMinutes();
    var sec = now.getSeconds();
    var then = ( hrs < 10 ? '0' + hrs : hrs ) + ':'
             + ( min < 10 ? '0' + min : min ) + ':'
             + ( sec < 10 ? '0' + sec : sec );
    return then;
}

function numberWithCommas(n) {
    var parts = n.toString().split(".");
    return parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",") + (parts[1] ? "." + parts[1] : "");
}

