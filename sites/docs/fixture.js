// A fixture is a group of tests for a specific API feature, with 
// the corresponding documentation. Some fixtures have sub-fixtures.

var Fixture = (function(){

    // Parsing functions used for the fixture contents

    function parseTestFixture(script) {
	
	var parsed = { tests: [], status: null, version: null };
	
	// The test functions themselves
	var run = eval("(function(TEST,TODO){\n" + script + "\n})")(function(name,func){
	    parsed.tests.push({name : name, func: func});
	},function(){});
	
	// The lines that are commented (the test fixture test)
	var lines = script.split("\n");
	var text  = [];
	for (var i = 0; i < lines.length; ++i) 
	    if (/^\s*\/\//.exec(lines[i])) 
		text.push(lines[i].replace(/^\s*\/\/\s?/,''));	    
	
	parsed.query = text.shift();
	parsed.description = text.shift().replace(/^.*\/\s*/,'');   
	
	while (text.length > 0 && text[0].trim() == '') text.shift();
	
	if (/@/.exec(text[0])) {
	    var current = text.shift().split('@');
	    parsed.status = current[0].trim();
	    parsed.version = current[1].trim();
	}
	
	parsed.body = markdown.toHTML(text.join('\n').trim());
	
	return parsed;
    }
    
    function parseDoc(md) {
	
	var parsed = { tests: [], status: null, version: null, query: null };
	var text = md.split("\n");
	
	parsed.description = text.shift();   
	
	while (text.length < 0 && text[0].trim() == '') text.shift();
	
	parsed.body = markdown.toHTML(text.join('\n').trim());
	
	return parsed;
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

	// The list of categories leading to this fixture. 
	this.categories = data.categories;

	// The description (used as title) 
	this.description = data.description;

	// The number of tests in the fixture. 
	this.nTests = data.tests || 0;

	// The actual list of tests, will be loaded when necessary. 
	this._tests = null;

	// The child fixtures
	this._fixtures = [];
    }

    F.prototype = {

	// The 'category path' of a fixture, of the form A::B::C
	catPath: function() { 
	    var parent = this.catParent();
	    if (parent) return parent + '::' + this.description; 
	    return this.description || '';
	},

	// All the child fixtures
	children: function() {
	    return this._fixtures;
	},

	// The 'category path' of a fixture's parent category fixture, of the form A::B
	catParent: function() { return this.categories.join('::'); },

	// Add a child fixture to this fixture
	addChild: function(fixture) {

	    // Do not be your own child 
	    if (fixture.catPath() == this.catPath()) return;

	    this._fixtures.push(fixture);
	},

	// Returns a promise that waits for all child tests (both in this fixture
	// and in child fixtures) to return. The provided callback function will 
	// be called whenever a test finishes.
	run: function(onTestEnd) {	  

	    var self = this;

	    // Always relod tests from scratch. This ensures server-side changes are
	    // taken into account, AND resets the statistics by clearing the old runs.
	    this.tests = null;
	    var myTests = this.loadTests().then(function(tests) {

		// Set to the real array to avoid async access when computing
		// statistics. 
		self._tests = tests;

		// Start all tests and wait for them to finish
		return $.when.apply($, tests.map(function(test) { return test.run(onTestEnd); }));

	    });

	    var myChildren = $.when.apply($, this._fixtures.map(function(f) { return f.run(onTestEnd); }));

	    return $.when(myTests, myChildren);
	},
	
	// Returns an object with statistics about this fixture and
	// all its child fixtures.
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

	    this._fixtures.forEach(function(fixture) {
		var stats = fixture.stats();
		mine.tests   += stats.tests;
		mine.failed  += stats.failed;
		mine.ran     += stats.ran;
		mine.running += stats.running;
	    });

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
	    var isJs = /.js$/.exec(this.file || '');
	    return this.raw().then(function(text){
		return isJs ? parseTestFixture(text) : parseDoc(text);
	    });
	},

	// Parses the raw contents of this fixture (if any), and extracts the tests
	// from it. 
	loadTests: function() {
	    return this.parsed().then(function(parsed){
		return parsed.tests.map(function(t) { return new Test(t.name,t.func); });
	    });
	},

	// Return a child by its category path. Follows the descriptions all the way 
	// down to a fixture an returns it. Argument can be a catPath()-like string, or
	// an array. 
	findByCatPath: function(catPath) {

	    if (typeof catPath == "string") 
		catPath = catPath.split('::').filter(function(s) { return s != ''; });
	    else
		catPath = catPath.slice(0);

	    if (catPath.length == 0) return this;
	    var first = catPath.shift();

	    for (var i = 0; i < this._fixtures.length; ++i)
		if (this._fixtures[i].description == first) 
		    return this._fixtures[i].findByCatPath(catPath);

	    return null;
	}
	
    };

    // A promise that returns all fixtures keyed by path.
    F.all = $.getJSON("/docs/all.json").then(function(json) {
	var r = {};
	for (var file in json) r[file] = new F(json[file]);
	return r;
    });

    // A promise that returns the root fixture
    F.root = F.all.then(function(all) {

	var fixtures = [];
	var fixturesByCatPath = {};
	
	// Fill with found fixtures
	for (var file in all) {
	    var fixture = all[file];
	    fixtures.push(fixture);
	    fixturesByCatPath[fixture.catPath()] = fixture;
	}
	
	// Fill in any missing parent catPaths 
	fixtures.forEach(function(fixture) {
	    
	    var parent = fixture.catParent();	
	    if (parent in fixturesByCatPath) return;
	    
	    var categories  = fixture.categories.slice(0);
	    var description = categories.length == 0 ? "" : categories.pop();
	    
	    var parentFixture = new F({
		file: parent.split('::').map(encodeURIComponent).join('/'),
		categories: categories,
		description: description
	    });
	    
	    all[parentFixture.file] = parentFixture;
	    fixtures.push(parentFixture);
	    fixturesByCatPath[parent] = parentFixture;
	    
	});
	
	// Connect each fixture to its parent
	fixtures.forEach(function(fixture) {
	    fixturesByCatPath[fixture.catParent()].addChild(fixture);
	});
	
	return fixturesByCatPath['']; 
	
    });

    return F;

})();
