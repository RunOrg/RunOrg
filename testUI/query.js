// Queries are sent to the API, and return results available for many things, including 
// examples. Query parameters can be acceptable as futures.

// Extend functions with "map" and "then" methods 
Function.prototype.map = function(applied) {
    var self = this;
    return function(callback) {
	self(function(result){ callback(applied(result)); });
    }
};

Function.prototype.then = function(callback) {
    this(function() { callback() });    
};

// url is an async string function
// data is an async object function (to be converted to JSON)
// token is an async string function
function Query(verb, url, data, token) {

    this.verb = verb;
    this.url = url;
    this.data = data;
    this.token = token;

    // When the request is sent, it will be stored here.
    this.request = null;

    // All functions invoked on the request once it is actually
    // created.
    this.pending = null;
}

Query.prototype = {
    
    send: function(callback) {
	var query = this;
	query.pending = [callback];
	query.token(function(token) {
	    query.url(function(url) {
		if (! /^\//.exec(url)) url = "/" + url;
		query.data(function(data) {
		    data = JSON.stringify(data);
		    Test.ping();
		    query.request = $.ajax({
			url: url,
			type: query.verb,
			dataType: 'json',
			contentType: 'application/json',
			data: (query.verb == "GET" || query.verb == "DELETE") ? {} : data,
			complete: query.pending,
			beforeSend: function() {
			    if (token) xhr.setRequestHeader('Authorization','RUNORG token=' + token);
			}
		    });
		    query.pending = null;
		});
	    });
	});
    },

    always: function() {
	var query = this;
	return function(callback) {
	    if (query.request != null) query.request.always(callback);
	    else if (query.pending != null) query.pending.push(callback);
	    else { query.send(callback);  }
	}
    },

    result: function(path) {
	var query = this,
	    result = query.always().map(function(data,status){
		if (status == "success") return data; 
		Test.fail("Query "+query+" failed.");	    
	    });

	if (!path) return result;
	return result.map(function(data){
	    return eval("(function(x){return x" + path + ";})")(data);
	});
    },

    token: function() {
	return this.result('.token');
    },

    error: function(http,more) {
	var query = this;
	return query.always().map(function(xhr,status){
	    if (status == "success") 
		return Test.fail("Query "+query+" expected to fail");
	    if (xhr.status != http) 
		return Test.fail("Query "+query+" returned invalid status");
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
Query.create = function(verb, url, data, token) {

    if (typeof token == "string" || typeof token == "undefined") 
	token = (function(token){ return function(callback) { callback(token) } })(token);

    if (typeof url == "string") 
	url = (function(url){ return function(callback) { callback(url) } })(url);

    if (typeof url == "object") // An array ! 
	url = (function(url){ return function(callback) { 

	    function loop(i) {
		if (i == url.length) return callback(url.join(''));
		if (typeof url[i] == "string") return loop(i+1);
		url[i](function(seg) { url[i] = seg; loop(i+1); })
	    }

	    loop(0);

	}})(url);

    if (typeof data != "function") {

	// Cleans up a value by instantiating any sub-elements, calls the callback
	// on it when it's done. 
	function cleanup(value,callback) {
	    if (typeof value == "function") return value(callback);
	    if (typeof value == "object") {
		if (Array.isArray(value)) { 

		    function arrayLoop(i) {
			if (i == value.length) return callback(value);
			cleanup(value[i], function(x) {
			    value[i] = x;
			    arrayLoop(i+1);
			});
		    }

		    arrayLoop(0);

		} else {

		    var keys = [];
		    for (var k in value) if (value.hasOwnProperty(k)) keys.push(k);

		    function objectLoop(i) {
			if (i == keys.length) return callback(value);
			cleanup(value[keys[i]], function(x) {
			    value[keys[i]] = x;
			    objectLoop(i+1);
			});
		    }

		    objectLoop(0);
		}
	    }
	    
	    // Only basic types are left
	    callback(value);
	}

	data = (function(data){ return function(callback){ cleanup(data, callback) } })(data);
    }

    return new Query(verb, url, data, token);
}
