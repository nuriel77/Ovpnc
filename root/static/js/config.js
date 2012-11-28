/* ovpnc_config js lib */
$(document).ready(function() {
	var doneR = new Array();

	// Disable checkboxes -> create
	add_remove_boxes();

	// Index the push directives
	index_push_string();

	// When disable checkbox is clicked
	$('.rmv').click(function(event){
		disable_clicked(this.id);
	});

	// When form is submitted
	$('form[name="configuration"]').submit(function(e){
		e.preventDefault();
		
		var inputs = $("form#conf :input");

		// Parse the input fields
		var appender = Object();
		var disabled = Array();
		var collected_errors = Array();
		inputs.each(function(i,n){

			if (n.type === "checkbox" && n.checked !== false){
				disabled.push(n.name);
			}
		
			if ( ! n.value.match(/[\w+|\/]/g) && n.name !== 'Send' && n.name !== ''){
				alert( "Empty value in " + n.name );
				$(this).css("border","2px dotted red").css('background-color','red').focus().bind("keyup",(function() {
					$(this).css('border', '0').css('background-color','').unbind("keyup");
					return false;
				}));
				collected_errors.push ( "Empty value in " + n.name );
				return false;
			}

			// Make sure its not disabled
			if ( n.type !== "checkbox" && n.value !== "" ){

				// Check if same name exists
				var c = check_dup(appender, n.name);
				if ( c !== false ){
					n.name += '_' + c;
				}

				// Get the parent node name
				var parent = n.getAttribute('parent');

				// Get the group_id name, was attached to the 'tr'
				var group_id = $('tr#' + n.name).attr('group');

				// Assign 0 to non-group elements
				if (group_id === undefined) group_id = '-1';

				// Append a disabled flag if disabled
				var d_flag = check_disabled(disabled, n.name)
						? '_disabled'
						: '';

				/* Note the format in which the values are being processed: */
				appender[ group_id + '_' + parent + '_' + n.name + d_flag  ] = n.value;
			} 
			else {
				//console.log( n.name + " is disabled");
			}

        });


		// Define our ajax function
		$.postCONFIG = function(url, data) {
		    return jQuery.ajax({	
			    headers: { 'Accept': 'application/json' },
				async : false,
				type:'POST',
			    url: url,
				data : data,
				timeout: 5,
				tryCount : 0,
			    retryLimit : 3,
				cache: false,
			    dataType: 'json',
				//beforeSend: function(){
				//	console.log( "At retry loop " + this.tryCount );
				//},
		        success: function(response){
					if ( response.rest.status !== undefined ){
						alert( response.rest.status );
						return false;
					}
					if ( response.error !== undefined ){
						var element = response.error.replace(/.*<(.*)>.*/gi, "$1");
						element = element.replace(/(\r\n|\n|\r)/gm,"");
						//console.log("Element: " + element);
						mark_span_text(element);
						alert(response.error);
						return false;
					}
	         	},
			    error : function (xhr, ajaxOptions, thrownError){  
					var temp = thrownError.toString();
					if ( xhr.status && xhr.status == "400" ){
						if ( xhr.responseText ){
							var err = jQuery.parseJSON(xhr.responseText);
							if ( err.rest.error !== undefined ){
								alert( err.rest.error );
								return false;
							}
						}
						alert("Form submission error: " + xhr.responseText
							+ ", Code: " + xhr.status + ", " + thrownError.toString());
						return false;
					}
					if ( temp.match(/NETWORK_ERR/) || ajaxOptions == 'timeout' ){
						this.tryCount++;
						if (this.tryCount <= this.retryLimit) {
							console.log( "Going to retry connection to host loop: " + this.tryCount);
		    	            //try again
		        	        $.ajax(this);
		            	    return;
			            }            
				        alert("Timeout error! No response from server.\r\n" + "\r\n" + thrownError);
			            return;
					}
			        alert("Form submission error: " + xhr.status + "\r\n" + thrownError);
				    return false;
			    }
			})
    	};

		if ( collected_errors.length == 0 ){
			// POST
			$.postCONFIG(
				$("form#conf").attr('action'), // The location to post to
				appender // The params
			);
		}

		return false;

	});

	function disable_clicked(o){
		var this_tr = $('#'+o).closest('tr');
		if ( this_tr.attr('ref') !== 'off' ){
			this_tr.css('text-decoration','line-through')
				   .attr('ref','off')
				   .css('color','lightgray')
				   .children('td').css('text-decoration','line-through')
				   .children('td').css('color','lightgray');
			$('input[value="' + o + '"]').css('color','lightgray').css('text-decoration','line-through');
			$('input#'+o + '[type="text"]').prop('readonly','on').css('color','lightgray');
			$('select#'+o).attr('disabled','disabled');
			$('input#'+o).attr('checked', true);
		} else {
			this_tr.css('text-decoration','none')
				   .attr('ref','on')
				   .css('color','')
				   .children('td').css('text-decoration','none')
				   .children('td').css('color','');
			$('input#'+o).css('color','');
			$('input[value="' + o + '"]').css('color','').css('text-decoration','none');
			$('input#'+o + '[type="text"]').removeProp('readonly').css('color','');
			$('select#'+o).removeAttr('disabled');
			$('input#'+o).attr('checked', false);
		}
	}

	function add_remove_boxes(){

		$(document).find('*[required]').each(function(index){
			var op = this.id;
			//console.log("Ob: %o",op);
			//return;
			if (op == 'server' || op == 'management port') return;
			for (var i = 0;i<doneR.length;i++){
				if (op === doneR[i])
					return;
			}
			$('td#'+op).html(
				'<span class="rmv msg disb" id="'+op+'" name="'+op+'" >'
			  + '<input type="checkbox" id="' + op + '" name="'+op+'" />disable</span>'
			);
			doneR.push(op);
		});

		$(document).find('*[alone]').each(function(index){
			var op = this.id;
			for (var i = 0;i<doneR.length;i++){
				if (op === doneR[i])
					return;
			}
			$('td#'+op).html(
				'<span class="rmv msg disb" id="'+op+'" name="'+op+'" >'
			  + '<input type="checkbox" id="' + op + '" name="'+op+'" />disable</span>');
			doneR.push(op);
		});

		// Check boxes which mode is 0 (disabled)
		$('input[type=checkbox]').each(function () {
			var this_tr = $(this).closest('tr');
			if ( this_tr.attr('status') !== "1" ){
				//this_tr.children('td').css('background-color','red');
				disable_clicked(this.id);
			}
		});
	}

	// Find all id 'push' and
	// index them for proper
	// submission
	function index_push_string(){
		var i = 0;
		$(document).find('tr[id="push"]').each(function(index){
			$(this).attr("id", "push_"+i);
			i++;
		});

		i = 0;
		$(document).find('input[id="push"][type="checkbox"]').each(function(index){
			$(this).attr("name", "push_"+i)
				   .attr("id", "push_"+i);
			i++;
		});

		i = 0;
		$(document).find('input[id="push"]').each(function(index){
			$(this).attr("name", "push_"+i)
				   .attr("id", "push_"+i);
			i++;
		});

		i = 0;
		$(document).find('td[id="push"]').each(function(index){
			$(this).attr("id", "push_"+i);
			i++;
		});
		i = 0
		$(document).find('span[id="push"]').each(function(index){
			$(this).attr("id", "push_"+i);
			i++;
		});;
	}

});

function check_dup(arr,item){
	var dup = 0;
	$.each(arr, function(key){
		var real = key.replace(/^.*?_(.*?)$/g, "$1");
		if (real.match(/push_[0-9]/)) return false;
		//console.log("REal: " + real);
		if (real === item) dup++;
	});
	if (dup == 0){
		return false;
	}
	else {
		return dup;
	}
}

function check_disabled(arr, item){
	if (arr.length === false || arr.length == 0 ) return false;
	for (var i=0 ; i < arr.length ; i++){
		if (arr[i] === item) return true;
	}
	return false;
}			

function mark_span_text(e){
	$("span").each(function(index, elem){
		console.log("compare " + e + " with " + $(this).text());
		if ( $(this).text() === e ){
			console.log("Found Match: " + e);
			$('input[parent="' + e + '"]').css('color', 'red')
										  .css('border','2px dotted red')
										  .bind("keyup",(function() {
				$(this).css('border', '0').css('color','').unbind("keyup");
				return false;
			}));
			return false;
		}
	});
}
