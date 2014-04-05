// Queries are sent to the API, and return results available for many things, including 
// examples. Query parameters can be acceptable as futures.

// url is an async string function
// data is an async object function (to be converted to JSON)
// token is an async string function
function Query(verb, url, data, token, as)  {

    this.uid = ++Query.uid;
    this.verb = verb;
    this.url = url;
    this.data = data;
    this.token = token;
    this.as = as;

    // When the request is sent, it will be stored here.
    this.request = null;

    // All functions invoked on the request once it is actually
    // created.
    this.pending = null;
}

Query.prototype = {

    toString: function() {
	return this.verb + ' ' + this.usedUrl;
    },
    
    send: function(callback) {

	var query = this;

	// Only run a query once
	if (query.pending) {
	    query.pending.push(callback);
	    return;
	}
	
	query.pending = [getClock,callback];

	// Extract all the asynchronous data.
	query.token(function(token) {
	    query.usedToken = token;
	    query.as(function(as) {
		query.usedAs = as;
		query.url(function(url) {
		    query.data(function(data) {		    
			data = JSON.stringify(data);
			query.usedData = data;		    

		        if (as) url = url + (/\?/.exec(url) ? '&' : '?') + 'as=' + as;			
			if (! /^\//.exec(url)) url = "/" + url;
			if (Query.clock) url = url + (/\?/.exec(url) ? '&' : '?') + 'at=' + Query.clock; 
			query.usedUrl = url;
			
			// Send the request and save it.
			Test.ping();
			query.request = $.ajax({
			    url: url,
			    type: query.verb,
			    dataType: 'json',
			    contentType: 'application/json',
			    data: (query.verb == "GET" || query.verb == "DELETE") ? {} : data,
			    beforeSend: function(xhr) {
				if (token) xhr.setRequestHeader('Authorization','RUNORG token=' + token);
			    }
			}).always(query.pending);
			
			query.pending = null;
		    });
		});
	    });
	});

	function getClock(data,status) {
	    if (status == "success" && "at" in data) {
		var c = Query.clock ? JSON.parse(Query.clock) : [], i, j;

		// Merge the new clock value with the old one
		for (i = 0; i < data.at.length; ++i) {
		    for (j = 0; j < c.length; ++j) 
			if (c[j][0] == data.at[i][0]) { c[j][1] = data.at[i][1]; break; }
		    if (j == c.length) 
			c.push(data.at[i]);
		}
		
		Query.clock = JSON.stringify(c);
	    }
	}
    },

    always: function() {
	var query = this;
	return function(callback) {
	    if (query.request != null) query.request.always(callback);
	    else query.send(callback);
	}
    },

    response: function() {
	return this.always().map(function(fst,status,snd) {
	    return (status == "success") ? snd : fst;
	});
    },

    result: function() {
	var query = this,
	    path = arguments,
	    result = query.always().map(function(data,status){
		if (status == "success") return data; 
		Test.fail("Failed: "+query);	    
	    });

	return result.map(function(data){
	    var original = data;
	    for (var i = 0; data && i < path.length; ++i) data = data[path[i]];
	    if (i != path.length || typeof data == 'undefined') 
		Test.fail("No "+Array.prototype.slice.call(path,0,i).join(".")+" in "+JSON.stringify(original));
	    return data;
	});
    },

    error: function(http,more) {
	var query = this;
	return query.always().map(function(xhr,status){
	    if (status == "success") 
		return Test.fail("Should fail: "+query);
	    if (xhr.status != http) 
		return Test.fail("Expected "+http+": "+query);
	    if (more)
		more(xhr.responseText);		    
	});
    }

};

// url may be: 
//   - a string
//   - an async string function
//   - an array mixing strings and async string functions
// data may be a JSON-convertible object with some pieces being
// async object functions
Query.create = function(verb, url, data, auth) {

    var token = auth ? auth.token : void(0);
    var as = auth ? auth.id : void(0);

    if (typeof token == "string" || typeof token == "undefined") 
	token = (function(token){ return function(callback) { callback(token) } })(token);

    if (typeof as == "string" || typeof as == "undefined") 
	as = (function(as){ return function(callback) { callback(as) } })(as);

    if (typeof url == "string") 
	url = (function(url){ return function(callback) { callback(url) } })(url);

    if (typeof url == "object") // An array ! 
	url = (function(url){ return function(callback) { 

	    function loop(i) {
		if (i == url.length) return callback(url.join(''));
		if (typeof url[i] == "string") return loop(i+1);
		url[i](function(seg) { 
		    url[i] = seg; 
		    loop(i+1); 
		})
	    }

	    loop(0);

	}})(url);

    if (typeof data != "function") {
	data = Async.lift(data);
    }

    return new Query(verb, url, data, token, as);
};

Query.uid = 0;

Query.authAsServerAdmin = function() {
    return {
	token : Query.create("POST","test/auth",{}).result('token'),
	id    : void(0)
    };
};

Query.auth = function(db,admin,email) {
    var r = Query.create("POST",["db/",db,"/test/auth"],{
	email : (email || void(0)),
	admin : (admin === false ? false : true)
    }).result();

    return {
	token : r.map('token'),
	id    : r.map('id')
    };
};

Query.mkdb = function() {
    var token = Query.authAsServerAdmin();
    return Query.create("POST","db/create",{label:"Test database " + new Date()}, token).result('id');
};
