/* Simple model. */

var Test = (function() {

    return {

	all: function(callback) {
	    Test.all_ = [ callback ];
	    Test.all  = function(callback) { Test.all_.push(callback); };
	    $.get("/docs/all.json",function(contents){
		Test.all = function(callback) { callback(contents); };
		for (var i = 0; i < Test.all_.length; ++i) Test.all(Test.all_[i]);
	    });
	},

	tree: function(callback) {
	    Test.tree_ = [ callback ];
	    Test.tree  = function(callback) { Test.tree_.push(callback); };
	    Test.all(function(tests) {
		var tree = {};
		for (var path in tests) {
		    var test = tests[path], root = tree;
		    for (var i = 0; i < test.categories.length; ++i) {
			var cat = test.categories[i];
			root[cat] = root[cat] || { '__' : "cat" };
			root = root[cat];
		    }
		    root[test.description] = { '__' : 'test', file: test };
		}
		Test.tree = function(callback) { callback(tree); };
		for (var i = 0; i < Test.tree_.length; ++i) Test.tree(Test.tree_[i]);
	    });
	},

	get: function(id, callback) {
	    Test.get_ = Test.get_ || {};
	    var cache = Test.get_[id] = Test.get_[id] || {};

	    if ('test' in cache) {	    
		callback(cache.test);
	    } else if ('wait' in cache) {
		cache.wait.push(callback);
	    } else {
		cache.wait = [callback];
		$.get("/docs/" + id, function(contents){
		    cache.test = contents;
		    for (var i = 0; i < cache.wait.length; ++i) cache.wait[i](contents);
		}, 'text');
	    }
	}

    };   

})();