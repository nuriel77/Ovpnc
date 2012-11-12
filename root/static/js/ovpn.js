/* ovpn js lib */
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
		inputs.each(function(i,n){
			if (n.type === "checkbox" && n.checked !== false){
				//console.log("Disabled:"+n.checked);
				disabled.push(n.name);
			}

			// Make sure its not disabled
			if ( ! check_disabled(disabled, n.name) && n.type !== "checkbox" && n.value !== "" ){
				// Check if same name exists
				var c = check_dup(appender, n.name);
				if ( c !== false ){
					n.name += '_' + c;
					//console.log("NEW NAME "+n.name);
				}
				var parent = n.getAttribute("parent");
				appender[ parent + '_' + n.name ] = n.value;	
				//console.log( "Appender HAS NOW: %o"  , appender);
			}
			else {
				//console.log("Is disabled");
			}

        });

		//console.log("HERE IS FINAL APPENDER: %o",appender);

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
	             	//console.log(response);
					if (typeof (response.error) !== "undefined"){
						alert(response.error);
						return false;
					}
					alert(response.status);
					return false;
	         	},
			    error : function (xhr, ajaxOptions, thrownError){  
					var temp = thrownError.toString();
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

		$.postCONFIG( $("form#conf").attr('action'), appender );
	    return false;
	});

	function disable_clicked(o){
		//console.log("Got: "+o);
		if ( $('tr#'+o).attr('ref') !== 'off' ){
			$('tr#'+o).css('text-decoration','line-through');
			$('tr#'+o).css('color','gray');
			$('tr#'+o).attr('ref','off');
			$('input#'+o).css('color','lightgray');
			$('input#'+o + '[type="text"]').prop('readonly','on');
			$('input#'+o).attr('checked', true);
		} else {
			$('tr#'+o).css('text-decoration','none');
			$('tr#'+o).css('color','');
			$('tr#'+o).attr('ref','on');
			$('input#'+o).css('color','');
			$('input#'+o + '[type="text"]').removeProp('readonly');
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
