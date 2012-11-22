$(document).ready(function(){

	// Disable submit if empty
	$('form').submit(function(event){
		if ( ! $('#username').attr('value').match(/\w+/) ){
			event.preventDefault();
			$('#username').focus();
			return false;
		}
		else if ( ! $('#password').attr('value').match(/\w+/) ){
			event.preventDefault();
			$('#password').focus();
			return false;
		}
		else {
			return true;
		}
		return;
	});

	// Show warnings div if content
	if ( $('#warnings').text() !== '' ){
		$('.warning').show(300);
	}

});
