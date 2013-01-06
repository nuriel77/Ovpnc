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
                    { display: 'Locked',    name : 'locked',        width: 25, sortable : true, align: 'left' },
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
                    { name: 'Add',          bclass: 'add', onpress : $.Certificate().addCertificate },
                    { name: 'Delete',       bclass: 'delete', onpress : $.Certificate().deleteCertificate },
                    { name: 'Revoke',       bclass: 'block', onpress : blockCertificates },
                    { name: 'Unrevoke',     bclass: 'unblock', onpress : unblockCertificates },
                    { name: 'Properties',   bclass: 'properties', onpress : test_edit },
                    { name: 'Download',     bclass: 'download', onpress : downloadCertificates },
                    { separator: true },
                    { name: 'Unselect All', bclass: 'unSelectAll', onpress: function (){ $('.bDiv').find('tr').removeClass('trSelected'); } },
                    { name: 'Select All',   bclass: 'selectAll',   onpress: function (){ $('.bDiv').find('tr').addClass('trSelected'); } }
                ],
                searchitems : [
                    { display: 'User',          name : 'user', isdefault: true },
                    { display: 'Created By',    name : 'created_by' },
                    { display: 'Name',      	name : 'name' },
                    { display: 'Type',          name : 'cert_type' },
                    { display: 'Common name',   name : 'key_cn' },
                    { display: 'Expires',       name : 'key_expire' },
                    { display: 'Created',       name : 'created' },
                    { display: 'Modified',      name : 'modified' },
                    { display: 'Revoked',       name : 'revoked' },
                    { display: 'Locked',        name : 'locked' },
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
                height: $(document).height() * 0.45
            });
            $.Ovpnc().styleFlexigrid();
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
                c.id          || 'unknown',
                c.user_id     || 'unknown',
                c.user        || 'unknown',
                c.name        || 'unknown',
                c.created_by  || 'unknown',
                c.cert_type   || 'unknown',
                c.key_cn      || 'unknown',
                c.created     || '0000-00-00 00:00',
                c.modified    || '0000-00-00 00:00',
                c.revoked     || '0000-00-00 00:00',
                c.locked      || 0,
                c.key_size    || '-',
                c.key_expire  || 0,
                c.key_country || '-',
                c.key_province|| '-',
                c.key_city    || '-',
                c.key_org     || '-',
                c.key_ou      || '-',
                c.key_email   || '-',
                c.key_serial  || '-',
                c.key_file    || 'unknown',
                c.cert_file   || 'unknown',
                c.key_digest  || '-',
                c.cert_digest || '-'
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
                $('#ajaxLoaderFlexgridLoading').remove();
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

            if ( obj.rest !== undefined && obj.rest.rows !== undefined ){
                var __rows = new Array();
                var __count = 0;
                for ( var index in obj.rest.rows ){
                    __count++;
                    __rows.push({
                       id: __count,
                       cell: $.Certificate().prepareCertificateColData(obj.rest.rows[index])
                    });
                }
                return {
                    total: obj.rest.total,
                    page:  obj.rest.page,
                    rows:   __rows
                };
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
        // Download Certificates
        //
        downloadCertificates: function (button, grid){
            // Get total selected certificate(s)
            var total_count  = $('.trSelected', grid).length,
                _loop        = 0,
                certificates = '',
                client       = '';

            if ( total_count > 1 ){
                alert( $.Ovpnc().alertErr + ' You may only download one certificate each time</div><div class="clear"></div>');
                return false;
            }

            $.each($('.trSelected', grid), function() {
                // Get the certificates name of this grid
                certificate = $('td:nth-child(4) div', this).html();
                client = $('td:nth-child(3) div', this).html();
                _loop++;
            });

            if ( _loop == 0 ){
                return false;
            }
            window.location.href = '/api/certificates/download/' + client + '/' + certificate + '?format=' + button;
        },
        //
        // Revoke certificate(s)
        //
        blockUnblockCertificates: function (button, grid, action){
            if ( action === undefined ){
                action = button.match(/unblock/i) ? 'unrevoke' : 'revoke';
            }
            // Get total selected certificate(s)

            var total_count = $('.trSelected', grid).length,
                _loop         = 0,
                _certificates = '',
                _serials      = '',
                _clients      = '';

            $.each($('.trSelected', grid), function() {
                // Get the certificates name of this grid
                var certificate = $('td:nth-child(4) div', this).html(),
                    clients     = $('td:nth-child(3) div', this).html(),
                    serials     = $('td:nth-child(20) div', this).html();
                // Get rid of any html tags, extract the name.
                certificate = certificate.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                _certificates += certificate + ',';
                _clients += clients + ',';
                _serials += serials + ',';
                _loop++;
            });

            // Return nothing if none selected
            if ( _loop == 0 ) return;

            var _action = function (passwd) {
                if ( passwd === undefined || passwd == '' ){
                    alert( $.Ovpnc().alertErr + ' No passwd?' );
                    return false;
                }
                // Revoke Certificate(s)
                $.Ovpnc().setAjaxLoading(1);
                $.ajaxSetup({ cache: false, async: true });
                $.ajax({
                    url: '/api/certificates/' + action,
                    type: 'POST',
                    cache: false,
                    timeout: 30000,
                    data: {
                        _ : '1',
                        certificates: _certificates,
                        clients: _clients,
                        serials: _serials,
                        ca_password: passwd,
                    },
                    dataType: 'json',
                    success: function (msg) {
                        if ( window.DEBUG ) log("revoke/unrevoke returned: %o", msg);
                        var _data_types = {
                            errors:      $.Ovpnc().alertErr,
                            warnings:    $.Ovpnc().alertIcon,
                            status:      $.Ovpnc().alertOk
                        };
                        $('.pReload').click();
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
                        window.lock_checked = undefined;
                        $.Ovpnc().removeAjaxLoading();
                        /*
                        var _wait_update_blockUnblock =
                            setInterval(function() {
                                if ( ! $('.loading').is(':visible') ){
                                    $('.pReload').click();
                                    window.clearInterval(_wait_update_blockUnblock);
                                }
                        }, 250 );
                        */
                    }
                });
            };

            var locked_ca = $('#locked_ca');
            if ( locked_ca !== undefined
              && window.lock_checked === undefined
            ){
                $.Certificate().processUnlockDialog( _action, 'blockUnblock' );
                return false;
            }

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
                messages:    $.Ovpnc().alertOk
            };
            if ( r.rest !== undefined ) {
                $('.pReload').click();
                $.Ovpnc().processAjaxReturn( r.rest, _data_types );
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
                    else if ( key.match(/tar|[gb]?zip/) ){
                        $.Certificate().downloadCertificates(key, $('.flexigrid'));
                    }
                },
                items: {
                    "properties":   { name: "Details",   icon: "edit" },
                    "delete":       { name: "Delete",    icon: "delete" },
                    "sep1":         "---------",
                    "block":        { name: "Revoke",    icon: "block" },
                    "unblock":      { name: "Unrevoke",  icon: "unblock" },
                    "download" :    {
                        "name"  : "Download",
                        "icon"  : "download",
                        "items" : {
                            "tar"   :       { name: "tar" },
                            "gzip"  :       { name: "gzip" },
                            "bzip"  :       { name: "bzip" },
                            "zip"   :       { name: "zip" }
                        }
                    }
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
        // Ask user for passwd to unlock Root CA
        //
        processUnlockDialog: function ( _action, confirmDiagName ){
        
            var dDiv = document.createElement('div');
            $( dDiv ).css({
                'display':'none',
                'color'  :'#555555'
            }).attr('id', confirmDiagName );

            $( 'body' ).prepend( dDiv );

            $('#' + confirmDiagName ).dialog({
                 autoOpen: false,
                 title: 'Password required',
                 hide: "explode",
                 modal:true,
                 closeText: 'close',
                 closeOnEscape: true,
                 stack: true,
                 height: "auto",
                 width: "auto",
                 zIndex:9010,
                 position: [ 300, 200 ],
                 buttons: [
                    {
                        text: "cancel",
                        click: function () { $(this).dialog("close").remove(); return false; }
                    },
                    {
                        id: "dialog_submit",
                        text: "ok",
                        click: function () {
                            //window.lock_checked = 1;
                            $(this).dialog('close').remove();
                            _action( $("#ca_password").attr('value') );
                            return false;
                        }
                    }
                 ],
            });

            var aDiv = document.createElement('div'),
                bDiv = document.createElement('div'),
                cDiv = document.createElement('div'),
                fDiv = document.createElement('form'),
                lDiv = document.createElement('label'),
                iDiv = document.createElement('input');

            $( iDiv ).attr({
               id: "ca_password",
               type: "password",
               name: "ca_password",
               autofocus: "autofocus"
            });
            $( lDiv ).attr('for','ca_password').text('Password: ');
            $( fDiv ).append( lDiv ).append( iDiv ).attr({
                action: 'javascript:void(0)',
                onsubmit: "if ( $(this).attr('value') == '' ) return false; $('#dialog_submit').click();"
            });
            $( bDiv ).append( fDiv );
            $( aDiv ).html($.Ovpnc().alertInfo + ' A password is required in order to use the Root CA.').append('<div class="clear"></div>');
            $( cDiv ).append( aDiv ).append( bDiv );

            $('#'+confirmDiagName).dialog('open')
                                  .append( cDiv ).show(200);
            $('.ui-dialog').addClass('justShadow');
            $( aDiv ).css('padding-bottom','8px'); //xxx
            return false;
        },
        //
        // Delete a certificate
        // 
        deleteCertificate: function (button, grid){
            // Get total selected certificate(s)
            var total_count = $('.trSelected', grid).length;

            // Return nothing if none selected
            if ( total_count == 0 ) return;

            var _action = function () {
                window.certificatesToDelete = total_count;
                var _loop         = 0,
                    _certificates = '',
                    _clients      = '',
                    _serials      = '';
                $.each($('.trSelected', grid), function() {
                    // Get the certificates name of this grid
                    var certificate = $('td:nth-child(4) div', this).html(),
                        clients     = $('td:nth-child(3) div', this).html(),
                        serials     = $('td:nth-child(20) div', this).html();
                    // Get rid of any html tags, extract the name.
                    certificate = certificate.replace(/^([0-9a-z_\-\.]+)<.*?>.*$/gi, "$1");
                    _certificates += certificate + ',';
                    _serials += serials + ',';
                    _clients += clients + ',';
                });

                if ( window.DEBUG ) log( "Certificates: " + _certificates + ' clients: ' + _clients + ' serials: ' + _serials );

                var deleteCertAction = function ( passwd ) {
                    $.Ovpnc().ajaxCall({
                        url: "/api/certificates/",
                        data: {
                            _ : '1',
                            certificates: _certificates,
                            clients: _clients,
                            ca_password: passwd,
                            serials: _serials
                        },
                        method: 'DELETE',
                        success_func: $.Certificate().certificateDeleteReturn,
                        error_func: $.Certificate().certificateDeleteError,
                        loader: 1,
                        timeout: 15000
                    });
                };

                var locked_ca = $('#locked_ca');
                if ( locked_ca !== undefined
                  && window.lock_checked === undefined
                ){
                    $.Certificate().processUnlockDialog(deleteCertAction, 'deleteCertificate');
                    return false;
                }
                $.ajaxSetup({ cache: false, async: true });
            };

            $.Ovpnc().confirmDiag({
                message: "<div>" + $.Ovpnc().alertIcon + " Warning!</div><br /></br /><div>" + 'Are you sure you want to delete ' + total_count + ' certificate' + ( total_count > 1 ? 's?' : '?' ) + '</div>',
                action: _action,
                params: { button: button, grid: grid }, //action: 'delete' }
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

function downloadCertificates(button, grid){
    if ( $('.trSelected', grid).length == 0 ) return false;
    var aDiv = document.createElement('div'),
        bDiv = document.createElement('div'),
        cDiv = document.createElement('div');

    $( aDiv ).attr('id', 'formatsDiv');
    $( bDiv ).html( 'Choose a format:<br />' );
    $( cDiv ).attr('id', 'radioGroup');
    $.each ( [ 'tar', 'gzip', 'bzip', 'zip' ], function (i, t){
        var sDiv = document.createElement('div'),
            iDiv = document.createElement('input'),
            lDiv = document.createElement('label');
        if ( i == 0 ) $( iDiv ).attr('checked', 'checked');
        $( iDiv ).attr({
            name: 'format',
            type: 'radio',
            value: t
        });
        $( lDiv ).text(' ' + t);
        $( sDiv ).append( iDiv )
                 .append( lDiv )
                 .addClass('dialog_radiobuttons');
        $( cDiv ).append( sDiv );
    });

    $( aDiv ).append( bDiv ).append( cDiv );

    $.Ovpnc().confirmDiag({
        run_after: function() {
            $('.dialog_radiobuttons').bind('click', function(){
                $('.dialog_radiobuttons').children('input').removeAttr('checked');
                $(this).children('input').attr('checked', 'checked');
            }).hover(function(){
                $(this).css('color','#000090');
            }, function(){
                $(this).css('color','');
            });
        }, 
        message: $( aDiv ).html(),
        title: 'Choose a format',
        buttons: [
                    { 
                        text: "cancel",   click: function () {
                            $(this).dialog("close").remove(); return false;
                        } 
                    },
                    { 
                        text: "Download", click: function () {
                            $.Certificate().downloadCertificates( $('.dialog_radiobuttons').children('input[type="radio"]:checked').attr('value'), grid );
                            $(this).dialog("close");
                            return true;
                        } 
                    }
                ],
    });
}
