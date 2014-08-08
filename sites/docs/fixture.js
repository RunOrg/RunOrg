// A fixture is a group of tests for a specific API feature, with 
// the corresponding documentation. Some fixtures have sub-fixtures.

var Fixture = (function(){

    // Parsing function used for the fixture contents

    function parseTestFixture(script) {
	
	var tests = [];
	
	// The test functions themselves
	var run = eval("(function(TEST,TODO){\n" + script + "\n})")(function(name,func){
	    tests.push({name : name, func: func});
	},function(){});

	return tests;
    }
    
    // Fixture class

    function F(data) {
	
	// The HTTP verb (for queries), 'JSON' (for types) or null.
	this.verb = data.verb || null;

	// The path (for queries), name (for types) or null. 
	this.path = data.path || null;

	// The source file that contains this fixture on the server.
	// Some fixtures are generated client-side and do not have a file.
	this.file = data.file || '';

	// The number of tests in the fixture. 
	this.nTests = data.tests || 0;

	// The actual list of tests, will be loaded when necessary. 
	this._tests = null;

	// The child fixtures
	this._fixtures = [];
    }

    F.prototype = Object.create({

	// Returns a promise that waits for all child tests (both in this fixture
	// and in child fixtures) to return. The provided callback function will 
	// be called whenever a test finishes.
	run: function(onTestEnd) {	  

	    var stats = this.stats();
	    if (stats.running > 0) return;

	    var self = this;

	    // Always reload tests from scratch. This ensures server-side changes are
	    // taken into account, AND resets the statistics by clearing the old runs.
	    this.tests = null;
	    
	    return this.loadTests().then(function(tests) {

		// Set to the real array to avoid async access when computing
		// statistics. 
		self._tests = tests;

		// Start all tests and wait for them to finish
		return $.when.apply($, tests.map(function(test) { return test.run(onTestEnd); }));

	    });
	},
	
	// Returns an object with statistics about this fixture.
	//  - tests: the number of tests
	//  - failed: the number of tests that ran and failed
	//  - ran: the number of tests that ran
	//  - running: the number of tests still running
	stats: function() {

	    var mine = { tests: this.nTests, failed: 0, ran: 0, running: 0 };

	    if (this._tests !== null) {
		this._tests.forEach(function(test) {
		    if (test.running()) mine.running++;
		    if (test.ran())     mine.ran++;
		    if (test.failed())  mine.failed++;
		});
	    }

	    return mine;
	},

	// Returns all tests that have failed. 
	failed: function() {
	    if (this._tests === null) return [];
	    return this._tests.filter(function(test) { return test.failed(); });
	},

	// Returns a promise that loads the raw contents of this fixture
	// (if it has a 'file'). 
	raw: function() {
	    if (this.file === null) return $.Deferred().resolve('').promise();
	    return $.get('/docs/' + this.file, function(){}, 'text');
	},

	// As 'raw()', but parses the fixture.
	parsed: function() {
	    return this.raw().then(function(text){
		return parseTestFixture(text);
	    });

	},

	// Parses the raw contents of this fixture (if any), and extracts the tests
	// from it. 
	loadTests: function() {
	    return this.parsed().then(function(tests){
		return tests.map(function(t) { return new Test(t.name,t.func); });
	    });
	},
	
    });

    // A promise that returns all fixtures keyed by path.
    F.all = $.getJSON("/docs/all.json").then(function(json) {
	var r = {};
	for (var file in json) r[file] = new F(json[file]);
	return r;
    });

    // A promise that returns an object containing all fixtures, with 
    // the following members:
    //  - all: a list of all fixtures
    //  - byFile: a dictionary of fixtures by file
    //  - stats(): computes the total stats for all fixtures
    //  - run(): runs all fixtures, returns a promise that resolves when
    //           all tests have finished running
    F.root = F.all.then(function(byFile) {
	
	var result = {

	    all: [],

	    byFile: byFile,

	    stats: function() {
		var stats = { tests: 0, failed: 0, ran: 0, running: 0 };

		this.all.forEach(function(fixture) {
		    var fixtureStats = fixture.stats();
		    for (var k in stats) stats[k] += fixtureStats[k];
		});

		return stats;
	    },

	    run: function(onTestEnd) {
		
		var promises = this.all.map(function(fixture) { 
		    return fixture.run(onTestEnd);
		});
		
		return $.when.apply($, promises);

	    }

	};

	// Fill with found fixtures
	for (var file in byFile) {
	    result.all.push(byFile[file]);
	}

	return result;

    });
	
    return F;

})();
