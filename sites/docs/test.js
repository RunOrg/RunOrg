var Test = (function() {

    // How many parallel tests ? 
    var semaphore = null;
    var parallel  = 10;

    function T(name,func) {

	// The name/description of this test
	this.name = name;

	// The function used to run this test. Takes a query connection and assert 
	// object as argument, returns a promise. 
	this.func = func;
	
	// Has this test run ? 
	this._ran = false;

	// Has this test failed ?
	this._failed = false;

	// What is the reason for this test's failure ? 
	this._failure = null;

	// Is this test running ?
	this._running = false;
    }

    T.prototype = {

	// Run the test. Call the provided callback when it finishes, regardless
	// of result. 
	run: function(onTestEnd) {

	    var self = this;

	    this._running = true;
	    this._ran     = false;
	    this._failed  = false;
	    this._failure = null;

	    semaphore = semaphore || new Semaphore(parallel);

	    return semaphore.lock(function() {

		var result = self.func.call(null,Query.create());
		
		function success() {
		    self._ran = true; 
                    self._running = false;
		    onTestEnd();		    
		}
		
		function failure(reason) {
		    self._ran = true;
		    self._running = false;
		    self._failed = true;
		    self._failure = reason; 
		    onTestEnd();
		}
		
		if (!(typeof result == 'object' && result && 'then' in result)) 
		    result = $.Deferred().reject("Test did not return promise.");
		
		return result.then(success,failure);

	    });
	},

	// Is this test running ? 
	running: function() { return this._running; },

	// Has this test run ? 
	ran: function() { return this._ran; },

	// Has this test failed ? 
	failed: function() { return this._failed; },

	// Why did this test fail ? 
	failure: function() { return this._failure; }

    };

    return T;

})();