// The query module returns connections, and connections are 
// used to perform queries against the server. 

var Query = (function(){

    // Utility. Appends query parameter to URL. 
    function addParameter(url, key, value) {
	return url + (/\?/.exec(url) ? '&' : '?') + key + '=' + value;
    }

    function Connection() {	
	this._clock = null;
    }

    Connection.prototype = {

	// Running a query and returns a promise representing the result. 
	// The promise is similar to the jQuery result, except that it never
	// fails because of a 4xx status.
	//
	// This is the meat of the connection class, most other methods 
	// simply forward calls to this one.	
	//
	// All parameters are expected to be synchronous values. 
	query: function(verb, url, data, auth) {

	    var self = this;

	    auth = auth || {};
	    var token = auth.token, as = auth.id;

	    if (!/^\//.exec(url)) url = "/" + url;
	    if (as) url = addParameter(url, 'as', as);
	    if (this._clock) url = addParameter(url, 'at', this._clock);

	    var promise = $.ajax({
		url: url,
		type: verb, 
		dataType: 'json',
		contentType: 'application/json',
		data: (verb == 'PUT' || verb == 'POST') ? JSON.stringify(data) : {},
		beforeSend: function(xhr) {
		    if (token) xhr.setRequestHeader('Authorization', 'RUNORG token=' + token);
		}
	    });

	    promise.then(function(data,status) {
		if (status != 'success' || ! ('at' in data)) return;

		var c = self._clock ? JSON.parse(self._clock) : {}, at = data.at;

		// Merge the new clock value with the old one
		for (var k in at)
		    if (!(k in c) || c[k] < at[k])
			c[k] = at[k];
		
		self._clock = JSON.stringify(c);
	    });

	    // Use a 'bounce' deferred to hide errors.
	    var result = $.Deferred();

	    promise.always(function(a,status,b) {
		var xhr  = ('responseJSON' in a) ? a : b;
		var data = xhr.responseJSON;
		result.resolve(data, status, xhr);
	    });

	    return $.extend(result.promise(),Assert.extensions);
	},

	// Like 'query', but applies Async.wait to all parameters (except the verb).
	// If the URL is an array (or has a join function), uses url.join(''). 
	queryAsync: function(verb,url,data,auth) {
	    var self = this;
	    var promise = $.when(Async.wait(url),Async.wait(data),Async.wait(auth))
		.then(function(url,data,auth) { 
		    if (typeof url === "object" && url && 'join' in url) url = url.join('');
		    return self.query(verb,url,data,auth); 
		});
	    return $.extend(promise,Assert.extensions);
	},

	// Performs a GET request
	get: function(url,auth) {
	    return this.queryAsync("GET",url,null,auth);
	},

	// Performs a PUT request
	put: function(url,data,auth) {
	    return this.queryAsync("PUT",url,data,auth);
	},

	// Performs a POST request
	post: function(url,data,auth) {
	    return this.queryAsync("POST",url,data,auth);
	},

	// Performs a DELETE request
	del: function(url,auth) {
	    return this.queryAsync("DELETE",url,null,auth);
	},

	// Authenticate as a server administrator. 
	asServerAdmin: function() {
	    return {
		token: this.post("test/auth",{}).then(function(r){ return r.token; }),
		id:    void(0)
	    };
	},

	// Create a brand new database and return the id. 
	mkdb: function() {
	    var auth = this.asServerAdmin();
	    return this.post("db/create",{label:"Test database " + new Date()},auth)
		.then(function(r) { return r.id; });
	},

	// Authenticate with a specific database
	auth: function(db,admin,email) {

	    var result = this.post(["db/",db,"/test/auth"],{
		email : (email || void(0)),
		admin : (admin === false ? false : true)
	    }).always(function(data) { return data; })

	    return {
		token : result.then(function(r) { return r.token; }),
		id    : result.then(function(r) { return r.id; })
	    };
	}
    };

    return {
	create: function() { return new Connection(); }
    };

})();

