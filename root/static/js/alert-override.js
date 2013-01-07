/*
 * Override the default alert
 * Used to display messages
 * to user on the message div
 */
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
    // Calculate the max height
    // which the message div can be
    var outerCenteredOffset     = $('#outer_centered').offset(),
        messageContainerOffset  = $('#message_container').offset(),
        limitOffset             = ( outerCenteredOffset.top - 10 ) - messageContainerOffset.top;

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
            stop : function () {  window.resized = 1 },
        });

        $('#message').css({
            'max-height': limitOffset + 'px',
            'cursor': 'move'
        });
    }

    if ( window.firstAlertPassed !== undefined ){
        if ( window.DEBUG) log( 'first alert passed' );
        // Bind a double click to close it
        $('#message').dblclick(function(){
            $('#message_container').hide(300);
            $('#message_content').remove();
        });
        $('#message').draggable().mousedown(function(){
        	$(this).css('cursor','move');
        }).mouseup(function(){
        	$(this).css('cursor','cell');
        });
    }

    if ( window.applied_message_context === undefined ) {
        applyMessageContext();
        $('#message_container').addClass('context-menu-two box menu-1');
    }

    // Show the message container
    if ( $('#message_container').is(':hidden') ) {
        $('#message_container').slideDown(300);
    }

    return false;
};

/*
 * Add a context menu to the message div
 */
function applyMessageContext (){
    window.applied_message_context = 1;

    $.contextMenu({
        selector: '.context-menu-two',
        trigger: 'right',
        delay: 500,
	    autoHide: true,
	    callback: function(key, options) {
	        var elem = options.$trigger;
	        if ( window.DEBUG ) log(key);
	        
	        switch(key.toLowerCase()){
            	case "remember":
	        		if ( window.DEBUG ) log('Got remember');
                    rememberLogLines();
	        		break;
	        	case "clear":
	        		if ( window.DEBUG ) log('Got erase');
                    $('#message_container').slideUp(350);
                    $('#message').empty();
	        		break;
	        	case "search":
	        		if ( window.DEBUG ) log('Got search');
	        		break;
	        	case "close":
	        		if ( window.DEBUG ) log('Got close');
                    $('#message_container').slideUp(350);
	        		break;
	        } 		
	    },		
	    items: {
	        //"Remember":     { name: "Remember",     icon: "remember"    },
	        "clear":        { name: "Clear All",    icon: "clear"       },
	        //"find":         { name: "Find",         icon: "search"      },
	        //"sep1":         "---------",
	        "Close":        { name: "Close",        icon: "close"       },
	    }
    });
}

function rememberLogLines(){
    
}
