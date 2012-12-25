window.alert = function(message) {
    var msgContent         = document.createElement('div'),
        msgContentTime     = document.createElement('div'),
        msgImage           = document.createElement('img'),
        iDiv               = document.createElement('div');

    window.firstAlertPassed = 1;

    // Create time div element
    $( msgContentTime ).css('float','left')
                       .text('[' + get_time() + ']');
    // Prepend time and message to message content div
    $( msgContent ).attr('class', 'message_content')
                   .prepend( msgContentTime )
                   .append( message );

    // Check if message is already visible,
    // If yes, save current content and append
    if ($('.message_content').is(':visible')) {
        // Remove first welcome message.
        var old_content = $('.message_content').text();
        if (old_content.match(/Hello/g) || old_content === message) {
            $('.message_content').empty();
        } else {
            message += '' + $('#message_content').html();
        }
    }
    // Populate the message div
    $('#message').prepend( msgContent );

    if ( ! $('#message_close').is(':visible') ){
        // Create img element
        $( msgImage ).addClass('hand_pointer')
                     .attr('id','message_close')
                     .attr('src','/static/images/close-gray.png');
        // Contain image in div
        $( iDiv ).html( msgImage );
        $('#message_container').append( iDiv );
    }

    // Calculate the max height
    // which the message div can be
    var outerCenteredOffset = $('#outer_centered').offset();
    var messageContainerOffset = $('#message_container').offset();
    var limitOffset = ( outerCenteredOffset.top - 10 ) - messageContainerOffset.top;
    
    // If the message div becomes too high
    // we limit its height and make
    // it ui-resizable.
    if ( $('#message').height() >= limitOffset
      && window.resized === undefined
    ){
        $('#message').resizable({
            //animate: true,
            //animateEasing: "easeOutBounce",
            grid: [ 10, 10 ],
            //helper : "resizable-helper",
            start : function () { $('#message').css('max-height', '') },
            stop : function () {  window.resized = 1 }
        });
        $('#message').css('max-height', limitOffset + 'px');
    }

    if ( window.firstAlertPassed !== undefined ){
        // Bind a double click to close it
        $('#message').dblclick(function(){
            $('#message_container').hide(300);
            $('#message_content').remove();
        });
    }
    // Show the message container
    if ( $('#message_container').is(':hidden') ) {
        $('#message_container').slideDown(300);
    }
    return false;
};

