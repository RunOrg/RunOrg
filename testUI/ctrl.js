/* Simple controller. */

/* Extend the layout to automatically render the sidebar. */
(function() {

    var layout = R.prototype.layout;

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
			    ok:   !node.fixture.failed,
			    ran:  node.fixture.ran,
			    verb: node.fixture.verb,
			    path: node.fixture.path,
			    file: "/docs/#/" + node.fixture.file,
			    count: node.fixture.tests
			});
			out.count += node.fixture.tests;
			out.ok = out.ok && !node.fixture.failed;
			out.ran = out.ran && node.fixture.ran;
		    }
		}
		out.ran = out.ran && out.count > 0;
		return out;
	    }
	    
	    R.sidebar(clean(tree));
	    R.show();

	    var location = document.location.pathname + document.location.hash;
	    var $a = $('a[href="' + location + '"]').addClass('active');
	    while ($a.length > 0) $a = $a.parent().closest('ul').show();	    
	});
    }

    R.prototype.layout = function(data) {
	function body(R) { R.show() }
	layout.call(this,$.extend({ sidebar : sidebar, body : body }, data || {}));
    }

})();

/* Root page */
Route.add(/^\/docs(\/(#\/?)?)?$/, function(R) {
    R.layout();
    R.show();
});

/* Individual node pages */
Route.add(/^\/docs\/#\/(.+)$/, function(R,path) {

    function body(R) {
	Test.get(path,function(contents) {
	    R.body(contents);
	    R.show();
	});
    }

    R.layout({ body: body });
    R.show();

});
