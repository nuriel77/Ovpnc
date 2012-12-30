/* Clients */

$.Ovpnc().count = 0;
var total_count = 0;

(function($) {

    // Create Client() namespace
    $.Client = function(options) {
        var obj = $.extend({},
        mem, actions );
        return obj;
    };

    var mem = {
        processed: 0,
        loop:  0,
        total_count: 0
    };

    var actions = {
        //
        // Set the Flexigrid table
        //
        setClientsTable: function() {
            $.ajaxSetup({ cache: false, async: true });
            $('#flexme').flexigrid({            
                url: '/api/clients',
                dataType: 'json',
                method: "GET",
                preProcess: $.Client().formatClientResults,
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
                    { display: 'Enabled', name : 'enabled', width: 40, sortable : true, align: 'right', hide: false },
                    { display: 'Blocked', name : 'revoked', width: 40, sortable : true, align: 'right', hide: false },
                    { display: 'Created', name : 'created', width: 100, sortable : true, align: 'right', hide: false },
                    { display: 'Modified', name : 'modified', width: 100, sortable : true, align: 'right', hide: false }
                ],
                buttons : [
                    { name: 'Add', bclass: 'add', onpress : $.Client().addClient },
                    { name: 'Delete', bclass: 'delete', onpress : $.Client().deleteClient },
                    { name: 'Block', bclass: 'block', onpress : blockClients },
                    { name: 'Unblock', bclass: 'unblock', onpress : unblockClients },
                    { name: 'Properties', bclass: 'properties', onpress : test_edit },
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
                width: $('#middle_frame').width() - 40,
                height: 300
            });
            $('.bDiv').append('<div id="ajaxLoaderFlexgridLoading">Loading table data... <img src="/static/images/ajax-loader.gif" /></div>');
        },
        //
        // Prepare client data for flexigrid
        //
        prepareClientColData: function (c){
           /*
            * Some fields need to contain
            * placeholders '-' because they
            * only get updated when server
            * status request returns
            * this keeps flexigrid from
            * messing up the order
            */
            return [
                c.id ? c.id : 'unknown',
                c.username ? c.username : 'unknown',
                c.virtual_ip ? c.virtual_ip : '-',
                c.remote_ip ? c.remote_ip : '-',
                c.remote_port ? c.remote_port : '-',
                c.bytes_recv ? ( c.bytes_recv / 1024 ).toFixed(2) + 'KB' : '-',
                c.bytes_sent ? ( c.bytes_sent / 1024 ).toFixed(2) + 'KB' : '-',
                c.conn_since ? c.conn_since : '-',
                c.fullname ? c.fullname : 'unknown',
                c.email ? c.email : 'unknown',
                c.phone ? c.phone : 'unknown',
                c.address ? c.address : 'unknown',
                c.enabled ? c.enabled : 0,
                c.revoked ? c.revoked : 0,
                c.created ? c.created : '0000-00-00 00:00',
                c.modified ? c.modified : '0000-00-00 00:00'
            ]
        },
        //
        // Format the data from
        // server status, processing
        // only the clients array
        //
        formatClientResults: function (obj){
            if ( window.DEBUG ) log ("Flex got clients: %o", obj);
            // This will force to update
            // online_data and not wait
            var is_felxgrid_ready =
                setInterval(function(){
                    if ( $('#flexme').is(':visible') ){
                        //( url, data, method, success_func, error_func, loader, timeout, retries, cache )
                        $.Ovpnc().ajaxCall({
                            url: "/api/server/status",
                            data: {},
                            method: 'GET',
                            success_func: $.Ovpnc().updateServerStatus
                        });
                        $('#ajaxLoaderFlexgridLoading').remove();
                        window.clearInterval(is_felxgrid_ready);
                    }
                }, 150);

            if ( obj.rest !== undefined && obj.rest.length !== undefined ){
                var __rows = new Array();
                var __count = 0;
                for ( var index in obj.rest ){
                    $.Ovpnc().count++;
                    __count++;
                    __rows.push({
                       id: $.Ovpnc().count,
                       cell: $.Client().prepareClientColData(obj.rest[index])
                    });
                }
                return {
                    total: __count,
                    page: 1,
                    rows: __rows
                }
            }
        },
        //
        // Update / modify data in the client's table
        //
        updateFlexgrid : function(r){
            // If no results, flexigrid applies
            // a blocking div, remove it.
            if ( $('.gBlock').is(':visible') ){
                $('.gBlock').remove();
                return;
            }

            // Apply select field also on right-click
            $('#flexme').find('tr').bind("contextmenu",function(){
                $(this).addClass('trSelected');
            });

            // Set the right color - on/off notice according
            // to client's status
            var _checker = 0;
            $('#flexme').find('tr').children('td[abbr="username"]')
                        .children('div').each(function(k, v)
            {

                // loop to find all neighbor td's
                // set them up with context menu class
                // Add parent name to each so we can easily
                // access / know which name it is when clicking
                // any of the td's
                $(this).parent('td').parent('tr').children('td')
                            .children('div').each(function(z, x){
                    var inner_text = x.innerHTML.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                    // Color unknown client in red
                    if ( inner_text === 'unknown' ){
                        $(this).parent().parent('tr')
                                .children('td[abbr="username"]')
                                .children('div')
                                .css('color','red')
                                .attr('title','Unknown user?!');
                    }
                    if ( inner_text === 'UNDEF' ){
                        $(this).parent().parent('tr').remove();
                    }
                    // Add context menu
                    var _username = $(this).parent().parent('tr').children('td[abbr="username"]').children('div').text();
                    _username = _username.replace(/^(.*)<span class="inner_flexi_text">on<\/span>$/gi, "$1");
                    $(this).addClass('context-menu-one box menu-1')
                           .css('cursor','cell').attr('parent', _username );
                });
               /*
                * we match the username from online_data
                * to the current tr.td[abbr=username].div.text in the loop
                * inner_text is in order to get only the username and not
                * any span we might have appended previous loop
                */
                var inner_text = v.innerHTML.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                var online_data = $.Client().checkClientsMatch(r.rest.clients, inner_text);
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
                                       .text( online_data[i] ).css('color','#000000');
                            }
                        }
                        // mark the row which has been found to be online
                        if ( ! $(this).children('span.inner_flexi_text').is(':visible') ){
                            $(this).append('<span class="inner_flexi_text">on</span>');
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
                // Update the table
                $('.pReload').click();
            }
        },
        //
        // Block / Unblock client(s)
        //
        blockUnblockClients: function (button, grid, action){
            if ( action === undefined ){
                action = button.match(/unblock/i) ? 'unrevoke' : 'revoke'; 
            }

            // Get total selected clients
            var total_count = $('.trSelected', grid).length;
            if ( window.DEBUG ) log ("Total selected clients: " + total_count);
            var processed = 0;
            var loop = 0;
            var _clients = '';
            $.each($('.trSelected', grid), function() {
                // Get the client's name of this grid
                var client = $('td:nth-child(2) div', this).html();
                var _tr = this;
                // Get rid of any html
                client = client.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                _clients += client + ',';
                loop++;
            });

            // return if no selected clients
            if ( loop == 0 ) return;

            // Revoke client/disconnect
            $.Ovpnc().setAjaxLoading();

            $.ajax({
                url: '/api/clients',
                type: action,
                cache: false,
                timeout: 5000,
                data: { _ : '1', clients: _clients },
                dataType: 'json',
                success: function (msg) {
                    if ( window.DEBUG ) log("block/unblock returned: %o",msg);
                    var _data_types = {
                        errors:      $.Ovpnc().alertErr,
                        warnings:    $.Ovpnc().alertIcon,
                        status:      $.Ovpnc().alertOk
                    };
                    if ( msg.rest !== undefined ) {
                        $.Ovpnc().processAjaxReturn( msg.rest, _data_types );
                        $('.pReload').click();
                        return;
                    }
                    alert( _data_types.errors + ' ' + msg + '</div><div class="clear"></div>' );
                    $('.pReload').click();

                },
                error: function ( xhr, textStatus, errorThrown ) {
                    if ( window.DEBUG ) log("block/unblock returned error: %o", xhr);
                    alert( $.Ovpnc().alertErr + ' Backend returned error: ' + xhr.statusText + '</div><div class="clear"></div>' );
                },
                complete : function(){
                    $.Ovpnc().removeAjaxLoading();
                }
            });
        },
        //
        // Check if client names match
        //
        checkClientsMatch: function(clients, current_client) {
            for (var i in clients) {
                if (clients[i].name === current_client) return clients[i];
            }
            return false;
        },
        //
        // Check if a series of ajax calls completed
        //
        checkCompleteBlock: function(loop, processed, total_count, action){
            if ( processed === total_count ){
                alert($.Ovpnc().alertInfo
                        + ' Total ' + processed
                        + ' client' + ( processed === 1 ? ' ' : 's ' )
                        + action + 'd</div><div class="clear"></div>' );
                // Update the table
                $('.pReload').click();
                return;
            }
            if ( loop === total_count ){
                $('.pReload').click();
                if ( processed === 0 ){
                    if ( total_count > 1 )
                        alert( $.Ovpnc().alertIcon + ' No clients ' + action + 'd!</div><div class="clear"></div>' );
                }
                else {
                    alert( $.Ovpnc().alertIcon + ' Only ' + processed + ' out of ' + total_count + ' clients ' + action + 'd</div><div class="clear"></div>' );
                }
            }
        },
        //
        // Process error returned from client delete
        //
        clientDeleteError: function (e){
            if ( e.responseText !== undefined ){
                var msg = jQuery.parseJSON( e.responseText );
                var _msg;
                if ( msg.rest && msg.rest.error ) {
                    _msg = msg.rest.error;
                }
                else if ( msg.rest && msg.rest.status ){
                    _msg = msg.rest.status;
                }
                else if ( msg.rest && msg.rest.status ){
                    _msg = msg.rest.status;
                }
                else if ( msg.status ){
                    _msg = msg.status;
                }
                else if ( msg.error ){
                    _msg = msg.error;
                }
                alert( $.Ovpnc().alertErr + ' Client'+(total_count>1?'s':'')+' failed delete: ' + _msg + '</div><div class="clear"></div>' );
            }
            else {
                alert( $.Ovpnc().alertErr + ' Error: No clients deleted!</div><div class="clear"></div>' );
            }
        },
        //
        // Process success returned from client delete
        //
        clientDeleteReturn: function (r){
            if ( r.rest.resultset !== undefined ) {
                var rs = r.rest.resultset;
                if ( rs.errors !== undefined && rs.errors.length > 0 ){
                    var _errors = rs.errors;
                    for ( var e in _errors ){
                        log(e);
                        alert( $.Ovpnc().alertErr + ' ' + _errors[e] + '</div><div class="clear"></div>' );
                    }
                }
    
                if ( rs.deleted !== undefined  ){
                    if ( rs.deleted.length > 0 ){
                        alert($.Ovpnc().alertOk + ' Total ' + rs.deleted.length +' client' + ( rs.deleted.length === 1 ? ' ' : 's ' ) + ' deleted</div><div class="clear"></div>' );
                    }
                    else {
                        alert( $.Ovpnc().alertIcon + ' No clients deleted!</div><div class="clear"></div>' );
                    }
                }

                if ( rs.failed !== undefined && rs.failed.length > 0 ){
                    if ( rs.failed.length != window.clientsToDelete ){
                        alert( $.Ovpnc().alertIcon + ' ' + rs.failed.length + ' out of ' + window.clientsToDelete + ' client'+(total_count>1?'s':'')+' failed delete</div><div class="clear"></div>' );
                    }
                }
                $('.pReload').click();
            }
        },
        //
        // Applt context menu to the flexigrid rows
        //
        applyContextMenu: function (){
            $.contextMenu({
                selector: '.context-menu-one',
                trigger: 'right',
                delay: 500,
                autoHide: true,
                callback: function(key, options) {
                    var elem = options.$trigger;
                    if ( window.DEBUG ) log(key);
                    var client = elem.context.getAttribute("parent");
                    if ( key.match(/block|unblock/i) ){
                        $.Client().blockUnblockClients(key, $('.flexigrid'));
                    }
                    else if ( key.match(/delete/i) ){
                        deleteClient(key, $('.flexigrid'));
                    }
                    else if ( key.match(/edit/i) ){
                        // TODO
                    }
                },
                items: {
                    "properties": {name: "Edit", icon: "edit"},
                    "delete": {name: "Delete", icon: "delete"},
                    "sep1": "---------",
                    "block": {name: "Block", icon: "block"},
                    "unblock": {name: "Unblock", icon: "unblock"}
                }
            });
            $('.context-menu-one').on('click', function(e){
                if ( window.DEBUG ) log('clicked', this);
            });
        },
        //
        // Redirect to clients/add
        // 
        addClient: function () {
            window.location = '/clients/add';
        },
        //
        // Delete a client
        // 
        deleteClient: function (button, grid){
            // Get total selected clients
            var total_count = $('.trSelected', grid).length;
            var _loop = 0;
            var _clients = '';
            $.each($('.trSelected', grid), function() {
                // Get the client's name of this grid
                var client = $('td:nth-child(2) div', this).html();
                // Get rid of any html tags, extract the name.
                client = client.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                _clients += client + ',';
                _loop++;
            });
            // Return nothing if none selected
            if ( _loop == 0 ) return;
            // Confirm delete
            var cnf = confirm('Are you sure you want to delete ' + total_count + ' client' + ( total_count > 1 ? 's?' : '?' ) );
            if ( cnf == false ) return false;
            // Execute
            //( url, data, method, success_func, error_func, loader, timeout, retries, cache )
            window.clientsToDelete = total_count;
            $.Ovpnc().ajaxCall({
                url: "/api/clients/",
                data: { clients: _clients, _ : '1' },
                method: 'REMOVE',
                success_func: $.Client().clientDeleteReturn,
                error_func: $.Client().clientDeleteError,
                loader: 1,
                timeout: 15000
            });
        }

    };

})(jQuery);

function blockClients(button, grid){
    $.Client().blockUnblockClients(button, grid, 'revoke');
}

function unblockClients(button, grid){
    $.Client().blockUnblockClients(button, grid, 'unrevoke');
}
