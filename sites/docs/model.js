/* Simple model. */

var Test = (function() {

    function Fixture(data) {
	this.verb = data.verb || null;
	this.path = data.path || null;
	this.file = data.file;
	this.categories = data.categories;
	this.description = data.description;
	this.tests = data.tests || 0;

	this.ran = false;
	this.rcount = 0;
	this.failed = [];
    }

    Fixture.prototype = {

	startTesting: function() {	    
	    this.ran = false;
	    this.rcount = 0;
	    this.failed = [];
	},
	
	hasFailed: function() {
	    return this.ran && this.failed.length > 0;
	},

	hasTests: function() {
	    return this.tests > 0;
	},

	hasRun: function() {
	    return this.tests == 0 || this.ran;
	}
	
    };

    return {

	// Returns all test fixtures, with the following format: 
	// { <file>: {
	//   verb: <string> | null, 
	//   path: <string> | null, 
	//   file: <string>, 
	//   categories: [ <string> ],
	//   description: <string>, 
	//   tests: <int> | null
	// }}
	all: function(callback) {
	    Test.all_ = [ callback ];
	    Test.all  = function(callback) { Test.all_.push(callback); };
	    $.get("/docs/all.json",function(contents){
		var fixtures = {};
		for (var k in contents) fixtures[k] = new Fixture(contents[k]);
		Test.all = function(callback) { callback(fixtures); };
		for (var i = 0; i < Test.all_.length; ++i) Test.all(Test.all_[i]);
	    });
	},

	// Get all tests as a category tree. Each tree node has the format: 
	// {
	//    __: "cat" | "test", 
	//   if __ = test 
	//     fixture: <test fixture> 
	//   if __ = cat 
	//     *: <node> 
	//     _f: <test fixture> || null
	// }
	// 
	// See Test.all for the format of <test fixture>. 

	tree: function(callback) {
	    Test.tree_ = [ callback ];
	    Test.tree  = function(callback) { Test.tree_.push(callback); };
	    Test.all(function(tests) {
		var tree = {};
		for (var path in tests) {
		    var test = tests[path], root = tree;
		    for (var i = 0; i < test.categories.length; ++i) {
			var cat = test.categories[i];
			if (cat in root) {
			    if (root[cat].__ == 'test') {
				root[cat].__ = 'cat';
				root[cat]._f.cat = root[cat];
			    }
			} else {
			    root[cat] = { '__' : "cat" };
			}
			root = root[cat];
		    }
		    if (test.description in root) {
			root[test.description]._f = test;
			test.cat = root[test.description];
		    } else {
			root[test.description] = { '__' : 'test', '_f': test };
		    }
		}
		Test.tree = function(callback) { callback(tree); };
		for (var i = 0; i < Test.tree_.length; ++i) Test.tree(Test.tree_[i]);
	    });
	},

	// Get the contents of a test, parsed (see parse.js for the format)
	get: function(id, callback) {
	    Test.get_ = Test.get_ || {};
	    var pending = Test.get_[id] = Test.get_[id] || {};

	    if ('wait' in pending) {
		pending.wait.push(callback);
	    } else {
		pending.wait = [callback];
		$.get("/docs/" + id, function(contents){
		    var fixture = /.js$/.exec(id) ? parseTestFixture(contents) : parseDoc(contents);
		    for (var i = 0; i < pending.wait.length; ++i) pending.wait[i](fixture);
		    delete pending.wait;
		}, 'text');
	    }
	},

	// Run all tests. Call the provided callback every time a test finishes
	// running.
	running: false,
	run: function(id, callback) {

	    if (Test.running) return;
	    Test.running = true;

	    var all = [];
	    Test.all(function(fixtures){

		for (var k in fixtures) {
		    if (!fixtures[k].hasTests()) continue;
		    if (id && fixtures[k].file != id) continue;
		    fixtures[k].startTesting();
		    all.push(k);
		}

		Test.ping();

		// This loop performs work on every test fixture selected above
		function loop(i) {
		    if (i == all.length) { Test.running = false; callback(null,null); return; }

		    // Set to true when the test is either interrupted or completes
		    // successfully.
		    var finished = false;

		    // If 'Test.ping' is not called for more than N seconds, 
		    // the test is aborted. 
		    function timeout(last) {
			setTimeout(function(){
			    if (finished) return;
			    if (last == Test.ping_) Test.fail("Timeout");
			    else timeout(Test.ping_);
			}, 10000)
		    }

		    timeout(Test.ping_);

		    // This function is called when the test failed. It is available
		    // from the outside as Test.fail(), but with the parameter being
		    function fail(what) {
			return function(reason) {			
			    if (finished) return;
			    fixtures[all[i]].failed.push({what:what,reason:reason});
			    next();
			}
		    }

		    Test.fail = fail("Loading fixture");

		    // This function starts the next test (after a short delay).
		    function next() {
			if (finished) return;
			fixtures[all[i]].ran = true;
			fixtures[all[i]].rcount = fixtures[all[i]].tests;
		    	finished = true;
			callback(all[i],null);
			loop(i+1);
		    }

		    // Run the tests by querying the test fixture and 
		    Test.get(all[i], function(fixture) {
			var tests = fixture.tests;
			
			function testLoop(j) {
			    fixtures[all[i]].rcount = j;
			    if (j == tests.length) { return next(); }
			    console.log("Starting: %s | %s", all[i], tests[j].name);
			    Test.fail = fail(tests[j].name);
			    delete Query.clock;
			    Test.ping();
			    tests[j].run(function(){ 
				callback(all[i],tests[j].name);
				setTimeout(function(){ testLoop(j+1); }, 50);
			    });
			}

			console.log("Starting: %s", all[i]);
			testLoop(0);
		    });
		}

		loop(0);
	    });
	},

	// The tests should call this function every so often, so that tests with
	// critical errors can be recognized.
	ping_: 0, 
	ping: function() {
	    Test.ping_++;
	},

	// Run a query.
	query: function() { return Query.create.apply(Query, arguments); } 

    };   

})();