/* Simple controller. */

/* Root page */
Route.add(/^\/docs(\/(#\/?)?)?$/, function(R) {
    R.layout();
    R.show();
});

/* Individual node pages */
Route.add(/^\/docs\/#\/(.+)$/, function(R,path) {

    function body(R) {
	Test.all(function(all) {
	    Test.get(path,function(contents) {

		// Extract all sub-elements and display them in a 
		// pretty table format
		var meta = all[path], inner = [];
		if ('cat' in meta) {
		    for (var k in meta.cat) {
			if (k == '__' || k == '_f') continue;
			var sub = meta.cat[k];
			if (sub.__ == 'cat') continue;
			inner.push(sub.fixture);
		    }
		}

		R.body($.extend({inner:inner},contents));
		R.show();
	    });
	});
    }

    R.layout({ body: body });
    R.show();

});
