/* Simple model. */

var Test = (function() {

    return {

	all: function(callback) {
	    $.get("/docs/all.json",function(contents){
		Test.all = function(callback) { callback(contents); };
		Test.all(callback);
	    });
	},

	tree: function(callback) {
	    Test.all(function(tests) {
		var tree = {};
		for (var path in tests) {
		    var test = tests[path], root = tree;
		    for (var i = 0; i < test.categories.length; ++i) {
			var cat = test.categories[i];
			root[cat] = root[cat] || { '__' : "cat" };
			root = root[cat];
		    }
		    root[test.description] = { '__' : 'test', test: test };
		}
		Test.tree = function(callback) { callback(tree); };
		Test.tree(callback);
	    });
	}

    };   

})();