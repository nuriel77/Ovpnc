/*
 * Logs class
 */

(function($) {

    // Create Logs namespace
    $.Logs = function(options) {
        var obj = $.extend({},
        mem, actions );
        return obj;
    };

    var mem = {
        loop:  0,
        total_count: 0
    };

    var actions = {
		//
        // Set the Flexigrid table
        //
        setLogsTable: function(url) {
        	$.ajaxSetup({ cache: false, async: true });
            $('#flexme').flexigrid({
                url: url,
                data: { lines: 2000, sortname: 'time', sortorder: 'asc' },
                dataType: 'json',
                method: "GET",
                preProcess: $.Logs().formatLogsResults,
                colModel: [
                // TODO: Save table proportions in cookie
                    { display: 'ID',        name : 'id',         width : 25,  sortable : false, align: 'center' },
                    { display: 'Timestamp', name : 'time',       width : 160, sortable : true, align: 'left' },
                    { display: 'Message',   name : 'message',    width : ( $(document).width() - 240 ), sortable : true, align: 'left'}
                ],
                buttons : [
                    { name: 'Edit',         bclass: 'edit', 	onpress : $.Logs().addCertificate },
                    { name: 'Delete',       bclass: 'delete', 	onpress : $.Logs().deleteCertificate }
                ],
                searchitems : [
                    { display: 'ID',          	name : 'id' },
                    { display: 'Time',    		name : 'time', isdefault: true  },
                    { display: 'Message',      	name : 'message' },
                ],
                sortname: "time",
                sortorder: "asc",
                usepager: true,
                title: 'Logs',
                useRp: true,
                rp: 25,
                errormsg: 'No results',
                showTableToggleBtn: false,
                //width: $(document).width() - 30,
                height: $(document).height() - 220
            });
            $.Ovpnc().styleFlexigrid();
        },
        //
        // Prepare logs data for flexigrid
        //
        prepareLogsColData: function (c){
            return [
                c.id          || 'unknown',
                c.time	      || 'unknown',
                c.message     || 'unknown',
            ]
        },
        //
        // process only the certificate array
        //
        formatLogsResults: function (obj){
            if ( window.DEBUG ) log ("Flex got logs: %o", obj);
            
            var _wait_update_flexigrid =
                setInterval(function() {
                    if ( window.DEBUG ) log('Waiting for flexigrid');
                    if ( $('#flexme').is(':visible') ) {
                        if ( window.DEBUG ) log('stop flexigrid update check');
                        $('#ajaxLoaderFlexgridLoading').remove();
                        window.clearInterval(_wait_update_flexigrid);
                    }
                    $.Logs().updateFlexgrid();
            }, 250 );
			
            if ( obj.rest !== undefined && obj.rest.rows !== undefined ){
            	var __rows = new Array();
                var __count = 0;
                for ( var index in obj.rest.rows ){
                    __count++;
                    __rows.push({
                       id: __count,
                       cell: $.Logs().prepareLogsColData(obj.rest.rows[index])
                    });
                }
                return {
                    total: obj.rest.total,
                    page:  obj.rest.page,
                    rows:  __rows
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
        // Get server logs
        //
        getServerLogs: function () {
            $.Ovpnc().ajaxCall({
                url: "/api/server/logs",
                data: { time: 1, lines: 2000 },
                method: 'GET',
                success_func: $.Logs().serverLogsAjaxSuccess()
            });
        },
        //
        // Ajax call to server logs successful
        //
        serverLogsAjaxSuccess: function (d) {
            if ( d.rest !== undefined && d.rest.resultset !== undefined ){
                var logs = d.rest.resultset;
                for ( var i in logs ){
                    $.each (logs[i], function (k, v) {
                        var trDiv = document.createElement('tr');
                        $( trDiv ).html('<td class="left">' + k + '</td><td class="right">' + v + '</td>');
                        $('#logs_table_body').append( trDiv );
                    });
                }
                if ( $('.logs_container').is(':hidden') ){

                    $('.logs_container').slideDown(300);

                    $('#logs_time').click(function(){

                        $('#logs_table_body').slideUp('slow').empty();

                        if ( window.time_sort === undefined ){
                            if ( window.DEBUG ) log('Sort down time clicked');
                            for( var i = logs.length-1 ; i >= 0; i-- ) {
                                $.each (logs[i], function (k, v) {
                                    var trDiv = document.createElement('tr');
                                    $( trDiv ).html('<td class="left">' + k + '</td><td class="right">' + v + '</td>');
                                    $('#logs_table_body').append( trDiv );
                                });
                            }
                            window.time_sort = 1;
                        }
                        else {
                            if ( window.DEBUG ) log('Sort down time clicked');
                            for ( var i in logs ){
                                $.each (logs[i], function (k, v) {
                                    var trDiv = document.createElement('tr');
                                    $( trDiv ).html('<td class="left">' + k + '</td><td class="right">' + v + '</td>');
                                    $('#logs_table_body').append( trDiv );
                                });
                            }
                            window.time_sort = undefined;
                        }

                        $('#logs_table_body').slideDown('slow');
                    });

                }
            }
        }
    };

})(jQuery);

