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
        // Get server logs
        //
        getServerLogs: function () {
            $.Ovpnc().ajaxCall({
                url: "/api/server/logs",
                data: { time: 1, lines: 2000 },
                method: 'GET',
                success_func: function (d) {
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
            });
        }
    };

})(jQuery);

