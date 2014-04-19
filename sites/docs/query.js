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

	// Running a query and returns the jQuery deferred object representing the 
	// result. This is the meat of the connection class, most other methods 
	// simply forward calls to this one.	
	//
	// All parameters are expected to be synchronous values. 
	query: function(verb, url, data, auth) {

	    var self = this;

	    auth = auth || {};
	    var token = auth.token, as = auth.as;

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

	    promise.always(function(data,status) {
		if (status != 'success' || ! ('at' in data)) return;

		var c = self._clock ? JSON.parse(self._clock) : [], i, j, at = data.at;

		// Merge the new clock value with the old one
		for (i = 0; i < at.length; ++i) {
		    for (j = 0; j < c.length; ++j) 
			if (c[j][0] == at[i][0]) { c[j][1] = at[i][1]; break; }
		    if (j == c.length) 
			c.push(at[i]);
		}
		
		self._clock = JSON.stringify(c);
	    });

	    return promise;
	},

	// Like 'query', but applies Async.wait to all parameters (except the verb).
	// If the URL is an array (or has a join function), uses url.join(''). 
	queryAsync: function(verb,url,data,auth) {
	    var self = this;
	    return $.when(Async.wait(url),Async.wait(data),Async.wait(auth))
		.then(function(url,data,auth) { 
		    if (typeof url === "object" && url && 'join' in url) url = url.join('');
		    return self.query(verb,url,data,auth); 
		});
	},

	// Performs a GET request
	get: function(url,token,as) {
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

