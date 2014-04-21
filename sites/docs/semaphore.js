// A semaphore implementation, to prevent more than N threads to run in 
// parallel. 

var Semaphore = (function() {

    // The parameter 'n' is the number of threads allowed to run
    // in parallel. 
    function S(n) {
	this._n = n;
	this._pending = [];
    }

    S.prototype = {
	
	// Runs a promise-returning function, returns the corresponding
	// promise but only starts running it once a free thread is available.
	lock: function(promiseF) {
	    var deferred = $.Deferred();
	    var promise  = deferred.then(promiseF);
	    this._pending.push({deferred:deferred,promise:promise});
	    this._run();
	    return promise;
	},

	// Attempts to run a thread, if any. 
	_run: function() {

	    if (this._pending.length == 0) return;
	    if (this._n <= 0) return;
	    
	    --this._n;
	    var next = this._pending.shift();
	    var self = this;
	    
	    next.deferred.resolve();
	    next.promise.then(function() {
		++self._n;
		self._run();
	    });
	}

    };

    return S;

})();
