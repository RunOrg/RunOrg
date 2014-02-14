/* Handles calling the RunOrg API from JavaScript. */

var API = (function(){
   
    // An API object, used to connect to a specific database. 
    function A(root, db) {

	this.db = db;
	this.root = root;
	
	this.token = null;

        // The clock is stored in JSON serialized format. The corresponding JSON
        // is an array of [stream,pos] integer pairs. 
	this.clock = null;
    }

    // Generic AJAX function used for sending requests
    // Used to create the individual request functions as members of
    // the 'A' object (and used above). 

    A.prototype = {

	ajax: function(method,path,data,success) {

	    var self = this, 	        
	        clock = self.clock, 
	        noBody = (method == 'GET' || method == 'DELETE'), 
	        ajax = {

		    // The token is a ready-to-use session authentication digest.
		    beforeSend: function(xhr) {
			if (self.token) xhr.setRequestHeader('Authorization','RUNORG token=' + self.token);
		    },
		
		    dataType: 'json',
		    
		    type: method,
		    
		    url: self.root 
			+ (path.charAt(0) == '/' ? '' : '/db/' + self.db + '/') 
			+ path 
			+ (clock ? '?at=' + clock : ''),
		    
		    statusCode: {

			// 200 code is always provided by successful GET requests
			200: success,

			// 401 indicates that a valid token is expected but not provided
			401: function() { self.onLoginRequired() },
		
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
			    
			    self.clock = JSON.stringify(c);
			    success(data);
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
	},
    
	onLoginRequired: function() {},

	// Runs a POST request and uses the returned token (if any) 
	// for all subsequent requests.
	AUTH: function(p,d,f) { 
	    var self = this; 
	    this.ajax("POST",p,d,function(data) {
		if ('token' in data) self.token = data.token;
		f(data);
	    }) 
	},

	GET: function(p,d,f) { this.ajax("GET",p,d,f) },
	POST: function(p,d,f) { this.ajax("POST",p,d,f) },
	PUT: function(p,d,f) { this.ajax("PUT",p,d,f) },
	DELETE: function(p,d,f) { this.ajax("DELETE",p,d,f) }
    };

    return A;

})();