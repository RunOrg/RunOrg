// Asynchronous operations. 
//
// This module contains a handful of functions related to promises and thenables. 
 
var Async = (function() {
   
    // Returns true if an object is 'thenable' (it has a 'then' member
    // function). 
    function isThenable(obj) { 
	return typeof obj == 'object' && obj !== null && 'then' in obj;
    }

    // Returns a promise that waits for all promises inside the passed object
    // to return with a result. The provided value is also modified in-place
    // so that all promises are replaced with their concrete values.  
    function wait(value) {

	if (isThenable(value)) return value;

	var self = $.Deferred().resolve(value).promise();

	if (typeof value == "object") {

	    var deferred = [ self ];

	    if ('each' in value) {

		value.each(function(e,i) {
		    deferred.push(wait(e).then(function(v) { value[i] = r; }));
		}); 

	    } else {
		
		for (var k in value) {
		    if (!value.hasOwnProperty(k)) continue;
		    (function(k) {
			deferred.push(wait(value[k]).then(function(v) { value[k] = v; }));
		    })(k);
		}

	    }
	
	    return $.when.apply($, deferred)
	        // Keep only the first deferred argument.
		.then(function(a) { return a; });
	}

	return self;
    }
    
    return {
	isThenable : isThenable,
	wait       : wait
    };

})();