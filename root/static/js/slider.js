$.Ovpnc.user_data = new Object();
function slide(nav_id, pad_out, pad_in, time, multiplier)  
{  
    var li_elem = nav_id + " li.sliding-element";  
    var links = li_elem + " a";  
    // initiates the timer used
	// for the sliding animation  
    var timer = 0;  
	if ( $.cookie( 'Ovpnc_User_Settings' ) === null ){
		$.Ovpnc.user_data = { already_animated: 1 };
	    $.cookie( "Ovpnc_User_Settings", JSON.stringify( $.Ovpnc.user_data ), { expires: 30, path: '/' } );		
	    // creates the slide animation for all list elements  
	    $(li_elem).each(function(i)  
	    {  
			// Remove earlier tab selections
			$(this).css('font-weight','normal');
	        // margin left = - ([width of element] + [total vertical padding of element])  
	        $(this).css("margin-left","-180px");  
	        // updates timer  
	        timer = (timer*multiplier + time);  
	        $(this).animate({ marginLeft: "0" }, timer);  
	        $(this).animate({ marginLeft: "15px" }, timer);  
	        $(this).animate({ marginLeft: "0" }, timer);  
	    });  
	}
    // creates the hover-slide effect for all link elements  
    $(links).each(function(i){  
        $(this).hover(  
        function(){  
            $(this).animate({ paddingLeft: pad_out }, 150);  
        }, function() {  
            $(this).animate({ paddingLeft: pad_in }, 150);  
        });  
    });  
	$.Ovpnc().set_select_tab(li_elem);
}  
