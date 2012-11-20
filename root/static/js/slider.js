var user_data = new Object();

function slide(navigation_id, pad_out, pad_in, time, multiplier)  
{  
    // creates the target paths  
    var list_elements = navigation_id + " li.sliding-element";  
    var link_elements = list_elements + " a";  

    // initiates the timer used for the sliding animation  
    var timer = 0;  

	if ( $.cookie( 'Ovpnc_User_Settings' ) === null ){

		user_data = { already_animated: 1 };
	    $.cookie( "Ovpnc_User_Settings", JSON.stringify( user_data ), { expires: 30, path: '/' } );		

	    // creates the slide animation for all list elements  
	    $(list_elements).each(function(i)  
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
    $(link_elements).each(function(i)  
    {  
        $(this).hover(  
        function()  
        {  
            $(this).animate({ paddingLeft: pad_out }, 150);  
        },  
        function()  
        {  
            $(this).animate({ paddingLeft: pad_in }, 150);  
        });  
    });  

	set_select_tab(list_elements);
}  

function set_select_tab(list_elements){

	// Check which page this is
	// then set bolder on the selected
	var pathname = window.location.pathname;
	pathname = pathname.replace('/','');
	if ( pathname == '' ){
		// This is main page
		$('a:contains("Main")').css('font-weight','bold');

	}
	else {
		$(list_elements).each(function(i){
			if ( pathname === $(this).text().toLowerCase() ){
				$(this).css('font-weight','bold');
				return;
			}
		});
	}

}
