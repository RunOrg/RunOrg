/* Simple controller. */

/* Extend the layout to automatically render the sidebar. */
(function() {

    var layout = R.layout;

    function sidebar(R) {
	Test.tree(function(tree) {
	    function clean(tree) {
		var out = { sub: [], tests: [], count: 0, ok: true, ran: true };
		for (var k in tree) {
		    var node = tree[k];
		    if (k == '__') continue;
		    if (node['__'] == 'cat') {
			var s = clean(node);
			s.name = k;
			out.sub.push(s);
			out.count += s.count;
			out.ok = out.ok && s.ok;
		    } else {                
			out.tests.push({ 
			    name: k, 
			    ok:   !node.failed,
			    ran:  node.ran,
			    verb: node.file.verb,
			    path: node.file.path,
			    file: "/docs/" + node.file.file,
			    count: node.file.tests
			});
			out.count += node.file.tests;
			out.ok = out.ok && !node.failed;
			out.ran = out.ran && node.ran;
		    }
		}
		out.ran = out.ran && out.count > 0;
		return out;
	    }
	    
	    R.sidebar(clean(tree));
	    R.show();
	});
    }

    R.layout = function(data) {
	layout.call(this,$.extend({ sidebar : sidebar }, data || {}));
    }

})();

/* Root page */
Route.add(/^\/docs\/?$/, function(R) {
    R.layout();
    R.show();
});

/* Individual node pages */
Route.add(/^\/docs\/(.+)$/, function(R) {
    console.log(arguments);
});