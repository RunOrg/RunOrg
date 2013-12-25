/* Handles calling the RunOrg API from JavaScript. */

var API = (function(){
   
    var token = null,

        // The clock is stored in JSON serialized format. The corresponding JSON
        // is an array of [stream,pos] integer pairs. 
        clock = null;

    // Generic AJAX function used for sending requests

    function ajax(method,path,data,success) {

	var noBody = (method == 'GET' || method == 'DELETE'), ajax = {

	    // The token is a ready-to-use session authentication digest.
	    beforeSend: function(xhr) {
		if (token) xhr.setRequestHeader('Authorization','RUNORG token=' + token);
	    },

	    dataType: 'json',

	    type: method,

	    url: API.root + path + (clock ? '?at=' + clock : ''),

	    statusCode: {

		// 200 code is always provided by successful GET requests
		200: success,

		// 401 indicates that a valid token is expected but not provided
		401: function() { API.onLoginRequired() },
		
		// 202 code indicates that the request was taken into account,
		// and includes a clock value
		202: function(data) {
		    var c = clock ? JSON.parse(clock) : [], i, j;

		    // Merge the new clock value with the old one
		    for (i = 0; i < data.at.length; ++i) {
			for (j = 0; j < c.length; ++j) 
			    if (c[j][0] == data.at[i][0]) { c[j][1] = data.at[i][1]; break; }
			if (j == c.length) 
			    c.push(data.at[i]);
		    }

		    clock = JSON.stringify(c);
		    success();
		},

	    }
	};

	if (noBody) {
	    ajax.data = data;
	} 

	else {
	    ajax.contentType = 'application/json';
	    ajax.data = JSON.stringify(data);
	}
 	
	$.ajax(ajax);
    }

    return {
	root: "https://runorg.local:4443",
	onLoginRequired: function() {},

	// Runs a POST request and uses the returned token (if any) 
	// for all subsequent requests.
	AUTH: function(p,d,f) { ajax("POST",p,d,function(data) {
	    if ('token' in data) token = data.token;
	    f(data);
	}) },

	GET: function(p,d,f) { ajax("GET",p,d,f) },
	POST: function(p,d,f) { ajax("POST",p,d,f) },
	PUT: function(p,d,f) { ajax("PUT",p,d,f) },
	DELETE: function(p,d,f) { ajax("DELETE",p,d,f) }
    };

})();