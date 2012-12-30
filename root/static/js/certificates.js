/* Certificates */

$.Ovpnc().count = 0;
var total_count = 0;

(function($) {

    // Create Certificate() namespace
    $.Certificate = function(options) {
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
        setCertificatesTable: function() {
            $.ajaxSetup({ cache: false, async: true });
            $('#flexme').flexigrid({            
                url: '/api/certificates',
                dataType: 'json',
                method: "GET",
                preProcess: $.Certificate().formatCertificateResults,
                colModel: [
                // TODO: Save table proportions in cookie
                    { display: 'ID',        name : 'id',            width : 15, sortable : false, align: 'right', hide: true },
                    { display: 'UserID',    name : 'user_id',       width : 15, sortable : true, align: 'right', hide: true },
                    { display: 'User',      name : 'user',          width : 85, sortable : true, align: 'left'},
                    { display: 'Name',      name : 'name',          width : 85, sortable : true, align: 'left'},
                    { display: 'Created By',name : 'created_by',    width : 85, sortable : true, align: 'left'},
                    { display: 'Type',      name : 'cert_type',     width : 50, sortable : true, align: 'left'},
                    { display: 'CN',        name : 'key_cn',        width : 85, sortable : true, align: 'left'},
                    { display: 'Created',   name : 'created',       width: 125, sortable : true, align: 'left', },
                    { display: 'Modified',  name : 'modified',      width: 125, sortable : true, align: 'left', hide: true },
                    { display: 'Revoked',   name : 'revoked',       width: 50, sortable : true, align: 'left' },
                    { display: 'Key Size',  name : 'key_size',      width : 45, sortable : true, align: 'right'},
                    { display: 'Expires',   name : 'key_expire',    width : 40, sortable : true, align: 'right'},
                    { display: 'Country',   name : 'key_country',   width : 40, sortable : true, align: 'center'},
                    { display: 'Province',  name : 'key_province',  width : 100, sortable : true, align: 'left' },
                    { display: 'City',      name : 'key_city',      width : 100, sortable : true, align: 'left' },
                    { display: 'Org',       name : 'key_org',       width: 100, sortable : true, align: 'left', hide: true },
                    { display: 'Org Unit',  name : 'key_ou',        width: 100, sortable : true, align: 'left', hide: true },
                    { display: 'Email',     name : 'key_email',     width : 80, sortable : true, align: 'left' },
                    { display: 'Serial',    name : 'key_serial',    width : 50, sortable : true, align: 'left' },
                    { display: 'Key File',  name : 'key_file',      width: 400, sortable : true, align: 'left', hide: true },
                    { display: 'Cert File', name : 'cert_file',     width: 400, sortable : true, align: 'left', hide: true },
                    { display: 'Key MD5',   name : 'key_digest',    width: 240, sortable : false, align: 'right', hide: true },
                    { display: 'Cert MD5',  name : 'cert_digest',   width: 240, sortable : false, align: 'right', hide: true }
                ],
                buttons : [
                    { name: 'Add', bclass: 'add', onpress : $.Certificate().addCertificate },
                    { name: 'Delete', bclass: 'delete', onpress : $.Certificate().deleteCertificate },
                    { name: 'Revoke', bclass: 'block', onpress : blockCertificates },
                    { name: 'Unrevoke', bclass: 'unblock', onpress : unblockCertificates },
                    { name: 'Properties', bclass: 'properties', onpress : test_edit },
                    { separator: true }
                ],
                searchitems : [
                    { display: 'Name',          name : 'name', isdefault: true },
                    { display: 'Created By',    name : 'created_by' },
                    { display: 'Username',      name : 'user' },
                    { display: 'Type',          name : 'cert_type' },
                    { display: 'Common name',   name : 'key_cn' },
                    { display: 'Expires',       name : 'key_expire' },
                    { display: 'Created',       name : 'created' },
                    { display: 'Modified',      name : 'modified' },
                    { display: 'Revoked',       name : 'revoked' },
                    { display: 'Email',         name : 'email' },
                    { display: 'Key Size',      name : 'key_size' },
                    { display: 'Country',       name : 'key_country' },
                    { display: 'Province',      name : 'key_province' },
                    { display: 'City',          name : 'key_city' },
                    { display: 'Serial',        name : 'key_serial' }
                ],
                sortname: "name",
                sortorder: "asc",
                usepager: true,
                title: 'Certificates',
                useRp: true,
                rp: 15,
                errormsg: 'No results',
                showTableToggleBtn: false,
                width: $('#middle_frame').width() - 40,
                height: 400
            });
            $('.bDiv').append('<div id="ajaxLoaderFlexgridLoading">Loading table data... <img src="/static/images/ajax-loader.gif" /></div>');
        },
        //
        // Prepare certificate data for flexigrid
        //
        prepareCertificateColData: function (c){
           /*
            * Some fields need to contain
            * placeholders '-' because they
            * only get updated when server
            * status request returns
            * this keeps flexigrid from
            * messing up the order
            */
            return [
                c.id            ? c.id          : 'unknown',
                c.user_id       ? c.user_id     : 'unknown',
                c.user          ? c.user        : 'unknown',
                c.name          ? c.name        : 'unknown',
                c.created_by    ? c.created_by  : 'unknown',
                c.cert_type     ? c.cert_type   : 'unknown',
                c.key_cn        ? c.key_cn      : 'unknown',
                c.created       ? c.created     : '0000-00-00 00:00',
                c.modified      ? c.modified    : '0000-00-00 00:00',
                c.revoked       ? c.revoked     : '0000-00-00 00:00',
                c.key_size      ? c.key_size    : '-',
                c.key_expire    ? c.key_expire  : 0,
                c.key_country   ? c.key_country : '-',
                c.key_province  ? c.key_province: '-',
                c.key_city      ? c.key_city    : '-',
                c.key_org       ? c.key_org     : '-',
                c.key_ou        ? c.key_ou      : '-',
                c.key_email     ? c.key_email   : '-',
                c.key_serial    ? c.key_serial  : '-',
                c.key_file      ? c.key_file    : 'unknown',
                c.cert_file     ? c.cert_file   : 'unknown',
                c.key_digest    ? c.key_digest  : '-',
                c.cert_digest   ? c.cert_digest : '-'
            ]
        },
        //
        // process only the certificate array
        //
        formatCertificateResults: function (obj){
            if ( window.DEBUG ) log ("Flex got certificates: %o", obj);
            if ( obj.rest !== undefined
              && obj.rest.resultset !== undefined
              && obj.rest.resultset[0] !== undefined
              && obj.rest.resultset[0] == 'No certificates'
            ){
                $('#flexme').find('tr').remove();
                return;
            }

            var _wait_update_flexigrid =
                setInterval(function() {
                    if ( window.DEBUG ) log('Waiting for flexigrid');
                    if ( $('#flexme').is(':visible') ) {
                        if ( window.DEBUG ) log('stop flexigrid update check');
                        $('#ajaxLoaderFlexgridLoading').remove();
                        window.clearInterval(_wait_update_flexigrid);
                    }
                    $.Certificate().updateFlexgrid();
            }, 250 );

            if ( obj.rest !== undefined && obj.rest.length !== undefined ){
                var __rows = new Array();
                var __count = 0;
                for ( var index in obj.rest ){
                    $.Ovpnc().count++;
                    __count++;
                    __rows.push({
                       id: $.Ovpnc().count,
                       cell: $.Certificate().prepareCertificateColData(obj.rest[index])
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
        // Update / modify data in the certificate's table
        //
        updateFlexgrid : function(){
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

            $('#flexme').find('tr').children('td[abbr="name"]')
                        .children('div').each(function(k, v)
            {
                // One more loop to find all neighbor td's
                // set them up with context menu class
                // Add parent name to each so we can easily
                // access / know which name it is when clicking
                // any of the td's
                $(this).parent('td').parent('tr').children('td')
                            .children('div').each( function(z, x){
                    var inner_text = x.innerHTML;
                    // Color unknown certificates in red
                    if ( inner_text === 'unknown' ){
                        $(this).parent().parent('tr')
                                .children('td[abbr="name"]')
                                .children('div')
                                .css('color','#ff0000')
                                .attr('title','Unknown user?!');
                    }
                    if ( inner_text === 'UNDEF' ){
                        $(this).parent().parent('tr').remove();
                    }
                    // Add context menu
                    var _name = $(this).parent().parent('tr')
                                       .children('td[abbr="name"]')
                                       .children('div').text();
                    $(this).addClass('context-menu-one box menu-1')
                           .css('cursor','cell').attr('parent', _name );
                });
            });
        },
        //
        // Revoke certificate(s)
        //
        blockUnblockCertificates: function (button, grid, action){
            if ( action === undefined ){
                action = button.match(/unblock/i) ? 'unrevoke' : 'revoke'; 
            }

            // Get total selected certificates
            var total_count = $('.trSelected', grid).length;
            if ( window.DEBUG ) log ("Total selected certificates: " + total_count);
            var processed = 0;
            var loop = 0;
            var _certificates = '';
            $.each($('.trSelected', grid), function() {
                // Get the certificate's name of this grid
                var certificate = $('td:nth-child(2) div', this).html();
                var _tr = this;
                // Get rid of any html
                certificate = certificate.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                _certificate += certificate + ',';
                loop++;
            });

            // return if no selected certificates
            if ( loop == 0 ) return;

            // Revoke Certificate(s)
            $.Ovpnc().setAjaxLoading();

            $.ajax({
                url: '/api/certificates',
                type: action,
                cache: false,
                timeout: 5000,
                data: { _ : '1', certificate: _certificates },
                dataType: 'json',
                success: function (msg) {
                    if ( window.DEBUG ) log("revoke/unrevoke returned: %o", msg);
                    $('.pReload').click();
                    var _data_types = {
                        errors:      $.Ovpnc().alertErr,
                        warnings:    $.Ovpnc().alertIcon,
                        status:      $.Ovpnc().alertOk
                    };
                    if ( msg.rest !== undefined ) {
                        $.Ovpnc().processAjaxReturn(
                            msg.rest,
                            _data_types
                        );
                    }
                    if ( msg.error !== undefined ){
                        for ( var e in msg.error ){
                            alert( $.Ovpnc().alertErr + ' ' + e + '</div><div class="clear"></div>' );
                        }
                    }
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
        // Check if certificate names match
        //
        checkCertificatesMatch: function(certificates, current_certificate) {
            for (var i in certificates){
                if (certificates[i].name === current_certificate) return certificates[i];
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
                        + ' certificates' + ( processed === 1 ? ' ' : 's ' )
                        + action + 'd</div><div class="clear"></div>' );
                // Update the table
                $('.pReload').click();
                return;
            }
            if ( loop === total_count ){
                $('.pReload').click();
                if ( processed === 0 ){
                    if ( total_count > 1 )
                        alert( $.Ovpnc().alertIcon + ' No certificates ' + action + 'd!</div><div class="clear"></div>' );
                }
                else {
                    alert( $.Ovpnc().alertIcon + ' Only ' + processed + ' out of ' + total_count + ' certificates ' + action + 'd</div><div class="clear"></div>' );
                }
            }
        },
        //
        // Process error returned from certificates delete
        //
        certificateDeleteError: function (e){
            if ( window.DEBUG ) log ( "delete error: %o", e);
            if ( e.responseText !== undefined ){
                var msg = jQuery.parseJSON( e.responseText );
                var _msg;
                if ( window.DEBUG ) log ( "delete error(parsed): %o", msg);
                if ( msg.rest && msg.rest.error ) {
                    _msg = msg.rest.error;
                    alert( $.Ovpnc().alertErr + ' Certificate'+(total_count>1?'s':'')+' failed delete: ' + _msg + '</div><div class="clear"></div>' );
                }
                if ( msg.rest && msg.rest.status ){
                    _msg = msg.rest.status;
                    alert( $.Ovpnc().alertErr + ' Certificate'+(total_count>1?'s':'')+' failed delete: ' + _msg + '</div><div class="clear"></div>' );
                }
                if ( msg.rest && msg.rest.status ){
                    _msg = msg.rest.status;
                    alert( $.Ovpnc().alertErr + ' Certificate'+(total_count>1?'s':'')+' failed delete: ' + _msg + '</div><div class="clear"></div>' );
                }
                if ( msg.status ){
                    _msg = msg.status;
                    alert( $.Ovpnc().alertErr + ' Certificate'+(total_count>1?'s':'')+' failed delete: ' + _msg + '</div><div class="clear"></div>' );
                }
                if ( msg.error ){
                    _msg = msg.error;
                    alert( $.Ovpnc().alertErr + ' Certificate'+(total_count>1?'s':'')+' failed delete: ' + _msg + '</div><div class="clear"></div>' );
                }
            }
            else {
                alert( $.Ovpnc().alertErr + ' Error: No certificates deleted!</div><div class="clear"></div>' );
            }
        },
        //
        // Process success returned from certificate delete
        //
        certificateDeleteReturn: function (r){
            if ( window.DEBUG ) log("certificateDeleteReturn: %o", r);
            var _data_types = {
                errors:      $.Ovpnc().alertErr,
                warnings:    $.Ovpnc().alertIcon,
                messages:     $.Ovpnc().alertOk
            };
            if ( r.rest !== undefined ) {
                $.Ovpnc().processAjaxReturn( r.rest, _data_types );
                $('.pReload').click();
            }
            if ( r.error !== undefined ){
                for ( var i in r.error ){
                    alert( $.Ovpnc().alertErr + ' ' + r.error[i] + '</div><div class="clear"></div>' );
                }
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
                    var certificate = elem.context.getAttribute("parent");
                    if ( key.match(/block|unblock/i) ){
                        $.Certificate().blockUnblockCertificates(key, $('.flexigrid'));
                    }
                    else if ( key.match(/delete/i) ){
                        $.Certificate().deleteCertificate(key, $('.flexigrid'));
                    }
                    else if ( key.match(/edit/i) ){
                        // TODO
                    }
                },
                items: {
                    "properties": {name: "Details", icon: "edit"},
                    "delete": {name: "Delete", icon: "delete"},
                    "sep1": "---------",
                    "block": {name: "Revoke", icon: "block"},
                    "unblock": {name: "Unrevoke", icon: "unblock"}
                }
            });
            $('.context-menu-one').on('click', function(e){
                if ( window.DEBUG ) log('clicked', this);
            });
        },
        //
        // Redirect to certificates/add
        // 
        addCertificate: function () {
            window.location = '/certificates/add';
        },
        //
        // Delete a certificate
        // 
        deleteCertificate: function (button, grid){
            // Get total selected certificate(s)
            var total_count = $('.trSelected', grid).length;
            var _loop = 0;
            var _certificates = '';
            var _clients = '';
            $.each($('.trSelected', grid), function() {
                // Get the certificates name of this grid
                var certificate = $('td:nth-child(4) div', this).html();
                var clients = $('td:nth-child(3) div', this).html();
                // Get rid of any html tags, extract the name.
                certificate = certificate.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                _certificates += certificate + ',';
                _clients += clients + ',';
                _loop++;
            });

            // Return nothing if none selected
            if ( _loop == 0 ) return;

            // Confirm delete
            var cnf = confirm('Are you sure you want to delete ' + total_count + ' certificate' + ( total_count > 1 ? 's?' : '?' ) );
            if ( cnf == false ) return false;

            // Execute
            //( url, data, method, success_func, error_func, loader, timeout, retries, cache )
            window.certificatesToDelete = total_count;
            $.Ovpnc().ajaxCall({
                url: "/api/certificates/",
                data: { certificates: _certificates, _ : '1', clients: _clients },
                method: 'DELETE',
                success_func: $.Certificate().certificateDeleteReturn,
                error_func: $.Certificate().certificateDeleteError,
                loader: 1,
                timeout: 15000
            });
        }

    };

})(jQuery);

function blockCertificates(button, grid){
    $.Certificate().blockUnblockCertificates(button, grid, 'revoke');
}

function unblockCertificates(button, grid){
    $.Certificate().blockUnblockCertificates(button, grid, 'unrevoke');
}
