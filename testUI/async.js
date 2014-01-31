// Asynchronous operations
var Async = (function() {

    // Extend functions with "map" and "then" methods 
    Function.prototype.map = function(applied) {
	var self = this;
	return function(callback) {
	    self(function(){ callback(applied.apply(this,arguments)); });
	}
    };
    
    Function.prototype.then = function(callback) {
	this(function() { callback() });    
    };

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
	    
	    return;
	}
	
	// Only basic types are left
	callback(value);
    }
    
    return {
	lift: function(data){ return function(callback){ cleanup(data, callback) } }
    };

})();